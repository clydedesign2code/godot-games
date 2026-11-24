extends SceneTree
## Write engine, third-party, and bundled font notices alongside the Web release.

func _initialize() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write licenses to " + path)
		quit(1)
		return

	for font_name in ["Noto Sans TC", "Roboto Mono"]:
		var filename := "OFL.txt" if font_name == "Noto Sans TC" else "RobotoMono-OFL.txt"
		file.store_line(font_name)
		file.store_line(FileAccess.get_file_as_string("res://assets/fonts/" + filename))
	file.store_line("Godot Engine")
	file.store_line(Engine.get_license_text())
	for component in Engine.get_copyright_info():
		file.store_line(component.name)
		for part in component.parts:
			file.store_line("\n".join(part.copyright))
			file.store_line("License: " + part.license)
		file.store_line("")
	var licenses := Engine.get_license_info()
	for name in licenses:
		file.store_line(name)
		file.store_line(licenses[name])
	file.close()
	quit()
