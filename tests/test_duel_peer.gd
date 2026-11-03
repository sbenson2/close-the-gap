extends SceneTree

var game
var side: String
var folder: String
var checks := 0
var failures := 0
var impacts := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", side, " / ", message)

func mark(key: String) -> void:
	FileAccess.open(folder.path_join(key), FileAccess.WRITE).store_string("ready")

func wait_for(key: String) -> bool:
	var deadline := Time.get_ticks_msec() + 14000
	while not FileAccess.file_exists(folder.path_join(key)):
		if game and game.phase == "lobby": game.set_ready(true)
		if Time.get_ticks_msec() >= deadline:
			check(false, "timed out waiting for " + key)
			return false
		await create_timer(0.05).timeout
	return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	side = args[0]
	folder = args[1]
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.gameplay_event.connect(func(kind, _values):
		if kind == "pebble_impact": impacts += 1)
	if side == "host":
		game.select_level("yard")
		game.host_game(int(args[2]))
		mark("ready")
	else:
		game.selected_ruleset = "classic_v1"
		if not await wait_for("ready"):
			quit(1)
			return
		game.join_game("127.0.0.1", int(args[2]))
	var deadline := Time.get_ticks_msec() + 14000
	while game.phase != "playing" and Time.get_ticks_msec() < deadline:
		if game.phase == "lobby": game.set_ready(true)
		await physics_frame
	check(game.phase == "playing" and game.ruleset_id == "duel_v2", "host's new ruleset reaches both peers")
	if game.phase != "playing":
		quit(1)
		return
	if side == "guest":
		game.local_player().aim = Vector2(0, 1.2)
		game.request_action("attack")
		await create_timer(0.35).timeout
		check(game.local_player().rifle_ammo == 2, "guest receives authoritative rifle ammunition after firing")
		game.request_action("reload")
		await create_timer(0.2).timeout
		check(game.local_player().reload_remaining > 2, "guest reload is replicated as committed weapon state")
		game.request_action("attack")
		await create_timer(3.0).timeout
		check(game.local_player().rifle_ammo == 3 and game.local_player().rifle_reserve == 8, "reload cannot duplicate rounds or permit an extra shot")
		mark("reloaded")
		if await wait_for("swapped"):
			await create_timer(0.3).timeout
			check(game.local_player().role == "stalker", "role swap gives the guest the stalker kit")
			game.local_player().aim = Vector2(0, 0.4)
			game.request_action("pebble")
			await create_timer(4.5).timeout
			check(game.local_player().pebbles == 2 and impacts == 1, "guest distraction spends one item and replicates one physical impact")
			mark("thrown")
		if await wait_for("drawn"):
			await create_timer(0.3).timeout
			check(game.phase == "match_over" and game.winner_id == 0 and game.set_winner() == 1, "draw ends the role pair and preserves its actual set winner")
			mark("checked")
		if await wait_for("rematch"):
			game.set_ready(true)
			var ready_deadline := Time.get_ticks_msec() + 5000
			while game.phase == "lobby" and Time.get_ticks_msec() < ready_deadline: await physics_frame
			await create_timer(0.3).timeout
			check(game.phase == "countdown" and game.scores.get(1) == 0 and game.local_player().rifle_ammo == 3, "rematch replicates fresh scores and finite equipment")
		mark("done")
	else:
		if await wait_for("reloaded"):
			var other = game.players[game.guest_id]
			check(other.rifle_ammo == 3 and other.rifle_reserve == 8, "host owns remote ammunition and reload outcome")
			game.end_round(1, "Network fixture elimination")
			game.transition_time = 0.01
			await create_timer(3.4).timeout
			mark("swapped")
		if await wait_for("thrown"):
			check(impacts == 1 and game.players[game.guest_id].pebbles == 2, "host resolves the remote projectile once")
			game.round_time = 0.01
			await create_timer(0.2).timeout
			check(game.phase == "match_over" and game.scores[1] == 1 and game.scores[game.guest_id] == 0, "timeout creates no phantom score or third defender round")
			mark("drawn")
		if await wait_for("checked"):
			game.rematch()
			mark("rematch")
		await wait_for("done")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("DUEL_PEER_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
