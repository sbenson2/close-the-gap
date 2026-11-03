extends SceneTree

var game
var side: String
var folder: String
var force_relay: bool = false
var wrong_secret: bool = false
var wrong_certificate: bool = false
var failures: int = 0
var checks: int = 0
var close_tree := false
var deadline: int

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL [%s]: %s" % [side, message])
	else:
		print("PASS [%s]: %s" % [side, message])

func mark(name: String, contents: String = "ready") -> void:
	var file := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func until(condition: Callable, label_text: String, seconds: float = 30.0) -> bool:
	var limit := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call():
		if game and game.phase == "lobby": game.set_ready(true)
		if Time.get_ticks_msec() >= limit:
			check(false, label_text + " timed out (phase=" + game.phase + ", connection=" + game.friends.state + ")")
			return false
		await process_frame
	return true

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	side = args[0]
	folder = args[1]
	force_relay = args[2] == "relay"
	wrong_secret = args.size() > 6 and args[6] == "wrong-secret"
	wrong_certificate = args.size() > 6 and args[6] == "wrong-certificate"
	close_tree = args.size() > 7 and args[7] == "close-tree"
	deadline = Time.get_ticks_msec() + 55000
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline:
		printerr("FAIL: friend test exceeded bounded deadline")
		quit(1)
	return false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await process_frame
	game.friends.force_relay = force_relay
	var args := OS.get_cmdline_user_args()
	if args.size() >= 6:
		game.friends.service_host = args[3]
		game.friends.service_port = int(args[4])
		game.friends.service_registrar = int(args[5])
	if side == "host":
		# This fixture's firing coordinates and assertion describe Pine Hollow.
		game.select_level("forest")
		game.host_friend_game()
		if await until(func(): return not game.friends.invite.is_empty(), "host invite"):
			var invite: String = game.friends.invite
			check(invite.begins_with("CTG1:"), "host generates a private expiring invite")
			mark("invite", invite)
			if wrong_secret or wrong_certificate:
				if await until(func(): return FileAccess.file_exists(folder.path_join("rejected")), "unauthorized rejection", 20):
					check(game.phase == "waiting" and game.players.is_empty(), "uninvited peer cannot start or access gameplay")
					mark("rejection_checked")
			if await until(func(): return game.phase == "playing", "authenticated match"):
				check(game.players.size() == 2 and game.friends.auth.accepted, "only an authenticated friend starts the match")
				check(game.multiplayer.refuse_new_connections, "match is locked to its invited second player")
				check(game.friends.invite.is_empty(), "invite is removed from active lobby after joining")
				if close_tree:
					await until(func(): return FileAccess.file_exists(folder.path_join("guest_connected")), "guest connected")
					game.queue_free()
					await create_timer(0.2).timeout
					game = null
					print("FRIEND_RESULT host checks=%d failures=%d" % [checks, failures])
					quit(1 if failures else 0)
					return
				if await until(func(): return FileAccess.file_exists(folder.path_join("guest_moved")), "guest movement"):
					check(game.players[game.guest_id].position.z > -35, "encrypted session carries authoritative movement")
					game.players[1].position = Vector3(0, 18.05, -33)
					game.players[game.guest_id].position = Vector3(0, 18.05, -39)
					await create_timer(0.5).timeout
					mark("rifle_ready")
					if await until(func(): return game.phase == "round_over", "encrypted rifle result"):
						check(game.scores[game.guest_id] == 1, "encrypted RPCs resolve combat and score")
						mark("host_done")
						await until(func(): return FileAccess.file_exists(folder.path_join("guest_done")), "guest completion")
						game.leave_game()
						await until(func(): return FileAccess.file_exists(folder.path_join("guest_left")), "disconnect cleanup", 12)
	else:
		if await until(func(): return FileAccess.file_exists(folder.path_join("invite")), "private invite"):
			var invite := FileAccess.get_file_as_string(folder.path_join("invite"))
			if wrong_secret or wrong_certificate:
				var codec = load("res://scripts/network/invite.gd")
				var data: Dictionary = codec.decode(invite)
				var cert: X509Certificate = data.certificate
				var secret: PackedByteArray = data.secret
				if wrong_secret:
					secret = Crypto.new().generate_random_bytes(32)
				else:
					var crypto := Crypto.new()
					cert = crypto.generate_self_signed_certificate(crypto.generate_rsa(2048), "CN=close-the-gap.test,O=CloseTheGap,C=US")
				var invalid: String = codec.encode(data.oid, cert, secret, data.expires)
				game.join_friend_game(invalid)
				if not await until(func(): return game.phase == "menu" and game.ui.menu_root.visible, "incorrect secret rejected", 18):
					game.queue_free()
					await process_frame
					quit(1)
					return
				check(game.players.is_empty() and game.friends.state == "idle", "tampered private invite is rejected before gameplay")
				mark("rejected")
				await until(func(): return FileAccess.file_exists(folder.path_join("rejection_checked")), "host rejects unauthorized peer")
			game.join_friend_game(invite)
			if await until(func(): return game.phase == "playing", "authenticated match"):
				check(game.friends.auth.accepted and game.local_id != 1, "guest verifies host and invite before gameplay")
				check(game.friends.route == "relay" if force_relay or args[2] == "fallback" else true, "requested encrypted relay path is used")
				if args[2] == "direct":
					check(game.friends.route == "direct", "direct encrypted P2P path works without a relay")
				print("FRIEND_ROUTE " + game.friends.route)
				if close_tree:
					mark("guest_connected")
					if await until(func(): return game.phase == "menu", "host application close", 12):
						check(game.players.is_empty() and game.friends.state == "idle", "host application close releases the guest session")
					game.queue_free()
					await process_frame
					print("FRIEND_RESULT guest checks=%d failures=%d" % [checks, failures])
					quit(1 if failures else 0)
					return
				check(game.arena.map_id == "forest", "selected map replicates through friend connection")
				Input.action_press("forward")
				await create_timer(0.7).timeout
				Input.action_release("forward")
				mark("guest_moved")
				if await until(func(): return FileAccess.file_exists(folder.path_join("rifle_ready")), "rifle setup"):
					game.local_player().aim = Vector2(PI, 0)
					game.request_action("attack")
					if await until(func(): return FileAccess.file_exists(folder.path_join("host_done")), "host score"):
						await until(func(): return game.phase == "round_over", "guest score replication")
						check(game.scores.get(game.local_id, 0) == 1, "guest receives authoritative score")
						mark("guest_done")
						if await until(func(): return game.phase == "menu", "host disconnect", 12):
							check(game.players.is_empty() and game.friends.state == "idle", "disconnect clears private session resources")
							mark("guest_left")
	print("FRIEND_RESULT %s checks=%d failures=%d" % [side, checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
