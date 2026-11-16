class_name CharacterOptions
extends RefCounted
## Cosmetic character choices (Game Bible §6). Every option is purely visual:
## none changes stats, dialogue outcomes or progression, and none is locked.
## Options have stable ids (what gets saved) and display names (what is shown),
## so renaming a label never invalidates an existing save.

const PRONOUNS: Array[Dictionary] = [
	{"id": "", "name": "Prefer not to say"},
	{"id": "she/her", "name": "she/her"},
	{"id": "he/him", "name": "he/him"},
	{"id": "they/them", "name": "they/them"},
	{"id": "she/they", "name": "she/they"},
	{"id": "he/they", "name": "he/they"},
]

const SKIN_TONES: Array[Dictionary] = [
	{"id": "tone_fair", "name": "Fair", "color": Color8(0xF3, 0xD2, 0xB8)},
	{"id": "tone_light", "name": "Light", "color": Color8(0xE2, 0xB4, 0x8E)},
	{"id": "tone_tan", "name": "Tan", "color": Color8(0xC6, 0x8E, 0x62)},
	{"id": "tone_medium_brown", "name": "Medium brown", "color": Color8(0xA2, 0x6B, 0x43)},
	{"id": "tone_brown", "name": "Brown", "color": Color8(0x7E, 0x4E, 0x2F)},
	{"id": "tone_deep_brown", "name": "Deep brown", "color": Color8(0x5A, 0x36, 0x20)},
	{"id": "tone_espresso", "name": "Espresso", "color": Color8(0x3D, 0x24, 0x16)},
]

const HAIR_STYLES: Array[Dictionary] = [
	{"id": "hair_low_fade", "name": "Low fade"},
	{"id": "hair_waves", "name": "Waves"},
	{"id": "hair_locs", "name": "Locs"},
	{"id": "hair_box_braids", "name": "Box braids"},
	{"id": "hair_twists", "name": "Twists"},
	{"id": "hair_natural", "name": "Natural"},
	{"id": "hair_cornrows", "name": "Cornrows"},
	{"id": "hair_shaved", "name": "Shaved"},
]

const OUTFIT_PALETTES: Array[Dictionary] = [
	{"id": "outfit_signal_purple", "name": "Signal purple", "color": Palette.SIGNAL_PURPLE},
	{"id": "outfit_copper", "name": "Copper", "color": Palette.COPPER},
	{"id": "outfit_ice_blue", "name": "Ice blue", "color": Palette.ICE_BLUE},
	{"id": "outfit_safe_green", "name": "Safe green", "color": Palette.SAFE_GREEN},
	{"id": "outfit_streetlight_gold", "name": "Streetlight gold", "color": Palette.STREETLIGHT_GOLD},
]


## Returns `value` when it is a known id in `options`, else the first option's id.
static func valid_id(options: Array[Dictionary], value: Variant) -> String:
	if typeof(value) == TYPE_STRING:
		for option: Dictionary in options:
			if option["id"] == value:
				return value
	return options[0]["id"]


static func index_of(options: Array[Dictionary], id: String) -> int:
	for index: int in options.size():
		if options[index]["id"] == id:
			return index
	return 0
