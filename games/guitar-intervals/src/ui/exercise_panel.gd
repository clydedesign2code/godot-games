extends PanelContainer
## Fixed information hierarchy for lookup, dyad and three-note chord exercises.
signal hint_requested
signal reveal_requested
signal play_root_requested
signal play_group_requested
signal next_requested
signal practice_requested
signal return_requested

const P = preload("res://src/ui/instrument_theme.gd")
var mono_font: Font
var sections: BoxContainer
var actions: BoxContainer
var playback: HBoxContainer
var help_actions: HBoxContainer
var help_divider: VSeparator
var eyebrow: Label
var prompt_heading: Label
var feedback_heading: Control
var tone_slots: HBoxContainer
var tone_divider: HSeparator
var instruction_label: Label
var composition_label: Label
var formula_label: Label
var full_composition_label: Label
var voicing_label: Label
var theory_detail_label: Label
var progress_label: Label
var feedback_panel: PanelContainer
var feedback_label: Label
var feedback_state: Label
var stats_panel: PanelContainer
var stats_values: Array[Label] = []
var tone_cards: Array[PanelContainer] = []
var tone_roles: Array[Label] = []
var tone_values: Array[Label] = []
var tone_states: Array[Label] = []
var hint_button: Button
var reveal_button: Button
var play_root_button: Button
var play_group_button: Button
var next_button: Button
var practice_button: Button
var return_button: Button


func _label(text: String, font_size: int = 13, color: Color = P.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _mono(text: String, font_size: int = 11, color: Color = P.MUTED) -> Label:
	var label := _label(text, font_size, color)
	label.add_theme_font_override("font", mono_font)
	return label


func _column(parent: Node, gap: int = 6) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column


func _surface(parent: Node, fill: Color, min_width: int = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	panel.add_theme_stylebox_override("panel", P.panel(fill, P.LINE, 4, 10))
	parent.add_child(panel)
	return panel


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _ready() -> void:
	add_theme_stylebox_override("panel", P.panel(P.CASE, P.LINE, 5, 10))
	var content := _column(self, 8)
	sections = BoxContainer.new()
	sections.add_theme_constant_override("separation", 10)
	content.add_child(sections)
	var prompt := _column(sections, 5)
	prompt.custom_minimum_size.x = 220
	prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt.size_flags_stretch_ratio = 1.0
	prompt_heading = _mono("題目")
	prompt.add_child(prompt_heading)
	eyebrow = _mono("", 10)
	prompt.add_child(eyebrow)
	instruction_label = _label("", 23)
	prompt.add_child(instruction_label)
	var composition := _surface(sections, Color("e5e9dd"), 240)
	composition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composition.size_flags_stretch_ratio = 1.4
	var structure := _column(composition, 5)
	var structure_header := HBoxContainer.new()
	structure_header.add_theme_constant_override("separation", 8)
	structure.add_child(structure_header)
	composition_label = _mono("02 / 和弦組成")
	composition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	structure_header.add_child(composition_label)
	progress_label = _mono("", 11, P.INK)
	progress_label.custom_minimum_size.x = 100
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	structure_header.add_child(progress_label)
	formula_label = _mono("", 13, P.INFO)
	structure.add_child(formula_label)
	full_composition_label = _label("", 13)
	structure.add_child(full_composition_label)
	voicing_label = _label("", 13, P.INFO)
	structure.add_child(voicing_label)
	tone_divider = HSeparator.new()
	structure.add_child(tone_divider)
	tone_slots = HBoxContainer.new()
	tone_slots.add_theme_constant_override("separation", 6)
	structure.add_child(tone_slots)
	for index in range(3):
		var card := _surface(tone_slots, P.KEY)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tone_cards.append(card)
		var tone := _column(card, 1)
		var note_row := HBoxContainer.new()
		note_row.add_theme_constant_override("separation", 4)
		tone.add_child(note_row)
		var role := _label("", 11, P.MUTED)
		role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note_row.add_child(role)
		tone_roles.append(role)
		var value := _mono("", 21, P.INK)
		value.custom_minimum_size.x = 48
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note_row.add_child(value)
		tone_values.append(value)
		var state := _label("", 10, P.MUTED)
		tone.add_child(state)
		tone_states.append(state)
	theory_detail_label = _label("", 11, P.MUTED)
	structure.add_child(theory_detail_label)
	stats_panel = _surface(sections, P.KEY, 208)
	var statistics := _column(stats_panel, 10)
	statistics.add_child(_mono("03 / 本次練習"))
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 10)
	statistics.add_child(metrics)
	for caption in ["獨立完成", "提示完成", "錯答次數"]:
		var metric := _column(metrics, 2)
		metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _mono("00", 23, P.INK)
		metric.add_child(value)
		stats_values.append(value)
		metric.add_child(_label(caption, 10, P.MUTED))
	feedback_panel = _surface(content, P.KEY)
	var feedback_row := HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 14)
	feedback_panel.add_child(feedback_row)
	feedback_heading = HBoxContainer.new()
	feedback_heading.add_theme_constant_override("separation", 10)
	feedback_heading.custom_minimum_size.x = 180
	feedback_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback_row.add_child(feedback_heading)
	var feedback_title := _mono("04 / 回饋", 10)
	feedback_title.custom_minimum_size.x = 68
	feedback_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback_heading.add_child(feedback_title)
	feedback_state = _label("等待作答", 14)
	feedback_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_heading.add_child(feedback_state)
	feedback_label = _label("", 14, P.MUTED)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feedback_row.add_child(feedback_label)
	actions = BoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	help_actions = HBoxContainer.new()
	help_actions.add_theme_constant_override("separation", 6)
	actions.add_child(help_actions)
	var help_title := _mono("提示", 10)
	help_title.custom_minimum_size.x = 26
	help_actions.add_child(help_title)
	hint_button = _button(help_actions, "位置提示", func() -> void: hint_requested.emit())
	reveal_button = _button(help_actions, "查看答案", func() -> void: reveal_requested.emit())
	help_divider = VSeparator.new()
	actions.add_child(help_divider)
	playback = HBoxContainer.new()
	playback.add_theme_constant_override("separation", 6)
	actions.add_child(playback)
	play_root_button = _button(playback, "播放根音", func() -> void: play_root_requested.emit())
	play_group_button = _button(playback, "播放雙音", func() -> void: play_group_requested.emit())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	practice_button = _button(actions, "用這個練習", func() -> void: practice_requested.emit())
	return_button = _button(actions, "返回查音程", func() -> void: return_requested.emit())
	next_button = _button(actions, "下一題 →", func() -> void: next_requested.emit())
	next_button.custom_minimum_size.x = 168
	next_button.add_theme_stylebox_override("normal", P.key(P.ROOT))
	next_button.add_theme_stylebox_override("hover", P.key(Color("fa9569")))
	resized.connect(_update_layout)
	_update_layout()


func _update_layout() -> void:
	sections.vertical = size.x < 1080
	actions.vertical = size.x < 850


func set_structure(tones: Array[Dictionary]) -> void:
	for index in range(tone_cards.size()):
		tone_cards[index].visible = index < tones.size()
		if index >= tones.size():
			continue
		var tone: Dictionary = tones[index]
		tone_roles[index].text = tone.role
		tone_values[index].text = tone.value
		tone_values[index].add_theme_color_override("font_color", P.INK if tone.known else P.MUTED)
		tone_states[index].text = tone.state
		tone_cards[index].add_theme_stylebox_override("panel", P.panel(P.KEY if tone.known else P.CASE, tone.color if tone.known else P.LINE, 3, 8))


func show_lookup_actions(host: Container, enabled: bool) -> void:
	host.visible = enabled
	actions.visible = not enabled
	var destination: Container = host if enabled else actions
	if playback.get_parent() != destination:
		playback.reparent(destination, false)
		destination.move_child(playback, 0 if enabled else help_divider.get_index() + 1)


func set_statistics(counts: Array[int], enabled: bool) -> void:
	prompt_heading.text = "題目" if enabled else "指板位置"
	feedback_heading.visible = enabled
	tone_slots.visible = enabled
	tone_divider.visible = enabled
	next_button.visible = enabled
	practice_button.visible = not enabled
	stats_panel.visible = enabled
	help_actions.visible = enabled
	help_divider.visible = enabled
	for index in range(stats_values.size()):
		stats_values[index].text = "%02d" % counts[index]


func set_feedback(state: String, message: String, color: Color, success: bool) -> void:
	feedback_state.text = state
	feedback_state.add_theme_color_override("font_color", color)
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", color)
	var fill: Color = Color("e1ebd7") if success else P.KEY
	var border: Color = color if success or color == P.ERROR else P.LINE
	feedback_panel.add_theme_stylebox_override("panel", P.panel(fill, border, 4, 8))
