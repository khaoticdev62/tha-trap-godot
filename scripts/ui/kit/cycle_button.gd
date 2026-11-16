class_name CycleButton
extends Button
## A button that steps through a fixed list of values each time it is pressed:
## one control that works the same with mouse, keyboard and controller (a
## dropdown popup is awkward on a gamepad). Shows "Label: Value".
##   var source: CycleButton = CycleButton.create("Source", [["all", "All"], ["auth", "Auth"]])
##   source.value_changed.connect(func(value: String) -> void: ...)

signal value_changed(value: String)

var caption: String = ""
var _values: PackedStringArray = PackedStringArray()
var _labels: PackedStringArray = PackedStringArray()
var _index: int = 0


## `options` is a list of [value, label] pairs. The first pair is the default.
## Pass autowrap = true only in a column of fixed width (never in a flow row).
static func create(caption_text: String, options: Array, autowrap: bool = false) -> CycleButton:
	var button: CycleButton = CycleButton.new()
	button.caption = caption_text
	for option: Variant in options:
		button._values.append(str((option as Array)[0]))
		button._labels.append(str((option as Array)[1]))
	button.custom_minimum_size = Vector2(0, SocTokens.MIN_TARGET)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if autowrap:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(button._advance)
	button._refresh()
	return button


func value() -> String:
	return _values[_index] if _index < _values.size() else ""


## Selects a value without emitting value_changed. Unknown values are ignored.
func set_value(wanted: String) -> void:
	var found: int = _values.find(wanted)
	if found >= 0:
		_index = found
		_refresh()


func _advance() -> void:
	if _values.is_empty():
		return
	_index = (_index + 1) % _values.size()
	_refresh()
	value_changed.emit(value())


func _refresh() -> void:
	text = "%s: %s" % [caption, _labels[_index] if _index < _labels.size() else ""]
	tooltip_text = "Press to change %s." % caption.to_lower()
