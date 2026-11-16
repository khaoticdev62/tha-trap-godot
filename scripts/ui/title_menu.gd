extends Control
## Title screen: Continue / New Game / Settings / Quit, fully operable by
## controller. Phase-1 scope: one save slot (slot 0). New Game goes through the
## character creator; starting over an existing save asks first (ModalDialog).
## Credits arrive with the rest of the UI system; they are not faked here.

const PRIMARY_SLOT: int = 0
const BUTTON_WIDTH: float = 420.0
const SCREEN_MARGIN: int = 32

var _save: SaveService
var _profile: ProfileService

var _continue_button: Button
var _new_game_button: Button
var _status: Label


func _ready() -> void:
	_save = get_node("/root/Saves")
	_profile = get_node("/root/Profiles")
	_build_ui()
	_refresh_continue_state()
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


func _refresh_continue_state() -> void:
	var peek: SaveResult = _save.read_slot(PRIMARY_SLOT)
	_continue_button.disabled = not peek.ok
	if peek.ok:
		_continue_button.text = "Continue"
	elif peek.code == SaveResult.Code.NOT_FOUND:
		_continue_button.text = "Continue (no save yet)"
	else:
		_continue_button.text = "Continue (save unavailable)"
		_set_status(peek.message)


func _focus_first_available() -> void:
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _set_status(text: String) -> void:
	_status.text = text


func _on_continue_pressed() -> void:
	var result: SaveResult = _save.load_slot(PRIMARY_SLOT)
	if not result.ok:
		_set_status(result.message)
		_refresh_continue_state()
		return
	var profile: PlayerProfile = _profile.load_from_payload(result.payload)
	var note: String = " (restored from backup)" if result.recovered_from_backup else ""
	_set_status("Welcome back, %s%s. The world map is not built yet." % [profile.display_name, note])


func _on_new_game_pressed() -> void:
	if not _save.has_save(PRIMARY_SLOT):
		_open_creator()
		return
	var dialog: ModalDialog = ModalDialog.open(
		self,
		"Start over?",
		"Creating a new character replaces your saved progress.",
		"Replace save and start new",
		"Keep my save",
	)
	dialog.confirmed.connect(_open_creator)


func _on_settings_pressed() -> void:
	get_node("/root/Scenes").go_to(&"settings")


func _open_creator() -> void:
	get_node("/root/Scenes").go_to(&"creator")


func _on_quit_pressed() -> void:
	get_tree().quit()
