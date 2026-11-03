extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
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
	current_scene = game
	await process_frame
	game.start_bot_duel("forest")
	game.transition_time = 0.01
	for i in range(360):
		await physics_frame
		if i % 60 == 0:
			print("GROUND_PROBE second=%d a=%s b=%s path=%d state=%s" % [i / 60, game.players[1].position, game.players[2].position, game.bot_brains[1].path.size(), game.bot_brains[1].state])
	check(game.players[1].position.distance_to(game.arena.spawn_for("stalker")) > 4, "stalker moves on terrain")
	check(game.players[1].position.y >= game.arena.height_at(game.players[1].position.x, game.players[1].position.z) - 0.1, "terrain physically supports the stalker")
	game.paused = true
	var sniper = game.players[2]
	sniper.position = Vector3(0, 18.05, -30.6)
	sniper.velocity = Vector3.ZERO
	for i in range(90):
		sniper.simulate(1.0 / 60, Vector2(0, -1), 3, Vector2(PI, 0))
		await physics_frame
	check(sniper.position.z <= -30.5 and sniper.position.y >= 18, "sprinting and jumping cannot take the sniper off the ridge")
	var path = game.arena.path_to(sniper.position, Vector3(0, 0, 30), "sniper")
	var on_ridge: bool = not path.is_empty()
	for point in path:
		on_ridge = on_ridge and game.arena.sniper_bounds().has_point(point)
	check(on_ridge, "sniper navigation remains on high ground when pursuing a downhill target")
	check(game.arena.spawn_for("sniper").y - game.arena.spawn_for("stalker").y > 17, "forest has eighteen metres of elevation between spawns")
	var stalker = game.players[1]
	stalker.position = Vector3(0, 0.05, 35)
	stalker.velocity = Vector3.ZERO
	# Follow the clear western trail with the real player movement and collision.
	var route := [Vector3(-23, 0, 24), Vector3(-23, 0, 2), Vector3(-23, 0, -20), Vector3(0, 18, -34)]
	for destination in route:
		path = game.arena.path_to(stalker.position, destination)
		for point in path:
			for i in range(150):
				var toward := Vector2(point.x - stalker.position.x, point.y - stalker.position.z)
				if toward.length() < 0.8:
					break
				stalker.simulate(1.0 / 60, toward.normalized(), 2, Vector2.ZERO)
				await physics_frame
	check(stalker.position.y > 17.8 and stalker.position.z < -30, "stalker can physically climb the mountain slope to the sniper ridge")
	game.start_bot_duel("yard")
	game.paused = true
	sniper = game.players[2]
	sniper.position = Vector3(0, 3.95, -31.1)
	sniper.velocity = Vector3.ZERO
	for i in range(90):
		sniper.simulate(1.0 / 60, Vector2(0, -1), 3, Vector2(PI, 0))
		await physics_frame
	check(sniper.position.z <= -31 and sniper.position.y >= 3.9, "yard sniper cannot leave the raised loading deck")
	stalker = game.players[1]
	stalker.position = Vector3(-23, 0.05, -24)
	stalker.velocity = Vector3.ZERO
	for destination in [Vector3(-11, 0, -24), Vector3(-11, 3.9, -41), Vector3(0, 3.9, -40)]:
		path = game.arena.path_to(stalker.position, destination, "sniper" if stalker.position.y > 3.4 else "stalker")
		print("RAMP_PATH goal=%s points=%d" % [destination, path.size()])
		for point in path:
			for i in range(100):
				var toward := Vector2(point.x - stalker.position.x, point.y - stalker.position.z)
				if toward.length() < 0.8:
					break
				stalker.simulate(1.0 / 60, toward.normalized(), 4, Vector2.ZERO)
				await physics_frame
		print("RAMP_POSITION ", stalker.position)
	check(stalker.position.y > 3.8 and absf(stalker.position.x) < 2, "stalker can crouch up the concealed side ramp and reach the rear bridge")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("HIGH_GROUND_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
