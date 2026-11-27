extends SceneTree
const Trainer = preload("res://src/trainer/trainer.tscn")
const Lesson = preload("res://src/trainer/tutorial_practice.gd")
var failed := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for url in ["https://youtu.be/K7F5JDC621M?t=30", "https://m.youtube.com/watch?t=30&v=K7F5JDC621M", "https://www.youtube.com/shorts/K7F5JDC621M"]:
		check(Lesson.canonical_url(url) == Lesson.EXAMPLE_URL, "Normalize YouTube video URL")
	for url in ["https://youtube.com.example.org/watch?v=K7F5JDC621M", "https://www.youtube.com/watch?v=bad", "javascript:alert(1)", "https://youtube.com/playlist?list=K7F5JDC621M"]:
		check(Lesson.canonical_url(url).is_empty(), "Reject invalid source")
	var app := Trainer.instantiate()
	root.add_child(app)
	await process_frame
	app.practice_nav_button.pressed.emit()
	app.mode_buttons[5].pressed.emit()
	var page = app.tutorial_practice
	page.link_input.text_changed.emit(Lesson.EXAMPLE_URL)
	check(page.visible and page.start_button.disabled, "Require topic confirmation")
	for topic in [0, 1]:
		page.topic_keys[topic].pressed.emit()
		page.start_button.pressed.emit()
		for i in 48:
			check(page.shape.size() == 3, "Ascending triad on all roots and groups")
			if page.shape.size() != 3:
				quit(1)
				return
			page._next()
		page.board.note_pressed.emit(page.shape[2])
		check(page.step == 0, "Fifth cannot be played before root")
		page._listen()
		check(page.demo_step == 1 and not page.demo.is_stopped(), "Audition starts one note at a time")
		for p in page.shape:
			page.board.note_pressed.emit(p)
		check(page.step == 3 and page.board.markers.size() == 3 and not page.advance.is_stopped(), "Ordered response completes")
		app.mode_buttons[4].pressed.emit()
		check(page.advance.is_stopped() and page.demo.is_stopped(), "Leaving cancels timers")
		app.mode_buttons[5].pressed.emit()
		await create_timer(1.8).timeout
		check(page.step == 0 and page.board.active_rows == [3,2,1], "Next drill moves to strings 2–4")
		page._edit()
	page._link_changed("https://youtu.be/abcdefghijk")
	check(page.topic == -1 and page.start_button.disabled, "New source requires new topic confirmation")
	print("Tutorial link, both topics, 96 voicings, grading and navigation: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
