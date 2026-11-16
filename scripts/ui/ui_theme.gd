class_name UiTheme
extends RefCounted
## Builds the global Theme from design tokens (Palette) and the player's
## accessibility settings. One place decides font sizes, colours, focus rings
## and control sizes so every screen stays consistent.
##
## Type variations used by screens: "TitleLabel", "HeadingLabel", "MutedLabel".

const BASE_FONT_SIZE: int = 26
const TITLE_FONT_SIZE: int = 64
const HEADING_FONT_SIZE: int = 34
const MUTED_FONT_SIZE: int = 22

const BORDER_WIDTH: int = 2
const PRESSED_BORDER_WIDTH: int = 4
const SLIDER_TRACK_HALF_HEIGHT: int = 6
## Focus ring is deliberately much thicker than the resting border, so focus is
## readable by shape and not by colour alone.
const FOCUS_BORDER_WIDTH: int = 5
const CORNER_RADIUS: int = 6
const CONTENT_MARGIN_X: int = 20
const CONTENT_MARGIN_Y: int = 12
## Minimum interactive target height on a 1280x800 base. Buttons grow beyond
## this as text scales, so it is a floor, not a fixed size.
const MIN_TARGET_HEIGHT: float = 64.0

## High-contrast palette: pure black and white with a saturated focus colour.
const HC_BACKGROUND: Color = Color(0, 0, 0)
const HC_PANEL: Color = Color(0.06, 0.06, 0.06)
const HC_TEXT: Color = Color(1, 1, 1)
const HC_ACCENT: Color = Color(1.0, 0.9, 0.0)


static func build(settings: AccessibilitySettings) -> Theme:
	var scheme: Dictionary = _scheme(settings.high_contrast)
	var scale: float = settings.text_scale
	var theme: Theme = Theme.new()
	theme.default_font_size = scaled(BASE_FONT_SIZE, scale)

	_style_labels(theme, scheme, scale)
	_style_buttons(theme, scheme, scale, "Button")
	_style_buttons(theme, scheme, scale, "CheckButton")
	_style_slider(theme, scheme)
	_style_line_edit(theme, scheme, scale)
	_style_popup(theme, scheme, scale)
	_style_panel(theme, scheme)
	return theme


## Page background colour for the active scheme.
static func background_color(settings: AccessibilitySettings) -> Color:
	return _scheme(settings.high_contrast)["background"]


static func scaled(base: int, scale: float) -> int:
	return maxi(roundi(base * scale), 1)


## WCAG 2.x contrast ratio between two opaque colours (1.0 to 21.0).
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


static func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


static func _scheme(high_contrast: bool) -> Dictionary:
	if high_contrast:
		return {
			"background": HC_BACKGROUND, "panel": HC_PANEL, "text": HC_TEXT,
			"muted": HC_TEXT, "title": HC_ACCENT, "accent": HC_ACCENT,
			"hover": Color(0.18, 0.18, 0.18), "pressed": Color(0.3, 0.3, 0.3),
			"border": HC_TEXT, "disabled_text": Color(0.7, 0.7, 0.7),
		}
	return {
		"background": Palette.OBSIDIAN, "panel": Palette.DEEP_PANEL, "text": Palette.WARM_WHITE,
		"muted": Palette.MUTED_SLATE, "title": Palette.ELECTRIC_LILAC, "accent": Palette.STREETLIGHT_GOLD,
		# Pressed uses the darkest token: white on Signal Purple is only 4.39:1 (< AA 4.5).
		"hover": Palette.NIGHT_VIOLET, "pressed": Palette.OBSIDIAN,
		"border": Palette.SIGNAL_PURPLE, "disabled_text": Palette.MUTED_SLATE,
	}


static func _style_labels(theme: Theme, scheme: Dictionary, scale: float) -> void:
	theme.set_color("font_color", "Label", scheme["text"])
	_label_variation(theme, "TitleLabel", scaled(TITLE_FONT_SIZE, scale), scheme["title"])
	_label_variation(theme, "HeadingLabel", scaled(HEADING_FONT_SIZE, scale), scheme["accent"])
	_label_variation(theme, "MutedLabel", scaled(MUTED_FONT_SIZE, scale), scheme["muted"])


static func _label_variation(theme: Theme, variation: StringName, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)


static func _style_buttons(theme: Theme, scheme: Dictionary, scale: float, type_name: StringName) -> void:
	theme.set_font_size("font_size", type_name, scaled(BASE_FONT_SIZE, scale))
	theme.set_color("font_color", type_name, scheme["text"])
	theme.set_color("font_hover_color", type_name, scheme["text"])
	theme.set_color("font_pressed_color", type_name, scheme["text"])
	theme.set_color("font_focus_color", type_name, scheme["text"])
	theme.set_color("font_hover_pressed_color", type_name, scheme["text"])
	theme.set_color("font_disabled_color", type_name, scheme["disabled_text"])
	theme.set_stylebox("normal", type_name, _box(scheme["panel"], scheme["border"], BORDER_WIDTH))
	theme.set_stylebox("hover", type_name, _box(scheme["hover"], scheme["border"], BORDER_WIDTH))
	theme.set_stylebox("pressed", type_name, _box(scheme["pressed"], scheme["accent"], PRESSED_BORDER_WIDTH))
	theme.set_stylebox("hover_pressed", type_name, _box(scheme["pressed"], scheme["accent"], PRESSED_BORDER_WIDTH))
	theme.set_stylebox("disabled", type_name, _box(scheme["background"], scheme["muted"], 1))
	theme.set_stylebox("focus", type_name, _focus_box(scheme["accent"]))


static func _style_slider(theme: Theme, scheme: Dictionary) -> void:
	theme.set_stylebox("focus", "HSlider", _focus_box(scheme["accent"]))
	# A visible track (outlined) with an accent-filled portion up to the grabber.
	var track: StyleBoxFlat = _box(scheme["hover"], scheme["border"], 1)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = SLIDER_TRACK_HALF_HEIGHT
	track.content_margin_bottom = SLIDER_TRACK_HALF_HEIGHT
	theme.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = _box(scheme["accent"], scheme["accent"], 1)
	filled.content_margin_left = 0
	filled.content_margin_right = 0
	filled.content_margin_top = SLIDER_TRACK_HALF_HEIGHT
	filled.content_margin_bottom = SLIDER_TRACK_HALF_HEIGHT
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)


static func _style_line_edit(theme: Theme, scheme: Dictionary, scale: float) -> void:
	theme.set_font_size("font_size", "LineEdit", scaled(BASE_FONT_SIZE, scale))
	theme.set_color("font_color", "LineEdit", scheme["text"])
	theme.set_color("font_selected_color", "LineEdit", scheme["text"])
	theme.set_color("font_placeholder_color", "LineEdit", scheme["muted"])
	theme.set_color("caret_color", "LineEdit", scheme["accent"])
	theme.set_color("selection_color", "LineEdit", scheme["pressed"])
	theme.set_stylebox("normal", "LineEdit", _box(scheme["background"], scheme["border"], BORDER_WIDTH))
	theme.set_stylebox("read_only", "LineEdit", _box(scheme["background"], scheme["muted"], 1))
	theme.set_stylebox("focus", "LineEdit", _focus_box(scheme["accent"]))


## Dropdown lists (OptionButton popups).
static func _style_popup(theme: Theme, scheme: Dictionary, scale: float) -> void:
	theme.set_font_size("font_size", "PopupMenu", scaled(BASE_FONT_SIZE, scale))
	theme.set_color("font_color", "PopupMenu", scheme["text"])
	theme.set_color("font_hover_color", "PopupMenu", scheme["text"])
	theme.set_color("font_disabled_color", "PopupMenu", scheme["disabled_text"])
	theme.set_stylebox("panel", "PopupMenu", _box(scheme["panel"], scheme["border"], BORDER_WIDTH))
	theme.set_stylebox("hover", "PopupMenu", _box(scheme["hover"], scheme["accent"], BORDER_WIDTH))


static func _style_panel(theme: Theme, scheme: Dictionary) -> void:
	theme.set_stylebox("panel", "PanelContainer", _box(scheme["panel"], scheme["border"], BORDER_WIDTH))


static func _box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = CONTENT_MARGIN_X
	box.content_margin_right = CONTENT_MARGIN_X
	box.content_margin_top = CONTENT_MARGIN_Y
	box.content_margin_bottom = CONTENT_MARGIN_Y
	return box


## Transparent fill with a thick outline drawn over the control.
static func _focus_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(FOCUS_BORDER_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.expand_margin_left = 3
	box.expand_margin_right = 3
	box.expand_margin_top = 3
	box.expand_margin_bottom = 3
	return box
