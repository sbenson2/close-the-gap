extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var recorded := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--replay-at="):
			for i in range(3):
				await process_frame
			if game.mode != "replay":
				game.start_replay()
			game.paused = true
			game.replay.seek(float(arg.trim_prefix("--replay-at=")))
			recorded = true
	if "--wildlife" in OS.get_cmdline_user_args():
		for i in range(3):
			await process_frame
		game.paused = true
		game.phase = "playing"
		game.round_time = 142
		var animals = game.arena.get_node("Wildlife")
		animals._update_animal(animals.walkers[0], 12.0)
		var target: Vector3 = animals.walkers[0].node.position + Vector3.UP
		var p = game.players[1]
		p.position = target + Vector3(1.7, -1, 3.2)
		p.position.y = game.arena.height_at(p.position.x, p.position.z)
		var direction: Vector3 = (target - p.eye_position()).normalized()
		p.aim = Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
		game.bird_alarm(game.round_index, 0, Vector3(0, 0, 1), 143)
		game.arena.birds.visual_time = 10
		game.arena.birds._update_visuals()
		var bird: Vector3 = game.arena.birds.bird_positions[0]
		var sniper = game.players[2]
		var toward: Vector3 = (bird - sniper.eye_position()).normalized()
		sniper.aim = Vector2(atan2(-toward.x, -toward.z), asin(toward.y))
		sniper.scoped = true
		sniper.camera.fov = 23
	if "--quick" in OS.get_cmdline_user_args():
		for i in range(8):
			await process_frame
	else:
		await create_timer(9.0).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(1000, 625, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var filename: String = "forest-wildlife.png" if "--wildlife" in OS.get_cmdline_user_args() else "bot-duel.png"
	if recorded:
		filename = "recorded-session.png"
	image.save_png("res://artifacts/" + filename)
	image = null
	print("CAPTURED_BOTH_POVS")
	print("FOREST_RENDER_METRICS fps=%d draw_calls=%d primitives=%d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.leave_game()
	game.queue_free()
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	quit()
