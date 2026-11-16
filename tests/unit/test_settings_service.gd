extends TestCase

var _service: SettingsService
var _path: String


func before_each() -> void:
	_path = "user://test_settings_%d.json" % Time.get_ticks_usec()
	_service = SettingsService.new()
	_service.settings_path = _path
	_service.apply_theme_to_root = false


func after_each() -> void:
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(_path + suffix):
			DirAccess.remove_absolute(_path + suffix)
	_service.free()


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file = null


func test_missing_file_gives_defaults() -> void:
	_service.load_from_disk()
	check_eq(_service.current.to_dict(), AccessibilitySettings.new().to_dict(), "defaults")


func test_update_persists_and_reloads() -> void:
	check(_service.update(1.5, true, true, "normal"), "update saves")
	var other: SettingsService = SettingsService.new()
	other.settings_path = _path
	other.apply_theme_to_root = false
	other.load_from_disk()
	check_eq(other.current.text_scale, 1.5, "scale persisted")
	check(other.current.reduced_motion, "motion persisted")
	check(other.current.high_contrast, "contrast persisted")
	other.free()


func test_text_speed_persists_and_bad_values_are_rejected() -> void:
	_service.update(1.0, false, false, "slow")
	var other: SettingsService = SettingsService.new()
	other.settings_path = _path
	other.apply_theme_to_root = false
	other.load_from_disk()
	check_eq(other.current.text_speed, "slow", "speed persisted")
	other.free()
	_service.update(1.0, false, false, "ludicrous")
	check_eq(_service.current.text_speed, "normal", "unknown speed falls back")


func test_update_validates_input() -> void:
	_service.update(500.0, true, false, "normal")
	check_eq(_service.current.text_scale, AppConfig.TEXT_SCALE_MAX, "out-of-range scale is clamped before saving")
	_service.update(NAN, false, false, "normal")
	check_eq(_service.current.text_scale, 1.0, "NaN scale is rejected")


func test_reset_restores_defaults_and_persists() -> void:
	_service.update(2.0, true, true, "normal")
	check(_service.reset_to_defaults(), "reset saves")
	_service.load_from_disk()
	check_eq(_service.current.to_dict(), AccessibilitySettings.new().to_dict(), "defaults after reload")


func test_corrupt_files_never_block_startup() -> void:
	for text: String in ["", "{ not json", "null", "[1,2]", "\"str\"", "{\"text_scale\": \"huge\"}"]:
		_write_raw(text)
		_service.load_from_disk()
		check_eq(_service.current.to_dict(), AccessibilitySettings.new().to_dict(), "defaults for '%s'" % text)


func test_oversized_file_is_ignored() -> void:
	_write_raw(" ".repeat(SettingsService.MAX_FILE_BYTES + 1))
	_service.load_from_disk()
	check_eq(_service.current.to_dict(), AccessibilitySettings.new().to_dict(), "defaults for oversized file")


func test_no_temp_file_left_behind() -> void:
	_service.update(1.25, false, false, "normal")
	check(not FileAccess.file_exists(_path + ".tmp"), "temp file renamed away")


func test_changed_signal_fires_with_new_values() -> void:
	var seen: Array[float] = []
	_service.changed.connect(func(settings: AccessibilitySettings) -> void: seen.append(settings.text_scale))
	_service.update(1.75, false, false, "normal")
	_service.reset_to_defaults()
	check_eq(seen, [1.75, 1.0] as Array[float], "signal carries each new state")


func test_unwritable_path_reports_failure_but_keeps_session_state() -> void:
	_service.settings_path = "user://no_such_dir_%d/settings.json" % Time.get_ticks_usec()
	check(not _service.update(1.5, false, false, "normal"), "failed save is reported")
	check_eq(_service.current.text_scale, 1.5, "in-memory change still applies")
