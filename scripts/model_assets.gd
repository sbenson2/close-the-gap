extends RefCounted

const PATHS := {
	"pine_1": "nature/Pine_1.gltf", "pine_2": "nature/Pine_2.gltf", "pine_3": "nature/Pine_3.gltf",
	"tree_1": "nature/CommonTree_1.gltf", "tree_2": "nature/CommonTree_2.gltf", "tree_3": "nature/CommonTree_3.gltf",
	"dead_tree": "nature/DeadTree_1.gltf", "bush": "nature/Bush_Common.gltf", "flowers": "nature/Bush_Common_Flowers.gltf",
	"fern": "nature/Fern_1.gltf", "grass": "nature/Grass_Common_Short.gltf", "tall_grass": "nature/Grass_Common_Tall.gltf",
	"wispy_grass": "nature/Grass_Wispy_Short.gltf", "plant": "nature/Plant_1.gltf", "clover": "nature/Clover_1.gltf",
	"rock_1": "nature/Rock_Medium_1.gltf", "rock_2": "nature/Rock_Medium_2.gltf", "rock_3": "nature/Rock_Medium_3.gltf",
	"pebble": "nature/Pebble_Round_1.gltf", "mushroom": "nature/Mushroom_Common.gltf",
	"stump": "nature_props/TreeStump_Moss.fbx", "log": "nature_props/WoodLog_Moss.fbx",
	"character": "characters/Diesel.glb", "rifle": "weapons/rifle.glb", "handgun": "weapons/handgun.glb", "knife": "weapons/knife.glb",
	"crow": "birds/glb/crow.glb", "rabbit": "birds/glb/rabbit.glb", "deer": "wildlife/Deer.glb", "stag": "wildlife/Stag.glb", "fox": "wildlife/Fox.glb",
	"yard_crate": "yard/crate.glb", "yard_barrier": "yard/barrier.glb", "yard_wall": "yard/wall.glb",
	"yard_beam": "yard/beam.glb", "yard_pipe": "yard/pipe.glb", "yard_rail": "yard/rail.glb",
	"yard_platform": "yard/platform.glb", "yard_stairs": "yard/stairs.glb", "yard_floor": "yard/floor.glb",
	"yard_deck": "yard/deck.glb", "yard_warehouse": "yard/warehouse.glb", "yard_fixture": "yard/fixture.glb",
	"yard_container": "yard/container.glb"
}
static var scenes: Dictionary = {}
static var meshes: Dictionary = {}

static func path(key: String) -> String:
	return "res://assets/models/" + PATHS[key]

static func scene(key: String) -> Node3D:
	var source := path(key)
	if not scenes.has(source):
		scenes[source] = load(source)
	var result: Node3D = scenes[source].instantiate()
	result.set_meta("asset_source", source)
	return result

static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

static func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animation(child)
		if found:
			return found
	return null

static func parts(node: Node, parent: Transform3D = Transform3D.IDENTITY) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh:
		result.append({"node": node, "transform": transform})
	for child in node.get_children():
		result.append_array(parts(child, transform))
	return result

static func bounds(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for part in parts(node):
		var box: AABB = part.transform * part.node.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

static func bake(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> ArrayMesh:
	var result := ArrayMesh.new()
	for part in parts(node):
		var original: Mesh = part.node.mesh
		for index in range(original.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.append_from(original, index, transform * part.transform)
			var material: Material = part.node.get_active_material(index)
			if material:
				material = material.duplicate()
				if material is StandardMaterial3D:
					material.vertex_color_use_as_albedo = true
			tool.set_material(material)
			tool.commit(result)
	return result

static func mesh_height(key: String, height: float = 1.0, centered: bool = false) -> ArrayMesh:
	return _mesh(key, Vector3.ONE * height, centered, false)

static func mesh_fit(key: String, dimensions: Vector3, centered: bool = true) -> ArrayMesh:
	return _mesh(key, dimensions, centered, true)

static func _mesh(key: String, dimensions: Vector3, centered: bool, fit: bool) -> ArrayMesh:
	var identity := "%s:%s:%s:%s" % [key, dimensions, centered, fit]
	if meshes.has(identity):
		return meshes[identity]
	var original := scene(key)
	var box := bounds(original)
	if fit and (key == "log" or key.begins_with("yard_")) and absf(dimensions.x - dimensions.z) > 0.01 and absf(box.size.x - box.size.z) > 0.01:
		if (dimensions.x > dimensions.z) != (box.size.x > box.size.z):
			original.rotate_y(PI / 2)
			box = bounds(original)
	if key == "yard_stairs":
		var totals := Vector2.ZERO
		var counts := Vector2.ZERO
		for part in parts(original):
			for surface in range(part.node.mesh.get_surface_count()):
				var vertices: PackedVector3Array = part.node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var point: Vector3 = part.transform * vertex
					if point.z < box.position.z + box.size.z * 0.2:
						totals.x += point.y
						counts.x += 1
					elif point.z > box.end.z - box.size.z * 0.2:
						totals.y += point.y
						counts.y += 1
		if totals.x / maxf(counts.x, 1) < totals.y / maxf(counts.y, 1):
			original.rotate_y(PI)
			box = bounds(original)
	var size := Vector3(maxf(box.size.x, 0.0001), maxf(box.size.y, 0.0001), maxf(box.size.z, 0.0001))
	var scale_value: Vector3 = dimensions / size if fit else Vector3.ONE * dimensions.y / size.y
	var anchor := box.get_center()
	if not centered:
		anchor.y = box.position.y
	var basis := Basis.IDENTITY.scaled(scale_value)
	var result := bake(original, Transform3D(basis, -(basis * anchor)))
	for index in range(result.get_surface_count()):
		var material: Material = result.surface_get_material(index)
		if material is StandardMaterial3D and material.albedo_texture and ("Leaves" in material.resource_name or material.resource_name in ["Grass", "Plants", "Flowers"]):
			var breeze := ShaderMaterial.new()
			breeze.shader = load("res://assets/models/foliage.gdshader")
			breeze.set_shader_parameter("albedo_texture", material.albedo_texture)
			breeze.set_shader_parameter("tint", material.albedo_color)
			result.surface_set_material(index, breeze)
	result.set_meta("asset_source", path(key))
	result.resource_name = "Imported_%s" % key
	original.free()
	meshes[identity] = result
	return result

static func visual(key: String, dimensions: Vector3, centered: bool = true) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh_fit(key, dimensions, centered)
	result.set_meta("asset_source", path(key))
	return result

static func animation_at(player: AnimationPlayer, clip: String, time: float, loop: bool = true) -> void:
	if player.current_animation != clip:
		player.play(clip, 0.0)
	var animation := player.get_animation(clip)
	var position := fposmod(time, animation.length) if loop else clampf(time, 0, animation.length)
	player.seek(position, true)
	player.advance(0)
