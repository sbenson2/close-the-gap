extends SceneTree

var game
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
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.bot_enabled = false
	game.select_level("yard")
	game.start_practice("sniper")
	game.phase = "playing"
	game.ui._process(0)
	check(game.ui.weapon_label.text.contains("3 | 9"), "rifle HUD exposes loaded ammunition and reserve")
	var actor = game.players[1]
	actor.velocity = Vector3.ZERO
	var quiet: String = actor.noise_description()
	game.players[2].position = Vector3(50, 10, 20)
	check(actor.noise_description() == quiet, "self-noise feedback is independent of hidden enemy distance")
	game.remember_event("Rifle fired")
	check(game.review_text().is_empty(), "round review cannot expose events during live play")
	game.scores = {1: 1, 2: 0}
	game.round_index = 1
	game.end_round(2, "test")
	check(game.set_winner() == 0, "set winner derives from the whole role pair")
	var heading = game.ui.content.get_child(0)
	check(heading.text == "Set drawn", "a split pair shows a draw instead of a misleading defeat")
	var review: Button
	for child in game.ui.content.get_children():
		if child is Button and child.text == "Review round":
			review = child
	check(review != null, "completed pair offers a skippable evidence review")
	if review:
		review.pressed.emit()
		check(game.ui.menu_screen == "review" and game.review_text().contains("Rifle fired"), "review opens the completed round's actual evidence")
	game.leave_game()
	game.ui.show_practice()
	check(game.ui.content.find_child("RulesPicker", true, false) != null, "practice exposes the supported rulesets")
	var status_reference: WeakRef = weakref(game.ui.status)
	game.queue_free()
	for i in range(3):
		await process_frame
	check(status_reference.get_ref() == null, "closing an unparented menu status releases its owned label and font resources")
	print("DUEL_INTERFACE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
