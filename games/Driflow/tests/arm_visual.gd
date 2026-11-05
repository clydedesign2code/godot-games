extends SceneTree
# Explicit offscreen draw avoids macOS window/VSYNC waits during frame capture.
# Physics remains fixed at 60Hz; save every third tick (20fps output).
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		push_error("Pass an absolute output directory")
		quit(1)
		return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	for label in lab.find_children("*", "Label", true, false): label.hide()
	lab.get_node("InteractionProps").hide()
	var camera := Camera2D.new()
	camera.zoom = Vector2(3,3)
	lab.add_child(camera)
	var p = lab.player
	for clip in ["crouch", "crouch_walk", "crawl", "crawl_left"]:
		for action in ["crouch","crawl","left","right"]: Input.action_release(action)
		p.set_physics_process(true)
		p.position = Vector2(720,619)
		p.velocity = Vector2.ZERO
		p.ledge_mode = ""
		p.low_pose = 0
		p.facing = -1 if clip == "crawl_left" else 1
		for i in 30: await physics_frame
		p.set_physics_process(false)
		for frame in 210:
			await physics_frame
			if frame == 6: Input.action_press("crawl" if clip.begins_with("crawl") else "crouch")
			if frame == 55 and clip != "crouch": Input.action_press("left" if clip == "crawl_left" else "right")
			if frame == 130:
				Input.action_release("left")
				Input.action_release("right")
			if frame == 145:
				Input.action_release("crouch")
				Input.action_release("crawl")
			p._physics_process(1.0/60)
			camera.position = p.position + Vector2(0,-76)
			if frame % 3 == 0 and not save_frame(output.path_join("%s_%03d.png" % [clip,frame/3])): return
	for facing in [1.0,-1.0]:
		for action in ["crouch","crawl","left","right"]: Input.action_release(action)
		p.set_physics_process(true)
		p.low_pose = 0
		p.ledge_mode = ""
		p.ledge_cooldown = 0
		p.facing = facing
		var wall: float = lab.CLIMB_PLATFORM.position.x if facing > 0 else lab.CLIMB_PLATFORM.end.x
		p.position = Vector2(wall-facing*16,lab.CLIMB_PLATFORM.position.y+100)
		p.velocity = Vector2.ZERO
		for i in 5: await physics_frame
		p.set_physics_process(false)
		if p.ledge_mode != "HANG" or not p.start_climb():
			push_error("Arm capture could not start climb")
			quit(1)
			return
		camera.zoom = Vector2(2.8,2.8)
		camera.position = Vector2(wall+facing*20,lab.CLIMB_PLATFORM.position.y-10)
		for frame in 84:
			await physics_frame
			p._physics_process(1.0/60)
			if frame % 3 == 0 and not save_frame(output.path_join("climb_%s_%03d.png" % ["right" if facing > 0 else "left",frame/3])): return
	print("ARM VISUAL CAPTURE: PASS (60Hz simulation / 20fps frames)")
	quit()

func save_frame(path: String) -> bool:
	RenderingServer.force_draw(false,1.0/60)
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Cannot save arm frame")
		quit(1)
		return false
	return true
