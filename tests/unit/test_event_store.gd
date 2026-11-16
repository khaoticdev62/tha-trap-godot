extends TestCase
## EventRecord and EventStore.


func _event(id: String, tick: int, actor: String = "a.user") -> EventRecord:
	return EventRecord.from_dict({"id": id, "display_id": id.to_upper(), "tick": tick, "source": "auth", "actor": actor, "result": "success", "ip_label": "int-1", "device": "HOST-1", "detail": "x", "tags": ["t"], "canonical": false})


func test_record_round_trips_through_a_dictionary() -> void:
	var original: EventRecord = _event("evt_x", 100, "j.smith")
	var copy: EventRecord = EventRecord.from_dict(original.to_dict())
	check_eq(copy.to_dict(), original.to_dict(), "to_dict and from_dict are inverse")


func test_record_tolerates_garbage() -> void:
	var record: EventRecord = EventRecord.from_dict({"tick": 99999999, "source": "shell", "result": 5, "tags": "oops", "canonical": "yes"})
	check_eq(record.tick, EventRecord.SECONDS_PER_DAY - 1, "tick is clamped into the day")
	check(EventRecord.SOURCES.has(record.source), "unknown source falls back to a known one")
	check(EventRecord.RESULTS.has(record.result), "unknown result falls back to a known one")
	check(record.tags.is_empty(), "non-array tags are ignored")
	check(not record.canonical, "canonical needs a real true")
	check_eq(EventRecord.from_dict({"tick": -50}).tick, 0, "negative tick clamps to zero")


func test_clock_text() -> void:
	check_eq(EventRecord.clock_text(33120), "09:12", "09:12")
	check_eq(EventRecord.clock_text(0), "00:00", "midnight")
	check_eq(EventRecord.clock_text(86399), "23:59", "end of day")
	check_eq(EventRecord.clock_text(-5), "00:00", "negative clamps")
	check_eq(EventRecord.clock_text(999999), "23:59", "huge clamps")


func test_add_rejects_duplicates_and_empty_ids() -> void:
	var store: EventStore = EventStore.new()
	check(store.add(_event("evt_a", 10)), "first add works")
	check(not store.add(_event("evt_a", 20)), "duplicate id rejected")
	check(not store.add(_event("", 30)), "empty id rejected")
	check_eq(store.size(), 1, "only one event stored")
	check_eq(store.get_event("evt_a").tick, 10, "the original is kept")


func test_events_come_back_in_time_then_id_order() -> void:
	var store: EventStore = EventStore.new()
	store.add(_event("evt_c", 300))
	store.add(_event("evt_b", 100))
	store.add(_event("evt_a", 100))
	store.add(_event("evt_d", 50))
	var ids: PackedStringArray = PackedStringArray()
	for event: EventRecord in store.all():
		ids.append(event.id)
	check_eq(",".join(ids), "evt_d,evt_a,evt_b,evt_c", "sorted by tick, ties by id")
	store.add(_event("evt_e", 75))
	check_eq(store.all()[1].id, "evt_e", "later additions are sorted in too")


func test_remove_and_lookup() -> void:
	var store: EventStore = EventStore.new()
	store.add(_event("evt_a", 1))
	check(store.has_event("evt_a"), "present")
	check(store.remove("evt_a"), "removed")
	check(not store.has_event("evt_a"), "gone")
	check(store.get_event("evt_a") == null, "lookup of a missing id is null")
	check(not store.remove("evt_a"), "removing twice reports false")


func test_all_returns_a_copy_of_the_list() -> void:
	var store: EventStore = EventStore.new()
	store.add(_event("evt_a", 1))
	var listing: Array[EventRecord] = store.all()
	listing.clear()
	check_eq(store.size(), 1, "clearing the returned list does not empty the store")


func test_hash_ignores_insertion_order_and_sees_changes() -> void:
	var first: EventStore = EventStore.new()
	first.add(_event("evt_a", 10))
	first.add(_event("evt_b", 20))
	var second: EventStore = EventStore.new()
	second.add(_event("evt_b", 20))
	second.add(_event("evt_a", 10))
	check_eq(first.content_hash(), second.content_hash(), "same events, same hash")
	second.get_event("evt_a").result = "failure"
	check(first.content_hash() != second.content_hash(), "a changed field changes the hash")
	check_eq(first.content_hash().length(), 64, "hex SHA-256")
	check(EventStore.new().content_hash() == EventStore.new().content_hash(), "empty stores hash alike")
