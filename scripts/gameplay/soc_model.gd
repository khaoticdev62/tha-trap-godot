class_name SocModel
extends RefCounted
## Everything the SOC screens show and do, with no UI in it. Screens read from
## this object and call its methods; it calls LabSession (the only thing that
## changes the case) and ProgressService (checkpointing). Nothing here touches
## the scene tree, the filesystem or the network, so it runs the same headless.
##
## Dashboard data source (documented simulation source): alerts are produced by
## DETECTION_RULES applied to the synthetic events of the running LabSession.
## Rules look only at fields a real SIEM would see (source, result, origin). They
## never read an event's tags or its `canonical` flag, which would give away the
## answer.
##
## Simulated case lifecycle (status, preserved snapshot, audit history) lives in
## this object for the current session only and is not saved yet; see
## docs/architecture/M8_UI_SYSTEM.md, open item OI-3.

signal changed
## Something the player should be told, for the shell's notification area.
signal notified(message: String, level: String)

const LAB_KEY: String = "lab_001"
const MISSION_ID: String = "mission_lab_001"
const LEARNING_ID: String = "mission_lab_001_learning"
const MAX_FILTER_TEXT: int = 60
const MAX_AUDIT_ENTRIES: int = 200
const STREAM_LIMIT: int = 12
const EXTERNAL_PREFIX: String = "ext-"

## Detection rules for the dashboard. `external` rules fire only for events
## whose origin label starts with EXTERNAL_PREFIX.
const DETECTION_RULES: Array[Dictionary] = [
	{"id": "mfa_change", "title": "MFA enrollment change", "severity": "high", "source": "mfa", "result": "", "external": false},
	{"id": "external_portal_access", "title": "Member data access from outside the network", "severity": "high", "source": "app", "result": "", "external": true},
	{"id": "external_signin", "title": "Sign-in from outside the network", "severity": "medium", "source": "auth", "result": "success", "external": true},
	{"id": "user_report", "title": "User-reported activity", "severity": "medium", "source": "helpdesk", "result": "", "external": false},
	{"id": "failed_signin", "title": "Failed sign-in", "severity": "low", "source": "auth", "result": "failure", "external": false},
]

const CASE_STATUSES: Array[String] = ["new", "investigating", "escalated", "contained", "preserved", "recovered"]
const CASE_STATUS_LABELS: Dictionary = {
	"new": "New", "investigating": "Investigating", "escalated": "Escalated",
	"contained": "Contained (simulated)", "preserved": "Evidence preserved (simulated)", "recovered": "Recovered (simulated)",
}
const RESPONSE_ACTIONS: Array[String] = ["investigate", "escalate", "contain", "preserve", "recover"]
## Terminal commands that change the case; they are recorded in the audit history.
const CHANGING_COMMANDS: Array[String] = ["evidence add", "evidence remove", "case note", "case severity", "case scope", "case recommend", "case escalate", "case report", "hint"]
## The sample commands offered as buttons, so a controller can run them without typing.
const COMMAND_PALETTE: Array[String] = [
	"help",
	"assets list",
	"hosts show HOST-014",
	"logs search source=auth user=j.smith after=09:00",
	"timeline build CASE-001",
	"evidence list",
	"case show",
	"case report CASE-001",
]

var content: LabContent = null
var session: LabSession = null
var terminal: TerminalParser = null
var learning: Dictionary = {}
var case_status: String = "new"
var preserved_ref: String = ""
## Investigation view state, kept here so it survives moving between screens.
var filter_source: String = "all"
var filter_result: String = "all"
var filter_text: String = ""
var selected_event_id: String = ""
## Hints the player has asked for, oldest first.
var hint_log: PackedStringArray = PackedStringArray()
## Problems that stopped the model from opening. Empty means ready.
var errors: PackedStringArray = PackedStringArray()

var _progress: ProgressService = null
var _audit: Array[Dictionary] = []
var _audit_number: int = 0
var _answers: Dictionary = {}  # check id -> chosen option id (formative, session only)


## Opens the SOC for the running lab, resuming a saved attempt if there is one
## and starting a fresh one otherwise.
static func open(progress: ProgressService, loader: ContentLoader = null) -> SocModel:
	var model: SocModel = SocModel.new()
	model._progress = progress
	var content_loader: ContentLoader = loader if loader != null else ContentLoader.new(ContentCatalog.build_registry())
	model.content = LabContent.load_lab(content_loader, LAB_KEY)
	if not model.content.is_ready():
		model.errors.append_array(model.content.errors)
		return model
	var learning_result: ContentResult = content_loader.load_content(LEARNING_ID)
	if not learning_result.ok():
		model.errors.append_array(learning_result.errors)
		return model
	model.learning = learning_result.data
	var live: LabSession = progress.current_session
	if live == null or live.package.id != model.content.package.id:
		live = progress.resume_lab(model.content) if progress.has_active_lab() else null
	if live == null:
		live = progress.begin_lab(MISSION_ID, model.content)
	if live == null:
		model.errors.append("The lab could not be started.")
		return model
	model._attach(live)
	model._log("Opened", "%s on %s difficulty." % [CaseFile.CASE_ID, live.difficulty])
	return model


func is_ready() -> bool:
	return errors.is_empty() and session != null


func _attach(live: LabSession) -> void:
	session = live
	terminal = TerminalParser.new(live)
	live.evidence_changed.connect(_on_session_changed)
	live.case_changed.connect(_on_session_changed)
	live.session_reset.connect(_on_session_changed)
	if not live.ledger.all().is_empty() or not live.case_file.entries().is_empty():
		case_status = "investigating"


func _on_session_changed() -> void:
	if _progress != null:
		_progress.checkpoint_lab()
	changed.emit()


# --- dashboard ------------------------------------------------------------------

## One entry per alert: {event_id, display_id, time, actor, severity, rule_id, title, device}.
func alerts() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: EventRecord in session.store.all():
		var rule: Dictionary = _rule_for(event)
		if rule.is_empty():
			continue
		found.append({
			"event_id": event.id, "display_id": event.display_id, "time": EventRecord.clock_text(event.tick),
			"tick": event.tick, "actor": event.actor, "severity": rule["severity"], "rule_id": rule["id"],
			"title": rule["title"], "device": event.device,
		})
	return found


## Count of alerts per severity id; every severity is present.
func severity_counts() -> Dictionary:
	var counts: Dictionary = {}
	for severity: String in SocTokens.SEVERITIES:
		counts[severity] = 0
	for alert: Dictionary in alerts():
		counts[alert["severity"]] = int(counts[alert["severity"]]) + 1
	return counts


## Incident queue: one row per account with alerts, worst first. The reported
## account is the case (CASE-001); the others are triage items.
## Row: {id, title, severity, status, alerts, actor, is_case}.
func incident_queue() -> Array[Dictionary]:
	var by_actor: Dictionary = {}
	for alert: Dictionary in alerts():
		var actor: String = str(alert["actor"])
		if not by_actor.has(actor):
			by_actor[actor] = {"count": 0, "severity": "info"}
		var row: Dictionary = by_actor[actor]
		row["count"] = int(row["count"]) + 1
		if SocTokens.severity_rank(str(alert["severity"])) < SocTokens.severity_rank(str(row["severity"])):
			row["severity"] = alert["severity"]
	var queue: Array[Dictionary] = []
	var actors: Array = by_actor.keys()
	actors.sort()
	var triage_number: int = 0
	for actor: String in actors:
		var row: Dictionary = by_actor[actor]
		var is_case: bool = actor == case_account()
		var severity: String = str(row["severity"])
		if is_case and session.case_file.severity != "unset":
			severity = session.case_file.severity
		if not is_case:
			triage_number += 1
		queue.append({
			"id": CaseFile.CASE_ID if is_case else "TRIAGE-%02d" % triage_number,
			"title": case_title() if is_case else "Review activity for %s" % actor,
			"severity": severity, "status": status_short() if is_case else "Not started",
			"alerts": int(row["count"]), "actor": actor, "is_case": is_case,
		})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["is_case"] != b["is_case"]:
			return a["is_case"]
		var rank_a: int = SocTokens.severity_rank(str(a["severity"]))
		var rank_b: int = SocTokens.severity_rank(str(b["severity"]))
		return rank_a < rank_b if rank_a != rank_b else str(a["id"]) < str(b["id"]))
	return queue


## Newest-first slice of the synthetic event stream.
func event_stream(limit: int = STREAM_LIMIT) -> Array[EventRecord]:
	var everything: Array[EventRecord] = session.store.all()
	everything.reverse()
	return everything.slice(0, clampi(limit, 0, 200))


## Network overview rows: {id, name, kind, owner, alerts, in_scope, status}.
func network_overview() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var all_alerts: Array[Dictionary] = alerts()
	for asset: Dictionary in session.package.assets:
		var asset_id: String = str(asset.get("id", ""))
		var asset_name: String = str(asset.get("name", ""))
		var count: int = 0
		for alert: Dictionary in all_alerts:
			if str(alert["device"]).to_lower() == asset_name.to_lower() or (asset_id == "member_portal" and alert["rule_id"] == "external_portal_access") or (asset_id == "sso_main" and alert["rule_id"] in ["mfa_change", "external_signin", "failed_signin"]):
				count += 1
		rows.append({
			"id": asset_id, "name": asset_name, "kind": str(asset.get("kind", "")).replace("_", " "),
			"owner": str(asset.get("owner", "")), "alerts": count,
			"in_scope": session.case_file.scope.has(asset_id),
			"status": "Alerting" if count > 0 else "Quiet",
		})
	return rows


func case_account() -> String:
	return str(learning.get("case_account", ""))


func case_title() -> String:
	return str(learning.get("case_title", "Case"))


func status_label() -> String:
	return str(CASE_STATUS_LABELS.get(case_status, case_status))


## One word, for table cells where the long label would not fit.
func status_short() -> String:
	return case_status.capitalize()


## "External" for a source outside the network, "Internal" inside it, otherwise
## "n/a" (for example a help-desk ticket). Plain words, so it never relies on colour.
static func origin_label(event: EventRecord) -> String:
	if event.ip_label.begins_with(EXTERNAL_PREFIX):
		return "External"
	if event.ip_label.begins_with("int-"):
		return "Internal"
	return "n/a"


func mission_state() -> String:
	var progress_state: String = _progress.recorded_state(MISSION_ID) if _progress != null else ""
	return progress_state if not progress_state.is_empty() else "in_progress"


# --- investigation ------------------------------------------------------------------

## Events matching the filters, in time order. `source` and `result` are "all"
## or a known value; `text` matches account, event id, device, origin and detail.
## Unknown filter values match nothing rather than everything.
func filter_events(source: String, result: String, text: String) -> Array[EventRecord]:
	var needle: String = text.strip_edges().to_lower().left(MAX_FILTER_TEXT)
	var matches: Array[EventRecord] = []
	if (source != "all" and not EventRecord.SOURCES.has(source)) or (result != "all" and not EventRecord.RESULTS.has(result)):
		return matches
	for event: EventRecord in session.store.all():
		if source != "all" and event.source != source:
			continue
		if result != "all" and event.result != result:
			continue
		if not needle.is_empty() and not _haystack(event).contains(needle):
			continue
		matches.append(event)
	return matches


func _haystack(event: EventRecord) -> String:
	return ("%s %s %s %s %s %s" % [event.display_id, event.actor, event.device, event.ip_label, event.detail, event.source]).to_lower()


## Account context for the selected event, or {} if the account is not a known identity.
func user_context(account: String) -> Dictionary:
	for identity: Dictionary in session.package.identities:
		if str(identity.get("account", "")).to_lower() == account.to_lower():
			return {
				"account": str(identity.get("account", "")), "name": str(identity.get("display_name", "")),
				"role": str(identity.get("role", "")),
				"normal_hours": "%s to %s" % [EventRecord.clock_text(int(identity.get("normal_start_tick", 0))), EventRecord.clock_text(int(identity.get("normal_end_tick", 0)))],
				"normal_device": str(identity.get("normal_device", "")),
				"normal_sources": ", ".join(PackedStringArray(identity.get("normal_sources", []))),
			}
	return {}


## Host context for a device name, or {} if it is not a known asset.
func host_context(device: String) -> Dictionary:
	for asset: Dictionary in session.package.assets:
		if str(asset.get("name", "")).to_lower() == device.to_lower():
			return {"name": str(asset.get("name", "")), "kind": str(asset.get("kind", "")).replace("_", " "), "owner": str(asset.get("owner", "")), "notes": str(asset.get("notes", ""))}
	return {}


## Plain-language MFA picture for an account, from its MFA-source events.
func mfa_summary(account: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for event: EventRecord in session.store.all():
		if event.source == "mfa" and event.actor.to_lower() == account.to_lower():
			lines.append("%s  %s  %s (%s)" % [EventRecord.clock_text(event.tick), event.result.capitalize(), event.detail, event.display_id])
	if lines.is_empty():
		return "No MFA events recorded for this account."
	lines.append("No MFA completion is recorded. Enrollment alone does not show who approved it.")
	return "\n".join(lines)


func is_collected(event_id: String) -> bool:
	for record: EvidenceRecord in session.ledger.all():
		if record.event_ids.has(event_id):
			return true
	return false


## Evidence id that holds this event, or "".
func evidence_id_for(event_id: String) -> String:
	for record: EvidenceRecord in session.ledger.all():
		if record.event_ids.has(event_id):
			return record.id
	return ""


func collect_evidence(event_id: String, note: String = "") -> ActionResult:
	var event: EventRecord = session.store.get_event(event_id)
	if event == null:
		return _failed("That event is not in this case.")
	var result: ActionResult = session.add_evidence(PackedStringArray([event.display_id]), note)
	if result.ok and result.changed:
		_log("Evidence added", "%s collected as %s." % [event.display_id, result.id])
		_advance_to("investigating")
	return _report(result)


func remove_evidence(evidence_id: String) -> ActionResult:
	var result: ActionResult = session.remove_evidence(evidence_id)
	if result.ok:
		_log("Evidence removed", result.message)
	return _report(result)


func add_note(kind: String, text: String, evidence_ids: PackedStringArray = PackedStringArray()) -> ActionResult:
	var result: ActionResult = session.add_case_entry(kind, text, evidence_ids)
	if result.ok:
		_log("Note added", "%s recorded as a %s." % [result.id, kind])
		_advance_to("investigating")
	return _report(result)


func remove_note(entry_id: String) -> ActionResult:
	var result: ActionResult = session.remove_case_entry(entry_id)
	if result.ok:
		_log("Note removed", result.message)
	return _report(result)


# --- case management --------------------------------------------------------------

func set_severity(level: String) -> ActionResult:
	var result: ActionResult = session.set_severity(level)
	if result.ok and result.changed:
		_log("Severity set", level)
	return _report(result)


## Adds the asset to the scope, or removes it if it is already there.
func toggle_scope(asset_id: String) -> ActionResult:
	var wanted: PackedStringArray = PackedStringArray()
	var removing: bool = session.case_file.scope.has(asset_id)
	for existing: String in session.case_file.scope:
		if existing != asset_id:
			wanted.append(existing)
	if not removing:
		wanted.append(asset_id)
	if wanted.is_empty():
		return _failed("Keep at least one asset in scope. Pick another before removing this one.")
	var result: ActionResult = session.set_scope(wanted)
	if result.ok:
		_log("Scope changed", "%s %s." % [asset_id, "removed" if removing else "added"])
	return _report(result)


## The five response actions. `option_id` is needed for escalate and contain.
## Everything here changes only the simulated case; nothing real is touched.
func apply_response(action: String, option_id: String = "") -> ActionResult:
	match action:
		"investigate":
			_advance_to("investigating", true)
			_log("Response: investigate", "Investigation under way.")
			return _report(ActionResult.success(CaseFile.CASE_ID, "Case marked as under investigation."))
		"escalate":
			var escalated: ActionResult = session.set_escalation(option_id)
			if escalated.ok:
				if option_id != "none":
					_advance_to("escalated", true)
				_log("Response: escalate", "Escalation set to %s." % option_id)
			return _report(escalated)
		"contain":
			var contained: ActionResult = session.set_recommendation(option_id)
			if contained.ok:
				if option_id != "monitor_only":
					_advance_to("contained", true)
				_log("Response: contain", "Containment choice set to %s (simulated)." % option_id)
			return _report(contained)
		"preserve":
			if session.ledger.size() == 0:
				return _failed("Collect at least one piece of evidence before preserving the case.")
			preserved_ref = session.state_hash().left(12)
			_advance_to("preserved", true)
			_log("Response: preserve", "Evidence snapshot %s recorded (simulated)." % preserved_ref)
			changed.emit()
			return _report(ActionResult.success(preserved_ref, "Evidence preserved as snapshot %s." % preserved_ref))
		"recover":
			if session.case_file.recommendation.is_empty() or session.case_file.recommendation == "monitor_only":
				return _failed("Choose a containment response first. Recovery follows containment.")
			_advance_to("recovered", true)
			_log("Response: recover", "Recovery steps recorded (simulated).")
			changed.emit()
			return _report(ActionResult.success(CaseFile.CASE_ID, "Recovery recorded in the simulated case."))
	return _failed("That is not a response action.")


func audit_history() -> Array[Dictionary]:
	return _audit.duplicate()


## One line each for the risk and impact panel: what could be at stake, from
## the assets in scope.
func impact_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if session.case_file.severity == "unset":
		lines.append("Severity not set yet. Set it once you know what the evidence shows.")
	else:
		lines.append("Severity: %s." % SocTokens.severity_text(session.case_file.severity))
	if session.case_file.scope.is_empty():
		lines.append("No assets in scope yet. Choose the systems you think are affected.")
	for asset: Dictionary in session.package.assets:
		if session.case_file.scope.has(str(asset.get("id", ""))):
			lines.append("%s: %s" % [asset.get("name", ""), asset.get("notes", "")])
	return lines


# --- terminal ---------------------------------------------------------------------

## The banner spec 05 §5 requires the lab shell to always show.
static func terminal_banner() -> String:
	return TerminalCommands.BANNER


## Runs one line through the allowlisted parser. Output is plain text lines.
func run_command(line: String) -> TerminalResult:
	var result: TerminalResult = terminal.run(line)
	if result.ok and CHANGING_COMMANDS.has(result.command):
		_log("Terminal", result.command)
	return result


# --- learning --------------------------------------------------------------------

## Review of the current case. Changes nothing.
func assessment() -> AssessmentResult:
	return session.assess()


## Per-objective progress for the mission and mastery screens:
## {id, text, criterion_id, title, status, points, max_points}.
func objectives() -> Array[Dictionary]:
	var review: AssessmentResult = assessment()
	var rows: Array[Dictionary] = []
	for objective: Dictionary in learning.get("objectives", []):
		var row: Dictionary = {"id": str(objective.get("id", "")), "text": str(objective.get("text", "")), "criterion_id": str(objective.get("criterion_id", "")), "title": str(objective.get("text", "")), "status": "unmet", "points": 0, "max_points": 0}
		if review != null:
			for criterion: Dictionary in review.criteria:
				if criterion["id"] == row["criterion_id"]:
					row["title"] = criterion["title"]
					row["status"] = criterion["status"]
					row["points"] = criterion["points"]
					row["max_points"] = criterion["max_points"]
		rows.append(row)
	return rows


## 0.0 to 1.0, from the rubric's points. Knowledge checks never add to this.
func mastery_fraction() -> float:
	var review: AssessmentResult = assessment()
	if review == null or review.max_points <= 0:
		return 0.0
	return clampf(float(review.total) / float(review.max_points), 0.0, 1.0)


func request_hint() -> ActionResult:
	var result: ActionResult = session.request_hint()
	if result.ok and result.changed:
		_log("Hint", result.id)
		hint_log.append(result.message)
	return _report(result)


## Records a formative answer and returns {correct, feedback}. Unknown ids give
## an empty dictionary. Answers are for feedback only and never change the score.
func answer_check(check_id: String, option_id: String) -> Dictionary:
	for check: Dictionary in learning.get("knowledge_checks", []):
		if str(check.get("id", "")) != check_id:
			continue
		for option: Dictionary in check.get("options", []):
			if str(option.get("id", "")) == option_id:
				_answers[check_id] = option_id
				return {"correct": option.get("correct", false) == true, "feedback": str(option.get("feedback", ""))}
	return {}


func answered(check_id: String) -> String:
	return str(_answers.get(check_id, ""))


# --- internals ----------------------------------------------------------------------

func _rule_for(event: EventRecord) -> Dictionary:
	var external: bool = event.ip_label.begins_with(EXTERNAL_PREFIX)
	for rule: Dictionary in DETECTION_RULES:
		if str(rule["source"]) != event.source:
			continue
		if not str(rule["result"]).is_empty() and str(rule["result"]) != event.result:
			continue
		if rule["external"] == true and not external:
			continue
		return rule
	return {}


## Moves the status forward only (never back), unless `force` sets it directly.
func _advance_to(status: String, force: bool = false) -> void:
	if force or CASE_STATUSES.find(status) > CASE_STATUSES.find(case_status):
		case_status = status


func _log(action: String, detail: String) -> void:
	_audit_number += 1
	_audit.append({"number": _audit_number, "action": action, "detail": detail})
	if _audit.size() > MAX_AUDIT_ENTRIES:
		_audit.remove_at(0)


func _failed(message: String) -> ActionResult:
	return _report(ActionResult.failure(message))


## Sends the outcome to the notification area and returns it unchanged.
func _report(result: ActionResult) -> ActionResult:
	if not result.message.is_empty():
		notified.emit(result.message, "success" if result.ok else "error")
	changed.emit()
	return result
