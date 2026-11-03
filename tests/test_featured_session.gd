extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var current_path := "res://replays/duel-session.json" if FileAccess.file_exists("res://replays/duel-session.json") else "res://replays/mountain-session.json"
	if FileAccess.file_exists("res://replays/demo-session.json"): current_path = "res://replays/demo-session.json"
	var decoded := Codec.read(current_path)
	check(decoded.has("data"), "the featured five-round session is present and validates")
	if decoded.has("data"):
		var data: Dictionary = decoded.data
		check(data.rounds.size() == 5 and data.headless, "featured session contains five completed headless rounds")
		var game = load("res://main.tscn").instantiate()
		game.auto_watch = false
		root.add_child(game)
		game.start_featured_replay()
		game.paused = true
		check(game.mode == "replay" and game.replay.data.rounds.size() == 5 and game.arena.map_id == "mountain", "normal featured entry selects the new mountainside session")
		var middle: int = data.rounds[2].scene
		var tick := -1
		for frame in data.frames:
			if int(frame.r) == middle:
				tick = int(frame.t)
				break
		game.replay.seek((tick + 6) / 60.0)
		check(game.replay.active_scene == middle, "third completed round seeks to its actual saved scene")
		game.paused = false
		for frame in range(20):
			await process_frame
		check(game.bot_brains[1].elapsed == 0 and game.bot_brains[2].elapsed == 0, "playback reconstructs saved states without rerunning decisions")
		game.start_replay("res://replays/ai-session.json")
		check(game.arena.map_id == "forest" and game.replay.data.rounds.size() == 5, "earlier five-round recording retains its original Pine Hollow terrain")
		game.start_replay("res://replays/forest-session.json")
		check(is_equal_approx(game.replay.duration, 600), "the earlier ten-minute recording remains playable")
		game.leave_game()
		game.queue_free()
		await process_frame
	print("FEATURED_SESSION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
