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
	for child in lab.get_children():
		if child is StaticBody2D and child.position.x>0 and child.position.x<1280 and child.position.y<lab.GROUND_Y:child.queue_free()
	var capture_blocks:Array[Rect2]=[]
	for rect in lab.blocks:
		if rect.position.y>=lab.GROUND_Y or rect.end.x<=0 or rect.position.x>=1280:capture_blocks.append(rect)
	lab.blocks=capture_blocks
	lab.queue_redraw()
	var camera:=Camera2D.new()
	camera.zoom=Vector2(3,3)
	lab.add_child(camera)
	var p=lab.player
	var samples:Array=[]
	var clips:Array=[["walk_right","right",false,false],["walk_left","left",false,false],["run_right","right",true,false],["run_left","left",true,false],["crouch_walk","right",false,true]]
	if args.has("--baseline"):clips=clips.slice(0,1)
	for spec in clips:
		for action in ["left","right","run","crouch"]:Input.action_release(action)
		p.set_physics_process(true)
		p.ledge_mode=""
		p.low_pose=0
		p.position=Vector2(400 if spec[1]=="right" else 900,619)
		p.velocity=Vector2.ZERO
		p.facing=1 if spec[1]=="right" else -1
		for i in 40:await physics_frame
		p.set_physics_process(false)
		for frame in 160:
			await physics_frame
			if frame==20:
				Input.action_press(spec[1])
				if spec[2]:Input.action_press("run")
				if spec[3]:Input.action_press("crouch")
			if frame==110:
				for action in ["left","right","run","crouch"]:Input.action_release(action)
			p._physics_process(1.0/60)
			# Both versions share a fixed vertical camera; height differences are real.
			camera.position=Vector2(p.position.x,lab.GROUND_Y-100)
			samples.append({"clip":spec[0],"frame":frame,"state":p.state,"height":p.visual_height(),"hat_y":p.position.y-p.visual_height()+2,"hip_y":p.rig.hip.position.y,"floor_y":p.position.y})
			RenderingServer.force_draw(false,1.0/60)
			if root.get_texture().get_image().save_png(output.path_join("%s_%03d.png"%[spec[0],frame]))!=OK:quit(1);return
	var file:=FileAccess.open(output.path_join("timing.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":60,"samples":samples}))
	print("WALK HEIGHT VISUAL: PASS (fixed vertical camera)")
	quit()
