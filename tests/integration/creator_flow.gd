extends Node
## Integration check: fills in the character creator like a player (including
## hostile and blank names), starts the game, and confirms the profile saved to
## disk, then Back / ui_cancel navigation.
##   godot --headless --path . res://tests/integration/creator_flow.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var tree: SceneTree = get_tree()
	tree.create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		tree.quit(1))
	var root: Window = tree.root
	# SceneFlow frees the current scene on every transition. Detach this test node
	# from that slot so it survives the swaps the creator triggers.
	tree.current_scene = null
	var saves: SaveService = root.get_node_or_null("Saves")
	if saves == null:
		print("FAIL  autoloads are not available")
		tree.quit(1)
		return
	var test_dir: String = "user://itest_creator_%d" % Time.get_ticks_usec()
	saves.save_dir = test_dir
	AppBootstrap.run(tree)

	var screen: Control = load(SceneFlow.path_for(&"creator")).instantiate()
	add_child(screen)
	await tree.process_frame

	var name_edit: LineEdit = _first_line_edit(screen)
	var choices: Array[OptionButton] = []
	_collect_choices(screen, choices)
	_check(name_edit != null and choices.size() == 4, "form shows a name field and four choices")
	_check(root.gui_get_focus_owner() == name_edit, "focus starts on the name field")
	_check(name_edit.max_length == AppConfig.PROFILE_NAME_MAX_LENGTH, "name length is capped in the field")
	_check(_has_scroll_container(screen), "form is scrollable for large text")
	_check(choices[0].item_count == CharacterOptions.PRONOUNS.size(), "pronoun choices match the data")
	_check(choices[1].item_count == CharacterOptions.SKIN_TONES.size(), "skin tone choices match the data")
	_check(choices[2].item_count == CharacterOptions.HAIR_STYLES.size(), "hair choices match the data")
	_check(choices[3].item_count == CharacterOptions.OUTFIT_PALETTES.size(), "outfit choices match the data")

	# Pick non-default options and a hostile name, then start.
	name_edit.text = "  <b>Kai</b>\n  Lee  "
	choices[0].select(3)
	choices[1].select(5)
	choices[2].select(2)
	choices[3].select(1)
	choices[1].item_selected.emit(5)
	_find_button(screen, "Start").pressed.emit()
	await tree.process_frame

	var loaded: SaveResult = saves.read_slot(0)
	_check(loaded.ok, "Start writes a valid save to slot 0")
	var profile: PlayerProfile = PlayerProfile.from_dict(loaded.payload.get("profile"))
	_check(profile.display_name == "<b>Kai</b> Lee", "name is sanitised but kept as plain text (got '%s')" % profile.display_name)
	_check(profile.pronouns == "they/them", "pronouns saved")
	_check(profile.skin_tone == "tone_deep_brown", "skin tone saved")
	_check(profile.hair_style == "hair_locs", "hair saved")
	_check(profile.outfit_palette == "outfit_copper", "outfit saved")
	_check(root.get_node("Profiles").current.display_name == "<b>Kai</b> Lee", "ProfileService holds the new profile")

	# A blank name falls back to the default rather than saving nothing.
	var second: Control = load(SceneFlow.path_for(&"creator")).instantiate()
	add_child(second)
	await tree.process_frame
	_first_line_edit(second).text = "   "
	_find_button(second, "Start").pressed.emit()
	await tree.process_frame
	var fallback: PlayerProfile = PlayerProfile.from_dict(saves.read_slot(0).payload.get("profile"))
	_check(fallback.display_name == AppConfig.DEFAULT_PROFILE_NAME, "blank name uses the default name")

	# Back and ui_cancel both return to the title. Read results synchronously:
	# the scene swap frees this test node.
	var went_to: Array[StringName] = []
	root.get_node("Scenes").scene_changed.connect(func(id: StringName) -> void: went_to.append(id))
	var third: Control = load(SceneFlow.path_for(&"creator")).instantiate()
	add_child(third)
	await tree.process_frame
	_find_button(third, "Back").pressed.emit()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	third._unhandled_input(cancel)
	_check(went_to.size() >= 2 and went_to[-1] == &"title" and went_to[-2] == &"title", "Back and ui_cancel both return to the title")

	saves.delete_slot(0)
	DirAccess.remove_absolute(test_dir)
	for line: String in _failures:
		print("FAIL  ", line)
	print("creator_flow: %d failures" % _failures.size())
	tree.quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _first_line_edit(node: Node) -> LineEdit:
	if node is LineEdit:
		return node
	for child: Node in node.get_children():
		var found: LineEdit = _first_line_edit(child)
		if found != null:
			return found
	return null


func _has_scroll_container(node: Node) -> bool:
	if node is ScrollContainer:
		return true
	for child: Node in node.get_children():
		if _has_scroll_container(child):
			return true
	return false


func _collect_choices(node: Node, into: Array[OptionButton]) -> void:
	if node is OptionButton:
		into.append(node)
	for child: Node in node.get_children():
		_collect_choices(child, into)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and not node is OptionButton and (node as Button).text.begins_with(text):
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null
