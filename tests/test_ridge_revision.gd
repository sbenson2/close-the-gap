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

func blocked(game, from: Vector3, to: Vector3) -> bool:
	return not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("mountain")
	game.paused = true
	var nest: Vector3 = game.arena.Mountain.NESTS[6]
	var old_fingerprint := ""
	for revision in ["ridge_v1", "ridge_v2"]:
		game.arena.map_revision = revision
		game.arena.load_level("mountain")
		await physics_frame
		await physics_frame
		var from: Vector3 = nest + Vector3(0, 1.4, 0)
		var to: Vector3 = nest + Vector3(-6, 1.4, 0)
		if revision == "ridge_v1":
			old_fingerprint = str(game.arena.solids)
			check(not blocked(game, from, to), "legacy Moss spur retains its original open western shoulder")
		else:
			check(blocked(game, from, to), "new Moss spur blocks cross-map observation through its western rock shoulder")
			check(str(game.arena.solids) != old_fingerprint, "new cover is physically distinct and cannot silently replace old replay terrain")
			check(not blocked(game, from, nest + Vector3(0, 1.4, -2)), "Moss spur keeps a usable rear exit")
	game.start_replay("res://replays/mountain-session.json")
	check(game.arena.map_revision == "ridge_v1", "old recording selects old terrain automatically")
	game.start_bot_duel("mountain")
	check(game.arena.map_revision == "ridge_v3", "new game restores the current terrain after a legacy replay")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("RIDGE_REVISION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
