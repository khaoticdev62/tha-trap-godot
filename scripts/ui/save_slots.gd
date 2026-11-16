extends Control
## Save slot screen. In "load" mode picking a slot loads it; in "new" mode
## picking a slot starts the character creator for it (asking first if it already
## holds a save). Each slot can be deleted after a confirmation. Everything is
## reachable by keyboard and controller; ui_cancel goes back.

const BUTTON_WIDTH: float = 700.0
const DELETE_WIDTH: float = 180.0
const SCREEN_MARGIN: int = 32

var _game: SaveGame
var _progress: ProgressService
var _mode: String = "load"

var _list: VBoxContainer
var _status: Label
var _back_button: Button
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	_game = SaveGame.from_tree(get_tree())
	_progress = get_node("/root/Progress")
	_mode = _progress.slot_screen_mode if _progress.slot_screen_mode == "new" else "load"
	_build_ui()
	_refresh()
	_focus_first_available()


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

	var center: CenterContainer = CenterContainer.new()
	margin.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var heading: Label = Label.new()
	heading.text = "New Game: choose a save slot" if _mode == "new" else "Load Game: choose a save slot"
	heading.theme_type_variation = &"HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	column.add_child(_list)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(BUTTON_WIDTH, UiTheme.MIN_TARGET_HEIGHT)
	_back_button.pressed.connect(_back)
	column.add_child(_back_button)

	_status = Label.new()
	_status.theme_type_variation = &"MutedLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	column.add_child(_status)


## Rebuilds the slot rows from what is on disk.
func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	for summary: SlotSummary in _game.summaries():
		# A flow row keeps the Delete button beside the slot when there is room and
		# drops it underneath at large text sizes, instead of running off screen.
		var row: HFlowContainer = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		row.add_theme_constant_override("v_separation", 8)
		_list.add_child(row)

		var slot_button: Button = Button.new()
		slot_button.text = summary.describe() + (" (will be replaced)" if _mode == "new" and summary.exists else "")
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.custom_minimum_size = Vector2(BUTTON_WIDTH - DELETE_WIDTH - 12, UiTheme.MIN_TARGET_HEIGHT)
		slot_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_button.disabled = _mode == "load" and not summary.usable
		slot_button.pressed.connect(_on_slot_pressed.bind(summary.slot))
		_describe(slot_button, "Save slot %d" % (summary.slot + 1), summary.describe())
		row.add_child(slot_button)
		_slot_buttons.append(slot_button)

		var delete_button: Button = Button.new()
		delete_button.text = "Delete"
		delete_button.custom_minimum_size = Vector2(DELETE_WIDTH, UiTheme.MIN_TARGET_HEIGHT)
		delete_button.disabled = not summary.exists
		delete_button.pressed.connect(_on_delete_pressed.bind(summary.slot))
		_describe(delete_button, "Delete save slot %d" % (summary.slot + 1), "Permanently deletes this save after you confirm.")
		row.add_child(delete_button)


func _focus_first_available() -> void:
	for button: Button in _slot_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	_back_button.grab_focus()


func _on_slot_pressed(slot: int) -> void:
	if _mode == "new":
		var existing: SlotSummary = _game.summaries()[slot]
		if existing.exists:
			var dialog: ModalDialog = ModalDialog.open(
				self,
				"Replace slot %d?" % (slot + 1),
				"Starting a new game here replaces the save in this slot once your new character is created.",
				"Replace save and start new",
				"Keep my save",
			)
			dialog.confirmed.connect(_start_creator.bind(slot))
		else:
			_start_creator(slot)
		return
	var result: SaveResult = _game.load_slot(slot)
	if not result.ok:
		_status.text = result.message
		_refresh()
		return
	var note: String = " (restored from backup)" if result.recovered_from_backup else ""
	_status.text = "Welcome back, %s%s. The world map is not built yet." % [get_node("/root/Profiles").current.display_name, note]


func _start_creator(slot: int) -> void:
	_progress.active_slot = slot
	get_node("/root/Scenes").go_to(&"creator")


func _on_delete_pressed(slot: int) -> void:
	var dialog: ModalDialog = ModalDialog.open(
		self,
		"Delete slot %d?" % (slot + 1),
		"This permanently deletes the save and its backups. It cannot be undone.",
		"Delete slot %d" % (slot + 1),
		"Keep it",
	)
	dialog.confirmed.connect(_delete_confirmed.bind(slot))


func _delete_confirmed(slot: int) -> void:
	if _game.delete_slot(slot):
		_status.text = "Slot %d deleted." % (slot + 1)
	else:
		_status.text = "Slot %d could not be fully deleted." % (slot + 1)
	_refresh()
	_focus_first_available()


func _back() -> void:
	get_node("/root/Scenes").go_to(&"title")


func _describe(control: Control, accessible_name: String, description: String) -> void:
	if "accessibility_name" in control:
		control.set("accessibility_name", accessible_name)
	if "accessibility_description" in control:
		control.set("accessibility_description", description)
