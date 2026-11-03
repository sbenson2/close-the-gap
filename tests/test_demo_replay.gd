extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Codec.VERSION == 3, "demo recordings version objectives, conditions and new equipment")
	if Codec.VERSION < 3:
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.selected_ruleset = "relay_v1"
	game.selected_environment = "rain"
	game.start_bot_duel("yard")
	game.bot_enabled = false
	game.phase = "playing"
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game, 10)
	game.broadcast_field("place", [1,"reflector",[0,0,15],0,0])
	game.broadcast_field("track", [2,[1,0,15],0,0])
	game.relay.rules.change(0,"stalker")
	game.broadcast_field("relay", [0,1,game.relay.rules.revision])
	for tick in range(90): await physics_frame
	recorder.finish()
	var path := "res://artifacts/demo/replay-test.json"
	check(recorder.save(path).is_empty(), "a recording with objective and field events saves and validates")
	var data: Dictionary = recorder.data
	game.start_replay(path)
	if game.replay:
		game.paused = true
		game.replay.seek(0.8)
		check(game.environment_id == "rain" and game.field.gadgets.size() == 1 and game.field.tracks.size() == 1, "seeking restores recorded conditions and physical evidence")
		check(game.relay.rules.stations[0] == 1, "objective state survives playback seeking")
		game.replay.seek(0)
		check(game.field.gadgets.is_empty() and game.field.tracks.is_empty(), "seeking backwards removes future evidence")
		check(game.relay.rules.stations[0] == 0 and game.relay.rules.revision == 0, "seeking backwards restores the earlier objective revision")
	else: check(false,"new recording opens for playback")
	var corrupt: Dictionary = data.duplicate(true)
	corrupt.frames[0].systems.relay[2] = [0,1,99]
	check(not Codec.validate(corrupt).is_empty(), "invalid objective state is rejected before playback")
	game.start_replay("res://replays/duel-session.json")
	check(game.replay != null and not game.field.enabled and game.map_revision == "ridge_v2", "the prior paired-duel recording retains its original interpretation")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_REPLAY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
