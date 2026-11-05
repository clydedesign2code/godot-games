extends SceneTree
var errors:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok and not errors.has(message):errors.append(message)
func frames(n:int)->void:
	for i in n:await physics_frame
func _initialize()->void:call_deferred("test")
func test()->void:
	var lab=load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	for child in lab.get_children():
		if child is StaticBody2D and child.position.x>0 and child.position.x<1280 and child.position.y<lab.GROUND_Y:child.queue_free()
	var p=lab.player
	await frames(25)
	for spec in [["right",false],["left",false],["right",true],["left",true]]:
		var facing:float=1 if spec[0]=="right" else -1
		p.position=Vector2(320 if facing>0 else 960,619)
		p.velocity=Vector2.ZERO
		p.facing=facing
		await frames(30)
		var idle_height:float=p.visual_height()
		Input.action_press(spec[0])
		if spec[1]:Input.action_press("run")
		await frames(25)
		var total:=0.0
		var minimum:=INF
		var maximum:=-INF
		var last_y:float=p.rig.hip.position.y
		var max_step:=0.0
		var contact_error:=0.0
		var max_bottom:=-INF
		for i in 90:
			await frames(1)
			var height:float=p.visual_height()
			total+=height
			minimum=minf(minimum,height)
			maximum=maxf(maximum,height)
			max_step=maxf(max_step,absf(p.rig.hip.position.y-last_y))
			last_y=p.rig.hip.position.y
			check(p.low_pose==0 and not p.crouching,"walking never enters crouch posture")
			for side in ["Front","Back"]:
				var thigh:Bone2D=p.rig.hip.get_node(side+"Thigh")
				var shin:Bone2D=thigh.get_node(side+"Shin")
				var boot:Bone2D=shin.get_node(side+"Boot")
				check(thigh.scale==Vector2.ONE,"upright gait keeps the original limb lengths")
				var contact:Dictionary=p.rig.contacts[side+"Foot"]
				var duty:=0.42 if spec[1] else 0.58
				if contact.last<duty:
					var angle:float=thigh.rotation+shin.rotation+boot.rotation
					var marker:Marker2D=boot.get_node("HeelContact" if angle< -0.001 else "ToeContact" if angle>0.001 else "SoleContact")
					var expected:Vector2=contact.point+Vector2(marker.position.x*facing,0)
					contact_error=maxf(contact_error,marker.global_position.distance_to(expected))
					if not spec[1] and contact.last/duty>0.30 and contact.last/duty<0.60:
						check(shin.rotation<0.72,"walking weight-bearing knee extends during passing")
				var art:Sprite2D=boot.get_node("Artwork")
				var rect:=art.get_rect()
				for point in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:max_bottom=maxf(max_bottom,art.to_global(point).y-p.position.y)
		var mean:=total/90
		print("GAIT ",spec," idle ",idle_height," mean ",mean," min ",minimum," max ",maximum," step ",max_step," contact error ",contact_error," boot depth ",max_bottom)
		if not spec[1]:
			check(idle_height-mean<3.0,"walking average height stays close to standing")
			check(idle_height-minimum<4.8,"walking never holds a deep semi-squat")
			check(max_step<2.5,"walking pelvis height changes continuously")
		check(contact_error<0.55,"heel and toe support remain fixed without skating")
		check(max_bottom<0.55,"rolled boots remain above the floor")
		Input.action_release(spec[0])
		Input.action_release("run")
		await frames(30)
		check(absf(p.rig.hip.position.y+60)<0.5,"stopping restores standing smoothly")
	# Varying the support duty must not turn a previous swing into a planted
	# foot in mid-air when switching between walk and run.
	p.position=Vector2(250,619)
	p.velocity=Vector2.ZERO
	p.facing=1
	await frames(25)
	Input.action_press("right")
	for tick in 70:
		if tick==20:Input.action_press("run")
		if tick==45:Input.action_release("run")
		await frames(1)
		for side in ["Front","Back"]:
			var contact:Dictionary=p.rig.contacts.get(side+"Foot",{})
			if not contact.is_empty() and contact.stance:
				check(absf(contact.point.y-p.position.y)<0.2,"walk-run transition cannot plant a foot in mid-air")
	Input.action_release("right")
	if errors.is_empty():print("WALK HEIGHT TESTS: PASS (%d checks)"%checks)
	else:
		for e in errors:push_error(e)
	quit(0 if errors.is_empty() else 1)
