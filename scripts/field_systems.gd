extends Node3D

const Assets = preload("res://scripts/model_assets.gd")
var game: Node3D
var clock := 0.0
var condition := "clear"
var enabled := false
var gadgets: Array[Dictionary] = []
var tracks: Array[Dictionary] = []
var mud: Array[Vector3] = []
var serial := 0
var trace_clock := 0.0
var last_print: Dictionary = {}
var track_mesh: MultiMeshInstance3D
var rain: MultiMeshInstance3D
var rope_points: Array[Vector3] = []
var climbers: Dictionary = {}
var audio: Array[AudioStreamPlayer] = []

func setup(subject: Node3D) -> void:
	game = subject

func _process(_delta: float) -> void:
	if not game: return
	for player in audio:
		player.stream_paused = game.paused or game.sound.muted

func reset() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	gadgets.clear()
	tracks.clear()
	mud.clear()
	last_print.clear()
	climbers.clear()
	rope_points.clear()
	audio.clear()
	clock = 0
	serial = 0
	track_mesh = null
	rain = null
	enabled = game.map_revision == "ridge_v3" and game.phase not in ["menu", "lobby"]
	condition = game.environment_id if enabled else "clear"
	if not enabled:
		return
	if game.arena.is_forest():
		for point in ([Vector3(-24, 0, 27), Vector3(13, 0, 28), Vector3(-27, 0, 16), Vector3(18, 0, 21)] if game.selected_level == "mountain" else [Vector3(-23, 0, 24), Vector3(23, 0, 2), Vector3(-23, 0, -20)]):
			mud.append(Vector3(point.x, game.arena.height_at(point.x, point.z), point.z))
		_build_tracks()
		_build_rope()
	if condition == "rain": _build_rain()
	_build_audio()

func movement_mask() -> float:
	if not enabled or condition == "clear": return 1.0
	var phase := fmod(clock, 29.0)
	var gust := smoothstep(11, 13, phase) * (1 - smoothstep(16, 18, phase))
	return lerpf(0.75 if condition == "rain" else 1.0, 0.32, gust)

func surface(point: Vector3) -> String:
	if in_mud(point): return "mud"
	if game.selected_level == "yard": return "wood" if point.y > 3 else "gravel"
	if game.selected_level == "mountain":
		for index in [1, 2, 5]:
			if point.distance_to(game.arena.Mountain.NESTS[index]) < 3.2: return "wood"
		return "gravel" if game.arena.Mountain.path_sample(Vector2(point.x, point.z)).x < 1.8 else "brush"
	return "wood" if point.y > 17.5 else "brush"

func surface_loudness(point: Vector3) -> float:
	return {"wood": 1.25, "gravel": 1.0, "brush": 0.75, "mud": 0.6}[surface(point)] * movement_mask()

func in_mud(point: Vector3) -> bool:
	for patch in mud:
		if Vector2(point.x - patch.x, point.z - patch.z).length() < 3: return true
	return false

func step(delta: float) -> void:
	if not enabled or game.phase != "playing": return
	clock += delta
	_update_weather()
	if not game.is_authority(): return
	for actor in game.players.values():
		if not actor.alive: continue
		if climbers.has(actor.peer_id):
			_step_climber(actor, delta)
		elif (actor.command_flags & 16) != 0 and not actor.climbing:
			_start_rope(actor)
	trace_clock -= delta
	if trace_clock <= 0:
		trace_clock = 0.6
		for actor in game.players.values():
			if actor.alive and in_mud(actor.position) and Vector2(actor.velocity.x, actor.velocity.z).length() > 0.7 and actor.position.distance_to(last_print.get(actor.peer_id, Vector3.INF)) > 0.55:
				last_print[actor.peer_id] = actor.position
				serial += 1
				game.broadcast_field("track", [serial, game.ReplayCodec.v3(actor.position), actor.aim.x, clock])
	for item in gadgets:
		if item.kind != "alarm" or item.triggered or clock - item.born < 1: continue
		for actor in game.players.values():
			var side := Vector3(cos(item.yaw),0,-sin(item.yaw)) * 0.9
			var wire: Vector3 = item.point + Vector3.UP * 0.15
			var touching: bool = game.Rules.segment_intersects_sphere(wire - side, wire + side, actor.position + Vector3.UP * 0.18, 0.38)
			var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(wire, actor.position + Vector3.UP * 0.18, 1)) if touching else {}
			if actor.alive and touching and wall.is_empty():
				game.broadcast_field("alarm", [item.serial])
				break
	_refresh_tracks()

func _update_weather() -> void:
	if not enabled: return
	var strength := (1 - movement_mask()) * 2.8 + 1
	for material in game.arena.wind_materials:
		material.set_shader_parameter("gust_multiplier", strength)
	if rain:
		rain.material_override.set_shader_parameter("weather_clock", clock)
	for i in range(audio.size()):
		audio[i].volume_db = (-37 + (1 - movement_mask()) * 18) if i == 0 else -29
	for child in game.arena.get_children():
		if child is WorldEnvironment:
			child.environment.fog_density = 0.013 if condition == "rain" else (0.005 if game.selected_level == "mountain" else 0.008 if game.selected_level == "forest" else 0.0035)
			child.environment.ambient_light_energy = 0.3 if condition == "rain" else 0.38
			child.environment.sky.sky_material.sky_top_color = Color("697982") if condition == "rain" else Color("536c83")
			child.environment.sky.sky_material.sky_horizon_color = Color("8b999b") if condition == "rain" else Color("b3b8b1")
		elif child is DirectionalLight3D:
			child.light_energy = 0.6 if condition == "rain" else 0.9

func place(actor: CharacterBody3D, kind: String) -> bool:
	if not enabled or kind not in ["reflector", "alarm"] or actor.cooldown > 0 or actor.throw_remaining > 0 or actor.reload_remaining > 0:
		return false
	if kind == "reflector" and (actor.role != "stalker" or actor.reflectors <= 0): return false
	if kind == "alarm" and (actor.role != "sniper" or actor.alarms <= 0): return false
	var point: Vector3 = actor.position + Vector3(-sin(actor.aim.x), 0, -cos(actor.aim.x)) * 1.7
	point.y = game.arena.height_at(point.x, point.z)
	if absf(point.y - actor.position.y) > 1.5: return false
	var ray := PhysicsRayQueryParameters3D.create(actor.eye_position(), point + Vector3.UP * 0.35, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return false
	if kind == "reflector": actor.reflectors -= 1
	else: actor.alarms -= 1
	actor.throw_remaining = 1
	serial += 1
	game.broadcast_field("place", [serial, kind, game.ReplayCodec.v3(point), actor.aim.x, clock])
	return true

func apply_event(kind: String, value: Array) -> void:
	if kind == "track":
		tracks.append({"serial": int(value[0]), "point": game.ReplayCodec.vector(value[1]), "yaw": value[2], "born": value[3]})
		if tracks.size() > 96: tracks.pop_front()
		_refresh_tracks()
	elif kind == "place":
		if gadgets.any(func(item): return item.serial == int(value[0])): return
		var point: Vector3 = game.ReplayCodec.vector(value[2])
		var node := Node3D.new()
		add_child(node)
		node.position = point
		node.rotation.y = float(value[3])
		var prop := Assets.visual("pebble" if value[1] == "alarm" else "stump", Vector3(0.22, 0.12, 0.22) if value[1] == "alarm" else Vector3(0.22, 0.4, 0.22))
		node.add_child(prop)
		var mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.2, 0.2) if value[1] == "reflector" else Vector2(1.8, 0.018)
		mesh.mesh = quad
		mesh.position.y = 0.48 if value[1] == "reflector" else 0.15
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffe7b1") if value[1] == "reflector" else Color("85674f")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if value[1] == "reflector" else BaseMaterial3D.BILLBOARD_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		node.add_child(mesh)
		gadgets.append({"serial": int(value[0]), "kind": value[1], "point": point, "yaw": value[3], "born": value[4], "triggered": false, "node": node})
	elif kind == "alarm":
		for item in gadgets:
			if item.serial == int(value[0]) and not item.triggered:
				item.triggered = true
				game.sound.play_at("alarm", item.point, -2)
				if game.is_authority():
					for brain in game.bot_brains.values(): brain.receive_sound(brain.senses.hear_event("alarm", item.point, 45))

func visible_evidence(actor: CharacterBody3D) -> Dictionary:
	# Only the engine-side sense layer calls this. Never return an owner/target.
	var candidates: Array = []
	for item in gadgets:
		if item.kind == "reflector": candidates.append({"source": "reflection", "position": item.point + Vector3.UP * 0.48, "radius": 2.0})
	for item in tracks:
		if clock - item.born < 28 and actor.position.distance_to(item.point) < 10:
			candidates.append({"source": "tracks", "position": item.point + Vector3.UP * 0.1, "radius": 2.0})
	var rays := 0
	for cue in candidates:
		var point: Vector3 = cue.position
		if actor.eye_position().distance_to(point) > 55 or actor.direction().dot((point - actor.eye_position()).normalized()) < 0.6: continue
		if rays >= 3: break
		rays += 1
		var ray := PhysicsRayQueryParameters3D.create(actor.eye_position(), point, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and not game.arena.foliage_hides(actor.eye_position(), point): return cue
	return {}

func _build_tracks() -> void:
	track_mesh = MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.44)
	batch.mesh = quad
	batch.instance_count = 96
	track_mesh.multimesh = batch
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/forest/footprint.svg")
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	track_mesh.material_override = material
	track_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(track_mesh)
	_refresh_tracks()
	for patch in mud:
		var surface_mesh := MeshInstance3D.new()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for z in range(-3, 3):
			for x in range(-3, 3):
				for point in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
					tool.set_color(Color(0.29,0.22,0.15,0.7))
					tool.add_vertex(Vector3(patch.x + point.x, game.arena.height_at(patch.x + point.x, patch.z + point.y) + 0.025, patch.z + point.y))
		tool.generate_normals()
		surface_mesh.mesh = tool.commit()
		var mud_material := StandardMaterial3D.new()
		mud_material.albedo_color = Color("5c4935")
		mud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface_mesh.material_override = mud_material
		add_child(surface_mesh)

func _refresh_tracks() -> void:
	if not track_mesh: return
	for i in range(96):
		var transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
		var color := Color(0.25, 0.19, 0.12, 0)
		if i < tracks.size() and clock - tracks[i].born < 28:
			var item: Dictionary = tracks[i]
			var point: Vector3 = item.point
			point.y = game.arena.height_at(point.x, point.z) + 0.045
			transform = Transform3D(Basis(Vector3.UP, item.yaw) * Basis(Vector3.RIGHT, -PI / 2), point)
			color.a = clampf((28 - clock + item.born) / 9, 0, 0.85)
		track_mesh.multimesh.set_instance_transform(i, transform)
		track_mesh.multimesh.set_instance_color(i, color)

func _build_rain() -> void:
	rain = MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.027, 1.35)
	batch.mesh = quad
	batch.instance_count = 1200
	var rng := RandomNumberGenerator.new()
	rng.seed = 6607
	for i in range(1200):
		var x := rng.randf_range(-35,35)
		var z := rng.randf_range(-44,44)
		batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, game.arena.height_at(x,z) + 28,z)))
		batch.set_instance_custom_data(i, Color(rng.randf(),0,0,1))
	rain.multimesh = batch
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/forest/rain.gdshader")
	rain.material_override = material
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)

func _build_audio() -> void:
	if DisplayServer.get_name() == "headless": return
	for kind in (["wind", "rain"] if condition == "rain" else ["wind"] if condition == "breezy" else []):
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/" + kind + ".wav")
		player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream.loop_end = player.stream.get_length() * player.stream.mix_rate
		add_child(player)
		audio.append(player)
		player.volume_db = -36
		player.play()

func _build_rope() -> void:
	if game.selected_level != "mountain": return
	var start: Vector3 = game.arena.Mountain.WEST[2]
	var end: Vector3 = game.arena.Mountain.NESTS[0] + Vector3(-1.8,0,-1.8)
	for i in range(17):
		var point := start.lerp(end, i / 16.0)
		point.y = game.arena.height_at(point.x, point.z) + 0.08
		rope_points.append(point)
	var visual := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c1aa7d")
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in rope_points: mesh.surface_add_vertex(point + Vector3.UP * 0.85)
	mesh.surface_end()
	visual.mesh = mesh
	add_child(visual)
	for point in [rope_points[0], rope_points[-1]]:
		var post := Assets.visual("log", Vector3(0.13, 1.25, 0.13))
		post.position = point
		add_child(post)

func rope_prompt(actor: CharacterBody3D) -> String:
	if actor.role != "stalker" or rope_points.is_empty(): return ""
	return game.key_label("interact") + " / Climb handline" if actor.position.distance_to(rope_points[0]) < 1.7 else ""

func _start_rope(actor: CharacterBody3D) -> void:
	if rope_prompt(actor).is_empty() or actor.throw_remaining > 0 or actor.reload_remaining > 0: return
	actor.climbing = true
	actor.climb_progress = 0
	climbers[actor.peer_id] = 1
	game.sound.play_at("step_wood", actor.position, -4)

func _step_climber(actor: CharacterBody3D, delta: float) -> void:
	var index: int = climbers[actor.peer_id]
	if not actor.alive or index >= rope_points.size():
		actor.climbing = false
		actor.velocity = Vector3.ZERO
		climbers.erase(actor.peer_id)
		return
	var offset: Vector3 = rope_points[index] - actor.position
	if offset.length() < 0.12:
		climbers[actor.peer_id] = index + 1
		actor.climb_progress = index / 16.0
		return
	var motion := offset.limit_length(3.5 * delta)
	actor.velocity = motion / maxf(delta, 0.001)
	var hit := actor.move_and_collide(motion)
	if hit:
		actor.climbing = false
		actor.velocity = Vector3.ZERO
		climbers.erase(actor.peer_id)

func restore_events(entries: Array, elapsed: float) -> void:
	clock = elapsed
	tracks.clear()
	var desired: Dictionary = {}
	var alarms: Dictionary = {}
	for entry in entries:
		if entry[0] == "place": desired[int(entry[1][0])] = entry[1]
		elif entry[0] == "alarm": alarms[int(entry[1][0])] = true
		elif entry[0] == "track" and clock - float(entry[1][3]) < 28:
			var value: Array = entry[1]
			tracks.append({"serial": int(value[0]), "point": game.ReplayCodec.vector(value[1]), "yaw": value[2], "born": value[3]})
	if tracks.size() > 96: tracks = tracks.slice(tracks.size() - 96)
	for item in gadgets.duplicate():
		if not desired.has(item.serial):
			remove_child(item.node)
			item.node.queue_free()
			gadgets.erase(item)
	for serial_id in desired: apply_event("place", desired[serial_id])
	for item in gadgets:
		item.triggered = alarms.has(item.serial)
	_update_weather()
	_refresh_tracks()
