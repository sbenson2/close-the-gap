extends RefCounted

const Assets = preload("res://scripts/model_assets.gd")
const MOTIONS: AnimationLibrary = preload("res://assets/models/characters/diesel_motions.res")
static var arm_meshes: Dictionary = {}
var actor: Node3D
var body: Node3D
var skeleton: Skeleton3D
var body_animation: AnimationPlayer
var arms: Node3D
var arm_animation: AnimationPlayer
var arm_skeleton: Skeleton3D
var right_hand: int = -1
var death_time: float = 0.0
var was_alive := true

func setup(subject: Node3D) -> void:
	actor = subject
	body = _human()
	actor.model.add_child(body)
	skeleton = Assets.find_skeleton(body)
	right_hand = skeleton.find_bone("mixamorig_RightHand")
	body_animation = _player(body)

func _human() -> Node3D:
	var human := Assets.scene("character")
	var box := Assets.bounds(human)
	human.scale *= 1.8 / box.size.y
	human.position.y = -box.position.y * human.scale.y
	human.rotation.y = PI
	for part in Assets.parts(human):
		var node: MeshInstance3D = part.node
		if "eyebrow" in node.name.to_lower() and not "mid_" in node.name.to_lower():
			node.visible = false
	return human

func _player(parent: Node3D) -> AnimationPlayer:
	var result := AnimationPlayer.new()
	result.name = "GameplayAnimation"
	result.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	parent.add_child(result)
	result.root_node = NodePath("..")
	result.add_animation_library("", MOTIONS)
	return result

func setup_arms() -> void:
	arms = _human()
	arms.name = "FirstPersonArms"
	arms.position += Vector3(0.04, -1.43, -0.3)
	actor.weapon.add_child(arms)
	for part in Assets.parts(arms):
		var node: MeshInstance3D = part.node
		var original: Mesh = node.mesh
		if not node.skin:
			node.hide()
			continue
		var key := original.get_instance_id()
		if not arm_meshes.has(key):
			arm_meshes[key] = _arms_only(original, node.skin)
		var filtered: ArrayMesh = arm_meshes[key]
		if filtered.get_surface_count() == 0:
			node.hide()
		else:
			node.mesh = filtered
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm_animation = _player(arms)
	arm_skeleton = Assets.find_skeleton(arms)

func _arms_only(original: Mesh, skin: Skin) -> ArrayMesh:
	var result := ArrayMesh.new()
	var allowed: Dictionary = {}
	for index in range(skin.get_bind_count()):
		var title := String(skin.get_bind_name(index))
		if title.is_empty() and skin.get_bind_bone(index) >= 0:
			title = skeleton.get_bone_name(skin.get_bind_bone(index))
		if "RightForeArm" in title or "RightHand" in title:
			allowed[index] = true
	for surface in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			continue
		var count: int = bones.size() / vertices.size()
		var selected := PackedByteArray()
		selected.resize(vertices.size())
		for vertex in range(vertices.size()):
			var influence := 0.0
			for slot in range(count):
				var offset := vertex * count + slot
				if allowed.has(bones[offset]):
					influence += weights[offset]
			selected[vertex] = 1 if influence >= 0.55 else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var filtered := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			if selected[indices[i]] and selected[indices[i + 1]] and selected[indices[i + 2]]:
				filtered.append_array(indices.slice(i, i + 3))
		if filtered.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = filtered
		var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if count == 8 else 0
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		result.surface_set_material(result.get_surface_count() - 1, original.surface_get_material(surface))
	result.set_meta("asset_source", Assets.path("character"))
	return result

func _grip(side: String) -> void:
	var prefix := "mixamorig_" + side + "Hand"
	var index := arm_skeleton.find_bone(prefix + "Index1")
	var pinky := arm_skeleton.find_bone(prefix + "Pinky1")
	var axis: Vector3 = (arm_skeleton.get_bone_global_pose(index).origin - arm_skeleton.get_bone_global_pose(pinky).origin).normalized()
	var direction := 1.0 if side == "Right" else -1.0
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in range(1, 4):
			var bone := arm_skeleton.find_bone(prefix + finger + str(joint))
			var local: Vector3 = arm_skeleton.get_bone_global_pose(bone).basis.inverse() * axis
			var degrees: float = [35.0, 55.0, 35.0][joint - 1]
			if finger == "Index":
				degrees *= 0.6
			arm_skeleton.set_bone_pose_rotation(bone, arm_skeleton.get_bone_pose_rotation(bone) * Quaternion(local.normalized(), deg_to_rad(degrees) * direction))

func update(delta: float) -> void:
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var moving := speed > 0.2
	var clock: float = actor.game.replay.position if actor.game.mode == "replay" else Time.get_ticks_msec() / 1000.0
	var clip := "Pistol_Idle" if actor.role == "sniper" else "Idle"
	var time: float = clock
	if actor.crouched:
		clip = "Crouch_Fwd" if moving else "Crouch_Idle"
	elif moving:
		clip = "Sprint" if speed > 6.5 else ("Jog_Fwd" if speed > 4 else "Walk")
	if moving:
		time = actor.motion_time / 5.0
	if not actor.alive:
		if was_alive:
			death_time = 0.0
		death_time += delta
		clip = "Death01"
		time = death_time
	was_alive = actor.alive
	Assets.animation_at(body_animation, clip, time, clip != "Death01")
	if arm_animation:
		Assets.animation_at(arm_animation, "Pistol_Idle", clock)
		_grip("Right")
		var hand_local: Vector3 = actor.weapon.global_transform.affine_inverse() * arm_skeleton.global_transform * arm_skeleton.get_bone_global_pose(right_hand).origin
		var grip := Vector3(0.25, -0.35, -0.55) if actor.role == "sniper" else (Vector3(0.3, -0.35, -0.48) if actor.active_weapon == "knife" else Vector3(0.28, -0.28, -0.55))
		arms.position += grip - hand_local
		arms.visible = actor.alive and not actor.scoped
	var hand: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(right_hand).origin
	var aim: Basis = actor.global_basis * Basis(Vector3.RIGHT, actor.aim.y)
	if actor.role == "sniper":
		actor.remote_rifle.global_transform = Transform3D(aim, hand + aim * Vector3(0, 0.03, -0.24))
		actor.glint.global_position = hand + aim * Vector3(0, 0.15, -0.68)
	else:
		actor.remote_knife.global_transform = Transform3D(aim * Basis(Vector3.RIGHT, -0.8), hand + aim * Vector3(0, 0.12, -0.03))
		actor.remote_handgun.global_transform = Transform3D(aim, hand + aim * Vector3(0, 0.03, -0.1))
