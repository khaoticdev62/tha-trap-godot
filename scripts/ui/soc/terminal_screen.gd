extends SocScreen
## SCREEN 05: The simulated terminal. Every line goes to SocModel.run_command,
## which uses the allowlisted TerminalParser over the synthetic scenario. This
## script only shows text: it never builds a command, starts a process or reads
## a file. Output is plain text (BBCode is off and lines are added with
## add_text), so nothing a command prints can change the display.
##
## Controller path: the sample-command buttons run any allowlisted example
## without typing, and Up/Down in the input line walks the command history.

const MAX_KEPT_LINES: int = 500
## A D-pad press scrolls the console by this fraction of a page.
const PAD_SCROLL_FRACTION: float = 4.0
const PROMPT: String = "analyst@new-meridian:~$ "
const BANNER_LINES: PackedStringArray = [
	"SIMULATED TERMINAL. Synthetic training data only.",
	"Nothing typed here reaches your computer, files or network.",
	"Type help to list the commands, or use the sample commands on the right.",
]

var _output: RichTextLabel
var _command_line: LineEdit
var _lines: Array[Dictionary] = []  # {text, role}
var _history_cursor: int = 0
var _palette_card: SocCard


func screen_id() -> StringName:
	return &"terminal"


func screen_title() -> String:
	return "Simulated Terminal"


func screen_context() -> String:
	return "Allowlisted commands over synthetic data only."


func build() -> void:
	var banner: PanelContainer = PanelContainer.new()
	banner.theme_type_variation = &"ElevatedPanel"
	# Always visible (spec 05 §5): the exact banner text, then what it means.
	var banner_text: VBoxContainer = UiKit.vbox(2)
	banner_text.add_child(UiKit.label(SocModel.terminal_banner(), &"SocMono"))
	banner_text.add_child(UiKit.label("Allowlisted commands over synthetic data. No real shell, files or network.", &"SocCaption"))
	banner.add_child(banner_text)
	_page.add_child(banner)

	var columns: HFlowContainer = UiKit.flow()
	_page.add_child(columns)

	var console: SocCard = SocCard.create("Console", &"", true)
	console.custom_minimum_size = Vector2(680, 0)
	columns.add_child(console)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = false
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.focus_mode = Control.FOCUS_ALL
	_output.custom_minimum_size = Vector2(0, 300)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.tooltip_text = "Command output. Use Up and Down to scroll when focused."
	_output.gui_input.connect(_on_output_gui_input)
	console.body.add_child(_output)
	var input_row: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	console.body.add_child(input_row)
	input_row.add_child(UiKit.label(PROMPT.strip_edges(), &"SocMono", false))
	_command_line = LineEdit.new()
	_command_line.placeholder_text = "Type a command, for example: help"
	_command_line.max_length = TerminalTokenizer.MAX_LINE_CHARS
	_command_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_line.custom_minimum_size = Vector2(240, SocTokens.MIN_TARGET)
	_command_line.text_submitted.connect(func(_text: String) -> void: _submit())
	_command_line.gui_input.connect(_on_input_gui_input)
	input_row.add_child(_command_line)
	input_row.add_child(UiKit.button("Run", _submit, &"PrimaryButton"))

	_palette_card = SocCard.create("Sample commands", &"", true)
	_palette_card.custom_minimum_size = Vector2(300, 0)
	columns.add_child(_palette_card)
	_palette_card.body.add_child(UiKit.label("Press a command to run it. Typing is optional.", &"SocCaption"))
	for command: String in SocModel.COMMAND_PALETTE:
		var button: Button = UiKit.button(command, func() -> void: _run_sample(command))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "Run: %s" % command
		_palette_card.body.add_child(button)
	_palette_card.body.add_child(UiKit.label("Up and Down in the input line recall earlier commands.", &"SocCaption"))

	for line: String in BANNER_LINES:
		_add_line(line, "system")


func refresh() -> void:
	# Output is append-only; nothing to re-read when the model changes.
	pass


func default_focus() -> Control:
	return _command_line


func _run_sample(command: String) -> void:
	_command_line.text = command
	_submit()
	_command_line.grab_focus()


func _submit() -> void:
	var line: String = _command_line.text
	if line.strip_edges().is_empty():
		return
	_add_line(PROMPT + line, "command")
	var result: TerminalResult = model.run_command(line)
	if result.clear_screen:
		_lines.clear()
		_render()
	for output_line: String in result.lines:
		_add_line(output_line, "output" if result.ok else "error")
	_command_line.text = ""
	_history_cursor = model.terminal.history.size()


func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var history: PackedStringArray = model.terminal.history
	if history.is_empty():
		return
	if event.is_action_pressed(&"ui_up"):
		# At the oldest entry, Up is not ours: let focus move out of the field.
		if _history_cursor <= 0:
			return
		_history_cursor = maxi(_history_cursor - 1, 0)
		_command_line.text = history[_history_cursor]
		_command_line.caret_column = _command_line.text.length()
		_command_line.accept_event()
	elif event.is_action_pressed(&"ui_down") and _history_cursor < history.size():
		_history_cursor += 1
		_command_line.text = history[_history_cursor] if _history_cursor < history.size() else ""
		_command_line.caret_column = _command_line.text.length()
		_command_line.accept_event()


## The engine scrolls a focused RichTextLabel only for keyboard keys, so a D-pad or
## stick would do nothing. Scroll for those here, and at either end let the event
## through so focus can move on (never a trap).
func _on_output_gui_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse:
		return
	var direction: int = 0
	if event.is_action_pressed(&"ui_up", true):
		direction = -1
	elif event.is_action_pressed(&"ui_down", true):
		direction = 1
	if direction == 0:
		return
	var bar: VScrollBar = _output.get_v_scroll_bar()
	var at_top: bool = bar.value <= bar.min_value
	var at_bottom: bool = bar.value >= bar.max_value - bar.page - 0.5
	if (direction < 0 and at_top) or (direction > 0 and at_bottom):
		return
	bar.value += direction * bar.page / PAD_SCROLL_FRACTION
	_output.accept_event()


func _add_line(text: String, role: String) -> void:
	_lines.append({"text": text, "role": role})
	if _lines.size() > MAX_KEPT_LINES:
		_lines = _lines.slice(_lines.size() - MAX_KEPT_LINES)
		_render()
		return
	_write(_lines[_lines.size() - 1])


func _render() -> void:
	_output.clear()
	for entry: Dictionary in _lines:
		_write(entry)


## Plain text only: add_text never parses markup.
func _write(entry: Dictionary) -> void:
	var color: Color = SocTokens.TEXT
	var prefix: String = ""
	match str(entry["role"]):
		"command":
			color = SocTokens.CYAN
		"error":
			color = SocTokens.RED
			prefix = "ERROR: "
		"system":
			color = SocTokens.TEXT_MUTED
	_output.push_color(color)
	_output.add_text(prefix + str(entry["text"]) + "\n")
	_output.pop()


## Lines currently shown, as plain text. Used by tests.
func output_text() -> String:
	var rows: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _lines:
		rows.append(str(entry["text"]))
	return "\n".join(rows)


## Runs a command as if typed. Used by tests and the capture tool.
func run_line(line: String) -> void:
	_command_line.text = line
	_submit()
