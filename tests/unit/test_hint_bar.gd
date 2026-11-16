extends TestCase


func test_hint_follows_keyboard_and_controller_focus() -> void:
	var bar: HintBar = HintBar.new()
	var button: Button = Button.new()
	bar.bind(button, "Does a thing.")
	check_eq(bar.text, "", "no hint before interaction")
	button.focus_entered.emit()
	check_eq(bar.text, "Does a thing.", "focus shows the hint (not hover-only)")
	bar.free()
	button.free()


func test_hint_also_shows_on_mouse_hover_and_sets_a_tooltip() -> void:
	var bar: HintBar = HintBar.new()
	var button: Button = Button.new()
	bar.bind(button, "Hover text.")
	button.mouse_entered.emit()
	check_eq(bar.text, "Hover text.", "hover shows the hint")
	check_eq(button.tooltip_text, "Hover text.", "mouse tooltip is set too")
	bar.free()
	button.free()


func test_latest_focus_wins() -> void:
	var bar: HintBar = HintBar.new()
	var first: Button = Button.new()
	var second: Button = Button.new()
	bar.bind(first, "First.")
	bar.bind(second, "Second.")
	first.focus_entered.emit()
	second.focus_entered.emit()
	check_eq(bar.text, "Second.", "hint tracks the most recently focused control")
	bar.free()
	first.free()
	second.free()
