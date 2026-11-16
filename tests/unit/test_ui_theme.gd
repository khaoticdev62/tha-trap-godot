extends TestCase

## WCAG 2.x thresholds: AA body text 4.5, AAA body text 7.0, non-text UI 3.0.
const AA: float = 4.5
const AAA: float = 7.0
const NON_TEXT: float = 3.0


func test_contrast_ratio_known_values() -> void:
	check(absf(UiTheme.contrast_ratio(Color.BLACK, Color.WHITE) - 21.0) < 0.01, "black on white is 21:1")
	check(absf(UiTheme.contrast_ratio(Color.WHITE, Color.WHITE) - 1.0) < 0.01, "identical colours are 1:1")


func test_standard_palette_text_meets_aaa_where_it_matters() -> void:
	check(UiTheme.contrast_ratio(Palette.WARM_WHITE, Palette.OBSIDIAN) >= AAA, "body text on background")
	check(UiTheme.contrast_ratio(Palette.WARM_WHITE, Palette.DEEP_PANEL) >= AAA, "body text on panel")
	check(UiTheme.contrast_ratio(Palette.WARM_WHITE, Palette.NIGHT_VIOLET) >= AAA, "button text on hover")
	check(UiTheme.contrast_ratio(Palette.STREETLIGHT_GOLD, Palette.OBSIDIAN) >= AAA, "headings on background")
	check(UiTheme.contrast_ratio(Palette.ELECTRIC_LILAC, Palette.OBSIDIAN) >= AAA, "title on background")


func test_secondary_text_and_ui_boundaries_meet_minimums() -> void:
	check(UiTheme.contrast_ratio(Palette.MUTED_SLATE, Palette.OBSIDIAN) >= AA, "muted text on background")
	check(UiTheme.contrast_ratio(Palette.SIGNAL_PURPLE, Palette.OBSIDIAN) >= NON_TEXT, "button border vs background")
	check(UiTheme.contrast_ratio(Palette.STREETLIGHT_GOLD, Palette.DEEP_PANEL) >= NON_TEXT, "focus ring vs panel")


func test_button_text_is_readable_in_every_state_of_the_built_theme() -> void:
	for high_contrast: bool in [false, true]:
		var settings: AccessibilitySettings = AccessibilitySettings.new()
		settings.high_contrast = high_contrast
		var theme: Theme = UiTheme.build(settings)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var box: StyleBoxFlat = theme.get_stylebox(state, "Button")
			var text_color: Color = theme.get_color("font_%s_color" % state if state != "normal" else "font_color", "Button")
			var ratio: float = UiTheme.contrast_ratio(text_color, box.bg_color)
			check(ratio >= AAA, "%s button text is %.2f:1 (hc=%s), needs %.1f" % [state, ratio, high_contrast, AAA])


func test_high_contrast_scheme_is_stronger_than_standard() -> void:
	check(UiTheme.contrast_ratio(UiTheme.HC_TEXT, UiTheme.HC_BACKGROUND) >= 21.0 - 0.01, "text is maximum contrast")
	check(UiTheme.contrast_ratio(UiTheme.HC_ACCENT, UiTheme.HC_BACKGROUND) >= AAA, "accent on background")
	check(UiTheme.contrast_ratio(UiTheme.HC_TEXT, UiTheme.HC_PANEL) >= AAA, "text on panel")


func test_font_sizes_scale_with_text_scale() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	var normal: Theme = UiTheme.build(settings)
	settings.text_scale = 2.0
	var large: Theme = UiTheme.build(settings)
	check_eq(normal.get_font_size("font_size", "Button"), UiTheme.BASE_FONT_SIZE, "base button size")
	check_eq(large.get_font_size("font_size", "Button"), UiTheme.BASE_FONT_SIZE * 2, "doubled button size")
	check_eq(large.get_font_size("font_size", "TitleLabel"), UiTheme.TITLE_FONT_SIZE * 2, "doubled title size")
	check_eq(large.default_font_size, UiTheme.BASE_FONT_SIZE * 2, "default font scales")


func test_smallest_scale_never_makes_text_unreadable() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	settings.text_scale = AppConfig.TEXT_SCALE_MIN
	var small: Theme = UiTheme.build(settings)
	check(small.get_font_size("font_size", "MutedLabel") >= 16, "muted text stays at least 16px at minimum scale")


func test_every_interactive_control_has_a_visible_focus_style() -> void:
	for high_contrast: bool in [false, true]:
		var settings: AccessibilitySettings = AccessibilitySettings.new()
		settings.high_contrast = high_contrast
		var theme: Theme = UiTheme.build(settings)
		for control_type: StringName in [&"Button", &"CheckButton", &"HSlider"]:
			check(theme.has_stylebox("focus", control_type), "%s has focus style (hc=%s)" % [control_type, high_contrast])
			var focus: StyleBoxFlat = theme.get_stylebox("focus", control_type)
			check(focus.border_width_left >= UiTheme.FOCUS_BORDER_WIDTH, "%s focus ring is thick (hc=%s)" % [control_type, high_contrast])
			check(not focus.draw_center, "%s focus ring does not hide content" % control_type)


func test_focus_ring_is_thicker_than_resting_border() -> void:
	var theme: Theme = UiTheme.build(AccessibilitySettings.new())
	var resting: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	var focus: StyleBoxFlat = theme.get_stylebox("focus", "Button")
	check(focus.border_width_left > resting.border_width_left * 2, "focus differs by shape, not colour alone")


func test_type_variations_inherit_from_label() -> void:
	var theme: Theme = UiTheme.build(AccessibilitySettings.new())
	for variation: StringName in [&"TitleLabel", &"HeadingLabel", &"MutedLabel"]:
		check_eq(theme.get_type_variation_base(variation), &"Label", "%s extends Label" % variation)


func test_slider_track_and_fill_are_defined_and_distinct() -> void:
	for high_contrast: bool in [false, true]:
		var settings: AccessibilitySettings = AccessibilitySettings.new()
		settings.high_contrast = high_contrast
		var theme: Theme = UiTheme.build(settings)
		for part: StringName in [&"slider", &"grabber_area"]:
			check(theme.has_stylebox(part, "HSlider"), "%s defined (hc=%s)" % [part, high_contrast])
		var track: StyleBoxFlat = theme.get_stylebox("slider", "HSlider")
		var fill: StyleBoxFlat = theme.get_stylebox("grabber_area", "HSlider")
		check(track.bg_color != fill.bg_color, "filled part differs from the track (hc=%s)" % high_contrast)
		check(UiTheme.contrast_ratio(fill.bg_color, track.bg_color) >= NON_TEXT, "fill vs track contrast >= 3:1 (hc=%s)" % high_contrast)
		check(UiTheme.contrast_ratio(track.border_color, Palette.OBSIDIAN if not high_contrast else UiTheme.HC_BACKGROUND) >= NON_TEXT, "track outline visible against the page (hc=%s)" % high_contrast)


func test_text_field_is_readable_and_shows_focus() -> void:
	for high_contrast: bool in [false, true]:
		var settings: AccessibilitySettings = AccessibilitySettings.new()
		settings.high_contrast = high_contrast
		var theme: Theme = UiTheme.build(settings)
		var box: StyleBoxFlat = theme.get_stylebox("normal", "LineEdit")
		check(UiTheme.contrast_ratio(theme.get_color("font_color", "LineEdit"), box.bg_color) >= AAA, "typed text readable (hc=%s)" % high_contrast)
		check(UiTheme.contrast_ratio(theme.get_color("font_placeholder_color", "LineEdit"), box.bg_color) >= AA, "placeholder readable (hc=%s)" % high_contrast)
		check(theme.get_stylebox("focus", "LineEdit").border_width_left >= UiTheme.FOCUS_BORDER_WIDTH, "focus ring (hc=%s)" % high_contrast)


func test_dropdown_popup_text_is_readable_in_both_states() -> void:
	for high_contrast: bool in [false, true]:
		var settings: AccessibilitySettings = AccessibilitySettings.new()
		settings.high_contrast = high_contrast
		var theme: Theme = UiTheme.build(settings)
		var panel: StyleBoxFlat = theme.get_stylebox("panel", "PopupMenu")
		var hover: StyleBoxFlat = theme.get_stylebox("hover", "PopupMenu")
		check(UiTheme.contrast_ratio(theme.get_color("font_color", "PopupMenu"), panel.bg_color) >= AAA, "item text (hc=%s)" % high_contrast)
		check(UiTheme.contrast_ratio(theme.get_color("font_hover_color", "PopupMenu"), hover.bg_color) >= AAA, "hovered item text (hc=%s)" % high_contrast)


func test_page_background_follows_the_colour_scheme() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	check_eq(UiTheme.background_color(settings), Palette.OBSIDIAN, "standard background is Obsidian")
	settings.high_contrast = true
	check_eq(UiTheme.background_color(settings), UiTheme.HC_BACKGROUND, "high contrast background is black")
