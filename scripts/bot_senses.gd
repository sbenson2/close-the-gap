extends RefCounted

# Engine-side perception. Only this module may inspect the candidate actor.
# Decision code receives visible samples or coarse sound areas, never a roster.
var arena: Node3D
var observer: CharacterBody3D
var candidate: CharacterBody3D
var noise_rng := RandomNumberGenerator.new()
var clock := 0.0
var previous_seen := Vector3.ZERO
var previous_time := -100.0
var field: Node3D
var relay: Node3D

func setup(owner_game: Node3D, subject: CharacterBody3D, seed_value: int) -> void:
	arena = owner_game.arena
	observer = subject
	field = owner_game.field
	relay = owner_game.relay
	for id in owner_game.players:
		if int(id) != subject.peer_id:
			candidate = owner_game.players[id]
			break
	noise_rng.seed = seed_value + 7919

func advance(delta: float) -> void:
	clock += delta

func observe() -> Dictionary:
	if not is_instance_valid(candidate):
		return {}
	var from: Vector3 = observer.eye_position()
	var offset: Vector3 = candidate.eye_position() - from
	var half_angle := deg_to_rad(16.0 if observer.scoped else 30.0 if observer.binoculars else 57.0)
	var in_weather_range: bool = not field.enabled or field.condition != "rain" or offset.length() <= 65
	if candidate.alive and in_weather_range and observer.direction().dot(offset.normalized()) >= cos(half_angle):
		for point in [candidate.position + Vector3(0, 0.8 if candidate.crouched else 1.05, 0), candidate.eye_position()]:
			var query := PhysicsRayQueryParameters3D.create(from, point, 3, [observer.get_rid()])
			var hit := observer.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == candidate and not arena.foliage_hides(from, point):
				var velocity := Vector3.ZERO
				var interval := clock - previous_time
				if interval > 0.001 and interval < 0.3:
					velocity = (candidate.position - previous_seen) / interval
				previous_seen = candidate.position
				previous_time = clock
				return {"sight": {"position": candidate.position, "aim_point": point, "velocity": velocity, "crouched": candidate.crouched,
					"facing": Vector3(-sin(candidate.aim.x), 0, -cos(candidate.aim.x))}}
	var loudness: float = field.surface_loudness(candidate.position) if field.enabled else 1.0
	if offset.length() < 10 * loudness and not candidate.crouched and Vector2(candidate.velocity.x, candidate.velocity.z).length() > 3:
		var cue := hear_event("footsteps", candidate.position, 10 * loudness)
		if not cue.is_empty(): return {"sound": cue}
	if field.enabled:
		var cue: Dictionary = field.visible_evidence(observer)
		if not cue.is_empty(): return {"evidence": cue}
	return {}

func hear_shot(origin: Vector3, weapon: String) -> Dictionary:
	if weapon == "knife":
		return {}
	var range_metres := 100.0 if weapon == "rifle" else 55.0
	if field.enabled: return hear_event("shot", origin, range_metres)
	if observer.eye_position().distance_to(origin) > range_metres:
		return {}
	return _sound_area("shot", origin)

func hear_event(category: String, origin: Vector3, audible_range: float) -> Dictionary:
	if not origin.is_finite():
		return {}
	var query := PhysicsRayQueryParameters3D.create(observer.eye_position(), origin, 1)
	var hit := observer.get_world_3d().direct_space_state.intersect_ray(query)
	var reach := audible_range * (0.35 if not hit.is_empty() and hit.position.distance_to(origin) > 0.3 else 1.0)
	return _sound_area(category, origin) if observer.eye_position().distance_to(origin) <= reach else {}

func _sound_area(source: String, origin: Vector3) -> Dictionary:
	# Quantisation prevents repeated noisy cues converging on exact coordinates.
	# Height comes from the map at the estimate, never the hidden actor's Y.
	var x := roundf(origin.x / 6.0) * 6.0 + noise_rng.randf_range(-1.5, 1.5)
	var z := roundf(origin.z / 6.0) * 6.0 + noise_rng.randf_range(-1.5, 1.5)
	return {"source": source, "position": Vector3(x, arena.height_at(x, z), z), "radius": 7.0}
