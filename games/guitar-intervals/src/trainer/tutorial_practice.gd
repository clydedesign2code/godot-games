extends VBoxContainer
## A reference video and a learner-selected topic drive an original fretboard drill.
const Board = preload("res://src/fretboard/fretboard.gd")
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Chords = preload("res://src/theory/inversion_theory.gd")
const P = preload("res://src/ui/instrument_theme.gd")
const EXAMPLE_URL := "https://www.youtube.com/watch?v=K7F5JDC621M"
const TOPICS := ["大三和弦琶音", "小三和弦琶音"]

var tone_player: Node
var form := VBoxContainer.new()
var exercise := VBoxContainer.new()
var link_input := LineEdit.new()
var status := Label.new()
var start_button: Button
var topic_keys: Array[Button] = []
var topic := -1
var video_url := ""
var question := Label.new()
var feedback := Label.new()
var board := Board.new()
var demo := Timer.new()
var advance := Timer.new()
var demo_step := 0
var question_index := 0
var step := 0
var shape: Array = []
var names: Array[String] = []


static func canonical_url(raw: String) -> String:
	var text := raw.strip_edges()
	var parts := text.split("://", true, 1)
	if parts.size() != 2 or parts[0].to_lower() not in ["http", "https"]:
		return ""
	var path := parts[1].get_slice("#", 0).split("/", true, 1)
	if path.size() != 2:
		return ""
	var host := path[0].to_lower()
	var route := path[1].get_slice("?", 0)
	var id := ""
	if host == "youtu.be":
		id = route
	elif host in ["www.youtube.com", "youtube.com", "m.youtube.com"]:
		if route == "watch":
			for pair in path[1].get_slice("?", 1).split("&"):
				if pair.begins_with("v="):
					id = pair.substr(2)
					break
		elif route.begins_with("shorts/") or route.begins_with("embed/") or route.begins_with("live/"):
			id = route.split("/", true, 1)[1]
	var valid := RegEx.create_from_string("^[A-Za-z0-9_-]{11}$")
	return "https://www.youtube.com/watch?v=" + id if valid.search(id) else ""


func _button(parent: Container, caption: String, action: Callable) -> Button:
	var key := Button.new()
	key.text = caption
	key.custom_minimum_size.y = 44
	parent.add_child(key)
	key.pressed.connect(action)
	return key


func _ready() -> void:
	hide()
	add_child(form)
	add_child(exercise)
	exercise.hide()
	form.add_theme_constant_override("separation", 10)
	exercise.add_theme_constant_override("separation", 8)
	link_input.placeholder_text = "貼上 YouTube 教學影片連結"
	link_input.accessibility_name = link_input.placeholder_text
	link_input.custom_minimum_size.y = 44
	link_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	form.add_child(link_input)
	link_input.text_changed.connect(_link_changed)
	for label in [status, question, feedback]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", P.INK)
	form.add_child(status)
	var choices := HFlowContainer.new()
	form.add_child(choices)
	_button(choices, "用範例連結", func():
		link_input.text = EXAMPLE_URL
		_link_changed(EXAMPLE_URL)
	)
	var group := ButtonGroup.new()
	for i in TOPICS.size():
		var key := _button(choices, TOPICS[i], _choose.bind(i))
		key.toggle_mode = true
		key.button_group = group
		topic_keys.append(key)
	start_button = _button(choices, "開始練習", _start)
	_link_changed("")
	question.add_theme_font_size_override("font_size", 20)
	exercise.add_child(question)
	exercise.add_child(feedback)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", P.panel(P.SCREEN, P.LINE, 5, 10))
	exercise.add_child(panel)
	board.read_quiz = true
	board.nearby = false
	board.conceal_answers = true
	panel.add_child(board)
	board.note_pressed.connect(_answer)
	var actions := HFlowContainer.new()
	exercise.add_child(actions)
	_button(actions, "試聽琶音", _listen)
	_button(actions, "下一題", _next)
	_button(actions, "開啟原影片", func(): OS.shell_open(video_url))
	_button(actions, "更換連結或主題", _edit)
	for timer in [demo, advance]:
		timer.one_shot = true
		add_child(timer)
	demo.timeout.connect(_demo_note)
	advance.timeout.connect(_next)


func set_active(value: bool) -> void:
	if visible and not value:
		_stop()
	visible = value
	if value and exercise.visible and step == shape.size():
		advance.start(1.6)


func _link_changed(value: String) -> void:
	video_url = canonical_url(value)
	topic = -1
	for key in topic_keys:
		key.set_pressed_no_signal(false)
		key.disabled = video_url.is_empty()
	start_button.disabled = true
	if value.strip_edges().is_empty():
		status.text = "貼上連結，再選這次想練的主題。"
	elif video_url.is_empty():
		status.text = "請貼單支影片的 YouTube 或 youtu.be 網址。"
	elif video_url == EXAMPLE_URL:
		status.text = "The Donut Doctor 的琶音教學 · 選擇要練的大三或小三和弦。"
	else:
		status.text = "選擇主題，產生遊戲原創的指板練習。"


func _choose(index: int) -> void:
	topic = index
	start_button.disabled = video_url.is_empty()


func _start() -> void:
	if topic < 0 or video_url.is_empty():
		return
	form.hide()
	exercise.show()
	question_index = 0
	_load_question()


func _edit() -> void:
	_stop()
	exercise.hide()
	form.show()


func _stop() -> void:
	demo.stop()
	advance.stop()
	tone_player.stop()


func _next() -> void:
	if not is_visible_in_tree() or not exercise.visible:
		return
	question_index += 1
	_load_question()


func _load_question() -> void:
	_stop()
	step = 0
	var first := question_index % 4 + 1
	@warning_ignore("integer_division")
	var root_pc := (question_index / 4 * 7) % 12
	names = Chords.note_names(topic, root_pc)
	# Choose an ascending root–third–fifth voicing on successive strings.
	shape = []
	for candidate in Chords.span_voicings(topic, root_pc, 0, 3, first):
		var bass := Theory.midi(candidate[0])
		var third := Theory.midi(candidate[1])
		var fifth := Theory.midi(candidate[2])
		if third - bass == Chords.definition(topic).full_tones[1] and fifth - bass == 7:
			shape = candidate
			break
	board.active_rows.assign(Chords.span_rows(3, first))
	board.focus_voicing(shape)
	board.markers.clear()
	board.queue_redraw()
	question.text = "%s%s · %d–%d 弦" % [names[0], TOPICS[topic], first, first + 2]
	_prompt()


func _prompt() -> void:
	feedback.add_theme_color_override("font_color", P.INK)
	feedback.text = "%s　｜　第 %d 弦找 %s（%d/3）" % [" → ".join(names), shape[step].x + 1, names[step], step + 1]


func _answer(position: Vector2i) -> void:
	if not is_visible_in_tree() or not exercise.visible or step >= shape.size():
		return
	demo.stop()
	_play_note(position)
	if position != shape[step]:
		_prompt()
		feedback.text = "再試一次。 " + feedback.text
		return
	board.markers[position] = {"text": names[step], "color": P.ROOT if step == 0 else P.TARGET}
	board.queue_redraw()
	step += 1
	if step == shape.size():
		feedback.add_theme_color_override("font_color", P.SUCCESS)
		feedback.text = "答對了！  " + " → ".join(names)
		advance.start(1.6)
	else:
		_prompt()


func _listen() -> void:
	demo.stop()
	demo_step = 0
	_demo_note()


func _demo_note() -> void:
	_play_note(shape[demo_step])
	demo_step += 1
	if demo_step < shape.size():
		demo.start(0.45)


func _play_note(position: Vector2i) -> void:
	var pitches: Array[int] = [Theory.midi(position)]
	tone_player.play_notes(pitches)
