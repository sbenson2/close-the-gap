extends SceneTree

var game
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("forest")
	game.paused = true
	var sniper = game.players[2]
	var brain = game.bot_brains[2]
	brain.sense_clock = 1000
	var stationary := 0
	var in_bounds := true
	for tick in range(1200):
		brain.tick(1.0 / 60)
		sniper.simulate(1.0 / 60, sniper.command_move, sniper.command_flags, sniper.aim)
		await physics_frame
		in_bounds = in_bounds and game.arena.sniper_bounds().grow(0.01).has_point(Vector2(sniper.position.x, sniper.position.z))
		if tick >= 900 and Vector2(sniper.velocity.x, sniper.velocity.z).length() < 0.1:
			stationary += 1
	check(in_bounds, "hiding sniper stays on its permitted ridge")
	check(stationary >= 225, "sniper settles and holds a concealed watch instead of repeating a patrol")
	var blocked := 0
	for approach in [Vector3(-23, 0, -20), Vector3(23, 0, -20), Vector3(0, 0, 10)]:
		approach.y = game.arena.height_at(approach.x, approach.z) + 1.1
		var chest: Vector3 = sniper.position + Vector3.UP * 0.75
		var query := PhysicsRayQueryParameters3D.create(approach, chest, 1)
		if not sniper.get_world_3d().direct_space_state.intersect_ray(query).is_empty() or game.arena.foliage_hides(approach, chest):
			blocked += 1
	check(blocked >= 2, "held position conceals the sniper from multiple plausible approaches")
	var plan: Variant = brain.get("hide_plan")
	check(plan is Dictionary and plan.get("lanes", 0) > 0, "sniper selects a real hiding position with a verified firing peek")
	brain.hear_birds(Vector3(-20, 8, 3))
	brain.tick(0.1)
	check(not brain.visible and sniper.command_move.length() < 0.01, "bird clue directs a concealed watch without chasing it downhill")
	check(not brain.path.is_empty() or sniper.command_move.is_zero_approx(), "a completed hide has a stable movement fallback")
	var planning = game.bot_brains[1].tactics
	var ray_count: int = planning.ray_tests
	planning.route(Vector3(-20.038, 18, -42.82), Vector3(0, 18, -42),
		{"position": Vector3(0.272, 18, -37.012), "facing": Vector3(0.887, 0, -0.463), "confidence": 0.999}, "stalker")
	check(planning.ray_tests - ray_count <= 256, "a dense-forest route keeps expensive visibility work within one request's budget")
	game.start_bot_duel("yard")
	game.paused = true
	if not ResourceLoader.exists("res://scripts/bot_tactics.gd"):
		check(false, "tactical routing can choose a covered alternative to an exposed shortcut")
	else:
		# Two actual corridors: direct z=35 is exposed; a wall shelters z=40.
		game.arena.box(Vector3(5, 1.5, 37), Vector3(10, 3, 0.8), game.arena.concrete)
		var grid: AStarGrid2D = game.arena.nav
		grid.clear()
		grid.region = Rect2i(-2, 25, 15, 19)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		for x in range(0, 11):
			for z in range(36, 39):
				grid.set_point_solid(Vector2i(x, z))
		for tick in range(3):
			await physics_frame
		var tactics = load("res://scripts/bot_tactics.gd").new()
		tactics.setup(game.arena, game.players[1])
		var route: PackedVector2Array = tactics.route(Vector3(0, 0, 35), Vector3(10, 0, 35),
			{"position": Vector3(5, 0, 25), "facing": Vector3.BACK, "confidence": 1.0}, "stalker")
		var sheltered := false
		for point in route:
			sheltered = sheltered or point.y >= 39
		check(sheltered, "risk-aware route uses the sheltered corridor despite its extra distance")
		var ordinary: PackedVector2Array = grid.get_point_path(Vector2i(0, 35), Vector2i(10, 35))
		check(ordinary.size() == 11 and ordinary[5] == Vector2(5, 35), "private tactical costs do not alter shared map pathfinding")
		for step in range(1, 11):
			route = tactics.route(Vector3(0, 0, 35), Vector3(10, 0, 35),
				{"position": Vector3(5, 0, 25), "facing": Vector3.BACK, "confidence": 1.0 - step * 0.1}, "stalker")
		check(route.size() == 11 and route[5] == Vector2(5, 35), "gradually forgotten evidence stops affecting future routes")
	game.leave_game()
	game.select_level("forest")
	game.start_practice("sniper")
	game.paused = true
	for tick in range(3):
		await physics_frame
	var searching = game.bot_brains[2]
	var first: Vector3 = searching._search_perch()
	searching.searched[Vector2i(roundi(first.x), roundi(first.z))] = true
	var second: Vector3 = searching._search_perch()
	check(first.distance_to(second) > 0.5, "stalker searches distinct perches in fresh sniper practice without another bot initializing them")
	searching.actor.position = Vector3(-20, 18.05, -40)
	searching.patrol = 4
	searching.chosen_flank = true
	searching.visible = true
	searching.visual_age = 0
	searching.memory_age = 0
	searching.last_known = Vector3(0, 18, -36)
	searching.last_facing = Vector3.BACK
	searching.path_clock = 0
	searching._stalker(1.0 / 60, 20)
	check(searching.goal.distance_to(Vector3(0, 18, -37.5)) < 0.1, "stalker on the ridge adapts to an observed rear instead of finishing a stale flank waypoint")
	searching.searched.clear()
	for candidate in game.arena.bot_hides:
		searching.searched[Vector2i(roundi(candidate.hide.x), roundi(candidate.hide.z))] = true
	var unchecked: Dictionary = {}
	for candidate in game.arena.bot_cover:
		var key := Vector2i(roundi(candidate.hide.x), roundi(candidate.hide.z))
		if not searching.searched.has(key):
			unchecked[key] = true
	var next_perch: Vector3 = searching._search_perch()
	check(unchecked.has(Vector2i(roundi(next_perch.x), roundi(next_perch.z))), "after firing perches are checked the stalker searches other concealed observation spots")
	game.leave_game()
	game.select_level("yard")
	game.start_bot_duel()
	game.paused = true
	sniper = game.players[2]
	sniper.position = Vector3(0, 3.95, -32)
	game.arena.box(Vector3(0, 5.4, -37), Vector3(4, 3, 0.8), game.arena.concrete)
	for x in range(-2, 3):
		for z in range(-38, -35):
			game.arena.sniper_nav.set_point_solid(Vector2i(x, z))
	for tick in range(3):
		await physics_frame
	var cover_cache: Variant = game.arena.get("bot_cover")
	if cover_cache is Array:
		# An authored covered observation point, with no valid firing peek.
		game.arena.bot_hides.clear()
		cover_cache.clear()
		cover_cache.append({"hide": Vector3(0, 3.95, -39), "peek": Vector3(0, 3.95, -39), "concealment": 3, "lanes": 0,
			"watch": game.bot_brains[2].tactics._approaches()})
		var fallback: Dictionary = game.bot_brains[2].tactics.choose_hide(Vector3(0, 0, 10), Vector3(1000, 0, 1000))
		check(fallback.hide.distance_to(Vector3(0, 3.95, -39)) < 0.1, "when no firing hide qualifies the sniper chooses reachable covered observation space")
	else:
		check(false, "when no firing hide qualifies the sniper chooses reachable covered observation space")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("BOT_TACTICS_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
