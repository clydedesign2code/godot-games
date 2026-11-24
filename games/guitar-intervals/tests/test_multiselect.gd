extends SceneTree
## Real viewport interactions: multi-select lookup and independent single-choice practice.
const Trainer = preload("res://src/trainer/trainer.tscn")
const Theory = preload("res://src/theory/fretboard_theory.gd")
var app: Control
var checks: int = 0
var failures: int = 0
var capture_dir: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	create_timer(20).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int = 4) -> void:
	for index in range(count):
		await process_frame


func point_at(control: Control, local_point: Vector2) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frames()
		ancestor = ancestor.get_parent()
	var point := control.global_position + local_point
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


func click(control: Control) -> void:
	if control is Button and not control.is_visible_in_tree() and control in app.mode_buttons:
		await click(app.practice_nav_button)
	await point_at(control, control.size / 2)


func note(position: Vector2i) -> void:
	await point_at(app.board, app.board.cell_center(position))


func capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await frames()
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save multi-selection preview")


func check_markers() -> void:
	var count: int = 0
	for interval in app.selected_intervals:
		for position in Theory.candidates(app.root_position, interval, app.nearby):
			count += 1
			check(app.board.markers.has(position) and app.board.markers[position].text == Theory.INTERVALS[interval].symbol, "Every selected interval is marked with its own symbol")
	check(app.board.markers.size() == count, "No unselected pitch classes appear in lookup markers")


func _run() -> void:
	app = Trainer.instantiate()
	root.add_child(app)
	await frames()
	app.tone_player.set_muted(true)
	check(app.mode == 4 and not app.practice_tabs.visible and app.mode_buttons[4].button_pressed, "Launch selects chord lookup and keeps exercise types in secondary navigation")
	await click(app.mode_buttons[0])
	check(app.selected_intervals == [4] and app.interval_buttons[4].button_pressed, "Starts with major third selected")
	check(app.task_panel.practice_button.is_visible_in_tree() and not app.next_button.is_visible_in_tree() and not app.instruction_label.text.contains("？") and not app.scope_note.visible, "Lookup offers listening and optional practice without question or scoring controls")
	var original_root: Vector2i = app.root_position
	await click(app.interval_buttons[7])
	await click(app.interval_buttons[9])
	check(app.selected_intervals == [4, 7, 9], "Real clicks select third, fifth and sixth together")
	check(app.interval_buttons[4].button_pressed and app.interval_buttons[7].button_pressed and app.interval_buttons[9].button_pressed, "All selected keys remain visibly pressed")
	check(app.root_position == original_root and app.instruction_label.text.contains("3 種音程"), "Multiple lookup keeps root and displays multi-interval task")
	check_markers()
	await capture("01-multiselect-lookup")
	var fifth := Vector2i(2, 0)
	await note(fifth)
	check(app.audition_target == fifth and app.interval_index == 7, "Clicking another selected interval changes the concrete dyad audition")
	await click(app.task_panel.practice_button)
	check(app.mode == 1 and app.interval_index == 7 and app.root_position == original_root and app.board.markers.is_empty(), "Practice the auditioned fifth from its original root without revealing the lookup set")
	check(app.task_panel.return_button.visible and app.selected_intervals == [4, 7, 9], "Contextual practice retains the three lookup selections")
	await click(app.next_button)
	await click(app.task_panel.return_button)
	check(app.mode == 0 and app.root_position == original_root and app.audition_target == fifth and app.selected_intervals == [4, 7, 9], "Return restores original root, audition stop and multi-selection after changing practice roots")
	await click(app.play_group_button)
	check(app.board.named_positions == [original_root, fifth], "Dyad playback labels root and the last chosen selected interval")
	await click(app.nearby_check)
	check(not app.nearby, "All-board lookup toggle works with multiple intervals")
	check_markers()
	await click(app.nearby_check)
	await click(app.interval_buttons[7])
	check(app.selected_intervals == [4, 9] and not app.interval_buttons[7].button_pressed, "Clicking a selected key removes only that interval")
	check_markers()
	await click(app.interval_buttons[9])
	await note(Vector2i(3, 2))
	var feedback: String = app.feedback
	await click(app.interval_buttons[4])
	check(app.selected_intervals == [4] and app.interval_buttons[4].button_pressed and app.feedback == feedback and app.audition_target == Vector2i(3, 2), "Last interval cannot be deselected and audition state is preserved")
	await click(app.interval_buttons[9])
	await click(app.mode_buttons[1])
	check(app.selected_intervals == [4, 9] and app.board.markers.is_empty(), "Lookup selection stays saved without leaking answers into practice")
	check(app.choice_label.text.contains("單選") and app.interval_index == 4, "Independent practice retains its own single interval after contextual practice")
	await click(app.interval_buttons[7])
	await click(app.interval_buttons[9])
	var selected_count: int = 0
	for button in app.interval_buttons:
		selected_count += int(button.button_pressed)
	check(selected_count == 1 and app.interval_buttons[9].button_pressed and not app.interval_buttons[7].button_pressed, "Real dyad clicks replace the single choice")
	check(app.selected_intervals == [4, 9] and app.practice_interval_index == 9, "Dyad selection does not modify lookup's saved collection")
	for index in range(40):
		app._new_question()
		check(app.interval_index == 9 and not app._valid_answers().is_empty(), "Next dyad question preserves its single interval")
		check(app.board.markers.is_empty(), "New practice question never exposes answers")
	var mistakes: int = app.mistake_count
	await note(Theory.candidates(app.root_position, 4, app.nearby)[0])
	check(not app.question_complete and app.mistake_count == mistakes + 1, "An interval selected only in lookup cannot answer the current practice question")
	await click(app.reveal_button)
	check(app.revealed and app.board.markers.size() == Theory.candidates(app.root_position, 9, app.nearby).size(), "Reveal shows every answer for the single practice interval")
	for position in app.board.markers:
		check(Theory.relative_pc(app.root_position, position) == 9, "Reveal only shows the current question's answers")
	await click(app.next_button)
	await note(app._valid_answers()[0])
	check(app.question_complete and not app.auto_advance_timer.is_stopped(), "Correct single-interval answer schedules normal success feedback")
	var score: int = app.completed_count
	await create_timer(1.8).timeout
	check(not app.question_complete and app.interval_index == 9 and app.completed_count == score and app.selected_intervals == [4, 9], "Auto-advance preserves the practice interval and independent lookup collection")
	await capture("02-single-select-practice")
	await note(app._valid_answers()[0])
	await click(app.interval_buttons[7])
	check(app.interval_index == 7 and app.auto_advance_timer.is_stopped() and not app.question_complete, "Changing the practice interval cancels the old answer timer")
	var root_before: Vector2i = app.root_position
	var feedback_before: String = app.feedback
	await click(app.interval_buttons[7])
	check(app.interval_index == 7 and app.root_position == root_before and app.feedback == feedback_before and app.interval_buttons[7].button_pressed, "Clicking the selected practice interval keeps it and preserves state")
	await click(app.mode_buttons[2])
	await click(app.chord_buttons[1])
	check(app.chord_index == 1 and not app.chord_buttons[0].button_pressed and app.choice_label.text.contains("單選"), "Triad quality remains an independent single choice")
	await capture("03-single-select-triad")
	await click(app.mode_buttons[0])
	check(app.selected_intervals == [4, 9] and app.interval_buttons[4].button_pressed and app.interval_buttons[9].button_pressed and app.choice_label.text.contains("複選"), "Returning to lookup restores its own multiple choices")
	check_markers()
	await click(app.interval_buttons[1])
	check(app.selected_intervals == [1, 4, 9], "Lookup may add another interval independently")
	await click(app.mode_buttons[1])
	check(app.interval_index == 7 and app.interval_buttons[7].button_pressed and not app.interval_buttons[1].button_pressed, "Returning to dyad practice restores its own interval even when not selected in lookup")
	check(not app.formula_label.text.contains("題庫"), "Practice UI contains no mixed-pool explanation")
	await click(app.mode_buttons[3])
	await click(app.mode_buttons[2])
	check(app.chord_index == 1 and app.chord_buttons[1].button_pressed, "Triad setting survives voice mode independently")
	await click(app.mode_buttons[0])
	check(app.selected_intervals == [1, 4, 9], "Lookup collection survives all practice mode switches")
	for index in range(12):
		if not app.selected_intervals.has(index):
			await click(app.interval_buttons[index])
	check(app.selected_intervals.size() == 12, "All twelve intervals can be selected")
	check_markers()
	await capture("03-all-intervals")
	# Leave the preview in the common thirds/fifth/sixth comparison configuration.
	app.selected_intervals.assign([4, 7, 9])
	app.interval_index = 4
	app.root_position = original_root
	app._reset_question()
	await capture("04-multiselect-final")
	app.queue_free()
	await frames()
	print("MULTISELECT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
