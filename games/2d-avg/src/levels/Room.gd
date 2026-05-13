class_name Room
extends Node2D

## AVG 基礎房間場景類。
## 所有遊戲中的房間（Room）都應該繼承此場景。
## 它負責管理背景音樂、路徑導航以及場景進入後的動作。

# ─── 匯出屬性 ─────────────────────────────────────────────
## 此房間的唯一 ID
@export var room_id: String = ""

## 背景音樂資源
@export var bgm: AudioStream

## 房間名稱（顯示於儲存檔或 HUD）
@export var room_name: String = "Unknown Room"

## 預設對話（進入場景後自動播放，留空則不播放）
@export var entry_dialogue: String = ""

# ─── 生命週期 ─────────────────────────────────────────────
func _ready() -> void:
	# 註冊場景 ID 至存檔系統（若有需要）
	if room_id == "":
		room_id = name.to_lower()
	
	# 播放背景音樂
	if bgm:
		AudioManager.play_music(bgm)
	
	# 發布進入場景信號
	EventBus.room_entered.emit(room_id)
	
	# 處理進入場景後的邏輯
	_on_enter_room()

func _on_enter_room() -> void:
	# 延遲一點點播放對話，避免過場動畫還沒跑完
	if entry_dialogue != "":
		await get_tree().create_timer(0.5).timeout
		GameManager.start_dialogue(entry_dialogue)

# ─── 公開方法 ────────────────────────────────────────────
## 供外部（如傳送門）呼叫的退出邏輯
func exit_room(target_room_path: String) -> void:
	# 可以在這裡加入淡出特效的觸發
	GameManager.change_room(target_room_path)
