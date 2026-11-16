class_name SocShell
extends Control
## The SOC application shell: header (title, context, status badges), left
## navigation, the content area that hosts one screen at a time, and a footer with
## the notification area and the controller legend. Screens are created the first
## time they are opened and then kept, so moving around never rebuilds them.
##
## Input: Up/Down/Left/Right and the stick use Godot's focus navigation. `nav_prev`
## and `nav_next` (shoulder buttons, [ and ]) switch screens. `ui_cancel` moves
## focus from a screen to the navigation, and from the navigation back to the title.

signal screen_changed(screen_id: StringName)

const SCREENS: Array[Dictionary] = [
	{"id": &"command_center", "label": "Command Center", "path": "res://scenes/soc/command_center.tscn"},
	{"id": &"investigation", "label": "Investigation", "path": "res://scenes/soc/investigation.tscn"},
	{"id": &"cases", "label": "Case Management", "path": "res://scenes/soc/case_management.tscn"},
	{"id": &"terminal", "label": "Terminal", "path": "res://scenes/soc/terminal.tscn"},
	{"id": &"mission", "label": "Mission & Learning", "path": "res://scenes/soc/mission_learning.tscn"},
	{"id": &"design_system", "label": "Design System", "path": "res://scenes/soc/design_system.tscn"},
]
const START_SCREEN: StringName = &"command_center"
const READY_MESSAGE: String = "Ready."
const LEGEND: String = "Move: D-pad or stick   Select: A / Enter   Back: B / Esc   Switch screen: LB RB / [ ]"
const LEVEL_MARKERS: Dictionary = {"success": "OK", "error": "ERROR", "info": "INFO"}

## Set before adding the shell to the tree to run it over a prepared model (tests).
var model: SocModel = null
var current_id: StringName = &""

var _screens: Dictionary = {}  # id -> SocScreen
var _nav_buttons: Dictionary = {}  # id -> Button
var _nav_group: ButtonGroup = ButtonGroup.new()
var _title_label: Label
var _context_label: Label
var _badge_row: HFlowContainer
var _content_host: Control
var _notice_label: Label
var _notice_timer: Timer
var _back_button: Button
var _background: ColorRect
var _nav: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	_apply_theme(_settings())
	var settings_service: Node = get_node_or_null("/root/Settings")
	if settings_service != null:
		settings_service.changed.connect(_apply_theme)
	if model == null:
		var progress: ProgressService = get_node_or_null("/root/Progress")
		model = SocModel.open(progress if progress != null else ProgressService.new())
	if not model.is_ready():
		_show_failure(model.errors)
		return
	model.changed.connect(_refresh_header)
	model.notified.connect(notify)
	show_screen(START_SCREEN)


func _unhandled_input(event: InputEvent) -> void:
	if model == null or not model.is_ready():
		return
	if event.is_action_pressed(&"nav_next"):
		_step(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"nav_prev"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_handle_cancel()


## Opens a screen by id. Unknown ids are refused so a bad id cannot load anything.
func show_screen(screen_id: StringName) -> bool:
	var entry: Dictionary = _entry(screen_id)
	if entry.is_empty() or model == null or not model.is_ready():
		return false
	var screen: SocScreen = _screens.get(screen_id)
	if screen == null:
		screen = _create_screen(entry)
		if screen == null:
			return false
	for other_id: StringName in _screens:
		if other_id != screen_id:
			(_screens[other_id] as SocScreen).hide_screen()
	current_id = screen_id
	screen.show_screen()
	_title_label.text = screen.screen_title()
	_context_label.text = screen.screen_context()
	_mark_nav(screen_id)
	_refresh_header()
	screen_changed.emit(screen_id)
	screen.focus_default()
	return true


func screen_node(screen_id: StringName) -> SocScreen:
	return _screens.get(screen_id)


## Shows a message in the notification area. It stays until replaced or timed out,
## and carries a text marker so the level is not colour-only.
func notify(message: String, level: String = "info") -> void:
	var marker: String = str(LEVEL_MARKERS.get(level, "INFO"))
	_notice_label.text = "%s  %s" % [marker, message]
	var color: Color = SocTokens.TEXT
	match level:
		"error":
			color = SocTokens.RED
		"success":
			color = SocTokens.GREEN
	_notice_label.add_theme_color_override("font_color", color)
	_notice_timer.start(SocTokens.TOAST_SECONDS)


func notification_text() -> String:
	return _notice_label.text


func nav_button(screen_id: StringName) -> Button:
	return _nav_buttons.get(screen_id)


# --- construction ------------------------------------------------------------------

func _build_frame() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	var frame: VBoxContainer = VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)

	var header: PanelContainer = PanelContainer.new()
	header.theme_type_variation = &"HeaderPanel"
	frame.add_child(header)
	# A flow, so at large text the status badges drop under the title instead of off the screen.
	var header_row: HFlowContainer = UiKit.flow(SocTokens.SPACE_L)
	header.add_child(header_row)
	var titles: VBoxContainer = UiKit.vbox(0)
	titles.custom_minimum_size = Vector2(520, 0)
	header_row.add_child(titles)
	_title_label = UiKit.label("", &"SocTitle", false)
	titles.add_child(_title_label)
	_context_label = UiKit.label("", &"SocCaption")
	titles.add_child(_context_label)
	_badge_row = UiKit.flow(SocTokens.SPACE_S)
	# The badges take whatever width the title leaves, right-aligned, and wrap when it is not enough.
	_badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge_row.alignment = FlowContainer.ALIGNMENT_END
	header_row.add_child(_badge_row)

	var body: MarginContainer = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, SocTokens.SHELL_MARGIN)
	frame.add_child(body)
	var columns: HBoxContainer = UiKit.hbox(SocTokens.SPACE_M)
	body.add_child(columns)

	var nav: VBoxContainer = UiKit.vbox(SocTokens.SPACE_S)
	nav.custom_minimum_size = Vector2(SocTokens.NAV_WIDTH, 0)
	columns.add_child(nav)
	_nav = nav
	for entry: Dictionary in SCREENS:
		var button: Button = UiKit.button(str(entry["label"]), _on_nav_pressed.bind(entry["id"]), &"NavButton")
		button.toggle_mode = true
		button.button_group = _nav_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nav.add_child(button)
		_nav_buttons[entry["id"]] = button
	var filler: Control = Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(filler)
	_back_button = UiKit.button("Back to title", _on_back_pressed)
	nav.add_child(_back_button)

	_content_host = Control.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_host.clip_contents = true
	columns.add_child(_content_host)

	var footer: PanelContainer = PanelContainer.new()
	footer.theme_type_variation = &"InsetPanel"
	frame.add_child(footer)
	var footer_column: VBoxContainer = UiKit.vbox(0)
	footer.add_child(footer_column)
	# Wraps rather than clips: a notification must always be readable in full.
	_notice_label = UiKit.label(READY_MESSAGE, &"SocMono")
	_notice_label.focus_mode = Control.FOCUS_NONE
	footer_column.add_child(_notice_label)
	footer_column.add_child(UiKit.label(LEGEND, &"SocCaption"))

	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(_clear_notice)
	add_child(_notice_timer)


func _create_screen(entry: Dictionary) -> SocScreen:
	var packed: Resource = load(str(entry["path"]))
	if not packed is PackedScene:
		push_error("SocShell: %s is not a scene." % entry["path"])
		return null
	var screen: SocScreen = (packed as PackedScene).instantiate() as SocScreen
	if screen == null:
		push_error("SocShell: %s does not use a SocScreen script." % entry["path"])
		return null
	screen.model = model
	screen.navigate_requested.connect(show_screen)
	screen.notify_requested.connect(notify)
	screen.visible = false
	_content_host.add_child(screen)
	_screens[entry["id"]] = screen
	return screen


func _show_failure(problems: PackedStringArray) -> void:
	_title_label.text = "SOC unavailable"
	_context_label.text = "The training case could not be opened."
	var message: Label = UiKit.label("The SOC could not start: %s" % "; ".join(problems), &"")
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_host.add_child(message)
	notify("The SOC could not start.", "error")
	_back_button.grab_focus()


# --- behaviour ----------------------------------------------------------------------

func _settings() -> AccessibilitySettings:
	var service: Node = get_node_or_null("/root/Settings")
	if service != null and "current" in service:
		return service.current
	return AccessibilitySettings.new()


func _apply_theme(settings: AccessibilitySettings) -> void:
	theme = SocTheme.build(settings)
	# The navigation grows with the text (up to a limit) so words do not break mid-word.
	_nav.custom_minimum_size.x = SocTokens.NAV_WIDTH * clampf(settings.text_scale, 1.0, 1.6)
	_background.color = SocTheme.scheme_for(settings.high_contrast)["background"]


func _entry(screen_id: StringName) -> Dictionary:
	for entry: Dictionary in SCREENS:
		if entry["id"] == screen_id:
			return entry
	return {}


func _mark_nav(screen_id: StringName) -> void:
	for id: StringName in _nav_buttons:
		var button: Button = _nav_buttons[id]
		var active: bool = id == screen_id
		button.set_pressed_no_signal(active)
		button.text = ("> " if active else "") + str(_entry(id)["label"])
		button.tooltip_text = "Open %s." % str(_entry(id)["label"])


func _step(direction: int) -> void:
	var index: int = 0
	for slot: int in SCREENS.size():
		if SCREENS[slot]["id"] == current_id:
			index = slot
	var next_index: int = posmod(index + direction, SCREENS.size())
	show_screen(SCREENS[next_index]["id"])


func _handle_cancel() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var nav_focused: bool = focused != null and (focused == _back_button or _nav_buttons.values().has(focused))
	if nav_focused:
		_on_back_pressed()
	else:
		var button: Button = _nav_buttons.get(current_id)
		if button != null:
			button.grab_focus()


func _on_nav_pressed(screen_id: StringName) -> void:
	show_screen(screen_id)


func _on_back_pressed() -> void:
	var flow: Node = get_node_or_null("/root/Scenes")
	if flow != null:
		flow.go_to(&"title")


func _refresh_header() -> void:
	for child: Node in _badge_row.get_children():
		_badge_row.remove_child(child)
		child.queue_free()
	if model == null or not model.is_ready():
		return
	var counts: Dictionary = model.severity_counts()
	var open_alerts: int = 0
	for severity: String in ["critical", "high", "medium", "low"]:
		open_alerts += int(counts[severity])
	_badge_row.add_child(UiKit.status_badge("Synthetic data", "info"))
	_badge_row.add_child(UiKit.status_badge("%d alerts" % open_alerts, "warn" if open_alerts > 0 else "ok"))
	_badge_row.add_child(UiKit.status_badge(model.status_label(), "ok" if model.case_status == "recovered" else "info"))


func _clear_notice() -> void:
	_notice_label.text = READY_MESSAGE
	_notice_label.remove_theme_color_override("font_color")
