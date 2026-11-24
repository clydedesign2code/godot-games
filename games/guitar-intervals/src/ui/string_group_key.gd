extends Button
## Six lines follow the board: first (thinnest) string at the top.

var first_string := 1
var string_count := 3
var caption := ""


func configure(first: int, count: int) -> void:
	first_string = first
	string_count = count
	var numbers := PackedStringArray()
	for number in range(first, first + count):
		numbers.append(str(number))
	accessibility_name = "第 %s 弦" % "、".join(numbers)
	tooltip_text = accessibility_name
	caption = "·".join(numbers)
	var caption_width := get_theme_font("font").get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	custom_minimum_size = Vector2(maxf(76, ceilf(caption_width) + 12), 65)
	queue_redraw()


func _draw() -> void:
	var ink := get_theme_color("font_pressed_color" if button_pressed else "font_color")
	var faint := Color(ink, 0.22)
	var width := minf(50.0, size.x - 22)
	var left := (size.x - width) * 0.5
	for row in range(6):
		var used := row + 1 >= first_string and row + 1 < first_string + string_count
		var start := Vector2(left, 9 + row * 4)
		draw_line(start, start + Vector2(width, 0), ink if used else faint, 1 + row * 0.15 if used else 1.0, true)
		if used:
			draw_circle(start, 1.8, ink)
	draw_string(get_theme_font("font"), Vector2(0, size.y - 9), caption,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, ink)
