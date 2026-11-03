extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_bot_duel("mountain")
	game.paused = true
	await physics_frame
	var data := {"cells": [], "nests": [], "names": game.arena.Mountain.NAMES, "edges": [], "flanks": []}
	for z in range(-44, 45):
		for x in range(-34, 35):
			var cell := Vector2i(x, z)
			var s = game.arena.sniper_nav
			data.cells.append([x, z, game.arena.height_at(x, z), game.arena.nav.is_point_solid(cell), s.is_point_solid(cell) if s.region.has_point(cell) else true, game.arena.mountain_walkable(Vector2(x, z))])
	for nest in game.arena.Mountain.NESTS:
		data.nests.append([nest.x, nest.y, nest.z])
	for edge in game.arena.Mountain.EDGES:
		data.edges.append([edge.x, edge.y])
	for route in [game.arena.Mountain.WEST, game.arena.Mountain.EAST]:
		var points: Array = []
		for point in route:
			points.append([point.x, point.y, point.z])
		data.flanks.append(points)
	FileAccess.open("res://artifacts/mountainside/nav-audit.json", FileAccess.WRITE).store_string(JSON.stringify(data))
	game.queue_free()
	await process_frame
	quit()
