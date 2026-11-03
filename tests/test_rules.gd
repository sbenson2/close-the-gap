extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	check(Rules.role_for_slot(0, 0) == "stalker", "host starts with knife")
	check(Rules.role_for_slot(0, 1) == "sniper", "guest starts with rifle")
	check(Rules.role_for_slot(1, 0) == "sniper", "roles swap after a round")
	check(Rules.role_for_slot(4, 1) == "sniper", "role parity remains correct")
	check(Rules.segment_intersects_sphere(Vector3.ZERO, Vector3(0, 0, -20), Vector3(0, 0, -10), 5.0), "foliage volume intersects a sightline")
	check(not Rules.segment_intersects_sphere(Vector3.ZERO, Vector3(0, 0, -4), Vector3(0, 0, -10), 5.0), "foliage behind a target does not conceal it")
	check(not Rules.segment_intersects_sphere(Vector3.ZERO, Vector3(0, 0, -20), Vector3(8, 0, -10), 5.0), "a sightline outside foliage stays clear")
	check(Rules.segment_intersects_sphere(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 5.0), "a zero-length sightline inside foliage is concealed")
	check(not Rules.valid_aim(Vector2(INF, 0)), "reject nonfinite network aim")
	check(not Rules.valid_aim(Vector2(0, 2)), "reject impossible vertical aim")
	check(Rules.weapon_allowed("stalker", "handgun"), "stalker can equip handgun")
	check(not Rules.weapon_allowed("sniper", "handgun"), "sniper cannot equip handgun")
	print("Rules: %d failures" % failures)
	quit(1 if failures else 0)
