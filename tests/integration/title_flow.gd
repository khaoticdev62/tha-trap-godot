extends Node
## Integration check: boots the real autoloads and the title scene and drives
## the buttons like a player: no saves, Continue picks the most recent save,
## New Game and Load Game open the slot screen in the right mode.
##   godot --headless --path . res://tests/integration/title_flow.tscn
## Runs as a scene (not -s) so the project's autoloads exist. Uses a throwaway
## save folder; the player's real saves are never touched.

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var tree: SceneTree = get_tree()
	tree.create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		tree.quit(1))
	var root: Window = tree.root
	# SceneFlow replaces the current scene on every transition; keep this node out of that slot.
	tree.current_scene = null
	var saves: SaveService = root.get_node_or_null("Saves")
	if saves == null:
		print("FAIL  autoloads are not available")
		tree.quit(1)
		return
	var test_dir: String = "user://itest_title_%d" % Time.get_ticks_usec()
	saves.save_dir = test_dir
	AppBootstrap.run(tree)
	var progress: ProgressService = root.get_node("Progress")
	var game: SaveGame = SaveGame.from_tree(tree)

	# No saves yet.
	var scene: Control = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(scene)
	await tree.process_frame
	var continue_button: Button = _find_button(scene, "Continue")
	var new_button: Button = _find_button(scene, "New Game")
	var load_button: Button = _find_button(scene, "Load Game")
	_check(continue_button != null and new_button != null and load_button != null, "title shows Continue, New Game and Load Game")
	_check(continue_button.disabled and continue_button.text.contains("no save yet"), "Continue is disabled with no save")
	_check(load_button.disabled, "Load Game is disabled with no save")
	_check(root.gui_get_focus_owner() == new_button, "focus starts on New Game when there is no save")
	_check(new_button.custom_minimum_size.y >= 44.0, "buttons meet the minimum target size")

	# Two saves: slot 3 is the most recent.
	game.fixed_unix_time = 50
	game.start_new(0, "Older", "", "", "", "")
	game.fixed_unix_time = 90
	game.start_new(2, "Newer", "", "", "", "")
	scene.queue_free()
	await tree.process_frame
	scene = load(SceneFlow.path_for(&"title")).instantiate()
	add_child(scene)
	await tree.process_frame
	continue_button = _find_button(scene, "Continue")
	_check(not continue_button.disabled, "Continue enables when a usable save exists")
	_check(not _find_button(scene, "Load Game").disabled, "Load Game enables too")
	_check(root.gui_get_focus_owner() == continue_button, "focus starts on Continue when a save exists")

	var loads: Array[int] = []
	root.get_node("EventBus").load_completed.connect(func(slot: int, _r: bool) -> void: loads.append(slot))
	continue_button.pressed.emit()
	await tree.process_frame
	_check(loads == [2], "Continue loads the most recently saved slot and the EventBus relays it (got %s)" % str(loads))
	_check(progress.active_slot == 2, "that slot becomes the active slot")
	_check(root.get_node("Profiles").current.display_name == "Newer", "and its character is loaded")

	# New Game and Load Game open the slot screen in their own modes.
	var went_to: Array[StringName] = []
	root.get_node("Scenes").scene_changed.connect(func(id: StringName) -> void: went_to.append(id))
	var modes: Array[String] = []
	_find_button(scene, "New Game").pressed.emit()
	modes.append(progress.slot_screen_mode)
	_find_button(scene, "Load Game").pressed.emit()
	modes.append(progress.slot_screen_mode)
	_check(went_to == [&"save_slots", &"save_slots"], "both buttons open the slot screen (got %s)" % str(went_to))
	_check(modes == ["new", "load"], "in 'new' and 'load' mode respectively (got %s)" % str(modes))

	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		saves.delete_slot(slot)
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
