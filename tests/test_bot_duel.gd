extends SceneTree

var game
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	check(game.has_method("start_bot_duel"), "bot versus bot mode exists")
	if not game.has_method("start_bot_duel"):
		game.free()
		finish()
		return
	game.auto_watch = false
	game.selected_ruleset = "classic_v1"
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_bot_duel()
	await frames(3)
	check(game.mode == "bot_duel" and game.players.size() == 2, "duel spawns two bots")
	check(game.bot_brains.size() == 2 and game.bot_brains[1] != game.bot_brains[2], "each bot owns independent perception and navigation state")
	check(game.players[1].has_pov and game.players[2].has_pov, "both bots have first-person weapons and cameras")
	check(not game.players[1].is_local and not game.players[2].is_local, "neither bot is controlled by local player input")
	check(game.spectator.views.size() == 2, "spectator has two independent viewports")
	check(game.spectator.views[0].viewport.world_3d == game.spectator.views[1].viewport.world_3d, "both views show the same shared match")
	check(game.spectator.views[0].camera.global_position.distance_to(game.spectator.views[1].camera.global_position) > 50, "the viewports show distinct first-person positions")
	game.transition_time = 0.01
	await frames(5)
	var before: Vector3 = game.players[1].position
	await frames(150)
	check(game.players[1].position.distance_to(before) > 1, "stalker actively moves through the level")
	game.paused = true
	before = game.players[1].position
	var clock: float = game.round_time
	await frames(20)
	check(game.players[1].position.is_equal_approx(before) and game.round_time == clock, "pause stops both bot movement and match clock")
	game.leave_game()
	check(not root.disable_3d and not game.spectator.visible, "leaving restores normal rendering and closes spectator views")
	game.select_level("yard")
	game.start_bot_duel()
	game.paused = true
	await frames(3)
	var spawn_query := PhysicsRayQueryParameters3D.create(game.players[2].eye_position(), game.players[1].eye_position(), 3, [game.players[2].get_rid()])
	var spawn_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(spawn_query)
	check(not spawn_hit.is_empty() and spawn_hit.collider != game.players[1], "yard stalker spawn is protected from the initial rifle sightline")
	var a = game.players[1]
	var b = game.players[2]
	a.position = Vector3(0, 0.05, 35)
	b.position = Vector3(0, 0.05, 29)
	a.aim = Vector2.ZERO
	await frames(3)
	var brain = game.bot_brains[1]
	brain.sense_clock = 0
	brain.tick(0.15)
	check(brain.visible, "bot perceives a visible opponent")
	var remembered: Vector3 = brain.last_known
	b.position = Vector3(-15, 0.05, 20)
	await frames(3)
	brain.sense_clock = 0
	brain.tick(0.15)
	check(not brain.visible, "solid cover blocks bot vision")
	check(brain.last_known.is_equal_approx(remembered), "bot retains last seen position instead of reading a hidden opponent's location")
	game.leave_game()
	game.select_level("forest")
	game.start_bot_duel()
	game.transition_time = 0.01
	for i in range(9060):
		await physics_frame
		if game.phase == "round_over" or game.phase == "match_over":
			break
	check("elimination" in game.result_text, "two bots complete a round through real combat")
	print("BOT_ROUND result=%s seconds=%.2f" % [game.result_text, 150.0 - game.round_time])
	for id in [1, 2]:
		print("BOT_STATE id=%d position=%s stage=%d state=%s path=%s goal=%s" % [id, game.players[id].position, game.bot_brains[id].patrol, game.bot_brains[id].state, game.bot_brains[id].path, game.bot_brains[id].goal])
	game.transition_time = 0.01
	await frames(5)
	check(game.players[1].role == "sniper" and game.players[2].role == "stalker", "bot duel swaps roles for the next round")
	game.scores[1] = 2
	game.phase = "playing"
	game.end_round(1, "Test match completion")
	check(game.phase == "match_over", "bot duel reaches match completion")
	game.transition_time = 0.01
	await frames(5)
	check(game.phase == "countdown" and game.scores[1] == 0 and game.spectator.views[0].actor == game.players[1], "bot duel automatically starts a fresh match and rebinds both views")
	game.leave_game()
	game.queue_free()
	await frames(3)
	finish()

func finish() -> void:
	print("BOT_DUEL_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
