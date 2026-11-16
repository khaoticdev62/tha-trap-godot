class_name InputActions
extends RefCounted
## Registers gameplay input actions with both keyboard and controller bindings,
## so every action is reachable without a mouse (Charter principle 9).
## Godot's built-in ui_* actions already include controller bindings.

const BINDINGS: Dictionary = {
	&"move_up": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP], "axis": [JOY_AXIS_LEFT_Y, -1.0]},
	&"move_down": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_DPAD_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1.0]},
	&"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axis": [JOY_AXIS_LEFT_X, -1.0]},
	&"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1.0]},
	&"interact": {"keys": [KEY_E, KEY_ENTER], "buttons": [JOY_BUTTON_A], "axis": []},
	&"open_pause": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START], "axis": []},
	&"open_map": {"keys": [KEY_M], "buttons": [JOY_BUTTON_Y], "axis": []},
	&"open_glossary": {"keys": [KEY_G], "buttons": [JOY_BUTTON_X], "axis": []},
	# Switch between the screens of a tabbed interface such as the SOC (LB / RB).
	&"nav_prev": {"keys": [KEY_BRACKETLEFT, KEY_PAGEUP], "buttons": [JOY_BUTTON_LEFT_SHOULDER], "axis": []},
	&"nav_next": {"keys": [KEY_BRACKETRIGHT, KEY_PAGEDOWN], "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "axis": []},
}

## Controller buttons added to built-in UI actions. The engine's defaults for
## accept/cancel carry no joypad button in every configuration (verified on
## 4.7.2 headless), so menus would not be controller-operable without these.
const UI_CONTROLLER_BUTTONS: Dictionary = {
	&"ui_accept": JOY_BUTTON_A,
	&"ui_cancel": JOY_BUTTON_B,
}

const AXIS_DEADZONE: float = 0.5


static func action_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: StringName in BINDINGS:
		names.append(key)
	return names


## Idempotent: safe to call more than once.
static func register() -> void:
	for ui_action: StringName in UI_CONTROLLER_BUTTONS:
		var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
		pad_event.button_index = UI_CONTROLLER_BUTTONS[ui_action]
		if InputMap.has_action(ui_action) and not InputMap.action_has_event(ui_action, pad_event):
			InputMap.action_add_event(ui_action, pad_event)
	for action: StringName in BINDINGS:
		var spec: Dictionary = BINDINGS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action, AXIS_DEADZONE)
		InputMap.action_erase_events(action)
		for keycode: Key in spec["keys"]:
			var key_event: InputEventKey = InputEventKey.new()
			key_event.keycode = keycode
			InputMap.action_add_event(action, key_event)
		for button: JoyButton in spec["buttons"]:
			var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
			button_event.button_index = button
			InputMap.action_add_event(action, button_event)
		var axis_spec: Array = spec["axis"]
		if not axis_spec.is_empty():
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = axis_spec[0]
			motion.axis_value = axis_spec[1]
			InputMap.action_add_event(action, motion)
