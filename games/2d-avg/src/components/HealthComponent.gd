class_name HealthComponent
extends Node

signal health_changed(current: int, max_health: int)
signal died()

@export var max_health: int = 3
var current_health: int

func _ready() -> void:
	current_health = max_health

func damage(amount: int) -> void:
	if current_health <= 0:
		return
		
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
		
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
