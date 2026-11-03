extends SceneTree

var canvas: SubViewport
var game
var output := "res://artifacts/design-slice"

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(5): await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	image.resize(1000, 625, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(output.path_join(title + ".png"))
	print("SLICE_CAPTURE ", title, " error=", error)
	if error != OK:
		quit(1)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(70).timeout.connect(func(): quit(1))
	canvas = SubViewport.new()
	canvas.size = Vector2i(1440, 900)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	canvas.add_child(game)
	game.sound.muted = true
	game.ui.show_practice()
	await shot("practice")
	game.start_lesson("sniper")
	game.phase = "playing"
	game.paused = true
	await shot("rifle-hud")
	game.phase = "playing"
	game.remember_event("Bird alarm")
	game.remember_event("Rifle fired and hit")
	game.end_round(1, "Rifle elimination.")
	game.ui.show_round_review()
	await shot("round-review")
	game.start_bot_duel("mountain")
	game.paused = true
	game.players[1].position = game.arena.Mountain.NESTS[0] + Vector3(0, 0, -2)
	game.players[2].position = game.arena.Mountain.NESTS[4] + Vector3(0, 0, -1)
	game.players[2].aim = Vector2(PI, -0.35)
	await shot("split-pov")
	game.leave_game()
	canvas.queue_free()
	for i in range(3): await process_frame
	quit()
