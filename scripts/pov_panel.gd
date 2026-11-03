extends Control

const BODY_FONT: Font = preload("res://assets/fonts/Body.ttf")
const DISPLAY_FONT: Font = preload("res://assets/fonts/Display.ttf")
const CHALK := Color("ece9df")
const ACCENT := Color("dfb46d")
var game: Node3D
var actor
var bot_id: int = 1
var viewport: SubViewport
var camera: Camera3D
var container: SubViewportContainer

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	container = SubViewportContainer.new()
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.world_3d = get_viewport().world_3d
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	# Drawing on a separate child places HUD graphics above the viewport texture.
	var overlay := Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_hud.bind(overlay))
	set_meta("overlay", overlay)

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(actor):
		return
	camera.global_transform = actor.camera.global_transform
	camera.fov = actor.camera.fov
	camera.near = actor.camera.near
	camera.far = actor.camera.far
	camera.cull_mask = actor.camera.cull_mask
	(get_meta("overlay") as Control).queue_redraw()

func _draw_hud(canvas: Control) -> void:
	if not is_instance_valid(actor):
		return
	var c := size / 2.0
	if actor.scoped:
		var radius := minf(size.x, size.y) * 0.43
		for i in range(80):
			var a := TAU * i / 80.0
			var b := TAU * (i + 1) / 80.0
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * radius, c + Vector2.from_angle(b) * radius, c + Vector2.from_angle(b) * size.length(), c + Vector2.from_angle(a) * size.length()]), Color("101b21"))
		canvas.draw_arc(c, radius, 0, TAU, 100, Color("849591"), 2, true)
		canvas.draw_line(c - Vector2(radius, 0), c + Vector2(radius, 0), Color("162125"), 1.5)
		canvas.draw_line(c - Vector2(0, radius), c + Vector2(0, radius), Color("162125"), 1.5)
		for i in range(-3, 4):
			canvas.draw_line(c + Vector2(-4, i * 32), c + Vector2(4, i * 32), Color("162125"), 1)
		canvas.draw_circle(c, 2, ACCENT)
	else:
		canvas.draw_circle(c, 2, CHALK)
		if actor.active_weapon != "knife":
			canvas.draw_line(c - Vector2(10, 0), c - Vector2(5, 0), CHALK, 1)
			canvas.draw_line(c + Vector2(5, 0), c + Vector2(10, 0), CHALK, 1)
	canvas.draw_rect(Rect2(0, 0, size.x, 76), Color(0.07, 0.12, 0.15, 0.84))
	canvas.draw_rect(Rect2(0, size.y - 86, size.x, 86), Color(0.07, 0.12, 0.15, 0.85))
	var role: String = "Stalker" if actor.role == "stalker" else "Sniper"
	var human: bool = game.mode == "replay" and game.replay and game.replay.data.get("actors_kind", "bots") == "players"
	canvas.draw_string(DISPLAY_FONT, Vector2(22, 32), "%s %d / %s" % ["Player" if human else "Bot", bot_id, role], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CHALK)
	var brain = game.bot_brains.get(bot_id)
	var behavior: String = "Recorded viewpoint" if human else brain.state if brain else "Waiting"
	if actor.role == "stalker" and not human:
		var watcher = game.bot_brains.get(2 if bot_id == 1 else 1)
		behavior += " / Spotted" if watcher and watcher.sightings > 0 else " / Undetected"
	canvas.draw_string(BODY_FONT, Vector2(22, 58), behavior, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("b4c4c7"))
	canvas.draw_string(BODY_FONT, Vector2(size.x - 100, 32), "Wins %d" % game.scores.get(bot_id, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)
	var weapon_text: String = actor.active_weapon.capitalize()
	if actor.active_weapon == "handgun":
		weapon_text += "   %d | %d" % [actor.handgun_ammo, actor.handgun_reserve]
	elif actor.active_weapon == "rifle" and game.Rules.modern(game.ruleset_id):
		weapon_text += "   %d | %d" % [actor.rifle_ammo, actor.rifle_reserve]
	if actor.role == "stalker" and game.Rules.modern(game.ruleset_id):
		weapon_text += "   Pebbles %d" % actor.pebbles
	if actor.reload_remaining > 0:
		weapon_text += "   Reloading %.1fs" % actor.reload_remaining
	elif actor.cooldown > 0 and actor.active_weapon == "rifle":
		weapon_text += "   Cycling bolt %.1fs" % actor.cooldown
	canvas.draw_string(DISPLAY_FONT, Vector2(22, size.y - 52), weapon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, CHALK)
	canvas.draw_rect(Rect2(22, size.y - 32, 130, 5), Color("43575d"))
	canvas.draw_rect(Rect2(22, size.y - 32, 130 * actor.health / 100.0, 5), ACCENT)
	canvas.draw_string(BODY_FONT, Vector2(166, size.y - 23), "%d / 100" % actor.health, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CHALK)
	if actor.hit_feedback > 0:
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			canvas.draw_line(c + d * 10, c + d * 18, ACCENT, 2)
	if actor.damage_flash > 0:
		canvas.draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Color(0.7, 0.31, 0.22, actor.damage_flash * 3), false, 5)
	if game.phase == "round_over" or game.phase == "match_over":
		var message: String = "Round drawn" if game.winner_id == 0 else "Round won" if game.winner_id == bot_id else "Round lost"
		if game.phase == "match_over" and game.Rules.modern(game.ruleset_id):
			message = "Set drawn" if game.set_winner() == 0 else "Set won" if game.set_winner() == bot_id else "Set lost"
		canvas.draw_string(DISPLAY_FONT, c + Vector2(-90, -50), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, CHALK)
