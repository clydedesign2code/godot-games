extends RefCounted


static func configure(window: Window) -> void:
	# The headless display starts at a 64×64 placeholder until a size is specified.
	if DisplayServer.get_name() == "headless" and window.size == Vector2i(64, 64):
		window.size = window.content_scale_size
	var update := func() -> void:
		var logical_size := window.size
		if OS.has_feature("web"):
			# Godot's backing buffer can be twice as wide as the touch surface.
			var canvas = JavaScriptBridge.get_interface("document").getElementById("canvas")
			if canvas != null and canvas.clientWidth > 0 and canvas.clientHeight > 0:
				logical_size = Vector2i(int(canvas.clientWidth), int(canvas.clientHeight))
		if logical_size.x > 0 and logical_size.y > 0 and window.content_scale_size != logical_size:
			window.content_scale_size = logical_size
	window.size_changed.connect(update)
	update.call()
