extends Node2D

# Shared by the lab, regression tests and visual capture. Heights are measured
# from the common floor: low jump 62px, jump-grab 205px, high reach 220px.
const GROUND_Y := 620.0
const LOW_PLATFORM := Rect2(260, 558, 120, 62)
const CLIMB_PLATFORM := Rect2(500, 415, 160, 20)
const HIGH_PLATFORM := Rect2(980, 400, 140, 20)
const CROUCH_CEILING := Rect2(1160, 494, 100, 32)
const CRAWL_CEILING := Rect2(1235, 526, 25, 26)
var player: CharacterBody2D
var status: Label
var blocks: Array[Rect2] = []

func platform(rect: Rect2) -> void:
	blocks.append(rect)
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)

func label_at(text: String, point: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _ready() -> void:
	preload("res://scripts/controls.gd").setup()
	platform(Rect2(-100, GROUND_Y, 1480, 100))
	platform(Rect2(-30, 0, 30, 720))
	platform(Rect2(1280, 0, 30, 720))
	platform(LOW_PLATFORM)
	platform(CLIMB_PLATFORM)
	platform(HIGH_PLATFORM)
	platform(CROUCH_CEILING)
	platform(CRAWL_CEILING)
	player = CharacterBody2D.new()
	player.set_script(preload("res://scripts/player.gd"))
	player.position = Vector2(150, 610)
	add_child(player)
	label_at("DRIFLOW  /  MOTION LAB", Vector2(40, 30), 28, Color("e9e5d9"))
	label_at("01   THE DETECTIVE     ·     SKELETAL CONTROLLER PROTOTYPE", Vector2(42, 70), 14, Color("7ca5ac"))
	label_at("MOVE  Stick / D-pad / A D     JUMP  A / Space     CROUCH  B / S     RUN  RT / Shift", Vector2(42, 112), 17, Color("c7d5d6"))
	label_at("CRAWL: LT / C · LEDGE: auto grab · Up / W: climb · Down / B: drop · Keyboard B: bones · R / Back: reset", Vector2(42, 140), 15, Color("7ca5ac"))
	status = label_at("", Vector2(42, 185), 18, Color("e6bc7d"))
	label_at("01 / LOW JUMP", Vector2(240, 665), 14, Color("7ca5ac"))
	label_at("02 / JUMP + CLIMB", Vector2(480, 665), 14, Color("7ca5ac"))
	label_at("03 / HIGH REACH", Vector2(960, 665), 14, Color("7ca5ac"))
	label_at("LOW / CRAWL", Vector2(1150, 665), 14, Color("7ca5ac"))
	for rect in [LOW_PLATFORM, CLIMB_PLATFORM, HIGH_PLATFORM]:
		label_at("%d px" % int(GROUND_Y - rect.position.y), rect.position + Vector2(8, -26), 14, Color("e6bc7d"))
	queue_redraw()

func _process(_dt: float) -> void:
	var pads := Input.get_connected_joypads()
	var device := "Keyboard · connect a controller anytime" if pads.is_empty() else Input.get_joy_name(pads[0])
	status.text = "%s    |    x %4.0f   y %4.0f    |    %s" % [player.state, player.velocity.x, player.velocity.y, device]

func _draw() -> void:
	for x in range(0, 1280, 40):
		draw_line(Vector2(x, 255), Vector2(x, 620), Color(0.12, 0.19, 0.23, 0.5))
	for y in range(260, 620, 40):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.12, 0.19, 0.23, 0.5))
	for rect in blocks:
		draw_rect(rect, Color("1d3442"))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("6d999b"), 2)
