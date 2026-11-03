extends RefCounted

const Invite = preload("res://scripts/network/invite.gd")
var api: SceneMultiplayer
var crypto := Crypto.new()
var secret := PackedByteArray()
var host: bool = false
var expires: int = 0
var accepted: bool = false
var accepted_id: int = 0
var pending: Dictionary = {}
var challenge := PackedByteArray()
signal rejected()

func attach(multiplayer_api: SceneMultiplayer, is_host: bool, invite_secret: PackedByteArray, expiry: int) -> void:
	api = multiplayer_api
	host = is_host
	secret = invite_secret
	expires = expiry
	api.auth_callback = _receive
	api.auth_timeout = 6.0
	api.allow_object_decoding = false
	api.peer_authenticating.connect(_begin)
	api.peer_authentication_failed.connect(_failed)

func detach() -> void:
	if is_instance_valid(api):
		api.auth_callback = Callable()
		if api.peer_authenticating.is_connected(_begin):
			api.peer_authenticating.disconnect(_begin)
		if api.peer_authentication_failed.is_connected(_failed):
			api.peer_authentication_failed.disconnect(_failed)
	pending.clear()
	secret.fill(0)
	secret = PackedByteArray()
	challenge = PackedByteArray()
	api = null

func _begin(id: int) -> void:
	if not host:
		return
	if accepted or Time.get_unix_time_from_system() >= expires or pending.size() >= 3:
		api.call_deferred("disconnect_peer", id)
		return
	var nonce := crypto.generate_random_bytes(32)
	pending[id] = nonce
	api.send_auth(id, PackedByteArray([67]) + nonce)

func _digest(label: String, nonce: PackedByteArray) -> PackedByteArray:
	return crypto.hmac_digest(HashingContext.HASH_SHA256, secret, (Invite.PROTOCOL + "/" + label).to_utf8_buffer() + nonce)

func _receive(id: int, data: PackedByteArray) -> void:
	if data.size() != 33 or Time.get_unix_time_from_system() >= expires:
		api.call_deferred("disconnect_peer", id)
		return
	if host:
		if accepted or not pending.has(id) or data[0] != 80:
			api.call_deferred("disconnect_peer", id)
			return
		var nonce: PackedByteArray = pending[id]
		pending.erase(id)
		if not crypto.constant_time_compare(_digest("client", nonce), data.slice(1)):
			api.call_deferred("disconnect_peer", id)
			return
		accepted = true
		accepted_id = id
		api.send_auth(id, PackedByteArray([65]) + _digest("host", nonce))
		api.complete_auth(id)
		api.refuse_new_connections = true
	else:
		if id != 1:
			return
		if data[0] == 67 and challenge.is_empty():
			challenge = data.slice(1)
			api.send_auth(1, PackedByteArray([80]) + _digest("client", challenge))
		elif data[0] == 65 and challenge.size() == 32 and crypto.constant_time_compare(_digest("host", challenge), data.slice(1)):
			accepted = true
			api.complete_auth(1)
		else:
			api.call_deferred("disconnect_peer", id)

func _failed(id: int) -> void:
	pending.erase(id)
	if host and accepted_id == id:
		accepted = false
		accepted_id = 0
		api.refuse_new_connections = false
	elif not host:
		rejected.emit()
