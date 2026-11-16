class_name LabSession
extends RefCounted
## One running attempt at a lab. Owns the event store, the evidence ledger and
## the case file, and can return to its exact starting state with reset(). It
## is the only object the UI and terminal change; it never touches the scene
## tree, the clock, the filesystem or the network, so it runs the same in
## headless tests and in the game.

signal session_reset
signal evidence_changed
signal case_changed

const SNAPSHOT_VERSION: int = 1

var package: ScenarioPackage
var difficulty: String
var seed_value: int
var store: EventStore = EventStore.new()
var ledger: EvidenceLedger = EvidenceLedger.new()
var case_file: CaseFile = CaseFile.new()


func _init(scenario: ScenarioPackage, difficulty_id: String = ScenarioGenerator.DEFAULT_DIFFICULTY, seed_number: int = 0) -> void:
	package = scenario
	difficulty = ScenarioGenerator.normalise_difficulty(difficulty_id)
	seed_value = seed_number
	_rebuild()


## Discards every change made during the attempt and restores the baseline.
func reset() -> void:
	_rebuild()
	session_reset.emit()


## Fingerprint of everything that defines this session's state.
func state_hash() -> String:
	var summary: String = "%s|%s|%d|%s|%s" % [package.id, difficulty, seed_value, store.canonical_json(), JSON.stringify(_player_state(), "", true, true)]
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(summary.to_utf8_buffer())
	return hasher.finish().hex_encode()


# --- evidence ---------------------------------------------------------------

## `event_refs` may be internal ids (evt_004) or display ids (EVT-004).
func add_evidence(event_refs: PackedStringArray, note: String = "") -> ActionResult:
	var ids: PackedStringArray = PackedStringArray()
	for reference: String in event_refs:
		var resolved: String = store.resolve_id(reference)
		if resolved.is_empty():
			return ActionResult.failure("I can't find an event called '%s'. Event ids look like EVT-001; logs search shows them." % _clip(reference))
		ids.append(resolved)
	var result: ActionResult = ledger.add(ids, note, store)
	if result.changed:
		evidence_changed.emit()
	return result


func remove_evidence(evidence_id: String) -> ActionResult:
	var wanted: String = evidence_id.to_lower()
	if not ledger.has_record(wanted):
		return ActionResult.failure("There is no evidence called '%s'. Type evidence list to see what you have." % _clip(evidence_id))
	var citing: String = case_file.cites(wanted)
	if not citing.is_empty():
		return ActionResult.failure("%s is cited by case entry %s. Remove or change that entry first." % [wanted, citing])
	ledger.remove(wanted)
	evidence_changed.emit()
	return ActionResult.success(wanted, "Removed %s." % wanted)


# --- case file --------------------------------------------------------------

func add_case_entry(kind: String, text: String, evidence_refs: PackedStringArray = PackedStringArray()) -> ActionResult:
	var cited: PackedStringArray = PackedStringArray()
	for reference: String in evidence_refs:
		cited.append(reference.to_lower())
	var result: ActionResult = case_file.add_entry(kind, text, cited, ledger)
	if result.changed:
		case_changed.emit()
	return result


func remove_case_entry(entry_id: String) -> ActionResult:
	var wanted: String = entry_id.to_lower()
	if not case_file.remove_entry(wanted):
		return ActionResult.failure("There is no case entry called '%s'. Type case show to see them." % _clip(entry_id))
	case_changed.emit()
	return ActionResult.success(wanted, "Removed %s." % wanted)


func set_severity(level: String) -> ActionResult:
	var result: ActionResult = case_file.set_severity(level.to_lower())
	if result.changed:
		case_changed.emit()
	return result


## `asset_refs` may be asset ids (host_014) or names (HOST-014).
func set_scope(asset_refs: PackedStringArray) -> ActionResult:
	var ids: PackedStringArray = PackedStringArray()
	for reference: String in asset_refs:
		var resolved: String = _resolve_asset(reference)
		if resolved.is_empty():
			return ActionResult.failure("I can't find an asset called '%s'. Type assets list to see them." % _clip(reference))
		ids.append(resolved)
	var result: ActionResult = case_file.set_scope(ids)
	if result.changed:
		case_changed.emit()
	return result


func build_timeline() -> Array[Dictionary]:
	return TimelineBuilder.build(store, ledger)


# --- snapshots (for saving and resuming) ------------------------------------

## Everything the player has done, as plain JSON-safe data. The events
## themselves are not stored: they are rebuilt from the scenario, difficulty
## and seed.
func snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"scenario_id": package.id,
		"difficulty": difficulty,
		"seed": str(seed_value),  # text: JSON numbers cannot hold every 64-bit seed exactly
		"player": _player_state(),
	}


## Applies a snapshot made for this same scenario, difficulty and seed. Nothing
## changes unless the whole snapshot is valid.
func restore(data: Variant) -> ActionResult:
	if typeof(data) != TYPE_DICTIONARY:
		return ActionResult.failure("The saved progress is not readable.")
	var source: Dictionary = data
	if int(_number(source.get("version"), -1)) != SNAPSHOT_VERSION:
		return ActionResult.failure("The saved progress is from a different version.")
	if str(source.get("scenario_id", "")) != package.id or str(source.get("difficulty", "")) != difficulty or str(source.get("seed", "")) != str(seed_value):
		return ActionResult.failure("The saved progress belongs to a different attempt of this lab.")
	var player: Variant = source.get("player")
	if typeof(player) != TYPE_DICTIONARY:
		return ActionResult.failure("The saved progress is missing its case data.")
	var staged_ledger: EvidenceLedger = EvidenceLedger.new()
	var staged_case: CaseFile = CaseFile.new()
	var ledger_result: ActionResult = staged_ledger.load_from_dict((player as Dictionary).get("evidence"), store)
	if not ledger_result.ok:
		return ledger_result
	var case_result: ActionResult = staged_case.load_from_dict((player as Dictionary).get("case"), staged_ledger, _asset_ids())
	if not case_result.ok:
		return case_result
	ledger = staged_ledger
	case_file = staged_case
	evidence_changed.emit()
	case_changed.emit()
	return ActionResult.success()


## Describes anything inconsistent in the live state. Empty when healthy.
## Used by tests to prove no sequence of actions can corrupt the lab.
func state_problems() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if ledger.size() > EvidenceLedger.MAX_RECORDS:
		problems.append("too many evidence records")
	for record: EvidenceRecord in ledger.all():
		if record.event_ids.is_empty():
			problems.append("%s has no events" % record.id)
		for event_id: String in record.event_ids:
			if not store.has_event(event_id):
				problems.append("%s cites missing event %s" % [record.id, event_id])
	if not CaseFile.SEVERITIES.has(case_file.severity):
		problems.append("invalid severity")
	for asset_id: String in case_file.scope:
		if not _asset_ids().has(asset_id):
			problems.append("scope lists unknown asset %s" % asset_id)
	if case_file.entries().size() > CaseFile.MAX_ENTRIES:
		problems.append("too many case entries")
	for entry: CaseEntry in case_file.entries():
		if entry.kind == "fact" and entry.evidence_ids.is_empty():
			problems.append("%s is a fact without evidence" % entry.id)
		for evidence_id: String in entry.evidence_ids:
			if not ledger.has_record(evidence_id):
				problems.append("%s cites missing evidence %s" % [entry.id, evidence_id])
	return problems


# --- internals --------------------------------------------------------------

func _rebuild() -> void:
	store = EventStore.new()
	ledger = EvidenceLedger.new()
	case_file = CaseFile.new()
	# Copies, so changing a record during play can never alter the package.
	for authored: EventRecord in package.events:
		store.add(EventRecord.from_dict(authored.to_dict()))
	for generated: EventRecord in ScenarioGenerator.generate(package, difficulty, seed_value):
		store.add(generated)


func _player_state() -> Dictionary:
	return {"evidence": ledger.to_dict(), "case": case_file.to_dict()}


func _asset_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for asset: Dictionary in package.assets:
		ids.append(str(asset.get("id", "")))
	return ids


func _resolve_asset(reference: String) -> String:
	var wanted: String = reference.strip_edges().to_lower()
	for asset: Dictionary in package.assets:
		if str(asset.get("id", "")).to_lower() == wanted or str(asset.get("name", "")).to_lower() == wanted:
			return str(asset.get("id", ""))
	return ""


static func _number(value: Variant, fallback: float) -> float:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func _clip(text: String) -> String:
	return text if text.length() <= 24 else text.left(24) + "..."
