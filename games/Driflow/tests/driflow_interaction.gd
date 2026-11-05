extends SceneTree

var errors: Array[String] = []
var count: int = 0
var manager: Node

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		errors.append(message)
		push_error(message)

func frames(n: int) -> void:
	for index in n:
		await physics_frame

func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	manager = root.get_node("InteractionManager")
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await frames(30)
	var player = lab.player
	var props = lab.get_node("InteractionProps")
	var climb: Rect2 = lab.CLIMB_PLATFORM
	var switch_feet := Vector2(props.get_node("Switch").global_position.x, lab.GROUND_Y - 1.0)
	var cabinet_feet := Vector2(props.get_node("Cabinet").global_position.x, lab.GROUND_Y - 1.0)
	check(player.is_in_group(&"interaction_actor"), "Detective must register as interaction actor")
	check(player.is_on_floor(), "Detective must start grounded")
	check(not manager.try_interact(), "Spawn must be outside object radius")
	player.position = switch_feet
	player.velocity = Vector2.ZERO
	await frames(4)
	press(&"interact")
	await frames(2)
	check(props.get_node("Switch/Light").visible, "Detective must toggle switch with actual action input")
	player.position = cabinet_feet
	player.velocity = Vector2.ZERO
	await frames(4)
	press(&"interact")
	await frames(2)
	check(manager.is_menu_open, "Detective must open cabinet menu")
	var anchor: Vector2 = player.position
	Input.action_press("right")
	Input.action_press("jump")
	await frames(8)
	check(player.position.distance_to(anchor) < 0.1, "Menu must lock movement and jumping")
	check(player.state == "INTERACT" and player.is_on_floor(), "Menu must retain grounded physics")
	Input.action_release("right")
	Input.action_release("jump")
	press(&"ui_accept")
	await frames(3)
	check(not manager.is_menu_open and "刮痕" in props.result.text, "Keyboard confirmation must deliver cabinet action")
	check(player.buffered == 0, "Menu jump must not leak into buffered jump")
	manager.try_interact()
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	Input.parse_input_event(confirm)
	await frames(1)
	confirm = confirm.duplicate()
	confirm.pressed = false
	Input.parse_input_event(confirm)
	await frames(3)
	check(not manager.is_menu_open and player.is_on_floor() and player.velocity.y >= 0, "Controller A must confirm without leaking into jump")
	Input.action_press("left")
	await frames(18)
	Input.action_release("left")
	check(player.position.x < anchor.x - 20, "Locomotion must resume after closing menu")
	player.position = cabinet_feet
	player.velocity = Vector2.ZERO
	await frames(4)
	manager.try_interact()
	press(&"ui_cancel")
	await frames(2)
	check(not manager.is_menu_open, "Escape must cancel menu")
	# 等 UI 關閉事件與當幀防護結束，再開始獨立的跳躍測試。
	await frames(4)
	# 跳躍期間範圍仍重疊，也不可開啟互動。
	Input.action_press("jump")
	await frames(6)
	check(not player.is_on_floor() and not manager.try_interact(), "Airborne detective must reject interaction")
	Input.action_release("jump")
	await frames(70)
	# 原有抓邊控制保持運作，而且懸掛時不可觸發物件。
	player.position = Vector2(climb.position.x - 16.0, climb.position.y + 100.0)
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.ledge_cooldown = 0
	await frames(4)
	check(player.ledge_mode == "HANG" and not player.can_interact(), "Hang must remain functional and disable interactions")
	check(not manager.try_interact(), "Manager must reject input during hang")
	Input.action_press("climb")
	await frames(ceili(player.catch_duration * Engine.physics_ticks_per_second) + 3)
	Input.action_release("climb")
	check(player.ledge_mode == "CLIMB" and not manager.try_interact(), "Climb must remain functional and disable interactions")
	await frames(ceili(player.climb_duration * Engine.physics_ticks_per_second) + 6)
	player.position = Vector2(climb.get_center().x, climb.position.y - 1.0)
	player.velocity = Vector2.ZERO
	await frames(5)
	check(player.is_on_floor() and player.can_interact(), "Standing on platform must enable interaction")
	press(&"interact")
	await frames(2)
	check(not props.get_node("Clue/Shape").visible, "Platform clue must be collected")
	check(not manager.try_interact(), "Platform clue must not react twice")
	# 開啟選單後移除主角或切換關卡也須清理。
	player.position = cabinet_feet
	player.velocity = Vector2.ZERO
	await frames(6)
	manager.try_interact()
	check(manager.is_menu_open, "Cabinet menu must remain reusable")
	lab.queue_free()
	await frames(4)
	check(not manager.is_menu_open and not manager.try_interact(), "Scene deletion must clean global menu and target")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var preview = load("res://scenes/lab.tscn").instantiate()
			root.add_child(preview)
			current_scene = preview
			await frames(20)
			var preview_props = preview.get_node("InteractionProps")
			var cabinet_position: Vector2 = preview_props.get_node("Cabinet").global_position
			preview.player.position = cabinet_position + Vector2(-35.0, -1.0)
			preview.player.velocity = Vector2.ZERO
			await frames(4)
			# 選較近的櫃子，同時讓偵探可見。
			await frames(4)
			manager.try_interact()
			await frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
	print("DRIFLOW INTERACTION TESTS: %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL", count])
	quit(0 if errors.is_empty() else 1)
