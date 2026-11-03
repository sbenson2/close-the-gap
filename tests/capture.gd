extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(path: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.resize(1000, 625, Image.INTERPOLATE_LANCZOS)
	picture.save_png(path)
	print("CAPTURED " + path)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.auto_watch = false
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.5).timeout
	await shot("res://artifacts/menu.png")
	scene.start_practice("stalker")
	await create_timer(3.3).timeout
	print("UI_GEOMETRY root=%s ui=%s hud=%s clock=%s" % [str(root.size), str(scene.ui.size), str(scene.ui.hud.size), str(scene.ui.clock_label.get_rect())])
	await shot("res://artifacts/knife.png")
	scene.local_player().command_flags = 0
	Input.action_press("forward")
	await create_timer(0.8).timeout
	Input.action_release("forward")
	scene.request_action("handgun")
	Input.action_press("scope")
	await create_timer(0.5).timeout
	await shot("res://artifacts/handgun.png")
	Input.action_release("scope")
	scene.leave_game()
	scene.start_practice("sniper")
	await create_timer(3.3).timeout
	await shot("res://artifacts/rifle.png")
	Input.action_press("scope")
	await create_timer(0.6).timeout
	await shot("res://artifacts/scope.png")
	Input.action_release("scope")
	quit()
