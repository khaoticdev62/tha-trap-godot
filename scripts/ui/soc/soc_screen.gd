class_name SocScreen
extends MarginContainer
## Base for the six SOC screens. A screen is a scene whose root script extends
## this. It reads from a SocModel and calls the model's methods; it never
## changes the simulation itself.
##
## Lifecycle: set `model`, add the screen to the tree (that builds it once),
## then it refreshes whenever the model changes. Refreshes are merged into one
## per frame, and a hidden screen only marks itself stale and refreshes when it
## is next shown, so nothing is rebuilt for a screen the player cannot see.

signal navigate_requested(screen_id: StringName)
signal notify_requested(message: String, level: String)

var model: SocModel = null

var _page: VBoxContainer = null
var _scroll: ScrollContainer = null
var _stale: bool = true
var _refresh_queued: bool = false


## Stable id used by the shell's navigation.
func screen_id() -> StringName:
	return &""


func screen_title() -> String:
	return ""


## One line under the title: what this screen is for.
func screen_context() -> String:
	return ""


## Build the controls once. Called from _ready after the page exists.
func build() -> void:
	pass


## Re-read the model and update the controls in place.
func refresh() -> void:
	pass


## The control that should take focus when the screen opens.
func default_focus() -> Control:
	var controls: Array[Control] = UiKit.focusable(self)
	return controls[0] if not controls.is_empty() else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page = UiKit.vbox(SocTokens.SPACE_M)
	_scroll = UiKit.scroll(_page)
	add_child(_scroll)
	if model == null:
		push_error("%s needs a model before it enters the tree." % name)
		return
	build()
	_fit_tables()
	model.changed.connect(_on_model_changed)
	_refresh_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _page != null:
		_fit_tables()


func _fit_tables() -> void:
	for node: Node in find_children("*", "Tree", true, false):
		UiKit.fit_columns(node as Tree)


## Called by the shell when the screen becomes visible.
func show_screen() -> void:
	visible = true
	if _stale:
		_refresh_now()


func hide_screen() -> void:
	visible = false


## Takes focus on the default control and shows the top of the page. The default
## control is always near the top, so it stays in view.
func focus_default() -> void:
	var target: Control = default_focus()
	if target != null:
		target.grab_focus()
	await get_tree().process_frame
	_scroll.scroll_vertical = 0


func notify(message: String, level: String = "info") -> void:
	notify_requested.emit(message, level)


## The outermost Control above this screen (the shell). Dialogs are added here,
## not inside the screen, so container layout cannot squeeze them.
func overlay_host() -> Node:
	var top: Node = self
	while top.get_parent() is Control:
		top = top.get_parent()
	return top


func go_to(target: StringName) -> void:
	navigate_requested.emit(target)


func _on_model_changed() -> void:
	_stale = true
	if not is_visible_in_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	_refresh_queued = false
	if is_inside_tree() and is_visible_in_tree():
		_refresh_now()


func _refresh_now() -> void:
	_stale = false
	refresh()
