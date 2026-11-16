extends SocScreen
## SCREEN 04: Case management for CASE-001. Overview, evidence locker, timeline,
## analyst notes, risk and impact, the five response actions and the audit
## history. Response actions change only the simulated case state in SocModel.

const SEVERITY_OPTIONS: Array = [["unset", "Not set"], ["low", "Low"], ["medium", "Medium"], ["high", "High"], ["critical", "Critical"]]

var _overview: SocCard
var _status_row: HBoxContainer
var _severity: CycleButton
var _scope_box: VBoxContainer
var _scope_toggles: Dictionary = {}  # asset id -> CheckButton
var _escalate_choice: CycleButton
var _contain_choice: CycleButton
var _response_note: Label
var _evidence_table: Tree
var _remove_evidence_button: Button
var _timeline_table: Tree
var _notes_table: Tree
var _remove_note_button: Button
var _impact_card: SocCard
var _audit_table: Tree
var _syncing: bool = false


func screen_id() -> StringName:
	return &"cases"


func screen_title() -> String:
	return "Case Management"


func screen_context() -> String:
	return "%s evidence, timeline and simulated response." % CaseFile.CASE_ID


func build() -> void:
	var columns: HFlowContainer = UiKit.flow()
	_page.add_child(columns)
	var left: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	left.custom_minimum_size = Vector2(300, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var middle: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	middle.custom_minimum_size = Vector2(420, 0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(middle)
	var right: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	right.custom_minimum_size = Vector2(300, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_build_overview(left)
	_build_response(left)
	_build_evidence(middle)
	_build_timeline(middle)
	_impact_card = SocCard.create("Risk and impact")
	right.add_child(_impact_card)
	var audit: SocCard = SocCard.create("Audit history", &"", true)
	_audit_table = UiKit.table([["#", 56], ["Entry", 0]], 220.0)
	audit.body.add_child(_audit_table)
	right.add_child(audit)
	_build_notes(_page)


func refresh() -> void:
	_syncing = true
	_refresh_overview()
	_syncing = false
	_refresh_evidence()
	_refresh_timeline()
	_refresh_notes()
	_refresh_impact()
	_refresh_audit()


func default_focus() -> Control:
	return _severity


func _build_overview(parent: Control) -> void:
	_overview = SocCard.create("Case overview", &"ElevatedPanel")
	parent.add_child(_overview)
	_overview.body.add_child(UiKit.label("%s  %s" % [CaseFile.CASE_ID, model.case_title()], &"SocMono"))
	_status_row = UiKit.hbox()
	_overview.body.add_child(_status_row)
	_severity = CycleButton.create("Severity", SEVERITY_OPTIONS)
	_severity.value_changed.connect(func(value: String) -> void:
		if not _syncing and value != "unset":
			model.set_severity(value))
	_overview.body.add_child(_severity)
	_overview.body.add_child(UiKit.label("Assets in scope", &"SocHeading"))
	_scope_box = UiKit.vbox(SocTokens.SPACE_XS)
	_overview.body.add_child(_scope_box)
	for asset: Dictionary in model.session.package.assets:
		var toggle: CheckButton = CheckButton.new()
		toggle.text = "%s (%s)" % [asset.get("name", ""), str(asset.get("kind", "")).replace("_", " ")]
		toggle.focus_mode = Control.FOCUS_ALL
		toggle.custom_minimum_size = Vector2(0, SocTokens.MIN_TARGET)
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var asset_id: String = str(asset.get("id", ""))
		toggle.toggled.connect(func(_on: bool) -> void:
			if not _syncing:
				model.toggle_scope(asset_id))
		_scope_box.add_child(toggle)
		_scope_toggles[asset_id] = toggle


func _build_response(parent: Control) -> void:
	var card: SocCard = SocCard.create("Response actions")
	parent.add_child(card)
	card.body.add_child(UiKit.label("Simulated only: these change the training case, never a real system.", &"SocCaption"))
	card.body.add_child(UiKit.button("Investigate", func() -> void: model.apply_response("investigate")))
	var escalate_options: Array = []
	for option: Dictionary in model.session.package.escalation_options:
		escalate_options.append([option["id"], option["label"]])
	_escalate_choice = CycleButton.create("Escalation", escalate_options, true)
	card.body.add_child(_escalate_choice)
	card.body.add_child(UiKit.button("Escalate", func() -> void: model.apply_response("escalate", _escalate_choice.value())))
	var contain_options: Array = []
	for option: Dictionary in model.session.package.response_options:
		contain_options.append([option["id"], option["label"]])
	_contain_choice = CycleButton.create("Response", contain_options, true)
	card.body.add_child(_contain_choice)
	card.body.add_child(UiKit.button("Contain", func() -> void: model.apply_response("contain", _contain_choice.value())))
	card.body.add_child(UiKit.button("Preserve evidence", func() -> void: model.apply_response("preserve")))
	card.body.add_child(UiKit.button("Recover", func() -> void: model.apply_response("recover")))
	_response_note = UiKit.label("", &"SocMuted")
	card.body.add_child(_response_note)


func _build_evidence(parent: Control) -> void:
	var card: SocCard = SocCard.create("Evidence locker", &"", true)
	parent.add_child(card)
	_evidence_table = UiKit.table([["ID", 84], ["Events", 0]], 120.0)
	card.body.add_child(_evidence_table)
	_remove_evidence_button = UiKit.button("Remove selected evidence", _on_remove_evidence, &"DangerButton")
	card.body.add_child(_remove_evidence_button)


func _build_timeline(parent: Control) -> void:
	var card: SocCard = SocCard.create("Timeline (from collected evidence)", &"", true)
	parent.add_child(card)
	_timeline_table = UiKit.table([["Time", 76], ["+Min", 70], ["Event", 116], ["Detail", 0]], 150.0)
	card.body.add_child(_timeline_table)


func _build_notes(parent: Control) -> void:
	var card: SocCard = SocCard.create("Analyst notes", &"", true)
	parent.add_child(card)
	_notes_table = UiKit.table([["Entry", 84], ["Type", 134], ["Note", 0]], 130.0)
	card.body.add_child(_notes_table)
	_remove_note_button = UiKit.button("Remove selected note", _on_remove_note, &"DangerButton")
	card.body.add_child(_remove_note_button)
	card.body.add_child(UiKit.button("Add notes in investigation", func() -> void: go_to(&"investigation")))


func _refresh_overview() -> void:
	for child: Node in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()
	_status_row.add_child(UiKit.status_badge(model.status_label(), "ok" if model.case_status == "recovered" else "info"))
	var level: String = model.session.case_file.severity
	_severity.set_value(level)
	if level != "unset":
		_status_row.add_child(UiKit.severity_badge(level))
	for asset_id: String in _scope_toggles:
		(_scope_toggles[asset_id] as CheckButton).button_pressed = model.session.case_file.scope.has(asset_id)
	var chosen: String = model.session.case_file.escalation
	if not chosen.is_empty():
		_escalate_choice.set_value(chosen)
	var response: String = model.session.case_file.recommendation
	if not response.is_empty():
		_contain_choice.set_value(response)
	_response_note.text = "Escalation: %s.  Containment: %s.%s" % [chosen if not chosen.is_empty() else "not chosen", response if not response.is_empty() else "not chosen", "  Snapshot %s." % model.preserved_ref if not model.preserved_ref.is_empty() else ""]


func _refresh_evidence() -> void:
	UiKit.clear_table(_evidence_table)
	for record: EvidenceRecord in model.session.ledger.all():
		var shown: PackedStringArray = PackedStringArray()
		for event_id: String in record.event_ids:
			var event: EventRecord = model.session.store.get_event(event_id)
			shown.append(event.display_id if event != null else event_id)
		var events_text: String = ", ".join(shown) + ("  (%s)" % record.note if not record.note.is_empty() else "")
		UiKit.add_row(_evidence_table, PackedStringArray([record.id, events_text]), record.id)
	_remove_evidence_button.disabled = model.session.ledger.size() == 0


func _refresh_timeline() -> void:
	UiKit.clear_table(_timeline_table)
	var items: Array[Dictionary] = model.session.build_timeline()
	if items.is_empty():
		UiKit.add_row(_timeline_table, PackedStringArray(["", "", "", "Collect evidence to build the timeline."]))
	for item: Dictionary in items:
		UiKit.add_row(_timeline_table, PackedStringArray([str(item["time"]), "+%s" % item["minutes_since_first"], str(item["display_id"]), "%s, %s: %s" % [item["actor"], item["result"], item["detail"]]]))


func _refresh_notes() -> void:
	UiKit.clear_table(_notes_table)
	for entry: CaseEntry in model.session.case_file.entries():
		UiKit.add_row(_notes_table, PackedStringArray([entry.id, entry.kind.capitalize(), entry.text]), entry.id)
	_remove_note_button.disabled = model.session.case_file.entries().is_empty()


func _refresh_impact() -> void:
	_impact_card.clear_body()
	for line: String in model.impact_lines():
		_impact_card.body.add_child(UiKit.label(line, &""))


func _refresh_audit() -> void:
	UiKit.clear_table(_audit_table)
	for entry: Dictionary in model.audit_history():
		UiKit.add_row(_audit_table, PackedStringArray([str(entry["number"]), "%s: %s" % [entry["action"], entry["detail"]]]))


func _on_remove_evidence() -> void:
	var evidence_id: Variant = UiKit.selected_metadata(_evidence_table)
	if typeof(evidence_id) != TYPE_STRING:
		notify("Select an evidence row first.", "error")
		return
	model.remove_evidence(evidence_id)


func _on_remove_note() -> void:
	var entry_id: Variant = UiKit.selected_metadata(_notes_table)
	if typeof(entry_id) != TYPE_STRING:
		notify("Select a note first.", "error")
		return
	model.remove_note(entry_id)
