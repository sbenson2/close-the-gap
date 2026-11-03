extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("forest")
	var recorder = load("res://scripts/replay_recorder.gd").new()
	game.add_child(recorder)
	recorder.setup(game, 30)
	for tick in range(15):
		await physics_frame
	check(recorder.has_method("finish"), "a multi-round recording can stop cleanly at its chosen round boundary")
	if recorder.has_method("finish"):
		recorder.finish()
		check(recorder.data.ticks > 0 and recorder.data.ticks < 1800, "early completion retains actual recorded duration")
		check(recorder.data.frames[-1].t == recorder.data.ticks, "early completion includes the final saved state")
		check(Codec.validate(recorder.data).is_empty(), "early completion produces a valid compatible replay")
		var frames: int = recorder.data.frames.size()
		recorder.finish()
		for tick in range(6):
			await physics_frame
		check(recorder.data.frames.size() == frames, "completion is idempotent and stops further sampling")
	recorder.set_physics_process(false)
	if game.gameplay_event.is_connected(recorder._event):
		game.gameplay_event.disconnect(recorder._event)
	game.leave_game()
	game.queue_free()
	await process_frame
	print("STUDY_RECORDING_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
