extends SceneTree
## Native state protocol and actual pointer states, without opening a microphone.
const Trainer = preload("res://src/trainer/trainer.tscn")
var app: Control
var quiz: Control
var checks: int = 0
var failures: int = 0
var capture_dir: String = ""
var test_phase: String = "setup"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	create_timer(50).timeout.connect(func() -> void:
		push_error("Voice workflow test timed out during " + test_phase)
		quit(2)
	)
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int = 4) -> void:
	for index in range(count):
		await process_frame


func point(control: Control) -> Vector2:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frames()
		ancestor = ancestor.get_parent()
	return control.get_global_rect().get_center()


func mouse(position: Vector2, pressed: int = -1) -> void:
	if pressed < 0:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		root.push_input(motion, true)
	else:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = bool(pressed)
		root.push_input(event, true)
	await frames()


func click(control: Control) -> void:
	if control is Button and not control.is_visible_in_tree() and control in app.mode_buttons:
		await click(app.practice_nav_button)
	var position: Vector2 = await point(control)
	await mouse(position)
	await mouse(position, 1)
	await mouse(position, 0)


func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await frames()
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save voice workflow state")


func write_state(payload: Dictionary) -> void:
	payload["id"] = quiz.speech.request_id
	var file := FileAccess.open(quiz.speech.session_path.path_join("status.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	await frames()


func wait_phase(phase: String, seconds: float = 3.0) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while quiz.speech.phase != phase and Time.get_ticks_msec() < until:
		await create_timer(0.05).timeout
	return quiz.speech.phase == phase


func launch_workflow_fixture() -> void:
	var args := PackedStringArray(["-n", "-g", ProjectSettings.globalize_path("res://build/NoteSpeech.app"), "--args", "--workflow-test", "--session", quiz.speech.session_path, "--id", quiz.speech.request_id])
	check(OS.create_process("/usr/bin/open", args) > 0, "Launch actual signed app workflow without microphone access")


func readable_button() -> void:
	for style in ["normal", "hover", "pressed", "hover_pressed"]:
		var box: StyleBoxFlat = quiz.microphone.get_theme_stylebox(style)
		var font_key: String = "font_color" if style == "normal" else "font_" + style + "_color"
		var ink: Color = quiz.microphone.get_theme_color(font_key)
		var light: float = maxf(box.bg_color.srgb_to_linear().get_luminance(), ink.srgb_to_linear().get_luminance())
		var dark: float = minf(box.bg_color.srgb_to_linear().get_luminance(), ink.srgb_to_linear().get_luminance())
		check((light + 0.05) / (dark + 0.05) >= 4.5, "Voice button text remains readable in " + style)
	var normal: Color = quiz.microphone.get_theme_stylebox("normal").bg_color
	var hover: Color = quiz.microphone.get_theme_stylebox("hover").bg_color
	check(normal.s > 0.4 and hover.s > 0.4 and absf(normal.h - hover.h) < 0.08, "Hover keeps the current action's color family")


func clear_cancelled(path: String) -> void:
	for filename in ["cancel", "status.json", "finish"]:
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)


func _run() -> void:
	app = Trainer.instantiate()
	root.add_child(app)
	await frames()
	quiz = app.voice_quiz
	quiz.speech.launch_native = false
	app.tone_player.set_muted(true)
	await click(app.mode_buttons[3])
	quiz.target = Vector2i(4, 1) # B flat, the native workflow fixture's final result.
	quiz.board.quiz_target = quiz.target
	quiz.board.queue_redraw()
	check(quiz.speech.phase == "idle" and not quiz.speech.active and not quiz.microphone.disabled, "Idle is explicitly not recording")
	readable_button()
	await mouse(Vector2(20, 20))
	await capture("01-ready")
	var mic_point: Vector2 = await point(quiz.microphone)
	await mouse(mic_point)
	check(quiz.microphone.get_draw_mode() == BaseButton.DRAW_HOVER, "Pointer produces the actual hover state")
	await capture("02-ready-hover")
	await mouse(mic_point, 1)
	check(quiz.microphone.get_draw_mode() == BaseButton.DRAW_PRESSED and not quiz.speech.active, "Pressed appearance is visible before the release starts preparation")
	await capture("03-ready-pressed")
	await mouse(mic_point, 0)
	check(quiz.speech.phase == "preparing" and quiz.microphone.disabled and quiz.voice_stage.text.contains("準備"), "First click prepares input and does not falsely tell the user to speak")
	quiz.speech.finish()
	check(not FileAccess.file_exists(quiz.speech.session_path.path_join("finish")), "Cannot finish an input device that is not ready")
	await capture("04-preparing")
	launch_workflow_fixture()
	test_phase = "native manual recording"
	check(await wait_phase("listening"), "Native ready acknowledgement enables speaking")
	check(quiz.voice_stage.text == "請開始說話" and not quiz.microphone.disabled and quiz.microphone.text.contains("說完了"), "Ready input gives an explicit start cue and stop button")
	check(quiz.input_meter.value > 0 and quiz.meter_caption.text.contains("剩餘") and not quiz.typed_answer.editable, "Recording shows its meter and limit while blocking competing answer input")
	readable_button()
	await mouse(await point(quiz.microphone))
	await capture("05-listening-hover")
	check(not quiz.complete, "No answer is graded while the user is recording")
	await click(quiz.microphone)
	check(quiz.speech.phase in ["stopping", "processing"] and quiz.microphone.disabled and quiz.voice_stage.text in ["請停止說話", "收音已停止"], "Stop click asks user to stop and cannot be submitted twice")
	check(await wait_phase("processing"), "Native stop acknowledgement moves to recognition")
	check(quiz.voice_stage.text == "收音已停止" and quiz.input_meter.value == 0 and quiz.microphone.disabled, "Recognition explicitly confirms the microphone is off")
	await capture("06-processing")
	check(await wait_phase("idle") and quiz.complete and quiz.correct_count == 1, "Final native workflow result reaches grading only after stop")
	print("PASS: actual ready, hover, press and native manual stop workflow")
	test_phase = "late packets and retry"
	await create_timer(1.8).timeout
	await click(quiz.microphone)
	await write_state({"state": "listening", "level": 0.25, "remaining_seconds": 8})
	quiz.speech.finish()
	await write_state({"state": "listening", "level": 0.3, "remaining_seconds": 7})
	check(quiz.speech.phase == "stopping" and quiz.microphone.disabled, "Late level updates cannot reopen recording after Stop")
	await write_state({"state": "partial", "text": "B"})
	check(quiz.speech.phase == "processing" and quiz.voice_stage.text == "收音已停止", "First partial acknowledges stop even when the processing packet was replaced")
	var mistakes: int = quiz.mistakes
	await write_state({"state": "error", "code": "silent_input"})
	check(quiz.speech.phase == "error" and quiz.status.visible and quiz.status.text.contains("音量") and quiz.mistakes == mistakes, "Silent input explains what to check and does not penalize")
	check(not quiz.microphone.disabled and quiz.microphone.text.contains("重新錄音"), "Failure clearly offers retry")
	readable_button()
	await capture("07-retry")
	await click(quiz.microphone)
	var cancelled: String = quiz.speech.session_path
	await click(quiz.cancel_button)
	check(not quiz.speech.active and quiz.voice_stage.text.contains("已取消"), "Cancel produces an explicit non-recording state")
	clear_cancelled(cancelled)
	print("PASS: late packets, missing stop acknowledgement, silent input and cancel")
	# Native timer path uses the same ten-second limit as real recording.
	quiz.target = Vector2i(4, 1)
	await click(quiz.microphone)
	launch_workflow_fixture()
	test_phase = "native ten-second recording limit"
	check(await wait_phase("listening"), "Second native session is ready")
	check(await wait_phase("processing", 11.0), "Ten-second recording limit stops input automatically")
	check(quiz.voice_stage.text == "收音已停止", "Time limit has the same visible stop confirmation")
	check(await wait_phase("idle") and quiz.complete, "Time-limited native session still completes normal grading")
	print("PASS: native ten-second limit and final grading")
	await click(quiz.next_button)
	await click(quiz.microphone)
	var mode_path: String = quiz.speech.session_path
	await click(app.mode_buttons[0])
	check(not quiz.speech.active and quiz.speech.phase == "idle", "Leaving voice mode stops and resets the workflow")
	clear_cancelled(mode_path)
	check(quiz.speech.start(), "Create a session cancelled before native launch")
	var early_path: String = quiz.speech.session_path
	var early_id: String = quiz.speech.request_id
	quiz.speech.cancel()
	var output: Array = []
	var bundle := ProjectSettings.globalize_path("res://build/NoteSpeech.app")
	check(OS.execute("/usr/bin/open", PackedStringArray(["-W", "-n", "-g", bundle, "--args", "--workflow-test", "--session", early_path, "--id", early_id]), output, true) == 0 and not DirAccess.dir_exists_absolute(early_path), "Native app honors pre-launch cancellation without starting capture")
	app.queue_free()
	await frames()
	print("VOICE FLOW RESULT: %d checks, %d failures (native protocol fixture, no microphone access)" % [checks, failures])
	quit(1 if failures else 0)
