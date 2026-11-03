extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	check(FileAccess.file_exists("res://scripts/relay_rules.gd"), "relay sabotage and repair rules are implemented")
	if failures:
		quit(1)
		return
	var relay = load("res://scripts/relay_rules.gd").new()
	check(relay.change(0, "stalker") and relay.advance(20) == "", "one offline station does not start an objective victory")
	check(relay.change(1, "stalker"), "a second distinct station can be sabotaged")
	check(relay.advance(29) == "" and relay.advance(1) == "stalker", "two offline stations win only after the full repair deadline")
	relay.reset()
	relay.change(0, "stalker")
	relay.change(1, "stalker")
	relay.advance(10)
	check(relay.change(0, "sniper") and relay.deadline == 0, "repair cancels the deadline when fewer than two remain offline")
	check(not relay.change(0, "stalker"), "a repaired station cannot be farmed for repeated sabotage")
	check(relay.change(2, "stalker") and relay.deadline == 30, "the last fresh station can create one new repair opportunity")
	relay.reset()
	check(relay.advance(150) == "draw", "base expiry without objective pressure is a draw")
	relay.reset()
	relay.advance(149.5)
	relay.change(0, "stalker")
	relay.change(1, "stalker")
	check(relay.advance(20) == "", "an active repair deadline survives the base round cap")
	relay.change(1, "sniper")
	check(relay.advance(0) == "draw", "repair after the base cap ends overtime as a draw")
	relay.reset()
	relay.advance(149)
	relay.change(0, "stalker")
	relay.change(1, "stalker")
	relay.advance(29)
	relay.change(2, "stalker")
	check(relay.advance(1) == "stalker" and relay.elapsed <= 180, "third sabotage cannot extend the round beyond its bounded deadline")
	check(not relay.change(-1, "stalker") and not relay.change(99, "sniper") and not relay.change(1, "unknown"), "invalid objective requests cannot mutate state")
	relay.reset()
	var old: Array = relay.snapshot()
	relay.change(0,"stalker")
	relay.restore(old)
	check(relay.stations[0] == 1, "an older snapshot cannot roll back a newer relay event")
	relay.restore(old,true)
	check(relay.stations[0] == 0 and relay.revision == 0, "explicit replay rewind restores the earlier objective revision")
	print("RELAY_RULES_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
