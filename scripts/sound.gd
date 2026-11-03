extends Node

var muted: bool = false
var streams: Dictionary = {}

func _ready() -> void:
	for kind in ["rifle", "handgun", "knife", "step", "hit", "round", "bolt", "bird_alarm"]:
		streams[kind] = load("res://assets/audio/%s.wav" % kind)
	streams["pebble"] = load("res://assets/audio/pebble.wav")
	streams["reload"] = load("res://assets/audio/reload.wav")
	for kind in ["step_wood", "step_gravel", "step_brush", "step_mud", "alarm", "relay"]:
		streams[kind] = load("res://assets/audio/" + kind + ".wav")

func play_at(kind: String, pos: Vector3, volume: float = 0.0, caption: bool = true) -> void:
	if muted or not streams.has(kind) or DisplayServer.get_name() == "headless":
		return
	var game = get_parent()
	var reach: float = 100 if kind == "rifle" else 55 if kind == "handgun" else 10 * game.field.surface_loudness(pos) if kind.begins_with("step") else 85 if kind == "bird_alarm" else 45 if kind == "alarm" else 18 if kind == "reload" else 30 if kind == "relay" else 24
	var listener = game.local_player()
	if listener and game.field.enabled:
		var from: Vector3 = game.spectator.listener.global_position if game.mode in ["bot_duel","replay"] and game.spectator.listener else listener.eye_position()
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, pos, 1))
		if not hit.is_empty() and hit.position.distance_to(pos) > 0.3:
			reach *= 0.35
			volume -= 10
	if caption and game.ui and listener and listener.eye_position().distance_to(pos) <= reach:
		game.ui.sound_caption(kind, pos, reach)
	var player := AudioStreamPlayer3D.new()
	player.stream = streams[kind]
	player.volume_db = volume
	player.unit_size = 5
	player.max_distance = reach
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	player.global_position = pos
	player.finished.connect(player.queue_free)
	player.play()

func cue(kind: String, volume: float = -8.0) -> void:
	if muted or not streams.has(kind) or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[kind]
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
