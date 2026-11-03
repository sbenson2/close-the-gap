extends SceneTree

const Assets = preload("res://scripts/model_assets.gd")
const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Pistol_Idle", "Sword_Idle", "Death01", "Pistol_Shoot", "Pistol_Reload", "Sword_Attack"]

func _initialize() -> void:
	call_deferred("run")

func weapon(source: String, output: String, texture_prefix: String) -> void:
	var importer := FBXDocument.new()
	var input := FBXState.new()
	assert(importer.append_from_file("res://source_art/weapons/" + source, input) == OK)
	var original: Node3D = importer.generate_scene(input)
	var mesh := Assets.bake(original)
	if not texture_prefix.is_empty():
		var material := StandardMaterial3D.new()
		var base := "res://source_art/weapons/" + texture_prefix
		material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(base + "_Base_Color.png"))
		material.normal_enabled = true
		material.normal_texture = ImageTexture.create_from_image(Image.load_from_file(base + "_Normal.png"))
		material.metallic = 1.0
		material.metallic_texture = ImageTexture.create_from_image(Image.load_from_file(base + "_Metallic.png"))
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.roughness_texture = ImageTexture.create_from_image(Image.load_from_file(base + "_Roughness.png"))
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		for index in range(mesh.get_surface_count()):
			mesh.surface_set_material(index, material)
	else:
		# The creator's FBX references an omitted palette. Keep the authored mesh
		# and restore distinct steel/rubber materials using its blade/handle split.
		var split := ArrayMesh.new()
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var groups: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
			for i in range(0, indices.size(), 3):
				var y: float = (vertices[indices[i]].y + vertices[indices[i + 1]].y + vertices[indices[i + 2]].y) / 3
				var group := 0 if y > 0.5 else 1
				groups[group].append_array(indices.slice(i, i + 3))
			for group in range(2):
				if groups[group].is_empty():
					continue
				var copy := arrays.duplicate()
				copy[Mesh.ARRAY_INDEX] = groups[group]
				split.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy)
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("a8b1b3") if group == 0 else Color("242c2b")
				material.metallic = 0.85 if group == 0 else 0.0
				material.roughness = 0.28 if group == 0 else 0.92
				split.surface_set_material(split.get_surface_count() - 1, material)
		mesh = split
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(node, state) == OK)
	assert(document.write_to_filesystem(state, "res://assets/models/weapons/" + output) == OK)
	node.free()
	original.free()
	print("PREPARED_WEAPON ", output)

func retarget() -> void:
	var target: Node3D = load("res://assets/models/characters/Diesel.glb").instantiate()
	var source: Node3D = load("res://assets/models/characters/motions.glb").instantiate()
	root.add_child(target)
	root.add_child(source)
	var skeleton := Assets.find_skeleton(target)
	var reference := Assets.find_skeleton(source)
	var player := Assets.find_animation(source)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var names := {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head"}
	for side in ["l", "r"]:
		var prefix := "Left" if side == "l" else "Right"
		for pair in [["clavicle", "Shoulder"], ["upperarm", "Arm"], ["lowerarm", "ForeArm"], ["hand", "Hand"], ["thigh", "UpLeg"], ["calf", "Leg"], ["foot", "Foot"], ["ball", "ToeBase"]]:
			names[pair[0] + "_" + side] = prefix + pair[1]
		for finger in ["index", "middle", "pinky", "ring", "thumb"]:
			for joint in range(1, 4):
				names["%s_%02d_%s" % [finger, joint, side]] = prefix + "Hand" + finger.capitalize() + str(joint)
	var mapping: Dictionary = {}
	for title in names:
		var index: int = skeleton.find_bone("mixamorig_" + names[title])
		var origin: int = reference.find_bone(title)
		if index >= 0 and origin >= 0:
			mapping[index] = origin
	var ratio: float = Assets.bounds(target).size.y / Assets.bounds(source).size.y
	var library := AnimationLibrary.new()
	var skeleton_path: String = str(target.get_path_to(skeleton))
	for name in CLIPS:
		var input := player.get_animation(name)
		var animation := Animation.new()
		animation.length = input.length
		animation.loop_mode = input.loop_mode
		var tracks: Dictionary = {}
		for index in mapping:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(skeleton_path + ":" + skeleton.get_bone_name(index)))
			tracks[index] = track
		var hip_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(hip_track, NodePath(skeleton_path + ":mixamorig_Hips"))
		player.play(name, 0.0)
		var count := ceili(input.length * 30)
		for frame in range(count + 1):
			var time: float = minf(input.length, frame / 30.0)
			player.seek(time, true)
			player.advance(0)
			var poses: Array[Quaternion] = []
			for index in range(skeleton.get_bone_count()):
				var parent := skeleton.get_bone_parent(index)
				var parent_rotation := poses[parent] if parent >= 0 else Quaternion.IDENTITY
				var local := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
				var global := parent_rotation * local
				if mapping.has(index):
					var other: int = mapping[index]
					var from_rest := reference.get_bone_global_rest(other).basis.get_rotation_quaternion()
					var from_pose := reference.get_bone_global_pose(other).basis.get_rotation_quaternion()
					var to_rest := skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
					global = from_pose * from_rest.inverse() * to_rest
					local = parent_rotation.inverse() * global
					animation.rotation_track_insert_key(tracks[index], time, local.normalized())
				poses.append(global.normalized())
			var source_hip: int = mapping[0]
			var offset: Vector3 = reference.get_bone_global_pose(source_hip).origin - reference.get_bone_global_rest(source_hip).origin
			animation.position_track_insert_key(hip_track, time, skeleton.get_bone_rest(0).origin + offset * ratio)
		library.add_animation(name, animation)
	assert(ResourceSaver.save(library, "res://assets/models/characters/diesel_motions.res") == OK)
	print("RETARGETED clips=%d bones=%d" % [library.get_animation_list().size(), mapping.size()])
	target.free()
	source.free()

func run() -> void:
	if "--yard-only" in OS.get_cmdline_user_args():
		yard()
		quit()
		return
	weapon("Sniper.fbx", "rifle.glb", "Sniper")
	weapon("Makarov.fbx", "handgun.glb", "Makarov")
	weapon("CombatKnife.fbx", "knife.glb", "")
	if "--weapons-only" in OS.get_cmdline_user_args():
		quit()
		return
	retarget()
	quit()

func save_part(node: Node3D, output: String, material: Material = null) -> void:
	var mesh := Assets.bake(node)
	if material:
		for i in range(mesh.get_surface_count()):
			mesh.surface_set_material(i, material)
	var model := MeshInstance3D.new()
	model.mesh = mesh
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model, state) == OK)
	assert(document.write_to_filesystem(state, "res://assets/models/yard/" + output + ".glb") == OK)
	model.free()
	print("PREPARED_YARD ", output)

func yard() -> void:
	var library: Node3D = load("res://assets/models/yard/industrial_library.glb").instantiate()
	var selection := {"crate": "Box_wood", "barrier": "Roadblock", "wall": "Wall", "beam": "Bridges_support_1", "pipe": "Pipes_vertical_long", "rail": "Pipes_horizontal_long", "platform": "Bridges_1", "stairs": "Bridges_stairs_1", "floor": "Alphalt_Floor", "deck": "Building_2", "warehouse": "Building_5", "fixture": "Ventilation_1"}
	for title in selection:
		var node := library.find_child(selection[title], true, false) as Node3D
		assert(node != null, "Missing industrial model: " + selection[title])
		save_part(node, title)
	library.free()
	var containers: Node3D = load("res://assets/models/yard/containers.gltf").instantiate()
	var container := containers.find_child("ShippingCrate_1", true, false) as Node3D
	assert(container != null)
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = load("res://assets/models/yard/ShippingContainer_albedo.png")
	paint.normal_enabled = true
	paint.normal_texture = load("res://assets/models/yard/ShippingContainer_normal.png")
	paint.metallic = 1.0
	paint.metallic_texture = load("res://assets/models/yard/ShippingContainer_metalness.png")
	paint.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	paint.roughness = 0.78
	save_part(container, "container", paint)
	containers.free()
