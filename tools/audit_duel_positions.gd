extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("mountain")
	game.paused = true
	var targets: Array = []
	for route in [game.arena.Mountain.WEST, game.arena.Mountain.EAST]:
		for leg in range(1, route.size()):
			for fraction in [0.2, 0.4, 0.6, 0.8]:
				var point: Vector3 = route[leg - 1].lerp(route[leg], fraction)
				targets.append(Vector3(point.x, game.arena.height_at(point.x, point.z) + 1.08, point.z))
	for x in [-12, 0, 12]:
		targets.append(Vector3(x, game.arena.height_at(x, 4) + 1.08, 4))
	var report: Dictionary = {"targets": [], "revisions": {}}
	for point in targets:
		report.targets.append([point.x, point.y, point.z])
	for revision in ["ridge_v1", "ridge_v2"]:
		game.arena.map_revision = revision
		game.arena.load_level("mountain")
		await physics_frame
		await physics_frame
		game.bot_brains[2].tactics.ensure_hides()
		var rows: Array = []
		for index in range(7):
			var nest: Vector3 = game.arena.Mountain.NESTS[index]
			var visible: Array = []
			for target in targets:
				var seen := false
				for plan in game.arena.bot_hides:
					if plan.nest != index: continue
					var from: Vector3 = plan.peek + Vector3.UP * 1.62
					var ray := PhysicsRayQueryParameters3D.create(from, target, 1)
					seen = seen or (game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and not game.arena.foliage_hides(from, target))
				visible.append(seen)
			rows.append({"name": game.arena.Mountain.NAMES[index], "visible": visible, "lanes": visible.count(true)})
		report.revisions[revision] = rows
	FileAccess.open("res://artifacts/design-slice/sightlines.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("POSITION_AUDIT ", JSON.stringify(report.revisions))
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	quit()
