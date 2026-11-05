extends Node2D

@export var align_to_lab_platforms: bool = true

@onready var result: Label = $UI/Result

func _ready() -> void:
	if align_to_lab_platforms:
		var lab = get_parent()
		var low: Rect2 = lab.LOW_PLATFORM
		var climb: Rect2 = lab.CLIMB_PLATFORM
		$Switch.position = Vector2(low.position.x - 40.0, lab.GROUND_Y)
		$Cabinet.position = Vector2((low.end.x + climb.position.x) * 0.5, lab.GROUND_Y)
		$Clue.position = Vector2(climb.get_center().x, climb.position.y)
	$Switch/Interactable.interacted.connect(_on_switch)
	$Cabinet/Interactable.interacted.connect(_on_cabinet)
	$Clue/Interactable.interacted.connect(_on_clue)

func _on_switch(_actor: Node2D, _action_id: StringName) -> void:
	$Switch/Light.visible = not $Switch/Light.visible
	result.text = "開關：燈光已切換。"

func _on_cabinet(_actor: Node2D, action_id: StringName) -> void:
	match action_id:
		&"look":
			result.text = "查看：櫃門上有一道新刮痕。"
		&"open":
			result.text = "開啟：裡面有一卷沒有標籤的磁帶。"

func _on_clue(_actor: Node2D, _action_id: StringName) -> void:
	$Clue/Shape.hide()
	result.text = "已拿取平台上的線索。這是單次互動示範，尚未寫入存檔。"
