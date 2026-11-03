extends SceneTree

var game
var side: String
var folder: String
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", side, " / ", message)
	if not value:
		failures += 1

func mark(name: String, value: String = "ready") -> void:
	FileAccess.open(folder.path_join(name), FileAccess.WRITE).store_string(value)

func wait_for(name: String) -> bool:
	var deadline := Time.get_ticks_msec() + 16000
	while not FileAccess.file_exists(folder.path_join(name)):
		if Time.get_ticks_msec() > deadline:
			check(false, "timed out waiting for " + name)
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
	if side == "host":
		game.select_level("mountain")
		game.host_game(int(args[2]))
		mark("ready")
	else:
		if not await wait_for("ready"):
			quit(1)
			return
		game.select_level("yard")
		game.join_game("127.0.0.1", int(args[2]))
	var deadline := Time.get_ticks_msec() + 16000
	while game.phase != "playing" and Time.get_ticks_msec() < deadline:
		if game.phase == "lobby": game.set_ready(true)
		await physics_frame
	check(game.phase == "playing" and game.arena.map_id == "mountain", "host mountainside selection reaches both peers")
	if game.phase != "playing":
		quit(1)
		return
	var fingerprint: String = (str(game.arena.solids) + str(game.arena.concealment) + str(game.arena.bird_perches) + str(game.arena.Mountain.NESTS)).sha256_text()
	mark(side, fingerprint)
	if not await wait_for("guest" if side == "host" else "host"):
		quit(1)
		return
	check(FileAccess.get_file_as_string(folder.path_join("guest" if side == "host" else "host")) == fingerprint, "cover, perches and outlook coordinates are deterministic between peers")
	if side == "guest":
		Input.action_press("forward")
		await create_timer(0.8).timeout
		Input.action_release("forward")
		mark("moved")
		if await wait_for("birds"):
			await create_timer(0.3).timeout
			check(game.arena.birds.alarm_count >= 1, "mountainside bird cue replicates")
			check(game.arena.Mountain.sniper_allowed(Vector2(game.local_player().position.x, game.local_player().position.z)), "replicated sniper stays in the high contour")
		mark("done")
	else:
		if await wait_for("moved"):
			var sniper = game.players[game.guest_id]
			check(game.arena.Mountain.sniper_allowed(Vector2(sniper.position.x, sniper.position.z)) and sniper.position.y > 12, "host enforces the moving guest's high-ground region")
			game.announce_birds(0, Vector3.FORWARD)
			mark("birds")
			await wait_for("done")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("MOUNTAIN_PEER_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
