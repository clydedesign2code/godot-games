extends RefCounted

static func setup() -> void:
	var keys = {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "crouch": [KEY_S, KEY_DOWN], "crawl": [KEY_C], "run": [KEY_SHIFT], "reset": [KEY_R], "bones": [KEY_B], "climb": [KEY_W, KEY_UP], "drop": [KEY_S, KEY_DOWN]}
	var buttons = {"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "reset": JOY_BUTTON_BACK, "climb": JOY_BUTTON_DPAD_UP, "drop": JOY_BUTTON_DPAD_DOWN}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.22)
		for code in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
		if buttons.has(action):
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = buttons[action]
			InputMap.action_add_event(action, event)
	for spec in [["crawl", JOY_AXIS_TRIGGER_LEFT, 1.0], ["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["run", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["climb", JOY_AXIS_LEFT_Y, -1.0], ["drop", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = spec[1]
		event.axis_value = spec[2]
		InputMap.action_add_event(spec[0], event)
