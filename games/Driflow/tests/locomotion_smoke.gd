extends SceneTree
var errors: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and not errors.has(message): errors.append(message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func _initialize() -> void: call_deferred("test")

func test() -> void:
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	var p = lab.player
	p.position = Vector2(720, 619)
	await frames(30)
	check(p.can_stand(), "floor does not block standing query")
	Input.action_press("crouch")
	await frames(3)
	check(p.low_pose > 0 and p.low_pose < 1, "squat transitions through intermediate poses")
	await frames(22)
	check(is_equal_approx(p.low_pose, 1) and p.shape.shape.size.y == 88, "squat settles into 88px collider")
	for side in ["Front", "Back"]:
		var forearm = p.rig.get_arm(side).get_node(side + "Forearm")
		check(forearm.rotation <= 0, "crouch elbows bend toward the anatomical flexion side")
		check(absf(angle_difference(PI/2, forearm.get_node(side + "Hand").rotation)) < 0.02, "relaxed crouch wrists follow forearm without a kink")
	Input.action_press("right")
	await frames(25)
	var drift := 0.0
	var samples := 0
	var last: Dictionary = {}
	for i in 36:
		await frames(1)
		for side in ["Front", "Back"]:
			var foot = p.rig.hip.get_node(side + "Thigh/" + side + "Shin/" + side + "Boot/SoleContact")
			var c: Dictionary = p.rig.contacts.get(side + "Foot", {})
			if not c.is_empty() and c.last < 0.65 and c.last > 0.08:
				check(absf(foot.global_position.y - p.position.y) < 0.7, "crouch support sole rests on floor")
				if last.has(side):
					drift = maxf(drift, foot.global_position.distance_to(last[side]))
					samples += 1
				last[side] = foot.global_position
			else: last.erase(side)
	check(samples > 12 and drift < 0.6, "crouch support feet do not skate")
	Input.action_release("right")
	Input.action_release("crouch")
	Input.action_press("crawl")
	for i in 50:
		await frames(1)
		for side in ["Front", "Back"]:
			var art: Sprite2D = p.rig.hip.get_node(side + "Thigh/" + side + "Shin/" + side + "Boot/Artwork")
			var rect := art.get_rect()
			for point in [rect.position, rect.position + Vector2(rect.size.x,0),rect.end,rect.position + Vector2(0,rect.size.y)]:
				check(art.to_global(point).y < p.position.y + 1, "kneeling transition keeps boots out of floor")
	check(is_equal_approx(p.low_pose, 2) and p.crawling and p.shape.shape.size == Vector2(132,64), "hands and knees has separate broad low collider")
	for direction in ["right", "left"]:
		p.position = Vector2(740,619)
		p.velocity = Vector2.ZERO
		p.facing = 1 if direction == "right" else -1
		await frames(12)
		Input.action_press(direction)
		await frames(22)
		var support_count := 0
		for i in 64:
			await frames(1)
			for side in ["Front", "Back"]:
				var arm = p.rig.get_arm(side).get_node(side + "Forearm")
				check(arm.rotation <= 0, "mirrored crawling elbows retain the flexion side")
				check(absf(angle_difference(PI/2, arm.get_node(side + "Hand").rotation)) <= 1.651, "support wrists stay within extension range")
				var palm: Dictionary = p.rig.contacts.get(side + "Palm", {})
				var knee: Dictionary = p.rig.contacts.get(side + "Knee", {})
				if not palm.is_empty() and palm.last < 0.72:
					support_count += 1
					check(arm.get_node("HandContact").global_position.distance_to(palm.point) < 0.9, "crawl support palm reaches its fixed world anchor")
					check(absf(arm.get_node("HandContact").global_position.y - p.position.y) < 0.7, "crawl palm lies on floor")
				if not knee.is_empty() and knee.last < 0.72:
					var joint = p.rig.hip.get_node(side + "Thigh/" + side + "Shin/KneeContact")
					check(joint.global_position.distance_to(knee.point) < 1.0, "crawl knees bear weight on floor")
			check(p.rig.spine.global_position.distance_to(p.rig.torso.get_node("CoatJoin").global_position) < 0.1, "coat remains joined through low movement")
		check(support_count > 40, "crawl samples cover complete mirrored support cycles")
		Input.action_release(direction)
		await frames(10)
	# Low passage accepts crawling and holds it on release; squat is too tall.
	p.position = Vector2(760,619)
	await frames(10)
	lab.platform(Rect2(690,520,160,32)) # 68px floor clearance
	var ceiling = lab.get_child(lab.get_child_count() - 1)
	await frames(4)
	Input.action_release("crawl")
	await frames(30)
	check(p.crawling and p.low_pose > 1.9, "crawl stays low beneath a crawl-only ceiling")
	Input.action_press("jump")
	await frames(8)
	check(absf(p.velocity.y) < 0.1 and p.crawling, "crawl cannot jump into low ceiling")
	Input.action_release("jump")
	ceiling.queue_free()
	await frames(48)
	check(p.low_pose < 0.01 and not p.crouching, "clear space smoothly restores standing")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 1
	Input.parse_input_event(trigger)
	await frames(50)
	check(p.crawling and p.low_pose > 1.99, "LT analog trigger enters hands-and-knees crawl")
	trigger.axis_value = 0
	Input.parse_input_event(trigger)
	await frames(50)
	# At fixed vertical velocity, ground gait phase and horizontal speed cannot flap legs.
	p.set_physics_process(false)
	p.rig.was_grounded = true
	for i in 24: p.rig.animate(1.0/60, Vector2(0,-40), false, false, 1, 0)
	var shin = p.rig.hip.get_node("FrontThigh/FrontShin")
	var before: float = shin.rotation
	var frozen: float = p.rig.phase
	for i in 30: p.rig.animate(1.0/60, Vector2(380,-40), false, false, 1, 0)
	check(absf(shin.rotation-before) < 0.01 and p.rig.phase == frozen, "air legs ignore horizontal gait phase")
	# Test a real neutral full jump; knee changes stay continuous through apex.
	p.set_physics_process(true)
	p.position = Vector2(720,619)
	p.velocity = Vector2.ZERO
	await frames(20)
	Input.action_press("jump")
	var max_step := 0.0
	var last_angle: float = shin.rotation
	var apex := false
	for i in 65:
		await frames(1)
		if not p.is_on_floor() and p.rig.air_time > 0.12:
			max_step = maxf(max_step, absf(angle_difference(last_angle, shin.rotation)))
			apex = apex or absf(p.velocity.y) < 30
		last_angle = shin.rotation
	Input.action_release("jump")
	check(apex and max_step < 0.20 and p.is_on_floor(), "jump crosses apex continuously and lands")
	check(p.rig.get_node("Skeleton2D").get_bone_count() == 22, "22 editable joints including independent hands")
	if errors.is_empty(): print("LOCOMOTION TESTS: PASS (%d checks)" % checks)
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
