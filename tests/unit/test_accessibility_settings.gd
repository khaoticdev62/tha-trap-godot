extends TestCase


func test_defaults() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	check_eq(settings.text_scale, 1.0, "default scale")
	check(not settings.reduced_motion, "motion on by default")
	check(not settings.high_contrast, "standard contrast by default")


func test_round_trip() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	settings.text_scale = 1.5
	settings.reduced_motion = true
	settings.high_contrast = true
	check_eq(AccessibilitySettings.from_dict(settings.to_dict()).to_dict(), settings.to_dict(), "lossless")


func test_garbage_gives_defaults() -> void:
	for junk: Variant in [null, 5, "x", [], PackedByteArray()]:
		check_eq(AccessibilitySettings.from_dict(junk).to_dict(), AccessibilitySettings.new().to_dict(), "junk %s" % str(junk))


func test_wrong_types_fall_back() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.from_dict({
		"text_scale": "big", "reduced_motion": "yes", "high_contrast": 1,
	})
	check_eq(settings.text_scale, 1.0, "string scale")
	check(not settings.reduced_motion, "string is not true")
	check(not settings.high_contrast, "number is not true")


func test_scale_is_clamped_snapped_and_finite() -> void:
	check_eq(AccessibilitySettings.from_dict({"text_scale": 99}).text_scale, AppConfig.TEXT_SCALE_MAX, "max")
	check_eq(AccessibilitySettings.from_dict({"text_scale": -3}).text_scale, AppConfig.TEXT_SCALE_MIN, "min")
	check_eq(AccessibilitySettings.from_dict({"text_scale": NAN}).text_scale, 1.0, "NaN")
	check_eq(AccessibilitySettings.from_dict({"text_scale": INF}).text_scale, 1.0, "INF")
	check_eq(AccessibilitySettings.from_dict({"text_scale": 1.13}).text_scale, 1.25, "snaps to the step")
	check_eq(AccessibilitySettings.from_dict({"text_scale": 1.1}).text_scale, 1.0, "snaps down when closer")


func test_motion_duration_honours_reduced_motion() -> void:
	var settings: AccessibilitySettings = AccessibilitySettings.new()
	check_eq(settings.motion_duration(0.3), 0.3, "full motion keeps duration")
	check_eq(settings.motion_duration(-1.0), 0.0, "negative durations are floored")
	settings.reduced_motion = true
	check_eq(settings.motion_duration(0.3), 0.0, "reduced motion is instant")
