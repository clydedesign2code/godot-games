extends SceneTree
## UI + compiled native IPC tests. Deliberately never requests microphone access.
const Scene = preload("res://src/trainer/trainer.tscn")
const Answers = preload("res://src/voice/note_answer.gd")
const Theory = preload("res://src/theory/fretboard_theory.gd")
var checks: int = 0
var failures: int = 0
var app: Control
var quiz: Control
var capture_dir: String = ""


func _initialize() -> void:
	create_timer(25).timeout.connect(func() -> void: quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame


func click(control: Control, local_point: Vector2 = Vector2.INF) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			await frames()
		parent = parent.get_parent()
	var point: Vector2 = control.get_global_rect().get_center() if local_point == Vector2.INF else control.global_position + local_point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await frames()


func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	var ancestor := quiz.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.scroll_vertical = 0
		ancestor = ancestor.get_parent()
	await frames()
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture voice UI")


func result_file(payload: Dictionary, native_fixture: bool = false) -> void:
	check(quiz.speech.start(), "Start isolated protocol session")
	if native_fixture:
		var output: Array = []
		var bundle := ProjectSettings.globalize_path("res://build/NoteSpeech.app")
		check(OS.execute("/usr/bin/open", PackedStringArray(["-W", "-n", "-g", bundle, "--args", "--protocol-test", "--session", quiz.speech.session_path, "--id", quiz.speech.request_id]), output, true) == 0, "Signed Swift app launches and writes its actual result protocol")
	else:
		payload["id"] = quiz.speech.request_id
		var file := FileAccess.open(quiz.speech.session_path.path_join("status.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
	await frames()


func _run() -> void:
	var cases := {
		"C": 0, "Do": 0, "dough": 0, "D": 2, "Re": 2, "ray": 2,
		"E": 4, "Mi": 4, "F": 5, "Fa": 5, "G": 7, "Sol": 7, "So": 7,
		"A": 9, "La": 9, "B": 11, "Si": 11, "Ti": 11, "bee": 11,
		"see": 0, "dee": 2, "eff": 5, "gee": 7, "ay": 9,
		"B flat": 10, "降 Si": 10, "F sharp": 6, "升 Fa": 6,
		"G♭": 6, "F#": 6, "Bb": 10, "C sharp": 1, "升Do": 1,
		"E flat": 3, "降咪": 3, "G sharp": 8, "升Sol": 8,
		"B sharp": 0, "C flat": 11, "This is B.": 11, "It's a B!": 11,
		"這是升Fa": 6, "答案是降 Si": 10, "a sharp": 10, "a flat": 8
	}
	for text in cases:
		check(Answers.parse(text) == cases[text], "Parse letter/fixed-do answer: " + text)
	var letter_names := ["C", "C sharp", "D", "E flat", "E", "F", "F sharp", "G", "A flat", "A", "B flat", "B"]
	var solfege_names := ["Do", "升 Do", "Re", "降 Mi", "Mi", "Fa", "升 Fa", "Sol", "降 La", "La", "降 Si", "Ti"]
	for string_index in range(6):
		for fret in range(16):
			var pc: int = Theory.midi(Vector2i(string_index, fret)) % 12
			check(Answers.parse(letter_names[pc]) == pc and Answers.parse(solfege_names[pc]) == pc, "Every position accepts both letter names and fixed do")
	for invalid in ["", "I don't know", "maybe B or C", "do re mi", "B C", "C4", "sharp", "double sharp F", "升Fa flat", "Banana", "D minor", "C major"]:
		check(Answers.parse(invalid) == -1, "Do not guess from invalid/ambiguous phrase: " + invalid)
	check(Answers.from_recognition({"text": "B", "confidence": 0.1}) == -1, "Low confidence is not graded")
	check(Answers.from_recognition({"text": "B", "confidence": 0.9, "alternatives": ["C"]}) == -1, "Conflicting hypotheses are not graded")
	check(Answers.from_recognition({"text": "F sharp", "confidence": 0.9, "alternatives": ["G flat"]}) == 6, "Enharmonic hypotheses agree")
	app = Scene.instantiate()
	root.add_child(app)
	await frames()
	app.tone_player.set_muted(true)
	quiz = app.voice_quiz
	quiz.speech.launch_native = false
	check(not quiz.speech.active and not quiz.active, "No microphone/session on application load")
	await click(app.mode_buttons[3])
	check(app.mode == 3 and quiz.visible and quiz.active and quiz.board.read_quiz, "Real mode button opens independent sight-reading quiz")
	check(quiz.board.markers.is_empty() and quiz.board.conceal_answers and not quiz.board.show_notes, "Dot conceals the note identity")
	for panel in app.interval_panels:
		check(not panel.visible, "Root/interval UI does not reveal read-the-dot answer")
	for i in range(100):
		quiz._new_question()
		check(Theory.midi(quiz.target) % 12 in [0, 2, 4, 5, 7, 9, 11], "Beginner questions use natural notes")
	await click(quiz.natural_check)
	check(not quiz.natural_check.button_pressed, "Real toggle enables chromatic notes")
	quiz.target = Vector2i(1, 0) # B3; both B and Si/Ti must work.
	quiz.board.quiz_target = quiz.target
	quiz.board.queue_redraw()
	quiz.readout.text = "？  ·  2 弦 0 品"
	await capture("voice-question")
	var initial_mistakes: int = quiz.mistakes
	await result_file({"state": "result", "text": "B", "confidence": 0.1})
	check(not quiz.complete and quiz.mistakes == initial_mistakes and quiz.status.text.contains("不計錯"), "Unclear speech retries without penalty")
	await result_file({"state": "result", "text": "C", "confidence": 0.9})
	check(not quiz.complete and quiz.mistakes == initial_mistakes + 1 and quiz.heard.text.contains("C"), "Clear wrong note is displayed and counted once")
	await result_file({"state": "result", "text": "Si", "confidence": 0.9})
	check(quiz.complete and quiz.correct_count == 1 and not quiz.advance.is_stopped(), "Spoken fixed-do Si correctly answers B and schedules advancement")
	check(quiz.readout.text.contains("B3") and quiz.board.markers.has(quiz.target), "Success reveals actual note name")
	await capture("voice-correct")
	var old_target: Vector2i = quiz.target
	await create_timer(1.85).timeout
	check(not quiz.complete and quiz.target != old_target and quiz.board.markers.is_empty(), "Success automatically advances and conceals new answer")
	quiz.target = Vector2i(4, 1) # B♭2
	quiz.board.quiz_target = quiz.target
	if quiz.speech.available():
		await result_file({}, true)
		check(quiz.complete and quiz.correct_count == 2, "Native Swift protocol result B flat / A sharp reaches Godot judgement")
	else:
		check(false, "Build the native helper before running voice tests on macOS")
	await click(quiz.next_button)
	quiz.target = Vector2i(5, 2) # F♯2
	quiz.board.quiz_target = quiz.target
	quiz.typed_answer.text = "升 Fa"
	await click(quiz.submit_button)
	check(quiz.complete, "Chinese accidental and solfege can answer F sharp through real submit button")
	await click(quiz.next_button)
	app.tone_player.set_muted(false)
	await click(quiz.listen_button)
	check(quiz.helped, "Listening before answering marks assistance")
	check(app.tone_player.current_notes == [Theory.midi(quiz.target)] and app.tone_player.player.playing and quiz.board.sounding.has(quiz.target), "Listening hint really starts the correct pitch and display ring")
	app.tone_player.set_muted(true)
	quiz.typed_answer.text = Theory.NOTE_NAMES[Theory.midi(quiz.target) % 12]
	await click(quiz.submit_button)
	check(quiz.complete and quiz.assisted_count == 1, "Aided completion is scored separately")
	await click(quiz.next_button)
	await click(quiz.reveal_button)
	check(quiz.revealed and not quiz.complete and quiz.advance.is_stopped() and quiz.microphone.disabled, "Reveal is not scored or advanced")
	await click(quiz.next_button)
	await click(quiz.board, quiz.board.cell_center(quiz.target))
	check(quiz.board.named_positions == [quiz.target] and quiz.readout.text.contains(Theory.note_name(quiz.target)), "Real board click displays the note inside the quiz circle")
	check(quiz.helped and not quiz.complete, "Inspecting the quiz circle marks assistance instead of grading")
	await capture("voice-clicked-circle")
	await click(quiz.next_button)
	check(quiz.board.named_positions.is_empty(), "New voice question conceals the previous clicked note")
	await click(quiz.microphone)
	check(quiz.speech.active and not quiz.cancel_button.disabled, "Explicit microphone button starts session")
	var cancelled_path: String = quiz.speech.session_path
	await click(quiz.cancel_button)
	check(not quiz.speech.active and FileAccess.file_exists(cancelled_path.path_join("cancel")), "Cancel sends native stop command")
	DirAccess.remove_absolute(cancelled_path.path_join("cancel"))
	DirAccess.remove_absolute(cancelled_path)
	await click(quiz.microphone)
	var old_id: String = quiz.speech.request_id
	var stale_path: String = quiz.speech.session_path
	await click(quiz.next_button)
	check(not quiz.speech.active, "Manual next cancels microphone session")
	DirAccess.remove_absolute(stale_path.path_join("cancel"))
	DirAccess.remove_absolute(stale_path)
	check(quiz.speech.start(), "Start new generation")
	var file := FileAccess.open(quiz.speech.session_path.path_join("status.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"id": old_id, "state": "result", "text": "B", "confidence": 0.9}))
	file.close()
	await frames()
	check(quiz.speech.active and not quiz.complete, "Late previous-session result cannot grade the new question")
	var count_before_errors: int = quiz.mistakes
	for error_code in ["speech_denied", "microphone_denied", "offline_unavailable", "no_speech", "no_input", "recognition_error"]:
		var cancelled: String = quiz.speech.session_path
		quiz.speech.cancel()
		DirAccess.remove_absolute(cancelled.path_join("cancel"))
		DirAccess.remove_absolute(cancelled)
		await result_file({"state": "error", "code": error_code})
		check(not quiz.speech.active and not quiz.complete and quiz.mistakes == count_before_errors and not quiz.status.text.is_empty(), "Native permission/model/recognition error does not grade: " + error_code)
	check(quiz.speech.start(), "Start before leaving mode")
	var mode_path: String = quiz.speech.session_path
	await click(app.mode_buttons[0])
	check(not quiz.active and not quiz.speech.active and not quiz.visible and app.board.visible, "Leaving voice mode stops listening and restores interval UI")
	DirAccess.remove_absolute(mode_path.path_join("cancel"))
	DirAccess.remove_absolute(mode_path)
	app.queue_free()
	await frames()
	print("VOICE RESULT: %d checks, %d failures (no microphone access requested)" % [checks, failures])
	quit(1 if failures else 0)
