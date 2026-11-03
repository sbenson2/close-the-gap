extends SceneTree

var checks: int = 0
var failures: int = 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await process_frame
	game.join_friend_game("not-a-valid-invite")
	await process_frame
	await process_frame
	check(game.phase == "menu" and game.players.is_empty(), "invalid invite never starts networking or gameplay")
	check(game.friends.state == "idle" and game.friends.noray.state == "closed", "invalid invite cleans up the connection attempt")
	# Cancellation is a local lifecycle check; never contact the public service in CI.
	game.friends.service_host = "127.0.0.1"
	game.host_friend_game()
	game.leave_game()
	await create_timer(0.2).timeout
	check(game.phase == "menu" and game.friends.state == "idle", "cancel during service registration returns to menu")
	check(game.friends.noray.state == "closed" and game.friends.invite.is_empty(), "cancel removes rendezvous state and invite")
	check(game.friends.secret.is_empty() and game.retry_invite.is_empty(), "cancel clears private authorization material")
	game.ui.show_host()
	check(game.ui.content.find_children("CreateGame", "Button", true, false).size() == 1, "normal host screen uses private invites")
	game.ui.show_join()
	check(game.ui.content.find_children("FriendInvite", "LineEdit", true, false).size() == 1, "normal join screen accepts private invites")
	game.ui.show_lan_join()
	check(game.ui.content.find_children("HostAddress", "LineEdit", true, false).size() == 1, "direct-IP testing remains available separately")
	game.queue_free()
	await process_frame
	await process_frame
	print("LIFECYCLE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
