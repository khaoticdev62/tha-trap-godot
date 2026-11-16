class_name ProfileService
extends Node
## Owns the active PlayerProfile (autoload "Profiles").

signal profile_changed(profile: PlayerProfile)

var current: PlayerProfile = PlayerProfile.new()


func start_new(display_name: String) -> PlayerProfile:
	var fresh: PlayerProfile = PlayerProfile.new()
	fresh.display_name = PlayerProfile.sanitize_name(display_name, AppConfig.DEFAULT_PROFILE_NAME, AppConfig.PROFILE_NAME_MAX_LENGTH)
	_set_current(fresh)
	return current


func load_from_payload(payload: Dictionary) -> PlayerProfile:
	_set_current(PlayerProfile.from_dict(payload.get("profile", {})))
	return current


func to_payload() -> Dictionary:
	return {"profile": current.to_dict()}


func _set_current(profile: PlayerProfile) -> void:
	current = profile
	profile_changed.emit(current)
