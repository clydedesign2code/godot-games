extends VBoxContainer
## Explore a chord on a chosen string set, then recall the same voicing on the board.
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Inversions = preload("res://src/theory/inversion_theory.gd")
const Fingering = preload("res://src/theory/guitar_fingering.gd")
const Board = preload("res://src/fretboard/fretboard.gd")
const StringGroupKey = preload("res://src/ui/string_group_key.gd")
const P = preload("res://src/ui/instrument_theme.gd")

const FINGER_NAMES := ["", "食指", "中指", "無名指", "小指"]
const INVERSION_NAMES := ["原位", "第一轉位", "第二轉位", "第三轉位"]
const SHORT_INVERSIONS := ["原位", "一轉", "二轉", "三轉"]
const COMMON_QUALITIES := [0, 1, 6, 4, 5]
const MORE_QUALITIES := [10, 11, 8, 9, 2, 3, 7, 12, 13]
const NO_POSITION := Vector2i(-1, -1)
enum DisplayMode { NOTE, INTERVAL, BOTH }

var tone_player: Node
var mono_font: Font
var active := false
var string_count := 3
var first_string := 1
var fixed_count := false
var is_practicing := false
var lookup_snapshot := {}
var display_mode := DisplayMode.NOTE
var string_group_label := ""
var root_pc := 0
var chord_index := 0
var inversion := 0
var shapes: Array[Array] = []
var shape_index := 0
var selection: Array[Vector2i] = []
var tones: Array = []
var names: Array[String] = []
var last_position := NO_POSITION
var rejected_selection: Array[Vector2i] = []
var feedback_pattern := ""
var revealed := true
var complete := false
var correct_count := 0
var mistakes := 0
var rng := RandomNumberGenerator.new()

var board: Control
var advance: Timer
var root_buttons: Dictionary = {}
var quality_buttons: Dictionary = {}
var more_quality_button: Button
var extra_qualities: HFlowContainer
var count_buttons: Array[Button] = []
var string_group_buttons: Array[Button] = []
var inversion_buttons: Array[Button] = []
var display_buttons: Array[Button] = []
var settings: VBoxContainer
var selector_grid: GridContainer
var region_controls: BoxContainer
var display_header: BoxContainer
var details_row: BoxContainer
var screen_actions: HFlowContainer
var shape_info: Label
var practice_button: Button
var back_button: Button
var question: Label
var composition: Label
var formula_label: Label
var bass_label: Label
var info_row: HBoxContainer
var instruction: Label
var readout: Label
var feedback: Label
var stats: Label
var listen_button: Button
var reveal_button: Button
var retry_button: Button
var previous_shape_button: Button
var next_shape_button: Button
var shape_counter: Label
var next_button: Button


func _ready() -> void:
	rng.randomize()
	add_theme_constant_override("separation", 10)
	advance = Timer.new()
	advance.one_shot = true
	advance.wait_time = 1.6
	advance.timeout.connect(_next_question)
	add_child(advance)
	_build_controls()
	tone_player.playback_ended.connect(func() -> void:
		board.sounding.clear()
		board.queue_redraw()
	)
	resized.connect(_adapt_layout)
	visible = false


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(parent: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _control_group(row: Container, caption: String, caption_color: Color = P.MUTED) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 5)
	row.add_child(group)
	group.add_child(_label(caption, 13, caption_color))
	return group


func _flow(parent: Container) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	return flow


func _section(parent: Container, caption: String) -> HFlowContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	parent.add_child(column)
	column.add_child(_label(caption, 13, P.MUTED))
	return _flow(column)


func _setting_keys(caption: String, stretch: float) -> HBoxContainer:
	var section := BoxContainer.new()
	section.vertical = true
	section.alignment = BoxContainer.ALIGNMENT_BEGIN
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = stretch
	section.add_theme_constant_override("separation", 5)
	region_controls.add_child(section)
	section.add_child(_label(caption, 13, P.MUTED))
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 5)
	section.add_child(keys)
	return keys


func _choice(parent: Container, caption: String, group: ButtonGroup, action: Callable) -> Button:
	var button := _button(parent, caption, action)
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size.x = 44
	button.add_theme_stylebox_override("hover_pressed", P.key(P.SCREEN, true))
	return button


func _keys(parent: Container, captions: Array, action: Callable) -> Array[Button]:
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for index in captions.size():
		var button := _button(parent, captions[index], action.bind(index))
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_stylebox_override("hover_pressed", P.key(P.SCREEN, true))
		buttons.append(button)
	return buttons


func _build_controls() -> void:
	settings = VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	add_child(settings)
	selector_grid = GridContainer.new()
	selector_grid.columns = 2
	selector_grid.add_theme_constant_override("h_separation", 14)
	settings.add_child(selector_grid)
	var roots := _section(selector_grid, "根音")
	var root_group := ButtonGroup.new()
	for pc in [0, 2, 4, 5, 7, 9, 11, 1, 3, 6, 8, 10]:
		root_buttons[pc] = _choice(roots, Theory.NOTE_NAMES[pc], root_group, _set_root.bind(pc))
	var qualities := _section(selector_grid, "和弦種類")
	extra_qualities = _flow(qualities.get_parent())
	extra_qualities.visible = false
	var quality_group := ButtonGroup.new()
	for id in COMMON_QUALITIES + MORE_QUALITIES:
		var definition := Inversions.definition(id)
		var caption: String = {0: "大三", 1: "小三", 2: "dim", 3: "aug"}.get(id, definition.suffix)
		var key := _choice(qualities if id in COMMON_QUALITIES else extra_qualities, caption, quality_group, _set_quality.bind(id))
		key.tooltip_text = definition.name + "　" + definition.formula
		quality_buttons[id] = key
	more_quality_button = _button(qualities, "更多和弦 ＋", _toggle_more_qualities)
	more_quality_button.toggle_mode = true
	more_quality_button.tooltip_text = "掛留、六和弦與其他變化和弦"

	region_controls = BoxContainer.new()
	settings.add_child(region_controls)
	count_buttons = _keys(_setting_keys("弦數", 0.18), ["3", "4", "5"], _set_count)
	for i in count_buttons.size():
		var button := count_buttons[i]
		button.custom_minimum_size = Vector2(44, 52)
		button.accessibility_name = "%d 條弦" % (i + 3)
		button.tooltip_text = button.accessibility_name
	var group_keys := _setting_keys("弦組", 0.32)
	var area_group := ButtonGroup.new()
	for first in range(1, 5):
		var key := StringGroupKey.new()
		key.toggle_mode = true
		key.button_group = area_group
		key.add_theme_stylebox_override("hover_pressed", P.key(P.SCREEN, true))
		key.configure(first, 3)
		key.pressed.connect(_set_region.bind(first))
		group_keys.add_child(key)
		string_group_buttons.append(key)
	inversion_buttons = _keys(_setting_keys("轉位", 0.5), INVERSION_NAMES, _set_inversion)
	for button in inversion_buttons:
		button.custom_minimum_size = Vector2(56, 52)
	var display := PanelContainer.new()
	display.add_theme_stylebox_override("panel", P.panel(P.SCREEN, Color("080e0b"), 6, 12))
	add_child(display)
	var screen := VBoxContainer.new()
	display.add_child(screen)
	display_header = BoxContainer.new()
	screen.add_child(display_header)
	question = _label("", 24, P.SCREEN_INK)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_header.add_child(question)
	var display_choice := _control_group(display_header, "指板標示", P.SCREEN_MUTED)
	display_buttons = _keys(display_choice, ["音名", "音程", "兩者"], _set_display_mode)
	display_buttons[DisplayMode.INTERVAL].tooltip_text = "以和弦根音為基準。R 是根音，m3 是小三度。"
	display_buttons[DisplayMode.BOTH].tooltip_text = "圓點上行顯示音名，下行顯示相對於和弦根音的音程。"
	for button in display_buttons:
		for state in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, P.key(P.TARGET, true))
			button.add_theme_color_override("font_%s_color" % state, P.INK)
	display_buttons[display_mode].set_pressed_no_signal(true)
	details_row = BoxContainer.new()
	screen.add_child(details_row)
	var chord_info := _flow(details_row)
	chord_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chord_info.add_theme_constant_override("h_separation", 14)
	composition = _label("", 15, P.TARGET)
	chord_info.add_child(composition)
	formula_label = _label("", 15, P.TARGET)
	chord_info.add_child(formula_label)
	bass_label = _label("", 15, P.ROOT)
	chord_info.add_child(bass_label)
	shape_info = _label("", 14, P.SCREEN_MUTED)
	shape_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(shape_info)
	screen_actions = _flow(details_row)
	listen_button = _button(screen_actions, "試聽和弦", _listen)
	listen_button.add_theme_stylebox_override("normal", P.key(P.ROOT))
	listen_button.add_theme_stylebox_override("hover", P.key(P.ROOT.lightened(0.13)))
	listen_button.add_theme_stylebox_override("pressed", P.key(P.ROOT.darkened(0.08), true))
	var play_focus := P.panel(Color.TRANSPARENT, P.INK, 4, 0)
	play_focus.set_border_width_all(2)
	listen_button.add_theme_stylebox_override("focus", play_focus)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		listen_button.add_theme_color_override(state, P.INK)
	reveal_button = _button(screen_actions, "遮住指法", _toggle_reference)
	practice_button = _button(screen_actions, "用這個練習", _enter_practice)
	back_button = _button(screen_actions, "← 返回查閱", return_to_lookup)
	board = Board.new()
	board.read_quiz = true
	board.nearby = false
	board.conceal_answers = true
	if mono_font:
		board.add_theme_font_override("font", mono_font)
	board.note_pressed.connect(_select_position)
	screen.add_child(board)
	board.custom_minimum_size = Vector2(0, 290)
	readout = _label("", 16, P.SCREEN_INK)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(readout)

	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", P.panel(P.CASE, P.LINE, 5, 12))
	add_child(footer)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	footer.add_child(controls)
	info_row = HBoxContainer.new()
	controls.add_child(info_row)
	instruction = _label("", 15, P.INK)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(instruction)
	stats = _label("", 13, P.MUTED)
	info_row.add_child(stats)
	feedback = _label("", 15, P.INFO)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(feedback)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	controls.add_child(actions)
	retry_button = _button(actions, "重練本題", _start_question)
	previous_shape_button = _button(actions, "← 上個指法", _browse_shape.bind(-1))
	shape_counter = _label("", 14, P.MUTED)
	actions.add_child(shape_counter)
	next_shape_button = _button(actions, "下個指法 →", _browse_shape.bind(1))
	next_button = _button(actions, "下一題・換根音 →", _next_question)
	next_button.tooltip_text = "保留弦組、和弦種類與轉位，換一個根音。"
	next_button.add_theme_stylebox_override("normal", P.key(P.ROOT))
	next_button.add_theme_stylebox_override("hover", P.key(P.ROOT.lightened(0.08)))


func _adapt_layout() -> void:
	selector_grid.columns = 1 if size.x < 670 else 2
	var stacked := size.x < 670
	region_controls.vertical = stacked
	region_controls.add_theme_constant_override("separation", 5 if stacked else (10 if size.x < 860 else 14))
	for section: BoxContainer in region_controls.get_children():
		section.vertical = not stacked
		section.add_theme_constant_override("separation", 8 if stacked else 5)
		var label: Label = section.get_child(0)
		label.custom_minimum_size.x = 30 if stacked else 0
	for i in inversion_buttons.size():
		inversion_buttons[i].text = SHORT_INVERSIONS[i] if size.x < 800 else INVERSION_NAMES[i]
		inversion_buttons[i].custom_minimum_size.x = 48 if size.x < 800 else 56
	display_header.vertical = size.x < 630
	question.add_theme_font_size_override("font_size", 20 if size.x < 480 else 24)
	details_row.vertical = size.x < 670
	screen_actions.custom_minimum_size.x = 0 if details_row.vertical else 290


func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if not active:
		advance.stop()
		tone_player.stop()
	visible = value
	if active:
		_start_question(shape_index)


func _set_root(value: int) -> void:
	if root_pc != value:
		root_pc = value
		_start_question()


func _set_quality(id: int) -> void:
	if chord_index != id:
		chord_index = id
		if not fixed_count:
			string_count = Inversions.definition(id).full_tones.size()
		if not Inversions.supports_count(id, string_count):
			string_count = 4
		_start_question()


func _toggle_more_qualities() -> void:
	extra_qualities.visible = more_quality_button.button_pressed
	_update_more_caption()


func _update_more_caption() -> void:
	if extra_qualities.visible:
		more_quality_button.text = "收合和弦 −"
	elif chord_index in MORE_QUALITIES:
		more_quality_button.text = "更多和弦 · %s ＋" % quality_buttons[chord_index].text
	else:
		more_quality_button.text = "更多和弦 ＋"


func _set_count(index: int) -> void:
	fixed_count = true
	if string_count != index + 3:
		string_count = index + 3
		_start_question()


func _set_region(first: int) -> void:
	fixed_count = true
	if first_string != first:
		first_string = first
		_start_question()


func _set_inversion(index: int) -> void:
	if inversion != index:
		inversion = index
		_start_question()


func _enter_practice() -> void:
	if is_practicing or shapes.is_empty():
		return
	lookup_snapshot = {
		"root": root_pc, "chord": chord_index, "count": string_count,
		"first": first_string, "fixed": fixed_count, "inversion": inversion,
		"shape": shape_index, "revealed": revealed, "display": display_mode,
	}
	is_practicing = true
	revealed = false
	_start_question(shape_index)


func return_to_lookup() -> void:
	if not is_practicing:
		return
	is_practicing = false
	root_pc = lookup_snapshot.root
	chord_index = lookup_snapshot.chord
	string_count = lookup_snapshot.count
	first_string = lookup_snapshot.first
	fixed_count = lookup_snapshot.fixed
	inversion = lookup_snapshot.inversion
	revealed = lookup_snapshot.revealed
	display_mode = lookup_snapshot.display
	var saved_shape: int = lookup_snapshot.shape
	lookup_snapshot.clear()
	_start_question(saved_shape)


func _start_question(preferred_shape: int = 0) -> void:
	advance.stop()
	tone_player.stop()
	selection.clear()
	last_position = NO_POSITION
	complete = false
	if is_practicing:
		revealed = false
	first_string = mini(first_string, 7 - string_count)
	var chord := Inversions.definition(chord_index)
	tones = chord.full_tones
	names = Inversions.note_names(chord_index, root_pc)
	var available := Inversions.playable_inversions(chord_index, root_pc, string_count, first_string)
	if inversion not in available:
		inversion = available.front() if not available.is_empty() else 0
	shapes = Inversions.span_voicings(chord_index, root_pc, inversion, string_count, first_string)
	shape_index = clampi(preferred_shape, 0, maxi(0, shapes.size() - 1))
	board.active_rows.assign(Inversions.span_rows(string_count, first_string))
	var numbers := PackedStringArray()
	for i in range(first_string, first_string + string_count):
		numbers.append(str(i))
	string_group_label = "・".join(numbers) + " 弦"
	for pc: int in root_buttons:
		root_buttons[pc].set_pressed_no_signal(pc == root_pc)
	for id: int in quality_buttons:
		quality_buttons[id].set_pressed_no_signal(id == chord_index)
	_update_more_caption()
	for i in count_buttons.size():
		count_buttons[i].disabled = not Inversions.supports_count(chord_index, i + 3)
		count_buttons[i].set_pressed_no_signal(i + 3 == string_count)
	for i in string_group_buttons.size():
		var key = string_group_buttons[i]
		key.visible = i + string_count <= 6
		key.configure(i + 1, string_count)
		key.set_pressed_no_signal(i + 1 == first_string)
	for i in inversion_buttons.size():
		var button := inversion_buttons[i]
		button.visible = i < tones.size()
		if not button.visible:
			continue
		button.disabled = i not in available
		var slash: String = names[0] + chord.suffix + ("/" + names[i] if i else "")
		button.accessibility_name = "%s，%s，最低音 %s" % [INVERSION_NAMES[i], slash, names[i]]
		button.tooltip_text = "%s　最低音 %s" % [slash, names[i]]
		if button.disabled:
			button.tooltip_text += "　此弦組與配置無可用按法"
		button.set_pressed_no_signal(i == inversion)
		if i == inversion:
			question.text = "%s　%s · %d–%d\u00a0弦" % [slash, INVERSION_NAMES[i], first_string, first_string + string_count - 1]
	composition.text = "組成音  %s" % " · ".join(names)
	formula_label.text = "音級  %s" % chord.formula
	bass_label.text = "● 最低音  %s（%s）" % [names[inversion], Inversions.degree_name(chord_index, inversion)]
	instruction.text = "在 %s各選一個位置，以 %s 為最低音。" % [string_group_label, names[inversion]]
	_set_feedback("從任一條亮起的弦開始。再點一次可取消，同弦另一品可換音。", P.INFO)
	if revealed and not shapes.is_empty():
		_show_shape()
	else:
		_refresh()


func _next_question() -> void:
	if not active or not is_practicing:
		return
	var offset := rng.randi_range(1, 11)
	for i in range(11):
		var candidate := (root_pc + 1 + (offset - 1 + i) % 11) % 12
		if inversion in Inversions.playable_inversions(chord_index, candidate, string_count, first_string):
			root_pc = candidate
			_start_question()
			return


func _set_display_mode(index: int) -> void:
	if display_mode == index:
		return
	display_mode = index
	_refresh()


func _set_feedback(value: String, color: Color) -> void:
	rejected_selection.clear()
	feedback_pattern = value
	_refresh_feedback()
	feedback.add_theme_color_override("font_color", color)


func _refresh_feedback() -> void:
	if not rejected_selection.is_empty():
		feedback.text = _selection_error(last_position, rejected_selection)
	elif feedback_pattern.contains("{bass}"):
		feedback.text = feedback_pattern.replace("{bass}", _pitch_caption(root_pc + int(tones[inversion])))
	else:
		feedback.text = feedback_pattern


func _shape_for(partial: Array[Vector2i]) -> int:
	for index in shapes.size():
		if partial.all(func(position: Vector2i) -> bool: return shapes[index].has(position)):
			return index
	return -1


func _tone_index(position: Vector2i) -> int:
	return tones.find(posmod(Theory.midi(position) - root_pc, 12))


func _pitch_labels(midi: int) -> PackedStringArray:
	var interval := Inversions.interval_label(chord_index, root_pc, midi)
	if display_mode == DisplayMode.INTERVAL:
		return PackedStringArray([interval])
	var distance := posmod(midi - root_pc, 12)
	var degree := tones.find(distance)
	var note: String
	if degree >= 0:
		note = names[degree]
	else:
		var root := Vector2i(5, posmod(root_pc - Theory.OPEN_MIDI[5], 12))
		note = Theory.spelled_note(root, distance, Theory.INTERVALS[distance].letter_steps)
	return PackedStringArray([note, interval] if display_mode == DisplayMode.BOTH else [note])


func _pitch_caption(midi: int) -> String:
	return " / ".join(_pitch_labels(midi))


func _selection_error(position: Vector2i, proposed: Array[Vector2i]) -> String:
	var degree := _tone_index(position)
	var clicked := _pitch_caption(Theory.midi(position))
	if degree < 0:
		return "%s 不在本題的組成音裡，請再試一品。" % clicked
	if string_count == 3 and tones.size() == 4 and degree == 2:
		return "三弦配置省略五度 %s，請選根音、三度或%s。" % [clicked, Inversions.degree_name(chord_index, 3)]
	var lowest := position
	var frets: Array[int] = []
	for other in proposed:
		if other != position and _tone_index(other) == degree and string_count <= tones.size():
			return "%d 弦已選了 %s。每個組成音各用一次，試試其他和弦音。" % [other.x + 1, clicked]
		if Theory.midi(other) < Theory.midi(lowest):
			lowest = other
		if other.y > 0:
			frets.append(other.y)
	if proposed.size() == string_count and _tone_index(lowest) != inversion:
		return "這組指法的最低音是 %s。%s的最低音要是 %s（%s）。" % [
			_pitch_caption(Theory.midi(lowest)), INVERSION_NAMES[inversion], _pitch_caption(root_pc + int(tones[inversion])), Inversions.degree_name(chord_index, inversion)]
	if not frets.is_empty() and int(frets.max()) - int(frets.min()) > Theory.LOCAL_RADIUS:
		return "目前要按 %d 到 %d 品，超過 4 品的跨度。試試同音的另一個位置。" % [frets.min(), frets.max()]
	return "%s 是和弦音，但這個位置無法與其他弦組成最低音為 %s 的完整指法。" % [clicked, _pitch_caption(root_pc + int(tones[inversion]))]


func _select_position(position: Vector2i) -> void:
	if not active or not Theory.is_position_valid(position):
		return
	if not board.active_rows.has(position.x) and (is_practicing or position.y != 0):
		if is_practicing and not complete and not revealed:
			_set_feedback("本題使用 %s。請點亮起的弦。" % string_group_label, P.INFO)
		return
	last_position = position
	_play([position], true)
	if not is_practicing or complete or revealed:
		_refresh()
		return
	if selection.has(position):
		selection.erase(position)
		_set_feedback("已移除 %d 弦的音，可以重新選品。" % (position.x + 1), P.INFO)
	else:
		var proposed: Array[Vector2i] = []
		for selected in selection:
			if selected.x != position.x:
				proposed.append(selected)
		proposed.append(position)
		var match_index := _shape_for(proposed)
		if match_index < 0:
			mistakes += 1
			rejected_selection.assign(proposed)
			feedback.add_theme_color_override("font_color", P.ERROR)
		else:
			selection.assign(proposed)
			selection.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x)
			if selection.size() == string_count:
				shape_index = match_index
				complete = true
				correct_count += 1
				_set_feedback("答對了！最低音是 {bass}（%s），即將進入下一題。" % Inversions.degree_name(chord_index, inversion), P.SUCCESS)
				advance.start()
			else:
				_set_feedback("已選 %d / %d 音，請繼續補齊其他弦。" % [selection.size(), string_count], P.INFO)
	_refresh()


func _play(positions: Array, highlight: bool) -> void:
	var pitches: Array[int] = []
	for position: Vector2i in positions:
		pitches.append(Theory.midi(position))
	board.sounding.clear()
	if tone_player.play_notes(pitches) and highlight:
		board.sounding.assign(positions)
	board.queue_redraw()


func _listen() -> void:
	if not active or shapes.is_empty():
		return
	if complete:
		advance.stop()
		_set_feedback("已保留這題。可以再聽、切換指法或按下一題。", P.SUCCESS)
	if selection.is_empty():
		_play(shapes[shape_index], false)
	else:
		_play(selection, true)


func _toggle_reference() -> void:
	if shapes.is_empty():
		return
	advance.stop()
	if revealed:
		revealed = false
		_start_question(shape_index)
		return
	revealed = true
	if not selection.is_empty():
		shape_index = maxi(0, _shape_for(selection))
	_show_shape()


func _browse_shape(step: int) -> void:
	if not active or not (revealed or complete) or shapes.size() < 2:
		return
	advance.stop()
	shape_index = posmod(shape_index + step, shapes.size())
	_show_shape()


func _show_shape() -> void:
	tone_player.stop()
	selection.assign(shapes[shape_index])
	last_position = NO_POSITION
	_set_feedback("橘色為最低音 {bass}（%s）。可點選各弦試聽，或播放整個指法。" % Inversions.degree_name(chord_index, inversion), P.INFO)
	_refresh()


func _describe_voicing(showing_shape: bool) -> String:
	if string_count == 3 and tones.size() == 4:
		return "三弦配置省略五度 %s，保留根音、三度與%s。" % [names[2], Inversions.degree_name(chord_index, 3)]
	var details := PackedStringArray()
	var extra := string_count - tones.size()
	if extra > 0:
		details.append("%d 條弦 · %d 個和弦音" % [string_count, tones.size()])
		if showing_shape:
			var counts := PackedInt32Array()
			counts.resize(tones.size())
			for position in selection:
				counts[_tone_index(position)] += 1
			var repeated := PackedStringArray()
			for i in counts.size():
				if counts[i] > 1:
					repeated.append("%s（%s）佔 %d 條弦" % [names[i], Inversions.degree_name(chord_index, i), counts[i]])
			details.append("、".join(repeated))
		else:
			details.append("另有 %d 個弦位重複和弦音" % extra)
	if not Inversions.supports_count(chord_index, 3):
		details.append("保留變化五度 %s" % names[2])
	return "　｜　".join(details)


func _refresh() -> void:
	board.named_positions.assign(selection)
	board.note_labels.clear()
	board.secondary_labels.clear()
	board.markers.clear()
	if last_position != NO_POSITION and not board.named_positions.has(last_position):
		board.named_positions.append(last_position)
	for position: Vector2i in board.named_positions:
		var labels := _pitch_labels(Theory.midi(position))
		board.note_labels[position] = labels[0]
		if labels.size() > 1:
			board.secondary_labels[position] = labels[1]
	var bass_midi := 128
	for position in selection:
		if _tone_index(position) == inversion:
			bass_midi = mini(bass_midi, Theory.midi(position))
	for position in selection:
		var color := P.ROOT if Theory.midi(position) == bass_midi else P.TARGET
		board.markers[position] = {"text": board.note_labels[position], "color": color}
	board.queue_redraw()
	board.focus_voicing(shapes[shape_index] if not is_practicing and not shapes.is_empty() else [])
	var showing_shape := (complete or revealed) and not shapes.is_empty()
	var fingers: Array[int] = []
	if showing_shape:
		fingers = Fingering.fingers(shapes[shape_index])
	shape_info.text = _describe_voicing(showing_shape)
	shape_info.visible = not shape_info.text.is_empty()
	var entries := PackedStringArray()
	for row: int in board.active_rows:
		var slot := "%d 弦  —" % (row + 1)
		for position in selection:
			if position.x == row:
				var fret := "空弦" if position.y == 0 else "%d 品" % position.y
				slot = "%d 弦  %s %s" % [row + 1, fret, _pitch_caption(Theory.midi(position))]
				if showing_shape and position.y > 0:
					slot += "・" + FINGER_NAMES[fingers[shapes[shape_index].find(position)]]
				break
		entries.append(slot)
	readout.text = "     ｜     ".join(entries)
	_refresh_feedback()
	stats.text = "答對 %d 題　錯點 %d 次" % [correct_count, mistakes]
	listen_button.text = "試聽和弦" if showing_shape or selection.is_empty() else "播放已選音"
	listen_button.disabled = shapes.is_empty()
	reveal_button.text = "遮住指法" if revealed else "顯示指法"
	reveal_button.visible = not complete
	practice_button.visible = not is_practicing
	practice_button.disabled = shapes.is_empty()
	back_button.visible = is_practicing
	settings.visible = not is_practicing
	info_row.visible = is_practicing
	instruction.visible = is_practicing and not showing_shape
	stats.visible = is_practicing
	feedback.visible = is_practicing
	next_button.visible = is_practicing
	retry_button.visible = is_practicing and (complete or revealed)
	previous_shape_button.visible = showing_shape and shapes.size() > 1
	next_shape_button.visible = previous_shape_button.visible
	shape_counter.visible = showing_shape
	shape_counter.text = "指法 %d / %d" % [shape_index + 1, shapes.size()]
	for i in display_buttons.size():
		display_buttons[i].set_pressed_no_signal(i == display_mode)
