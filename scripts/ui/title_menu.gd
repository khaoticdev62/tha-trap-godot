extends Control
## Title screen: Continue / New Game / Settings / Quit, fully operable by
## controller. Phase-1 scope: one save slot (slot 0). Credits and the character
## creator arrive with the rest of the UI system; they are not faked here.

const PRIMARY_SLOT: int = 0
const BUTTON_WIDTH: float = 420.0

var _save: SaveService
var _profile: ProfileService

var _menu: VBoxContainer
var _continue_button: Button
var _new_game_button: Button
var _status: Label
var _confirm_box: VBoxContainer
var _confirm_no: Button


func _ready() -> void:
	_save = get_node("/root/Saves")
	_profile = get_node("/root/Profiles")
	_build_ui()
	_refresh_continue_state()
	_focus_first_available()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Palette.OBSIDIAN
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	column.add_child(_label(AppConfig.GAME_TITLE, &"TitleLabel"))
	column.add_child(_label(AppConfig.GAME_TAGLINE, &"HeadingLabel"))
	column.add_child(_spacer(24))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	column.add_child(_menu)
	_continue_button = _add_button(_menu, "Continue", _on_continue_pressed)
	_new_game_button = _add_button(_menu, "New Game", _on_new_game_pressed)
	_add_button(_menu, "Settings", _on_settings_pressed)
	_add_button(_menu, "Quit", _on_quit_pressed)

	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 12)
	_confirm_box.visible = false
	column.add_child(_confirm_box)
	var warning: Label = _label("Start over? This replaces your saved progress.", &"")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_box.add_child(warning)
	_confirm_no = _add_button(_confirm_box, "Keep my save", _on_confirm_no)
	_add_button(_confirm_box, "Replace save and start new", _on_confirm_yes)

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
	if _save.has_save(PRIMARY_SLOT):
		_show_confirm(true)
		return
	_start_new_game()


func _on_settings_pressed() -> void:
	get_node("/root/Scenes").go_to(&"settings")


func _on_confirm_no() -> void:
	_show_confirm(false)


func _on_confirm_yes() -> void:
	_show_confirm(false)
	_start_new_game()


func _show_confirm(visible_state: bool) -> void:
	_confirm_box.visible = visible_state
	_menu.visible = not visible_state
	if visible_state:
		# Focus the safe choice first so a stray button press cannot destroy a save.
		_confirm_no.grab_focus()
	else:
		_focus_first_available()


func _start_new_game() -> void:
	var profile: PlayerProfile = _profile.start_new(AppConfig.DEFAULT_PROFILE_NAME)
	var result: SaveResult = _save.save_slot(PRIMARY_SLOT, _profile.to_payload())
	if not result.ok:
		_set_status("Could not create your save: %s" % result.message)
		return
	_set_status("New game started as %s. The world map is not built yet." % profile.display_name)
	_refresh_continue_state()
	_focus_first_available()


func _on_quit_pressed() -> void:
	get_tree().quit()
