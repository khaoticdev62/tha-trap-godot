class_name SaveMigrations
extends RefCounted
## Linear migration chain for save payloads.
## To change the save layout: bump AppConfig.SAVE_SCHEMA_VERSION and register a
## step for the OLD version in `_steps()` that returns the upgraded payload.

## Result: { "ok": bool, "payload": Dictionary, "error": String }
static func migrate(payload: Dictionary, from_version: int, to_version: int, steps: Dictionary = {}) -> Dictionary:
	if from_version > to_version:
		return _fail("Save is newer (v%d) than this build understands (v%d)." % [from_version, to_version])
	if from_version < 1:
		return _fail("Save version %d is not valid." % from_version)
	var active_steps: Dictionary = steps if not steps.is_empty() else _steps()
	var current: Dictionary = payload.duplicate(true)
	var version: int = from_version
	while version < to_version:
		if not active_steps.has(version):
			return _fail("No migration step registered from v%d." % version)
		var step: Callable = active_steps[version]
		var upgraded: Variant = step.call(current)
		if typeof(upgraded) != TYPE_DICTIONARY:
			return _fail("Migration step from v%d returned invalid data." % version)
		current = upgraded
		version += 1
	return {"ok": true, "payload": current, "error": ""}


## Registered steps, keyed by the version they upgrade FROM.
static func _steps() -> Dictionary:
	return {1: _v1_to_v2}


## v1 saved only the profile. v2 adds mission progress and save metadata; an
## empty `progress` means "new game" to the loader, so nothing is lost or
## invented.
static func _v1_to_v2(payload: Dictionary) -> Dictionary:
	var upgraded: Dictionary = payload.duplicate(true)
	if not upgraded.has("progress"):
		upgraded["progress"] = {}
	if not upgraded.has("meta"):
		upgraded["meta"] = {}
	return upgraded


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "payload": {}, "error": reason}
