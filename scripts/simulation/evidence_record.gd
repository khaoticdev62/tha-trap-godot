class_name EvidenceRecord
extends RefCounted
## One piece of collected evidence: the log event(s) behind it and an optional
## note. Evidence is how a conclusion points back at what actually happened.

var id: String = ""
var event_ids: PackedStringArray = PackedStringArray()
var note: String = ""


func to_dict() -> Dictionary:
	return {"id": id, "event_ids": Array(event_ids), "note": note}
