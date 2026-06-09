extends Node

## 磁帶日誌管理器 (Autoload)。
## 儲存、管理玩家的調查錄音。每筆錄音有降質程度與異常旗標。
## 異常錄音：孩子不記得自己錄過的內容，是靈魂輪替謎題的線索。

# ─── 資料結構 ─────────────────────────────────────────────
## 每筆 entry 格式：
## {
##   id: String,          唯一識別碼
##   chapter: int,        所屬章節
##   label: String,       磁帶標籤（顯示於列表）
##   text: String,        錄音內容
##   degradation: float,  0.0 = 清晰，1.0 = 嚴重失真
##   is_anomaly: bool,    true = 孩子不記得錄過的內容
##   is_played: bool,     是否已播放過
## }

var entries: Array[Dictionary] = []

# ─── 新增錄音 ─────────────────────────────────────────────
func add_entry(
	id: String,
	chapter: int,
	label: String,
	text: String,
	degradation: float = 0.0,
	is_anomaly: bool = false
) -> void:
	if get_entry(id) != {}:
		push_warning("TapeManager: entry '%s' already exists, skipping." % id)
		return
	entries.append({
		"id": id,
		"chapter": chapter,
		"label": label,
		"text": text,
		"degradation": clampf(degradation, 0.0, 1.0),
		"is_anomaly": is_anomaly,
		"is_played": false,
	})
	EventBus.tape_entry_added.emit(id)

# ─── 查詢 ──────────────────────────────────────────────────
func get_entry(id: String) -> Dictionary:
	for e in entries:
		if e.id == id:
			return e
	return {}

func get_entries_by_chapter(chapter: int) -> Array:
	return entries.filter(func(e): return e.chapter == chapter)

func get_all_entries() -> Array[Dictionary]:
	return entries

# ─── 播放 ──────────────────────────────────────────────────
func mark_played(id: String) -> void:
	for e in entries:
		if e.id == id and not e.is_played:
			e.is_played = true
			EventBus.tape_entry_played.emit(id, e.is_anomaly)
			return

# ─── 存讀檔介接 ────────────────────────────────────────────
func serialize() -> Array:
	return entries.duplicate(true)

func deserialize(data: Array) -> void:
	entries.clear()
	for e in data:
		entries.append(e)
