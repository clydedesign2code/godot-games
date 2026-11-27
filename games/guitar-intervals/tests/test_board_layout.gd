extends SceneTree
## Board geometry and real viewport input in focused, full and stacked layouts.
const Board = preload("res://src/fretboard/fretboard.gd")
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Model = preload("res://src/theory/inversion_theory.gd")
const ThemeColors = preload("res://src/ui/instrument_theme.gd")
const NONE := Vector2i(-1, -1)

var checks := 0
var failures := 0
var board: Control
var pressed: Array[Vector2i] = []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1050, 820)
	create_timer(30).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)


func tap(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)


func click(control: Control, local := Vector2.INF) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
		ancestor = ancestor.get_parent()
	var point := control.get_global_rect().get_center() if local == Vector2.INF else control.global_position + local
	tap(point)
	await settle()


func check_entry() -> void:
	var app: Control = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	await settle()
	var page: Control = app.inversion_practice
	board = page.board
	check(page.visible and board.last_focused_fret > 0, "Main scene opens a focused voicing")
	var original: Array = page.selection.duplicate()
	for pos: Vector2i in original:
		var center: Vector2 = board.cell_center(pos)
		check(Rect2(Vector2.ZERO, board.size).has_point(center), "Each reference note appears inside the focused board")
		await click(board, center)
		check(app.tone_player.current_notes == [Theory.midi(pos)], "Tapping the drawn fret plays that string and fret")
	await click(page.practice_button)
	check(board.last_focused_fret == 0 and board.markers.is_empty(), "Entering recall restores full neck and clears the displayed answer")
	await click(page.back_button)
	check(board.last_focused_fret > 0 and page.selection == original, "Returning to lookup restores the voicing")
	app.queue_free()
	await settle()


func check_hit(local: Vector2, expected: Vector2i) -> void:
	pressed.clear()
	tap(board.global_position + local)
	if expected == NONE:
		check(pressed.is_empty(), "Outside the playable area gives no note")
	else:
		check(pressed == [expected], "Visible cell must emit %s, got %s" % [expected, pressed])


func set_width(width: float) -> void:
	board.size = Vector2(width, board.custom_minimum_size.y)
	await settle()
	# Outside a Container, release the previous height after the minimum shrinks.
	board.size.y = board.custom_minimum_size.y
	await settle()


func check_full(width: float, expected_banks: int) -> void:
	await set_width(width)
	check(board._bank_count() == expected_banks, "Full neck wraps to fit labelled frets")
	var open: Vector2 = board.cell_center(Vector2i(0, 0))
	var first: Vector2 = board.cell_center(Vector2i(0, 1))
	check(open.x < first.x and is_equal_approx(open.y, first.y), "Open strings sit to the left of fret 1")
	check(board._column_width() >= board.MIN_FRET_WIDTH, "Each numbered fret has room for its heading")
	for string in range(6):
		for fret in range(16):
			var pos := Vector2i(string, fret)
			var center: Vector2 = board.cell_center(pos)
			check(Rect2(Vector2.ZERO, board.size).has_point(center), "Visible fret inside bounds")
			check_hit(center, pos)
	check_hit(Vector2(board.STRING_LABEL_WIDTH - 0.2, open.y), Vector2i(0, 0))
	check_hit(Vector2(board.STRING_LABEL_WIDTH + 0.2, open.y), Vector2i(0, 1))
	check_hit(Vector2(-1, open.y), NONE)
	if expected_banks > 1:
		var next_bank: Vector2 = board.cell_center(Vector2i(0, board._column_count() + 1))
		check(is_equal_approx(next_bank.x, first.x) and next_bank.y > first.y, "Numbering continues at the start of the next row")
		check_hit(Vector2(open.x, next_bank.y), NONE)
	var last: Vector2 = board.cell_center(Vector2i(5, 15))
	check_hit(last + Vector2(board._column_width() * 0.5 + 0.2, 0), NONE)


func check_focused() -> void:
	var grip := [Vector2i(2, 12), Vector2i(1, 13), Vector2i(0, 0)]
	check(grip in Model.span_voicings(0, 0, 1, 3, 1), "Test uses a real C/E with an open high E")
	board.focus_voicing(grip)
	await set_width(320)
	check(board.last_focused_fret == 13, "High shape includes every fret up to its highest note")
	for pos: Vector2i in grip:
		check_hit(board.cell_center(pos), pos)
	for fret in range(1, 14):
		check_hit(board.cell_center(Vector2i(2, fret)), Vector2i(2, fret))
	check(board.cell_center(Vector2i(2, 14)).x < 0, "A fret past the lookup range has no drawn cell")
	move(board.global_position + board.cell_center(grip[0]))
	check(board.hovered == grip[0] and board.tooltip_text.contains("12 品"), "Hover reads the focused cell")
	board.focus_voicing([Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 0)])
	check(board.last_focused_fret == 5 and board.hovered == NONE and board.tooltip_text.is_empty(), "Changing fret window clears stale hover and tooltip")
	check_hit(board.cell_center(Vector2i(1, 1)), Vector2i(1, 1))
	move(board.global_position + board.cell_center(Vector2i(1, 1)))
	board.focus_voicing([])
	check(board.last_focused_fret == 0 and board.hovered == NONE and board.tooltip_text.is_empty(), "Clearing focus restores the full neck without stale metadata")


func check_rendered_banks() -> void:
	if DisplayServer.get_name() == "headless":
		return
	board.markers.clear()
	for pos: Vector2i in [Vector2i(1, 1), Vector2i(1, 9)]:
		board.markers[pos] = {"color": ThemeColors.ROOT, "text": ""}
	board.queue_redraw()
	await settle()
	RenderingServer.force_draw(false)
	var pixels := root.get_texture().get_image()
	var scale := Vector2(pixels.get_size()) / root.get_visible_rect().size
	for fret in [1, 9]:
		var center: Vector2 = board.global_position + board.cell_center(Vector2i(1, fret))
		var p := Vector2i((center + Vector2(8, 0)) * scale)
		var color := pixels.get_pixelv(p)
		check(color.r > color.g * 1.45 and color.g > color.b, "Native render paints the orange marker in bank for fret %d" % fret)
		var line_pos: Vector2 = board.global_position + board.cell_center(Vector2i(5, fret))
		var line := pixels.get_pixelv(Vector2i(line_pos * scale))
		var between := pixels.get_pixelv(Vector2i((line_pos + Vector2(0, 6)) * scale))
		check(line.g > between.g + 0.06, "Native render paints the corresponding string in both banks")


func _run() -> void:
	await check_entry()
	board = Board.new()
	board.add_theme_font_override("font", preload("res://assets/fonts/NotoSansTC.ttf"))
	board.nearby = false
	board.read_quiz = true
	board.position = Vector2(12, 12)
	root.add_child(board)
	board.note_pressed.connect(func(pos: Vector2i) -> void: pressed.append(pos))
	await settle()
	await check_full(900, 1)
	move(board.global_position + board.cell_center(Vector2i(0, 15)))
	await check_full(649, 2)
	check(board.hovered == NONE and board.tooltip_text.is_empty(), "Changing banks clears the previous full-neck hover")
	await check_focused()
	await check_full(320, 3)
	await check_rendered_banks()
	print("Board layout (%s): %d checks, %d failures" % [DisplayServer.get_name(), checks, failures])
	quit(1 if failures else 0)
