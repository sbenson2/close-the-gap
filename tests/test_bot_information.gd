extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("yard")
	game.paused = true
	var brain = game.bot_brains[1]
	check(brain._knowledge().get("confidence", 0) == 0 and not brain._knowledge().has("position"), "a new bot has no assumed opponent position, including spawn")
	if failures:
		game.leave_game()
		game.queue_free()
		await process_frame
		print("BOT_INFORMATION_RESULT checks=%d failures=%d" % [checks, failures])
		quit(1)
		return
	var own = game.players[2]
	var opponent = game.players[1]
	game.arena.box(Vector3(0, 5, -40.5), Vector3(70, 10, 0.5), game.arena.concrete, true, false)
	var decisions: Array = []
	var variant := 0
	for hidden in [Vector3(-5, 0.05, -44), Vector3(0, 0.05, -43), Vector3(24, 0.05, -44)]:
		own.position = game.arena.spawn_for("sniper")
		own.aim = Vector2(PI, 0)
		own.velocity = Vector3.ZERO
		opponent.position = hidden
		opponent.velocity = Vector3(variant, 0, variant)
		opponent.crouched = variant % 2 == 0
		opponent.aim = Vector2(variant, variant * 0.2)
		variant += 1
		await physics_frame
		var clone = load("res://scripts/bot_controller.gd").new()
		clone.setup(game, own, 513)
		clone.sense_clock = 0
		var history: Array = []
		for tick in range(30):
			clone.tick(1.0 / 60)
			history.append(str([clone.state, own.command_move, own.command_flags, own.aim, clone.goal, clone.path, clone.hide_plan, clone.rng.state, clone.last_known]))
		check(not clone.visible and clone.cue_source == "none", "silent occluded opponent supplies no observation")
		decisions.append(str(history))
	check(decisions[0] == decisions[1] and decisions[1] == decisions[2], "moving a silent unseen opponent cannot change movement, aim, route, hide choice or decision RNG")
	var properties: Array = brain.get_property_list().map(func(item): return item.name)
	check(not properties.has("enemy") and not properties.has("game"), "decision controller holds neither an opponent object nor the game roster")
	var sound: Dictionary = brain.senses.hear_shot(Vector3(20.25, 0.8, -43.75), "rifle")
	check(not sound.is_empty() and sound.radius >= 6 and sound.position.distance_to(Vector3(20.25, 0.8, -43.75)) > 0.1, "sound interface supplies an uncertain area rather than the emitter coordinates")
	check(brain.senses.hear_shot(Vector3(-10.25, 0.8, 23.75), "rifle").is_empty(), "occluded distant shots cannot create an inaudible positional clue")
	brain.receive_sound(sound)
	check(not brain.visible and brain._knowledge().confidence <= 0.3 and brain.last_aim_point == Vector3.ZERO, "sound creates low-confidence search memory without a firing lock")
	check(brain.senses.hear_shot(Vector3.ZERO, "knife").is_empty(), "silent knife action creates no positional clue")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("BOT_INFORMATION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
