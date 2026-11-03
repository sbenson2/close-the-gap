extends RefCounted

const Assets = preload("res://scripts/model_assets.gd")

var forest: RefCounted
var arena: Node3D
var rng := RandomNumberGenerator.new()
var groups: Dictionary = {}

func build(source: RefCounted) -> void:
	forest = source
	arena = source.arena
	rng.seed = 604991
	_register("MeadowGrass", Assets.mesh_height("wispy_grass"), null)
	_register("TallGrass", Assets.mesh_height("tall_grass"), null)
	_register("WoodlandFerns", Assets.mesh_height("fern"), null)
	_register("BrambleLeaves", Assets.mesh_fit("bush", Vector3(1.5, 1.0, 1.5)), null)
	_register("PineSaplings", Assets.mesh_fit("pine_2", Vector3.ONE, false), null)
	_register("LeafLitter", Assets.mesh_fit("clover", Vector3(0.28, 0.025, 0.28), false), null)
	_register("FallenTwigs", Assets.mesh_fit("log", Vector3(0.04, 0.03, 0.6), false), null)
	_register("MossyStones", Assets.mesh_fit("pebble", Vector3.ONE, false), null)
	_register("TreeRoots", Assets.mesh_fit("stump", Vector3(1.3, 0.25, 1.3), false), null)
	# Keep the established random stream and collision layout: one sourced
	# mushroom now contains its stem and cap, and one stump contains its rings.
	_register("MushroomStems", null, null)
	_register("MushroomCaps", Assets.mesh_height("mushroom", 0.3), null)
	_register("OldStumps", Assets.mesh_fit("stump", Vector3(0.95, 0.65, 0.95)), null)
	_register("StumpRings", null, null)
	for i in range(9600):
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-44, 44))
		var route: bool = forest._clear_route(p, 1.35)
		var patch: float = sin(p.x * 0.34 + cos(p.z * 0.23)) * cos(p.z * 0.29)
		if route and i % 5 != 0:
			continue
		if patch < -0.55 and i % 3 != 0:
			continue
		var size: float = rng.randf_range(0.42, 1.05) if not route else rng.randf_range(0.16, 0.3)
		_spawn("MeadowGrass", p, Vector3(size, size, size))
	for i in range(1100):
		var p := Vector3(rng.randf_range(-33, 33), 0, rng.randf_range(-43, 43))
		if forest._clear_route(p, 1.7):
			continue
		var scale_value: float = rng.randf_range(0.55, 1.2)
		_spawn("WoodlandFerns", p, Vector3.ONE * scale_value)
	for i in range(7200):
		var p := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-44, 44))
		_spawn("LeafLitter", p, Vector3.ONE * rng.randf_range(0.65, 1.7), 0.018)
		if i % 9 == 0:
			_spawn("FallenTwigs", p, Vector3.ONE * rng.randf_range(0.5, 1.8), 0.04)
		if i % 12 == 0 and not forest._clear_route(p, 1.2):
			_spawn("MossyStones", p, Vector3(rng.randf_range(0.15, 0.55), rng.randf_range(0.08, 0.25), rng.randf_range(0.2, 0.6)), 0.03)
	for transform in forest.trunk_transforms:
		var p: Vector3 = transform.origin - Vector3.UP * transform.basis.y.length() * 0.5
		if absf(p.x) > 34 or absf(p.z) > 44:
			continue
		_spawn("TreeRoots", p, Vector3.ONE * rng.randf_range(0.65, 1.15))
		# Understory follows trunks instead of a uniform lawn over every clearing.
		for i in range(2):
			var offset := p + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
			if not forest._clear_route(offset, 2.2):
				_spawn("BrambleLeaves", offset, Vector3.ONE * rng.randf_range(0.45, 0.8), 0.52)
		if rng.randf() < 0.38:
			for i in range(rng.randi_range(2, 5)):
				var offset := p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				var size := Vector3.ONE * rng.randf_range(0.65, 1.3)
				_spawn("MushroomStems", offset, size, size.y * 0.08)
				_spawn("MushroomCaps", offset, size, size.y * 0.16)
	for i in range(100):
		var p := Vector3(rng.randf_range(-33, 33), 0, rng.randf_range(-41, 41))
		if forest._clear_route(p, 3):
			continue
		_spawn("PineSaplings", p, Vector3(0.6, 1.6, 0.6) * rng.randf_range(0.6, 1.15))
	for i in range(28):
		var p := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-37, 37))
		if forest._clear_route(p, 4.0) or not _clear_of_solids(p):
			continue
		_spawn("OldStumps", p, Vector3.ONE, 0.325)
		_spawn("StumpRings", p, Vector3.ONE, 0.655)
		var body := StaticBody3D.new()
		body.position = Vector3(p.x, arena.height_at(p.x, p.z) + 0.325, p.z)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.46
		shape.height = 0.65
		collision.shape = shape
		body.add_child(collision)
		arena.add_child(body)
		arena.solids.append(Rect2(Vector2(p.x - 1.1, p.z - 1.1), Vector2.ONE * 2.2))
	var tall_rng := RandomNumberGenerator.new()
	tall_rng.seed = 192883
	for i in range(100):
		var center := Vector3(tall_rng.randf_range(-32, 32), 0, tall_rng.randf_range(-38, 38))
		if forest._clear_route(center, 3):
			continue
		for j in range(28):
			var point := center + Vector3(tall_rng.randf_range(-1.4, 1.4), 0, tall_rng.randf_range(-1.4, 1.4))
			if forest._clear_route(point, 1.3):
				continue
			_spawn("TallGrass", point, Vector3(tall_rng.randf_range(0.7, 1.1), tall_rng.randf_range(1.4, 2.1), tall_rng.randf_range(0.7, 1.1)))
		arena.concealment.append(Vector4(center.x, arena.height_at(center.x, center.z) + 0.7, center.z, 0.95))
	_flush()

func _clear_of_solids(p: Vector3) -> bool:
	for solid in arena.solids:
		if solid.grow(1.0).has_point(Vector2(p.x, p.z)):
			return false
	return true

func _register(title: String, mesh: Mesh, material: Material) -> void:
	if material is StandardMaterial3D:
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	groups[title] = {"mesh": mesh, "material": material, "patches": {}, "count": 0}

func _spawn(title: String, p: Vector3, scale_value: Vector3, lift: float = 0.0) -> void:
	var yaw := rng.randf_range(0, TAU)
	var dx: float = arena.height_at(p.x + 0.2, p.z) - arena.height_at(p.x - 0.2, p.z)
	var dz: float = arena.height_at(p.x, p.z + 0.2) - arena.height_at(p.x, p.z - 0.2)
	var normal := Vector3(-dx / 0.4, 1, -dz / 0.4).normalized()
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := forward.cross(normal).normalized()
	var basis := Basis(right * scale_value.x, normal * scale_value.y, right.cross(normal).normalized() * scale_value.z)
	p.y = arena.height_at(p.x, p.z) + lift
	var patch := Vector2i(floori(p.x / 24), floori(p.z / 24))
	if not groups[title].patches.has(patch):
		groups[title].patches[patch] = []
	groups[title].patches[patch].append([Transform3D(basis, p), Color.WHITE.darkened(rng.randf_range(0, 0.28))])
	groups[title].count += 1

func _flush() -> void:
	var root := Node3D.new()
	root.name = "ForestDetails"
	arena.add_child(root)
	for title in groups:
		var group: Dictionary = groups[title]
		arena.forest_details[title] = group.count
		if group.mesh == null:
			continue
		for patch in group.patches:
			var items: Array = group.patches[patch]
			var instances := MultiMesh.new()
			instances.transform_format = MultiMesh.TRANSFORM_3D
			instances.use_colors = true
			instances.mesh = group.mesh
			instances.instance_count = items.size()
			for i in range(items.size()):
				instances.set_instance_transform(i, items[i][0])
				instances.set_instance_color(i, items[i][1])
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [title, patch.x, patch.y]
			node.multimesh = instances
			node.material_override = group.material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.extra_cull_margin = 0.2
			if title in ["LeafLitter", "FallenTwigs", "MushroomCaps", "MushroomStems", "MossyStones", "StumpRings"]:
				node.visibility_range_end = 30
			elif title in ["MeadowGrass", "TallGrass", "WoodlandFerns", "TreeRoots"]:
				node.visibility_range_end = 48
			root.add_child(node)
	for title in ["MeadowGrass", "TallGrass", "WoodlandFerns", "BrambleLeaves", "PineSaplings"]:
		arena.foliage_count += groups[title].count

