extends Node

# Let ENet finish its disconnect exchange before closing a DTLS UDP socket.
# Immediate close can produce an ICMP/socket error at a directly connected peer.
var peer: ENetMultiplayerPeer
var deadline: int = 0

func _ready() -> void:
	deadline = Time.get_ticks_msec() + 2000

func _process(_delta: float) -> void:
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED or peer.host == null:
		peer = null
		queue_free()
		return
	peer.poll()
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED or peer.host.get_peers().is_empty() or Time.get_ticks_msec() >= deadline:
		peer.close()
		peer = null
		queue_free()

func _exit_tree() -> void:
	if peer:
		peer.close()
		peer = null
