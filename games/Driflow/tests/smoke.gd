extends SceneTree
var errors: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _initialize() -> void:
	call_deferred("test")

func test() -> void:
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	await frames(30)
	var p = lab.player
	var climb: Rect2 = lab.CLIMB_PLATFORM
	check(p.is_on_floor(), "spawn settles on floor")
	Input.action_press("jump")
	await frames(6)
	check(p.velocity.y < 0 and absf(p.velocity.x) < 0.1, "neutral jump is vertical")
	Input.action_release("jump")
	await frames(70)
	Input.action_press("right")
	await frames(12)
	check(p.velocity.x > 150, "walk accelerates")
	Input.action_press("jump")
	await frames(4)
	check(p.velocity.x > 150 and p.velocity.y < 0, "moving jump retains direction")
	Input.action_release("jump")
	Input.action_release("right")
	await frames(70)
	p.position = Vector2(150, 620)
	p.velocity = Vector2.ZERO
	await frames(4)
	Input.action_press("crouch")
	await frames(18)
	check(p.crouching and p.shape.shape.size.y == 88, "crouch changes collision")
	p.position = Vector2(lab.CROUCH_CEILING.get_center().x, lab.GROUND_Y)
	await frames(4)
	Input.action_release("crouch")
	await frames(4)
	check(p.crouching, "ceiling prevents standing")
	p.position = Vector2(150, 620)
	await frames(4)
	Input.action_press("right")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	await frames(16)
	check(p.velocity.x > 300, "RT trigger activates run")
	Input.action_release("right")
	trigger.axis_value = 0
	Input.parse_input_event(trigger)
	await frames(5)
	check(p.rig.get_node("Skeleton2D").get_bone_count() == 22, "22 actual Bone2D joints with spine, neck and shoulders")
	for bone in p.rig.find_children("*", "Bone2D", true, false):
		if bone.has_node("Artwork"):
			check(bone.get_node("Artwork") is Sprite2D and bone.get_node("Artwork").texture != null, "body artwork remains a replaceable textured Sprite2D")
	check(is_finite(p.rig.pony.rotation) and absf(p.rig.pony.rotation) <= 1.0, "ponytail spring stays bounded")
	p.position = Vector2(150, 620)
	p.velocity = Vector2.ZERO
	p.facing = 1.0
	await frames(5)
	var anchor: float = p.position.x
	Input.action_press("left")
	await frames(3)
	check(p.facing == -1 and absf(p.position.x - anchor) < 0.01, "tap reverse turns without displacement")
	Input.action_release("left")
	await frames(3)
	check(absf(p.position.x - anchor) < 0.01, "release cancels pending walk")
	for action in ["right", "left", "right", "left"]:
		Input.action_press(action)
		await frames(2)
		Input.action_release(action)
		await frames(1)
	check(absf(p.position.x - anchor) < 0.01, "rapid alternate taps remain anchored")
	Input.action_press("right")
	await frames(16)
	check(p.velocity.x > 150 and p.position.x > anchor, "held reverse becomes walk")
	Input.action_release("right")
	Input.action_press("left")
	await frames(2)
	check(p.turn_remaining == 0, "moving reversal has no turn delay")
	Input.action_release("left")
	p.velocity = Vector2.ZERO
	await frames(4)
	p.facing = 1
	Input.action_press("left")
	Input.action_press("jump")
	await frames(3)
	check(p.velocity.y < 0 and p.velocity.x < 0, "directional jump bypasses turn delay")
	Input.action_release("left")
	Input.action_release("jump")

	# Approach the floating platform from both sides at hand height.
	for spec in [[climb.position.x - 16, 1.0], [climb.end.x + 16, -1.0]]:
		p.ledge_mode = ""
		p.ledge_cooldown = 0
		p.position = Vector2(spec[0], climb.position.y + 100)
		p.velocity = Vector2.ZERO
		p.facing = spec[1]
		await frames(4)
		check(p.ledge_mode == "HANG", "auto grab floating platform from either side")
		var hang_position: Vector2 = p.position
		await frames(10)
		check(p.position.distance_to(hang_position) < 0.01, "hang stays anchored")
		var climb_frames := 0
		var checked_transfer := false
		var elbow_at_rollover := 0.0
		var checked_press := false
		Input.action_press("climb")
		for frame in range(ceili(p.climb_duration * Engine.physics_ticks_per_second) + 12):
			await frames(1)
			if p.ledge_mode != "CLIMB":
				continue
			climb_frames += 1
			var progress: float = p.climb_elapsed / p.climb_duration
			check(p.rig.spine.global_position.distance_to(p.rig.torso.get_node("CoatJoin").global_position) < 0.1, "upper and lower coat stay joined while the spine bends")
			for index in range(2):
				var prefix: String = "Front" if index == 0 else "Back"
				var arm = p.rig.get_arm(prefix).get_node(prefix + "Forearm")
				check(arm.rotation <= 0.01, "climb elbows retain anatomical bend direction")
				check(absf(angle_difference(PI/2, arm.get_node(prefix + "Hand").rotation)) <= 1.651, "climb wrist extension stays in range")
				var hand: Vector2 = arm.get_node("HandContact").global_position
				check(hand.distance_to(arm.get_node(prefix + "Hand/PalmContact").global_position) < 0.01, "legacy hand marker follows editable palm contact")
				if index == 0:
					if progress <= 0.44:
						elbow_at_rollover = arm.rotation
					if progress >= 0.58 and not checked_press:
						check(absf(elbow_at_rollover) - absf(arm.rotation) > 0.8, "front elbow extends during downward push before foot plant")
						checked_press = true
					if progress >= p.rig.FRONT_FOOT_PLANT and not checked_transfer:
						check(hand.distance_to(p.ledge_top) < 2, "palm and planted foot overlap during support transfer")
						checked_transfer = true
					if progress >= p.rig.WEIGHT_OVER_FOOT:
						var hip_x: float = (p.rig.hip.global_position.x - p.ledge_top.x) * p.facing
						check(hip_x >= 22 and hip_x <= 32, "pelvis reaches the planted foot before the final stand")
				if progress <= (p.rig.FRONT_HAND_RELEASE.x if index == 0 else p.rig.BACK_HAND_RELEASE.x):
					check(hand.distance_to(p.ledge_top) < 1, "support palm %s at %.3f drifts %.2f px" % [prefix, progress, hand.distance_to(p.ledge_top)])
				var boot = p.rig.hip.get_node(prefix + "Thigh/" + prefix + "Shin/" + prefix + "Boot")
				var sole: Vector2 = boot.get_node("SoleContact").global_position
				if progress >= (p.rig.FRONT_FOOT_PLANT if index == 0 else p.rig.BACK_FOOT_PLANT):
					var plant: Vector2 = p.ledge_top + Vector2((27 if index == 0 else 17) * p.facing, 0)
					check(sole.distance_to(plant) < 0.5, "planted boot stays fixed while standing up")
				# The toe must clear the edge before either boot moves onto the top.
				if (sole.x - p.ledge_top.x) * p.facing > -12 and sole.y < p.ledge_top.y + 33:
					check(sole.y <= p.ledge_top.y + 0.5, "boot %s at %.3f intersects edge: %s" % [prefix, progress, sole - p.ledge_top])
		Input.action_release("climb")
		check(climb_frames >= ceili(p.climb_duration * Engine.physics_ticks_per_second) - 2, "climb completes full support sequence")
		check(p.ledge_mode == "" and p.is_on_floor() and absf(p.position.y - climb.position.y) < 2, "up climbs onto platform")
	# Resume walking after a climb: IK offsets must not contaminate locomotion.
	Input.action_press("left")
	await frames(8)
	Input.action_release("left")
	check(p.velocity.x < -150, "walk resumes after climb")
	await frames(16)
	check(absf(p.rig.hip.position.x) < 0.5, "climb hip offset clears on locomotion")

	# A new obstacle appearing after the preflight sweep must stop the collider.
	p.ledge_mode = ""
	p.ledge_cooldown = 0
	p.position = Vector2(climb.position.x - 16, climb.position.y + 100)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(4)
	Input.action_press("climb")
	await frames(12)
	Input.action_release("climb")
	check(p.ledge_mode == "CLIMB", "dynamic obstacle test starts mid-climb")
	lab.platform(Rect2(p.position.x - 20, p.position.y - 145, 40, 12))
	var blocker = lab.get_child(lab.get_child_count() - 1)
	for i in 22:
		await frames(1)
		if p.ledge_mode != "CLIMB":
			break
	check(p.ledge_mode == "" and p.ledge_cooldown > 0, "new obstacle aborts climbing without disabling collision")
	check(not p.shape.disabled, "collision remains active during climb")
	blocker.queue_free()
	await frames(3)

	p.ledge_mode = ""
	p.ledge_cooldown = 0
	p.position = Vector2(climb.position.x - 16, climb.position.y + 100)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(4)
	Input.action_press("drop")
	await frames(3)
	Input.action_release("drop")
	check(p.ledge_mode == "" and p.velocity.y > 0 and p.ledge_cooldown > 0, "drop releases and prevents immediate regrab")
	p.ledge_cooldown = 0
	p.position = Vector2(climb.position.x - 16, climb.position.y + 100)
	p.velocity = Vector2.ZERO
	await frames(4)
	lab.platform(Rect2(climb.position.x, climb.position.y - 113, climb.size.x, 30))
	var top_blocker = lab.get_child(lab.get_child_count() - 1)
	await frames(3)
	Input.action_press("climb")
	await frames(4)
	Input.action_release("climb")
	check(p.ledge_mode == "HANG", "blocked top refuses climb")
	top_blocker.queue_free()
	await frames(3)

	for rect in [climb, lab.HIGH_PLATFORM]:
		for facing in [1.0, -1.0]:
			var wall_x: float = rect.position.x if facing > 0 else rect.end.x
			p.ledge_mode = ""
			p.ledge_cooldown = 0
			p.position = Vector2(wall_x - facing * 16, lab.GROUND_Y - 1)
			p.velocity = Vector2.ZERO
			p.facing = facing
			await frames(6)
			check(p.is_on_floor() and p.ledge_mode == "", "high stations cannot be grabbed from standing")
			var min_feet: float = p.position.y
			Input.action_press("jump")
			for frame in 45:
				await frames(1)
				min_feet = minf(min_feet, p.position.y)
				if p.ledge_mode == "HANG":
					break
			Input.action_release("jump")
			check(p.ledge_mode == "HANG" and absf(p.ledge_top.y - rect.position.y) < 1, "full ground jump reaches ledge y=%s from facing %s (minimum feet y=%s)" % [rect.position.y, facing, min_feet])
			if p.ledge_mode != "HANG":
				continue
			await frames(5)
			for pair in [["FrontArm", "FrontForearm"], ["BackArm", "BackForearm"]]:
				var upper = p.rig.get_arm(pair[0])
				var lower = upper.get_node(pair[1])
				var hand: Vector2 = lower.get_node("HandContact").global_position
				check(hand.distance_to(p.ledge_top) < 1, "ground-jump hand stays pinned to ledge")
			Input.action_press("climb")
			await frames(ceili(p.climb_duration * Engine.physics_ticks_per_second) + 12)
			Input.action_release("climb")
			check(p.ledge_mode == "" and p.is_on_floor() and absf(p.position.y - rect.position.y) < 2, "ground jump and climb finishes on the intended platform")

	# Even a full-speed jump cannot land directly on the next high station.
	p.ledge_mode = ""
	p.ledge_cooldown = 0
	p.position = Vector2(climb.end.x - 16, climb.position.y - 1)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(5)
	check(p.is_on_floor(), "gap test starts on the first climb station")
	p.velocity.x = p.run_speed
	Input.action_press("right")
	Input.action_press("run")
	Input.action_press("jump")
	var skipped_climb := false
	for frame in 55:
		await frames(1)
		if p.is_on_floor() and absf(p.position.y - lab.HIGH_PLATFORM.position.y) < 2 and p.position.x >= lab.HIGH_PLATFORM.position.x:
			skipped_climb = true
	Input.action_release("right")
	Input.action_release("run")
	Input.action_release("jump")
	check(not skipped_climb and (p.ledge_mode == "HANG" or p.is_on_floor() and absf(p.position.y - lab.GROUND_Y) < 2), "running gap jump still needs a climb instead of landing directly on the high station")
	print("MOTION TESTS: ", "PASS" if errors.is_empty() else errors)
	quit(0 if errors.is_empty() else 1)
