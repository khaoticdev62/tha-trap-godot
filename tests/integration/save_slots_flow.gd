extends Node
## Integration check for the save slot screen: slot cards, load mode, new mode
## (including the replace confirmation), deleting with a confirmation, and
## going back.
##   godot --headless --path . res://tests/integration/save_slots_flow.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var tree: SceneTree = get_tree()
	tree.create_timer(30.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 30s")
		tree.quit(1))
	var root: Window = tree.root
	tree.current_scene = null
	var saves: SaveService = root.get_node_or_null("Saves")
	if saves == null:
		print("FAIL  autoloads are not available")
		tree.quit(1)
		return
	var test_dir: String = "user://itest_slots_%d" % Time.get_ticks_usec()
	saves.save_dir = test_dir
	AppBootstrap.run(tree)
	var progress: ProgressService = root.get_node("Progress")
	var game: SaveGame = SaveGame.from_tree(tree)
	game.fixed_unix_time = 10
	game.start_new(0, "Kai", "", "", "", "")
	# Slot 3 holds a file whose progress is damaged.
	saves.save_slot(2, {"profile": {}, "progress": {"version": 1, "difficulty": "nightmare"}, "meta": {}})

	# --- load mode ---
	progress.slot_screen_mode = "load"
	var scene: Control = load(SceneFlow.path_for(&"save_slots")).instantiate()
	add_child(scene)
	await tree.process_frame
	var slot_buttons: Array[Button] = _buttons_starting(scene, "Slot ")
	var delete_buttons: Array[Button] = _buttons_starting(scene, "Delete")
	_check(slot_buttons.size() == 3 and delete_buttons.size() == 3, "three slots, each with a Delete button")
	_check(slot_buttons[0].text.begins_with("Slot 1: Kai") and not slot_buttons[0].disabled, "slot 1 shows the character and can be loaded")
	_check(slot_buttons[1].text == "Slot 2: Empty" and slot_buttons[1].disabled, "an empty slot cannot be loaded")
	_check(slot_buttons[2].text.contains("Cannot be loaded") and slot_buttons[2].disabled, "a damaged slot says so and cannot be loaded")
	_check(delete_buttons[0].disabled == false and delete_buttons[1].disabled and delete_buttons[2].disabled == false, "Delete is available exactly where a file exists")
	_check(root.gui_get_focus_owner() == slot_buttons[0], "focus starts on the first usable slot")
	_check(slot_buttons[0].custom_minimum_size.y >= 44.0 and delete_buttons[0].custom_minimum_size.y >= 44.0, "buttons meet the minimum target size")

	var loads: Array[int] = []
	root.get_node("EventBus").load_completed.connect(func(slot: int, _r: bool) -> void: loads.append(slot))
	slot_buttons[0].pressed.emit()
	await tree.process_frame
	_check(loads == [0] and progress.active_slot == 0 and root.get_node("Profiles").current.display_name == "Kai", "choosing a slot loads it and makes it active")

	# --- delete with confirmation ---
	delete_buttons[2].grab_focus()
	delete_buttons[2].pressed.emit()
	await tree.process_frame
	var keep: Button = _find_button(scene, "Keep it")
	var confirm: Button = _find_button(scene, "Delete slot 3")
	_check(keep != null and confirm != null and keep.is_visible_in_tree(), "Delete asks for confirmation")
	_check(root.gui_get_focus_owner() == keep, "the dialog focuses the safe choice")
	_press_cancel()
	await tree.process_frame
	await tree.process_frame
	_check(_find_button(scene, "Keep it") == null and saves.has_save(2), "cancelling keeps the save")
	delete_buttons[2].pressed.emit()
	await tree.process_frame
	_find_button(scene, "Delete slot 3").pressed.emit()
	await tree.process_frame
	_check(not saves.has_save(2), "confirming deletes the slot")
	slot_buttons = _buttons_starting(scene, "Slot ")
	_check(slot_buttons[2].text == "Slot 3: Empty", "the list refreshes")
	_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(), "focus is not lost after a delete")

	# --- back ---
	var went_to: Array[StringName] = []
	root.get_node("Scenes").scene_changed.connect(func(id: StringName) -> void: went_to.append(id))
	_find_button(scene, "Back").pressed.emit()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	scene._unhandled_input(cancel)
	_check(went_to == [&"title", &"title"], "Back and ui_cancel both return to the title (got %s)" % str(went_to))
	went_to.clear()

	# --- new mode ---
	scene.queue_free()
	await tree.process_frame
	progress.slot_screen_mode = "new"
	scene = load(SceneFlow.path_for(&"save_slots")).instantiate()
	add_child(scene)
	await tree.process_frame
	slot_buttons = _buttons_starting(scene, "Slot ")
	_check(not slot_buttons[0].disabled and not slot_buttons[1].disabled and not slot_buttons[2].disabled, "every slot can start a new game")
	_check(slot_buttons[0].text.contains("(will be replaced)") and not slot_buttons[1].text.contains("(will be replaced)"), "only an occupied slot warns that it will be replaced")

	slot_buttons[0].pressed.emit()
	await tree.process_frame
	var keep_save: Button = _find_button(scene, "Keep my save")
	_check(keep_save != null and _find_button(scene, "Replace save and start new") != null, "choosing an occupied slot asks first")
	_check(root.gui_get_focus_owner() == keep_save, "the dialog focuses the safe choice")
	_press_cancel()
	await tree.process_frame
	await tree.process_frame
	_check(went_to.is_empty() and saves.has_save(0), "cancelling goes nowhere and keeps the save")

	slot_buttons[1].pressed.emit()
	_check(went_to == [&"creator"] and progress.active_slot == 1, "an empty slot goes straight to the creator for that slot")
	went_to.clear()
	slot_buttons[0].pressed.emit()
	await tree.process_frame
	_find_button(scene, "Replace save and start new").pressed.emit()
	_check(went_to == [&"creator"] and progress.active_slot == 0, "confirming goes to the creator for that slot")
	_check(saves.has_save(0), "and the old save survives until the new character is created")

	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		saves.delete_slot(slot)
	DirAccess.remove_absolute(test_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("save_slots_flow: %d failures" % _failures.size())
	tree.quit(1 if _failures.size() > 0 else 0)


func _press_cancel() -> void:
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.begins_with(text):
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _buttons_starting(node: Node, text: String) -> Array[Button]:
	var found: Array[Button] = []
	if node is Button and (node as Button).text.begins_with(text):
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_buttons_starting(child, text))
	return found
