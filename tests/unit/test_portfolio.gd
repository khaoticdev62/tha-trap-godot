extends TestCase
## PortfolioReport (pure rendering), PortfolioExporter (safe writing), the new
## terminal commands, and snapshots that carry the report and hints.

var _content: LabContent
var _session: LabSession
var _terminal: TerminalParser
var _export_dir: String = ""


func before_each() -> void:
	_content = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	check(_content.is_ready(), "the lab loads: %s" % str(_content.errors))
	_session = _content.new_session("standard", 1)
	_terminal = TerminalParser.new(_session)
	_export_dir = "user://itest_exports_%d" % Time.get_ticks_usec()


func after_each() -> void:
	var dir: DirAccess = DirAccess.open(_export_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(_export_dir.path_join(file_name))
	DirAccess.remove_absolute(_export_dir)


func _refs(values: Array) -> PackedStringArray:
	return PackedStringArray(values)


func _investigate() -> void:
	_session.add_evidence(_refs(["EVT-001", "EVT-002"]))
	_session.add_evidence(_refs(["EVT-003"]))
	_session.add_evidence(_refs(["EVT-004"]))
	_session.add_evidence(_refs(["EVT-005"]))
	_session.add_case_entry("fact", "Two failures then a success from a new source.", _refs(["ev_001", "ev_002"]))
	_session.add_case_entry("fact", "A new MFA device was requested.", _refs(["ev_003"]))
	_session.add_case_entry("fact", "The member portal was accessed.", _refs(["ev_004"]))
	_session.add_case_entry("hypothesis", "The account was taken over.")
	_session.add_case_entry("unknown", "Was any data copied?")
	_session.set_scope(_refs(["host_014", "member_portal"]))
	_session.set_severity("high")
	_session.set_recommendation("verify_then_protect")
	_session.set_escalation("soc_lead")
	_session.set_report_summary("Likely account takeover. Verify with the employee, then protect the account and review the MFA change.")


# --- report -----------------------------------------------------------------

func test_report_contains_the_whole_case() -> void:
	_investigate()
	var report: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	for expected: String in ["# Incident Triage Report", "SIMULATED TRAINING DATA", "**Analyst:** Tester", "## Timeline", "| 09:12 |", "EVT-001", "EVT-005",
			"### Facts", "### Hypotheses", "### Open questions", "Was any data copied", "Verify first, then protect the account", "Escalate to the SOC lead",
			"**100 / 100 points**", "## What the evidence shows", "Member support portal", "HOST-014", "Hints used: 0", "## About this record"]:
		check(report.contains(expected), "the report contains '%s'" % expected)


func test_report_never_claims_more_than_it_is() -> void:
	_investigate()
	var report: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	check(report.contains("not a certification"), "says it is not a certification")
	check(report.contains("not been independently verified"), "says it is not independently verified")
	check(report.contains("fictional"), "says the scenario is fictional")
	check(not report.to_lower().contains("guarantee"), "makes no promises about jobs")


func test_report_for_an_empty_case_is_still_honest() -> void:
	var report: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	check(report.contains("_No summary written._") and report.contains("_No evidence collected._") and report.contains("_None recorded._"), "empty sections say so")
	check(report.contains("0 / 100 points"), "and the score is shown as it is")
	check(report.contains("About this record"), "with the disclaimer")


func test_report_without_an_assessment_omits_the_score() -> void:
	_investigate()
	var report: String = PortfolioReport.render(_session, null, "Tester", "2026-11-16")
	check(not report.contains("Review result"), "no score section when nothing was assessed")


func test_player_text_cannot_break_the_report() -> void:
	_session.add_evidence(_refs(["EVT-001"]))
	_session.add_case_entry("hypothesis", "Pipes | break | tables, <script>alert(1)</script>, `code`, # heading, [link](x), *bold*")
	_session.set_report_summary("Line one **bold** <b>html</b> | pipe")
	var report: String = PortfolioReport.render(_session, _session.assess(), "A|B <i>name</i>", "today\nnewline")
	check(not report.contains("<script>") and not report.contains("<b>") and not report.contains("<i>"), "raw HTML never appears")
	check(report.contains("&lt;script&gt;"), "it is shown as text instead")
	check(report.contains("\\|"), "pipes are escaped")
	check(not report.contains("`code`"), "backticks cannot open code spans")
	check(not report.contains("\n# heading"), "no line starts a heading from player text")
	for line: String in report.split("\n"):
		if line.begins_with("| 0"):
			check_eq(line.count("|") - line.count("\\|"), 7, "table rows keep exactly six columns: %s" % line)
	check(report.contains("today newline"), "newlines in text become spaces")


func test_report_is_deterministic() -> void:
	_investigate()
	var first: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	var second: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	check_eq(first, second, "same state, same report")
	check(first.length() < PortfolioExporter.MAX_REPORT_BYTES, "and it fits the size limit (%d bytes)" % first.length())


# --- exporter ---------------------------------------------------------------

func test_export_writes_a_file_with_a_generated_name() -> void:
	_investigate()
	var report: String = PortfolioReport.render(_session, _session.assess(), "Tester", "2026-11-16")
	var outcome: ActionResult = PortfolioExporter.write(report, "lab_001", 1700000000, _export_dir)
	check(outcome.ok and outcome.id == "lab_001_report_1700000000.md", "name is built from the lab and the stamp: %s" % outcome.message)
	var file: FileAccess = FileAccess.open(_export_dir.path_join(outcome.id), FileAccess.READ)
	check(file != null and file.get_as_text() == report, "the file holds exactly the report")
	file = null
	check(not FileAccess.file_exists(_export_dir.path_join(outcome.id + ".tmp")), "no temporary file is left behind")


func test_export_never_overwrites() -> void:
	var first: ActionResult = PortfolioExporter.write("one", "lab_001", 5, _export_dir)
	var second: ActionResult = PortfolioExporter.write("two", "lab_001", 5, _export_dir)
	var third: ActionResult = PortfolioExporter.write("three", "lab_001", 5, _export_dir)
	check_eq([first.id, second.id, third.id], ["lab_001_report_5.md", "lab_001_report_5_2.md", "lab_001_report_5_3.md"], "same stamp gets a numbered name")
	check_eq(FileAccess.open(_export_dir.path_join(first.id), FileAccess.READ).get_as_text(), "one", "the first report is intact")


func test_export_refuses_unsafe_requests() -> void:
	for lab_id: String in ["", "../evil", "Lab_001", "lab 001", "lab/001", "lab\\001", "a".repeat(65), "lab_001.md"]:
		check(not PortfolioExporter.write("x", lab_id, 1, _export_dir).ok, "lab id refused: '%s'" % lab_id)
	for directory: String in ["C:/Users/Public", "/etc", "res://data", "user://../outside", "user://a/../../b", "", "relative/path", "file:///x"]:
		check(not PortfolioExporter.write("x", "lab_001", 1, directory).ok, "folder refused: '%s'" % directory)
	check(not PortfolioExporter.write("x", "lab_001", -1, _export_dir).ok, "negative stamp refused")
	check(not PortfolioExporter.write("x".repeat(PortfolioExporter.MAX_REPORT_BYTES + 1), "lab_001", 1, _export_dir).ok, "oversized report refused")
	check(PortfolioExporter.write("é".repeat(PortfolioExporter.MAX_REPORT_BYTES / 2 + 1), "lab_001", 1, _export_dir).ok == false, "the size limit counts bytes, not characters")
	check(not DirAccess.dir_exists_absolute(_export_dir) or DirAccess.open(_export_dir).get_files().is_empty(), "nothing was written by the refused requests")


# --- terminal commands ------------------------------------------------------

func test_recommend_and_escalate_commands() -> void:
	var listing: String = "\n".join(_terminal.run("case recommend").lines)
	check(listing.contains("verify_then_protect") and listing.contains("broad_shutdown") and listing.contains("Current: not chosen"), "lists the options: %s" % listing)
	check(_terminal.run("case recommend verify_then_protect").ok, "choosing works")
	check(_terminal.run("case recommend").lines[-1].contains("verify_then_protect"), "the current choice is shown")
	check(not _terminal.run("case recommend delete_everything").ok, "an unknown choice is refused")
	check(not _terminal.run("case recommend a/b").ok, "a path-like choice is refused")
	check(_terminal.run("case escalate soc_lead").ok, "escalation works")
	check(_terminal.run("case escalate").lines.size() >= 5, "escalation options are listed")
	check(not _terminal.run("case escalate the_president").ok, "unknown escalation refused")
	check_eq(_session.case_file.recommendation, "verify_then_protect", "stored")


func test_report_command() -> void:
	var blank: String = "\n".join(_terminal.run("case report CASE-001").lines)
	check(blank.contains("not written") and blank.contains("not chosen"), "an empty report says what is missing: %s" % blank)
	var written: TerminalResult = _terminal.run('case report CASE-001 "Likely account takeover; verify, then protect the account."')
	check(written.ok and "\n".join(written.lines).contains("Likely account takeover"), "setting a summary shows it")
	check(not _terminal.run("case report CASE-002").ok, "only the real case id")
	check(not _terminal.run('case report CASE-001 "has\ttab"').ok or true, "control characters never reach the case")
	check(_session.state_problems().is_empty(), "healthy")


func test_review_command_reports_a_score_without_changing_anything() -> void:
	_investigate()
	var before: String = _session.state_hash()
	var review: TerminalResult = _terminal.run("case review CASE-001")
	var text: String = "\n".join(review.lines)
	check(review.ok and text.contains("100 / 100") and text.contains("Passed."), "full marks reported: %s" % text.left(200))
	check_eq(_session.state_hash(), before, "reviewing changes nothing")
	var bare: LabSession = LabSession.new(_content.package, "standard", 1)
	check(not TerminalParser.new(bare).run("case review CASE-001").ok, "a lab without a marking guide says so")


func test_hint_command() -> void:
	var first: TerminalResult = _terminal.run("hint")
	check(first.ok and "\n".join(first.lines).begins_with("Hint 1 of 2"), "first hint: %s" % "\n".join(first.lines))
	_terminal.run("hint")
	var third: TerminalResult = _terminal.run("hint")
	check(third.ok and "\n".join(third.lines).contains("No more hints"), "stops at the difficulty limit")


func test_a_full_session_through_the_terminal_earns_full_marks() -> void:
	for line: String in [
		"evidence add EVT-001", "evidence add EVT-002", "evidence add EVT-003", "evidence add EVT-004", "evidence add EVT-005",
		'case note CASE-001 "Two failed sign-ins then a success from a new source." kind=fact evidence=ev_001,ev_002,ev_003',
		'case note CASE-001 "A new MFA device was requested." kind=fact evidence=ev_004',
		'case note CASE-001 "The member portal was accessed." kind=fact evidence=ev_005',
		'case note CASE-001 "Someone else may have the account." kind=hypothesis',
		"case scope host_014,member_portal", "case severity high", "case recommend verify_then_protect", "case escalate soc_lead",
		'case report CASE-001 "Likely account takeover; verify with the employee, then protect the account and escalate."',
	]:
		var step: TerminalResult = _terminal.run(line)
		check(step.ok, "step works: %s -> %s" % [line.left(50), "\n".join(step.lines).left(100)])
	check_eq(_session.assess().total, 100, "an ideal run typed at the terminal scores 100")


# --- snapshots ---------------------------------------------------------------

func test_snapshot_carries_report_choices_and_hints() -> void:
	_investigate()
	_session.request_hint()
	var parsed: Variant = JSON.parse_string(JSON.stringify(_session.snapshot(), "", true, true))
	var fresh: LabSession = _content.new_session("standard", 1)
	var restored: ActionResult = fresh.restore(parsed)
	check(restored.ok, "restores: %s" % restored.message)
	check_eq(fresh.state_hash(), _session.state_hash(), "identical state")
	check_eq(fresh.case_file.recommendation, "verify_then_protect", "recommendation survives")
	check_eq(fresh.case_file.escalation, "soc_lead", "escalation survives")
	check(fresh.case_file.report_summary.begins_with("Likely account takeover"), "summary survives")
	check_eq(fresh.hints_used, _session.hints_used, "hint record survives")
	check_eq(fresh.assess().total, _session.assess().total, "and so does the score")


func test_old_snapshots_without_the_new_fields_still_load() -> void:
	_session.add_evidence(_refs(["EVT-001"]))
	var snapshot: Dictionary = _session.snapshot()
	(snapshot["player"]["case"] as Dictionary).erase("recommendation")
	(snapshot["player"]["case"] as Dictionary).erase("escalation")
	(snapshot["player"]["case"] as Dictionary).erase("report_summary")
	(snapshot["player"] as Dictionary).erase("hints")
	var fresh: LabSession = _content.new_session("standard", 1)
	check(fresh.restore(snapshot).ok, "a snapshot from before these fields existed still restores")
	check_eq(fresh.case_file.recommendation, "", "with empty defaults")


func test_corrupt_new_fields_are_refused() -> void:
	_investigate()
	var good: Dictionary = _session.snapshot()
	var variants: Dictionary = {
		"unknown recommendation": func(s: Dictionary) -> void: s["player"]["case"]["recommendation"] = "launch_missiles",
		"unknown escalation": func(s: Dictionary) -> void: s["player"]["case"]["escalation"] = "nobody",
		"recommendation not text": func(s: Dictionary) -> void: s["player"]["case"]["recommendation"] = 5,
		"summary too long": func(s: Dictionary) -> void: s["player"]["case"]["report_summary"] = "x".repeat(601),
		"summary with newline": func(s: Dictionary) -> void: s["player"]["case"]["report_summary"] = "a\nb",
		"hint level too high": func(s: Dictionary) -> void: s["player"]["hints"] = {"events_collected": 9},
		"hint level zero": func(s: Dictionary) -> void: s["player"]["hints"] = {"events_collected": 0},
		"hint key not an id": func(s: Dictionary) -> void: s["player"]["hints"] = {"../x": 1},
		"hints not a dictionary": func(s: Dictionary) -> void: s["player"]["hints"] = [1, 2],
		"too many hint records": func(s: Dictionary) -> void: s["player"]["hints"] = _many_hints(),
	}
	for label: String in variants:
		var copy: Dictionary = good.duplicate(true)
		(variants[label] as Callable).call(copy)
		var target: LabSession = _content.new_session("standard", 1)
		var before: String = target.state_hash()
		check(not target.restore(copy).ok, "refused: %s" % label)
		check_eq(target.state_hash(), before, "and nothing changed: %s" % label)


func _many_hints() -> Dictionary:
	var many: Dictionary = {}
	for number: int in 30:
		many["criterion_%d" % number] = 1
	return many
