class_name TimelineBuilder
extends RefCounted
## Builds the investigation timeline: every event the player has collected as
## evidence, in time order, each pointing back at the evidence that cites it.
## Returns plain data; the UI and the terminal decide how to draw it.


## Items: {event_id, display_id, tick, time, minutes_since_first, source, actor,
## result, detail, evidence_ids}
static func build(store: EventStore, ledger: EvidenceLedger) -> Array[Dictionary]:
	var cited_by: Dictionary = {}  # event id -> Array of evidence ids
	for record: EvidenceRecord in ledger.all():
		for event_id: String in record.event_ids:
			if not cited_by.has(event_id):
				cited_by[event_id] = []
			(cited_by[event_id] as Array).append(record.id)
	var items: Array[Dictionary] = []
	var first_tick: int = -1
	for event: EventRecord in store.all():
		if not cited_by.has(event.id):
			continue
		if first_tick < 0:
			first_tick = event.tick
		items.append({
			"event_id": event.id,
			"display_id": event.display_id,
			"tick": event.tick,
			"time": EventRecord.clock_text(event.tick),
			"minutes_since_first": (event.tick - first_tick) / 60,
			"source": event.source,
			"actor": event.actor,
			"result": event.result,
			"detail": event.detail,
			"evidence_ids": PackedStringArray(cited_by[event.id]),
		})
	return items
