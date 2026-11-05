extends PanelContainer
## Subtle mounting marks keep the casing separate from its working controls.


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	for corner in [Vector2(9, 9), Vector2(size.x - 9, 9), Vector2(9, size.y - 9), Vector2(size.x - 9, size.y - 9)]:
		draw_circle(corner, 3, Color("b5baad"))
		draw_line(corner - Vector2(1.4, 0), corner + Vector2(1.4, 0), Color("737a6b"), 0.8, true)
