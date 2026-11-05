extends SceneTree

var failures: int = 0
var checks: int = 0
var activations: Array[StringName] = []
var manager: Node
var actor: Node2D
var room: Node2D

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _frames(count: int = 2) -> void:
	for index in count:
		await process_frame

func _target(at: Vector2, radius: float = 100.0) -> InteractableComponent:
	var target := InteractableComponent.new()
	target.position = at
	target.interaction_radius = radius
	room.add_child(target)
	target.interacted.connect(func(_actor: Node2D, id: StringName): activations.append(id))
	return target

func _option(id: StringName) -> InteractionOption:
	var option := InteractionOption.new()
	option.action_id = id
	option.label = String(id)
	return option

func _press(action: StringName, echo: bool = false) -> void:
	if echo:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		key.echo = true
		Input.parse_input_event(key)
	else:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		Input.parse_input_event(event)
		var release := InputEventAction.new()
		release.action = action
		Input.parse_input_event(release)

func _run() -> void:
	manager = root.get_node("InteractionManager")
	check(InputMap.has_action(&"interact"), "Input Map fallback must exist")
	check(not manager.try_interact(), "No actor must be inert")
	room = Node2D.new()
	root.add_child(room)
	actor = Node2D.new()
	actor.add_to_group(&"interaction_actor")
	room.add_child(actor)
	var first := _target(Vector2(101, 0))
	check(not manager.try_interact(), "Outside radius must not activate")
	actor.position.x = 1.0
	check(manager.try_interact(), "Exact radius boundary must activate")
	check(activations.size() == 1, "Boundary activation must emit once")
	actor.position = Vector2.ZERO
	first.interaction_radius = 120.0
	check(manager.try_interact(), "Radius changes must apply immediately")
	var nearer := _target(Vector2(20, 0))
	manager.refresh_target()
	check(manager.current_target == nearer, "Nearest target must win")
	first.priority = 1
	manager.refresh_target()
	check(manager.current_target == first, "Higher priority must win")
	first.hide()
	manager.refresh_target()
	check(manager.current_target == nearer, "Hidden target must be excluded")
	first.show()
	first.enabled = false
	manager.refresh_target()
	check(manager.current_target == nearer, "Disabled target must be excluded")
	var before := activations.size()
	_press(&"interact")
	await _frames()
	check(activations.size() == before + 1, "Real input must dispatch exactly once")
	_press(&"interact", true)
	await _frames()
	check(activations.size() == before + 1, "Key repeat must not activate")
	nearer.disable_after_use = true
	check(manager.try_interact(), "One-shot target must activate")
	check(not manager.try_interact(), "One-shot target must reject second use")
	nearer.enabled = true
	nearer.disable_after_use = false
	nearer.response_mode = InteractableComponent.ResponseMode.MENU
	check(not manager.try_interact(), "Menu without options must be inert")
	var look := _option(&"look")
	var open := _option(&"open")
	nearer.options = [look, open]
	before = activations.size()
	check(manager.try_interact() and manager.is_menu_open, "Menu response must open UI")
	check(activations.size() == before, "Opening menu must not execute an action")
	check(not manager.try_interact(), "Repeated action must not open another menu")
	check(manager.choose_option(&"look"), "Valid menu selection must execute")
	check(activations.back() == &"look" and not manager.is_menu_open, "Choice must return its ID and close")
	manager.try_interact()
	check(not manager.choose_option(&"forged"), "Unlisted action must be rejected")
	manager.try_interact()
	open.enabled = false
	check(not manager.choose_option(&"open"), "Option disabled after opening must be rejected")
	manager.try_interact()
	actor.position = Vector2(500, 0)
	check(not manager.choose_option(&"look"), "Selection after leaving radius must be rejected immediately")
	actor.position = Vector2.ZERO
	manager.try_interact()
	actor.position = Vector2(500, 0)
	await _frames()
	check(not manager.is_menu_open and not manager.get("_overlay").visible, "Leaving range must close UI")
	actor.position = Vector2.ZERO
	manager.try_interact()
	_press(&"ui_cancel")
	await _frames()
	check(not manager.is_menu_open, "Escape must close menu")
	manager.try_interact()
	nearer.hide()
	await _frames()
	check(not manager.is_menu_open, "Hiding target must close menu")
	nearer.show()
	manager.try_interact()
	nearer.enabled = false
	await _frames()
	check(not manager.is_menu_open, "Disabling target must close menu")
	nearer.enabled = true
	manager.try_interact()
	var block_on_close := func(is_open: bool):
		if not is_open:
			manager.blocked = true
	manager.menu_state_changed.connect(block_on_close)
	check(not manager.choose_option(&"look"), "Close listener blocking interaction must prevent execution")
	manager.menu_state_changed.disconnect(block_on_close)
	manager.blocked = false
	manager.try_interact()
	manager.blocked = true
	check(not manager.is_menu_open and not manager.try_interact(), "Global block must close and prevent interaction")
	manager.blocked = false
	paused = true
	check(not manager.try_interact(), "Paused tree must reject public input")
	paused = false
	manager.try_interact()
	nearer.queue_free()
	await _frames(3)
	check(not manager.is_menu_open and not manager.get("_overlay").visible, "Deleting menu target must close UI")
	first.enabled = true
	first.priority = 0
	var container := Node2D.new()
	room.add_child(container)
	first.reparent(container)
	container.hide()
	check(not manager.try_interact(), "Hidden ancestor must exclude target")
	container.show()
	first.disable_after_use = true
	first.interacted.connect(func(_a: Node2D, _id: StringName): check(not first.activate(actor, &"interact"), "One-shot must resist reentrant signal handlers"))
	check(manager.try_interact(), "One-shot with reentrant listener must still complete")
	actor.queue_free()
	await _frames(3)
	check(not manager.try_interact(), "Deleting actor must make manager inert")
	room.queue_free()
	await _frames()
	# 執行實際示範場景與 UI，確保資源與訊號連線可以一起運作。
	var demo := load("res://scenes/interaction_demo.tscn").instantiate() as Node2D
	root.add_child(demo)
	current_scene = demo
	await _frames()
	check(demo.get_global_transform_with_canvas().origin.length() < 0.1, "Demo camera must isolate the scene from addon cameras")
	var demo_actor := demo.get_node("Actor") as Node2D
	demo_actor.position = Vector2(380, 350)
	_press(&"interact")
	await _frames()
	check(demo.get_node("Switch/Light").visible, "Demo switch must toggle light via real input")
	demo_actor.position = Vector2(690, 350)
	_press(&"interact")
	await _frames()
	check(manager.is_menu_open, "Demo cabinet must open menu")
	_press(&"ui_accept")
	await _frames()
	check("刮痕" in demo.get_node("UI/Result").text and not manager.is_menu_open, "Focused menu must accept keyboard confirmation")
	_press(&"interact")
	await _frames()
	# 以真實 GUI 滑鼠事件選擇第一個選項。
	var choices := manager.get("_choices") as VBoxContainer
	var choice := choices.get_child(1) as Button
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = choice.get_global_rect().get_center()
	click.pressed = true
	# headless 視窗是 64x64，GUI 卻沿用專案的邏輯解析度；直接送入 viewport 本地座標。
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await _frames()
	check("刮痕" in demo.get_node("UI/Result").text and not manager.is_menu_open, "GUI click must deliver cabinet option")
	demo_actor.position = Vector2(1010, 350)
	_press(&"interact")
	await _frames()
	check(not demo.get_node("Clue/Shape").visible, "Demo clue must disappear")
	check(not manager.try_interact(), "Demo clue must stay disabled")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			demo_actor.position = Vector2(690, 350)
			manager.try_interact()
			await _frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argument.trim_prefix("--capture="))
	print("INTERACTION TESTS: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
