extends SceneTree

var game
var side: String
var folder: String
var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",side," / ",text)

func mark(key: String) -> void:
	FileAccess.open(folder.path_join(key),FileAccess.WRITE).store_string("ready")

func until(condition: Callable, description: String, seconds: float = 14) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call():
		if Time.get_ticks_msec() >= deadline:
			check(false,"timed out: " + description + " / " + game.phase)
			return false
		await physics_frame
	return true

func wait_for(key: String, seconds: float = 14) -> bool:
	return await until(func(): return FileAccess.file_exists(folder.path_join(key)),key,seconds)

func aim_at(actor, point: Vector3) -> void:
	var direction: Vector3 = (point + Vector3.UP * .8 - actor.eye_position()).normalized()
	actor.aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	side = args[0]
	folder = args[1]
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	if side == "host":
		game.selected_ruleset = "relay_v1"
		game.selected_environment = "rain"
		game.selected_pairs = 3
		game.host_game(int(args[2]))
		mark("host")
	else:
		if not await wait_for("host"):
			quit(1)
			return
		game.join_game("127.0.0.1",int(args[2]))
	if not await until(func(): return game.phase == "lobby","ready room"):
		quit(1)
		return
	check(game.players.is_empty(),"no player is spawned before both friends are ready")
	check(game.ruleset_id == "relay_v1" and game.environment_id == "rain" and game.pairs_to_play == 3,"host's full-match and weather choices replicate")
	if side == "host":
		game.set_ready(true)
		mark("host_ready")
	else:
		await wait_for("host_ready")
		await create_timer(.2).timeout
		check(game.phase == "lobby", "one ready player cannot start the match")
		game.set_ready(true)
	if not await until(func(): return game.phase == "playing","countdown"):
		quit(1)
		return
	if game.players.size() != 2:
		check(false,"both actor scenes instantiate")
		quit(1)
		return
	if side == "host":
		var actor = game.players[1]
		var point: Vector3 = game.relay.positions[0]
		actor.position = point + Vector3(0,.05,1.5)
		aim_at(actor,point)
		game.request_action("reflector")
		await create_timer(1.15).timeout
		Input.action_press("interact")
		await create_timer(4.2).timeout
		Input.action_release("interact")
		check(game.relay.rules.stations[0] == 1, "host physically sabotages the first relay")
		mark("first")
		point = game.relay.positions[1]
		actor.position = point + Vector3(0,.05,1.5)
		actor.velocity = Vector3.ZERO
		aim_at(actor,point)
		await create_timer(.2).timeout
		Input.action_press("interact")
		await create_timer(4.2).timeout
		Input.action_release("interact")
		check(game.relay.rules.stations[1] == 1 and game.relay.rules.deadline > 28,"second sabotage starts the shared repair deadline")
		var remote = game.players[game.guest_id]
		point = game.relay.positions[0]
		remote.position = point + Vector3(0,.05,1.5)
		remote.velocity = Vector3.ZERO
		mark("repair")
		if await wait_for("repaired"):
			check(game.relay.rules.stations[0] == 2 and game.relay.rules.deadline == 0,"guest repair is authoritative and cancels the deadline")
		if await wait_for("utilities"):
			check(game.field.gadgets.size() == 2 and remote.alarms == 0,"guest utility placement replicates once and consumes supply")
			game.end_round(1,"Demo network fixture")
			for index in range(1,6):
				game.transition_time = .01
				await until(func(): return game.phase == "countdown","role swap")
				game.transition_time = .01
				await until(func(): return game.phase == "playing","next round")
				check(game.round_index == index,"full match progresses through complete role pairs")
				game.end_round(1 if index % 2 == 0 else game.guest_id,"Demo network fixture")
			check(game.phase == "match_over" and game.round_index == 5,"full match ends after all six rounds")
		if await wait_for("rematch_requested"):
			await until(func(): return game.phase == "lobby","rematch room")
			check(game.ready_players.get(game.guest_id,false),"guest can request the rematch first")
			game.set_ready(true)
			await wait_for("done")
	else:
		var weather_updates := 0
		var last_weather: float = game.field.clock
		for frame in range(12):
			await physics_frame
			if game.field.clock != last_weather: weather_updates += 1
			last_weather = game.field.clock
		check(weather_updates >= 9,"guest weather animates every physics step between snapshots")
		if await wait_for("first"):
			await until(func(): return game.relay.rules.stations[0] == 1 and game.field.gadgets.size() == 1,"station and reflector replication",3)
			check(game.relay.rules.stations[0] == 1 and game.field.gadgets.size() == 1,"station and reflector state reach the guest")
		if await wait_for("repair"):
			await create_timer(.4).timeout
			var actor = game.local_player()
			aim_at(actor,game.relay.positions[0])
			Input.action_press("interact")
			await create_timer(5.4).timeout
			Input.action_release("interact")
			check(game.relay.rules.stations[0] == 2 and game.relay.rules.deadline == 0,"held guest interaction repairs through the input channel")
			mark("repaired")
			game.request_action("alarm")
			await create_timer(1.2).timeout
			check(actor.alarms == 0,"guest alarm inventory agrees with the host")
			Input.action_press("observe")
			await create_timer(.2).timeout
			check(actor.binoculars and not actor.scoped,"observation flag replicates without rifle glint")
			Input.action_release("observe")
			mark("utilities")
		if await until(func(): return game.phase == "match_over","six-round result"):
			check(game.round_index == 5 and game.completed_reviews.size() == 6,"guest receives complete results and each round's review")
			await physics_frame
			check(game.save_match().begins_with("Saved."),"a completed online match saves with canonical player IDs")
			if not game.saved_match_path.is_empty(): DirAccess.remove_absolute(game.saved_match_path)
			game.rematch()
			mark("rematch_requested")
			await until(func(): return game.phase == "countdown","mutual rematch readiness")
			check(game.scores.get(1) == 0 and game.local_player().alarms == 1,"mutual rematch resets match score and equipment")
			mark("done")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_PEER_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
