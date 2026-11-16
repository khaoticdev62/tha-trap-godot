class_name Typewriter
extends RefCounted
## Pure maths for the dialogue reveal effect, kept separate from nodes so it can
## be unit tested. Reduced motion and the "instant" speed show the whole line at
## once (a reveal is motion). Speed never gates information: the player can
## always finish a line immediately.

const CHARS_PER_SECOND: Dictionary = {
	"slow": 20.0,
	"normal": 45.0,
	"fast": 90.0,
	"instant": 0.0,
}


static func chars_per_second(speed_id: String) -> float:
	return CHARS_PER_SECOND.get(AccessibilitySettings.valid_text_speed(speed_id), 0.0)


## Number of characters visible `elapsed` seconds after the line started.
static func visible_chars(elapsed: float, total_chars: int, speed_id: String, reduced_motion: bool) -> int:
	if total_chars <= 0:
		return 0
	var rate: float = chars_per_second(speed_id)
	if reduced_motion or rate <= 0.0 or is_nan(elapsed):
		return total_chars
	return clampi(floori(maxf(elapsed, 0.0) * rate), 0, total_chars)


static func is_complete(elapsed: float, total_chars: int, speed_id: String, reduced_motion: bool) -> bool:
	return visible_chars(elapsed, total_chars, speed_id, reduced_motion) >= total_chars
