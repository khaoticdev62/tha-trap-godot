class_name SocTheme
extends RefCounted
## Builds the Theme used by every SOC screen from SocTokens and the player's
## accessibility settings (text scale, high contrast). The shell assigns it to
## its root control, so it overrides the menu theme only inside the SOC.
##
## Type variations: SocTitle, SocHeading, SocMuted, SocCaption, SocMono,
## SocDisplay (labels); PrimaryButton, DangerButton, NavButton (buttons);
## ElevatedPanel, InsetPanel, HeaderPanel (panels).

const MONO_FONT_NAMES: PackedStringArray = ["Cascadia Mono", "Consolas", "DejaVu Sans Mono", "Menlo", "Liberation Mono", "monospace"]
const DISPLAY_FONT_NAMES: PackedStringArray = ["Bahnschrift", "Segoe UI Semibold", "DejaVu Sans", "sans-serif"]


static func build(settings: AccessibilitySettings) -> Theme:
	var scheme: Dictionary = scheme_for(settings.high_contrast)
	var scale: float = settings.text_scale
	var theme: Theme = Theme.new()
	theme.default_font_size = _px(SocTokens.FONT_BODY, scale)
	_style_labels(theme, scheme, scale)
	_style_buttons(theme, scheme, scale)
	_style_panels(theme, scheme)
	_style_inputs(theme, scheme, scale)
	_style_collections(theme, scheme, scale)
	_style_tabs(theme, scheme, scale)
	_style_progress(theme, scheme, scale)
	_style_scrollbars(theme, scheme)
	return theme


## Colour roles for a scheme. Screens ask for a role, never a raw colour, so
## high contrast works everywhere without extra code.
static func scheme_for(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return {
			"background": SocTokens.HC_BACKGROUND, "surface": SocTokens.HC_SURFACE, "elevated": SocTokens.HC_ELEVATED,
			"text": SocTokens.HC_TEXT, "muted": SocTokens.HC_TEXT, "accent": SocTokens.HC_ACCENT,
			"focus": SocTokens.HC_ACCENT, "border": SocTokens.HC_BORDER, "divider": SocTokens.HC_BORDER,
			"primary": SocTokens.HC_ACCENT, "danger": Color(1.0, 0.45, 0.45), "success": Color(0.4, 1.0, 0.6),
			"on_accent": Color(0, 0, 0),
		}
	return {
		"background": SocTokens.BACKGROUND, "surface": SocTokens.SURFACE, "elevated": SocTokens.ELEVATED,
		"text": SocTokens.TEXT, "muted": SocTokens.TEXT_MUTED, "accent": SocTokens.CYAN,
		"focus": SocTokens.CYAN, "border": SocTokens.BORDER, "divider": SocTokens.DIVIDER,
		"primary": SocTokens.CYAN, "danger": SocTokens.RED, "success": SocTokens.GREEN,
		"on_accent": SocTokens.BACKGROUND,
	}


static func mono_font() -> Font:
	var font: SystemFont = SystemFont.new()
	font.font_names = MONO_FONT_NAMES
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font


static func display_font() -> Font:
	var font: SystemFont = SystemFont.new()
	font.font_names = DISPLAY_FONT_NAMES
	font.font_weight = 700
	return font


static func _px(base: int, scale: float) -> int:
	return UiTheme.scaled(base, scale)


# --- labels -----------------------------------------------------------------

static func _style_labels(theme: Theme, scheme: Dictionary, scale: float) -> void:
	theme.set_color("font_color", "Label", scheme["text"])
	theme.set_font_size("font_size", "Label", _px(SocTokens.FONT_BODY, scale))
	_label_variation(theme, "SocTitle", _px(SocTokens.FONT_TITLE, scale), scheme["text"], display_font())
	_label_variation(theme, "SocDisplay", _px(SocTokens.FONT_DISPLAY, scale), scheme["accent"], display_font())
	_label_variation(theme, "SocHeading", _px(SocTokens.FONT_HEADING, scale), scheme["accent"], display_font())
	_label_variation(theme, "SocMuted", _px(SocTokens.FONT_SMALL, scale), scheme["muted"], null)
	_label_variation(theme, "SocCaption", _px(SocTokens.FONT_SMALL, scale), scheme["muted"], null)
	_label_variation(theme, "SocMono", _px(SocTokens.FONT_MONO, scale), scheme["text"], mono_font())
	theme.set_font_size("normal_font_size", "RichTextLabel", _px(SocTokens.FONT_MONO, scale))
	theme.set_font_size("mono_font_size", "RichTextLabel", _px(SocTokens.FONT_MONO, scale))
	theme.set_font("normal_font", "RichTextLabel", mono_font())
	theme.set_color("default_color", "RichTextLabel", scheme["text"])
	theme.set_stylebox("focus", "RichTextLabel", _focus_box(scheme["focus"]))


static func _label_variation(theme: Theme, variation: StringName, size: int, color: Color, font: Font) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)
	if font != null:
		theme.set_font("font", variation, font)


# --- buttons ----------------------------------------------------------------

static func _style_buttons(theme: Theme, scheme: Dictionary, scale: float) -> void:
	for type_name: StringName in [&"Button", &"CheckButton", &"OptionButton"]:
		_button_states(theme, type_name, scheme, scale, scheme["elevated"], scheme["border"], scheme["text"])
	theme.set_type_variation("PrimaryButton", "Button")
	_button_states(theme, &"PrimaryButton", scheme, scale, scheme["primary"], scheme["primary"], scheme["on_accent"])
	theme.set_type_variation("DangerButton", "Button")
	_button_states(theme, &"DangerButton", scheme, scale, scheme["elevated"], scheme["danger"], scheme["text"])
	theme.set_type_variation("NavButton", "Button")
	_button_states(theme, &"NavButton", scheme, scale, scheme["surface"], scheme["divider"], scheme["text"])
	theme.set_constant("h_separation", "NavButton", SocTokens.SPACE_S)
	theme.set_stylebox("pressed", "NavButton", _box(scheme["elevated"], scheme["accent"], 2, 2))


static func _button_states(theme: Theme, type_name: StringName, scheme: Dictionary, scale: float, fill: Color, border: Color, text: Color) -> void:
	var hover_fill: Color = fill.lightened(0.12) if fill.get_luminance() < 0.5 else fill.darkened(0.12)
	var pressed_fill: Color = fill.darkened(0.2) if fill.get_luminance() < 0.5 else fill.darkened(0.25)
	theme.set_font_size("font_size", type_name, _px(SocTokens.FONT_BODY, scale))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, type_name, text)
	theme.set_color("font_disabled_color", type_name, scheme["muted"])
	theme.set_stylebox("normal", type_name, _box(fill, border, SocTokens.BORDER_WIDTH))
	theme.set_stylebox("hover", type_name, _box(hover_fill, border, SocTokens.BORDER_WIDTH))
	theme.set_stylebox("pressed", type_name, _box(pressed_fill, border, 2))
	theme.set_stylebox("hover_pressed", type_name, _box(pressed_fill, border, 2))
	theme.set_stylebox("disabled", type_name, _box(scheme["background"], scheme["divider"], SocTokens.BORDER_WIDTH))
	theme.set_stylebox("focus", type_name, _focus_box(scheme["focus"]))


# --- panels -----------------------------------------------------------------

static func _style_panels(theme: Theme, scheme: Dictionary) -> void:
	theme.set_stylebox("panel", "PanelContainer", _box(scheme["surface"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.PANEL_PADDING))
	theme.set_type_variation("ElevatedPanel", "PanelContainer")
	theme.set_stylebox("panel", "ElevatedPanel", _box(scheme["elevated"], scheme["border"], SocTokens.BORDER_WIDTH, SocTokens.PANEL_PADDING))
	theme.set_type_variation("InsetPanel", "PanelContainer")
	theme.set_stylebox("panel", "InsetPanel", _box(scheme["background"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
	theme.set_type_variation("HeaderPanel", "PanelContainer")
	var header: StyleBoxFlat = _box(scheme["surface"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S)
	header.border_width_top = 0
	header.border_width_left = 0
	header.border_width_right = 0
	header.set_corner_radius_all(0)
	theme.set_stylebox("panel", "HeaderPanel", header)


# --- inputs -----------------------------------------------------------------

static func _style_inputs(theme: Theme, scheme: Dictionary, scale: float) -> void:
	for type_name: StringName in [&"LineEdit", &"TextEdit"]:
		theme.set_font_size("font_size", type_name, _px(SocTokens.FONT_BODY, scale))
		theme.set_color("font_color", type_name, scheme["text"])
		theme.set_color("font_placeholder_color", type_name, scheme["muted"])
		theme.set_color("caret_color", type_name, scheme["accent"])
		theme.set_color("selection_color", type_name, scheme["elevated"])
		theme.set_stylebox("normal", type_name, _box(scheme["background"], scheme["border"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
		theme.set_stylebox("focus", type_name, _focus_box(scheme["focus"]))
	theme.set_stylebox("read_only", "LineEdit", _box(scheme["surface"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
	theme.set_font("font", "LineEdit", mono_font())
	theme.set_font("font", "TextEdit", mono_font())
	theme.set_stylebox("panel", "PopupMenu", _box(scheme["surface"], scheme["border"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
	theme.set_stylebox("hover", "PopupMenu", _box(scheme["elevated"], scheme["accent"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
	theme.set_font_size("font_size", "PopupMenu", _px(SocTokens.FONT_BODY, scale))
	theme.set_color("font_color", "PopupMenu", scheme["text"])
	theme.set_color("font_hover_color", "PopupMenu", scheme["text"])


# --- lists and tables ---------------------------------------------------------

static func _style_collections(theme: Theme, scheme: Dictionary, scale: float) -> void:
	var selected: StyleBoxFlat = _box(scheme["elevated"], scheme["accent"], 2, SocTokens.SPACE_XS)
	var cursor: StyleBoxFlat = _focus_box(scheme["focus"])
	var panel: StyleBoxFlat = _box(scheme["background"], scheme["border"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_XS)
	theme.set_font_size("font_size", "Tree", _px(SocTokens.FONT_SMALL, scale))
	theme.set_font_size("title_button_font_size", "Tree", _px(SocTokens.FONT_SMALL, scale))
	theme.set_font("font", "Tree", mono_font())
	theme.set_color("font_color", "Tree", scheme["text"])
	theme.set_color("font_selected_color", "Tree", scheme["text"])
	theme.set_color("title_button_color", "Tree", scheme["accent"])
	theme.set_stylebox("panel", "Tree", panel)
	theme.set_stylebox("focus", "Tree", cursor)
	theme.set_stylebox("selected", "Tree", selected)
	theme.set_stylebox("selected_focus", "Tree", selected)
	theme.set_stylebox("cursor", "Tree", cursor)
	theme.set_stylebox("cursor_unfocused", "Tree", selected)
	theme.set_stylebox("title_button_normal", "Tree", _box(scheme["elevated"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_XS))
	theme.set_stylebox("title_button_hover", "Tree", _box(scheme["elevated"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_XS))
	theme.set_stylebox("title_button_pressed", "Tree", _box(scheme["elevated"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_XS))
	theme.set_constant("v_separation", "Tree", SocTokens.SPACE_S)
	theme.set_color("guide_color", "Tree", scheme["divider"])

	theme.set_font_size("font_size", "ItemList", _px(SocTokens.FONT_SMALL, scale))
	theme.set_font("font", "ItemList", mono_font())
	theme.set_color("font_color", "ItemList", scheme["text"])
	theme.set_color("font_selected_color", "ItemList", scheme["text"])
	theme.set_stylebox("panel", "ItemList", panel)
	theme.set_stylebox("focus", "ItemList", cursor)
	theme.set_stylebox("selected", "ItemList", selected)
	theme.set_stylebox("selected_focus", "ItemList", selected)
	theme.set_stylebox("cursor", "ItemList", cursor)
	theme.set_stylebox("cursor_unfocused", "ItemList", selected)
	theme.set_constant("v_separation", "ItemList", SocTokens.SPACE_S)


static func _style_tabs(theme: Theme, scheme: Dictionary, scale: float) -> void:
	for type_name: StringName in [&"TabContainer", &"TabBar"]:
		theme.set_font_size("font_size", type_name, _px(SocTokens.FONT_BODY, scale))
		theme.set_color("font_selected_color", type_name, scheme["text"])
		theme.set_color("font_hovered_color", type_name, scheme["text"])
		theme.set_color("font_unselected_color", type_name, scheme["muted"])
		theme.set_stylebox("tab_selected", type_name, _box(scheme["elevated"], scheme["accent"], 2, SocTokens.SPACE_S))
		theme.set_stylebox("tab_unselected", type_name, _box(scheme["surface"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
		theme.set_stylebox("tab_hovered", type_name, _box(scheme["elevated"], scheme["border"], SocTokens.BORDER_WIDTH, SocTokens.SPACE_S))
		theme.set_stylebox("tab_focus", type_name, _focus_box(scheme["focus"]))
	theme.set_stylebox("panel", "TabContainer", _box(scheme["surface"], scheme["divider"], SocTokens.BORDER_WIDTH, SocTokens.PANEL_PADDING))


static func _style_progress(theme: Theme, scheme: Dictionary, scale: float) -> void:
	theme.set_font_size("font_size", "ProgressBar", _px(SocTokens.FONT_SMALL, scale))
	theme.set_color("font_color", "ProgressBar", scheme["text"])
	theme.set_stylebox("background", "ProgressBar", _box(scheme["background"], scheme["border"], SocTokens.BORDER_WIDTH, 2))
	theme.set_stylebox("fill", "ProgressBar", _box(scheme["primary"], scheme["primary"], 0, 2))


static func _style_scrollbars(theme: Theme, scheme: Dictionary) -> void:
	for type_name: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox("scroll", type_name, _box(scheme["background"], scheme["divider"], SocTokens.BORDER_WIDTH, 2))
		theme.set_stylebox("grabber", type_name, _box(scheme["border"], scheme["border"], 0, 6))
		theme.set_stylebox("grabber_highlight", type_name, _box(scheme["accent"], scheme["accent"], 0, 6))
		theme.set_stylebox("grabber_pressed", type_name, _box(scheme["accent"], scheme["accent"], 0, 6))


# --- style box helpers ------------------------------------------------------------

static func _box(fill: Color, border: Color, border_width: int, padding: int = SocTokens.SPACE_S) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(SocTokens.RADIUS)
	box.content_margin_left = padding + SocTokens.SPACE_XS
	box.content_margin_right = padding + SocTokens.SPACE_XS
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


## Outline drawn over the control. Thicker than the resting border so focus is
## a shape, not just a colour.
static func _focus_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(SocTokens.FOCUS_WIDTH)
	box.set_corner_radius_all(SocTokens.RADIUS)
	box.expand_margin_left = 2
	box.expand_margin_right = 2
	box.expand_margin_top = 2
	box.expand_margin_bottom = 2
	return box
