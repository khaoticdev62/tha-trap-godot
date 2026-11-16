class_name CaseFile
extends RefCounted
## The player's case for one lab: severity, the assets they believe are
## affected, and a list of facts, hypotheses and unknowns. A fact must cite
## evidence from the ledger; the other kinds may. Ids (ce_001, ...) are never
## reused.

const SEVERITIES: Array[String] = ["unset", "low", "medium", "high", "critical"]
const CASE_ID: String = "CASE-001"
const MAX_ENTRIES: int = 50
const MAX_TEXT_CHARS: int = 300
const MAX_EVIDENCE_PER_ENTRY: int = 10
const MAX_SCOPE_ASSETS: int = 20
const MAX_SUMMARY_CHARS: int = 600
const ID_PREFIX: String = "ce_"

var severity: String = SEVERITIES[0]
## Asset ids the player believes are affected.
var scope: PackedStringArray = PackedStringArray()
## Id of the chosen response option, or "".
var recommendation: String = ""
## Id of who the case is escalated to, or "".
var escalation: String = ""
## The player's short written summary for the report.
var report_summary: String = ""

var _entries: Array[CaseEntry] = []
var _next_number: int = 1


func entries() -> Array[CaseEntry]:
	return _entries.duplicate()


func get_entry(id: String) -> CaseEntry:
	for entry: CaseEntry in _entries:
		if entry.id == id:
			return entry
	return null


func cites(evidence_id: String) -> String:
	for entry: CaseEntry in _entries:
		if entry.evidence_ids.has(evidence_id):
			return entry.id
	return ""


func add_entry(kind: String, text: String, evidence_ids: PackedStringArray, ledger: EvidenceLedger) -> ActionResult:
	if not CaseEntry.KINDS.has(kind):
		return ActionResult.failure("An entry is a fact, a hypothesis or an unknown (you wrote '%s')." % _clip(kind))
	if SimText.has_forbidden(text):
		return ActionResult.failure("The text contains characters that are not allowed. Use plain text on one line.")
	var cleaned: String = SimText.tidy(text)
	if cleaned.is_empty():
		return ActionResult.failure("Write what you found, in a sentence.")
	if cleaned.length() > MAX_TEXT_CHARS:
		return ActionResult.failure("That is %d characters; the limit is %d." % [cleaned.length(), MAX_TEXT_CHARS])
	if evidence_ids.size() > MAX_EVIDENCE_PER_ENTRY:
		return ActionResult.failure("One entry can cite at most %d pieces of evidence." % MAX_EVIDENCE_PER_ENTRY)
	var cited: PackedStringArray = PackedStringArray()
	for evidence_id: String in evidence_ids:
		if not ledger.has_record(evidence_id):
			return ActionResult.failure("There is no evidence called '%s'. Type evidence list to see what you have." % _clip(evidence_id))
		if not cited.has(evidence_id):
			cited.append(evidence_id)
	if kind == "fact" and cited.is_empty():
		return ActionResult.failure("A fact needs evidence behind it. Collect evidence, then cite it with evidence=ev_001. If you are not sure yet, record it as a hypothesis.")
	if _entries.size() >= MAX_ENTRIES:
		return ActionResult.failure("The case file is full (%d entries)." % MAX_ENTRIES)
	var entry: CaseEntry = CaseEntry.new()
	entry.id = "%s%03d" % [ID_PREFIX, _next_number]
	_next_number += 1
	entry.kind = kind
	entry.text = cleaned
	entry.evidence_ids = cited
	_entries.append(entry)
	return ActionResult.success(entry.id, "Recorded %s as a %s." % [entry.id, kind])


func remove_entry(id: String) -> bool:
	for index: int in _entries.size():
		if _entries[index].id == id:
			_entries.remove_at(index)
			return true
	return false


func set_severity(level: String) -> ActionResult:
	if level == "unset" or not SEVERITIES.has(level):
		return ActionResult.failure("Severity must be one of: %s." % ", ".join(PackedStringArray(SEVERITIES.slice(1))))
	if severity == level:
		return ActionResult.unchanged(level, "Severity is already %s." % level)
	severity = level
	return ActionResult.success(level, "Severity set to %s." % level)


## `asset_ids` are real asset ids (already resolved by the caller).
func set_scope(asset_ids: PackedStringArray) -> ActionResult:
	if asset_ids.is_empty():
		return ActionResult.failure("Name at least one asset, for example: case scope host_014")
	if asset_ids.size() > MAX_SCOPE_ASSETS:
		return ActionResult.failure("Scope can list at most %d assets." % MAX_SCOPE_ASSETS)
	var unique: PackedStringArray = PackedStringArray()
	for asset_id: String in asset_ids:
		if not unique.has(asset_id):
			unique.append(asset_id)
	scope = unique
	return ActionResult.success(CASE_ID, "Scope set to %s." % ", ".join(unique))


## `allowed` are the option ids the scenario offers.
func set_recommendation(option_id: String, allowed: PackedStringArray) -> ActionResult:
	if not allowed.has(option_id):
		return ActionResult.failure("That is not one of the responses on offer. Type case recommend to see them.")
	if recommendation == option_id:
		return ActionResult.unchanged(option_id, "That is already your recommendation.")
	recommendation = option_id
	return ActionResult.success(option_id, "Recommendation set.")


func set_escalation(option_id: String, allowed: PackedStringArray) -> ActionResult:
	if not allowed.has(option_id):
		return ActionResult.failure("That is not someone you can escalate to. Type case escalate to see the choices.")
	if escalation == option_id:
		return ActionResult.unchanged(option_id, "You already chose that.")
	escalation = option_id
	return ActionResult.success(option_id, "Escalation set.")


func set_report_summary(text: String) -> ActionResult:
	if SimText.has_forbidden(text):
		return ActionResult.failure("The summary contains characters that are not allowed. Use plain text on one line.")
	var cleaned: String = SimText.tidy(text)
	if cleaned.is_empty():
		return ActionResult.failure("Write a sentence or two: what happened and what you recommend.")
	if cleaned.length() > MAX_SUMMARY_CHARS:
		return ActionResult.failure("That summary is %d characters; the limit is %d." % [cleaned.length(), MAX_SUMMARY_CHARS])
	if cleaned == report_summary:
		return ActionResult.unchanged("", "The summary is unchanged.")
	report_summary = cleaned
	return ActionResult.success("", "Summary saved.")


func to_dict() -> Dictionary:
	var rows: Array = []
	for entry: CaseEntry in _entries:
		rows.append(entry.to_dict())
	return {
		"severity": severity, "scope": Array(scope), "next": _next_number, "entries": rows,
		"recommendation": recommendation, "escalation": escalation, "report_summary": report_summary,
	}


## Replaces the contents from saved data, but only if every part is valid.
func load_from_dict(data: Variant, ledger: EvidenceLedger, known_asset_ids: PackedStringArray, response_ids: PackedStringArray = PackedStringArray(), escalation_ids: PackedStringArray = PackedStringArray()) -> ActionResult:
	if typeof(data) != TYPE_DICTIONARY:
		return ActionResult.failure("Case data is not readable.")
	var source: Dictionary = data
	var level: String = str(source.get("severity", SEVERITIES[0]))
	if typeof(source.get("severity", SEVERITIES[0])) != TYPE_STRING or not SEVERITIES.has(level):
		return ActionResult.failure("Case data has an invalid severity.")
	var raw_scope: Variant = source.get("scope", [])
	var loaded_scope: PackedStringArray = PackedStringArray()
	if typeof(raw_scope) != TYPE_ARRAY or (raw_scope as Array).size() > MAX_SCOPE_ASSETS:
		return ActionResult.failure("Case data has an invalid scope.")
	for asset: Variant in raw_scope:
		if typeof(asset) != TYPE_STRING or not known_asset_ids.has(asset) or loaded_scope.has(asset):
			return ActionResult.failure("Case data lists an unknown asset.")
		loaded_scope.append(asset)
	var chosen_response: Variant = source.get("recommendation", "")
	var chosen_escalation: Variant = source.get("escalation", "")
	var summary: Variant = source.get("report_summary", "")
	if typeof(chosen_response) != TYPE_STRING or (chosen_response != "" and not response_ids.has(chosen_response)):
		return ActionResult.failure("Case data has an invalid recommendation.")
	if typeof(chosen_escalation) != TYPE_STRING or (chosen_escalation != "" and not escalation_ids.has(chosen_escalation)):
		return ActionResult.failure("Case data has an invalid escalation.")
	if typeof(summary) != TYPE_STRING or summary.length() > MAX_SUMMARY_CHARS or SimText.has_forbidden(summary):
		return ActionResult.failure("Case data has an invalid summary.")
	var raw_entries: Variant = source.get("entries", [])
	if typeof(raw_entries) != TYPE_ARRAY or (raw_entries as Array).size() > MAX_ENTRIES:
		return ActionResult.failure("Case data has an invalid entry list.")
	var loaded: Array[CaseEntry] = []
	var seen: Dictionary = {}
	var highest: int = 0
	for raw: Variant in raw_entries:
		if typeof(raw) != TYPE_DICTIONARY:
			return ActionResult.failure("Case data has an invalid entry.")
		var row: Dictionary = raw
		var id: String = str(row.get("id", ""))
		var number: int = _number_of(id)
		if number < 1 or seen.has(id):
			return ActionResult.failure("Case data has an invalid or repeated entry id.")
		var kind_value: Variant = row.get("kind")
		var text_value: Variant = row.get("text")
		var raw_evidence: Variant = row.get("evidence_ids", [])
		if typeof(kind_value) != TYPE_STRING or not CaseEntry.KINDS.has(kind_value) or typeof(text_value) != TYPE_STRING or typeof(raw_evidence) != TYPE_ARRAY:
			return ActionResult.failure("Case entry %s is not valid." % id)
		var text: String = text_value
		if text.is_empty() or text.length() > MAX_TEXT_CHARS or SimText.has_forbidden(text) or (raw_evidence as Array).size() > MAX_EVIDENCE_PER_ENTRY:
			return ActionResult.failure("Case entry %s has invalid text or evidence." % id)
		var cited: PackedStringArray = PackedStringArray()
		for evidence_value: Variant in raw_evidence:
			if typeof(evidence_value) != TYPE_STRING or not ledger.has_record(evidence_value) or cited.has(evidence_value):
				return ActionResult.failure("Case entry %s cites evidence that does not exist." % id)
			cited.append(evidence_value)
		if kind_value == "fact" and cited.is_empty():
			return ActionResult.failure("Case entry %s is a fact with no evidence." % id)
		var entry: CaseEntry = CaseEntry.new()
		entry.id = id
		entry.kind = kind_value
		entry.text = text
		entry.evidence_ids = cited
		loaded.append(entry)
		seen[id] = true
		highest = maxi(highest, number)
	var next_value: Variant = source.get("next", highest + 1)
	if typeof(next_value) not in [TYPE_INT, TYPE_FLOAT]:
		return ActionResult.failure("Case data has an invalid counter.")
	severity = level
	scope = loaded_scope
	recommendation = chosen_response
	escalation = chosen_escalation
	report_summary = summary
	_entries = loaded
	_next_number = maxi(int(next_value), highest + 1)
	return ActionResult.success()


static func _number_of(id: String) -> int:
	if not id.begins_with(ID_PREFIX) or id.length() <= ID_PREFIX.length() or id.length() > ID_PREFIX.length() + 6:
		return 0
	var digits: String = id.substr(ID_PREFIX.length())
	for index: int in digits.length():
		var code: int = digits.unicode_at(index)
		if code < 0x30 or code > 0x39:
			return 0
	return int(digits)


static func _clip(text: String) -> String:
	return text if text.length() <= 24 else text.left(24) + "..."
