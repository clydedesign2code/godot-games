extends CharacterBody2D

@export var walk_speed: float = 220.0
@export var run_speed: float = 380.0
@export var crouch_speed: float = 85.0
@export var crawl_speed: float = 46.0
@export var posture_speed: float = 4.0
@export var crawl_transition_speed: float = 2.8
# 0 = standing, 1 = squat, 2 = hands and knees.
var low_pose := 0.0
var crawling := false
var posture_shape := RectangleShape2D.new()
@export var acceleration: float = 2200.0
@export var air_acceleration: float = 1500.0
@export var jump_anticipation: float = 0.06
@export var moving_jump_anticipation: float = 0.03
var jump_pending := false
var jump_elapsed := 0.0
var jump_windup_duration := 0.06
var jump_released := false
@export var jump_speed: float = 560.0
@export var gravity: float = 1550.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var turn_delay: float = 0.10
@export var climb_duration: float = 1.02
@export var catch_duration: float = 0.16
@export var reach_distance: float = 64.0
@export var grab_height: float = 130.0
var reach_elapsed := 0.0
var reach_top := Vector2.INF
var reach_facing := 1.0
var catch_elapsed := 0.0
var climb_requested := false
var _interaction_input_guard := false
var ledge_mode := ""
var ledge_cooldown := 0.0
var ledge_top := Vector2.ZERO
var climb_start := Vector2.ZERO
var climb_corner := Vector2.ZERO
var climb_end := Vector2.ZERO
var climb_elapsed := 0.0
var turn_remaining := 0.0
var crouching := false
var facing := 1.0
var grace := 0.0
var buffered := 0.0
var landing := 0.0
var state := "IDLE"
var shape: CollisionShape2D
var rig: Node2D
var standing := CapsuleShape2D.new()
var ducking := CapsuleShape2D.new()

func _ready() -> void:
	add_to_group(&"interaction_actor")
	InteractionManager.menu_state_changed.connect(_on_interaction_menu_changed)
	standing.radius = 13
	standing.height = 132
	ducking.radius = 13
	ducking.height = 88
	shape = CollisionShape2D.new()
	shape.shape = standing
	shape.position.y = -66
	add_child(shape)
	rig = load("res://scenes/rig.tscn").instantiate()
	add_child(rig)
	floor_snap_length = 8

func _on_interaction_menu_changed(is_open: bool) -> void:
	if not is_open:
		# 手把 A 同時是選單確認與跳躍；隔離關閉當幀的輪詢輸入。
		_interaction_input_guard = true

## 距離互動只在地面可用，避免打斷抓邊／攀爬。
func can_interact() -> bool:
	return is_on_floor() and ledge_mode.is_empty() and not jump_pending

func fits_shape(candidate: Shape2D, height: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = candidate
	# Keep the query just above the supporting floor, including exact surface spawns.
	query.transform = Transform2D(0, global_position + Vector2(0, -height / 2 - 0.08))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func can_stand() -> bool:
	return fits_shape(standing, standing.height)

func visual_height() -> float:
	var hat: Sprite2D = rig.head.get_node("Hat/Artwork")
	var rect := hat.get_rect()
	var top := global_position.y
	for point in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		top = minf(top, hat.to_global(point).y)
	return clampf(global_position.y - top + 2, 0, standing.height)

func update_posture(dt: float, grounded: bool) -> void:
	var target := 0.0
	if grounded:
		target = 2.0 if Input.is_action_pressed("crawl") else 1.0 if Input.is_action_pressed("crouch") else 0.0
	if target == 2 and low_pose <= 1.01:
		var crawl_shape := RectangleShape2D.new()
		crawl_shape.size = Vector2(132, 64)
		if not fits_shape(crawl_shape, 64):
			target = 1
	if target == 0 and low_pose > 0.01 and not can_stand():
		target = 1.0 if fits_shape(ducking, ducking.height) else 2.0
	# Jump may unfold a squat, but does not silently queue a jump after a crawl.
	if buffered > 0 and low_pose <= 1.01 and can_stand():
		target = 0.0
	var rate := crawl_transition_speed if maxf(low_pose, target) > 1.01 else posture_speed
	var next := move_toward(low_pose, target, rate * dt)
	var height := lerpf(132, 88, minf(next, 1)) if next <= 1 else lerpf(88, 64, next - 1)
	# Do not shrink the collider ahead of the visible head during a transition.
	height = maxf(height, visual_height())
	var width := lerpf(26, 132, smoothstep(1.45, 2, next))
	var current_height: float = shape.shape.height if shape.shape is CapsuleShape2D else shape.shape.size.y
	var current_width: float = 26 if shape.shape is CapsuleShape2D else shape.shape.size.x
	var candidate := RectangleShape2D.new()
	candidate.size = Vector2(width, height)
	# Contraction is always safe; expansion must fit before changing the pose.
	if (shape.shape is RectangleShape2D and width <= current_width + 0.001 and height <= current_height + 0.001) or fits_shape(candidate, height):
		low_pose = next
		if low_pose < 0.001:
			shape.shape = standing
		else:
			posture_shape.size = Vector2(width, height)
			shape.shape = posture_shape
		shape.position.y = -height / 2
	crouching = low_pose > 0.01
	crawling = low_pose > 1.01

func cancel_jump_preparation() -> void:
	jump_pending = false
	jump_elapsed = 0
	jump_released = false
	if is_instance_valid(rig):
		rig.takeoff_active = false

func launch_jump(direction: float, grounded: bool) -> void:
	# Finish the grounded extension before applying the impulse; air pose captures it.
	if grounded and jump_pending:
		rig.apply_takeoff_pose(1.0, facing)
	if absf(direction) < 0.01:
		velocity.x = 0
	velocity.y = -jump_speed * (0.55 if jump_released or not Input.is_action_pressed("jump") else 1.0)
	cancel_jump_preparation()
	crouching = false
	crawling = false
	low_pose = 0
	shape.shape = standing
	shape.position.y = -standing.height / 2
	buffered = 0
	grace = 0

func _physics_process(dt: float) -> void:
	var resetting := Input.is_action_just_pressed("reset") or position.y > 950
	if resetting:
		position = Vector2(150, 580)
		velocity = Vector2.ZERO
		turn_remaining = 0.0
		ledge_mode = ""
		climb_requested = false
		reach_elapsed = 0
		reach_top = Vector2.INF
		catch_elapsed = 0
		cancel_jump_preparation()
		buffered = 0
		grace = 0
		low_pose = 0
		crouching = false
		crawling = false
		shape.shape = standing
		shape.position.y = -66
	# 選單只鎖玩家輸入，保留重力與碰撞，不暫停整個場景。
	if InteractionManager.is_menu_open or _interaction_input_guard:
		_interaction_input_guard = false
		velocity.x = 0.0
		buffered = 0.0
		cancel_jump_preparation()
		turn_remaining = 0.0
		if not is_on_floor():
			velocity.y += gravity * dt
		move_and_slide()
		state = "INTERACT"
		rig.animate(dt, velocity, is_on_floor(), crouching, facing, landing, low_pose)
		return
	ledge_cooldown = maxf(0, ledge_cooldown - dt)
	if update_ledge(dt):
		return
	var grounded := is_on_floor() and not resetting
	grace = coyote_time if grounded else maxf(0, grace - dt)
	buffered = jump_buffer if not resetting and Input.is_action_just_pressed("jump") else maxf(0, buffered - dt)
	var direction := Input.get_axis("left", "right")
	turn_remaining = maxf(0.0, turn_remaining - dt)
	if absf(direction) > 0.01:
		var desired_facing := signf(direction)
		if desired_facing != facing and grounded and absf(velocity.x) < 8.0:
			turn_remaining = turn_delay
		facing = desired_facing
	# Release cancels the pending walk. Jump and run never wait for a turn.
	if absf(direction) < 0.01 or not grounded or buffered > 0 or Input.is_action_pressed("run"):
		turn_remaining = 0.0
	update_posture(dt, grounded)
	var speed := lerpf(walk_speed, crouch_speed, minf(low_pose, 1)) if low_pose <= 1 else lerpf(crouch_speed, crawl_speed, low_pose - 1)
	if low_pose < 0.01 and Input.is_action_pressed("run"):
		speed = run_speed
	if turn_remaining > 0:
		velocity.x = 0.0
	else:
		velocity.x = move_toward(velocity.x, direction * speed, (acceleration if grounded else air_acceleration) * dt)
	if not jump_pending and buffered > 0 and grace > 0 and low_pose <= 1.01 and can_stand():
		jump_released = not Input.is_action_pressed("jump")
		if not grounded:
			# Coyote jumps remain immediate: there is no surface to compress against.
			launch_jump(direction, false)
		else:
			jump_pending = true
			jump_elapsed = 0
			jump_windup_duration = jump_anticipation if low_pose > 0.4 else moving_jump_anticipation if absf(velocity.x) > 80 or absf(direction) > 0.01 else jump_anticipation
			rig.begin_takeoff(absf(velocity.x) > 80 or absf(direction) > 0.01, facing)
	if jump_pending:
		jump_released = jump_released or not Input.is_action_pressed("jump")
		if not can_stand():
			cancel_jump_preparation()
			buffered = 0
		elif not grounded:
			if grace > 0:
				launch_jump(direction, false)
			else:
				cancel_jump_preparation()
		else:
			jump_elapsed += dt
			if jump_elapsed >= jump_windup_duration:
				launch_jump(direction, true)
	if Input.is_action_just_released("jump") and velocity.y < -220:
		velocity.y = -220
	if not grounded or velocity.y < 0:
		velocity.y += gravity * (1.25 if velocity.y > 0 else 1.0) * dt
	move_and_slide()
	if try_grab_ledge():
		rig.animate_catch(dt, facing, 0.0, catch_duration, ledge_top)
		return
	if not grounded and is_on_floor():
		landing = 1.0
	landing = move_toward(landing, 0, dt * 7)
	state = ("CRAWL" if crawling else "CROUCH") if crouching else ("RISE" if velocity.y < -5 else "FALL") if not is_on_floor() else ("RUN" if absf(velocity.x) > walk_speed + 20 else "WALK") if absf(velocity.x) > 8 else "IDLE"
	if turn_remaining > 0 and is_on_floor():
		state = "TURN"
	var jump_progress := clampf(jump_elapsed / maxf(jump_windup_duration, dt), 0, 1) if jump_pending else -1.0
	if jump_pending:
		state = "JUMP_LOAD" if jump_progress < 0.45 and rig.takeoff_hip.y < -40 else "JUMP_PUSH"
	rig.animate(dt, velocity, is_on_floor(), crouching, facing, landing, low_pose, jump_progress)
	update_reach(dt)

func ray_between(start: Vector2, end: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(start, end, collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)

func clear_at(feet: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = standing
	query.transform = Transform2D(0, feet + Vector2(0, -standing.height / 2))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()

# The same collision geometry drives preview and actual contact.
func find_ledge_candidate(distance: float, maximum_height: int) -> Dictionary:
	for height in range(maximum_height, 79, -3):
		var side := ray_between(global_position + Vector2(0, -height), global_position + Vector2(facing * distance, -height))
		if side.is_empty() or side.normal.x * facing > -0.8:
			continue
		var x: float = side.position.x
		var top := ray_between(Vector2(x + facing * 3, global_position.y - maximum_height - 12), Vector2(x + facing * 3, global_position.y - height + 1))
		if top.is_empty() or top.normal.y > -0.9 or top.collider != side.collider:
			continue
		return {"top": Vector2(x, top.position.y), "collider": top.collider}
	return {}

func update_reach(dt: float) -> void:
	if is_on_floor() or crouching or ledge_cooldown > 0 or Input.is_action_pressed("drop"):
		reach_elapsed = 0
		reach_top = Vector2.INF
		return
	var candidate := find_ledge_candidate(reach_distance, 190)
	if candidate.is_empty():
		reach_elapsed = 0
		reach_top = Vector2.INF
		return
	var top: Vector2 = candidate.top
	var remaining_rise := velocity.y * velocity.y / (2 * gravity) if velocity.y < 0 else 0.0
	if global_position.y - remaining_rise > top.y + grab_height:
		reach_elapsed = 0
		reach_top = Vector2.INF
		return
	if reach_top == Vector2.INF or reach_top.distance_to(top) > 2 or reach_facing != facing:
		reach_elapsed = 0
		reach_top = top
		reach_facing = facing
		rig.begin_reach()
	reach_elapsed += dt
	rig.animate_reach(dt, facing, reach_elapsed, reach_top)

func try_grab_ledge() -> bool:
	if is_on_floor() or crouching or ledge_cooldown > 0 or Input.is_action_pressed("drop"):
		return false
	var candidate := find_ledge_candidate(27, 138)
	if candidate.is_empty():
		return false
	var top: Vector2 = candidate.top
	# A side-ray may hit the bottom of a thick ledge. Check the TOP height,
	# rather than treating the scan height as the anatomical reach limit.
	if global_position.y - top.y > grab_height:
		return false
	var hang := Vector2(top.x - facing * 16, top.y + 130)
	if not clear_at(hang) or test_move(global_transform, hang - global_position):
		return false
	ledge_top = top
	if reach_top != Vector2.INF and reach_top.distance_to(top) < 2:
		rig.animate_reach(0, facing, reach_elapsed, top)
	rig.begin_catch(ledge_top, velocity)
	global_position = hang
	velocity = Vector2.ZERO
	buffered = 0
	grace = 0
	turn_remaining = 0
	catch_elapsed = 0
	# Preserve Up/W held or pressed on the contact frame.
	climb_requested = Input.is_action_pressed("climb")
	reach_elapsed = 0
	reach_top = Vector2.INF
	ledge_mode = "HANG"
	state = "HANG"
	return true

func start_climb() -> bool:
	if ledge_mode != "HANG":
		return false
	if catch_elapsed < catch_duration:
		climb_requested = true
		return true
	climb_requested = false
	climb_start = global_position
	climb_corner = Vector2(global_position.x, ledge_top.y - 1)
	climb_end = Vector2(ledge_top.x + facing * 22, ledge_top.y - 1)
	# Both legs of the route are swept before climbing; no collision disabling.
	if not clear_at(climb_end) or test_move(global_transform, climb_corner - global_position):
		return false
	var corner_transform := global_transform
	corner_transform.origin = climb_corner
	if test_move(corner_transform, climb_end - climb_corner):
		return false
	climb_elapsed = 0
	ledge_mode = "CLIMB"
	return true

func update_ledge(dt: float) -> bool:
	if ledge_mode.is_empty():
		return false
	velocity = Vector2.ZERO
	if Input.is_action_just_pressed("drop") or Input.is_action_just_pressed("crouch"):
		ledge_mode = ""
		climb_requested = false
		reach_elapsed = 0
		reach_top = Vector2.INF
		ledge_cooldown = 0.35
		return false
	if ledge_mode == "HANG":
		catch_elapsed = minf(catch_duration, catch_elapsed + dt)
		if Input.is_action_just_pressed("climb"):
			climb_requested = true
		if catch_elapsed < catch_duration:
			rig.animate_catch(dt, facing, catch_elapsed, catch_duration, ledge_top)
		else:
			rig.animate_ledge(dt, facing, 0, ledge_top)
			if climb_requested:
				start_climb()
	else:
		climb_elapsed += dt
		var progress := minf(1.0, climb_elapsed / maxf(climb_duration, dt))
		var target: Vector2
		if progress < 0.66:
			target = climb_start.lerp(climb_corner, smoothstep(0, 0.66, progress))
		else:
			target = climb_corner.lerp(climb_end, smoothstep(0.66, 0.94, progress))
		var collision := move_and_collide(target - global_position)
		rig.animate_ledge(dt, facing, progress, ledge_top)
		if collision != null or progress >= 1:
			ledge_mode = ""
			ledge_cooldown = 0.25
	state = ledge_mode if not ledge_mode.is_empty() else "IDLE"
	return true
