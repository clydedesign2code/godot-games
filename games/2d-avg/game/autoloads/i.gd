@tool
extends "res://addons/popochiu/engine/interfaces/i_inventory.gd"

# classes ----
const PIIClue := preload("res://game/inventory_items/clue/inventory_item_clue.gd")
# ---- classes

# nodes ----
var Clue: PIIClue : get = get_Clue
# ---- nodes

# functions ----
func get_Clue() -> PIIClue: return get_item_instance("Clue")
# ---- functions

