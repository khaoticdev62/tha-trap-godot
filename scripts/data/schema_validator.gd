class_name SchemaValidator
extends RefCounted
## Validates untrusted, already-parsed content (JSON documents under data/)
## against a small declarative schema. It never evaluates anything: it only
## inspects types, ranges, lengths and characters, and returns every problem it
## finds as "<path>: <reason>" in a ContentResult.
##
## Schema nodes are Dictionaries:
##   {"type": "object", "fields": {name: node}, "allow_unknown": false}
##       a field node may add "required": true
##   {"type": "array", "items": node, "max_items": 1000}
##   {"type": "string", "max_length": 1000, "multiline": false}
##   {"type": "id"}      stable content id: ^[a-z][a-z0-9_]{0,63}$
##   {"type": "int" | "number", "min": x, "max": y}
##   {"type": "bool"}
##   {"type": "enum", "values": [..strings..]}
##   {"type": "path"}    safe relative content path (see is_safe_content_path)
## An unknown "type" in a schema is reported as an error, never accepted.

const MAX_DEPTH: int = 8
const DEFAULT_MAX_STRING: int = 1000
const DEFAULT_MAX_ITEMS: int = 1000
const MAX_ID_LENGTH: int = 64
const MAX_PATH_LENGTH: int = 128
## Whole numbers beyond this are not exactly representable as floats.
const MAX_SAFE_INT: float = 9007199254740992.0


static func validate(value: Variant, schema: Dictionary) -> ContentResult:
	var result: ContentResult = ContentResult.new()
	_check(value, schema, "$", 0, result)
	return result


## True for a plain relative path made only of letters, digits, `_`, `-`, `.`
## and `/`. Rejects traversal, absolute paths, drive letters, URL schemes,
## backslashes, empty or hidden segments, and anything over the length cap.
static func is_safe_content_path(path: String) -> bool:
	if path.is_empty() or path.length() > MAX_PATH_LENGTH:
		return false
	for index: int in path.length():
		var code: int = path.unicode_at(index)
		var allowed: bool = (code >= 0x61 and code <= 0x7A) or (code >= 0x41 and code <= 0x5A) or (code >= 0x30 and code <= 0x39) or code == 0x5F or code == 0x2D or code == 0x2E or code == 0x2F
		if not allowed:
			return false
	for segment: String in path.split("/"):
		if segment.is_empty() or segment.begins_with("."):
			return false
	return true


## Ids that appear more than once in `records[*][field]`. Records that are not
## dictionaries, or have no string id, are skipped (the schema reports those).
static func find_duplicate_ids(records: Array, field: String) -> PackedStringArray:
	var seen: Dictionary = {}
	var duplicates: PackedStringArray = PackedStringArray()
	for record: Variant in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var id: Variant = (record as Dictionary).get(field)
		if typeof(id) != TYPE_STRING:
			continue
		if seen.has(id):
			if not duplicates.has(id):
				duplicates.append(id)
		else:
			seen[id] = true
	return duplicates


static func _check(value: Variant, schema: Dictionary, path: String, depth: int, result: ContentResult) -> void:
	if result.is_full():
		return
	if depth > MAX_DEPTH:
		result.add(path, "nesting is too deep")
		return
	var type: String = str(schema.get("type", ""))
	match type:
		"object":
			_check_object(value, schema, path, depth, result)
		"array":
			_check_array(value, schema, path, depth, result)
		"string":
			_check_string(value, schema, path, result)
		"id":
			_check_id(value, path, result)
		"int":
			_check_number(value, schema, path, result, true)
		"number":
			_check_number(value, schema, path, result, false)
		"bool":
			if typeof(value) != TYPE_BOOL:
				result.add(path, "must be true or false")
		"enum":
			_check_enum(value, schema, path, result)
		"path":
			if typeof(value) != TYPE_STRING or not is_safe_content_path(value):
				result.add(path, "must be a safe relative content path")
		_:
			result.add(path, "schema has unknown type '%s'" % type)


static func _check_object(value: Variant, schema: Dictionary, path: String, depth: int, result: ContentResult) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		result.add(path, "must be an object")
		return
	var source: Dictionary = value
	var fields: Dictionary = schema.get("fields", {})
	var allow_unknown: bool = schema.get("allow_unknown", false) == true
	for key: Variant in source:
		if not fields.has(key) and not allow_unknown:
			result.add("%s.%s" % [path, str(key)], "is not a known field")
	for key: Variant in fields:
		var field_schema: Dictionary = fields[key]
		var field_path: String = "%s.%s" % [path, str(key)]
		if source.has(key):
			_check(source[key], field_schema, field_path, depth + 1, result)
		elif field_schema.get("required", false) == true:
			result.add(field_path, "is required")


static func _check_array(value: Variant, schema: Dictionary, path: String, depth: int, result: ContentResult) -> void:
	if typeof(value) != TYPE_ARRAY:
		result.add(path, "must be an array")
		return
	var items: Array = value
	var max_items: int = int(schema.get("max_items", DEFAULT_MAX_ITEMS))
	if items.size() > max_items:
		result.add(path, "has %d items; the limit is %d" % [items.size(), max_items])
		return
	var item_schema: Variant = schema.get("items")
	if typeof(item_schema) != TYPE_DICTIONARY:
		result.add(path, "schema array has no items definition")
		return
	for index: int in items.size():
		if result.is_full():
			return
		_check(items[index], item_schema, "%s[%d]" % [path, index], depth + 1, result)


static func _check_string(value: Variant, schema: Dictionary, path: String, result: ContentResult) -> void:
	if typeof(value) != TYPE_STRING:
		result.add(path, "must be text")
		return
	var text: String = value
	var max_length: int = int(schema.get("max_length", DEFAULT_MAX_STRING))
	if text.length() > max_length:
		result.add(path, "is %d characters; the limit is %d" % [text.length(), max_length])
		return
	var multiline: bool = schema.get("multiline", false) == true
	for index: int in text.length():
		if _is_forbidden_char(text.unicode_at(index), multiline):
			result.add(path, "contains a control, zero-width or direction-override character")
			return


static func _check_id(value: Variant, path: String, result: ContentResult) -> void:
	if typeof(value) != TYPE_STRING:
		result.add(path, "must be an id (text)")
		return
	var text: String = value
	var valid: bool = not text.is_empty() and text.length() <= MAX_ID_LENGTH
	if valid:
		for index: int in text.length():
			var code: int = text.unicode_at(index)
			var is_lower: bool = code >= 0x61 and code <= 0x7A
			var is_tail: bool = is_lower or (code >= 0x30 and code <= 0x39) or code == 0x5F
			if index == 0 and not is_lower:
				valid = false
				break
			if not is_tail:
				valid = false
				break
	if not valid:
		result.add(path, "must be a lowercase id (letters, digits, underscore; starts with a letter; at most %d characters)" % MAX_ID_LENGTH)


static func _check_number(value: Variant, schema: Dictionary, path: String, result: ContentResult, whole_only: bool) -> void:
	var kind: int = typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		result.add(path, "must be a number")
		return
	var number: float = float(value)
	if is_nan(number) or is_inf(number):
		result.add(path, "must be a finite number")
		return
	if whole_only:
		if absf(number) > MAX_SAFE_INT or number != floorf(number):
			result.add(path, "must be a whole number")
			return
	if schema.has("min") and number < float(schema["min"]):
		result.add(path, "must be at least %s" % str(schema["min"]))
	elif schema.has("max") and number > float(schema["max"]):
		result.add(path, "must be at most %s" % str(schema["max"]))


static func _check_enum(value: Variant, schema: Dictionary, path: String, result: ContentResult) -> void:
	var allowed: Array = schema.get("values", [])
	if typeof(value) != TYPE_STRING or not allowed.has(value):
		result.add(path, "must be one of: %s" % ", ".join(PackedStringArray(allowed)))


## Control characters (newline allowed only in multiline text), DEL and C1
## controls, zero-width characters, and bidirectional overrides and isolates.
static func _is_forbidden_char(code: int, multiline: bool) -> bool:
	if code < 0x20:
		return not (multiline and code == 0x0A)
	if code >= 0x7F and code <= 0x9F:
		return true
	if code >= 0x200B and code <= 0x200F:
		return true
	if code >= 0x202A and code <= 0x202E:
		return true
	if code >= 0x2066 and code <= 0x2069:
		return true
	return code == 0xFEFF
