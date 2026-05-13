extends Node

## AVG 全域管理器。
## 職責：遊戲狀態機、場景切換（含淡入淡出）、全域旗標系統、Dialogic 包裝。

# ─── 狀態機 ──────────────────────────────────────────────
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	DIALOGUE,
	CUTSCENE
}

var current_state: GameState = GameState.MENU : set = _set_current_state

func _set_current_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	EventBus.flag_changed.emit("_game_state", new_state)

# ─── 暫停 ────────────────────────────────────────────────
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false

# ─── 場景切換 ────────────────────────────────────────────
## 切換至目標 Room 場景路徑，例如：
## GameManager.change_room("res://src/levels/chapters/ch01/room_entrance.tscn")
func change_room(scene_path: String) -> void:
	var from_room := get_tree().current_scene.name if get_tree().current_scene else ""
	EventBus.room_exit_started.emit(from_room)
	# 使用 call_deferred 確保不在 physics frame 中途切換
	get_tree().call_deferred("change_scene_to_file", scene_path)

# ─── 全域旗標系統 ─────────────────────────────────────────
## 用來記錄遊戲進度旗標，例如：是否撿過鑰匙、門是否已打開等。
## 旗標會被 SaveManager 自動序列化。
var _flags: Dictionary = {}

func set_flag(key: String, value: Variant) -> void:
	_flags[key] = value
	EventBus.flag_changed.emit(key, value)

func get_flag(key: String, default: Variant = false) -> Variant:
	return _flags.get(key, default)

func has_flag(key: String) -> bool:
	return _flags.has(key) and _flags[key] != false

# ─── Dialogic 包裝 ────────────────────────────────────────
## 統一入口：播放對話，同時切換狀態並廣播事件。
## timeline_name 對應 Dialogic 中的 Timeline 名稱字串。
func start_dialogue(timeline_name: String) -> void:
	if current_state == GameState.DIALOGUE:
		push_warning("GameManager: 已有對話進行中，忽略 start_dialogue(%s)" % timeline_name)
		return
	current_state = GameState.DIALOGUE
	EventBus.dialogue_started.emit(timeline_name)
	var timeline = Dialogic.start(timeline_name)
	# 對話結束後自動回到 PLAYING
	if timeline:
		timeline.timeline_ended.connect(_on_dialogue_ended.bind(timeline_name), CONNECT_ONE_SHOT)

func _on_dialogue_ended(timeline_name: String) -> void:
	current_state = GameState.PLAYING
	EventBus.dialogue_ended.emit(timeline_name)
