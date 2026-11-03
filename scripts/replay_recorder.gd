extends Node

signal finished
const Codec = preload("res://scripts/replay_codec.gd")
var game: Node3D
var tick: int = 0
var limit: int = 36000
var last_actor: int = 0
var scene: int = -1
var previous_phase: String = ""
var data: Dictionary
var completed := false
var ids: Array = [1, 2]

func setup(subject: Node3D, seconds: float = 600.0) -> void:
	game = subject
	ids = [1, game.guest_id]
	limit = roundi(seconds * Codec.HZ)
	process_physics_priority = 100
	data = {"format": Codec.FORMAT, "version": Codec.VERSION, "hz": Codec.HZ, "sample_hz": 20, "level": game.selected_level, "ticks": limit, "headless": DisplayServer.get_name() == "headless", "seed": game.duel_seed, "frames": [], "events": [], "scenes": [], "rounds": []}
	data.actors_kind = "players" if game.mode == "online" else "bots"
	data.ruleset_id = game.ruleset_id
	data.build_id = game.Rules.BUILD_ID
	data.map_revision = game.arena.map_revision
	data.environment_id = game.environment_id
	data.pairs_to_play = game.pairs_to_play
	game.gameplay_event.connect(_event)
	_sample()

func _physics_process(_delta: float) -> void:
	if data.is_empty():
		return
	if not game.players.has(ids[0]) or not game.players.has(ids[1]):
		finish()
		return
	tick += 1
	var fresh := _scene()
	if tick % 3 == 0 or fresh or tick == limit:
		_sample()
	if game.phase in ["round_over", "match_over"] and previous_phase == "playing":
		var sniper = game.players[ids[0]] if game.players[ids[0]].role == "sniper" else game.players[ids[1]]
		var record := {"scene": scene, "round": game.round_index + 1, "end_tick": tick, "seconds": snappedf(game.round_elapsed(), 0.01), "winner": slot(game.winner_id), "role": game.players[game.winner_id].role if game.winner_id != 0 else "draw", "result": game.result_text, "sniper_sightings": game.bot_brains[sniper.peer_id].sightings if game.bot_brains.has(sniper.peer_id) else 0, "bird_alarms": game.arena.birds.alarm_count if game.arena.birds else 0}
		data.rounds.append(record)
		print("RECORDED_ROUND ", JSON.stringify(record))
	previous_phase = game.phase
	if tick >= limit or (data.actors_kind == "players" and game.phase == "match_over"):
		finish()

func finish() -> void:
	if completed:
		return
	completed = true
	set_physics_process(false)
	if game.gameplay_event.is_connected(_event):
		game.gameplay_event.disconnect(_event)
	if not data.events.is_empty():
		tick = maxi(tick, int(data.events[-1].t))
	if game.players.has(ids[0]) and game.players.has(ids[1]) and data.frames[-1].t < tick:
		_sample()
	data.ticks = int(data.frames[-1].t)
	finished.emit()

func _scene() -> bool:
	var identity: int = game.players[ids[0]].get_instance_id()
	if identity == last_actor:
		return false
	last_actor = identity
	scene += 1
	data.scenes.append({"index": game.round_index, "t": tick, "roles": [game.players[ids[0]].role, game.players[ids[1]].role]})
	return true

func _sample() -> void:
	_scene()
	var wildlife = game.arena.get_node_or_null("Wildlife")
	data.frames.append({"t": tick, "r": scene, "phase": game.phase, "clock": game.round_time, "transition": maxf(0, game.transition_time), "scores": [game.scores[ids[0]], game.scores[ids[1]]], "winner": slot(game.winner_id), "result": game.result_text, "actors": [Codec.actor_state(game.players[ids[0]]), Codec.actor_state(game.players[ids[1]])], "brains": [brain(ids[0]), brain(ids[1])], "wild": wildlife.motion_time if wildlife else 0.0, "birds": game.arena.birds.visual_time if game.arena.birds else 0.0})
	data.frames[-1].systems = {"field_clock": game.field.clock, "relay": game.relay.rules.snapshot()}
	if game.phase in ["round_over", "match_over"]:
		data.frames[-1].review = game.round_review.duplicate(true)

func _event(kind: String, values: Array) -> void:
	_scene()
	values = values.duplicate(true)
	if kind == "attack":
		values[0] = slot(int(values[0]))
		values[4] = slot(int(values[4]))
	elif kind == "reload": values[0] = slot(int(values[0]))
	elif kind == "pebble_throw": values[1] = slot(int(values[1]))
	data.events.append({"t": mini(tick + 1, limit), "r": scene, "kind": kind, "v": values})

func save(path: String) -> String:
	var error: String = Codec.validate(data)
	if error:
		return error
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return "Could not create recording."
	file.store_string(JSON.stringify(data))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return "Could not finish recording."
	return ""

func slot(peer_id: int) -> int:
	return 0 if peer_id == 0 else ids.find(peer_id) + 1

func brain(peer_id: int) -> Array:
	var controller = game.bot_brains.get(peer_id)
	return [controller.state, controller.sightings] if controller else ["Player", 0]
