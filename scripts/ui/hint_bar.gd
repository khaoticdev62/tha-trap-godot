class_name HintBar
extends Label
## A line of help text that follows keyboard/controller focus as well as the
## mouse, so guidance is never hover-only. Controls keep a normal tooltip too.
##   hint_bar.bind(control, "What this does.")

const FOCUS_COLOR_VARIATION: StringName = &"MutedLabel"


func _ready() -> void:
	theme_type_variation = FOCUS_COLOR_VARIATION
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func bind(control: Control, hint: String) -> void:
	control.tooltip_text = hint
	control.focus_entered.connect(func() -> void: text = hint)
	control.mouse_entered.connect(func() -> void: text = hint)
