class_name SaveService
extends Node
## Versioned local saves (autoload "Saves").
##
## On-disk envelope (JSON): { schema_version, checksum, payload_json }.
## `payload_json` is the payload serialised once, so the SHA-256 `checksum`
## covers exactly the bytes that are stored.
##
## Guarantees:
##  - Paths are built from an integer slot only; callers never supply a path.
##  - Writes go to a temp file, are read back and verified, then swapped in.
##  - The previous good save is rotated into numbered backups first.
##  - A corrupt primary falls back to the newest valid backup.
##  - Saves from a newer schema are refused and never overwritten.
##  - No credentials or secrets are stored; payload is gameplay state only.

signal saved(slot: int)
signal save_failed(slot: int, reason: String)
signal loaded(slot: int, recovered_from_backup: bool)
signal load_failed(slot: int, reason: String)

var save_dir: String = AppConfig.SAVE_DIR


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < AppConfig.SAVE_SLOT_COUNT


func has_save(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	return FileAccess.file_exists(_main_path(slot))


func save_slot(slot: int, payload: Dictionary) -> SaveResult:
	var result: SaveResult = _write(slot, payload)
	if result.ok:
		saved.emit(slot)
	else:
		save_failed.emit(slot, result.message)
	return result


func load_slot(slot: int) -> SaveResult:
	var result: SaveResult = read_slot(slot)
	if result.ok:
		loaded.emit(slot, result.recovered_from_backup)
	else:
		load_failed.emit(slot, result.message)
	return result


## Same as load_slot but emits no signals; used to peek at a slot.
func read_slot(slot: int) -> SaveResult:
	if not is_valid_slot(slot):
		return SaveResult.failure(SaveResult.Code.INVALID_SLOT, "Save slot %d does not exist." % slot)
	var candidates: Array[String] = [_main_path(slot)]
	for index: int in range(1, AppConfig.SAVE_BACKUP_COUNT + 1):
		candidates.append(_backup_path(slot, index))
	var first_failure: SaveResult = null
	for index: int in candidates.size():
		var path: String = candidates[index]
		if not FileAccess.file_exists(path):
			continue
		var attempt: SaveResult = _read_file(path)
		if attempt.ok:
			attempt.recovered_from_backup = index > 0
			return attempt
		if first_failure == null:
			first_failure = attempt
		# A save from a newer build is not corruption: never fall back past it.
		if attempt.code == SaveResult.Code.TOO_NEW:
			return attempt
	if first_failure != null:
		return first_failure
	return SaveResult.failure(SaveResult.Code.NOT_FOUND, "No save in slot %d." % slot)


func delete_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false
	var paths: Array[String] = [_main_path(slot), _temp_path(slot)]
	for index: int in range(1, AppConfig.SAVE_BACKUP_COUNT + 1):
		paths.append(_backup_path(slot, index))
	var all_removed: bool = true
	for path: String in paths:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			all_removed = false
	return all_removed


# --- internals -------------------------------------------------------------

func _write(slot: int, payload: Dictionary) -> SaveResult:
	if not is_valid_slot(slot):
		return SaveResult.failure(SaveResult.Code.INVALID_SLOT, "Save slot %d does not exist." % slot)
	if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
		return SaveResult.failure(SaveResult.Code.IO_ERROR, "Could not create the save folder.")

	var main_path: String = _main_path(slot)
	# Refuse to overwrite a save written by a newer build.
	if FileAccess.file_exists(main_path):
		var existing: SaveResult = _read_file(main_path)
		if not existing.ok and existing.code == SaveResult.Code.TOO_NEW:
			return existing

	var payload_json: String = JSON.stringify(payload, "", true, true)
	var envelope: Dictionary = {
		"schema_version": AppConfig.SAVE_SCHEMA_VERSION,
		"checksum": _checksum(payload_json),
		"payload_json": payload_json,
	}
	var text: String = JSON.stringify(envelope, "", true, true)
	if text.length() > AppConfig.MAX_SAVE_BYTES:
		return SaveResult.failure(SaveResult.Code.TOO_LARGE, "Save data is too large.")

	var temp_path: String = _temp_path(slot)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return SaveResult.failure(SaveResult.Code.IO_ERROR, "Could not open the save file for writing.")
	file.store_string(text)
	file.flush()
	file = null  # close

	var verify: SaveResult = _read_file(temp_path)
	if not verify.ok:
		DirAccess.remove_absolute(temp_path)
		return SaveResult.failure(SaveResult.Code.IO_ERROR, "Save verification failed; previous save kept.")

	_rotate_backups(slot)
	if DirAccess.rename_absolute(temp_path, main_path) != OK:
		DirAccess.remove_absolute(temp_path)
		return SaveResult.failure(SaveResult.Code.IO_ERROR, "Could not finalise the save file.")
	return SaveResult.success(payload)


## Moves the current primary into backup 1 (shifting older backups down), but
## only when the primary is itself valid so a corrupt file never displaces a
## good backup.
func _rotate_backups(slot: int) -> void:
	var main_path: String = _main_path(slot)
	if not FileAccess.file_exists(main_path):
		return
	if not _read_file(main_path).ok:
		return
	for index: int in range(AppConfig.SAVE_BACKUP_COUNT, 1, -1):
		var older: String = _backup_path(slot, index)
		var newer: String = _backup_path(slot, index - 1)
		if FileAccess.file_exists(newer):
			if FileAccess.file_exists(older):
				DirAccess.remove_absolute(older)
			DirAccess.copy_absolute(newer, older)
	var first_backup: String = _backup_path(slot, 1)
	if FileAccess.file_exists(first_backup):
		DirAccess.remove_absolute(first_backup)
	DirAccess.copy_absolute(main_path, first_backup)


func _read_file(path: String) -> SaveResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SaveResult.failure(SaveResult.Code.IO_ERROR, "Could not open the save file.")
	if file.get_length() > AppConfig.MAX_SAVE_BYTES:
		return SaveResult.failure(SaveResult.Code.TOO_LARGE, "Save file is too large.")
	var text: String = file.get_as_text()
	file = null

	var envelope: Variant = _parse_json(text)
	if typeof(envelope) != TYPE_DICTIONARY:
		return SaveResult.failure(SaveResult.Code.CORRUPT, "Save file is not readable.")
	var data: Dictionary = envelope
	var version_value: Variant = data.get("schema_version")
	var payload_json: Variant = data.get("payload_json")
	var checksum: Variant = data.get("checksum")
	if typeof(version_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(payload_json) != TYPE_STRING or typeof(checksum) != TYPE_STRING:
		return SaveResult.failure(SaveResult.Code.CORRUPT, "Save file is missing required fields.")
	if _checksum(payload_json) != checksum:
		return SaveResult.failure(SaveResult.Code.CORRUPT, "Save file failed its integrity check.")

	var parsed: Variant = _parse_json(payload_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return SaveResult.failure(SaveResult.Code.CORRUPT, "Save contents are not readable.")

	var from_version: int = int(version_value)
	if from_version > AppConfig.SAVE_SCHEMA_VERSION:
		return SaveResult.failure(SaveResult.Code.TOO_NEW, "This save was made by a newer version of the game.")
	var migrated: Dictionary = SaveMigrations.migrate(parsed, from_version, AppConfig.SAVE_SCHEMA_VERSION)
	if not migrated["ok"]:
		return SaveResult.failure(SaveResult.Code.MIGRATION_FAILED, migrated["error"])
	return SaveResult.success(migrated["payload"])


## Returns the parsed value, or null on malformed input. Unlike
## JSON.parse_string this does not print engine errors for bad files, which are
## an expected condition here (corrupt saves are handled, not exceptional).
func _parse_json(text: String) -> Variant:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data


func _checksum(text: String) -> String:
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(text.to_utf8_buffer())
	return hasher.finish().hex_encode()


func _main_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func _backup_path(slot: int, index: int) -> String:
	return save_dir.path_join("slot_%d.bak%d" % [slot, index])


func _temp_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.tmp" % slot)
