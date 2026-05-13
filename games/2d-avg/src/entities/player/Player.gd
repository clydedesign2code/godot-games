class_name Player
extends CharacterBody2D

## AVG 玩家控制器。
## 職責：接收背景點擊導航、監聽 hotspot_clicked 觸發互動、管理道具選取模式。
## 場景結構（Player.tscn）：
##   Player (CharacterBody2D)
##   ├── StateMachine
##   │   ├── IdleState
##   │   ├── WalkState
##   │   └── InteractState
##   ├── NavigationAgent2D
##   └── AnimatedSprite2D

const WALK_SPEED: float = 120.0

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## 非空字串表示玩家正持有道具準備點選目標
var selected_item_id: String = ""

func _ready() -> void:
	EventBus.hotspot_clicked.connect(_on_hotspot_clicked)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Hotspot 的點擊由 Area2D 消費，到這裡只剩背景點擊
		walk_to(get_global_mouse_position())

# ─── 移動 ────────────────────────────────────────────────
func walk_to(target: Vector2) -> void:
	nav_agent.target_position = target
	state_machine.transition_to("walk")

# ─── 互動 ────────────────────────────────────────────────
func _on_hotspot_clicked(hotspot_id: String, _verb: String) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if selected_item_id != "":
		EventBus.item_used_on.emit(selected_item_id, hotspot_id)
		deselect_item()
		return
	state_machine.transition_to("interact")

# ─── 道具選取模式 ────────────────────────────────────────
## 供 HUD ItemIcon 呼叫，進入「持著道具等待點選目標」狀態
func select_item(item_id: String) -> void:
	selected_item_id = item_id
	CursorManager.set_cursor("use")

func deselect_item() -> void:
	selected_item_id = ""
	CursorManager.reset_cursor()
