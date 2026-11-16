class_name SaveGame
extends RefCounted
## Turns the player's current state into a save and back. This is the one place
## that knows what a whole save contains (profile, progress and metadata), so the
## services stay independent of each other. Saves go through SaveService, which
## writes atomically, verifies, keeps backups and refuses newer versions.

var saves: SaveService
var profiles: ProfileService
var progress: ProgressService
## Tests set this to a fixed number instead of reading the clock; -1 uses the clock.
var fixed_unix_time: int = -1


func _init(save_service: SaveService, profile_service: ProfileService, progress_service: ProgressService) -> void:
	saves = save_service
	profiles = profile_service
	progress = progress_service


## Builds the helper from the running game's autoloads.
static func from_tree(tree: SceneTree) -> SaveGame:
	var root: Node = tree.root
	return SaveGame.new(root.get_node("Saves"), root.get_node("Profiles"), root.get_node("Progress"))


## Saves the current game into `slot` (the active slot when omitted).
func save(slot: int = -1) -> SaveResult:
	var target: int = progress.active_slot if slot < 0 else slot
	progress.checkpoint_lab()
	var played: float = progress.take_play_seconds()
	profiles.current.playtime_seconds += played
	var payload: Dictionary = {
		"profile": profiles.current.to_dict(),
		"progress": progress.to_dict(),
		"meta": {"saved_unix": _now()},
	}
	var result: SaveResult = saves.save_slot(target, payload)
	if not result.ok:
		# Nothing was written, so the time played is still unsaved.
		profiles.current.playtime_seconds -= played
		progress.add_play_seconds(played)
	return result


## Loads `slot` into the running game. Damaged progress is refused (nothing is
## changed) rather than half-applied.
func load_slot(slot: int) -> SaveResult:
	var result: SaveResult = saves.read_slot(slot)
	if not result.ok:
		saves.load_failed.emit(slot, result.message)
		return result
	var applied: ActionResult = progress.load_from_dict(result.payload.get("progress", {}))
	if not applied.ok:
		var refused: SaveResult = SaveResult.failure(SaveResult.Code.CORRUPT, applied.message)
		saves.load_failed.emit(slot, refused.message)
		return refused
	profiles.load_from_payload(result.payload)
	progress.active_slot = slot
	saves.loaded.emit(slot, result.recovered_from_backup)
	return result


## Starts a brand-new game in `slot` and saves it. An existing save in that slot
## is only replaced once the new one has been written and verified.
func start_new(slot: int, display_name: String, pronouns: String, skin_tone: String, hair_style: String, outfit_palette: String) -> SaveResult:
	if not saves.is_valid_slot(slot):
		return SaveResult.failure(SaveResult.Code.INVALID_SLOT, "Save slot %d does not exist." % slot)
	progress.reset()
	progress.active_slot = slot
	profiles.create(display_name, pronouns, skin_tone, hair_style, outfit_palette)
	return save(slot)


func delete_slot(slot: int) -> bool:
	return saves.delete_slot(slot)


## One summary per slot, in slot order. Reads files but changes no game state.
func summaries() -> Array[SlotSummary]:
	var found: Array[SlotSummary] = []
	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		found.append(_summarise(slot))
	return found


## The slot saved most recently, or -1 when there is no usable save.
func most_recent_slot() -> int:
	var best: int = -1
	var best_time: int = -1
	for summary: SlotSummary in summaries():
		if summary.usable and summary.saved_unix > best_time:
			best = summary.slot
			best_time = summary.saved_unix
	return best


func _summarise(slot: int) -> SlotSummary:
	var summary: SlotSummary = SlotSummary.new()
	summary.slot = slot
	var peek: SaveResult = saves.read_slot(slot)
	if not peek.ok:
		summary.exists = peek.code != SaveResult.Code.NOT_FOUND
		summary.problem = peek.message
		return summary
	summary.exists = true
	summary.recovered_from_backup = peek.recovered_from_backup
	var profile: PlayerProfile = PlayerProfile.from_dict(peek.payload.get("profile", {}))
	var counts: Dictionary = ProgressService.summarise(peek.payload.get("progress", {}))
	var meta: Variant = peek.payload.get("meta", {})
	summary.player_name = profile.display_name
	summary.playtime_seconds = profile.playtime_seconds
	summary.missions_completed = int(counts["completed"])
	summary.lab_in_progress = counts["in_progress"] == true
	if typeof(meta) == TYPE_DICTIONARY:
		summary.saved_unix = clampi(int((meta as Dictionary).get("saved_unix", 0)), 0, 4102444800)
	# A slot whose progress is damaged is shown as unusable instead of failing later.
	var check: ProgressService = ProgressService.new()
	var progress_data: Variant = peek.payload.get("progress", {})
	var valid: ActionResult = check.load_from_dict(progress_data)
	check.free()
	summary.usable = valid.ok
	if not valid.ok:
		summary.problem = valid.message
	return summary


func _now() -> int:
	return fixed_unix_time if fixed_unix_time >= 0 else int(Time.get_unix_time_from_system())
