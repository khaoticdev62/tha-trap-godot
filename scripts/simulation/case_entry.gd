class_name CaseEntry
extends RefCounted
## One statement in the case file. `kind` says how sure the player is:
## a fact is backed by evidence, a hypothesis is a working idea, an unknown is
## a question still open. Keeping them apart is a core investigation skill.

const KINDS: Array[String] = ["fact", "hypothesis", "unknown"]

var id: String = ""
var kind: String = KINDS[1]
var text: String = ""
var evidence_ids: PackedStringArray = PackedStringArray()


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "text": text, "evidence_ids": Array(evidence_ids)}
