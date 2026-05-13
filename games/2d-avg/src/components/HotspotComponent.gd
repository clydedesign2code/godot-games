class_name HotspotComponent
extends Area2D

## AVG 熱區互動組件（掛在任何場景物件的子節點上）。
##
## 使用方式：
##   1. 將此節點加為場景物件的子節點
##   2. 加入 CollisionShape2D 作為子節點，定義可點擊範圍
##   3. 設定 Export 屬性（hotspot_id、verb、dialogue_timeline）
##   4. 點擊後自動觸發 EventBus.hotspot_clicked，並按需啟動對話

# ─── 匯出屬性 ─────────────────────────────────────────────
## Hotspot 的唯一 ID（供旗標系統、存檔系統識別）
@export var hotspot_id: String = ""

## 預設動詞（examine / talk / use / pick_up）
@export_enum("examine", "talk", "use", "pick_up") var verb: String = "examine"

## 滑鼠懸停時顯示的描述文字（左下角 HUD 顯示）
@export var description: String = ""

## 點擊後自動啟動的 Dialogic Timeline 名稱（留空則不自動播對話）
@export var dialogue_timeline: String = ""

## 是否受旗標條件控制（留空 = 永遠啟用）
@export var required_flag: String = ""

## 點擊後是否禁用此 Hotspot（例如：撿起道具後消失）
@export var disable_after_use: bool = false

# ─── 內部狀態 ─────────────────────────────────────────────
var _is_hovered: bool = false

# ─── 生命週期 ─────────────────────────────────────────────
func _ready() -> void:
	# 設定碰撞層：Layer 2 = Hotspot 互動層（與玩家移動層分離）
	collision_layer = 2
	collision_mask = 0
	input_pickable = true

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# 若需要旗標條件，則初始狀態由旗標決定
	if required_flag != "":
		_refresh_enabled_state()
		EventBus.flag_changed.connect(_on_flag_changed)

# ─── 互動處理 ─────────────────────────────────────────────
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not visible or not input_pickable:
		return
	# 左鍵點擊確認
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate()

func _activate() -> void:
	EventBus.hotspot_clicked.emit(hotspot_id, verb)

	# 自動播對話（若有設定 timeline）
	if dialogue_timeline != "":
		GameManager.start_dialogue(dialogue_timeline)

	# 點擊後禁用自身
	if disable_after_use:
		set_enabled(false)
		EventBus.hotspot_state_changed.emit(hotspot_id, false)

# ─── 游標懸停 ─────────────────────────────────────────────
func _on_mouse_entered() -> void:
	_is_hovered = true
	CursorManager.set_cursor(verb)
	EventBus.hotspot_hovered.emit(hotspot_id, description, verb)

func _on_mouse_exited() -> void:
	_is_hovered = false
	CursorManager.reset_cursor()
	EventBus.hotspot_unhovered.emit(hotspot_id)

# ─── 旗標聯動 ────────────────────────────────────────────
func _on_flag_changed(flag_key: String, _value: Variant) -> void:
	if flag_key == required_flag:
		_refresh_enabled_state()

func _refresh_enabled_state() -> void:
	var should_enable := GameManager.has_flag(required_flag)
	set_enabled(should_enable)

# ─── 公開方法 ────────────────────────────────────────────
## 外部可呼叫，強制啟用/禁用此 Hotspot
func set_enabled(value: bool) -> void:
	input_pickable = value
	# 視覺回饋：禁用時略微降低透明度（可自行改為隱藏）
	modulate.a = 1.0 if value else 0.0
