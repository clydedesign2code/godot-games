extends Node

## 游標管理器（Autoload）。
## 根據遊戲動詞（examine / talk / use / pick_up）切換游標樣式。
## 需先在 Project Settings > Autoload 中加入此腳本。
##
## 游標圖片放置於：res://assets/ui/cursors/
## 命名規範：cursor_default.png / cursor_examine.png / cursor_talk.png / cursor_use.png

# ─── 游標資源預載 ────────────────────────────────────────
## 若圖片尚未製作，可先保持 null（使用系統預設游標）
const CURSOR_PATHS := {
	"default":  "res://assets/ui/cursors/cursor_default.png",
	"examine":  "res://assets/ui/cursors/cursor_examine.png",
	"talk":     "res://assets/ui/cursors/cursor_talk.png",
	"use":      "res://assets/ui/cursors/cursor_use.png",
	"pick_up":  "res://assets/ui/cursors/cursor_pick_up.png",
}

var _cursors: Dictionary = {}
var _current_verb: String = "default"

# ─── 生命週期 ─────────────────────────────────────────────
func _ready() -> void:
	_preload_cursors()

func _preload_cursors() -> void:
	for verb in CURSOR_PATHS:
		var path: String = CURSOR_PATHS[verb]
		if ResourceLoader.exists(path):
			_cursors[verb] = load(path)
		else:
			_cursors[verb] = null  # 預設系統游標

# ─── 公開 API ────────────────────────────────────────────
## 切換至指定動詞對應的游標
func set_cursor(verb: String) -> void:
	if verb == _current_verb:
		return
	_current_verb = verb
	var texture: Texture2D = _cursors.get(verb, null)
	if texture:
		# hotspot 是游標的「作用點」，通常設在圖片左上角
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2.ZERO)
	else:
		Input.set_custom_mouse_cursor(null)  # 使用系統預設

## 恢復預設游標
func reset_cursor() -> void:
	set_cursor("default")
