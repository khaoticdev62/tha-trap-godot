class_name DiagnosticsService
extends Node
## Local-only diagnostics (autoload "Diagnostics").
## Writes a size-capped log under user://logs. Nothing is transmitted anywhere;
## there is no telemetry. Every message is redacted before it is stored.

const MEMORY_LIMIT: int = 200

var log_dir: String = AppConfig.LOG_DIR
var write_to_disk: bool = true

var _recent: PackedStringArray = PackedStringArray()


func info(message: String) -> void:
	_record("INFO", message)


func warn(message: String) -> void:
	_record("WARN", message)


func error(message: String) -> void:
	_record("ERROR", message)


func recent_entries() -> PackedStringArray:
	return _recent.duplicate()


## Strips personal data and secret-looking values from text destined for logs.
static func redact(text: String) -> String:
	var result: String = text
	for rule: Array in _redaction_rules():
		var regex: RegEx = rule[0]
		result = regex.sub(result, rule[1], true)
	return result


static func _redaction_rules() -> Array:
	var rules: Array = []
	var specs: Array = [
		# Windows and POSIX home directories: keep the shape, drop the name.
		["(?i)([a-z]:[\\\\/]+users[\\\\/]+)[^\\\\/\\s\"']+", "$1<user>"],
		["(/(?:home|Users)/)[^/\\s\"']+", "$1<user>"],
		# key=value / key: value pairs that look like credentials.
		["(?i)\\b(password|passwd|secret|token|api[_-]?key|authorization)\\b\\s*[=:]\\s*\\S+", "$1=<redacted>"],
		# Long opaque tokens (hex / base64-ish, 32+ chars).
		["\\b[A-Za-z0-9+/_-]{32,}={0,2}", "<redacted-token>"],
	]
	for spec: Array in specs:
		var regex: RegEx = RegEx.new()
		if regex.compile(spec[0]) == OK:
			rules.append([regex, spec[1]])
	return rules


func _record(level: String, message: String) -> void:
	var line: String = "%s [%s] %s" % [Time.get_datetime_string_from_system(true), level, redact(message)]
	_recent.append(line)
	if _recent.size() > MEMORY_LIMIT:
		_recent.remove_at(0)
	if write_to_disk:
		_append_to_file(line)


func _append_to_file(line: String) -> void:
	if DirAccess.make_dir_recursive_absolute(log_dir) != OK:
		return
	var path: String = log_dir.path_join(AppConfig.LOG_FILE)
	if FileAccess.file_exists(path):
		var existing: FileAccess = FileAccess.open(path, FileAccess.READ)
		var too_big: bool = existing != null and existing.get_length() > AppConfig.LOG_MAX_BYTES
		existing = null
		if too_big:
			var rotated: String = path + ".1"
			if FileAccess.file_exists(rotated):
				DirAccess.remove_absolute(rotated)
			DirAccess.rename_absolute(path, rotated)
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file: FileAccess = FileAccess.open(path, mode)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
