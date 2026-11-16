extends TestCase
## SIEM-style query language: tokenizer, parser, executor, against the shipped
## LAB-001 events. Golden results use the story account so synthetic noise can
## never change them.

var _store: EventStore


func before_each() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var scenario: ContentResult = loader.load_content("lab_001_scenario")
	check(scenario.ok(), "scenario loads: %s" % str(scenario.errors))
	_store = LabSession.new(ScenarioPackage.from_document(scenario.data), "standard", 1).store


func _ids(result: QueryResult) -> String:
	var found: PackedStringArray = PackedStringArray()
	for ids: PackedStringArray in result.row_event_ids:
		found.append_array(ids)
	return ",".join(found)


func _run(text: String) -> QueryResult:
	return QueryEngine.run(text, _store)


# --- golden queries ---------------------------------------------------------

func test_failed_sign_ins_for_the_story_account() -> void:
	var result: QueryResult = _run('FROM auth_events WHERE user = "j.smith" AND result = "failure"')
	check(result.ok, "runs: %s" % result.message)
	check_eq(_ids(result), "evt_001,evt_002", "the two failures at 09:12 and 09:13")
	check_eq(result.columns, PackedStringArray(QueryExecutor.RAW_COLUMNS), "raw columns")
	check_eq(result.rows[0][0], "EVT-001", "display id shown to the player")
	check_eq(result.rows[0][1], "09:12", "time shown as a clock")


func test_time_range_is_inclusive_after_and_exclusive_before() -> void:
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AND result = "success" AFTER "09:00"')), "evt_003", "only the 09:16 success is after 09:00")
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" BEFORE "09:13"')), "evt_007,evt_001", "09:13:00 itself is excluded by BEFORE")
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AFTER "09:13" BEFORE "09:16"')), "evt_002", "AFTER is inclusive")
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AFTER "09:16"')), "evt_003", "09:16 is included when it is the AFTER time")


func test_iso_timestamps_work_like_clock_times() -> void:
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AFTER "2026-10-04T09:15:00"')), "evt_003", "date part ignored, time used")
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AFTER "9:15"')), "evt_003", "single-digit hour accepted")


func test_group_by_and_sort() -> void:
	var result: QueryResult = _run('FROM auth_events WHERE user = "j.smith" GROUP BY source_ip COUNT SORT count DESC')
	check(result.ok, "runs: %s" % result.message)
	check_eq(result.columns, PackedStringArray(["source_ip", "count"]), "grouped columns")
	check_eq(result.rows.size(), 2, "two sources")
	check_eq(result.rows[0], PackedStringArray(["ext-203-0-113-45", "3"]), "the unfamiliar source has three events")
	check_eq(result.rows[1], PackedStringArray(["int-10-20-0-12", "1"]), "the usual source has one")
	check_eq(result.row_event_ids[0], PackedStringArray(["evt_001", "evt_002", "evt_003"]), "group rows carry their event ids")
	var ascending: QueryResult = _run('FROM auth_events WHERE user = "j.smith" GROUP BY source_ip SORT count ASC')
	check_eq(ascending.rows[0][1], "1", "ascending order flips it")


func test_count_alone() -> void:
	var result: QueryResult = _run('FROM auth_events WHERE user = "j.smith" COUNT')
	check_eq(result.rows.size(), 1, "one summary row")
	check_eq(result.rows[0][0], "4", "four sign-in events for the account")
	check_eq(result.row_event_ids[0].size(), 4, "the row carries all four event ids")
	check_eq(result.columns, PackedStringArray(["count"]), "single count column")


func test_other_sources() -> void:
	check_eq(_ids(_run("FROM mfa_events")), "evt_004", "the MFA enrollment request")
	check_eq(_ids(_run('FROM app_events WHERE user = "j.smith"')), "evt_005", "the portal access")
	check_eq(_ids(_run('FROM helpdesk_tickets WHERE detail CONTAINS "no recent"')), "evt_006", "the help-desk report")


func test_boolean_logic_and_parentheses() -> void:
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AND NOT (result = "failure" OR source_ip CONTAINS "int-")')), "evt_003", "NOT with parentheses")
	check_eq(_ids(_run('FROM auth_events WHERE user = "j.smith" AND result = "failure" OR user = "r.alvarez"')), "evt_008,evt_001,evt_002", "AND binds tighter than OR")
	check_eq(_ids(_run('FROM auth_events WHERE user != "j.smith" AND source_ip = "int-10-20-0-31"')), "evt_008", "inequality")
	check_eq(_ids(_run('FROM auth_events WHERE tags CONTAINS "new_source"')), "evt_003", "tags are searchable")


func test_matching_ignores_case() -> void:
	check_eq(_ids(_run('from AUTH_EVENTS where USER = "J.SMITH" and Result = "FAILURE"')), "evt_001,evt_002", "keywords, fields and values ignore case")


func test_limit_and_truncation() -> void:
	var result: QueryResult = _run('FROM auth_events WHERE user = "j.smith" LIMIT 1')
	check_eq(result.rows.size(), 1, "one row returned")
	check(result.truncated, "marked as truncated")
	check_eq(result.matched_count, 4, "total matches are still reported")
	check(not _run('FROM auth_events WHERE user = "j.smith" LIMIT 4').truncated, "not truncated when everything fits")


func test_sorting_raw_rows() -> void:
	var by_result: QueryResult = _run('FROM auth_events WHERE user = "j.smith" SORT result DESC')
	check_eq(by_result.rows[0][5], "success", "descending by result text")
	var by_time: QueryResult = _run('FROM auth_events WHERE user = "j.smith" SORT time DESC')
	check_eq(_ids(by_time), "evt_003,evt_002,evt_001,evt_007", "descending by time")


func test_story_results_do_not_depend_on_difficulty_or_seed() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var package: ScenarioPackage = ScenarioPackage.from_document(loader.load_content("lab_001_scenario").data)
	var query: String = 'FROM auth_events WHERE user = "j.smith" GROUP BY source_ip COUNT SORT count DESC'
	var reference: QueryResult = _run(query)
	for level: String in ScenarioGenerator.DIFFICULTIES:
		var other: QueryResult = QueryEngine.run(query, LabSession.new(package, level, 31).store)
		check_eq(other.rows, reference.rows, "same answer at %s" % level)


func test_data_that_looks_like_code_is_just_data() -> void:
	var result: QueryResult = _run('FROM auth_events WHERE user = "x\' OR \'1\'=\'1"')
	check(result.ok and result.rows.is_empty(), "an injection-style string simply matches nothing")
	result = _run('FROM auth_events WHERE detail = "\\"; DROP TABLE auth_events; --"')
	check(result.ok and result.rows.is_empty(), "escaped quotes inside text are data")
	result = _run('FROM auth_events WHERE user = "j.smith" AND detail CONTAINS "Café 🙂 مرحبا"')
	check(result.ok and result.rows.is_empty(), "unicode text is accepted")


# --- teaching errors --------------------------------------------------------

func _expect_failure(text: String, code: QueryResult.Code, hint: String = "") -> void:
	var result: QueryResult = _run(text)
	check(not result.ok, "rejected: %s" % text.left(50))
	check_eq(result.code, code, "error code for: %s" % text.left(50))
	check(not result.message.is_empty(), "has a message: %s" % text.left(50))
	if not hint.is_empty():
		check(result.message.contains(hint), "message mentions '%s': %s" % [hint, result.message])
	check(result.rows.is_empty(), "no rows on failure")


func test_empty_and_oversized_queries() -> void:
	_expect_failure("", QueryResult.Code.EMPTY_QUERY)
	_expect_failure("   \n\t ", QueryResult.Code.EMPTY_QUERY)
	_expect_failure("FROM auth_events WHERE user = \"%s\"" % "a".repeat(600), QueryResult.Code.TOO_LONG)
	_expect_failure("FROM auth_events WHERE " + " OR ".join(PackedStringArray(range(80).map(func(n: int) -> String: return 'user = "u%d"' % n))), QueryResult.Code.TOO_LONG)


func test_unknown_source_and_field() -> void:
	_expect_failure("FROM users", QueryResult.Code.UNKNOWN_SOURCE, "auth_events")
	_expect_failure("FROM", QueryResult.Code.UNKNOWN_SOURCE)
	_expect_failure('FROM auth_events WHERE password = "x"', QueryResult.Code.UNKNOWN_FIELD, "source_ip")
	_expect_failure("FROM auth_events GROUP BY nothing", QueryResult.Code.UNKNOWN_FIELD)
	_expect_failure("FROM auth_events SORT nothing", QueryResult.Code.UNKNOWN_FIELD)
	_expect_failure("FROM auth_events SORT count", QueryResult.Code.UNKNOWN_FIELD, "You can SORT by")


func test_syntax_problems_explain_the_fix() -> void:
	_expect_failure("SELECT * FROM auth_events", QueryResult.Code.SYNTAX, "starts with FROM")
	_expect_failure("FROM auth_events WHERE user = j.smith", QueryResult.Code.SYNTAX, "double quotes")
	_expect_failure("FROM auth_events WHERE user", QueryResult.Code.SYNTAX, "=, != or CONTAINS")
	_expect_failure('FROM auth_events WHERE user > "a"', QueryResult.Code.SYNTAX, "AFTER")
	_expect_failure("FROM auth_events WHERE user = 'a'", QueryResult.Code.SYNTAX, "double quotes")
	_expect_failure('FROM auth_events WHERE (user = "a"', QueryResult.Code.SYNTAX, "closed")
	_expect_failure('FROM auth_events WHERE user = "a")', QueryResult.Code.SYNTAX)
	_expect_failure('FROM auth_events WHERE user = "unfinished', QueryResult.Code.SYNTAX, "closing double quote")
	_expect_failure('FROM auth_events WHERE user = "a\\nb"', QueryResult.Code.SYNTAX, "backslash")
	_expect_failure('FROM auth_events LIMIT 5 WHERE user = "a"', QueryResult.Code.SYNTAX, "order")
	_expect_failure('FROM auth_events; DROP TABLE x', QueryResult.Code.SYNTAX, "no pipes")
	_expect_failure('FROM auth_events | grep x', QueryResult.Code.SYNTAX, "no pipes")
	_expect_failure("FROM auth_events GROUP source_ip", QueryResult.Code.SYNTAX, "BY")
	_expect_failure("FROM auth_events trailing junk", QueryResult.Code.SYNTAX, "Unexpected")


func test_time_and_limit_problems() -> void:
	for bad_time: String in ["25:00", "09:60", "9", "abc", "", "09:5", "-1:00", "09:15:7", "2026-13-40T09:00", "T09:00"]:
		_expect_failure('FROM auth_events AFTER "%s"' % bad_time, QueryResult.Code.BAD_TIME)
	_expect_failure("FROM auth_events AFTER 0915", QueryResult.Code.BAD_TIME, "double quotes")
	_expect_failure('FROM auth_events AFTER "10:00" BEFORE "09:00"', QueryResult.Code.BAD_TIME, "later")
	_expect_failure("FROM auth_events LIMIT 0", QueryResult.Code.BAD_LIMIT)
	_expect_failure("FROM auth_events LIMIT 501", QueryResult.Code.BAD_LIMIT, "500")
	_expect_failure("FROM auth_events LIMIT many", QueryResult.Code.BAD_LIMIT)
	_expect_failure("FROM auth_events LIMIT 99999999999", QueryResult.Code.SYNTAX)
	check(_run("FROM auth_events LIMIT 500").ok, "the maximum limit is accepted")


func test_nesting_limit() -> void:
	var seven: String = "(".repeat(7) + 'user = "a"' + ")".repeat(7)
	check(_run("FROM auth_events WHERE " + seven).ok, "seven levels of parentheses are fine")
	_expect_failure("FROM auth_events WHERE " + "(".repeat(9) + 'user = "a"' + ")".repeat(9), QueryResult.Code.TOO_DEEP)
	_expect_failure("FROM auth_events WHERE " + "NOT ".repeat(9) + 'user = "a"', QueryResult.Code.TOO_DEEP)


func test_unsafe_characters_are_refused() -> void:
	_expect_failure("FROM auth_events WHERE user = \"a" + String.chr(1) + "b\"", QueryResult.Code.BAD_CHARACTER)
	_expect_failure("FROM auth_events" + String.chr(0x202E) + " WHERE user = \"a\"", QueryResult.Code.BAD_CHARACTER)
	_expect_failure("FROM auth_events WHERE user = \"a" + String.chr(0x200B) + "b\"", QueryResult.Code.BAD_CHARACTER)
	_expect_failure("FROM auth_events WHERE user = \"a" + String.chr(10) + "b\"", QueryResult.Code.BAD_CHARACTER)


func test_work_budget() -> void:
	var big: EventStore = EventStore.new()
	for index: int in 3000:
		big.add(EventRecord.from_dict({"id": "evt_b%d" % index, "tick": index % 80000, "source": "auth", "actor": "u", "result": "success"}))
	var clauses: PackedStringArray = PackedStringArray()
	for index: int in 20:
		clauses.append('user = "u%d"' % index)
	var wide: String = "FROM auth_events WHERE " + " OR ".join(clauses)
	check(QueryEngine.run(wide, big).ok, "a normal-sized search over thousands of events runs")
	var heavy: EventStore = EventStore.new()
	for index: int in 60000:
		heavy.add(EventRecord.from_dict({"id": "evt_h%d" % index, "tick": index % 80000, "source": "auth", "actor": "u", "result": "success"}))
	var refused: QueryResult = QueryEngine.run(wide, heavy)
	check(not refused.ok and refused.code == QueryResult.Code.TOO_EXPENSIVE, "an over-budget search is refused instead of run")


func test_time_parser_directly() -> void:
	check_eq(QueryParser.parse_time("09:12"), 33120, "HH:MM")
	check_eq(QueryParser.parse_time("9:12"), 33120, "H:MM")
	check_eq(QueryParser.parse_time("09:12:30"), 33150, "HH:MM:SS")
	check_eq(QueryParser.parse_time("2026-10-04T09:12:00"), 33120, "ISO")
	check_eq(QueryParser.parse_time("00:00"), 0, "midnight")
	check_eq(QueryParser.parse_time("23:59:59"), 86399, "last second")
	check_eq(QueryParser.parse_time("24:00"), -1, "24:00 is not a time")
	check_eq(QueryParser.parse_time("+9:12"), -1, "signs are not digits")
