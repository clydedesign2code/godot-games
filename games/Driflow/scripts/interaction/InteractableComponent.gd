@tool
class_name InteractableComponent
extends Node2D

## 加為物件的子節點；本節點的位置就是互動距離的圓心（世界座標像素）。
## 不需要碰撞形狀，也不接收個別物件的按鍵輸入。
signal interacted(actor: Node2D, action_id: StringName)

enum ResponseMode { DIRECT, MENU }

@export var display_name: String = "物件"
@export var enabled: bool = true
@export_range(1.0, 2000.0, 1.0, "or_greater") var interaction_radius: float = 96.0:
	set(value):
		interaction_radius = maxf(value, 1.0)
		queue_redraw()
## 較高優先級先選中；同級選最近的物件。
@export var priority: int = 0
@export var response_mode: ResponseMode = ResponseMode.DIRECT
@export var direct_action_id: StringName = &"interact"
@export var options: Array[InteractionOption] = []
@export var disable_after_use: bool = false
@export var show_prompt: bool = true
@export var prompt_offset: Vector2 = Vector2(0, -48)
@export var debug_draw_radius: bool = false:
	set(value):
		debug_draw_radius = value
		queue_redraw()

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(&"interactables")

func _draw() -> void:
	if Engine.is_editor_hint() or debug_draw_radius:
		# 抵消祖先縮放，與以世界像素計算的距離一致。
		var inverse_basis := global_transform.affine_inverse()
		var points := PackedVector2Array()
		for index in 65:
			var offset := Vector2.from_angle(TAU * index / 64.0) * interaction_radius
			points.append(inverse_basis.basis_xform(offset))
		draw_polyline(points, Color(0.35, 0.9, 0.75, 0.7), 1.0)

func can_interact(actor: Node2D) -> bool:
	if not enabled or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree():
		return false
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if not can_process() or not actor.can_process() or get_viewport() != actor.get_viewport():
		return false
	if get_world_2d() != actor.get_world_2d():
		return false
	# 控制器可選擇實作此 hook，例如懸掛／攀爬期間不允許開選單。
	if actor.has_method("can_interact") and not actor.call("can_interact"):
		return false
	if global_position.distance_squared_to(actor.global_position) > interaction_radius * interaction_radius:
		return false
	return response_mode == ResponseMode.DIRECT or not available_options().is_empty()

func available_options() -> Array[InteractionOption]:
	var result: Array[InteractionOption] = []
	for option in options:
		if option != null and option.enabled and option.action_id != &"":
			result.append(option)
	return result

## Manager 在按鍵、開選單和選定選項時都會重新驗證距離。
func activate(actor: Node2D, action_id: StringName) -> bool:
	if not can_interact(actor):
		return false
	if response_mode == ResponseMode.DIRECT:
		if action_id != direct_action_id:
			return false
	else:
		var found := false
		for option in available_options():
			if option.action_id == action_id:
				found = true
				break
		if not found:
			return false
	# 先禁用，讓訊號接收端即使立即再次呼叫也不會重複觸發。
	if disable_after_use:
		enabled = false
	interacted.emit(actor, action_id)
	return true
