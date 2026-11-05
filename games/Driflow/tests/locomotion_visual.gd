extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		push_error("Pass absolute output directory after --")
		quit(1)
		return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	for label in lab.find_children("*", "Label", true, false):
		label.hide()
	lab.get_node("InteractionProps").hide()
	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	lab.add_child(camera)
	var p = lab.player
	var samples: Array = []
	for spec in [["walk", 120], ["run", 100], ["crouch", 120], ["crouch_walk", 180], ["crawl", 260], ["jump", 100], ["run_jump", 110], ["crawl_left", 220]]:
		for action in ["crouch", "crawl", "left", "right", "jump", "run"]:
			Input.action_release(action)
		p.set_physics_process(true)
		p.position = Vector2(720, 619)
		p.velocity = Vector2.ZERO
		p.ledge_mode = ""
		p.ledge_cooldown = 0.2
		p.low_pose = 0
		p.facing = -1 if spec[0] == "crawl_left" else 1
		p.rig.contacts.clear()
		for n in 40:
			await physics_frame
		p.set_physics_process(false)
		var jump_clip: bool = spec[0] in ["jump", "run_jump"]
		camera.zoom = Vector2(2.4,2.4) if jump_clip else Vector2(3,3)
		for frame in spec[1]:
			await physics_frame
			match spec[0]:
				"walk", "run":
					if frame == 10:
						Input.action_press("right")
						if spec[0] == "run": Input.action_press("run")
					if frame == 65:
						Input.action_release("right")
						Input.action_release("run")
				"crouch":
					if frame == 10: Input.action_press("crouch")
					if frame == 75: Input.action_release("crouch")
				"crouch_walk":
					if frame == 0: Input.action_press("crouch")
					if frame == 35: Input.action_press("right")
					if frame == 140: Input.action_release("right")
					if frame == 155: Input.action_release("crouch")
				"crawl", "crawl_left":
					if frame == 0: Input.action_press("crawl")
					if frame == 55: Input.action_press("left" if spec[0] == "crawl_left" else "right")
					if frame == 175: Input.action_release("left" if spec[0] == "crawl_left" else "right")
					if frame == 200: Input.action_release("crawl")
				"jump", "run_jump":
					if frame == 0 and spec[0] == "run_jump":
						Input.action_press("right")
						Input.action_press("run")
					if frame == 16: Input.action_press("jump")
					if frame == 52:
						Input.action_release("jump")
						Input.action_release("right")
						Input.action_release("run")
			p._physics_process(1.0 / 60)
			camera.position = Vector2(p.position.x, lab.GROUND_Y - 115) if jump_clip else p.position + Vector2(0, -76)
			samples.append({"clip":spec[0], "frame":frame, "posture":p.low_pose, "state":p.state, "hip":p.rig.hip.position, "velocity":p.velocity})
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(output.path_join("%s_%03d.png" % [spec[0],frame])) != OK:
				push_error("Cannot save frame")
				quit(1)
				return
	var file := FileAccess.open(output.path_join("timing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":60,"samples":samples}))
	print("LOCOMOTION VISUAL CAPTURE: PASS")
	quit()
