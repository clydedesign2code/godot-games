@tool
extends "res://addons/popochiu/engine/interfaces/i_character.gd"

# classes ----
const PCCharacter1 := preload("res://game/characters/character_1/character_character_1.gd")
# ---- classes

# nodes ----
var Character1: PCCharacter1 : get = get_Character1
# ---- nodes

# functions ----
func get_Character1() -> PCCharacter1: return get_runtime_character("Character1")
# ---- functions

