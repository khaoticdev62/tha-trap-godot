class_name EventRecord
extends RefCounted
## One synthetic log event. `tick` is seconds since midnight of the scenario
## day (09:12 is 33120). All values are fictional; IP-like labels never refer to
## a real address.

const SOURCES: Array[String] = ["auth", "mfa", "app", "helpdesk"]
const RESULTS: Array[String] = ["success", "failure", "requested", "reported"]
const SECONDS_PER_DAY: int = 86400

## Content schema for one event (used by the scenario schema).
const SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"display_id": {"type": "string", "required": true, "max_length": 16},
		"tick": {"type": "int", "required": true, "min": 0, "max": 86399},
		"source": {"type": "enum", "required": true, "values": SOURCES},
		"actor": {"type": "string", "required": true, "max_length": 32},
		"result": {"type": "enum", "required": true, "values": RESULTS},
		"ip_label": {"type": "string", "required": true, "max_length": 32},
		"device": {"type": "string", "required": true, "max_length": 32},
		"detail": {"type": "string", "required": true, "max_length": 200},
		"tags": {"type": "array", "required": true, "max_items": 8, "items": {"type": "id"}},
		"canonical": {"type": "bool", "required": true},
	},
}

var id: String = ""
var display_id: String = ""
var tick: int = 0
var source: String = SOURCES[0]
var actor: String = ""
var result: String = RESULTS[0]
var ip_label: String = ""
var device: String = ""
var detail: String = ""
var tags: PackedStringArray = PackedStringArray()
var canonical: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_id": display_id,
		"tick": tick,
		"source": source,
		"actor": actor,
		"result": result,
		"ip_label": ip_label,
		"device": device,
		"detail": detail,
		"tags": Array(tags),
		"canonical": canonical,
	}


## Builds a record from a document that already passed the schema. Missing or
## wrongly typed values fall back to harmless defaults.
static func from_dict(data: Dictionary) -> EventRecord:
	var record: EventRecord = EventRecord.new()
	record.id = str(data.get("id", ""))
	record.display_id = str(data.get("display_id", ""))
	record.tick = clampi(int(data.get("tick", 0)), 0, SECONDS_PER_DAY - 1)
	var source_value: String = str(data.get("source", ""))
	record.source = source_value if SOURCES.has(source_value) else SOURCES[0]
	record.actor = str(data.get("actor", ""))
	var result_value: String = str(data.get("result", ""))
	record.result = result_value if RESULTS.has(result_value) else RESULTS[0]
	record.ip_label = str(data.get("ip_label", ""))
	record.device = str(data.get("device", ""))
	record.detail = str(data.get("detail", ""))
	var raw_tags: Variant = data.get("tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for tag: Variant in raw_tags:
			record.tags.append(str(tag))
	record.canonical = Validate.strict_bool(data.get("canonical", false))
	return record


## "09:12" style text for a tick.
static func clock_text(tick_value: int) -> String:
	var minutes_total: int = clampi(tick_value, 0, SECONDS_PER_DAY - 1) / 60
	return "%02d:%02d" % [minutes_total / 60, minutes_total % 60]
