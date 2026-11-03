extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var game
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var loaded := Codec.read("res://replays/forest-session.json")
	check(loaded.has("data"), "headless session is a valid recording")
	if not loaded.has("data"):
		printerr(loaded)
		quit(1)
		return
	var data: Dictionary = loaded.data
	check(data.headless and data.ticks == 36000 and data.frames.size() >= 12000, "recording contains ten simulated minutes sampled at 20 Hz")
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_replay()
	game.paused = true
	check(game.mode == "replay" and not game.is_authority() and not game._can_input(), "playback cannot run authoritative simulation or accept player movement")
	check(game.players[1].has_pov and game.players[2].has_pov and game.spectator.replay_controls.visible, "recording uses both first-person views and replay controls")
	var samples: Array = [data.frames[0], data.frames[150], data.frames[-1]]
	var selected: Dictionary = {}
	for frame in data.frames:
		if int(frame.r) in [1, 3] and not selected.has(int(frame.r)):
			samples.append(frame)
			selected[int(frame.r)] = true
			if selected.size() == 2:
				break
	var exact := true
	var roles := true
	for frame in samples:
		game.replay.seek(float(frame.t) / 60)
		for i in range(2):
			exact = exact and game.players[i + 1].position.distance_to(Codec.vector(frame.actors[i][0])) < 0.003 and game.players[i + 1].health == int(frame.actors[i][7])
			roles = roles and game.players[i + 1].role == data.scenes[int(frame.r)].roles[i]
		exact = exact and game.scores[1] == int(frame.scores[0]) and game.phase == frame.phase
	check(exact, "seeking restores recorded positions, health, scores and match phase")
	check(roles, "role swaps and rematches reconstruct the recorded actors")
	var a: Dictionary = data.frames[100]
	var b: Dictionary = data.frames[101]
	game.replay.seek((float(a.t) + float(b.t)) / 120)
	check(game.players[1].position.distance_to(Codec.vector(a.actors[0][0]).lerp(Codec.vector(b.actors[0][0]), 0.5)) < 0.003, "movement interpolates between recorded samples")
	var stopped: Vector3 = game.players[1].position
	await frames(8)
	check(game.players[1].position.is_equal_approx(stopped) and game.bot_brains[1].elapsed == 0, "pause holds the replay and AI never reruns")
	var attack: Dictionary = {}
	for event in data.events:
		if event.kind == "attack":
			attack = event
			break
	game.replay.seek(float(attack.t) / 60 - 0.1)
	var events_before: int = game.replay.applied_events
	game.paused = false
	game.replay._process(0.2)
	game.paused = true
	check(game.replay.applied_events > events_before and game.players[int(attack.v[4])].health == int(attack.v[5]), "recorded attacks restore combat effects and their original damage")
	game.replay.seek(float(attack.t) / 60)
	check(game.players[int(attack.v[4])].health == int(attack.v[5]), "seeking at an attack preserves its exact damage between state samples")
	check(game.bot_brains[1].shots == 0 and game.bot_brains[2].shots == 0, "replay does not decide new attacks")
	game.replay.seek(4)
	game.replay.rate = 2
	game.paused = false
	game.replay._process(0.5)
	game.paused = true
	check(is_equal_approx(game.replay.position, 5.0), "playback speed advances the recorded timeline")
	game.replay.rate = 1
	game.replay.seek(game.replay.duration - 0.1)
	game.paused = false
	game.replay._process(1)
	check(game.paused and is_equal_approx(game.replay.position, game.replay.duration), "end of recording stops playback")
	var small: Dictionary = data.duplicate(false)
	small.frames = [data.frames[0].duplicate(true), data.frames[1].duplicate(true)]
	small.ticks = small.frames[-1].t
	small.events = []
	check(Codec.validate(small).is_empty(), "small complete recording validates")
	small.frames[1].t = 0
	check(not Codec.validate(small).is_empty(), "duplicate or reversed timestamps are rejected")
	small.frames[1].t = small.ticks
	small.frames[1].actors[0][0][0] = INF
	check(not Codec.validate(small).is_empty(), "nonfinite recorded transforms are rejected")
	game.start_replay("res://replays/missing-session.json")
	check(game.mode == "menu" and game.replay == null and game.players.is_empty(), "missing recording returns to a clean menu")
	game.queue_free()
	await frames(6)
	print("REPLAY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
