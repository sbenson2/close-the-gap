extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("mountain")
	var log := FileAccess.open("res://artifacts/mountainside/path-probe.jsonl", FileAccess.WRITE)
	for frame in range(2400):
		await physics_frame
		if frame % 15 == 0:
			var actor = game.players[1]
			var brain = game.bot_brains[1]
			var next: Vector2 = brain.path[brain.waypoint] if brain.waypoint < brain.path.size() else Vector2.INF
			var hits: Array = []
			for i in range(actor.get_slide_collision_count()):
				var hit = actor.get_slide_collision(i)
				hits.append({"normal": hit.get_normal(), "collider": str(hit.get_collider()), "position": hit.get_position()})
			log.store_line(JSON.stringify({"seconds": frame / 60.0, "state": brain.state, "position": actor.position, "goal": brain.goal, "path": brain.path, "waypoint": brain.waypoint, "next": next, "velocity": actor.velocity, "move": actor.command_move, "aim": actor.aim, "seen": brain.visible, "visual_age": brain.visual_age, "hits": hits, "floor": actor.is_on_floor()}))
	log.close()
	game.leave_game()
	game.queue_free()
	await process_frame
	quit()
