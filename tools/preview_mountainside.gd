extends SceneTree

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func run() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(960, 720)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	canvas.add_child(game)
	game.start_bot_duel("mountain")
	game.sound.muted = true
	game.paused = true
	game.spectator.stop()
	canvas.disable_3d = false
	game.ui.hide()
	game.spectator.hide()
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false
	var camera := Camera3D.new()
	canvas.add_child(camera)
	camera.current = true
	camera.far = 300
	var shots := [
		["overview", Vector3(73, 90, 107), Vector3(0, 15, -12), 60.0],
		["lookout", Vector3(-20, 26, -6), Vector3(-25, 23, -15), 65.0],
		["ravine", Vector3(-8, 2.62, 36), Vector3(-13, 24, -30), 75.0],
		["crown", Vector3(-13, 30.62, -31.0), Vector3(1, 6, 18), 78.0],
		["east-stand", Vector3(19, 23, 8), Vector3(25, 20, -3), 65.0],
	]
	for shot in shots:
		camera.position = shot[1]
		camera.look_at(shot[2])
		camera.fov = shot[3]
		for i in range(8):
			await RenderingServer.frame_post_draw
		var output: String = "res://artifacts/mountainside/" + shot[0] + ".png"
		DirAccess.make_dir_recursive_absolute("res://artifacts/mountainside")
		var error := canvas.get_texture().get_image().save_png(output)
		print("MOUNTAIN_PREVIEW ", output, " error=", error)
	game.leave_game()
	canvas.queue_free()
	await process_frame
	await process_frame
	quit()
