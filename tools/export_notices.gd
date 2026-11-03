extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() else "res://builds/windows/Godot-LICENSES.txt"
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Could not write license notices: " + output)
		quit(1)
		return
	file.store_string("Godot Engine 4.7.2\n\n" + Engine.get_license_text() + "\n\nThird-party copyright notices:\n\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(), "\t"))
	file.store_string("\n\nThird-party licenses:\n\n")
	var licenses := Engine.get_license_info()
	for key in licenses:
		file.store_string(str(key) + "\n\n" + str(licenses[key]) + "\n\n")
	file.close()
	quit()
