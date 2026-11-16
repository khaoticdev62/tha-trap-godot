extends TestCase
## ProgressService, MissionService and mission content rules.

var _content: LabContent
var _progress: ProgressService


func before_each() -> void:
	_content = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	check(_content.is_ready(), "the lab loads: %s" % str(_content.errors))
	_progress = ProgressService.new()


func after_each() -> void:
	_progress.free()


func _result(total: int, passed: bool, version: String = "1.0.0") -> AssessmentResult:
	var result: AssessmentResult = AssessmentResult.new()
	result.total = total
	result.passed = passed
	result.rubric_version = version
	return result


func _play(mission_id: String, total: int, passed: bool, version: String = "1.0.0") -> String:
	_progress.begin_lab(mission_id, _content)
	return _progress.finish_lab(_result(total, passed, version))


func test_a_new_game_has_no_record() -> void:
	check(not _progress.is_completed("mission_lab_001"), "nothing completed")
	check_eq(_progress.attempts("mission_lab_001"), 0, "no attempts")
	check_eq(_progress.recorded_state("mission_lab_001"), "", "no recorded state")
	check(not _progress.has_active_lab(), "no lab in progress")


func test_starting_a_lab_marks_it_in_progress_with_a_fresh_seed() -> void:
	var session: LabSession = _progress.begin_lab("mission_lab_001", _content)
	check(session != null and _progress.current_session == session, "a session is created")
	check_eq(session.seed_value, ProgressService.BASE_SEED, "the first attempt uses the base seed")
	check_eq(_progress.recorded_state("mission_lab_001"), "in_progress", "recorded as in progress")
	check_eq(_progress.active_mission_id(), "mission_lab_001", "the active mission is known")
	_progress.finish_lab(_result(40, false))
	var second: LabSession = _progress.begin_lab("mission_lab_001", _content)
	check_eq(second.seed_value, ProgressService.BASE_SEED + 1, "a replay uses a new seed, so the background noise changes")


func test_begin_lab_refuses_bad_input() -> void:
	check(_progress.begin_lab("Bad Id", _content) == null, "a bad mission id is refused")
	check(_progress.begin_lab("../x", _content) == null, "a path-like id is refused")
	check(_progress.begin_lab("mission_lab_001", LabContent.new()) == null, "content that did not load is refused")
	check(not _progress.has_active_lab(), "nothing started")


func test_passing_completes_the_mission() -> void:
	var seen: Array[String] = []
	_progress.mission_state_changed.connect(func(id: String, state: String) -> void: seen.append("%s:%s" % [id, state]))
	check_eq(_play("mission_lab_001", 92, true), "completed", "state returned")
	check(_progress.is_completed("mission_lab_001"), "completed")
	check_eq(_progress.best_score("mission_lab_001"), 92, "best score recorded")
	check_eq(_progress.attempts("mission_lab_001"), 1, "one attempt")
	check_eq(_progress.content_version("mission_lab_001"), "1.0.0", "the marking-guide version is stored with the result")
	check(not _progress.has_active_lab() and _progress.current_session == null, "the attempt is closed")
	check(seen.has("mission_lab_001:completed"), "listeners are told")


func test_a_failed_attempt_is_recorded_but_does_not_complete() -> void:
	check_eq(_play("mission_lab_001", 45, false), "in_progress", "still in progress")
	check_eq(_progress.attempts("mission_lab_001"), 1, "the attempt counts")
	check_eq(_progress.best_score("mission_lab_001"), 45, "its score is kept")
	check(not _progress.is_completed("mission_lab_001"), "not completed")


func test_completion_is_permanent_and_scores_only_rise() -> void:
	_play("mission_lab_001", 80, true, "1.0.0")
	check_eq(_play("mission_lab_001", 30, false, "2.0.0"), "completed", "a poor replay cannot undo completion")
	check_eq(_progress.best_score("mission_lab_001"), 80, "the best score stays")
	check_eq(_progress.content_version("mission_lab_001"), "1.0.0", "and the version it was earned under stays")
	_play("mission_lab_001", 95, true, "2.0.0")
	check_eq(_progress.best_score("mission_lab_001"), 95, "a better replay raises it")
	check_eq(_progress.content_version("mission_lab_001"), "2.0.0", "and records the version that earned it")
	check_eq(_progress.attempts("mission_lab_001"), 3, "every attempt is counted")


func test_abandoning_forgets_a_fresh_attempt_but_keeps_history() -> void:
	_progress.begin_lab("mission_lab_001", _content)
	_progress.abandon_lab()
	check_eq(_progress.recorded_state("mission_lab_001"), "", "an abandoned first attempt leaves no trace")
	_play("mission_lab_001", 90, true)
	_progress.begin_lab("mission_lab_001", _content)
	_progress.abandon_lab()
	check(_progress.is_completed("mission_lab_001"), "abandoning a replay keeps the earlier completion")
	check_eq(_progress.attempts("mission_lab_001"), 1, "and does not count as an attempt")


func test_finish_without_an_active_lab_does_nothing() -> void:
	check_eq(_progress.finish_lab(_result(100, true)), "", "nothing to finish")
	_progress.begin_lab("mission_lab_001", _content)
	check_eq(_progress.finish_lab(null), "", "no result, no change")
	check(_progress.has_active_lab(), "the attempt is still open")


func test_flags_checkpoint_and_difficulty_are_validated() -> void:
	check(_progress.set_flag("met_nia") and _progress.has_flag("met_nia"), "a valid flag is set")
	for bad: String in ["", "Met Nia", "../x", "a".repeat(65), "UPPER"]:
		check(not _progress.set_flag(bad), "flag refused: '%s'" % bad)
	check(_progress.set_checkpoint("hq_briefing") and _progress.checkpoint() == "hq_briefing", "checkpoint set")
	check(not _progress.set_checkpoint("Bad Place"), "bad checkpoint refused")
	check(_progress.set_checkpoint("") and _progress.checkpoint() == "", "a checkpoint can be cleared")
	check(_progress.set_difficulty("advanced") and _progress.difficulty == "advanced", "difficulty set")
	check(not _progress.set_difficulty("nightmare"), "unknown difficulty refused")
	for number: int in ProgressService.MAX_FLAGS:
		_progress.set_flag("flag_%d" % number)
	check(not _progress.set_flag("one_too_many"), "the flag list has a limit")


func test_reset_forgets_everything() -> void:
	_play("mission_lab_001", 90, true)
	_progress.set_flag("met_nia")
	_progress.set_difficulty("expert")
	_progress.reset()
	check(not _progress.is_completed("mission_lab_001") and not _progress.has_flag("met_nia"), "record cleared")
	check_eq(_progress.difficulty, "standard", "difficulty back to the default")


# --- saving and loading -----------------------------------------------------

func test_progress_round_trips_through_json() -> void:
	_play("mission_lab_001", 88, true)
	_progress.set_flag("met_nia")
	_progress.set_checkpoint("hq_board")
	_progress.set_difficulty("advanced")
	var text: String = JSON.stringify(_progress.to_dict(), "", true, true)
	var other: ProgressService = ProgressService.new()
	var loaded: ActionResult = other.load_from_dict(JSON.parse_string(text))
	check(loaded.ok, "loads: %s" % loaded.message)
	check_eq(JSON.stringify(other.to_dict(), "", true, true), text, "identical after a save and load")
	check(other.is_completed("mission_lab_001") and other.best_score("mission_lab_001") == 88 and other.has_flag("met_nia"), "values survive")
	other.free()


func test_an_empty_progress_record_means_a_new_game() -> void:
	_play("mission_lab_001", 90, true)
	check(_progress.load_from_dict({}).ok, "an empty record is a new game (this is what a v1 save upgrades to)")
	check(not _progress.is_completed("mission_lab_001"), "nothing carried over")


func test_damaged_progress_is_refused_and_changes_nothing() -> void:
	_play("mission_lab_001", 88, true)
	var good: Dictionary = _progress.to_dict()
	var before: String = JSON.stringify(good, "", true, true)
	var mutations: Dictionary = {
		"not a dictionary": "text",
		"missing version": func(d: Dictionary) -> void: d.erase("version"),
		"version zero": func(d: Dictionary) -> void: d["version"] = 0,
		"newer version": func(d: Dictionary) -> void: d["version"] = ProgressService.FORMAT_VERSION + 1,
		"unknown difficulty": func(d: Dictionary) -> void: d["difficulty"] = "nightmare",
		"missions not a dictionary": func(d: Dictionary) -> void: d["missions"] = [],
		"bad mission id": func(d: Dictionary) -> void: d["missions"]["../evil"] = {"state": "completed"},
		"bad state": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["state"] = "available",
		"negative score": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["best_score"] = -1,
		"huge score": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["best_score"] = 5000,
		"fractional score": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["best_score"] = 50.5,
		"text score": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["best_score"] = "100",
		"huge attempts": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["attempts"] = 10000000,
		"version with newline": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["content_version"] = "1\n0",
		"long version": func(d: Dictionary) -> void: d["missions"]["mission_lab_001"]["content_version"] = "x".repeat(30),
		"flag that is not true": func(d: Dictionary) -> void: d["flags"] = {"met_nia": "yes"},
		"bad flag name": func(d: Dictionary) -> void: d["flags"] = {"Bad Flag": true},
		"too many flags": func(d: Dictionary) -> void: d["flags"] = _many(ProgressService.MAX_FLAGS + 1, true),
		"too many missions": func(d: Dictionary) -> void: d["missions"] = _many(ProgressService.MAX_MISSIONS + 1, {"state": "completed", "best_score": 1, "attempts": 1, "content_version": "1"}),
		"bad checkpoint": func(d: Dictionary) -> void: d["checkpoint"] = "../x",
		"active lab not a dictionary": func(d: Dictionary) -> void: d["active_lab"] = 5,
		"active lab without snapshot": func(d: Dictionary) -> void: d["active_lab"] = {"mission_id": "mission_lab_001", "lab_key": "lab_001"},
		"active lab bad key": func(d: Dictionary) -> void: d["active_lab"] = {"mission_id": "mission_lab_001", "lab_key": "../lab", "snapshot": {}},
	}
	for label: String in mutations:
		var candidate: Variant = "text"
		if mutations[label] is Callable:
			var copy: Dictionary = good.duplicate(true)
			(mutations[label] as Callable).call(copy)
			candidate = copy
		var outcome: ActionResult = _progress.load_from_dict(candidate)
		check(not outcome.ok and not outcome.message.is_empty(), "refused: %s" % label)
		check_eq(JSON.stringify(_progress.to_dict(), "", true, true), before, "and nothing changed: %s" % label)


func _many(count: int, value: Variant) -> Dictionary:
	var many: Dictionary = {}
	for number: int in count:
		many["item_%d" % number] = value.duplicate(true) if value is Dictionary else value
	return many


func test_unknown_missions_are_kept_but_never_unlock_anything() -> void:
	var data: Dictionary = _progress.to_dict()
	data["missions"]["mission_from_the_future"] = {"state": "completed", "best_score": 100, "attempts": 1, "content_version": "9.9.9"}
	check(_progress.load_from_dict(data).ok, "an unknown mission id is accepted")
	check(_progress.to_dict()["missions"].has("mission_from_the_future"), "and written back unchanged")
	var missions: MissionService = MissionService.load_all(ContentLoader.new(ContentCatalog.build_registry()), PackedStringArray(ContentCatalog.MISSION_IDS))
	check_eq(missions.state_of("mission_from_the_future", _progress), MissionService.LOCKED, "but it is locked as far as the game is concerned")
	missions._definitions["mission_needs_future"] = {"lab_key": "lab_001", "title": "x", "summary": "x", "prerequisites": PackedStringArray(["mission_from_the_future"])}
	check_eq(missions.state_of("mission_needs_future", _progress), MissionService.LOCKED, "and satisfies no prerequisite")


func test_resuming_a_lab_restores_the_exact_work() -> void:
	var session: LabSession = _progress.begin_lab("mission_lab_001", _content)
	session.add_evidence(PackedStringArray(["EVT-001", "EVT-002"]), "failures")
	session.add_case_entry("fact", "Two failed sign-ins.", PackedStringArray(["ev_001"]))
	session.set_severity("high")
	var expected: String = session.state_hash()
	_progress.checkpoint_lab()
	var other: ProgressService = ProgressService.new()
	check(other.load_from_dict(JSON.parse_string(JSON.stringify(_progress.to_dict()))).ok, "the saved progress loads")
	check(other.has_active_lab(), "the lab in progress is remembered")
	var resumed: LabSession = other.resume_lab(_content)
	check(resumed != null, "resumes: %s" % other.last_error)
	check_eq(resumed.state_hash(), expected, "the evidence, case and counters are exactly as left")
	check_eq(resumed.seed_value, session.seed_value, "with the same seed, so the same log")
	other.free()


func test_work_since_the_last_checkpoint_is_not_saved() -> void:
	var session: LabSession = _progress.begin_lab("mission_lab_001", _content)
	session.add_evidence(PackedStringArray(["EVT-001"]))
	_progress.checkpoint_lab()
	session.add_evidence(PackedStringArray(["EVT-002"]))
	var other: ProgressService = ProgressService.new()
	other.load_from_dict(_progress.to_dict())
	check_eq(other.resume_lab(_content).ledger.size(), 1, "only checkpointed work comes back")
	other.free()


func test_resume_fails_safely() -> void:
	check(_progress.resume_lab(_content) == null and not _progress.last_error.is_empty(), "nothing to resume says so")
	var session: LabSession = _progress.begin_lab("mission_lab_001", _content)
	session.add_evidence(PackedStringArray(["EVT-001"]))
	_progress.checkpoint_lab()
	var data: Dictionary = _progress.to_dict()

	var damaged: Dictionary = data.duplicate(true)
	damaged["active_lab"]["snapshot"]["player"]["evidence"]["records"][0]["event_ids"] = ["evt_missing"]
	var other: ProgressService = ProgressService.new()
	other.load_from_dict(damaged)
	check(other.resume_lab(_content) == null and not other.last_error.is_empty(), "a damaged snapshot is refused: %s" % other.last_error)

	var wrong_lab: Dictionary = data.duplicate(true)
	wrong_lab["active_lab"]["lab_key"] = "lab_099"
	other.load_from_dict(wrong_lab)
	check(other.resume_lab(_content) == null, "a lab this version does not have is refused")

	var bad_seed: Dictionary = data.duplicate(true)
	bad_seed["active_lab"]["snapshot"]["seed"] = "not a number"
	other.load_from_dict(bad_seed)
	check(other.resume_lab(_content) == null, "an invalid seed is refused")

	var bad_level: Dictionary = data.duplicate(true)
	bad_level["active_lab"]["snapshot"]["difficulty"] = "nightmare"
	other.load_from_dict(bad_level)
	check(other.resume_lab(_content) == null, "an unknown difficulty is refused")
	other.free()


func test_play_time_is_collected_once() -> void:
	_progress.add_play_seconds(30.0)
	_progress.add_play_seconds(-5.0)
	check_eq(_progress.take_play_seconds(), 30.0, "negative time is ignored")
	check_eq(_progress.take_play_seconds(), 0.0, "taken once")
	_progress.add_play_seconds(1.0e12)
	check_eq(_progress.take_play_seconds(), ProgressService.MAX_PLAY_SECONDS_HELD, "unsaved time is capped")


func test_summaries_never_fail() -> void:
	for junk: Variant in [null, 5, "x", [], {}, {"missions": 5}, {"missions": {"a": 1}}, {"active_lab": "x"}]:
		check(ProgressService.summarise(junk).has("completed"), "summarised without error: %s" % str(junk))
	_play("mission_lab_001", 90, true)
	var summary: Dictionary = ProgressService.summarise(_progress.to_dict())
	check_eq(summary["completed"], 1, "one completed mission")
	check_eq(summary["attempts"], 1, "one attempt")
	check_eq(summary["in_progress"], false, "no lab open")


# --- missions ---------------------------------------------------------------

func test_mission_states() -> void:
	var missions: MissionService = MissionService.load_all(ContentLoader.new(ContentCatalog.build_registry()), PackedStringArray(ContentCatalog.MISSION_IDS))
	check(missions.errors.is_empty(), "missions load: %s" % str(missions.errors))
	check_eq(missions.ids(), PackedStringArray(["mission_lab_001"]), "the shipped mission")
	check_eq(missions.lab_key("mission_lab_001"), "lab_001", "points at its lab")
	check_eq(missions.state_of("mission_lab_001", _progress), MissionService.AVAILABLE, "available at the start")
	_progress.begin_lab("mission_lab_001", _content)
	check_eq(missions.state_of("mission_lab_001", _progress), MissionService.IN_PROGRESS, "in progress once started")
	_progress.finish_lab(_result(50, false))
	check_eq(missions.state_of("mission_lab_001", _progress), MissionService.IN_PROGRESS, "still in progress after a failed attempt")
	_play("mission_lab_001", 95, true)
	check_eq(missions.state_of("mission_lab_001", _progress), MissionService.COMPLETED, "completed after a pass")
	check_eq(missions.state_of("no_such_mission", _progress), MissionService.LOCKED, "unknown missions are locked")


func test_prerequisites_lock_a_mission_until_they_are_completed() -> void:
	var missions: MissionService = MissionService.new()
	missions._definitions = {
		"first": {"lab_key": "lab_001", "title": "1", "summary": "", "prerequisites": PackedStringArray()},
		"second": {"lab_key": "lab_001", "title": "2", "summary": "", "prerequisites": PackedStringArray(["first"])},
		"orphan": {"lab_key": "lab_001", "title": "3", "summary": "", "prerequisites": PackedStringArray(["ghost"])},
	}
	check_eq(missions.state_of("second", _progress), MissionService.LOCKED, "locked while the first is unfinished")
	check_eq(missions.state_of("orphan", _progress), MissionService.LOCKED, "a prerequisite that does not exist never unlocks")
	_progress.begin_lab("first", _content)
	_progress.finish_lab(_result(90, true))
	check_eq(missions.state_of("second", _progress), MissionService.AVAILABLE, "available once the first is completed")


func test_mission_content_rules() -> void:
	var good: Dictionary = {"a": {"lab_key": "lab_001", "prerequisites": []}, "b": {"lab_key": "lab_001", "prerequisites": ["a"]}}
	check(ContentCatalog.mission_problems(good, PackedStringArray(["a", "b"])).is_empty(), "a sound mission set passes")
	check(not ContentCatalog.mission_problems({"a": {"lab_key": "lab_001", "prerequisites": ["zzz"]}}, PackedStringArray(["a"])).is_empty(), "unknown prerequisite caught")
	check(not ContentCatalog.mission_problems({"a": {"lab_key": "lab_001", "prerequisites": ["a"]}}, PackedStringArray(["a"])).is_empty(), "self prerequisite caught")
	var loop: Dictionary = {"a": {"lab_key": "lab_001", "prerequisites": ["b"]}, "b": {"lab_key": "lab_001", "prerequisites": ["a"]}}
	check(not ContentCatalog.mission_problems(loop, PackedStringArray(["a", "b"])).is_empty(), "a prerequisite loop is caught")
	check(not ContentCatalog.mission_problems({"a": {"lab_key": "lab_404", "prerequisites": []}}, PackedStringArray(["a"])).is_empty(), "a mission pointing at a lab with no content is caught")
