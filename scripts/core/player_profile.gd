class_name PlayerProfile
extends RefCounted
## Player identity and accessibility preferences.
## Cosmetic and identity choices never change stats or outcomes (Game Bible §6).
## All input is untrusted (it may come from a hand-edited save), so from_dict
## validates and clamps every field.

const MAX_PRONOUNS_LENGTH: int = 24

var display_name: String = AppConfig.DEFAULT_PROFILE_NAME
var pronouns: String = ""
var text_scale: float = 1.0
var reduced_motion: bool = false
var high_contrast: bool = false
var playtime_seconds: float = 0.0


func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"pronouns": pronouns,
		"text_scale": text_scale,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"playtime_seconds": playtime_seconds,
	}


static func from_dict(data: Variant) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	if typeof(data) != TYPE_DICTIONARY:
		return profile
	var source: Dictionary = data
	profile.display_name = sanitize_name(source.get("display_name", ""), AppConfig.DEFAULT_PROFILE_NAME, AppConfig.PROFILE_NAME_MAX_LENGTH)
	profile.pronouns = sanitize_name(source.get("pronouns", ""), "", MAX_PRONOUNS_LENGTH)
	profile.text_scale = _clamped_float(source.get("text_scale", 1.0), AppConfig.TEXT_SCALE_MIN, AppConfig.TEXT_SCALE_MAX, 1.0)
	profile.reduced_motion = _strict_bool(source.get("reduced_motion", false))
	profile.high_contrast = _strict_bool(source.get("high_contrast", false))
	profile.playtime_seconds = _clamped_float(source.get("playtime_seconds", 0.0), 0.0, 3.0e8, 0.0)
	return profile


## Trims, removes control characters and bidi-override characters, collapses
## runs of whitespace and truncates by character count. Falls back when the
## result is empty. Output is plain text: UI Labels never interpret markup.
static func sanitize_name(value: Variant, fallback: String, max_length: int) -> String:
	if typeof(value) != TYPE_STRING:
		return fallback
	var cleaned: String = ""
	var last_was_space: bool = false
	for index: int in (value as String).length():
		var code: int = (value as String).unicode_at(index)
		if _is_stripped(code):
			continue
		if code == 0x20 or code == 0x09 or code == 0xA0:
			if not last_was_space and not cleaned.is_empty():
				cleaned += " "
			last_was_space = true
			continue
		last_was_space = false
		cleaned += String.chr(code)
	cleaned = cleaned.strip_edges()
	if cleaned.length() > max_length:
		cleaned = cleaned.substr(0, max_length).strip_edges()
	return cleaned if not cleaned.is_empty() else fallback


static func _is_stripped(code: int) -> bool:
	if code < 0x20 and code != 0x09:
		return true  # C0 controls (newlines included)
	if code >= 0x7F and code <= 0x9F:
		return true  # DEL and C1 controls
	if code >= 0x202A and code <= 0x202E:
		return true  # bidi embeddings/overrides
	if code >= 0x2066 and code <= 0x2069:
		return true  # bidi isolates
	if code >= 0x200B and code <= 0x200F:
		return true  # zero-width and directional marks
	return code == 0xFEFF


## Only a real boolean true enables a flag; strings and numbers never do.
## (Comparing a String to a bool with == raises in GDScript, so test the type.)
static func _strict_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value


static func _clamped_float(value: Variant, low: float, high: float, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number: float = float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return clampf(number, low, high)
