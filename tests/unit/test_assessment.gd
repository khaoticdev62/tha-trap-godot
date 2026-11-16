extends TestCase
## Rubric scoring (spec 04 §7), critical errors, hints, cross-document checks.
## Each golden path states the exact score it must earn.

var _content: LabContent


func before_each() -> void:
	_content = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	check(_content.is_ready(), "the lab loads: %s" % str(_content.errors))


func _session(difficulty: String = "standard", seed_number: int = 1) -> LabSession:
	return _content.new_session(difficulty, seed_number)


func _refs(values: Array) -> PackedStringArray:
	return PackedStringArray(values)


## The ideal investigation: every key event, a fact for each step, a hypothesis
## and an unknown, scope, severity, the best response, and a clear report.
func _play_ideal(session: LabSession) -> void:
	session.add_evidence(_refs(["EVT-001", "EVT-002"]), "two failures")        # ev_001
	session.add_evidence(_refs(["EVT-003"]), "success from a new source")      # ev_002
	session.add_evidence(_refs(["EVT-004"]), "new MFA device")                 # ev_003
	session.add_evidence(_refs(["EVT-005"]), "member portal accessed")         # ev_004
	session.add_evidence(_refs(["EVT-006"]), "employee says it was not them")  # ev_005
	session.add_case_entry("fact", "Two failed sign-ins were followed by a success from a source this account has not used.", _refs(["ev_001", "ev_002"]))
	session.add_case_entry("fact", "A new MFA device was requested three minutes after the success.", _refs(["ev_003"]))
	session.add_case_entry("fact", "The member support portal was accessed from the same source.", _refs(["ev_004"]))
	session.add_case_entry("hypothesis", "Someone other than the employee took over the account.")
	session.add_case_entry("unknown", "Was any member data copied?")
	session.set_scope(_refs(["host_014", "member_portal"]))
	session.set_severity("high")
	session.set_recommendation("verify_then_protect")
	session.set_escalation("soc_lead")
	session.set_report_summary("Likely account takeover of j.smith. Verify with the employee, then reset the password, end sessions and review the MFA change.")


func _points(result: AssessmentResult) -> Dictionary:
	var by_id: Dictionary = {}
	for row: Dictionary in result.criteria:
		by_id[row["id"]] = row["points"]
	return by_id


# --- golden paths -----------------------------------------------------------

func test_ideal_investigation_scores_full_marks() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	var result: AssessmentResult = session.assess()
	check_eq(result.total, 100, "full marks")
	check(result.passed and not result.needs_retry and result.critical_errors.is_empty(), "passed with no critical error")
	check_eq(result.max_points, 100, "out of 100")
	check_eq(_points(result), {"events_collected": 20, "timeline_facts": 20, "facts_and_hypotheses": 20, "impact_and_scope": 15, "response": 15, "report": 10}, "each criterion at its maximum (20/20/20/15/15/10)")
	for row: Dictionary in result.criteria:
		check_eq(row["status"], "met", "%s is met" % row["id"])


func test_a_valid_alternative_path_also_passes() -> void:
	var session: LabSession = _session()
	for event_ref: String in ["EVT-001", "EVT-002", "EVT-003", "EVT-004", "EVT-005"]:
		session.add_evidence(_refs([event_ref]))  # ev_001 .. ev_005, one event each
	session.add_case_entry("fact", "Failed sign-ins, then a success from a new source.", _refs(["ev_001", "ev_002", "ev_003"]))
	session.add_case_entry("fact", "A new MFA device was requested.", _refs(["ev_004"]))
	session.add_case_entry("fact", "The member portal was accessed.", _refs(["ev_005"]))
	session.add_case_entry("unknown", "Whether member data left the portal.")
	session.set_scope(_refs(["HOST-014", "Member support portal"]))
	session.set_severity("medium")
	session.set_recommendation("protect_now")
	session.set_escalation("incident_commander")
	session.set_report_summary("Probable account takeover with portal access; recommend protecting the account and escalating to the incident commander.")
	var result: AssessmentResult = session.assess()
	check_eq(result.total, 95, "a different but defensible route scores 95 (response 10 instead of 15)")
	check(result.passed, "and passes")
	check_eq(_points(result)["response"], 10, "acceptable response earns 10")
	check_eq(_points(result)["report"], 10, "either right escalation target earns full report marks")


func test_an_empty_case_scores_nothing_without_punishment() -> void:
	var result: AssessmentResult = _session().assess()
	check_eq(result.total, 0, "nothing done, nothing earned")
	check(not result.passed and not result.needs_retry and result.critical_errors.is_empty(), "not passed, but no error either")
	for row: Dictionary in result.criteria:
		check_eq(row["status"], "unmet", "%s unmet" % row["id"])
		check(not str(row["feedback"]).is_empty(), "%s explains what to do" % row["id"])


func test_a_partial_investigation_scores_what_it_earned() -> void:
	var session: LabSession = _session()
	session.add_evidence(_refs(["EVT-001", "EVT-002", "EVT-003"]))
	session.add_case_entry("fact", "Failures then a success from a new source.", _refs(["ev_001"]))
	session.add_case_entry("hypothesis", "Possible password guessing.")
	var result: AssessmentResult = session.assess()
	check_eq(_points(result), {"events_collected": 12, "timeline_facts": 10, "facts_and_hypotheses": 12, "impact_and_scope": 0, "response": 0, "report": 0}, "12 + 10 + 12")
	check_eq(result.total, 34, "34 in total")
	check(not result.passed, "below the pass mark")
	var events_row: Dictionary = result.criteria[0]
	check_eq(events_row["status"], "partial", "partial status")
	check(str(events_row["feedback"]).contains("EVT-004") and str(events_row["feedback"]).contains("EVT-005"), "feedback names the missing events: %s" % events_row["feedback"])


func test_each_response_option_scores_as_authored() -> void:
	var expected: Dictionary = {"verify_then_protect": 15, "protect_now": 10, "disable_account_now": 6, "monitor_only": 3, "broad_shutdown": 2}
	for option_id: String in expected:
		var session: LabSession = _session()
		_play_ideal(session)
		session.set_recommendation(option_id)
		check_eq(_points(session.assess())["response"], expected[option_id], "response '%s'" % option_id)
	var none: LabSession = _session()
	_play_ideal(none)
	none.case_file.recommendation = ""
	check_eq(_points(none.assess())["response"], 0, "no recommendation scores nothing")


func test_each_escalation_option_scores_as_authored() -> void:
	var expected: Dictionary = {"soc_lead": 10, "incident_commander": 10, "helpdesk": 8, "none": 6}
	for option_id: String in expected:
		var session: LabSession = _session()
		_play_ideal(session)
		session.set_escalation(option_id)
		check_eq(_points(session.assess())["report"], expected[option_id], "escalation '%s' (summary 6 + escalation)" % option_id)


# --- critical errors --------------------------------------------------------

func test_declaring_exfiltration_as_fact_is_a_critical_error_with_coaching() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	session.add_case_entry("fact", "Confirmed exfiltration of member data.", _refs(["ev_004"]))
	var result: AssessmentResult = session.assess()
	check(result.needs_retry and not result.passed, "asks for another attempt")
	check_eq(result.critical_errors.size(), 1, "one critical error")
	check_eq(result.critical_errors[0]["id"], "unsupported_claim", "the right one")
	check(str(result.critical_errors[0]["coaching"]).contains("hypothesis"), "coaching says what to do instead")
	check_eq(result.total, 94, "the claims points are lost too (100 - 6)")
	check(" ".join(result.summary_lines()).contains("nothing is lost"), "the player is told nothing is lost")


func test_hedged_or_hypothesis_statements_are_not_flagged() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	session.add_case_entry("fact", "There is no evidence of data exfiltration in these logs.", _refs(["ev_004"]))
	session.add_case_entry("hypothesis", "Data was copied out of the portal.")
	session.add_case_entry("unknown", "Whether data was stolen is unknown.")
	var result: AssessmentResult = session.assess()
	check(result.critical_errors.is_empty() and result.total == 100, "careful wording is rewarded, not punished")


func test_a_broad_shutdown_without_analysis_is_a_critical_error() -> void:
	var session: LabSession = _session()
	session.add_evidence(_refs(["EVT-003"]))
	session.set_recommendation("broad_shutdown")
	var result: AssessmentResult = session.assess()
	check(result.needs_retry, "broad shutdown with no analysis needs coaching")
	check_eq(result.critical_errors[0]["id"], "broad_response_without_analysis", "named correctly")
	check(str(result.critical_errors[0]["coaching"]).contains("evidence"), "coaching points at evidence first")


func test_a_broad_shutdown_after_analysis_is_poor_but_not_critical() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	session.set_recommendation("broad_shutdown")
	var result: AssessmentResult = session.assess()
	check(result.critical_errors.is_empty() and not result.needs_retry, "analysis was done, so this is judgement, not a critical error")
	check_eq(_points(result)["response"], 2, "but it earns very little")
	check_eq(result.total, 87, "100 - 13")


func test_disabling_one_account_is_not_a_broad_response() -> void:
	var session: LabSession = _session()
	session.set_recommendation("disable_account_now")
	check(session.assess().critical_errors.is_empty(), "overreach is scored, only the broad option is critical")


# --- properties -------------------------------------------------------------

func test_evaluation_is_pure() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	var before: String = session.state_hash()
	var first: AssessmentResult = session.assess()
	var second: AssessmentResult = session.assess()
	check_eq(session.state_hash(), before, "assessing changes nothing")
	check_eq(first.total, second.total, "same state, same score")
	check_eq(JSON.stringify(first.criteria), JSON.stringify(second.criteria), "and the same feedback")


func test_difficulty_and_seed_never_change_the_answer() -> void:
	for level: String in ScenarioGenerator.DIFFICULTIES:
		for seed_number: int in [0, 7, 123456]:
			var session: LabSession = _session(level, seed_number)
			_play_ideal(session)
			check_eq(session.assess().total, 100, "ideal run scores 100 at %s / seed %d" % [level, seed_number])


func test_query_history_and_hints_do_not_change_the_score() -> void:
	var plain: LabSession = _session("beginner", 2)
	_play_ideal(plain)
	var helped: LabSession = _session("beginner", 2)
	_play_ideal(helped)
	var terminal: TerminalParser = TerminalParser.new(helped)
	terminal.run("logs search user=j.smith")
	terminal.run("hint")
	helped.hints_used["response"] = 3
	check_eq(helped.assess().total, plain.assess().total, "score ignores searches and hints")
	check_eq(helped.assess().hints_used, 3, "but the report records how many hints were used")


func test_scoring_uses_evidence_not_wording_of_events() -> void:
	var session: LabSession = _session()
	session.add_evidence(_refs(["EVT-001", "EVT-002", "EVT-003", "EVT-004", "EVT-005"]))
	check_eq(_points(session.assess())["events_collected"], 20, "one evidence item holding all five events counts as collecting them")


func test_noise_evidence_does_not_earn_or_cost_points() -> void:
	var session: LabSession = _session("advanced", 4)
	var noise_id: String = ""
	for event: EventRecord in session.store.all():
		if event.id.begins_with("evt_n"):
			noise_id = event.id
			break
	session.add_evidence(_refs([noise_id]))
	check_eq(session.assess().total, 0, "an unrelated event earns nothing")


# --- hints ------------------------------------------------------------------

func test_hints_climb_one_rung_at_a_time_then_stop() -> void:
	var session: LabSession = _session("standard", 1)
	var first: ActionResult = session.request_hint()
	check(first.ok and first.id == "events_collected/1" and first.message.contains("Hint 1 of 2"), "first hint: %s" % first.message)
	var second: ActionResult = session.request_hint()
	check(second.ok and second.id == "events_collected/2", "second hint is more direct")
	var third: ActionResult = session.request_hint()
	check(third.ok and not third.changed and third.message.contains("No more hints"), "standard difficulty allows two: %s" % third.message)
	check_eq(session.hints_used, {"events_collected": 2}, "use is recorded")


func test_hints_follow_the_first_unmet_step() -> void:
	var session: LabSession = _session("beginner", 1)
	for event_ref: String in ["EVT-001", "EVT-002", "EVT-003", "EVT-004", "EVT-005"]:
		session.add_evidence(_refs([event_ref]))
	check_eq(session.request_hint().id, "timeline_facts/1", "events are done, so the hint moves on to the timeline")


func test_hint_levels_depend_on_difficulty() -> void:
	var allowed: Dictionary = {"beginner": 3, "standard": 2, "advanced": 1, "expert": 0}
	for level: String in allowed:
		var session: LabSession = _session(level, 1)
		var given: int = 0
		for _i: int in 5:
			var outcome: ActionResult = session.request_hint()
			if outcome.ok and outcome.changed:
				given += 1
		check_eq(given, allowed[level], "%s gets %d hint levels" % [level, allowed[level]])
	check(not _session("expert").request_hint().ok, "expert is told there are no hints")


func test_no_hint_needed_when_everything_is_met() -> void:
	var session: LabSession = _session()
	_play_ideal(session)
	var outcome: ActionResult = session.request_hint()
	check(outcome.ok and not outcome.changed and outcome.message.contains("everything"), "nothing left to hint: %s" % outcome.message)


func test_a_bare_session_has_no_hints() -> void:
	var bare: LabSession = LabSession.new(_content.package, "beginner", 1)
	check(not bare.request_hint().ok, "no rubric attached, no hints")
	check(bare.assess() == null, "and nothing to assess")


# --- content cross-checks ---------------------------------------------------

func _documents() -> Array[Dictionary]:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var docs: Array[Dictionary] = []
	for content_id: String in ["lab_001_scenario", "lab_001_rubric", "lab_001_hints"]:
		docs.append((loader.load_content(content_id).data as Dictionary).duplicate(true))
	return docs


func test_shipped_documents_agree_with_each_other() -> void:
	var docs: Array[Dictionary] = _documents()
	check(ContentCatalog.lab_cross_problems(docs[0], docs[1], docs[2]).is_empty(), "the shipped lab is consistent: %s" % str(ContentCatalog.lab_cross_problems(docs[0], docs[1], docs[2])))


func test_cross_checks_catch_broken_documents() -> void:
	var broken: Dictionary = {
		"total does not add up": func(d: Array[Dictionary]) -> void: d[1]["max_points"] = 90,
		"criterion ceiling mismatch": func(d: Array[Dictionary]) -> void: d[1]["criteria"][0]["max_points"] = 25,
		"option offered but not scored": func(d: Array[Dictionary]) -> void: d[1]["response_scores"].remove_at(0),
		"option scored but not offered": func(d: Array[Dictionary]) -> void: d[0]["response_options"].remove_at(0),
		"escalation not scored": func(d: Array[Dictionary]) -> void: d[1]["escalation_scores"].remove_at(0),
		"unknown required event": func(d: Array[Dictionary]) -> void: d[1]["criteria"][0]["params"]["required"].append("evt_999"),
		"unknown asset in scoring": func(d: Array[Dictionary]) -> void: d[1]["criteria"][3]["params"]["scope_points"]["ghost_asset"] = 3,
		"hint for unknown criterion": func(d: Array[Dictionary]) -> void: d[2]["hints"][0]["criterion_id"] = "ghost",
		"missing hint level": func(d: Array[Dictionary]) -> void: d[2]["hints"].remove_at(1),
		"duplicate hint level": func(d: Array[Dictionary]) -> void: d[2]["hints"].append(d[2]["hints"][0].duplicate()),
		"pass mark above maximum": func(d: Array[Dictionary]) -> void: d[1]["pass_points"] = 150,
	}
	for label: String in broken:
		var docs: Array[Dictionary] = _documents()
		(broken[label] as Callable).call(docs)
		check(not ContentCatalog.lab_cross_problems(docs[0], docs[1], docs[2]).is_empty(), "caught: %s" % label)


func test_schemas_reject_malformed_rubric_documents() -> void:
	var docs: Array[Dictionary] = _documents()
	var rubric: Dictionary = docs[1]
	rubric["criteria"][0]["check"] = "run_arbitrary_code"
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var schema: Dictionary = registry.entry("lab_001_rubric")["schema"]
	check(not SchemaValidator.validate(rubric, schema).ok(), "a rubric cannot name a check that does not exist")
	var hints: Dictionary = docs[2]
	hints["hints"][0]["level"] = 9
	check(not SchemaValidator.validate(hints, registry.entry("lab_001_hints")["schema"]).ok(), "hint levels are limited to 1 to 3")


func test_lab_content_refuses_an_inconsistent_lab() -> void:
	var root: String = "user://itest_labcontent_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(root.path_join("labs/lab_001"))
	var docs: Array[Dictionary] = _documents()
	docs[1]["max_points"] = 90
	var names: Dictionary = {"labs/lab_001/manifest.json": null, "labs/lab_001/scenario.json": docs[0], "labs/lab_001/rubric.json": docs[1], "labs/lab_001/hints.json": docs[2]}
	for relative: String in names:
		if names[relative] == null:
			continue
		var file: FileAccess = FileAccess.open(root.path_join(relative), FileAccess.WRITE)
		file.store_string(JSON.stringify(names[relative]))
		file = null
	var content: LabContent = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry(), root), "lab_001")
	check(not content.is_ready() and not content.errors.is_empty(), "an inconsistent lab is not playable: %s" % str(content.errors))
	for relative: String in names:
		DirAccess.remove_absolute(root.path_join(relative))
	DirAccess.remove_absolute(root.path_join("labs/lab_001"))
	DirAccess.remove_absolute(root.path_join("labs"))
	DirAccess.remove_absolute(root)
