extends SceneTree
## Verify the visible separation of prompt, tone slots, feedback and counters.
const Trainer = preload("res://src/trainer/trainer.tscn")
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


func click(control: Control, local_point: Vector2 = Vector2.INF) -> void:
	if control is Button and not control.is_visible_in_tree() and control in app.mode_buttons:
		await click(app.practice_nav_button)
	var ancestor := control.get_parent()
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
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save grouped exercise panel")


func _run() -> void:
	app = Trainer.instantiate()
	root.add_child(app)
	await frames()
	app.tone_player.set_muted(true)
	await click(app.mode_buttons[2])
	app.root_position = Vector2i(4, 3)
	app.chord_index = 0
	app._reset_question()
	await frames()
	var panel: PanelContainer = app.task_panel
	var prompt: String = app.instruction_label.text
	check(prompt == "組成 C 大三和弦", "Prompt gives the chord task without score or progress text")
	check(panel.progress_label.text == "已選 0 / 2 音", "Selection count has a dedicated location")
	check(panel.tone_values[0].text == "C" and panel.tone_values[1].text == "？" and panel.tone_values[2].text == "？", "Root is given and unsolved chord tones stay hidden")
	check(panel.stats_panel.visible and panel.feedback_state.text == "等待作答", "Statistics and answer state are separate blocks")
	check(not panel.sections.vertical, "Desktop task sections align in columns")
	await capture("01-triad-ready")
	await note(Vector2i(2, 0))
	check(panel.tone_values[2].text == "G" and panel.tone_values[1].text == "？", "Selecting fifth first fills only its own slot")
	check(panel.progress_label.text == "已選 1 / 2 音" and panel.feedback_state.text == "繼續選音", "Partial chord has independent progress and feedback")
	check(app.instruction_label.text == prompt, "Prompt stays fixed while selecting")
	await capture("02-triad-partial")
	await note(Vector2i(2, 0))
	check(panel.tone_values[2].text == "？" and panel.progress_label.text == "已選 0 / 2 音", "Canceling a tone clears the correct slot and progress")
	await note(Vector2i(4, 4))
	check(panel.feedback_state.text == "再試一次" and panel.stats_values[2].text == "01", "Wrong answer updates feedback and only the wrong-answer counter")
	check(panel.tone_values[1].text == "？" and panel.tone_values[2].text == "？", "Wrong note does not fill a chord slot")
	await note(Vector2i(3, 2))
	await note(Vector2i(2, 0))
	check(app.question_complete and panel.feedback_state.text.contains("答對了"), "Success is clearly shown in the feedback block")
	check(app.instruction_label.text == prompt and panel.tone_values[1].text == "E" and panel.tone_values[2].text == "G", "Completed chord retains the question and visible selected notes")
	check(panel.stats_values[0].text == "01" and panel.stats_values[1].text == "00", "Independent completion has its own counter")
	await capture("03-triad-success")
	await create_timer(1.8).timeout
	check(not app.question_complete and panel.progress_label.text == "已選 0 / 2 音" and panel.tone_values[1].text == "？", "Automatic next question resets slots and progress")
	check(panel.stats_values[0].text == "01", "Session counters survive auto-advance")
	await click(app.reveal_button)
	check(app.revealed and panel.feedback_state.text == "已顯示答案" and panel.tone_values[1].text != "？" and panel.tone_values[2].text != "？", "Reveal fills note slots without declaring success")
	await click(app.next_button)
	await click(app.hint_button)
	check(panel.feedback_state.text == "位置提示" and panel.tone_values[1].text == "？" and panel.tone_values[2].text == "？", "Text hint does not reveal hidden chord slot names")
	await note(app._valid_answers()[0])
	await note(app._valid_answers()[0])
	check(app.question_complete and panel.stats_values[1].text == "01", "Assisted completion uses the separate assistance counter")
	await click(app.mode_buttons[1])
	check(panel.tone_cards[0].visible and panel.tone_cards[1].visible and not panel.tone_cards[2].visible, "Dyad shows exactly two structure slots")
	await click(app.mode_buttons[0])
	check(not panel.stats_panel.visible and not panel.help_actions.visible, "Lookup hides practice-only counters and hints")
	await click(app.interval_buttons[7])
	check(not panel.tone_cards[0].visible and app.theory_detail_label.text.contains("→"), "Multiple lookup uses a readable mapping instead of empty note slots")
	await click(app.mode_buttons[2])
	app._reset_question()
	var original_size: Vector2 = app.size
	var original_position: Vector2 = app.position
	app.size = Vector2(1024, 900)
	app.position = Vector2.ZERO
	await frames(6)
	check(panel.sections.vertical, "Narrow view stacks task sections")
	for section in panel.sections.get_children():
		check(section.get_global_rect().position.x >= 0 and section.get_global_rect().end.x <= app.size.x, "Narrow task section stays within the content width")
	app.size = original_size
	app.position = original_position
	await frames(6)
	check(not panel.sections.vertical, "Desktop columns restore after resize")
	app.queue_free()
	await frames()
	print("EXERCISE PANEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
