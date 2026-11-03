extends Node3D

signal gameplay_event(kind: String, values: Array)

const Rules = preload("res://scripts/rules.gd")
const Player = preload("res://scripts/player.gd")
const Arena = preload("res://scripts/arena.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/sound.gd")
const FriendConnection = preload("res://scripts/network/friend_connection.gd")
const BotController = preload("res://scripts/bot_controller.gd")
const Spectator = preload("res://scripts/spectator.gd")
const ReplayRecorder = preload("res://scripts/replay_recorder.gd")
const ReplayPlayer = preload("res://scripts/replay_player.gd")
const ReplayCodec = preload("res://scripts/replay_codec.gd")
const Pebble = preload("res://scripts/pebble.gd")
const FieldSystems = preload("res://scripts/field_systems.gd")
const RelayController = preload("res://scripts/relay_controller.gd")
const Journal = preload("res://scripts/field_journal.gd")
const DEFAULT_REPLAY = "res://replays/forest-session.json"
const FEATURED_REPLAY = "res://replays/mountain-session.json"
const PRIOR_FEATURED_REPLAY = "res://replays/ai-session.json"
const LATEST_REPLAY = "res://replays/demo-session.json"
const DUEL_REPLAY = "res://replays/duel-session.json"

var arena: Node3D
var ui: Control
var sound: Node
var friends: Node
var connection_kind: String = "lan"
var retry_invite: String = ""
var retry_host: bool = false
var spectator: Control
var auto_watch: bool = false
var match_recording: Node
var saved_match_path := ""
var replay: Node
var bot_brains: Dictionary = {}
var duel_seed: int = 71
var players: Dictionary = {}
var scores: Dictionary = {}
var selected_level: String = "mountain"
var bot_enabled: bool = true
var phase: String = "menu"
var mode: String = "menu"
var local_id: int = 1
var guest_id: int = 2
var round_index: int = 0
var round_time: float = 150.0
var transition_time: float = 0.0
var result_text: String = ""
var winner_id: int = 0
var practice_role: String = "stalker"
var practice_lesson: String = ""
var paused: bool = false
var connecting_time: float = 0.0
var net_clock: float = 0.0
var sequence: int = 0
var settings: Dictionary = {"sensitivity": 0.0023, "volume": 0.7, "invert": false, "reduced_motion": false, "captions": true, "fov": 78.0}
var last_jump: bool = false
var ruleset_id: String = Rules.DUEL
var selected_ruleset: String = Rules.DUEL
var map_revision: String = "ridge_v3"
var environment_id := "breezy"
var selected_environment := "breezy"
var pairs_to_play := 1
var selected_pairs := 1
var field: Node3D
var relay: Node3D
var ready_players: Dictionary = {}
var completed_reviews: Array = []
var ping_ms := 0
var ping_clock := 0.0
var bindings: Dictionary = {}
var rebinding := ""
var journal = Journal.new()
var journal_session := ""
var projectiles: Dictionary = {}
var projectile_serial := 0
var round_events: Array = []
var round_review: Array = []

func _ready() -> void:
	_load_settings()
	journal.open()
	_setup_input()
	arena = Arena.new()
	arena.map_id = selected_level
	add_child(arena)
	sound = Sound.new()
	add_child(sound)
	field = FieldSystems.new()
	add_child(field)
	field.setup(self)
	relay = RelayController.new()
	add_child(relay)
	relay.setup(self)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Interface.new()
	ui.game = self
	layer.add_child(ui)
	spectator = Spectator.new()
	spectator.game = self
	spectator.theme = ui.theme
	layer.add_child(spectator)
	friends = FriendConnection.new()
	add_child(friends)
	friends.invite_ready.connect(func(invite: String): ui.show_friend_lobby(invite))
	friends.status_changed.connect(func(message: String): ui.update_connection(message))
	friends.failed.connect(func(message: String): call_deferred("_friend_failed", message))
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	_apply_settings()
	# Automation arguments are explicit and never enabled by a normal launch.
	var args := OS.get_cmdline_user_args()
	var launch_practice := false
	for arg in args:
		if arg == "--practice-sniper":
			launch_practice = true
			call_deferred("start_practice", "sniper")
		elif arg == "--practice-stalker":
			launch_practice = true
			call_deferred("start_practice", "stalker")
	if (auto_watch or "--watch" in args or "--live" in args) and not launch_practice and "--menu" not in args:
		if (FileAccess.file_exists(FEATURED_REPLAY) or FileAccess.file_exists(DEFAULT_REPLAY)) and "--live" not in args:
			call_deferred("start_featured_replay")
		else:
			call_deferred("start_bot_duel")
	print("CLOSE_THE_GAP_READY")

func _setup_input() -> void:
	var defaults := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "reload": KEY_R, "knife": KEY_1, "handgun": KEY_2, "pebble": KEY_G, "map": KEY_TAB, "interact": KEY_E, "observe": KEY_B, "reflector": KEY_Q, "alarm": KEY_T, "guide": KEY_F1}
	for action in defaults:
		if not bindings.has(action): bindings[action] = defaults[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, key)
	for action in ["attack", "scope"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var button := InputEventMouseButton.new()
			button.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, button)

func _input(event: InputEvent) -> void:
	if not rebinding.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			rebind(rebinding, event.physical_keycode)
		rebinding = ""
		ui.show_controls(phase != "menu")
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("guide"):
		if mode in ["practice", "online"]:
			paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.show_guide(mode in ["practice", "online"])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if phase == "lobby":
			leave_game()
			get_viewport().set_input_as_handled()
			return
		if mode in ["bot_duel", "replay"]:
			paused = not paused
			get_viewport().set_input_as_handled()
			return
		if mode in ["practice", "online"] and phase != "match_over":
			paused = not paused
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			ui.show_pause(paused)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var p = local_player()
		if p and p.alive:
			var sensitivity: float = settings.sensitivity * (0.34 if p.scoped else (0.65 if p.aiming else 1.0))
			p.aim.x = wrapf(p.aim.x - event.relative.x * sensitivity, -PI, PI)
			p.aim.y = clampf(p.aim.y - event.relative.y * sensitivity * (-1 if settings.invert else 1), -1.4, 1.4)
	if event.is_action_pressed("attack") and _can_input():
		request_action("attack")
	if _can_input():
		for action in ["knife", "handgun", "reload", "pebble", "reflector", "alarm"]:
			if event.is_action_pressed(action):
				request_action(action)

func _can_input() -> bool:
	return phase == "playing" and not paused and mode not in ["bot_duel", "replay"]

func is_authority() -> bool:
	return mode != "replay" and (mode != "online" or multiplayer.is_server())

func local_player():
	return players.get(local_id)

func select_level(level: String) -> void:
	if phase != "menu" or not Rules.LEVELS.has(level):
		return
	selected_level = level
	arena.load_level(level)

func start_practice(role: String) -> void:
	_close_network()
	practice_lesson = ""
	ruleset_id = selected_ruleset
	map_revision = "ridge_v3"
	environment_id = selected_environment
	pairs_to_play = selected_pairs
	completed_reviews.clear()
	mode = "practice"
	practice_role = role
	local_id = 1
	guest_id = 2
	round_index = 0 if role == "stalker" else 1
	scores = {1: 0, 2: 0}
	_begin_round()

func start_lesson(role: String) -> void:
	if role not in ["stalker", "sniper"]:
		return
	selected_ruleset = Rules.DUEL
	selected_level = "yard"
	start_practice(role)
	practice_lesson = role
	var subject = players[1]
	var target = players[2]
	subject.position = Vector3(-4, 3.95, -32) if role == "stalker" else Vector3(0, 3.95, -39)
	target.position = Vector3(0, 3.95, -38) if role == "stalker" else Vector3(0, 3.95, -33)
	subject.aim = Vector2(0, 0) if role == "stalker" else Vector2(PI, 0)
	target.aim = Vector2(PI, 0)
	if role == "sniper":
		subject.rifle_ammo = 1

func lesson_hint() -> String:
	if practice_lesson == "stalker":
		return "Static practice target / Ctrl moves quietly. Go around its shoulder for a rear knife attack. G throws a pebble."
	if practice_lesson == "sniper":
		return "Static practice target / R reloads the partial magazine. Right click scopes; left click fires."
	return ""

func start_bot_duel(level: String = "") -> void:
	_close_network()
	practice_lesson = ""
	ruleset_id = selected_ruleset
	map_revision = "ridge_v3"
	environment_id = selected_environment
	pairs_to_play = selected_pairs
	completed_reviews.clear()
	_clear_players()
	if Rules.LEVELS.has(level) and selected_level != level:
		selected_level = level
		arena.load_level(level)
	mode = "bot_duel"
	connection_kind = "offline"
	bot_enabled = true
	local_id = 1
	guest_id = 2
	round_index = 0
	scores = {1: 0, 2: 0}
	_begin_round()

func start_featured_replay() -> void:
	if FileAccess.file_exists(LATEST_REPLAY):
		start_replay(LATEST_REPLAY)
		return
	if FileAccess.file_exists(DUEL_REPLAY):
		start_replay(DUEL_REPLAY)
		return
	var fallback := PRIOR_FEATURED_REPLAY if FileAccess.file_exists(PRIOR_FEATURED_REPLAY) else DEFAULT_REPLAY
	start_replay(FEATURED_REPLAY if FileAccess.file_exists(FEATURED_REPLAY) else fallback)

func start_replay(path: String = DEFAULT_REPLAY) -> void:
	var decoded: Dictionary = ReplayCodec.read(path)
	if decoded.has("error"):
		leave_game("Cannot open recording. " + decoded.error)
		return
	_close_network()
	practice_lesson = ""
	_clear_players()
	mode = "replay"
	connection_kind = "offline"
	local_id = 1
	guest_id = 2
	paused = false
	replay = ReplayPlayer.new()
	add_child(replay)
	replay.setup(self, decoded.data)

func host_friend_game() -> void:
	_close_network()
	connection_kind = "friends"
	retry_host = true
	retry_invite = ""
	mode = "hosting"
	phase = "waiting"
	local_id = 1
	ui.show_connection("Creating a private game…", true)
	friends.host_game()

func join_friend_game(invite: String) -> void:
	if invite.strip_edges().is_empty():
		ui.set_status("Paste the private invite your friend sent you.")
		return
	_close_network()
	connection_kind = "friends"
	retry_host = false
	retry_invite = invite
	mode = "joining"
	phase = "waiting"
	ui.show_connection("Opening your private invite…", true)
	friends.join_game(invite)

func retry_friend_connection() -> void:
	if retry_host:
		host_friend_game()
	else:
		join_friend_game(retry_invite)

func _friend_failed(message: String) -> void:
	if connection_kind != "friends" or mode == "menu":
		return
	var was_host := retry_host
	var saved_invite := retry_invite
	leave_game()
	retry_host = was_host
	retry_invite = saved_invite
	ui.show_friend_error(message)

func host_game(port: int) -> void:
	_close_network()
	connection_kind = "lan"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1, 3)
	if error != OK:
		ui.show_connection("Could not host on port %d. Choose another port." % port, false)
		return
	multiplayer.multiplayer_peer = peer
	mode = "hosting"
	phase = "waiting"
	local_id = 1
	var addresses := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ":" not in ip and not ip.begins_with("127."):
			addresses.append(ip)
	ui.show_connection("Waiting for a second player\n\nHost address: %s\nPort: %d\n\nShare your public IP for internet play,\nor this address on the same network." % [", ".join(addresses), port], true)
	print("HOST_LISTENING port=%d" % port)

func join_game(address: String, port: int) -> void:
	if address.strip_edges().is_empty():
		ui.set_status("Enter the host's IP address.")
		return
	_close_network()
	connection_kind = "lan"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port, 3)
	if error != OK:
		ui.show_connection("Could not connect. Check the address and port.", false)
		return
	multiplayer.multiplayer_peer = peer
	mode = "joining"
	phase = "waiting"
	connecting_time = 0
	ui.show_connection("Connecting to %s:%d…" % [address, port], true)

func _peer_connected(id: int) -> void:
	if mode != "hosting" or not multiplayer.is_server():
		return
	guest_id = id
	practice_lesson = ""
	ruleset_id = selected_ruleset
	map_revision = "ridge_v3"
	environment_id = selected_environment
	pairs_to_play = selected_pairs
	mode = "online"
	if connection_kind == "friends":
		friends.connected()
		retry_invite = ""
	round_index = 0
	scores = {1: 0, guest_id: 0}
	ready_players = {1: false, guest_id: false}
	configure_lobby.rpc(guest_id, selected_level, ruleset_id, environment_id, pairs_to_play, ready_players)
	print("PEER_JOINED id=%d" % id)

func _connected() -> void:
	local_id = multiplayer.get_unique_id()
	mode = "online"
	practice_lesson = ""
	if connection_kind == "friends":
		friends.connected()
		retry_invite = ""
	print("CONNECTED id=%d" % local_id)

func _connection_failed() -> void:
	if connection_kind == "friends":
		call_deferred("_friend_connection_failed")
		return
	call_deferred("leave_game", "Connection failed. Check the host address, port and firewall.")

func _friend_connection_failed() -> void:
	if connection_kind == "friends" and mode == "joining" and friends.state == "connecting" and not friends.try_relay():
		_friend_failed("Could not connect to your friend. Check that the invite is still open and retry.")

func _server_disconnected() -> void:
	# ENet is still polling when these signals fire. Release it after the poll.
	call_deferred("leave_game", "The host disconnected. You can join or host a new game.")

func _peer_disconnected(_id: int) -> void:
	if mode == "online":
		call_deferred("leave_game", "The other player disconnected. Host a new game to play again.")

func _close_network() -> void:
	if match_recording and not match_recording.completed: match_recording.finish()
	if replay:
		replay.set_process(false)
		replay.queue_free()
		replay = null
	if spectator:
		spectator.stop()
	if friends:
		friends.close()
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	multiplayer.refuse_new_connections = false

func leave_game(message: String = "") -> void:
	mode = "menu"
	phase = "menu"
	practice_lesson = ""
	paused = false
	_close_network()
	retry_invite = ""
	_clear_players()
	if field: field.reset()
	if relay: relay.reset()
	arena.menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_home(message)

func _clear_players() -> void:
	clear_pebbles()
	bot_brains.clear()
	for p in players.values():
		remove_child(p)
		p.queue_free()
	players.clear()

func _begin_round() -> void:
	var ids := [1, guest_id]
	var roles := [Rules.role_for_slot(round_index, 0), Rules.role_for_slot(round_index, 1)]
	if mode == "online":
		configure_round.rpc(round_index, ids, roles, scores, selected_level, ruleset_id, map_revision, environment_id, pairs_to_play)
	else:
		configure_round(round_index, ids, roles, scores, selected_level)

@rpc("authority", "call_local", "reliable")
func configure_round(index: int, ids: Array, roles: Array, match_scores: Dictionary, level: String, ruleset: String = "", revision: String = "", weather: String = "", pairs: int = 0) -> void:
	if ruleset != "":
		if not Rules.RULESETS.has(ruleset):
			leave_game("This game uses an unsupported ruleset.")
			return
		ruleset_id = ruleset
	if revision != "":
		if revision not in ["ridge_v1", "ridge_v2", "ridge_v3"]:
			leave_game("This game uses an unsupported map revision.")
			return
		map_revision = revision
	if weather in Rules.ENVIRONMENTS: environment_id = weather
	if pairs > 0: pairs_to_play = clampi(pairs, 1, 3)
	_clear_players()
	round_events.clear()
	round_review.clear()
	selected_level = level
	if arena.map_id != level or arena.map_revision != map_revision:
		arena.map_revision = map_revision
		arena.load_level(level)
	round_index = index
	if index == 0: journal_session = Crypto.new().generate_random_bytes(12).hex_encode()
	scores = match_scores.duplicate()
	guest_id = int(ids[1])
	phase = "countdown"
	transition_time = 3.0
	round_time = Rules.ROUND_SECONDS
	paused = false
	result_text = ""
	winner_id = 0
	if arena.birds:
		arena.birds.reset_round(index)
	for i in range(2):
		var p = Player.new()
		p.setup(int(ids[i]), str(roles[i]), int(ids[i]) == local_id and mode not in ["bot_duel", "replay"], self, mode in ["bot_duel", "replay"])
		add_child(p)
		p.position = arena.spawn_for(p.role)
		p.aim.x = PI if p.role == "sniper" else 0.0
		players[p.peer_id] = p
	field.reset()
	relay.reset()
	if mode in ["practice", "bot_duel", "replay"]:
		for id in ([1, 2] if mode in ["bot_duel", "replay"] else [2]):
			var brain = BotController.new()
			brain.setup(self, players[id], duel_seed + round_index * 101 + id * 4099)
			bot_brains[id] = brain
	if mode == "online" and index == 0:
		if match_recording:
			match_recording.finish()
			match_recording.queue_free()
		match_recording = ReplayRecorder.new()
		add_child(match_recording)
		match_recording.setup(self, 1200)
		saved_match_path = ""
	ui.enter_game()
	if mode in ["bot_duel", "replay"]:
		ui.menu_root.hide()
		ui.hud.hide()
		spectator.start()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mode in ["bot_duel", "replay"] else Input.MOUSE_MODE_CAPTURED
	sound.cue("round", -13)
	print("ROUND_READY index=%d local=%d role=%s" % [index, local_id, local_player().role if local_player() else "none"])

func _physics_process(delta: float) -> void:
	if mode == "replay":
		return
	if mode == "online" and not multiplayer.get_peers().is_empty():
		ping_clock += delta
		if ping_clock >= 1:
			ping_clock = 0
			heartbeat.rpc_id(guest_id if local_id == 1 else 1, Time.get_ticks_msec())
	if mode == "bot_duel" and phase == "match_over":
		if not paused:
			transition_time -= delta
			if transition_time <= 0:
				rematch()
		return
	if mode == "joining" and connection_kind == "lan":
		connecting_time += delta
		if connecting_time >= 12.0:
			leave_game("Connection timed out. Check the host's UDP port and address.")
	if phase not in ["countdown", "playing", "round_over"]:
		return
	if mode in ["practice", "bot_duel"] and paused:
		return
	if is_authority():
		if phase in ["countdown", "round_over"]:
			transition_time -= delta
			if transition_time <= 0:
				if phase == "countdown":
					phase = "playing"
				elif phase == "round_over":
					round_index += 1
					_begin_round()
		elif phase == "playing":
			round_time = maxf(0, round_time - delta)
			if round_time <= 0 and ruleset_id != Rules.RELAY:
				if Rules.modern(ruleset_id):
					end_round(0, "Time expired. Round drawn.")
				else:
					for actor in players.values():
						if actor.role == "sniper":
							end_round(actor.peer_id, "Time expired. The sniper survived.")
	else:
		if phase == "countdown" or phase == "round_over":
			transition_time = maxf(0, transition_time - delta)
		elif phase == "playing":
			round_time = maxf(0, round_time - delta)
	var p = local_player()
	if p and p.alive and mode != "bot_duel":
		var move := Input.get_vector("left", "right", "forward", "back") if _can_input() else Vector2.ZERO
		var flags: int = 0
		if _can_input():
			flags = (1 if Input.is_action_just_pressed("jump") else 0) | (2 if Input.is_action_pressed("sprint") else 0) | (4 if Input.is_action_pressed("crouch") else 0) | (8 if Input.is_action_pressed("scope") else 0)
			flags |= (16 if Input.is_action_pressed("interact") else 0) | (32 if Input.is_action_pressed("observe") else 0)
		if is_authority():
			p.command_move = move
			p.command_flags = flags
		else:
			sequence += 1
			submit_input.rpc_id(1, move, flags, p.aim, sequence)
			p.simulate(delta, move if phase == "playing" else Vector2.ZERO, flags if phase == "playing" else 0, p.aim)
	if is_authority():
		if mode in ["practice", "bot_duel"] and phase == "playing":
			_update_bot(delta)
		for actor in players.values():
			actor.command_age += delta
			if actor.peer_id != local_id and mode == "online" and actor.command_age > 0.35:
				actor.command_move = Vector2.ZERO
				actor.command_flags = 0
			actor.simulate(delta, actor.command_move if phase == "playing" else Vector2.ZERO, actor.command_flags if phase == "playing" else 0, actor.aim)
		field.step(delta)
		relay.step(delta)
		if mode == "online":
			net_clock += delta
			if net_clock >= 0.05:
				net_clock = 0
				_send_snapshot()
	else:
		field.step(delta)
	_record_visit()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, flags: int, view: Vector2, input_sequence: int) -> void:
	if not multiplayer.is_server() or mode != "online":
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != guest_id or not players.has(sender) or not move.is_finite() or not Rules.valid_aim(view):
		return
	var p = players[sender]
	if input_sequence <= p.last_sequence:
		return
	p.last_sequence = input_sequence
	p.command_age = 0
	p.command_move = move.limit_length(1.0)
	p.command_flags = flags & 63
	p.aim = view

func _send_snapshot() -> void:
	var states: Array = []
	for p in players.values():
		states.append([p.peer_id, p.position, p.velocity, p.aim, p.crouched, p.scoped, p.cooldown, p.last_sequence, p.active_weapon, p.health, p.handgun_ammo, p.handgun_reserve, p.reload_remaining, p.aiming, p.rifle_ammo, p.rifle_reserve, p.pebbles, p.throw_remaining, p.binoculars, p.reflectors, p.alarms, p.interaction_progress, p.climbing, p.climb_progress])
	receive_snapshot.rpc(round_index, states, phase, round_time, transition_time, field.clock, relay.rules.snapshot())

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(index: int, states: Array, server_phase: String, time: float, transition: float, field_time: float = 0, relay_state: Array = []) -> void:
	if index != round_index or phase == "match_over" or (phase == "round_over" and server_phase == "playing"):
		return
	# Results own scores, reviews and recording completion on the reliable channel.
	if server_phase not in ["round_over", "match_over"]: phase = server_phase
	round_time = time
	transition_time = transition
	field.clock = field_time
	field._update_weather()
	if not relay_state.is_empty():
		relay.rules.restore(relay_state)
		relay._update_lights()
	for state in states:
		var id: int = int(state[0])
		if not players.has(id):
			continue
		var p = players[id]
		if id == local_id:
			var error: float = p.position.distance_to(state[1])
			if error > 2.5:
				p.position = state[1]
			else:
				p.position = p.position.lerp(state[1], 0.3 if error > 0.25 else 0.08)
		else:
			p.position = state[1]
			p.aim = state[3]
			p.crouched = state[4]
			p.scoped = state[5]
		p.velocity = state[2]
		p.cooldown = state[6]
		p.equip(state[8])
		p.health = mini(p.health, int(state[9]))
		p.alive = p.health > 0
		p.handgun_ammo = state[10]
		p.handgun_reserve = state[11]
		p.reload_remaining = state[12]
		p.aiming = state[13]
		if state.size() >= 18:
			p.rifle_ammo = state[14]
			p.rifle_reserve = state[15]
			p.pebbles = state[16]
			p.throw_remaining = state[17]
		if state.size() >= 24:
			p.binoculars = state[18]
			p.reflectors = state[19]
			p.alarms = state[20]
			p.interaction_progress = state[21]
			p.climbing = state[22]
			p.climb_progress = state[23]
	field._refresh_tracks()

func request_action(kind: String) -> void:
	var p = local_player()
	if not p or not p.alive or phase != "playing":
		return
	if is_authority():
		_resolve_action(local_id, kind, p.aim)
	else:
		submit_action.rpc_id(1, kind, p.aim)

@rpc("any_peer", "call_remote", "reliable")
func submit_action(kind: String, view: Vector2) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == guest_id:
		_resolve_action(guest_id, kind, view)

func _resolve_action(id: int, kind: String, view: Vector2) -> void:
	if phase != "playing" or not players.has(id) or not Rules.valid_aim(view):
		return
	var p = players[id]
	if not p.alive:
		return
	p.aim = view
	if p.climbing: return
	if kind in ["reflector", "alarm"]:
		field.place(p, kind)
		return
	if kind in ["knife", "handgun", "rifle"]:
		p.equip(kind)
		return
	if kind == "reload":
		var previous: float = p.reload_remaining
		p.start_reload()
		if p.reload_remaining > previous:
			if mode == "online":
				reload_effect.rpc(id, p.active_weapon, p.position)
			else:
				reload_effect(id, p.active_weapon, p.position)
		return
	if kind == "pebble":
		if not field.enabled or p.role != "stalker" or p.pebbles <= 0 or p.throw_remaining > 0 or p.reload_remaining > 0 or p.cooldown > 0:
			return
		p.pebbles -= 1
		p.throw_remaining = Rules.THROW_SECONDS
		projectile_serial += 1
		var origin: Vector3 = p.eye_position()
		var launch: Vector3 = p.direction() * 16 + Vector3.UP * 3
		if mode == "online":
			pebble_thrown.rpc(round_index, projectile_serial, id, origin, launch)
		else:
			pebble_thrown(round_index, projectile_serial, id, origin, launch)
		return
	if kind != "attack" or p.cooldown > 0 or p.reload_remaining > 0 or p.throw_remaining > 0 or p.binoculars:
		return
	p.interaction_progress = 0
	relay.tasks.erase(id)
	var weapon_name: String = p.active_weapon
	var reach: float = Rules.KNIFE_REACH
	p.cooldown = Rules.KNIFE_COOLDOWN
	if weapon_name == "rifle":
		if Rules.modern(ruleset_id):
			if p.rifle_ammo <= 0:
				p.cooldown = 0
				return
			p.rifle_ammo -= 1
		reach = 160.0
		p.cooldown = Rules.SHOT_COOLDOWN
	elif weapon_name == "handgun":
		if p.handgun_ammo <= 0:
			p.cooldown = 0
			return
		p.handgun_ammo -= 1
		reach = Rules.HANDGUN_RANGE
		p.cooldown = Rules.HANDGUN_COOLDOWN
	var origin: Vector3 = p.eye_position()
	var target: Vector3 = origin + p.direction() * reach
	var query := PhysicsRayQueryParameters3D.create(origin, target, 3, [p.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var victim: int = 0
	var health_after: int = 100
	if not hit.is_empty() and hit.collider is CharacterBody3D:
		victim = hit.collider.peer_id
		var damage: int = Rules.HANDGUN_DAMAGE if weapon_name == "handgun" else 100
		if weapon_name == "knife":
			damage = Rules.knife_damage(p.position, hit.collider.position, hit.collider.aim.x, ruleset_id)
			if damage < 100:
				hit.collider.cooldown = maxf(hit.collider.cooldown, 0.45)
				p.cooldown = 1.05
		health_after = maxi(0, hit.collider.health - damage)
		hit.collider.health = health_after
		hit.collider.alive = health_after > 0
	if mode == "online":
		attack_effect.rpc(id, weapon_name, origin, target, victim, health_after)
	else:
		attack_effect(id, weapon_name, origin, target, victim, health_after)
	if victim != 0 and health_after == 0:
		end_round(id, "%s elimination." % weapon_name.capitalize())

@rpc("authority", "call_local", "reliable")
func attack_effect(id: int, weapon_name: String, from: Vector3, to: Vector3, victim: int, health_after: int) -> void:
	if not players.has(id):
		return
	gameplay_event.emit("attack", [id, weapon_name, [from.x, from.y, from.z], [to.x, to.y, to.z], victim, health_after])
	remember_event("%s fired%s" % [weapon_name.capitalize(), " and hit" if victim else ""] if weapon_name != "knife" else ("Knife elimination" if victim and health_after == 0 else "Knife contact" if victim else "Knife missed"))
	var p = players[id]
	p.equip(weapon_name)
	p.attack_feedback()
	sound.play_at(weapon_name, from, 0 if weapon_name == "rifle" else -5)
	if is_authority():
		for observer in bot_brains:
			if observer != id:
				var cue: Dictionary = bot_brains[observer].senses.hear_shot(from, weapon_name)
				bot_brains[observer].receive_sound(cue)
	if arena.birds:
		arena.birds.hear_shot(from, id, weapon_name)
	if weapon_name != "knife":
		var line := MeshInstance3D.new()
		var immediate := ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffe0a6")
		immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
		immediate.surface_add_vertex(from)
		immediate.surface_add_vertex(to)
		immediate.surface_end()
		line.mesh = immediate
		add_child(line)
		get_tree().create_timer(0.1).timeout.connect(line.queue_free)
	if victim != 0:
		if players.has(victim):
			players[victim].damage_flash = 0.25
			players[victim].health = health_after
			players[victim].alive = health_after > 0
		if id == local_id:
			ui.hit_flash = 0.35
			sound.cue("hit", -6)
		p.hit_feedback = 0.3
func end_round(winner: int, reason: String) -> void:
	if not is_authority() or phase != "playing" or (winner != 0 and not players.has(winner)):
		return
	if winner != 0:
		scores[winner] = int(scores.get(winner, 0)) + 1
	if mode == "online":
		announce_result.rpc(winner, reason, scores)
	else:
		announce_result(winner, reason, scores)

@rpc("authority", "call_local", "reliable")
func announce_result(winner: int, reason: String, match_scores: Dictionary) -> void:
	scores = match_scores.duplicate()
	winner_id = winner
	result_text = reason
	phase = "match_over" if Rules.match_finished(round_index, scores, ruleset_id, pairs_to_play) else "round_over"
	if practice_lesson != "":
		phase = "match_over"
	round_review = round_events.slice(maxi(0, round_events.size() - 5)).duplicate(true)
	completed_reviews.append({"round": round_index + 1, "role": local_player().role if local_player() else "", "reason": reason, "events": round_review.duplicate(true)})
	if completed_reviews.size() > 6: completed_reviews.pop_front()
	if mode == "online" and local_player() and DisplayServer.get_name() != "headless":
		journal.record(journal_session + ":" + str(round_index),local_player().role,"draw" if winner == 0 else "win" if winner == local_id else "loss")
		journal.save()
	transition_time = 5
	sound.cue("round", -9)
	if phase == "match_over" and mode != "bot_duel":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.show_match_result()
	print("ROUND_RESULT winner=%d scores=%s phase=%s" % [winner, str(scores), phase])

func rematch() -> void:
	if phase != "match_over":
		return
	if mode == "online":
		if is_authority(): open_rematch_lobby(local_id)
		else: request_rematch.rpc_id(1)
		return
	if not is_authority(): return
	if practice_lesson != "":
		start_lesson(practice_lesson)
		return
	if mode == "bot_duel":
		duel_seed += 137
	scores = {1: 0, guest_id: 0}
	round_index = 0
	completed_reviews.clear()
	_begin_round()

func announce_birds(index: int, direction: Vector3) -> void:
	if not is_authority():
		return
	if mode == "online":
		bird_alarm.rpc(round_index, index, direction, round_time)
	else:
		bird_alarm(round_index, index, direction, round_time)

@rpc("authority", "call_local", "reliable")
func bird_alarm(index: int, flock: int, direction: Vector3, remaining: float) -> void:
	if index != round_index or phase != "playing" or not arena.birds or not direction.is_finite() or not is_finite(remaining) or remaining < 0 or remaining > Rules.ROUND_SECONDS:
		return
	if direction.length_squared() < 0.01 or direction.length_squared() > 1.1:
		return
	arena.birds.apply_alarm(flock, direction.normalized(), round_elapsed())
	remember_event("Bird alarm")
	gameplay_event.emit("birds", [flock, [direction.x, direction.y, direction.z], remaining])

func _update_bot(delta: float) -> void:
	if not bot_enabled or practice_lesson != "":
		return
	for brain in bot_brains.values():
		brain.tick(delta)

func remember_event(description: String) -> void:
	if phase != "playing":
		return
	round_events.append({"seconds": snappedf(round_elapsed(), 0.1), "description": description})
	if round_events.size() > 128:
		round_events.pop_front()

func review_text(review_index: int = -1) -> String:
	if phase not in ["round_over", "match_over"]:
		return ""
	var lines := PackedStringArray()
	var events: Array = completed_reviews[review_index].events if review_index >= 0 and review_index < completed_reviews.size() else round_review
	for event in events:
		lines.append("%02d:%02d  %s" % [int(event.seconds) / 60, int(event.seconds) % 60, event.description])
	return "\n".join(lines) if not lines.is_empty() else "No weapon or wildlife events this round."

func set_winner() -> int:
	if phase != "match_over":
		return 0
	var first := int(scores.get(1, 0))
	var second := int(scores.get(guest_id, 0))
	return 0 if first == second else (1 if first > second else guest_id)

func clear_pebbles() -> void:
	for item in projectiles.values():
		remove_child(item)
		item.queue_free()
	projectiles.clear()

@rpc("authority", "call_local", "reliable")
func pebble_thrown(index: int, serial: int, actor_id: int, origin: Vector3, launch: Vector3) -> void:
	if index != round_index or phase != "playing" or projectiles.has(serial) or not players.has(actor_id) or not origin.is_finite() or not launch.is_finite():
		return
	var item := Pebble.new()
	item.setup(self, serial, origin, launch, [players[actor_id].get_rid()])
	add_child(item)
	projectiles[serial] = item
	gameplay_event.emit("pebble_throw", [serial, actor_id, ReplayCodec.v3(origin), ReplayCodec.v3(launch)])
	remember_event("Stalker threw a pebble")

func finish_pebble(serial: int, point: Vector3) -> void:
	if not is_authority() or not projectiles.has(serial):
		return
	if mode == "online":
		pebble_impact.rpc(round_index, serial, point)
	else:
		pebble_impact(round_index, serial, point)

@rpc("authority", "call_local", "reliable")
func pebble_impact(index: int, serial: int, point: Vector3) -> void:
	if index != round_index or phase != "playing" or not point.is_finite():
		return
	if projectiles.has(serial):
		var item = projectiles[serial]
		remove_child(item)
		item.queue_free()
		projectiles.erase(serial)
	sound.play_at("pebble", point, -6)
	gameplay_event.emit("pebble_impact", [serial, ReplayCodec.v3(point)])
	remember_event("Pebble impact")
	if is_authority():
		for brain in bot_brains.values():
			brain.receive_sound(brain.senses.hear_event("impact", point, 24.0))
		if arena.birds:
			arena.birds.hear_impact(point)

@rpc("authority", "call_local", "reliable")
func reload_effect(id: int, weapon_name: String, point: Vector3) -> void:
	if not players.has(id) or phase != "playing":
		return
	sound.play_at("reload", point, -9)
	gameplay_event.emit("reload", [id, weapon_name, ReplayCodec.v3(point)])
	remember_event("%s reloaded" % weapon_name.capitalize())
	if is_authority():
		for observer in bot_brains:
			if observer != id:
				var brain = bot_brains[observer]
				brain.receive_sound(brain.senses.hear_event("mechanism", point, 18.0))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("options", key, settings[key])
		if config.has_section("bindings"):
			for key in config.get_section_keys("bindings"):
				var value = config.get_value("bindings", key)
				if value is int and value > 0 and value < 67108864: bindings[key] = value
	settings.sensitivity = clampf(float(settings.sensitivity), 0.0005, 0.006)
	settings.volume = clampf(float(settings.volume), 0, 1)
	settings.fov = clampf(float(settings.fov), 65, 100)

func save_settings() -> void:
	_apply_settings()
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("options", key, settings[key])
	for key in bindings: config.set_value("bindings", key, bindings[key])
	config.save("user://settings.cfg")

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(settings.volume, 0.0001)))
	AudioServer.set_bus_mute(0, settings.volume <= 0)

func broadcast_field(kind: String, value: Array) -> void:
	if not is_authority() or phase != "playing": return
	if mode == "online": field_event.rpc(round_index, kind, value)
	else: field_event(round_index, kind, value)

@rpc("authority", "call_local", "reliable")
func field_event(index: int, kind: String, value: Array) -> void:
	# Reliable field events can precede the first playing snapshot on its separate channel.
	if index != round_index or phase not in ["countdown", "playing", "round_over", "match_over"]: return
	if kind == "relay":
		relay.apply_change(int(value[0]), int(value[1]), int(value[2]) if value.size() > 2 else -1)
		remember_event("Relay %d %s" % [int(value[0]) + 1, "sabotaged" if int(value[1]) == 1 else "repaired"])
	else:
		field.apply_event(kind, value)
		if kind == "alarm": remember_event("Tripwire alarm")
	gameplay_event.emit("field", [kind, value])

@rpc("authority", "call_local", "reliable")
func configure_lobby(guest: int, level: String, ruleset: String, weather: String, pairs: int, readiness: Dictionary) -> void:
	if not Rules.LEVELS.has(level) or not Rules.RULESETS.has(ruleset) or not Rules.ENVIRONMENTS.has(weather):
		leave_game("Your friend is using a different demo version. Download the same build.")
		return
	mode = "online"
	phase = "lobby"
	guest_id = guest
	selected_level = level
	ruleset_id = ruleset
	environment_id = weather
	pairs_to_play = clampi(pairs, 1, 3)
	ready_players = readiness.duplicate()
	paused = false
	_clear_players()
	field.reset()
	if arena.map_id != level: arena.load_level(level)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_ready_room()

func set_ready(value: bool = true) -> void:
	if mode != "online" or phase != "lobby": return
	if ready_players.get(local_id, false) == value: return
	if is_authority(): _apply_ready(local_id, value)
	else:
		ready_players[local_id] = value
		submit_ready.rpc_id(1, value)

@rpc("any_peer", "call_remote", "reliable")
func submit_ready(value: bool) -> void:
	if is_authority() and multiplayer.get_remote_sender_id() == guest_id and phase == "lobby":
		_apply_ready(guest_id, value)

func _apply_ready(id: int, value: bool) -> void:
	ready_players[id] = value
	configure_lobby.rpc(guest_id, selected_level, ruleset_id, environment_id, pairs_to_play, ready_players)
	if ready_players.get(1, false) and ready_players.get(guest_id, false):
		round_index = 0
		scores = {1: 0, guest_id: 0}
		completed_reviews.clear()
		_begin_round()

@rpc("any_peer", "call_remote", "unreliable", 2)
func heartbeat(nonce: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if mode == "online" and sender == (guest_id if local_id == 1 else 1):
		heartbeat_reply.rpc_id(sender, nonce)

@rpc("any_peer", "call_remote", "unreliable", 2)
func heartbeat_reply(nonce: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var interval := Time.get_ticks_msec() - nonce
	if mode == "online" and sender == (guest_id if local_id == 1 else 1) and interval >= 0 and interval <= 10000:
		ping_ms = int(interval)

func rebind(action: String, keycode: int) -> void:
	if not bindings.has(action) or keycode <= 0 or keycode == KEY_ESCAPE: return
	var previous: int = bindings[action]
	for other in bindings:
		if other != action and int(bindings[other]) == keycode: bindings[other] = previous
	bindings[action] = keycode
	_setup_input()
	save_settings()

func round_elapsed() -> float:
	return field.clock if field and field.enabled else Rules.ROUND_SECONDS - round_time

@rpc("any_peer", "call_remote", "reliable")
func request_rematch() -> void:
	if is_authority() and phase == "match_over" and multiplayer.get_remote_sender_id() == guest_id:
		open_rematch_lobby(guest_id)

func open_rematch_lobby(requester: int) -> void:
	ready_players = {1: requester == 1, guest_id: requester == guest_id}
	configure_lobby.rpc(guest_id, selected_level, ruleset_id, environment_id, pairs_to_play, ready_players)

func save_match() -> String:
	if not saved_match_path.is_empty(): return "Saved. Find it under Watch / Your recordings."
	if not match_recording or not match_recording.completed: return "The recording is finishing. Try again in a moment."
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://recordings/" + stamp + "-" + journal_session.left(6) + ".json"
	var problem: String = match_recording.save(path)
	if not problem.is_empty(): return problem
	saved_match_path = path
	return "Saved. Find it under Watch / Your recordings."

func key_label(action: String) -> String:
	return OS.get_keycode_string(int(bindings.get(action, 0)))

func _record_visit() -> void:
	if mode != "online" or phase != "playing" or selected_level != "mountain" or DisplayServer.get_name() == "headless": return
	var own = local_player()
	if own:
		var index: int = arena.Mountain.nearest_nest(own.position)
		if own.position.distance_to(arena.Mountain.NESTS[index]) < 3 and journal.visit(index): journal.save()
