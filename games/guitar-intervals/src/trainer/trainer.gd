extends Control

const Theory = preload("res://src/theory/fretboard_theory.gd")
const Board = preload("res://src/fretboard/fretboard.gd")
const TonePlayer = preload("res://src/audio/tone_player.gd")
const MINT := Color("7ae3c3")
const GOLD := Color("f3c77b")
const BLUE := Color("8dbbff")
const MUTED := Color("96aab9")
const RED := Color("ff858d")

var mode: int = 0
var root_position := Vector2i(4, 3)
var interval_index: int = 4
var chord_index: int = 0
var nearby: bool = true
var picked: Array[Vector2i] = []
var wrong_position := Vector2i(-1, -1)
var revealed: bool = false
var question_complete: bool = false
var help_used: bool = false
var completed_count: int = 0
var assisted_count: int = 0
var mistake_count: int = 0
var feedback: String = ""
var feedback_color: Color = MUTED
var rng := RandomNumberGenerator.new()
var tone_player: Node
var placing_root: bool = false
var audition_target := Vector2i(-1, -1)

var board: Control
var mode_buttons: Array[Button] = []
var interval_select: OptionButton
var chord_select: OptionButton
var string_select: OptionButton
var fret_select: SpinBox
var nearby_check: CheckButton
var notes_check: CheckButton
var root_label: Label
var eyebrow: Label
var instruction_label: Label
var formula_label: Label
var feedback_label: Label
var stats_label: Label
var hint_button: Button
var reveal_button: Button
var next_button: Button
var root_placement_button: Button
var play_root_button: Button
var play_group_button: Button
var mute_button: Button
var volume_slider: HSlider


func _ready() -> void:
	rng.randomize()
	tone_player = TonePlayer.new()
	add_child(tone_player)
	_build_ui()
	tone_player.playback_ended.connect(func() -> void:
		board.sounding.clear()
		board.queue_redraw()
	)
	_reset_question()


func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


func _label(value: String, font_size: int = 16, color: Color = Color("e5edf4")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 43
	button.pressed.connect(action)
	return button


func _row(parent: Node, separation: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)


func _build_ui() -> void:
	var app_theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansTC.ttf")
	font.variation_opentype = {"wght": 450.0}
	app_theme.default_font = font
	app_theme.default_font_size = 16
	for type_name in ["Button", "OptionButton"]:
		app_theme.set_stylebox("normal", type_name, _style(Color("172834"), Color("334753")))
		app_theme.set_stylebox("hover", type_name, _style(Color("243d48"), MINT))
		app_theme.set_stylebox("pressed", type_name, _style(Color("284b4c"), MINT))
		app_theme.set_stylebox("focus", type_name, _style(Color(0, 0, 0, 0), MINT))
		app_theme.set_stylebox("disabled", type_name, _style(Color("111e29"), Color("24323d")))
		app_theme.set_color("font_color", type_name, Color("e5edf4"))
		app_theme.set_color("font_disabled_color", type_name, Color("637584"))
	app_theme.set_stylebox("panel", "PopupMenu", _style(Color("172834"), Color("334753")))
	app_theme.set_stylebox("normal", "LineEdit", _style(Color("172834"), Color("334753")))
	theme = app_theme
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 24)
	scroll.add_child(margins)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margins.add_child(content)
	var header := _row(content)
	var brand := VBoxContainer.new()
	header.add_child(brand)
	brand.add_child(_label("FRET / RELATIONS", 13, MINT))
	brand.add_child(_label("把音程，變成看得見的位置", 26))
	brand.add_child(_label("從一個根音出發，建立整張指板的相對座標。", 15, MUTED))
	_spacer(header)
	var tuning := _label("STANDARD TUNING\n6 → 1 弦   E · A · D · G · B · e", 14, MUTED)
	tuning.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var header_info := VBoxContainer.new()
	header.add_child(header_info)
	header_info.add_child(tuning)
	var sound_controls := _row(header_info, 8)
	sound_controls.alignment = BoxContainer.ALIGNMENT_END
	mute_button = _button("聲音：開", func() -> void:
		tone_player.set_muted(not tone_player.muted)
		mute_button.text = "聲音：靜音" if tone_player.muted else "聲音：開"
	)
	mute_button.custom_minimum_size.y = 30
	mute_button.tooltip_text = "切換所有試聽聲音；靜音會立即停止播放。"
	sound_controls.add_child(mute_button)
	sound_controls.add_child(_label("音量", 13, MUTED))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = tone_player.volume_percent
	volume_slider.custom_minimum_size.x = 100
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.value_changed.connect(func(value: float) -> void: tone_player.set_volume(value))
	volume_slider.tooltip_text = "試聽音量"
	sound_controls.add_child(volume_slider)
	var tabs := _row(content)
	for index in range(3):
		var button := _button(["01   音程查閱", "02   雙音練習", "03   三和弦練習"][index], _set_mode.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		tabs.add_child(button)
		mode_buttons.append(button)
	var toolbar := _row(content)
	toolbar.add_child(_label("根音位置", 14, MUTED))
	string_select = OptionButton.new()
	for index in range(6):
		string_select.add_item("%d 弦 %s" % [index + 1, Theory.STRING_NAMES[index]])
	string_select.item_selected.connect(_on_string_changed)
	toolbar.add_child(string_select)
	fret_select = SpinBox.new()
	fret_select.min_value = 0
	fret_select.max_value = Theory.LAST_FRET
	fret_select.suffix = "品"
	fret_select.custom_minimum_size.x = 100
	fret_select.value_changed.connect(_on_fret_changed)
	toolbar.add_child(fret_select)
	interval_select = OptionButton.new()
	for interval in Theory.INTERVALS:
		interval_select.add_item("%s  %s" % [interval.symbol, interval.name])
	interval_select.item_selected.connect(_on_interval_changed)
	toolbar.add_child(interval_select)
	chord_select = OptionButton.new()
	for chord in Theory.TRIADS:
		chord_select.add_item(chord.name)
	chord_select.item_selected.connect(_on_chord_changed)
	toolbar.add_child(chord_select)
	_spacer(toolbar)
	nearby_check = CheckButton.new()
	nearby_check.text = "根音 ±4 品"
	nearby_check.button_pressed = true
	nearby_check.toggled.connect(func(value: bool) -> void:
		nearby = value
		_reset_question()
	)
	toolbar.add_child(nearby_check)
	notes_check = CheckButton.new()
	notes_check.text = "顯示音名"
	notes_check.toggled.connect(func(_value: bool) -> void: _refresh())
	toolbar.add_child(notes_check)
	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", _style(Color("101e29"), Color("293b48"), 16))
	content.add_child(board_panel)
	var board_content := VBoxContainer.new()
	board_content.add_theme_constant_override("separation", 8)
	board_panel.add_child(board_content)
	var board_header := _row(board_content)
	root_label = _label("", 18, MINT)
	board_header.add_child(root_label)
	root_placement_button = _button("點選：試聽", _toggle_root_placement)
	root_placement_button.toggle_mode = true
	root_placement_button.custom_minimum_size.y = 30
	root_placement_button.tooltip_text = "切換成設定根音後，點指板指定新根音；設定後會自動回到試聽。"
	board_header.add_child(root_placement_button)
	_spacer(board_header)
	board_header.add_child(_label("● 根音 R", 13, MINT))
	board_header.add_child(_label("● 三度 / 目標音", 13, GOLD))
	board_header.add_child(_label("● 五度", 13, BLUE))
	board = Board.new()
	board.note_pressed.connect(_on_note_pressed)
	board_content.add_child(board)
	board_content.add_child(_label("上方是細弦 1 弦，下方是粗弦 6 弦。每往右一品升高半音；G → B 弦相隔 4 半音，其餘相鄰弦為 5 半音。", 13, MUTED))
	var octave_note := _label("本版練習音級關係：包含不同八度、低於根音的同音級位置。懸停查閱可看實際半音差。", 13, MUTED)
	octave_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(octave_note)
	var task_panel := PanelContainer.new()
	task_panel.add_theme_stylebox_override("panel", _style(Color("14242f"), Color("293b48"), 16))
	content.add_child(task_panel)
	var task_content := VBoxContainer.new()
	task_content.add_theme_constant_override("separation", 9)
	task_panel.add_child(task_content)
	var task_header := _row(task_content)
	eyebrow = _label("", 13, MINT)
	task_header.add_child(eyebrow)
	_spacer(task_header)
	stats_label = _label("", 13, MUTED)
	task_header.add_child(stats_label)
	instruction_label = _label("", 22)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_content.add_child(instruction_label)
	formula_label = _label("", 15, GOLD)
	formula_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_content.add_child(formula_label)
	feedback_label = _label("", 15, MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size.y = 32
	task_content.add_child(feedback_label)
	var actions := _row(task_content)
	hint_button = _button("給我位置提示", _hint)
	actions.add_child(hint_button)
	reveal_button = _button("查看答案", _reveal)
	actions.add_child(reveal_button)
	play_root_button = _button("播放根音", func() -> void: _play_positions([root_position]))
	actions.add_child(play_root_button)
	play_group_button = _button("播放雙音", _play_group)
	actions.add_child(play_group_button)
	_spacer(actions)
	next_button = _button("換一個根音  →", _new_question)
	next_button.custom_minimum_size.x = 180
	actions.add_child(next_button)
	var footer := _label("查閱：點音試聽，切換「點選：設根音」更換根音    /    練習：點音作答並試聽    /    播放雙音、三和弦可一起聽", 13, MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)


func _set_mode(value: int) -> void:
	mode = value
	placing_root = false
	_reset_question()


func _on_string_changed(value: int) -> void:
	root_position.x = value
	_reset_question()


func _on_fret_changed(value: float) -> void:
	root_position.y = int(value)
	_reset_question()


func _on_interval_changed(value: int) -> void:
	interval_index = value
	_reset_question()


func _on_chord_changed(value: int) -> void:
	chord_index = value
	_reset_question()


func _reset_question() -> void:
	tone_player.stop()
	picked.clear()
	audition_target = Vector2i(-1, -1)
	wrong_position = Vector2i(-1, -1)
	revealed = false
	question_complete = false
	help_used = false
	feedback = "點音可單獨試聽；點亮起的目標音可選擇雙音的另一個音。切換「點選：設根音」可更換根音。" if mode == 0 else "先觀察根音，再點選你認為正確的位置；點音也會單獨試聽。"
	feedback_color = MUTED
	if mode == 2 and _voicings().is_empty():
		feedback = "此根音與範圍沒有符合條件的三和弦。請更換根音，或關閉 ±4 品限制。"
	_refresh()


func _voicings() -> Array[Array]:
	return Theory.triad_voicings(root_position, chord_index, nearby)


func _compatible_voicings() -> Array[Array]:
	var result: Array[Array] = []
	for voicing in _voicings():
		var compatible: bool = true
		for position in picked:
			if not voicing.has(position):
				compatible = false
		if compatible:
			result.append(voicing)
	return result


func _valid_answers() -> Array[Vector2i]:
	if mode != 2:
		return Theory.candidates(root_position, interval_index, nearby)
	var result: Array[Vector2i] = []
	for voicing in _compatible_voicings():
		for position: Vector2i in voicing:
			if not result.has(position) and not picked.has(position):
				result.append(position)
	return result


func _on_note_pressed(position: Vector2i) -> void:
	if mode == 0:
		if placing_root:
			root_position = position
			placing_root = false
			_reset_question()
		else:
			if position != root_position and Theory.in_scope(root_position, position, nearby) and Theory.relative_pc(root_position, position) == interval_index:
				audition_target = position
			feedback = "單音 %s · %d 弦 %d 品。%s。" % [Theory.note_name(position), position.x + 1, position.y, Theory.movement(root_position, position)]
			feedback_color = MUTED
			_refresh()
		_play_positions([position])
		return
	_play_positions([position])
	if question_complete or revealed:
		if mode == 1 and revealed and Theory.candidates(root_position, interval_index, nearby).has(position):
			audition_target = position
			_refresh()
		return
	if position == root_position:
		feedback = "綠色 R 是已給定的根音，請在其他位置補上目標音。"
		feedback_color = MUTED
		_refresh()
		return
	if not Theory.in_scope(root_position, position, nearby):
		feedback = "請在亮起的範圍內作答（根音左右各 4 品），或關閉範圍限制重新開始。"
		feedback_color = MUTED
		_refresh()
		return
	if picked.has(position):
		picked.erase(position)
		feedback = "已取消這個音，可以重新選擇位置。"
		feedback_color = MUTED
	elif _valid_answers().has(position):
		picked.append(position)
		wrong_position = Vector2i(-1, -1)
		feedback = "找到了！%s。" % Theory.movement(root_position, position)
		feedback_color = MINT
		if picked.size() == (2 if mode == 2 else 1):
			question_complete = true
			if help_used:
				assisted_count += 1
			else:
				completed_count += 1
			feedback += "  已完成，可點下一題。"
		else:
			feedback += " 再找出另一個和弦音；再次點選可取消。"
	else:
		wrong_position = position
		mistake_count += 1
		feedback_color = RED
		var relative: int = Theory.relative_pc(root_position, position)
		if mode == 2 and Theory.TRIADS[chord_index].tones.has(relative):
			feedback = "音級正確，但無法與目前選擇組成三弦指型：每弦只能一音，按弦跨度最多 4 品。可取消已選音再試。"
		else:
			feedback = "這裡是 %s，與根音相差 %+d 半音，音級關係為 %s。再試一次。" % [Theory.note_name(position), Theory.midi(position) - Theory.midi(root_position), Theory.INTERVALS[relative].name]
	_refresh()


func _toggle_root_placement() -> void:
	placing_root = not placing_root
	feedback = "點選指板上的新根音；設定後會回到試聽模式。" if placing_root else "點音可試聽；亮起的目標音可選作雙音的另一個音。"
	feedback_color = MUTED
	_refresh()


func _default_audition_target() -> Vector2i:
	var answers: Array[Vector2i] = Theory.candidates(root_position, interval_index, nearby)
	var best := Vector2i(-1, -1)
	var best_distance: int = 100000
	var desired_delta: int = 12 if interval_index == 0 else interval_index
	for position in answers:
		var distance: int = absi(Theory.midi(position) - Theory.midi(root_position) - desired_delta) * 100 + absi(position.y - root_position.y) * 6 + absi(position.x - root_position.x)
		if distance < best_distance:
			best = position
			best_distance = distance
	return best


func _group_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = [root_position]
	if mode == 0 or (mode == 1 and revealed):
		if not Theory.is_position_valid(audition_target):
			audition_target = _default_audition_target()
		if Theory.is_position_valid(audition_target):
			positions.append(audition_target)
	else:
		positions.append_array(picked)
	return positions


func _play_positions(positions: Array[Vector2i]) -> void:
	var notes: Array[int] = []
	for position in positions:
		notes.append(Theory.midi(position))
	if tone_player.play_notes(notes):
		board.sounding.assign(positions)
		board.queue_redraw()


func _play_group() -> void:
	var positions: Array[Vector2i] = _group_positions()
	if positions.size() < 2:
		return
	_play_positions(positions)
	if mode == 0:
		var names: Array[String] = []
		for position in positions:
			names.append("%s（%d 弦 %d 品）" % [Theory.note_name(position), position.x + 1, position.y])
		feedback = "同時試聽：" + " ＋ ".join(names) + "。白色外圈標出實際發聲位置。"
		feedback_color = MUTED
		_refresh()


func _hint() -> void:
	var answers: Array[Vector2i] = _valid_answers()
	if answers.is_empty():
		return
	help_used = true
	feedback = "提示：%s。" % Theory.movement(root_position, answers[0])
	feedback_color = GOLD
	_refresh()


func _reveal() -> void:
	revealed = true
	help_used = true
	wrong_position = Vector2i(-1, -1)
	if mode == 2:
		var voicings: Array[Array] = _compatible_voicings()
		if not voicings.is_empty():
			picked.assign(voicings[0])
		feedback = "顯示一組可彈奏的答案；也可以使用其他符合音級與跨度的指型。點下一題再練一次。"
	else:
		feedback = "已顯示所有符合範圍的答案。選一個位置記住它與根音的位移，再點下一題。"
	feedback_color = GOLD
	_refresh()


func _new_question() -> void:
	var possible: Array[Vector2i] = []
	for string_index in range(6):
		for fret in range(Theory.LAST_FRET + 1):
			var position := Vector2i(string_index, fret)
			if position == root_position:
				continue
			if mode == 2 and Theory.triad_voicings(position, chord_index, nearby).is_empty():
				continue
			if mode != 2 and Theory.candidates(position, interval_index, nearby).is_empty():
				continue
			possible.append(position)
	if not possible.is_empty():
		root_position = possible[rng.randi_range(0, possible.size() - 1)]
	_reset_question()


func _tone_symbol(relative: int) -> String:
	if mode == 2:
		var chord: Dictionary = Theory.TRIADS[chord_index]
		var index: int = chord.tones.find(relative)
		if index >= 0:
			return chord.symbols[index]
	return Theory.INTERVALS[relative].symbol


func _refresh() -> void:
	if not is_instance_valid(board):
		return
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(index == mode)
	string_select.select(root_position.x)
	fret_select.set_value_no_signal(root_position.y)
	interval_select.select(interval_index)
	chord_select.select(chord_index)
	interval_select.visible = mode != 2
	chord_select.visible = mode == 2
	notes_check.disabled = mode != 0
	root_placement_button.visible = mode == 0
	root_placement_button.set_pressed_no_signal(placing_root)
	root_placement_button.text = "點選：設根音" if placing_root else "點選：試聽"
	var group: Array[Vector2i] = _group_positions()
	play_group_button.disabled = group.size() < 2
	play_group_button.text = "播放三和弦" if group.size() == 3 else "播放雙音"
	play_group_button.tooltip_text = "同時播放根音與已選的音；三和弦尚未選滿時，可先聽雙音。"
	board.listening_target = audition_target if mode == 0 or (mode == 1 and revealed) else Vector2i(-1, -1)
	board.root = root_position
	board.nearby = nearby
	board.show_notes = notes_check.button_pressed
	board.conceal_answers = mode != 0 and not revealed and not question_complete
	board.markers.clear()
	if mode == 0 or (mode == 1 and revealed):
		for position in Theory.candidates(root_position, interval_index, nearby):
			board.markers[position] = {"text": _tone_symbol(interval_index), "color": GOLD}
	for position in picked:
		var relative: int = Theory.relative_pc(root_position, position)
		var color: Color = BLUE if mode == 2 and relative == Theory.TRIADS[chord_index].tones[1] else GOLD
		board.markers[position] = {"text": _tone_symbol(relative), "color": color}
	if Theory.is_position_valid(wrong_position):
		board.markers[wrong_position] = {"text": "×", "color": RED}
	board.queue_redraw()
	var root_name: String = Theory.root_name(root_position)
	root_label.text = "ROOT   %s  /  %d 弦 · %d 品" % [Theory.note_name(root_position), root_position.x + 1, root_position.y]
	eyebrow.text = ["EXPLORE / 看見相對位置", "DYAD / 從一個音找到另一個音", "TRIAD / 用音程組成和弦"][mode]
	if mode != 2:
		var interval: Dictionary = Theory.INTERVALS[interval_index]
		var target: String = Theory.spelled_note(root_position, interval.semitones, interval.letter_steps)
		instruction_label.text = "%s 的%s，在哪裡？" % [root_name, interval.name]
		formula_label.text = "R → %s  ·  %s → %s  ·  向上 %d 半音（以八度為循環）" % [interval.symbol, root_name, target if mode == 0 or revealed or question_complete else "？", interval.semitones]
		if interval_index == 0:
			formula_label.text = "R → 1 / 8  ·  同音級可相差 0、±12、±24…半音；不包含已給定的根音位置"
		if mode == 0:
			formula_label.text += "  ·  範圍內有 %d 個位置" % Theory.candidates(root_position, interval_index, nearby).size()
	else:
		var chord: Dictionary = Theory.TRIADS[chord_index]
		instruction_label.text = "組成 %s%s：補上三度與五度" % [root_name, chord.suffix]
		var notes: Array[String] = [root_name]
		for index in range(2):
			notes.append(Theory.spelled_note(root_position, chord.tones[index], chord.steps[index]))
		formula_label.text = "%s  ·  %s  ·  已選 %d / 2 音" % [chord.name, chord.formula, picked.size()]
		if revealed or question_complete:
			formula_label.text += "  ·  " + " – ".join(notes)
	feedback_label.text = feedback
	feedback_label.add_theme_color_override("font_color", feedback_color)
	stats_label.text = "獨立完成 %d 題  ·  提示完成 %d 題  ·  錯點 %d 次" % [completed_count, assisted_count, mistake_count]
	stats_label.visible = mode != 0
	hint_button.visible = mode != 0
	reveal_button.visible = mode != 0
	var no_answers: bool = _valid_answers().is_empty()
	hint_button.disabled = question_complete or revealed or no_answers
	reveal_button.disabled = question_complete or revealed or no_answers
	next_button.text = "換一個根音  →" if mode == 0 else "下一題  →"
