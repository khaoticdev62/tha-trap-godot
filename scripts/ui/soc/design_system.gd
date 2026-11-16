extends SocScreen
## SCREEN 01: Design system. A live style guide built from the same tokens, theme
## and kit the other screens use, so it doubles as the visual QA reference:
## palette, type, buttons and states, cards, badges, navigation, tables, dialogs,
## tabs, progress, focus and spacing.

const SWATCHES: Array[Dictionary] = [
	{"name": "Background", "color": SocTokens.BACKGROUND},
	{"name": "Surface", "color": SocTokens.SURFACE},
	{"name": "Elevated", "color": SocTokens.ELEVATED},
	{"name": "Primary cyan", "color": SocTokens.CYAN},
	{"name": "Ultraviolet", "color": SocTokens.ULTRAVIOLET},
	{"name": "Warning amber", "color": SocTokens.AMBER},
	{"name": "Critical red", "color": SocTokens.RED},
	{"name": "Success green", "color": SocTokens.GREEN},
	{"name": "Primary text", "color": SocTokens.TEXT},
	{"name": "Secondary text", "color": SocTokens.TEXT_MUTED},
]
const TYPE_SAMPLES: Array[Dictionary] = [
	{"variation": &"SocDisplay", "name": "Display", "sample": "THA T.R.A.P."},
	{"variation": &"SocTitle", "name": "Title", "sample": "Incident Investigation"},
	{"variation": &"SocHeading", "name": "Heading", "sample": "Evidence locker"},
	{"variation": &"", "name": "Body", "sample": "Readable sans-serif for standard interface text."},
	{"variation": &"SocMuted", "name": "Secondary", "sample": "Supporting detail and captions."},
	{"variation": &"SocMono", "name": "Monospace", "sample": "logs search source=auth user=j.smith"},
]
const SPACING_TOKENS: Array[Dictionary] = [
	{"name": "SPACE_XS", "value": SocTokens.SPACE_XS}, {"name": "SPACE_S", "value": SocTokens.SPACE_S},
	{"name": "SPACE_M", "value": SocTokens.SPACE_M}, {"name": "SPACE_L", "value": SocTokens.SPACE_L},
	{"name": "SPACE_XL", "value": SocTokens.SPACE_XL},
]
const BUTTON_STATES: PackedStringArray = ["normal", "hover", "pressed", "disabled", "focus"]

var _first_button: Button
var _dialog_result: Label


func screen_id() -> StringName:
	return &"design_system"


func screen_title() -> String:
	return "Design System"


func screen_context() -> String:
	return "Tokens and components shared by every SOC screen."


func build() -> void:
	_page.add_child(_palette_card())
	_page.add_child(_type_card())
	_page.add_child(_buttons_card())
	var row: HFlowContainer = UiKit.flow()
	_page.add_child(row)
	row.add_child(_sized(_cards_card(), 440))
	row.add_child(_sized(_badges_card(), 300))
	var row_two: HFlowContainer = UiKit.flow()
	_page.add_child(row_two)
	row_two.add_child(_sized(_navigation_card(), 320))
	row_two.add_child(_sized(_table_card(), 520))
	_page.add_child(_tabs_card())
	var row_three: HFlowContainer = UiKit.flow()
	_page.add_child(row_three)
	row_three.add_child(_sized(_progress_card(), 420))
	row_three.add_child(_sized(_dialog_card(), 320))
	_page.add_child(_spacing_card())


func refresh() -> void:
	# The style guide is static; it follows the theme automatically.
	pass


func default_focus() -> Control:
	return _first_button


func _palette_card() -> SocCard:
	var card: SocCard = SocCard.create("Colour palette")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", SocTokens.SPACE_S)
	grid.add_theme_constant_override("v_separation", SocTokens.SPACE_S)
	card.body.add_child(grid)
	for swatch: Dictionary in SWATCHES:
		var color: Color = swatch["color"]
		var tile: VBoxContainer = UiKit.vbox(SocTokens.SPACE_XS)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Outlined, so Background and Surface stay visible against the card behind them.
		var chip: Panel = Panel.new()
		var chip_style: StyleBoxFlat = StyleBoxFlat.new()
		chip_style.bg_color = color
		chip_style.border_color = SocTokens.BORDER
		chip_style.set_border_width_all(SocTokens.BORDER_WIDTH)
		chip_style.set_corner_radius_all(SocTokens.RADIUS)
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.custom_minimum_size = Vector2(0, 36)
		chip.tooltip_text = "%s %s" % [swatch["name"], color.to_html(false).to_upper()]
		tile.add_child(chip)
		tile.add_child(UiKit.label("%s\n#%s" % [swatch["name"], color.to_html(false).to_upper()], &"SocCaption"))
		grid.add_child(tile)
	card.body.add_child(UiKit.label("Text on Surface: primary %.1f:1, secondary %.1f:1 (WCAG)." % [UiTheme.contrast_ratio(SocTokens.TEXT, SocTokens.SURFACE), UiTheme.contrast_ratio(SocTokens.TEXT_MUTED, SocTokens.SURFACE)], &"SocCaption"))
	return card


func _type_card() -> SocCard:
	var card: SocCard = SocCard.create("Typography hierarchy")
	for sample: Dictionary in TYPE_SAMPLES:
		var row: HBoxContainer = UiKit.hbox(SocTokens.SPACE_M)
		var name_label: Label = UiKit.label(str(sample["name"]), &"SocCaption", false)
		name_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_label)
		row.add_child(UiKit.label(str(sample["sample"]), sample["variation"]))
		card.body.add_child(row)
	return card


func _buttons_card() -> SocCard:
	var card: SocCard = SocCard.create("Buttons and states")
	var live: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	card.body.add_child(live)
	_first_button = UiKit.button("Default", func() -> void: notify("Default button pressed.", "info"))
	live.add_child(_first_button)
	live.add_child(UiKit.button("Primary", func() -> void: notify("Primary button pressed.", "success"), &"PrimaryButton"))
	live.add_child(UiKit.button("Danger", func() -> void: notify("Danger button pressed.", "error"), &"DangerButton"))
	var disabled: Button = UiKit.button("Disabled", Callable())
	disabled.disabled = true
	live.add_child(disabled)
	live.add_child(CycleButton.create("Cycle", [["a", "One"], ["b", "Two"], ["c", "Three"]]))
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "Toggle"
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.custom_minimum_size = Vector2(0, SocTokens.MIN_TARGET)
	live.add_child(toggle)
	card.body.add_child(UiKit.label("Resting, hover, pressed, disabled and focus, drawn from the theme:", &"SocCaption"))
	var states: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	card.body.add_child(states)
	for state: String in BUTTON_STATES:
		states.add_child(_state_sample(state))
	return card


func _state_sample(state: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 0)
	var box: StyleBox = get_theme_stylebox(state, "Button")
	panel.add_theme_stylebox_override("panel", box)
	var caption: Label = UiKit.label(state.capitalize(), &"", false)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(caption)
	panel.custom_minimum_size.y = SocTokens.MIN_TARGET
	return panel


func _cards_card() -> SocCard:
	var card: SocCard = SocCard.create("Cards and panels")
	var standard: SocCard = SocCard.create("Card")
	standard.body.add_child(UiKit.label("Surface fill, divider outline. The default container.", &"SocMuted"))
	card.body.add_child(standard)
	var elevated: SocCard = SocCard.create("Elevated card", &"ElevatedPanel")
	elevated.body.add_child(UiKit.label("Elevated fill, stronger outline. For the main focus of a screen.", &"SocMuted"))
	card.body.add_child(elevated)
	var inset: SocCard = SocCard.create("", &"InsetPanel")
	inset.body.add_child(UiKit.label("Inset panel for counters and code.", &"SocMono"))
	card.body.add_child(inset)
	return card


func _badges_card() -> SocCard:
	var card: SocCard = SocCard.create("Status badges")
	card.body.add_child(UiKit.label("Colour always comes with a marker and a word.", &"SocCaption"))
	for severity: String in SocTokens.SEVERITIES:
		card.body.add_child(UiKit.severity_badge(severity))
	for level: String in ["ok", "warn", "error", "info"]:
		card.body.add_child(UiKit.status_badge("Example %s" % level, level))
	return card


func _navigation_card() -> SocCard:
	var card: SocCard = SocCard.create("Navigation elements")
	card.body.add_child(UiKit.button("Command Center", func() -> void: go_to(&"command_center"), &"NavButton"))
	card.body.add_child(UiKit.button("Investigation", func() -> void: go_to(&"investigation"), &"NavButton"))
	card.body.add_child(UiKit.label("Left navigation items. Q / E or the shoulder buttons switch screens; Back returns to the menu.", &"SocCaption"))
	return card


func _table_card() -> SocCard:
	var card: SocCard = SocCard.create("Data table")
	var table: Tree = UiKit.table([["Time", 64], ["Event", 84], ["User", 0], ["Result", 90]], 120.0)
	UiKit.add_row(table, PackedStringArray(["09:12", "EVT-001", "j.smith", "failure"]))
	UiKit.add_row(table, PackedStringArray(["09:15", "EVT-002", "j.smith", "failure"]))
	UiKit.add_row(table, PackedStringArray(["09:19", "EVT-003", "j.smith", "success"]))
	card.body.add_child(table)
	return card


func _tabs_card() -> SocCard:
	var card: SocCard = SocCard.create("Tabs")
	var tabs: TabContainer = TabContainer.new()
	tabs.focus_mode = Control.FOCUS_ALL
	tabs.custom_minimum_size = Vector2(0, 110)
	var first: Label = UiKit.label("Content of the first tab. Left and Right change tab when the tab bar has focus.", &"")
	first.name = "Overview"
	var second: Label = UiKit.label("Content of the second tab.", &"")
	second.name = "Details"
	tabs.add_child(first)
	tabs.add_child(second)
	card.body.add_child(tabs)
	return card


func _progress_card() -> SocCard:
	var card: SocCard = SocCard.create("Progress indicators")
	card.body.add_child(UiKit.progress(0.25, "Started"))
	card.body.add_child(UiKit.progress(0.6, "Skill mastery"))
	card.body.add_child(UiKit.progress(1.0, "Complete"))
	return card


func _dialog_card() -> SocCard:
	var card: SocCard = SocCard.create("Dialog")
	card.body.add_child(UiKit.button("Open sample dialog", _open_dialog))
	_dialog_result = UiKit.label("Dialogs start on the safe choice and return focus here.", &"SocCaption")
	card.body.add_child(_dialog_result)
	return card


func _spacing_card() -> SocCard:
	var card: SocCard = SocCard.create("Spacing, radius and focus tokens")
	for token: Dictionary in SPACING_TOKENS:
		var row: HBoxContainer = UiKit.hbox(SocTokens.SPACE_M)
		var name_label: Label = UiKit.label("%s  %dpx" % [token["name"], token["value"]], &"SocMono", false)
		name_label.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_label)
		var bar: ColorRect = ColorRect.new()
		bar.color = SocTokens.CYAN
		bar.custom_minimum_size = Vector2(int(token["value"]) * 4, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		card.body.add_child(row)
	card.body.add_child(UiKit.label("Radius %dpx. Border %dpx. Focus outline %dpx (thicker than the border, so focus is a shape and not only a colour). Minimum target %dpx." % [SocTokens.RADIUS, SocTokens.BORDER_WIDTH, SocTokens.FOCUS_WIDTH, int(SocTokens.MIN_TARGET)], &"SocMuted"))
	return card


## Gives a card a minimum width so the flow row wraps it instead of squeezing it.
func _sized(card: Control, width: float) -> Control:
	card.custom_minimum_size.x = width
	return card


func _open_dialog() -> void:
	var dialog: ModalDialog = ModalDialog.open(overlay_host(), "Sample dialog", "This is the shared confirmation dialog. It starts on the safe choice.", "Confirm", "Cancel")
	dialog.confirmed.connect(func() -> void: _dialog_result.text = "Dialog result: confirmed.")
	dialog.cancelled.connect(func() -> void: _dialog_result.text = "Dialog result: cancelled.")
