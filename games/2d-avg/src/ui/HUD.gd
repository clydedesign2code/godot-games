extends CanvasLayer

## AVG 全域 HUD (Heads-Up Display)。
## 負責：
##   1. 顯示游標在 Hotspot 時的描述文字 (Label)
##   2. 顯示道具欄中的持有物品 (Inventory View)
##   3. 遊戲選單按鈕與提示

# ─── 節點引用（假設場景內有名稱對應的子節點） ────────────────────
@onready var description_label: Label = $DescriptionLabel
@onready var inventory_container: Control = $InventoryContainer
@onready var item_grid: GridContainer = $InventoryContainer/ItemGrid
# @onready var item_icon_prefab = preload("res://src/ui/Inventory/ItemIcon.tscn")

# ─── 生命週期 ─────────────────────────────────────────────
func _ready() -> void:
	# 初始化 UI 狀態
	description_label.text = ""
	_refresh_inventory()
	
	# 綁定事件
	EventBus.item_added.connect(func(_id): _refresh_inventory())
	EventBus.item_removed.connect(func(_id): _refresh_inventory())
	EventBus.hotspot_hovered.connect(_on_hotspot_hovered)
	EventBus.hotspot_unhovered.connect(_on_hotspot_unhovered)

# ─── 描述欄處理 ───────────────────────────────────────────
func set_description(text: String) -> void:
	description_label.text = text

func clear_description() -> void:
	description_label.text = ""

# ─── 道具欄處理 ───────────────────────────────────────────
func _refresh_inventory() -> void:
	# 清空舊列表
	for child in item_grid.get_children():
		child.queue_free()
	
	# 根據 InventoryManager 內容填入
	var items := InventoryManager.get_items()
	for item_id in items:
		_add_item_ui(item_id)

func _add_item_ui(item_id: String) -> void:
	# 在實際工程中，應建立一個 ItemIcon 預製件來實例化
	# 本腳本僅提供邏輯架構
	var item_btn := Button.new()
	item_btn.text = item_id
	item_btn.tooltip_text = "Use " + item_id
	item_btn.pressed.connect(_on_item_pressed.bind(item_id))
	item_grid.add_child(item_btn)

func _on_item_pressed(item_id: String) -> void:
	print("HUD: Item clicked - ", item_id)

func _on_hotspot_hovered(_hotspot_id: String, description: String, _verb: String) -> void:
	set_description(description)

func _on_hotspot_unhovered(_hotspot_id: String) -> void:
	clear_description()
