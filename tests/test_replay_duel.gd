extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var failures := 0
var checks := 0

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
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("yard")
	game.bot_enabled = false
	game.phase = "playing"
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game, 8)
	game._resolve_action(1, "pebble", Vector2(0, 0.3))
	game._resolve_action(2, "attack", Vector2(0, 1.2))
	game._resolve_action(2, "reload", Vector2(0, 1.2))
	for tick in range(220):
		await physics_frame
	game.round_time = 0.001
	for tick in range(4):
		await physics_frame
	recorder.finish()
	check(recorder.data.get("version") == 3 and recorder.data.get("ruleset_id") == "duel_v2", "new recordings identify the actual duel rules")
	check(Codec.validate(recorder.data).is_empty(), "new combat, reload, projectile and draw events produce a valid recording")
	check(recorder.data.rounds.size() == 1 and recorder.data.rounds[0].role == "draw", "recording a timeout draw needs no nonexistent winner actor")
	if recorder.data.get("version") == 3:
		var path := "res://artifacts/design-slice/replay-test.json"
		check(recorder.save(path).is_empty(), "new recording saves with validated resource state")
		var data: Dictionary = recorder.data
		game.start_replay(path)
		game.paused = true
		if not game.replay:
			check(false, "new replay opens: " + str(Codec.read(path)))
			game.queue_free()
			quit(1)
			return
		check(game.ruleset_id == "duel_v2", "playback restores its recorded ruleset")
		game.replay.seek(0.1)
		check(game.projectiles.size() == 1, "seeking reconstructs a pebble already in flight")
		game.replay.seek(3.5)
		check(game.projectiles.is_empty(), "seeking after an impact does not resurrect the projectile")
		var corrupt: Dictionary = data.duplicate(true)
		corrupt.ruleset_id = "unknown_rules"
		check(not Codec.validate(corrupt).is_empty(), "unknown rules cannot silently change replay interpretation")
		corrupt = data.duplicate(true)
		corrupt.frames[0].actors[1][21] = -1
		check(not Codec.validate(corrupt).is_empty(), "invalid recorded rifle ammunition is rejected")
	game.start_replay("res://replays/mountain-session.json")
	check(game.mode == "replay" and game.ruleset_id == "classic_v1", "legacy recordings explicitly retain classic rules")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("REPLAY_DUEL_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
