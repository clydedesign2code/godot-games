extends SceneTree
var errors: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not errors.has(message): errors.append(message)
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void: call_deferred("test")

func test() -> void:
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	var p = lab.player
	# Manual fixed steps make the exact press-to-liftoff interval observable.
	p.position = Vector2(720,619)
	await frames(30)
	p.set_physics_process(false)
	var floor_y: float = p.position.y
	var initial_hip: float = p.rig.hip.global_position.y
	var max_dip := 0.0
	var knee_max := 0.0
	var launch_knee := 0.0
	var liftoff := 0
	Input.action_press("jump")
	for tick in range(1,10):
		await physics_frame
		p._physics_process(1.0/60)
		var shin = p.rig.hip.get_node("FrontThigh/FrontShin")
		if p.jump_pending:
			check(p.is_on_floor() and absf(p.position.y-floor_y)<0.1, "load keeps the physical feet on the floor")
			max_dip = maxf(max_dip,p.rig.hip.global_position.y-initial_hip)
			knee_max = maxf(knee_max,shin.rotation)
			for side in ["Front","Back"]:
				var toe = p.rig.hip.get_node(side+"Thigh/"+side+"Shin/"+side+"Boot/ToeContact")
				check(toe.global_position.distance_to(p.rig.takeoff_anchors[side])<0.5,"push-off toes remain fixed")
				var art: Sprite2D=toe.get_parent().get_node("Artwork")
				var rect:=art.get_rect()
				for point in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
					check(art.to_global(point).y<floor_y+0.5,"heel rise keeps complete boot out of the floor")
		if p.velocity.y < 0:
			liftoff=tick
			launch_knee=shin.rotation
			break
	check(liftoff>=3 and liftoff<=5,"neutral liftoff follows a short bounded 50–83ms anticipation")
	check(max_dip>5 and knee_max-launch_knee>0.3,"pelvis compresses then knees extend before liftoff")
	check(absf(p.velocity.x)<0.1,"neutral jump stays vertical")
	Input.action_release("jump")
	p.set_physics_process(true)
	await frames(70)
	# A tap released during loading still produces one short jump, never a full jump.
	p.position=Vector2(720,619)
	p.velocity=Vector2.ZERO
	await frames(15)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var min_y: float=p.position.y
	var took_off:=false
	for i in 60:
		await frames(1)
		min_y=minf(min_y,p.position.y)
		took_off=took_off or p.velocity.y<0
	check(took_off and floor_y-min_y<60 and p.is_on_floor(),"tap released during load becomes a short jump and lands")
	# A loaded squat unfolds into the push instead of adding another downstroke.
	p.position=Vector2(720,619)
	p.velocity=Vector2.ZERO
	await frames(15)
	Input.action_press("crouch")
	await frames(25)
	var crouch_hip: float=p.rig.hip.position.y
	Input.action_press("jump")
	await frames(2)
	check(p.rig.hip.position.y<=crouch_hip+0.5,"crouched takeoff does not crouch a second time")
	await frames(5)
	check(p.velocity.y<0 and not p.jump_pending,"crouch unfolds then launches within the short preparation")
	Input.action_release("crouch")
	Input.action_release("jump")
	await frames(65)
	# Directional launch stays responsive and preserves motion on both mirrored sides.
	for direction in ["right","left"]:
		p.position=Vector2(740,619)
		p.velocity=Vector2.ZERO
		await frames(12)
		Input.action_press(direction)
		Input.action_press("run")
		await frames(10)
		var travel_sign:=1 if direction=="right" else -1
		Input.action_press("jump")
		await frames(4)
		check(p.velocity.y<0 and p.velocity.x*travel_sign>300,"moving jump has brief preparation and retains running speed")
		Input.action_release("jump")
		Input.action_release(direction)
		Input.action_release("run")
		await frames(65)
	# Coyote jumps bypass ground compression. Use a genuine unsupported fall with grace.
	p.position=Vector2(750,580)
	p.velocity=Vector2.ZERO
	await frames(1)
	p.grace=0.08
	Input.action_press("jump")
	await frames(2)
	check(p.velocity.y<0 and not p.jump_pending,"coyote launch is immediate without fictitious ground compression")
	Input.action_release("jump")
	await frames(65)
	# A new ceiling after loading begins cancels the pending impulse.
	p.position=Vector2(720,619)
	p.velocity=Vector2.ZERO
	await frames(15)
	Input.action_press("jump")
	await frames(2)
	lab.platform(Rect2(690,480,60,12))
	var blocker=lab.get_child(lab.get_child_count()-1)
	await frames(8)
	check(not p.jump_pending and p.velocity.y>=0,"new overhead obstacle cancels load instead of pushing into it")
	Input.action_release("jump")
	blocker.queue_free()
	await frames(10)
	# A buffered press just before landing survives the preparation interval.
	p.position=Vector2(740,608)
	p.velocity=Vector2(0,200)
	await frames(1)
	p.grace=0
	Input.action_press("jump")
	await frames(12)
	check(p.velocity.y<0,"landing buffer still launches after grounded preparation")
	Input.action_release("jump")
	await frames(65)
	# Reset during the pending windup must clear the stored intent.
	p.position=Vector2(720,619)
	p.velocity=Vector2.ZERO
	await frames(12)
	Input.action_press("jump")
	await frames(2)
	Input.action_press("reset")
	await frames(1)
	Input.action_release("reset")
	await frames(15)
	check(not p.jump_pending and p.velocity.y>=0,"reset clears pending launch without a delayed jump")
	Input.action_release("jump")
	if errors.is_empty():print("JUMP PUSH TESTS: PASS (%d checks)"%checks)
	else:
		for e in errors:push_error(e)
	quit(0 if errors.is_empty() else 1)
