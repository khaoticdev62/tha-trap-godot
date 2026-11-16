extends TestCase
## SOC design tokens and theme: the brief's palette, contrast, type floor,
## scaling, high contrast, and the type variations screens depend on.

const AA: float = 4.5
const AAA: float = 7.0
const NON_TEXT: float = 3.0
const VARIATIONS: Array[String] = ["SocTitle", "SocDisplay", "SocHeading", "SocMuted", "SocCaption", "SocMono"]


func _theme(scale: float = 1.0, high_contrast: bool = false) -> Theme:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	settings.text_scale = scale
	settings.high_contrast = high_contrast
	return SocTheme.build(settings)


func test_palette_matches_the_brief() -> void:
	check_eq(SocTokens.BACKGROUND.to_html(false).to_upper(), "10121B", "background")
	check_eq(SocTokens.SURFACE.to_html(false).to_upper(), "191D2B", "surface")
	check_eq(SocTokens.ELEVATED.to_html(false).to_upper(), "232A3B", "elevated")
	check_eq(SocTokens.CYAN.to_html(false).to_upper(), "42D9F5", "primary cyan")
	check_eq(SocTokens.ULTRAVIOLET.to_html(false).to_upper(), "9275FF", "ultraviolet")
	check_eq(SocTokens.AMBER.to_html(false).to_upper(), "F5B84B", "warning amber")
	check_eq(SocTokens.RED.to_html(false).to_upper(), "F06472", "critical red")
	check_eq(SocTokens.GREEN.to_html(false).to_upper(), "63D69B", "success green")
	check_eq(SocTokens.TEXT.to_html(false).to_upper(), "F2F4FA", "primary text")
	check_eq(SocTokens.TEXT_MUTED.to_html(false).to_upper(), "A4AEC3", "secondary text")


func test_text_contrast_on_every_surface() -> void:
	for surface: Color in [SocTokens.BACKGROUND, SocTokens.SURFACE, SocTokens.ELEVATED]:
		check(UiTheme.contrast_ratio(SocTokens.TEXT, surface) >= AAA, "primary text is AAA on %s" % surface.to_html(false))
		check(UiTheme.contrast_ratio(SocTokens.TEXT_MUTED, surface) >= AA, "secondary text is AA on %s" % surface.to_html(false))
		check(UiTheme.contrast_ratio(SocTokens.CYAN, surface) >= AAA, "cyan accent text is AAA on %s" % surface.to_html(false))


func test_boundaries_and_focus_are_visible() -> void:
	check(UiTheme.contrast_ratio(SocTokens.BORDER, SocTokens.SURFACE) >= NON_TEXT, "component border vs surface")
	check(UiTheme.contrast_ratio(SocTokens.BORDER, SocTokens.BACKGROUND) >= NON_TEXT, "component border vs background")
	check(UiTheme.contrast_ratio(SocTokens.CYAN, SocTokens.SURFACE) >= NON_TEXT, "focus outline vs surface")
	check(SocTokens.FOCUS_WIDTH > SocTokens.BORDER_WIDTH, "focus is thicker than the resting border")


func test_severity_badges_are_readable_and_never_colour_only() -> void:
	for severity: String in SocTokens.SEVERITIES:
		var fill: Color = SocTokens.severity_color(severity)
		check(UiTheme.contrast_ratio(SocTokens.BACKGROUND, fill) >= AA, "badge text on %s fill" % severity)
		var text: String = SocTokens.severity_text(severity)
		check(text.contains(SocTokens.SEVERITY_LABELS[severity]) and text.contains(SocTokens.SEVERITY_MARKERS[severity]), "%s carries a label and a marker" % severity)
	check_eq(SocTokens.severity_text("nonsense"), SocTokens.severity_text("info"), "unknown severities read as info")
	check(SocTokens.severity_rank("critical") < SocTokens.severity_rank("low"), "critical outranks low")
	check_eq(SocTokens.severity_rank("nonsense"), SocTokens.SEVERITIES.size(), "unknown severities sort last")
	var markers: Dictionary = {}
	for severity: String in SocTokens.SEVERITIES:
		markers[SocTokens.SEVERITY_MARKERS[severity]] = true
	check_eq(markers.size(), SocTokens.SEVERITIES.size(), "every severity has its own marker")


func test_every_text_size_meets_the_floor() -> void:
	var theme: Theme = _theme()
	for variation: String in VARIATIONS:
		check(theme.get_font_size("font_size", variation) >= SocTokens.FONT_FLOOR, "%s is at least %dpx" % [variation, SocTokens.FONT_FLOOR])
	for type_name: String in ["Label", "Button", "LineEdit", "Tree", "ItemList", "TabContainer", "ProgressBar"]:
		check(theme.get_font_size("font_size", type_name) >= SocTokens.FONT_FLOOR, "%s text is at least %dpx" % [type_name, SocTokens.FONT_FLOOR])
	check(theme.default_font_size >= SocTokens.FONT_FLOOR, "default font size")


func test_text_scale_applies_to_every_variation() -> void:
	var normal: Theme = _theme(1.0)
	var large: Theme = _theme(2.0)
	for variation: String in VARIATIONS:
		check_eq(large.get_font_size("font_size", variation), normal.get_font_size("font_size", variation) * 2, "%s doubles at 200%%" % variation)
	check_eq(large.get_font_size("font_size", "Button"), normal.get_font_size("font_size", "Button") * 2, "buttons scale too")


func test_type_variations_resolve_to_their_base_types() -> void:
	var theme: Theme = _theme()
	for variation: String in VARIATIONS:
		check_eq(String(theme.get_type_variation_base(variation)), "Label", "%s extends Label" % variation)
	for variation: String in ["PrimaryButton", "DangerButton", "NavButton"]:
		check_eq(String(theme.get_type_variation_base(variation)), "Button", "%s extends Button" % variation)
	for variation: String in ["ElevatedPanel", "InsetPanel", "HeaderPanel"]:
		check_eq(String(theme.get_type_variation_base(variation)), "PanelContainer", "%s extends PanelContainer" % variation)


func test_button_text_is_readable_in_every_state() -> void:
	for high_contrast: bool in [false, true]:
		var theme: Theme = _theme(1.0, high_contrast)
		for type_name: String in ["Button", "PrimaryButton", "DangerButton", "NavButton"]:
			for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
				var box: StyleBoxFlat = theme.get_stylebox(state, type_name)
				var key: String = "font_color" if state == "normal" else "font_%s_color" % state
				var ratio: float = UiTheme.contrast_ratio(theme.get_color(key, type_name), box.bg_color)
				check(ratio >= AA, "%s %s text is %.2f:1 (hc=%s)" % [type_name, state, ratio, high_contrast])


func test_focus_outline_is_a_shape_on_every_interactive_type() -> void:
	var theme: Theme = _theme()
	for type_name: String in ["Button", "CheckButton", "LineEdit", "TextEdit", "Tree", "ItemList", "TabContainer", "RichTextLabel"]:
		var box: StyleBox = theme.get_stylebox("focus" if type_name != "TabContainer" else "tab_focus", type_name)
		check(box is StyleBoxFlat and (box as StyleBoxFlat).border_width_left >= SocTokens.FOCUS_WIDTH, "%s has a thick focus outline" % type_name)


func test_high_contrast_is_stronger_than_standard() -> void:
	var standard: Dictionary = SocTheme.scheme_for(false)
	var strong: Dictionary = SocTheme.scheme_for(true)
	check(UiTheme.contrast_ratio(strong["text"], strong["background"]) > UiTheme.contrast_ratio(standard["text"], standard["background"]), "text contrast rises")
	check(UiTheme.contrast_ratio(strong["muted"], strong["surface"]) >= AAA, "secondary text is AAA in high contrast")
	check(UiTheme.contrast_ratio(strong["focus"], strong["background"]) >= AAA, "focus colour is strong in high contrast")


func test_scheme_has_every_role_screens_use() -> void:
	for high_contrast: bool in [false, true]:
		var scheme: Dictionary = SocTheme.scheme_for(high_contrast)
		for role: String in ["background", "surface", "elevated", "text", "muted", "accent", "focus", "border", "divider", "primary", "danger", "success", "on_accent"]:
			check(scheme.has(role) and scheme[role] is Color, "role %s exists (hc=%s)" % [role, high_contrast])


func test_spacing_and_target_tokens_are_consistent() -> void:
	check(SocTokens.SPACE_XS < SocTokens.SPACE_S and SocTokens.SPACE_S < SocTokens.SPACE_M and SocTokens.SPACE_M < SocTokens.SPACE_L and SocTokens.SPACE_L < SocTokens.SPACE_XL, "spacing steps rise")
	check(SocTokens.MIN_TARGET >= 40.0, "targets are comfortable for touch and gamepad")
	check_eq(SocTokens.REFERENCE_SIZE, Vector2i(1280, 800), "reference resolution is 1280x800")
	check(SocTokens.MOTION_FAST < SocTokens.MOTION_BASE, "motion timings are ordered")


func test_mono_font_prefers_monospace_faces() -> void:
	var font: Font = SocTheme.mono_font()
	check(font is SystemFont and (font as SystemFont).font_names.size() > 1, "monospace font lists fallbacks")
	check(SocTheme.mono_font() != SocTheme.display_font(), "mono and display fonts differ")
