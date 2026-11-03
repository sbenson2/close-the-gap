extends RefCounted

var path := "user://field-journal.json"
var data: Dictionary = {"version":1,"visits":[],"stalker":{"win":0,"loss":0,"draw":0},"sniper":{"win":0,"loss":0,"draw":0},"last_round":""}
var error := ""

func open(file_path: String = "user://field-journal.json") -> String:
	path = file_path
	if not FileAccess.file_exists(path): return ""
	var parser := JSON.new()
	parser.parse(FileAccess.get_file_as_string(path))
	var parsed = parser.data
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("visits") is Array or parsed.visits.size() > 7 or not parsed.get("last_round") is String:
		error = "The field journal could not be read. The original file is preserved."
		return error
	for index in parsed.visits:
		if not index is float and not index is int or index < 0 or index > 6 or index != floorf(index):
			error = "The field journal contains an invalid visit. The original file is preserved."
			return error
	for role in ["stalker","sniper"]:
		if not parsed.get(role) is Dictionary:
			error = "The field journal contains an invalid role record."
			return error
		for outcome in ["win","loss","draw"]:
			var value = parsed[role].get(outcome)
			if (not value is int and not value is float) or value < 0 or value > 1000000 or value != floorf(value):
				error = "The field journal contains an invalid round count."
				return error
	data = parsed
	return ""

func visit(index: int) -> bool:
	if index < 0 or index > 6 or data.visits.any(func(value): return int(value) == index): return false
	data.visits.append(index)
	return true

func record(round_id: String, role: String, outcome: String) -> bool:
	if role not in ["stalker","sniper"] or outcome not in ["win","loss","draw"] or round_id == data.last_round or round_id.is_empty(): return false
	data.last_round = round_id
	data[role][outcome] = int(data[role][outcome]) + 1
	return true

func save() -> String:
	if not error.is_empty(): return error
	var file := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if not file: return "Could not save the field journal."
	file.store_string(JSON.stringify(data))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp",path) != OK: return "Could not finish saving the field journal."
	return ""
