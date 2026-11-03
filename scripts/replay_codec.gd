extends RefCounted

const Rules = preload("res://scripts/rules.gd")
const FORMAT = "CTG_REPLAY"
const VERSION = 3
const HZ = 60
const ACTOR_FIELDS = 31

static func v3(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]

static func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func actor_state(actor: CharacterBody3D) -> Array:
	return [v3(actor.position), v3(actor.velocity), [actor.aim.x, actor.aim.y], actor.crouched, actor.scoped, actor.cooldown, actor.active_weapon, actor.health, actor.handgun_ammo, actor.handgun_reserve, actor.reload_remaining, actor.aiming, actor.alive, actor.motion_time, actor.recoil, actor.swing, actor.hit_feedback, actor.damage_flash, actor.camera.fov, actor.command_flags, actor.head.position.y, actor.rifle_ammo, actor.rifle_reserve, actor.pebbles, actor.throw_remaining, actor.binoculars, actor.reflectors, actor.alarms, actor.interaction_progress, actor.climbing, actor.climb_progress]

static func numbers(value: Variant, count: int, limit: float) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(number) or absf(number) > limit:
			return false
	return true

static func integer(value: Variant, low: int, high: int) -> bool:
	return numbers([value], 1, 1000000) and value == floorf(value) and value >= low and value <= high

static func validate(data: Variant) -> String:
	if not data is Dictionary or data.get("format") != FORMAT or (data.get("version") != 1 and data.get("version") != 2 and data.get("version") != VERSION) or data.get("hz") != HZ:
		return "Unsupported recording format."
	var modern: bool = data.version >= 2
	var demo: bool = data.version >= 3
	if modern and (not Rules.RULESETS.has(data.get("ruleset_id", "")) or not data.get("build_id") is String or data.get("map_revision") not in ["ridge_v1", "ridge_v2", "ridge_v3"]):
		return "Recording has unsupported rules or map revision."
	if demo and (not Rules.ENVIRONMENTS.has(data.get("environment_id", "")) or not integer(data.get("pairs_to_play"), 1, 3)):
		return "Recording has invalid match settings."
	if not Rules.LEVELS.has(data.get("level", "")) or not data.get("ticks") is float and not data.get("ticks") is int:
		return "Recording has no valid map or duration."
	if not integer(data.ticks, 1, HZ * 3600):
		return "Recording duration is outside the supported range."
	for key in ["frames", "scenes", "events"]:
		if not data.get(key) is Array:
			return "Recording is missing " + key + "."
	if data.frames.size() < 2 or data.frames.size() > 80000 or data.scenes.is_empty() or data.scenes.size() > 500 or data.events.size() > 20000:
		return "Recording has an invalid number of states or events."
	for scene in data.scenes:
		if not scene is Dictionary or not scene.get("index") is float and not scene.get("index") is int:
			return "Invalid round description."
		if not integer(scene.index, 0, 10) or scene.get("roles") not in [["stalker", "sniper"], ["sniper", "stalker"]]:
			return "Invalid round roles."
	var previous: float = -1
	for frame in data.frames:
		if not frame is Dictionary or not numbers([frame.get("t"), frame.get("r"), frame.get("clock"), frame.get("transition"), frame.get("winner"), frame.get("wild"), frame.get("birds")], 7, 1000000):
			return "Invalid frame header."
		if not integer(frame.t, 0, int(data.ticks)) or frame.t <= previous or not integer(frame.r, 0, data.scenes.size() - 1) or frame.clock < 0 or frame.clock > 150 or frame.transition < 0 or frame.transition > 10 or not integer(frame.winner, 0, 2):
			return "Invalid frame ordering or round state at tick %s." % frame.t
		previous = frame.t
		if frame.get("phase") not in ["countdown", "playing", "round_over", "match_over"] or not numbers(frame.get("scores"), 2, 6 if demo else 3) or not frame.get("result") is String or frame.result.length() > 200:
			return "Invalid frame score or phase."
		if not integer(frame.scores[0], 0, 6 if demo else 3) or not integer(frame.scores[1], 0, 6 if demo else 3):
			return "Invalid round score."
		if frame.has("review"):
			if not frame.review is Array or frame.review.size() > 5:
				return "Invalid round review."
			for item in frame.review:
				if not item is Dictionary or not numbers([item.get("seconds")], 1, 180 if demo else 150) or item.seconds < 0 or not item.get("description") is String or item.description.length() > 200:
					return "Invalid round review event."
		if demo:
			var systems: Variant = frame.get("systems")
			if not systems is Dictionary or not numbers([systems.get("field_clock")], 1, 180) or not systems.get("relay") is Array or systems.relay.size() < 4 or systems.relay.size() > 5:
				return "Invalid field state."
			var relay: Array = systems.relay
			if not numbers([relay[0]],1,180) or not numbers([relay[1]],1,30) or relay[0] < 0 or relay[1] < 0 or not relay[2] is Array or relay[2].size() != 3 or relay[3] not in ["", "draw", "stalker"]:
				return "Invalid relay state."
			for state in relay[2]:
				if not integer(state,0,2): return "Invalid station state."
			if relay.size() > 4 and not integer(relay[4],0,6): return "Invalid objective revision."
		if not frame.get("actors") is Array or frame.actors.size() != 2 or not frame.get("brains") is Array or frame.brains.size() != 2:
			return "Invalid player states."
		for i in range(2):
			var state: Variant = frame.actors[i]
			if not state is Array or state.size() != (ACTOR_FIELDS if demo else 25 if modern else 21) or not numbers(state[0], 3, 200) or not numbers(state[1], 3, 100) or not numbers(state[2], 2, 10000):
				return "Invalid player transform."
			if absf(state[2][1]) > 1.45 or not Rules.weapon_allowed(data.scenes[int(frame.r)].roles[i], str(state[6])):
				return "Invalid player aim or weapon."
			for field in [3, 4, 11, 12]:
				if not state[field] is bool:
					return "Invalid player flags."
			for field in [5, 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20]:
				if not numbers([state[field]], 1, 100000):
					return "Invalid player values."
			if not integer(state[7], 0, 100) or not integer(state[8], 0, 6) or not integer(state[9], 0, 12) or not integer(state[19], 0, 63 if demo else 15) or state[18] < 10 or state[18] > 100:
				return "Invalid health, ammunition or camera."
			if modern and (not integer(state[21], 0, 3) or not integer(state[22], 0, 9) or not integer(state[23], 0, 3) or not numbers([state[24]], 1, 1.01) or state[24] < 0):
				return "Invalid rifle or distraction state."
			if demo and (not state[25] is bool or not state[29] is bool or not integer(state[26],0,1) or not integer(state[27],0,1) or not numbers([state[28]],1,5.1) or state[28] < 0 or not numbers([state[30]],1,1) or state[30] < 0):
				return "Invalid equipment or interaction state."
			var brain: Variant = frame.brains[i]
			if not brain is Array or brain.size() != 2 or not brain[0] is String or brain[0].length() > 120 or not numbers([brain[1]], 1, 100000):
				return "Invalid bot description."
	previous = -1
	for event in data.events:
		if not event is Dictionary or not integer(event.get("t"), 0, int(data.ticks)) or not integer(event.get("r"), 0, data.scenes.size() - 1) or event.t < previous or not event.get("v") is Array:
			return "Invalid event ordering."
		previous = event.t
		var value: Array = event.v
		if event.get("kind") == "attack":
			if value.size() != 6 or not integer(value[0], 1, 2) or value[1] not in ["knife", "handgun", "rifle"] or not numbers(value[2], 3, 400) or not numbers(value[3], 3, 400) or not integer(value[4], 0, 2) or not integer(value[5], 0, 100):
				return "Invalid attack event."
		elif event.get("kind") == "birds":
			if value.size() != 3 or not integer(value[0], 0, 256) or not numbers([value[2]], 1, 150) or not numbers(value[1], 3, 1.01) or value[2] < 0:
				return "Invalid bird event."
		elif modern and event.kind == "reload":
			if value.size() != 3 or not integer(value[0], 1, 2) or value[1] not in ["rifle", "handgun"] or not numbers(value[2], 3, 400):
				return "Invalid reload event."
		elif modern and event.kind == "pebble_throw":
			if value.size() != 4 or not integer(value[0], 1, 1000000) or not integer(value[1], 1, 2) or not numbers(value[2], 3, 400) or not numbers(value[3], 3, 30):
				return "Invalid distraction event."
		elif modern and event.kind == "pebble_impact":
			if value.size() != 2 or not integer(value[0], 1, 1000000) or not numbers(value[1], 3, 400):
				return "Invalid impact event."
		elif demo and event.kind == "field":
			if not valid_field_event(value): return "Invalid field event."
		else:
			return "Unknown recording event."
	if data.frames[0].t != 0 or data.frames[-1].t != data.ticks:
		return "Recording is incomplete."
	return ""

static func valid_field_event(value: Array) -> bool:
	if value.size() != 2 or not value[0] is String or not value[1] is Array: return false
	var v: Array = value[1]
	match value[0]:
		"track": return v.size() == 4 and integer(v[0],1,1000000) and numbers(v[1],3,200) and numbers([v[2],v[3]],2,10000) and v[3] >= 0
		"place": return v.size() == 5 and integer(v[0],1,1000000) and v[1] in ["reflector","alarm"] and numbers(v[2],3,200) and numbers([v[3],v[4]],2,10000) and v[4] >= 0
		"alarm": return v.size() == 1 and integer(v[0],1,1000000)
		"relay": return v.size() in [2,3] and integer(v[0],0,2) and integer(v[1],0,2) and (v.size() == 2 or integer(v[2],0,6))
	return false

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32 * 1024 * 1024:
		return {"error": "Recording is missing or too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "Recording contains invalid JSON."}
	var error := validate(parser.data)
	return {"error": error} if error else {"data": parser.data}
