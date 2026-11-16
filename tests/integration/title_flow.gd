extends Node
## Integration check: boots the real autoloads and title scene, then drives the
## buttons the way a player would (New Game, Continue, overwrite confirm).
##   godot --headless --path . res://tests/integration/title_flow.tscn
## Runs as a scene (not -s) so the project's autoloads exist.
## Uses a throwaway save folder; the player's real saves are never touched.

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# A script error inside this coroutine would otherwise leave the process hanging.
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		get_tree().quit(1))
	var root: Window = get_tree().root
	var saves: SaveService = root.get_node_or_null("Saves")
	if saves == null:
		print("FAIL  autoloads are not available")
		get_tree().quit(1)
		return
	var test_dir: String = "user://itest_saves_%d" % Time.get_ticks_usec()
	saves.save_dir = test_dir
	AppBootstrap.run(get_tree())

	var scene: Control = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var continue_button: Button = _find_button(scene, "Continue")
	var new_button: Button = _find_button(scene, "New Game")
	_check(continue_button != null and new_button != null, "title shows Continue and New Game")
	_check(continue_button.disabled, "Continue is disabled with no save")
	_check(root.gui_get_focus_owner() == new_button, "focus starts on New Game when there is no save")
	_check(new_button.custom_minimum_size.y >= 44.0, "buttons meet the minimum touch/controller target size")

	new_button.pressed.emit()
	await get_tree().process_frame
	_check(saves.has_save(0), "New Game writes slot 0")
	_check(not _find_button(scene, "Continue").disabled, "Continue enables after New Game")

	var bus_events: Array[int] = []
	root.get_node("EventBus").load_completed.connect(func(slot: int, _r: bool) -> void: bus_events.append(slot))
	_find_button(scene, "Continue").pressed.emit()
	await get_tree().process_frame
	_check(bus_events == [0], "Continue loads slot 0 and the EventBus relays it")

	new_button.pressed.emit()
	await get_tree().process_frame
	var keep: Button = _find_button(scene, "Keep my save")
	_check(keep != null and keep.is_visible_in_tree(), "New Game over an existing save asks first")
	_check(root.gui_get_focus_owner() == keep, "confirm focuses the safe choice")
	keep.pressed.emit()
	await get_tree().process_frame
	_check(saves.has_save(0), "declining keeps the save")

	saves.delete_slot(0)
	DirAccess.remove_absolute(test_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("title_flow: %d failures" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


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
