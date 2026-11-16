extends Node
## Integration check: drives the DialogueBox inside a real scene tree, the way
## the dialogue system will. Covers reveal timing, accept-to-complete,
## accept-to-advance, branching choices, reduced motion and hostile text.
##   godot --headless --path . res://tests/integration/dialogue_flow.tscn

var _failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var tree: SceneTree = get_tree()
	tree.create_timer(20.0).timeout.connect(func() -> void:
		print("FAIL  watchdog: test did not finish in 20s")
		tree.quit(1))

	var settings: AccessibilitySettings = AccessibilitySettings.new()
	settings.text_speed = "slow"
	var box: DialogueBox = DialogueBox.new()
	box.settings = settings
	add_child(box)
	await tree.process_frame

	var finished: Array[int] = [0]
	var picked: Array[int] = []
	box.line_finished.connect(func() -> void: finished[0] += 1)
	box.choice_selected.connect(func(index: int) -> void: picked.append(index))

	# Reveal is gradual at slow speed, and not instant.
	box.show_line("Nia", "x".repeat(400))
	_check(box.visible and box.is_active(), "line becomes visible and active")
	_check(box.is_revealing(), "slow text is still revealing right after it starts")
	_check(box.visible_character_count() < 400, "not all characters are visible yet")

	# Accept while revealing completes the line but does not advance it.
	_press_accept(box)
	_check(not box.is_revealing(), "accept completes the reveal")
	_check(finished[0] == 0, "completing a line does not also advance it")
	_check(box.visible_character_count() == -1, "the whole line is shown")

	# A second accept advances.
	_press_accept(box)
	_check(finished[0] == 1, "accept on a finished line advances")
	_check(not box.visible, "box hides after the last line")

	# Reduced motion shows lines instantly.
	settings.reduced_motion = true
	box.show_line("Nia", "x".repeat(400))
	_check(not box.is_revealing(), "reduced motion shows the line at once")
	_press_accept(box)
	_check(finished[0] == 2, "advance works after an instant line")
	settings.reduced_motion = false

	# Choices appear only when the line is complete, and are keyboard/controller focusable.
	box.show_line("Imani", "Which first?", ["Contain it", "Gather evidence"])
	_check(box.is_revealing(), "choice line reveals first at slow speed")
	var choice_buttons: Array[Button] = []
	_collect_buttons(box, choice_buttons)
	_check(choice_buttons.size() == 2, "two choice buttons exist")
	_check(not choice_buttons[0].visible, "choices stay hidden while text reveals")
	_press_accept(box)
	_check(choice_buttons[0].visible and choice_buttons[1].visible, "choices appear when the line completes")
	_check(get_viewport().gui_get_focus_owner() == choice_buttons[0], "focus lands on the first choice")
	_check(choice_buttons[0].custom_minimum_size.y >= 44.0, "choices meet the minimum target size")
	choice_buttons[1].pressed.emit()
	_check(picked == [1], "pressing a choice reports its index")
	_check(finished[0] == 2, "a choice does not also fire line_finished")

	# Hostile text is shown literally and over-long input is truncated, never rejected.
	settings.text_speed = "instant"
	box.show_line("<b>Eve</b>", "[b]bold[/b] [url=x]link[/url] " + "y".repeat(2400))
	var texts: Array[Label] = []
	_collect_labels(box, texts)
	var longest: int = 0
	var markup_seen: bool = false
	for label: Label in texts:
		longest = maxi(longest, label.text.length())
		markup_seen = markup_seen or label.text.begins_with("[b]bold[/b]")
	# Literal on purpose: the contract is 1200 characters, not "whatever the constant says".
	_check(longest <= 1200, "long text is truncated to 1200 characters (got %d)" % longest)
	_check(markup_seen, "markup-like text is displayed literally")
	_press_accept(box)

	# More choices than the cap are truncated.
	var many: Array[String] = []
	for index: int in 20:
		many.append("Option %d" % index)
	box.show_line("", "Pick.", many)
	var capped: Array[Button] = []
	_collect_buttons(box, capped)
	_check(capped.size() == 6, "choice count is capped at 6 (got %d)" % capped.size())

	for line: String in _failures:
		print("FAIL  ", line)
	print("dialogue_flow: %d failures" % _failures.size())
	tree.quit(1 if _failures.size() > 0 else 0)


func _press_accept(box: DialogueBox) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	box._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _collect_buttons(node: Node, into: Array[Button]) -> void:
	if node is Button:
		into.append(node)
	for child: Node in node.get_children():
		if child.is_queued_for_deletion():
			continue
		_collect_buttons(child, into)


func _collect_labels(node: Node, into: Array[Label]) -> void:
	if node is Label:
		into.append(node)
	for child: Node in node.get_children():
		_collect_labels(child, into)
