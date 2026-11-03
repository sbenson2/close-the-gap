extends SceneTree

var game
var canvas: SubViewport
var start: float = 0.0
var seconds: float = 600.0

class MovieLayout extends Node:
	var subject
	func _process(_delta: float) -> void:
		subject.spectator.replay_controls.hide()
		for child in subject.spectator.get_children():
			if child is HBoxContainer and child != subject.spectator.row:
				child.hide()
		subject.spectator.row.offset_bottom = 0

func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		start = maxf(0, float(args[0]))
	if args.size() >= 2:
		seconds = maxf(0.1, float(args[1]))
	if args.size() not in [4, 5]:
		push_error("Usage: render_movie.gd -- start seconds ffmpeg.exe video.mp4 [replay.json]")
		quit(1)
		return
	var encoder := OS.execute_with_pipe(args[2], PackedStringArray([
		"-hide_banner", "-loglevel", "error", "-nostats", "-nostdin", "-y",
		"-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1920x1080",
		"-framerate", "60", "-i", "pipe:0", "-an",
		"-vf", "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p",
		"-c:v", "h264_nvenc", "-preset", "p5", "-cq", "20", "-b:v", "12M",
		"-maxrate", "24M", "-bufsize", "48M", "-colorspace", "bt709",
		"-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
		"-movflags", "+faststart", args[3]
	]), true)
	if encoder.is_empty():
		push_error("Unable to start FFmpeg")
		quit(1)
		return
	var pipe: FileAccess = encoder.stdio
	# The tiny root MovieWriter keeps Godot's offline audio clock and writes PCM.
	# The full-size child viewport goes directly to NVENC, avoiding JPEG encoding.
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.own_world_3d = true
	canvas.audio_listener_enable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	canvas.add_child(game)
	game.start_replay(args[4] if args.size() == 5 else game.DEFAULT_REPLAY)
	if game.replay == null or start + seconds > game.replay.duration + 0.001:
		push_error("Requested video interval is outside the saved replay")
		OS.kill(encoder.pid)
		quit(1)
		return
	game.sound.muted = true
	game.paused = true
	game.replay.seek(start)
	var layout := MovieLayout.new()
	layout.subject = game
	layout.process_priority = 100
	root.add_child(layout)
	for i in range(4):
		await RenderingServer.frame_post_draw
	var first_frame: int = Engine.get_frames_drawn()
	print("MOVIE_BEGIN start=%.3f seconds=%.3f fps=60 drawn=%d" % [start, seconds, first_frame])
	game.sound.muted = false
	game.paused = false
	var count: int = roundi(seconds * 60)
	for i in range(count):
		await RenderingServer.frame_post_draw
		if not OS.is_process_running(encoder.pid):
			push_error("FFmpeg exited before all frames were sent")
			quit(1)
			return
		var frame := canvas.get_texture().get_image()
		frame.convert(Image.FORMAT_RGB8)
		pipe.store_buffer(frame.get_data())
		if pipe.get_error() != OK:
			push_error("Video pipe write failed")
			quit(1)
			return
		if (i + 1) % 900 == 0:
			print("MOVIE_PROGRESS frames=%d/%d position=%.3f" % [i + 1, count, game.replay.position])
	game.paused = true
	pipe.close()
	var deadline := Time.get_ticks_msec() + 30000
	while OS.is_process_running(encoder.pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
	if OS.is_process_running(encoder.pid):
		OS.kill(encoder.pid)
		push_error("FFmpeg did not finish within 30 seconds")
		quit(1)
		return
	var errors: String = encoder.stderr.get_as_text()
	encoder.stderr.close()
	if not errors.is_empty():
		push_error("FFmpeg: " + errors)
		quit(1)
		return
	var metadata := {"first_drawn_frame": first_frame, "last_drawn_frame": Engine.get_frames_drawn(), "frames": count, "start": start, "end": game.replay.position, "fps": 60, "size": [canvas.size.x, canvas.size.y]}
	var file := FileAccess.open("res://movie-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	file.close()
	print("MOVIE_DONE ", JSON.stringify(metadata))
	game.leave_game()
	canvas.queue_free()
	layout.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw
	call_deferred("quit")
