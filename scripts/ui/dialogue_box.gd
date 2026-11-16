class_name DialogueBox
extends PanelContainer
## Dialogue panel: speaker, revealed text, optional choices.
##   box.show_line("Nia", "Hello.")                  -> emits line_finished
##   box.show_line("Nia", "Ready?", ["Yes", "Wait"]) -> emits choice_selected(i)
##
## Behaviour:
##  - accept (A / Enter) while text is revealing completes the line; accept on a
##    finished line advances. Nothing is timed, so a player can read at any pace.
##  - the reveal honours the text-speed setting and reduced motion.
##  - the full line is exposed to assistive tech immediately, not letter by letter.
##  - text is plain text; markup in a line is shown literally, never interpreted.

signal line_finished
signal choice_selected(index: int)

const MAX_LINE_CHARS: int = 1200
const MAX_CHOICES: int = 6
const MAX_CHOICE_CHARS: int = 160
const PANEL_MARGIN: float = 24.0
const CONTINUE_PROMPT: String = "Press A or Enter to continue"

## Tests may set this; otherwise the Settings autoload is used when present.
var settings: AccessibilitySettings

var _speaker_label: Label
var _text_label: Label
var _prompt_label: Label
var _choices_box: VBoxContainer
var _choice_count: int = 0
var _elapsed: float = 0.0
var _complete: bool = true
var _active: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Pinned to the bottom edge; the panel is as tall as its content and grows upward.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, int(PANEL_MARGIN))
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	if not _active or _complete:
		return
	_elapsed += delta
	_apply_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not event.is_action_pressed(&"ui_accept"):
		return
	# Choice buttons handle their own accept presses once they are shown.
	if _complete and _choice_count > 0:
		return
	get_viewport().set_input_as_handled()
	if not _complete:
		_finish_reveal()
	else:
		_active = false
		visible = false
		line_finished.emit()


## Shows one line. Over-long text and extra choices are truncated, never rejected.
func show_line(speaker: String, text: String, choices: Array[String] = []) -> void:
	var clean_text: String = text.substr(0, MAX_LINE_CHARS)
	_speaker_label.text = PlayerProfile.sanitize_name(speaker, "", AppConfig.PROFILE_NAME_MAX_LENGTH)
	_speaker_label.visible = not _speaker_label.text.is_empty()
	_text_label.text = clean_text
	_text_label.visible_characters = 0
	_set_choices(choices)
	_describe(self, _speaker_label.text if _speaker_label.visible else "Dialogue", clean_text)
	_elapsed = 0.0
	_active = true
	_complete = false
	visible = true
	_apply_reveal()


func is_revealing() -> bool:
	return _active and not _complete


func is_active() -> bool:
	return _active


func visible_character_count() -> int:
	return _text_label.visible_characters


func _build() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	_speaker_label = Label.new()
	_speaker_label.theme_type_variation = &"HeadingLabel"
	column.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(0, 96)
	column.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	column.add_child(_choices_box)

	_prompt_label = Label.new()
	_prompt_label.text = CONTINUE_PROMPT
	_prompt_label.theme_type_variation = &"MutedLabel"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_prompt_label)


func _set_choices(choices: Array[String]) -> void:
	for child: Node in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()
	_choice_count = mini(choices.size(), MAX_CHOICES)
	for index: int in _choice_count:
		var button: Button = Button.new()
		button.text = choices[index].substr(0, MAX_CHOICE_CHARS)
		button.custom_minimum_size = Vector2(0, UiTheme.MIN_TARGET_HEIGHT)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.visible = false
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choices_box.add_child(button)


func _on_choice_pressed(index: int) -> void:
	if not _active or not _complete:
		return
	_active = false
	visible = false
	choice_selected.emit(index)


func _current_settings() -> AccessibilitySettings:
	if settings != null:
		return settings
	var service: Node = get_node_or_null("/root/Settings")
	if service != null and "current" in service:
		return service.current
	return AccessibilitySettings.new()


func _apply_reveal() -> void:
	var active_settings: AccessibilitySettings = _current_settings()
	var total: int = _text_label.text.length()
	var shown: int = Typewriter.visible_chars(_elapsed, total, active_settings.text_speed, active_settings.reduced_motion)
	_text_label.visible_characters = shown
	if shown >= total:
		_on_reveal_complete()


func _finish_reveal() -> void:
	_text_label.visible_characters = -1
	_on_reveal_complete()


func _on_reveal_complete() -> void:
	_complete = true
	_text_label.visible_characters = -1
	for child: Node in _choices_box.get_children():
		(child as Control).visible = true
	_prompt_label.visible = _choice_count == 0
	if _choice_count > 0:
		(_choices_box.get_child(0) as Control).grab_focus()


func _describe(control: Control, accessible_name: String, description: String) -> void:
	if "accessibility_name" in control:
		control.set("accessibility_name", accessible_name)
	if "accessibility_description" in control:
		control.set("accessibility_description", description)
