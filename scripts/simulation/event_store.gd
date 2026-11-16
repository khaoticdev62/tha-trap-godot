class_name EventStore
extends RefCounted
## The events of one running lab, kept in (tick, id) order. Owned by a
## LabSession; the UI reads it and never edits it. `content_hash()` fingerprints
## the whole store so tests can prove two runs, or a run and its reset, match.

var _events: Array[EventRecord] = []
var _index: Dictionary = {}
var _sorted: bool = true


## Returns false (and stores nothing) when the id is empty or already present.
func add(event: EventRecord) -> bool:
	if event.id.is_empty() or _index.has(event.id):
		return false
	_events.append(event)
	_index[event.id] = event
	_sorted = false
	return true


func remove(id: String) -> bool:
	if not _index.has(id):
		return false
	_events.erase(_index[id])
	_index.erase(id)
	return true


func has_event(id: String) -> bool:
	return _index.has(id)


func get_event(id: String) -> EventRecord:
	return _index.get(id)


## Turns what a player typed ("EVT-004", "evt_004") into an internal id, or ""
## if no such event exists.
func resolve_id(reference: String) -> String:
	var candidate: String = reference.strip_edges().to_lower().replace("-", "_")
	return candidate if _index.has(candidate) else ""


func size() -> int:
	return _events.size()


## All events in (tick, id) order. A new array each call; the records are shared.
func all() -> Array[EventRecord]:
	_ensure_sorted()
	return _events.duplicate()


## Stable text form: sorted events, sorted keys, no whitespace.
func canonical_json() -> String:
	var rows: Array = []
	for event: EventRecord in all():
		rows.append(event.to_dict())
	return JSON.stringify(rows, "", true, true)


func content_hash() -> String:
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(canonical_json().to_utf8_buffer())
	return hasher.finish().hex_encode()


func _ensure_sorted() -> void:
	if _sorted:
		return
	_events.sort_custom(func(a: EventRecord, b: EventRecord) -> bool:
		return a.tick < b.tick or (a.tick == b.tick and a.id < b.id))
	_sorted = true
