extends TestCase
## The real shipped content under res://data, plus the lab safety rules.


func _manifest() -> Dictionary:
	return {
		"allowed_actions": ["search_logs", "add_evidence"],
		"forbidden_actions": ["host_shell", "external_network", "real_credentials"],
	}


func test_shipped_content_is_valid() -> void:
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var result: ContentResult = ContentLoader.new(registry).validate_all()
	check(result.ok(), "everything under res://data validates: %s" % str(result.errors))
	check(registry.ids().size() >= 1, "at least one document is registered")


func test_lab_001_manifest_values() -> void:
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var result: ContentResult = ContentLoader.new(registry).load_content("lab_001_manifest")
	check(result.ok(), "manifest loads: %s" % str(result.errors))
	var manifest: Dictionary = result.data
	check_eq(manifest["id"], "lab_001", "stable id")
	check_eq(manifest["display_id"], "LAB-001", "display id")
	check_eq(manifest["reset_policy"], "full_reset", "labs reset fully")
	check((manifest["objectives"] as Array).size() == 5, "five learning objectives from spec 04 §7")
	check((manifest["forbidden_actions"] as Array).has("host_shell"), "the host shell is forbidden")


func test_safe_manifest_has_no_problems() -> void:
	check(ContentCatalog.lab_manifest_problems(_manifest()).is_empty(), "a safe manifest passes")


func test_every_dangerous_action_must_be_forbidden() -> void:
	for required: String in ContentCatalog.REQUIRED_FORBIDDEN_ACTIONS:
		var manifest: Dictionary = _manifest()
		(manifest["forbidden_actions"] as Array).erase(required)
		var problems: PackedStringArray = ContentCatalog.lab_manifest_problems(manifest)
		check(problems.size() == 1 and problems[0].contains(required), "missing '%s' is reported" % required)


func test_an_action_cannot_be_allowed_and_forbidden() -> void:
	var manifest: Dictionary = _manifest()
	(manifest["allowed_actions"] as Array).append("host_shell")
	check(not ContentCatalog.lab_manifest_problems(manifest).is_empty(), "allowing a forbidden action is reported")


func test_schema_refuses_unknown_actions() -> void:
	var registry: ContentRegistry = ContentCatalog.build_registry()
	var schema: Dictionary = registry.entry("lab_001_manifest")["schema"]
	var doc: Dictionary = {"schema_version": 1, "id": "lab_x", "display_id": "X", "version": "1", "title": "t", "district": "d", "difficulty": "standard", "estimated_minutes": 5, "prerequisites": [], "objectives": [], "scenario_data": "labs/x", "allowed_actions": ["host_shell"], "forbidden_actions": [], "framework_mappings": [], "reset_policy": "full_reset", "portfolio_artifact": "p"}
	check(not SchemaValidator.validate(doc, schema).ok(), "a manifest cannot allow an action outside the known safe list")
	doc["allowed_actions"] = ["search_logs"]
	check(SchemaValidator.validate(doc, schema).ok(), "the same manifest with a safe action is valid")


func test_loader_runs_the_registered_check() -> void:
	var root: String = "user://itest_catalog_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(root)
	var file: FileAccess = FileAccess.open(root.path_join("doc.json"), FileAccess.WRITE)
	file.store_string('{"schema_version": 1, "id": "doc"}')
	file = null
	var schema: Dictionary = {"type": "object", "fields": {"schema_version": {"type": "int", "required": true}, "id": {"type": "id", "required": true}}}
	var registry: ContentRegistry = ContentRegistry.new()
	registry.register("doc", "doc.json", schema, 1, func(_document: Dictionary) -> PackedStringArray: return PackedStringArray(["custom rule broken"]))
	var result: ContentResult = ContentLoader.new(registry, root).load_content("doc")
	check(not result.ok() and result.errors[0].contains("custom rule broken"), "the registered check can reject a schema-valid document")
	check(result.data == null, "no data is returned when a check fails")
	DirAccess.remove_absolute(root.path_join("doc.json"))
	DirAccess.remove_absolute(root)
