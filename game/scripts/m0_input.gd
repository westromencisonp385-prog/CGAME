class_name M0Input
extends RefCounted

static func configure() -> void:
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
		"aim_left": KEY_J, "aim_right": KEY_L, "aim_up": KEY_I, "aim_down": KEY_K,
		"primary": KEY_SPACE, "throw_cargo": KEY_E, "dash": KEY_SHIFT, "interact": KEY_R,
		"pause": KEY_ESCAPE, "garage": KEY_B}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0],
		"aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "throw_cargo": [JOY_AXIS_TRIGGER_LEFT, 1.0]}
	for action in axes:
		var axis := InputEventJoypadMotion.new()
		axis.axis = axes[action][0]
		axis.axis_value = axes[action][1]
		InputMap.action_add_event(action, axis)
	var buttons := {"dash": JOY_BUTTON_LEFT_SHOULDER, "interact": JOY_BUTTON_A, "garage": JOY_BUTTON_Y, "pause": JOY_BUTTON_START}
	for action in buttons:
		var button := InputEventJoypadButton.new()
		button.button_index = buttons[action]
		InputMap.action_add_event(action, button)
	for action in ["primary", "throw_cargo"]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT if action == "primary" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, mouse)
