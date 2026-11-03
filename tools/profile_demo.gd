extends SceneTree

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func run() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	canvas.add_child(game)
	game.selected_ruleset = "relay_v1"
	game.selected_environment = "rain"
	game.selected_pairs = 3
	game.start_bot_duel("mountain")
	game.sound.muted = true
	for i in range(180):
		await process_frame
	var times: Array[float] = []
	var stalls: Array = []
	var started := Time.get_ticks_usec()
	var previous := started
	for i in range(1800):
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed_ms := (now - previous) / 1000.0
		times.append(elapsed_ms)
		if elapsed_ms > 40: stalls.append({"ms":elapsed_ms,"field_clock":game.field.clock,"gadgets":game.field.gadgets.size(),"phase":game.phase,"state":[game.bot_brains[1].state,game.bot_brains[2].state]})
		previous = now
		if now - started >= 15000000:
			break
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	times.sort()
	var report := {"stalls":stalls,"resolution": [1920, 1080], "mode": "live split-screen bots", "seconds": elapsed,
		"frames": times.size(), "average_fps": times.size() / elapsed, "median_ms": times[times.size() / 2],
		"p95_ms": times[int(times.size() * 0.95)], "p99_ms": times[int(times.size() * 0.99)], "max_ms": times[-1],
		"gpu": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://artifacts/demo")
	FileAccess.open("res://artifacts/demo/windows-performance.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("DEMO_PERFORMANCE ", JSON.stringify(report))
	game.leave_game()
	canvas.queue_free()
	for i in range(8): await process_frame
	quit()
