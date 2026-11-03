extends Node3D

const Rules = preload("res://scripts/rules.gd")
const Assets = preload("res://scripts/model_assets.gd")
var arena: Node3D
var game: Node3D
var walkers: Array[Dictionary] = []
var ambient_time: float = 0.0
var motion_time: float = 0.0

func setup(owner_arena: Node3D, owner_game: Node3D) -> void:
	name = "Wildlife"
	arena = owner_arena
	game = owner_game
	var locations := [Vector3(-10, 0, 27), Vector3(13, 0, 18), Vector3(-9, 0, -9), Vector3(21, 0, -17), Vector3(12, 0, 30), Vector3(-18, 0, 4), Vector3(8, 0, 22), Vector3(-12, 0, 15), Vector3(19, 0, -4), Vector3(-8, 0, -23)]
	for i in range(locations.size()):
		var species: String = "deer" if i < 4 else ("fox" if i < 6 else "rabbit")
		_add_animal(species, locations[i], i)
	arena.forest_details["Wildlife"] = walkers.size()

func _process(delta: float) -> void:
	if game.mode == "replay":
		return
	if game.paused:
		return
	ambient_time += delta
	# Gameplay clock gives both online peers the same decorative patrol positions.
	if game.phase in ["playing", "countdown"]:
		motion_time = game.round_index * Rules.ROUND_SECONDS + Rules.ROUND_SECONDS - game.round_time
	elif game.phase in ["round_over", "match_over"]:
		motion_time += delta
	else:
		motion_time = ambient_time
	for walker in walkers:
		_update_animal(walker, motion_time)

func _add_animal(species: String, center: Vector3, index: int) -> void:
	var points := PackedVector3Array()
	var corners := [center + Vector3(-3, 0, -3), center + Vector3(3, 0, -3), center + Vector3(3, 0, 3), center + Vector3(-3, 0, 3)]
	for i in range(4):
		var segment: PackedVector2Array = arena.path_to(corners[i], corners[(i + 1) % 4])
		if segment.is_empty():
			return
		for p in segment:
			var point := Vector3(p.x, arena.height_at(p.x, p.y), p.y)
			if points.is_empty() or points[-1].distance_to(point) > 0.1:
				points.append(point)
	var lengths := PackedFloat32Array([0.0])
	for i in range(points.size()):
		lengths.append(lengths[-1] + points[i].distance_to(points[(i + 1) % points.size()]))
	if lengths[-1] < 1:
		return
	var root := Node3D.new()
	root.name = "%s_%d" % [species.capitalize(), index]
	add_child(root)
	var asset := "stag" if species == "deer" and index % 2 == 0 else species
	var model := Assets.scene(asset)
	var bounds := Assets.bounds(model)
	var visual := Node3D.new()
	visual.name = "AuthoredModel"
	var height: float = (2.0 if asset == "stag" else 1.65) if species == "deer" else (0.58 if species == "fox" else 0.42)
	visual.scale = Vector3.ONE * height / bounds.size.y
	visual.position.y = -bounds.position.y * visual.scale.y
	visual.rotation.y = PI
	root.add_child(visual)
	visual.add_child(model)
	var animation := Assets.find_animation(model)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var walk := "walk" if species == "rabbit" else "Walk"
	var idle := "idle" if species == "rabbit" else "Eating"
	walkers.append({"node": root, "visual": visual, "animation": animation, "skeleton": Assets.find_skeleton(model), "walk": walk, "idle": idle,
		"points": points, "lengths": lengths, "distance": lengths[-1], "speed": 0.75 if species == "deer" else (1.0 if species == "fox" else 0.7), "phase": index * 7.17, "species": species})
	_update_animal(walkers[-1], 0)

func _update_animal(walker: Dictionary, time: float) -> void:
	var cycle: float = walker.distance / walker.speed + 5.0
	var phase: float = fposmod(time + walker.phase, cycle)
	var moving: bool = phase >= 5.0
	var distance: float = maxf(0, phase - 5.0) * walker.speed
	var lengths: PackedFloat32Array = walker.lengths
	var points: PackedVector3Array = walker.points
	var segment: int = 0
	while segment < points.size() - 1 and lengths[segment + 1] < distance:
		segment += 1
	var next: int = (segment + 1) % points.size()
	var weight: float = clampf((distance - lengths[segment]) / maxf(0.01, lengths[segment + 1] - lengths[segment]), 0, 1)
	var position: Vector3 = points[segment].lerp(points[next], weight)
	position.y = arena.height_at(position.x, position.z)
	if walker.species == "rabbit" and moving:
		position.y += maxf(0, sin(phase * 10)) * 0.1
	var direction: Vector3 = points[next] - points[segment]
	walker.node.position = position
	walker.node.rotation.y = atan2(-direction.x, -direction.z)
	Assets.animation_at(walker.animation, walker.walk if moving else walker.idle, phase)
