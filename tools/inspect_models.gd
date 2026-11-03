extends SceneTree

var box := AABB()
var initialized := false
var meshes := 0
var triangles := 0
var materials: Array[String] = []
var skeletons: Array[Dictionary] = []
var clips: Array[String] = []

func visit(node: Node, parent: Transform3D) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		meshes += 1
		var bounds: AABB = transform * node.get_aabb()
		box = box.merge(bounds) if initialized else bounds
		initialized = true
		for surface in range(node.mesh.get_surface_count()):
			var data: Array = node.mesh.surface_get_arrays(surface)
			triangles += data[Mesh.ARRAY_INDEX].size() / 3 if data[Mesh.ARRAY_INDEX] != null and not data[Mesh.ARRAY_INDEX].is_empty() else data[Mesh.ARRAY_VERTEX].size() / 3
			var mat: Material = node.get_active_material(surface)
			if mat:
				materials.append(mat.resource_name)
	if node is Skeleton3D:
		var bones: Array[String] = []
		var rest: Dictionary = {}
		for i in range(node.get_bone_count()):
			var title: String = node.get_bone_name(i)
			bones.append(title)
			if any_named(title, ["Hips", "pelvis", "hand_l", "LeftHand", "Head", "head", "upperarm_l", "LeftArm", "thigh_l", "LeftUpLeg"]):
				var pose: Transform3D = node.get_bone_global_rest(i)
				rest[title] = {"origin": [pose.origin.x, pose.origin.y, pose.origin.z], "rotation": str(pose.basis.get_rotation_quaternion())}
		skeletons.append({"path": str(node.name), "bones": bones, "rest": rest})
	if node is AnimationPlayer:
		for clip in node.get_animation_list():
			clips.append(clip)
	for child in node.get_children():
		visit(child, transform)

func any_named(value: String, endings: Array) -> bool:
	for ending in endings:
		if value == ending or value.ends_with(":" + ending):
			return true
	return false

func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	for path in paths:
		box = AABB()
		initialized = false
		meshes = 0
		triangles = 0
		materials.clear()
		skeletons.clear()
		clips.clear()
		var scene: Node = load(path).instantiate()
		visit(scene, Transform3D.IDENTITY)
		print(JSON.stringify({"path": path, "bounds": str(box), "meshes": meshes, "triangles": triangles, "materials": materials, "skeletons": skeletons, "animations": clips}))
		scene.free()
	quit()
