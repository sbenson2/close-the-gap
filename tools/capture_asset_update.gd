extends SceneTree

var game
var canvas: SubViewport

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func layout() -> void:
	game.spectator.replay_controls.hide()
	game.spectator.row.offset_bottom = 0
	for child in game.spectator.get_children():
		if child is HBoxContainer and child != game.spectator.row:
			child.hide()

func settle() -> void:
	layout()
	for i in range(8):
		await RenderingServer.frame_post_draw

func capture(title: String) -> void:
	await settle()
	var image := canvas.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png("res://artifacts/asset-" + title + ".png")
	if error != OK:
		push_error("Asset capture failed: " + title)
		quit(1)
		return
	print("ASSET_CAPTURE ", title)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	create_timer(60).timeout.connect(func():
		push_error("Asset capture exceeded 60 seconds")
		quit(1))
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	canvas.add_child(game)
	game.sound.muted = true
	game.start_replay()
	game.paused = true
	game.replay.seek(61.8)
	await capture("forest")
	var animals = game.arena.get_node("Wildlife")
	animals._update_animal(animals.walkers[0], 12.0)
	var actor = game.players[1]
	var target: Vector3 = animals.walkers[0].node.position + Vector3.UP * 1.15
	actor.position = target + Vector3(1.8, -1.15, 3.8)
	actor.position.y = game.arena.height_at(actor.position.x, actor.position.z)
	var direction: Vector3 = (target - actor.eye_position()).normalized()
	actor.aim = Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
	await capture("wildlife")
	game.replay.seek(30)
	actor = game.players[1]
	actor.equip("handgun")
	actor.aiming = true
	actor.camera.fov = 56
	actor.weapon.position = Vector3(-0.28, 0.135, 0.09)
	await capture("handgun")
	game.replay.seek(55)
	await settle()
	game.paused = false
	var previous := Time.get_ticks_usec()
	var until := previous + 6000000
	var times: Array[float] = []
	while Time.get_ticks_usec() < until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
	game.paused = true
	times.sort()
	var sum := 0.0
	for value in times:
		sum += value
	var report := {"frames": times.size(), "mean_fps": times.size() * 1000.0 / sum,
		"median_frame_ms": times[times.size() / 2], "p95_frame_ms": times[int(times.size() * 0.95)],
		"size": [1920, 1080], "renderer": RenderingServer.get_video_adapter_name(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open("res://artifacts/asset-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("ASSET_PERFORMANCE ", JSON.stringify(report))
	game.start_bot_duel("yard")
	game.paused = true
	game.bot_enabled = false
	await capture("yard")
	game.queue_free()
	await process_frame
	quit()
