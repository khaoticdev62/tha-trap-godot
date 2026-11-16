extends TestCase
## SocModel: the logic behind the SOC screens. Dashboard binding, event
## filtering, evidence, the five response actions, the terminal wrapper, learning
## feedback, and save/resume through ProgressService. No UI is created here.

var _progress: ProgressService
var _model: SocModel


func before_each() -> void:
	_progress = ProgressService.new()
	_model = SocModel.open(_progress)


func after_each() -> void:
	_progress.free()


func test_model_opens_and_starts_a_lab() -> void:
	check(_model.is_ready(), "model is ready: %s" % ", ".join(_model.errors))
	check(_progress.has_active_lab(), "opening the SOC starts the mission in progress")
	check_eq(_progress.active_mission_id(), SocModel.MISSION_ID, "the active mission is LAB-001")
	check_eq(_model.case_status, "new", "a fresh case is new")
	check_eq(_model.case_account(), "j.smith", "the case account comes from the learning document")


func test_opening_twice_reuses_the_running_session() -> void:
	var second: SocModel = SocModel.open(_progress)
	check(second.session == _model.session, "the same live session is reused, not restarted")


func test_dashboard_counters_come_from_detection_rules() -> void:
	var counts: Dictionary = _model.severity_counts()
	for severity: String in SocTokens.SEVERITIES:
		check(counts.has(severity), "counter present for %s" % severity)
	check(int(counts["high"]) >= 2, "MFA change and external portal access raise high alerts")
	check(int(counts["medium"]) >= 2, "the external sign-in and the help-desk report raise medium alerts")
	check(int(counts["low"]) >= 2, "the failed sign-ins raise low alerts")
	var total: int = 0
	for severity: String in counts:
		total += int(counts[severity])
	check_eq(total, _model.alerts().size(), "counters add up to the alert list")


func test_alerts_never_read_answer_flags() -> void:
	var alerted: PackedStringArray = PackedStringArray()
	for alert: Dictionary in _model.alerts():
		alerted.append(alert["event_id"])
	check(not alerted.has("evt_007"), "a normal internal baseline sign-in raises no alert")
	var source: String = FileAccess.get_file_as_string("res://scripts/gameplay/soc_model.gd")
	check(not source.contains("event.tags") and not source.contains(".canonical"), "detection never reads tags or the canonical flag")


func test_incident_queue_puts_the_case_first() -> void:
	var queue: Array[Dictionary] = _model.incident_queue()
	check(not queue.is_empty(), "there is at least one incident")
	check_eq(queue[0]["id"], CaseFile.CASE_ID, "CASE-001 leads the queue")
	check(queue[0]["is_case"] == true, "and is marked as the case")
	_model.set_severity("high")
	check_eq(_model.incident_queue()[0]["severity"], "high", "the case row shows the severity the analyst set")


func test_event_stream_is_newest_first_and_bounded() -> void:
	var stream: Array[EventRecord] = _model.event_stream(5)
	check(stream.size() <= 5, "stream respects its limit")
	for index: int in range(1, stream.size()):
		check(stream[index - 1].tick >= stream[index].tick, "newest first")
	check_eq(_model.event_stream(-3).size(), 0, "a negative limit gives nothing")


func test_network_overview_marks_scope_and_alerts() -> void:
	_model.toggle_scope("host_014")
	var found: bool = false
	for row: Dictionary in _model.network_overview():
		if row["id"] == "host_014":
			found = true
			check(row["in_scope"] == true, "host_014 shows as in scope")
	check(found, "host_014 is listed")


func test_filter_events_by_source_result_and_text() -> void:
	var everything: int = _model.filter_events("all", "all", "").size()
	check_eq(everything, _model.session.store.size(), "no filters shows every event")
	for event: EventRecord in _model.filter_events("mfa", "all", ""):
		check_eq(event.source, "mfa", "source filter keeps only mfa")
	for event: EventRecord in _model.filter_events("auth", "failure", ""):
		check(event.source == "auth" and event.result == "failure", "combined filters both apply")
	var smith: Array[EventRecord] = _model.filter_events("all", "all", "  J.SMITH ")
	check(not smith.is_empty() and smith.size() < everything, "text filter is trimmed and case-insensitive")
	check(_model.filter_events("all", "all", "zzz-no-such-text").is_empty(), "no match gives an empty list, not everything")


func test_filter_rejects_unknown_values_and_long_text() -> void:
	check(_model.filter_events("shell", "all", "").is_empty(), "an unknown source matches nothing")
	check(_model.filter_events("all", "maybe", "").is_empty(), "an unknown result matches nothing")
	var long_text: String = "x".repeat(5000)
	check(_model.filter_events("all", "all", long_text).is_empty(), "very long text is clipped and does not crash")
	check(_model.filter_events("all", "all", "[b]<script>'; DROP TABLE").is_empty(), "markup and SQL-like text are plain text")


func test_user_host_and_mfa_context() -> void:
	var user: Dictionary = _model.user_context("J.Smith")
	check_eq(user.get("name", ""), "J. Smith", "user context finds the identity case-insensitively")
	check(_model.user_context("nobody").is_empty(), "unknown accounts give no context")
	check_eq(_model.host_context("host-014").get("owner", ""), "j.smith", "host context finds HOST-014")
	check(_model.host_context("browser-unknown").is_empty(), "an unknown device gives no context")
	check(_model.mfa_summary("j.smith").contains("EVT-004"), "MFA summary cites the enrollment event")
	check(_model.mfa_summary("r.alvarez").begins_with("No MFA events"), "an account without MFA events says so")


func test_collect_evidence_updates_state_and_checkpoints() -> void:
	var result: ActionResult = _model.collect_evidence("evt_004")
	check(result.ok and result.changed, "collecting a real event works")
	check(_model.is_collected("evt_004"), "it is now collected")
	check(not _model.evidence_id_for("evt_004").is_empty(), "and has an evidence id")
	check_eq(_model.case_status, "investigating", "collecting evidence starts the investigation")
	var again: ActionResult = _model.collect_evidence("evt_004")
	check(again.ok and not again.changed, "collecting twice changes nothing")
	check(not _model.collect_evidence("evt_999").ok, "an unknown event is refused")
	check(not _model.collect_evidence("").ok, "an empty id is refused")
	var snapshot: Dictionary = _progress.to_dict()["active_lab"]["snapshot"]
	check(str(snapshot["player"]["evidence"]).contains("evt_004"), "the change is checkpointed into saved progress")


func test_status_only_moves_forward_from_evidence_and_notes() -> void:
	_model.collect_evidence("evt_004")
	_model.apply_response("contain", "verify_then_protect")
	check_eq(_model.case_status, "contained", "contain moves the status")
	_model.collect_evidence("evt_005")
	check_eq(_model.case_status, "contained", "later evidence does not move the status back")


func test_notes_require_evidence_for_facts() -> void:
	check(not _model.add_note("fact", "Login came from an unusual place.").ok, "a fact without evidence is refused")
	_model.collect_evidence("evt_003")
	var evidence_id: String = _model.evidence_id_for("evt_003")
	check(_model.add_note("fact", "A sign-in succeeded after two failures.", PackedStringArray([evidence_id])).ok, "a cited fact is accepted")
	check(_model.add_note("hypothesis", "The password may have been guessed.").ok, "a hypothesis needs no evidence")
	check(not _model.add_note("fact", "x", PackedStringArray(["ev_404"])).ok, "citing missing evidence is refused")
	check(not _model.add_note("opinion", "text").ok, "an unknown kind is refused")
	check(not _model.add_note("unknown", "line one\nline two").ok, "control characters are refused")


func test_response_actions_change_only_the_simulated_case() -> void:
	check(not _model.apply_response("preserve").ok, "preserving needs evidence first")
	check(not _model.apply_response("recover").ok, "recovery needs a containment choice first")
	check(not _model.apply_response("unknown_action").ok, "an unknown action is refused")
	check(_model.apply_response("investigate").ok, "investigate works")
	check_eq(_model.case_status, "investigating", "status follows")
	check(_model.apply_response("escalate", "soc_lead").ok, "escalate to the SOC lead works")
	check_eq(_model.session.case_file.escalation, "soc_lead", "the escalation is stored on the case")
	check_eq(_model.case_status, "escalated", "status follows")
	check(not _model.apply_response("escalate", "the_internet").ok, "an escalation target that is not offered is refused")
	_model.collect_evidence("evt_004")
	check(_model.apply_response("preserve").ok, "preserve works once evidence exists")
	check(not _model.preserved_ref.is_empty(), "a snapshot reference is recorded")
	check_eq(_model.case_status, "preserved", "status follows")
	check(not _model.apply_response("contain", "format_all_drives").ok, "a response that is not offered is refused")
	check(_model.apply_response("contain", "monitor_only").ok, "choosing to monitor is allowed")
	check(not _model.apply_response("recover").ok, "monitoring alone does not allow recovery")
	check(_model.apply_response("contain", "verify_then_protect").ok, "contain works")
	check(_model.apply_response("recover").ok, "recover works after containment")
	check_eq(_model.case_status, "recovered", "status follows")
	check(_model.audit_history().size() >= 6, "every action is in the audit history")


func test_scope_toggle_keeps_at_least_one_asset() -> void:
	check(_model.toggle_scope("host_014").ok, "add an asset")
	check(_model.toggle_scope("member_portal").ok, "add another")
	check(_model.toggle_scope("host_014").ok, "remove one")
	check(not _model.toggle_scope("member_portal").ok, "removing the last asset is refused")
	check(not _model.toggle_scope("not_an_asset").ok, "an unknown asset is refused")
	check_eq(",".join(_model.session.case_file.scope), "member_portal", "scope is what is left")


func test_terminal_runs_only_allowlisted_commands() -> void:
	for line: String in ["help", "assets list", "hosts show HOST-014", "logs search source=auth user=jsmith after=09:00", "timeline build CASE-001", "case report CASE-001"]:
		check(_model.run_command(line).ok, "allowed: %s" % line)
	for line: String in ["rm -rf /", "cat /etc/passwd", "powershell -c whoami", "help; ls", "logs search source=auth | sh", "../../etc/passwd", "OS.execute('x')", "hosts show ../../x"]:
		var result: TerminalResult = _model.run_command(line)
		check(not result.ok, "refused: %s" % line)
		check(not result.lines.is_empty(), "with an explanation: %s" % line)


func test_terminal_commands_change_the_same_case() -> void:
	var before: int = _model.audit_history().size()
	var result: TerminalResult = _model.run_command("evidence add EVT-004 CASE-001")
	check(result.ok, "evidence add works")
	check(_model.is_collected("evt_004"), "and the model sees the evidence")
	check(_model.audit_history().size() > before, "a changing command is audited")
	var read_only: int = _model.audit_history().size()
	_model.run_command("help")
	check_eq(_model.audit_history().size(), read_only, "a read-only command is not audited")


func test_knowledge_checks_give_feedback_but_never_change_the_score() -> void:
	var before: float = _model.mastery_fraction()
	var right: Dictionary = _model.answer_check("kc_failures_then_success", "b")
	check(right["correct"] == true and not str(right["feedback"]).is_empty(), "the correct option is recognised with feedback")
	var wrong: Dictionary = _model.answer_check("kc_failures_then_success", "a")
	check(wrong["correct"] == false and not str(wrong["feedback"]).is_empty(), "a wrong option gets teaching feedback")
	check(_model.answer_check("kc_failures_then_success", "zzz").is_empty(), "an unknown option gives nothing")
	check(_model.answer_check("no_such_check", "a").is_empty(), "an unknown check gives nothing")
	check_eq(_model.mastery_fraction(), before, "mastery is unchanged by knowledge checks")


func test_objectives_follow_the_rubric() -> void:
	var rows: Array[Dictionary] = _model.objectives()
	check_eq(rows.size(), 6, "six mission objectives")
	for row: Dictionary in rows:
		check_eq(row["status"], "unmet", "%s starts unmet" % row["id"])
	check_eq(_model.mastery_fraction(), 0.0, "mastery starts at zero")
	for event_id: String in ["evt_001", "evt_002", "evt_003", "evt_004", "evt_005"]:
		_model.collect_evidence(event_id)
	check(_model.mastery_fraction() > 0.0, "collecting the key events raises mastery")
	check_eq(_model.objectives()[0]["status"], "met", "the events objective is met")


func test_hints_are_logged() -> void:
	check(_model.hint_log.is_empty(), "no hints yet")
	var result: ActionResult = _model.request_hint()
	check(result.ok, "a hint is available: %s" % result.message)
	check_eq(_model.hint_log.size(), 1, "the hint is kept in the log")


func test_progress_resumes_from_the_checkpoint() -> void:
	_model.collect_evidence("evt_004")
	_model.add_note("hypothesis", "Someone else may have the password.")
	var saved: Dictionary = _progress.to_dict()
	var restored: ProgressService = ProgressService.new()
	check(restored.load_from_dict(saved).ok, "saved progress loads")
	var resumed: SocModel = SocModel.open(restored)
	check(resumed.is_ready(), "the SOC reopens from saved progress")
	check(resumed.is_collected("evt_004"), "collected evidence is back")
	check_eq(resumed.session.case_file.entries().size(), 1, "notes are back")
	check_eq(resumed.case_status, "investigating", "status is inferred from restored work")
	restored.free()


func test_terminal_banner_is_the_one_the_spec_requires() -> void:
	check_eq(SocModel.terminal_banner(), TerminalCommands.BANNER, "the banner comes from the terminal's own constant")
	check(SocModel.terminal_banner().contains("SIMULATED ENVIRONMENT") and SocModel.terminal_banner().contains("NO HOST COMMANDS"), "and says SIMULATED ENVIRONMENT and NO HOST COMMANDS (spec 05 §5)")


func test_a_broken_content_set_fails_safely() -> void:
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var spare: ProgressService = ProgressService.new()
	var missing: SocModel = SocModel.open(spare, ContentLoader.new(registry, "res://does_not_exist"))
	check(not missing.is_ready(), "missing content leaves the model not ready")
	check(not missing.errors.is_empty(), "and says why")
	check(not spare.has_active_lab(), "no lab is started when the content is broken")
	spare.free()
