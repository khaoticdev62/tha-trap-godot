extends Control
## Accessibility settings screen: text size, reduced motion, high contrast.
## Changes apply immediately (live preview) and persist through SettingsService.
## Fully operable with keyboard or controller; ui_cancel goes back.

var _settings: SettingsService
var _syncing: bool = false

var _scale_slider: HSlider
var _scale_value: Label
var _motion_check: CheckButton
var _contrast_check: CheckButton
var _speed_choice: OptionButton
var _hint: HintBar
var _status: Label
var _back_button: Button


func _ready() -> void:
	_settings = get_node("/root/Settings")
	_build_ui()
	_sync_controls()
	_scale_slider.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Palette.OBSIDIAN
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_settings.changed.connect(_on_settings_changed)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(720, 0)
	center.add_child(column)

	column.add_child(_label("Settings", &"HeadingLabel"))
	column.add_child(_label("Accessibility", &"MutedLabel"))

	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 16)
	column.add_child(scale_row)
	scale_row.add_child(_label("Text size", &""))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = AppConfig.TEXT_SCALE_MIN
	_scale_slider.max_value = AppConfig.TEXT_SCALE_MAX
	_scale_slider.step = AccessibilitySettings.TEXT_SCALE_STEP
	_scale_slider.custom_minimum_size = Vector2(320, UiTheme.MIN_TARGET_HEIGHT)
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.focus_mode = Control.FOCUS_ALL
	_name_for_assistive_tech(_scale_slider, "Text size", "Left and right change the text size.")
	_scale_slider.value_changed.connect(_on_value_changed)
	scale_row.add_child(_scale_slider)
	_scale_value = _label("100%", &"")
	scale_row.add_child(_scale_value)

	_motion_check = _check("Reduce motion", "Turns off screen transitions and animated effects.")
	column.add_child(_motion_check)
	_contrast_check = _check("High contrast", "Uses a black and white scheme with a yellow focus outline.")
	column.add_child(_contrast_check)

	column.add_child(_label("Dialogue text speed", &""))
	_speed_choice = OptionButton.new()
	_speed_choice.custom_minimum_size = Vector2(420, UiTheme.MIN_TARGET_HEIGHT)
	_speed_choice.focus_mode = Control.FOCUS_ALL
	for option: Dictionary in AccessibilitySettings.TEXT_SPEEDS:
		_speed_choice.add_item(option["name"])
		_speed_choice.set_item_metadata(_speed_choice.item_count - 1, option["id"])
	_name_for_assistive_tech(_speed_choice, "Dialogue text speed", "How fast dialogue text appears. Instant shows whole lines at once.")
	_speed_choice.item_selected.connect(func(_i: int) -> void: _on_value_changed(0.0))
	column.add_child(_speed_choice)

	var sample: Label = _label("Sample: Learn. Defend. Level Up.", &"MutedLabel")
	sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sample)

	var reset_button: Button = _button("Reset to defaults", _on_reset_pressed)
	column.add_child(reset_button)
	_back_button = _button("Back", _go_back)
	column.add_child(_back_button)

	_status = _label("", &"MutedLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_hint = HintBar.new()
	column.add_child(_hint)
	_hint.bind(_scale_slider, "Makes all text larger or smaller. Left and right change it.")
	_hint.bind(_motion_check, "Turns off animated effects, including typed-out dialogue.")
	_hint.bind(_contrast_check, "Black and white colours with a bright yellow focus outline.")
	_hint.bind(_speed_choice, "Dialogue never moves on by itself. Press accept to finish a line early.")
	_hint.bind(reset_button, "Puts every accessibility setting back to its default.")
	_hint.bind(_back_button, "Return to the title screen. Escape or B also works.")


func _label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, UiTheme.MIN_TARGET_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(handler)
	return button


func _check(text: String, description: String) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.custom_minimum_size = Vector2(420, UiTheme.MIN_TARGET_HEIGHT)
	check.focus_mode = Control.FOCUS_ALL
	_name_for_assistive_tech(check, text, description)
	check.toggled.connect(func(_pressed: bool) -> void: _on_value_changed(0.0))
	return check


## Sets screen-reader name/description when the engine exposes them.
func _name_for_assistive_tech(control: Control, accessible_name: String, description: String) -> void:
	if "accessibility_name" in control:
		control.set("accessibility_name", accessible_name)
	if "accessibility_description" in control:
		control.set("accessibility_description", description)


func _sync_controls() -> void:
	_syncing = true
	var current: AccessibilitySettings = _settings.current
	_scale_slider.value = current.text_scale
	_motion_check.button_pressed = current.reduced_motion
	_contrast_check.button_pressed = current.high_contrast
	_speed_choice.select(_speed_index(current.text_speed))
	_scale_value.text = "%d%%" % roundi(current.text_scale * 100.0)
	_syncing = false


func _speed_index(speed_id: String) -> int:
	for index: int in _speed_choice.item_count:
		if _speed_choice.get_item_metadata(index) == speed_id:
			return index
	return 0


func _on_value_changed(_ignored: float) -> void:
	if _syncing:
		return
	var saved: bool = _settings.update(_scale_slider.value, _motion_check.button_pressed, _contrast_check.button_pressed, str(_speed_choice.get_item_metadata(_speed_choice.selected)))
	_status.text = "" if saved else "Your change applies now but could not be saved to disk."


func _on_settings_changed(current: AccessibilitySettings) -> void:
	_scale_value.text = "%d%%" % roundi(current.text_scale * 100.0)


func _on_reset_pressed() -> void:
	var saved: bool = _settings.reset_to_defaults()
	_sync_controls()
	_status.text = "Settings reset to defaults." if saved else "Reset applied but could not be saved to disk."


func _go_back() -> void:
	get_node("/root/Scenes").go_to(&"title")
