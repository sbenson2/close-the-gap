extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_bot_duel("mountain")
	game.bot_enabled = false
	game.paused = true
	game.phase = "playing"
	var actor = game.players[1]
	actor.position = game.arena.spawn_for("stalker")
	actor.aim = Vector2.ZERO
	var point: Vector3 = actor.position + Vector3(0,0,-2)
	point.y = game.arena.height_at(point.x,point.z)
	game.field.apply_event("place",[1,"reflector",[point.x,point.y,point.z],0,0])
	for i in range(2): await physics_frame
	var cue: Dictionary = game.field.visible_evidence(actor)
	check(not cue.is_empty() and cue.source == "reflection" and not cue.has("owner") and not cue.has("is_fake"), "visible optical evidence carries no owner or decoy identity")
	actor.aim = Vector2(PI,0)
	check(game.field.visible_evidence(actor).is_empty(), "a cue outside direct view cannot enter the bot's observations")
	actor.aim = Vector2.ZERO
	game.arena.box(actor.position + Vector3(0,1,-1), Vector3(4,4,.2),game.arena.concrete,true,false)
	for i in range(2): await physics_frame
	check(game.field.visible_evidence(actor).is_empty(), "solid occlusion blocks reflector evidence")
	game.field.restore_events([["track",[2,[point.x,point.y,point.z],0,0]]],30)
	check(game.field.tracks.is_empty(), "old footprints expire instead of becoming permanent tracking")
	game.mode = "practice"
	game.ui.caption_text = ""
	game.ui.sound_caption("step_gravel",point,1)
	check(game.ui.caption_text.is_empty(), "captions cannot reveal a sound outside its actual audible range")
	game.start_bot_duel("mountain")
	game.bot_enabled = false
	game.paused = true
	game.phase = "playing"
	actor = game.players[1]
	actor.position = game.field.rope_points[0]
	actor.velocity = Vector3.ZERO
	game.field._start_rope(actor)
	check(actor.climbing, "the western handline can be used from its physical base")
	for i in range(600):
		game.field.step(1.0/60)
		await physics_frame
		if not actor.climbing: break
	var destination: Vector3 = game.field.rope_points[-1]
	print("HANDLINE_END ",actor.position," destination=",destination)
	check(actor.position.distance_to(destination) < .6 and not actor.climbing, "handline movement reaches its upper anchor through actual capsule collision")
	game.start_bot_duel("yard")
	game.bot_enabled = false
	game.paused = true
	game.phase = "playing"
	actor = game.players[1]
	actor.position = Vector3(0,3.95,-37.8)
	game.players[2].position = Vector3(15,3.95,-40)
	game.field.apply_event("place",[1,"alarm",[0,3.95,-37],0,0])
	game.field.step(2)
	check(not game.field.gadgets[0].triggered, "an alarm requires touching its visible wire rather than entering an invisible radius")
	actor.position = Vector3(0,3.95,-37)
	game.field.step(.016)
	check(game.field.gadgets[0].triggered, "actual capsule contact with the wire creates a physical alarm event")
	game.leave_game()
	game.queue_free()
	for i in range(3): await process_frame
	print("DEMO_FIELD_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
