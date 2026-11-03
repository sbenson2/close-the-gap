extends SceneTree

var failures: int = 0
var checks: int = 0
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
		await physics_frame

func finish() -> void:
	if game:
		game.queue_free()
		await frames(3)
	print("FOREST_HANDGUN_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	await frames(3)
	check(game.has_method("select_level"), "level selection is available")
	if not game.has_method("select_level"):
		await finish()
		return
	game.select_level("forest")
	check(game.arena.map_id == "forest", "forest can be selected")
	check(game.arena.tree_count >= 150, "forest includes dense trees")
	check(game.arena.foliage_count >= 9000, "forest includes dense layers of ground foliage")
	print("FOREST_DENSITY trees=%d foliage=%d" % [game.arena.tree_count, game.arena.foliage_count])
	print("FOREST_DETAILS ", JSON.stringify(game.arena.forest_details))
	var path = game.arena.path_to(game.arena.spawn_for("stalker"), game.arena.spawn_for("sniper"))
	check(path.size() > 50, "forest has a traversable route between spawns")
	var first_layout: String = str(game.arena.solids)
	game.select_level("yard")
	check(game.arena.map_id == "yard", "original freight yard remains selectable")
	game.select_level("forest")
	check(str(game.arena.solids) == first_layout, "forest geometry is deterministic for both peers")
	check(game.arena.path_to(game.arena.spawn_for("stalker"), game.arena.spawn_for("sniper")) == path, "changing maps does not retain stale navigation obstacles")
	game.select_level("yard")
	game.bot_enabled = false
	game.start_practice("stalker")
	game.transition_time = 0.01
	await frames(5)
	var p = game.players[1]
	var target = game.players[2]
	p.position = Vector3(0, 3.95, -32)
	target.position = Vector3(0, 3.95, -39)
	p.aim = Vector2.ZERO
	await frames(3)
	check(not InputMap.has_action("smoke"), "smoke control is removed")
	game.request_action("handgun")
	check(p.active_weapon == "handgun", "stalker can equip the handgun")
	Input.action_press("scope")
	await frames(3)
	check(p.aiming and not p.scoped, "handgun supports iron-sight aiming without a sniper overlay")
	Input.action_release("scope")
	game.request_action("attack")
	check(target.health == 60 and target.alive, "first handgun hit damages without eliminating")
	check(p.handgun_ammo == 5, "firing consumes a handgun round")
	game.request_action("attack")
	check(target.health == 60 and p.handgun_ammo == 5, "handgun cooldown prevents duplicate shots")
	game.request_action("reload")
	check(p.reload_remaining > 0, "reload starts when magazine is partially empty")
	game.request_action("attack")
	check(target.health == 60, "cannot fire during reload")
	await frames(110)
	check(p.handgun_ammo == 6 and p.handgun_reserve == 11, "reload transfers only the missing ammunition")
	game.request_action("attack")
	check(target.health == 20 and game.phase == "playing", "second handgun hit keeps the round alive")
	await frames(30)
	game.request_action("attack")
	check(not target.alive and game.scores[1] == 1, "third handgun hit eliminates and scores once")
	game.transition_time = 0.01
	await frames(4)
	check(game.players[1].health == 100, "health resets when roles swap")
	game.transition_time = 0.01
	await frames(4)
	game.request_action("handgun")
	check(game.players[1].active_weapon == "rifle", "sniper cannot equip the stalker's handgun")
	game.leave_game()
	game.select_level("forest")
	game.start_practice("stalker")
	game.transition_time = 0.01
	await frames(4)
	p = game.local_player()
	game.request_action("handgun")
	p.handgun_ammo = 0
	p.handgun_reserve = 0
	game.request_action("attack")
	check(p.handgun_ammo == 0 and p.cooldown == 0, "empty handgun cannot fire or create ammunition")
	game.request_action("knife")
	check(p.active_weapon == "knife", "knife remains available when ammunition runs out")
	await finish()
