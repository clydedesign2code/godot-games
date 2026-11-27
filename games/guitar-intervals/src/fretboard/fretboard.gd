extends Control
## Fretboard rendering and hit testing only; the trainer owns question state.

signal note_pressed(position: Vector2i)
signal root_requested(position: Vector2i)

const Theory = preload("res://src/theory/fretboard_theory.gd")
const P = preload("res://src/ui/instrument_theme.gd")
const INK := P.SCREEN_INK
const MUTED := P.SCREEN_MUTED
const MINT := P.ROOT
const GOLD := P.TARGET
const BLUE := P.FIFTH
const RED := P.ERROR

var root := Vector2i(4, 3)
var nearby: bool = true
var show_notes: bool = false
var selecting_root: bool = false
var conceal_answers: bool = false
var markers: Dictionary = {}
var hovered := Vector2i(-1, -1)
var sounding: Array[Vector2i] = []
var named_positions: Array[Vector2i] = [] # Keep labels after the sound ends.
var note_labels: Dictionary = {} # Primary label for each selected or revealed position.
var secondary_labels: Dictionary = {} # Optional second line inside the same circle.
var active_rows: Array[int] = [] # Empty enables the whole fretboard.
var listening_target := Vector2i(-1, -1)
var read_quiz: bool = false
var quiz_target := Vector2i(-1, -1)
const STRING_LABEL_WIDTH := 48.0
const RIGHT_MARGIN := 8.0
const MIN_FRET_WIDTH := 50.0
var last_focused_fret := 0 # Zero shows the complete neck.
var single_bank_height := 300.0


func _ready() -> void:
	single_bank_height = maxf(single_bank_height, custom_minimum_size.y)
	custom_minimum_size.x = 250
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(func() -> void:
		hovered = Vector2i(-1, -1)
		tooltip_text = ""
		queue_redraw()
	)
	resized.connect(_update_layout)
	_update_layout()


func focus_voicing(positions: Array) -> void:
	var last := 0
	if not positions.is_empty():
		last = 5
		for position: Vector2i in positions:
			last = maxi(last, position.y)
	if last != last_focused_fret:
		last_focused_fret = last
		_update_layout()


func _last_fret() -> int:
	return last_focused_fret if last_focused_fret > 0 else Theory.LAST_FRET


func _bank_count() -> int:
	var capacity := maxi(1, floori((size.x - STRING_LABEL_WIDTH - RIGHT_MARGIN) / MIN_FRET_WIDTH))
	return ceili(float(_last_fret()) / capacity)


func _column_count() -> int:
	return ceili(float(_last_fret()) / _bank_count())


func _update_layout() -> void:
	hovered = Vector2i(-1, -1)
	tooltip_text = ""
	var banks := _bank_count()
	custom_minimum_size.y = 270.0 * banks if banks > 1 else single_bank_height
	queue_redraw()


func cell_center(position: Vector2i) -> Vector2:
	if position.y > _last_fret():
		return Vector2(-100, -100)
	var y := 46.0 + position.x * _row_height()
	if position.y == 0:
		return Vector2(STRING_LABEL_WIDTH * 0.5, y)
	var index := position.y - 1
	var columns := _column_count()
	var bank := floori(float(index) / columns)
	return Vector2(STRING_LABEL_WIDTH + (index % columns + 0.5) * _column_width(), bank * _bank_height() + y)


func _column_width() -> float:
	return (size.x - STRING_LABEL_WIDTH - RIGHT_MARGIN) / _column_count()


func _bank_height() -> float:
	return size.y / _bank_count()


func _row_height() -> float:
	return (_bank_height() - 78.0) / 5.0


func _position_at(point: Vector2) -> Vector2i:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return Vector2i(-1, -1)
	var bank := floori(point.y / _bank_height())
	var fret := 0
	if point.x >= STRING_LABEL_WIDTH:
		var column := floori((point.x - STRING_LABEL_WIDTH) / _column_width())
		fret = bank * _column_count() + column + 1
		if column >= _column_count() or fret > _last_fret():
			return Vector2i(-1, -1)
	elif bank > 0:
		return Vector2i(-1, -1)
	var row := roundi((point.y - bank * _bank_height() - 46.0) / _row_height())
	var position := Vector2i(row, fret)
	if Theory.is_position_valid(position) and absf(cell_center(position).y - point.y) <= _row_height() * 0.5:
		return position
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered = _position_at(event.position)
		tooltip_text = ""
		if Theory.is_position_valid(hovered):
			tooltip_text = "%d 弦 · %d 品" % [hovered.x + 1, hovered.y]
			if not active_rows.is_empty() and not active_rows.has(hovered.x):
				tooltip_text += " · 此弦組範圍外"
			elif not active_rows.is_empty() and not conceal_answers:
				tooltip_text += " · " + str(note_labels.get(hovered, Theory.pitch_class_name(hovered)))
				if secondary_labels.has(hovered):
					tooltip_text += " · " + str(secondary_labels[hovered])
			elif not conceal_answers:
				tooltip_text += " · %s\n%s" % [Theory.pitch_class_name(hovered), Theory.movement(root, hovered)]
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var position: Vector2i = _position_at(event.position)
		if Theory.is_position_valid(position):
			if event.double_click and not read_quiz:
				root_requested.emit(position)
			else:
				note_pressed.emit(position)
			accept_event()


func _text(at: Vector2, value: String, color: Color, font_size: int = 15, centered: bool = false) -> void:
	var font: Font = get_theme_font("font")
	var offset: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0 if centered else 0.0
	draw_string(font, at - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	var columns := _column_count()
	for bank in range(_bank_count()):
		var first := bank * columns + 1
		_draw_bank(first, mini(first + columns - 1, _last_fret()))
	_draw_notes()


func _draw_bank(first: int, last: int) -> void:
	var cw: float = _column_width()
	var top: float = cell_center(Vector2i(0, first)).y
	var bottom: float = cell_center(Vector2i(5, first)).y
	var right := STRING_LABEL_WIDTH + cw * (last - first + 1)
	for fret in range(first, last + 1):
		var x: float = cell_center(Vector2i(0, fret)).x
		var active: bool = not nearby or absi(fret - root.y) <= Theory.LOCAL_RADIUS
		if active:
			draw_rect(Rect2(x - cw * 0.5, top - 18, cw, bottom - top + 36), Color("253027"))
		_text(Vector2(x, top - 26), "第 %d 品" % fret, INK if active else MUTED, 13, true)
		draw_line(Vector2(x + cw * 0.5, top - 18), Vector2(x + cw * 0.5, bottom + 18), P.SCREEN_GRID, 1.0, true)
		if fret in [3, 5, 7, 9, 12, 15]:
			draw_circle(Vector2(x, bottom + 25), 2.5, MUTED)
			if fret == 12:
				draw_circle(Vector2(x + 9, bottom + 25), 2.5, MUTED)
	for string_index in range(6):
		var y: float = cell_center(Vector2i(string_index, first)).y
		var active_string := active_rows.is_empty() or active_rows.has(string_index)
		_text(Vector2(STRING_LABEL_WIDTH * 0.5, y + 5), "%d  %s" % [string_index + 1, Theory.STRING_NAMES[string_index]], INK if active_string else MUTED, 14, true)
		draw_line(Vector2(STRING_LABEL_WIDTH, y), Vector2(right, y), Color("637366") if active_string else P.SCREEN_GRID, 1.0 + string_index * 0.22, true)
	if first == 1:
		_text(Vector2(STRING_LABEL_WIDTH * 0.5, top - 26), "空弦", MUTED, 12, true)
		draw_line(Vector2(STRING_LABEL_WIDTH, top - 18), Vector2(STRING_LABEL_WIDTH, bottom + 18), INK, 3.0, true)


func _draw_notes() -> void:
	for string_index in range(6):
		var active_string := active_rows.is_empty() or active_rows.has(string_index)
		if not active_string:
			continue
		for fret in range(_last_fret() + 1):
			var position := Vector2i(string_index, fret)
			var center: Vector2 = cell_center(position)
			if fret > 0 and show_notes and not conceal_answers and Theory.in_scope(root, position, nearby):
				if selecting_root:
					draw_circle(center, 14, Color("344538"))
				_text(center + Vector2(0, 5), Theory.pitch_class_name(position), INK if selecting_root else MUTED, 14 if selecting_root else 12, true)
			if position == hovered:
				draw_circle(center, 21, Color(1, 1, 1, 0.10))
			if markers.has(position):
				var marker: Dictionary = markers[position]
				draw_circle(center, 16, marker.color)
				if not named_positions.has(position):
					_text(center + Vector2(0, 5), marker.text, P.SCREEN, 14, true)
	if read_quiz:
		if Theory.is_position_valid(quiz_target) and not markers.has(quiz_target):
			var target_center := cell_center(quiz_target)
			draw_circle(target_center, 21, Color(MINT, 0.18))
			draw_circle(target_center, 16, MINT)
	else:
		var root_center: Vector2 = cell_center(root)
		draw_circle(root_center, 21, Color(MINT, 0.18))
		draw_circle(root_center, 16, MINT)
		if not named_positions.has(root):
			_text(root_center + Vector2(0, 5), "R", P.SCREEN, 15, true)
	for position in named_positions:
		var center := cell_center(position)
		var fill: Color = P.SCREEN_GRID
		var colored: bool = false
		if markers.has(position):
			fill = markers[position].color
			colored = true
		elif position == (quiz_target if read_quiz else root):
			fill = MINT
			colored = true
		draw_circle(center, 18, fill)
		var label: String = note_labels.get(position, Theory.pitch_class_name(position))
		var ink := P.SCREEN if colored else INK
		var secondary: String = secondary_labels.get(position, "")
		if not secondary.is_empty():
			_text(center + Vector2(0, -1), label, ink, 13 if label.length() <= 2 else 12, true)
			_text(center + Vector2(0, 12), secondary, ink, 12 if secondary.length() < 4 else 11, true)
		else:
			_text(center + Vector2(0, 4.5), label, ink, 12 if label.length() > 2 else 14, true)
	if Theory.is_position_valid(listening_target):
		draw_arc(cell_center(listening_target), 20, 0, TAU, 48, GOLD, 1.5, true)
	for position in sounding:
		draw_arc(cell_center(position), 23, 0, TAU, 48, INK, 2.0, true)
