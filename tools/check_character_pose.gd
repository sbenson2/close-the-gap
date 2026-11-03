extends SceneTree
const Assets = preload("res://scripts/model_assets.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for key in ["rifle", "handgun"]:
		var source := Assets.scene(key)
		var baked := Assets.bake(source)
		var bounds := baked.get_aabb()
		for side in [-1, 1]:
			var box := AABB()
			var first := true
			for surface in range(baked.get_surface_count()):
				var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for v in vertices:
					if (v.z - bounds.get_center().z) * side < bounds.size.z * 0.35:
						continue
					box = AABB(v, Vector3.ZERO) if first else box.expand(v)
					first = false
			print("WEAPON_END key=%s side=%d bounds=%s" % [key, side, box])
		source.free()
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	game.start_replay()
	game.paused = true
	game.replay.seek(55)
	for id in [1, 2]:
		var actor = game.players[id]
		actor.visual.update(0)
		var rig: Skeleton3D = Assets.find_skeleton(actor.visual.arms)
		var hands := {}
		for side in ["Right", "Left"]:
			var bone := rig.find_bone("mixamorig_" + side + "Hand")
			var world: Vector3 = rig.global_transform * rig.get_bone_global_pose(bone).origin
			hands[side] = str(actor.camera.global_transform.affine_inverse() * world)
		print("POSE role=%s body=%s fps=%s hands=%s" % [actor.role, actor.visual.body_animation.current_animation, actor.visual.arm_animation.current_animation, hands])
	game.queue_free()
	await process_frame
	quit()
