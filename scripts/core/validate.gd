class_name Validate
extends RefCounted
## Defensive coercion for untrusted data (hand-edited saves and settings files).


## Only a real boolean true enables a flag; strings and numbers never do.
## (Comparing a String to a bool with == raises in GDScript, so test the type.)
static func strict_bool(value: Variant) -> bool:
	return typeof(value) == TYPE_BOOL and value


## Numbers only, finite, clamped to [low, high]; anything else gives `fallback`.
static func clamped_float(value: Variant, low: float, high: float, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number: float = float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return clampf(number, low, high)
