extends TestCase
## LabSession, ScenarioGenerator and the shipped LAB-001 scenario: canonical
## events, determinism, difficulty and reset.

const STORY_ACTORS: Array[String] = ["j.smith", "r.alvarez"]

var _package: ScenarioPackage


func before_each() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var result: ContentResult = loader.load_content("lab_001_scenario")
	check(result.ok(), "the shipped scenario validates: %s" % str(result.errors))
	_package = ScenarioPackage.from_document(result.data)


func _canonical(session: LabSession) -> Array:
	var rows: Array = []
	for event: EventRecord in session.store.all():
		if event.canonical:
			rows.append(event.to_dict())
	return rows


func _generated(session: LabSession) -> Array[EventRecord]:
	var found: Array[EventRecord] = []
	for event: EventRecord in session.store.all():
		if event.id.begins_with("evt_n"):
			found.append(event)
	return found


func test_canonical_events_match_spec_04() -> void:
	var session: LabSession = LabSession.new(_package, "standard", 1)
	var expected: Array = [
		["evt_001", 33120, "auth", "failure"],
		["evt_002", 33180, "auth", "failure"],
		["evt_003", 33360, "auth", "success"],
		["evt_004", 33540, "mfa", "requested"],
		["evt_005", 33840, "app", "success"],
		["evt_006", 34800, "helpdesk", "reported"],
	]
	var found: Array = _canonical(session)
	check_eq(found.size(), expected.size(), "exactly six canonical events")
	for index: int in mini(found.size(), expected.size()):
		var row: Dictionary = found[index]
		check_eq([row["id"], row["tick"], row["source"], row["result"]], expected[index], "event %d matches" % (index + 1))
		check_eq(row["actor"], "j.smith", "story events belong to the single synthetic account")
	check_eq(EventRecord.clock_text(33120), "09:12", "EVT-001 is at 09:12")


func test_canonical_events_never_change_with_difficulty_or_seed() -> void:
	var reference: Array = _canonical(LabSession.new(_package, "standard", 1))
	for level: String in ScenarioGenerator.DIFFICULTIES:
		for seed_number: int in [0, 1, 99, -7]:
			check_eq(_canonical(LabSession.new(_package, level, seed_number)), reference, "canonical events identical at %s / seed %d" % [level, seed_number])


func test_same_inputs_give_the_same_state() -> void:
	var first: LabSession = LabSession.new(_package, "advanced", 42)
	var second: LabSession = LabSession.new(_package, "advanced", 42)
	check_eq(first.state_hash(), second.state_hash(), "identical inputs, identical state hash")
	check_eq(first.store.canonical_json(), second.store.canonical_json(), "and identical events")


func test_different_seed_changes_the_noise_only() -> void:
	var first: LabSession = LabSession.new(_package, "standard", 1)
	var second: LabSession = LabSession.new(_package, "standard", 2)
	check(first.state_hash() != second.state_hash(), "a new seed gives a new state")
	check_eq(_canonical(first), _canonical(second), "but the story events are untouched")


func test_noise_grows_with_difficulty() -> void:
	var sizes: Array[int] = []
	for level: String in ScenarioGenerator.DIFFICULTIES:
		sizes.append(_generated(LabSession.new(_package, level, 5)).size())
	check(sizes[0] < sizes[1] and sizes[1] < sizes[2] and sizes[2] < sizes[3], "noise strictly increases: %s" % str(sizes))


func test_noise_never_uses_the_story_accounts() -> void:
	var session: LabSession = LabSession.new(_package, "expert", 3)
	for event: EventRecord in _generated(session):
		check(not STORY_ACTORS.has(event.actor), "noise actor %s is not a story actor" % event.actor)
		check(not event.canonical, "generated events are never canonical")


func test_ids_are_unique_and_sorted_by_time() -> void:
	var session: LabSession = LabSession.new(_package, "expert", 11)
	var seen: Dictionary = {}
	var last_tick: int = -1
	for event: EventRecord in session.store.all():
		check(not seen.has(event.id), "unique id %s" % event.id)
		seen[event.id] = true
		check(event.tick >= last_tick, "time order holds at %s" % event.id)
		last_tick = event.tick
		check(event.tick >= 0 and event.tick < EventRecord.SECONDS_PER_DAY, "tick inside the day")


func test_decoys_appear_only_at_higher_difficulty() -> void:
	for level: String in ["beginner", "standard"]:
		for event: EventRecord in _generated(LabSession.new(_package, level, 8)):
			check(not event.tags.has("decoy"), "no decoys at %s" % level)
	var advanced: LabSession = LabSession.new(_package, "advanced", 8)
	var decoy_events: int = 0
	var decoy_failures: int = 0
	for event: EventRecord in _generated(advanced):
		if event.tags.has("decoy"):
			decoy_events += 1
			if event.result == "failure":
				decoy_failures += 1
	check_eq(decoy_events, 9, "three decoy bursts of three events at advanced")
	check_eq(decoy_failures, 6, "each burst is two failures then a success")


func test_reset_restores_the_exact_baseline() -> void:
	var session: LabSession = LabSession.new(_package, "advanced", 77)
	var baseline: String = session.state_hash()
	session.store.add(EventRecord.from_dict({"id": "evt_intruder", "tick": 5}))
	session.store.remove("evt_001")
	session.store.get_event("evt_003").result = "failure"
	session.store.get_event("evt_002").actor = "someone.else"
	check(session.state_hash() != baseline, "mutations change the state")
	session.reset()
	check_eq(session.state_hash(), baseline, "reset returns to the identical state")
	check(session.store.has_event("evt_001"), "removed events are back")
	check(not session.store.has_event("evt_intruder"), "added events are gone")


func test_reset_signals_and_is_repeatable() -> void:
	var session: LabSession = LabSession.new(_package, "standard", 4)
	var baseline: String = session.state_hash()
	var resets: Array[int] = [0]
	session.session_reset.connect(func() -> void: resets[0] += 1)
	for _i: int in 3:
		session.store.remove("evt_005")
		session.reset()
	check_eq(resets[0], 3, "one signal per reset")
	check_eq(session.state_hash(), baseline, "still the baseline after repeated resets")


func test_play_cannot_corrupt_the_shared_package() -> void:
	var first: LabSession = LabSession.new(_package, "standard", 1)
	var untouched: String = LabSession.new(_package, "standard", 1).state_hash()
	first.store.get_event("evt_001").detail = "tampered"
	first.store.get_event("evt_001").tags.append("tampered")
	check_eq(LabSession.new(_package, "standard", 1).state_hash(), untouched, "a new session is unaffected by edits made in another")
	check_eq(_package.events[0].detail, "Sign-in failed: incorrect password.", "the package events are never edited")


func test_unknown_difficulty_falls_back_to_standard() -> void:
	var odd: LabSession = LabSession.new(_package, "nightmare; rm -rf /", 6)
	check_eq(odd.difficulty, "standard", "difficulty is normalised")
	var standard_hash: String = LabSession.new(_package, "standard", 6).state_hash()
	check_eq(odd.state_hash(), standard_hash, "and behaves exactly as standard")


func test_extreme_seeds_do_not_break_generation() -> void:
	for seed_number: int in [0, -1, 1, 9223372036854775807, -9223372036854775808]:
		var session: LabSession = LabSession.new(_package, "expert", seed_number)
		check(session.store.size() >= 6, "seed %d still builds a session" % seed_number)


func test_missing_noise_settings_yield_no_noise_instead_of_crashing() -> void:
	var bare: ScenarioPackage = ScenarioPackage.from_document({"id": "bare", "events": [], "noise": {}})
	check_eq(ScenarioGenerator.generate(bare, "expert", 1).size(), 0, "no noise config, no noise")
	var mismatched: ScenarioPackage = ScenarioPackage.from_document({"id": "m", "noise": {"accounts": ["a", "b"], "sources": ["x"], "devices": ["y", "z"]}})
	check_eq(ScenarioGenerator.generate(mismatched, "expert", 1).size(), 0, "mismatched lists yield no noise")
	check_eq(LabSession.new(bare).store.size(), 0, "an empty scenario makes an empty session")


func test_scenario_checks_reject_bad_documents() -> void:
	var good: Dictionary = {
		"events": [{"id": "e1", "actor": "story.person"}],
		"assets": [], "identities": [],
		"noise": {"accounts": ["n.one"], "sources": ["s"], "devices": ["d"], "day_start_tick": 100, "day_end_tick": 200,
			"counts": {"beginner": 1, "standard": 2, "advanced": 3, "expert": 4}, "decoys": {"beginner": 0, "standard": 0, "advanced": 1, "expert": 2}},
	}
	check(ContentCatalog.scenario_problems(good).is_empty(), "a sound scenario passes")
	var dup: Dictionary = good.duplicate(true)
	dup["events"].append({"id": "e1", "actor": "x"})
	check(not ContentCatalog.scenario_problems(dup).is_empty(), "duplicate event ids caught")
	var clash: Dictionary = good.duplicate(true)
	clash["noise"]["accounts"] = ["story.person"]
	check(not ContentCatalog.scenario_problems(clash).is_empty(), "noise reusing a story actor caught")
	var backwards: Dictionary = good.duplicate(true)
	backwards["noise"]["day_end_tick"] = 50
	check(not ContentCatalog.scenario_problems(backwards).is_empty(), "inverted day window caught")
	var shrinking: Dictionary = good.duplicate(true)
	shrinking["noise"]["counts"]["advanced"] = 0
	check(not ContentCatalog.scenario_problems(shrinking).is_empty(), "less noise at a harder level caught")
	var uneven: Dictionary = good.duplicate(true)
	uneven["noise"]["devices"] = []
	check(not ContentCatalog.scenario_problems(uneven).is_empty(), "uneven noise lists caught")
