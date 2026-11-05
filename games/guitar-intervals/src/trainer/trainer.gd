extends Control

const Theory = preload("res://src/theory/fretboard_theory.gd")
const Board = preload("res://src/fretboard/fretboard.gd")
const TonePlayer = preload("res://src/audio/tone_player.gd")
const P = preload("res://src/ui/instrument_theme.gd")
const IntervalKey = preload("res://src/ui/interval_key.gd")
const Faceplate = preload("res://src/ui/faceplate.gd")
const VoiceQuiz = preload("res://src/voice/voice_quiz.gd")
const MINT := P.SUCCESS
const GOLD := P.TARGET
const BLUE := P.FIFTH
const MUTED := P.MUTED
const RED := P.ERROR
const AUTO_ADVANCE_DELAY: float = 1.6

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
var auto_advance_timer: Timer

var board: Control
var mode_buttons: Array[Button] = []
var interval_choices: HFlowContainer
var chord_choices: HFlowContainer
var interval_buttons: Array[Button] = []
var chord_buttons: Array[Button] = []
var choice_label: Label
var nearby_check: CheckButton
var notes_check: CheckButton
var root_label: Label
var board_instruction_label: Label
var note_readout: Label
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
var task_panel: PanelContainer
var mono_font: Font
var instrument_body: BoxContainer
var volume_value: Label
var voice_quiz: Control
var interval_panels: Array[Control] = []
var last_click_position := Vector2i(-1, -1)
var last_click_scores: Array[int] = []


func _ready() -> void:
	rng.randomize()
	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	auto_advance_timer.wait_time = AUTO_ADVANCE_DELAY
	auto_advance_timer.timeout.connect(_advance_after_success)
	add_child(auto_advance_timer)
	tone_player = TonePlayer.new()
	add_child(tone_player)
	_build_ui()
	tone_player.playback_ended.connect(func() -> void:
		board.sounding.clear()
		board.queue_redraw()
	)
	_reset_question()


func _style(color: Color, border: Color = P.LINE, radius: int = 5) -> StyleBoxFlat:
	return P.panel(color, border, radius)


func _label(value: String, font_size: int = 16, color: Color = P.INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _mono(value: String, font_size: int = 13, color: Color = P.MUTED) -> Label:
	var label := _label(value, font_size, color)
	label.add_theme_font_override("font", mono_font)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
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


func _svg_texture(svg: String) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


func _switch_icon(active: bool) -> Texture2D:
	var fill: String = "#242821" if active else "#bfc3b7"
	var x: int = 19 if active else 3
	return _svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="38" height="22"><rect x="0" y="1" width="38" height="20" rx="3" fill="%s"/><rect x="%d" y="4" width="16" height="14" rx="2" fill="#fafaf2"/></svg>' % [fill, x])


func _build_theme() -> void:
	var app_theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansTC.ttf")
	font.variation_opentype = {"wght": 550.0}
	font.variation_embolden = 0.2
	app_theme.default_font = font
	app_theme.default_font_size = 15
	var mono := FontVariation.new()
	mono.base_font = preload("res://assets/fonts/RobotoMono.ttf")
	mono.variation_opentype = {"wght": 500.0}
	mono.fallbacks = [font]
	mono_font = mono
	app_theme.set_stylebox("normal", "Button", P.key(P.KEY))
	app_theme.set_stylebox("hover", "Button", P.key(Color("e4e7db")))
	app_theme.set_stylebox("pressed", "Button", P.key(P.SCREEN, true))
	app_theme.set_stylebox("disabled", "Button", P.key(Color("e1e4d9")))
	var focus := P.panel(Color.TRANSPARENT, P.ROOT, 4, 0)
	focus.set_border_width_all(2)
	app_theme.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		app_theme.set_color(state, "Button", P.INK)
	app_theme.set_color("font_pressed_color", "Button", P.SCREEN_INK)
	app_theme.set_color("font_hover_pressed_color", "Button", P.SCREEN_INK)
	app_theme.set_color("font_disabled_color", "Button", Color("8d9585"))
	for icon in ["checked", "checked_disabled"]:
		app_theme.set_icon(icon, "CheckButton", _switch_icon(true))
	for icon in ["unchecked", "unchecked_disabled"]:
		app_theme.set_icon(icon, "CheckButton", _switch_icon(false))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		app_theme.set_color(state, "CheckButton", P.INK)
	app_theme.set_color("font_disabled_color", "CheckButton", Color("969e8e"))
	for state in ["normal", "pressed", "disabled"]:
		app_theme.set_stylebox(state, "CheckButton", P.panel(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4))
	app_theme.set_stylebox("hover", "CheckButton", P.panel(Color("e0e4d6"), Color.TRANSPARENT, 3, 4))
	app_theme.set_stylebox("slider", "HSlider", P.panel(P.LINE, Color.TRANSPARENT, 2, 2))
	app_theme.set_stylebox("grabber_area", "HSlider", P.panel(P.INK, Color.TRANSPARENT, 2, 2))
	app_theme.set_stylebox("grabber_area_highlight", "HSlider", P.panel(P.INK, Color.TRANSPARENT, 2, 2))
	var knob: Texture2D = _svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="20"><rect x="1" y="1" width="14" height="18" rx="3" fill="#f07845"/><path d="M8 4v12" stroke="#242821" stroke-width="1.5"/></svg>')
	app_theme.set_icon("grabber", "HSlider", knob)
	app_theme.set_icon("grabber_highlight", "HSlider", knob)
	app_theme.set_stylebox("normal", "LineEdit", P.panel(P.KEY, P.LINE, 4, 10))
	app_theme.set_stylebox("read_only", "LineEdit", P.panel(Color("e1e4d9"), P.LINE, 4, 10))
	app_theme.set_stylebox("focus", "LineEdit", focus)
	app_theme.set_color("font_color", "LineEdit", P.INK)
	app_theme.set_color("font_uneditable_color", "LineEdit", P.MUTED)
	app_theme.set_color("font_placeholder_color", "LineEdit", P.MUTED)
	app_theme.set_color("caret_color", "LineEdit", P.INK)
	theme = app_theme


func _build_ui() -> void:
	_build_theme()
	var background := ColorRect.new()
	background.color = P.DESK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 16)
	scroll.add_child(margins)
	var faceplate := Faceplate.new()
	faceplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var case_style := P.panel(P.CASE, Color("aeb4a5"), 8, 18)
	case_style.border_width_bottom = 4
	case_style.shadow_color = Color(0.12, 0.16, 0.08, 0.15)
	case_style.shadow_size = 7
	case_style.shadow_offset = Vector2(0, 4)
	faceplate.add_theme_stylebox_override("panel", case_style)
	margins.add_child(faceplate)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	faceplate.add_child(content)
	var header := _row(content)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header.add_child(brand)
	brand.add_child(_mono("FR–12", 32, P.INK))
	brand.add_child(_label("FRET RELATIONS  /  指板音程練習器", 12, P.MUTED))
	_spacer(header)
	var header_info := VBoxContainer.new()
	header_info.add_theme_constant_override("separation", 3)
	header.add_child(header_info)
	var tuning := _mono("STANDARD TUNING    E · A · D · G · B · e", 11)
	tuning.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_info.add_child(tuning)
	var sound_controls := _row(header_info, 8)
	sound_controls.alignment = BoxContainer.ALIGNMENT_END
	mute_button = _button("● 聲音開", func() -> void:
		tone_player.set_muted(not tone_player.muted)
		mute_button.text = "○ 靜音" if tone_player.muted else "● 聲音開"
	)
	mute_button.custom_minimum_size.y = 34
	mute_button.tooltip_text = "切換試聽聲音；靜音會立即停止播放。"
	sound_controls.add_child(mute_button)
	sound_controls.add_child(_mono("OUTPUT", 10))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = tone_player.volume_percent
	volume_slider.custom_minimum_size.x = 100
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.tooltip_text = "試聽音量"
	sound_controls.add_child(volume_slider)
	volume_value = _mono("70", 13, P.INK)
	volume_value.custom_minimum_size.x = 26
	sound_controls.add_child(volume_value)
	volume_slider.value_changed.connect(func(value: float) -> void:
		tone_player.set_volume(value)
		volume_value.text = "%02d" % int(value)
	)
	var tabs := _row(content, 8)
	for index in range(4):
		var button := _button(["01  音程查閱", "02  雙音練習", "03  三和弦練習", "04  口說讀譜"][index], _set_mode.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		tabs.add_child(button)
		mode_buttons.append(button)
	var toolbar := _row(content, 10)
	interval_panels.append(toolbar)
	root_label = _mono("", 17, P.INK)
	toolbar.add_child(root_label)
	root_placement_button = _button("在指板選根音", _toggle_root_placement)
	root_placement_button.toggle_mode = true
	root_placement_button.tooltip_text = "可直接雙擊指板設定根音；也可按此鍵後單擊選定。"
	toolbar.add_child(root_placement_button)
	_spacer(toolbar)
	nearby_check = CheckButton.new()
	nearby_check.text = "±4 品範圍"
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
	instrument_body = BoxContainer.new()
	instrument_body.add_theme_constant_override("separation", 14)
	content.add_child(instrument_body)
	interval_panels.append(instrument_body)
	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", P.panel(P.SCREEN, Color("080e0b"), 6, 12))
	instrument_body.add_child(board_panel)
	var board_content := VBoxContainer.new()
	board_content.add_theme_constant_override("separation", 6)
	board_panel.add_child(board_content)
	var board_header := _row(board_content, 8)
	board_instruction_label = _label("", 12, P.SCREEN_MUTED)
	board_header.add_child(board_instruction_label)
	_spacer(board_header)
	board_header.add_child(_label("● 根音", 12, P.ROOT))
	board_header.add_child(_label("● 目標音", 12, P.TARGET))
	board_header.add_child(_label("● 五度", 12, P.FIFTH))
	board = Board.new()
	board.add_theme_font_override("font", mono_font)
	board.note_pressed.connect(_on_note_pressed)
	board.root_requested.connect(_on_root_requested)
	board_content.add_child(board)
	note_readout = _mono("點選指板，查看音名與八度", 17, P.SCREEN_INK)
	note_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_content.add_child(note_readout)
	var board_note := _label("1 弦在上方 · 6 弦在下方   /   G → B：4 半音，其餘相鄰弦：5 半音", 11, P.SCREEN_MUTED)
	board_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_content.add_child(board_note)
	var keypad := PanelContainer.new()
	keypad.custom_minimum_size.x = 264
	keypad.add_theme_stylebox_override("panel", P.panel(Color("e1e5d9"), P.LINE, 5, 12))
	instrument_body.add_child(keypad)
	var keypad_content := VBoxContainer.new()
	keypad_content.add_theme_constant_override("separation", 8)
	keypad.add_child(keypad_content)
	choice_label = _mono("", 12, P.INK)
	keypad_content.add_child(choice_label)
	interval_choices = HFlowContainer.new()
	interval_choices.add_theme_constant_override("h_separation", 6)
	interval_choices.add_theme_constant_override("v_separation", 6)
	keypad_content.add_child(interval_choices)
	var interval_group := ButtonGroup.new()
	interval_buttons.resize(Theory.INTERVALS.size())
	for index in [0, 5, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11]:
		var interval: Dictionary = Theory.INTERVALS[index]
		var button := IntervalKey.new()
		button.symbol = interval.symbol
		button.caption = "同音／八度" if index == 0 else ("增四／減五" if index == 6 else interval.name)
		button.index_text = "%02d" % interval.semitones
		button.glyph_font = mono_font
		button.custom_minimum_size = Vector2(112, 48)
		button.toggle_mode = true
		button.button_group = interval_group
		button.tooltip_text = "%s · 向上 %d 半音（按音級比較）" % [interval.name, interval.semitones]
		button.pressed.connect(_on_interval_changed.bind(index))
		interval_choices.add_child(button)
		interval_buttons[index] = button
	chord_choices = HFlowContainer.new()
	chord_choices.add_theme_constant_override("h_separation", 6)
	chord_choices.add_theme_constant_override("v_separation", 6)
	keypad_content.add_child(chord_choices)
	var chord_group := ButtonGroup.new()
	for index in range(Theory.TRIADS.size()):
		var chord: Dictionary = Theory.TRIADS[index]
		var button := IntervalKey.new()
		button.symbol = chord.formula.replace(" ", "")
		button.caption = chord.name
		button.index_text = "%02d" % (index + 1)
		button.glyph_font = mono_font
		button.custom_minimum_size = Vector2(112, 64)
		button.toggle_mode = true
		button.button_group = chord_group
		button.tooltip_text = "%s · %s" % [chord.name, chord.formula]
		button.pressed.connect(_on_chord_changed.bind(index))
		chord_choices.add_child(button)
		chord_buttons.append(button)
	var keypad_help := _label("先選根音，再選音程。\n點指板，把位置與聽感連起來。", 12, P.MUTED)
	keypad_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keypad_content.add_child(keypad_help)
	task_panel = PanelContainer.new()
	task_panel.add_theme_stylebox_override("panel", P.panel(P.CASE, P.LINE, 4, 12))
	content.add_child(task_panel)
	interval_panels.append(task_panel)
	var task_content := VBoxContainer.new()
	task_content.add_theme_constant_override("separation", 5)
	task_panel.add_child(task_content)
	var task_header := _row(task_content)
	eyebrow = _mono("", 11)
	task_header.add_child(eyebrow)
	_spacer(task_header)
	stats_label = _mono("", 11)
	task_header.add_child(stats_label)
	instruction_label = _label("", 22)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_content.add_child(instruction_label)
	formula_label = _mono("", 13, Color("3d657c"))
	formula_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_content.add_child(formula_label)
	feedback_label = _label("", 14, P.MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size.y = 28
	task_content.add_child(feedback_label)
	var actions := _row(task_content, 8)
	hint_button = _button("位置提示", _hint)
	actions.add_child(hint_button)
	reveal_button = _button("查看答案", _reveal)
	actions.add_child(reveal_button)
	play_root_button = _button("播放根音", func() -> void: _play_positions([root_position]))
	actions.add_child(play_root_button)
	play_group_button = _button("播放雙音", _play_group)
	actions.add_child(play_group_button)
	_spacer(actions)
	next_button = _button("下一題 →", _new_question)
	next_button.custom_minimum_size.x = 168
	next_button.add_theme_stylebox_override("normal", P.key(P.ROOT))
	next_button.add_theme_stylebox_override("hover", P.key(Color("fa9569")))
	actions.add_child(next_button)
	var scope_note := _label("音級關係含不同八度與低於根音的位置。點音會顯示實際音名；完整答對後自動進入下一題。", 11, P.MUTED)
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(scope_note)
	interval_panels.append(scope_note)
	voice_quiz = VoiceQuiz.new()
	voice_quiz.tone_player = tone_player
	voice_quiz.mono_font = mono_font
	content.add_child(voice_quiz)
	resized.connect(_update_instrument_layout)
	_update_instrument_layout()


func _update_instrument_layout() -> void:
	if is_instance_valid(instrument_body):
		instrument_body.vertical = size.x < 1180.0


func _set_mode(value: int) -> void:
	mode = value
	placing_root = false
	auto_advance_timer.stop()
	tone_player.stop()
	voice_quiz.set_active(mode == 3)
	for panel in interval_panels:
		panel.visible = mode != 3
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(index == mode)
	if mode == 3:
		return
	_reset_question()


func _on_interval_changed(value: int) -> void:
	if interval_index == value:
		return
	interval_index = value
	_reset_question()


func _on_chord_changed(value: int) -> void:
	if chord_index == value:
		return
	chord_index = value
	_reset_question()


func _reset_question() -> void:
	auto_advance_timer.stop()
	last_click_position = Vector2i(-1, -1)
	last_click_scores.clear()
	placing_root = false
	tone_player.stop()
	note_readout.text = "點選指板，查看音名與八度"
	board.named_positions.clear()
	picked.clear()
	audition_target = Vector2i(-1, -1)
	wrong_position = Vector2i(-1, -1)
	revealed = false
	question_complete = false
	help_used = false
	feedback = "先選音程，再單擊指板試聽；雙擊任一位置即可設定根音。" if mode == 0 else "先觀察根音，再單擊你認為正確的位置；雙擊可重新設定根音。"
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


func _on_root_requested(position: Vector2i) -> void:
	if mode == 3 or not Theory.is_position_valid(position):
		return
	# A native double-click includes an ordinary first click. Undo only its score
	# changes, so selecting a root cannot add a wrong answer or a completion.
	if last_click_position == position and last_click_scores.size() == 3:
		completed_count = last_click_scores[0]
		assisted_count = last_click_scores[1]
		mistake_count = last_click_scores[2]
	root_position = position
	_reset_question()
	feedback = "根音已設為 %s · %d 弦 %d 品。" % [Theory.note_name(position), position.x + 1, position.y]
	_refresh()
	_play_positions([position])


func _on_note_pressed(position: Vector2i) -> void:
	last_click_position = position
	last_click_scores.assign([completed_count, assisted_count, mistake_count])
	if placing_root:
		root_position = position
		_reset_question()
		_play_positions([position])
		return
	if mode == 0:
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
		feedback = "橘色 R 是已給定的根音，請在其他位置補上目標音。"
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
			feedback = "答對了！%s。即將自動進入下一題。" % Theory.movement(root_position, position)
			auto_advance_timer.start()
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


func _advance_after_success() -> void:
	if mode != 0 and question_complete and not revealed and not placing_root:
		_new_question()


func _toggle_root_placement() -> void:
	placing_root = not placing_root
	if placing_root:
		auto_advance_timer.stop()
		tone_player.stop()
	elif question_complete and not revealed:
		auto_advance_timer.start()
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
	var note_descriptions: Array[String] = []
	for position in positions:
		notes.append(Theory.midi(position))
		note_descriptions.append("%s（%d 弦 · %d 品）" % [Theory.note_name(position), position.x + 1, position.y])
	# Keep note identity visible after playback, even when muted or in practice.
	note_readout.text = ("音名：" if positions.size() == 1 else "合奏音名：") + " ＋ ".join(note_descriptions)
	board.named_positions.assign(positions)
	board.queue_redraw()
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
	feedback_color = P.INFO
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
	feedback_color = P.INFO
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
	if not is_instance_valid(board) or mode == 3:
		return
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(index == mode)
	for index in range(interval_buttons.size()):
		interval_buttons[index].set_pressed_no_signal(index == interval_index)
	for index in range(chord_buttons.size()):
		chord_buttons[index].set_pressed_no_signal(index == chord_index)
	interval_choices.visible = mode != 2
	chord_choices.visible = mode == 2
	choice_label.text = "02 / CHORD · 和弦" if mode == 2 else "02 / INTERVAL · 音程"
	notes_check.disabled = mode != 0
	root_placement_button.set_pressed_no_signal(placing_root)
	root_placement_button.text = "取消選根音" if placing_root else "在指板選根音"
	var group: Array[Vector2i] = _group_positions()
	play_group_button.disabled = group.size() < 2
	play_group_button.text = "播放三和弦" if group.size() == 3 else "播放雙音"
	play_group_button.tooltip_text = "同時播放根音與已選的音；三和弦尚未選滿時，可先聽雙音。"
	board.listening_target = audition_target if not placing_root and (mode == 0 or (mode == 1 and revealed)) else Vector2i(-1, -1)
	board.root = root_position
	board.nearby = nearby and not placing_root
	board.selecting_root = placing_root
	board.show_notes = notes_check.button_pressed or placing_root
	board.conceal_answers = mode != 0 and not revealed and not question_complete and not placing_root
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
	if placing_root:
		board.markers.clear()
	board.queue_redraw()
	var root_name: String = Theory.root_name(root_position)
	root_label.text = "根音  %s   ·   %d 弦 %d 品" % [Theory.note_name(root_position), root_position.x + 1, root_position.y]
	board_instruction_label.text = "選根音：直接點選指板位置" if placing_root else ("單擊試聽 · 雙擊設根音" if mode == 0 else "單擊作答／試聽 · 雙擊設根音")
	board_instruction_label.add_theme_color_override("font_color", P.ROOT if placing_root else P.SCREEN_MUTED)
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
	var show_success: bool = question_complete and not placing_root
	if placing_root:
		instruction_label.text = "請在指板點選一個根音"
	elif show_success:
		instruction_label.text = "✓ 答對了！"
	instruction_label.add_theme_color_override("font_color", P.SUCCESS if show_success else P.INK)
	task_panel.add_theme_stylebox_override("panel", _style(Color("e1ebd7") if show_success else P.CASE, P.SUCCESS if show_success else P.LINE, 4))
	feedback_label.text = "直接點選指板位置即可設定根音；按「取消選根音」回到原題。" if placing_root else feedback
	feedback_label.add_theme_color_override("font_color", MUTED if placing_root else feedback_color)
	stats_label.text = "獨立完成 %d 題  ·  提示完成 %d 題  ·  錯點 %d 次" % [completed_count, assisted_count, mistake_count]
	stats_label.visible = mode != 0
	hint_button.visible = mode != 0
	reveal_button.visible = mode != 0
	var no_answers: bool = _valid_answers().is_empty()
	hint_button.disabled = question_complete or revealed or no_answers
	reveal_button.disabled = question_complete or revealed or no_answers
	next_button.text = "換一個根音  →" if mode == 0 else ("立即下一題  →" if question_complete else "下一題  →")
