extends SceneTree

const Rules = preload("res://scripts/rules.gd")
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
	check(Rules.BUILD_ID == "demo-20261102" and Rules.RULESETS.has("relay_v1"),"export contains the demo rules and build identity")
	check(not FileAccess.file_exists("res://tests/test_demo_pack.gd") and not FileAccess.file_exists("res://tools/verify_demo_play.py"),"the player pack excludes development tests and tools")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	check(game.mode == "menu" and game.phase == "menu" and game.ui.menu_screen == "home","the exported game opens the play menu")
	game.selected_ruleset = Rules.RELAY
	game.selected_environment = "rain"
	game.selected_pairs = 3
	game.start_practice("stalker")
	check(game.field.enabled and game.field.rain != null and game.field.rope_points.size() == 17,"export contains forest weather and the physical handline")
	check(game.relay.positions.size() == 3 and game.players[1].reflectors == 1 and game.players[2].alarms == 1,"export contains all objective stations and role equipment")
	game.leave_game()
	game.select_level("yard")
	game.start_practice("sniper")
	check(game.field.rain != null and game.field.rope_points.is_empty(),"yard weather works without creating a forest handline")
	game.start_featured_replay()
	check(game.replay != null and game.replay.data.version == 3 and game.replay.data.rounds.size() == 5 and game.ruleset_id == Rules.RELAY,"featured export footage is the new five-round relay recording")
	if game.replay:
		game.paused = true
		game.replay.seek(game.replay.duration * .5)
		check(game.field.rain != null and game.bot_brains[1].elapsed == 0,"exported replay restores weather without running bot decisions")
	game.start_replay("res://replays/duel-session.json")
	check(game.replay != null and game.map_revision == "ridge_v2" and not game.field.enabled,"the prior paired recording retains its original field interpretation")
	game.leave_game()
	game.queue_free()
	for i in range(4): await process_frame
	print("DEMO_PACK_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
