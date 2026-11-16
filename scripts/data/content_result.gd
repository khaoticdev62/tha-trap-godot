class_name ContentResult
extends RefCounted
## Outcome of validating a content document. Never throws; callers branch on
## `ok()`. Errors read "<path>: <reason>" so authors can find the bad field.

## Past this many errors the list stops growing, so a hostile or broken file
## cannot make the validator allocate without bound.
const MAX_ERRORS: int = 50

var errors: PackedStringArray = PackedStringArray()


func ok() -> bool:
	return errors.is_empty()


func add(path: String, reason: String) -> void:
	if errors.size() < MAX_ERRORS:
		errors.append("%s: %s" % [path, reason])
	elif errors.size() == MAX_ERRORS:
		errors.append("(further errors omitted)")


func is_full() -> bool:
	return errors.size() > MAX_ERRORS
