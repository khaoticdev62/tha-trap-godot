class_name QueryExecutor
extends RefCounted
## Runs a ParsedQuery over an EventStore. A plain linear scan: no indexes, no
## dynamic evaluation, and a work budget so no query can stall the game.

## (events x condition nodes) above this is refused.
const MAX_WORK: int = 2000000

const RAW_COLUMNS: Array[String] = ["event_id", "time", "user", "source_ip", "device", "result", "detail"]


static func execute(query: ParsedQuery, store: EventStore) -> QueryResult:
	var events: Array[EventRecord] = store.all()
	if events.size() * maxi(1, query.node_count) > MAX_WORK:
		return QueryResult.failure(QueryResult.Code.TOO_EXPENSIVE, "That search would take too long. Add filters or a time range.")

	var matches: Array[EventRecord] = []
	for event: EventRecord in events:
		if not query.source.is_empty() and event.source != query.source:
			continue
		if query.after_tick >= 0 and event.tick < query.after_tick:
			continue
		if query.before_tick >= 0 and event.tick >= query.before_tick:
			continue
		if not query.condition.is_empty() and not _matches(query.condition, event):
			continue
		matches.append(event)

	var result: QueryResult = QueryResult.new()
	var entries: Array[Dictionary] = []  # {cells, ids, sort_text, sort_number}
	if not query.group_by.is_empty():
		result.columns = PackedStringArray([query.group_by, "count"])
		entries = _group(matches, query.group_by)
	elif query.count_only:
		result.columns = PackedStringArray(["count"])
		var all_ids: PackedStringArray = PackedStringArray()
		for event: EventRecord in matches:
			all_ids.append(event.id)
		entries.append({"cells": PackedStringArray([str(matches.size())]), "ids": all_ids, "key": "count", "count": matches.size(), "order": 0})
	else:
		result.columns = PackedStringArray(RAW_COLUMNS)
		for index: int in matches.size():
			var event: EventRecord = matches[index]
			entries.append({
				"cells": PackedStringArray([event.display_id, EventRecord.clock_text(event.tick), event.actor, event.ip_label, event.device, event.result, event.detail]),
				"ids": PackedStringArray([event.id]),
				"event": event,
				"order": index,
			})

	_sort(entries, query)
	result.matched_count = entries.size()
	if entries.size() > query.limit:
		result.truncated = true
		entries.resize(query.limit)
	for entry: Dictionary in entries:
		result.rows.append(entry["cells"])
		result.row_event_ids.append(entry["ids"])
	return result


## The text value of a field for an event (used for comparing, grouping and sorting).
static func field_value(event: EventRecord, field: String) -> String:
	match field:
		"event_id":
			return event.display_id
		"time":
			return EventRecord.clock_text(event.tick)
		"user":
			return event.actor
		"source_ip":
			return event.ip_label
		"device":
			return event.device
		"result":
			return event.result
		"detail":
			return event.detail
		"tags":
			return " ".join(event.tags)
	return ""


static func _matches(node: Dictionary, event: EventRecord) -> bool:
	match node.get("op", ""):
		"or":
			for item: Dictionary in node["items"]:
				if _matches(item, event):
					return true
			return false
		"and":
			for item: Dictionary in node["items"]:
				if not _matches(item, event):
					return false
			return true
		"not":
			return not _matches(node["item"], event)
		"cmp":
			var actual: String = field_value(event, node["field"]).to_lower()
			var wanted: String = String(node["value"]).to_lower()
			match node["cmp"]:
				"=":
					return actual == wanted
				"!=":
					return actual != wanted
				"contains":
					return actual.contains(wanted)
	return false


static func _group(matches: Array[EventRecord], field: String) -> Array[Dictionary]:
	var groups: Dictionary = {}  # key -> entry
	var order: int = 0
	for event: EventRecord in matches:
		var key: String = field_value(event, field)
		if not groups.has(key):
			groups[key] = {"cells": PackedStringArray([key, "0"]), "ids": [], "key": key, "count": 0, "order": order}
			order += 1
		var entry: Dictionary = groups[key]
		entry["count"] += 1
		(entry["ids"] as Array).append(event.id)
	var entries: Array[Dictionary] = []
	for key: String in groups:
		var entry: Dictionary = groups[key]
		entry["cells"] = PackedStringArray([entry["key"], str(entry["count"])])
		entry["ids"] = PackedStringArray(entry["ids"])
		entries.append(entry)
	return entries


static func _sort(entries: Array[Dictionary], query: ParsedQuery) -> void:
	var grouped: bool = not query.group_by.is_empty() or query.count_only
	var field: String = query.sort_field
	var descending: bool = query.sort_descending
	if field.is_empty():
		if grouped:
			field = "count"
			descending = true
		else:
			return  # raw rows are already in time order
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var comparison: int = _compare(a, b, field, grouped)
		if comparison == 0:
			# Ties keep a fixed order so results never depend on the sort algorithm.
			return a["order"] < b["order"]
		return comparison > 0 if descending else comparison < 0)


## -1, 0 or 1. Counts compare as numbers, times by tick, everything else as text.
static func _compare(a: Dictionary, b: Dictionary, field: String, grouped: bool) -> int:
	if field == "count":
		return signi(int(a["count"]) - int(b["count"]))
	if grouped:
		return _compare_text(String(a["key"]), String(b["key"]))
	var first: EventRecord = a["event"]
	var second: EventRecord = b["event"]
	if field == "time":
		return signi(first.tick - second.tick)
	return _compare_text(field_value(first, field), field_value(second, field))


static func _compare_text(first: String, second: String) -> int:
	var left: String = first.to_lower()
	var right: String = second.to_lower()
	if left == right:
		return 0
	return -1 if left < right else 1
