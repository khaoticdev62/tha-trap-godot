class_name TestCase
extends RefCounted
## Minimal assertion base for headless unit tests. Test methods are named
## `test_*`; override before_each/after_each for fixtures.

var failures: PackedStringArray = PackedStringArray()
var assertions: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func reset_failures() -> void:
	failures = PackedStringArray()
