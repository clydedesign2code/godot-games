extends Node

## 存檔管理 (Autoload)。
## 負責將遊戲狀態序列化至多個插槽 (Slots)，並自動保存截圖預覽。

const SAVES_DIR := "user://saves/"

func _ready() -> void:
	_ensure_dir_exists()

func _ensure_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

# ─── 插槽路徑工具 ──────────────────────────────────────────
func _get_save_path(slot_id: int) -> String:
	return SAVES_DIR + "slot_%d.json" % slot_id

func _get_screenshot_path(slot_id: int) -> String:
	return SAVES_DIR + "slot_%d.png" % slot_id

# ─── 執行存檔 ─────────────────────────────────────────────
## 儲存遊戲至指定插槽，並自動截圖。
func save_game(slot_id: int) -> void:
	_ensure_dir_exists()
	
	var save_data := {
		"game_manager": {
			"flags": GameManager._flags if "_flags" in GameManager else {},
			"current_scene_path": get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		},
		"inventory": {
			"items": InventoryManager.get_items()
		},
		"timestamp": Time.get_datetime_dict_from_system(),
		"room_name": get_tree().current_scene.name if get_tree().current_scene else "Unknown"
	}
	
	# 1. 保存 JSON 資料
	var json_path := _get_save_path(slot_id)
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		print("SaveManager: Data saved to ", json_path)
	
	# 2. 保存 截圖預覽 (PNG)
	# 等待一幀確保渲染完成，獲取視口圖像
	await get_tree().process_frame
	var image = get_viewport().get_texture().get_image()
	# 縮小圖片以節省空間（可選）
	image.resize(320, 180, Image.INTERPOLATE_LANCZOS)
	var img_path := _get_screenshot_path(slot_id)
	image.save_png(img_path)
	print("SaveManager: Screenshot saved to ", img_path)

# ─── 執行讀檔 ─────────────────────────────────────────────
## 從指定插槽載入遊戲。
func load_game(slot_id: int) -> void:
	var path := _get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		push_error("SaveManager: Slot %d not found." % slot_id)
		return
	
	var json_string = FileAccess.get_file_as_string(path)
	var save_data = JSON.parse_string(json_string)
	
	if typeof(save_data) != TYPE_DICTIONARY:
		return
		
	# 1. 還原 GameManager 旗標
	if save_data.has("game_manager"):
		var gm_data = save_data["game_manager"]
		if gm_data.has("flags"):
			GameManager._flags = gm_data["flags"]
		if gm_data.has("current_scene_path") and gm_data["current_scene_path"] != "":
			GameManager.change_room(gm_data["current_scene_path"])
	
	# 2. 還原 道具欄
	if save_data.has("inventory"):
		var inv_data = save_data["inventory"]
		if inv_data.has("items"):
			InventoryManager.clear()
			for item_id in inv_data["items"]:
				InventoryManager.add_item(item_id)
				
	print("SaveManager: Slot %d loaded." % slot_id)

# ─── 查詢 API ─────────────────────────────────────────────
## 獲取所有存檔列表（供 UI 顯示）
func get_save_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in range(10): # 假設上限 10 個插槽
		var path := _get_save_path(i)
		if FileAccess.file_exists(path):
			var json_string = FileAccess.get_file_as_string(path)
			var data = JSON.parse_string(json_string)
			if data:
				data["slot_id"] = i
				data["screenshot_path"] = _get_screenshot_path(i)
				list.append(data)
	return list

## 刪除特定插槽
func delete_slot(slot_id: int) -> void:
	var p1 := _get_save_path(slot_id)
	var p2 := _get_screenshot_path(slot_id)
	if FileAccess.file_exists(p1): DirAccess.remove_absolute(p1)
	if FileAccess.file_exists(p2): DirAccess.remove_absolute(p2)
	print("SaveManager: Slot %d deleted." % slot_id)

