extends Node

const Codec = preload("res://scripts/replay_codec.gd")
const Rules = preload("res://scripts/rules.gd")
var game: Node3D
var data: Dictionary
var position: float = 0.0
var duration: float = 0.0
var rate: float = 1.0
var active_scene: int = -1
var event_cursor: int = 0
var applied_events: int = 0

func setup(subject: Node3D, recording: Dictionary) -> void:
	game = subject
	data = recording
	game.ruleset_id = data.get("ruleset_id", Rules.CLASSIC)
	game.arena.map_revision = data.get("map_revision", "ridge_v1")
	game.map_revision = game.arena.map_revision
	game.environment_id = data.get("environment_id", "clear")
	game.pairs_to_play = int(data.get("pairs_to_play", 1))
	# The arena may already contain the same map ID with a different revision.
	game.arena.load_level(data.level)
	duration = float(data.ticks) / Codec.HZ
	process_priority = -50
	seek(0)

func _process(delta: float) -> void:
	if game.mode != "replay" or game.paused:
		return
	var target: float = minf(duration, position + delta * rate)
	_apply(target)
	while event_cursor < data.events.size() and data.events[event_cursor].t <= target * Codec.HZ:
		var event: Dictionary = data.events[event_cursor]
		if int(event.r) == active_scene:
			_event(event)
		event_cursor += 1
	position = target
	if position >= duration:
		game.paused = true

func _frame_index(tick: float) -> int:
	var lo := 0
	var hi: int = data.frames.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if data.frames[mid].t <= tick + 0.000001:
			lo = mid
		else:
			hi = mid - 1
	return lo

func _event_index(tick: float) -> int:
	var lo := 0
	var hi: int = data.events.size()
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if data.events[mid].t <= tick + 0.000001:
			lo = mid + 1
		else:
			hi = mid
	return lo

func seek(seconds: float) -> void:
	position = clampf(seconds, 0, duration)
	var was_muted: bool = game.sound.muted
	game.sound.muted = true
	_apply(position)
	if game.arena.birds:
		game.arena.birds.reset_round(game.round_index)
	event_cursor = 0
	while event_cursor < data.events.size() and data.events[event_cursor].t <= position * Codec.HZ:
		var event: Dictionary = data.events[event_cursor]
		if event.kind == "birds" and int(event.r) == active_scene:
			_event(event)
		event_cursor += 1
	_environment(data.frames[_frame_index(position * Codec.HZ)])
	game.sound.muted = was_muted

func _apply(seconds: float) -> void:
	var tick: float = seconds * Codec.HZ
	var index: int = _frame_index(tick)
	var a: Dictionary = data.frames[index]
	var b: Dictionary = data.frames[mini(index + 1, data.frames.size() - 1)]
	var weight: float = clampf((tick - a.t) / maxf(1, b.t - a.t), 0, 1) if a.r == b.r else 0.0
	if active_scene != int(a.r):
		active_scene = int(a.r)
		var scene: Dictionary = data.scenes[active_scene]
		var paused: bool = game.paused
		game.configure_round(int(scene.index), [1, 2], scene.roles, {1: int(a.scores[0]), 2: int(a.scores[1])}, data.level)
		game.paused = paused
	game.phase = a.phase
	game.round_time = lerpf(a.clock, b.clock, weight) if a.phase == b.phase else a.clock
	game.transition_time = a.transition
	game.scores = {1: int(a.scores[0]), 2: int(a.scores[1])}
	game.winner_id = int(a.winner)
	game.result_text = a.result
	game.round_review = a.get("review", []).duplicate(true)
	if a.has("systems"):
		game.field.clock = a.systems.field_clock
		game.relay.rules.restore(a.systems.relay, true)
		game.relay._update_lights()
	for i in range(2):
		var actor = game.players[i + 1]
		var state: Array = a.actors[i]
		var next: Array = b.actors[i]
		actor.position = Codec.vector(state[0]).lerp(Codec.vector(next[0]), weight)
		actor.velocity = Codec.vector(state[1])
		actor.aim = Vector2(lerp_angle(state[2][0], next[2][0], weight), lerpf(state[2][1], next[2][1], weight))
		actor.crouched = state[3]
		actor.scoped = state[4]
		actor.cooldown = state[5]
		actor.equip(state[6])
		actor.health = int(state[7])
		actor.handgun_ammo = int(state[8])
		actor.handgun_reserve = int(state[9])
		actor.reload_remaining = state[10]
		actor.aiming = state[11]
		actor.alive = state[12]
		actor.motion_time = state[13]
		actor.recoil = state[14]
		actor.swing = state[15]
		actor.hit_feedback = state[16]
		actor.damage_flash = state[17]
		actor.camera.fov = state[18]
		actor.command_flags = int(state[19])
		actor.head.position.y = state[20]
		if state.size() >= 25:
			actor.rifle_ammo = int(state[21])
			actor.rifle_reserve = int(state[22])
			actor.pebbles = int(state[23])
			actor.throw_remaining = state[24]
		if state.size() >= 31:
			actor.binoculars = state[25]
			actor.reflectors = int(state[26])
			actor.alarms = int(state[27])
			actor.interaction_progress = state[28]
			actor.climbing = state[29]
			actor.climb_progress = state[30]
		game.bot_brains[i + 1].state = a.brains[i][0]
		game.bot_brains[i + 1].sightings = int(a.brains[i][1])
	# Combat events have 60 Hz timing between the 20 Hz state samples.
	# Preserve their damage/ammunition until the next sample includes the hit.
	var event_index: int = _event_index(a.t)
	while event_index < data.events.size() and data.events[event_index].t <= tick + 0.000001:
		var event: Dictionary = data.events[event_index]
		if int(event.r) == active_scene and event.kind == "attack":
			var value: Array = event.v
			var attacker = game.players[int(value[0])]
			var age: float = (tick - event.t) / Codec.HZ
			attacker.equip(value[1])
			attacker.cooldown = maxf(0, (Rules.SHOT_COOLDOWN if value[1] == "rifle" else (Rules.HANDGUN_COOLDOWN if value[1] == "handgun" else Rules.KNIFE_COOLDOWN)) - age)
			if value[1] == "handgun":
				attacker.handgun_ammo = maxi(0, attacker.handgun_ammo - 1)
			elif value[1] == "rifle" and Rules.modern(game.ruleset_id):
				attacker.rifle_ammo = maxi(0, attacker.rifle_ammo - 1)
			if int(value[4]) > 0:
				var victim = game.players[int(value[4])]
				victim.health = int(value[5])
				victim.alive = victim.health > 0
				victim.damage_flash = maxf(0, 0.25 - age)
				attacker.hit_feedback = maxf(0, 0.3 - age)
		elif int(event.r) == active_scene and event.kind == "pebble_throw":
			var actor = game.players[int(event.v[1])]
			actor.pebbles = maxi(0, actor.pebbles - 1)
			actor.throw_remaining = maxf(0, Rules.THROW_SECONDS - (tick - event.t) / Codec.HZ)
		elif int(event.r) == active_scene and event.kind == "reload":
			game.players[int(event.v[0])].reload_remaining = maxf(0, (Rules.RIFLE_RELOAD_SECONDS if event.v[1] == "rifle" else Rules.RELOAD_SECONDS) - (tick - event.t) / Codec.HZ)
		event_index += 1
	_environment({"wild": lerpf(a.wild, b.wild, weight), "birds": lerpf(a.birds, b.birds, weight)})
	_restore_pebbles(tick)
	_restore_field(tick, a)

func _restore_field(tick: float, frame: Dictionary) -> void:
	if not frame.has("systems") or not game.field.enabled: return
	var entries: Array = []
	var cursor := _event_index(float(data.scenes[active_scene].get("t", 0)) - 1)
	while cursor < data.events.size() and data.events[cursor].t <= tick:
		var event: Dictionary = data.events[cursor]
		if int(event.r) == active_scene and event.kind == "field": entries.append(event.v)
		cursor += 1
	var elapsed: float = float(frame.systems.field_clock) + (tick - frame.t) / Codec.HZ if frame.phase == "playing" else float(frame.systems.field_clock)
	game.field.restore_events(entries, elapsed)

func _restore_pebbles(tick: float) -> void:
	var active: Dictionary = {}
	var cursor := _event_index(float(data.scenes[active_scene].get("t", 0)) - 1)
	while cursor < data.events.size() and data.events[cursor].t <= tick:
		var event: Dictionary = data.events[cursor]
		if int(event.r) == active_scene:
			if event.kind == "pebble_throw":
				active[int(event.v[0])] = event
			elif event.kind == "pebble_impact":
				active.erase(int(event.v[0]))
		cursor += 1
	for serial in game.projectiles.keys():
		if not active.has(serial):
			var item = game.projectiles[serial]
			game.remove_child(item)
			item.queue_free()
			game.projectiles.erase(serial)
	for serial in active:
		var event: Dictionary = active[serial]
		if not game.projectiles.has(serial):
			game.pebble_thrown(game.round_index, serial, int(event.v[1]), Codec.vector(event.v[2]), Codec.vector(event.v[3]))
		if game.projectiles.has(serial):
			var age := (tick - float(event.t)) / Codec.HZ
			game.projectiles[serial].position = Codec.vector(event.v[2]) + Codec.vector(event.v[3]) * age + Vector3.DOWN * 9 * age * age
			game.projectiles[serial].rotation = Vector3(4, 2, 3) * age

func _environment(frame: Dictionary) -> void:
	var animals = game.arena.get_node_or_null("Wildlife")
	if animals:
		animals.motion_time = frame.wild
		for walker in animals.walkers:
			animals._update_animal(walker, frame.wild)
	if game.arena.birds:
		game.arena.birds.visual_time = frame.birds
		game.arena.birds._update_visuals()

func _event(event: Dictionary) -> void:
	var values: Array = event.v
	if event.kind == "attack":
		game.attack_effect(int(values[0]), values[1], Codec.vector(values[2]), Codec.vector(values[3]), int(values[4]), int(values[5]))
	elif event.kind == "birds" and game.arena.birds:
		game.arena.birds.apply_alarm(int(values[0]), Codec.vector(values[1]), game.field.clock if data.version >= 3 else 150.0 - float(values[2]))
	elif event.kind == "reload":
		game.reload_effect(int(values[0]), values[1], Codec.vector(values[2]))
	elif event.kind == "pebble_impact":
		game.pebble_impact(game.round_index, int(values[0]), Codec.vector(values[1]))
	elif event.kind == "field":
		game.field_event(game.round_index, values[0], values[1])
	applied_events += 1
