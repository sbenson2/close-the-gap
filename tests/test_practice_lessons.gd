extends SceneTree

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
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	check(game.has_method("start_lesson"), "short role lessons are available before a live duel")
	if game.has_method("start_lesson"):
		game.start_lesson("stalker")
		game.phase = "playing"
		for i in range(10): await physics_frame
		check(game.mode == "practice" and game.selected_level == "yard" and game.bot_brains[2].elapsed == 0, "rear-approach lesson uses a safe static target with real combat rules")
		game.local_player().position = Vector3(0, 3.95, -40)
		game.local_player().aim = Vector2(PI, 0)
		for i in range(2): await physics_frame
		game.request_action("attack")
		check(game.phase == "match_over" and not game.players[2].alive, "successful rear attack completes the lesson without an unrelated role swap")
		game.rematch()
		check(game.practice_lesson == "stalker" and game.phase == "countdown" and game.players[2].alive, "lesson retry resets the same teaching encounter")
		game.start_lesson("sniper")
		check(game.local_player().role == "sniper" and game.local_player().rifle_ammo == 1, "rifle lesson starts with a visible partial magazine for reload practice")
		game.start_practice("stalker")
		check(game.practice_lesson.is_empty(), "starting normal practice clears the static-target lesson")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("PRACTICE_LESSONS_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
