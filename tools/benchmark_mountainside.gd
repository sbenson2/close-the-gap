extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	var start := Time.get_ticks_usec()
	root.add_child(game)
	print("MOUNTAIN_BUILD_MS ", (Time.get_ticks_usec() - start) / 1000.0)
	start = Time.get_ticks_usec()
	var checksum := 0.0
	for i in range(10000):
		checksum += game.arena.height_at(i % 65 - 32, (i / 65) % 85 - 42)
	print("MOUNTAIN_HEIGHT_MS ", (Time.get_ticks_usec() - start) / 1000.0, " checksum=", checksum)
	game.leave_game()
	game.queue_free()
	await process_frame
	quit()
