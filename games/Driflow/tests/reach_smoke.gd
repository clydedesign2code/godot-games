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
	var p=lab.player
	await frames(25)
	check(not p.start_climb() and not p.climb_requested,"climb requests outside hanging are rejected")
	var spec_index:=0
	for platform in [lab.CLIMB_PLATFORM,lab.HIGH_PLATFORM]:
		for facing in [1.0,-1.0]:
			p.set_physics_process(true)
			p.ledge_mode=""
			p.ledge_cooldown=0
			p.position=Vector2((platform.position.x if facing>0 else platform.end.x)-facing*16,lab.GROUND_Y-1)
			p.velocity=Vector2.ZERO
			p.facing=facing
			p.reach_top=Vector2.INF
			p.reach_elapsed=0
			await frames(15)
			p.set_physics_process(false)
			Input.action_press("jump")
			var reached:=0
			var caught:=false
			var before:Dictionary={}
			var max_step:=0.0
			for tick in 70:
				await physics_frame
				p._physics_process(1.0/60)
				if p.reach_elapsed>0:reached+=1
				if spec_index==0 and p.reach_elapsed>0.10:Input.action_press("climb")
				for side in ["Front","Back"]:
					var forearm=p.rig.get_arm(side).get_node(side+"Forearm")
					var palm:Vector2=forearm.get_node("HandContact").global_position
					check(forearm.rotation<=0.01,"reaching elbow keeps the arm flexion branch")
					check(absf(angle_difference(PI/2,forearm.get_node(side+"Hand").rotation))<=1.651,"reach wrist stays within its range")
					if before.has(side):max_step=maxf(max_step,palm.distance_to(before[side]))
					before[side]=palm
				check(p.rig.spine.global_position.distance_to(p.rig.torso.get_node("CoatJoin").global_position)<0.1,"reach keeps coat seam joined")
				if p.ledge_mode=="HANG":
					caught=true
					break
			Input.action_release("jump")
			Input.action_release("climb")
			check(reached>=5,"reachable ledge produces a multi-frame anticipatory arm raise")
			check(caught,"both heights and both facings complete the actual ground jump catch")
			check(max_step<35,"palm movement remains continuous during raise and catch handoff")
			if not caught:continue
			var anchor:Vector2=p.position
			if spec_index==0:
				check(p.climb_requested,"climb held during approach is remembered on contact")
				check(p.start_climb() and p.ledge_mode=="HANG" and p.climb_requested,"early climb request waits for the catch instead of skipping it")
			for tick in 15:
				await physics_frame
				p._physics_process(1.0/60)
				check(not p.shape.disabled,"collision stays enabled throughout catch")
				if p.ledge_mode=="HANG":check(p.position.distance_to(anchor)<0.01,"physical hang root remains anchored during visual settling")
				for side in ["Front","Back"]:
					var forearm=p.rig.get_arm(side).get_node(side+"Forearm")
					if p.ledge_mode=="HANG" and p.catch_elapsed>=(p.rig.FRONT_GRIP_TIME if side=="Front" else p.rig.BACK_GRIP_TIME):
						check(forearm.get_node("HandContact").global_position.distance_to(p.ledge_top)<1,"loaded palm stays fixed while pelvis settles")
			if spec_index==0:
				check(p.ledge_mode=="CLIMB","queued climb begins automatically after catch")
				for i in 75:
					await physics_frame
					p._physics_process(1.0/60)
				check(p.ledge_mode=="" and p.is_on_floor(),"queued catch-to-climb completes on platform")
			spec_index+=1
	# Drop also cancels a climb request while the second hand is still closing.
	p.set_physics_process(true)
	p.ledge_mode=""
	p.ledge_cooldown=0
	p.position=Vector2(lab.CLIMB_PLATFORM.position.x-16,lab.GROUND_Y-1)
	p.velocity=Vector2.ZERO
	p.facing=1
	await frames(15)
	p.set_physics_process(false)
	Input.action_press("jump")
	for tick in 70:
		await physics_frame
		p._physics_process(1.0/60)
		if p.ledge_mode=="HANG":break
	Input.action_release("jump")
	p.start_climb()
	Input.action_press("drop")
	await physics_frame
	p._physics_process(1.0/60)
	Input.action_release("drop")
	check(p.ledge_mode=="" and not p.climb_requested,"drop cancels catch and its queued climb")
	for tick in 45:
		await physics_frame
		p._physics_process(1.0/60)
	check(p.ledge_mode!="CLIMB","released catch cannot start a delayed climb")
	# Removing a predicted target must withdraw the reach, not attach to empty air.
	lab.platform(Rect2(750,415,120,20))
	var temporary=lab.get_child(lab.get_child_count()-1)
	p.set_physics_process(true)
	p.position=Vector2(734,lab.GROUND_Y-1)
	p.velocity=Vector2.ZERO
	p.ledge_mode=""
	p.ledge_cooldown=0
	await frames(15)
	p.set_physics_process(false)
	Input.action_press("jump")
	var saw_reach:=false
	for tick in 30:
		await physics_frame
		p._physics_process(1.0/60)
		if p.reach_elapsed>0:
			saw_reach=true
			break
	check(saw_reach,"temporary ledge enters anticipatory reach")
	temporary.queue_free()
	var empty_catch:=false
	for tick in 65:
		await physics_frame
		p._physics_process(1.0/60)
		empty_catch=empty_catch or p.ledge_mode!=""
	Input.action_release("jump")
	check(not empty_catch and p.reach_elapsed==0,"vanished target withdraws reach without a phantom catch")
	# A short hop cannot reach either high ledge, so it must not wave at it.
	p.set_physics_process(true)
	p.ledge_mode=""
	p.ledge_cooldown=0
	p.position=Vector2(lab.CLIMB_PLATFORM.position.x-16,lab.GROUND_Y-1)
	p.velocity=Vector2.ZERO
	p.facing=1
	await frames(15)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var phantom:=false
	for i in 60:
		await frames(1)
		phantom=phantom or p.reach_elapsed>0 or p.ledge_mode!=""
	check(not phantom,"unreachable short hop does not reach or magnetically catch a ledge")
	if errors.is_empty():print("REACH CATCH TESTS: PASS (%d checks)"%checks)
	else:
		for e in errors:push_error(e)
	quit(0 if errors.is_empty() else 1)
