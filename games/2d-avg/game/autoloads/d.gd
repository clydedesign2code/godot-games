@tool
extends "res://addons/popochiu/engine/interfaces/i_dialog.gd"

# classes ----
const PDTestDialog := preload("res://game/dialogs/test_dialog/dialog_test_dialog.gd")
# ---- classes

# nodes ----
var TestDialog: PDTestDialog : get = get_TestDialog
# ---- nodes

# functions ----
func get_TestDialog() -> PDTestDialog: return get_instance("TestDialog")
# ---- functions

