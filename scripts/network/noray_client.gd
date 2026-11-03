extends Node

# Bounded implementation of the MIT-licensed noray protocol, informed by
# netfox.noray. Upstream attribution is in third_party/noray/LICENSE.txt.
const Invite = preload("res://scripts/network/invite.gd")
signal registered()
signal endpoint(address: String, port: int, relayed: bool)
signal failed(message: String)
var server: String = "foxssake.studio"
var control_port: int = 8890
var registrar_port: int = 8809
var oid: String = ""
var local_port: int = 0
var resolved: String = ""
var state: String = "closed"
var tcp := StreamPeerTCP.new()
var udp := PacketPeerUDP.new()
var dns_id: int = IP.RESOLVER_INVALID_ID
var deadline: int = 0
var next_udp: int = 0
var pid: String = ""
var buffer: String = ""

func _ready() -> void:
	set_process(false)

func open() -> void:
	close()
	state = "dns"
	deadline = Time.get_ticks_msec() + 8000
	dns_id = IP.resolve_hostname_queue_item(server, IP.TYPE_IPV4)
	set_process(true)

func close() -> void:
	set_process(false)
	state = "closed"
	tcp.disconnect_from_host()
	udp.close()
	if dns_id != IP.RESOLVER_INVALID_ID:
		IP.erase_resolve_item(dns_id)
		dns_id = IP.RESOLVER_INVALID_ID
	buffer = ""
	pid = ""
	oid = ""
	local_port = 0

func request(oid_to_join: String, relay: bool = false) -> void:
	if state != "ready" or not Invite.valid_oid(oid_to_join):
		_abort("Connection service is not ready. Please retry.")
		return
	_send(("connect-relay " if relay else "connect ") + oid_to_join)

func _send(line: String) -> void:
	if tcp.put_data((line + "\n").to_utf8_buffer()) != OK:
		_abort("Connection service disconnected. Please retry.")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if state != "ready" and now >= deadline:
		_abort("The free connection service timed out. Please retry.")
		return
	if state == "dns":
		var status := IP.get_resolve_item_status(dns_id)
		if status == IP.RESOLVER_STATUS_WAITING:
			return
		if status != IP.RESOLVER_STATUS_DONE:
			_abort("The free connection service could not be reached.")
			return
		resolved = IP.get_resolve_item_address(dns_id)
		IP.erase_resolve_item(dns_id)
		dns_id = IP.RESOLVER_INVALID_ID
		if tcp.connect_to_host(resolved, control_port) != OK:
			_abort("The free connection service could not be reached.")
			return
		state = "tcp"
	tcp.poll()
	if state == "tcp":
		if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
			return
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_abort("The free connection service could not be reached.")
			return
		tcp.set_no_delay(true)
		state = "ids"
		_send("register-host")
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_abort("Connection service disconnected. Please retry.")
		return
	var available := tcp.get_available_bytes()
	if available > 8192 or buffer.length() > 8192:
		_abort("Connection service sent an invalid response.")
		return
	if available > 0:
		var data := tcp.get_data(available)
		if data[0] != OK:
			_abort("Connection service disconnected. Please retry.")
			return
		buffer += data[1].get_string_from_utf8()
		var count := 0
		while "\n" in buffer and state != "closed":
			var split := buffer.find("\n")
			var line := buffer.substr(0, split).strip_edges()
			buffer = buffer.substr(split + 1)
			_command(line)
			count += 1
			if count > 64:
				_abort("Connection service sent an invalid response.")
				return
	if state == "udp":
		if now >= next_udp:
			udp.put_packet(pid.to_utf8_buffer())
			next_udp = now + 150
		while udp.get_available_packet_count() > 0:
			var reply := udp.get_packet()
			if udp.get_packet_ip() != resolved or udp.get_packet_port() != registrar_port:
				continue
			if reply.get_string_from_ascii() == "OK":
				local_port = udp.get_local_port()
				udp.close()
				pid = ""
				state = "ready"
				registered.emit()
				break

func _command(line: String) -> void:
	var split := line.find(" ")
	var command := line.substr(0, split) if split >= 0 else line
	var data := line.substr(split + 1) if split >= 0 else ""
	if command == "set-oid" and state == "ids":
		if not Invite.valid_oid(data):
			_abort("Connection service sent an invalid response.")
			return
		oid = data
	elif command == "set-pid" and state == "ids":
		if data.is_empty() or data.length() > 256:
			_abort("Connection service sent an invalid response.")
			return
		pid = data
	if state == "ids" and not oid.is_empty() and not pid.is_empty():
		if udp.bind(0, "0.0.0.0") != OK or udp.set_dest_address(resolved, registrar_port) != OK:
			_abort("Could not open a connection. Please retry.")
			return
		state = "udp"
		deadline = Time.get_ticks_msec() + 6000
	elif command == "connect" and state == "ready":
		var parts := data.rsplit(":", true, 1)
		if parts.size() == 2 and parts[0].is_valid_ip_address() and parts[1].is_valid_int() and int(parts[1]) in range(1, 65536):
			endpoint.emit(parts[0], int(parts[1]), false)
	elif command == "connect-relay" and state == "ready":
		if data.is_valid_int() and int(data) in range(1, 65536):
			endpoint.emit(resolved, int(data), true)
	elif command == "error":
		_abort("That invite is no longer available. Ask your friend for a new invite.")

func _abort(message: String) -> void:
	close()
	failed.emit(message)
