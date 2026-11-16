class_name ProfileService
extends Node
## Owns the active PlayerProfile (autoload "Profiles").

signal profile_changed(profile: PlayerProfile)

var current: PlayerProfile = PlayerProfile.new()


## Builds a validated profile from raw character-creator input.
func create(display_name: String, pronouns: String, skin_tone: String, hair_style: String, outfit_palette: String) -> PlayerProfile:
	_set_current(PlayerProfile.from_dict({
		"display_name": display_name,
		"pronouns": pronouns,
		"skin_tone": skin_tone,
		"hair_style": hair_style,
		"outfit_palette": outfit_palette,
	}))
	return current


func load_from_payload(payload: Dictionary) -> PlayerProfile:
	_set_current(PlayerProfile.from_dict(payload.get("profile", {})))
	return current


func to_payload() -> Dictionary:
	return {"profile": current.to_dict()}


func _set_current(profile: PlayerProfile) -> void:
	current = profile
	profile_changed.emit(current)
