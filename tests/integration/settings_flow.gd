extends Node
## Integration check: opens Settings from the title screen, changes every
## setting the way a player would, and confirms live theme updates, persistence,
## reset, and navigation back. Uses a throwaway settings file.
##   godot --headless --path . res://tests/integration/settings_flow.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# Keep our own reference: the scene swap below frees this node.
	var tree: SceneTree = get_tree()
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		get_tree().quit(1))
	var root: Window = get_tree().root
	var settings: SettingsService = root.get_node_or_null("Settings")
	if settings == null:
		print("FAIL  autoloads are not available")
		get_tree().quit(1)
		return
	var test_path: String = "user://itest_settings_%d.json" % Time.get_ticks_usec()
	settings.settings_path = test_path
	settings.load_from_disk()
	AppBootstrap.run(get_tree())

	_check(root.theme != null, "Settings installs a global theme at startup")
	_check(root.theme.default_font_size == UiTheme.BASE_FONT_SIZE, "theme starts at base size")

	# Title -> Settings
	var title: Control = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(title)
	await get_tree().process_frame
	_check(_find_button(title, "Settings") != null, "title offers Settings")
	title.queue_free()

	var screen: Control = load(SceneFlow.path_for(&"settings")).instantiate()
	add_child(screen)
	await get_tree().process_frame

	var slider: HSlider = _find_node(screen, "HSlider")
	var checks: Array[CheckButton] = []
	_collect_checks(screen, checks)
	_check(slider != null and checks.size() == 2, "screen shows a slider and two toggles")
	_check(root.gui_get_focus_owner() == slider, "focus starts on the first control")
	_check(slider.custom_minimum_size.y >= 44.0, "slider meets minimum target size")

	slider.value = 1.5
	await get_tree().process_frame
	_check(settings.current.text_scale == 1.5, "slider changes the service")
	_check(root.theme.default_font_size == roundi(UiTheme.BASE_FONT_SIZE * 1.5), "theme updates live")

	checks[0].button_pressed = true
	checks[1].button_pressed = true
	await get_tree().process_frame
	_check(settings.current.reduced_motion and settings.current.high_contrast, "toggles change the service")

	var speed: OptionButton = _find_node(screen, "OptionButton")
	_check(speed != null and speed.item_count == AccessibilitySettings.TEXT_SPEEDS.size(), "text speed offers every defined speed")
	speed.select(0)
	speed.item_selected.emit(0)
	await get_tree().process_frame
	_check(settings.current.text_speed == "slow", "text speed choice changes the service")

	var reloaded: SettingsService = SettingsService.new()
	reloaded.settings_path = test_path
	reloaded.apply_theme_to_root = false
	reloaded.load_from_disk()
	_check(reloaded.current.text_scale == 1.5 and reloaded.current.reduced_motion and reloaded.current.high_contrast and reloaded.current.text_speed == "slow", "changes persisted to disk")
	reloaded.free()

	_find_button(screen, "Reset to defaults").pressed.emit()
	await get_tree().process_frame
	_check(settings.current.to_dict() == AccessibilitySettings.new().to_dict(), "reset restores defaults")
	_check(slider.value == 1.0 and not checks[0].button_pressed and not checks[1].button_pressed and speed.selected == 1, "controls reflect the reset (speed back to Normal)")

	# Controller/keyboard cancel returns to the title. SceneFlow swaps out the
	# current scene (this test node), so read the result synchronously.
	var went_back: Array[bool] = [false]
	root.get_node("Scenes").scene_changed.connect(func(id: StringName) -> void: went_back[0] = id == &"title")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	_check(went_back[0], "ui_cancel goes back to the title screen")

	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	for line: String in _failures:
		print("FAIL  ", line)
	print("settings_flow: %d failures" % _failures.size())
	tree.quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _find_node(node: Node, class_name_text: String) -> Node:
	if node.get_class() == class_name_text:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node(child, class_name_text)
		if found != null:
			return found
	return null


func _collect_checks(node: Node, into: Array[CheckButton]) -> void:
	if node is CheckButton:
		into.append(node)
	for child: Node in node.get_children():
		_collect_checks(child, into)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.begins_with(text):
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null
