class_name MissionService
extends RefCounted
## The missions this build ships, read from validated content, and whether the
## player can start each one. Definitions never change at run time; the
## player's record lives in ProgressService.

const LOCKED: String = "locked"
const AVAILABLE: String = "available"
const IN_PROGRESS: String = "in_progress"
const COMPLETED: String = "completed"

var _definitions: Dictionary = {}  # mission id -> {lab_key, title, summary, prerequisites}
## Problems found while loading. Empty means every mission loaded.
var errors: PackedStringArray = PackedStringArray()


static func load_all(loader: ContentLoader, mission_ids: PackedStringArray) -> MissionService:
	var service: MissionService = MissionService.new()
	for mission_id: String in mission_ids:
		var loaded: ContentResult = loader.load_content(mission_id)
		if not loaded.ok():
			service.errors.append_array(loaded.errors)
			continue
		var document: Dictionary = loaded.data
		service._definitions[mission_id] = {
			"lab_key": str(document.get("lab_key", "")),
			"title": str(document.get("title", "")),
			"summary": str(document.get("summary", "")),
			"prerequisites": PackedStringArray(document.get("prerequisites", [])),
		}
	return service


func ids() -> PackedStringArray:
	var sorted_ids: Array = _definitions.keys()
	sorted_ids.sort()
	return PackedStringArray(sorted_ids)


func has_mission(mission_id: String) -> bool:
	return _definitions.has(mission_id)


func definition(mission_id: String) -> Dictionary:
	return _definitions.get(mission_id, {})


func lab_key(mission_id: String) -> String:
	return str(definition(mission_id).get("lab_key", ""))


## "locked" until every prerequisite is completed, then "available"; "in_progress"
## once started; "completed" once passed. Unknown ids are always "locked": a
## mission id found only in a save can never unlock anything.
func state_of(mission_id: String, progress: ProgressService) -> String:
	if not _definitions.has(mission_id):
		return LOCKED
	var recorded: String = progress.recorded_state(mission_id)
	if recorded == COMPLETED:
		return COMPLETED
	for prerequisite: String in _definitions[mission_id]["prerequisites"]:
		if not _definitions.has(prerequisite) or not progress.is_completed(prerequisite):
			return LOCKED
	if recorded == IN_PROGRESS or progress.active_mission_id() == mission_id:
		return IN_PROGRESS
	return AVAILABLE
