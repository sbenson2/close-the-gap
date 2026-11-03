extends SceneTree

var game
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("PASS: ", message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(3):
		await physics_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("yard")
	game.paused = true
	var a = game.players[1]
	var b = game.players[2]
	var brain = game.bot_brains[1]
	a.position = Vector3(0, 0.05, 35)
	b.position = Vector3(0, 0.05, 29)
	a.aim = Vector2(0, 1.2)
	await settle()
	brain._observe()
	check(not brain.visible, "looking above the opponent does not grant horizontal-only vision")
	a.aim = Vector2.ZERO
	brain.visible = false
	brain.memory_age = 100
	brain.reaction = 0
	brain.hear_birds(Vector3(10, 0, 20))
	brain._observe()
	check(brain.visible, "physical front-facing opponent is still visible")
	check(brain.reaction > 0.2, "hearing a cue before first sight does not bypass visual acquisition delay")
	var seen: Vector3 = brain.last_known
	brain.visible = false
	brain.hear_birds(Vector3(-20, 0, -10))
	check(brain.last_known.is_equal_approx(seen), "a vague bird clue does not replace a fresh confirmed sighting")
	b.position = Vector3(0, 0.05, 35)
	a.position = Vector3(6, 0.05, 31.5)
	b.aim = Vector2.ZERO
	b.scoped = true
	await settle()
	var watching = game.bot_brains[2]
	watching._observe()
	check(not watching.visible, "scoped sniper cannot identify an opponent far outside its narrow view")
	a.position = Vector3(0, 0.05, 29)
	await settle()
	watching._observe()
	check(watching.visible, "scoped sniper retains vision along the actual sight direction")
	a.crouched = true
	watching.visible = false
	watching.visual_age = 2
	watching._observe()
	watching.sense_clock = 1000
	var before_shots: int = watching.shots
	for i in range(48):
		watching.tick(1.0 / 60)
	check(watching.visible and watching.shots == before_shots, "a brief view of a crouched silhouette is insufficient for a precise rifle shot")
	a.position = Vector3(-15, 0.05, 20)
	a.crouched = true
	await settle()
	var remembered: Vector3 = watching.last_known
	watching._observe()
	check(not watching.visible and watching.last_known.is_equal_approx(remembered), "hidden movement cannot update visual target memory")
	game.start_bot_duel("yard")
	game.paused = true
	game.phase = "playing"
	a = game.players[1]
	b = game.players[2]
	a.position = Vector3(-17, 0.05, 38)
	b.position = Vector3(0, 0.05, 29)
	b.aim = Vector2.ZERO
	await settle()
	brain = game.bot_brains[1]
	game._resolve_action(2, "attack", Vector2.ZERO)
	check(brain.cue_source == "shot" and not brain.visible and brain.cue_radius >= 2, "an audible rifle shot creates an uncertain cue without visual lock")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("BOT_AWARENESS_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
