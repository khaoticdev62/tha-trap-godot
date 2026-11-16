class_name AccessibilitySettings
extends RefCounted
## Player-wide accessibility preferences. Stored per machine (not per save slot)
## so they apply on the title screen, before any save is loaded.

const SCHEMA_VERSION: int = 1
const TEXT_SCALE_STEP: float = 0.25
## Motion durations collapse to this when reduced motion is on (0 = instant).
const REDUCED_MOTION_DURATION: float = 0.0

var text_scale: float = 1.0
var reduced_motion: bool = false
var high_contrast: bool = false


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"text_scale": text_scale,
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
	}


## Never fails: unknown keys are ignored and bad values fall back to defaults.
static func from_dict(data: Variant) -> AccessibilitySettings:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	if typeof(data) != TYPE_DICTIONARY:
		return settings
	var source: Dictionary = data
	settings.text_scale = snap_scale(Validate.clamped_float(source.get("text_scale", 1.0), AppConfig.TEXT_SCALE_MIN, AppConfig.TEXT_SCALE_MAX, 1.0))
	settings.reduced_motion = Validate.strict_bool(source.get("reduced_motion", false))
	settings.high_contrast = Validate.strict_bool(source.get("high_contrast", false))
	return settings


static func snap_scale(value: float) -> float:
	var snapped_value: float = snappedf(value, TEXT_SCALE_STEP)
	return clampf(snapped_value, AppConfig.TEXT_SCALE_MIN, AppConfig.TEXT_SCALE_MAX)


## Use for every UI animation duration so reduced motion is honoured everywhere.
func motion_duration(base_seconds: float) -> float:
	return REDUCED_MOTION_DURATION if reduced_motion else maxf(base_seconds, 0.0)
