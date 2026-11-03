extends SceneTree

const Assets = preload("res://scripts/model_assets.gd")
var checks := 0
var failures := 0
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for key in Assets.PATHS:
		check(ResourceLoader.exists(Assets.path(key)), "sourced model is packaged: " + key)
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_replay()
	game.paused = true
	game.replay.seek(55)
	await process_frame
	var actor = game.players[1]
	var rig: Skeleton3D = actor.visual.skeleton
	check(rig.get_bone_count() > 50, "human uses the imported skinned skeleton")
	check(actor.visual.body_animation.has_animation("Crouch_Fwd"), "human has retargeted crouched locomotion")
	var thigh: int = rig.find_bone("mixamorig_RightUpLeg")
	Assets.animation_at(actor.visual.body_animation, "Walk", 0.13)
	var a := rig.get_bone_pose_rotation(thigh)
	Assets.animation_at(actor.visual.body_animation, "Walk", 0.49)
	check(a.angle_to(rig.get_bone_pose_rotation(thigh)) > 0.05, "walk animation actually moves the imported leg bones")
	Assets.animation_at(actor.visual.body_animation, "Idle", 0.2)
	var standing := rig.get_bone_pose_position(0).y
	Assets.animation_at(actor.visual.body_animation, "Crouch_Idle", 0.2)
	check(rig.get_bone_pose_position(0).y < standing - 0.15, "crouch lowers the skeleton without squashing the character")
	var arm_surfaces := 0
	for part in Assets.parts(actor.visual.arms):
		if part.node.visible:
			arm_surfaces += part.node.mesh.get_surface_count()
	check(arm_surfaces > 0 and actor.visual.arms.has_meta("asset_source"), "first-person hand is extracted from the sourced character")
	for key in ["rifle", "handgun", "knife"]:
		var model := Assets.scene(key)
		check(Assets.bounds(model).size.is_finite(), "weapon import has finite geometry: " + key)
		check(Assets.parts(model)[0].node.get_active_material(0) is StandardMaterial3D, "weapon has a lit material: " + key)
		model.free()
	var animals = game.arena.get_node("Wildlife")
	for walker in animals.walkers:
		check(walker.skeleton != null and walker.animation.has_animation(walker.walk), "wildlife uses authored skeletal animation: " + walker.species)
	var walker: Dictionary = animals.walkers[0]
	walker.phase = 6.0
	animals._update_animal(walker, 0.05)
	var poses: Array[Quaternion] = []
	for bone in range(walker.skeleton.get_bone_count()):
		poses.append(walker.skeleton.get_bone_pose_rotation(bone))
	animals._update_animal(walker, 0.21)
	var changed := false
	for bone in range(poses.size()):
		changed = changed or poses[bone].angle_to(walker.skeleton.get_bone_pose_rotation(bone)) > 0.01
	check(changed, "walking wildlife deforms its imported skeleton")
	check(game.arena.birds.bird_models.size() == game.arena.birds.bird_positions.size(), "every bird clue has an imported crow visual")
	game.select_level("yard")
	var mesh := Assets.mesh_fit("yard_floor", Vector3(72, 0.5, 90))
	check(mesh.get_aabb().size.is_finite(), "flat floor import stays finite when fitted to the existing collider")
	check(Assets.mesh_fit("yard_container", Vector3(6, 3.7, 12)).has_meta("asset_source"), "yard uses the sourced shipping container")
	game.queue_free()
	await process_frame
	print("MODEL_ASSETS_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
