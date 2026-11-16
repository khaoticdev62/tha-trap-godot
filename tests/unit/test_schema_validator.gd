extends TestCase
## SchemaValidator: type, range, enum, id, text-safety, nesting and path checks.

const LAB_SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"id": {"type": "id", "required": true},
		"title": {"type": "string", "required": true, "max_length": 40},
		"minutes": {"type": "int", "min": 1, "max": 600},
		"difficulty": {"type": "enum", "values": ["beginner", "standard", "advanced"]},
		"objectives": {"type": "array", "max_items": 3, "items": {"type": "string", "max_length": 30}},
		"enabled": {"type": "bool"},
		"weight": {"type": "number", "min": 0.0, "max": 1.0},
	},
}


func _good() -> Dictionary:
	return {"id": "lab_001", "title": "Somebody's In The Network", "minutes": 25, "difficulty": "standard", "objectives": ["read logs"], "enabled": true, "weight": 0.5}


func _errors_for(value: Variant, schema: Dictionary = LAB_SCHEMA) -> PackedStringArray:
	return SchemaValidator.validate(value, schema).errors


func test_valid_document_passes() -> void:
	var result: ContentResult = SchemaValidator.validate(_good(), LAB_SCHEMA)
	check(result.ok(), "a well-formed document passes: %s" % str(result.errors))


func test_non_object_root_is_rejected() -> void:
	check(not _errors_for([1, 2]).is_empty(), "an array is not an object")
	check(not _errors_for("text").is_empty(), "a string is not an object")
	check(not _errors_for(null).is_empty(), "null is not an object")


func test_missing_required_field_names_the_field() -> void:
	var doc: Dictionary = _good()
	doc.erase("title")
	var errors: PackedStringArray = _errors_for(doc)
	check_eq(errors.size(), 1, "exactly one error")
	check(errors[0].contains("$.title"), "error names the path: %s" % errors[0])


func test_unknown_keys_rejected_unless_allowed() -> void:
	var doc: Dictionary = _good()
	doc["surprise"] = 1
	check(not _errors_for(doc).is_empty(), "unknown key rejected by default")
	var open_schema: Dictionary = LAB_SCHEMA.duplicate()
	open_schema["allow_unknown"] = true
	check(_errors_for(doc, open_schema).is_empty(), "unknown key allowed when the schema says so")


func test_int_rules() -> void:
	var doc: Dictionary = _good()
	doc["minutes"] = 25.0  # JSON numbers load as floats
	check(_errors_for(doc).is_empty(), "a whole float is a valid int")
	doc["minutes"] = 25.5
	check(not _errors_for(doc).is_empty(), "a fractional number is not an int")
	doc["minutes"] = "25"
	check(not _errors_for(doc).is_empty(), "a string is not an int")
	doc["minutes"] = true
	check(not _errors_for(doc).is_empty(), "a bool is not an int")
	doc["minutes"] = 0
	check(not _errors_for(doc).is_empty(), "below min rejected")
	doc["minutes"] = 601
	check(not _errors_for(doc).is_empty(), "above max rejected")
	doc["minutes"] = 1.0e30
	check(not _errors_for(doc).is_empty(), "absurdly large number rejected")


func test_number_rules() -> void:
	var doc: Dictionary = _good()
	doc["weight"] = INF
	check(not _errors_for(doc).is_empty(), "infinity rejected")
	doc["weight"] = NAN
	check(not _errors_for(doc).is_empty(), "NaN rejected")
	doc["weight"] = 1.5
	check(not _errors_for(doc).is_empty(), "out of range rejected")
	doc["weight"] = 1
	check(_errors_for(doc).is_empty(), "an int is a valid number")


func test_bool_must_be_a_real_bool() -> void:
	var doc: Dictionary = _good()
	doc["enabled"] = "true"
	check(not _errors_for(doc).is_empty(), "the string 'true' is not a bool")
	doc["enabled"] = 1
	check(not _errors_for(doc).is_empty(), "1 is not a bool")


func test_enum_rules() -> void:
	var doc: Dictionary = _good()
	doc["difficulty"] = "expert"
	check(not _errors_for(doc).is_empty(), "value outside the enum rejected")
	doc["difficulty"] = 3
	check(not _errors_for(doc).is_empty(), "non-string enum value rejected")


func test_id_rules() -> void:
	var doc: Dictionary = _good()
	for bad: String in ["Lab_001", "1lab", "lab-001", "lab 001", "../lab", "lab/001", "", "a".repeat(65), "lab\u00e9"]:
		doc["id"] = bad
		check(not _errors_for(doc).is_empty(), "id rejected: '%s'" % bad)
	for good: String in ["lab_001", "a", "evt_001", "a".repeat(64)]:
		doc["id"] = good
		check(_errors_for(doc).is_empty(), "id accepted: '%s'" % good)


func test_string_length_and_control_characters() -> void:
	var doc: Dictionary = _good()
	doc["title"] = "x".repeat(41)
	check(not _errors_for(doc).is_empty(), "too long rejected")
	doc["title"] = "bad" + String.chr(1) + "nul"
	check(not _errors_for(doc).is_empty(), "control character rejected")
	doc["title"] = "line one" + String.chr(10) + "two"
	check(not _errors_for(doc).is_empty(), "newline rejected in a single-line string")
	doc["title"] = "evil" + String.chr(0x202E) + "txt"
	check(not _errors_for(doc).is_empty(), "bidi override rejected")
	doc["title"] = "zero" + String.chr(0x200B) + "width"
	check(not _errors_for(doc).is_empty(), "zero-width character rejected")
	doc["title"] = "Café 🙂 مرحبا"
	check(_errors_for(doc).is_empty(), "ordinary unicode, emoji and RTL text are allowed")


func test_multiline_strings_allow_newlines_only() -> void:
	var schema: Dictionary = {"type": "object", "fields": {"body": {"type": "string", "multiline": true, "max_length": 100}}}
	check(_errors_for({"body": "a" + String.chr(10) + "b"}, schema).is_empty(), "newline allowed when multiline")
	check(not _errors_for({"body": "a" + String.chr(1) + "b"}, schema).is_empty(), "control character still rejected when multiline")


func test_array_rules() -> void:
	var doc: Dictionary = _good()
	doc["objectives"] = ["a", "b", "c", "d"]
	check(not _errors_for(doc).is_empty(), "too many items rejected")
	doc["objectives"] = ["a", 5]
	var errors: PackedStringArray = _errors_for(doc)
	check_eq(errors.size(), 1, "one bad item, one error")
	check(errors[0].contains("$.objectives[1]"), "error names the item index: %s" % errors[0])
	doc["objectives"] = "not an array"
	check(not _errors_for(doc).is_empty(), "wrong container type rejected")


func test_nested_objects_report_full_path() -> void:
	var schema: Dictionary = {"type": "object", "fields": {"meta": {"type": "object", "required": true, "fields": {"owner": {"type": "string", "required": true}}}}}
	var errors: PackedStringArray = _errors_for({"meta": {}}, schema)
	check_eq(errors.size(), 1, "one error")
	check(errors[0].contains("$.meta.owner"), "nested path reported: %s" % errors[0])


func test_depth_limit_stops_runaway_nesting() -> void:
	var schema: Dictionary = {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "array", "items": {"type": "int"}}}}}}}}}}}
	var value: Variant = [[[[[[[[[[1]]]]]]]]]]
	check(not _errors_for(value, schema).is_empty(), "nesting beyond the cap is rejected, not recursed")


func test_error_list_is_capped() -> void:
	var schema: Dictionary = {"type": "array", "max_items": 5000, "items": {"type": "int"}}
	var bad: Array = []
	for i: int in 500:
		bad.append("x")
	var errors: PackedStringArray = _errors_for(bad, schema)
	check(errors.size() <= ContentResult.MAX_ERRORS + 1, "errors are capped (%d)" % errors.size())
	check(errors.size() > 1, "but still reported")


func test_unknown_schema_type_is_an_error_not_a_pass() -> void:
	var errors: PackedStringArray = _errors_for({"a": 1}, {"type": "object", "fields": {"a": {"type": "banana"}}})
	check(not errors.is_empty(), "a typo in a schema must not silently accept data")


func test_content_paths() -> void:
	for good: String in ["labs/lab_001/events.json", "data/a-b_c.json", "events.json"]:
		check(SchemaValidator.is_safe_content_path(good), "path accepted: %s" % good)
	var bad_paths: Array[String] = [
		"", "../x.json", "a/../b.json", "/etc/passwd", "C:\\x.json", "c:/x.json", "a\\b.json",
		"res://data/x.json", "user://saves/slot_0.json", "a//b.json", "./a.json", "a/./b.json",
		"a/.hidden.json", "a b.json", "a.json ", "x".repeat(129), "a" + String.chr(1) + ".json", "%2e%2e/x.json", "a/b/",
	]
	for bad: String in bad_paths:
		check(not SchemaValidator.is_safe_content_path(bad), "path rejected: '%s'" % bad)


func test_path_schema_type() -> void:
	var schema: Dictionary = {"type": "object", "fields": {"scenario_data": {"type": "path", "required": true}}}
	check(_errors_for({"scenario_data": "labs/lab_001/events.json"}, schema).is_empty(), "safe path accepted")
	check(not _errors_for({"scenario_data": "../../secret"}, schema).is_empty(), "traversal path rejected")


func test_duplicate_ids_are_found() -> void:
	var records: Array = [{"id": "evt_001"}, {"id": "evt_002"}, {"id": "evt_001"}, {"id": "evt_002"}, {"id": "evt_003"}]
	var dupes: PackedStringArray = SchemaValidator.find_duplicate_ids(records, "id")
	check_eq(dupes.size(), 2, "two duplicated ids")
	check(dupes.has("evt_001") and dupes.has("evt_002"), "the right ids are named")
	check(SchemaValidator.find_duplicate_ids([{"id": "a"}, {"id": "b"}], "id").is_empty(), "no false positives")
	check(SchemaValidator.find_duplicate_ids([{"x": 1}, "junk", null], "id").is_empty(), "records without ids are ignored here (the schema reports them)")
