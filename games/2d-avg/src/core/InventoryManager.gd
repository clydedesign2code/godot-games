extends Node

## 道具管理器 (Autoload)。
## 負責追蹤玩家持有的道具、添加/移除道具，以及廣播相關事件。

## 目前持有的道具 ID 列表
var _items: Array[String] = []

## 全域配方庫（可於啟動時加載或手動註冊）
var recipes: Array[ItemCombination] = []

# ─── 生命週期 ─────────────────────────────────────────────
func _ready() -> void:
	# 可以在這裡加入自動掃描 res://src/items/recipes/ 並加載所有的 ItemCombination
	pass

# ─── 道具操作 ────────────────────────────────────────────
## 添加道具
func add_item(item_id: String) -> void:
	if item_id in _items:
		return
	
	_items.append(item_id)
	EventBus.item_added.emit(item_id)
	print("Inventory: Added item ", item_id)

## 移除道具
func remove_item(item_id: String) -> void:
	if item_id in _items:
		_items.erase(item_id)
		EventBus.item_removed.emit(item_id)
		print("Inventory: Removed item ", item_id)

# ─── 合成邏輯 ────────────────────────────────────────────
## 嘗試合成兩個道具（無序：1+2 等於 2+1）
func try_combine(id_1: String, id_2: String) -> bool:
	for recipe in recipes:
		var match_a = (recipe.item_id_a == id_1 and recipe.item_id_b == id_2)
		var match_b = (recipe.item_id_a == id_2 and recipe.item_id_b == id_1)
		
		if match_a or match_b:
			# 檢查旗標條件
			if recipe.required_flag != "" and not GameManager.has_flag(recipe.required_flag):
				continue
				
			# 執行合成
			_execute_combination(id_1, id_2, recipe.result_item)
			return true
			
	print("Inventory: No recipe found for %s + %s" % [id_1, id_2])
	return false

func _execute_combination(id_1: String, id_2: String, result: ItemResource) -> void:
	remove_item(id_1)
	remove_item(id_2)
	add_item(result.item_id)
	
	EventBus.items_combined.emit(id_1, id_2, result.item_id)
	print("Inventory: Success! Combined %s and %s into %s" % [id_1, id_2, result.item_id])

# ─── 查詢 API ────────────────────────────────────────────
## 檢查是否持有道具
func has_item(item_id: String) -> bool:
	return item_id in _items


## 取得所有道具列表
func get_items() -> Array[String]:
	return _items

## 清空道具欄（用於重開遊戲）
func clear() -> void:
	_items.clear()
