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
	return registry


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
