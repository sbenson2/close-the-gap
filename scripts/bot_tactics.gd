extends RefCounted

const Mountain = preload("res://scripts/mountainside.gd")

# Receives static map geometry and observed estimates; never an enemy actor.
var arena: Node3D
var actor: CharacterBody3D
var grids: Dictionary = {}
var ray_tests := 0
var route_ms := 0.0
var route_count := 0
var max_route_ms := 0.0
var slowest_route: Dictionary = {}

class RiskGrid extends AStarGrid2D:
	var arena: Node3D
	var space: PhysicsDirectSpaceState3D
	var threat := Vector3.ZERO
	var facing := Vector3.BACK
	var confidence := 0.0
	var strength := 22.0
	var costs: Dictionary = {}
	var rough_costs: Dictionary = {}
	var rays := 0
	var ray_budget := 256

	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		if rough_costs.has(to_id):
			return Vector2(from_id).distance_to(Vector2(to_id)) * float(rough_costs[to_id])
		if not costs.has(to_id):
			var point := Vector3(to_id.x, arena.height_at(to_id.x, to_id.y) + 0.8, to_id.y)
			var risk := 0.0
			if confidence > 0.01:
				var offset := point - threat
				var flat := Vector3(offset.x, 0, offset.z).normalized()
				var exposure := 0.4 + 0.6 * maxf(0, facing.dot(flat))
				if ray_budget <= 0:
					# Conservative unknown costs are query-local, so later plans can
					# refine them without a single frame tracing the whole map.
					rough_costs[to_id] = 1.0 + strength * confidence * exposure
					return Vector2(from_id).distance_to(Vector2(to_id)) * float(rough_costs[to_id])
				ray_budget -= 1
				var query := PhysicsRayQueryParameters3D.create(threat, point, 1)
				rays += 1
				if space.intersect_ray(query).is_empty() and not arena.foliage_hides(threat, point):
					risk = strength * confidence * exposure
			costs[to_id] = 1.0 + risk
		return Vector2(from_id).distance_to(Vector2(to_id)) * float(costs[to_id])

func setup(level: Node3D, subject: CharacterBody3D) -> void:
	arena = level
	actor = subject

func route(from: Vector3, to: Vector3, knowledge: Dictionary, role: String) -> PackedVector2Array:
	var started := Time.get_ticks_usec()
	var source: AStarGrid2D = arena.sniper_nav if role == "sniper" else arena.nav
	if not grids.has(role):
		var copy := RiskGrid.new()
		copy.arena = arena
		copy.space = actor.get_world_3d().direct_space_state
		copy.region = source.region
		copy.cell_size = source.cell_size
		copy.diagonal_mode = source.diagonal_mode
		copy.update()
		for x in range(source.region.position.x, source.region.end.x):
			for z in range(source.region.position.y, source.region.end.y):
				var cell := Vector2i(x, z)
				if source.is_point_solid(cell):
					copy.set_point_solid(cell)
		grids[role] = copy
	var grid: RiskGrid = grids[role]
	grid.ray_budget = 256
	grid.rough_costs.clear()
	var reference: Vector3 = knowledge.get("position", actor.position) + Vector3.UP * 1.3
	var direction: Vector3 = knowledge.get("facing", Vector3.BACK)
	var certainty: float = knowledge.get("confidence", 0.0)
	if grid.threat.distance_to(reference) > 2 or grid.facing.dot(direction) < 0.8 or absf(grid.confidence - certainty) > 0.15:
		grid.costs.clear()
		grid.threat = reference
		grid.facing = direction
		grid.confidence = certainty
	grid.strength = 4.0 if actor.role == "sniper" else 22.0
	if role == "sniper":
		from = arena.constrain_sniper(from)
		to = arena.constrain_sniper(to)
	var a := Vector2i(roundi(from.x), roundi(from.z)).clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	var b := Vector2i(roundi(to.x), roundi(to.z)).clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	a = arena._free_cell(grid, a)
	b = arena._free_cell(grid, b)
	var result := PackedVector2Array()
	if not grid.is_point_solid(a) and not grid.is_point_solid(b):
		result = grid.get_point_path(a, b)
	ray_tests += grid.rays
	grid.rays = 0
	var duration := (Time.get_ticks_usec() - started) / 1000.0
	route_ms += duration
	max_route_ms = maxf(max_route_ms, duration)
	if slowest_route.is_empty() or duration > float(slowest_route.ms):
		slowest_route = {"ms": duration, "from": [from.x, from.y, from.z], "to": [to.x, to.y, to.z],
			"reference": [reference.x, reference.y, reference.z], "facing": [direction.x, direction.y, direction.z],
			"confidence": certainty, "role": role, "cells": grid.costs.size()}
	route_count += 1
	return result

func blocked(from: Vector3, to: Vector3) -> bool:
	ray_tests += 1
	return not actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty() or arena.foliage_hides(from, to)

func route_score(points: PackedVector2Array, role: String) -> float:
	if points.is_empty():
		return INF
	var grid: RiskGrid = grids[role]
	var total := 0.0
	for i in range(1, points.size()):
		total += grid._compute_cost(Vector2i(points[i - 1]), Vector2i(points[i]))
	return total

func _free(point: Vector3) -> bool:
	var cell := Vector2i(roundi(point.x), roundi(point.z))
	if not arena.sniper_nav.region.has_point(cell) or arena.sniper_nav.is_point_solid(cell):
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.72)
	query.collision_mask = 1
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _approaches() -> Array[Vector3]:
	var result: Array[Vector3] = [Vector3(-23, 0, -20), Vector3(23, 0, -20), Vector3(0, 0, 10)]
	if arena.map_id == "mountain":
		result = [Vector3(-20, 0, 25), Vector3(18, 0, 24), Vector3(0, 0, 5)]
	for i in range(result.size()):
		result[i].y = arena.height_at(result[i].x, result[i].z) + 1.1
	return result

func _build_hides() -> void:
	if arena.map_id == "mountain":
		_build_mountain_hides()
		return
	var bounds: Rect2 = arena.sniper_bounds()
	var approaches := _approaches()
	# The ridge's central component also overlooks its near/rear entrances.
	# A distant valley ray alone rejects useful, reachable ambush positions.
	var lane_points: Array[Vector3] = approaches.duplicate()
	for point in [Vector3(-6, 0, -40), Vector3(6, 0, -40), Vector3(0, 0, -31)]:
		point.y = arena.height_at(point.x, point.z) + 1.1
		lane_points.append(point)
	var stride := 4 if arena.map_id == "forest" else 2
	for x in range(ceili(bounds.position.x) + 1, ceili(bounds.end.x), stride):
		for z in range(ceili(bounds.position.y) + 1, ceili(bounds.end.y), 2):
			var hide := Vector3(x, arena.height_at(x, z) + 0.04, z)
			if not _free(hide):
				continue
			var conceal := 0
			for approach in approaches:
				if blocked(approach, hide + Vector3.UP * 0.75):
					conceal += 1
			if conceal < 2:
				continue
			arena.bot_cover.append({"hide": hide, "peek": hide, "concealment": conceal, "lanes": 0, "watch": approaches})
			var best: Dictionary = {}
			for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]:
				var peek: Vector3 = hide + direction * 2.0
				if not bounds.grow(-0.15).has_point(Vector2(peek.x, peek.z)) or not _free(peek):
					continue
				var connection: PackedVector2Array = arena.path_to(hide, peek, "sniper")
				if connection.is_empty() or connection.size() > 7:
					continue
				var views: Array[Vector3] = []
				for approach in lane_points:
					if not blocked(peek + Vector3.UP * 1.62, approach):
						views.append(approach)
				if not views.is_empty() and (best.is_empty() or views.size() > best.lanes):
					best = {"hide": hide, "peek": peek, "concealment": conceal, "lanes": views.size(), "watch": views}
			if not best.is_empty():
				arena.bot_hides.append(best)

func _build_mountain_hides() -> void:
	var approaches := _approaches()
	for i in range(Mountain.NESTS.size()):
		var nest: Vector3 = Mountain.NESTS[i]
		var hide := nest + Vector3(0, 0.16, -1.0)
		if not _free(hide):
			continue
		var lanes: Array[Vector3] = approaches.duplicate()
		var vista: Vector3 = Mountain.VIEWS[i]
		vista.y = arena.height_at(vista.x, vista.z) + 1.1
		lanes.append(vista)
		# Local exposed crossings supplement valley views at the rear overlooks.
		for edge in Mountain.EDGES:
			if edge.x == i or edge.y == i:
				var crossing: Vector3 = nest.lerp(Mountain.NESTS[edge.y if edge.x == i else edge.x], 0.55)
				crossing.y = arena.height_at(crossing.x, crossing.z) + 1.1
				lanes.append(crossing)
		var conceal := 0
		for approach in approaches:
			if blocked(approach, hide + Vector3.UP * 0.75):
				conceal += 1
		var cover := {"hide": hide, "peek": hide, "concealment": conceal, "lanes": 0, "watch": lanes, "nest": i}
		arena.bot_cover.append(cover)
		for offset in [Vector3(2.8, 0, -0.5), Vector3(-2.8, 0, -0.5), Vector3(0, 0, 2.5)]:
			var peek: Vector3 = nest + offset
			peek.y = arena.height_at(peek.x, peek.z) + 0.16
			if not _free(peek) or arena.path_to(hide, peek, "sniper").is_empty():
				continue
			var views: Array[Vector3] = []
			for lane in lanes:
				if not blocked(peek + Vector3.UP * 1.62, lane):
					views.append(lane)
			if not views.is_empty() and conceal >= 2:
				arena.bot_hides.append({"hide": hide, "peek": peek, "concealment": conceal, "lanes": views.size(), "watch": views, "nest": i})

func ensure_hides() -> void:
	if arena.bot_hides.is_empty() and arena.bot_cover.is_empty():
		_build_hides()

func choose_hide(threat: Vector3, previous: Vector3, variation: float = 0.0) -> Dictionary:
	ensure_hides()
	var best: Dictionary = {}
	var best_score := -INF
	for pool in [arena.bot_hides, arena.bot_cover]:
		for candidate in pool:
			var hide: Vector3 = candidate.hide
			var path: PackedVector2Array = arena.path_to(actor.position, hide, "sniper")
			if path.is_empty():
				continue
			var score: float = candidate.concealment * 6 + candidate.lanes * 2 - path.size() * 0.18
			if previous.distance_to(hide) < 3:
				score -= 8
			if arena.map_id == "mountain" and previous.length() < 100 and Mountain.nearest_nest(previous) == Mountain.nearest_nest(hide):
				score -= 24
			if threat != Vector3.ZERO:
				score += minf(12, hide.distance_to(threat)) * 0.2
				score += 4.0 if blocked(threat + Vector3.UP, hide + Vector3.UP * 0.75) else -4.0
			# Stable seed-dependent variety, with no dependence on hidden actors.
			score += sin(hide.x * 1.7 + hide.z * 0.8 + variation) * 1.3
			if score > best_score:
				best_score = score
				best = candidate.duplicate()
		if not best.is_empty():
			break
	if best.is_empty():
		var fallback: Vector3 = arena.constrain_sniper(actor.position)
		best = {"hide": fallback, "peek": fallback, "concealment": 0, "lanes": 0, "watch": _approaches()}
	best.score = best_score if is_finite(best_score) else 0.0
	return best
