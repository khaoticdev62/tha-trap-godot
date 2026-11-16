class_name ContentCatalog
extends RefCounted
## The game's registered content: which documents exist, their schemas and the
## extra safety checks they must pass. Add a document here when it is added to
## data/. The schema shapes follow 04_LAB_AND_SIMULATION_SPEC §5.

const LAB_ACTIONS: Array[String] = ["search_logs", "inspect_identity", "add_evidence", "write_report"]
## Actions no lab may ever allow, and every lab manifest must explicitly forbid
## (spec 04 §1, decision D-006).
const REQUIRED_FORBIDDEN_ACTIONS: Array[String] = ["host_shell", "external_network", "real_credentials"]

const LAB_MANIFEST_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"display_id": {"type": "string", "required": true, "max_length": 32},
		"aliases": {"type": "array", "max_items": 8, "items": {"type": "string", "max_length": 32}},
		"version": {"type": "string", "required": true, "max_length": 16},
		"title": {"type": "string", "required": true, "max_length": 80},
		"district": {"type": "id", "required": true},
		"difficulty": {"type": "enum", "required": true, "values": ["beginner", "standard", "advanced", "expert", "adaptive"]},
		"estimated_minutes": {"type": "int", "required": true, "min": 1, "max": 600},
		"prerequisites": {"type": "array", "required": true, "max_items": 20, "items": {"type": "id"}},
		"objectives": {"type": "array", "required": true, "max_items": 20, "items": {"type": "string", "max_length": 200}},
		"scenario_data": {"type": "path", "required": true},
		"allowed_actions": {"type": "array", "required": true, "max_items": 16, "items": {"type": "enum", "values": LAB_ACTIONS}},
		"forbidden_actions": {"type": "array", "required": true, "max_items": 16, "items": {"type": "id"}},
		"framework_mappings": {"type": "array", "required": true, "max_items": 50, "items": {"type": "object", "allow_unknown": true}},
		"reset_policy": {"type": "enum", "required": true, "values": ["full_reset"]},
		"portfolio_artifact": {"type": "id", "required": true},
	},
}


const _ASSET_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"kind": {"type": "enum", "required": true, "values": ["workstation", "portal", "identity_provider"]},
		"name": {"type": "string", "required": true, "max_length": 64},
		"owner": {"type": "string", "required": true, "max_length": 32},
		"notes": {"type": "string", "required": true, "max_length": 300},
	},
}

const _IDENTITY_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"account": {"type": "string", "required": true, "max_length": 32},
		"display_name": {"type": "string", "required": true, "max_length": 48},
		"role": {"type": "string", "required": true, "max_length": 64},
		"normal_start_tick": {"type": "int", "required": true, "min": 0, "max": 86399},
		"normal_end_tick": {"type": "int", "required": true, "min": 0, "max": 86399},
		"normal_sources": {"type": "array", "required": true, "max_items": 8, "items": {"type": "string", "max_length": 32}},
		"normal_device": {"type": "string", "required": true, "max_length": 32},
	},
}

const _OPTION_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"label": {"type": "string", "required": true, "max_length": 80},
		"summary": {"type": "string", "required": true, "max_length": 300},
	},
}

const RUBRIC_CHECKS: Array[String] = ["events_collected", "fact_cites_events", "facts_and_hypotheses", "scope_and_severity", "response_quality", "report_quality"]
const CRITICAL_CHECKS: Array[String] = ["unsupported_claim", "broad_response_without_analysis"]

const RUBRIC_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"lab_id": {"type": "id", "required": true},
		"content_version": {"type": "string", "required": true, "max_length": 16},
		"max_points": {"type": "int", "required": true, "min": 1, "max": 1000},
		"pass_points": {"type": "int", "required": true, "min": 0, "max": 1000},
		"criteria": {"type": "array", "required": true, "max_items": 20, "items": {
			"type": "object",
			"fields": {
				"id": {"type": "id", "required": true},
				"title": {"type": "string", "required": true, "max_length": 80},
				"check": {"type": "enum", "required": true, "values": RUBRIC_CHECKS},
				"max_points": {"type": "int", "required": true, "min": 0, "max": 1000},
				"params": {"type": "object", "required": true, "allow_unknown": true},
				"met_feedback": {"type": "string", "required": true, "max_length": 300},
				"partial_feedback": {"type": "string", "required": true, "max_length": 300},
				"unmet_feedback": {"type": "string", "required": true, "max_length": 300},
			},
		}},
		"critical_errors": {"type": "array", "required": true, "max_items": 10, "items": {
			"type": "object",
			"fields": {
				"id": {"type": "id", "required": true},
				"check": {"type": "enum", "required": true, "values": CRITICAL_CHECKS},
				"params": {"type": "object", "required": true, "allow_unknown": true},
				"coaching": {"type": "string", "required": true, "max_length": 500},
			},
		}},
		"response_scores": {"type": "array", "required": true, "max_items": 12, "items": {
			"type": "object",
			"fields": {
				"option_id": {"type": "id", "required": true},
				"quality": {"type": "enum", "required": true, "values": ["best", "acceptable", "weak", "overreach"]},
				"broad": {"type": "bool"},
				"points": {"type": "int", "required": true, "min": 0, "max": 1000},
				"feedback": {"type": "string", "required": true, "max_length": 400},
			},
		}},
		"escalation_scores": {"type": "array", "required": true, "max_items": 12, "items": {
			"type": "object",
			"fields": {
				"option_id": {"type": "id", "required": true},
				"points": {"type": "int", "required": true, "min": 0, "max": 1000},
				"feedback": {"type": "string", "required": true, "max_length": 400},
			},
		}},
		"rationale": {"type": "array", "required": true, "max_items": 12, "items": {"type": "string", "max_length": 400}},
	},
}

const HINTS_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"levels_by_difficulty": {"type": "object", "required": true, "fields": {
			"beginner": {"type": "int", "required": true, "min": 0, "max": 3},
			"standard": {"type": "int", "required": true, "min": 0, "max": 3},
			"advanced": {"type": "int", "required": true, "min": 0, "max": 3},
			"expert": {"type": "int", "required": true, "min": 0, "max": 3},
		}},
		"hints": {"type": "array", "required": true, "max_items": 100, "items": {
			"type": "object",
			"fields": {
				"criterion_id": {"type": "id", "required": true},
				"level": {"type": "int", "required": true, "min": 1, "max": 3},
				"text": {"type": "string", "required": true, "max_length": 300},
			},
		}},
	},
}

const _KNOWLEDGE_OPTION_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"text": {"type": "string", "required": true, "max_length": 200},
		"correct": {"type": "bool", "required": true},
		"feedback": {"type": "string", "required": true, "max_length": 300},
	},
}

## Player-facing teaching text for one mission (briefing, objectives, learning
## goals, formative checks). Scoring never reads this; the rubric does.
const LEARNING_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"mission_id": {"type": "id", "required": true},
		"case_account": {"type": "string", "required": true, "max_length": 32},
		"case_title": {"type": "string", "required": true, "max_length": 80},
		"briefing": {"type": "array", "required": true, "max_items": 8, "items": {"type": "string", "max_length": 500}},
		"objectives": {"type": "array", "required": true, "max_items": 12, "items": {
			"type": "object",
			"fields": {
				"id": {"type": "id", "required": true},
				"text": {"type": "string", "required": true, "max_length": 200},
				"criterion_id": {"type": "id", "required": true},
			},
		}},
		"community_impact": {"type": "string", "required": true, "max_length": 600},
		"learning_objectives": {"type": "array", "required": true, "max_items": 16, "items": {
			"type": "object",
			"fields": {
				"id": {"type": "id", "required": true},
				"title": {"type": "string", "required": true, "max_length": 60},
				"explanation": {"type": "string", "required": true, "max_length": 400},
			},
		}},
		"knowledge_checks": {"type": "array", "required": true, "max_items": 12, "items": {
			"type": "object",
			"fields": {
				"id": {"type": "id", "required": true},
				"learning_objective_id": {"type": "id", "required": true},
				"question": {"type": "string", "required": true, "max_length": 240},
				"options": {"type": "array", "required": true, "max_items": 6, "items": _KNOWLEDGE_OPTION_SCHEMA},
			},
		}},
		"career_preview": {"type": "array", "required": true, "max_items": 6, "items": {
			"type": "object",
			"fields": {
				"stage": {"type": "string", "required": true, "max_length": 40},
				"title": {"type": "string", "required": true, "max_length": 60},
				"note": {"type": "string", "required": true, "max_length": 200},
			},
		}},
	},
}

## Missions this build ships (content ids).
const MISSION_IDS: Array[String] = ["mission_lab_001"]

const MISSION_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"lab_key": {"type": "id", "required": true},
		"title": {"type": "string", "required": true, "max_length": 80},
		"summary": {"type": "string", "required": true, "max_length": 300},
		"prerequisites": {"type": "array", "required": true, "max_items": 10, "items": {"type": "id"}},
	},
}

const _LEVEL_COUNTS_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"beginner": {"type": "int", "required": true, "min": 0, "max": 500},
		"standard": {"type": "int", "required": true, "min": 0, "max": 500},
		"advanced": {"type": "int", "required": true, "min": 0, "max": 500},
		"expert": {"type": "int", "required": true, "min": 0, "max": 500},
	},
}

const SCENARIO_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true, "min": 1},
		"id": {"type": "id", "required": true},
		"events": {"type": "array", "required": true, "max_items": 200, "items": EventRecord.SCHEMA},
		"assets": {"type": "array", "required": true, "max_items": 50, "items": _ASSET_SCHEMA},
		"identities": {"type": "array", "required": true, "max_items": 50, "items": _IDENTITY_SCHEMA},
		"response_options": {"type": "array", "required": true, "max_items": 12, "items": _OPTION_SCHEMA},
		"escalation_options": {"type": "array", "required": true, "max_items": 12, "items": {
			"type": "object",
			"fields": {"id": {"type": "id", "required": true}, "label": {"type": "string", "required": true, "max_length": 80}},
		}},
		"noise": {
			"type": "object",
			"required": true,
			"fields": {
				"accounts": {"type": "array", "required": true, "max_items": 50, "items": {"type": "string", "max_length": 32}},
				"sources": {"type": "array", "required": true, "max_items": 50, "items": {"type": "string", "max_length": 32}},
				"devices": {"type": "array", "required": true, "max_items": 50, "items": {"type": "string", "max_length": 32}},
				"day_start_tick": {"type": "int", "required": true, "min": 0, "max": 86399},
				"day_end_tick": {"type": "int", "required": true, "min": 0, "max": 86399},
				"counts": _LEVEL_COUNTS_SCHEMA,
				"decoys": _LEVEL_COUNTS_SCHEMA,
			},
		},
	},
}


## Registry holding every document this build ships.
static func build_registry() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var outcome: ContentResult = registry.register("lab_001_manifest", "labs/lab_001/manifest.json", LAB_MANIFEST_SCHEMA, 1, lab_manifest_problems)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	outcome = registry.register("lab_001_scenario", "labs/lab_001/scenario.json", SCENARIO_SCHEMA, 1, scenario_problems)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	outcome = registry.register("lab_001_rubric", "labs/lab_001/rubric.json", RUBRIC_SCHEMA, 1)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	outcome = registry.register("lab_001_hints", "labs/lab_001/hints.json", HINTS_SCHEMA, 1)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	outcome = registry.register("mission_lab_001", "missions/mission_lab_001.json", MISSION_SCHEMA, 1)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	outcome = registry.register("mission_lab_001_learning", "missions/mission_lab_001_learning.json", LEARNING_SCHEMA, 1, learning_problems)
	assert(outcome.ok(), "ContentCatalog registration failed: %s" % str(outcome.errors))
	return registry


## Loads every document, then checks that the lab's documents agree with each
## other (rubric options exist in the scenario, scoring adds up, hints point at
## real criteria). One call for the validator tool and for tests.
static func validate_everything(loader: ContentLoader) -> ContentResult:
	var combined: ContentResult = loader.validate_all()
	var scenario: ContentResult = loader.load_content("lab_001_scenario")
	var rubric: ContentResult = loader.load_content("lab_001_rubric")
	var hints: ContentResult = loader.load_content("lab_001_hints")
	if scenario.ok() and rubric.ok() and hints.ok():
		for message: String in lab_cross_problems(scenario.data, rubric.data, hints.data):
			combined.add("lab_001", message)
	var missions: Dictionary = {}
	for mission_id: String in MISSION_IDS:
		var loaded: ContentResult = loader.load_content(mission_id)
		if loaded.ok():
			missions[mission_id] = loaded.data
	for message: String in mission_problems(missions, PackedStringArray(MISSION_IDS)):
		combined.add("missions", message)
	var learning: ContentResult = loader.load_content("mission_lab_001_learning")
	if learning.ok() and rubric.ok():
		for message: String in learning_cross_problems(learning.data, rubric.data):
			combined.add("mission_lab_001_learning", message)
	return combined


## Rules across missions: prerequisites must name real missions, nothing may be
## its own prerequisite (directly or through a chain), and each mission must
## point at a lab whose documents are registered.
static func mission_problems(missions: Dictionary, known_ids: PackedStringArray) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for mission_id: String in missions:
		var document: Dictionary = missions[mission_id]
		for prerequisite: Variant in document.get("prerequisites", []):
			if not known_ids.has(str(prerequisite)):
				problems.append("%s: prerequisite '%s' is not a known mission" % [mission_id, str(prerequisite)])
		if _reaches(missions, mission_id, mission_id, {}):
			problems.append("%s: prerequisites loop back to the mission itself" % mission_id)
		var lab_key: String = str(document.get("lab_key", ""))
		if lab_key.is_empty() or not build_registry().has_entry("%s_manifest" % lab_key) or not build_registry().has_entry("%s_scenario" % lab_key):
			problems.append("%s: lab '%s' has no registered content" % [mission_id, lab_key])
	return problems


static func _reaches(missions: Dictionary, from_id: String, target: String, visited: Dictionary) -> bool:
	if visited.has(from_id) or not missions.has(from_id):
		return false
	visited[from_id] = true
	for prerequisite: Variant in (missions[from_id] as Dictionary).get("prerequisites", []):
		if str(prerequisite) == target or _reaches(missions, str(prerequisite), target, visited):
			return true
	return false


## Cross-document rules for one lab. Empty when the documents agree.
static func lab_cross_problems(scenario: Dictionary, rubric: Dictionary, hints: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var event_ids: PackedStringArray = _ids_of(scenario.get("events", []), "id")
	var asset_ids: PackedStringArray = _ids_of(scenario.get("assets", []), "id")
	var option_ids: PackedStringArray = _ids_of(scenario.get("response_options", []), "id")
	var escalation_ids: PackedStringArray = _ids_of(scenario.get("escalation_options", []), "id")
	var response_scores: Array = rubric.get("response_scores", [])
	var escalation_scores: Array = rubric.get("escalation_scores", [])

	_same_ids("response options", option_ids, _ids_of(response_scores, "option_id"), problems)
	_same_ids("escalation options", escalation_ids, _ids_of(escalation_scores, "option_id"), problems)

	var criteria: Array = rubric.get("criteria", [])
	var criterion_ids: PackedStringArray = _ids_of(criteria, "id")
	for duplicate: String in SchemaValidator.find_duplicate_ids(criteria, "id"):
		problems.append("criteria: id '%s' appears more than once" % duplicate)
	var total: int = 0
	for criterion: Dictionary in criteria:
		total += int(criterion.get("max_points", 0))
		var ceiling: int = _ceiling(criterion, response_scores, escalation_scores)
		if ceiling != int(criterion.get("max_points", 0)):
			problems.append("criterion '%s' can score at most %d but declares %d" % [criterion.get("id", ""), ceiling, int(criterion.get("max_points", 0))])
		var params: Dictionary = criterion.get("params", {})
		for event_id: Variant in params.get("required", []):
			if not event_ids.has(str(event_id)):
				problems.append("criterion '%s' requires unknown event '%s'" % [criterion.get("id", ""), str(event_id)])
		for group: Variant in params.get("groups", []):
			for event_id: Variant in (group as Dictionary).get("events_all", []):
				if not event_ids.has(str(event_id)):
					problems.append("criterion '%s' cites unknown event '%s'" % [criterion.get("id", ""), str(event_id)])
		for asset_id: Variant in (params.get("scope_points", {}) as Dictionary).keys():
			if not asset_ids.has(str(asset_id)):
				problems.append("criterion '%s' scores unknown asset '%s'" % [criterion.get("id", ""), str(asset_id)])
	if total != int(rubric.get("max_points", 0)):
		problems.append("criteria add up to %d points but max_points is %d" % [total, int(rubric.get("max_points", 0))])
	if int(rubric.get("pass_points", 0)) > int(rubric.get("max_points", 0)):
		problems.append("pass_points is higher than max_points")
	for duplicate: String in SchemaValidator.find_duplicate_ids(rubric.get("critical_errors", []), "id"):
		problems.append("critical_errors: id '%s' appears more than once" % duplicate)

	var seen_levels: Dictionary = {}
	for hint: Dictionary in hints.get("hints", []):
		var criterion_id: String = str(hint.get("criterion_id", ""))
		if not criterion_ids.has(criterion_id):
			problems.append("hint refers to unknown criterion '%s'" % criterion_id)
		var key: String = "%s/%d" % [criterion_id, int(hint.get("level", 0))]
		if seen_levels.has(key):
			problems.append("hint %s is defined twice" % key)
		seen_levels[key] = true
	for criterion_id: String in criterion_ids:
		for level: int in [1, 2, 3]:
			if not seen_levels.has("%s/%d" % [criterion_id, level]):
				problems.append("criterion '%s' has no level %d hint" % [criterion_id, level])
	return problems


## Rules inside one learning document: ids are unique, every check has exactly
## one correct option, and every check teaches a declared learning objective.
static func learning_problems(document: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for group: String in ["objectives", "learning_objectives", "knowledge_checks"]:
		for duplicate: String in SchemaValidator.find_duplicate_ids(document.get(group, []), "id"):
			problems.append("%s: id '%s' appears more than once" % [group, duplicate])
	var objective_ids: PackedStringArray = _ids_of(document.get("learning_objectives", []), "id")
	for check: Dictionary in document.get("knowledge_checks", []):
		var check_id: String = str(check.get("id", ""))
		if not objective_ids.has(str(check.get("learning_objective_id", ""))):
			problems.append("check '%s' teaches an unknown learning objective" % check_id)
		var options: Array = check.get("options", [])
		var correct: int = 0
		for option: Dictionary in options:
			if option.get("correct", false) == true:
				correct += 1
		if options.size() < 2:
			problems.append("check '%s' needs at least two options" % check_id)
		if correct != 1:
			problems.append("check '%s' must have exactly one correct option (has %d)" % [check_id, correct])
		for duplicate: String in SchemaValidator.find_duplicate_ids(options, "id"):
			problems.append("check '%s': option id '%s' appears more than once" % [check_id, duplicate])
	return problems


## The learning document must point at real scoring criteria and its mission.
static func learning_cross_problems(learning: Dictionary, rubric: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var criterion_ids: PackedStringArray = _ids_of(rubric.get("criteria", []), "id")
	for objective: Dictionary in learning.get("objectives", []):
		if not criterion_ids.has(str(objective.get("criterion_id", ""))):
			problems.append("objective '%s' points at unknown criterion '%s'" % [objective.get("id", ""), objective.get("criterion_id", "")])
	if not MISSION_IDS.has(str(learning.get("mission_id", ""))):
		problems.append("learning document names unknown mission '%s'" % learning.get("mission_id", ""))
	return problems


static func _ids_of(records: Array, field: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for record: Variant in records:
		if typeof(record) == TYPE_DICTIONARY:
			ids.append(str((record as Dictionary).get(field, "")))
	return ids


static func _same_ids(label: String, expected: PackedStringArray, actual: PackedStringArray, problems: PackedStringArray) -> void:
	for id: String in expected:
		if not actual.has(id):
			problems.append("%s: '%s' is offered to the player but never scored" % [label, id])
	for id: String in actual:
		if not expected.has(id):
			problems.append("%s: '%s' is scored but not offered in the scenario" % [label, id])


## The most a criterion can award, worked out from its own parameters.
static func _ceiling(criterion: Dictionary, response_scores: Array, escalation_scores: Array) -> int:
	var params: Dictionary = criterion.get("params", {})
	match str(criterion.get("check", "")):
		"events_collected":
			return int(params.get("points_each", 0)) * (params.get("required", []) as Array).size()
		"fact_cites_events":
			var sum: int = 0
			for group: Variant in params.get("groups", []):
				sum += int((group as Dictionary).get("points", 0))
			return sum
		"facts_and_hypotheses":
			return int(params.get("points_facts", 0)) + int(params.get("points_open", 0)) + int(params.get("points_claims", 0))
		"scope_and_severity":
			var scope_sum: int = 0
			for points: Variant in (params.get("scope_points", {}) as Dictionary).values():
				scope_sum += int(points)
			var best_severity: int = 0
			for points: Variant in (params.get("severity_points", {}) as Dictionary).values():
				best_severity = maxi(best_severity, int(points))
			return scope_sum + best_severity
		"response_quality":
			var best: int = 0
			for row: Variant in response_scores:
				best = maxi(best, int((row as Dictionary).get("points", 0)))
			return best
		"report_quality":
			var best_escalation: int = 0
			for row: Variant in escalation_scores:
				best_escalation = maxi(best_escalation, int((row as Dictionary).get("points", 0)))
			return int(params.get("summary_points", 0)) + best_escalation
	return -1


## Rules a schema cannot express: every lab must forbid the dangerous actions
## and may never allow any of them, and its action lists must not overlap.
static func lab_manifest_problems(document: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var forbidden: Array = document.get("forbidden_actions", [])
	var allowed: Array = document.get("allowed_actions", [])
	for required: String in REQUIRED_FORBIDDEN_ACTIONS:
		if not forbidden.has(required):
			problems.append("forbidden_actions must include '%s'" % required)
	for action: Variant in allowed:
		if forbidden.has(action):
			problems.append("action '%s' is both allowed and forbidden" % str(action))
	return problems


## Rules a schema cannot express for a lab scenario: unique ids, a usable noise
## setup, noise that never touches an account in the authored story, and more
## noise at higher difficulty.
static func scenario_problems(document: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for list_name: String in ["events", "assets", "identities"]:
		for duplicate: String in SchemaValidator.find_duplicate_ids(document.get(list_name, []), "id"):
			problems.append("%s: id '%s' appears more than once" % [list_name, duplicate])
	var noise: Dictionary = document.get("noise", {})
	var accounts: Array = noise.get("accounts", [])
	if accounts.is_empty():
		problems.append("noise.accounts must not be empty")
	if noise.get("sources", []).size() != accounts.size() or noise.get("devices", []).size() != accounts.size():
		problems.append("noise.sources and noise.devices must each have one entry per noise account")
	if int(noise.get("day_end_tick", 0)) <= int(noise.get("day_start_tick", 0)):
		problems.append("noise.day_end_tick must be after noise.day_start_tick")
	for event: Variant in document.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and accounts.has((event as Dictionary).get("actor")):
			problems.append("noise account '%s' is also an authored event actor" % str((event as Dictionary).get("actor")))
	for group: String in ["counts", "decoys"]:
		var levels: Dictionary = noise.get(group, {})
		var previous: int = 0
		for level: String in ScenarioGenerator.DIFFICULTIES:
			var amount: int = int(levels.get(level, 0))
			if amount < previous:
				problems.append("noise.%s.%s must not be lower than the easier level before it" % [group, level])
			previous = amount
	return problems
