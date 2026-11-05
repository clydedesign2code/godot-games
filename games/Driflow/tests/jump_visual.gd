extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		quit(1)
		return
	var output:String=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var lab=load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	for label in lab.find_children("*","Label",true,false):label.hide()
	lab.get_node("InteractionProps").hide()
	# Isolate the takeoff arc from the lab's grab-able ledges and low ceilings.
	for child in lab.get_children():
		if child is StaticBody2D and child.position.x>0 and child.position.x<1280 and child.position.y<lab.GROUND_Y:
			child.queue_free()
	var capture_blocks:Array[Rect2]=[]
	for rect in lab.blocks:
		if rect.position.y>=lab.GROUND_Y or rect.end.x<=0 or rect.position.x>=1280: capture_blocks.append(rect)
	lab.blocks=capture_blocks
	lab.queue_redraw()
	var camera:=Camera2D.new()
	camera.zoom=Vector2(2.4,2.4)
	lab.add_child(camera)
	var p=lab.player
	var samples:Array=[]
	for clip in ["neutral","tap","run_right","run_left","crouch"]:
		for action in ["jump","run","left","right","crouch"]:Input.action_release(action)
		p.set_physics_process(true)
		p.ledge_mode=""
		p.position=Vector2(740,619)
		p.velocity=Vector2.ZERO
		p.low_pose=0
		p.facing=-1 if clip=="run_left" else 1
		for i in 40:await physics_frame
		p.set_physics_process(false)
		for frame in 100:
			await physics_frame
			if frame==0:
				if clip.begins_with("run"):
					Input.action_press("run")
					Input.action_press("left" if clip=="run_left" else "right")
				if clip=="crouch":Input.action_press("crouch")
			if frame==20:Input.action_press("jump")
			if frame==21 and clip=="tap":Input.action_release("jump")
			if frame==35:
				Input.action_release("left")
				Input.action_release("right")
				Input.action_release("run")
				Input.action_release("crouch")
			if frame==65:Input.action_release("jump")
			p._physics_process(1.0/60)
			camera.position=Vector2(p.position.x,lab.GROUND_Y-115)
			samples.append({"clip":clip,"frame":frame,"seconds":frame/60.0,"state":p.state,"feet_y":p.position.y,"hip_y":p.rig.hip.global_position.y,"front_knee":p.rig.hip.get_node("FrontThigh/FrontShin").rotation})
			RenderingServer.force_draw(false,1.0/60)
			if root.get_texture().get_image().save_png(output.path_join("%s_%03d.png"%[clip,frame]))!=OK:
				quit(1)
				return
	var file:=FileAccess.open(output.path_join("timing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":60,"samples":samples}))
	print("JUMP VISUAL CAPTURE: PASS (60Hz)")
	quit()
