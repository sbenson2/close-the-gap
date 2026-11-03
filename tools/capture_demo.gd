extends SceneTree

var game
var canvas: SubViewport
var output_dir := "res://artifacts/demo"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func shot(name_text: String) -> void:
	for i in range(7): await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	image.resize(1000,625,Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(output_dir.path_join(name_text + ".png"))
	print("DEMO_CAPTURE ",name_text," error=",error)
	if error != OK: quit(1)

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	canvas = SubViewport.new()
	canvas.size = Vector2i(1440,900)
	canvas.own_world_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://main.tscn").instantiate()
	canvas.add_child(game)
	game.sound.muted = true
	await shot("home")
	game.selected_ruleset = "relay_v1"
	game.selected_environment = "rain"
	game.selected_pairs = 3
	game.ui.show_host()
	await shot("host")
	game.configure_lobby(2,"mountain","relay_v1","rain",3,{1:true,2:false})
	await shot("ready")
	game.start_bot_duel("mountain")
	game.phase = "playing"
	game.paused = true
	game.field.clock = 14
	game.field._update_weather()
	game.players[1].position = game.relay.positions[0] + Vector3(0,0,1.5)
	var direction: Vector3 = (game.relay.positions[0] + Vector3.UP - game.players[1].eye_position()).normalized()
	game.players[1].aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	game.players[2].position = game.arena.Mountain.NESTS[4] + Vector3(0,0,-1)
	game.players[2].aim = Vector2(PI,-0.3)
	await shot("rain-split")
	game.leave_game()
	game.start_practice("stalker")
	game.phase = "playing"
	game.paused = true
	var actor = game.players[1]
	actor.position = game.relay.positions[0] + Vector3(0,0,1.5)
	direction = (game.relay.positions[0] + Vector3.UP * .8 - actor.eye_position()).normalized()
	actor.aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	actor.interaction_progress = 2
	await shot("relay-interaction")
	game.leave_game()
	game.ui.show_guide(false)
	await shot("guide")
	game.leave_game()
	canvas.queue_free()
	for i in range(3): await process_frame
	quit()
