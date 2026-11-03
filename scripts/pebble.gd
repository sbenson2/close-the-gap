extends Node3D

const Assets = preload("res://scripts/model_assets.gd")
var game: Node3D
var serial: int
var velocity := Vector3.ZERO
var age := 0.0
var excluded: Array[RID] = []

func setup(owner_game: Node3D, number: int, origin: Vector3, launch: Vector3, ignore: Array[RID]) -> void:
	game = owner_game
	serial = number
	position = origin
	velocity = launch
	excluded = ignore
	add_child(Assets.visual("pebble", Vector3(0.09, 0.07, 0.09)))

func _physics_process(delta: float) -> void:
	if game.mode == "replay" or game.paused or game.phase != "playing":
		return
	age += delta
	var next := position + velocity * delta + Vector3.DOWN * 9 * delta * delta
	velocity.y -= 18 * delta
	if game.is_authority():
		var query := PhysicsRayQueryParameters3D.create(position, next, 3, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() or age > 4:
			game.finish_pebble(serial, hit.position if not hit.is_empty() else next)
			return
	position = next
	rotation += Vector3(4, 2, 3) * delta
