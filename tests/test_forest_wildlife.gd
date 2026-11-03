extends SceneTree

var failures := 0
var checks := 0
var game

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_bot_duel("forest")
	game.bot_enabled = false
	game.set_physics_process(false)
	game.phase = "playing"
	var animals = game.arena.get_node("Wildlife")
	var species: Dictionary = {}
	for walker in animals.walkers:
		species[walker.species] = true
	check(species.has("deer") and species.has("fox") and species.has("rabbit"), "forest contains deer, foxes and rabbits")
	check(game.arena.forest_details.get("TallGrass", 0) > 1000, "forest has substantial patches of tall grass")
	game.round_time = 149
	game.field.clock = 1
	await frames(3)
	var positions: Array[Vector3] = []
	for walker in animals.walkers:
		positions.append(walker.node.position)
	game.round_time = 144
	game.field.clock = 6
	await frames(3)
	var moved := false
	var grounded := true
	var animated := false
	for i in range(animals.walkers.size()):
		var walker: Dictionary = animals.walkers[i]
		moved = moved or walker.node.position.distance_to(positions[i]) > 0.5
		var pos: Vector3 = walker.node.position
		grounded = grounded and pos.y >= game.arena.height_at(pos.x, pos.z) - 0.02
		animated = animated or walker.animation.current_animation.to_lower().contains("walk")
	check(moved and animated, "wildlife walks along paths with animated legs")
	check(grounded, "wildlife follows the mountain terrain")
	game.paused = true
	var stopped: Vector3 = animals.walkers[0].node.position
	await frames(5)
	check(animals.walkers[0].node.position.is_equal_approx(stopped), "pause stops ambient wildlife")
	var birds = game.arena.birds
	check(birds.flocks.size() > 8 and birds.bird_models.size() > 24, "birds perch in flocks throughout the forest")
	game.paused = false
	game.round_time = 140
	game.field.clock = 10
	var p = game.players[1]
	var perch: Vector3 = birds.flocks[0].perch
	p.position = Vector3(perch.x + 1.1, game.arena.height_at(perch.x, perch.z), perch.z + 1)
	p.crouched = true
	p.velocity = Vector3(2.3, 0, 0)
	birds.sense_clock = 0
	birds._physics_process(0.2)
	check(birds.alarm_count == 0, "quiet crouched movement does not startle birds")
	p.crouched = false
	p.velocity = Vector3(6, 0, 0)
	var brain = game.bot_brains[2]
	brain.visible = false
	# Keep the positive hearing case within even the occluded audible radius.
	brain.actor.position = Vector3(perch.x + 8,game.arena.height_at(perch.x + 8,perch.z),perch.z)
	birds.sense_clock = 0
	birds._physics_process(0.2)
	check(birds.alarm_count > 0, "noisy movement beneath a tree startles its birds")
	check(brain.bird_memory > 0 and not brain.visible, "sniper investigates a bird cue without acquiring magical sight")
	check(Vector2(brain.last_known.x - p.position.x, brain.last_known.z - p.position.z).length() > 1, "bird clue identifies disturbed trees rather than the player's exact position")
	var count: int = birds.alarm_count
	birds.sense_clock = 0
	birds._physics_process(0.2)
	check(birds.alarm_count == count, "bird alarm cooldown prevents continuous repeated alerts")
	p.velocity = Vector3.ZERO
	game.round_time = 138
	game.field.clock = 12
	await frames(3)
	check(birds.bird_positions[0].distance_to(perch) > 3, "startled birds actually fly away from their perch")
	game.round_time = 112
	game.field.clock = 38
	await frames(3)
	check(birds.bird_positions[0].distance_to(perch) < 0.7, "birds return to their tree after the flight")
	birds.reset_round(game.round_index)
	birds.hear_shot(p.eye_position(), 1, "knife")
	check(birds.alarm_count == 0, "knife attacks do not create a gunshot bird cue")
	birds.hear_shot(p.eye_position(), 1, "handgun")
	check(birds.alarm_count > 0, "gunfire startles nearby birds")
	birds.reset_round(game.round_index)
	check(birds.alarm_count == 0, "a new round clears old bird cues")
	p.crouched = false
	p.velocity = Vector3(0, 7, 0)
	birds.sense_clock = 0
	birds._physics_process(0.2)
	check(birds.alarm_count > 0, "jumping under a tree can give away the player's approach")
	birds.reset_round(game.round_index)
	game.bird_alarm(game.round_index + 1, 0, Vector3.FORWARD, game.round_time)
	game.bird_alarm(game.round_index, 0, Vector3(INF, 0, 0), game.round_time)
	check(birds.alarm_count == 0, "stale and malformed bird events are rejected")
	game.leave_game()
	game.select_level("yard")
	check(game.arena.birds == null and not game.arena.has_node("Wildlife"), "changing maps removes forest wildlife and bird sensors")
	game.queue_free()
	await frames(6)
	print("FOREST_WILDLIFE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
