extends Control
## Title screen: Continue / New Game / Load Game / Settings / Quit, fully
## operable by controller. Continue loads the most recently saved slot. New Game
## and Load Game open the slot screen. Credits arrive with the rest of the UI
## system; they are not faked here.

const BUTTON_WIDTH: float = 420.0
const SCREEN_MARGIN: int = 32

var _game: SaveGame
var _progress: ProgressService
var _recent_slot: int = -1

var _continue_button: Button
var _new_game_button: Button
var _load_button: Button
var _status: Label


func _ready() -> void:
	_game = SaveGame.from_tree(get_tree())
	_progress = get_node("/root/Progress")
	_build_ui()
	_refresh_save_state()
	_focus_first_available()


func _build_ui() -> void:
	add_child(PageBackground.new())

	# Scrollable with margins so every control stays reachable at large text sizes.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, SCREEN_MARGIN)
	scroll.add_child(margin)

	var center: CenterContainer = CenterContainer.new()
	margin.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	column.add_child(_label(AppConfig.GAME_TITLE, &"TitleLabel"))
	column.add_child(_label(AppConfig.GAME_TAGLINE, &"HeadingLabel"))
	column.add_child(_spacer(24))

	var menu: VBoxContainer = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	column.add_child(menu)
	_continue_button = _add_button(menu, "Continue", _on_continue_pressed)
	_new_game_button = _add_button(menu, "New Game", _on_new_game_pressed)
	_load_button = _add_button(menu, "Load Game", _on_load_game_pressed)
	_add_button(menu, "SOC Console", _on_soc_pressed)
	_add_button(menu, "Settings", _on_settings_pressed)
	_add_button(menu, "Quit", _on_quit_pressed)

	column.add_child(_spacer(16))
	_status = _label("", &"MutedLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(760, 0)
	column.add_child(_status)
	column.add_child(_label("v%s" % AppConfig.VERSION, &"MutedLabel"))


func _label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, UiTheme.MIN_TARGET_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


## Continue follows the most recent usable save; Load Game is available whenever
## any slot holds a file, so a damaged one can still be seen and deleted.
func _refresh_save_state() -> void:
	_recent_slot = _game.most_recent_slot()
	var any_file: bool = false
	var damaged: int = 0
	for summary: SlotSummary in _game.summaries():
		if summary.exists:
			any_file = true
			if not summary.usable:
				damaged += 1
	_continue_button.disabled = _recent_slot < 0
	_continue_button.text = "Continue" if _recent_slot >= 0 else ("Continue (no usable save)" if any_file else "Continue (no save yet)")
	_load_button.disabled = not any_file
	if damaged > 0:
		_set_status("%d save slot%s cannot be loaded. Open Load Game to see why or delete %s." % [damaged, "" if damaged == 1 else "s", "it" if damaged == 1 else "them"])


func _focus_first_available() -> void:
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _set_status(text: String) -> void:
	_status.text = text


func _on_continue_pressed() -> void:
	var result: SaveResult = _game.load_slot(_recent_slot)
	if not result.ok:
		_set_status(result.message)
		_refresh_save_state()
		return
	var note: String = " (restored from backup)" if result.recovered_from_backup else ""
	_set_status("Welcome back, %s%s. The world map is not built yet; the SOC Console is open from this menu." % [get_node("/root/Profiles").current.display_name, note])


func _on_new_game_pressed() -> void:
	_open_slots("new")


func _on_load_game_pressed() -> void:
	_open_slots("load")


func _open_slots(mode: String) -> void:
	_progress.slot_screen_mode = mode
	get_node("/root/Scenes").go_to(&"save_slots")


func _on_soc_pressed() -> void:
	get_node("/root/Scenes").go_to(&"soc")


func _on_settings_pressed() -> void:
	get_node("/root/Scenes").go_to(&"settings")


func _on_quit_pressed() -> void:
	get_tree().quit()
