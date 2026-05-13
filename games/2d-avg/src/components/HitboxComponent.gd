class_name HitboxComponent
extends Area2D

## Deals damage to Hurtboxes it collides with.

@export var damage: int = 1

func _init() -> void:
	# Keep hitboxes on a specific collision layer to decouple from physics geometry.
	# Typically Layer 0 for Hitboxes, Layer 1 for Hurtboxes (custom bits).
	pass
