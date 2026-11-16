extends SocScreen
## SCREEN 06: Mission and learning for LAB-001, "Somebody's In The Network".
## Briefing, objectives, community impact, learning objectives, skill mastery,
## contextual hints, knowledge checks, case review and a career preview. All text
## comes from the mission's learning document; progress comes from the rubric
## review. Knowledge checks give feedback only: they never change the score.

var _objectives_card: SocCard
var _mastery_card: SocCard
var _hint_card: SocCard
var _hint_button: Button
var _review_card: SocCard
var _review_button: Button
var _check_feedback: Dictionary = {}  # check id -> Label
var _check_buttons: Dictionary = {}  # check id -> Array[Button]


func screen_id() -> StringName:
	return &"mission"


func screen_title() -> String:
	return "Mission and Learning"


func screen_context() -> String:
	return "LAB-001: Somebody's In The Network."


func build() -> void:
	var columns: HFlowContainer = UiKit.flow()
	_page.add_child(columns)
	var left: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	left.custom_minimum_size = Vector2(330, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var middle: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	middle.custom_minimum_size = Vector2(330, 0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(middle)
	var right: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	right.custom_minimum_size = Vector2(330, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_build_briefing(left)
	_objectives_card = SocCard.create("Mission objectives")
	left.add_child(_objectives_card)
	_build_learning_objectives(left)

	_mastery_card = SocCard.create("Skill mastery", &"ElevatedPanel")
	middle.add_child(_mastery_card)
	_build_hints(middle)
	_build_review(middle)
	_build_career(middle)

	_build_checks(right)


func refresh() -> void:
	_refresh_objectives()
	_refresh_mastery()
	_refresh_hints()


func default_focus() -> Control:
	return _hint_button


func _build_briefing(parent: Control) -> void:
	var card: SocCard = SocCard.create("Story briefing", &"ElevatedPanel")
	parent.add_child(card)
	card.body.add_child(UiKit.label("LAB-001  |  Market Row", &"SocCaption"))
	for paragraph: Variant in model.learning.get("briefing", []):
		card.body.add_child(UiKit.label(str(paragraph), &""))
	var impact: SocCard = SocCard.create("Community impact")
	parent.add_child(impact)
	impact.body.add_child(UiKit.label(str(model.learning.get("community_impact", "")), &""))


func _build_learning_objectives(parent: Control) -> void:
	var card: SocCard = SocCard.create("What you will learn")
	parent.add_child(card)
	for objective: Variant in model.learning.get("learning_objectives", []):
		var row: Dictionary = objective
		card.body.add_child(UiKit.label(str(row.get("title", "")), &"SocHeading"))
		card.body.add_child(UiKit.label(str(row.get("explanation", "")), &"SocMuted"))


func _build_hints(parent: Control) -> void:
	_hint_card = SocCard.create("Contextual hints")
	parent.add_child(_hint_card)
	_hint_button = UiKit.button("Ask for a hint", _on_hint_pressed, &"PrimaryButton")
	_hint_card.body.add_child(_hint_button)


func _build_review(parent: Control) -> void:
	_review_card = SocCard.create("Case review")
	parent.add_child(_review_card)
	_review_card.body.add_child(UiKit.label("A review checks your case against the marking guide. It changes nothing, so you can review as often as you like.", &"SocMuted"))
	_review_button = UiKit.button("Review my case", _on_review_pressed)
	_review_card.body.add_child(_review_button)


func _build_career(parent: Control) -> void:
	var card: SocCard = SocCard.create("Career progression preview")
	parent.add_child(card)
	for stage: Variant in model.learning.get("career_preview", []):
		var row: Dictionary = stage
		card.body.add_child(UiKit.label("%s: %s" % [row.get("stage", ""), row.get("title", "")], &"SocHeading"))
		card.body.add_child(UiKit.label(str(row.get("note", "")), &"SocMuted"))
	card.body.add_child(UiKit.label("This is a preview of the story's path. It is not a qualification or a promise of a job.", &"SocCaption"))


func _build_checks(parent: Control) -> void:
	var card: SocCard = SocCard.create("Knowledge checks")
	parent.add_child(card)
	card.body.add_child(UiKit.label("Quick checks for feedback. They do not change your score; your case does.", &"SocCaption"))
	for check: Variant in model.learning.get("knowledge_checks", []):
		var row: Dictionary = check
		var check_id: String = str(row.get("id", ""))
		card.body.add_child(UiKit.label(str(row.get("question", "")), &"SocHeading"))
		var buttons: Array[Button] = []
		for option: Variant in row.get("options", []):
			var option_row: Dictionary = option
			var option_id: String = str(option_row.get("id", ""))
			var button: Button = UiKit.button(str(option_row.get("text", "")), func() -> void: _on_option_pressed(check_id, option_id))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.body.add_child(button)
			buttons.append(button)
		_check_buttons[check_id] = buttons
		var feedback: Label = UiKit.label("", &"")
		card.body.add_child(feedback)
		_check_feedback[check_id] = feedback


func _refresh_objectives() -> void:
	_objectives_card.clear_body()
	for objective: Dictionary in model.objectives():
		var marker: String = "[x] Done" if objective["status"] == "met" else ("[~] Partly" if objective["status"] == "partial" else "[ ] Not yet")
		_objectives_card.body.add_child(UiKit.label("%s  %s" % [marker, objective["text"]], &""))


func _refresh_mastery() -> void:
	_mastery_card.clear_body()
	_mastery_card.body.add_child(UiKit.progress(model.mastery_fraction(), "Overall"))
	for objective: Dictionary in model.objectives():
		var max_points: int = int(objective["max_points"])
		var fraction: float = float(objective["points"]) / float(max_points) if max_points > 0 else 0.0
		_mastery_card.body.add_child(UiKit.progress(fraction, str(objective["title"])))
	_mastery_card.body.add_child(UiKit.label("Mastery comes from the evidence in your case, not from the quick checks.", &"SocCaption"))


func _refresh_hints() -> void:
	for child: Node in _hint_card.body.get_children():
		if child != _hint_button:
			_hint_card.body.remove_child(child)
			child.queue_free()
	if model.hint_log.is_empty():
		_hint_card.body.add_child(UiKit.label("No hints used yet. Hints never lower your score.", &"SocMuted"))
	for hint: String in model.hint_log:
		_hint_card.body.add_child(UiKit.label(hint, &""))


func _on_hint_pressed() -> void:
	model.request_hint()


func _on_review_pressed() -> void:
	var review: AssessmentResult = model.assessment()
	for child: Node in _review_card.body.get_children():
		if child != _review_button and child.name.begins_with("ReviewLine"):
			_review_card.body.remove_child(child)
			child.queue_free()
	if review == null:
		notify("This lab has no marking guide.", "error")
		return
	var index: int = 0
	for line: String in review.summary_lines():
		var label: Label = UiKit.label(line, &"SocMono")
		label.name = "ReviewLine%d" % index
		_review_card.body.add_child(label)
		index += 1
	notify("Review: %d of %d points." % [review.total, review.max_points], "info")


func _on_option_pressed(check_id: String, option_id: String) -> void:
	var outcome: Dictionary = model.answer_check(check_id, option_id)
	if outcome.is_empty():
		return
	var label: Label = _check_feedback[check_id]
	label.text = "%s %s" % ["Correct." if outcome["correct"] else "Not quite.", outcome["feedback"]]
