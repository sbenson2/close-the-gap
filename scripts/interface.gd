extends Control

const Rules = preload("res://scripts/rules.gd")
const CHALK := Color("ece9df")
const MUTED := Color("a9bdc7")
const ACCENT := Color("dfb46d")
const INK := Color("243a47")
var game: Node3D
var display_font: Font = preload("res://assets/fonts/Display.ttf")
var body_font: Font = preload("res://assets/fonts/Body.ttf")
var menu_root: Control
var brand: Control
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var hud: Control
var clock_label: Label
var role_label: Label
var weapon_label: Label
var objective_label: Label
var score_label: Label
var health_label: Label
var noise_label: Label
var field_label: Label
var caption_text := ""
var caption_remaining := 0.0
var footer: Label
var center_label: Label
var center_detail: Label
var hit_flash: float = 0.0
var menu_screen: String = "home"
var help_visible: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_resource := Theme.new()
	theme_resource.default_font = body_font
	theme_resource.default_font_size = 19
	theme_resource.set_color("font_color", "Label", CHALK)
	theme_resource.set_color("font_color", "Button", CHALK)
	theme_resource.set_color("font_hover_color", "Button", Color("fff4dc"))
	theme_resource.set_stylebox("normal", "Button", style(Color("354d5a"), 3))
	theme_resource.set_stylebox("hover", "Button", style(Color("496474"), 3))
	theme_resource.set_stylebox("pressed", "Button", style(Color("566f79"), 3))
	var focus := style(Color(0, 0, 0, 0), 3)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	theme_resource.set_stylebox("focus", "Button", focus)
	theme_resource.set_stylebox("normal", "LineEdit", style(Color("1b303d"), 3))
	theme_resource.set_color("font_color", "LineEdit", CHALK)
	theme_resource.set_color("caret_color", "LineEdit", ACCENT)
	theme_resource.set_stylebox("focus", "LineEdit", focus)
	theme = theme_resource
	_build_menu()
	_build_hud()
	show_home()

func style(color: Color, corners: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corners)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _exit_tree() -> void:
	# clear_content owns a status label even on screens that do not display it.
	if is_instance_valid(status) and status.get_parent() == null and not status.is_queued_for_deletion():
		status.free()

func label(text: String, font_size: int = 19, color: Color = CHALK, font: Font = null) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	if font:
		item.add_theme_font_override("font", font)
	return item

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_root)
	var shade := TextureRect.new()
	menu_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.07, 0.12, 0.16, 0.91))
	gradient.set_color(1, Color(0.07, 0.12, 0.16, 0.12))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.width = 1024
	gradient_texture.height = 4
	gradient_texture.fill_from = Vector2.ZERO
	gradient_texture.fill_to = Vector2(0.87, 0)
	gradient_texture.gradient = gradient
	shade.texture = gradient_texture
	brand = Control.new()
	menu_root.add_child(brand)
	var title := label("Close\nthe gap", 126, CHALK, display_font)
	title.position = Vector2(78, 153)
	title.add_theme_constant_override("line_spacing", -28)
	brand.add_child(title)
	var rule := ColorRect.new()
	rule.color = ACCENT
	rule.position = Vector2(84, 456)
	rule.size = Vector2(64, 4)
	brand.add_child(rule)
	var subtitle := label("Two-player elimination", 24, ACCENT)
	subtitle.position = Vector2(82, 486)
	brand.add_child(subtitle)
	var intro := label("Stalker: knife and handgun. Sniper: scoped rifle.\nClimb a wooded mountain slope or approach a loading deck.", 20, CHALK)
	intro.position = Vector2(82, 533)
	intro.add_theme_constant_override("line_spacing", 7)
	brand.add_child(intro)
	var roles := label("Stalker    Stay hidden · approach from behind\nSniper     Restricted to high ground · scoped rifle", 18, MUTED)
	roles.position = Vector2(82, 638)
	roles.add_theme_constant_override("line_spacing", 12)
	brand.add_child(roles)
	panel = PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -490
	panel.offset_right = -82
	panel.offset_top = -330
	panel.offset_bottom = 370
	panel.add_theme_stylebox_override("panel", style(Color("243a47"), 5))
	menu_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	scroll.add_child(content)
	footer = label("", 16, MUTED)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(82, -51)
	menu_root.add_child(footer)

func clear_content(title: String, description: String = "") -> void:
	if is_instance_valid(status) and not status.is_queued_for_deletion() and status.get_parent() == null:
		status.free()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(label(title, 34, CHALK, display_font))
	if description:
		var detail := label(description, 17, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)
	status = label("", 16, ACCENT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func button(text: String, action: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.name = text.to_pascal_case().replace(" ", "")
	item.custom_minimum_size.y = 52
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		item.add_theme_stylebox_override("normal", style(ACCENT, 3))
		item.add_theme_stylebox_override("hover", style(ACCENT.lightened(0.1), 3))
		item.add_theme_color_override("font_color", INK)
		item.add_theme_color_override("font_hover_color", INK)
	item.pressed.connect(action)
	content.add_child(item)
	return item

func show_home(message: String = "") -> void:
	menu_screen = "home"
	menu_root.show()
	brand.show()
	hud.hide()
	clear_content("Play", "Two players · private friend invites")
	button("Host a game", show_host, true)
	button("Join a game", show_join)
	button("Practice", show_practice)
	button("How to play", func(): show_guide(false))
	button("Field journal", show_journal)
	button("Watch bots", show_watch)
	button("Settings", func(): show_settings(false))
	button("Quit", func(): get_tree().quit())
	content.add_child(status)
	status.text = message

func port_field() -> SpinBox:
	content.add_child(label("Port", 16, MUTED))
	var port := SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 27015
	port.custom_minimum_size.y = 44
	content.add_child(port)
	return port

func show_host() -> void:
	menu_screen = "host"
	clear_content("Play with a friend", "Choose a level, then create a private invite.")
	level_picker(false)
	button("Create game", func(): game.host_friend_game(), true)
	condition_pickers()
	button("LAN / direct IP", show_lan_host)
	button("Back", show_home)
	content.add_child(status)

func show_join() -> void:
	menu_screen = "join"
	clear_content("Join a friend", "Paste the private invite your friend sent you.")
	var invite := LineEdit.new()
	invite.name = "FriendInvite"
	invite.placeholder_text = "Paste private invite"
	invite.max_length = 4096
	invite.custom_minimum_size.y = 48
	content.add_child(invite)
	button("Paste invite", func(): invite.text = DisplayServer.clipboard_get().strip_edges())
	button("Join friend", func(): game.join_friend_game(invite.text), true)
	button("LAN / direct IP", show_lan_join)
	button("Back", show_home)
	content.add_child(status)
	invite.grab_focus()

func show_friend_lobby(invite: String) -> void:
	menu_root.show()
	clear_content("Waiting for your friend", "%s\n\nCopy this private invite and send it to your friend. It expires in 15 minutes and admits one player." % game.arena.map_title())
	button("Copy private invite", func(): DisplayServer.clipboard_set(invite); set_status("Invite copied. Send it privately to your friend."), true)
	button("Cancel", func(): game.leave_game())
	content.add_child(status)

func update_connection(message: String) -> void:
	if game.phase == "waiting" and menu_root.visible:
		set_status(message)

func show_friend_error(message: String) -> void:
	menu_root.show()
	clear_content("Connection unsuccessful", message)
	button("Retry", func(): game.retry_friend_connection(), true)
	button("Back", func(): game.leave_game())
	content.add_child(status)

func show_lan_host() -> void:
	menu_screen = "host"
	clear_content("LAN / direct host", "Use this for LAN testing. Internet friend invites are available from the previous screen.")
	level_picker()
	var port := port_field()
	var note := label("Internet play: forward this UDP port on the host's router, or use a virtual LAN. No account required.", 17, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	button("Start hosting", func(): game.host_game(int(port.value)), true)
	button("Back", show_home)
	content.add_child(status)

func show_lan_join() -> void:
	menu_screen = "join"
	clear_content("LAN / direct join", "Enter the host's IP address and port.")
	content.add_child(label("Host IP address", 16, MUTED))
	var address := LineEdit.new()
	address.name = "HostAddress"
	address.placeholder_text = "192.168.1.10"
	address.custom_minimum_size.y = 48
	content.add_child(address)
	var port := port_field()
	button("Connect", func(): game.join_game(address.text, int(port.value)), true)
	button("Back", show_home)
	content.add_child(status)
	address.grab_focus()

func show_connection(message: String, pending: bool) -> void:
	menu_root.show()
	clear_content("Waiting for a player" if game.mode == "hosting" else "Connection", message)
	button("Cancel" if pending else "Back", func(): game.leave_game())
	content.add_child(status)

func set_status(message: String) -> void:
	status.text = message

func show_practice() -> void:
	menu_screen = "practice"
	clear_content("Practice", "Choose a level and starting role.")
	button("Learn the rear approach", func(): game.start_lesson("stalker"))
	button("Learn rifle and reload", func(): game.start_lesson("sniper"))
	level_picker()
	button("Play with the knife", func(): game.start_practice("stalker"), true)
	button("Play with the rifle", func(): game.start_practice("sniper"))
	var detail := label("WASD / Mouse   Move / Look\nLeft click   Attack    Right click   Aim\n1   Knife    2   Handgun    R   Reload\nG   Throw pebble    Ctrl   Quiet crouch\nShift   Sprint    Space   Jump", 17, MUTED)
	detail.add_theme_constant_override("line_spacing", 5)
	content.add_child(detail)
	button("Back", show_home)

func level_picker(extended: bool = true) -> void:
	content.add_child(label("Level", 16, MUTED))
	var picker := OptionButton.new()
	picker.name = "LevelPicker"
	picker.custom_minimum_size.y = 44
	for id in Rules.LEVELS:
		picker.add_item(Rules.LEVELS[id])
		var index := picker.item_count - 1
		picker.set_item_metadata(index, id)
		if id == game.selected_level:
			picker.select(index)
	picker.item_selected.connect(func(index: int): game.select_level(picker.get_item_metadata(index)))
	content.add_child(picker)
	content.add_child(label("Rules", 16, MUTED))
	var rules := OptionButton.new()
	rules.name = "RulesPicker"
	rules.custom_minimum_size.y = 44
	for id in Rules.RULESETS:
		rules.add_item(Rules.RULESETS[id])
		rules.set_item_metadata(rules.item_count - 1, id)
		if id == game.selected_ruleset:
			rules.select(rules.item_count - 1)
	rules.item_selected.connect(func(index: int): game.selected_ruleset = rules.get_item_metadata(index))
	content.add_child(rules)
	if extended: condition_pickers()

func condition_pickers() -> void:
	content.add_child(label("Conditions", 16, MUTED))
	var weather := OptionButton.new()
	weather.name = "WeatherPicker"
	weather.custom_minimum_size.y = 42
	for id in Rules.ENVIRONMENTS:
		weather.add_item(Rules.ENVIRONMENTS[id])
		weather.set_item_metadata(weather.item_count - 1, id)
		if id == game.selected_environment: weather.select(weather.item_count - 1)
	weather.item_selected.connect(func(index): game.selected_environment = weather.get_item_metadata(index))
	content.add_child(weather)
	content.add_child(label("Match length", 16, MUTED))
	var length := OptionButton.new()
	length.name = "LengthPicker"
	length.custom_minimum_size.y = 42
	length.add_item("Quick / 2 rounds, swap roles")
	length.add_item("Full / 6 rounds, three role pairs")
	length.select(1 if game.selected_pairs == 3 else 0)
	length.item_selected.connect(func(index): game.selected_pairs = 3 if index == 1 else 1)
	content.add_child(length)

func show_settings(in_game: bool) -> void:
	menu_root.show()
	brand.visible = not in_game
	clear_content("Settings")
	content.add_child(label("Mouse sensitivity", 17, MUTED))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = game.settings.sensitivity
	sensitivity.custom_minimum_size.y = 26
	sensitivity.value_changed.connect(func(value: float): game.settings.sensitivity = value; game.save_settings())
	content.add_child(sensitivity)
	content.add_child(label("Volume", 17, MUTED))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.01
	volume.value = game.settings.volume
	volume.custom_minimum_size.y = 26
	volume.value_changed.connect(func(value: float): game.settings.volume = value; game.save_settings())
	content.add_child(volume)
	for option in [["Invert mouse", "invert"], ["Reduce weapon motion", "reduced_motion"]]:
		var check := CheckButton.new()
		check.text = option[0]
		check.button_pressed = game.settings[option[1]]
		var key: String = option[1]
		check.toggled.connect(func(value: bool): game.settings[key] = value; game.save_settings())
		content.add_child(check)
	var captions := CheckButton.new()
	captions.text = "Sound captions"
	captions.button_pressed = game.settings.captions
	captions.toggled.connect(func(value): game.settings.captions = value; game.save_settings())
	content.add_child(captions)
	content.add_child(label("Field of view", 17, MUTED))
	var fov := HSlider.new()
	fov.min_value = 65
	fov.max_value = 100
	fov.step = 1
	fov.value = game.settings.fov
	fov.value_changed.connect(func(value): game.settings.fov = value; game.save_settings())
	content.add_child(fov)
	button("Keyboard controls", func(): show_controls(in_game))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	content.add_child(fullscreen)
	button("Back", func(): show_match_result() if in_game and game.phase == "match_over" else show_pause(true) if in_game else show_home())

func enter_game() -> void:
	if game.connection_kind == "friends":
		clear_content("")
	menu_root.hide()
	hud.show()

func show_pause(visible: bool) -> void:
	if not visible:
		menu_root.hide()
		hud.show()
		return
	menu_screen = "pause"
	menu_root.show()
	brand.hide()
	hud.hide()
	clear_content("Paused" if game.mode == "practice" else "Menu", "Online rounds continue while this menu is open." if game.mode == "online" else "Practice is paused.")
	button("Resume", func(): game.paused = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; show_pause(false), true)
	button("Settings", func(): show_settings(true))
	button("Leave game", func(): game.leave_game())
	content.add_child(label("WASD  Move    Shift  Sprint\nCtrl  Crouch    Space  Jump\nLMB  Attack    RMB  Aim\n1  Knife    2  Handgun    R  Reload\nG  Throw pebble / three per round", 17, MUTED))

func show_match_result() -> void:
	menu_screen = "result"
	menu_root.show()
	hud.hide()
	brand.hide()
	var winner: int = game.set_winner()
	var title := "Set drawn" if winner == 0 else ("Set won" if winner == game.local_id else "Set lost")
	if game.ruleset_id == Rules.CLASSIC:
		title = "Match won" if winner == game.local_id else "Match lost"
	if game.practice_lesson != "":
		title = "Practice complete"
	clear_content(title, "Final score   %d : %d" % [game.scores.get(game.local_id, 0), game.scores.get(game.guest_id if game.local_id == 1 else 1, 0)])
	if game.is_authority() or game.mode == "online":
		button("Play again", func(): game.rematch(), true)
	else:
		content.add_child(label("Waiting for the host to play again.", 17, MUTED))
	if game.mode == "online":
		var saved := label("",16,MUTED)
		saved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button("Save match recording", func(): saved.text = game.save_match())
		content.add_child(saved)
	button("Review round", show_round_review)
	button("Return to menu", func(): game.leave_game())

func show_round_review() -> void:
	if game.phase not in ["round_over", "match_over"]:
		return
	menu_screen = "review"
	menu_root.show()
	brand.hide()
	hud.hide()
	clear_content("Round review", "Last weapon and wildlife events.")
	var events := label(game.review_text(), 19, CHALK)
	events.add_theme_constant_override("line_spacing", 8)
	content.add_child(events)
	if game.completed_reviews.size() > 1:
		var picker := OptionButton.new()
		for item in game.completed_reviews:
			picker.add_item("Round %d / %s" % [item.round, item.reason])
		picker.select(picker.item_count - 1)
		picker.item_selected.connect(func(index): events.text = game.review_text(index))
		content.add_child(picker)
	content.add_child(label("Which clue would change your next approach?", 17, MUTED))
	if game.is_authority() and game.phase == "match_over":
		button("Play again", func(): game.rematch(), true)
	button("Back", show_match_result)

func place(item: Control, anchor: int, pos: Vector2) -> void:
	hud.add_child(item)
	item.set_anchors_preset(anchor)
	item.offset_left = pos.x
	item.offset_top = pos.y
	item.offset_right = pos.x
	item.offset_bottom = pos.y

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	role_label = label("", 30, CHALK, display_font)
	place(role_label, Control.PRESET_TOP_LEFT, Vector2(40, 27))
	objective_label = label("", 17, MUTED)
	place(objective_label, Control.PRESET_TOP_LEFT, Vector2(40, 67))
	clock_label = label("", 40, CHALK, display_font)
	clock_label.custom_minimum_size.x = 140
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(clock_label, Control.PRESET_CENTER_TOP, Vector2(-70, 23))
	score_label = label("", 20, CHALK)
	score_label.custom_minimum_size.x = 230
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(score_label, Control.PRESET_TOP_RIGHT, Vector2(-270, 34))
	health_label = label("", 17, MUTED)
	health_label.custom_minimum_size.x = 230
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(health_label, Control.PRESET_TOP_RIGHT, Vector2(-270, 69))
	weapon_label = label("", 23, CHALK, display_font)
	place(weapon_label, Control.PRESET_BOTTOM_LEFT, Vector2(40, -91))
	noise_label = label("", 16, MUTED)
	place(noise_label, Control.PRESET_BOTTOM_LEFT, Vector2(40, -123))
	field_label = label("", 18, ACCENT)
	field_label.custom_minimum_size.x = 1080
	field_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(field_label, Control.PRESET_CENTER_BOTTOM, Vector2(-540, -164))
	var controls := label("WASD  Move     Shift  Sprint     Ctrl  Crouch     Space  Jump     Tab  Map     Esc  Menu", 15, MUTED)
	controls.name = "MovementControls"
	place(controls, Control.PRESET_BOTTOM_LEFT, Vector2(40, -42))
	center_label = label("", 60, CHALK, display_font)
	center_label.custom_minimum_size.x = 1000
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(center_label, Control.PRESET_CENTER, Vector2(-500, -124))
	center_detail = label("", 21, CHALK)
	center_detail.custom_minimum_size.x = 1000
	center_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(center_detail, Control.PRESET_CENTER, Vector2(-500, -40))

func _process(delta: float) -> void:
	hit_flash = maxf(hit_flash - delta, 0)
	caption_remaining = maxf(0, caption_remaining - delta)
	var mode_id: String = game.ruleset_id if game.mode != "menu" else game.selected_ruleset
	var pairs: int = game.pairs_to_play if game.mode != "menu" else game.selected_pairs
	footer.text = "%s  /  %s  /  %s" % [game.arena.map_title(), Rules.RULESETS[mode_id], "%d rounds · roles swap" % (pairs * 2) if Rules.modern(mode_id) else "First to 3 · roles swap"]
	if hud.visible:
		var p = game.local_player()
		if p:
			var movement = hud.get_node_or_null("MovementControls")
			if movement: movement.text = "%s%s%s%s Move   %s Sprint   %s Crouch   %s Jump   %s Map   Esc Menu" % [game.key_label("forward"),game.key_label("left"),game.key_label("back"),game.key_label("right"),game.key_label("sprint"),game.key_label("crouch"),game.key_label("jump"),game.key_label("map")]
			role_label.text = "Stalker / Knife + handgun" if p.role == "stalker" else "Sniper / Rifle"
			objective_label.text = "%s / %s" % [game.arena.map_title(), "Stay hidden. Reach the sniper from behind." if p.role == "stalker" else "Use the high contour to change outlooks." if game.arena.map_id == "mountain" else "Hold the ridge. Watch the uphill routes." if game.arena.map_id == "forest" else "Hold the loading deck. Watch the approaches."]
			if game.practice_lesson != "":
				objective_label.text = game.lesson_hint()
			health_label.text = "Health %d / 100" % p.health
			clock_label.text = "%02d:%02d" % [int(ceil(game.round_time)) / 60, int(ceil(game.round_time)) % 60]
			clock_label.modulate = ACCENT if game.round_time < 30 else CHALK
			var other: int = game.guest_id if game.local_id == 1 else 1
			score_label.text = "You  %d    :    %d  Opponent" % [game.scores.get(game.local_id, 0), game.scores.get(other, 0)]
			var readiness := "Ready" if p.cooldown <= 0 else "Cycling bolt  %.1fs" % p.cooldown
			noise_label.text = p.noise_description()
			field_label.text = ""
			if game.field.enabled:
				if game.field.movement_mask() < 0.6:
					field_label.text = "Gust / movement is quieter"
				noise_label.text += "     %s / Reflector %d" % [game.key_label("reflector"), p.reflectors] if p.role == "stalker" else "     %s / Observe     %s / Alarm %d" % [game.key_label("observe"),game.key_label("alarm"), p.alarms]
				var task: Dictionary = game.relay.interaction(p)
				if not task.is_empty():
					field_label.text = "Hold %s / %s   %.1f / %.1fs" % [game.key_label("interact"),task.text, p.interaction_progress, task.seconds]
				elif not game.field.rope_prompt(p).is_empty(): field_label.text = game.field.rope_prompt(p)
				if p.climbing: field_label.text = "Climbing handline / %.0f%%" % (p.climb_progress * 100)
				if game.ruleset_id == Rules.RELAY:
					objective_label.text = "Sabotage two relays or eliminate the sniper." if p.role == "stalker" else "Protect the relays. Repair a disabled station or eliminate the stalker."
					if game.relay.rules.deadline > 0:
						field_label.text += "     Repair deadline %.0fs" % ceilf(game.relay.rules.deadline)
			if caption_remaining > 0 and game.settings.captions:
				field_label.text += "     " + caption_text
			if p.role == "stalker" and (Rules.modern(game.ruleset_id) or game.field.enabled):
				noise_label.text += "     %s / Pebbles %d" % [game.key_label("pebble"),p.pebbles]
			if p.active_weapon == "knife":
				weapon_label.text = "Knife / LMB attack     %s / Equip handgun" % game.key_label("handgun")
			elif p.active_weapon == "handgun":
				var reload_text: String = "Reloading %.1fs" % p.reload_remaining if p.reload_remaining > 0 else "RMB aim / %s reload" % game.key_label("reload")
				weapon_label.text = "Handgun / %d | %d     %s     %s / Knife" % [p.handgun_ammo, p.handgun_reserve, reload_text,game.key_label("knife")]
			else:
				if p.reload_remaining > 0:
					readiness = "Reloading %.1fs" % p.reload_remaining
				weapon_label.text = "Rifle / %s     %s     RMB scope / %s reload" % ["%d | %d" % [p.rifle_ammo, p.rifle_reserve] if Rules.modern(game.ruleset_id) else "Unlimited", readiness,game.key_label("reload")]
			center_label.text = ""
			center_detail.text = ""
			if game.phase == "countdown":
				center_label.text = str(maxi(1, ceili(game.transition_time)))
				center_detail.text = "Rear knife is lethal. %s throws a distraction. %s moves quietly." % [game.key_label("pebble"),game.key_label("crouch")] if p.role == "stalker" and Rules.modern(game.ruleset_id) else "Stay hidden. Pick your shot; %s reloads your rifle." % game.key_label("reload") if p.role == "sniper" and Rules.modern(game.ruleset_id) else "Stay hidden. Use cover and listen."
			elif game.phase == "round_over":
				center_label.text = "Round drawn" if game.winner_id == 0 else "Round won" if game.winner_id == game.local_id else "Round lost"
				center_detail.text = "%s  Roles swap in %d." % [game.result_text, maxi(1, ceili(game.transition_time))]
			if game.mode == "online": health_label.text += "   %d ms" % game.ping_ms
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if menu_root and menu_root.visible:
		return
	if not hud or not hud.visible:
		return
	var p = game.local_player()
	if not p:
		return
	var c := viewport_size / 2.0
	if p.scoped and game.phase == "playing":
		var radius := viewport_size.y * 0.37
		for i in range(96):
			var a := TAU * i / 96.0
			var b := TAU * (i + 1) / 96.0
			var points := PackedVector2Array([c + Vector2.from_angle(a) * radius, c + Vector2.from_angle(b) * radius, c + Vector2.from_angle(b) * viewport_size.length(), c + Vector2.from_angle(a) * viewport_size.length()])
			draw_colored_polygon(points, Color(0.025, 0.045, 0.055, 0.98))
		draw_arc(c, radius, 0, TAU, 128, Color("85969c"), 3, true)
		draw_line(c - Vector2(radius, 0), c + Vector2(radius, 0), Color("14222b"), 1.5, true)
		draw_line(c - Vector2(0, radius), c + Vector2(0, radius), Color("14222b"), 1.5, true)
		for i in range(-4, 5):
			if i:
				draw_line(c + Vector2(i * 35, -5), c + Vector2(i * 35, 5), Color("14222b"), 1.5)
				draw_line(c + Vector2(-5, i * 35), c + Vector2(5, i * 35), Color("14222b"), 1.5)
		draw_circle(c, 2, ACCENT)
	elif game.phase == "playing":
		var cross := Color(0.93, 0.94, 0.9, 0.9)
		if p.active_weapon == "knife":
			draw_circle(c, 2, cross)
		else:
			for axis in [Vector2.RIGHT, Vector2.DOWN]:
				draw_line(c + axis * 5, c + axis * 12, cross, 1.3, true)
				draw_line(c - axis * 5, c - axis * 12, cross, 1.3, true)
	# HUD backplates are drawn after the scope to preserve legibility.
	draw_rect(Rect2(0, 0, viewport_size.x, 112), Color(0.07, 0.12, 0.16, 0.68))
	draw_rect(Rect2(0, viewport_size.y - 110, viewport_size.x, 110), Color(0.07, 0.12, 0.16, 0.72))
	if hit_flash > 0:
		for dir in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			draw_line(c + dir * 10, c + dir * 19, ACCENT, 3)
	if Input.is_action_pressed("map"):
		_draw_map(Rect2(viewport_size.x - 300, viewport_size.y - 452, 256, 328), p)

func _draw_map(rect: Rect2, p: Node3D) -> void:
	draw_rect(rect.grow(12), Color("1b303d"))
	draw_rect(rect, Color("3c535f"))
	for solid in game.arena.solids:
		var pos: Vector2 = rect.position + (solid.position + Vector2(36, 46)) / Vector2(72, 92) * rect.size
		var extent: Vector2 = solid.size / Vector2(72, 92) * rect.size
		draw_rect(Rect2(pos, extent), Color("91a2a8"))
	var point := rect.position + (Vector2(p.position.x, p.position.z) + Vector2(36, 46)) / Vector2(72, 92) * rect.size
	draw_circle(point, 4.5, ACCENT)
	var forward := Vector2(-sin(p.aim.x), -cos(p.aim.x))
	draw_line(point, point + forward * 13, ACCENT, 2)
	draw_string(body_font, rect.position - Vector2(0, 19), "%s · your position only" % game.arena.map_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CHALK)
	if game.selected_level == "mountain":
		for i in range(7):
			var nest: Vector3 = game.arena.Mountain.NESTS[i]
			var marker := rect.position + (Vector2(nest.x, nest.z) + Vector2(36,46)) / Vector2(72,92) * rect.size
			draw_circle(marker, 3, CHALK)
			draw_string(body_font, marker + Vector2(5,-4), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CHALK)

func show_ready_room() -> void:
	menu_screen = "ready"
	menu_root.show()
	brand.show()
	hud.hide()
	clear_content("Ready to play", "%s\n%s / %s\n%d rounds with exchanged roles." % [game.arena.map_title(), Rules.RULESETS[game.ruleset_id], Rules.ENVIRONMENTS[game.environment_id], 2 * game.pairs_to_play])
	var other: int = game.guest_id if game.local_id == 1 else 1
	content.add_child(label("You: %s\nFriend: %s" % ["ready" if game.ready_players.get(game.local_id,false) else "not ready", "ready" if game.ready_players.get(other,false) else "not ready"], 20, CHALK))
	if game.connection_kind == "friends":
		content.add_child(label("Private connection / %s" % game.friends.route, 17, MUTED))
	var already_ready: bool = game.ready_players.get(game.local_id,false)
	button("Not ready" if already_ready else "Ready", func(): game.set_ready(not already_ready), true)
	button("Leave game", func(): game.leave_game())
	content.add_child(label("Both players must be ready.\nRoles swap after each round.\nF1 opens the field guide.", 17, MUTED))

func show_watch() -> void:
	menu_screen = "watch"
	clear_content("Watch", "Live bots or a saved split-screen session.")
	level_picker()
	button("Start live bots", func(): game.start_bot_duel(), true)
	button("Watch recorded session", func(): game.start_featured_replay())
	button("Your recordings", show_recordings)
	button("Back", show_home)

func show_journal() -> void:
	menu_screen = "journal"
	clear_content("Field journal","Your visited overlooks and completed online rounds. Stored on this PC.")
	if not game.journal.error.is_empty():
		var detail := label(game.journal.error,17,ACCENT)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)
	for role in ["stalker","sniper"]:
		var record: Dictionary = game.journal.data[role]
		content.add_child(label("%s / %d won, %d lost, %d drawn" % [role.capitalize(),record.win,record.loss,record.draw],18,CHALK))
	content.add_child(label("Crow's Ridge",25,ACCENT,display_font))
	for i in range(7):
		var visited: bool = game.journal.data.visits.any(func(value): return int(value) == i)
		content.add_child(label("%s / %s" % [game.arena.Mountain.NAMES[i],"visited" if visited else "unvisited"],17,CHALK if visited else MUTED))
	button("Back",show_home)

func show_guide(in_game: bool = false) -> void:
	menu_screen = "guide"
	menu_root.show()
	brand.visible = not in_game
	hud.hide()
	clear_content("Field guide", "Roles swap every round. Keys below are defaults; Settings shows your bindings.")
	for heading in ["Stalker", "Sniper", "Forest and relays", "Play with a friend"]:
		content.add_child(label(heading, 25, ACCENT, display_font))
		var copy: String = {"Stalker":"Ctrl moves quietly. Use cover and approach from behind: a rear knife hit is lethal. Front strikes give the defender a counterattack window. Equip the handgun with 2; right click aims. G throws one of three pebbles. Q places your reflector decoy.", "Sniper":"Stay on the connected high ground. Hold B to observe without rifle glint; release it before firing. Right click scopes. R reloads the three-round rifle. T places one visible tripwire alarm; any player can trigger it. Pick a new angle when your old one is exposed.", "Forest and relays":"Gusts and rain mask movement. Mud preserves fading footprints; they show past passage. Tab shows your location and numbered overlooks. In Relay infiltration, hold E at two stations to sabotage them. The sniper can repair. Two offline stations start a 30-second deadline. E also uses the western handline.", "Play with a friend":"Use the same Windows demo build. Host chooses the map, rules and conditions, creates an invite and sends it privately. Friend pastes it into Join a game. Both press Ready. F1 opens this guide; online rounds continue while menus are open."}[heading]
		var detail := label(copy, 17, CHALK)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)
	if game.selected_level == "mountain":
		content.add_child(label("Crow's Ridge overlooks", 25, ACCENT, display_font))
		for i in range(7): content.add_child(label("%d / %s" % [i + 1, game.arena.Mountain.NAMES[i]], 17, MUTED))
	button("Back", func(): show_match_result() if in_game and game.phase == "match_over" else show_pause(true) if in_game else show_home())

func show_controls(in_game: bool = false) -> void:
	menu_screen = "controls"
	clear_content("Keyboard controls", "Choose an action, then press a key. Esc cancels. Conflicting keys swap assignments.")
	for action in game.bindings:
		var name_text: String = action.capitalize() + " / " + OS.get_keycode_string(int(game.bindings[action]))
		var key_action: String = action
		button(name_text, func(): game.rebinding = key_action; set_status("Press a key for " + key_action + "."))
	content.add_child(status)
	button("Back", func(): show_settings(in_game))

func sound_caption(kind: String, point: Vector3, audible_range: float = -1.0) -> void:
	if not game.settings.captions or game.mode not in ["online", "practice"] or game.phase != "playing": return
	var actor = game.local_player()
	if not actor or actor.eye_position().distance_to(point) < 0.7: return
	var reach: float = 100 if kind == "rifle" else 55 if kind == "handgun" else 18 if kind.begins_with("step") else 45 if kind == "alarm" else 24
	if audible_range >= 0: reach = audible_range
	if actor.eye_position().distance_to(point) > reach: return
	var offset: Vector3 = point - actor.eye_position()
	var right := Vector3(cos(actor.aim.x),0,-sin(actor.aim.x))
	var side := right.dot(offset.normalized())
	caption_text = ("Movement" if kind.begins_with("step") else kind.capitalize()) + (" / right" if side > 0.35 else " / left" if side < -0.35 else " / ahead or behind")
	caption_remaining = 1.6

func show_recordings() -> void:
	menu_screen = "recordings"
	clear_content("Your recordings", "Saved matches on this PC. Playback shows both recorded viewpoints.")
	var files := DirAccess.get_files_at("user://recordings")
	files.sort()
	files.reverse()
	var count := 0
	for filename in files:
		if not filename.ends_with(".json"): continue
		var path := "user://recordings/" + filename
		button(filename.trim_suffix(".json"), func(): game.start_replay(path))
		count += 1
		if count >= 20: break
	if count == 0: content.add_child(label("Finish an online match, then choose Save match recording.",17,MUTED))
	button("Back", show_watch)
