extends TestCase

var _save: SaveService
var _dir: String


func before_each() -> void:
	_dir = "user://test_saves_%d" % Time.get_ticks_usec()
	_save = SaveService.new()
	_save.save_dir = _dir


func after_each() -> void:
	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		_save.delete_slot(slot)
	DirAccess.remove_absolute(_dir)
	_save.free()


func _payload(marker: int) -> Dictionary:
	return {"profile": {"display_name": "Tester"}, "marker": marker}


func _corrupt(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not valid json")
	file = null


func test_round_trip_preserves_payload() -> void:
	var saved: SaveResult = _save.save_slot(0, _payload(7))
	check(saved.ok, "save should succeed")
	var loaded: SaveResult = _save.load_slot(0)
	check(loaded.ok, "load should succeed")
	check_eq(loaded.payload["profile"]["display_name"], "Tester", "name survives round trip")
	check_eq(int(loaded.payload["marker"]), 7, "marker survives round trip")
	check(not loaded.recovered_from_backup, "primary load is not a recovery")


func test_missing_slot_reports_not_found() -> void:
	var result: SaveResult = _save.load_slot(1)
	check(not result.ok, "empty slot should fail")
	check_eq(result.code, SaveResult.Code.NOT_FOUND, "code is NOT_FOUND")


func test_invalid_slots_are_rejected() -> void:
	for slot: int in [-1, AppConfig.SAVE_SLOT_COUNT, 99, 2147483647]:
		check_eq(_save.save_slot(slot, _payload(1)).code, SaveResult.Code.INVALID_SLOT, "save rejects slot %d" % slot)
		check_eq(_save.load_slot(slot).code, SaveResult.Code.INVALID_SLOT, "load rejects slot %d" % slot)
		check(not _save.has_save(slot), "has_save false for slot %d" % slot)
		check(not _save.delete_slot(slot), "delete rejects slot %d" % slot)


func test_no_temp_file_left_after_save() -> void:
	_save.save_slot(0, _payload(1))
	check(not FileAccess.file_exists(_dir.path_join("slot_0.tmp")), "temp file is cleaned up")


func test_backups_rotate_and_cap() -> void:
	for marker: int in [1, 2, 3, 4]:
		check(_save.save_slot(0, _payload(marker)).ok, "save %d ok" % marker)
	check(FileAccess.file_exists(_dir.path_join("slot_0.bak1")), "bak1 exists")
	check(FileAccess.file_exists(_dir.path_join("slot_0.bak2")), "bak2 exists")
	check(not FileAccess.file_exists(_dir.path_join("slot_0.bak3")), "no bak3 beyond the cap")
	check_eq(int(_save.load_slot(0).payload["marker"]), 4, "primary holds latest save")


func test_corrupt_primary_recovers_from_backup() -> void:
	_save.save_slot(0, _payload(1))
	_save.save_slot(0, _payload(2))
	_corrupt(_dir.path_join("slot_0.json"))
	var result: SaveResult = _save.load_slot(0)
	check(result.ok, "load should recover")
	check(result.recovered_from_backup, "result is flagged as recovered")
	check_eq(int(result.payload["marker"]), 1, "newest valid backup is used")


func test_corrupt_primary_does_not_displace_good_backup() -> void:
	_save.save_slot(0, _payload(1))
	_save.save_slot(0, _payload(2))
	_corrupt(_dir.path_join("slot_0.json"))
	_save.save_slot(0, _payload(3))
	var backup: SaveResult = _save._read_file(_dir.path_join("slot_0.bak1"))
	check(backup.ok, "bak1 must still be a valid save")
	check_eq(int(backup.payload["marker"]), 1, "bak1 keeps the last good save, not the corrupt file")


func test_everything_corrupt_fails_without_crashing() -> void:
	_save.save_slot(0, _payload(1))
	_save.save_slot(0, _payload(2))
	_save.save_slot(0, _payload(3))
	for suffix: String in ["json", "bak1", "bak2"]:
		_corrupt(_dir.path_join("slot_0.%s" % suffix))
	var result: SaveResult = _save.load_slot(0)
	check(not result.ok, "load fails")
	check_eq(result.code, SaveResult.Code.CORRUPT, "code is CORRUPT")


func test_tampered_payload_fails_checksum() -> void:
	_save.save_slot(0, _payload(1))
	var path: String = _dir.path_join("slot_0.json")
	var text: String = FileAccess.get_file_as_string(path)
	var tampered: String = text.replace("Tester", "Hacker")
	check(tampered != text, "test setup changed the file")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(tampered)
	file = null
	var result: SaveResult = _save.read_slot(0)
	check(not result.ok, "tampered save is rejected")
	check_eq(result.code, SaveResult.Code.CORRUPT, "code is CORRUPT")


func test_malformed_shapes_are_corrupt_not_crashes() -> void:
	var path: String = _dir.path_join("slot_0.json")
	DirAccess.make_dir_recursive_absolute(_dir)
	for text: String in ["", "null", "[]", "42", "{}", "{\"schema_version\":1}", "{\"schema_version\":\"x\",\"checksum\":1,\"payload_json\":2}"]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file = null
		var result: SaveResult = _save.read_slot(0)
		check(not result.ok, "rejects '%s'" % text)
		check_eq(result.code, SaveResult.Code.CORRUPT, "CORRUPT for '%s'" % text)


func test_newer_schema_is_refused_and_not_overwritten() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var payload_json: String = JSON.stringify({"from": "the future"}, "", true, true)
	var envelope: Dictionary = {
		"schema_version": AppConfig.SAVE_SCHEMA_VERSION + 1,
		"checksum": _save._checksum(payload_json),
		"payload_json": payload_json,
	}
	var path: String = _dir.path_join("slot_0.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file = null
	var before: String = FileAccess.get_file_as_string(path)
	check_eq(_save.read_slot(0).code, SaveResult.Code.TOO_NEW, "load refuses newer save")
	check_eq(_save.save_slot(0, _payload(1)).code, SaveResult.Code.TOO_NEW, "save refuses to overwrite newer save")
	check_eq(FileAccess.get_file_as_string(path), before, "newer save file is untouched")


func test_oversized_file_is_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var file: FileAccess = FileAccess.open(_dir.path_join("slot_0.json"), FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0x20]).duplicate())
	file.seek(AppConfig.MAX_SAVE_BYTES + 10)
	file.store_8(0x20)
	file = null
	check_eq(_save.read_slot(0).code, SaveResult.Code.TOO_LARGE, "oversized file is rejected before parsing")


func test_unicode_payload_round_trips() -> void:
	var nasty: String = "Zoë 🛡️ مرحبا <b>x</b> ' OR 1=1 --"
	_save.save_slot(0, {"note": nasty})
	check_eq(_save.load_slot(0).payload["note"], nasty, "unicode and markup-like text are stored verbatim")


func test_delete_removes_all_files() -> void:
	_save.save_slot(0, _payload(1))
	_save.save_slot(0, _payload(2))
	check(_save.delete_slot(0), "delete succeeds")
	check(not _save.has_save(0), "primary removed")
	check(not FileAccess.file_exists(_dir.path_join("slot_0.bak1")), "backup removed")
	check_eq(_save.read_slot(0).code, SaveResult.Code.NOT_FOUND, "slot is empty after delete")


func test_slots_are_isolated() -> void:
	_save.save_slot(0, _payload(10))
	_save.save_slot(1, _payload(20))
	check_eq(int(_save.load_slot(0).payload["marker"]), 10, "slot 0 unchanged")
	check_eq(int(_save.load_slot(1).payload["marker"]), 20, "slot 1 independent")


func test_signals_fire() -> void:
	var events: Array[String] = []
	_save.saved.connect(func(_slot: int) -> void: events.append("saved"))
	_save.save_failed.connect(func(_slot: int, _reason: String) -> void: events.append("save_failed"))
	_save.loaded.connect(func(_slot: int, _recovered: bool) -> void: events.append("loaded"))
	_save.load_failed.connect(func(_slot: int, _reason: String) -> void: events.append("load_failed"))
	_save.save_slot(0, _payload(1))
	_save.load_slot(0)
	_save.load_slot(2)
	_save.save_slot(-5, _payload(1))
	check_eq(events, ["saved", "loaded", "load_failed", "save_failed"] as Array[String], "signals fire in order")
