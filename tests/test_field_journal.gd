extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else: print("PASS: " + message)

func _initialize() -> void:
	var Journal = load("res://scripts/field_journal.gd")
	var journal = Journal.new()
	var path := "res://artifacts/demo/journal-test.json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	journal.open(path)
	check(journal.visit(3) and not journal.visit(3) and not journal.visit(-1),"visits count a real overlook once and reject invalid indices")
	check(journal.record("round-a","stalker","draw") and not journal.record("round-a","stalker","draw"),"duplicate round results cannot inflate local records")
	check(journal.save().is_empty(),"local progress saves through an atomic temporary file")
	journal.visit(4)
	check(journal.save().is_empty(),"a later save replaces the prior journal atomically")
	var restored = Journal.new()
	check(restored.open(path).is_empty() and restored.data.stalker.draw == 1 and restored.data.visits.size() == 2,"visits and role records survive a restart")
	FileAccess.open(path,FileAccess.WRITE).store_string("broken journal")
	var broken = Journal.new()
	check(not broken.open(path).is_empty() and not broken.save().is_empty() and FileAccess.get_file_as_string(path) == "broken journal","invalid existing records are preserved rather than silently overwritten")
	DirAccess.remove_absolute(path)
	print("FIELD_JOURNAL_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
