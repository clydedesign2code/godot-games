@tool
extends "res://addons/popochiu/engine/interfaces/i_room.gd"

# classes ----
const PRRoom1 := preload("res://game/rooms/room_1/room_room_1.gd")
# ---- classes

# nodes ----
var Room1: PRRoom1 : get = get_Room1
# ---- nodes

# functions ----
func get_Room1() -> PRRoom1: return get_runtime_room("Room1")
# ---- functions

