extends Control
## Fretboard rendering and hit testing only; the trainer owns question state.

signal note_pressed(position: Vector2i)

const Theory = preload("res://src/theory/fretboard_theory.gd")
const INK := Color("dce5ee")
const MUTED := Color("74899b")
const MINT := Color("7ae3c3")
const GOLD := Color("f3c77b")
const BLUE := Color("8dbbff")
const RED := Color("ff858d")

var root := Vector2i(4, 3)
var nearby: bool = true
var show_notes: bool = false
var conceal_answers: bool = false
var markers: Dictionary = {}
var hovered := Vector2i(-1, -1)
var sounding: Array[Vector2i] = []
var listening_target := Vector2i(-1, -1)


func _ready() -> void:
	custom_minimum_size = Vector2(900, 280)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(func() -> void:
		hovered = Vector2i(-1, -1)
		queue_redraw()
	)
	resized.connect(queue_redraw)


func cell_center(position: Vector2i) -> Vector2:
	return Vector2(76.0 + position.y * _column_width(), 72.0 + position.x * _row_height())


func _column_width() -> float:
	return (size.x - 108.0) / float(Theory.LAST_FRET + 1)


func _row_height() -> float:
	return (size.y - 118.0) / 5.0


func _position_at(point: Vector2) -> Vector2i:
	var position := Vector2i(roundi((point.y - 72.0) / _row_height()), roundi((point.x - 76.0) / _column_width()))
	if Theory.is_position_valid(position) and cell_center(position).distance_to(point) <= minf(23.0, _column_width() * 0.48):
		return position
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = _position_at(event.position)
		tooltip_text = ""
		if Theory.is_position_valid(hovered):
			tooltip_text = "%d 弦 · %d 品" % [hovered.x + 1, hovered.y]
			if not conceal_answers:
				tooltip_text += " · %s\n%s" % [Theory.note_name(hovered), Theory.movement(root, hovered)]
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var position: Vector2i = _position_at(event.position)
		if Theory.is_position_valid(position):
			note_pressed.emit(position)
			accept_event()


func _text(at: Vector2, value: String, color: Color, font_size: int = 15, centered: bool = false) -> void:
	var font: Font = get_theme_default_font()
	var offset: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0 if centered else 0.0
	draw_string(font, at - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	var cw: float = _column_width()
	var bottom: float = cell_center(Vector2i(5, 0)).y
	var left: float = 76.0 - cw * 0.5
	var right: float = cell_center(Vector2i(0, Theory.LAST_FRET)).x + cw * 0.5
	for fret in range(Theory.LAST_FRET + 1):
		var x: float = cell_center(Vector2i(0, fret)).x
		var active: bool = not nearby or absi(fret - root.y) <= Theory.LOCAL_RADIUS
		if active:
			draw_rect(Rect2(x - cw * 0.5, 48, cw, bottom - 24), Color("172834"))
		_text(Vector2(x, 30), "空弦" if fret == 0 else str(fret), INK if active else MUTED, 13, true)
		if fret > 0:
			draw_line(Vector2(x + cw * 0.5, 48), Vector2(x + cw * 0.5, bottom + 22), Color("334654"), 1.0, true)
		if fret in [3, 5, 7, 9, 12, 15]:
			draw_circle(Vector2(x, bottom + 34), 2.5, MUTED)
			if fret == 12:
				draw_circle(Vector2(x + 9, bottom + 34), 2.5, MUTED)
	var nut_x: float = 76.0 + cw * 0.5
	draw_line(Vector2(nut_x, 48), Vector2(nut_x, bottom + 22), Color("b7c7cc"), 4, true)
	for string_index in range(6):
		var y: float = cell_center(Vector2i(string_index, 0)).y
		_text(Vector2(4, y + 5), "%d  %s" % [string_index + 1, Theory.STRING_NAMES[string_index]], INK, 14)
		draw_line(Vector2(left, y), Vector2(right, y), Color("536470"), 1.0 + string_index * 0.3, true)
		for fret in range(Theory.LAST_FRET + 1):
			var position := Vector2i(string_index, fret)
			var center: Vector2 = cell_center(position)
			if show_notes and not conceal_answers and Theory.in_scope(root, position, nearby):
				_text(center + Vector2(0, 5), Theory.NOTE_NAMES[Theory.midi(position) % 12], MUTED, 12, true)
			if position == hovered:
				draw_circle(center, 21, Color(1, 1, 1, 0.10))
			if markers.has(position):
				var marker: Dictionary = markers[position]
				draw_circle(center, 16, marker.color)
				_text(center + Vector2(0, 5), marker.text, Color("10232c"), 14, true)
	var root_center: Vector2 = cell_center(root)
	draw_circle(root_center, 21, Color(MINT, 0.18))
	draw_circle(root_center, 16, MINT)
	_text(root_center + Vector2(0, 5), "R", Color("10232c"), 15, true)
	if Theory.is_position_valid(listening_target):
		draw_arc(cell_center(listening_target), 20, 0, TAU, 48, GOLD, 1.5, true)
	for position in sounding:
		draw_arc(cell_center(position), 23, 0, TAU, 48, INK, 2.0, true)
