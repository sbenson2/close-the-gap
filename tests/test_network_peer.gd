extends SceneTree

var game
var failures: int = 0
var side: String
var folder: String
var port: int

func mark(step: String, data: String = "ready") -> void:
	var file := FileAccess.open(folder.path_join(step), FileAccess.WRITE)
	file.store_string(data)
	file.close()

func wait_for(step: String, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not FileAccess.file_exists(folder.path_join(step)):
		if game and game.phase == "lobby": game.set_ready(true)
		if Time.get_ticks_msec() > deadline:
			check(false, "timed out waiting for " + step)
			return false
		await create_timer(0.05).timeout
	return true

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL [%s]: %s" % [side, message])
	else:
		print("PASS [%s]: %s" % [side, message])

func wait_phase(wanted: String, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while game.phase != wanted:
		if game.phase == "lobby": game.set_ready(true)
		if Time.get_ticks_msec() > deadline:
			check(false, "phase did not become " + wanted + " (actual " + game.phase + ")")
			return false
		await physics_frame
	return true

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	side = args[0]
	folder = args[1]
	port = int(args[2])
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	game.selected_ruleset = "classic_v1"
	root.add_child(game)
	current_scene = game
	await process_frame
	if side == "host":
		await host_test()
	else:
		await guest_test()
	print("NETWORK_RESULT %s failures=%d" % [side, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func host_test() -> void:
	game.select_level("forest")
	game.host_game(port)
	check(game.mode == "hosting", "ENet server listens")
	mark("host_ready")
	if not await wait_phase("playing"):
		return
	check(game.players.size() == 2, "host has both peers")
	check(game.arena.map_id == "forest", "host runs selected forest level")
	if not await wait_for("guest_moved"):
		return
	var guest = game.players[game.guest_id]
	check(guest.position.z > -34, "host simulates guest movement input")
	var scope_deadline: int = Time.get_ticks_msec() + 3000
	while not guest.scoped and Time.get_ticks_msec() < scope_deadline:
		await physics_frame
	check(guest.scoped, "scope state replicated to host")
	mark("scope_checked")
	check(guest.position.is_finite(), "malformed network input is rejected")
	check(guest.position.y >= 18 and guest.position.z <= -30.5, "host keeps the online sniper on the ridge")
	var alarm_count: int = game.arena.birds.alarm_count
	game.announce_birds(0, Vector3.FORWARD)
	check(game.arena.birds.alarm_count == alarm_count + 1, "host creates an authoritative bird disturbance")
	mark("birds_ready", str(game.arena.birds.alarm_count))
	if not await wait_for("birds_seen"):
		return
	# Move both real peers onto an unobstructed line of fire.
	game.players[1].position = Vector3(0, 18.05, -33)
	guest.position = Vector3(0, 18.05, -39)
	game.players[1].velocity = Vector3.ZERO
	guest.velocity = Vector3.ZERO
	await create_timer(0.5).timeout
	mark("rifle_ready")
	if not await wait_phase("round_over", 15):
		return
	check(game.scores[game.guest_id] == 1, "remote rifle hit awards the guest")
	if not await wait_phase("playing"):
		return
	guest = game.players[game.guest_id]
	check(guest.role == "stalker", "host swaps guest to knife")
	guest.position = Vector3(0, 18.05, -33)
	game.players[1].position = Vector3(0, 18.05, -39)
	guest.velocity = Vector3.ZERO
	game.players[1].velocity = Vector3.ZERO
	await create_timer(0.5).timeout
	mark("handgun_ready")
	if not await wait_for("handgun_hit"):
		return
	await create_timer(0.25).timeout
	check(game.players[1].health == 60 and game.players[1].alive, "host applies nonlethal remote handgun damage")
	check(guest.active_weapon == "handgun" and guest.aiming, "handgun selection and aiming reach host")
	check(guest.handgun_ammo == 5, "host owns handgun ammunition")
	mark("handgun_checked")
	if not await wait_for("reload_done"):
		return
	check(guest.handgun_ammo == 6 and guest.handgun_reserve == 11, "remote reload is resolved by host")
	game.players[1].position = Vector3(0, 18.05, -34.8)
	await create_timer(0.5).timeout
	mark("knife_ready")
	if not await wait_phase("round_over"):
		return
	check(game.scores[game.guest_id] == 2, "remote knife hit awards the guest")
	if not await wait_phase("playing"):
		return
	game.round_time = 0.01
	if not await wait_phase("match_over"):
		return
	check(game.scores[game.guest_id] == 3, "timeout reaches first-to-three match result")
	if not await wait_for("guest_match_over"):
		return
	game.rematch()
	await create_timer(0.4).timeout
	mark("rematch_ready")
	if not await wait_for("guest_rematch"):
		return
	game.leave_game()
	mark("host_left")
	await wait_for("guest_disconnected", 12)

func guest_test() -> void:
	if not await wait_for("host_ready"):
		return
	game.select_level("yard")
	game.join_game("127.0.0.1", port)
	if not await wait_phase("playing"):
		return
	check(game.local_id != 1 and game.local_player().role == "sniper", "guest handshake assigns rifle")
	check(game.arena.map_id == "forest" and game.selected_level == "forest", "host forest selection replaces guest local selection")
	Input.action_press("forward")
	await create_timer(0.8).timeout
	Input.action_release("forward")
	Input.action_press("scope")
	await create_timer(0.2).timeout
	game.submit_input.rpc_id(1, Vector2(INF, 0), 0, Vector2(INF, 0), 1000000)
	mark("guest_moved")
	if not await wait_for("scope_checked"):
		return
	Input.action_release("scope")
	if not await wait_for("birds_ready"):
		return
	await create_timer(0.2).timeout
	check(game.arena.birds.alarm_count == int(FileAccess.get_file_as_string(folder.path_join("birds_ready"))), "bird disturbance replicates to the guest")
	check(game.arena.birds.last_alarm.is_equal_approx(game.arena.bird_perches[0]), "both peers identify the same disturbed tree")
	mark("birds_seen")
	if not await wait_for("rifle_ready"):
		return
	game.local_player().aim = Vector2(PI, 0)
	game.request_action("attack")
	if not await wait_phase("round_over"):
		return
	check(game.scores.get(game.local_id, 0) == 1, "rifle result replicated")
	if not await wait_for("handgun_ready"):
		return
	check(game.local_player().role == "stalker", "guest receives swapped knife role")
	game.request_action("handgun")
	await create_timer(0.3).timeout
	game.local_player().aim = Vector2.ZERO
	Input.action_press("scope")
	await create_timer(0.2).timeout
	game.request_action("attack")
	mark("handgun_hit")
	if not await wait_for("handgun_checked"):
		return
	check(game.players[1].health == 60, "guest receives opponent handgun damage")
	check(game.local_player().handgun_ammo == 5 and game.local_player().aiming, "guest receives ammunition and aim state")
	game.request_action("reload")
	await create_timer(1.9).timeout
	check(game.local_player().handgun_ammo == 6 and game.local_player().handgun_reserve == 11, "guest receives completed reload")
	mark("reload_done")
	if not await wait_for("knife_ready"):
		return
	Input.action_release("scope")
	game.request_action("knife")
	await create_timer(0.2).timeout
	game.local_player().aim = Vector2.ZERO
	game.request_action("attack")
	if not await wait_phase("match_over", 15):
		return
	check(game.scores.get(game.local_id, 0) == 3, "guest receives final score")
	mark("guest_match_over")
	if not await wait_for("rematch_ready"):
		return
	check(game.phase == "countdown" and game.scores.get(game.local_id, -1) == 0, "rematch replicated with fresh score")
	mark("guest_rematch")
	if not await wait_for("host_left"):
		return
	if not await wait_phase("menu", 12):
		return
	check(game.players.is_empty(), "host disconnect returns guest to clean menu")
	mark("guest_disconnected")
