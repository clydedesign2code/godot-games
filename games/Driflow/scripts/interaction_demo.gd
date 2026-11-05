extends Node2D

## 獨立互動測試台，不依賴原有 Player／GameManager／Popochiu。
@onready var actor: Node2D = $Actor
@onready var result: Label = $UI/Result

func _ready() -> void:
	$Camera2D.position = get_viewport_rect().size * 0.5
	$Camera2D.make_current()
	$Switch/Interactable.interacted.connect(_on_switch)
	$Cabinet/Interactable.interacted.connect(_on_cabinet)
	$Clue/Interactable.interacted.connect(_on_clue)
	InteractionManager.menu_state_changed.connect(_on_menu_state_changed)

func _physics_process(delta: float) -> void:
	if InteractionManager.is_menu_open:
		return
	actor.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 220.0 * delta
	actor.position = actor.position.clamp(Vector2(30, 170), Vector2(1250, 670))

func _on_switch(_actor: Node2D, _action_id: StringName) -> void:
	$Switch/Light.visible = not $Switch/Light.visible
	result.text = "開關：燈光已切換。"

func _on_cabinet(_actor: Node2D, action_id: StringName) -> void:
	if action_id == &"look":
		result.text = "查看：櫃門上有一道新刮痕。"
	elif action_id == &"open":
		result.text = "開啟：櫃子裡傳出金屬碰撞聲。"

func _on_clue(_actor: Node2D, _action_id: StringName) -> void:
	$Clue/Shape.hide()
	result.text = "已拿取線索；此物件已停用，無法再次觸發。"

func _on_menu_state_changed(is_open: bool) -> void:
	if is_open:
		result.text = "方向鍵選擇／Enter 確認／Esc 取消，也可用滑鼠選擇。"
