extends SceneTree
## Run: Godot --headless --path games/guitar-intervals --script res://tests/test_runner.gd
## Omit --headless and add -- --capture-dir=/tmp/fret-relations for rendered previews.

const Theory = preload("res://src/theory/fretboard_theory.gd")
const TrainerScene = preload("res://src/trainer/trainer.tscn")
const TonePlayer = preload("res://src/audio/tone_player.gd")
var failures: int = 0
var checks: int = 0
var app: Control
var capture_dir: String = ""
var audio_capture: AudioEffectCapture


func _initialize() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		push_error("FAIL: test run exceeded 40 seconds")
		quit(1)
	)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame


func _click_at(point: Vector2, double_click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.double_click = double_click and pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await _frames()
		ancestor = ancestor.get_parent()
	await _click_at(control.get_global_rect().get_center())


func _note(position: Vector2i) -> void:
	var ancestor: Node = app.board.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(app.board)
			await _frames()
		ancestor = ancestor.get_parent()
	await _click_at(app.board.global_position + app.board.cell_center(position))


func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await _frames()
	# An unchanged/occluded window may not emit another frame_post_draw signal.
	# Render explicitly after layout so static selection screens cannot stall QA.
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image: Image = root.get_texture().get_image()
	_check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Save rendered " + name)


func _double_note(position: Vector2i) -> void:
	await _note(position)
	await _click_at(app.board.global_position + app.board.cell_center(position), true)


func _theory_tests() -> void:
	_check(Theory.note_name(Vector2i(5, 0)) == "E2", "Low open E2")
	_check(Theory.note_name(Vector2i(0, 0)) == "E4", "High open E4")
	_check(Theory.relative_pc(Vector2i(2, 5), Vector2i(1, 5)) == 4, "G/B crossing is a major third")
	_check(Theory.relative_pc(Vector2i(3, 5), Vector2i(2, 5)) == 5, "D/G crossing is a fourth")
	var c_root := Vector2i(4, 3)
	_check(Theory.note_name(c_root) == "C3", "Initial C3 root")
	_check(Theory.candidates(c_root, 4).has(Vector2i(3, 2)), "C3 to E3 is major third")
	_check(Theory.candidates(c_root, 9).has(Vector2i(2, 2)), "C3 to A3 is major sixth")
	_check(not Theory.candidates(c_root, 0).has(c_root), "Root excluded from unison/octave answers")
	_check(Theory.candidates(c_root, 0).has(Vector2i(1, 1)), "Octave C4 accepted")
	_check(Theory.relative_pc(c_root, Vector2i(5, 0)) == 4, "Lower E2 belongs to relative major-third pitch class")
	_check(not Theory.in_scope(Vector2i(4, 8), Vector2i(0, 3), true), "Local range excludes five-fret offset")
	_check(Theory.in_scope(Vector2i(4, 8), Vector2i(0, 4), true), "Local range includes four-fret offset")
	_check(Theory.spelled_note(c_root, 8, 4) == "G♯", "Augmented fifth spelled G sharp")
	_check(Theory.spelled_note(c_root, 8, 5) == "A♭", "Minor sixth spelled A flat")
	_check(Theory.spelled_note(Vector2i(4, 4), 4, 2) == "E♯", "C sharp major uses E sharp")
	_check(Theory.spelled_note(Vector2i(3, 6), 6, 4) == "E♭♭", "A flat diminished fifth uses E double flat")
	_check(Theory.triad_voicings(c_root, 0).has([Vector2i(3, 2), Vector2i(2, 0)]), "C E G golden voicing")
	_check(Theory.triad_voicings(Vector2i(5, 0), 1).has([Vector2i(2, 0), Vector2i(1, 0)]), "All-open E minor voicing")
	for string_index in range(6):
		for fret in range(Theory.LAST_FRET + 1):
			var root_position := Vector2i(string_index, fret)
			for nearby in [true, false]:
				for interval in range(12):
					var candidates: Array[Vector2i] = Theory.candidates(root_position, interval, nearby)
					_check(not candidates.is_empty(), "Every dyad question has an answer")
					for candidate in candidates:
						_check(candidate != root_position and Theory.is_position_valid(candidate), "Answer bounds and root exclusion")
						_check(posmod(Theory.midi(candidate) - Theory.midi(root_position), 12) == interval, "Pitch class correct")
						_check(not nearby or absi(candidate.y - fret) <= 4, "Range correct")
				for chord_index in range(4):
					for voicing in Theory.triad_voicings(root_position, chord_index, nearby):
						_check(voicing[0].x != string_index and voicing[1].x != string_index and voicing[0].x != voicing[1].x, "Three distinct strings")
						_check(Theory.relative_pc(root_position, voicing[0]) == Theory.TRIADS[chord_index].tones[0], "Triad third correct")
						_check(Theory.relative_pc(root_position, voicing[1]) == Theory.TRIADS[chord_index].tones[1], "Triad fifth correct")
	print("PASS: theory, 96 roots × 12 pitch classes × 2 scopes; four triad qualities")


func _spectral_amplitude(samples: PackedFloat32Array, hz: float, start: int, count: int) -> float:
	# Goertzel detection validates the generated PCM, independently of UI metadata.
	var coefficient: float = 2.0 * cos(TAU * hz / 44100.0)
	var previous: float = 0.0
	var previous2: float = 0.0
	for index in range(start, start + count):
		var value: float = samples[index] + coefficient * previous - previous2
		previous2 = previous
		previous = value
	return 2.0 * sqrt(maxf(0.0, previous * previous + previous2 * previous2 - coefficient * previous * previous2)) / count


func _audio_model_tests() -> void:
	var synth := TonePlayer.new()
	root.add_child(synth)
	_check(is_equal_approx(TonePlayer.frequency(69), 440.0), "A4 tuning reference 440 Hz")
	_check(absf(TonePlayer.frequency(40) - 82.406889) < 0.0001, "Low E2 frequency")
	var cases: Array[Array] = [[69], [48, 52], [48, 52, 55], [48, 51, 55], [48, 51, 54], [48, 52, 56], [40, 64], [48, 48, 48]]
	for notes in cases:
		var typed_notes: Array[int] = []
		typed_notes.assign(notes)
		var stream: AudioStreamWAV = synth.stream_for(typed_notes)
		_check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate == 44100 and not stream.stereo, "16-bit mono PCM reference stream")
		var data: PackedByteArray = stream.data
		var samples := PackedFloat32Array()
		samples.resize(data.size() / 2)
		var peak: float = 0.0
		for index in range(samples.size()):
			samples[index] = data.decode_s16(index * 2) / 32768.0
			peak = maxf(peak, absf(samples[index]))
		_check(peak > 0.05 and peak < 0.73, "Audible non-clipping signal, including unison")
		_check(absf(samples[0]) < 0.0001 and absf(samples[-1]) < 0.0001, "Smooth silent endpoints")
		for note: int in notes:
			_check(_spectral_amplitude(samples, TonePlayer.frequency(note), 1000, 10000) > 0.045, "Every chord voice is present in the initial 250ms window")
		if notes.size() == 1:
			_check(_spectral_amplitude(samples, 440.0, 4410, 22050) > 8.0 * _spectral_amplitude(samples, 450.0, 4410, 22050), "A4 PCM has the expected pitch, not a neighboring frequency")
		if not capture_dir.is_empty() and (notes == [69] or notes == [48, 52] or notes == [48, 52, 55]):
			DirAccess.make_dir_recursive_absolute(capture_dir)
			var filename: String = {1: "single-a4", 2: "dyad-c-e", 3: "triad-c-e-g"}[notes.size()]
			_check(stream.save_to_wav(capture_dir.path_join(filename + ".wav")) == OK, "Export audio preview " + filename)
	_check(synth.stream_for([]) == null and synth.stream_for([-1]) == null and synth.stream_for([48, 52, 55, 60]) == null, "Reject invalid note groups")
	synth.queue_free()
	print("PASS: PCM pitch spectra, simultaneous voices, four triad qualities, octave register, envelopes and clipping")


func _ui_tests() -> void:
	app = TrainerScene.instantiate()
	root.add_child(app)
	app.tone_player.set_muted(true)
	await _frames(5)
	_check(app.mode == 0 and app.board.markers.size() > 0, "Lookup starts with answers")
	_check(app.board.size.x >= 900 and app.board.size.y >= 280, "Fretboard has usable dimensions")
	await _capture("01-lookup")
	await _click(app.root_placement_button)
	await _note(Vector2i(2, 5))
	_check(app.root_position == Vector2i(2, 5), "Real board click changes root")
	_check(not app.placing_root, "Root placement returns to audition mode")
	_check(app.root_label.text.contains("C4") and app.root_label.text.contains("3 弦 5 品"), "Root summary shows actual note and position")
	await _click(app.mode_buttons[1])
	_check(app.mode == 1 and app.board.markers.is_empty(), "Dyad hides answers")
	_check(app.board.conceal_answers and app.notes_check.disabled, "Practice hides note-name assistance")
	await _note(app.root_position)
	_check(app.mistake_count == 0 and not app.question_complete, "Root click is not an answer or a mistake")
	await _note(Vector2i(0, 15))
	_check(app.mistake_count == 0, "Out-of-scope click ignored")
	await _note(Vector2i(2, 6))
	_check(app.mistake_count == 1 and not app.question_complete, "Wrong answer gives retry")
	await _capture("02-dyad-retry")
	await _note(Vector2i(1, 5))
	_check(app.question_complete and app.completed_count == 1, "Real dyad answer completes question")
	await _note(Vector2i(1, 5))
	_check(app.completed_count == 1, "Completed question cannot be counted twice")
	var previous: Vector2i = app.root_position
	await _click(app.next_button)
	_check(app.root_position != previous and not app.question_complete, "Next question has a different root and clears result")
	await _click(app.hint_button)
	_check(app.help_used, "Hint records assistance")
	await _note(app._valid_answers()[0])
	_check(app.assisted_count == 1 and app.completed_count == 1, "Assisted answer counted separately")
	await _click(app.next_button)
	await _click(app.reveal_button)
	_check(app.revealed and not app.question_complete and not app.board.markers.is_empty(), "Reveal shows answers without awarding completion")
	await _click(app.mode_buttons[2])
	_check(app.mode == 2 and app.chord_choices.visible and not app.interval_choices.visible, "Triad choices shown")
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	await _note(Vector2i(4, 7))
	_check(app.mistake_count == 2 and app.picked.is_empty(), "Triad rejects a chord tone on the root string")
	await _note(Vector2i(3, 2))
	_check(app.picked.size() == 1 and not app.question_complete, "Third accepted")
	await _note(Vector2i(3, 2))
	_check(app.picked.is_empty(), "Selected note can be undone")
	await _note(Vector2i(2, 0))
	await _note(Vector2i(3, 2))
	_check(app.question_complete and app.completed_count == 2, "Triad accepts fifth before third")
	_check(app.formula_label.text.contains("C – E – G"), "Completion reveals correctly spelled chord")
	await _capture("03-triad-complete")
	for chord_index in range(4):
		app._on_chord_changed(chord_index)
		app._new_question()
		_check(not app._voicings().is_empty(), "Generated chord question solvable")
		await _frames()
		var voicing: Array = app._voicings()[0]
		await _note(voicing[0])
		await _note(voicing[1])
		_check(app.question_complete, "All four triad qualities accept valid answers")
	app._set_mode(0)
	for interval in range(12):
		app._on_interval_changed(interval)
		_check(app.board.markers.size() == Theory.candidates(app.root_position, interval, app.nearby).size(), "Lookup markers match selected interval")
	app._on_interval_changed(9)
	await _frames()
	await _click(app.nearby_check)
	_check(not app.nearby and not app.board.nearby, "Range toggle updates board and model")
	await _click(app.notes_check)
	_check(app.board.show_notes, "Note names toggle works")
	app._set_mode(1)
	_check(app.board.conceal_answers and app.notes_check.disabled, "Note-name preference cannot leak answers into practice")
	print("PASS: real viewport mouse events, lookup, wrong/retry, hints, reveal, random questions, all triad qualities")


func _check_audio_output(description: String) -> void:
	await create_timer(0.25).timeout
	var frames: PackedVector2Array = audio_capture.get_buffer(audio_capture.get_frames_available())
	var peak: float = 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	_check(frames.size() > 1000 and peak > 0.001, "Real audio bus emits samples: " + description)


func _audio_ui_tests() -> void:
	var bus_index: int = AudioServer.bus_count
	var master_volume: float = AudioServer.get_bus_volume_db(0)
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "AuditionTest")
	audio_capture = AudioEffectCapture.new()
	audio_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_index, audio_capture)
	app.tone_player.player.bus = "AuditionTest"
	app._set_mode(0)
	app.root_position = Vector2i(4, 3)
	app.interval_index = 4
	app.nearby = true
	app.nearby_check.set_pressed_no_signal(true)
	app.notes_check.set_pressed_no_signal(false)
	app._reset_question()
	app.tone_player.set_muted(false)
	await _frames()
	await _note(Vector2i(3, 2))
	_check(app.root_position == Vector2i(4, 3) and app.audition_target == Vector2i(3, 2), "Audition preserves root and selects a concrete dyad position")
	_check(app.tone_player.current_notes == [52] and app.board.sounding == [Vector2i(3, 2)], "Board click plays actual E3 and highlights its position")
	_check(app.note_readout.text == "音名：E3（4 弦 · 2 品）", "Clicked note name, octave and location shown immediately")
	_check(app.board.named_positions == [Vector2i(3, 2)], "Clicked circle carries its actual note label")
	await _capture("06-clicked-note-name")
	await _check_audio_output("single E3")
	app.tone_player.stop()
	await _frames()
	_check(app.board.named_positions == [Vector2i(3, 2)] and app.board.sounding.is_empty(), "Circle note name remains after playback stops")
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 52] and app.board.sounding.size() == 2, "Lookup plays C3 and E3 together")
	_check(app.note_readout.text.contains("C3") and app.note_readout.text.contains("E3"), "Dyad shows both actual note names")
	_check(app.board.named_positions.size() == 2, "Simultaneous notes each have a circle label")
	await _check_audio_output("dyad C3 E3")
	await _capture("04-dyad-audio")
	await _note(Vector2i(5, 0))
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 40], "Lower E2 position stays below C3; playback does not fold octaves")
	_check(app.note_readout.text.contains("E2") and not app.note_readout.text.contains("E3"), "Readout preserves actual octave")
	await _click(app.mode_buttons[1])
	_check(app.play_group_button.disabled and app.board.sounding.is_empty(), "New question stops sound and hides unselected answer from group playback")
	_check(not app.note_readout.text.contains("E2"), "Changing question clears previous note readout")
	_check(app.board.named_positions.is_empty(), "New question removes previous circle labels")
	await _click(app.play_root_button)
	_check(app.tone_player.current_notes == [48], "Root can be auditioned during practice")
	_check(app.note_readout.text == "音名：C3（5 弦 · 3 品）", "Root audition shows note name in practice")
	await _note(Vector2i(3, 2))
	_check(app.question_complete, "Audio preserves dyad grading")
	var completed: int = app.completed_count
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 52] and app.completed_count == completed, "Replay does not change score")
	await _note(Vector2i(5, 0))
	_check(app.tone_player.current_notes == [40] and app.completed_count == completed, "Completed question still allows single-note listening without regrading")
	_check(app.note_readout.text == "音名：E2（6 弦 · 0 品）", "Completed question still updates clicked note name")
	await _click(app.next_button)
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	await _click(app.reveal_button)
	await _note(Vector2i(5, 0))
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 40] and app.completed_count == completed, "Revealed dyad auditions the clicked voicing without awarding credit")
	await _click(app.mode_buttons[2])
	app.chord_index = 0
	app._reset_question()
	await _frames()
	await _note(Vector2i(3, 2))
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 52], "Partial triad can be heard as a dyad")
	await _note(Vector2i(2, 0))
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes == [48, 52, 55] and app.play_group_button.text == "播放三和弦", "Full triad plays all three actual pitches")
	_check(app.note_readout.text.contains("C3") and app.note_readout.text.contains("E3") and app.note_readout.text.contains("G3"), "Triad shows all three actual note names")
	var completed_triad_root: Vector2i = app.root_position
	await _check_audio_output("triad C3 E3 G3")
	await _capture("05-triad-audio")
	await _click(app.mute_button)
	_check(app.tone_player.muted and not app.tone_player.player.playing and app.board.sounding.is_empty(), "Mute immediately stops sound and clears highlights")
	await _note(Vector2i(0, 0))
	_check(app.tone_player.current_notes.is_empty(), "Muted clicks cannot start sound")
	_check(app.note_readout.text == "音名：E4（1 弦 · 0 品）", "Muted click still shows note identity")
	_check(app.board.named_positions == [Vector2i(0, 0)], "Muted click still labels its circle")
	await _click(app.mute_button)
	app.volume_slider.value = 0
	await _click(app.play_group_button)
	_check(app.tone_player.volume_percent == 0.0 and not app.tone_player.player.playing, "Zero volume is silent")
	app.volume_slider.value = 70
	await _click(app.play_group_button)
	_check(app.tone_player.current_notes.size() == 3 and app.tone_player.player.playing, "Restoring volume allows playback")
	await create_timer(1.75).timeout
	_check(app.board.sounding.is_empty() and app.tone_player.current_notes.is_empty(), "Playback completion clears all highlights")
	_check(app.root_position != completed_triad_root and not app.question_complete and app.note_readout.text == "點選指板，查看音名與八度", "Completed triad advances automatically and clears previous note names")
	await _click(app.next_button)
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	await _note(Vector2i(4, 4))
	_check(app.note_readout.text == "音名：C♯3（5 弦 · 4 品）" and app.picked.is_empty(), "Wrong practice answer shows the clicked accidental without selecting it")
	app.tone_player.stop()
	await create_timer(0.1).timeout
	_check(AudioServer.get_bus_volume_db(0) == master_volume, "App volume does not change the master bus")
	app.tone_player.player.bus = "Master"
	AudioServer.remove_bus(bus_index)
	print("PASS: actual audio bus output, clicked MIDI pitches, dyads, triads, partial chords, mute, volume, score and highlight lifecycle")


func _auto_advance_tests() -> void:
	app.tone_player.set_muted(true)
	app._set_mode(1)
	app.root_position = Vector2i(4, 3)
	app.interval_index = 4
	app._reset_question()
	await _frames()
	var start_root: Vector2i = app.root_position
	var score: int = app.completed_count
	await _note(Vector2i(4, 4))
	await create_timer(1.8).timeout
	_check(app.root_position == start_root and not app.question_complete and app.auto_advance_timer.is_stopped(), "Wrong answer stays on the same question")
	await _note(Vector2i(3, 2))
	_check(app.question_complete and app.completed_count == score + 1, "Correct dyad counted immediately")
	_check(app.instruction_label.text.contains("答對了") and app.feedback_label.text.contains("自動進入下一題"), "Correct answer gives explicit success feedback")
	await _note(Vector2i(3, 2))
	await create_timer(0.3).timeout
	_check(app.question_complete and app.root_position == start_root and app.completed_count == score + 1, "Feedback stays visible briefly; repeated clicks cannot award more credit")
	await _capture("07-correct-answer-feedback")
	await create_timer(1.6).timeout
	_check(app.root_position != start_root and not app.question_complete and app.picked.is_empty(), "Correct dyad advances without pressing Next")
	_check(app.interval_index == 4 and app.completed_count == score + 1 and app.auto_advance_timer.is_stopped(), "Automatic advance preserves interval and counts only once")
	var new_root: Vector2i = app.root_position
	await create_timer(1.8).timeout
	_check(app.root_position == new_root and not app.question_complete, "A completed answer schedules exactly one advance")
	app._set_mode(2)
	app.root_position = Vector2i(4, 3)
	app.chord_index = 0
	app._reset_question()
	await _frames()
	await _note(Vector2i(3, 2))
	await create_timer(1.8).timeout
	_check(app.root_position == Vector2i(4, 3) and app.picked.size() == 1 and not app.question_complete, "One correct triad tone does not advance prematurely")
	await _note(Vector2i(2, 0))
	_check(app.question_complete and app.instruction_label.text.contains("答對了"), "Complete triad receives success feedback")
	await create_timer(1.8).timeout
	_check(app.mode == 2 and app.chord_index == 0 and app.root_position != Vector2i(4, 3) and app.picked.is_empty(), "Complete triad advances and preserves selected quality")
	app._set_mode(1)
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	await _note(Vector2i(3, 2))
	await _click(app.next_button)
	new_root = app.root_position
	await create_timer(1.8).timeout
	_check(app.root_position == new_root and not app.question_complete, "Manual Next cancels the old success timer")
	await _note(app._valid_answers()[0])
	await _click(app.mode_buttons[0])
	new_root = app.root_position
	await create_timer(1.8).timeout
	_check(app.mode == 0 and app.root_position == new_root and app.auto_advance_timer.is_stopped(), "Switching mode cancels pending advancement")
	app._set_mode(1)
	await _frames()
	await _click(app.reveal_button)
	new_root = app.root_position
	await create_timer(1.8).timeout
	_check(app.revealed and app.root_position == new_root and not app.question_complete, "Revealing an answer does not auto-advance")
	app._reset_question()
	await _frames()
	await _note(app._valid_answers()[0])
	app._on_interval_changed(9)
	_check(app.interval_index == 9 and not app.question_complete and app.auto_advance_timer.is_stopped(), "Changing question settings cancels pending advancement")
	print("PASS: success feedback, delayed dyad and triad advancement, single scoring, partial/revealed answers and cancellation")


func _selection_ui_tests() -> void:
	app.tone_player.set_muted(true)
	app._set_mode(0)
	app.root_position = Vector2i(5, 2)
	app.interval_index = 4
	app._reset_question()
	await _frames()
	_check(app.root_label.text.contains("F♯2") and app.root_label.text.contains("6 弦 2 品"), "Root summary names fretted F sharp rather than open-string E")
	_check(app.interval_buttons.size() == 12 and app.interval_choices.visible, "All twelve interval choices are directly available")
	await _capture("08-direct-interval-selection")
	await _click(app.interval_buttons[9])
	_check(app.interval_index == 9 and app.interval_buttons[9].button_pressed and not app.interval_buttons[4].button_pressed, "Major-sixth button selects and highlights the interval")
	await _click(app.interval_buttons[8])
	_check(app.interval_index == 8 and app.root_position == Vector2i(5, 2), "Minor-sixth comparison keeps the same root")
	await _note(app._valid_answers()[0])
	var feedback: String = app.feedback
	var target: Vector2i = app.audition_target
	await _click(app.interval_buttons[8])
	_check(app.interval_buttons[8].button_pressed and app.audition_target == target and app.feedback == feedback, "Clicking selected interval retains current listening state")
	await _click(app.root_placement_button)
	_check(app.placing_root and app.board.show_notes and not app.board.nearby and app.board.markers.is_empty(), "Choosing root exposes note names across the whole board")
	await _click(app.root_placement_button)
	_check(not app.placing_root and app.root_position == Vector2i(5, 2) and app.board.nearby, "Root selection can be canceled without changing root")
	await _click(app.root_placement_button)
	await _note(Vector2i(0, 15))
	_check(app.root_position == Vector2i(0, 15) and not app.placing_root and app.root_label.text.contains("G5"), "Root can be selected outside the old local range")
	await _click(app.mode_buttons[1])
	var mistakes: int = app.mistake_count
	var completed: int = app.completed_count
	await _click(app.root_placement_button)
	await _note(Vector2i(5, 2))
	_check(app.mode == 1 and app.root_position == Vector2i(5, 2) and not app.placing_root, "Practice also supports direct root placement")
	_check(app.mistake_count == mistakes and app.completed_count == completed and app.picked.is_empty(), "Choosing a root never grades it as an answer")
	await _click(app.mode_buttons[2])
	_check(app.chord_buttons.size() == 4 and app.chord_choices.visible and not app.interval_choices.visible, "All four chord qualities are directly available")
	await _click(app.chord_buttons[1])
	_check(app.chord_index == 1 and app.chord_buttons[1].button_pressed and not app.chord_buttons[0].button_pressed and app.formula_label.text.contains("♭3"), "Minor-triad choice updates formula and selected state")
	await _capture("09-direct-chord-selection")
	await _note(app._valid_answers()[0])
	var partial: Array[Vector2i] = app.picked.duplicate()
	feedback = app.feedback
	await _click(app.root_placement_button)
	await _click(app.root_placement_button)
	_check(app.picked == partial and app.feedback == feedback and not app.placing_root, "Canceling root placement preserves the partial chord and feedback")
	await _note(app._valid_answers()[0])
	var completed_root: Vector2i = app.root_position
	await _click(app.root_placement_button)
	await create_timer(1.8).timeout
	_check(app.placing_root and app.question_complete and app.root_position == completed_root and app.auto_advance_timer.is_stopped(), "Root placement pauses the pending auto-advance")
	await _capture("10-direct-root-selection")
	await _click(app.root_placement_button)
	await create_timer(1.8).timeout
	_check(not app.placing_root and not app.question_complete and app.root_position != completed_root, "Canceling root placement resumes completed-question advancement")
	print("PASS: visible interval/chord choices, actual root note, one selected option, full-board placement and practice-safe root editing")


func _instrument_layout_tests() -> void:
	var original_size: Vector2 = app.size
	var original_position: Vector2 = app.position
	app.size = Vector2(1024, 900)
	# The scene grows from both anchors; keep this simulated viewport at the origin.
	app.position = Vector2.ZERO
	await _frames(6)
	_check(app.instrument_body.vertical, "Compact instrument stacks display and keys")
	_check(app.board.get_global_rect().position.x >= 0 and app.board.get_global_rect().end.x <= app.size.x, "Compact display stays within the viewport")
	_check(app.root_label.get_global_rect().position.x >= 0, "Compact root selector stays visible")
	for button in app.interval_buttons:
		_check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= app.size.x and button.size.y >= 44, "Compact keys remain visible and large enough to press")
	await _capture("11-instrument-compact")
	app.size = original_size
	app.position = original_position
	await _frames(6)
	_check(not app.instrument_body.vertical, "Desktop instrument restores side-by-side panels")
	app._set_mode(0)
	app.root_position = Vector2i(4, 3)
	app.interval_index = 4
	app._reset_question()
	app.tone_player.set_muted(false)
	await _frames()
	await _note(Vector2i(3, 2))
	await _capture("12-instrument-final")
	app.tone_player.stop()
	await create_timer(0.1).timeout
	print("PASS: compact layout bounds, readable key sizes and desktop instrument layout")


func _double_root_tests() -> void:
	app._set_mode(0)
	app.tone_player.set_muted(false)
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	await _note(Vector2i(2, 6))
	_check(app.root_position == Vector2i(4, 3), "Single click continues audition without changing root")
	await _double_note(Vector2i(2, 6))
	_check(app.root_position == Vector2i(2, 6) and app.root_label.text.contains("C♯4"), "Real double-click selects root and refreshes actual note name")
	_check(app.tone_player.current_notes == [61] and app.board.named_positions == [Vector2i(2, 6)], "New root is auditioned and labeled inside its circle")
	await _double_note(Vector2i(0, 15))
	_check(app.root_position == Vector2i(0, 15), "Double-click can choose a root outside the old local range")
	app.tone_player.set_muted(true)
	app._set_mode(1)
	app.interval_index = 4
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	var mistakes: int = app.mistake_count
	await _double_note(Vector2i(4, 4))
	_check(app.root_position == Vector2i(4, 4) and app.mistake_count == mistakes, "Double-click first press cannot add a wrong-answer penalty")
	app.root_position = Vector2i(4, 3)
	app._reset_question()
	await _frames()
	var score: int = app.completed_count
	await _double_note(Vector2i(3, 2))
	_check(app.root_position == Vector2i(3, 2) and app.completed_count == score and not app.question_complete, "Double-click on a correct answer changes root without awarding credit")
	_check(app.auto_advance_timer.is_stopped(), "Root change cancels success timer from the first click")
	await create_timer(1.8).timeout
	_check(app.root_position == Vector2i(3, 2), "Old question cannot advance after double-click root change")
	app._set_mode(2)
	app.root_position = Vector2i(4, 3)
	app.chord_index = 0
	app._reset_question()
	await _frames()
	await _note(Vector2i(3, 2))
	score = app.completed_count
	await _double_note(Vector2i(2, 0))
	_check(app.root_position == Vector2i(2, 0) and app.picked.is_empty() and app.completed_count == score, "Triad double-click clears old voicing without counting its completion")
	app._set_mode(0)
	await _capture("13-double-click-root")
	print("PASS: native double-click root selection, single-click audition, score rollback and old-timer cancellation")


func _run() -> void:
	_theory_tests()
	_audio_model_tests()
	await _ui_tests()
	await _audio_ui_tests()
	await _selection_ui_tests()
	await _auto_advance_tests()
	await _instrument_layout_tests()
	await _double_root_tests()
	app.queue_free()
	await _frames()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
