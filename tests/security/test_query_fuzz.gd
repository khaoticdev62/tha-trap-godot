extends TestCase
## Fuzzing the query engine with hostile and random input. Properties checked
## for every input: it returns a QueryResult (never crashes), failures carry a
## message, successes stay within the row cap, and the whole run stays fast.
## Seeds are fixed so a failure can be reproduced exactly.

const VOCABULARY: Array[String] = [
	"FROM", "auth_events", "mfa_events", "app_events", "helpdesk_tickets", "WHERE", "AND", "OR", "NOT",
	"(", ")", "=", "!=", "CONTAINS", "AFTER", "BEFORE", "GROUP", "BY", "COUNT", "SORT", "ASC", "DESC",
	"LIMIT", "user", "result", "source_ip", "time", "tags", "\"j.smith\"", "\"09:15\"", "\"\"", "5", "0",
	"999999999", "\"", "\\", "'", ";", "--", "*", "evt_001", ">", "<", "|", "&&", "$(x)", "`x`", "../..",
]
const SEEDS_PER_TEST: int = 1500
const TIME_BUDGET_MS: int = 30000

var _store: EventStore


func before_each() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var scenario: ContentResult = loader.load_content("lab_001_scenario")
	_store = LabSession.new(ScenarioPackage.from_document(scenario.data), "expert", 9).store


func _check_one(text: String, context: String) -> bool:
	var result: QueryResult = QueryEngine.run(text, _store)
	var sane: bool = result != null and result.rows.size() <= ParsedQuery.MAX_LIMIT and result.rows.size() == result.row_event_ids.size()
	if result != null and not result.ok:
		sane = sane and not result.message.is_empty() and result.rows.is_empty()
	check(sane, "%s: input stayed well-behaved: %s" % [context, text.left(60).c_escape()])
	return result != null and result.ok


func test_random_token_soup() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261116
	var started: int = Time.get_ticks_msec()
	var accepted: int = 0
	for _i: int in SEEDS_PER_TEST:
		var parts: PackedStringArray = PackedStringArray()
		for _j: int in rng.randi_range(0, 30):
			parts.append(VOCABULARY[rng.randi_range(0, VOCABULARY.size() - 1)])
		if _check_one((" " if rng.randi_range(0, 4) > 0 else "").join(parts), "soup"):
			accepted += 1
	check(Time.get_ticks_msec() - started < TIME_BUDGET_MS, "token soup finished within the time budget")
	check(accepted < SEEDS_PER_TEST, "most random soup is rejected (%d accepted)" % accepted)


func test_random_characters() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var interesting: Array[int] = [0x200B, 0x202E, 0x2066, 0xFEFF, 0x1F600, 0x0627, 0x22, 0x5C, 0x27, 0x28, 0x29, 0x0A, 0x09, 0x7F, 0x85]
	var started: int = Time.get_ticks_msec()
	for _i: int in SEEDS_PER_TEST:
		var text: String = ""
		for _j: int in rng.randi_range(0, 60):
			var code: int = interesting[rng.randi_range(0, interesting.size() - 1)] if rng.randi_range(0, 3) == 0 else rng.randi_range(1, 0x2FF)
			text += String.chr(code)
		_check_one(text, "chars")
	check(Time.get_ticks_msec() - started < TIME_BUDGET_MS, "random characters finished within the time budget")


func test_mutations_of_valid_queries() -> void:
	var seeds: Array[String] = [
		'FROM auth_events WHERE user = "j.smith" AND result = "failure" AFTER "09:00" GROUP BY source_ip COUNT SORT count DESC LIMIT 20',
		'FROM mfa_events WHERE NOT (result = "success" OR user != "j.smith") BEFORE "2026-10-04T10:00:00" LIMIT 5',
		'FROM helpdesk_tickets WHERE detail CONTAINS "no recent" COUNT',
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var started: int = Time.get_ticks_msec()
	for seed_query: String in seeds:
		check(_check_one(seed_query, "seed query"), "the seed query itself is valid: %s" % seed_query)
		for _i: int in SEEDS_PER_TEST / seeds.size():
			var text: String = seed_query
			for _edit: int in rng.randi_range(1, 4):
				var at: int = rng.randi_range(0, maxi(0, text.length() - 1))
				match rng.randi_range(0, 3):
					0:
						text = text.erase(at, rng.randi_range(1, 6))
					1:
						text = text.insert(at, String.chr(rng.randi_range(1, 0x7E)))
					2:
						text = text.insert(at, VOCABULARY[rng.randi_range(0, VOCABULARY.size() - 1)])
					3:
						text = text.insert(at, text.substr(at, rng.randi_range(1, 20)))
			_check_one(text, "mutation")
	check(Time.get_ticks_msec() - started < TIME_BUDGET_MS, "mutations finished within the time budget")


func test_pathological_inputs() -> void:
	var started: int = Time.get_ticks_msec()
	var cases: Array[String] = [
		"A".repeat(100000),
		"(".repeat(600),
		"FROM auth_events WHERE " + "NOT ".repeat(200) + "user = \"a\"",
		"\"".repeat(1000),
		" ".repeat(10000),
		"FROM auth_events WHERE " + "(".repeat(300) + "user = \"a\"" + ")".repeat(300),
		"\\".repeat(500),
		"FROM auth_events LIMIT " + "9".repeat(400),
		"\n".repeat(400) + "FROM auth_events",
		"FROM auth_events WHERE user = \"" + "x".repeat(480) + "\"",
	]
	for text: String in cases:
		_check_one(text, "pathological")
	check(Time.get_ticks_msec() - started < TIME_BUDGET_MS, "pathological inputs finished within the time budget")
