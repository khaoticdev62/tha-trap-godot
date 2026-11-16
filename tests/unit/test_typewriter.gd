extends TestCase


func test_every_speed_id_has_a_rate() -> void:
	for option: Dictionary in AccessibilitySettings.TEXT_SPEEDS:
		check(Typewriter.CHARS_PER_SECOND.has(option["id"]), "rate defined for '%s'" % option["id"])


func test_speeds_are_ordered_slow_to_fast() -> void:
	var slow: float = Typewriter.chars_per_second("slow")
	var normal: float = Typewriter.chars_per_second("normal")
	var fast: float = Typewriter.chars_per_second("fast")
	check(slow > 0.0 and slow < normal and normal < fast, "slow < normal < fast, all positive")
	check_eq(Typewriter.chars_per_second("instant"), 0.0, "instant has no typing rate")


func test_reveal_grows_with_time_and_never_exceeds_total() -> void:
	check_eq(Typewriter.visible_chars(0.0, 100, "normal", false), 0, "nothing at t=0")
	check_eq(Typewriter.visible_chars(1.0, 100, "normal", false), 45, "one second of normal speed")
	check_eq(Typewriter.visible_chars(999.0, 100, "normal", false), 100, "capped at total")
	check(Typewriter.visible_chars(0.5, 100, "fast", false) > Typewriter.visible_chars(0.5, 100, "slow", false), "fast reveals more than slow")


func test_instant_and_reduced_motion_show_everything_at_once() -> void:
	check_eq(Typewriter.visible_chars(0.0, 50, "instant", false), 50, "instant speed")
	check_eq(Typewriter.visible_chars(0.0, 50, "slow", true), 50, "reduced motion overrides speed")


func test_hostile_inputs_are_safe() -> void:
	check_eq(Typewriter.visible_chars(-5.0, 10, "normal", false), 0, "negative time clamps to zero")
	check_eq(Typewriter.visible_chars(NAN, 10, "normal", false), 10, "NaN time shows the line rather than hiding it")
	check_eq(Typewriter.visible_chars(1.0, 0, "normal", false), 0, "empty text")
	check_eq(Typewriter.visible_chars(1.0, -3, "normal", false), 0, "negative length")
	check_eq(Typewriter.chars_per_second("warp-speed"), Typewriter.chars_per_second("normal"), "unknown id uses the default speed")
	check_eq(Typewriter.chars_per_second(""), Typewriter.chars_per_second("normal"), "empty id uses the default speed")


func test_is_complete() -> void:
	check(not Typewriter.is_complete(0.1, 100, "slow", false), "not complete early")
	check(Typewriter.is_complete(100.0, 100, "slow", false), "complete eventually")
	check(Typewriter.is_complete(0.0, 100, "instant", false), "instant is complete immediately")
	check(Typewriter.is_complete(0.0, 0, "slow", false), "empty line is complete")
