extends Node3D

const Forest = preload("res://scripts/forest.gd")
const Wildlife = preload("res://scripts/wildlife.gd")
const Birds = preload("res://scripts/forest_birds.gd")
const Rules = preload("res://scripts/rules.gd")
const Assets = preload("res://scripts/model_assets.gd")
const Mountain = preload("res://scripts/mountainside.gd")
var map_id: String = "yard"
var map_revision: String = "ridge_v3"
var wind_materials: Array[ShaderMaterial] = []
var tree_count: int = 0
var foliage_count: int = 0
var forest_details: Dictionary = {}
var bird_perches := PackedVector3Array()
var birds: Node3D
var concealment: Array[Vector4] = []
var solids: Array[Rect2] = []
var nav := AStarGrid2D.new()
var sniper_nav := AStarGrid2D.new()
var bot_hides: Array[Dictionary] = []
var bot_cover: Array[Dictionary] = []
var mountain_heights: Dictionary = {}
var menu_camera: Camera3D
var steel: StandardMaterial3D
var concrete: StandardMaterial3D
var dark: StandardMaterial3D
var ochre: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	load_level(map_id)

func load_level(level: String) -> void:
	if not Rules.LEVELS.has(level):
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	map_id = level
	solids.clear()
	concealment.clear()
	bot_hides.clear()
	bot_cover.clear()
	mountain_heights.clear()
	tree_count = 0
	foliage_count = 0
	forest_details.clear()
	wind_materials.clear()
	bird_perches.clear()
	birds = null
	rng.seed = 67120
	steel = mat(Color("526973"), 0.4)
	concrete = mat(Color("75878c"))
	dark = mat(Color("293e48"))
	ochre = mat(Color("d2ac6c"))
	_build_environment()
	if is_forest():
		Forest.new().build(self)
	else:
		_build_yard()
	_build_navigation()
	if is_forest():
		var wildlife := Wildlife.new()
		add_child(wildlife)
		wildlife.setup(self, get_parent())
		birds = Birds.new()
		add_child(birds)
		birds.setup(self, get_parent())
	menu_camera = Camera3D.new()
	menu_camera.name = "YardCamera"
	menu_camera.position = Vector3(33, 23, 43)
	menu_camera.fov = 62
	menu_camera.far = 300
	add_child(menu_camera)
	menu_camera.look_at(Vector3(-1, 1.0, -8))
	menu_camera.current = true

func map_title() -> String:
	return Rules.LEVELS[map_id]

func is_forest() -> bool:
	return map_id in ["forest", "mountain"]

func foliage_hides(from: Vector3, to: Vector3) -> bool:
	for volume in concealment:
		if Rules.segment_intersects_sphere(from, to, Vector3(volume.x, volume.y, volume.z), volume.w):
			return true
	return false

func mat(color: Color, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.83
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.3
	return material

func box(pos: Vector3, size: Vector3, material: Material, solid: bool = true, record: bool = true, asset: String = "") -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = pos
	add_child(root)
	var mesh := MeshInstance3D.new()
	if map_id == "yard":
		var key := asset if not asset.is_empty() else _yard_box_asset(size)
		mesh.mesh = Assets.mesh_fit(key, size)
		mesh.set_meta("asset_source", Assets.path(key))
		if mesh.mesh.get_aabb().size.y < 0.001:
			mesh.position.y = size.y * 0.5
		if material is StandardMaterial3D and material.emission_enabled:
			mesh.material_override = material
	else:
		var cube := BoxMesh.new()
		cube.size = size
		mesh.mesh = cube
		mesh.material_override = material
	root.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
		if record and pos.y - size.y * 0.5 < 1.7:
			solids.append(Rect2(Vector2(pos.x - size.x / 2, pos.z - size.z / 2), Vector2(size.x, size.z)).grow(0.65))
	return root

func _yard_box_asset(size: Vector3) -> String:
	if size.y < 1.0 and minf(size.x, size.z) > 3:
		return "yard_floor"
	if size.y > 2 and minf(size.x, size.z) > 5:
		return "yard_deck"
	if size.y > 2 and minf(size.x, size.z) < 1 and maxf(size.x, size.z) > 4:
		return "yard_wall"
	if size.y > maxf(size.x, size.z) * 3:
		return "yard_pipe"
	if size.y < 1 and maxf(size.x, size.z) > 3:
		return "yard_rail"
	return "yard_beam"

func cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Assets.mesh_fit("yard_pipe", Vector3(radius * 2, height, radius * 2))
	mesh.position = pos
	add_child(mesh)
	return mesh

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("536c83")
	sky_mat.sky_horizon_color = Color("b3b8b1")
	sky_mat.ground_bottom_color = Color("344b5c")
	sky_mat.ground_horizon_color = Color("bdc0b5")
	sky_mat.sky_curve = 0.18
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("afc5d0")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("9aaeb4")
	environment.fog_density = 0.005 if map_id == "mountain" else (0.008 if map_id == "forest" else 0.0035)
	if is_forest():
		environment.fog_light_color = Color("81927e")
		environment.ambient_light_color = Color("b7c2a4")
	if map_id == "mountain":
		environment.fog_light_color = Color("8c9fa5")
		environment.ambient_light_color = Color("b9c7cd")
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -38, 0)
	sun.light_color = Color("f4e9d6") if map_id == "mountain" else Color("ffdfb2")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)

func _build_yard() -> void:
	box(Vector3(0, -0.3, 0), Vector3(72, 0.6, 92), mat(Color("4b626b")), true, false)
	for x in [-35, 35]:
		box(Vector3(x, 1.8, 0), Vector3(1, 3.6, 92), concrete)
	for z in [-45, 45]:
		box(Vector3(0, 1.8, z), Vector3(72, 3.6, 1), concrete)
	# Three main sightlines, punctuated by staggered cover.
	container(Vector3(-15, 0, 28), Color("9c5f4b"), true)
	container(Vector3(14, 0, 24), Color("477b7a"), true)
	container(Vector3(-16, 0, 7), Color("456c7b"), false)
	container(Vector3(15, 0, 3), Color("a8814e"), false)
	container(Vector3(-16, 0, -16), Color("9c5f4b"), true)
	container(Vector3(17, 0, -20), Color("477b7a"), true)
	container(Vector3(-27, 0, -5), Color("a8814e"), true)
	container(Vector3(27, 0, 15), Color("456c7b"), true)
	# Crouching cover on center route.
	for p in [Vector3(1, 0, 27), Vector3(-3, 0, 13), Vector3(3, 0, -2), Vector3(-3, 0, -13)]:
		barrier(p)
	for p in [Vector3(-24, 0, 34), Vector3(25, 0, 32), Vector3(-8, 0, -7), Vector3(24, 0, -32), Vector3(-26, 0, -30)]:
		crate(p)
		crate(p + Vector3(1.7, 0, 0))
	# Sniper loading deck, with an open, climbable ramp.
	box(Vector3(0, 1.9, -36), Vector3(15, 3.8, 12), dark)
	box(Vector3(0, 3.84, -36), Vector3(15.5, 0.12, 12.5), concrete, true, false)
	ramp()
	for x in [-11, 11]:
		_side_ramp(x)
		# Side screens conceal the climb; the rear bridge reaches behind the rifle.
		box(Vector3(signf(x) * 8.2, 3.2, -30.5), Vector3(0.5, 6.4, 17), dark)
	box(Vector3(0, 3.79, -40.5), Vector3(26, 0.22, 3), concrete, true, false)
	for x in [-7.4, 7.4]:
		box(Vector3(x, 4.3, -35.5), Vector3(0.2, 0.85, 6), steel, true, false)
	for x in [-5, 5]:
		barrier(Vector3(x, 3.9, -31.3))
	# Warehouse backdrop remains outside the playable boundaries.
	for x in [-49, 49]:
		warehouse(Vector3(x, 0, -20), Vector3(20, 12, 55))
	warehouse(Vector3(0, 0, -61), Vector3(55, 15, 20))
	industrial_prop("building-c", Vector3(-55, 0, 24), 12.0)
	industrial_prop("building-f", Vector3(55, 0, -38), 13.0)
	industrial_prop("chimney-large", Vector3(-40, 0, -64), 16.0)
	industrial_prop("chimney-large", Vector3(37, 0, -68), 12.0)
	for p in [Vector3(-28, 0, -37), Vector3(28, 0, -7)]:
		industrial_prop("detail-tank", p, 5.0)
		box(p + Vector3(0, 0.9, 0), Vector3(4.2, 1.8, 2.5), dark, true).visible = false
	for z in [-35, -8, 20, 40]:
		for x in [-32, 32]:
			lamp(Vector3(x, 0, z))
	# Rails, sleepers and painted lane boundaries.
	for x in [-5.3, -3.9, 4, 5.4]:
		box(Vector3(x, 0.035, 12), Vector3(0.075, 0.07, 54), steel, false)
	for z in range(-14, 39, 2):
		for x in [-4.6, 4.7]:
			box(Vector3(x, 0.01, z), Vector3(2.1, 0.03, 0.2), dark, false)
	for x in [-30, 30]:
		for z in range(-40, 42, 5):
			box(Vector3(x, 0.02, z), Vector3(0.13, 0.025, 2.5), ochre, false)
	# Shipping gantry gives the yard a recognizable silhouette.
	for x in [-22, 22]:
		box(Vector3(x, 8, -6), Vector3(0.8, 16, 0.8), ochre)
		box(Vector3(x, 0.3, -6), Vector3(3, 0.6, 5), dark)
	box(Vector3(0, 15.8, -6), Vector3(45, 1.0, 1.2), ochre)
	box(Vector3(7, 14.6, -6), Vector3(3, 1.7, 2.3), dark, false)
	cylinder(Vector3(7, 11, -6), 0.045, 6, steel)
	label_3d("EAST YARD", Vector3(0, 7, -50.8), 135, Color("ddd0b4"))
	label_3d("04", Vector3(-48, 4, 7.6), 175, Color("dfb46d"))

func container(pos: Vector3, color: Color, longwise: bool) -> void:
	var size := Vector3(6.0, 3.7, 12.0) if longwise else Vector3(11.5, 3.7, 5.6)
	var body := box(pos + Vector3(0, 1.85, 0), size, steel, true, true, "yard_container")
	var visual := body.get_child(0) as MeshInstance3D
	for surface in range(visual.mesh.get_surface_count()):
		var material: StandardMaterial3D = visual.get_active_material(surface).duplicate()
		material.albedo_color = color
		visual.set_surface_override_material(surface, material)
	label_3d("CTG  /  %03d" % rng.randi_range(100, 999), pos + Vector3(-size.x * 0.22, 2.8, size.z / 2 + 0.15), 26, Color("e0d8c8"))

func barrier(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.58, 0), Vector3(3.5, 1.16, 0.85), concrete, true, true, "yard_barrier")

func crate(pos: Vector3) -> void:
	box(pos + Vector3(0, 0.8, 0), Vector3(1.6, 1.6, 1.6), ochre, true, true, "yard_crate")

func warehouse(pos: Vector3, size: Vector3) -> void:
	var visual := Assets.visual("yard_warehouse", size, false)
	visual.position = pos
	add_child(visual)

func industrial_prop(asset: String, pos: Vector3, scale_factor: float) -> void:
	var packed := load("res://assets/industrial/%s.glb" % asset) as PackedScene
	if packed:
		var prop := packed.instantiate() as Node3D
		prop.position = pos
		prop.scale = Vector3.ONE * scale_factor
		add_child(prop)

func lamp(pos: Vector3) -> void:
	cylinder(pos + Vector3(0, 4.3, 0), 0.12, 8.6, steel)
	box(pos + Vector3(0.5, 8.5, 0), Vector3(1.3, 0.14, 0.5), dark, false)
	box(pos + Vector3(0.7, 8.4, 0), Vector3(0.7, 0.04, 0.4), mat(Color("ffe0a3"), 0, true), false)

func label_3d(text: String, pos: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/fonts/Display.ttf")
	label.font_size = font_size
	label.pixel_size = 0.012
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	add_child(label)

func ramp() -> void:
	var verts := PackedVector3Array([
		Vector3(-3, 0, -16), Vector3(3, 0, -16), Vector3(-3, 4.15, -30), Vector3(3, 4.15, -30),
		Vector3(-3, 0, -30), Vector3(3, 0, -30)])
	var indices := [0, 2, 1, 1, 2, 3, 0, 4, 2, 1, 3, 5, 4, 5, 3, 4, 3, 2]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		surface.add_vertex(verts[i])
	surface.generate_normals()
	var mesh := surface.commit()
	var body := StaticBody3D.new()
	add_child(body)
	var visual := MeshInstance3D.new()
	visual.mesh = Assets.mesh_fit("yard_stairs", Vector3(6, 4.15, 14), false)
	visual.position.z = -23
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
func _side_ramp(x: float) -> void:
	# Rise above the bridge's front collision lip, as with the central ramp.
	var vertices := [Vector3(x - 1.5, 0, -26), Vector3(x + 1.5, 0, -26), Vector3(x - 1.5, 4.15, -39), Vector3(x + 1.5, 4.15, -39)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 2, 1, 1, 2, 3]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	add_child(visual)
	visual.create_trimesh_collision()
	visual.hide()
	var stairs := Assets.visual("yard_stairs", Vector3(3, 4.15, 13), false)
	stairs.position = Vector3(x, 0, -32.5)
	add_child(stairs)

func _build_navigation() -> void:
	_build_sniper_navigation()
	nav.clear()
	nav.region = Rect2i(-34, -44, 69, 89)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(-34, 35):
		for z in range(-44, 45):
			var p := Vector2(x, z)
			if map_id == "mountain" and not mountain_walkable(p):
				nav.set_point_solid(Vector2i(x, z))
				continue
			for solid in solids:
				if solid.has_point(p):
					nav.set_point_solid(Vector2i(x, z))
					break
	# The loading deck is reached by the central ramp.
	if map_id != "yard":
		return
	for z in range(-39, -15):
		for x in range(-2, 3):
			nav.set_point_solid(Vector2i(x, z), false)

func _build_sniper_navigation() -> void:
	var bounds := sniper_bounds()
	sniper_nav.clear()
	sniper_nav.region = Rect2i(Vector2i(ceili(bounds.position.x), ceili(bounds.position.y)), Vector2i(floori(bounds.end.x) - ceili(bounds.position.x) + 1, floori(bounds.end.y) - ceili(bounds.position.y) + 1))
	sniper_nav.cell_size = Vector2.ONE
	sniper_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	sniper_nav.update()
	if is_forest():
		for x in range(sniper_nav.region.position.x, sniper_nav.region.end.x):
			for z in range(sniper_nav.region.position.y, sniper_nav.region.end.y):
				if map_id == "mountain" and (not Mountain.sniper_allowed(Vector2(x, z)) or not mountain_walkable(Vector2(x, z))):
					sniper_nav.set_point_solid(Vector2i(x, z))
					continue
				for solid in solids:
					if solid.has_point(Vector2(x, z)):
						sniper_nav.set_point_solid(Vector2i(x, z))
						break

func sniper_bounds() -> Rect2:
	if map_id == "mountain":
		return Rect2(-30, -39, 60, 58)
	return Rect2(-28, -42, 56, 11.5) if map_id == "forest" else Rect2(-6.4, -40.8, 12.8, 9.8)

func mountain_walkable(point: Vector2) -> bool:
	# Match the actual one-metre collision triangles, including the cells
	# touched by the capsule. Cardinal height differences miss diagonal faces.
	for x in [point.x - 1, point.x]:
		for z in [point.y - 1, point.y]:
			var a := height_at(x, z)
			var b := height_at(x + 1, z)
			var c := height_at(x, z + 1)
			var d := height_at(x + 1, z + 1)
			if Vector2(b - a, c - a).length() > 0.85 or Vector2(d - c, d - b).length() > 0.85:
				return false
	return true

func height_at(x: float, z: float) -> float:
	if map_id == "mountain":
		# Grid vertices repeat during mesh generation and triangle navigation.
		# Cache exact integer samples only; moving actor positions stay uncached.
		if x == floorf(x) and z == floorf(z):
			var cell := Vector2i(int(x), int(z))
			if not mountain_heights.has(cell):
				mountain_heights[cell] = Mountain.height(x, z)
			return mountain_heights[cell]
		return Mountain.height(x, z)
	if map_id == "forest":
		return clampf((30.0 - z) * 0.3, 0, 18)
	if absf(x) <= 13 and z >= -42 and z <= -39:
		return 3.9
	if absf(absf(x) - 11) <= 1.5 and z >= -39 and z <= -26:
		return (-26.0 - z) / 13.0 * 4.15
	if absf(x) <= 7.5 and z <= -30 and z >= -42:
		return 3.9
	if absf(x) < 2.1 and z < -16 and z > -30:
		return (-16.0 - z) / 14.0 * 3.9
	return 0

func constrain_sniper(point: Vector3) -> Vector3:
	if map_id == "mountain":
		return Mountain.constrain(point)
	var bounds := sniper_bounds()
	point.x = clampf(point.x, bounds.position.x, bounds.end.x)
	point.z = clampf(point.z, bounds.position.y, bounds.end.y)
	point.y = maxf(point.y, height_at(point.x, point.z))
	return point

func _free_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return cell

func path_to(from: Vector3, to: Vector3, role: String = "stalker") -> PackedVector2Array:
	if role == "sniper":
		var start := constrain_sniper(from)
		var finish := constrain_sniper(to)
		var a := Vector2i(roundi(start.x), roundi(start.z)).clamp(sniper_nav.region.position, sniper_nav.region.end - Vector2i.ONE)
		var b := Vector2i(roundi(finish.x), roundi(finish.z)).clamp(sniper_nav.region.position, sniper_nav.region.end - Vector2i.ONE)
		a = _free_cell(sniper_nav, a)
		b = _free_cell(sniper_nav, b)
		if sniper_nav.is_point_solid(a) or sniper_nav.is_point_solid(b):
			return PackedVector2Array()
		return sniper_nav.get_point_path(a, b)
	var a := Vector2i(clampi(roundi(from.x), -33, 33), clampi(roundi(from.z), -43, 43))
	var b := Vector2i(clampi(roundi(to.x), -33, 33), clampi(roundi(to.z), -43, 43))
	a = _free_cell(nav, a)
	b = _free_cell(nav, b)
	if nav.is_point_solid(a) or nav.is_point_solid(b):
		return PackedVector2Array()
	return nav.get_point_path(a, b)

func spawn_for(role: String) -> Vector3:
	if map_id == "mountain":
		return Mountain.NESTS[3] + Vector3.UP * 0.1 if role == "sniper" else Mountain.SPAWN
	if map_id == "forest":
		var z: float = -36 if role == "sniper" else 38
		return Vector3(0, height_at(0, z) + 0.1, z)
	# Start the stalker behind the southern containers, outside the initial rifle lane.
	return Vector3(0, 3.95, -36) if role == "sniper" else Vector3(-17, 0.1, 38)
