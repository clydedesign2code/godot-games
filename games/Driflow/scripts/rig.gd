extends Node2D
# Normalized timing shared by contact tests and the authored motion.
const FRONT_FOOT_PLANT := 0.60
const BACK_FOOT_PLANT := 0.84
const FRONT_HAND_RELEASE := Vector2(0.60, 0.76)
const BACK_HAND_RELEASE := Vector2(0.52, 0.66)
const WEIGHT_OVER_FOOT := 0.76
var ledge_pose_active := false
var previous_ledge_hip := Vector2.ZERO
var visual_facing := 1.0
var hair_velocity := 0.0
var tip_velocity := 0.0
var previous_facing := 1.0
var previous_y := 0.0
@onready var pony: Bone2D = $Skeleton2D/Hip/Spine/Torso/Neck/Head/Ponytail
@onready var tip: Bone2D = $Skeleton2D/Hip/Spine/Torso/Neck/Head/Ponytail/Tip
var clock := 0.0
var phase := 0.0
var debug_bones := false
@onready var hip: Bone2D = $Skeleton2D/Hip
@onready var torso: Bone2D = $Skeleton2D/Hip/Spine/Torso
@onready var spine: Bone2D = $Skeleton2D/Hip/Spine
@onready var neck: Bone2D = $Skeleton2D/Hip/Spine/Torso/Neck
@onready var head: Bone2D = $Skeleton2D/Hip/Spine/Torso/Neck/Head

func get_arm(prefix: String) -> Bone2D:
	var side := "Front" if prefix.begins_with("Front") else "Back"
	return torso.get_node(side + "Shoulder/" + side + "Arm")

func toggle_debug_bones() -> void:
	if Input.is_action_just_pressed("bones"):
		debug_bones = not debug_bones

func pose(bone: Bone2D, target: float, blend: float) -> void:
	bone.rotation = lerp_angle(bone.rotation, target, blend)

# Ground contacts are stored in world space throughout each support interval.
# Changing pose, turning, teleporting or leaving the floor starts a new cycle.
var contacts: Dictionary = {}
var gait_cycle := 0.0
var gait_mode := -1
var last_root := Vector2.ZERO
var was_grounded := false
var was_moving := false
var air_time := 0.0
var air_lead := 0.0
var air_entry: Dictionary = {}
var gait_entry_points: Dictionary = {}
var gait_entry_time := 1.0

func ground_contact(key: String, offset: float, base: float, stride: float, duty: float, lift: float, moving: bool, facing: float) -> Vector2:
	var t := fposmod(gait_cycle + offset, 1.0)
	var root_point := global_position
	var half := stride * duty * 0.5
	if not contacts.has(key):
		var start := root_point + Vector2((base + lerpf(half, -half, minf(t / duty, 1))) * facing, 0)
		contacts[key] = {"point": start, "last": t, "swing": start, "stance": t < duty}
	var contact: Dictionary = contacts[key]
	if not moving:
		contact.point = contact.point.lerp(root_point + Vector2(base * facing, 0), 0.22)
		contact.last = t
		contact.swing = contact.point
		contact.stance = t < duty
		return contact.point
	if t < duty:
		if not contact.stance or t < contact.last:
			contact.point = root_point + Vector2((base + half - stride * t) * facing, 0)
		contact.swing = contact.point
	else:
		var u := (t - duty) / (1 - duty)
		var goal := root_point + Vector2((base + half) * facing, 0)
		contact.point = (contact.swing as Vector2).lerp(goal, smoothstep(0, 1, u)) - Vector2(0, sin(PI * u) * lift)
	contact.last = t
	contact.stance = t < duty
	if gait_entry_time < 0.12 and gait_entry_points.has(key):
		return (gait_entry_points[key] as Vector2).lerp(contact.point, smoothstep(0, 0.12, gait_entry_time))
	return contact.point

func forearm_axis(side: String) -> float:
	var forearm: Bone2D = get_arm(side).get_node(side + "Forearm")
	return (to_local(forearm.to_global(Vector2.DOWN)) - to_local(forearm.global_position)).angle()

func point_hand(side: String, angle: float) -> void:
	var arm := get_arm(side)
	var forearm: Bone2D = arm.get_node(side + "Forearm")
	var wrist := clampf(angle_difference(forearm_axis(side), angle), -1.65, 1.65)
	var hand: Bone2D = forearm.get_node(side + "Hand")
	hand.rotation = PI / 2 + wrist
	# Compatibility marker follows the actual palm; WristContact is the IK endpoint.
	forearm.get_node("HandContact").position = forearm.to_local(hand.get_node("PalmContact").global_position)

# Solve the wrist and palm together: an authored grip cannot force the wrist
# past its limit. Re-evaluate the small palm offset after choosing a valid angle.
func solve_arm_contact(side: String, palm_world: Vector2, desired_angle: float) -> float:
	var arm := get_arm(side)
	var forearm: Bone2D = arm.get_node(side + "Forearm")
	var palm_local: Vector2 = forearm.get_node(side + "Hand/PalmContact").position
	var hand_angle := desired_angle
	for iteration in 12:
		var wrist_world := palm_world - (to_global(palm_local.rotated(hand_angle)) - global_position)
		solve_limb(arm, forearm, wrist_world, forearm.get_node("WristContact").position.y, -1.0)
		var neutral := forearm_axis(side)
		var feasible := neutral + clampf(angle_difference(neutral, desired_angle), -1.60, 1.60)
		if absf(angle_difference(hand_angle, feasible)) < 0.0001:
			break
		hand_angle = feasible
	return hand_angle

# A ground contact stores the flat-sole reference. Roll around the heel at
# landing and the toe at push-off; the pivot moves continuously through swing.
func ground_foot_pose(side: String, reference: Vector2, cycle: float, duty: float, moving: bool, upright: float) -> Dictionary:
	var boot: Bone2D = hip.get_node(side + "Thigh/" + side + "Shin/" + side + "Boot")
	var sole: Vector2 = boot.get_node("SoleContact").position
	var heel: Vector2 = boot.get_node("HeelContact").position
	var toe: Vector2 = boot.get_node("ToeContact").position
	var pivot := sole
	var angle := 0.0
	var stance := cycle < duty
	if moving:
		if stance:
			var u := cycle / duty
			if u < 0.20:
				pivot = heel
				angle = -0.17 * (1 - smoothstep(0, 0.20, u))
			elif u > 0.70:
				pivot = toe
				angle = 0.25 * smoothstep(0.70, 1, u)
		else:
			var u := (cycle - duty) / (1 - duty)
			pivot = toe.lerp(heel, smoothstep(0, 1, u))
			angle = lerpf(0.25, -0.17, smoothstep(0, 1, u))
	pivot = sole.lerp(pivot, upright)
	angle *= upright
	var anchor := reference + (to_global(Vector2(pivot.x - sole.x, 0)) - global_position)
	var ankle := anchor - (to_global(pivot.rotated(angle)) - global_position)
	return {"ankle": ankle, "angle": angle, "stance": stance, "anchor": anchor, "pivot": pivot}

func solve_ground_foot(side: String, foot: Dictionary) -> void:
	var thigh: Bone2D = hip.get_node(side + "Thigh")
	var shin: Bone2D = thigh.get_node(side + "Shin")
	var boot: Bone2D = shin.get_node(side + "Boot")
	thigh.scale = Vector2.ONE
	solve_limb(thigh, shin, foot.ankle, boot.position.length())
	boot.rotation = foot.angle - thigh.rotation - shin.rotation

func crawl_leg(side: String, knee_world: Vector2, amount: float) -> void:
	var thigh: Bone2D = hip.get_node(side + "Thigh")
	var shin: Bone2D = thigh.get_node(side + "Shin")
	var boot: Bone2D = shin.get_node(side + "Boot")
	var target: Vector2 = hip.to_local(knee_world) - thigh.position
	var length := shin.position.length()
	# Mild 2D foreshortening lets a planted knee remain fixed under a shifting pelvis.
	var projected := clampf(target.length() / length, 0.75, 1.10)
	thigh.scale = Vector2.ONE * lerpf(1, projected, amount)
	thigh.rotation = lerp_angle(thigh.rotation, target.angle() - PI / 2, amount)
	# Fold the shins and turn the toes up before lowering the knee onto the floor.
	var fold := smoothstep(0, 0.65, amount)
	shin.rotation = lerp_angle(shin.rotation, PI / 2 - thigh.rotation, fold)
	boot.rotation = PI * fold - thigh.rotation - shin.rotation
	# Keep the complete replaceable boot above the supporting floor while it folds.
	var artwork: Sprite2D = boot.get_node("Artwork")
	var rect := artwork.get_rect()
	var bottom := boot.global_position.y
	for point in [rect.position, rect.position + Vector2(rect.size.x,0), rect.end, rect.position + Vector2(0,rect.size.y)]:
		bottom = maxf(bottom, artwork.to_global(point).y)
	if bottom > global_position.y:
		var shoe_drop := bottom - boot.global_position.y
		var shin_length := boot.position.length() * thigh.scale.x
		var max_cosine := (global_position.y - shoe_drop - shin.global_position.y) / shin_length
		var folded_angle := acos(clampf(max_cosine, -1, 1))
		shin.rotation = folded_angle - thigh.rotation
		boot.rotation = PI * fold - folded_angle

var takeoff_active := false
var takeoff_moving := false
var takeoff_support := "Front"
var takeoff_anchors: Dictionary = {}
var takeoff_hip := Vector2.ZERO
var takeoff_chest := Vector2.ZERO
var takeoff_chest_angle := 0.0
var takeoff_arms: Dictionary = {}
var takeoff_coat := Vector2(9,1)

func begin_takeoff(moving: bool, facing: float) -> void:
	takeoff_active = true
	takeoff_moving = moving
	visual_facing = facing
	scale.x = facing
	takeoff_hip = hip.position
	takeoff_chest = hip.to_local(torso.global_position)
	takeoff_chest_angle = spine.rotation + torso.rotation
	takeoff_coat = Vector2(spine.get_node("Artwork").position.y, spine.get_node("Artwork").scale.y)
	takeoff_anchors.clear()
	takeoff_arms.clear()
	var closest := INF
	for side in ["Front", "Back"]:
		var boot: Bone2D = hip.get_node(side + "Thigh/" + side + "Shin/" + side + "Boot")
		var toe: Vector2 = boot.get_node("ToeContact").global_position
		var sole: Vector2 = boot.get_node("SoleContact").global_position
		takeoff_anchors[side] = Vector2(toe.x, global_position.y)
		if absf(sole.y - global_position.y) < closest:
			closest = absf(sole.y - global_position.y)
			takeoff_support = side
		var arm := get_arm(side)
		takeoff_arms[side] = Vector2(arm.rotation, arm.get_node(side + "Forearm").rotation)
	was_grounded = true
	air_entry.clear()

func apply_takeoff_pose(progress: float, _facing: float) -> void:
	if not takeoff_active:
		return
	var load := smoothstep(0, 0.45, progress)
	var push := smoothstep(0, 1, progress) if takeoff_hip.y > -40 else smoothstep(0.45, 1, progress)
	var toe_angle := 0.17 * push
	var support: Bone2D = hip.get_node(takeoff_support + "Thigh")
	var boot: Bone2D = support.get_node(takeoff_support + "Shin/" + takeoff_support + "Boot")
	var ankle: Vector2 = to_local(takeoff_anchors[takeoff_support]) - boot.get_node("ToeContact").position.rotated(toe_angle)
	var dx: float = ankle.x - support.position.x
	var finish_x: float = dx - clampf(dx, -24, 24) if takeoff_moving else 0.0
	var leg_length: float = support.get_node(takeoff_support + "Shin").position.length() + boot.position.length() - 0.5
	var finish_y: float = ankle.y - sqrt(maxf(1, leg_length * leg_length - pow(ankle.x - finish_x - support.position.x, 2)))
	var depth := 5.0 if takeoff_moving else 9.0
	# A crouched launch is already loaded: extend rather than dip a second time.
	var loaded_hip := takeoff_hip + Vector2(-2, depth) if takeoff_hip.y < -40 else takeoff_hip
	hip.position = takeoff_hip.lerp(loaded_hip, load).lerp(Vector2(finish_x, finish_y), push)
	var chest_offset := takeoff_chest.lerp(Vector2(3,-33), load * (0.25 if takeoff_hip.y > -40 else 1)).lerp(Vector2(2,-34), push)
	var chest_angle := lerpf(lerpf(takeoff_chest_angle, 0.14, load), 0.05, push)
	spine.rotation = 0
	spine.position = chest_offset + torso.get_node("CoatJoin").position.rotated(chest_angle)
	torso.position = spine.to_local(hip.to_global(chest_offset))
	torso.rotation = chest_angle
	spine.get_node("Artwork").position.y = lerpf(takeoff_coat.x, 9, push)
	spine.get_node("Artwork").scale.y = lerpf(takeoff_coat.y, 1, push)
	pose(neck, -chest_angle * 0.7, 1)
	pose(head, -chest_angle * 0.3, 1)
	for side in ["Front", "Back"]:
		if not takeoff_moving or side == takeoff_support:
			var thigh: Bone2D = hip.get_node(side + "Thigh")
			var shin: Bone2D = thigh.get_node(side + "Shin")
			var shoe: Bone2D = shin.get_node(side + "Boot")
			thigh.scale = Vector2.ONE
			var toe: Vector2 = shoe.get_node("ToeContact").position
			var ankle_world: Vector2 = takeoff_anchors[side] - (to_global(toe.rotated(toe_angle)) - global_position)
			solve_limb(thigh, shin, ankle_world, shoe.position.length())
			shoe.rotation = toe_angle - thigh.rotation - shin.rotation
		var arm := get_arm(side)
		var forearm: Bone2D = arm.get_node(side + "Forearm")
		arm.rotation = takeoff_arms[side].x + 0.18 * load - 0.40 * push
		forearm.rotation = lerpf(takeoff_arms[side].y, -0.45, push)
		point_hand(side, forearm_axis(side))

func animate(dt: float, velocity: Vector2, grounded: bool, _crouch: bool, facing: float, landing: float, low_pose: float = 0.0, jump_progress: float = -1.0) -> void:
	var from_ledge := ledge_pose_active
	ledge_pose_active = false
	var blend := 1 - exp(-22 * dt)
	clock += dt
	var squat := clampf(low_pose, 0, 1)
	var crawl := smoothstep(1, 2, low_pose)
	var moving := grounded and absf(velocity.x) > 3
	var mode := 2 if low_pose > 1.5 else 1 if low_pose > 0.5 else 0
	if mode != gait_mode or facing != previous_facing or not was_grounded or global_position.distance_to(last_root) > 40 or from_ledge or (moving and not was_moving):
		gait_entry_points.clear()
		for side in ["Front", "Back"]:
			var shin: Bone2D = hip.get_node(side + "Thigh/" + side + "Shin")
			gait_entry_points[side + "Foot"] = shin.get_node(side + "Boot/SoleContact").global_position
			gait_entry_points[side + "Knee"] = shin.get_node("KneeContact").global_position
			gait_entry_points[side + "Palm"] = get_arm(side).get_node(side + "Forearm/HandContact").global_position
		contacts.clear()
		gait_cycle = 0.36 if moving else 0
		gait_mode = mode
		gait_entry_time = 0
	gait_entry_time += dt
	var run_amount := clampf((absf(velocity.x) - 220) / 160, 0, 1)
	var stride := lerpf(88, 112, run_amount)
	stride = lerpf(stride, 56, squat)
	stride = lerpf(stride, 34, crawl)
	if moving:
		gait_cycle += absf(global_position.x - last_root.x) / stride
		phase = gait_cycle * TAU
	var amount := clampf(absf(velocity.x) / 220, 0, 1.6)
	visual_facing = move_toward(visual_facing, facing, dt * 20)
	var visible_sign := signf(visual_facing) if absf(visual_facing) > 0.001 else facing
	scale.x = facing if moving or crawl > 0.01 else visible_sign * maxf(0.22, absf(visual_facing))
	var duty := lerpf(lerpf(0.58, 0.42, run_amount), 0.72, squat)
	var feet: Dictionary = {}
	var support_bound := -INF
	if grounded:
		for i in range(2):
			var side := "Front" if i == 0 else "Back"
			var cycle := fposmod(gait_cycle + (0 if i == 0 else 0.5), 1)
			var reference := ground_contact(side + "Foot", 0 if i == 0 else 0.5, 6 if i == 0 else -6, stride, duty, lerpf(13, 7, squat), moving, facing)
			feet[side] = ground_foot_pose(side, reference, cycle, duty, moving, 1 - squat)
			if moving and feet[side].stance:
				var thigh: Bone2D = hip.get_node(side + "Thigh")
				var shin: Bone2D = thigh.get_node(side + "Shin")
				var length: float = shin.position.length() + shin.get_node(side + "Boot").position.length() - 0.15
				var ankle_local := to_local(feet[side].ankle)
				var dx: float = ankle_local.x - thigh.position.x
				var bound: float = ankle_local.y - sqrt(maxf(1, length * length - dx * dx))
				support_bound = maxf(support_bound, bound)
	var walk_height := lerpf(-56, -60, pow(sin(gait_cycle * TAU), 2))
	var run_height := climb_curve(fposmod(gait_cycle, 0.5) * 2, [0.0,0.42,0.84,0.92,1.0], [-56.0,-53.0,-57.0,-58.0,-56.0])
	var travel_hip := lerpf(walk_height, run_height, run_amount) if moving else -60.0
	var hip_target := Vector2(lerpf(0, -8, squat), lerpf(travel_hip, -27, squat))
	hip_target = hip_target.lerp(Vector2(-18, -27), crawl)
	hip_target.y += landing * 6 * (1 - squat) + (0.0 if moving else sin(clock * 2.5) * 0.35) * (1 - crawl * 0.75)
	if not grounded:
		hip_target = Vector2(0, -59)
	hip.position = hip.position.lerp(hip_target, blend)
	if grounded and moving:
		# Once in stride use the authored periodic height without filter phase lag.
		var gait_weight := smoothstep(0, 0.16, gait_entry_time) * (1 - squat)
		hip.position.y = lerpf(hip.position.y, hip_target.y, gait_weight)
		if squat < 0.01 and is_finite(support_bound):
			hip.position.y = maxf(hip.position.y, support_bound)
	var chest_target := Vector2(0, -34).lerp(Vector2(23, -20), squat).lerp(Vector2(38, -5), crawl)
	var angle_target := lerpf(velocity.x * facing * 0.00022, 0.78, squat)
	angle_target = lerpf(angle_target, 1.30, crawl)
	var chest_offset := hip.to_local(torso.global_position).lerp(chest_target, blend)
	var chest_angle := lerp_angle(spine.rotation + torso.rotation, angle_target, blend)
	pose(spine, lerpf(0, 0.95, crawl), blend)
	spine.position = chest_offset + torso.get_node("CoatJoin").position.rotated(chest_angle)
	torso.position = spine.to_local(hip.to_global(chest_offset))
	torso.rotation = chest_angle - spine.rotation
	var coat: Sprite2D = spine.get_node("Artwork")
	coat.position.y = lerpf(9, 3, squat * (1 - crawl))
	coat.scale.y = lerpf(1, 0.60, squat * (1 - crawl))
	for side in ["Front", "Back"]:
		var shoulder: Bone2D = torso.get_node(side + "Shoulder")
		var shoulder_rest := Vector2(9 if side == "Front" else -7, 5)
		var crawl_shoulder := Vector2(6 if side == "Front" else -6, 4 if side == "Front" else 1).rotated(-chest_angle)
		shoulder.position = shoulder.position.lerp(shoulder_rest.lerp(crawl_shoulder, crawl), blend)
	if grounded:
		air_time = 0
		for i in range(2):
			var side := "Front" if i == 0 else "Back"
			solve_ground_foot(side, feet[side])
			if crawl > 0:
				var knee := ground_contact(side + "Knee", 0.58 if i == 0 else 0.08, -15 if i == 0 else -25, stride, 0.76, 4, moving, facing)
				crawl_leg(side, knee - Vector2(0, 5), crawl)
	else:
		if was_grounded or air_entry.is_empty():
			air_lead = clampf(absf(velocity.x) / 220, 0, 1)
			air_entry.clear()
			for side in ["Front", "Back"]:
				var thigh: Bone2D = hip.get_node(side + "Thigh")
				air_entry[side] = Vector2(thigh.rotation, thigh.get_node(side + "Shin").rotation)
		air_time += dt
		# Vertical velocity defines tuck/hold/landing preparation. No gait phase in air.
		var tuck := 1 - smoothstep(-220, 260, velocity.y)
		var entry_blend := smoothstep(0, 0.16, air_time)
		for i in range(2):
			var side := "Front" if i == 0 else "Back"
			var thigh: Bone2D = hip.get_node(side + "Thigh")
			var shin: Bone2D = thigh.get_node(side + "Shin")
			var knee_angle := lerpf(0.28, 0.94, tuck)
			var upper_angle := lerpf(-0.12, -0.55, tuck) + (0.12 if i == 0 else -0.12) * air_lead
			thigh.scale = Vector2.ONE
			pose(thigh, lerp_angle(air_entry[side].x, upper_angle, entry_blend), blend)
			pose(shin, lerp_angle(air_entry[side].y, knee_angle, entry_blend), blend)
			pose(shin.get_node(side + "Boot"), -upper_angle - knee_angle + 0.12, blend)
	var swing := sin(phase) * 0.65 * amount if grounded else 0.08
	for i in range(2):
		var side := "Front" if i == 0 else "Back"
		var arm := get_arm(side)
		var forearm: Bone2D = arm.get_node(side + "Forearm")
		pose(arm, (-swing * 0.85 - 0.12 if i == 0 else swing * 0.85 + 0.12) - chest_angle * squat * 0.45, blend)
		pose(forearm, -0.22 - amount * 0.25, blend)
		if squat > 0:
			var balance_hand := global_position + Vector2((44 if i == 0 else 33) * facing, -30)
			var upper_rest := arm.rotation
			var lower_rest := forearm.rotation
			solve_limb(arm, forearm, balance_hand, forearm.get_node("WristContact").position.y, -1.0)
			arm.rotation = lerp_angle(upper_rest, arm.rotation, squat)
			forearm.rotation = lerp_angle(lower_rest, forearm.rotation, squat)
		if crawl > 0:
			var palm := ground_contact(side + "Palm", 0 if i == 0 else 0.5, 34 if i == 0 else 22, stride, 0.76, 5, moving, facing)
			var upper_old := arm.rotation
			var lower_old := forearm.rotation
			var palm_offset: Vector2 = forearm.get_node(side + "Hand/PalmContact").position
			var wrist_world := palm - (to_global(palm_offset) - global_position)
			solve_limb(arm, forearm, wrist_world, forearm.get_node("WristContact").position.y, -1.0)
			arm.rotation = lerp_angle(upper_old, arm.rotation, crawl)
			forearm.rotation = lerp_angle(lower_old, forearm.rotation, crawl)
		point_hand(side, lerp_angle(forearm_axis(side), 0, crawl))
	pose(neck, -chest_angle * lerpf(0.45, 0.90, squat), blend)
	pose(head, -chest_angle * lerpf(0.20, 0.10, squat), blend)
	toggle_debug_bones()
	var target := clampf(absf(velocity.x) * 0.0013 + (sin(phase) * amount * 0.06 if grounded else 0) - velocity.y * 0.0004, -0.35, 0.8)
	if facing != previous_facing:
		hair_velocity += 2.4
	if grounded and previous_y > 100:
		hair_velocity -= 2
	hair_velocity += ((target - pony.rotation) * 85 - hair_velocity * 13) * dt
	pony.rotation = clampf(pony.rotation + hair_velocity * dt, -0.6, 1)
	tip_velocity += ((pony.rotation * 0.65 - tip.rotation) * 65 - tip_velocity * 10) * dt
	tip.rotation = clampf(tip.rotation + tip_velocity * dt, -0.7, 0.8)
	if jump_progress >= 0 and grounded:
		apply_takeoff_pose(jump_progress, facing)
	previous_facing = facing
	previous_y = velocity.y
	was_grounded = grounded
	was_moving = moving
	last_root = global_position
	queue_redraw()

func _draw() -> void:
	if not debug_bones:
		return
	for bone in find_children("*", "Bone2D", true, false):
		var point: Vector2 = to_local(bone.global_position)
		draw_circle(point, 2.5, Color("72f5db"))
		if bone.get_parent() is Bone2D:
			draw_line(point, to_local(bone.get_parent().global_position), Color("72f5db"), 1)

# References and shot-to-game adaptation: docs/CLIMB_REFERENCE.md.
# PCHIP avoids overshooting the ledge and avoids stopping at every pose key.
func curve_tangent(index: int, times: Array, values: Array) -> float:
	if index == 0 or index == times.size() - 1:
		return 0.0
	var before: float = (values[index] - values[index - 1]) / (times[index] - times[index - 1])
	var after: float = (values[index + 1] - values[index]) / (times[index + 1] - times[index])
	if before * after <= 0:
		return 0.0
	var h_before: float = times[index] - times[index - 1]
	var h_after: float = times[index + 1] - times[index]
	var w_before := 2 * h_after + h_before
	var w_after := h_after + 2 * h_before
	return (w_before + w_after) / (w_before / before + w_after / after)

func climb_curve(progress: float, times: Array, values: Array) -> float:
	for i in range(1, times.size()):
		if progress <= times[i]:
			var h: float = times[i] - times[i - 1]
			var t := clampf((progress - times[i - 1]) / h, 0, 1)
			var t2 := t * t
			var t3 := t2 * t
			return (2*t3 - 3*t2 + 1) * values[i - 1] + (t3 - 2*t2 + t) * h * curve_tangent(i - 1, times, values) + (-2*t3 + 3*t2) * values[i] + (t3 - t2) * h * curve_tangent(i, times, values)
	return values.back()

func ledge_key(progress: float, times: Array, points: Array) -> Vector2:
	var xs: Array = []
	var ys: Array = []
	for point in points:
		xs.append(point.x)
		ys.append(point.y)
	return Vector2(climb_curve(progress, times, xs), climb_curve(progress, times, ys))

func solve_limb(upper: Bone2D, lower: Bone2D, target_world: Vector2, end_length: float, bend_sign: float = 1.0) -> void:
	var target: Vector2 = upper.get_parent().to_local(target_world) - upper.position
	var length: float = lower.position.length()
	var distance := clampf(target.length(), absf(length - end_length) + 0.01, length + end_length - 0.01)
	var offset := acos(clampf((length * length + distance * distance - end_length * end_length) / (2 * length * distance), -1, 1))
	upper.rotation = target.angle() - PI / 2 - offset * bend_sign
	lower.rotation = bend_sign * (PI - acos(clampf((length * length + end_length * end_length - distance * distance) / (2 * length * end_length), -1, 1)))

const FRONT_REACH_TIME := 0.14
const BACK_REACH_DELAY := 0.025
const BACK_REACH_TIME := 0.18
const FRONT_GRIP_TIME := 0.035
const BACK_GRIP_TIME := 0.07
var reach_seed: Dictionary = {}
var catch_seed: Dictionary = {}

func begin_reach() -> void:
	reach_seed.clear()
	for side in ["Front", "Back"]:
		var arm := get_arm(side)
		var palm: Marker2D = arm.get_node(side + "Forearm/HandContact")
		reach_seed[side] = to_local(palm.global_position) - to_local(arm.global_position)

func animate_reach(_dt: float, facing: float, age: float, grip_world: Vector2) -> void:
	if reach_seed.is_empty():
		begin_reach()
	var weight := smoothstep(0, FRONT_REACH_TIME, age)
	var chest_offset := hip.to_local(torso.global_position)
	var chest_angle := lerp_angle(spine.rotation + torso.rotation, -0.03, weight * 0.25)
	spine.position = chest_offset + torso.get_node("CoatJoin").position.rotated(chest_angle)
	torso.position = spine.to_local(hip.to_global(chest_offset))
	torso.rotation = chest_angle - spine.rotation
	for side in ["Front", "Back"]:
		var front: bool = side == "Front"
		var u := smoothstep(0 if front else BACK_REACH_DELAY, FRONT_REACH_TIME if front else BACK_REACH_TIME, age)
		var shoulder: Bone2D = torso.get_node(side + "Shoulder")
		shoulder.position = Vector2(9 if front else -7, 5) + Vector2(0, -2 * u).rotated(-chest_angle)
		var arm := get_arm(side)
		var start_world: Vector2 = arm.global_position + (to_global(reach_seed[side]) - global_position)
		var approach := grip_world + Vector2((-1 if front else -5) * facing, -1 if front else -6)
		# Arc in front of the shoulder, never through its IK singularity.
		var target := start_world.lerp(approach, u) + Vector2(facing * (22 if front else 18) * sin(PI * u), -8 * sin(PI * u))
		var angle := solve_arm_contact(side, target, lerp_angle(forearm_axis(side), -PI * 0.65, u))
		point_hand(side, angle)
	pose(neck, -chest_angle * 0.45 - 0.08 * weight, 1)
	pose(head, -chest_angle * 0.20 - 0.10 * weight, 1)
	queue_redraw()

func begin_catch(_grip_world: Vector2, approach_velocity: Vector2) -> void:
	catch_seed = {"hip": hip.global_position, "chest": hip.to_local(torso.global_position), "angle": spine.rotation + torso.rotation, "neck": neck.rotation, "head": head.rotation, "velocity": approach_velocity, "palms": {}, "hands": {}, "soles": {}, "shoulders": {}}
	for side in ["Front", "Back"]:
		var arm := get_arm(side)
		var hand: Bone2D = arm.get_node(side + "Forearm/" + side + "Hand")
		catch_seed.palms[side] = arm.get_node(side + "Forearm/HandContact").global_position
		catch_seed.hands[side] = (to_local(hand.to_global(Vector2.RIGHT)) - to_local(hand.global_position)).angle()
		catch_seed.soles[side] = hip.get_node(side + "Thigh/" + side + "Shin/" + side + "Boot/SoleContact").global_position
		catch_seed.shoulders[side] = torso.get_node(side + "Shoulder").position
	ledge_pose_active = false
	takeoff_active = false

func animate_catch(dt: float, facing: float, age: float, duration: float, grip_world: Vector2) -> void:
	if catch_seed.is_empty():
		animate_ledge(dt, facing, 0, grip_world)
		return
	toggle_debug_bones()
	visual_facing = facing
	scale.x = facing
	was_grounded = false
	contacts.clear()
	var q := smoothstep(0, maxf(duration, dt), age)
	var load := sin(PI * q)
	var momentum: Vector2 = catch_seed.velocity * age * (1 - smoothstep(0, 0.08, age))
	momentum = Vector2(clampf(momentum.x, -2, 2), clampf(momentum.y, -3, 3))
	var target_hip := grip_world + Vector2(-16 * facing, 70)
	var hip_world: Vector2 = (catch_seed.hip as Vector2).lerp(target_hip, q) + momentum + Vector2(0, 1.6 * load)
	hip.position = to_local(hip_world)
	var chest_offset: Vector2 = (catch_seed.chest as Vector2).lerp(Vector2(8,-32), q) - Vector2(0, 1.2 * load)
	var chest_angle := lerp_angle(catch_seed.angle, 0, q)
	spine.rotation = 0
	spine.position = chest_offset + torso.get_node("CoatJoin").position.rotated(chest_angle)
	torso.position = spine.to_local(hip.to_global(chest_offset))
	torso.rotation = chest_angle
	spine.get_node("Artwork").position.y = 9
	spine.get_node("Artwork").scale.y = 1
	for side in ["Front", "Back"]:
		var front: bool = side == "Front"
		var shoulder: Bone2D = torso.get_node(side + "Shoulder")
		shoulder.position = (catch_seed.shoulders[side] as Vector2).lerp(Vector2(9 if front else -7, 5), q) - Vector2(0, 1.5 * load)
		var grip_weight := smoothstep(0 if front else BACK_REACH_DELAY, FRONT_GRIP_TIME if front else BACK_GRIP_TIME, age)
		var palm_target: Vector2 = (catch_seed.palms[side] as Vector2).lerp(grip_world, grip_weight)
		var hand_angle := lerp_angle(catch_seed.hands[side], -PI / 2, grip_weight)
		var feasible := solve_arm_contact(side, palm_target, hand_angle)
		point_hand(side, feasible)
	for side in ["Front", "Back"]:
		var thigh: Bone2D = hip.get_node(side + "Thigh")
		var shin: Bone2D = thigh.get_node(side + "Shin")
		var boot: Bone2D = shin.get_node(side + "Boot")
		thigh.scale = Vector2.ONE
		var target := grip_world + Vector2((-9 if side == "Front" else -29) * facing, 130 if side == "Front" else 128)
		var sole: Vector2 = (catch_seed.soles[side] as Vector2).lerp(target, q)
		var angle := 0.08 * load
		var sole_offset: Vector2 = boot.get_node("SoleContact").position
		var ankle := sole - (to_global(sole_offset.rotated(angle)) - global_position)
		solve_limb(thigh, shin, ankle, boot.position.length())
		boot.rotation = angle - thigh.rotation - shin.rotation
	neck.rotation = lerp_angle(catch_seed.neck, -chest_angle * 0.45, q)
	head.rotation = lerp_angle(catch_seed.head, -chest_angle * 0.40, q)
	finish_ledge_pose(dt, facing)

func animate_ledge(dt: float, facing: float, progress: float, grip_world: Vector2) -> void:
	toggle_debug_bones()
	spine.get_node("Artwork").position.y = 9
	spine.get_node("Artwork").scale.y = 1
	was_grounded = false
	contacts.clear()
	visual_facing = facing
	scale.x = facing
	var times := [0.0, 0.08, 0.26, 0.42, 0.54, 0.60, 0.76, 0.90, 1.0]
	# Pull with hips outside the lip; shift over the planted foot before standing.
	var hip_offset := ledge_key(progress, times, [Vector2(-16,70), Vector2(-18,68), Vector2(-27,40), Vector2(-35,10), Vector2(-28,-13), Vector2(-18,-25), Vector2(25,-34), Vector2(24,-57), Vector2(22,-61)])
	hip.position = to_local(grip_world + Vector2(hip_offset.x * facing, hip_offset.y))
	spine.rotation = climb_curve(progress, times, [0.0, -0.02, -0.08, -0.10, -0.06, 0.0, 0.08, 0.02, 0.0])
	var torso_offset := ledge_key(progress, times, [Vector2(8,-32), Vector2(10,-32), Vector2(13,-31), Vector2(18,-31), Vector2(18,-32), Vector2(14,-32), Vector2(3,-34), Vector2(0,-34), Vector2(0,-34)])
	var chest_angle := climb_curve(progress, times, [0.0, 0.05, 0.18, 0.50, 0.66, 0.65, 0.35, 0.05, 0.0])
	# Keep the two coat pieces joined at the waist as the chest leans forward.
	spine.position = torso_offset + torso.get_node("CoatJoin").position.rotated(chest_angle)
	torso.position = spine.to_local(hip.to_global(torso_offset))
	torso.rotation = chest_angle - spine.rotation
	var shoulder_load := smoothstep(0, 0.12, progress) * (1 - smoothstep(0.25, 0.55, progress))
	for side in ["Front", "Back"]:
		var shoulder: Bone2D = torso.get_node(side + "Shoulder")
		shoulder.position = Vector2((9 if side == "Front" else -7) + (-0.8 if side == "Front" else 0.8) * shoulder_load, 5 + shoulder_load)
	var grip_angle := climb_curve(progress, [0.0,0.12,0.28,0.45,0.60,1.0], [-PI/2,-PI/2,-1.05,-0.20,0.0,0.0])
	var grip_angles: Dictionary = {}
	for index in range(2):
		var names := ["FrontArm", "FrontForearm"] if index == 0 else ["BackArm", "BackForearm"]
		var upper: Bone2D = get_arm(names[0])
		var lower: Bone2D = upper.get_node(names[1])
		var side := "Front" if index == 0 else "Back"
		grip_angles[side] = solve_arm_contact(side, grip_world, grip_angle)
		var release_window := FRONT_HAND_RELEASE if index == 0 else BACK_HAND_RELEASE
		var release := smoothstep(release_window.x, release_window.y, progress)
		# A low balancing reach bridges the push-off and the relaxed standing arms.
		var arm_rest := lerpf(-0.65 if index == 0 else 0.35, -0.12 if index == 0 else 0.12, smoothstep(0.76, 1, progress))
		upper.rotation = lerp_angle(upper.rotation, arm_rest, release)
		lower.rotation = lerp_angle(lower.rotation, -0.22, release)
	for side in ["Front", "Back"]:
		var window := FRONT_HAND_RELEASE if side == "Front" else BACK_HAND_RELEASE
		point_hand(side, lerp_angle(forearm_axis(side), grip_angles[side], 1 - smoothstep(window.x, window.y, progress)))
	var front_sole := ledge_key(progress, [0.0,0.10,0.28,0.45,0.54,FRONT_FOOT_PLANT,1.0], [Vector2(-9,130),Vector2(-14,124),Vector2(-26,94),Vector2(-28,44),Vector2(-14,-2),Vector2(27,0),Vector2(27,0)])
	var back_sole := ledge_key(progress, [0.0,0.12,0.32,0.52,0.60,0.70,BACK_FOOT_PLANT,1.0], [Vector2(-29,128),Vector2(-35,120),Vector2(-43,85),Vector2(-40,37),Vector2(-37,16),Vector2(-14,-2),Vector2(17,0),Vector2(17,0)])
	for index in range(2):
		var names := ["FrontThigh", "FrontShin", "FrontBoot"] if index == 0 else ["BackThigh", "BackShin", "BackBoot"]
		var thigh: Bone2D = hip.get_node(names[0])
		var shin: Bone2D = thigh.get_node(names[1])
		var boot: Bone2D = shin.get_node(names[2])
		thigh.scale = Vector2.ONE
		var sole: Vector2 = front_sole if index == 0 else back_sole
		var ankle := grip_world + Vector2(sole.x * facing, sole.y - boot.get_node("SoleContact").position.y)
		solve_limb(thigh, shin, ankle, boot.position.length())
		boot.rotation = -thigh.rotation - shin.rotation
	pose(neck, -(torso.rotation + spine.rotation) * 0.45, 1 - exp(-22 * dt))
	pose(head, -(torso.rotation + spine.rotation) * 0.40, 1 - exp(-22 * dt))
	finish_ledge_pose(dt, facing)

func finish_ledge_pose(dt: float, facing: float) -> void:
	var hip_velocity := Vector2.ZERO
	if ledge_pose_active:
		hip_velocity = (hip.global_position - previous_ledge_hip) / maxf(dt, 0.001)
	previous_ledge_hip = hip.global_position
	ledge_pose_active = true
	var hair_target := clampf(-0.18 * torso.rotation + hip_velocity.x * facing * 0.001 - hip_velocity.y * 0.0003, -0.35, 0.45)
	hair_velocity += ((hair_target - pony.rotation) * 85 - hair_velocity * 13) * dt
	pony.rotation = clampf(pony.rotation + hair_velocity * dt, -0.6, 1)
	tip_velocity += ((pony.rotation * 0.65 - tip.rotation) * 65 - tip_velocity * 10) * dt
	tip.rotation = clampf(tip.rotation + tip_velocity * dt, -0.7, 0.8)
	previous_facing = facing
	previous_y = 0
	queue_redraw()
