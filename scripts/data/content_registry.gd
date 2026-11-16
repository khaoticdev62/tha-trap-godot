class_name ContentRegistry
extends RefCounted
## The list of content documents the game is allowed to load. Code asks for a
## content id, never a path, so a bad id or a hostile string cannot reach an
## arbitrary file. Each entry fixes the file, its schema and the schema version
## this build understands.

var _entries: Dictionary = {}


## Adds one entry. `check` is an optional Callable taking the parsed document
## and returning a PackedStringArray of problems the schema cannot express.
## Returns the problems found; nothing is stored unless the result is ok.
func register(id: String, relative_path: String, schema: Dictionary, schema_version: int, check: Callable = Callable()) -> ContentResult:
	var result: ContentResult = ContentResult.new()
	if not SchemaValidator.validate(id, {"type": "id"}).ok():
		result.add(id, "is not a valid content id")
	if not SchemaValidator.is_safe_content_path(relative_path) or not relative_path.ends_with(".json"):
		result.add(id, "path '%s' is not a safe relative .json path" % relative_path)
	if schema_version < 1:
		result.add(id, "schema version must be at least 1")
	if _entries.has(id):
		result.add(id, "is already registered")
	for existing_id: String in _entries:
		if _entries[existing_id]["path"] == relative_path:
			result.add(id, "path '%s' is already used by '%s'" % [relative_path, existing_id])
	if result.ok():
		_entries[id] = {"path": relative_path, "schema": schema, "version": schema_version, "check": check}
	return result


func has_entry(id: String) -> bool:
	return _entries.has(id)


## The stored entry ({path, schema, version, check}), or an empty Dictionary.
func entry(id: String) -> Dictionary:
	return _entries.get(id, {})


## Registered ids in sorted order, so reports are stable run to run.
func ids() -> PackedStringArray:
	var sorted_ids: Array = _entries.keys()
	sorted_ids.sort()
	return PackedStringArray(sorted_ids)
