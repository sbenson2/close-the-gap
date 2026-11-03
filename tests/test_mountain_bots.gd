extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	var failures := 0
	for side in [-1.0, 1.0]:
		game.start_bot_duel("mountain")
		# Fix the flank to reproduce the two independently observed failures.
		game.bot_brains[1].chosen_flank = true
		game.bot_brains[1].flank = side
		if side > 0:
			# Isolate arrival at an obstructed route marker from combat outcomes.
			game.bot_brains[1].sense_clock = 1000
			game.bot_brains[2].sense_clock = 1000
		var height := 0.0
		var stalls := 0
		var violations := 0
		for frame in range(3600):
			await physics_frame
			var stalker = game.players[1] if game.players[1].role == "stalker" else game.players[2]
			var sniper = game.players[1] if game.players[1].role == "sniper" else game.players[2]
			height = maxf(height, stalker.position.y)
			if game.phase == "playing" and stalker.command_move.length() > 0.3 and Vector2(stalker.velocity.x, stalker.velocity.z).length() < 0.05:
				stalls += 1
			if not game.arena.Mountain.sniper_allowed(Vector2(sniper.position.x, sniper.position.z)):
				violations += 1
			if game.phase in ["round_over", "match_over"]:
				break
		var passed := height > 13 and stalls < 300 and violations == 0
		if not passed:
			failures += 1
		print("MOUNTAIN_BOT_PROGRESS flank=", side, " height=", height, " stalled_seconds=", stalls / 60.0, " violations=", violations)
		print("PASS: " if passed else "FAIL: ", "bot climbs its forest approach and sniper remains on high ground")
	game.start_bot_duel("mountain")
	game.paused = true
	var stalker = game.players[1]
	var brain = game.bot_brains[1]
	stalker.position = game.arena.Mountain.NESTS[6]
	brain.chosen_flank = true
	brain.flank = 1
	brain.patrol = 3
	brain.visible = true
	brain.visual_age = 0
	brain.memory_age = 0
	brain.last_known = game.arena.Mountain.NESTS[3]
	brain.last_facing = Vector3.RIGHT
	brain._stalker(1.0 / 60, stalker.position.distance_to(brain.last_known))
	var holds_flank: bool = brain.patrol == 3 and Vector2(brain.goal.x - 25, brain.goal.z + 3).length() < 0.1
	if not holds_flank:
		failures += 1
	print("PASS: " if holds_flank else "FAIL: ", "a distant confirmed sighting does not send the stalker across the exposed valley")
	stalker.position = game.arena.Mountain.NESTS[5]
	brain.last_known = stalker.position + Vector3(2, 0, 0)
	brain.last_facing = Vector3.FORWARD
	brain.path_clock = 0 # Independent contact scenario; discard the prior path's hysteresis.
	brain._stalker(1.0 / 60, 2)
	var closes: bool = brain.state == "Closing silently from behind" and brain.goal.distance_to(brain.last_known - brain.last_facing * 1.5) < 0.1
	if not closes:
		failures += 1
	print("PASS: " if closes else "FAIL: ", "a nearby observed target permits the final rear approach")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("MOUNTAIN_BOTS_RESULT checks=4 failures=", failures)
	quit(1 if failures else 0)
