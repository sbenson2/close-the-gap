extends RefCounted

const Details = preload("res://scripts/forest_details.gd")
const Assets = preload("res://scripts/model_assets.gd")
const Mountain = preload("res://scripts/mountainside.gd")

# Deterministic geometry: visual detail uses a separate random stream from cover.
var arena: Node3D
var rng := RandomNumberGenerator.new()
var pine_transforms: Array = []
var birch_transforms: Array = []
var trunk_transforms: Array = []
var grass_transforms: Array = []
var fern_transforms: Array = []
var bush_transforms: Array = []
var rock_material: Material
var bark_material: StandardMaterial3D
var authored_trees: Dictionary = {}

func build(owner_arena: Node3D) -> void:
	arena = owner_arena
	rng.seed = 781233
	rock_material = textured_material("rock_boulder_dry_diff_1k.jpg", "rock_boulder_dry_nor_gl_1k.jpg")
	rock_material.albedo_color = Color("a1ab95")
	bark_material = textured_material("bark_brown_02_diff_1k.jpg", "bark_brown_02_nor_gl_1k.jpg")
	bark_material.uv1_scale = Vector3(1.5, 4, 1)
	_terrain()
	if arena.map_id == "mountain":
		_mountain_paths()
	else:
		_trail(0.0)
		_trail(-23.0)
		_trail(23.0)
	if arena.map_id == "mountain":
		_mountain_edges()
	else:
		for x in [-35.5, 35.5]:
			for z in range(-44, 45, 4):
				_boundary(Vector3(x, arena.height_at(x, z) + 2.8, z), Vector3(2, 5.6, 4.1))
		for z in [-45.5, 45.5]:
			_boundary(Vector3(0, arena.height_at(0, z) + 2.8, z), Vector3(72, 5.6, 2))
	if arena.map_id == "mountain":
		_mountain_cover()
		_stealth_thickets()
	else:
		_legacy_cover()
	# Distant rocky peaks make the uphill direction readable from both approaches.
	for i in range(0 if arena.map_id == "mountain" else 7):
		var width: float = 36 + i % 3 * 10
		var height: float = 34 + i % 3 * 9
		var mountain := Assets.visual("rock_2", Vector3(width, height, width))
		mountain.position = Vector3(-78 + i * 26, 18 + height * 0.5, -78 - i % 2 * 12)
		arena.add_child(mountain)
	for x in range(-32, 34, 4):
		for z in range(-41, 43, 5):
			var p := Vector3(x + rng.randf_range(-0.9, 0.9), 0, z + rng.randf_range(-1.1, 1.1))
			if _clear_route(p, 1.8):
				continue
			if arena.map_id == "mountain" and Mountain.tree_blocks_view(p):
				continue
			_tree(p, rng.randf_range(0.75, 1.25), rng.randf() < 0.23)
	# Beyond the rock boundary, taller crowns close the silhouette of the forest.
	for i in range(90):
		var angle := i * TAU / 90.0
		var p := Vector3(sin(angle) * rng.randf_range(43, 55), 0, cos(angle) * rng.randf_range(54, 67))
		_tree(p, rng.randf_range(1.15, 1.8), false, false)
	if arena.map_id == "mountain":
		var saved_state := rng.state
		rng.seed = 419760
		for i in range(160):
			var p := Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-125, 100))
			if absf(p.x) < 40 and absf(p.z) < 52:
				continue
			_tree(p, rng.randf_range(0.8, 1.6), false, false)
		rng.state = saved_state
	for i in range(3800):
		var p := Vector3(rng.randf_range(-34, 34), 0.025, rng.randf_range(-44, 44))
		p.y += arena.height_at(p.x, p.z)
		if _clear_route(p, 1.0):
			continue
		var height := rng.randf_range(0.3, 0.85)
		var transform := Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(height, height, height)), p)
		if i % 4 == 0:
			fern_transforms.append(transform)
		else:
			grass_transforms.append(transform)
	for i in range(150):
		var p := Vector3(rng.randf_range(-31, 31), 0, rng.randf_range(-40, 40))
		p.y = arena.height_at(p.x, p.z)
		if _clear_route(p, 2.0):
			continue
		var radius := rng.randf_range(1.1, 1.7)
		bush_transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(radius, radius, radius)), p + Vector3(0, 0.7, 0)))
		arena.concealment.append(Vector4(p.x, p.y + 0.8, p.z, radius))
	for key in authored_trees:
		_batch("Imported_" + key, Assets.mesh_height(key), null, authored_trees[key])
	_batch("Undergrowth", Assets.mesh_fit("bush", Vector3(2.0, 1.4, 2.0)), null, bush_transforms)
	_batch("Grass", Assets.mesh_height("grass"), null, grass_transforms, false)
	_batch("Ferns", Assets.mesh_height("fern"), null, fern_transforms, false)
	arena.foliage_count = grass_transforms.size() + fern_transforms.size() + bush_transforms.size()
	Details.new().build(self)

func textured_material(color_map: String, normal_map: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = arena.mat(Color.WHITE)
	material.albedo_texture = load("res://assets/forest/" + color_map)
	material.normal_enabled = true
	material.normal_texture = load("res://assets/forest/" + normal_map)
	material.normal_scale = 0.65
	return material

func wind_material(color: Color, strength: float, height: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/forest/foliage.gdshader")
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("wind_strength", strength)
	material.set_shader_parameter("plant_height", height)
	arena.wind_materials.append(material)
	return material

func _clear_route(p: Vector3, padding: float) -> bool:
	if arena.map_id == "mountain":
		return Mountain.clear_route(p, padding)
	if p.z < -39.5:
		return true
	# A clear ridge lip gives the sniper a readable view down the wooded slope.
	if p.z < -29 and absf(p.x) < 15:
		return true
	if absf(p.z) > 30 and absf(p.x) < 6.5:
		return true
	var trail_x := sin(p.z * 0.105) * 3.0
	return absf(p.x - trail_x) < padding or absf(absf(p.x) - 23.0) < padding or absf(absf(p.z) - 13.0) < 1.2

func _tree(p: Vector3, variation: float, birch: bool, collide: bool = true) -> void:
	p.y = arena.height_at(p.x, p.z)
	var height := (8.5 if birch else 11.0) * variation
	var radius := 0.39 * variation
	var rotation := Basis(Vector3.UP, rng.randf_range(0, TAU))
	var key := ("tree_%d" if birch else "pine_%d") % (arena.tree_count % 3 + 1)
	if not authored_trees.has(key):
		authored_trees[key] = []
	authored_trees[key].append(Transform3D(rotation.scaled(Vector3.ONE * height), p))
	trunk_transforms.append(Transform3D(rotation.scaled(Vector3(variation, height * 0.6, variation)), p + Vector3(0, height * 0.3, 0)))
	if birch:
		birch_transforms.append(Transform3D(rotation.scaled(Vector3(2.3 * variation, 3.1 * variation, 2.1 * variation)), p + Vector3(0, height * 0.77, 0)))
	else:
		pine_transforms.append(Transform3D(rotation.scaled(Vector3(2.5 * variation, height * 0.8, 2.5 * variation)), p + Vector3(0, height * 0.23, 0)))
	arena.tree_count += 1
	if not collide:
		return
	arena.bird_perches.append(p + rotation * Vector3(0.8, height * 0.54, 0.2))
	var body := StaticBody3D.new()
	body.position = p + Vector3(0, height * 0.3, 0)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height * 0.6
	shape.shape = cylinder
	body.add_child(shape)
	arena.add_child(body)
	arena.solids.append(Rect2(Vector2(p.x - radius, p.z - radius), Vector2.ONE * radius * 2).grow(0.65))

func _rock(p: Vector3, extent: Vector3) -> void:
	p.y = arena.height_at(p.x, p.z)
	var body := StaticBody3D.new()
	body.position = p + Vector3(0, extent.y * 0.43, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 7
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.mesh = Assets.mesh_fit("rock_1", Vector3.ONE * 2)
	visual.scale = extent
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape()
	collision.scale = extent
	body.add_child(collision)
	arena.add_child(body)
	arena.solids.append(Rect2(Vector2(p.x - extent.x, p.z - extent.z), Vector2(extent.x, extent.z) * 2).grow(0.6))

func _boundary(position: Vector3, dimensions: Vector3) -> void:
	var body: Node3D = arena.box(position, dimensions, rock_material)
	for child in body.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var count := ceili(dimensions.x / 6.0) if dimensions.x > 10 else 1
	for i in range(count):
		var visual := Assets.visual("rock_3", Vector3(dimensions.x / count + 0.4, dimensions.y + 0.6, dimensions.z + 0.25))
		visual.position.x = -dimensions.x * 0.5 + (i + 0.5) * dimensions.x / count
		body.add_child(visual)

func _log(p: Vector3) -> void:
	p.y = arena.height_at(p.x, p.z)
	var body: Node3D = arena.box(p + Vector3(0, 0.48, 0), Vector3(5.5, 0.96, 0.96), bark_material)
	for child in body.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	body.add_child(Assets.visual("log", Vector3(5.8, 1.15, 1.15)))

func _trail(offset: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-44, 44, 2):
		var x0: float = sin(z * 0.105) * 3.0 if offset == 0 else offset
		var x1: float = sin((z + 2) * 0.105) * 3.0 if offset == 0 else offset
		var a := Vector3(x0 - 1.65, 0.012, z)
		var b := Vector3(x0 + 1.65, 0.012, z)
		var c := Vector3(x1 - 1.65, 0.012, z + 2)
		var d := Vector3(x1 + 1.65, 0.012, z + 2)
		for vertex in [a, b, c, b, d, c]:
			vertex.y += arena.height_at(vertex.x, vertex.z)
			surface.set_uv(Vector2(vertex.x, vertex.z) / 3.5)
			surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	var material := textured_material("forest_leaves_02_diffuse_1k.jpg", "forest_leaves_02_nor_gl_1k.jpg")
	material.albedo_color = Color("aba38b")
	mesh.material_override = material
	arena.add_child(mesh)

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One-metre triangles resolve gullies and contour paths on the new map.
	var step := 1 if arena.map_id == "mountain" else 2
	var width := step if arena.map_id == "mountain" else 4
	for z in range(-84, 84, step):
		for x in range(-64, 64, width):
			var a := Vector3(x, arena.height_at(x, z), z)
			var b := Vector3(x + width, arena.height_at(x + width, z), z)
			var c := Vector3(x, arena.height_at(x, z + step), z + step)
			var d := Vector3(x + width, arena.height_at(x + width, z + step), z + step)
			for vertex in [a, b, c, b, d, c]:
				surface.set_uv(Vector2(vertex.x, vertex.z) / 3.5)
				surface.add_vertex(vertex)
	if arena.map_id == "mountain":
		# Coarser surrounding land hides the arena outline and carries distant peaks.
		for z in range(-232, 132, 4):
			for x in range(-180, 180, 4):
				if x >= -64 and x < 64 and z >= -84 and z < 84:
					continue
				for point in [Vector2(x, z), Vector2(x + 4, z), Vector2(x, z + 4), Vector2(x + 4, z), Vector2(x + 4, z + 4), Vector2(x, z + 4)]:
					surface.set_uv(point / 3.5)
					surface.add_vertex(Vector3(point.x, arena.height_at(point.x, point.y), point.y))
	surface.generate_normals()
	surface.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.name = "MountainSlope"
	mesh.mesh = surface.commit()
	var ground: StandardMaterial3D = textured_material("forest_leaves_02_diffuse_1k.jpg", "forest_leaves_02_nor_gl_1k.jpg")
	ground.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = ground
	if arena.map_id == "mountain":
		var terrain_material := ShaderMaterial.new()
		terrain_material.shader = load("res://assets/forest/mountainside.gdshader")
		terrain_material.set_shader_parameter("forest_floor", ground.albedo_texture)
		terrain_material.set_shader_parameter("rock", load("res://assets/forest/rock_boulder_dry_diff_1k.jpg"))
		mesh.material_override = terrain_material
	arena.add_child(mesh)
	mesh.create_trimesh_collision()

func _legacy_cover() -> void:
	for p in [Vector3(-3.8, 0, 25), Vector3(4.8, 0, 12), Vector3(-5.8, 0, -1), Vector3(4.4, 0, -16), Vector3(-5, 0, -29)]:
		_rock(p, Vector3(2.1, 1.2, 1.6))
	for p in [Vector3(-17, 0, 23), Vector3(17, 0, 7), Vector3(-15, 0, -13), Vector3(19, 0, -27)]:
		_log(p)
	_rock(Vector3(0, 0, 31), Vector3(2.7, 2.4, 1.8))
	for x in [-17, 17]:
		for z in [-24, -31, -38]:
			_rock(Vector3(x, 0, z), Vector3(2.2, 3.0, 3.5))
	for p in [Vector3(-10, 0, -39), Vector3(10, 0, -39)]:
		_rock(p, Vector3(1.4, 1.2, 0.8))

func _mountain_paths() -> void:
	for edge in Mountain.EDGES:
		_path_strip(Mountain.NESTS[edge.x], Mountain.NESTS[edge.y], 1.4)
	for route in [Mountain.WEST, Mountain.EAST]:
		for i in range(1, route.size()):
			_path_strip(route[i - 1], route[i], 1.15)

func _stealth_thickets() -> void:
	# Actual imported bushes screen the quiet climbs. Gaps remain between
	# patches; they are visual concealment and do not stop bullets or movement.
	var routes: Array = [Mountain.WEST, Mountain.EAST,
		[Mountain.NESTS[0], Mountain.NESTS[1]],
		[Mountain.NESTS[6], Mountain.NESTS[5]],
		[Mountain.NESTS[2], Mountain.NESTS[3]]]
	for route in routes:
		for leg in range(1, route.size()):
			var a: Vector3 = route[leg - 1]
			var b: Vector3 = route[leg]
			var count := maxi(1, floori(Vector2(b.x - a.x, b.z - a.z).length() / 4.6))
			for i in range(count):
				var point := a.lerp(b, (i + 0.5) / count)
				_thicket(point)
	for nest in Mountain.NESTS:
		_thicket(nest + Vector3(2.8, 0, -3.5))

func _thicket(point: Vector3) -> void:
	point.y = arena.height_at(point.x, point.z)
	bush_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.7, 1.3, 1.7)), point + Vector3.UP * 0.9))
	arena.concealment.append(Vector4(point.x, point.y + 0.9, point.z, 1.4))

func _mountain_edges() -> void:
	# Broad, irregular outcrops replace the old row of thin rock fence posts.
	for side in [-1.0, 1.0]:
		for z in range(-44, 45, 8):
			var x: float = side * (38.5 + sin(z * 0.19) * 0.45)
			_rock(Vector3(x, 0, z), Vector3(3.8, 3.6 + sin(z * 0.31) * 0.7, 5.0))
	for z in [-48.0, 48.0]:
		for x in range(-32, 33, 9):
			_rock(Vector3(x, 0, z + sin(x * 0.25) * 0.4), Vector3(5.2, 3.5 + cos(x * 0.21), 3.5))

func _path_strip(a: Vector3, b: Vector3, half_width: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * half_width
	var steps := ceili(a.distance_to(b))
	for i in range(steps):
		var start := a.lerp(b, float(i) / steps)
		var finish := a.lerp(b, float(i + 1) / steps)
		for point in [start - side, finish - side, start + side, start + side, finish - side, finish + side]:
			point.y = arena.height_at(point.x, point.z) + 0.025
			surface.set_uv(Vector2(point.x, point.z) / 2.5)
			surface.add_vertex(point)
	surface.generate_normals()
	surface.generate_tangents()
	var visual := MeshInstance3D.new()
	visual.name = "ContourTrail"
	visual.mesh = surface.commit()
	var material := textured_material("forest_leaves_02_diffuse_1k.jpg", "forest_leaves_02_nor_gl_1k.jpg")
	material.albedo_color = Color("91836b")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	arena.add_child(visual)

func _timber(a: Vector3, b: Vector3, thickness: float, collide: bool = false) -> void:
	var body: Node3D = StaticBody3D.new() if collide else Node3D.new()
	body.position = (a + b) * 0.5
	arena.add_child(body)
	body.look_at(b, Vector3.RIGHT if absf((b - a).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	var visual := MeshInstance3D.new()
	visual.mesh = Assets.mesh_fit("log", Vector3(thickness, thickness, a.distance_to(b)))
	body.add_child(visual)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(thickness, thickness, a.distance_to(b))
		shape.shape = box
		body.add_child(shape)

func _mountain_cover() -> void:
	for i in range(Mountain.NESTS.size()):
		var nest: Vector3 = Mountain.NESTS[i]
		var marker := Marker3D.new()
		marker.name = "Outlook_%d" % i
		marker.position = nest
		marker.set_meta("outlook", Mountain.NAMES[i])
		arena.add_child(marker)
		# Imported logs form a low breastwork: crouched concealment, standing view.
		for layer in range(3):
			_timber(nest + Vector3(-1.1, 0.22 + layer * 0.36, 0.8), nest + Vector3(1.1, 0.22 + layer * 0.36, 0.8), 0.39, true)
		arena.solids.append(Rect2(nest.x - 1.7, nest.z + 0.1, 3.4, 1.4))
		# Rock shoulder screens the rear from neighbouring overlooks, leaving two exits.
		_rock(nest + Vector3(-3.5, 0, -2.6), Vector3(0.9, 1.8, 1.2))
		# Three timber crow's nests project from naturally elevated rock shoulders.
		if i in [1, 2, 5]:
			for x in [-2.3, 2.3]:
				for z in [-2.0, 3.6]:
					var top := nest + Vector3(x, 0.05, z)
					var bottom := Vector3(top.x, minf(nest.y - 3.5, arena.height_at(top.x, top.z) - 0.2), top.z)
					_timber(bottom, top + Vector3.UP * 2.4, 0.25)
				_timber(nest + Vector3(x, -2.0, -2), nest + Vector3(x, 0, 3.6), 0.18)
			# Closely spaced authored logs make a walkable deck flush with the spur.
			for plank in range(24):
				var z := -2.2 + plank * 0.25
				_timber(nest + Vector3(-2.3, -0.09, z), nest + Vector3(2.3, -0.09, z), 0.22)
			# A continuous floor avoids individual logs catching the capsule.
			var floor_body := StaticBody3D.new()
			floor_body.position = nest + Vector3(0, -0.075, 0.8)
			var collision := CollisionShape3D.new()
			var floor_shape := BoxShape3D.new()
			floor_shape.size = Vector3(4.8, 0.15, 6.4)
			collision.shape = floor_shape
			floor_body.add_child(collision)
			arena.add_child(floor_body)
			_timber(nest + Vector3(-2.3, 2.4, -2), nest + Vector3(2.3, 2.4, -2), 0.24)
			_timber(nest + Vector3(-2.3, 2.4, 3.6), nest + Vector3(2.3, 2.4, 3.6), 0.24)
			# Weathered log roof gives each stand a recognizable silhouette.
			for plank in range(20):
				var x := -2.4 + plank * 0.25
				_timber(nest + Vector3(x, 2.5, -2.3), nest + Vector3(x, 2.5, 3.9), 0.30)
	for point in [Vector3(-13, 0, 26), Vector3(7, 0, 21), Vector3(-12, 0, 8), Vector3(9, 0, -3), Vector3(-7, 0, -15), Vector3(15, 0, -15), Vector3(0, 0, -22)]:
		if not Mountain.clear_route(point, 3):
			_rock(point, Vector3(2.0, 1.5, 1.4))
	arena.forest_details["Outlooks"] = 7
	if arena.map_revision in ["ridge_v2", "ridge_v3"]:
		# Moss is an eastern forward watch, not a view of both lower climbs.
		_rock(Mountain.NESTS[6] + Vector3(-2.7, 0, 0), Vector3(1.1, 1.6, 2.2))
		# Saddle remains a screened transfer hub; side peeks retain firing lanes.
		_rock(Mountain.NESTS[3] + Vector3(0, 0, 2.8), Vector3(1.2, 1.7, 1.0))
		# East crag's south-west shoulder limits sweeping the whole high contour.
		_rock(Mountain.NESTS[4] + Vector3(-2.7, 0, 1.9), Vector3(1.0, 1.6, 1.1))
		arena.forest_details["Outlook shoulder screens"] = 3

func _batch(title: String, mesh: Mesh, material: Material, transforms: Array, shadows: bool = true) -> void:
	var patches: Dictionary = {}
	for transform in transforms:
		var patch := Vector2i(floori(transform.origin.x / 24), floori(transform.origin.z / 24))
		if not patches.has(patch):
			patches[patch] = []
		patches[patch].append([transform, Color.WHITE.darkened(rng.randf_range(0, 0.22))])
	if material is StandardMaterial3D:
		material.vertex_color_use_as_albedo = true
	var family := Node3D.new()
	family.name = title
	arena.add_child(family)
	for patch in patches:
		var items: Array = patches[patch]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = mesh
		instances.instance_count = items.size()
		for i in range(items.size()):
			instances.set_instance_transform(i, items[i][0])
			instances.set_instance_color(i, items[i][1])
		var node := MultiMeshInstance3D.new()
		node.name = "%d_%d" % [patch.x, patch.y]
		node.multimesh = instances
		node.material_override = material
		node.extra_cull_margin = 0.25
		if not shadows:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = 48
		family.add_child(node)
