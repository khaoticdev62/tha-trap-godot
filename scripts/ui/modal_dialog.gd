class_name ModalDialog
extends Control
## Reusable confirmation dialog.
##   var dialog := ModalDialog.open(self, "Title", "Body", "Confirm", "Cancel")
##   dialog.confirmed.connect(...)
##
## Behaviour: blocks the mouse behind it, traps keyboard/controller focus
## between its two buttons, starts focused on the SAFE choice (cancel), maps
## ui_cancel to cancel, and returns focus to whatever had it before opening.

signal confirmed
signal cancelled

const PANEL_WIDTH: float = 720.0
const DIM_COLOR: Color = Color(0, 0, 0, 0.72)

var cancel_button: Button
var confirm_button: Button

var _title: String
var _body: String
var _confirm_text: String
var _cancel_text: String
var _previous_focus: Control
var _finished: bool = false


static func open(host: Node, title: String, body: String, confirm_text: String, cancel_text: String) -> ModalDialog:
	var dialog: ModalDialog = ModalDialog.new()
	dialog._title = title
	dialog._body = body
	dialog._confirm_text = confirm_text
	dialog._cancel_text = cancel_text
	host.add_child(dialog)
	return dialog


func _ready() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_describe(panel, _title, _body)
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var heading: Label = Label.new()
	heading.text = _title
	heading.theme_type_variation = &"HeadingLabel"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)

	var body: Label = Label.new()
	body.text = _body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)

	cancel_button = _button(_cancel_text, func() -> void: _finish(false))
	confirm_button = _button(_confirm_text, func() -> void: _finish(true))
	column.add_child(cancel_button)
	column.add_child(confirm_button)
	_trap_focus()


func _button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, UiTheme.MIN_TARGET_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(handler)
	return button


## Focus can only move between the two buttons, so keyboard and controller
## navigation cannot reach controls hidden behind the dimmed overlay.
func _trap_focus() -> void:
	var pair: Array[Button] = [cancel_button, confirm_button]
	for index: int in 2:
		var self_button: Button = pair[index]
		var other: Button = pair[1 - index]
		for side: Side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
			self_button.set_focus_neighbor(side, self_button.get_path_to(other))
		self_button.focus_next = self_button.get_path_to(other)
		self_button.focus_previous = self_button.get_path_to(other)


func _describe(control: Control, accessible_name: String, description: String) -> void:
	if "accessibility_name" in control:
		control.set("accessibility_name", accessible_name)
	if "accessibility_description" in control:
		control.set("accessibility_description", description)


func _finish(accepted: bool) -> void:
	if _finished:
		return
	_finished = true
	var restore: Control = _previous_focus
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	if is_instance_valid(restore) and restore.is_inside_tree() and restore.is_visible_in_tree():
		restore.grab_focus()
	queue_free()
