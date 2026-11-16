extends TestCase


func _all_lists() -> Array:
	return [
		["pronouns", CharacterOptions.PRONOUNS],
		["skin tones", CharacterOptions.SKIN_TONES],
		["hair styles", CharacterOptions.HAIR_STYLES],
		["outfit palettes", CharacterOptions.OUTFIT_PALETTES],
	]


func test_every_option_has_a_unique_id_and_a_visible_name() -> void:
	for entry: Array in _all_lists():
		var seen: Dictionary = {}
		var options: Array[Dictionary] = entry[1]
		check(options.size() >= 2, "%s offers a real choice" % entry[0])
		for option: Dictionary in options:
			check(option.has("id") and option.has("name"), "%s entries have id and name" % entry[0])
			check(not str(option["name"]).strip_edges().is_empty(), "%s: option '%s' has a display name" % [entry[0], option["id"]])
			check(not seen.has(option["id"]), "%s: id '%s' is unique" % [entry[0], option["id"]])
			seen[option["id"]] = true


func test_ids_are_stable_machine_names_not_display_text() -> void:
	for options: Array[Dictionary] in [CharacterOptions.SKIN_TONES, CharacterOptions.HAIR_STYLES, CharacterOptions.OUTFIT_PALETTES]:
		for option: Dictionary in options:
			var id: String = option["id"]
			check(id == id.to_lower() and not id.contains(" "), "id '%s' is lowercase with no spaces" % id)


func test_swatch_lists_define_a_colour_for_every_option() -> void:
	for options: Array[Dictionary] in [CharacterOptions.SKIN_TONES, CharacterOptions.OUTFIT_PALETTES]:
		for option: Dictionary in options:
			check(option["color"] is Color, "'%s' has a colour" % option["id"])


func test_skin_tones_cover_a_wide_range_in_order() -> void:
	var previous_luminance: float = 2.0
	for option: Dictionary in CharacterOptions.SKIN_TONES:
		var color: Color = option["color"]
		check(color.get_luminance() < previous_luminance, "'%s' is darker than the one before it" % option["id"])
		previous_luminance = color.get_luminance()
	check(CharacterOptions.SKIN_TONES.size() >= 6, "at least six tones")


func test_valid_id_accepts_known_and_rejects_everything_else() -> void:
	check_eq(CharacterOptions.valid_id(CharacterOptions.HAIR_STYLES, "hair_locs"), "hair_locs", "known id")
	check_eq(CharacterOptions.valid_id(CharacterOptions.HAIR_STYLES, "nope"), "hair_low_fade", "unknown id gives first")
	check_eq(CharacterOptions.valid_id(CharacterOptions.HAIR_STYLES, 3), "hair_low_fade", "non-string gives first")
	check_eq(CharacterOptions.valid_id(CharacterOptions.HAIR_STYLES, null), "hair_low_fade", "null gives first")


func test_index_of_finds_ids_and_defaults_to_zero() -> void:
	check_eq(CharacterOptions.index_of(CharacterOptions.HAIR_STYLES, "hair_locs"), 2, "found")
	check_eq(CharacterOptions.index_of(CharacterOptions.HAIR_STYLES, "missing"), 0, "missing gives 0")
