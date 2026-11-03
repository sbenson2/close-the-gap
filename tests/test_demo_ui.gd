extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.phase == "menu" and game.mode == "menu", "normal demo launch opens play options rather than old footage")
	var buttons: Array = game.ui.content.find_children("*", "Button", true, false)
	check(buttons[0].text == "Host a game" and buttons[1].text == "Join a game", "friend play is the first menu action")
	game.ui.show_host()
	check(game.ui.content.find_child("WeatherPicker", true, false) != null and game.ui.content.find_child("LengthPicker", true, false) != null, "host can select weather and complete match length")
	check(not game.Rules.match_finished(1, {1:2,2:0}, "relay_v1", 3) and game.Rules.match_finished(5, {1:3,2:3}, "relay_v1", 3), "full matches finish only after all three complete role pairs")
	if game.ui.has_method("show_ready_room"):
		game.configure_lobby(2, "mountain", "relay_v1", "rain", 3, {1:false,2:false})
		check(game.phase == "lobby" and game.players.is_empty(), "authenticated ready room cannot begin play before readiness")
		check(game.ui.content.find_child("Ready", true, false) != null, "ready room gives each player an explicit start action")
	else:
		check(false, "friend ready room is implemented")
	game.leave_game()
	if game.ui.has_method("show_guide"):
		game.ui.show_guide(false)
		check(game.ui.menu_screen == "guide", "field guide is available before first play")
	else: check(false, "field guide is implemented")
	game.ui.show_pause(false)
	check(game.ui.hud.visible and not game.ui.menu_root.visible, "resuming after a guide or settings screen restores the live HUD")
	var original: Dictionary = game.bindings.duplicate()
	game.rebind("interact", KEY_H)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	check(InputMap.event_is_action(event,"interact") and game.key_label("interact") == "H", "remapped keys drive actual input and interaction prompts")
	var saved := ConfigFile.new()
	saved.load("user://settings.cfg")
	check(saved.get_value("bindings","interact") == KEY_H,"keyboard bindings persist in settings")
	game.bindings = original
	game._setup_input()
	game.save_settings()
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_UI_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
