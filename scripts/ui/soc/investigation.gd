extends SocScreen
## SCREEN 03: Incident investigation for CASE-001 (Suspicious Authentication).
## Filter the authentication events, select one, read its user, host and MFA
## context, collect it as evidence and write investigation notes. Filter and
## selection state live in SocModel so they survive moving between screens.

const NOTE_KINDS: Array = [["fact", "Fact"], ["hypothesis", "Hypothesis"], ["unknown", "Unknown"]]

var _summary_card: SocCard
var _source_filter: CycleButton
var _result_filter: CycleButton
var _text_filter: LineEdit
var _count_label: Label
var _table: Tree
var _detail_card: SocCard
var _collect_button: Button
var _detail_body: VBoxContainer
var _note_kind: CycleButton
var _note_input: LineEdit
var _cite_toggle: CheckButton
var _notes_card: SocCard
var _syncing: bool = false


func screen_id() -> StringName:
	return &"investigation"


func screen_title() -> String:
	return "Incident Investigation"


func screen_context() -> String:
	return "%s: %s" % [CaseFile.CASE_ID, model.case_title() if model != null else ""]


func build() -> void:
	_summary_card = SocCard.create("Case summary", &"ElevatedPanel")
	_page.add_child(_summary_card)
	_summary_card.body.add_child(UiKit.label("%s: %s. Reported account: %s. %s" % [CaseFile.CASE_ID, model.case_title(), model.case_account(), str((model.learning.get("briefing", [""]) as Array)[0])], &""))

	var filters: SocCard = SocCard.create("Event filters")
	_page.add_child(filters)
	var row: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	filters.body.add_child(row)
	var source_options: Array = [["all", "All"]]
	for source: String in EventRecord.SOURCES:
		source_options.append([source, source.capitalize()])
	var result_options: Array = [["all", "All"]]
	for outcome: String in EventRecord.RESULTS:
		result_options.append([outcome, outcome.capitalize()])
	_source_filter = CycleButton.create("Source", source_options)
	_source_filter.value_changed.connect(func(value: String) -> void: _set_filters(value, model.filter_result, model.filter_text))
	row.add_child(_source_filter)
	_result_filter = CycleButton.create("Result", result_options)
	_result_filter.value_changed.connect(func(value: String) -> void: _set_filters(model.filter_source, value, model.filter_text))
	row.add_child(_result_filter)
	_text_filter = LineEdit.new()
	_text_filter.placeholder_text = "Account, event, device or text"
	_text_filter.max_length = SocModel.MAX_FILTER_TEXT
	_text_filter.clear_button_enabled = true
	_text_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_filter.custom_minimum_size = Vector2(280, SocTokens.MIN_TARGET)
	_text_filter.tooltip_text = "Filter events by text."
	_text_filter.text_changed.connect(func(value: String) -> void: _set_filters(model.filter_source, model.filter_result, value))
	row.add_child(_text_filter)
	row.add_child(UiKit.button("Clear filters", _clear_filters))
	_count_label = UiKit.label("", &"SocMuted")
	filters.body.add_child(_count_label)

	var middle: HFlowContainer = UiKit.flow()
	_page.add_child(middle)
	var table_card: SocCard = SocCard.create("Authentication events", &"", true)
	table_card.custom_minimum_size = Vector2(680, 0)
	_table = UiKit.table([["Time", 76], ["Event", 116], ["User", 130], ["Source", 90], ["Result", 114], ["Origin", 0]], 260.0)
	_table.item_selected.connect(_on_row_selected)
	table_card.body.add_child(_table)
	middle.add_child(table_card)

	_detail_card = SocCard.create("Selected event", &"ElevatedPanel", true)
	_detail_card.custom_minimum_size = Vector2(320, 0)
	middle.add_child(_detail_card)
	_detail_body = UiKit.vbox()
	_detail_card.body.add_child(_detail_body)
	_collect_button = UiKit.button("Collect as evidence", _on_collect_pressed, &"PrimaryButton")
	_detail_card.body.add_child(_collect_button)

	var notes: SocCard = SocCard.create("Investigation notes")
	_page.add_child(notes)
	var entry_row: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	notes.body.add_child(entry_row)
	_note_kind = CycleButton.create("Type", NOTE_KINDS)
	entry_row.add_child(_note_kind)
	_note_input = LineEdit.new()
	_note_input.placeholder_text = "What did you find? One sentence."
	_note_input.max_length = CaseFile.MAX_TEXT_CHARS
	_note_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_input.custom_minimum_size = Vector2(360, SocTokens.MIN_TARGET)
	_note_input.text_submitted.connect(func(_text: String) -> void: _on_add_note())
	entry_row.add_child(_note_input)
	entry_row.add_child(UiKit.button("Add note", _on_add_note))
	_cite_toggle = CheckButton.new()
	_cite_toggle.text = "Cite the selected event's evidence (a fact needs this)"
	_cite_toggle.focus_mode = Control.FOCUS_ALL
	_cite_toggle.custom_minimum_size = Vector2(0, SocTokens.MIN_TARGET)
	_cite_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.body.add_child(_cite_toggle)
	_notes_card = SocCard.create("")
	notes.body.add_child(_notes_card)
	_page.add_child(UiKit.button("Open case management", func() -> void: go_to(&"cases")))


func refresh() -> void:
	_syncing = true
	_source_filter.set_value(model.filter_source)
	_result_filter.set_value(model.filter_result)
	if _text_filter.text != model.filter_text:
		_text_filter.text = model.filter_text
	_syncing = false
	_refresh_table()
	_refresh_detail()
	_refresh_notes()


func default_focus() -> Control:
	return _source_filter


func _set_filters(source: String, outcome: String, text: String) -> void:
	if _syncing:
		return
	model.filter_source = source
	model.filter_result = outcome
	model.filter_text = text
	_refresh_table()
	_refresh_detail()


func _clear_filters() -> void:
	_set_filters("all", "all", "")
	_source_filter.set_value("all")
	_result_filter.set_value("all")
	_text_filter.text = ""
	notify("Filters cleared.", "info")


func _refresh_table() -> void:
	var events: Array[EventRecord] = model.filter_events(model.filter_source, model.filter_result, model.filter_text)
	UiKit.clear_table(_table)
	var keep: TreeItem = null
	for event: EventRecord in events:
		var marker: String = " *" if model.is_collected(event.id) else ""
		var item: TreeItem = UiKit.add_row(_table, PackedStringArray([EventRecord.clock_text(event.tick), event.display_id + marker, event.actor, event.source, event.result, SocModel.origin_label(event)]), event.id)
		if event.id == model.selected_event_id:
			keep = item
	if keep != null:
		keep.select(0)
	else:
		# A selection that the filters hide is dropped, so the detail panel never shows a row that is not listed.
		model.selected_event_id = ""
	var total: int = model.session.store.size()
	_count_label.text = "Showing %d of %d events.%s   * = collected as evidence" % [events.size(), total, "  No events match these filters." if events.is_empty() else ""]


func _on_row_selected() -> void:
	var event_id: Variant = UiKit.selected_metadata(_table)
	if typeof(event_id) != TYPE_STRING:
		return
	model.selected_event_id = event_id
	_refresh_detail()


func _refresh_detail() -> void:
	for child: Node in _detail_body.get_children():
		_detail_body.remove_child(child)
		child.queue_free()
	var event: EventRecord = model.session.store.get_event(model.selected_event_id)
	if event == null:
		_detail_body.add_child(UiKit.label("Select an event in the table to see its details.", &"SocMuted"))
		_collect_button.disabled = true
		_collect_button.text = "Collect as evidence"
		return
	_detail_body.add_child(UiKit.label("%s  %s" % [event.display_id, EventRecord.clock_text(event.tick)], &"SocHeading"))
	_detail_body.add_child(UiKit.label(event.detail, &""))
	_detail_body.add_child(UiKit.label("Account: %s\nSource: %s   Result: %s\nOrigin: %s\nDevice: %s" % [event.actor, event.source, event.result, event.ip_label, event.device], &"SocMono"))
	var user: Dictionary = model.user_context(event.actor)
	if not user.is_empty():
		_detail_body.add_child(UiKit.label("User: %s, %s.\nUsual hours %s on %s from %s." % [user["name"], user["role"], user["normal_hours"], user["normal_device"], user["normal_sources"]], &"SocMuted"))
	var host: Dictionary = model.host_context(event.device)
	if not host.is_empty():
		_detail_body.add_child(UiKit.label("Host %s (%s), owner %s. %s" % [host["name"], host["kind"], host["owner"], host["notes"]], &"SocMuted"))
	_detail_body.add_child(UiKit.label("MFA", &"SocHeading"))
	_detail_body.add_child(UiKit.label(model.mfa_summary(event.actor), &"SocMuted"))
	var evidence_id: String = model.evidence_id_for(event.id)
	_collect_button.disabled = not evidence_id.is_empty()
	_collect_button.text = "Collected as %s" % evidence_id if not evidence_id.is_empty() else "Collect %s as evidence" % event.display_id


func _on_collect_pressed() -> void:
	if model.selected_event_id.is_empty():
		return
	model.collect_evidence(model.selected_event_id)
	_refresh_table()
	_refresh_detail()
	if _collect_button.disabled:
		_table.grab_focus()


func _on_add_note() -> void:
	var cited: PackedStringArray = PackedStringArray()
	if _cite_toggle.button_pressed:
		var evidence_id: String = model.evidence_id_for(model.selected_event_id)
		if evidence_id.is_empty():
			notify("Collect the selected event first, then cite it.", "error")
			return
		cited.append(evidence_id)
	var result: ActionResult = model.add_note(_note_kind.value(), _note_input.text, cited)
	if result.ok:
		_note_input.text = ""


func _refresh_notes() -> void:
	_notes_card.clear_body()
	var entries: Array[CaseEntry] = model.session.case_file.entries()
	if entries.is_empty():
		_notes_card.body.add_child(UiKit.label("No notes yet.", &"SocMuted"))
	for entry: CaseEntry in entries:
		var cites: String = " (cites %s)" % ", ".join(entry.evidence_ids) if not entry.evidence_ids.is_empty() else ""
		_notes_card.body.add_child(UiKit.label("[%s] %s  %s%s" % [entry.kind.to_upper(), entry.id, entry.text, cites], &""))
