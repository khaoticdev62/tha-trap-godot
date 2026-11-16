extends Node
## Event-level controller check for the SOC. It feeds the real input events a
## gamepad produces (Joypad Button 0/1/9/10/11/12 and Left Stick Axis 1) through
## the viewport's normal input path (_input, GUI, _unhandled_input), so it proves
## the configured mappings reach the controls. It does NOT replace testing on
## physical hardware: see docs/qa/M8_PHYSICAL_CONTROLLER_TEST_PLAN.md.
##   godot --headless --path . res://tests/integration/soc_controller.tscn

const BTN_A: JoyButton = JOY_BUTTON_A
const BTN_B: JoyButton = JOY_BUTTON_B
const BTN_LB: JoyButton = JOY_BUTTON_LEFT_SHOULDER
const BTN_RB: JoyButton = JOY_BUTTON_RIGHT_SHOULDER
const BTN_DPAD_UP: JoyButton = JOY_BUTTON_DPAD_UP
const BTN_DPAD_DOWN: JoyButton = JOY_BUTTON_DPAD_DOWN
const EXPECTED_STEPS: int = 9

var _failures: PackedStringArray = PackedStringArray()
var _finished: PackedStringArray = PackedStringArray()
var _tree: SceneTree
var _shell: SocShell


func _ready() -> void:
	_tree = get_tree()
	_tree.create_timer(60.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 60s")
		_tree.quit(1))
	_tree.current_scene = null
	var root: Window = _tree.root
	var saves: SaveService = root.get_node_or_null("Saves")
	var settings: SettingsService = root.get_node_or_null("Settings")
	if saves == null or settings == null:
		print("FAIL  autoloads are not available")
		_tree.quit(1)
		return
	var tag: int = Time.get_ticks_usec()
	saves.save_dir = "user://itest_ctl_%d" % tag
	settings.settings_path = "user://itest_ctl_settings_%d.json" % tag
	AppBootstrap.run(_tree)
	root.get_node("Progress").reset()

	_shell = load(SceneFlow.path_for(&"soc")).instantiate()
	add_child(_shell)
	await _frames(4)
	_check(_shell.model != null and _shell.model.is_ready(), "the SOC opens")

	_check_configured_mappings()
	_finished.append("configured_mappings")
	await _check_mapping_reaches_focus_navigation()
	_finished.append("focus_navigation")
	await _check_confirm_cancel_and_shoulders()
	_finished.append("confirm_cancel_shoulders")
	await _check_stick_and_tables()
	_finished.append("stick_and_tables")
	await _check_text_field_active()
	_finished.append("text_field_active")
	await _check_terminal_history_and_scroll()
	_finished.append("terminal_history_scroll")
	await _check_dialog_focus()
	_finished.append("dialog_focus")
	await _check_mouse_then_controller()
	_finished.append("mouse_then_controller")
	await _check_focus_when_returning()
	_finished.append("return_focus")
	_check(_finished.size() == EXPECTED_STEPS, "every step ran to the end (%d of %d: %s)" % [_finished.size(), EXPECTED_STEPS, ", ".join(_finished)])

	settings.reset_to_defaults()
	DirAccess.remove_absolute(settings.settings_path)
	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		saves.delete_slot(slot)
	DirAccess.remove_absolute(saves.save_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("soc_controller: %d failures" % _failures.size())
	_tree.quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _frames(count: int = 3) -> void:
	for _i: int in count:
		await _tree.process_frame


func _focus_owner() -> Control:
	return _tree.root.gui_get_focus_owner()


# --- event builders: the physical events, not named actions ---------------------

func _pad_button(button: JoyButton) -> void:
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = button
	press.pressed = true
	_tree.root.push_input(press)
	var release: InputEventJoypadButton = InputEventJoypadButton.new()
	release.button_index = button
	release.pressed = false
	_tree.root.push_input(release)


func _stick(axis: JoyAxis, value: float) -> void:
	var push: InputEventJoypadMotion = InputEventJoypadMotion.new()
	push.axis = axis
	push.axis_value = value
	_tree.root.push_input(push)
	var rest: InputEventJoypadMotion = InputEventJoypadMotion.new()
	rest.axis = axis
	rest.axis_value = 0.0
	_tree.root.push_input(rest)


func _key(keycode: Key, unicode: int = 0) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.unicode = unicode
	press.pressed = true
	_tree.root.push_input(press)
	var release: InputEventKey = InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	_tree.root.push_input(release)


# --- checks ---------------------------------------------------------------------

## The real InputMap, as configured by the project and InputActions.register().
func _check_configured_mappings() -> void:
	var expected_buttons: Dictionary = {
		&"ui_up": JOY_BUTTON_DPAD_UP, &"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT, &"ui_right": JOY_BUTTON_DPAD_RIGHT,
		&"ui_accept": JOY_BUTTON_A, &"ui_cancel": JOY_BUTTON_B,
		&"nav_prev": JOY_BUTTON_LEFT_SHOULDER, &"nav_next": JOY_BUTTON_RIGHT_SHOULDER,
	}
	for action: StringName in expected_buttons:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == expected_buttons[action]:
				found = true
		_check(found, "%s is bound to joypad button %d" % [action, expected_buttons[action]])
	var expected_axes: Dictionary = {
		&"ui_up": [JOY_AXIS_LEFT_Y, -1.0], &"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
		&"ui_left": [JOY_AXIS_LEFT_X, -1.0], &"ui_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	for action: StringName in expected_axes:
		var spec: Array = expected_axes[action]
		var found_axis: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == spec[0] and signf((event as InputEventJoypadMotion).axis_value) == signf(spec[1]):
				found_axis = true
		_check(found_axis, "%s is bound to the left stick (axis %d, %s)" % [action, spec[0], spec[1]])
	_check(InputMap.action_get_deadzone(&"ui_up") >= 0.4, "the stick dead-zone is not tiny (%.2f)" % InputMap.action_get_deadzone(&"ui_up"))

func _check_mapping_reaches_focus_navigation() -> void:
	_shell.show_screen(&"command_center")
	await _frames(4)
	var nav: Button = _shell.nav_button(&"command_center")
	nav.grab_focus()
	await _frames()
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"investigation"), "D-pad Down moves focus from the first nav item to the second (owner %s)" % _focus_owner())
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(_focus_owner() == nav, "D-pad Up moves it back (owner %s)" % _focus_owner())


func _check_confirm_cancel_and_shoulders() -> void:
	# A (confirm) activates the focused navigation button.
	_shell.nav_button(&"investigation").grab_focus()
	await _frames()
	_pad_button(BTN_A)
	await _frames(3)
	_check(_shell.current_id == &"investigation", "A on the focused nav item opens that screen (now %s)" % _shell.current_id)
	# RB / LB switch screens and wrap.
	_pad_button(BTN_RB)
	await _frames(3)
	_check(_shell.current_id == &"cases", "RB opens the next screen (now %s)" % _shell.current_id)
	_pad_button(BTN_LB)
	_pad_button(BTN_LB)
	await _frames(3)
	_check(_shell.current_id == &"command_center", "LB twice goes back two screens (now %s)" % _shell.current_id)
	_pad_button(BTN_LB)
	await _frames(3)
	_check(_shell.current_id == &"design_system", "LB from the first screen wraps to the last (now %s)" % _shell.current_id)
	# B (cancel) from inside a screen goes to the navigation, not away.
	_shell.show_screen(&"investigation")
	await _frames(4)
	_check(_focus_owner() != _shell.nav_button(&"investigation"), "focus starts inside the screen")
	_pad_button(BTN_B)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"investigation"), "B moves focus from the screen to its navigation item (owner %s)" % _focus_owner())
	# B again on the navigation asks to leave for the title.
	var requested: Array[StringName] = []
	var flow: SceneFlow = _tree.root.get_node("Scenes")
	flow.scene_requested.connect(func(id: StringName) -> void: requested.append(id), CONNECT_ONE_SHOT)
	_pad_button(BTN_B)
	await _frames(2)
	_check(requested == [&"title"], "B on the navigation asks to return to the title (got %s)" % str(requested))
	await _frames(4)
	if is_instance_valid(_shell):
		_shell.queue_free()
	_shell = load(SceneFlow.path_for(&"soc")).instantiate()
	add_child(_shell)
	await _frames(4)


func _check_stick_and_tables() -> void:
	_shell.show_screen(&"investigation")
	await _frames(4)
	var screen: Control = _shell.screen_node(&"investigation")
	screen._clear_filters()
	await _frames(2)
	var table: Tree = screen._table
	table.grab_focus()
	await _frames()
	table.get_root().get_child(0).select(0)
	await _frames()
	var first: TreeItem = table.get_selected()
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(table.get_selected() != null and table.get_selected() != first, "D-pad Down moves the table selection")
	var after_down: TreeItem = table.get_selected()
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(table.get_selected() != after_down, "and moves it again")
	_pad_button(BTN_DPAD_UP)
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(table.get_selected() == first, "D-pad Up twice returns to the first row")
	_check(screen._count_label.text.contains("Showing"), "the table is the filtered list")
	# A on a row activates it (item_activated) without changing screens unexpectedly.
	var selected_before: String = screen._table.get_selected().get_text(1)
	_pad_button(BTN_A)
	await _frames()
	_check(table.get_selected() != null and table.get_selected().get_text(1) == selected_before, "A on a row keeps the selection")


func _check_text_field_active() -> void:
	_shell.show_screen(&"terminal")
	await _frames(4)
	var screen: Control = _shell.screen_node(&"terminal")
	var line: LineEdit = screen._command_line
	line.grab_focus()
	await _frames()
	_check(_focus_owner() == line, "the command line takes focus")
	# Typing a bracket into the field must type it, not switch screens.
	_key(KEY_BRACKETLEFT, 91)
	await _frames()
	_check(_shell.current_id == &"terminal", "a bracket typed into the field does not switch screens")
	_check(line.text.contains("["), "and is typed into the field (text '%s')" % line.text)
	line.text = ""
	# Shoulder buttons still switch screens while the field is active.
	_pad_button(BTN_RB)
	await _frames(3)
	_check(_shell.current_id == &"mission", "RB switches screens even while a text field had focus (now %s)" % _shell.current_id)
	_pad_button(BTN_LB)
	await _frames(3)
	_check(_shell.current_id == &"terminal", "and LB comes back (now %s)" % _shell.current_id)
	# B from the field goes to the navigation.
	screen._command_line.grab_focus()
	await _frames()
	_pad_button(BTN_B)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"terminal"), "B in the text field moves focus to the navigation (owner %s)" % _focus_owner())


func _check_terminal_history_and_scroll() -> void:
	_shell.show_screen(&"terminal")
	await _frames(4)
	var screen: Control = _shell.screen_node(&"terminal")
	for command: String in ["help", "assets list", "case show"]:
		screen.run_line(command)
	await _frames(2)
	var line: LineEdit = screen._command_line
	line.grab_focus()
	await _frames()
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(line.text == "case show", "D-pad Up recalls the newest command (text '%s')" % line.text)
	_pad_button(BTN_DPAD_UP)
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(line.text == "help", "two more Ups reach the oldest command (text '%s')" % line.text)
	# At the oldest entry another Up must leave the field, so focus is never held.
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(_focus_owner() != line, "Up at the oldest entry moves focus out of the field (owner %s)" % _focus_owner())
	# Back in, Down walks forward and then leaves downward.
	line.grab_focus()
	await _frames()
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(_focus_owner() != line or line.text != "", "Down from the field is not swallowed")
	# The console scrolls with the stick when it has focus.
	for _i: int in 12:
		screen.run_line("help")
	await _frames(3)
	var output: RichTextLabel = screen._output
	output.grab_focus()
	await _frames()
	var bar: VScrollBar = output.get_v_scroll_bar()
	_check(bar.max_value > bar.page, "the console has more output than fits (scrollable)")
	var before: float = bar.value
	_pad_button(BTN_DPAD_UP)
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(bar.value < before, "D-pad Up scrolls the focused console up (%.0f -> %.0f)" % [before, bar.value])
	_check(_focus_owner() == output, "and focus stays on the console while it can still scroll")
	var after_up: float = bar.value
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(bar.value > after_up, "D-pad Down scrolls it back down (%.0f -> %.0f)" % [after_up, bar.value])
	# At the very top the console no longer takes Up (it is not consumed or scrolled), and the
	# console can be left in other directions, so it is never a trap.
	bar.value = bar.min_value
	await _frames()
	_pad_button(BTN_DPAD_UP)
	await _frames()
	_check(bar.value <= bar.min_value + 0.5, "Up at the top does not scroll further")
	_check(output.find_valid_focus_neighbor(SIDE_BOTTOM) == screen._command_line, "Down from the console reaches the command line")
	_check(output.find_valid_focus_neighbor(SIDE_RIGHT) != null, "Right from the console reaches the sample commands")


func _check_dialog_focus() -> void:
	_shell.show_screen(&"design_system")
	await _frames(4)
	var screen: Control = _shell.screen_node(&"design_system")
	var opener: Button = null
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).text == "Open sample dialog":
			opener = node
	_check(opener != null, "the dialog opener exists")
	if opener == null:
		return
	opener.grab_focus()
	await _frames()
	_pad_button(BTN_A)
	await _frames(3)
	var dialog: ModalDialog = null
	for child: Node in _shell.get_children():
		if child is ModalDialog:
			dialog = child
	_check(dialog != null, "A on the opener opens the dialog")
	if dialog == null:
		return
	_check(_focus_owner() == dialog.cancel_button, "the dialog starts on the safe choice (owner %s)" % _focus_owner())
	# Focus is trapped between its two buttons.
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_pad_button(BTN_DPAD_UP)
	_pad_button(BTN_DPAD_UP)
	await _frames()
	var inside: bool = _focus_owner() == dialog.cancel_button or _focus_owner() == dialog.confirm_button
	_check(inside, "D-pad cannot move focus out of the dialog (owner %s)" % _focus_owner())
	_pad_button(BTN_B)
	await _frames(3)
	_check(not is_instance_valid(dialog) or not dialog.is_inside_tree(), "B closes the dialog")
	_check(_focus_owner() == opener, "focus returns to the control that opened it (owner %s)" % _focus_owner())
	_check(screen._dialog_result.text.contains("cancelled"), "and the screen is told it was cancelled")


func _check_mouse_then_controller() -> void:
	# Synthetic mouse clicks do not register in a headless run, so this checks the part
	# that can be proved here: a Button takes focus when clicked (focus_mode is ALL), and
	# the controller and keyboard then carry on from that control. The click itself is
	# on the physical test plan.
	_shell.show_screen(&"command_center")
	await _frames(4)
	var target: Button = _shell.nav_button(&"cases")
	_check(target.focus_mode == Control.FOCUS_ALL, "nav items take focus when clicked")
	target.grab_focus()
	await _frames()
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"terminal"), "D-pad continues from the clicked item (owner %s)" % _focus_owner())
	_key(KEY_UP)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"cases"), "keyboard Up moves focus back (owner %s)" % _focus_owner())
	_pad_button(BTN_DPAD_DOWN)
	await _frames()
	_check(_focus_owner() == _shell.nav_button(&"terminal"), "and the controller still works afterwards")


func _check_focus_when_returning() -> void:
	# Current behaviour, recorded so a change is deliberate: a screen always opens on
	# its default control; it does not remember where focus was last time.
	_shell.show_screen(&"investigation")
	await _frames(4)
	var screen: SocScreen = _shell.screen_node(&"investigation")
	var default_target: Control = screen.default_focus()
	var table: Control = screen._table
	table.grab_focus()
	await _frames()
	_shell.show_screen(&"terminal")
	await _frames(4)
	_shell.show_screen(&"investigation")
	await _frames(4)
	_check(_focus_owner() == default_target, "returning to a screen puts focus on its default control (owner %s)" % _focus_owner())
	_check(is_instance_valid(_focus_owner()) and _focus_owner().is_visible_in_tree(), "and that control is visible")
