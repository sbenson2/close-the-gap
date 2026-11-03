extends Node

const Invite = preload("res://scripts/network/invite.gd")
const Auth = preload("res://scripts/network/invite_auth.gd")
const Noray = preload("res://scripts/network/noray_client.gd")
const PeerDrain = preload("res://scripts/network/peer_drain.gd")
signal invite_ready(invite: String)
signal status_changed(message: String)
signal failed(message: String)
var noray: Node
var api: SceneMultiplayer
var auth: RefCounted
var peer: ENetMultiplayerPeer
var hosting: bool = false
var state: String = "idle"
var invite: String = ""
var route: String = "direct"
var force_relay: bool = false
var service_host: String = "foxssake.studio"
var service_port: int = 8890
var service_registrar: int = 8809
var key: CryptoKey
var certificate: X509Certificate
var secret := PackedByteArray()
var expires: int = 0
var target_oid: String = ""
var deadline: int = 0
var punch_address: String = ""
var punch_port: int = 0
var next_punch: int = 0
var punch_udp := PacketPeerUDP.new()
var punch_read: bool = false
var punch_handshake: bool = false
var punch_finish: int = 0
var secure_at: int = 0

func _ready() -> void:
	set_process(false)
	noray = Noray.new()
	add_child(noray)
	noray.registered.connect(_registered)
	noray.endpoint.connect(_endpoint)
	noray.failed.connect(_service_failed)

func _exit_tree() -> void:
	# Tree teardown cannot attach a disconnect-drain child to the busy root.
	# An application exit closes immediately; ordinary Leave still drains ENet.
	_reset_peer()
	close()

func host_game() -> void:
	close()
	hosting = true
	var crypto := Crypto.new()
	key = crypto.generate_rsa(2048)
	certificate = crypto.generate_self_signed_certificate(key, "CN=" + Invite.TLS_NAME + ",O=CloseTheGap,C=US", "20200101000000", "20350101000000")
	if key == null or certificate == null:
		_fail("Could not create a private connection. Please retry.")
		return
	secret = crypto.generate_random_bytes(32)
	expires = int(Time.get_unix_time_from_system()) + Invite.LIFETIME
	_open_service()

func join_game(text: String) -> void:
	close()
	var data := Invite.decode(text)
	if data.is_empty():
		_fail("This invite is invalid, expired, or from a different build. Both use the same demo, then create a new invite.")
		return
	hosting = false
	certificate = data.certificate
	secret = data.secret
	expires = data.expires
	target_oid = data.oid
	_open_service()

func _open_service() -> void:
	api = multiplayer as SceneMultiplayer
	api.refuse_new_connections = false
	noray.server = service_host
	noray.control_port = service_port
	noray.registrar_port = service_registrar
	state = "registering"
	status_changed.emit("Contacting the free test connection service…")
	set_process(true)
	noray.open()

func _registered() -> void:
	if state != "registering":
		return
	if hosting:
		state = "waiting"
		invite = Invite.encode(noray.oid, certificate, secret, expires)
		if invite.is_empty():
			_fail("Could not create a private invite. Please retry.")
			return
		invite_ready.emit(invite)
	else:
		state = "finding"
		route = "relay" if force_relay else "direct"
		deadline = Time.get_ticks_msec() + 6000
		status_changed.emit("Finding your friend's game…")
		noray.request(target_oid, force_relay)

func _attach_auth() -> void:
	if auth:
		auth.detach()
	auth = Auth.new()
	auth.attach(api, hosting, secret.duplicate(), expires)
	auth.rejected.connect(_authentication_failed)

func _endpoint(address: String, port: int, relayed: bool) -> void:
	if state == "idle" or state == "connected":
		return
	if hosting:
		if state not in ["waiting", "connecting"]:
			return
	elif state not in ["finding", "connecting"] or (route == "relay" and not relayed):
		return
	_reset_peer()
	route = "relay" if relayed else "direct"
	punch_address = address
	punch_port = port
	if punch_udp.bind(noray.local_port, "0.0.0.0") != OK or punch_udp.set_dest_address(address, port) != OK:
		_fail("Could not open a connection. Please retry.")
		return
	state = "punching"
	punch_read = false
	punch_handshake = false
	punch_finish = 0
	next_punch = 0
	deadline = Time.get_ticks_msec() + 4500
	status_changed.emit("Preparing an encrypted relay connection…" if relayed else "Preparing a direct connection…")

func _begin_secure_peer() -> void:
	peer = ENetMultiplayerPeer.new()
	if hosting:
		if peer.create_server(noray.local_port, 3, 3) != OK or peer.host.dtls_server_setup(TLSOptions.server(key, certificate)) != OK:
			_fail("Could not open an encrypted connection. Please retry.")
			return
	else:
		if peer.create_client(punch_address, punch_port, 3, 0, 0, noray.local_port) != OK or peer.host.dtls_client_setup(Invite.TLS_NAME, TLSOptions.client(certificate)) != OK:
			_fail("Could not open an encrypted connection. Please retry.")
			return
	_attach_auth()
	api.multiplayer_peer = peer
	state = "connecting"
	deadline = Time.get_ticks_msec() + (10000 if route == "relay" else 6000)
	status_changed.emit("Connecting securely through the test relay…" if route == "relay" else "Connecting securely to your friend…")

func _process(_delta: float) -> void:
	if state in ["idle", "registering", "connected"]:
		return
	var now := Time.get_ticks_msec()
	if Time.get_unix_time_from_system() >= expires:
		_fail("This invite expired. Create a new game to get another invite.")
		return
	if state == "handoff":
		if now >= secure_at:
			_begin_secure_peer()
		return
	if state == "punching":
		_punch(now)
	if not hosting and now >= deadline and state in ["finding", "connecting", "punching"]:
		if not try_relay():
			_fail("Could not reach your friend. Ask for a new invite or retry shortly.")
	elif hosting and state in ["punching", "connecting"] and now >= deadline:
		_reset_peer()
		state = "waiting"

func _punch(now: int) -> void:
	# Noray's bounded UDP handshake happens before DTLS owns the socket.
	# It carries no secret or game data and never authenticates a player.
	var count := 0
	while punch_udp.get_available_packet_count() > 0 and count < 32:
		var packet := punch_udp.get_packet()
		count += 1
		if punch_udp.get_packet_ip() != punch_address or punch_udp.get_packet_port() != punch_port or packet.size() > 8:
			continue
		var valid: bool = not packet.is_empty()
		for byte in packet:
			if byte not in [36, 45, 114, 119, 120]:
				valid = false
		if not valid:
			continue
		var status := packet.get_string_from_ascii()
		if not status.begins_with("$"):
			continue
		punch_read = true
		if "r" in status:
			punch_handshake = true
		if "x" in status and punch_handshake and punch_finish == 0:
			punch_finish = now + 300
	if now >= next_punch:
		var status := "$" + ("r" if punch_read else "-") + "w" + ("x" if punch_handshake else "-")
		punch_udp.put_packet(status.to_ascii_buffer())
		next_punch = now + 100
	if punch_finish > 0 and now >= punch_finish:
		punch_udp.close()
		state = "handoff"
		secure_at = now + 300

func try_relay() -> bool:
	if hosting or state not in ["finding", "connecting", "punching", "handoff"] or route == "relay":
		return false
	_reset_peer()
	route = "relay"
	state = "finding"
	deadline = Time.get_ticks_msec() + 8000
	status_changed.emit("Trying an encrypted relay connection…")
	noray.request(target_oid, true)
	return true

func connected() -> void:
	state = "connected"
	invite = ""
	status_changed.emit("Connected")

func _authentication_failed() -> void:
	_fail("The private invite could not be verified. Ask your friend for a new invite.")

func _service_failed(message: String) -> void:
	if state != "connected" and state != "idle":
		_fail(message)

func _reset_peer() -> void:
	# Only called from ordinary processing, never from a multiplayer poll callback.
	if api and api.has_multiplayer_peer():
		api.multiplayer_peer.close()
		api.multiplayer_peer = OfflineMultiplayerPeer.new()
	if auth:
		auth.detach()
		auth = null
	peer = null
	punch_udp.close()

func close() -> void:
	if state == "connected" and peer and api and api.multiplayer_peer == peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and peer.host != null:
		var drain := PeerDrain.new()
		drain.peer = peer
		for id in api.get_peers():
			peer.disconnect_peer(id)
		peer.host.flush()
		api.multiplayer_peer = OfflineMultiplayerPeer.new()
		get_tree().root.add_child(drain)
	set_process(false)
	state = "idle"
	if noray:
		noray.close()
	if auth:
		auth.detach()
		auth = null
	key = null
	certificate = null
	secret.fill(0)
	secret = PackedByteArray()
	invite = ""
	target_oid = ""
	peer = null
	punch_udp.close()

func _fail(message: String) -> void:
	if state == "failed":
		return
	state = "failed"
	set_process(false)
	failed.emit(message)
