extends CharacterBody3D

const Rules = preload("res://scripts/rules.gd")
const Assets = preload("res://scripts/model_assets.gd")
const CharacterVisual = preload("res://scripts/character_visual.gd")
var peer_id: int = 1
var role: String = "stalker"
var is_local: bool = false
var has_pov: bool = false
var hit_feedback: float = 0.0
var damage_flash: float = 0.0
var alive: bool = true
var aim := Vector2.ZERO
var command_move := Vector2.ZERO
var command_flags: int = 0
var command_age: float = 0.0
var cooldown: float = 0.0
var health: int = 100
var active_weapon: String = "knife"
var handgun_ammo: int = Rules.HANDGUN_MAGAZINE
var handgun_reserve: int = Rules.HANDGUN_RESERVE
var rifle_ammo: int = Rules.RIFLE_MAGAZINE
var rifle_reserve: int = Rules.RIFLE_RESERVE
var pebbles: int = 0
var throw_remaining: float = 0.0
var binoculars := false
var reflectors := 0
var alarms := 0
var interaction_progress := 0.0
var climbing := false
var climb_progress := 0.0
var reload_remaining: float = 0.0
var last_sequence: int = -1
var crouched: bool = false
var scoped: bool = false
var aiming: bool = false
var motion_time: float = 0.0
var swing: float = 0.0
var recoil: float = 0.0
var foot_clock: float = 0.0
var camera: Camera3D
var head: Node3D
var model: Node3D
var weapon: Node3D
var knife_view: Node3D
var handgun_view: Node3D
var remote_knife: Node3D
var remote_handgun: Node3D
var glint: MeshInstance3D
var game: Node3D
var body_shape: CollisionShape3D
var visual: RefCounted
var remote_rifle: Node3D

func setup(id: int, player_role: String, local: bool, owner_game: Node3D, observer_view: bool = false) -> void:
	peer_id = id
	role = player_role
	active_weapon = "rifle" if role == "sniper" else "knife"
	pebbles = Rules.PEBBLES if role == "stalker" else 0
	reflectors = 1 if role == "stalker" else 0
	alarms = 1 if role == "sniper" else 0
	is_local = local
	has_pov = local or observer_view
	game = owner_game
	name = "Player_%d" % id
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var shape := CollisionShape3D.new()
	body_shape = shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 78
	camera.near = 0.05
	camera.far = 240
	head.add_child(camera)
	camera.current = is_local
	model = Node3D.new()
	add_child(model)
	_build_body()
	model.visible = not is_local
	if has_pov:
		_build_weapon()
	if observer_view:
		model.visible = true
		var body_layer: int = 1 << id
		var weapon_layer: int = 1 << (id + 8)
		var other_weapon_layer: int = 1 << (11 - id)
		_set_layers(model, body_layer)
		_set_layers(weapon, weapon_layer)
		camera.cull_mask = 0xFFFFF & ~(body_layer | other_weapon_layer)

func _set_layers(node: Node, mask: int) -> void:
	if node is VisualInstance3D:
		node.layers = mask
	for child in node.get_children():
		_set_layers(child, mask)

func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.65
	return mat

func part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = mat
	item.position = pos
	parent.add_child(item)
	return item

func _build_body() -> void:
	visual = CharacterVisual.new()
	visual.setup(self)
	if role == "sniper":
		remote_rifle = Assets.visual("rifle", Vector3(0.065, 0.4, 1.14))
		model.add_child(remote_rifle)
		var glint_mat := material(Color("ffe7b1"))
		glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.22)
		glint = part(model, quad, Vector3.ZERO, glint_mat)
		glint.visible = false
	else:
		remote_knife = Assets.visual("knife", Vector3(0.055, 0.35, 0.018))
		model.add_child(remote_knife)
		remote_handgun = Assets.visual("handgun", Vector3(0.038, 0.16, 0.26))
		model.add_child(remote_handgun)
		remote_handgun.visible = false

func _build_weapon() -> void:
	weapon = Node3D.new()
	camera.add_child(weapon)
	if role == "sniper":
		var rifle := Assets.visual("rifle", Vector3(0.065, 0.4, 1.14))
		rifle.position = Vector3(0.25, -0.25, -0.8)
		weapon.add_child(rifle)
	else:
		knife_view = Node3D.new()
		weapon.add_child(knife_view)
		var knife := Assets.visual("knife", Vector3(0.055, 0.35, 0.018))
		knife.position = Vector3(0.3, -0.23, -0.59)
		knife.rotation.x = -0.45
		knife_view.add_child(knife)
		handgun_view = Node3D.new()
		weapon.add_child(handgun_view)
		var handgun := Assets.visual("handgun", Vector3(0.038, 0.16, 0.26))
		handgun.position = Vector3(0.28, -0.205, -0.65)
		handgun_view.add_child(handgun)
		handgun_view.visible = false
	visual.setup_arms()

func equip(kind: String) -> void:
	if not Rules.weapon_allowed(role, kind):
		return
	if active_weapon != kind:
		reload_remaining = 0
	active_weapon = kind
	if knife_view:
		knife_view.visible = kind == "knife"
		handgun_view.visible = kind == "handgun"
	if remote_knife:
		remote_knife.visible = kind == "knife"
		remote_handgun.visible = kind == "handgun"

func start_reload() -> void:
	if active_weapon == "handgun" and reload_remaining <= 0 and handgun_ammo < Rules.HANDGUN_MAGAZINE and handgun_reserve > 0:
		reload_remaining = Rules.RELOAD_SECONDS
	elif active_weapon == "rifle" and Rules.modern(game.ruleset_id) and reload_remaining <= 0 and rifle_ammo < Rules.RIFLE_MAGAZINE and rifle_reserve > 0:
		reload_remaining = Rules.RIFLE_RELOAD_SECONDS

func simulate(delta: float, move: Vector2, flags: int, view: Vector2) -> void:
	if not alive:
		return
	if climbing:
		command_move = Vector2.ZERO
		velocity = Vector3.ZERO
		return
	var observing: bool = role == "sniper" and (flags & 32) != 0 and game.field.enabled
	if binoculars and not observing: cooldown = maxf(cooldown, 0.35)
	binoculars = observing
	aim = view
	rotation.y = aim.x
	head.rotation.x = aim.y
	crouched = (flags & 4) != 0
	body_shape.shape.height = 1.2 if crouched else 1.8
	body_shape.position.y = 0.6 if crouched else 0.9
	aiming = active_weapon != "knife" and (flags & 8) != 0 and not crouched_sprinting(flags) and reload_remaining <= 0 and throw_remaining <= 0 and not binoculars
	scoped = active_weapon == "rifle" and aiming
	var speed := 6.0 if role == "stalker" else 4.4
	if crouched:
		speed = 2.3
	elif (flags & 2) != 0 and not aiming:
		speed = 8.7 if role == "stalker" else 5.8
	if aiming:
		speed = 1.6 if scoped else 2.8
	if reload_remaining > 0 or throw_remaining > 0:
		speed = minf(speed, 2.3)
	if binoculars: speed = minf(speed, 1.8)
	var direction := Basis(Vector3.UP, aim.x) * Vector3(move.x, 0, move.y)
	var weight := minf(delta * (17.0 if is_on_floor() else 5.0), 1.0)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif (flags & 1) != 0 and not crouched:
		velocity.y = 7.1
	else:
		velocity.y = -0.5
	move_and_slide()
	# The role restriction is applied by the same simulation on host and guest.
	if role == "sniper":
		var limited: Vector3 = game.arena.constrain_sniper(position)
		if limited.x != position.x:
			velocity.x = 0
		if limited.z != position.z:
			velocity.z = 0
		position = limited
	if position.y < -10:
		position = game.arena.spawn_for(role)
	command_flags = flags & ~1
	cooldown = maxf(cooldown - delta, 0.0)
	throw_remaining = maxf(0, throw_remaining - delta)
	if reload_remaining > 0:
		reload_remaining = maxf(0, reload_remaining - delta)
		if reload_remaining <= 0 and game.is_authority():
			if active_weapon == "rifle":
				var transfer := mini(Rules.RIFLE_MAGAZINE - rifle_ammo, rifle_reserve)
				rifle_ammo += transfer
				rifle_reserve -= transfer
			else:
				var transfer := mini(Rules.HANDGUN_MAGAZINE - handgun_ammo, handgun_reserve)
				handgun_ammo += transfer
				handgun_reserve -= transfer

func noise_description() -> String:
	# Emission feedback only. Never consult an opponent or their detection state.
	if reload_remaining > 0:
		return "Reload audible nearby"
	if throw_remaining > 0:
		return "Throwing"
	if climbing: return "Climbing handline"
	if binoculars: return "Observing / release B before firing"
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.7 or crouched:
		return "Quiet movement" if speed > 0.7 else "Still"
	return "Loud footfalls" if speed > 6.5 else "Footfalls audible nearby"

func crouched_sprinting(flags: int) -> bool:
	return (flags & 2) != 0 and (flags & 4) == 0

func _process(delta: float) -> void:
	if head == null:
		return
	if game.mode == "replay":
		delta = 0 if game.paused else delta * game.replay.rate
	rotation.y = aim.x
	head.rotation.x = aim.y + recoil * 0.035
	head.position.y = lerpf(head.position.y, 1.08 if crouched else 1.62, minf(delta * 13, 1))
	if glint:
		glint.visible = scoped and alive
	var horizontal := Vector2(velocity.x, velocity.z).length()
	motion_time += delta * horizontal * 1.8
	visual.update(delta)
	hit_feedback = maxf(0, hit_feedback - delta)
	damage_flash = maxf(0, damage_flash - delta)
	# Each peer renders spatial footsteps from replicated movement as well as its own.
	var grounded: bool = is_on_floor() or (not is_local and not game.is_authority() and absf(velocity.y) < 0.8)
	if horizontal > 1.0 and grounded and not crouched and alive and game.phase == "playing" and not game.paused:
		foot_clock -= delta
		if foot_clock <= 0:
			var surface_name: String = game.field.surface(global_position) if game.field.enabled else "gravel"
			var factor: float = game.field.surface_loudness(global_position) if game.field.enabled else 1.0
			game.sound.play_at("step_" + surface_name, global_position, (-15 if is_local else -6) + linear_to_db(maxf(0.1, factor)), not is_local)
			foot_clock = 0.32 if horizontal > 6.5 else 0.48
	swing = maxf(swing - delta * 3.6, 0)
	recoil = maxf(recoil - delta * 5, 0)
	camera.fov = lerpf(camera.fov, 42.0 if binoculars else 23.0 if scoped else (56.0 if aiming else float(game.settings.fov)), minf(delta * 14, 1))
	if not has_pov:
		return
	if weapon:
		weapon.visible = not scoped and not binoculars and not climbing
		var bob_scale: float = 0.0 if game.settings.reduced_motion else 1.0
		var aim_offset := Vector3(-0.28, 0.135, 0.09) if active_weapon == "handgun" and aiming else Vector3.ZERO
		var target_offset := aim_offset + Vector3(sin(motion_time) * 0.009 * bob_scale, absf(cos(motion_time)) * 0.012 * bob_scale - swing * 0.1, swing * -0.48 + recoil * 0.16)
		if reload_remaining > 0:
			target_offset.y -= 0.22
		weapon.position = weapon.position.lerp(target_offset, minf(delta * 18, 1))
		weapon.rotation.z = swing * -0.65 - (0.4 if reload_remaining > 0 else 0.0)

func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.08 if crouched else 1.62, 0)

func direction() -> Vector3:
	return Basis(Vector3.UP, aim.x) * Basis(Vector3.RIGHT, aim.y) * Vector3.FORWARD

func attack_feedback() -> void:
	if active_weapon != "knife":
		recoil = 1 if active_weapon == "rifle" else 0.55
	else:
		swing = 1
