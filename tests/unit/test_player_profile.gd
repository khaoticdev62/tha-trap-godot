extends TestCase


func test_defaults_are_valid() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	check_eq(profile.display_name, AppConfig.DEFAULT_PROFILE_NAME, "default name")
	check_eq(profile.pronouns, "", "no pronouns by default")
	check_eq(profile.playtime_seconds, 0.0, "no playtime by default")


func test_round_trip() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	profile.display_name = "Mo"
	profile.pronouns = "they/them"
	profile.playtime_seconds = 90.0
	var copy: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	check_eq(copy.to_dict(), profile.to_dict(), "to_dict/from_dict is lossless")


func test_garbage_input_gives_defaults() -> void:
	for junk: Variant in [null, 5, "text", [], PackedByteArray()]:
		check_eq(PlayerProfile.from_dict(junk).display_name, AppConfig.DEFAULT_PROFILE_NAME, "junk %s" % str(junk))


func test_wrong_field_types_fall_back() -> void:
	var profile: PlayerProfile = PlayerProfile.from_dict({
		"display_name": 12, "pronouns": [], "playtime_seconds": null,
	})
	check_eq(profile.display_name, AppConfig.DEFAULT_PROFILE_NAME, "name falls back")
	check_eq(profile.pronouns, "", "pronouns fall back")
	check_eq(profile.playtime_seconds, 0.0, "playtime falls back")


func test_playtime_is_clamped_and_non_finite_rejected() -> void:
	check_eq(PlayerProfile.from_dict({"playtime_seconds": -10}).playtime_seconds, 0.0, "negative playtime")
	check_eq(PlayerProfile.from_dict({"playtime_seconds": NAN}).playtime_seconds, 0.0, "NaN playtime")
	check_eq(PlayerProfile.from_dict({"playtime_seconds": 9.9e20}).playtime_seconds, 3.0e8, "huge playtime")


func test_legacy_accessibility_keys_are_ignored() -> void:
	var profile: PlayerProfile = PlayerProfile.from_dict({"display_name": "Old", "text_scale": 3, "reduced_motion": true})
	check_eq(profile.display_name, "Old", "known keys still load")
	check(not profile.to_dict().has("text_scale"), "accessibility no longer lives in the profile")


func test_name_sanitising() -> void:
	var fallback: String = AppConfig.DEFAULT_PROFILE_NAME
	var limit: int = AppConfig.PROFILE_NAME_MAX_LENGTH
	check_eq(PlayerProfile.sanitize_name("", fallback, limit), fallback, "empty")
	check_eq(PlayerProfile.sanitize_name("   \t  ", fallback, limit), fallback, "whitespace only")
	check_eq(PlayerProfile.sanitize_name("  Ava   Lee  ", fallback, limit), "Ava Lee", "trim and collapse")
	check_eq(PlayerProfile.sanitize_name("Ava\nLee\r", fallback, limit), "AvaLee", "newlines stripped")
	var bell: String = String.chr(0x07)
	var rlo: String = String.chr(0x202E)
	var lre: String = String.chr(0x202A)
	var zwsp: String = String.chr(0x200B)
	check_eq(PlayerProfile.sanitize_name("A" + bell + "B" + String.chr(0x7F) + "C", fallback, limit), "ABC", "control chars stripped")
	check_eq(PlayerProfile.sanitize_name("a" + rlo + "b" + lre + "c", fallback, limit), "abc", "bidi overrides stripped")
	check_eq(PlayerProfile.sanitize_name("a" + zwsp + "b", fallback, limit), "ab", "zero-width stripped")
	check_eq(PlayerProfile.sanitize_name("x".repeat(500), fallback, limit).length(), limit, "long names truncated")
	check_eq(PlayerProfile.sanitize_name("<b>Hi</b> ' OR 1=1", fallback, limit), "<b>Hi</b> ' OR 1=1", "markup-like text kept as plain text")
	check_eq(PlayerProfile.sanitize_name("Zoë 🛡️", fallback, limit), "Zoë 🛡️", "unicode and emoji kept")
	check_eq(PlayerProfile.sanitize_name("مرحبا", fallback, limit), "مرحبا", "RTL text kept")
	check_eq(PlayerProfile.sanitize_name(["x"], fallback, limit), fallback, "non-string")
