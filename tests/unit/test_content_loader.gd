extends TestCase
## ContentRegistry + ContentLoader: registered ids only, size caps, malformed
## JSON, schema and version checks. Uses a throwaway folder under user://.

const SCHEMA: Dictionary = {
	"type": "object",
	"fields": {
		"schema_version": {"type": "int", "required": true},
		"id": {"type": "id", "required": true},
		"title": {"type": "string", "required": true, "max_length": 40},
	},
}

var _root: String = ""
var _registry: ContentRegistry
var _loader: ContentLoader


func before_each() -> void:
	_root = "user://itest_content_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_root.path_join("labs"))
	_registry = ContentRegistry.new()
	_loader = ContentLoader.new(_registry, _root)


func after_each() -> void:
	for dir_path: String in [_root.path_join("labs"), _root]:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(dir_path.path_join(file_name))
		DirAccess.remove_absolute(dir_path)


func _write(relative: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_root.path_join(relative), FileAccess.WRITE)
	file.store_string(text)
	file = null


func _register(id: String = "lab_001", path: String = "labs/lab_001.json") -> void:
	var outcome: ContentResult = _registry.register(id, path, SCHEMA, 1)
	check(outcome.ok(), "registration works: %s" % str(outcome.errors))


func test_loads_a_valid_document() -> void:
	_write("labs/lab_001.json", '{"schema_version": 1, "id": "lab_001", "title": "Somebody"}')
	_register()
	var result: ContentResult = _loader.load_content("lab_001")
	check(result.ok(), "valid document loads: %s" % str(result.errors))
	check_eq(typeof(result.data), TYPE_DICTIONARY, "data is returned")
	check_eq((result.data as Dictionary).get("title"), "Somebody", "data content is intact")


func test_unknown_id_is_refused() -> void:
	var result: ContentResult = _loader.load_content("never_registered")
	check(not result.ok(), "an unregistered id never loads")
	check(result.data == null, "no data is returned")


func test_a_file_that_is_not_registered_cannot_be_reached() -> void:
	_write("labs/secret.json", '{"schema_version": 1, "id": "secret", "title": "x"}')
	for sneaky: String in ["labs/secret.json", "../secret", "labs/lab_001.json", "res://project.godot", ""]:
		check(not _loader.load_content(sneaky).ok(), "only registered ids load: '%s'" % sneaky)


func test_missing_file_is_an_error_not_a_crash() -> void:
	_register()
	var result: ContentResult = _loader.load_content("lab_001")
	check(not result.ok(), "missing file reported")
	check(result.errors[0].contains("lab_001"), "error names the content id: %s" % result.errors[0])


func test_malformed_json_reports_a_line() -> void:
	_register()
	var broken: Array[String] = ["{", "not json", '{"a": }', "[1, 2", "", "   ", '{"schema_version": 1,}', "{" + String.chr(1) + "}"]
	for text: String in broken:
		_write("labs/lab_001.json", text)
		var result: ContentResult = _loader.load_content("lab_001")
		check(not result.ok(), "malformed content is rejected: '%s'" % text.left(20))
	_write("labs/lab_001.json", "{\n  \"schema_version\": 1,\n  oops\n}")
	var located: String = _loader.load_content("lab_001").errors[0]
	# The engine reports where parsing stopped (line 2 or 3 for this file); the
	# loader's job is to pass a line number through.
	check(located.contains("(line 2)") or located.contains("(line 3)"), "the error carries a line number near the fault: %s" % located)


func test_oversized_file_is_rejected_before_parsing() -> void:
	_register()
	_write("labs/lab_001.json", '{"schema_version": 1, "id": "lab_001", "title": "' + "x".repeat(200) + '"}')
	_loader.max_file_bytes = 100
	var result: ContentResult = _loader.load_content("lab_001")
	check(not result.ok(), "file over the cap rejected")
	check(result.errors[0].contains("too large"), "says why: %s" % result.errors[0])


func test_schema_violations_are_reported_with_the_id() -> void:
	_register()
	_write("labs/lab_001.json", '{"schema_version": 1, "id": "Bad Id", "title": 5}')
	var result: ContentResult = _loader.load_content("lab_001")
	check(not result.ok(), "invalid content rejected")
	check(result.errors.size() >= 2, "every problem is listed (%d)" % result.errors.size())
	check(result.errors[0].begins_with("lab_001"), "errors start with the content id: %s" % result.errors[0])
	check(result.data == null, "invalid content returns no data")


func test_schema_version_is_enforced() -> void:
	_register()
	_write("labs/lab_001.json", '{"id": "lab_001", "title": "x"}')
	check(not _loader.load_content("lab_001").ok(), "missing schema_version rejected")
	_write("labs/lab_001.json", '{"schema_version": 2, "id": "lab_001", "title": "x"}')
	var newer: ContentResult = _loader.load_content("lab_001")
	check(not newer.ok(), "a newer schema version is refused")
	check(newer.errors[0].contains("newer"), "says it is newer: %s" % newer.errors[0])
	_write("labs/lab_001.json", '{"schema_version": 0, "id": "lab_001", "title": "x"}')
	check(not _loader.load_content("lab_001").ok(), "version 0 rejected")
	_write("labs/lab_001.json", '{"schema_version": 1.5, "id": "lab_001", "title": "x"}')
	check(not _loader.load_content("lab_001").ok(), "fractional version rejected")


func test_root_must_be_an_object() -> void:
	_register()
	for text: String in ["[]", "5", '"text"', "null", "true"]:
		_write("labs/lab_001.json", text)
		check(not _loader.load_content("lab_001").ok(), "root rejected: %s" % text)


func test_registration_rules() -> void:
	check(not _registry.register("Bad Id", "labs/a.json", SCHEMA, 1).ok(), "bad id rejected")
	check(not _registry.register("a", "../a.json", SCHEMA, 1).ok(), "traversal path rejected")
	check(not _registry.register("a", "res://data/a.json", SCHEMA, 1).ok(), "scheme path rejected")
	check(not _registry.register("a", "labs/a.json", SCHEMA, 0).ok(), "version below 1 rejected")
	check(not _registry.register("a", "labs/a.txt", SCHEMA, 1).ok(), "only .json files can be registered")
	check(_registry.register("a", "labs/a.json", SCHEMA, 1).ok(), "a valid entry registers")
	check(not _registry.register("a", "labs/b.json", SCHEMA, 1).ok(), "a duplicate id is rejected")
	check(not _registry.register("b", "labs/a.json", SCHEMA, 1).ok(), "two ids cannot share one file")
	check_eq(_registry.ids().size(), 1, "failed registrations leave no trace")


func test_ids_are_sorted_for_stable_output() -> void:
	_registry.register("zeta", "z.json", SCHEMA, 1)
	_registry.register("alpha", "a.json", SCHEMA, 1)
	_registry.register("mid", "m.json", SCHEMA, 1)
	check_eq(",".join(_registry.ids()), "alpha,mid,zeta", "ids come back sorted")


func test_validate_all_collects_every_problem() -> void:
	_registry.register("good_one", "labs/good.json", SCHEMA, 1)
	_registry.register("bad_one", "labs/bad.json", SCHEMA, 1)
	_registry.register("missing_one", "labs/missing.json", SCHEMA, 1)
	_write("labs/good.json", '{"schema_version": 1, "id": "good_one", "title": "ok"}')
	_write("labs/bad.json", '{"schema_version": 1, "id": "bad_one"}')
	var result: ContentResult = _loader.validate_all()
	check(not result.ok(), "one bad document fails the whole check")
	var text: String = "\n".join(result.errors)
	check(text.contains("bad_one") and text.contains("missing_one"), "both failures are named")
	check(not text.contains("good_one"), "the good document is not blamed")


func test_validate_all_passes_when_everything_is_valid() -> void:
	_registry.register("good_one", "labs/good.json", SCHEMA, 1)
	_write("labs/good.json", '{"schema_version": 1, "id": "good_one", "title": "ok"}')
	check(_loader.validate_all().ok(), "all valid passes")
	check(ContentLoader.new(ContentRegistry.new(), _root).validate_all().ok(), "an empty registry is valid")
