extends SceneTree

const Assets = preload("res://scripts/model_assets.gd")

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1440, 810)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293c42")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	canvas.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.8
	canvas.add_child(light)
	var camera := Camera3D.new()
	canvas.add_child(camera)
	camera.position = Vector3(0, 4.3, 10)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	var keys := ["stag", "deer", "fox", "rabbit", "crow"]
	for i in range(keys.size()):
		var key: String = keys[i]
		var source := Assets.scene(key)
		var box := Assets.bounds(source)
		var wrapper := Node3D.new()
		canvas.add_child(wrapper)
		wrapper.position.x = (i - 2) * 1.8
		wrapper.rotation.y = -0.6
		wrapper.scale = Vector3.ONE * [2.0, 1.65, 0.58, 0.42, 0.35][i] / box.size.y
		source.position.y = -box.position.y
		wrapper.add_child(source)
		var player := Assets.find_animation(source)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		Assets.animation_at(player, "Walk" if i < 3 else "walk", 0.4)
		var label := Label.new()
		label.text = key.capitalize()
		label.position = Vector2(65 + i * 270, 600)
		label.add_theme_font_size_override("font_size", 24)
		canvas.add_child(label)
	for i in range(10):
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var picture := canvas.get_texture().get_image()
	picture.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var result := picture.save_png("res://artifacts/asset-animals.png")
	print("ASSET_SHEET result=", result)
	quit(0 if result == OK else 1)
