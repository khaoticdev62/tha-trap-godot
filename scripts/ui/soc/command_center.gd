extends SocScreen
## SCREEN 02: SOC Command Center. Mission status, alert counters, the incident
## queue, the synthetic event stream, the network overview, analyst activity and
## current objectives, all read from SocModel.

const RECENT_ACTIVITY: int = 6

var _mission_card: SocCard
var _counter_row: HFlowContainer
var _counter_cards: Dictionary = {}  # severity -> Label
var _queue: Tree
var _stream: Tree
var _network: Tree
var _objectives_card: SocCard
var _activity_card: SocCard
var _open_case_button: Button


func screen_id() -> StringName:
	return &"command_center"


func screen_title() -> String:
	return "SOC Command Center"


func screen_context() -> String:
	return "New Meridian security operations. Synthetic training data."


func build() -> void:
	_page.add_child(UiKit.label("SYNTHETIC TRAINING DATA: nothing on this screen is real.", &"SocCaption"))
	var top: HFlowContainer = UiKit.flow()
	_page.add_child(top)
	_mission_card = SocCard.create("Mission status", &"ElevatedPanel")
	_mission_card.custom_minimum_size = Vector2(340, 0)
	top.add_child(_mission_card)
	var counters: SocCard = SocCard.create("Alert severity")
	counters.custom_minimum_size = Vector2(640, 0)
	top.add_child(counters)
	_counter_row = UiKit.flow(SocTokens.SPACE_S)
	counters.body.add_child(_counter_row)
	for severity: String in SocTokens.SEVERITIES:
		_counter_row.add_child(_build_counter(severity))

	var quick: HFlowContainer = UiKit.flow(SocTokens.SPACE_S)
	_page.add_child(quick)
	_open_case_button = UiKit.button("Open investigation", func() -> void: go_to(&"investigation"), &"PrimaryButton")
	quick.add_child(_open_case_button)
	quick.add_child(UiKit.button("Case management", func() -> void: go_to(&"cases")))
	quick.add_child(UiKit.button("Terminal", func() -> void: go_to(&"terminal")))
	quick.add_child(UiKit.button("Mission and learning", func() -> void: go_to(&"mission")))

	var middle: HFlowContainer = UiKit.flow()
	_page.add_child(middle)
	var queue_card: SocCard = SocCard.create("Incident queue", &"", true)
	queue_card.custom_minimum_size = Vector2(640, 0)
	_queue = UiKit.table([["Case", 114], ["Title", 0], ["Severity", 130], ["Status", 140], ["Alerts", 84]], 150.0)
	_queue.item_activated.connect(_on_queue_activated)
	queue_card.body.add_child(_queue)
	queue_card.body.add_child(UiKit.label("Press Enter or A on a row to open it in the investigation view.", &"SocCaption"))
	middle.add_child(queue_card)
	_objectives_card = SocCard.create("Current objectives", &"", true)
	_objectives_card.custom_minimum_size = Vector2(340, 0)
	middle.add_child(_objectives_card)

	var bottom: HFlowContainer = UiKit.flow()
	_page.add_child(bottom)
	var stream_card: SocCard = SocCard.create("Security event stream (newest first)", &"", true)
	stream_card.custom_minimum_size = Vector2(620, 0)
	_stream = UiKit.table([["Time", 76], ["Event", 116], ["User", 130], ["Source", 90], ["Result", 0]], 220.0)
	stream_card.body.add_child(_stream)
	bottom.add_child(stream_card)
	var side: VBoxContainer = UiKit.vbox(SocTokens.SPACE_M)
	side.custom_minimum_size = Vector2(340, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(side)
	var network_card: SocCard = SocCard.create("New Meridian network overview", &"", true)
	_network = UiKit.table([["Asset", 0], ["Alerts", 84], ["Status", 92]], 130.0)
	network_card.body.add_child(_network)
	side.add_child(network_card)
	_activity_card = SocCard.create("Analyst activity", &"", true)
	side.add_child(_activity_card)


func refresh() -> void:
	_refresh_mission()
	_refresh_counters()
	_refresh_queue()
	_refresh_objectives()
	_refresh_stream()
	_refresh_network()
	_refresh_activity()


func default_focus() -> Control:
	return _open_case_button


func _build_counter(severity: String) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	tile.theme_type_variation = &"InsetPanel"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(110, 0)
	var column: VBoxContainer = UiKit.vbox(SocTokens.SPACE_XS)
	tile.add_child(column)
	var number: Label = UiKit.label("0", &"SocDisplay", false)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var badge: PanelContainer = UiKit.severity_badge(severity)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(badge)
	_counter_cards[severity] = number
	tile.tooltip_text = "%s alerts raised by the detection rules." % SocTokens.SEVERITY_LABELS[severity].capitalize()
	return tile


func _refresh_mission() -> void:
	_mission_card.clear_body()
	var body: VBoxContainer = _mission_card.body
	body.add_child(UiKit.label(str(model.learning.get("case_title", "")), &"SocTitle"))
	body.add_child(UiKit.label("%s  |  %s difficulty" % [CaseFile.CASE_ID, model.session.difficulty.capitalize()], &"SocMono"))
	var row: HBoxContainer = UiKit.hbox()
	row.add_child(UiKit.status_badge(model.status_label(), "info" if model.case_status != "recovered" else "ok"))
	body.add_child(row)
	var done: int = 0
	var rows: Array[Dictionary] = model.objectives()
	for objective: Dictionary in rows:
		if objective["status"] == "met":
			done += 1
	body.add_child(UiKit.progress(float(done) / maxf(float(rows.size()), 1.0), "Objectives %d/%d" % [done, rows.size()]))
	body.add_child(UiKit.label("Evidence collected: %d   Hints used: %d" % [model.session.ledger.size(), model.hint_log.size()], &"SocMuted"))


func _refresh_counters() -> void:
	var counts: Dictionary = model.severity_counts()
	for severity: String in _counter_cards:
		(_counter_cards[severity] as Label).text = str(counts[severity])


func _refresh_queue() -> void:
	UiKit.clear_table(_queue)
	for incident: Dictionary in model.incident_queue():
		UiKit.add_row(_queue, PackedStringArray([incident["id"], incident["title"], SocTokens.severity_text(incident["severity"]), incident["status"], str(incident["alerts"])]), incident)


func _refresh_objectives() -> void:
	_objectives_card.clear_body()
	for objective: Dictionary in model.objectives():
		var marker: String = "[x]" if objective["status"] == "met" else ("[~]" if objective["status"] == "partial" else "[ ]")
		var line: Label = UiKit.label("%s %s" % [marker, objective["text"]], &"")
		line.tooltip_text = "Status: %s" % str(objective["status"]).capitalize()
		_objectives_card.body.add_child(line)
	_objectives_card.body.add_child(UiKit.label("[x] done   [~] partly done   [ ] not yet", &"SocCaption"))


func _refresh_stream() -> void:
	UiKit.clear_table(_stream)
	for event: EventRecord in model.event_stream():
		UiKit.add_row(_stream, PackedStringArray([EventRecord.clock_text(event.tick), event.display_id, event.actor, event.source, event.result]), event.id)


func _refresh_network() -> void:
	UiKit.clear_table(_network)
	for asset: Dictionary in model.network_overview():
		var label: String = "%s (%s)%s" % [asset["name"], asset["kind"], " [in scope]" if asset["in_scope"] else ""]
		UiKit.add_row(_network, PackedStringArray([label, str(asset["alerts"]), asset["status"]]), asset["id"])


func _refresh_activity() -> void:
	_activity_card.clear_body()
	var history: Array[Dictionary] = model.audit_history()
	if history.is_empty():
		_activity_card.body.add_child(UiKit.label("No analyst activity yet.", &"SocMuted"))
		return
	for entry: Dictionary in history.slice(maxi(history.size() - RECENT_ACTIVITY, 0)):
		_activity_card.body.add_child(UiKit.label("#%03d %s: %s" % [entry["number"], entry["action"], entry["detail"]], &"SocMuted"))


func _on_queue_activated() -> void:
	var incident: Variant = UiKit.selected_metadata(_queue)
	if typeof(incident) != TYPE_DICTIONARY:
		return
	model.filter_source = "all"
	model.filter_result = "all"
	model.filter_text = str((incident as Dictionary)["actor"])
	model.selected_event_id = ""
	go_to(&"investigation")
