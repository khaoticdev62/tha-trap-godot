extends Control
## Character creator: name, pronouns (optional) and cosmetic choices.
## Nothing here affects stats or story outcomes. Every choice is a labelled
## option (colour swatches are never the only signal). Operable by keyboard and
## controller; the form scrolls so it stays usable at large text sizes.

const PRIMARY_SLOT: int = 0
const FORM_WIDTH: float = 640.0
const SWATCH_SIZE: Vector2 = Vector2(48, 48)
const SCREEN_MARGIN: int = 32

var _profiles: ProfileService
var _saves: SaveService

var _name_edit: LineEdit
var _pronouns: OptionButton
var _skin: OptionButton
var _hair: OptionButton
var _outfit: OptionButton
var _skin_swatch: ColorRect
var _outfit_swatch: ColorRect
var _status: Label


func _ready() -> void:
	_profiles = get_node("/root/Profiles")
	_saves = get_node("/root/Saves")
	_build_ui()
	_refresh_swatches()
	_name_edit.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _build_ui() -> void:
	add_child(PageBackground.new())

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

	var outer: CenterContainer = CenterContainer.new()
	margin.add_child(outer)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(FORM_WIDTH, 0)
	outer.add_child(column)

	column.add_child(_label("Create your character", &"HeadingLabel"))
	var intro: Label = _label("These choices are cosmetic. They never change your skills, your story, or how people respond to you.", &"MutedLabel")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)

	column.add_child(_label("Name", &""))
	_name_edit = LineEdit.new()
	_name_edit.max_length = AppConfig.PROFILE_NAME_MAX_LENGTH
	_name_edit.placeholder_text = AppConfig.DEFAULT_PROFILE_NAME
	_name_edit.custom_minimum_size = Vector2(0, UiTheme.MIN_TARGET_HEIGHT)
	_name_edit.focus_mode = Control.FOCUS_ALL
	_describe(_name_edit, "Name", "Up to %d characters. Leave empty to use %s." % [AppConfig.PROFILE_NAME_MAX_LENGTH, AppConfig.DEFAULT_PROFILE_NAME])
	column.add_child(_name_edit)

	_pronouns = _add_choice(column, "Pronouns (optional)", CharacterOptions.PRONOUNS)
	_skin = _add_choice(column, "Skin tone", CharacterOptions.SKIN_TONES)
	_skin_swatch = _add_swatch(column, "Skin tone preview")
	_hair = _add_choice(column, "Hair", CharacterOptions.HAIR_STYLES)
	_outfit = _add_choice(column, "Outfit colour", CharacterOptions.OUTFIT_PALETTES)
	_outfit_swatch = _add_swatch(column, "Outfit colour preview")
	_skin.item_selected.connect(func(_i: int) -> void: _refresh_swatches())
	_outfit.item_selected.connect(func(_i: int) -> void: _refresh_swatches())

	column.add_child(_button("Start", _on_start_pressed))
	column.add_child(_button("Back", _back))
	_status = _label("", &"MutedLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _label(text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, UiTheme.MIN_TARGET_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(handler)
	return button


func _add_choice(parent: Control, caption: String, options: Array[Dictionary]) -> OptionButton:
	parent.add_child(_label(caption, &""))
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(0, UiTheme.MIN_TARGET_HEIGHT)
	choice.focus_mode = Control.FOCUS_ALL
	choice.fit_to_longest_item = false
	for option: Dictionary in options:
		choice.add_item(option["name"])
		choice.set_item_metadata(choice.item_count - 1, option["id"])
	_describe(choice, caption, "Choose one option.")
	parent.add_child(choice)
	return choice


func _add_swatch(parent: Control, accessible_name: String) -> ColorRect:
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_describe(swatch, accessible_name, "Decorative colour sample. The option name above is the real label.")
	parent.add_child(swatch)
	return swatch


func _describe(control: Control, accessible_name: String, description: String) -> void:
	if "accessibility_name" in control:
		control.set("accessibility_name", accessible_name)
	if "accessibility_description" in control:
		control.set("accessibility_description", description)


func _selected_id(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected))


func _refresh_swatches() -> void:
	var skin_index: int = CharacterOptions.index_of(CharacterOptions.SKIN_TONES, _selected_id(_skin))
	_skin_swatch.color = CharacterOptions.SKIN_TONES[skin_index]["color"]
	var outfit_index: int = CharacterOptions.index_of(CharacterOptions.OUTFIT_PALETTES, _selected_id(_outfit))
	_outfit_swatch.color = CharacterOptions.OUTFIT_PALETTES[outfit_index]["color"]


func _on_start_pressed() -> void:
	var profile: PlayerProfile = _profiles.create(
		_name_edit.text,
		_selected_id(_pronouns),
		_selected_id(_skin),
		_selected_id(_hair),
		_selected_id(_outfit),
	)
	var result: SaveResult = _saves.save_slot(PRIMARY_SLOT, _profiles.to_payload())
	if not result.ok:
		_status.text = "Could not create your save: %s" % result.message
		return
	_status.text = "Welcome, %s." % profile.display_name
	get_node("/root/Scenes").go_to(&"title")


func _back() -> void:
	get_node("/root/Scenes").go_to(&"title")
