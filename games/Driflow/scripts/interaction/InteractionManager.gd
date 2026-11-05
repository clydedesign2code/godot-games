extends Node

## 全域輸入／目標選擇。只有 interaction_actor 群組裡的主角會啟用此機制。
## 角色移動程式可讀取 is_menu_open 或監聽 menu_state_changed 自行鎖住移動。
signal target_changed(target: InteractableComponent)
signal menu_state_changed(is_open: bool)

const ACTOR_GROUP := &"interaction_actor"
const TARGET_GROUP := &"interactables"

var input_action: StringName = &"interact"
var blocked: bool = false:
	set(value):
		blocked = value
		if value:
			close_menu()
			_set_target(null)
var current_target: InteractableComponent
var is_menu_open: bool:
	get:
		return is_instance_valid(_menu_target)

var _actor: Node2D
var _menu_actor: Node2D
var _menu_target: InteractableComponent
var _layer: CanvasLayer
var _prompt: Label
var _overlay: Control
var _panel: PanelContainer
var _choices: VBoxContainer
var _target_instance_id: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# 未設定時提供預設 E／手把 Y；已有 Input Map 則尊重專案設定。
	if not InputMap.has_action(input_action):
		InputMap.add_action(input_action)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event(input_action, key)
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = JOY_BUTTON_Y
		InputMap.action_add_event(input_action, button)
	_ensure_menu_controls()
	_create_ui()

func _ensure_menu_controls() -> void:
	# Godot 的預設 ui_* 不保證有手把映射；補缺少的標準按鈕，保留既有按鍵。
	var bindings := {&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B,
		&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == bindings[action]:
				found = true
				break
		if not found:
			var button := InputEventJoypadButton.new()
			button.device = -1
			button.button_index = bindings[action]
			InputMap.action_add_event(action, button)

func _process(_delta: float) -> void:
	refresh_target()
	if _overlay.visible:
		if not is_menu_open or _actor != _menu_actor or not _menu_target.can_interact(_menu_actor):
			close_menu()
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and is_menu_open:
		close_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(input_action) and not event.is_echo():
		if is_menu_open or try_interact():
			get_viewport().set_input_as_handled()

## 公開入口可供觸控按鈕呼叫；不需要模擬鍵盤。
func try_interact() -> bool:
	if blocked or get_tree().paused or is_menu_open:
		return false
	refresh_target()
	if not is_instance_valid(current_target):
		return false
	var target := current_target
	if target.response_mode == InteractableComponent.ResponseMode.MENU:
		_open_menu(target)
		return true
	return target.activate(_actor, target.direct_action_id)

func refresh_target() -> void:
	_actor = get_tree().get_first_node_in_group(ACTOR_GROUP) as Node2D
	if blocked or get_tree().paused or not is_instance_valid(_actor):
		_set_target(null)
		return
	var best: InteractableComponent = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		var candidate := node as InteractableComponent
		if candidate == null or not candidate.can_interact(_actor):
			continue
		var distance := candidate.global_position.distance_squared_to(_actor.global_position)
		if best == null or candidate.priority > best.priority or (candidate.priority == best.priority and distance < best_distance):
			best = candidate
			best_distance = distance
	_set_target(best)

func _set_target(target: InteractableComponent) -> void:
	var instance_id := target.get_instance_id() if is_instance_valid(target) else 0
	if _target_instance_id == instance_id:
		current_target = target
		return
	_target_instance_id = instance_id
	current_target = target
	target_changed.emit(current_target)

func _open_menu(target: InteractableComponent) -> void:
	_menu_target = target
	_menu_actor = _actor
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = target.display_name
	_choices.add_child(title)
	for option in target.available_options():
		var button := Button.new()
		button.text = option.label
		button.pressed.connect(choose_option.bind(option.action_id))
		_choices.add_child(button)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(close_menu)
	_choices.add_child(cancel)
	_overlay.show()
	_prompt.hide()
	(_choices.get_child(1) as Button).grab_focus()
	menu_state_changed.emit(true)

## 不信任舊選單：物件可能已移動、被停用、刪除或移除選項。
func choose_option(action_id: StringName) -> bool:
	if not is_menu_open:
		close_menu()
		return false
	var target := _menu_target
	var actor := _menu_actor
	refresh_target()
	var valid := not blocked and not get_tree().paused and _actor == actor and is_instance_valid(target) and target.can_interact(actor)
	close_menu()
	# close_menu 發訊號時，接收端可能切場景或封鎖互動，因此再次確認。
	if not valid or blocked or get_tree().paused or not is_instance_valid(target):
		return false
	if get_tree().get_first_node_in_group(ACTOR_GROUP) != actor:
		return false
	return target.activate(actor, action_id)

func close_menu() -> void:
	# 物件已刪除時仍須關閉畫面。
	var was_open := is_instance_valid(_overlay) and _overlay.visible
	_menu_target = null
	_menu_actor = null
	if is_instance_valid(_overlay):
		_overlay.hide()
	if was_open:
		menu_state_changed.emit(false)

func _update_prompt() -> void:
	_prompt.visible = not blocked and not is_menu_open and is_instance_valid(current_target) and current_target.show_prompt
	if not _prompt.visible:
		return
	var bindings := InputMap.action_get_events(input_action)
	var key_label := bindings[0].as_text() if not bindings.is_empty() else String(input_action)
	_prompt.text = "[%s] %s" % [key_label, current_target.display_name]
	var position_on_screen := current_target.get_global_transform_with_canvas().origin
	_prompt.position = position_on_screen + current_target.prompt_offset

func _create_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.hide()
	_layer.add_child(_prompt)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	_layer.add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	margin.add_child(_choices)
