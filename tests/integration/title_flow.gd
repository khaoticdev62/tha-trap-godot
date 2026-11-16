extends Node
## Integration check: boots the real autoloads and title scene, then drives the
## buttons the way a player would: Continue, the start-over modal (keep / replace)
## and New Game into the character creator.
##   godot --headless --path . res://tests/integration/title_flow.tscn
## Runs as a scene (not -s) so the project's autoloads exist. Uses a throwaway
## save folder; the player's real saves are never touched.

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# SceneFlow swaps out the current scene (this node), so keep our own reference.
	var tree: SceneTree = get_tree()
	tree.create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		tree.quit(1))
	var root: Window = tree.root
	var saves: SaveService = root.get_node_or_null("Saves")
	if saves == null:
		print("FAIL  autoloads are not available")
		tree.quit(1)
		return
	var test_dir: String = "user://itest_saves_%d" % Time.get_ticks_usec()
	saves.save_dir = test_dir
	AppBootstrap.run(tree)

	var scene: Control = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(scene)
	await tree.process_frame

	var continue_button: Button = _find_button(scene, "Continue")
	var new_button: Button = _find_button(scene, "New Game")
	_check(continue_button != null and new_button != null, "title shows Continue and New Game")
	_check(continue_button.disabled, "Continue is disabled with no save")
	_check(root.gui_get_focus_owner() == new_button, "focus starts on New Game when there is no save")
	_check(new_button.custom_minimum_size.y >= 44.0, "buttons meet the minimum target size")

	# With a save present, Continue works and the EventBus relays the load.
	var profiles: ProfileService = root.get_node("Profiles")
	profiles.create("Tester", "", "", "", "")
	saves.save_slot(0, profiles.to_payload())
	scene.queue_free()
	await tree.process_frame
	scene = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(scene)
	await tree.process_frame
	_check(not _find_button(scene, "Continue").disabled, "Continue enables when a save exists")
	_check(root.gui_get_focus_owner() == _find_button(scene, "Continue"), "focus starts on Continue when a save exists")

	var loads: Array[int] = []
	root.get_node("EventBus").load_completed.connect(func(slot: int, _r: bool) -> void: loads.append(slot))
	_find_button(scene, "Continue").pressed.emit()
	await tree.process_frame
	_check(loads == [0], "Continue loads slot 0 and the EventBus relays it")

	# New Game over a save asks first and focuses the safe choice; cancel keeps the save.
	var new_game: Button = _find_button(scene, "New Game")
	new_game.grab_focus()
	new_game.pressed.emit()
	await tree.process_frame
	var keep: Button = _find_button(scene, "Keep my save")
	var replace: Button = _find_button(scene, "Replace save")
	_check(keep != null and keep.is_visible_in_tree(), "New Game over an existing save asks first")
	_check(root.gui_get_focus_owner() == keep, "the dialog focuses the safe choice")
	_check(keep.get_node(keep.focus_neighbor_right) == replace and replace.get_node(replace.focus_neighbor_left) == keep, "focus is trapped between the two dialog buttons")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await tree.process_frame
	await tree.process_frame
	_check(_find_button(scene, "Keep my save") == null, "ui_cancel closes the dialog")
	_check(saves.has_save(0), "cancelling keeps the save")
	_check(root.gui_get_focus_owner() == new_game, "focus returns to the control that opened the dialog")

	# Final step: New Game then Replace leaves for the creator (this frees the test node).
	var went_to: Array[StringName] = []
	root.get_node("Scenes").scene_changed.connect(func(id: StringName) -> void: went_to.append(id))
	new_game.pressed.emit()
	await tree.process_frame
	var saved_before: bool = saves.has_save(0)
	_find_button(scene, "Replace save").pressed.emit()
	_check(went_to == [&"creator"], "confirming opens the character creator")
	_check(saved_before and saves.has_save(0), "the old save survives until the creator finishes")

	saves.delete_slot(0)
	DirAccess.remove_absolute(test_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("title_flow: %d failures" % _failures.size())
	tree.quit(1 if _failures.size() > 0 else 0)


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
