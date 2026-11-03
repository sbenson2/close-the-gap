extends SceneTree

var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await process_frame
	var levels := ["yard"] if "yard" in OS.get_cmdline_user_args() else ["forest", "yard"]
	for level in levels:
		for seed_value in [71, 114, 201]:
			game.duel_seed = seed_value
			game.start_bot_duel(level)
			for round_number in range(2):
				game.transition_time = 0.01
				for i in range(9300):
					await physics_frame
					if game.phase in ["round_over", "match_over"]:
						break
				var winner = game.players.get(game.winner_id)
				var record := {"level": level, "seed": seed_value, "round": round_number, "winner_role": winner.role if winner else "none", "result": game.result_text, "seconds": snappedf(150.0 - game.round_time, 0.01), "bots": []}
				for id in [1, 2]:
					var brain = game.bot_brains[id]
					record.bots.append({"role": game.players[id].role, "weapon": game.players[id].active_weapon, "shots": brain.shots, "sightings": brain.sightings, "position": str(game.players[id].position), "state": brain.state, "path_size": brain.path.size(), "route_stage": brain.patrol, "goal": str(brain.goal), "path_end": str(brain.path[-1]) if not brain.path.is_empty() else "none"})
				records.append(record)
				print("MEASURE ", JSON.stringify(record))
				game.transition_time = 0.01
				for i in range(4):
					await physics_frame
	var output: String = "res://artifacts/bot-matches-yard.json" if levels.size() == 1 else "res://artifacts/bot-matches.json"
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	game.leave_game()
	game.queue_free()
	await process_frame
	print("MEASURE_DONE rounds=%d" % records.size())
	quit()
