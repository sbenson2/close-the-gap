extends SceneTree

var failures: int = 0
var checks: int = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	# Retain regression coverage of the shipped legacy ruleset.
	game.selected_ruleset = "classic_v1"
	root.add_child(game)
	current_scene = game
	await frames(4)
	check(game.phase == "menu", "game boots into menu")
	game.ui.show_join()
	game.join_game("", 27015)
	check(game.ui.status.text.contains("Enter"), "joining with empty address gives an actionable error")
	game.select_level("yard")
	game.bot_enabled = false
	game.start_practice("stalker")
	await frames(5)
	check(game.players.size() == 2, "practice spawns both players")
	check(game.players[1].role == "stalker" and game.players[2].role == "sniper", "practice roles assigned")
	check(game.phase == "countdown", "round starts with a countdown")
	game.transition_time = 0.01
	await frames(4)
	check(game.phase == "playing", "countdown unlocks the round")
	var p = game.players[1]
	var original: Vector3 = p.position
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(p.position.z < original.z - 1.0, "movement input advances through physics")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(p.position.y > 0.1, "jump input lifts the player")
	await frames(65)
	Input.action_press("crouch")
	await frames(3)
	check(p.crouched, "crouch reaches gameplay state")
	check(p.body_shape.shape.height < 1.3, "crouching reduces the actual hit volume")
	Input.action_release("crouch")
	p.position = Vector3(0, 0.1, -15)
	p.velocity = Vector3.ZERO
	p.aim = Vector2.ZERO
	Input.action_press("forward")
	await frames(200)
	Input.action_release("forward")
	print("RAMP_END position=%s phase=%s" % [str(p.position), game.phase])
	check(p.position.y > 3.7 and p.position.z < -30, "knife player can climb the ramp to the sniper deck")
	# Actual knife ray against a CharacterBody, with no cover in between.
	p.position = Vector3(0, 3.95, -35)
	game.players[2].position = Vector3(0, 3.95, -36.8)
	p.aim = Vector2.ZERO
	await frames(2)
	game.request_action("attack")
	check(game.phase == "round_over" and game.scores[1] == 1, "knife hit awards exactly one round")
	game.request_action("attack")
	check(game.scores[1] == 1, "repeated attack after elimination cannot duplicate score")
	game.transition_time = 0.01
	await frames(4)
	check(game.players[1].role == "sniper", "next round swaps weapons")
	game.transition_time = 0.01
	await frames(3)
	p = game.players[1]
	var opponent = game.players[2]
	p.position = Vector3(0, 3.95, -38)
	opponent.position = Vector3(0, 3.95, -33)
	p.aim = Vector2(PI, 0)
	await frames(2)
	game.request_action("attack")
	check(p.cooldown > 2.0, "rifle shot starts the bolt cooldown")
	check(not opponent.alive and game.scores[1] == 2, "clear rifle ray eliminates the opponent")
	game.transition_time = 0.01
	await frames(4)
	game.transition_time = 0.01
	await frames(3)
	game.end_round(1, "Test elimination")
	check(game.phase == "match_over" and game.scores[1] == 3, "first to three ends the match")
	game.rematch()
	check(game.phase == "countdown" and game.scores[1] == 0, "rematch resets scores")
	# Timer awards the sniper, independent of which peer carries the rifle.
	game.transition_time = 0.01
	await frames(3)
	game.round_time = 0.01
	await frames(3)
	check(game.winner_id == 2 and game.phase == "round_over", "timeout awards the current sniper")
	game.leave_game()
	check(game.players.is_empty() and game.phase == "menu", "leaving cleans up players")
	game.queue_free()
	await frames(3)
	print("GAMEPLAY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
