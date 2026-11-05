extends Button
## A real Button with printed legends, a glyph and a selection LED.

const P = preload("res://src/ui/instrument_theme.gd")
var symbol: String = ""
var caption: String = ""
var index_text: String = ""
var glyph_font: Font


func _ready() -> void:
	# Keep the native caption for keyboard/accessibility semantics.
	text = caption
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	toggled.connect(func(_pressed: bool) -> void: queue_redraw())


func _draw() -> void:
	var face: Color = P.SCREEN_INK if button_pressed else P.INK
	var secondary: Color = P.SCREEN_MUTED if button_pressed else P.MUTED
	var typeface: Font = glyph_font if glyph_font != null else get_theme_default_font()
	draw_string(typeface, Vector2(12, 23), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, face)
	draw_string(get_theme_default_font(), Vector2(12, size.y - 9), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, face)
	var index_position := Vector2(size.x - 40, size.y - 9) if symbol.length() > 3 else Vector2(size.x - 32, 20)
	draw_string(typeface, index_position, index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, secondary)
	if button_pressed:
		draw_circle(Vector2(size.x - 15, size.y - 13), 3, P.ROOT)
