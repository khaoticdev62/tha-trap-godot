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


## Registry holding every document this build ships.
static func build_registry() -> ContentRegistry:
	var registry: ContentRegistry = ContentRegistry.new()
	var outcome: ContentResult = registry.register("lab_001_manifest", "labs/lab_001/manifest.json", LAB_MANIFEST_SCHEMA, 1, lab_manifest_problems)
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
