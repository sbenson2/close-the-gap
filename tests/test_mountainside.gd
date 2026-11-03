extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	await physics_frame
	game.start_bot_duel("mountain")
	game.paused = true
	check(game.arena.map_id == "mountain", "mountainside is a selectable level")
	if game.arena.map_id != "mountain":
		quit(1)
		return
	var layout = load("res://scripts/mountainside.gd")
	check(layout.NESTS.size() == 7, "seven distinct elevated outlooks are present")
	var connected := true
	var stalker_routes := true
	var grades := true
	for nest in layout.NESTS:
		var target := Vector3(nest.x, nest.y, nest.z)
		var path = game.arena.path_to(game.arena.spawn_for("sniper"), target, "sniper")
		connected = connected and not path.is_empty() and path[-1].distance_to(Vector2(nest.x, nest.z)) < 1.5
		var approach = game.arena.path_to(game.arena.spawn_for("stalker"), target)
		print("OUTLOOK_PATH ", layout.NAMES[layout.NESTS.find(nest)], " sniper=", path.size(), " stalker=", approach.size(), " endpoint=", path[-1] if not path.is_empty() else Vector2.INF)
		stalker_routes = stalker_routes and not approach.is_empty() and approach[-1].distance_to(Vector2(nest.x, nest.z)) < 1.5
		for i in range(1, path.size()):
			var a: Vector2 = path[i - 1]
			var b: Vector2 = path[i]
			grades = grades and absf(game.arena.height_at(a.x, a.y) - game.arena.height_at(b.x, b.y)) / a.distance_to(b) < 0.85
	check(connected, "sniper can reach every outlook through the connected high contour")
	check(stalker_routes, "stalker can reach every outlook from the lower forest")
	check(grades, "all sniper routes respect the character's climbable grade")
	check(not layout.sniper_allowed(Vector2(0, 28)), "low drainage remains outside the sniper area")
	var clamped = game.arena.constrain_sniper(Vector3(0, 0, 28))
	check(layout.sniper_allowed(Vector2(clamped.x, clamped.z)), "sniper constraints return a valid high path")
	check(game.arena.height_at(-25, -5) - game.arena.height_at(0, -5) > 5, "cross-slope terrain contains a pronounced drainage")
	check(game.arena.tree_count > 150 and game.arena.foliage_count > 9000, "dense authored forest assets remain on the mountainside")
	check(game.arena.birds != null and game.arena.has_node("Wildlife"), "forest animals and bird alarms remain active")
	game.bot_brains[2].tactics.ensure_hides()
	check(game.arena.bot_hides.size() >= 7, "all outlooks supply covered firing plans")
	var covered_nests: Dictionary = {}
	for plan in game.arena.bot_hides:
		covered_nests[plan.nest] = true
	check(covered_nests.size() == 7, "each individual outlook has a qualified covered firing position")
	# Traverse actual collision, rather than treating a grid path as playability.
	var sniper = game.players[2]
	var traversed := true
	for index in [2, 1, 0, 6, 5, 4, 3]:
		var destination: Vector3 = layout.NESTS[index] + Vector3(0, 0, -1)
		var path = game.arena.path_to(sniper.position, destination, "sniper")
		for point in path:
			for frame in range(110):
				var offset := Vector2(point.x - sniper.position.x, point.y - sniper.position.z)
				if offset.length() < 0.55:
					break
				sniper.simulate(1.0 / 60, offset.normalized(), 4, Vector2.ZERO)
				await physics_frame
		var reached := Vector2(sniper.position.x, sniper.position.z).distance_to(Vector2(destination.x, destination.z)) < 1.4
		print("PHYSICAL_OUTLOOK ", index, " reached=", reached, " feet=", sniper.position)
		traversed = traversed and reached
		if not reached:
			break
	check(traversed, "crouched sniper physically traverses all seven outlooks and completes the contour loop")
	var climbs := true
	var stalker = game.players[1]
	for side in [-1.0, 1.0]:
		stalker.position = game.arena.spawn_for("stalker")
		stalker.velocity = Vector3.ZERO
		var route = layout.WEST if side < 0 else layout.EAST
		for destination in route.slice(1):
			var path = game.arena.path_to(stalker.position, destination)
			for point in path:
				for frame in range(110):
					var offset := Vector2(point.x - stalker.position.x, point.y - stalker.position.z)
					if offset.length() < 0.55:
						break
					stalker.simulate(1.0 / 60, offset.normalized(), 4, Vector2.ZERO)
					await physics_frame
		var target: Vector3 = route[-1]
		climbs = climbs and Vector2(stalker.position.x, stalker.position.z).distance_to(Vector2(target.x, target.z)) < 1.5 and stalker.position.y > 12
		print("PHYSICAL_FLANK ", side, " feet=", stalker.position)
	check(climbs, "stalker can crouch up both forest approaches to the high contour")
	stalker.position = game.arena.spawn_for("stalker")
	stalker.velocity = Vector3.ZERO
	var brain = game.bot_brains[1]
	for destination in layout.WEST.slice(1):
		for frame in range(1800):
			stalker.command_move = Vector2.ZERO
			stalker.command_flags = 4
			brain.path_clock -= 1.0 / 60
			brain._navigate(destination, 1.0 / 60)
			stalker.simulate(1.0 / 60, stalker.command_move, 4, Vector2.ZERO)
			await physics_frame
			if Vector2(stalker.position.x - destination.x, stalker.position.z - destination.z).length() < 0.8:
				break
	print("BOT_FLANK feet=", stalker.position)
	check(stalker.position.y >= 13.8 and stalker.position.z < 9, "actual exposure-aware bot navigation climbs the western approach without stalling")
	game.leave_game()
	game.queue_free()
	await process_frame
	print("MOUNTAINSIDE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
