extends SceneTree

func _initialize() -> void:
	for property in ProjectSettings.get_property_list():
		if "movie_writer" in property.name:
			print(property.name, " = ", ProjectSettings.get_setting(property.name), " options=", property.hint_string)
	quit()
