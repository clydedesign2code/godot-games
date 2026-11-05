extends VBoxContainer
## An independent sight-reading exercise, with replaceable speech input.
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Board = preload("res://src/fretboard/fretboard.gd")
const Answers = preload("res://src/voice/note_answer.gd")
const Speech = preload("res://src/voice/speech_bridge.gd")
const P = preload("res://src/ui/instrument_theme.gd")

var tone_player: Node
var mono_font: Font
var speech: Node
var board: Control
var active: bool = false
var target := Vector2i(-1, -1)
var complete: bool = false
var revealed: bool = false
var helped: bool = false
var correct_count: int = 0
var assisted_count: int = 0
var mistakes: int = 0
var rng := RandomNumberGenerator.new()
var advance: Timer
var body: BoxContainer
var natural_check: CheckButton
var language: OptionButton
var microphone: Button
var cancel_button: Button
var status: Label
var heard: Label
var readout: Label
var question: Label
var feedback: Label
var stats: Label
var typed_answer: LineEdit
var submit_button: Button
var reveal_button: Button
var listen_button: Button
var next_button: Button


func _ready() -> void:
	rng.randomize()
	add_theme_constant_override("separation", 10)
	speech = Speech.new()
	add_child(speech)
	speech.status_changed.connect(func(message: String) -> void:
		status.text = message
		_refresh_buttons()
	)
	speech.failed.connect(func(message: String) -> void:
		status.text = message
		_refresh_buttons()
	)
	speech.recognized.connect(_recognized)
	advance = Timer.new()
	advance.one_shot = true
	advance.wait_time = 1.6
	advance.timeout.connect(_new_question)
	add_child(advance)
	_build()
	tone_player.playback_ended.connect(func() -> void:
		board.sounding.clear()
		board.queue_redraw()
	)
	resized.connect(func() -> void: body.vertical = size.x < 1100)
	visible = false


func _label(text: String, font_size: int = 14, color: Color = P.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	return button


func _build() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 14)
	add_child(toolbar)
	natural_check = CheckButton.new()
	natural_check.text = "先練自然音 A–G"
	natural_check.button_pressed = true
	natural_check.toggled.connect(func(_value: bool) -> void: _new_question())
	toolbar.add_child(natural_check)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var language_label := Label.new()
	language_label.text = "辨識語言"
	language_label.add_theme_color_override("font_color", P.MUTED)
	toolbar.add_child(language_label)
	language = OptionButton.new()
	language.add_item("English · A–G / Do–Si")
	language.add_item("中文 · 音名／唱名")
	language.custom_minimum_size.y = 44
	language.item_selected.connect(func(_index: int) -> void:
		speech.cancel()
		status.text = "語言已切換。音名與固定唱名都接受。"
		_refresh_buttons()
	)
	toolbar.add_child(language)
	body = BoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	var display := PanelContainer.new()
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.add_theme_stylebox_override("panel", P.panel(P.SCREEN, Color("080e0b"), 6, 12))
	body.add_child(display)
	var screen := VBoxContainer.new()
	display.add_child(screen)
	screen.add_child(_label("READ THE DOT  /  看位置，說出音名或唱名", 13, P.SCREEN_MUTED))
	board = Board.new()
	board.read_quiz = true
	board.nearby = false
	board.conceal_answers = true
	board.add_theme_font_override("font", mono_font)
	board.note_pressed.connect(_inspect_note)
	screen.add_child(board)
	readout = _label("", 18, P.SCREEN_INK)
	screen.add_child(readout)
	screen.add_child(_label("1 弦在上方 · 6 弦在下方；只讀音名，不必說八度。", 12, P.SCREEN_MUTED))
	var mic_panel := PanelContainer.new()
	mic_panel.custom_minimum_size.x = 264
	mic_panel.add_theme_stylebox_override("panel", P.panel(Color("e1e5d9"), P.LINE, 5, 12))
	body.add_child(mic_panel)
	var mic_controls := VBoxContainer.new()
	mic_controls.add_theme_constant_override("separation", 10)
	mic_panel.add_child(mic_controls)
	mic_controls.add_child(_label("04 / VOICE · 口說讀譜", 15))
	mic_controls.add_child(_label("A–G 或 Do–Si 都可以\nB = Si / Ti\nF sharp = 升 Fa\nB flat = 降 Si", 15))
	microphone = _button("● 開始口說", _toggle_microphone)
	microphone.add_theme_stylebox_override("normal", P.key(P.ROOT))
	mic_controls.add_child(microphone)
	cancel_button = _button("取消聆聽", func() -> void:
		speech.cancel()
		status.text = "已取消。沒有判題，也不計錯。"
		_refresh_buttons()
	)
	mic_controls.add_child(cancel_button)
	status = _label("按下才聽。首次使用需允許麥克風與語音辨識。", 13, P.MUTED)
	mic_controls.add_child(status)
	mic_controls.add_child(_label("裝置端辨識 · 不儲存錄音\n說出名稱即可，不必唱出音高。", 12, P.MUTED))
	var task := PanelContainer.new()
	task.add_theme_stylebox_override("panel", P.panel(P.CASE, P.LINE, 4, 12))
	add_child(task)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	task.add_child(controls)
	stats = _label("", 12, P.MUTED)
	controls.add_child(stats)
	question = _label("這個位置是什麼音？", 23)
	controls.add_child(question)
	heard = _label("我聽到：—", 17, P.INFO)
	controls.add_child(heard)
	feedback = _label("", 15)
	controls.add_child(feedback)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	controls.add_child(input_row)
	typed_answer = LineEdit.new()
	typed_answer.placeholder_text = "也可輸入：B、Si、F sharp、升 Fa"
	typed_answer.custom_minimum_size.y = 44
	typed_answer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typed_answer.text_submitted.connect(_submit_text)
	input_row.add_child(typed_answer)
	submit_button = _button("送出答案", func() -> void: _submit_text(typed_answer.text))
	input_row.add_child(submit_button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	controls.add_child(actions)
	listen_button = _button("聽音提示", _listen)
	actions.add_child(listen_button)
	reveal_button = _button("查看音名", _reveal)
	actions.add_child(reveal_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(gap)
	next_button = _button("下一題 →", _new_question)
	next_button.custom_minimum_size.x = 168
	actions.add_child(next_button)
	add_child(_label("固定唱名 C = Do，B = Si／Ti；等音接受，例如 F♯ = G♭。沒聽清楚不算答錯。", 12, P.MUTED))


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	speech.cancel()
	advance.stop()
	if enabled:
		_new_question()
	else:
		tone_player.stop()


func _new_question() -> void:
	if not active:
		return
	speech.cancel()
	advance.stop()
	tone_player.stop()
	var candidates: Array[Vector2i] = []
	for string_index in range(6):
		for fret in range(Theory.LAST_FRET + 1):
			var position := Vector2i(string_index, fret)
			if position != target and (not natural_check.button_pressed or Theory.midi(position) % 12 in [0, 2, 4, 5, 7, 9, 11]):
				candidates.append(position)
	target = candidates[rng.randi_range(0, candidates.size() - 1)]
	complete = false
	revealed = false
	helped = false
	board.quiz_target = target
	board.conceal_answers = true
	board.markers.clear()
	board.named_positions.clear()
	board.tooltip_text = ""
	board.queue_redraw()
	readout.text = "？  ·  %d 弦 %d 品" % [target.x + 1, target.y]
	question.text = "這個位置是什麼音？"
	question.add_theme_color_override("font_color", P.INK)
	heard.text = "我聽到：—"
	feedback.text = "看橘色圓點，說出音名或固定唱名。"
	feedback.add_theme_color_override("font_color", P.MUTED)
	status.text = "準備好了再按「開始口說」。"
	typed_answer.clear()
	_refresh_buttons()


func _toggle_microphone() -> void:
	if not active or complete or revealed:
		return
	if speech.active:
		speech.finish()
	else:
		tone_player.stop()
		speech.start("en-US" if language.selected == 0 else "zh-TW")
	_refresh_buttons()


func _recognized(result: Dictionary) -> void:
	if not active or complete or revealed:
		return
	heard.text = "我聽到：%s" % str(result.get("text", ""))
	var answer: int = Answers.from_recognition(result)
	if answer < 0:
		status.text = "這次音名不夠明確，請重說；不計錯。"
		_refresh_buttons()
		return
	status.text = "已辨識。"
	_judge(answer)


func _submit_text(text: String) -> void:
	if not active or complete or revealed:
		return
	speech.cancel()
	heard.text = "你輸入：%s" % text
	var answer: int = Answers.parse(text)
	if answer < 0:
		status.text = "請輸入一個音名或固定唱名，例如 B、Si、B flat、降 Si。不計錯。"
		_refresh_buttons()
		return
	status.text = "已使用輸入答案。"
	_judge(answer)


func _judge(answer: int) -> void:
	if answer == Theory.midi(target) % 12:
		complete = true
		speech.cancel()
		if helped:
			assisted_count += 1
		else:
			correct_count += 1
		question.text = "✓ 答對了！"
		question.add_theme_color_override("font_color", P.SUCCESS)
		_show_identity()
		feedback.text = "%s。即將自動進入下一題。" % Answers.NAMES[answer]
		feedback.add_theme_color_override("font_color", P.SUCCESS)
		advance.start()
	else:
		mistakes += 1
		feedback.text = "你答的是 %s，這次不對。再看一次圓點的位置。" % Answers.NAMES[answer]
		feedback.add_theme_color_override("font_color", P.ERROR)
	_refresh_buttons()


func _show_identity() -> void:
	readout.text = "音名：%s  ·  %d 弦 %d 品" % [Theory.note_name(target), target.x + 1, target.y]
	board.markers[target] = {"text": Theory.NOTE_NAMES[Theory.midi(target) % 12], "color": P.FIFTH if complete else P.TARGET}
	board.named_positions.assign([target])
	board.queue_redraw()


func _inspect_note(position: Vector2i) -> void:
	if not active:
		return
	speech.cancel()
	if not complete and not revealed:
		helped = true
		feedback.text = "已顯示點選位置的音名；這題完成會記為提示完成。"
		feedback.add_theme_color_override("font_color", P.INFO)
	board.named_positions.assign([position])
	readout.text = "音名：%s  ·  %d 弦 %d 品" % [Theory.note_name(position), position.x + 1, position.y]
	var notes: Array[int] = [Theory.midi(position)]
	if tone_player.play_notes(notes):
		board.sounding.assign([position])
	board.queue_redraw()
	_refresh_buttons()


func _listen() -> void:
	if not active:
		return
	speech.cancel()
	if not complete and not revealed:
		helped = true
		feedback.text = "已播放提示；這題完成會記為提示完成。"
		feedback.add_theme_color_override("font_color", P.INFO)
	var notes: Array[int] = [Theory.midi(target)]
	if tone_player.play_notes(notes):
		board.sounding.assign([target])
		board.queue_redraw()
	_refresh_buttons()


func _reveal() -> void:
	if not active or complete:
		return
	speech.cancel()
	advance.stop()
	revealed = true
	_show_identity()
	feedback.text = "答案是 %s。先記住位置，再按下一題；本題不計完成。" % Answers.NAMES[Theory.midi(target) % 12]
	feedback.add_theme_color_override("font_color", P.INFO)
	_refresh_buttons()


func _refresh_buttons() -> void:
	microphone.text = "■ 完成說話" if speech.active else "● 開始口說"
	microphone.disabled = complete or revealed
	cancel_button.disabled = not speech.active
	submit_button.disabled = complete or revealed
	typed_answer.editable = not complete and not revealed
	reveal_button.disabled = complete or revealed
	stats.text = "獨立完成 %d 題  ·  提示完成 %d 題  ·  錯答 %d 次" % [correct_count, assisted_count, mistakes]


func _exit_tree() -> void:
	if is_instance_valid(speech):
		speech.cancel()
