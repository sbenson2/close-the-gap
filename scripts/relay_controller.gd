extends Node3D

const Logic = preload("res://scripts/relay_rules.gd")
const Assets = preload("res://scripts/model_assets.gd")
var game: Node3D
var rules = Logic.new()
var positions: Array[Vector3] = []
var lights: Array[MeshInstance3D] = []
var tasks: Dictionary = {}

func setup(subject: Node3D) -> void:
	game = subject

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	positions.clear()
	lights.clear()
	tasks.clear()
	rules.reset()
	if game.ruleset_id != game.Rules.RELAY:
		return
	var points: Array = [Vector3(-15, 0, -37), Vector3(0, 0, -37), Vector3(15, 0, -37)]
	if game.selected_level == "mountain":
		points = [game.arena.Mountain.NESTS[1] + Vector3(0, 0, -2), game.arena.Mountain.NESTS[3] + Vector3(1.5, 0, -2), game.arena.Mountain.NESTS[5] + Vector3(0, 0, -2)]
	for i in range(3):
		var point: Vector3 = points[i]
		point.y = game.arena.height_at(point.x, point.z)
		positions.append(point)
		var console := Node3D.new()
		console.position = point
		add_child(console)
		var base := Assets.visual("yard_crate", Vector3(0.65, 0.8, 0.5))
		console.add_child(base)
		var antenna := Assets.visual("yard_pipe", Vector3(0.055, 2.0, 0.055))
		antenna.position.y = 0.9
		console.add_child(antenna)
		var light := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.07
		mesh.height = 0.14
		light.mesh = mesh
		light.position = Vector3(0, 1.04, 0.1)
		light.material_override = StandardMaterial3D.new()
		console.add_child(light)
		lights.append(light)
	_update_lights()

func _update_lights() -> void:
	for i in range(lights.size()):
		var material: StandardMaterial3D = lights[i].material_override
		material.albedo_color = Color("df5b3c") if rules.stations[i] == 1 else Color("8bb187") if rules.stations[i] == 2 else Color("d8ba73")
		material.emission_enabled = true
		material.emission = material.albedo_color

func interaction(actor: CharacterBody3D) -> Dictionary:
	for i in range(positions.size()):
		if not (rules.stations[i] == 0 and actor.role == "stalker" or rules.stations[i] == 1 and actor.role == "sniper"):
			continue
		if accessible(actor, positions[i]):
			return {"index": i, "seconds": 4.0 if actor.role == "stalker" else 5.0, "text": "Sabotage relay %d" % (i + 1) if actor.role == "stalker" else "Repair relay %d" % (i + 1)}
	return {}

func accessible(actor: CharacterBody3D, point: Vector3) -> bool:
	if actor.position.distance_to(point) > 2.5:
		return false
	var to: Vector3 = point + Vector3.UP * 0.8
	if actor.direction().dot((to - actor.eye_position()).normalized()) < 0.55:
		return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.eye_position(), to, 1))
	return hit.is_empty() or hit.position.distance_to(to) < 0.2

func step(delta: float) -> void:
	if game.ruleset_id != game.Rules.RELAY or game.phase != "playing" or not game.is_authority():
		return
	for actor in game.players.values():
		var task: Dictionary = interaction(actor) if actor.alive and (actor.command_flags & 16) != 0 and actor.reload_remaining <= 0 and actor.throw_remaining <= 0 and actor.cooldown <= 0 and not actor.binoculars and not actor.climbing else {}
		var prior: Dictionary = tasks.get(actor.peer_id, {})
		if task.is_empty() or not prior.is_empty() and (prior.origin.distance_to(actor.position) > 0.15 or prior.health != actor.health):
			actor.interaction_progress = 0
			tasks.erase(actor.peer_id)
			continue
		if prior.is_empty() or prior.index != task.index:
			prior = {"index": task.index, "origin": actor.position, "health": actor.health}
			actor.interaction_progress = 0
			tasks[actor.peer_id] = prior
		actor.interaction_progress += delta
		if actor.interaction_progress >= task.seconds:
			if rules.change(task.index, actor.role):
				game.broadcast_field("relay", [task.index, rules.stations[task.index], rules.revision])
			actor.interaction_progress = 0
			tasks.erase(actor.peer_id)
	var outcome: String = rules.advance(delta)
	if not outcome.is_empty():
		var winner := 0
		if outcome == "stalker":
			for actor in game.players.values():
				if actor.role == "stalker": winner = actor.peer_id
		game.end_round(winner, "Relay infiltration." if winner else "Time expired. Round drawn.")

func apply_change(index: int, state: int, revision: int = -1) -> void:
	if revision >= 0 and revision < rules.revision: return
	if index >= 0 and index < positions.size() and state >= 0 and state <= 2:
		rules.stations[index] = state
		if revision >= 0: rules.revision = revision
		_update_lights()
		game.sound.play_at("relay", positions[index], -6)
		if game.is_authority():
			for brain in game.bot_brains.values():
				brain.receive_sound(brain.senses.hear_event("mechanism", positions[index], 30))

func visible_stations(actor: CharacterBody3D) -> Array:
	var seen: Array = []
	for i in range(positions.size()):
		var point: Vector3 = positions[i] + Vector3.UP
		if actor.eye_position().distance_to(point) > 24 or actor.direction().dot((point - actor.eye_position()).normalized()) < 0.5:
			continue
		var ray := PhysicsRayQueryParameters3D.create(actor.eye_position(), point, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and not game.arena.foliage_hides(actor.eye_position(), point):
			seen.append([i, rules.stations[i]])
	return seen
