extends TestCase


func test_same_version_is_a_no_op() -> void:
	var result: Dictionary = SaveMigrations.migrate({"a": 1}, 1, 1)
	check(result["ok"], "no-op migration succeeds")
	check_eq(result["payload"], {"a": 1}, "payload unchanged")


func test_chain_runs_in_order() -> void:
	var steps: Dictionary = {
		1: func(p: Dictionary) -> Dictionary: p["trail"] = "1>2"; return p,
		2: func(p: Dictionary) -> Dictionary: p["trail"] = p["trail"] + ">3"; return p,
	}
	var result: Dictionary = SaveMigrations.migrate({}, 1, 3, steps)
	check(result["ok"], "chain succeeds")
	check_eq(result["payload"]["trail"], "1>2>3", "steps ran in order")


func test_input_is_not_mutated() -> void:
	var steps: Dictionary = {1: func(p: Dictionary) -> Dictionary: p["x"] = 1; return p}
	var original: Dictionary = {}
	SaveMigrations.migrate(original, 1, 2, steps)
	check(original.is_empty(), "caller's dictionary is untouched")


func test_missing_step_fails() -> void:
	var result: Dictionary = SaveMigrations.migrate({}, 1, 3, {1: func(p: Dictionary) -> Dictionary: return p})
	check(not result["ok"], "gap in chain fails")


func test_bad_step_return_fails() -> void:
	var result: Dictionary = SaveMigrations.migrate({}, 1, 2, {1: func(_p: Dictionary) -> int: return 5})
	check(not result["ok"], "non-dictionary result fails")


func test_newer_and_invalid_versions_fail() -> void:
	check(not SaveMigrations.migrate({}, 3, 2)["ok"], "newer than target fails")
	check(not SaveMigrations.migrate({}, 0, 1)["ok"], "version 0 fails")
	check(not SaveMigrations.migrate({}, -4, 1)["ok"], "negative version fails")
