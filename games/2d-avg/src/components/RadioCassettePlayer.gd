class_name RadioCassettePlayer
extends Node2D

## 電台隨身聽互動物件。
## 場景結構：
##   RadioCassettePlayer (Node2D)
##   ├── Sprite2D              ← 隨身聽外觀
##   ├── InteractArea (Area2D) ← 靠近偵測範圍
##   │   └── CollisionShape2D
##   ├── HotspotComponent      ← 點擊/互動觸發
##   │   └── CollisionShape2D
##   └── RadioUI (Control)     ← 操作介面（預設隱藏）
##       ├── BtnRadio (Button)
##       └── BtnCassette (Button)

enum Mode { RADIO, CASSETTE }

@onready var interact_area: Area2D = $InteractArea
@onready var radio_ui: Control = $RadioUI
@onready var btn_radio: Button = $RadioUI/BtnRadio
@onready var btn_cassette: Button = $RadioUI/BtnCassette

var current_mode: Mode = Mode.RADIO
var _player_nearby: bool = false

func _ready() -> void:
	radio_ui.hide()

	interact_area.body_entered.connect(_on_player_entered)
	interact_area.body_exited.connect(_on_player_exited)

	btn_radio.pressed.connect(_on_radio_pressed)
	btn_cassette.pressed.connect(_on_cassette_pressed)

	# HotspotComponent 的點擊也觸發開關
	EventBus.hotspot_clicked.connect(_on_hotspot_clicked)

# ─── 玩家靠近偵測 ─────────────────────────────────────────
func _on_player_entered(body: Node2D) -> void:
	if body is Player:
		_player_nearby = true
		body.nearby_hotspot = get_node_or_null("HotspotComponent")

func _on_player_exited(body: Node2D) -> void:
	if body is Player:
		_player_nearby = false
		body.nearby_hotspot = null
		radio_ui.hide()

# ─── 開關 UI ─────────────────────────────────────────────
func _on_hotspot_clicked(hotspot_id: String, _verb: String) -> void:
	if hotspot_id != "radio_cassette_player":
		return
	if radio_ui.visible:
		radio_ui.hide()
	else:
		radio_ui.show()

# ─── 模式切換 ─────────────────────────────────────────────
func _on_radio_pressed() -> void:
	current_mode = Mode.RADIO
	EventBus.radio_mode_changed.emit(Mode.RADIO)
	# 播放電台環境音
	AudioManager.play_bgm("radio_static")

func _on_cassette_pressed() -> void:
	current_mode = Mode.CASSETTE
	EventBus.radio_mode_changed.emit(Mode.CASSETTE)
	radio_ui.hide()
	# 開啟磁帶播放器
	var tape_ui := get_tree().get_first_node_in_group("tape_player_ui")
	if tape_ui and tape_ui.has_method("open"):
		tape_ui.open()
