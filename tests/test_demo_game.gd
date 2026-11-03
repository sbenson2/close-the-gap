extends SceneTree

var checks := 0
var failures := 0
var game

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
	check(game.get("field") != null and game.get("relay") != null, "demo has physical field and relay systems")
	if game.get("relay") != null:
		game.selected_ruleset = "relay_v1"
		game.start_bot_duel("yard")
		game.bot_enabled = false
		game.paused = true
		game.phase = "playing"
		var actor = game.players[1]
		var station: Vector3 = game.relay.positions[0]
		actor.position = station + Vector3(0, 0, 1.5)
		var offset: Vector3 = (station + Vector3.UP * 0.8 - actor.eye_position()).normalized()
		actor.aim = Vector2(atan2(-offset.x, -offset.z), asin(offset.y))
		actor.command_flags = 16
		for i in range(20): game.relay.step(0.1)
		check(actor.interaction_progress > 1, "holding interact at a real accessible station advances sabotage")
		actor.position.x += 0.4
		game.relay.step(0.1)
		check(actor.interaction_progress == 0, "moving interrupts the committed interaction")
		actor.command_flags = 0
		game.relay.step(0.1)
		actor.command_flags = 16
		for i in range(42): game.relay.step(0.1)
		check(game.relay.rules.stations[0] == 1, "completed physical sabotage changes the host-owned station")
		check(actor.reflectors == 1 and game.players[2].alarms == 1, "roles spawn with bounded utility supplies")
		game._resolve_action(1, "reflector", actor.aim)
		check(actor.reflectors == 0 and game.field.gadgets.size() == 1, "placing a reflector consumes its single supply")
		game._resolve_action(1, "reflector", actor.aim)
		check(game.field.gadgets.size() == 1, "repeated placement cannot duplicate a depleted utility")
		var sniper = game.players[2]
		sniper.simulate(0.016, Vector2.ZERO, 32, sniper.aim)
		check(sniper.binoculars and not sniper.scoped, "wide observation does not emit a rifle scope glint")
		var before: int = sniper.rifle_ammo
		game._resolve_action(2, "attack", sniper.aim)
		check(sniper.rifle_ammo == before, "observation must be released before firing")
		game.field.clock = 14
		check(game.field.movement_mask() < 0.6, "shared gusts create a real movement-audibility window")
		game.field.clock = 2
		check(game.field.movement_mask() >= 0.9, "calm intervals restore normal movement audibility")
	game.phase = "playing"
	game.receive_snapshot(game.round_index,[],"match_over",0,5)
	check(game.phase == "playing","an unreliable snapshot cannot finish a match before its reliable result")
	game.phase = "countdown"
	game.field_event(game.round_index,"place",[999,"reflector",[0,0,0],0,0])
	check(game.field.gadgets.any(func(item): return item.serial == 999),"reliable field events arriving before the playing snapshot are retained")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_GAME_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
