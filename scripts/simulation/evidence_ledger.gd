class_name EvidenceLedger
extends RefCounted
## The evidence collected during a lab. Ids (ev_001, ev_002, ...) are never
## reused after a removal, so a reference can never silently point at
## something new. Evidence can only cite events that exist in the EventStore.

const MAX_RECORDS: int = 50
const MAX_EVENTS_PER_RECORD: int = 10
const MAX_NOTE_CHARS: int = 200
const ID_PREFIX: String = "ev_"

var _records: Array[EvidenceRecord] = []
var _next_number: int = 1


## Adds evidence for these (internal) event ids. Asking for the same set of
## events again returns the existing record unchanged.
func add(event_ids: PackedStringArray, note: String, store: EventStore) -> ActionResult:
	if event_ids.is_empty():
		return ActionResult.failure("Choose at least one event to collect, for example: evidence add EVT-004")
	if event_ids.size() > MAX_EVENTS_PER_RECORD:
		return ActionResult.failure("One piece of evidence can hold at most %d events." % MAX_EVENTS_PER_RECORD)
	var unique: PackedStringArray = PackedStringArray()
	for event_id: String in event_ids:
		if not store.has_event(event_id):
			return ActionResult.failure("No event with that id exists in this lab.")
		if not unique.has(event_id):
			unique.append(event_id)
	if SimText.has_forbidden(note):
		return ActionResult.failure("The note contains characters that are not allowed. Use plain text on one line.")
	var cleaned_note: String = SimText.tidy(note)
	if cleaned_note.length() > MAX_NOTE_CHARS:
		return ActionResult.failure("That note is %d characters; the limit is %d." % [cleaned_note.length(), MAX_NOTE_CHARS])
	for existing: EvidenceRecord in _records:
		if _same_events(existing.event_ids, unique):
			return ActionResult.unchanged(existing.id, "Already collected as %s." % existing.id)
	if _records.size() >= MAX_RECORDS:
		return ActionResult.failure("The evidence list is full (%d items). Remove something you no longer need." % MAX_RECORDS)
	var record: EvidenceRecord = EvidenceRecord.new()
	record.id = "%s%03d" % [ID_PREFIX, _next_number]
	_next_number += 1
	record.event_ids = unique
	record.note = cleaned_note
	_records.append(record)
	return ActionResult.success(record.id, "Added %s." % record.id)


func remove(id: String) -> bool:
	for index: int in _records.size():
		if _records[index].id == id:
			_records.remove_at(index)
			return true
	return false


func has_record(id: String) -> bool:
	return get_record(id) != null


func get_record(id: String) -> EvidenceRecord:
	for record: EvidenceRecord in _records:
		if record.id == id:
			return record
	return null


func all() -> Array[EvidenceRecord]:
	return _records.duplicate()


func size() -> int:
	return _records.size()


func to_dict() -> Dictionary:
	var rows: Array = []
	for record: EvidenceRecord in _records:
		rows.append(record.to_dict())
	return {"next": _next_number, "records": rows}


## Replaces the contents from saved data, but only if every part is valid;
## otherwise nothing changes.
func load_from_dict(data: Variant, store: EventStore) -> ActionResult:
	if typeof(data) != TYPE_DICTIONARY:
		return ActionResult.failure("Evidence data is not readable.")
	var source: Dictionary = data
	var raw_records: Variant = source.get("records")
	if typeof(raw_records) != TYPE_ARRAY or (raw_records as Array).size() > MAX_RECORDS:
		return ActionResult.failure("Evidence data has an invalid list.")
	var loaded: Array[EvidenceRecord] = []
	var seen_ids: Dictionary = {}
	var highest: int = 0
	for raw: Variant in raw_records:
		if typeof(raw) != TYPE_DICTIONARY:
			return ActionResult.failure("Evidence data has an invalid entry.")
		var row: Dictionary = raw
		var id: String = str(row.get("id", ""))
		var number: int = _number_of(id)
		if number < 1 or seen_ids.has(id):
			return ActionResult.failure("Evidence data has an invalid or repeated id.")
		var raw_events: Variant = row.get("event_ids")
		if typeof(raw_events) != TYPE_ARRAY or (raw_events as Array).is_empty() or (raw_events as Array).size() > MAX_EVENTS_PER_RECORD:
			return ActionResult.failure("Evidence %s has an invalid event list." % id)
		var events: PackedStringArray = PackedStringArray()
		for event_value: Variant in raw_events:
			var event_id: String = str(event_value)
			if typeof(event_value) != TYPE_STRING or not store.has_event(event_id) or events.has(event_id):
				return ActionResult.failure("Evidence %s cites an event that does not exist." % id)
			events.append(event_id)
		var note: String = str(row.get("note", ""))
		if typeof(row.get("note", "")) != TYPE_STRING or SimText.has_forbidden(note) or note.length() > MAX_NOTE_CHARS:
			return ActionResult.failure("Evidence %s has an invalid note." % id)
		var record: EvidenceRecord = EvidenceRecord.new()
		record.id = id
		record.event_ids = events
		record.note = note
		loaded.append(record)
		seen_ids[id] = true
		highest = maxi(highest, number)
	var next_value: Variant = source.get("next", highest + 1)
	if typeof(next_value) not in [TYPE_INT, TYPE_FLOAT]:
		return ActionResult.failure("Evidence data has an invalid counter.")
	_records = loaded
	_next_number = maxi(int(next_value), highest + 1)
	return ActionResult.success()


static func _same_events(first: PackedStringArray, second: PackedStringArray) -> bool:
	if first.size() != second.size():
		return false
	for event_id: String in first:
		if not second.has(event_id):
			return false
	return true


## The number in "ev_007", or 0 if the text is not an evidence id.
static func _number_of(id: String) -> int:
	if not id.begins_with(ID_PREFIX) or id.length() <= ID_PREFIX.length() or id.length() > ID_PREFIX.length() + 6:
		return 0
	var digits: String = id.substr(ID_PREFIX.length())
	for index: int in digits.length():
		var code: int = digits.unicode_at(index)
		if code < 0x30 or code > 0x39:
			return 0
	return int(digits)
