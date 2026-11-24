extends SceneTree
## Independent sus formulas, grouped choices and real viewport/audio interaction.
const Theory = preload("res://src/theory/fretboard_theory.gd")
const Trainer = preload("res://src/trainer/trainer.tscn")
const CASES: Array[Dictionary] = [
	{"index": 10, "semitones": 2, "notes": "C – D – G", "role": "二度 · 2", "replace": "二度", "first": Vector2i(3, 0), "midi": 50},
	{"index": 11, "semitones": 5, "notes": "C – F – G", "role": "四度 · 4", "replace": "四度", "first": Vector2i(3, 3), "midi": 53},
]
var app: Control
var checks: int = 0
var failures: int = 0
var capture_dir: String = ""
var audio_capture: AudioEffectCapture


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	create_timer(30).timeout.connect(func() -> void:
		push_error("Sus tests timed out")
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


func show(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frames()
		ancestor = ancestor.get_parent()


func click(control: Control, local_point: Vector2 = Vector2.INF) -> void:
	if control is Button and not control.is_visible_in_tree() and control in app.mode_buttons:
		await click(app.practice_nav_button)
	await show(control)
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


func capture(name: String, focus: Control) -> void:
	if capture_dir.is_empty():
		return
	await show(focus)
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save grouped sus preview")


func single_choice(expected: int) -> void:
	var count: int = 0
	for index in range(app.chord_buttons.size()):
		if app.chord_buttons[index].button_pressed:
			count += 1
			check(index == expected, "Selected chord matches the current question across groups")
	check(count == 1 and app.chord_index == expected, "Exactly one chord remains selected across both groups")


func model_checks() -> void:
	for item in CASES:
		var count: int = 0
		for row in range(6):
			for fret in range(16):
				var origin := Vector2i(row, fret)
				for nearby in [true, false]:
					var voicings: Array[Array] = Theory.chord_voicings(origin, item.index, nearby)
					check(not voicings.is_empty(), "Sus has an answer for every root and scope")
					for voicing in voicings:
						count += 1
						check(posmod(Theory.midi(voicing[0]) - Theory.midi(origin), 12) == item.semitones, "First tone is a second or fourth, never a third")
						check(posmod(Theory.midi(voicing[1]) - Theory.midi(origin), 12) == 7, "Sus retains the perfect fifth")
						check(voicing[0].x != row and voicing[1].x != row and voicing[0].x != voicing[1].x, "Three different strings")
						var fretted: Array[int] = []
						for position: Vector2i in [origin, voicing[0], voicing[1]]:
							check(not nearby or absi(position.y - fret) <= 4, "Sus respects local range")
							if position.y > 0:
								fretted.append(position.y)
						check(fretted.is_empty() or fretted.max() - fretted.min() <= 4, "Sus respects fretted span")
		check(count > 0, "Exhaustive musical checks are not vacuous")
	check(Theory.chord_note_names(Vector2i(4, 4), 10) == ["C♯", "D♯", "G♯"], "C sharp sus2 functional spelling")
	check(Theory.chord_note_names(Vector2i(4, 4), 11) == ["C♯", "F♯", "G♯"], "C sharp sus4 functional spelling")


func check_audio() -> void:
	await create_timer(0.25).timeout
	var samples: PackedVector2Array = audio_capture.get_buffer(audio_capture.get_frames_available())
	var peak: float = 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(samples.size() > 1000 and peak > 0.001, "Sus playback produces actual audio bus samples")


func _run() -> void:
	model_checks()
	app = Trainer.instantiate()
	root.add_child(app)
	await frames(5)
	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "SusTest")
	audio_capture = AudioEffectCapture.new()
	audio_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_index, audio_capture)
	app.tone_player.player.bus = "SusTest"
	await click(app.mode_buttons[2])
	check(app.chord_section_labels.size() == 2 and app.chord_section_labels[0].text.contains("基礎／掛留") and app.chord_section_labels[1].text.contains("七／六和弦"), "Existing choices have two named groups")
	check(app.chord_sections[0].get_child_count() == 6 and app.chord_sections[1].get_child_count() == 6, "All twelve options belong to exactly one group")
	for index in range(12):
		var expected_group: int = 0 if index < 4 or index >= 10 else 1
		check(app.chord_buttons[index].get_parent() == app.chord_sections[expected_group], "Each chord is in its intended group")
	for item in CASES:
		await click(app.chord_buttons[item.index])
		app.root_position = Vector2i(4, 3)
		app._reset_question()
		await frames()
		single_choice(item.index)
		check(app.instruction_label.text.contains(item.replace) and not app.instruction_label.text.contains("三度"), "Sus instruction requests the right replacement interval")
		check(app.task_panel.full_composition_label.text.contains(item.notes) and app.task_panel.voicing_label.text.contains(item.notes), "Both full composition and played notes are visible")
		check(app.task_panel.voicing_label.text.contains("以%s取代三度" % item.replace) and not app.task_panel.voicing_label.text.contains("省略五度"), "Sus explains replacement rather than omission")
		check(app.task_panel.tone_roles[1].text == item.role and app.task_panel.tone_roles[2].text == "五度 · 5", "Slots show second or fourth and perfect fifth")
		await capture("%d-ready" % item.index, app.task_panel)
		var mistakes: int = app.mistake_count
		for wrong in [Vector2i(3, 2), Vector2i(3, 1)]: # E3 / E flat3.
			await note(wrong)
		check(app.picked.is_empty() and app.mistake_count == mistakes + 2, "Neither major nor minor third can answer a suspended chord")
		await note(Vector2i(2, 0)) # G3 may be selected first.
		check(app.picked.size() == 1 and not app.question_complete, "Fifth first remains a partial answer")
		await note(Vector2i(2, 0))
		check(app.picked.is_empty(), "Fifth can be canceled")
		await note(item.first)
		check(app.tone_player.current_notes == [item.midi] and app.board.named_positions.has(item.first), "Click auditions and labels the actual sus tone")
		await click(app.play_group_button)
		check(app.tone_player.current_notes == [48, item.midi], "Partial sus can be heard as a dyad")
		await note(Vector2i(2, 0))
		check(app.question_complete and app.picked.size() == 2 and not app.auto_advance_timer.is_stopped(), "Second or fourth plus fifth completes the three-note chord")
		audio_capture.clear_buffer()
		await click(app.play_group_button)
		check(app.tone_player.current_notes == [48, item.midi, 55], "Sus plays exactly C3 D3/F3 G3 without a third")
		await check_audio()
		await capture("%d-complete" % item.index, app.task_panel)
		await click(app.next_button)
		check(app.chord_index == item.index and app.picked.is_empty(), "Next question preserves selected sus type")
		await click(app.hint_button)
		check(app.help_used and not app.revealed, "Sus supports position hints")
		await click(app.reveal_button)
		check(app.revealed and not app.question_complete and app.picked.size() == 2, "Reveal supplies only the two missing sus positions")
		for position in app.picked:
			check([item.semitones, 7].has(Theory.relative_pc(app.root_position, position)), "Revealed sus contains no third")
	# Switching groups cancels any old question and preserves one global choice.
	await click(app.chord_buttons[5])
	single_choice(5)
	check(app.task_panel.voicing_label.text.contains("省略五度"), "Seventh group retains shell explanation")
	await click(app.chord_buttons[10])
	single_choice(10)
	check(not app.task_panel.voicing_label.text.contains("省略五度") and app.picked.is_empty(), "Returning to sus clears previous chord selections and omission text")
	await click(app.mode_buttons[0])
	check(not app.chord_choices.visible, "Grouped choices hide during lookup")
	await click(app.mode_buttons[2])
	single_choice(10)
	await capture("groups-desktop", app.chord_choices)
	app.size = Vector2(1024, 900)
	app.position = Vector2.ZERO
	await frames(6)
	for button in app.chord_buttons:
		check(button.size.y >= 44 and button.get_global_rect().end.x <= app.size.x, "Grouped keys stay readable and within narrow width")
	await capture("groups-narrow", app.chord_choices)
	app.queue_free()
	await frames()
	AudioServer.remove_bus(bus_index)
	print("SUS CHORD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
