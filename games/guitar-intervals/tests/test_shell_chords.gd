extends SceneTree
## Musical oracles are independent of CHORDS; UI uses actual viewport clicks.
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Trainer = preload("res://src/trainer/trainer.tscn")
const CASES: Array[Dictionary] = [
	{"index": 4, "full": [0, 4, 7, 11], "answers": [4, 11], "full_names": "C – E – G – B", "played": "C – E – B", "role": "七度 · 7"},
	{"index": 5, "full": [0, 4, 7, 10], "answers": [4, 10], "full_names": "C – E – G – B♭", "played": "C – E – B♭", "role": "七度 · ♭7"},
	{"index": 6, "full": [0, 3, 7, 10], "answers": [3, 10], "full_names": "C – E♭ – G – B♭", "played": "C – E♭ – B♭", "role": "七度 · ♭7"},
	{"index": 7, "full": [0, 3, 7, 11], "answers": [3, 11], "full_names": "C – E♭ – G – B", "played": "C – E♭ – B", "role": "七度 · 7"},
	{"index": 8, "full": [0, 4, 7, 9], "answers": [4, 9], "full_names": "C – E – G – A", "played": "C – E – A", "role": "六度 · 6"},
	{"index": 9, "full": [0, 3, 7, 9], "answers": [3, 9], "full_names": "C – E♭ – G – A", "played": "C – E♭ – A", "role": "六度 · 6"},
]
var checks: int = 0
var failures: int = 0
var app: Control
var capture_dir: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	create_timer(35).timeout.connect(func() -> void:
		push_error("Shell chord tests timed out")
		quit(2)
	)
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame


func click(control: Control, local_point: Vector2 = Vector2.INF) -> void:
	if control is Button and not control.is_visible_in_tree() and control in app.mode_buttons:
		await click(app.practice_nav_button)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frames()
		ancestor = ancestor.get_parent()
	var point: Vector2 = control.get_global_rect().get_center() if local_point == Vector2.INF else control.global_position + local_point
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await frames()


func note(position: Vector2i) -> void:
	await click(app.board, app.board.cell_center(position))


func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	var ancestor: Node = app.task_panel.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(app.task_panel)
			await frames()
		ancestor = ancestor.get_parent()
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save shell exercise preview")


func model_checks() -> void:
	var c_root := Vector2i(4, 3)
	for item in CASES:
		check(Theory.CHORDS[item.index].full_tones == item.full, "Complete chord retains the fifth")
		check(" – ".join(Theory.chord_note_names(c_root, item.index)) == item.full_names, "Full C chord spelling")
		check(" – ".join(Theory.chord_note_names(c_root, item.index, true)) == item.played, "Played C shell spelling")
		for row in range(6):
			for fret in range(16):
				var origin := Vector2i(row, fret)
				for nearby in [true, false]:
					var voicings: Array[Array] = Theory.chord_voicings(origin, item.index, nearby)
					check(not voicings.is_empty(), "Every shell root and scope has at least one answer")
					for voicing in voicings:
						var third_delta: int = posmod(Theory.midi(voicing[0]) - Theory.midi(origin), 12)
						var other_delta: int = posmod(Theory.midi(voicing[1]) - Theory.midi(origin), 12)
						check(third_delta == item.answers[0] and other_delta == item.answers[1], "Generated positions match independent shell formula")
						check(voicing[0].x != origin.x and voicing[1].x != origin.x and voicing[0].x != voicing[1].x, "Each shell note occupies a different string")
						var fretted: Array[int] = []
						for position: Vector2i in [origin, voicing[0], voicing[1]]:
							check(not nearby or absi(position.y - origin.y) <= 4, "Shell respects root-centered range")
							if position.y > 0:
								fretted.append(position.y)
						check(fretted.is_empty() or fretted.max() - fretted.min() <= 4, "Shell respects fretted span even with unrestricted root range")
	var sharp_root := Vector2i(4, 4)
	check(Theory.chord_note_names(sharp_root, 4, true) == ["C♯", "E♯", "B♯"], "C sharp maj7 keeps functional E sharp and B sharp spelling")
	check(Theory.chord_note_names(sharp_root, 9, true) == ["C♯", "E", "A♯"], "Minor sixth still uses major sixth")


func _run() -> void:
	model_checks()
	app = Trainer.instantiate()
	root.add_child(app)
	await frames(5)
	await click(app.mode_buttons[2])
	for item in CASES:
		await click(app.chord_buttons[item.index])
		app.root_position = Vector2i(4, 3)
		app._reset_question()
		await frames()
		check(app.chord_index == item.index and app.chord_buttons[item.index].button_pressed, "Direct shell selection works")
		var selected: int = 0
		for button in app.chord_buttons:
			if button.button_pressed:
				selected += 1
		check(selected == 1, "Shell mode remains single choice")
		check(app.task_panel.full_composition_label.text.contains(item.full_names), "Question displays complete chord notes before answering")
		check(app.task_panel.voicing_label.text.contains(item.played) and app.task_panel.voicing_label.text.contains("省略五度（5）：G"), "Question separates played notes and omitted fifth")
		check(app.task_panel.tone_roles[2].text == item.role, "Final slot names sixth or seventh accurately")
		check(app.task_panel.tone_values[2].text == "？" and app.task_panel.progress_label.text == "已選 0 / 2 音", "Positions remain to be found and only two answers are required")
		var errors: int = app.mistake_count
		await note(Vector2i(2, 0)) # G3: a chord tone, but omitted in this exercise.
		check(app.mistake_count == errors + 1 and app.picked.is_empty() and app.feedback.contains("本題省略五度"), "Omitted fifth is rejected with an explanation of this voicing")
		if item.index == 9:
			errors = app.mistake_count
			await note(Vector2i(2, 1)) # A flat is not the sixth of Cm6.
			check(app.mistake_count == errors + 1 and app.picked.is_empty(), "Cm6 rejects flat sixth even though its third is minor")
		var voicing: Array = app._voicings()[0]
		await note(voicing[1])
		check(app.picked.size() == 1 and not app.question_complete and app.auto_advance_timer.is_stopped(), "Sixth or seventh may be selected first without completing")
		await note(voicing[1])
		check(app.picked.is_empty(), "Canceling sixth or seventh clears its selection")
		await click(app.hint_button)
		check(app.help_used and not app.revealed, "Shell hint remains a positional hint")
		await note(voicing[1])
		await click(app.play_group_button)
		check(app.tone_player.current_notes == [48, Theory.midi(voicing[1])], "Partial shell plays the actual root and chosen pitch")
		await note(voicing[0])
		check(app.question_complete and not app.auto_advance_timer.is_stopped(), "Both required shell tones complete and schedule next question")
		await click(app.play_group_button)
		check(app.tone_player.current_notes == [48, Theory.midi(voicing[1]), Theory.midi(voicing[0])], "Playback uses exactly the three selected pitches, including actual octaves")
		check(app.play_group_button.text == "播放三音", "Playback label applies to both triads and shells")
		if item.index == 5:
			await capture("01-C7-complete")
		await click(app.next_button)
		check(app.chord_index == item.index and not app.question_complete and not app._voicings().is_empty(), "New question retains shell type and remains solvable")
		await click(app.reveal_button)
		check(app.revealed and not app.question_complete and app.picked.size() == 2, "Reveal shows only required shell tones without awarding completion")
		for position in app.picked:
			check(item.answers.has(Theory.relative_pc(app.root_position, position)), "Reveal never inserts the omitted fifth")
	# Verify delayed transition and switching cancel the old timer for new types.
	await click(app.chord_buttons[9])
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await capture("02-Cm6-ready")
	var answer: Array = app._voicings()[0]
	await note(answer[0])
	await note(answer[1])
	var old_root: Vector2i = app.root_position
	await create_timer(1.8).timeout
	check(app.root_position != old_root and app.chord_index == 9 and app.picked.is_empty(), "Completed m6 automatically advances and clears positions")
	await click(app.chord_buttons[4])
	answer = app._voicings()[0]
	await note(answer[0])
	await note(answer[1])
	await click(app.chord_buttons[8])
	old_root = app.root_position
	await create_timer(1.8).timeout
	check(app.root_position == old_root and app.chord_index == 8 and app.picked.is_empty(), "Changing shell type cancels the previous timer")
	app.size = Vector2(1024, 900)
	app.position = Vector2.ZERO
	await frames(6)
	check(app.task_panel.sections.vertical, "Shell composition stacks in a narrow view")
	for section in app.task_panel.sections.get_children():
		check(section.get_global_rect().end.x <= app.size.x, "Composition stays within narrow viewport")
	await capture("03-sixth-narrow")
	await click(app.mode_buttons[0])
	check(not app.task_panel.full_composition_label.visible and not app.task_panel.voicing_label.visible, "Chord details do not leak into lookup")
	app.queue_free()
	await frames()
	print("SHELL CHORD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
