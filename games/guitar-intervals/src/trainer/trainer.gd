extends Control

const Theory = preload("res://src/theory/fretboard_theory.gd")
const Board = preload("res://src/fretboard/fretboard.gd")
const TonePlayer = preload("res://src/audio/tone_player.gd")
const P = preload("res://src/ui/instrument_theme.gd")
const IntervalKey = preload("res://src/ui/interval_key.gd")
const Faceplate = preload("res://src/ui/faceplate.gd")
const ExercisePanel = preload("res://src/ui/exercise_panel.gd")
const VoiceQuiz = preload("res://src/voice/voice_quiz.gd")
const InversionPractice = preload("res://src/trainer/inversion_practice.gd")
const MODE_TITLES := ["查音程", "雙音練習", "和弦補音", "指板讀譜", "查和弦"]
const MINT := P.SUCCESS
const GOLD := P.TARGET
const BLUE := P.FIFTH
const MUTED := P.MUTED
const RED := P.ERROR
const AUTO_ADVANCE_DELAY: float = 1.6
const DEGREE_NAMES: Dictionary = {1: "二度", 2: "三度", 3: "四度", 4: "五度", 5: "六度", 6: "七度"}
const CHORD_GROUPS: Array[Dictionary] = [
	{"id": "basic_sus", "name": "基礎／掛留"},
	{"id": "seventh_sixth", "name": "七／六和弦"},
]

var mode: int = 4
var last_practice_mode := 1
var lookup_return: Dictionary = {}
var root_position := Vector2i(4, 3)
var interval_index: int = 4
var selected_intervals: Array[int] = [4] # Lookup only.
var lookup_interval_index: int = 4
var practice_interval_index: int = 4
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
var practice_nav_button: Button
var practice_tabs: HFlowContainer
var page_scroll: ScrollContainer
var page_margins: MarginContainer
var header: BoxContainer
var tuning: Label
var scope_note: Label
var lookup_actions: HFlowContainer
var interval_choices: HFlowContainer
var chord_choices: VBoxContainer
var chord_sections: Array[HFlowContainer] = []
var chord_section_labels: Array[Label] = []
var interval_buttons: Array[Button] = []
var chord_buttons: Array[Button] = []
var choice_label: Label
var keypad_help: Label
var nearby_check: CheckButton
var notes_check: CheckButton
var root_label: Label
var board_instruction_label: Label
var note_readout: Label
var eyebrow: Label
var instruction_label: Label
var formula_label: Label
var theory_detail_label: Label
var feedback_label: Label
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
var inversion_practice: Control
var interval_panels: Array[Control] = []
var last_click_position := Vector2i(-1, -1)
var last_click_scores: Array[int] = []


func _ready() -> void:
	preload("res://src/ui/window_layout.gd").configure(get_window())
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
	_set_mode(4)


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
	page_scroll = ScrollContainer.new()
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page_scroll)
	page_margins = MarginContainer.new()
	page_margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_margins)
	var faceplate := Faceplate.new()
	faceplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var case_style := P.panel(P.CASE, Color("aeb4a5"), 8, 18)
	case_style.border_width_bottom = 4
	case_style.shadow_color = Color(0.12, 0.16, 0.08, 0.15)
	case_style.shadow_size = 7
	case_style.shadow_offset = Vector2(0, 4)
	faceplate.add_theme_stylebox_override("panel", case_style)
	page_margins.add_child(faceplate)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	faceplate.add_child(content)
	header = BoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var tabs := _row(header, 8)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sound_controls := _row(header, 8)
	sound_controls.alignment = BoxContainer.ALIGNMENT_END
	tuning = _mono("標準調弦  E A D G B e", 11)
	sound_controls.add_child(tuning)
	mute_button = _button("● 聲音開", func() -> void:
		tone_player.set_muted(not tone_player.muted)
		mute_button.text = "○ 靜音" if tone_player.muted else "● 聲音開"
	)
	mute_button.custom_minimum_size.y = 44
	mute_button.tooltip_text = "切換試聽聲音；靜音會立即停止播放。"
	sound_controls.add_child(mute_button)
	sound_controls.add_child(_label("音量", 12, P.MUTED))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = tone_player.volume_percent
	volume_slider.custom_minimum_size = Vector2(100, 44)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	practice_tabs = HFlowContainer.new()
	practice_tabs.add_theme_constant_override("h_separation", 8)
	content.add_child(practice_tabs)
	mode_buttons.resize(MODE_TITLES.size())
	for index in [4, 0, 1, 2, 3]:
		var button := _button(MODE_TITLES[index], _navigate.bind(index))
		button.toggle_mode = true
		if index in [4, 0]:
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tabs.add_child(button)
		else:
			practice_tabs.add_child(button)
		mode_buttons[index] = button
	practice_nav_button = _button("練習", func() -> void: _navigate(last_practice_mode))
	practice_nav_button.toggle_mode = true
	tabs.add_child(practice_nav_button)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 12)
	content.add_child(toolbar)
	interval_panels.append(toolbar)
	root_label = _mono("", 17, P.INK)
	toolbar.add_child(root_label)
	root_placement_button = _button("在指板選根音", _toggle_root_placement)
	root_placement_button.toggle_mode = true
	root_placement_button.tooltip_text = "可直接雙擊指板設定根音；也可按此鍵後單擊選定。"
	toolbar.add_child(root_placement_button)
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
	var board_header := HFlowContainer.new()
	board_header.add_theme_constant_override("h_separation", 12)
	board_content.add_child(board_header)
	board_instruction_label = _label("", 12, P.SCREEN_MUTED)
	board_header.add_child(board_instruction_label)
	board_header.add_child(_label("● 根音", 12, P.ROOT))
	board_header.add_child(_label("● 目標音", 12, P.TARGET))
	board_header.add_child(_label("● 五／六／七度", 12, P.FIFTH))
	board = Board.new()
	board.add_theme_font_override("font", mono_font)
	board.note_pressed.connect(_on_note_pressed)
	board.root_requested.connect(_on_root_requested)
	board_content.add_child(board)
	note_readout = _mono("點選指板，查看音名與弦品", 17, P.SCREEN_INK)
	note_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_content.add_child(note_readout)
	lookup_actions = HFlowContainer.new()
	lookup_actions.add_theme_constant_override("h_separation", 12)
	board_content.add_child(lookup_actions)
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
		button.tooltip_text = "%s · 向上 %d 半音。" % [interval.name, interval.semitones]
		button.pressed.connect(_on_interval_changed.bind(index))
		interval_choices.add_child(button)
		interval_buttons[index] = button
	chord_choices = VBoxContainer.new()
	chord_choices.add_theme_constant_override("separation", 10)
	keypad_content.add_child(chord_choices)
	# One shared ButtonGroup preserves single selection across both sections.
	var chord_group := ButtonGroup.new()
	chord_buttons.resize(Theory.CHORDS.size())
	for group_index in range(CHORD_GROUPS.size()):
		var group: Dictionary = CHORD_GROUPS[group_index]
		if group_index > 0:
			chord_choices.add_child(HSeparator.new())
		var heading := _mono("%02d / %s" % [group_index + 1, group.name], 12, P.INK)
		chord_choices.add_child(heading)
		chord_section_labels.append(heading)
		var keys := HFlowContainer.new()
		keys.add_theme_constant_override("h_separation", 6)
		keys.add_theme_constant_override("v_separation", 6)
		chord_choices.add_child(keys)
		chord_sections.append(keys)
		for index in range(Theory.CHORDS.size()):
			var chord: Dictionary = Theory.CHORDS[index]
			if chord.group != group.id:
				continue
			var button := IntervalKey.new()
			button.symbol = chord.suffix if chord.omit_fifth or chord.steps[0] != 2 else chord.formula.replace(" ", "")
			button.caption = chord.name
			button.index_text = "%02d" % (index + 1)
			button.glyph_font = mono_font
			button.custom_minimum_size = Vector2(112, 56)
			button.toggle_mode = true
			button.button_group = chord_group
			button.tooltip_text = "%s · 完整 %s\n本題 %s%s" % [chord.name, chord.formula, chord.voicing_formula, "（省略五度）" if chord.omit_fifth else ""]
			button.pressed.connect(_on_chord_changed.bind(index))
			keys.add_child(button)
			chord_buttons[index] = button
	keypad_help = _label("", 12, P.MUTED)
	keypad_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keypad_content.add_child(keypad_help)
	task_panel = ExercisePanel.new()
	task_panel.mono_font = mono_font
	content.add_child(task_panel)
	task_panel.practice_button.reparent(lookup_actions, false)
	interval_panels.append(task_panel)
	eyebrow = task_panel.eyebrow
	instruction_label = task_panel.instruction_label
	formula_label = task_panel.formula_label
	theory_detail_label = task_panel.theory_detail_label
	feedback_label = task_panel.feedback_label
	hint_button = task_panel.hint_button
	reveal_button = task_panel.reveal_button
	play_root_button = task_panel.play_root_button
	play_group_button = task_panel.play_group_button
	next_button = task_panel.next_button
	task_panel.hint_requested.connect(_hint)
	task_panel.reveal_requested.connect(_reveal)
	task_panel.play_root_requested.connect(func() -> void: _play_positions([root_position]))
	task_panel.play_group_requested.connect(_play_group)
	task_panel.next_requested.connect(_new_question)
	task_panel.practice_requested.connect(_practice_lookup)
	task_panel.return_requested.connect(_navigate.bind(0))
	scope_note = _label("音級關係含不同八度與低於根音的位置。點音會顯示實際音名；完整答對後自動進入下一題。", 11, P.MUTED)
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(scope_note)
	interval_panels.append(scope_note)
	voice_quiz = VoiceQuiz.new()
	voice_quiz.tone_player = tone_player
	voice_quiz.mono_font = mono_font
	content.add_child(voice_quiz)
	inversion_practice = InversionPractice.new()
	inversion_practice.tone_player = tone_player
	inversion_practice.mono_font = mono_font
	inversion_practice.visible = false
	content.add_child(inversion_practice)
	resized.connect(_update_instrument_layout)
	_update_instrument_layout()


func _update_instrument_layout() -> void:
	if is_instance_valid(instrument_body):
		instrument_body.vertical = size.x < 1180.0
		header.vertical = size.x < 720
		tuning.visible = size.x >= 560
		var margin := 6 if size.x < 650 else 16
		for edge in ["left", "right", "top", "bottom"]:
			page_margins.add_theme_constant_override("margin_" + edge, margin)


func _navigate(value: int) -> void:
	if value == mode:
		mode_buttons[value].set_pressed_no_signal(true)
		practice_nav_button.set_pressed_no_signal(practice_tabs.visible)
		if value == 4:
			inversion_practice.return_to_lookup()
		return
	_set_mode(value)


func _practice_lookup() -> void:
	if mode != 0:
		return
	lookup_return = {
		"root": root_position, "nearby": nearby, "target": audition_target,
		"practice_interval": practice_interval_index,
	}
	practice_interval_index = interval_index
	_set_mode(1)


func _set_mode(value: int) -> void:
	if mode == 0:
		lookup_interval_index = interval_index
	elif mode == 1:
		practice_interval_index = interval_index
	mode = value
	var returning := mode == 0 and not lookup_return.is_empty()
	if returning:
		root_position = lookup_return.root
		nearby = lookup_return.nearby
		nearby_check.set_pressed_no_signal(nearby)
	if mode == 0:
		interval_index = lookup_interval_index
	elif mode == 1:
		interval_index = practice_interval_index
	placing_root = false
	auto_advance_timer.stop()
	tone_player.stop()
	voice_quiz.set_active(mode == 3)
	inversion_practice.set_active(mode == 4)
	if mode == 4:
		inversion_practice.return_to_lookup()
	practice_tabs.visible = mode in [1, 2, 3]
	practice_nav_button.set_pressed_no_signal(practice_tabs.visible)
	if practice_tabs.visible:
		last_practice_mode = mode
	for panel in interval_panels:
		panel.visible = mode < 3
	task_panel.show_lookup_actions(lookup_actions, mode == 0)
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(index == mode)
	page_scroll.scroll_vertical = 0
	if mode >= 3:
		return
	_reset_question()
	if returning:
		audition_target = lookup_return.target
		practice_interval_index = lookup_return.practice_interval
		lookup_return.clear()
		_refresh()


func _on_interval_changed(value: int) -> void:
	if mode == 1:
		if interval_index == value:
			_refresh()
			return
		interval_index = value
		_reset_question()
		return
	if mode != 0:
		return
	if selected_intervals.has(value):
		if selected_intervals.size() == 1:
			# Keep one usable choice and preserve the current answer/listening state.
			_refresh()
			return
		selected_intervals.erase(value)
		if interval_index == value:
			interval_index = selected_intervals[0]
	else:
		selected_intervals.append(value)
		selected_intervals.sort()
		interval_index = value
	_reset_question()


func _on_chord_changed(value: int) -> void:
	if chord_index == value:
		return
	chord_index = value
	_reset_question()


func _reset_question() -> void:
	if mode == 0 and not selected_intervals.has(interval_index):
		interval_index = selected_intervals[0]
	if mode == 0:
		lookup_interval_index = interval_index
	elif mode == 1:
		practice_interval_index = interval_index
	auto_advance_timer.stop()
	last_click_position = Vector2i(-1, -1)
	last_click_scores.clear()
	placing_root = false
	tone_player.stop()
	note_readout.text = "點選指板，查看音名與弦品"
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
		feedback = "此根音與範圍沒有符合條件的三音配置。請更換根音，或關閉 ±4 品限制。"
	_refresh()


func _voicings() -> Array[Array]:
	return Theory.chord_voicings(root_position, chord_index, nearby)


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
	if mode == 0:
		var positions: Array[Vector2i] = []
		for interval in selected_intervals:
			positions.append_array(Theory.candidates(root_position, interval, nearby))
		return positions
	if mode != 2:
		return Theory.candidates(root_position, interval_index, nearby)
	var result: Array[Vector2i] = []
	for voicing in _compatible_voicings():
		for position: Vector2i in voicing:
			if not result.has(position) and not picked.has(position):
				result.append(position)
	return result


func _on_root_requested(position: Vector2i) -> void:
	if mode >= 3 or not Theory.is_position_valid(position):
		return
	# A native double-click includes an ordinary first click. Undo only its score
	# changes, so selecting a root cannot add a wrong answer or a completion.
	if last_click_position == position and last_click_scores.size() == 3:
		completed_count = last_click_scores[0]
		assisted_count = last_click_scores[1]
		mistake_count = last_click_scores[2]
	root_position = position
	_reset_question()
	feedback = "根音已設為 %s · %d 弦 %d 品。" % [Theory.pitch_class_name(position), position.x + 1, position.y]
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
		var relative: int = Theory.relative_pc(root_position, position)
		if position != root_position and Theory.in_scope(root_position, position, nearby) and selected_intervals.has(relative):
			audition_target = position
			interval_index = relative
			lookup_interval_index = relative
		feedback = "單音 %s · %d 弦 %d 品。%s。" % [Theory.pitch_class_name(position), position.x + 1, position.y, Theory.movement(root_position, position)]
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
		if mode == 2 and Theory.CHORDS[chord_index].omit_fifth and relative == 7:
			feedback = "這是五度音，本題省略五度。請補上三度與%s，共三音。" % ("六度" if Theory.CHORDS[chord_index].steps[1] == 5 else "七度")
		elif mode == 2 and Theory.CHORDS[chord_index].tones.has(relative):
			feedback = "音級正確，但無法與目前選擇組成三弦指型：每弦只能一音，按弦跨度最多 4 品。可取消已選音再試。"
		else:
			feedback = "這裡是 %s，與根音相差 %+d 半音，音級關係為 %s。再試一次。" % [Theory.pitch_class_name(position), Theory.midi(position) - Theory.midi(root_position), Theory.INTERVALS[relative].name]
	_refresh()


func _advance_after_success() -> void:
	if mode in [1, 2] and question_complete and not revealed and not placing_root:
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
		note_descriptions.append("%s（%d 弦 · %d 品）" % [Theory.pitch_class_name(position), position.x + 1, position.y])
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
			names.append("%s（%d 弦 %d 品）" % [Theory.pitch_class_name(position), position.x + 1, position.y])
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
		feedback = "顯示一組三音位置；也可以使用其他符合音級與跨度的配置。點下一題再練一次。"
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
			if mode == 2 and Theory.chord_voicings(position, chord_index, nearby).is_empty():
				continue
			if mode != 2 and Theory.candidates(position, interval_index, nearby).is_empty():
				continue
			possible.append(position)
	if not possible.is_empty():
		root_position = possible[rng.randi_range(0, possible.size() - 1)]
	_reset_question()


func _tone_symbol(relative: int) -> String:
	if mode == 2:
		var chord: Dictionary = Theory.CHORDS[chord_index]
		var index: int = chord.tones.find(relative)
		if index >= 0:
			return chord.symbols[index]
	return Theory.INTERVALS[relative].symbol


func _tone_card(position: Vector2i, role: String, color: Color, given: bool = false) -> Dictionary:
	var known: bool = Theory.is_position_valid(position)
	return {
		"role": role,
		"value": Theory.pitch_class_name(position) if known else "？",
		"state": ("已給定" if given else "%d 弦 %d 品" % [position.x + 1, position.y]) if known else "等待選音",
		"known": known,
		"color": color
	}


func _refresh() -> void:
	if not is_instance_valid(board) or mode >= 3:
		return
	for index in range(mode_buttons.size()):
		mode_buttons[index].set_pressed_no_signal(index == mode)
	for index in range(interval_buttons.size()):
		interval_buttons[index].set_pressed_no_signal(selected_intervals.has(index) if mode == 0 else index == interval_index)
	for index in range(chord_buttons.size()):
		chord_buttons[index].set_pressed_no_signal(index == chord_index)
	interval_choices.visible = mode != 2
	chord_choices.visible = mode == 2
	choice_label.text = "和弦・單選" if mode == 2 else ("音程・複選" if mode == 0 else "音程・單選")
	if mode == 0:
		keypad_help.text = "可複選，再點一次取消。\n至少保留一項；點指板比較聽感。"
	elif mode == 1:
		keypad_help.text = "單選一個音程。\n根音＋一個目標音，共兩音。"
	else:
		keypad_help.text = "兩組共用單選，每題三音。\n基礎／掛留：保留五度。\n七／六和弦：省略五度。"
	notes_check.disabled = mode != 0
	root_placement_button.set_pressed_no_signal(placing_root)
	root_placement_button.text = "取消選根音" if placing_root else "在指板選根音"
	var group: Array[Vector2i] = _group_positions()
	play_group_button.disabled = group.size() < 2
	play_group_button.text = "播放三音" if group.size() == 3 else "播放雙音"
	play_group_button.tooltip_text = "同時播放根音與已選的音；尚未選滿時，可先聽雙音。"
	if mode == 0:
		var interval_name: String = Theory.INTERVALS[interval_index].name
		play_group_button.text = "試聽%s" % interval_name
		play_group_button.tooltip_text = "同時播放根音與指板上圈選的%s。" % interval_name
		task_panel.practice_button.tooltip_text = "沿用目前根音，練習找%s。" % interval_name
	board.listening_target = audition_target if not placing_root and (mode == 0 or (mode == 1 and revealed)) else Vector2i(-1, -1)
	board.root = root_position
	board.nearby = nearby and not placing_root
	board.selecting_root = placing_root
	board.show_notes = notes_check.button_pressed or placing_root
	board.conceal_answers = mode != 0 and not revealed and not question_complete and not placing_root
	board.markers.clear()
	if mode == 0 or (mode == 1 and revealed):
		var shown: Array[int] = []
		if mode == 0:
			shown.assign(selected_intervals)
		else:
			shown.append(interval_index)
		for interval in shown:
			for position in Theory.candidates(root_position, interval, nearby):
				board.markers[position] = {"text": _tone_symbol(interval), "color": BLUE if mode == 0 and interval == 7 and shown.size() > 1 else GOLD}
	for position in picked:
		var relative: int = Theory.relative_pc(root_position, position)
		var color: Color = BLUE if mode == 2 and relative == Theory.CHORDS[chord_index].tones[1] else GOLD
		board.markers[position] = {"text": _tone_symbol(relative), "color": color}
	if Theory.is_position_valid(wrong_position):
		board.markers[wrong_position] = {"text": "×", "color": RED}
	if placing_root:
		board.markers.clear()
	board.queue_redraw()
	var root_name: String = Theory.root_name(root_position)
	root_label.text = "根音  %s   ·   %d 弦 %d 品" % [Theory.pitch_class_name(root_position), root_position.x + 1, root_position.y]
	board_instruction_label.text = "選根音：直接點選指板位置" if placing_root else ("單擊試聽 · 雙擊設根音" if mode == 0 else "單擊作答／試聽 · 雙擊設根音")
	board_instruction_label.add_theme_color_override("font_color", P.ROOT if placing_root else P.SCREEN_MUTED)
	eyebrow.text = ["", "雙音練習", "和弦補音"][mode]
	eyebrow.visible = mode != 0
	scope_note.visible = mode != 0
	var structure: Array[Dictionary] = []
	task_panel.composition_label.text = "和弦組成" if mode == 2 else "音程關係"
	task_panel.full_composition_label.visible = mode == 2
	task_panel.voicing_label.visible = mode == 2
	if mode == 0 and selected_intervals.size() > 1:
		var symbols: Array[String] = []
		var names: Array[String] = []
		for index in selected_intervals:
			var interval: Dictionary = Theory.INTERVALS[index]
			symbols.append(interval.symbol)
			names.append(Theory.spelled_note(root_position, interval.semitones, interval.letter_steps))
		instruction_label.text = "%s：同時查閱 %d 種音程" % [root_name, selected_intervals.size()]
		formula_label.text = "R → " + " / ".join(symbols)
		theory_detail_label.text = "%s → %s\n範圍內有 %d 個位置" % [root_name, " / ".join(names), _valid_answers().size()]
		task_panel.progress_label.text = "已選 %d 種" % selected_intervals.size()
	elif mode != 2:
		var interval: Dictionary = Theory.INTERVALS[interval_index]
		instruction_label.text = ("%s 的%s位置" if mode == 0 else "%s 的%s，在哪裡？") % [root_name, interval.name]
		formula_label.text = "%s  ·  R → %s" % [interval.name, interval.symbol]
		theory_detail_label.text = "向上 %d 半音 · 以八度為循環" % interval.semitones
		if interval_index == 0:
			theory_detail_label.text = "相差 0、±12、±24…半音；不含原根音位置"
		if mode == 0:
			theory_detail_label.text += " · %d 個位置" % Theory.candidates(root_position, interval_index, nearby).size()
		var target_position := Vector2i(-1, -1)
		if mode == 0 or revealed:
			target_position = audition_target
		elif not picked.is_empty():
			target_position = picked[0]
		if mode != 0:
			structure.append(_tone_card(root_position, "根音 · R", P.ROOT, true))
			structure.append(_tone_card(target_position, "目標音 · " + interval.symbol, P.INFO))
		task_panel.progress_label.text = "查閱" if mode == 0 else "已選 %d / 1 音" % picked.size()
	else:
		var chord: Dictionary = Theory.CHORDS[chord_index]
		instruction_label.text = "組成 %s %s" % [root_name, chord.name]
		if chord.omit_fifth or chord.steps[0] != 2:
			instruction_label.text = "%s%s：補上%s與%s" % [root_name, chord.suffix, DEGREE_NAMES[chord.steps[0]], DEGREE_NAMES[chord.steps[1]]]
		var notes: Array[String] = Theory.chord_note_names(root_position, chord_index, true)
		structure.append(_tone_card(root_position, "根音 · 1", P.ROOT, true))
		for index in range(2):
			var position := Vector2i(-1, -1)
			for chosen in picked:
				if Theory.relative_pc(root_position, chosen) == chord.tones[index]:
					position = chosen
					break
			var role: String = DEGREE_NAMES[chord.steps[index]]
			structure.append(_tone_card(position, role + " · " + chord.symbols[index], P.INFO if index == 0 else P.SUCCESS))
		formula_label.text = "%s  ·  %s" % [chord.name, chord.formula]
		task_panel.full_composition_label.text = "完整組成：%s" % " – ".join(Theory.chord_note_names(root_position, chord_index))
		task_panel.voicing_label.text = "本題三音：%s  ·  %s" % [chord.voicing_formula, " – ".join(notes)]
		if chord.omit_fifth:
			task_panel.voicing_label.text += "\n省略五度（5）：%s；保留根音、三度與%s。" % [Theory.spelled_note(root_position, 7, 4), "六度" if chord.steps[1] == 5 else "七度"]
		elif chord.steps[0] != 2:
			task_panel.voicing_label.text += "\n以%s取代三度，保留根音與五度。" % DEGREE_NAMES[chord.steps[0]]
		theory_detail_label.text = "每弦一音 · 按弦跨度最多 4 品"
		task_panel.progress_label.text = "已選 %d / 2 音" % picked.size()
	task_panel.set_structure(structure)
	var show_success: bool = question_complete and not placing_root
	var feedback_state: String = "查閱中" if mode == 0 else "等待作答"
	if placing_root:
		instruction_label.text = "請在指板點選一個根音"
		feedback_state = "設定根音"
	elif show_success:
		feedback_state = "✓ 答對了！"
	elif revealed:
		feedback_state = "已顯示答案"
	elif feedback_color == RED:
		feedback_state = "再試一次"
	elif help_used:
		feedback_state = "位置提示"
	elif not picked.is_empty():
		feedback_state = "繼續選音"
	instruction_label.add_theme_color_override("font_color", P.INK)
	task_panel.set_feedback(feedback_state, "直接點選指板位置即可設定根音；按「取消選根音」回到原題。" if placing_root else feedback, MUTED if placing_root else feedback_color, show_success)
	var statistics: Array[int] = [completed_count, assisted_count, mistake_count]
	task_panel.set_statistics(statistics, mode != 0)
	task_panel.return_button.visible = mode == 1 and not lookup_return.is_empty()
	hint_button.visible = mode != 0
	reveal_button.visible = mode != 0
	var no_answers: bool = _valid_answers().is_empty()
	hint_button.disabled = question_complete or revealed or no_answers
	reveal_button.disabled = question_complete or revealed or no_answers
	next_button.text = "換一個根音  →" if mode == 0 else ("立即下一題  →" if question_complete else "下一題  →")
