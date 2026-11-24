extends SceneTree
## Exercise the fifth mode through its real fretboard, controls and shared player.
const Trainer = preload("res://src/trainer/trainer.tscn")
const Theory = preload("res://src/theory/fretboard_theory.gd")
var app: Control
var page: Control
var checks := 0
var failures := 0
var capture_dir := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	create_timer(45).timeout.connect(func() -> void:
		push_error("Inversion practice timed out")
		quit(2)
	)
	_run.call_deferred()


func check(result: bool, message: String) -> void:
	checks += 1
	if not result:
		failures += 1
		push_error(message)


func frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func click(control: Control, local_point := Vector2.INF) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			await frames()
		parent = parent.get_parent()
	var point := control.get_global_rect().get_center() if local_point == Vector2.INF else control.global_position + local_point
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
	await frames()


func pick(string_number: int, fret: int) -> void:
	var position := Vector2i(string_number - 1, fret)
	await click(page.board, page.board.cell_center(position))


func save_preview(name: String) -> void:
	if capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Save preview")


func check_grip(label: String) -> void:
	check(not page.shapes.is_empty() and page.selection == page.shapes[page.shape_index], label + " displays actual grip")
	check(page.board.markers.size() == page.string_count and page.board.active_rows.size() == page.string_count, label + " has one marker per required string")
	var lowest := 128
	for position in page.selection:
		lowest = mini(lowest, Theory.midi(position))
	for position in page.selection:
		check((page.board.markers[position].color == page.P.ROOT) == (Theory.midi(position) == lowest), label + " marks the sounding bass")


func _run() -> void:
	root.size = Vector2i(1360, 900)
	app = Trainer.instantiate()
	root.add_child(app)
	await frames()
	page = app.inversion_practice
	check(app.mode == 4 and page.active and not page.is_practicing, "Home opens the guitar chord explorer")
	check(page.root_pc == 0 and page.chord_index == 0 and page.string_count == 3 and page.first_string == 1, "Initial C major on strings 123")
	check(page.root_buttons.size() == 12 and page.quality_buttons.size() == 14, "All project chord qualities can be reached in lookup")
	for id in [0,1,6,4,5]:
		check(page.quality_buttons[id].is_visible_in_tree(), "Common quality has a direct key")
	check(not page.quality_buttons[11].is_visible_in_tree() and page.more_quality_button.visible, "Additional qualities start collapsed")
	check(not page.next_button.is_visible_in_tree() and not page.stats.is_visible_in_tree() and not page.feedback.is_visible_in_tree(), "Lookup hides exercise-only controls and feedback")
	check(page.board.first_focused_fret > 0, "Reference uses a focused neck")
	check_grip("Initial C")
	check(page.question.text.contains("C") and page.readout.text.contains("指 "), "Reference includes the chord and left hand fingering")
	await click(page.quality_buttons[6])
	check(page.string_count == 4 and page.names == ["C","E♭","G","B♭"], "m7 shortcut opens a full seventh by default")
	await click(page.count_buttons[0])
	check(page.string_count == 3 and page.inversion_buttons[2].disabled and page.shape_info.text.contains("省略五度 G"), "m7 shell excludes its fifth and second inversion")
	await click(page.quality_buttons[0])
	check(page.string_count == 3 and page.fixed_count, "Explicit span held across quality changes")
	check(page.count_buttons.size() == 3, "Choose three, four or five strings")
	for count_index in page.count_buttons.size():
		await click(page.count_buttons[count_index])
		var count: int = 3 + count_index
		for first in range(1, 8-count):
			await click(page.string_group_buttons[first-1])
			check(page.first_string == first and page.string_group_buttons[first-1].button_pressed, "Region key switches")
			check(page.board.active_rows.front() == first + count - 2 and page.board.active_rows.back() == first-1, "Correct thick and thin strings")
			check_grip("C %d strings from %d" % [count, first])
			await click(page.listen_button)
			var midi: Array[int] = []
			for pos: Vector2i in page.selection:
				midi.append(Theory.midi(pos))
			check(app.tone_player.current_notes == midi, "Heard registers agree with the grip")
		for i in page.string_group_buttons.size():
			check(page.string_group_buttons[i].visible == (i + count <= 6), "Only complete consecutive string groups are visible")

	await click(page.count_buttons[0])
	await click(page.string_group_buttons[1])
	await click(page.inversion_buttons[1])
	check(page.inversion_buttons[1].text == "第一轉位" and page.inversion_buttons[1].tooltip_text.contains("C/E") and page.question.text.contains("C/E"), "Short inversion key and full slash chord in tooltip and heading")
	check(page.selection == [Vector2i(3,2),Vector2i(2,0),Vector2i(1,1)], "C/E on 432 uses E3 G3 C4 through the G-B tuning step")
	await click(page.display_buttons[2])
	check(page.board.note_labels[Vector2i(3,2)] == "E" and page.board.secondary_labels[Vector2i(3,2)] == "3", "Displayed bass uses the root-relative third without octave digit")
	await click(page.display_buttons[1])
	check(page.board.note_labels[Vector2i(1,1)] == "R" and page.board.secondary_labels.is_empty(), "Root present in interval-only view")
	await click(page.reveal_button)
	check(not page.revealed and page.board.markers.is_empty() and page.board.first_focused_fret > 0, "Cover hides the lookup dots without starting a scored exercise")
	await pick(4,2)
	check(page.correct_count == 0 and page.mistakes == 0 and page.selection.is_empty() and page.board.markers.is_empty(), "A click in covered lookup only auditions")
	await click(page.reveal_button)
	check_grip("Uncover")

	await click(page.count_buttons[1])
	await click(page.string_group_buttons[0])
	await click(page.quality_buttons[5])
	await click(page.inversion_buttons[3])
	check(page.question.text.contains("C7/B♭") and page.inversion_buttons[3].tooltip_text.contains("C7/B♭"), "C7 third inversion and slash spelling")
	await click(page.display_buttons[2])
	check(page.shapes.size() > 1, "Several C7/B-flat grips are available")
	await click(page.next_shape_button)
	var saved_index: int = page.shape_index
	var source: Array = page.selection.duplicate()
	var original: String = page.question.text
	await click(page.practice_button)
	check(page.is_practicing and page.question.text == original and page.selection.is_empty(), "Recall begins with exactly the displayed chord")
	check(page.board.first_focused_fret == 0 and page.stats.visible and page.next_button.visible and page.settings.visible == false, "Practice uses full neck, stats and next question")
	check(page.board.markers.is_empty() and page.board.secondary_labels.is_empty() and not page.revealed, "Fresh practice reveals no dots")
	await click(page.listen_button)
	var expected_notes: Array[int] = []
	for pos: Vector2i in source:
		expected_notes.append(Theory.midi(pos))
	check(app.tone_player.current_notes == expected_notes, "Unanswered practice auditions the original alternative grip")
	await pick(6,0)
	check(page.mistakes == 0 and page.selection.is_empty(), "Inactive strings never count as errors")
	await pick(1,1)
	check(page.mistakes == 1 and page.rejected_selection.size() == 1, "Incorrect active note is rejected")
	var first_pos: Vector2i = source[0]
	await pick(first_pos.x+1,first_pos.y)
	await click(page.display_buttons[1])
	check(page.selection.size() == 1 and page.board.note_labels[first_pos] == "m7", "Changing labels keeps a partial answer")
	await pick(first_pos.x+1,first_pos.y)
	check(page.selection.is_empty() and page.advance.is_stopped(), "Tap again removes a note")
	for pos: Vector2i in source:
		await pick(pos.x+1,pos.y)
	check(page.complete and page.correct_count == 1 and not page.advance.is_stopped(), "Complete inversion scores once with delayed advance")
	await create_timer(1.85).timeout
	check(page.root_pc != 0 and page.inversion == 3 and not page.complete and page.selection.is_empty(), "Auto advance changes root and retains inversion")
	var new_root: int = page.root_pc
	await click(page.next_button)
	check(page.root_pc != new_root and page.is_practicing, "Manual next root from same practice")
	await click(page.back_button)
	check(not page.is_practicing and page.revealed and page.root_pc == 0 and page.question.text == original, "Return restores original lookup after both automatic and manual next")
	for pc: int in page.root_buttons:
		check(page.root_buttons[pc].button_pressed == (pc == 0), "Only the restored root is highlighted")
	check(page.display_mode == 2 and page.shape_index == saved_index and page.selection == source, "Return restores exact alternative and label format")
	await save_preview("chord-explorer-C7-Bflat")
	await click(page.count_buttons[0])
	await click(page.more_quality_button)
	await click(page.quality_buttons[12])
	check(page.string_count == 4 and page.count_buttons[0].disabled and page.shape_info.text.contains("變化五度 G♭"), "Half diminished keeps its distinctive fifth with four strings")
	await click(page.quality_buttons[13])
	check(page.names[3] == "B♭♭" and page.count_buttons[0].disabled, "Fully diminished also retains its changed fifth")
	await click(page.quality_buttons[7])
	await click(page.count_buttons[0])
	await click(page.string_group_buttons[1])
	for pc in range(12):
		await click(page.root_buttons[pc])
		check(not page.shapes.is_empty(), "Root change always presents a playable inversion")
		check(page.inversion_buttons[3].disabled == (3 not in page.Inversions.playable_inversions(7,pc,3,2)), "Unreachable mMaj7 shell inversions disabled per root")

	await click(page.quality_buttons[0])
	await click(page.root_buttons[0])
	await click(page.count_buttons[1])
	await click(page.inversion_buttons[0])
	await click(page.reveal_button)
	await click(page.practice_button)
	var doubled: Array = page.shapes[page.shape_index]
	for pos: Vector2i in doubled:
		await pick(pos.x+1,pos.y)
	check(page.complete and page.correct_count == 2, "A four-string triad accepts a doubled degree")
	await click(page.back_button)
	check(not page.revealed and page.selection.is_empty() and page.advance.is_stopped(), "Return restores a covered lookup and cancels pending advance")
	await click(page.reveal_button)
	await frames()
	check_grip("Revealed doubled triad")
	root.size = Vector2i(768,1024)
	await frames()
	for control: Control in [page.string_group_buttons[1],page.board,page.display_buttons[2],page.practice_button]:
		check(control.get_global_rect().end.x <= app.size.x + 1, "Narrow width fits "+control.name)
	root.size = Vector2i(390,844)
	await frames()
	check(page.selector_grid.columns == 1 and page.display_header.vertical, "Selectors and screen header stack on a phone")
	for control: Control in [page.board,page.display_buttons[2],page.practice_button,page.root_buttons[10]]:
		check(control.get_global_rect().end.x <= app.size.x + 1, "Phone width fits "+control.name)
	await click(page.practice_button)
	await click(app.mode_buttons[4])
	check(not page.is_practicing and page.root_pc == 0, "Top-level Chords also returns to lookup")
	await check_sus_and_sixth_lookup()
	await check_five_strings()
	await check_selector_layout()
	print("Chord explorer: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func check_selector_layout() -> void:
	if page.extra_qualities.visible:
		await click(page.more_quality_button)
	await click(page.quality_buttons[6])
	await click(page.count_buttons[2])
	await click(page.string_group_buttons[1])
	await click(page.inversion_buttons[1])
	for viewport_size in [Vector2i(1360, 900), Vector2i(768, 1024), Vector2i(390, 844)]:
		root.size = viewport_size
		app.page_scroll.scroll_vertical = 0
		await frames()
		var navigation_y: float = app.mode_buttons[4].global_position.y
		check(is_equal_approx(navigation_y, app.header.global_position.y), "Navigation starts at the top of the panel")
		check(is_equal_approx(navigation_y, app.mute_button.global_position.y) == (viewport_size.x >= 768), "Sound controls share the top row on desktop and tablet")
		check(app.volume_slider.size.y >= 44, "Volume slider has a full-height touch target")
		var sections: Array = page.region_controls.get_children()
		var last_rect := Rect2()
		var first_x: float = sections.front().get_child(1).global_position.x
		for section: Control in sections:
			var heading: Label = section.get_child(0)
			var keys: Container = section.get_child(1)
			var first_key: Rect2 = keys.get_child(0).get_global_rect()
			if viewport_size.x >= 768:
				check(is_equal_approx(heading.global_position.x, first_key.position.x) and heading.get_global_rect().end.y < first_key.position.y, "Each setting is labeled above its first key")
			else:
				check(heading.get_global_rect().end.x < first_key.position.x and is_equal_approx(first_x, first_key.position.x), "Phone labels form a left column with aligned controls")
			if last_rect.has_area():
				check(not last_rect.intersects(section.get_global_rect()), "Setting groups have their own space")
			last_rect = section.get_global_rect()
			for key: Button in keys.get_children():
				if key.is_visible_in_tree():
					check(key.get_global_rect().end.x <= viewport_size.x and key.size.x >= 44 and key.size.y >= 44, "All keys are visible touch targets")
		if viewport_size.x >= 768:
			check(is_equal_approx(sections.front().global_position.y, sections.back().global_position.y), "iPad and desktop align all three group headings at %s; target %s, group minima %s" % [viewport_size, page.region_controls.size, sections.map(func(s: Control): return s.get_combined_minimum_size())])
		else:
			check(sections.back().global_position.y > sections.front().global_position.y, "Phone wraps complete groups")
		check(page.question.text.contains("Cm7/E♭") and page.formula_label.text.contains("♭7"), "Full slash chord and formula remain on screen")
		check(page.question.get_line_count() == 1, "Cm7/E-flat and its string range fit on one line")
		for element: Control in [app, page, page.composition, page.formula_label, page.board, page.question, page.region_controls]:
			check(element.get_global_rect().end.x <= viewport_size.x + 1, "Full chord fits the actual window, including its composition")
		await save_preview("chord-controls-%d" % viewport_size.x)


func check_sus_and_sixth_lookup() -> void:
	root.size = Vector2i(1024,768)
	await frames()
	await click(page.count_buttons[0])
	await click(page.string_group_buttons[0])
	await click(page.display_buttons[2])
	var cases := [
		[10, 1, "Csus2/D", "二度", "2", [0,2,7]],
		[11, 1, "Csus4/F", "四度", "4", [0,5,7]],
		[8, 3, "C6/A", "六度", "6", [0,4,9]],
		[9, 3, "Cm6/A", "六度", "6", [0,3,9]]
	]
	for item in cases:
		await click(page.quality_buttons[item[0]])
		await click(page.inversion_buttons[item[1]])
		check(not page.is_practicing and page.revealed and page.question.text.contains(item[2]), "Look up "+item[2]+" without entering practice")
		check(page.bass_label.text.contains(item[3]), "Bass function for "+item[2])
		var bass: Vector2i = page.selection[0]
		for pos: Vector2i in page.selection:
			if Theory.midi(pos) < Theory.midi(bass):
				bass = pos
		check(page.board.secondary_labels[bass] == item[4], "Marker uses the interval spelled by the chord")
		var selected_notes: Array[int] = []
		var pitch_classes: Array[int] = []
		for pos: Vector2i in page.selection:
			selected_notes.append(Theory.midi(pos))
			pitch_classes.append(Theory.midi(pos) % 12)
		await click(page.listen_button)
		pitch_classes.sort()
		check(app.tone_player.current_notes == selected_notes and pitch_classes == item[5], "Audition uses the displayed notes of "+item[2])
		if item[1] == 3:
			check(page.shape_info.text.contains("省略五度 G") and page.shape_info.text.contains("六度"), "Sixth shell names the omitted fifth and retained sixth")
			check(not page.shape_info.text.contains("七度") and page.inversion_buttons[2].disabled, "No seventh or omitted fifth bass in a sixth shell")
	await click(page.more_quality_button)
	check(not page.quality_buttons[9].is_visible_in_tree() and page.more_quality_button.text.contains("m6"), "Collapsed control retains the chosen additional quality")
	await click(page.count_buttons[1])
	check(page.chord_index == 9 and page.selection.size() == 4 and page.inversion_buttons[2].visible and not page.inversion_buttons[2].disabled, "Four-string Cm6 restores all four tones and its fifth inversion choice")


func check_five_strings() -> void:
	await click(page.quality_buttons[0])
	await click(page.root_buttons[0])
	await click(page.inversion_buttons[1])
	await click(page.count_buttons[2])
	await click(page.string_group_buttons[1])
	check(page.question.text.contains("C/E") and page.board.active_rows == [5,4,3,2,1], "Changing count and region keeps the playable slash chord")
	for viewport_size in [Vector2i(768,1024), Vector2i(390,844)]:
		root.size = viewport_size
		await frames()
		for control: Control in [page.count_buttons[2], page.string_group_buttons[0], page.string_group_buttons[1], page.question, page.readout, page.practice_button]:
			check(control.get_global_rect().end.x <= app.size.x + 1, "Five-string layout fits %s at %d" % [control.name, viewport_size.x])
		for key in page.string_group_buttons.slice(0, 2):
			var caption_width: float = key.get_theme_font("font").get_string_size(key.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			check(key.size.x >= caption_width + 10, "All five string numbers fit with padding")
		await click(page.string_group_buttons[0])
		check(page.board.active_rows == [4,3,2,1,0] and page.selection.size() == 5, "Touch-sized 12345 key is reachable at %d" % viewport_size.x)
		await click(page.string_group_buttons[1])
		check(page.board.active_rows == [5,4,3,2,1], "Touch-sized 23456 key is reachable at %d" % viewport_size.x)
	await click(page.quality_buttons[6])
	await click(page.inversion_buttons[0])
	for first in [1, 2]:
		await click(page.string_group_buttons[first - 1])
		await click(page.listen_button)
		check(page.composition.text.contains("C · E♭ · G · B♭") and page.shape_info.text.contains("G（五度）佔 2 條弦"), "Five-string Cm7 names its four notes and doubled fifth")
		check(app.tone_player.current_notes == [48,55,58,63,67], "Both common Cm7 fingerings sound C3 G3 B-flat3 E-flat4 G4")
		if first == 1:
			root.size = Vector2i(768,1024)
			await frames()
			await save_preview("five-string-Cm7-ipad")
	await click(page.quality_buttons[5])
	await click(page.inversion_buttons[3])
	check(page.string_count == 5 and page.question.text.contains("C7/B♭") and page.shape_info.text.contains("4 個和弦音"), "Five-string seventh retains all four degrees under a slash bass")
	var counts := {}
	for position: Vector2i in page.selection:
		var pc := Theory.midi(position) % 12
		counts[pc] = counts.get(pc, 0) + 1
	for pc: int in counts:
		if counts[pc] == 2:
			var doubled_name: String = page.names[page.tones.find(pc)]
			check(page.shape_info.text.contains(doubled_name + "（") and page.shape_info.text.count("佔 2 條弦") == 1, "Five-string seventh identifies the single doubled note")
	await click(page.more_quality_button)
	await click(page.quality_buttons[12])
	check(page.string_count == 5 and page.shape_info.text.contains("變化五度 G♭") and page.shape_info.text.contains("佔 2 條弦"), "Five-string half-diminished voicing retains its altered fifth and identifies its doubling")
	await click(page.quality_buttons[0])
	await click(page.string_group_buttons[0])
	await click(page.inversion_buttons[0])
	root.size = Vector2i(1024,768)
	await frames()
	await save_preview("five-string-C")
	var original_shape: Array = page.selection.duplicate()
	var base_score: int = page.correct_count
	for frets in [[3,2,0,1,0], [3,2,0,5,0]]:
		await click(page.practice_button)
		check(page.shape_info.text.contains("另有 2 個弦位") and not page.shape_info.text.contains("佔 2 條弦") and page.board.markers.is_empty(), "New exercise explains doubling without revealing the grip")
		await pick(6, 0)
		check(page.selection.is_empty(), "Sixth string stays outside 12345")
		var played: Array[int] = []
		for i in 5:
			var row := 4 - i
			played.append(Theory.midi(Vector2i(row, frets[i])))
			await pick(row + 1, frets[i])
			check(page.selection.size() == i + 1 and page.complete == (i == 4), "Recall requires one note on each of the five strings")
		base_score += 1
		check(page.correct_count == base_score, "Five-note completion scores once")
		if frets[3] == 1:
			check(page.shape_info.text.contains("C（根音）佔 2 條弦") and page.shape_info.text.contains("E（三度）佔 2 條弦"), "Both doubled degrees are named")
		else:
			check(page.shape_info.text.contains("E（三度）佔 3 條弦") and page.shape_info.text.count("佔 ") == 1, "Three occurrences of the same degree are counted together")
		await click(page.listen_button)
		check(app.tone_player.current_notes == played and page.board.sounding.size() == 5, "Full grip sounds on five strings, including any unisons")
		await click(page.next_button)
		check(page.root_pc != 0 and page.string_count == 5 and page.first_string == 1 and page.inversion == 0, "Next recall changes only the root")
		await click(page.back_button)
		check(page.root_pc == 0 and page.string_count == 5 and page.selection == original_shape and page.advance.is_stopped(), "Returning restores the five-string lookup grip")
