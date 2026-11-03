extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seconds: float = 600.0
	var output: String = "res://replays/forest-session.json"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		seconds = clampf(float(args[0]), 1, 1800)
	if args.size() >= 2:
		output = args[1]
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_bot_duel("forest")
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game, seconds)
	print("RECORDING_START seconds=%.0f headless=%s" % [seconds, DisplayServer.get_name() == "headless"])
	await recorder.finished
	var error: String = recorder.save(output)
	print("RECORDING_DONE frames=%d events=%d rounds=%d seconds=%.1f error=%s" % [recorder.data.frames.size(), recorder.data.events.size(), recorder.data.rounds.size(), seconds, error])
	game.leave_game()
	game.queue_free()
	for i in range(6):
		await process_frame
	quit(0 if error.is_empty() else 1)
