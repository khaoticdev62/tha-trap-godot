class_name ContentLoader
extends RefCounted
## Reads registered content documents from the data folder and validates them.
## Only ids in the ContentRegistry can be loaded. Every failure (missing file,
## oversized file, malformed JSON, wrong version, schema violation) comes back
## as a ContentResult; this class never crashes on bad content and never reads
## a path the caller supplied.

const DEFAULT_ROOT: String = "res://data"
## Per-document size cap, checked before the file is read into memory.
const DEFAULT_MAX_FILE_BYTES: int = 1024 * 1024

var data_root: String
var max_file_bytes: int = DEFAULT_MAX_FILE_BYTES

var _registry: ContentRegistry


func _init(registry: ContentRegistry, root: String = DEFAULT_ROOT) -> void:
	_registry = registry
	data_root = root


## Loads and validates one document. On success `data` holds the parsed
## Dictionary.
func load_content(id: String) -> ContentResult:
	var result: ContentResult = ContentResult.new()
	if not _registry.has_entry(id):
		result.add(id, "is not registered content")
		return result
	var entry: Dictionary = _registry.entry(id)
	var path: String = data_root.path_join(entry["path"])

	if not FileAccess.file_exists(path):
		result.add(id, "file '%s' was not found" % entry["path"])
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.add(id, "file '%s' could not be opened" % entry["path"])
		return result
	if file.get_length() > max_file_bytes:
		result.add(id, "file is too large (limit %d bytes)" % max_file_bytes)
		return result
	var text: String = file.get_as_text()
	file = null

	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		result.add(id, "is not valid JSON (line %d): %s" % [parser.get_error_line(), parser.get_error_message()])
		return result
	if typeof(parser.data) != TYPE_DICTIONARY:
		result.add(id, "must be a JSON object at the top level")
		return result
	var document: Dictionary = parser.data

	var version_problem: String = _version_problem(document, int(entry["version"]))
	if not version_problem.is_empty():
		result.add(id, version_problem)
		return result

	var checked: ContentResult = SchemaValidator.validate(document, entry["schema"])
	if not checked.ok():
		for message: String in checked.errors:
			result.add(id, message)
		return result
	result.data = document
	return result


## Loads every registered document and reports all problems together. Used by
## the content validator tool and by tests.
func validate_all() -> ContentResult:
	var combined: ContentResult = ContentResult.new()
	for id: String in _registry.ids():
		combined.merge(load_content(id))
	return combined


## Empty string when the document's schema_version is acceptable.
static func _version_problem(document: Dictionary, supported: int) -> String:
	var value: Variant = document.get("schema_version")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return "is missing a numeric schema_version"
	var number: float = float(value)
	if is_nan(number) or is_inf(number) or number < 1.0 or number != floorf(number):
		return "has an invalid schema_version"
	if int(number) > supported:
		return "was made for a newer version of the game (schema_version %d, this build reads %d)" % [int(number), supported]
	return ""
