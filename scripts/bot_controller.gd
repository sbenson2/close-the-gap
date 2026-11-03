extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const Tactics = preload("res://scripts/bot_tactics.gd")
const Senses = preload("res://scripts/bot_senses.gd")
var arena: Node3D
var request_attack: Callable
var senses: RefCounted
var actor: CharacterBody3D
var rng := RandomNumberGenerator.new()
var state: String = "Searching"
var visible: bool = false
var sense_clock: float = 0.0
var memory_age: float = 100.0
var last_known := Vector3.ZERO
var last_aim_point := Vector3.ZERO
var last_velocity := Vector3.ZERO
var last_facing := Vector3.BACK
var reaction: float = 0.0
var elapsed: float = 0.0
var path_clock: float = 0.0
var path := PackedVector2Array()
var waypoint: int = 1
var patrol: int = 0
var flank: float = 1.0
var goal := Vector3.ZERO
var cover_time: float = 0.0
var cover_goal := Vector3.ZERO
var previous_health: int = 100
var stuck_time: float = 0.0
var previous_position := Vector3.ZERO
var shots: int = 0
var sightings: int = 0
var path_queries: int = 0
var bird_memory: float = 0.0
var visual_age: float = 100.0
var cue_age: float = 100.0
var cue_source: String = "none"
var cue_position := Vector3.ZERO
var cue_radius: float = 0.0
var tactics: RefCounted
var hide_plan: Dictionary = {}
var hide_until := 0.0
var peek_until := 0.0
var next_peek := 0.0
var attention := Vector3.ZERO
var chosen_flank := false
var searched: Dictionary = {}
var search_goal := Vector3.ZERO
var search_until := 0.0
var crossing_until := 0.0
var crossing_ready := 0.0
var next_distraction := 10.0
var relay_positions: Array = []
var relay_known: Dictionary = {}
var relay_mode := false
var deployed_utility := false
var own_decoy := Vector3.INF
var own_trail: Array[Vector3] = []
var own_trail_clock := 0.0

func setup(owner_game: Node3D, subject: CharacterBody3D, seed_value: int) -> void:
	arena = owner_game.arena
	request_attack = owner_game._resolve_action
	relay_mode = owner_game.ruleset_id == Rules.RELAY
	if relay_mode: relay_positions = owner_game.relay.positions.duplicate()
	actor = subject
	senses = Senses.new()
	senses.setup(owner_game, actor, seed_value)
	rng.seed = seed_value
	flank = -1.0 if rng.randf() < 0.5 else 1.0
	if absf(actor.position.x) > 5:
		flank = signf(actor.position.x)
	previous_position = actor.position
	goal = actor.position
	sense_clock = rng.randf_range(0, 0.12)
	tactics = Tactics.new()
	tactics.setup(arena, actor)

func tick(delta: float) -> void:
	if not actor.alive:
		return
	senses.advance(delta)
	elapsed += delta
	own_trail_clock -= delta
	if own_trail_clock <= 0:
		own_trail_clock = 0.6
		own_trail.append(actor.position)
		if own_trail.size() > 48: own_trail.pop_front()
	memory_age += delta
	visual_age += delta
	cue_age += delta
	reaction = maxf(0, reaction - delta)
	cover_time = maxf(0, cover_time - delta)
	bird_memory = maxf(0, bird_memory - delta)
	sense_clock -= delta
	path_clock -= delta
	actor.command_move = Vector2.ZERO
	actor.command_flags = 0
	if sense_clock <= 0:
		sense_clock = 0.12 + rng.randf_range(0, 0.04)
		_observe()
		if relay_mode:
			for observation in senses.relay.visible_stations(actor): relay_known[int(observation[0])] = int(observation[1])
	if actor.health < previous_health:
		cover_time = 1.3
		cover_goal = _find_cover()
	previous_health = actor.health
	if actor.reload_remaining > 0:
		state = "Reloading in cover"
		_navigate(cover_goal, delta)
		_look(delta)
		return
	if (actor.active_weapon == "handgun" and actor.handgun_ammo <= 0) or (actor.active_weapon == "rifle" and Rules.modern(actor.game.ruleset_id) and actor.rifle_ammo <= 0):
		if (actor.handgun_reserve if actor.active_weapon == "handgun" else actor.rifle_reserve) > 0:
			cover_goal = _find_cover()
			request_attack.call(actor.peer_id, "reload", actor.aim)
			state = "Reloading"
			return
		elif actor.role == "stalker":
			actor.equip("knife")
	var distance: float = actor.position.distance_to(last_known) if memory_age < 8.0 else 100.0
	if _relay_decision(delta): return
	if senses.field.enabled and not deployed_utility and not visible and elapsed > 8 and actor.position.y > 12:
		if actor.role == "stalker": own_decoy = actor.position + Vector3(-sin(actor.aim.x),0,-cos(actor.aim.x)) * 1.7
		request_attack.call(actor.peer_id, "alarm" if actor.role == "sniper" else "reflector", actor.aim)
		deployed_utility = actor.alarms == 0 if actor.role == "sniper" else actor.reflectors == 0
	if actor.role == "stalker":
		_stalker(delta, distance)
	else:
		_sniper(delta, distance)
	_look(delta)
	if actor.role == "stalker" and not visible and actor.pebbles > 0 and elapsed >= next_distraction and Rules.modern(actor.game.ruleset_id):
		# Choose a lateral disturbance from own route/map knowledge, never a hidden target.
		var landing := actor.position + Vector3(flank * -12, 0, -8)
		var toward: Vector3 = (landing - actor.eye_position()).normalized()
		var throwing_aim := Vector2(atan2(-toward.x, -toward.z), 0.25)
		request_attack.call(actor.peer_id, "pebble", throwing_aim)
		next_distraction = elapsed + 24.0
	if visible and reaction <= 0 and actor.cooldown <= 0 and actor.reload_remaining <= 0:
		if actor.role == "stalker" and not _behind_target():
			return
		var aim_point := last_aim_point + last_velocity * minf(memory_age, 0.18)
		var direction: Vector3 = (aim_point - actor.eye_position()).normalized()
		var desired := Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
		var angular_error: float = absf(angle_difference(actor.aim.x, desired.x)) + absf(actor.aim.y - desired.y)
		var reach: float = Rules.KNIFE_REACH if actor.active_weapon == "knife" else (Rules.HANDGUN_RANGE if actor.active_weapon == "handgun" else 160.0)
		if angular_error < 0.035 and actor.eye_position().distance_to(aim_point) <= reach:
			var wobble: float = 0.0025 if actor.active_weapon == "rifle" else 0.004
			request_attack.call(actor.peer_id, "attack", actor.aim + Vector2(rng.randf_range(-wobble, wobble), rng.randf_range(-wobble, wobble)))
			if actor.cooldown > 0:
				shots += 1
			if actor.role == "sniper" and actor.cooldown > 0:
				cover_time = 0.9
				cover_goal = _find_cover()

func _observe() -> void:
	var was_visible := visible
	visible = false
	var sample: Dictionary = senses.observe()
	if sample.has("sight"):
		var sight: Dictionary = sample.sight
		visible = true
		if not was_visible and visual_age > 0.65:
			# A low silhouette needs a sustained view before a precise rifle shot.
			# This is confirmed visual appearance, never hidden stance information.
			reaction = (1.2 if sight.crouched else 0.6) if actor.role == "sniper" else 0.4
			sightings += 1
		last_known = sight.position
		last_aim_point = sight.aim_point
		last_velocity = sight.velocity
		last_facing = sight.facing
		memory_age = 0
		visual_age = 0
	elif sample.has("sound") and memory_age > 0.6:
		receive_sound(sample.sound)
	elif sample.has("evidence") and not visible:
		var cue: Dictionary = sample.evidence
		if cue.source == "reflection" and own_decoy.distance_to(cue.position) < 2: return
		if cue.source == "tracks" and own_trail.any(func(point): return point.distance_to(cue.position) < 1.8): return
		_remember_cue(cue.source, cue.position, cue.radius)

func _stalker(delta: float, distance: float) -> void:
	actor.equip("knife")
	actor.command_flags = 4 # Stay crouched and silent throughout the approach.
	if not chosen_flank:
		var best := INF
		for side in [-1.0, 1.0]:
			var entry := Vector3(side * 23, 0, 2)
			if arena.map_id == "mountain":
				entry = arena.Mountain.WEST[1] if side < 0 else arena.Mountain.EAST[1]
			var candidate: PackedVector2Array = tactics.route(actor.position, entry, _knowledge(), "stalker")
			var score: float = tactics.route_score(candidate, "stalker") + rng.randf_range(0, 3)
			if score < best:
				best = score
				flank = side
		chosen_flank = true
	if cover_time > 0:
		state = "Breaking sight in cover"
		_navigate(cover_goal, delta)
		return
	if visible and distance > 5 and last_facing.dot((actor.position - last_known).normalized()) > 0.75:
		var cover: Vector3 = _find_cover()
		if cover.distance_to(actor.position) > 1:
			cover_goal = cover
			cover_time = 0.8
			state = "Breaking sight before a shot"
			_navigate(cover_goal, delta)
			return
	var route := [Vector3(flank * 23, 0, 24), Vector3(flank * 23, 0, 2), Vector3(flank * 23, 0, -22), Vector3(flank * 23, 18, -42), Vector3(0, 18, -42)] if arena.map_id == "forest" else [Vector3(flank * 23, 0, 24), Vector3(flank * 23, 0, -24), Vector3(flank * 11, 0, -24), Vector3(flank * 11, 3.9, -41), Vector3(0, 3.9, -40)]
	var can_close: bool = actor.position.y >= 17.5 if arena.map_id == "forest" else actor.position.y >= 3.4 and (absf(actor.position.x) < 7 or actor.position.z < -39.3)
	if arena.map_id == "mountain":
		route = arena.Mountain.flank(flank)
		can_close = distance <= 12 and arena.Mountain.sniper_allowed(Vector2(actor.position.x, actor.position.z))
	if (patrol >= 3 or arena.map_id == "mountain") and can_close and (visible or visual_age < 6):
		patrol = route.size()
	if patrol < route.size() and _reached_patrol(route[patrol]):
		patrol += 1
	if patrol < route.size():
		state = "Sneaking along covered flank" if patrol < 3 else "Circling behind the high ground"
		_navigate(route[patrol], delta)
	elif visible or visual_age < 6:
		state = "Closing silently from behind"
		var rear: Vector3 = last_known - last_facing * 1.5
		_navigate(rear, delta)
	else:
		state = "Searching concealed perches"
		if elapsed >= search_until or _flat_distance(actor.position, search_goal) < 1.2:
			searched[Vector2i(roundi(search_goal.x), roundi(search_goal.z))] = true
			search_goal = _search_perch()
			search_until = elapsed + 7
		_navigate(search_goal, delta)

func _reached_patrol(destination: Vector3) -> bool:
	if _flat_distance(actor.position, destination) < 1.0:
		return true
	# A steep or obstructed authored marker can project onto a nearby free
	# grid cell. Arrival must use that reachable endpoint, with a bounded offset.
	if arena.map_id == "mountain" and not path.is_empty() and _flat_distance(goal, destination) < 0.1:
		var end := Vector3(path[-1].x, 0, path[-1].y)
		return _flat_distance(end, destination) <= 3.0 and _flat_distance(actor.position, end) < 0.9
	return false

func _knowledge() -> Dictionary:
	if memory_age < 10:
		var sound_only := cue_age < visual_age
		var confidence := clampf(1.0 - memory_age / 12.0, 0.2, 1.0)
		return {"position": last_known, "facing": Vector3.ZERO if sound_only else last_facing, "confidence": minf(confidence, 0.3) if sound_only else confidence}
	return {"confidence": 0.0}

func _search_perch() -> Vector3:
	tactics.ensure_hides()
	var best: Vector3 = arena.constrain_sniper(actor.position)
	var score := INF
	for candidates in [arena.bot_hides, arena.bot_cover]:
		for candidate in candidates:
			var point: Vector3 = candidate.hide
			var key := Vector2i(roundi(point.x), roundi(point.z))
			if searched.has(key):
				continue
			var value: float = actor.position.distance_to(point)
			if cue_age < 7:
				value += point.distance_to(cue_position) * 0.5
			if value < score:
				score = value
				best = point
		if score < INF:
			return best
	searched.clear()
	return best

func _behind_target() -> bool:
	var offset := Vector3(actor.position.x - last_known.x, 0, actor.position.z - last_known.z)
	return offset.length_squared() > 0.01 and offset.normalized().dot(last_facing) < -0.4

func hear_birds(perch: Vector3) -> void:
	if visible or actor.position.distance_to(perch) > 85:
		return
	if senses.field.enabled and senses.hear_event("birds", perch, 85).is_empty(): return
	_remember_cue("birds", Vector3(perch.x, arena.height_at(perch.x, perch.z), perch.z), 10.0)
	bird_memory = 4.0

func receive_sound(cue: Dictionary) -> void:
	if visible or cue.is_empty():
		return
	_remember_cue(cue.source, cue.position, cue.radius)

func _remember_cue(source: String, point: Vector3, radius: float) -> void:
	cue_source = source
	cue_position = point
	cue_radius = radius
	cue_age = 0
	# A recent visual contact remains more precise than a disturbed tree/noise.
	if visual_age > 2.0:
		last_known = point
		memory_age = 0.5

func _sniper(delta: float, distance: float) -> void:
	if arena.map_id == "mountain" and not hide_plan.is_empty() and not visible and elapsed >= hide_until and _flat_distance(actor.position, hide_plan.hide) < 1.0:
		hide_plan = tactics.choose_hide(Vector3.ZERO, hide_plan.hide, rng.randf() * TAU)
		hide_until = elapsed + rng.randf_range(24, 36)
	if hide_plan.is_empty() or (hide_plan.lanes == 0 and elapsed >= hide_until):
		hide_plan = tactics.choose_hide(Vector3.ZERO, Vector3(1000, 0, 1000), rng.randf() * TAU)
		hide_until = elapsed + ((24 if arena.map_id == "mountain" else 12) if hide_plan.lanes > 0 else 2)
		next_peek = elapsed + rng.randf_range(4, 7)
	if cover_time > 0 and distance > 8:
		actor.command_flags = 4
		state = "Withdrawing into concealment"
		_navigate(cover_goal, delta)
	elif visible:
		actor.command_flags = 8
		state = "Lining up rifle shot"
		if distance < 11:
			actor.command_flags = 2
			state = "Escaping a close approach"
			if elapsed > hide_until:
				hide_plan = tactics.choose_hide(last_known, hide_plan.hide, rng.randf() * TAU)
				hide_until = elapsed + 3
			_navigate(hide_plan.hide, delta)
	else:
		var hide: Vector3 = hide_plan.hide
		actor.command_flags = 4
		var approaches: Array[Vector3] = hide_plan.watch
		attention = approaches[int(elapsed / 3.5) % approaches.size()]
		if _flat_distance(actor.position, hide) > 0.8 and peek_until <= elapsed:
			state = "Moving to concealed perch"
			_navigate(hide, delta)
		elif elapsed < peek_until:
			state = "Checking a firing lane"
			actor.command_flags = 0
			_navigate(hide_plan.peek, delta)
		else:
			state = "Holding concealed watch"
			if cue_age < 5:
				state = "Watching a sound from concealment"
				attention = cue_position + Vector3.UP
			if elapsed >= next_peek:
				peek_until = elapsed + 1.6
				next_peek = elapsed + rng.randf_range(9, 13)
			# Short, infrequent rear checks leave learnable opportunities to flank.
			if fmod(elapsed, 18.0) < 0.8:
				attention = actor.position + Vector3(6 * sin(elapsed), 1.1, -8)

func _look(delta: float) -> void:
	var point: Vector3
	if visible:
		point = last_aim_point + last_velocity * minf(memory_age, 0.18)
	elif visual_age < 3:
		point = last_known + Vector3.UP
	elif cue_age < 5:
		point = cue_position + Vector3(sin(elapsed * 1.8) * cue_radius * 0.3, 1, 0)
	else:
		if actor.role == "sniper":
			point = attention
		else:
			point = goal + Vector3(0, 1.2, 0)
	var toward: Vector3 = point - actor.eye_position()
	if toward.length_squared() < 0.01:
		return
	var desired := Vector2(atan2(-toward.x, -toward.z), asin(clampf(toward.normalized().y, -1, 1)))
	actor.aim.x = rotate_toward(actor.aim.x, desired.x, delta * 3.6)
	actor.aim.y = move_toward(actor.aim.y, desired.y, delta * 2.5)

func _navigate(destination: Vector3, delta: float) -> void:
	if actor.role == "sniper":
		destination = arena.constrain_sniper(destination)
	destination.y = arena.height_at(destination.x, destination.z)
	if path_clock <= 0 or _flat_distance(destination, goal) > 3:
		path_clock = 0.65 + rng.randf_range(0, 0.2)
		goal = destination
		var on_deck: bool = arena.map_id == "yard" and actor.position.y >= 3.4 and (absf(actor.position.x) < 7 or actor.position.z < -39.3)
		var navigation_role: String = "sniper" if on_deck and destination.z < -30 and absf(destination.x) < 7 else actor.role
		path = tactics.route(actor.position, destination, _knowledge(), navigation_role)
		waypoint = 1
		path_queries += 1
	while waypoint < path.size() and Vector2(actor.position.x, actor.position.z).distance_to(path[waypoint]) < 0.85:
		waypoint += 1
	if waypoint >= path.size():
		return
	var point := path[waypoint]
	if actor.role == "stalker" and visual_age < 3 and elapsed >= crossing_ready and tactics.blocked(last_known + Vector3.UP, actor.eye_position()) and not tactics.blocked(last_known + Vector3.UP, Vector3(point.x, arena.height_at(point.x, point.y) + 0.85, point.y)):
		crossing_until = elapsed + 0.6
		crossing_ready = elapsed + 4
	if elapsed < crossing_until:
		state = "Waiting before an exposed crossing"
		return
	var direction := Vector3(point.x - actor.position.x, 0, point.y - actor.position.z).normalized()
	var local: Vector3 = Basis(Vector3.UP, -actor.aim.x) * direction
	actor.command_move = Vector2(local.x, local.z)
	if actor.position.distance_to(previous_position) < delta * 0.2:
		stuck_time += delta
	else:
		stuck_time = 0
	previous_position = actor.position
	if stuck_time > 0.8:
		actor.command_flags |= 1
		path_clock = 0
		stuck_time = 0

func _find_cover() -> Vector3:
	if actor.role == "sniper":
		var previous: Vector3 = hide_plan.get("hide", actor.position)
		hide_plan = tactics.choose_hide(last_known, previous, rng.randf() * TAU)
		hide_until = elapsed + 6
		peek_until = 0
		return hide_plan.hide
	var best: Vector3 = actor.position
	var best_score: float = -INF
	for i in range(8):
		var angle: float = i * TAU / 8
		var candidate: Vector3 = actor.position + Vector3(cos(angle), 0, sin(angle)) * 4.5
		candidate.x = clampf(candidate.x, -32, 32)
		candidate.z = clampf(candidate.z, -41, 41)
		if actor.role == "sniper":
			candidate = arena.constrain_sniper(candidate)
		candidate.y = arena.height_at(candidate.x, candidate.z)
		if arena.path_to(actor.position, candidate, actor.role).is_empty():
			continue
		var query := PhysicsRayQueryParameters3D.create(last_known + Vector3(0, 1.6, 0), candidate + Vector3(0, 1.1, 0), 1)
		var blocked: bool = not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		var score: float = (10.0 if blocked else 0.0) + candidate.distance_to(last_known) * 0.04
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _relay_decision(delta: float) -> bool:
	if not relay_mode or visible and actor.position.distance_to(last_known) < 12: return false
	if actor.role == "stalker" and actor.position.y < (12.0 if arena.map_id == "mountain" else 17.5 if arena.map_id == "forest" else 3.4): return false
	var goal_index := -1
	var nearest := INF
	for i in range(relay_positions.size()):
		var known: int = relay_known.get(i, 0)
		if not (actor.role == "stalker" and known == 0 or actor.role == "sniper" and known == 1): continue
		var distance: float = actor.position.distance_to(relay_positions[i])
		if distance < nearest:
			nearest = distance
			goal_index = i
	if goal_index < 0: return false
	var station: Vector3 = relay_positions[goal_index]
	state = "Approaching relay" if actor.role == "stalker" else "Approaching observed damaged relay"
	actor.command_flags = 4
	if nearest > 2.0:
		_navigate(station + Vector3(0,0,1.1), delta)
		_look(delta)
	else:
		var direction: Vector3 = (station + Vector3.UP * 0.8 - actor.eye_position()).normalized()
		actor.aim = Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
		actor.command_move = Vector2.ZERO
		actor.command_flags = 16 | 4
		state = "Sabotaging relay" if actor.role == "stalker" else "Repairing observed relay"
	return true
