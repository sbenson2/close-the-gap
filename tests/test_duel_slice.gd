extends SceneTree

const Codec = preload("res://scripts/replay_codec.gd")
var game
var checks := 0
var failures := 0
var impacts: Array = []

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

func fresh(index: int = 0, points: Dictionary = {1: 0, 2: 0}) -> void:
	game.configure_round(index, [1, 2], ["stalker", "sniper"] if index % 2 == 0 else ["sniper", "stalker"], points, "yard")
	game.phase = "playing"
	await frames(2)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.auto_watch = false
	root.add_child(game)
	current_scene = game
	game.select_level("yard")
	game.bot_enabled = false
	game.start_practice("stalker")
	await fresh()
	game.round_time = 0.001
	await frames(3)
	check(game.winner_id == 0 and game.scores == {1: 0, 2: 0}, "timeout is a draw without awarding either player")
	await fresh(1, {1: 1, 2: 0})
	game.end_round(2, "test")
	check(game.phase == "match_over" and game.scores == {1: 1, 2: 1}, "a split complete role pair ends as a set draw")
	await fresh(1, {1: 1, 2: 0})
	game.end_round(1, "test")
	check(game.phase == "match_over" and game.scores[1] == 2, "two wins finish the pair without an extra sniper turn")
	await fresh()
	var stalker = game.players[1]
	var sniper = game.players[2]
	stalker.position = Vector3(0, 3.95, -35)
	sniper.position = Vector3(0, 3.95, -36.8)
	stalker.aim = Vector2.ZERO
	sniper.aim = Vector2(PI, 0)
	await frames(2)
	game.request_action("attack")
	check(sniper.alive and sniper.health == 65 and game.phase == "playing", "front knife interrupts and damages instead of instantly killing")
	check(sniper.cooldown >= 0.35, "front knife creates a brief recovery window")
	check(stalker.cooldown > sniper.cooldown + 0.2, "front knife recovery leaves the defender a counterattack window instead of a stun lock")
	stalker.cooldown = 0
	sniper.aim = Vector2.ZERO
	await frames(2)
	game.request_action("attack")
	check(not sniper.alive and game.scores[1] == 1, "rear knife is lethal under the same authoritative combat rules")
	await fresh(1)
	var rifle = game.players[1]
	check(rifle.get("rifle_ammo") == 3 and rifle.get("rifle_reserve") == 9, "sniper spawns with a finite loaded magazine and reserve")
	if rifle.get("rifle_ammo") != null:
		rifle.aim = Vector2(0, 1.0)
		game.request_action("attack")
		check(rifle.rifle_ammo == 2, "a missed rifle shot still spends a round")
		game.request_action("reload")
		check(rifle.reload_remaining > 2, "rifle reload commits the weapon for a visible interval")
		rifle.cooldown = 0
		game.request_action("attack")
		check(rifle.rifle_ammo == 2, "rifle cannot shoot during its reload")
		await frames(190)
		check(rifle.rifle_ammo == 3 and rifle.rifle_reserve == 8, "rifle reload transfers only missing rounds from reserve")
		rifle.rifle_ammo = 0
		rifle.rifle_reserve = 0
		rifle.cooldown = 0
		game.request_action("attack")
		check(rifle.cooldown == 0 and rifle.rifle_ammo == 0, "an empty rifle cannot fire or conjure ammunition")
	await fresh()
	stalker = game.players[1]
	game.gameplay_event.connect(func(kind, values):
		if kind == "pebble_impact": impacts.append(values))
	check(stalker.get("pebbles") == 3, "stalker starts with three finite distractions")
	if stalker.get("pebbles") != null:
		stalker.position = Vector3(0, 0.1, 15)
		stalker.aim = Vector2(0, 0.35)
		game.request_action("pebble")
		check(stalker.pebbles == 2, "throwing pays one pebble on the authority")
		game.request_action("pebble")
		check(stalker.pebbles == 2, "repeated throw while committed cannot duplicate a projectile")
		await frames(240)
		check(impacts.size() == 1, "a thrown pebble produces exactly one physical impact")
		stalker.pebbles = 0
		game.request_action("pebble")
		await frames(30)
		check(impacts.size() == 1 and stalker.pebbles == 0, "depleted supply creates no extra impact")
		game._resolve_action(2, "pebble", Vector2.ZERO)
		check(game.players[2].pebbles == 0, "sniper cannot use stalker distractions")
	var old := Codec.read("res://replays/mountain-session.json")
	check(old.has("data"), "existing mountainside recording remains readable")
	game.start_bot_duel("yard")
	game.paused = true
	game.phase = "playing"
	game.round_index = 1
	game.end_round(0, "draw")
	var prior_seed: int = game.duel_seed
	game.rematch()
	check(game.duel_seed != prior_seed, "new bot sets use fresh deterministic plans instead of repeating the same two rounds forever")
	game.leave_game()
	game.queue_free()
	await frames(3)
	print("DUEL_SLICE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
