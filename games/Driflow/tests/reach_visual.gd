extends SceneTree
func _initialize()->void:call_deferred("capture")
func capture()->void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():quit(1);return
	var output:String=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var lab=load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	for label in lab.find_children("*","Label",true,false):label.hide()
	lab.get_node("InteractionProps").hide()
	var camera:=Camera2D.new()
	camera.zoom=Vector2(2.6,2.6)
	lab.add_child(camera)
	var p=lab.player
	var samples:Array=[]
	var specs:Array=[["reach_right",lab.CLIMB_PLATFORM,1.0,false],["reach_left",lab.CLIMB_PLATFORM,-1.0,false],["high_right",lab.HIGH_PLATFORM,1.0,false],["high_left",lab.HIGH_PLATFORM,-1.0,false],["chain",lab.CLIMB_PLATFORM,1.0,true]]
	if args.has("--baseline"):specs=specs.slice(0,1)
	for spec in specs:
		for action in ["jump","climb","drop","left","right"]:Input.action_release(action)
		p.set_physics_process(true)
		p.ledge_mode=""
		p.ledge_cooldown=0
		p.low_pose=0
		var platform:Rect2=spec[1]
		var facing:float=spec[2]
		var wall:float=platform.position.x if facing>0 else platform.end.x
		p.position=Vector2(wall-facing*16,lab.GROUND_Y-1)
		p.velocity=Vector2.ZERO
		p.facing=facing
		camera.position=Vector2(wall+facing*20,500)
		for i in 30:await physics_frame
		p.set_physics_process(false)
		var caught_at:=-1
		for frame in 140:
			await physics_frame
			if frame==10:Input.action_press("jump")
			if caught_at>=0:
				Input.action_release("jump")
				if spec[3] and frame==caught_at+1:Input.action_press("climb")
				if spec[3] and frame==caught_at+3:Input.action_release("climb")
			if frame==105 and not spec[3]:Input.action_press("drop")
			if frame==107:Input.action_release("drop")
			p._physics_process(1.0/60)
			if p.ledge_mode=="HANG" and caught_at<0:caught_at=frame
			var front=p.rig.get_arm("Front").get_node("FrontForearm/HandContact")
			var back=p.rig.get_arm("Back").get_node("BackForearm/HandContact")
			samples.append({"clip":spec[0],"frame":frame,"mode":p.ledge_mode,"reach":p.get("reach_elapsed"),"catch":p.get("catch_elapsed"),"hip":p.rig.hip.global_position,"front":front.global_position,"back":back.global_position})
			RenderingServer.force_draw(false,1.0/60)
			if root.get_texture().get_image().save_png(output.path_join("%s_%03d.png"%[spec[0],frame]))!=OK:quit(1);return
		if caught_at<0:
			push_error("Capture never reached the "+str(spec[0])+" ledge")
			quit(1)
			return
	var file:=FileAccess.open(output.path_join("timing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":60,"samples":samples}))
	print("REACH VISUAL CAPTURE: PASS (ground jump / both sides / queued climb)")
	quit()
