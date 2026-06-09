class_name Player
extends CharacterBody2D

## AVG 玩家控制器（橫向直接移動）。
## 場景結構（Player.tscn）：
##   Player (CharacterBody2D)
##   ├── StateMachine
##   │   ├── IdleState
##   │   ├── WalkState
##   │   └── InteractState
##   └── AnimatedSprite2D

const WALK_SPEED: float = 120.0

@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## 非空字串表示玩家正持有道具準備使用
var selected_item_id: String = ""

## 目前在範圍內可互動的 Hotspot
var nearby_hotspot: HotspotComponent = null

func _ready() -> void:
	EventBus.hotspot_clicked.connect(_on_hotspot_clicked)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# 靠近時按 interact 鍵觸發
	if event.is_action_pressed("interact") and nearby_hotspot != null:
		nearby_hotspot._activate()

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
func select_item(item_id: String) -> void:
	selected_item_id = item_id
	CursorManager.set_cursor("use")

func deselect_item() -> void:
	selected_item_id = ""
	CursorManager.reset_cursor()
