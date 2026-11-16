class_name PlayerProfile
extends RefCounted
## Player identity. Cosmetic and identity choices never change stats or
## outcomes (Game Bible §6). Accessibility preferences live in
## AccessibilitySettings, not here, so they work before any save is loaded.
## All input is untrusted (it may come from a hand-edited save), so from_dict
## validates every field.

const MAX_PRONOUNS_LENGTH: int = 24

var display_name: String = AppConfig.DEFAULT_PROFILE_NAME
var pronouns: String = ""
var playtime_seconds: float = 0.0


func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"pronouns": pronouns,
		"playtime_seconds": playtime_seconds,
	}


static func from_dict(data: Variant) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	if typeof(data) != TYPE_DICTIONARY:
		return profile
	var source: Dictionary = data
	profile.display_name = sanitize_name(source.get("display_name", ""), AppConfig.DEFAULT_PROFILE_NAME, AppConfig.PROFILE_NAME_MAX_LENGTH)
	profile.pronouns = sanitize_name(source.get("pronouns", ""), "", MAX_PRONOUNS_LENGTH)
	profile.playtime_seconds = Validate.clamped_float(source.get("playtime_seconds", 0.0), 0.0, 3.0e8, 0.0)
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
