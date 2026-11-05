extends SceneTree

# Run with the graphical renderer and --fixed-fps 60. Pass an absolute output
# directory after --; no images or generated files are written into the project.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		push_error("Pass an absolute capture directory after --")
		quit(1)
		return
	var output: String = args[0]
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create capture directory: " + output)
		quit(1)
		return
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	if args.has("--clean"):
		# Isolate the character for comparison without altering normal gameplay.
		for label in lab.find_children("*", "Label", true, false):
			label.hide()
		var props = lab.get_node_or_null("InteractionProps")
		if props is CanvasItem:
			props.hide()
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.2, 2.2)
	lab.add_child(camera)
	var p = lab.player
	var platform: Rect2 = lab.CLIMB_PLATFORM
	for facing in [1.0, -1.0]:
		var side := "right" if facing > 0 else "left"
		var wall_x: float = platform.position.x if facing > 0 else platform.end.x
		camera.position = Vector2(wall_x + facing * 30, platform.position.y - 8)
		p.set_physics_process(true)
		p.ledge_mode = ""
		p.ledge_cooldown = 0
		p.position = Vector2(wall_x - facing * 16, platform.position.y + 100)
		p.velocity = Vector2.ZERO
		p.facing = facing
		for i in 6:
			await physics_frame
		if p.ledge_mode != "HANG":
			push_error("Capture setup failed to grab the " + side + " ledge")
			quit(1)
			return
		for i in 6:
			await physics_frame
			await RenderingServer.frame_post_draw
			if not save_frame(output.path_join("%s_%03d.png" % [side, i])):
				return
		# Advance exactly one simulation tick per saved frame. Awaiting rendering
		# alongside live physics can skip ticks and distort the apparent timing.
		p.set_physics_process(false)
		if not p.start_climb():
			push_error("Capture setup cannot start climbing")
			quit(1)
			return
		var samples: Array = []
		var capture_dt := 1.0 / Engine.physics_ticks_per_second
		for i in range(ceili(p.climb_duration * Engine.physics_ticks_per_second) + 20):
			await physics_frame
			p._physics_process(capture_dt)
			samples.append({"frame": i + 6, "seconds": (i + 1) * capture_dt, "progress": minf(1, p.climb_elapsed / p.climb_duration), "mode": p.ledge_mode, "hip_x": p.rig.hip.global_position.x, "hip_y": p.rig.hip.global_position.y})
			await RenderingServer.frame_post_draw
			if not save_frame(output.path_join("%s_%03d.png" % [side, i + 6])):
				return
		var metadata := FileAccess.open(output.path_join(side + "_timing.json"), FileAccess.WRITE)
		if metadata == null:
			push_error("Cannot save timing metadata")
			quit(1)
			return
		metadata.store_string(JSON.stringify({"fps": Engine.physics_ticks_per_second, "climb_duration": p.climb_duration, "samples": samples}))
		metadata.close()
		if p.ledge_mode != "" or not p.is_on_floor():
			push_error("Capture did not finish on the " + side + " platform")
			quit(1)
			return
	print("CLIMB VISUAL CAPTURE: PASS (both sides)")
	quit()

func save_frame(path: String) -> bool:
	if root.get_texture().get_image().save_png(path) == OK:
		return true
	push_error("Cannot save capture frame: " + path)
	quit(1)
	return false
