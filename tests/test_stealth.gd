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
	game.start_bot_duel("yard")
	game.paused = true
	game.phase = "playing"
	var stalker = game.players[1]
	var sniper = game.players[2]
	var sneaking = game.bot_brains[1]
	var watching = game.bot_brains[2]
	stalker.position = Vector3(0, 3.95, -33.8)
	sniper.position = Vector3(0, 3.95, -36)
	sniper.aim = Vector2(PI, 0)
	stalker.aim = Vector2.ZERO
	for i in range(3):
		await physics_frame
	sneaking.sense_clock = 0
	sneaking.tick(0.15)
	check(stalker.active_weapon == "knife" and (stalker.command_flags & 4) != 0, "stalker uses a knife and crouches instead of starting a handgun duel")
	sneaking.reaction = 0
	sneaking.tick(0.15)
	check(sniper.health == 100 and sneaking.shots == 0, "stalker refuses a frontal knife attack")
	stalker.position = Vector3(0, 3.95, -38.0)
	stalker.aim = Vector2(PI, 0)
	stalker.crouched = true
	for i in range(3):
		await physics_frame
	watching.sense_clock = 0
	watching.tick(0.15)
	check(not watching.visible and watching.sightings == 0, "sniper cannot see a crouched opponent behind its head at close range")
	sneaking.patrol = 5
	sneaking.sense_clock = 0
	sneaking.tick(0.15)
	sneaking.reaction = 0
	sneaking.tick(0.15)
	check(not sniper.alive and "Knife elimination" in game.result_text, "stalker performs a real knife elimination from behind")
	check(watching.sightings == 0, "rear knife elimination can complete without the sniper ever seeing the stalker")
	game.leave_game()
	game.queue_free()
	for i in range(6):
		await process_frame
	print("STEALTH_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
