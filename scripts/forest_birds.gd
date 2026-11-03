extends Node3D

const Rules = preload("res://scripts/rules.gd")
const Assets = preload("res://scripts/model_assets.gd")
var arena: Node3D
var game: Node3D
var flocks: Array[Dictionary] = []
var bird_models: Array[Dictionary] = []
var bird_positions := PackedVector3Array()
var sense_clock: float = 0.0
var alarm_count: int = 0
var last_alarm := Vector3.ZERO
var round_id: int = -1
var visual_time: float = 0.0

func setup(owner_arena: Node3D, owner_game: Node3D) -> void:
	name = "TreeBirds"
	arena = owner_arena
	game = owner_game
	for i in range(0, arena.bird_perches.size(), 12):
		flocks.append({"perch": arena.bird_perches[i], "start": -100.0, "direction": Vector3.FORWARD, "ready": 0.0})
	bird_positions.resize(flocks.size() * 3)
	for i in range(flocks.size() * 3):
		var root := Node3D.new()
		root.name = "Crow_%d" % i
		add_child(root)
		var model := Assets.scene("crow")
		var bounds := Assets.bounds(model)
		var visual := Node3D.new()
		visual.scale = Vector3.ONE * 0.28 / bounds.size.y
		visual.position.y = -bounds.position.y * visual.scale.y
		visual.rotation.y = PI
		root.add_child(visual)
		visual.add_child(model)
		for part in Assets.parts(model):
			part.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var animation := Assets.find_animation(model)
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		bird_models.append({"node": root, "animation": animation})
	arena.forest_details["Birds"] = flocks.size() * 3
	reset_round(game.round_index)
	_update_visuals()

func reset_round(index: int) -> void:
	round_id = index
	alarm_count = 0
	last_alarm = Vector3.ZERO
	visual_time = 0.0
	for flock in flocks:
		flock.start = -100.0
		flock.ready = 0.0

func _time() -> float:
	return game.round_elapsed()

func _physics_process(delta: float) -> void:
	if not game.is_authority() or game.phase != "playing" or game.paused:
		return
	sense_clock -= delta
	if sense_clock > 0:
		return
	sense_clock = 0.15
	for player in game.players.values():
		if not player.alive or player.crouched:
			continue
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		if speed < 3.2 and absf(player.velocity.y) < 2:
			continue
		var radius: float = 10.0 if speed > 7 else 6.0
		for index in range(flocks.size()):
			var perch: Vector3 = flocks[index].perch
			if Vector2(perch.x - player.position.x, perch.z - player.position.z).length() < radius:
				_spook(index, player.position, player.peer_id)

func hear_shot(origin: Vector3, source_id: int, weapon: String) -> void:
	if not game.is_authority() or game.phase != "playing" or weapon == "knife":
		return
	var radius: float = 38.0 if weapon == "rifle" else 20.0
	for index in range(flocks.size()):
		if origin.distance_to(flocks[index].perch) <= radius:
			_spook(index, origin, source_id)

func hear_impact(origin: Vector3) -> void:
	if not game.is_authority() or game.phase != "playing":
		return
	for index in range(flocks.size()):
		if origin.distance_to(flocks[index].perch) <= 12:
			_spook(index, origin, -1)

func _spook(index: int, source: Vector3, source_id: int) -> void:
	if _time() < flocks[index].ready:
		return
	var away: Vector3 = flocks[index].perch - source
	away.y = 0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	# Coarse flight directions cannot be intersected to recover exact player coordinates.
	var angle := snappedf(atan2(away.x, away.z), PI / 4)
	game.announce_birds(index, Vector3(sin(angle), 0, cos(angle)))
	# The cue gives a tree's location, not the hidden player's coordinates.
	for id in game.bot_brains:
		if id != source_id:
			game.bot_brains[id].hear_birds(flocks[index].perch)

func apply_alarm(index: int, direction: Vector3, time: float) -> void:
	if index < 0 or index >= flocks.size():
		return
	flocks[index].start = time
	flocks[index].ready = time + 30.0
	flocks[index].direction = direction
	alarm_count += 1
	last_alarm = flocks[index].perch
	game.sound.play_at("bird_alarm", last_alarm, -3)

func _process(delta: float) -> void:
	if game.mode == "replay":
		return
	if game.paused:
		return
	if game.phase in ["playing", "countdown"]:
		visual_time = _time()
	else:
		visual_time += delta
	_update_visuals()

func _update_visuals() -> void:
	if bird_models.is_empty():
		return
	for i in range(flocks.size()):
		var flock: Dictionary = flocks[i]
		var age: float = visual_time - flock.start
		var flying: bool = age >= 0 and age < 22
		for j in range(3):
			var position: Vector3 = flock.perch + Vector3(cos(j * 2.4) * 0.45, j * 0.1, sin(j * 2.4) * 0.45)
			var yaw: float = i * 1.71 + j
			if flying:
				var progress: float = minf(age, 6.0) if age < 15 else maxf(0, (22.0 - age) / 7.0 * 6.0)
				position += flock.direction * progress * (4.8 + j * 0.4) + Vector3.UP * progress * 2.0
				position += Vector3(sin(age * 2 + j), sin(age * 3 + j) * 0.25, cos(age * 2 + j)) * minf(age, 1) * minf(22.0 - age, 1)
				yaw = atan2(-flock.direction.x, -flock.direction.z) + PI * clampf((age - 14.5) / 1.5, 0, 1)
			var bird: Dictionary = bird_models[i * 3 + j]
			bird_positions[i * 3 + j] = position
			bird.node.position = position
			bird.node.rotation.y = yaw
			Assets.animation_at(bird.animation, "run" if flying else "idle", (age * 1.8 if flying else visual_time) + j * 0.37)
