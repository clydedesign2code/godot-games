extends Control

## 磁帶播放器 UI。
## 節點結構（需在 .tscn 中對應）：
##   TapePlayerUI (Control)
##   ├── Cassette (Control)
##   │   ├── ReelLeft  (Node2D)
##   │   └── ReelRight (Node2D)
##   ├── EntryList (ItemList)
##   ├── TextDisplay (RichTextLabel)
##   └── Controls (HBoxContainer)
##       ├── PlayBtn  (Button)
##       └── CloseBtn (Button)

@onready var reel_left: Node2D = $Cassette/ReelLeft
@onready var reel_right: Node2D = $Cassette/ReelRight
@onready var entry_list: ItemList = $EntryList
@onready var text_display: RichTextLabel = $TextDisplay
@onready var play_btn: Button = $Controls/PlayBtn
@onready var close_btn: Button = $Controls/CloseBtn

const REEL_SPEED := 1.8
const NOISE_CHARS := ["▒", "░", "▓", "·", "~", "■"]

var _current_entry: Dictionary = {}
var _is_playing: bool = false
var _reel_rotation: float = 0.0

# ─── 生命週期 ──────────────────────────────────────────────
func _ready() -> void:
	hide()
	_populate_list()
	entry_list.item_selected.connect(_on_entry_selected)
	play_btn.pressed.connect(_on_play_pressed)
	close_btn.pressed.connect(close)
	EventBus.tape_entry_added.connect(func(_id): _populate_list())

func _process(delta: float) -> void:
	if not _is_playing:
		return
	_reel_rotation += REEL_SPEED * delta
	reel_left.rotation = -_reel_rotation
	reel_right.rotation = _reel_rotation

# ─── 列表 ──────────────────────────────────────────────────
func _populate_list() -> void:
	entry_list.clear()
	for entry in TapeManager.get_all_entries():
		var label := entry.label
		if entry.is_anomaly and entry.is_played:
			label += "  [?]"
		entry_list.add_item(label)

func _on_entry_selected(index: int) -> void:
	_current_entry = TapeManager.get_all_entries()[index]
	_stop_playback()

# ─── 播放 ──────────────────────────────────────────────────
func _on_play_pressed() -> void:
	if _current_entry.is_empty():
		return
	_is_playing = true
	TapeManager.mark_played(_current_entry.id)
	_render_text(_current_entry)
	_populate_list()

func _stop_playback() -> void:
	_is_playing = false

# ─── 文字渲染（失真效果） ──────────────────────────────────
func _render_text(entry: Dictionary) -> void:
	var text: String = _apply_degradation(entry.text, entry.degradation)
	text_display.clear()

	if entry.is_anomaly:
		# 異常錄音：淡紅色提示，讓玩家感覺不對勁
		text_display.push_color(Color(1.0, 0.82, 0.82))
		text_display.add_text(text)
		text_display.pop()
	else:
		text_display.add_text(text)

func _apply_degradation(text: String, amount: float) -> String:
	if amount <= 0.0:
		return text
	var result := ""
	for ch in text:
		if randf() < amount * 0.25:
			result += NOISE_CHARS[randi() % NOISE_CHARS.size()]
		else:
			result += ch
	return result

# ─── 開關 ──────────────────────────────────────────────────
func open() -> void:
	_populate_list()
	show()
	EventBus.tape_player_opened.emit()

func close() -> void:
	_stop_playback()
	hide()
	EventBus.tape_player_closed.emit()
