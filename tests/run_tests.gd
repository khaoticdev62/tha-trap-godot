extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run_tests.gd [-- <name-filter>]
## Discovers tests/unit/test_*.gd, runs every `test_*` method, and exits 1 on
## any failure so CI can gate on it.

const TEST_DIR: String = "res://tests/unit"


func _init() -> void:
	var filter: String = ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() > 0:
		filter = user_args[0]

	var total_tests: int = 0
	var total_assertions: int = 0
	var failed: PackedStringArray = PackedStringArray()

	for file_name: String in _discover():
		if not filter.is_empty() and not file_name.contains(filter):
			continue
		var script: GDScript = load(TEST_DIR.path_join(file_name))
		if script == null or not script.can_instantiate():
			failed.append("%s: failed to compile" % file_name)
			continue
		var probe: Object = script.new()
		for method: Dictionary in probe.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.before_each()
			case.call(method_name)
			case.after_each()
			total_tests += 1
			total_assertions += case.assertions
			for message: String in case.failures:
				failed.append("%s::%s: %s" % [file_name, method_name, message])
			if case.assertions == 0:
				failed.append("%s::%s: made no assertions" % [file_name, method_name])

	for line: String in failed:
		print("FAIL  ", line)
	print("---")
	print("%d tests, %d assertions, %d failures" % [total_tests, total_assertions, failed.size()])
	quit(1 if failed.size() > 0 or total_tests == 0 else 0)


func _discover() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(file_name)
	found.sort()
	return found
