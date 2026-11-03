extends Control

const PovPanel = preload("res://scripts/pov_panel.gd")
const Rules = preload("res://scripts/rules.gd")
var game: Node3D
var views: Array[Control] = []
var status: Label
var pause_button: Button
var level: OptionButton
var listener: AudioListener3D
var row: HBoxContainer
var restart_button: Button
var live_button: Button
var replay_controls: HBoxContainer
var timeline: HSlider
var replay_time: Label
var speed: OptionButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("1b303b")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row = HBoxContainer.new()
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 58
	row.offset_bottom = -54
	row.add_theme_constant_override("separation", 3)
	for id in [1, 2]:
		var panel := PovPanel.new()
		panel.game = game
		panel.bot_id = id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		views.append(panel)
	status = Label.new()
	status.add_theme_font_override("font", load("res://assets/fonts/Display.ttf"))
	status.add_theme_font_size_override("font_size", 26)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 12
	status.offset_bottom = 48
	var controls := HBoxContainer.new()
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 20
	controls.offset_top = -46
	controls.offset_right = -20
	controls.offset_bottom = -5
	controls.add_theme_constant_override("separation", 12)
	pause_button = _button(controls, "Pause", _toggle_pause)
	restart_button = _button(controls, "Restart duel", func():
		if game.mode == "replay":
			game.replay.seek(0)
			game.paused = false
		else:
			game.start_bot_duel())
	level = OptionButton.new()
	for id in Rules.LEVELS:
		level.add_item(Rules.LEVELS[id])
		level.set_item_metadata(level.item_count - 1, id)
	level.item_selected.connect(func(index: int): game.start_bot_duel(level.get_item_metadata(index)))
	controls.add_child(level)
	live_button = _button(controls, "Live bots", func(): game.start_bot_duel())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	_button(controls, "Menu", func(): game.leave_game())
	replay_controls = HBoxContainer.new()
	add_child(replay_controls)
	replay_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	replay_controls.offset_left = 20
	replay_controls.offset_top = -92
	replay_controls.offset_right = -20
	replay_controls.offset_bottom = -57
	replay_controls.add_theme_constant_override("separation", 16)
	replay_time = Label.new()
	replay_time.custom_minimum_size.x = 145
	replay_controls.add_child(replay_time)
	timeline = HSlider.new()
	timeline.step = 0.1
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.tooltip_text = "Seek through the recorded match"
	timeline.value_changed.connect(func(value: float):
		if game.mode == "replay" and game.replay:
			game.replay.seek(value))
	replay_controls.add_child(timeline)
	speed = OptionButton.new()
	for value in [0.5, 1.0, 2.0, 4.0]:
		speed.add_item("%s×" % value)
		speed.set_item_metadata(speed.item_count - 1, value)
	speed.select(1)
	speed.item_selected.connect(func(index: int):
		if game.replay:
			game.replay.rate = speed.get_item_metadata(index))
	replay_controls.add_child(speed)
	listener = AudioListener3D.new()
	game.add_child(listener)
	hide()

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func start() -> void:
	for i in range(views.size()):
		views[i].actor = game.players[i + 1]
		views[i].viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for index in range(level.item_count):
		if level.get_item_metadata(index) == game.selected_level:
			level.select(index)
	get_viewport().disable_3d = true
	var recorded: bool = game.mode == "replay"
	replay_controls.visible = recorded
	live_button.visible = recorded
	level.visible = not recorded
	restart_button.text = "Restart recording" if recorded else "Restart duel"
	row.offset_bottom = -104 if recorded else -54
	if recorded:
		timeline.set_block_signals(true)
		timeline.max_value = game.replay.duration
		timeline.set_value_no_signal(game.replay.position)
		timeline.set_block_signals(false)
		for index in range(speed.item_count):
			if is_equal_approx(speed.get_item_metadata(index), game.replay.rate):
				speed.select(index)
	listener.make_current()
	show()

func stop() -> void:
	get_viewport().disable_3d = false
	for panel in views:
		panel.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		panel.actor = null
	if listener:
		listener.clear_current()
	hide()

func _process(_delta: float) -> void:
	if not visible:
		return
	pause_button.text = "Resume" if game.paused else "Pause"
	var time_text := "%02d:%02d" % [int(ceil(game.round_time)) / 60, int(ceil(game.round_time)) % 60]
	var phase_text: String = "Round %d / %d" % [game.round_index + 1, game.pairs_to_play * 2] if Rules.modern(game.ruleset_id) else "Round %d" % (game.round_index + 1)
	if game.phase == "countdown":
		phase_text = "Starting in %d" % maxi(1, ceili(game.transition_time))
	elif game.phase == "round_over":
		phase_text = "Roles swap in %d" % maxi(1, ceili(game.transition_time))
	elif game.phase == "match_over":
		phase_text = "%s / New set in %d" % ["Set drawn" if game.set_winner() == 0 else "Bot %d wins" % game.set_winner(), maxi(1, ceili(game.transition_time))]
	status.text = "%s     %s     %s" % [game.arena.map_title(), time_text, phase_text]
	if game.ruleset_id == Rules.RELAY:
		status.text += "     Relays %d offline" % game.relay.rules.stations.count(1)
		if game.relay.rules.deadline > 0: status.text += " / Repair %.0fs" % game.relay.rules.deadline
	if game.mode == "replay" and game.replay:
		status.text = "Recorded session     " + status.text
		timeline.set_value_no_signal(game.replay.position)
		replay_time.text = "%s / %s" % [_time(game.replay.position), _time(game.replay.duration)]
		if game.replay.position >= game.replay.duration:
			status.text = "End of recording     " + game.arena.map_title()
	if game.players.size() == 2:
		listener.position = (game.players[1].eye_position() + game.players[2].eye_position()) * 0.5

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _toggle_pause() -> void:
	if game.mode == "replay" and game.replay.position >= game.replay.duration:
		game.replay.seek(0)
		game.paused = false
	else:
		game.paused = not game.paused
