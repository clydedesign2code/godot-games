extends SceneTree

var output_dir: String
var manager: Node

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for index in count:
		await physics_frame

func save_frame(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output_dir.path_join(filename))
	assert(result == OK, "Failed to write documentation capture")

func capture() -> void:
	output_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	manager = root.get_node("InteractionManager")
	var lab = load("res://scenes/lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await frames(30)
	var props = lab.get_node("InteractionProps")
	var switch_position: Vector2 = props.get_node("Switch").global_position
	lab.player.position = switch_position + Vector2(-25.0, -1.0)
	lab.player.velocity = Vector2.ZERO
	await frames(5)
	assert(manager.try_interact(), "Switch must activate for capture")
	await frames(3)
	await save_frame("01-switch-response.png")
	var cabinet_position: Vector2 = props.get_node("Cabinet").global_position
	lab.player.position = cabinet_position + Vector2(-35.0, -1.0)
	lab.player.velocity = Vector2.ZERO
	await frames(5)
	await save_frame("02-proximity-prompt.png")
	assert(manager.try_interact() and manager.is_menu_open, "Menu must open for capture")
	await frames(4)
	await save_frame("03-cabinet-menu.png")
	assert(manager.choose_option(&"open"), "Cabinet open option must activate")
	await frames(4)
	await save_frame("04-menu-response.png")
	print("DOCUMENTATION CAPTURE: PASS (4 actual game frames)")
	quit()
