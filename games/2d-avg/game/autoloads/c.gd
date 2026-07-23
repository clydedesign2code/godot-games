@tool
extends "res://addons/popochiu/engine/interfaces/i_character.gd"

# classes ----
const PCCharacter1 := preload("res://game/characters/character_1/character_character_1.gd")
const PCNpc1 := preload("res://game/characters/npc_1/character_npc_1.gd")
# ---- classes

# nodes ----
var Character1: PCCharacter1 : get = get_Character1
var Npc1: PCNpc1 : get = get_Npc1
# ---- nodes

# functions ----
func get_Character1() -> PCCharacter1: return get_runtime_character("Character1")
func get_Npc1() -> PCNpc1: return get_runtime_character("Npc1")
# ---- functions

