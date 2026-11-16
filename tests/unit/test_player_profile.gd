extends TestCase


func test_defaults_are_valid() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	check_eq(profile.display_name, AppConfig.DEFAULT_PROFILE_NAME, "default name")
	check_eq(profile.text_scale, 1.0, "default text scale")
	check(not profile.reduced_motion, "motion on by default")


func test_round_trip() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.display_name = "Mo"
	profile.pronouns = "they/them"
	profile.text_scale = 1.5
	profile.reduced_motion = true
	profile.high_contrast = true
	profile.playtime_seconds = 90.0
	var copy: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	check_eq(copy.to_dict(), profile.to_dict(), "to_dict/from_dict is lossless")


func test_garbage_input_gives_defaults() -> void:
	for junk: Variant in [null, 5, "text", [], PackedByteArray()]:
		check_eq(PlayerProfile.from_dict(junk).display_name, AppConfig.DEFAULT_PROFILE_NAME, "junk %s" % str(junk))


func test_wrong_field_types_fall_back() -> void:
	var profile: PlayerProfile = PlayerProfile.from_dict({
		"display_name": 12, "pronouns": [], "text_scale": "big",
		"reduced_motion": "yes", "high_contrast": 1, "playtime_seconds": null,
	})
	check_eq(profile.display_name, AppConfig.DEFAULT_PROFILE_NAME, "name falls back")
	check_eq(profile.pronouns, "", "pronouns fall back")
	check_eq(profile.text_scale, 1.0, "scale falls back")
	check(not profile.reduced_motion, "only literal true enables flags")
	check(not profile.high_contrast, "numeric 1 is not true")
	check_eq(profile.playtime_seconds, 0.0, "playtime falls back")


func test_numbers_are_clamped_and_non_finite_rejected() -> void:
	check_eq(PlayerProfile.from_dict({"text_scale": 99}).text_scale, AppConfig.TEXT_SCALE_MAX, "scale max")
	check_eq(PlayerProfile.from_dict({"text_scale": -3}).text_scale, AppConfig.TEXT_SCALE_MIN, "scale min")
	check_eq(PlayerProfile.from_dict({"text_scale": NAN}).text_scale, 1.0, "NaN scale")
	check_eq(PlayerProfile.from_dict({"text_scale": INF}).text_scale, 1.0, "INF scale")
	check_eq(PlayerProfile.from_dict({"playtime_seconds": -10}).playtime_seconds, 0.0, "negative playtime")


func test_name_sanitising() -> void:
	var fallback: String = AppConfig.DEFAULT_PROFILE_NAME
	var limit: int = AppConfig.PROFILE_NAME_MAX_LENGTH
	check_eq(PlayerProfile.sanitize_name("", fallback, limit), fallback, "empty")
	check_eq(PlayerProfile.sanitize_name("   \t  ", fallback, limit), fallback, "whitespace only")
	check_eq(PlayerProfile.sanitize_name("  Ava   Lee  ", fallback, limit), "Ava Lee", "trim and collapse")
	check_eq(PlayerProfile.sanitize_name("Ava\nLee\r", fallback, limit), "AvaLee", "newlines stripped")
	var nul: String = String.chr(0x07)
	var rlo: String = String.chr(0x202E)
	var lre: String = String.chr(0x202A)
	var zwsp: String = String.chr(0x200B)
	check_eq(PlayerProfile.sanitize_name("A" + nul + "B" + String.chr(0x7F) + "C", fallback, limit), "ABC", "control chars stripped")
	check_eq(PlayerProfile.sanitize_name("a" + rlo + "b" + lre + "c", fallback, limit), "abc", "bidi overrides stripped")
	check_eq(PlayerProfile.sanitize_name("a" + zwsp + "b", fallback, limit), "ab", "zero-width stripped")
	check_eq(PlayerProfile.sanitize_name("x".repeat(500), fallback, limit).length(), limit, "long names truncated")
	check_eq(PlayerProfile.sanitize_name("<b>Hi</b> ' OR 1=1", fallback, limit), "<b>Hi</b> ' OR 1=1", "markup-like text kept as plain text")
	check_eq(PlayerProfile.sanitize_name("Zoë 🛡️", fallback, limit), "Zoë 🛡️", "unicode and emoji kept")
	check_eq(PlayerProfile.sanitize_name("مرحبا", fallback, limit), "مرحبا", "RTL text kept")
	check_eq(PlayerProfile.sanitize_name(["x"], fallback, limit), fallback, "non-string")
