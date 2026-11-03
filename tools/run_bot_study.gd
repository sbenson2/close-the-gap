extends SceneTree

var game
var trace: FileAccess
var output: String
var records: Array = []
var round_id := 0
var previous_positions: Dictionary = {}
var totals: Dictionary = {}
var controller_hash := ""

func _initialize() -> void:
	call_deferred("run")

func sample(seconds: float) -> void:
	var bots: Array = []
	for id in [1, 2]:
		var actor = game.players[id]
		var brain = game.bot_brains[id]
		var hide: Variant = brain.get("hide_plan")
		var role: String = actor.role
		var travelled: float = actor.position.distance_to(previous_positions.get(id, actor.position))
		previous_positions[id] = actor.position
		totals[role + "_distance"] += travelled
		if brain.visible:
			totals[role + "_sees_seconds"] += seconds
		if travelled < 0.04:
			totals[role + "_stationary_seconds"] += seconds
			if actor.command_move.length() > 0.3:
				totals[role + "_stalled_seconds"] += seconds
		var high_ground_valid: bool = game.arena.Mountain.sniper_allowed(Vector2(actor.position.x, actor.position.z)) if game.arena.map_id == "mountain" else game.arena.sniper_bounds().grow(0.03).has_point(Vector2(actor.position.x, actor.position.z))
		if role == "sniper" and not high_ground_valid:
			totals.high_ground_violations += 1
		if role == "stalker" and brain.state == "Sneaking along covered flank" and brain.waypoint >= brain.path.size() and Vector2(actor.position.x - brain.goal.x, actor.position.z - brain.goal.z).length() > 1.2:
			totals.stalker_unresolved_arrival_seconds += seconds
		if game.arena.map_id == "mountain" and role == "sniper":
			var nest: int = game.arena.Mountain.nearest_nest(actor.position)
			var center: Vector3 = game.arena.Mountain.NESTS[nest]
			if Vector2(actor.position.x - center.x, actor.position.z - center.z).length() < 4.5:
				totals.visited_outlooks[str(nest)] = true
		bots.append({"id": id, "role": role, "position": [actor.position.x, actor.position.y, actor.position.z],
			"aim": [actor.aim.x, actor.aim.y], "crouched": actor.crouched, "scoped": actor.scoped,
			"state": brain.state, "visible": brain.visible, "memory_age": brain.memory_age,
			"estimate": [brain.last_known.x, brain.last_known.y, brain.last_known.z],
			"path_points": brain.path.size(), "path_queries": brain.path_queries,
			"goal": [brain.goal.x, brain.goal.y, brain.goal.z], "waypoint": brain.waypoint,
			"shots": brain.shots, "sightings": brain.sightings,
			"visual_age": brain.get("visual_age"), "cue": brain.get("cue_source"), "cue_age": brain.get("cue_age"),
			"cue_radius": brain.get("cue_radius"), "hide_lanes": hide.get("lanes", 0) if hide is Dictionary else 0})
	trace.store_line(JSON.stringify({"round": round_id, "seconds": snappedf(game.round_elapsed(), 0.001), "phase": game.phase, "bots": bots}))

func reset_totals() -> void:
	totals = {"high_ground_violations": 0, "visited_outlooks": {}, "stalker_unresolved_arrival_seconds": 0.0}
	for role in ["stalker", "sniper"]:
		for metric in ["distance", "sees_seconds", "stationary_seconds", "stalled_seconds"]:
			totals[role + "_" + metric] = 0.0
	previous_positions.clear()

func run() -> void:
	controller_hash = FileAccess.get_sha256("res://scripts/bot_controller.gd")
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() else "res://artifacts/ai-upgrade/study"
	var count := clampi(int(args[1]), 1, 24) if args.size() > 1 else 12
	var first_seed := int(args[2]) if args.size() > 2 else 71
	var fast_countdown := "--fast-countdown" in args
	DirAccess.make_dir_recursive_absolute(output)
	trace = FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	game.sound.muted = true
	if "--relay" in args: game.selected_ruleset = "relay_v1"
	if "--rain" in args: game.selected_environment = "rain"
	await physics_frame
	var started := Time.get_ticks_msec()
	var study_levels := ["mountain"] if "--mountain" in args else ["forest", "yard"]
	for level in study_levels:
		for index in range(count):
			var seed_value := first_seed + index * 137
			game.duel_seed = seed_value
			game.start_bot_duel(level)
			for assignment in range(2):
				reset_totals()
				if fast_countdown:
					game.transition_time = 0.01
				var ticks := 0
				for frame in range(11200):
					await physics_frame
					if game.phase == "playing":
						ticks += 1
						if ticks % 15 == 0:
							sample(0.25)
					if game.phase in ["round_over", "match_over"]:
						break
				var record: Dictionary = totals.duplicate()
				record.merge({"id": round_id, "level": level, "seed": seed_value, "assignment": assignment,
					"duration": snappedf(game.round_elapsed(), 0.001), "result": game.result_text, "relay": game.relay.rules.snapshot(), "field_objects": game.field.gadgets.size(),
					"winner_role": game.players[game.winner_id].role if game.winner_id in game.players else ("draw" if game.phase in ["round_over", "match_over"] else "none"), "bots": []})
				for id in [1, 2]:
					var actor = game.players[id]
					var brain = game.bot_brains[id]
					var stats: Variant = brain.get("tactics")
					var hide: Variant = brain.get("hide_plan")
					record.bots.append({"role": actor.role, "state": brain.state, "shots": brain.shots,
						"rifle_ammo": actor.rifle_ammo, "rifle_reserve": actor.rifle_reserve, "pebbles": actor.pebbles,
						"sightings": brain.sightings, "path_queries": brain.path_queries,
						"position": [actor.position.x, actor.position.y, actor.position.z],
						"hide_lanes": hide.get("lanes", 0) if hide is Dictionary else 0,
						"route_ms": stats.route_ms if stats else 0,
						"max_route_ms": stats.max_route_ms if stats else 0,
						"ray_tests": stats.ray_tests if stats else 0,
						"slowest_route": stats.slowest_route if stats else {}})
				records.append(record)
				var checkpoint := FileAccess.open(output.path_join("results.partial.json"), FileAccess.WRITE)
				checkpoint.store_string(JSON.stringify({"rounds": records, "controller_sha256": controller_hash}))
				checkpoint.close()
				trace.flush()
				round_id += 1
				print("STUDY_ROUND ", JSON.stringify({"id": round_id, "total": count * study_levels.size() * 2, "level": level, "seed": seed_value, "result": game.result_text, "relay": game.relay.rules.snapshot(), "field_objects": game.field.gadgets.size(), "seconds": record.duration}), " wall_ms=", Time.get_ticks_msec() - started)
				if game.phase not in ["round_over", "match_over"]:
					push_error("Study round did not complete within 11200 physics frames")
					quit(1)
					return
				game.transition_time = 0.01
				await physics_frame
				await physics_frame
				await physics_frame
	trace.close()
	var report := {"format": "CTG_BOT_STUDY", "version": 1, "hz": 60, "sample_hz": 4, "normal_countdown": not fast_countdown,
		"environment_id": game.environment_id, "build_id": game.Rules.BUILD_ID, "ruleset_id": game.ruleset_id, "map_revision": game.arena.map_revision,
		"engine": Engine.get_version_info().string, "wall_ms": Time.get_ticks_msec() - started,
		"controller_sha256": controller_hash, "rounds": records}
	report.map_sha256 = {}
	for source in ["arena", "forest", "mountainside", "bot_tactics", "bot_senses", "field_systems", "relay_rules", "relay_controller", "rules"]:
		report.map_sha256[source] = FileAccess.get_sha256("res://scripts/" + source + ".gd")
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	game.leave_game()
	game.queue_free()
	await process_frame
	print("STUDY_DONE rounds=", records.size(), " wall_ms=", report.wall_ms)
	quit()
