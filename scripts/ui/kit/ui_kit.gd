class_name UiKit
extends RefCounted
## Small factory functions for the SOC screens, so every label, button, table
## and badge is built one way. Replaces the per-screen `_label`, `_button` and
## `_describe` helpers duplicated in the menu scripts (gap G-13) for new screens.

const STATUS_LEVELS: Dictionary = {
	"ok": {"marker": "OK", "role": "success"},
	"warn": {"marker": "WARN", "role": "accent"},
	"error": {"marker": "ERROR", "role": "danger"},
	"info": {"marker": "INFO", "role": "accent"},
}


static func label(text: String, variation: StringName = &"", autowrap: bool = true) -> Label:
	var node: Label = Label.new()
	node.text = text
	if variation != &"":
		node.theme_type_variation = variation
	if autowrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, handler: Callable, variation: StringName = &"") -> Button:
	var node: Button = Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.custom_minimum_size = Vector2(0, SocTokens.MIN_TARGET)
	if variation != &"":
		node.theme_type_variation = variation
	if handler.is_valid():
		node.pressed.connect(handler)
	return node


static func vbox(separation: int = SocTokens.SPACE_S) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = SocTokens.SPACE_S) -> HBoxContainer:
	var node: HBoxContainer = HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


## Columns that sit side by side when there is room and stack when there is not
## (large text, small windows). Give each child a custom_minimum_size.x.
static func flow(separation: int = SocTokens.SPACE_M) -> HFlowContainer:
	var node: HFlowContainer = HFlowContainer.new()
	node.add_theme_constant_override("h_separation", separation)
	node.add_theme_constant_override("v_separation", separation)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func scroll(child: Control) -> ScrollContainer:
	var node: ScrollContainer = ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.follow_focus = true
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(child)
	return node


## Colour plus a text marker and label, so severity never depends on colour alone.
static func severity_badge(severity: String) -> PanelContainer:
	var known: String = severity if SocTokens.SEVERITY_LABELS.has(severity) else "info"
	return _badge(SocTokens.severity_text(known), SocTokens.severity_color(known), "Severity: %s" % SocTokens.SEVERITY_LABELS[known])


## level is "ok", "warn", "error" or "info"; the marker word carries the meaning.
static func status_badge(text: String, level: String) -> PanelContainer:
	var spec: Dictionary = STATUS_LEVELS.get(level, STATUS_LEVELS["info"])
	var color: Color = SocTokens.TEXT_MUTED
	match str(spec["role"]):
		"success":
			color = SocTokens.GREEN
		"danger":
			color = SocTokens.RED
		"accent":
			color = SocTokens.AMBER if level == "warn" else SocTokens.CYAN
	return _badge("%s  %s" % [spec["marker"], text], color, "Status: %s" % text)


static func _badge(text: String, fill: Color, tooltip: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(SocTokens.RADIUS)
	box.content_margin_left = SocTokens.SPACE_S
	box.content_margin_right = SocTokens.SPACE_S
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	panel.tooltip_text = tooltip
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var caption: Label = Label.new()
	caption.text = text
	caption.theme_type_variation = &"SocMono"
	caption.add_theme_color_override("font_color", SocTokens.BACKGROUND)
	panel.add_child(caption)
	return panel


## A row table. `columns` is a list of [title, minimum_width] pairs at 100% text;
## a width of 0 means "take the remaining space" and wraps long text. Widths grow
## with the text scale (see fit_columns). Rows are added with add_row; each can
## carry one metadata value to read back on select.
static func table(columns: Array, height: float = 160.0) -> Tree:
	var tree: Tree = Tree.new()
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.focus_mode = Control.FOCUS_ALL
	tree.allow_reselect = true
	# Columns keep their readable widths; if the window is too narrow (large text) the
	# table scrolls sideways instead of pushing the whole screen past the window edge.
	tree.scroll_horizontal_enabled = true
	tree.custom_minimum_size = Vector2(0, height)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var base_widths: PackedInt32Array = PackedInt32Array()
	var wrapped: PackedInt32Array = PackedInt32Array()
	for index: int in columns.size():
		var spec: Array = columns[index]
		base_widths.append(int(spec[1]))
		if int(spec[1]) == 0:
			wrapped.append(index)
		tree.set_column_title(index, str(spec[0]))
		tree.set_column_expand(index, int(spec[1]) == 0)
		tree.set_column_clip_content(index, true)
	tree.set_meta("base_widths", base_widths)
	tree.set_meta("wrapped_columns", wrapped)
	fit_columns(tree)
	tree.create_item()
	return tree


## Re-applies column widths for the current text scale. Called when a screen is
## built and whenever the theme changes, so tables stay readable at 200% text.
static func fit_columns(tree: Tree) -> void:
	if not tree.has_meta("base_widths"):
		return
	var scale: float = float(tree.get_theme_font_size("font_size", "Tree")) / float(SocTokens.FONT_SMALL)
	var widths: PackedInt32Array = tree.get_meta("base_widths")
	for index: int in widths.size():
		tree.set_column_custom_minimum_width(index, roundi(widths[index] * scale))


static func add_row(tree: Tree, cells: PackedStringArray, metadata: Variant = null) -> TreeItem:
	var item: TreeItem = tree.create_item(tree.get_root())
	var wrapped: PackedInt32Array = tree.get_meta("wrapped_columns", PackedInt32Array())
	for index: int in mini(cells.size(), tree.columns):
		item.set_text(index, cells[index])
		if wrapped.has(index):
			item.set_autowrap_mode(index, TextServer.AUTOWRAP_WORD_SMART)
	if metadata != null:
		item.set_metadata(0, metadata)
	return item


static func clear_table(tree: Tree) -> void:
	tree.clear()
	tree.create_item()


static func selected_metadata(tree: Tree) -> Variant:
	var item: TreeItem = tree.get_selected()
	return item.get_metadata(0) if item != null else null


## A progress bar with its readout above it ("Caption  60%"), so the value is
## text and the readout never sits on top of the fill colour.
static func progress(fraction: float, caption: String) -> VBoxContainer:
	var column: VBoxContainer = vbox(2)
	var percent: int = int(roundf(clampf(fraction, 0.0, 1.0) * 100.0))
	var text: Label = label("%s  %d%%" % [caption, percent], &"SocMono")
	column.add_child(text)
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = percent
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.tooltip_text = "%s: %d%%" % [caption, percent]
	column.add_child(bar)
	return column


static func spacer(height: float) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Every Control under `node` that can take focus, in tree order.
static func focusable(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	_collect_focusable(node, found)
	return found


static func _collect_focusable(node: Node, found: Array[Control]) -> void:
	if node is Control:
		var control: Control = node
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			found.append(control)
	for child: Node in node.get_children():
		_collect_focusable(child, found)
