extends RefCounted

# Metres. Heights and paths are shared by geometry, constraints and navigation.
const NESTS := [Vector3(-25, 14, 8), Vector3(-25, 22, -15), Vector3(-13, 29, -34), Vector3(5, 25, -30), Vector3(24, 27, -26), Vector3(25, 19, -3), Vector3(15, 13, 14)]
const NAMES := ["Fern blind", "Split-pine lookout", "Crown nest", "Saddle hide", "East crag", "Hunter's stand", "Moss spur"]
const EDGES := [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(1, 3), Vector2i(0, 6)]
const WEST := [Vector3(-8, 1, 38), Vector3(-23, 5, 28), Vector3(-30, 10, 19), Vector3(-25, 14, 8)]
const EAST := [Vector3(-8, 1, 38), Vector3(9, 3, 30), Vector3(21, 9.5, 24), Vector3(15, 13, 14)]
const SPAWN := Vector3(-8, 1.1, 38)
const VIEWS := [Vector3(-20, 5, 27), Vector3(-17, 8, 0), Vector3(-8, 10, 5), Vector3(0, 7, 12), Vector3(16, 10, -8), Vector3(16, 6, 22), Vector3(0, 1, 30)]

static func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

static func _segment(point: Vector2, a: Vector3, b: Vector3) -> Vector2:
	var start := _flat(a)
	var offset := _flat(b) - start
	var t := clampf((point - start).dot(offset) / offset.length_squared(), 0, 1)
	# Reserve level ground at overlooks, then grade the remaining distance.
	# Blending a flat disk into an already sloping path creates steep lips.
	var start_pad := 4.8 if NESTS.has(a) else 0.0
	var end_pad := 4.8 if NESTS.has(b) else 0.0
	var rise := clampf((t * offset.length() - start_pad) / maxf(1, offset.length() - start_pad - end_pad), 0, 1)
	return Vector2(point.distance_to(start + offset * t), lerpf(a.y, b.y, rise))

static func path_sample(point: Vector2, high_only: bool = false) -> Vector2:
	var best := Vector2(INF, 0)
	for edge in EDGES:
		var sample := _segment(point, NESTS[edge.x], NESTS[edge.y])
		if sample.x < best.x:
			best = sample
	if not high_only:
		for route in [WEST, EAST]:
			for i in range(1, route.size()):
				var sample := _segment(point, route[i - 1], route[i])
				if sample.x < best.x:
					best = sample
	return best

static func height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var west := 8.0 * exp(-pow((x + 25) / 12, 2)) * exp(-pow((z + 8) / 42, 2))
	var east := 7.0 * exp(-pow((x - 25) / 12, 2)) * exp(-pow((z + 6) / 40, 2))
	var drainage := 4.5 * exp(-pow((x - sin(z * 0.065) * 3) / 8, 2)) * exp(-pow((z - 4) / 30, 2))
	var result := maxf(0.3, (38 - z) * 0.28 + west + east - drainage + sin(x * 0.17) * sin(z * 0.13) * 0.65)
	# Distant land continues the ridge; it is not a row of enlarged boulders.
	var outside := maxf(absf(x) - 34, maxf(-44 - z, z - 44))
	if outside > 0:
		var peaks := 54 * exp(-pow((z + 135) / 52, 2)) * (0.55 + 0.45 * pow(sin(x * 0.038 + 1.8), 2))
		peaks += 30 * exp(-pow((x + 110) / 44, 2)) * exp(-pow((z + 65) / 80, 2))
		peaks += 3 * sin(x * 0.13) * cos(z * 0.09)
		result += peaks * smoothstep(0, 25, outside)
	var sample := path_sample(point)
	result = lerpf(result, sample.y, 1 - smoothstep(2.3, 5.2, sample.x))
	for nest in NESTS:
		result = lerpf(result, nest.y, 1 - smoothstep(4.0, 4.8, point.distance_to(_flat(nest))))
	return result

static func sniper_allowed(point: Vector2) -> bool:
	if path_sample(point, true).x <= 2.15:
		return true
	for nest in NESTS:
		if point.distance_to(_flat(nest)) <= 4.1:
			return true
	return false

static func constrain(point: Vector3) -> Vector3:
	var flat := _flat(point)
	if not sniper_allowed(flat):
		var best := Vector2.ZERO
		var distance := INF
		for edge in EDGES:
			var a := _flat(NESTS[edge.x])
			var offset := _flat(NESTS[edge.y]) - a
			var center := a + offset * clampf((flat - a).dot(offset) / offset.length_squared(), 0, 1)
			var candidate := center + (flat - center).limit_length(2.05)
			if candidate.distance_squared_to(flat) < distance:
				distance = candidate.distance_squared_to(flat)
				best = candidate
		for nest in NESTS:
			var candidate := _flat(nest) + (flat - _flat(nest)).limit_length(4.0)
			if candidate.distance_squared_to(flat) < distance:
				distance = candidate.distance_squared_to(flat)
				best = candidate
		point.x = best.x
		point.z = best.y
	point.y = maxf(point.y, height(point.x, point.z))
	return point

static func clear_route(point: Vector3, padding: float) -> bool:
	if path_sample(_flat(point)).x < maxf(padding, 2.5):
		return true
	for nest in NESTS:
		if _flat(point).distance_to(_flat(nest)) < 5.5:
			return true
	return false

static func flank(side: float) -> Array:
	return WEST.slice(1) + [NESTS[1], NESTS[2], NESTS[3]] if side < 0 else EAST.slice(1) + [NESTS[5], NESTS[4], NESTS[3]]

static func nearest_nest(point: Vector3) -> int:
	var best := 0
	for i in range(1, NESTS.size()):
		if _flat(point).distance_squared_to(_flat(NESTS[i])) < _flat(point).distance_squared_to(_flat(NESTS[best])):
			best = i
	return best

static func tree_blocks_view(point: Vector3) -> bool:
	for i in range(NESTS.size()):
		var sample := _segment(_flat(point), NESTS[i], VIEWS[i])
		if sample.x < 4.7:
			return true
	return false
