extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var level := args[0] if args.size() > 0 else "forest"
	var output := args[1] if args.size() > 1 else "res://replays/ai-session.json"
	var rounds := clampi(int(args[2]), 1, 5) if args.size() > 2 else 5
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.duel_seed = 71
	if "--relay" in args: game.selected_ruleset = "relay_v1"
	if "--rain" in args: game.selected_environment = "rain"
	game.selected_pairs = 3
	game.start_bot_duel(level)
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game, 1000)
	var started := Time.get_ticks_msec()
	while recorder.data.rounds.size() < rounds and not recorder.completed:
		await physics_frame
		if Time.get_ticks_msec() - started > 600000:
			push_error("Recording exceeded ten wall-clock minutes")
			quit(1)
			return
	recorder.finish()
	if recorder.data.rounds.size() != rounds:
		push_error("Recording did not contain the requested completed rounds")
		quit(1)
		return
	recorder.data.controller_sha256 = FileAccess.get_sha256("res://scripts/bot_controller.gd")
	recorder.data.tactics_sha256 = FileAccess.get_sha256("res://scripts/bot_tactics.gd")
	recorder.data.map_sha256 = {}
	for source in ["arena", "forest", "mountainside", "bot_tactics", "bot_senses", "field_systems", "relay_rules", "relay_controller", "rules"]:
		recorder.data.map_sha256[source] = FileAccess.get_sha256("res://scripts/" + source + ".gd")
	var error: String = recorder.save(output)
	print("STUDY_RECORDING_DONE ", JSON.stringify({"rounds": recorder.data.rounds.size(), "ticks": recorder.data.ticks,
		"frames": recorder.data.frames.size(), "events": recorder.data.events.size(), "error": error,
		"controller_sha256": FileAccess.get_sha256("res://scripts/bot_controller.gd")}))
	game.leave_game()
	game.queue_free()
	await process_frame
	quit(0 if error.is_empty() else 1)
