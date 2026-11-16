class_name Rubric
extends RefCounted
## A lab's scoring rules, read from validated content. It holds data only; the
## AssessmentEngine applies it. Scores always come from evidence the player
## collected and reasoning they wrote, never from a multiple-choice answer alone.

var id: String = ""
var lab_id: String = ""
## Version of the rubric a result was earned under. Stored with every result so
## re-releasing a lab never rewrites an earlier score.
var content_version: String = ""
var max_points: int = 0
var pass_points: int = 0
var criteria: Array[Dictionary] = []
var critical_errors: Array[Dictionary] = []
## option id -> {quality, points, feedback, broad}
var response_scores: Dictionary = {}
## option id -> {points, feedback}
var escalation_scores: Dictionary = {}
var rationale: PackedStringArray = PackedStringArray()


static func from_document(document: Dictionary) -> Rubric:
	var rubric: Rubric = Rubric.new()
	rubric.id = str(document.get("id", ""))
	rubric.lab_id = str(document.get("lab_id", ""))
	rubric.content_version = str(document.get("content_version", ""))
	rubric.max_points = int(document.get("max_points", 0))
	rubric.pass_points = int(document.get("pass_points", 0))
	for raw: Variant in document.get("criteria", []):
		if typeof(raw) == TYPE_DICTIONARY:
			rubric.criteria.append((raw as Dictionary).duplicate(true))
	for raw: Variant in document.get("critical_errors", []):
		if typeof(raw) == TYPE_DICTIONARY:
			rubric.critical_errors.append((raw as Dictionary).duplicate(true))
	for raw: Variant in document.get("response_scores", []):
		if typeof(raw) == TYPE_DICTIONARY:
			var row: Dictionary = (raw as Dictionary).duplicate(true)
			rubric.response_scores[str(row.get("option_id", ""))] = row
	for raw: Variant in document.get("escalation_scores", []):
		if typeof(raw) == TYPE_DICTIONARY:
			var row: Dictionary = (raw as Dictionary).duplicate(true)
			rubric.escalation_scores[str(row.get("option_id", ""))] = row
	for raw: Variant in document.get("rationale", []):
		rubric.rationale.append(str(raw))
	return rubric


## The critical-error definition for a check name, or an empty Dictionary.
func critical_error_for(check: String) -> Dictionary:
	for definition: Dictionary in critical_errors:
		if definition.get("check", "") == check:
			return definition
	return {}
