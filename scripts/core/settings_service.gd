class_name SettingsService
extends Node
## Owns and persists AccessibilitySettings (autoload "Settings").
## File: user://settings.json, written atomically (temp file, then rename).
## A missing, oversized or corrupt file silently yields defaults; the player is
## never blocked from starting the game by a bad settings file.

signal changed(settings: AccessibilitySettings)

const MAX_FILE_BYTES: int = 64 * 1024

var settings_path: String = "user://settings.json"
var current: AccessibilitySettings = AccessibilitySettings.new()
## Set false in tests that run outside the scene tree.
var apply_theme_to_root: bool = true


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	current = _read()
	_publish()


## Applies a validated change and persists it. Returns false if saving failed
## (the in-memory change still applies so the session stays consistent).
func update(text_scale: float, reduced_motion: bool, high_contrast: bool, text_speed: String) -> bool:
	var candidate: Dictionary = {
		"text_scale": text_scale,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"text_speed": text_speed,
	}
	current = AccessibilitySettings.from_dict(candidate)
	_publish()
	return _write()


func reset_to_defaults() -> bool:
	current = AccessibilitySettings.new()
	_publish()
	return _write()


func _publish() -> void:
	if apply_theme_to_root and is_inside_tree():
		get_tree().root.theme = UiTheme.build(current)
	changed.emit(current)


func _read() -> AccessibilitySettings:
	if not FileAccess.file_exists(settings_path):
		return AccessibilitySettings.new()
	var file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return AccessibilitySettings.new()
	var text: String = file.get_as_text()
	file = null
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return AccessibilitySettings.new()
	return AccessibilitySettings.from_dict(parser.data)


func _write() -> bool:
	var temp_path: String = settings_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(current.to_dict(), "\t", true))
	file.flush()
	file = null
	if DirAccess.rename_absolute(temp_path, settings_path) != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	return true
