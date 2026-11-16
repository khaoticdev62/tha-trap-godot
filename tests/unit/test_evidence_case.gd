extends TestCase
## EvidenceLedger, CaseFile, TimelineBuilder and LabSession snapshots.

var _package: ScenarioPackage
var _session: LabSession


func before_each() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var scenario: ContentResult = loader.load_content("lab_001_scenario")
	check(scenario.ok(), "scenario loads: %s" % str(scenario.errors))
	_package = ScenarioPackage.from_document(scenario.data)
	_session = LabSession.new(_package, "standard", 1)


func _refs(values: Array) -> PackedStringArray:
	return PackedStringArray(values)


# --- evidence ---------------------------------------------------------------

func test_collecting_evidence_by_display_or_internal_id() -> void:
	var seen: Array[int] = [0]
	_session.evidence_changed.connect(func() -> void: seen[0] += 1)
	var first: ActionResult = _session.add_evidence(_refs(["EVT-004"]), "MFA device added")
	check(first.ok and first.id == "ev_001" and first.changed, "first evidence is ev_001: %s" % first.message)
	var second: ActionResult = _session.add_evidence(_refs(["evt_003"]))
	check(second.ok and second.id == "ev_002", "internal ids work too")
	check_eq(seen[0], 2, "one signal per real change")
	check_eq(_session.ledger.get_record("ev_001").note, "MFA device added", "the note is kept")
	check_eq(_session.ledger.get_record("ev_001").event_ids, PackedStringArray(["evt_004"]), "stored under the internal id")


func test_collecting_the_same_events_again_changes_nothing() -> void:
	_session.add_evidence(_refs(["EVT-001", "EVT-002"]))
	var seen: Array[int] = [0]
	_session.evidence_changed.connect(func() -> void: seen[0] += 1)
	var again: ActionResult = _session.add_evidence(_refs(["EVT-002", "evt_001"]))
	check(again.ok and not again.changed and again.id == "ev_001", "same set in another order is the same evidence")
	check(again.message.contains("Already collected"), "the player is told: %s" % again.message)
	check_eq(seen[0], 0, "no signal, because nothing changed")
	check_eq(_session.ledger.size(), 1, "still one record")


func test_bad_evidence_requests_are_refused_with_a_reason() -> void:
	var cases: Dictionary = {
		"unknown event": [_refs(["EVT-999"]), ""],
		"path-like text": [_refs(["../etc/passwd"]), ""],
		"empty list": [_refs([]), ""],
		"empty id": [_refs([""]), ""],
		"too many events": [_refs(["EVT-001", "EVT-002", "EVT-003", "EVT-004", "EVT-005", "EVT-006", "EVT-007", "EVT-008", "evt_n0001", "evt_n0002", "evt_n0003"]), ""],
		"note too long": [_refs(["EVT-001"]), "x".repeat(EvidenceLedger.MAX_NOTE_CHARS + 1)],
		"note with newline": [_refs(["EVT-001"]), "a" + String.chr(10) + "b"],
		"note with bidi override": [_refs(["EVT-001"]), "a" + String.chr(0x202E) + "b"],
	}
	for label: String in cases:
		var result: ActionResult = _session.add_evidence(cases[label][0], cases[label][1])
		check(not result.ok and not result.message.is_empty(), "refused (%s): %s" % [label, result.message])
	check_eq(_session.ledger.size(), 0, "nothing was stored")
	check(_session.state_problems().is_empty(), "state is still healthy")


func test_notes_are_tidied() -> void:
	_session.add_evidence(_refs(["EVT-001"]), "   spaced    out   note  ")
	check_eq(_session.ledger.get_record("ev_001").note, "spaced out note", "edges trimmed and spaces collapsed")


func test_evidence_ids_are_never_reused() -> void:
	_session.add_evidence(_refs(["EVT-001"]))
	_session.add_evidence(_refs(["EVT-002"]))
	check(_session.remove_evidence("ev_001").ok, "removed")
	var next: ActionResult = _session.add_evidence(_refs(["EVT-003"]))
	check_eq(next.id, "ev_003", "the number moves on instead of reusing ev_001")


func test_removing_evidence() -> void:
	_session.add_evidence(_refs(["EVT-001"]))
	check(not _session.remove_evidence("ev_999").ok, "unknown evidence")
	check(_session.remove_evidence("EV_001").ok, "case-insensitive")
	check_eq(_session.ledger.size(), 0, "gone")


func test_evidence_list_has_a_limit() -> void:
	var big: LabSession = LabSession.new(_package, "expert", 5)
	var ids: Array[EventRecord] = big.store.all()
	check(ids.size() > EvidenceLedger.MAX_RECORDS, "enough events to hit the cap (%d)" % ids.size())
	for index: int in EvidenceLedger.MAX_RECORDS:
		check(big.add_evidence(_refs([ids[index].id])).ok, "evidence %d added" % (index + 1))
	var over: ActionResult = big.add_evidence(_refs([ids[EvidenceLedger.MAX_RECORDS].id]))
	check(not over.ok and over.message.contains("full"), "the 51st is refused: %s" % over.message)
	check(big.state_problems().is_empty(), "still healthy")


# --- case file --------------------------------------------------------------

func test_hypotheses_and_unknowns_need_no_evidence_but_facts_do() -> void:
	var hypothesis: ActionResult = _session.add_case_entry("hypothesis", "The account may have been taken over.")
	check(hypothesis.ok and hypothesis.id == "ce_001", "hypothesis recorded: %s" % hypothesis.message)
	check(_session.add_case_entry("unknown", "Was member data copied?").ok, "unknown recorded")
	var bare_fact: ActionResult = _session.add_case_entry("fact", "Two failures came before the success.")
	check(not bare_fact.ok and bare_fact.message.contains("hypothesis"), "a fact without evidence is refused and the fix is explained: %s" % bare_fact.message)
	_session.add_evidence(_refs(["EVT-001", "EVT-002"]))
	var fact: ActionResult = _session.add_case_entry("fact", "Two failed sign-ins came before the success.", _refs(["ev_001"]))
	check(fact.ok, "a fact with evidence is accepted: %s" % fact.message)
	check_eq(_session.case_file.get_entry(fact.id).evidence_ids, PackedStringArray(["ev_001"]), "the citation is stored")


func test_case_entries_reject_bad_input() -> void:
	_session.add_evidence(_refs(["EVT-001"]))
	var cases: Dictionary = {
		"unknown kind": ["conclusion", "text", []],
		"empty text": ["hypothesis", "", []],
		"blank text": ["hypothesis", "     ", []],
		"too long": ["hypothesis", "x".repeat(CaseFile.MAX_TEXT_CHARS + 1), []],
		"newline": ["hypothesis", "a" + String.chr(10) + "b", []],
		"zero width": ["hypothesis", "a" + String.chr(0x200B), []],
		"missing evidence": ["hypothesis", "text", ["ev_404"]],
		"too much evidence": ["hypothesis", "text", ["ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001", "ev_001"]],
	}
	for label: String in cases:
		var spec: Array = cases[label]
		var result: ActionResult = _session.add_case_entry(spec[0], spec[1], _refs(spec[2]))
		check(not result.ok and not result.message.is_empty(), "refused (%s): %s" % [label, result.message])
	check_eq(_session.case_file.entries().size(), 0, "nothing was stored")


func test_case_text_may_hold_unicode_and_markup_as_plain_text() -> void:
	var text: String = "Café 🙂 مرحبا <b>bold</b> [url=x]link[/url] $(x)"
	var result: ActionResult = _session.add_case_entry("hypothesis", text)
	check(result.ok, "accepted as text: %s" % result.message)
	check_eq(_session.case_file.get_entry(result.id).text, text, "stored exactly, never interpreted")


func test_case_entry_limit_and_id_reuse() -> void:
	for index: int in CaseFile.MAX_ENTRIES:
		check(_session.add_case_entry("unknown", "question %d" % index).ok, "entry %d" % index)
	check(not _session.add_case_entry("unknown", "one too many").ok, "the case file has a limit")
	check(_session.remove_case_entry("ce_001").ok, "removed")
	check(not _session.remove_case_entry("ce_001").ok, "not removable twice")
	check_eq(_session.add_case_entry("unknown", "after removal").id, "ce_051", "ids are not reused")


func test_evidence_cited_by_the_case_cannot_be_removed() -> void:
	_session.add_evidence(_refs(["EVT-003"]))
	_session.add_case_entry("fact", "A sign-in succeeded from a new source.", _refs(["ev_001"]))
	var blocked: ActionResult = _session.remove_evidence("ev_001")
	check(not blocked.ok and blocked.message.contains("ce_001"), "the citing entry is named: %s" % blocked.message)
	check(_session.remove_case_entry("ce_001").ok, "remove the entry first")
	check(_session.remove_evidence("ev_001").ok, "then the evidence can go")
	check(_session.state_problems().is_empty(), "state healthy")


func test_severity() -> void:
	check_eq(_session.case_file.severity, "unset", "starts unset")
	for bad: String in ["", "unset", "urgent", "HIGHEST", "high; drop"]:
		check(not _session.set_severity(bad).ok, "rejected: '%s'" % bad)
	check(_session.set_severity("HIGH").ok, "case-insensitive")
	check_eq(_session.case_file.severity, "high", "stored in lower case")
	var again: ActionResult = _session.set_severity("high")
	check(again.ok and not again.changed, "setting the same value is not a change")


func test_scope_by_id_or_name() -> void:
	check(_session.set_scope(_refs(["host_014", "Member support portal"])).ok, "ids and names both resolve")
	check_eq(_session.case_file.scope, PackedStringArray(["host_014", "member_portal"]), "stored as asset ids")
	check(_session.set_scope(_refs(["HOST-014", "host_014"])).ok, "duplicates collapse")
	check_eq(_session.case_file.scope, PackedStringArray(["host_014"]), "one entry")
	check(not _session.set_scope(_refs(["host_999"])).ok, "unknown asset refused")
	check(not _session.set_scope(_refs([])).ok, "empty scope refused")
	check_eq(_session.case_file.scope, PackedStringArray(["host_014"]), "a refused change leaves the scope alone")


func test_case_signals() -> void:
	var seen: Array[int] = [0]
	_session.case_changed.connect(func() -> void: seen[0] += 1)
	_session.add_case_entry("unknown", "q")
	_session.set_severity("low")
	_session.set_severity("low")
	_session.set_scope(_refs(["host_014"]))
	_session.add_case_entry("conclusion", "bad")
	check_eq(seen[0], 3, "signals only for real changes")


# --- timeline ---------------------------------------------------------------

func test_timeline_orders_collected_events_by_time() -> void:
	check(_session.build_timeline().is_empty(), "empty without evidence")
	_session.add_evidence(_refs(["EVT-004"]))
	_session.add_evidence(_refs(["EVT-001"]))
	_session.add_evidence(_refs(["EVT-003"]), "new source")
	_session.add_evidence(_refs(["EVT-001", "EVT-002"]))
	var items: Array[Dictionary] = _session.build_timeline()
	var order: PackedStringArray = PackedStringArray()
	for item: Dictionary in items:
		order.append(item["display_id"])
	check_eq(",".join(order), "EVT-001,EVT-002,EVT-003,EVT-004", "time order, each event once")
	check_eq(items[0]["time"], "09:12", "clock time")
	check_eq(items[0]["minutes_since_first"], 0, "first event is the origin")
	check_eq(items[2]["minutes_since_first"], 4, "09:16 is four minutes after 09:12")
	check_eq(items[3]["minutes_since_first"], 7, "09:19 is seven minutes after 09:12")
	check_eq(items[0]["evidence_ids"], PackedStringArray(["ev_002", "ev_004"]), "an event lists every evidence item citing it")


# --- reset and snapshots ----------------------------------------------------

func _investigate(session: LabSession) -> void:
	session.add_evidence(_refs(["EVT-001", "EVT-002"]), "failures")
	session.add_evidence(_refs(["EVT-003"]))
	session.add_evidence(_refs(["EVT-004"]), "MFA change")
	session.add_case_entry("fact", "Two failures then a success from a new source.", _refs(["ev_001", "ev_002"]))
	session.add_case_entry("hypothesis", "The password was guessed or reused.")
	session.add_case_entry("unknown", "Was any member data copied?")
	session.set_severity("high")
	session.set_scope(_refs(["host_014", "member_portal"]))


func test_reset_clears_the_case_and_returns_to_baseline() -> void:
	var baseline: String = _session.state_hash()
	_investigate(_session)
	check(_session.state_hash() != baseline, "the investigation changes the state")
	_session.reset()
	check_eq(_session.state_hash(), baseline, "reset returns to the exact baseline")
	check_eq(_session.ledger.size(), 0, "no evidence")
	check_eq(_session.case_file.entries().size(), 0, "no entries")
	check_eq(_session.case_file.severity, "unset", "severity cleared")
	check_eq(_session.add_evidence(_refs(["EVT-001"])).id, "ev_001", "counters restart too")


func test_snapshot_round_trips_through_json() -> void:
	_investigate(_session)
	var text: String = JSON.stringify(_session.snapshot(), "", true, true)
	var parsed: Variant = JSON.parse_string(text)
	var fresh: LabSession = LabSession.new(_package, "standard", 1)
	var restored: ActionResult = fresh.restore(parsed)
	check(restored.ok, "restores: %s" % restored.message)
	check_eq(fresh.state_hash(), _session.state_hash(), "identical state after a save-and-load")
	check_eq(JSON.stringify(fresh.snapshot(), "", true, true), text, "and an identical snapshot")
	check_eq(fresh.add_evidence(_refs(["EVT-005"])).id, "ev_004", "counters continue where they left off")
	check(fresh.state_problems().is_empty(), "healthy")


func test_snapshot_round_trip_with_a_huge_seed() -> void:
	var seed_number: int = 9223372036854775807
	var big: LabSession = LabSession.new(_package, "advanced", seed_number)
	_investigate(big)
	var parsed: Variant = JSON.parse_string(JSON.stringify(big.snapshot(), "", true, true))
	var fresh: LabSession = LabSession.new(_package, "advanced", seed_number)
	check(fresh.restore(parsed).ok, "a 64-bit seed survives JSON")
	check_eq(fresh.state_hash(), big.state_hash(), "same state")


func test_restore_refuses_a_different_attempt() -> void:
	_investigate(_session)
	var snapshot: Dictionary = _session.snapshot()
	for other: LabSession in [LabSession.new(_package, "standard", 2), LabSession.new(_package, "advanced", 1)]:
		var before: String = other.state_hash()
		check(not other.restore(snapshot).ok, "snapshot refused by a session with other settings")
		check_eq(other.state_hash(), before, "and nothing changed")
	var wrong_scenario: Dictionary = snapshot.duplicate(true)
	wrong_scenario["scenario_id"] = "another_lab"
	check(not LabSession.new(_package, "standard", 1).restore(wrong_scenario).ok, "wrong scenario refused")
	var wrong_version: Dictionary = snapshot.duplicate(true)
	wrong_version["version"] = 99
	check(not LabSession.new(_package, "standard", 1).restore(wrong_version).ok, "wrong version refused")


func test_restore_refuses_corrupt_data_and_changes_nothing() -> void:
	_investigate(_session)
	var good: Dictionary = _session.snapshot()
	var before: String = _session.state_hash()
	var bad_snapshots: Dictionary = {}
	for shape: Variant in ["not a dictionary", 5, null, [], {}]:
		bad_snapshots["shape %s" % str(shape)] = shape
	var variants: Dictionary = {
		"missing player": func(s: Dictionary) -> void: s.erase("player"),
		"evidence cites missing event": func(s: Dictionary) -> void: s["player"]["evidence"]["records"][0]["event_ids"] = ["evt_missing"],
		"evidence without events": func(s: Dictionary) -> void: s["player"]["evidence"]["records"][0]["event_ids"] = [],
		"duplicate evidence ids": func(s: Dictionary) -> void: s["player"]["evidence"]["records"][1]["id"] = "ev_001",
		"bad evidence id": func(s: Dictionary) -> void: s["player"]["evidence"]["records"][0]["id"] = "ev_../x",
		"too many evidence records": func(s: Dictionary) -> void: s["player"]["evidence"]["records"] = range(60).map(func(_n: int) -> Dictionary: return {}),
		"fact without evidence": func(s: Dictionary) -> void: s["player"]["case"]["entries"][0]["evidence_ids"] = [],
		"entry cites missing evidence": func(s: Dictionary) -> void: s["player"]["case"]["entries"][0]["evidence_ids"] = ["ev_404"],
		"bad kind": func(s: Dictionary) -> void: s["player"]["case"]["entries"][1]["kind"] = "conclusion",
		"bad severity": func(s: Dictionary) -> void: s["player"]["case"]["severity"] = "apocalyptic",
		"unknown scope asset": func(s: Dictionary) -> void: s["player"]["case"]["scope"] = ["nothing_here"],
		"newline in text": func(s: Dictionary) -> void: s["player"]["case"]["entries"][1]["text"] = "a\nb",
		"numeric text": func(s: Dictionary) -> void: s["player"]["case"]["entries"][1]["text"] = 5,
		"counter is text": func(s: Dictionary) -> void: s["player"]["evidence"]["next"] = "many",
	}
	for label: String in variants:
		var copy: Dictionary = good.duplicate(true)
		(variants[label] as Callable).call(copy)
		bad_snapshots[label] = copy
	for label: Variant in bad_snapshots:
		var target: LabSession = LabSession.new(_package, "standard", 1)
		_investigate(target)
		var untouched: String = target.state_hash()
		var outcome: ActionResult = target.restore(bad_snapshots[label])
		check(not outcome.ok and not outcome.message.is_empty(), "refused (%s): %s" % [str(label), outcome.message])
		check_eq(target.state_hash(), untouched, "a refused snapshot changes nothing (%s)" % str(label))
	check_eq(_session.state_hash(), before, "the original session was never touched")


func test_state_problems_detects_a_corrupted_lab() -> void:
	check(_session.state_problems().is_empty(), "a new lab is healthy")
	_investigate(_session)
	check(_session.state_problems().is_empty(), "an investigation keeps it healthy")
	_session.store.remove("evt_001")
	check(not _session.state_problems().is_empty(), "evidence citing a deleted event is reported")
