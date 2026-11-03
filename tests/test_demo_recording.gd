extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_bot_duel("yard")
	game.spectator.stop()
	game.bot_enabled = false
	game.set_physics_process(false)
	game.bot_brains.clear()
	var remote = game.players[2]
	game.players.erase(2)
	remote.peer_id = 777
	game.players[777] = remote
	game.guest_id = 777
	game.scores = {1:0,777:0}
	game.mode = "online"
	game.phase = "playing"
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game,20)
	game.match_recording = recorder
	for i in range(12): await physics_frame
	game.attack_effect(777,"rifle",remote.eye_position(),Vector3.ZERO,1,0)
	for i in range(12): await physics_frame
	check(recorder.data.actors_kind == "players" and recorder.data.events[0].v[0] == 2 and recorder.data.events[0].v[4] == 1,"human recordings map real peer IDs into stable playback slots")
	game.round_index = 1
	game.announce_result(777,"Recording fixture",{1:0,777:1})
	for i in range(4): await physics_frame
	check(recorder.completed and recorder.data.frames[-1].winner == 2,"a finished human match closes its recording automatically")
	var result: String = game.save_match()
	check(result.begins_with("Saved.") and FileAccess.file_exists(game.saved_match_path),"the result screen saves a validated human match")
	var path: String = game.saved_match_path
	check(game.save_match().begins_with("Saved.") and game.saved_match_path == path,"repeated save clicks keep one recording")
	game.leave_game()
	game.start_replay(path)
	check(game.replay != null and game.replay.data.actors_kind == "players","saved human matches open in the existing split-screen replay")
	if game.replay:
		game.paused = true
		game.replay.seek(game.replay.duration)
		check(game.players[1].health == 0 and game.winner_id == 2,"human playback restores damage and the winning player")
	game.leave_game()
	DirAccess.remove_absolute(path)
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_RECORDING_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
