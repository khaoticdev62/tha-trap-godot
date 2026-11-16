extends TestCase
## SaveGame (whole-save assembly), save schema v2 with its first real migration,
## slot summaries, and damaged or interrupted saves.

var _dir: String = ""
var _saves: SaveService
var _profiles: ProfileService
var _progress: ProgressService
var _game: SaveGame
var _content: LabContent


func before_each() -> void:
	_dir = "user://itest_savegame_%d" % Time.get_ticks_usec()
	_saves = SaveService.new()
	_saves.save_dir = _dir
	_profiles = ProfileService.new()
	_progress = ProgressService.new()
	_game = SaveGame.new(_saves, _profiles, _progress)
	_game.fixed_unix_time = 1000
	_content = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")


func after_each() -> void:
	for slot: int in AppConfig.SAVE_SLOT_COUNT:
		_saves.delete_slot(slot)
	var dir: DirAccess = DirAccess.open(_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)
	_saves.free()
	_profiles.free()
	_progress.free()


func _new_game(slot: int, display_name: String = "Kai") -> SaveResult:
	return _game.start_new(slot, display_name, "they/them", "tone_tan", "hair_locs", "outfit_copper")


func _write_raw(slot: int, version: int, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var payload_json: String = JSON.stringify(payload, "", true, true)
	var envelope: Dictionary = {"schema_version": version, "checksum": _saves._checksum(payload_json), "payload_json": payload_json}
	var file: FileAccess = FileAccess.open(_dir.path_join("slot_%d.json" % slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope, "", true, true))
	file = null


func _fresh_game() -> Array:
	var profiles: ProfileService = ProfileService.new()
	var progress: ProgressService = ProgressService.new()
	return [SaveGame.new(_saves, profiles, progress), profiles, progress]


# --- the save itself --------------------------------------------------------

func test_a_save_holds_profile_progress_and_metadata() -> void:
	check(_new_game(1, "Kai Lee").ok, "a new game saves")
	var stored: SaveResult = _saves.read_slot(1)
	check(stored.ok, "and can be read: %s" % stored.message)
	check_eq(stored.payload["profile"]["display_name"], "Kai Lee", "the profile is saved")
	check(stored.payload.has("progress") and stored.payload["progress"]["version"] == 1, "progress is saved")
	check_eq(int(stored.payload["meta"]["saved_unix"]), 1000, "when it was saved")
	check_eq(_progress.active_slot, 1, "the new game's slot is the active slot")


func test_loading_restores_everything_into_fresh_services() -> void:
	_new_game(0)
	_progress.begin_lab("mission_lab_001", _content)
	_progress.finish_lab(_result(90, true))
	_progress.set_flag("met_nia")
	_progress.add_play_seconds(125.0)
	check(_game.save().ok, "saved")
	var other: Array = _fresh_game()
	var loaded: SaveResult = (other[0] as SaveGame).load_slot(0)
	check(loaded.ok, "loaded: %s" % loaded.message)
	check_eq((other[1] as ProfileService).current.display_name, "Kai", "the profile is back")
	check((other[2] as ProgressService).is_completed("mission_lab_001") and (other[2] as ProgressService).has_flag("met_nia"), "so is the progress")
	check_eq((other[1] as ProfileService).current.playtime_seconds, 125.0, "the time played was added to the profile")
	check_eq((other[2] as ProgressService).active_slot, 0, "the active slot follows the load")
	other[1].free()
	other[2].free()


func _result(total: int, passed: bool) -> AssessmentResult:
	var result: AssessmentResult = AssessmentResult.new()
	result.total = total
	result.passed = passed
	result.rubric_version = "1.0.0"
	return result


func test_saving_checkpoints_the_lab_in_progress() -> void:
	_new_game(0)
	var session: LabSession = _progress.begin_lab("mission_lab_001", _content)
	session.add_evidence(PackedStringArray(["EVT-003"]), "new source")
	check(_game.save().ok, "saved mid-lab, with no separate checkpoint call")
	var other: Array = _fresh_game()
	(other[0] as SaveGame).load_slot(0)
	var resumed: LabSession = (other[2] as ProgressService).resume_lab(_content)
	check(resumed != null and resumed.ledger.size() == 1, "the evidence collected so far is back: %s" % (other[2] as ProgressService).last_error)
	other[1].free()
	other[2].free()


func test_play_time_is_kept_when_a_save_fails() -> void:
	_new_game(0)
	_progress.add_play_seconds(60.0)
	var failed: SaveResult = _game.save(99)
	check(not failed.ok, "saving to a slot that does not exist fails")
	check_eq(_profiles.current.playtime_seconds, 0.0, "the profile did not gain time that was never saved")
	check_eq(_progress.take_play_seconds(), 60.0, "and the time is still waiting for the next save")


func test_slots_are_independent() -> void:
	_new_game(0, "First")
	_new_game(2, "Third")
	check_eq(_saves.read_slot(0).payload["profile"]["display_name"], "First", "slot 1 untouched")
	check_eq(_saves.read_slot(2).payload["profile"]["display_name"], "Third", "slot 3 written")
	check(not _saves.has_save(1), "slot 2 empty")
	check(not _new_game(5).ok, "an invalid slot is refused")
	_progress.active_slot = 2
	_profiles.current.display_name = "Third again"
	check(_game.save().ok and _saves.read_slot(2).payload["profile"]["display_name"] == "Third again", "saving without a slot uses the active slot")


func test_starting_over_replaces_the_old_game_completely() -> void:
	_new_game(0, "Old")
	_progress.begin_lab("mission_lab_001", _content)
	_progress.finish_lab(_result(90, true))
	_game.save()
	_new_game(0, "New")
	var stored: SaveResult = _saves.read_slot(0)
	check_eq(stored.payload["profile"]["display_name"], "New", "the new character")
	check_eq(ProgressService.summarise(stored.payload["progress"])["completed"], 0, "with none of the old progress")
	check(not _progress.is_completed("mission_lab_001"), "and none in memory either")


# --- damaged progress --------------------------------------------------------

func test_damaged_progress_is_refused_without_changing_the_game() -> void:
	_new_game(0, "Keeper")
	_progress.set_flag("keep_me")
	var bad: Dictionary = {"profile": {"display_name": "Intruder"}, "progress": {"version": 1, "difficulty": "nightmare"}, "meta": {}}
	_write_raw(1, AppConfig.SAVE_SCHEMA_VERSION, bad)
	var failures: Array[int] = [0]
	_saves.load_failed.connect(func(_slot: int, _reason: String) -> void: failures[0] += 1)
	var result: SaveResult = _game.load_slot(1)
	check(not result.ok and result.code == SaveResult.Code.CORRUPT, "refused as corrupt: %s" % result.message)
	check_eq(_profiles.current.display_name, "Keeper", "the running game is untouched")
	check(_progress.has_flag("keep_me"), "including progress")
	check_eq(failures[0], 1, "listeners hear about the failure")


func test_load_signals() -> void:
	_new_game(0)
	var loaded: Array[int] = []
	_saves.loaded.connect(func(slot: int, _recovered: bool) -> void: loaded.append(slot))
	_game.load_slot(0)
	check_eq(loaded, [0], "a successful load announces the slot")
	check(not _game.load_slot(2).ok, "an empty slot fails cleanly")


# --- summaries --------------------------------------------------------------

func test_summaries_describe_every_slot() -> void:
	_new_game(0, "Kai Lee")
	_progress.begin_lab("mission_lab_001", _content)
	_progress.finish_lab(_result(90, true))
	_progress.add_play_seconds(3900.0)
	_game.save(0)
	_write_raw(2, AppConfig.SAVE_SCHEMA_VERSION, {"profile": {}, "progress": {"version": 1, "flags": {"X": true}}, "meta": {}})
	var summaries: Array[SlotSummary] = _game.summaries()
	check_eq(summaries.size(), AppConfig.SAVE_SLOT_COUNT, "one summary per slot")
	check_eq(summaries[0].describe(), "Slot 1: Kai Lee - 1h 05m - 1 mission completed", "a healthy slot")
	check_eq(summaries[1].describe(), "Slot 2: Empty", "an empty slot")
	check(summaries[2].exists and not summaries[2].usable, "a slot with damaged progress exists but is not usable")
	check(summaries[2].describe().begins_with("Slot 3: Cannot be loaded ("), "and says so: %s" % summaries[2].describe())


func test_summary_for_an_unreadable_file() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var file: FileAccess = FileAccess.open(_dir.path_join("slot_1.json"), FileAccess.WRITE)
	file.store_string("this is not a save")
	file = null
	var summary: SlotSummary = _game.summaries()[1]
	check(summary.exists and not summary.usable, "garbage is reported as a damaged slot, not an empty one")
	check(not summary.problem.is_empty(), "with a reason")


func test_summary_for_a_save_from_a_newer_game() -> void:
	_write_raw(0, AppConfig.SAVE_SCHEMA_VERSION + 1, {"profile": {}})
	var summary: SlotSummary = _game.summaries()[0]
	check(summary.exists and not summary.usable and summary.problem.contains("newer"), "newer saves are shown as unusable: %s" % summary.problem)
	check(not _game.load_slot(0).ok, "and are not loaded")


func test_playtime_text() -> void:
	check_eq(SlotSummary.format_playtime(0.0), "under 1m", "zero")
	check_eq(SlotSummary.format_playtime(59.0), "under 1m", "under a minute")
	check_eq(SlotSummary.format_playtime(60.0), "0h 01m", "a minute")
	check_eq(SlotSummary.format_playtime(3900.0), "1h 05m", "an hour and five")
	check_eq(SlotSummary.format_playtime(-5.0), "under 1m", "negative is safe")
	check_eq(SlotSummary.format_playtime(1.0e12), "277777777h 46m", "huge values do not break")


func test_most_recent_slot() -> void:
	check_eq(_game.most_recent_slot(), -1, "no saves, no recent slot")
	_game.fixed_unix_time = 100
	_new_game(2, "Older")
	_game.fixed_unix_time = 500
	_new_game(1, "Newer")
	check_eq(_game.most_recent_slot(), 1, "the latest save wins")
	_write_raw(0, AppConfig.SAVE_SCHEMA_VERSION, {"profile": {}, "progress": {"version": 99}, "meta": {"saved_unix": 9999}})
	check_eq(_game.most_recent_slot(), 1, "an unusable slot is never chosen, however new")
	_game.fixed_unix_time = 500
	_new_game(0, "Tie")
	check_eq(_game.most_recent_slot(), 0, "ties go to the lower slot")


func test_deleting_a_slot() -> void:
	_new_game(1)
	check(_game.delete_slot(1), "deleted")
	check(not _saves.has_save(1), "gone")
	check(not _game.delete_slot(7), "an invalid slot is refused")


# --- schema v2 and migration -------------------------------------------------

func test_a_v1_save_upgrades_to_a_new_game_with_the_profile_intact() -> void:
	check_eq(AppConfig.SAVE_SCHEMA_VERSION, 2, "this build writes schema v2")
	_write_raw(0, 1, {"profile": {"display_name": "Veteran", "pronouns": "she/her", "skin_tone": "tone_tan", "hair_style": "hair_locs", "outfit_palette": "outfit_copper", "playtime_seconds": 7200.0}})
	var read: SaveResult = _saves.read_slot(0)
	check(read.ok, "a v1 file still reads: %s" % read.message)
	check(read.payload.has("progress") and (read.payload["progress"] as Dictionary).is_empty(), "the migration adds an empty progress record")
	check(read.payload.has("meta"), "and a metadata section")
	check_eq(read.payload["profile"]["display_name"], "Veteran", "the profile is untouched")
	var loaded: SaveResult = _game.load_slot(0)
	check(loaded.ok, "and it loads into the game: %s" % loaded.message)
	check_eq(_profiles.current.display_name, "Veteran", "the character carries over")
	check_eq(_profiles.current.playtime_seconds, 7200.0, "and the time played")
	check(not _progress.is_completed("mission_lab_001"), "with a clean mission record")
	check(_game.summaries()[0].usable, "and the slot card shows it as usable")


func test_saving_over_a_v1_file_writes_v2_and_keeps_a_backup() -> void:
	_write_raw(0, 1, {"profile": {"display_name": "Veteran"}})
	_game.load_slot(0)
	check(_game.save(0).ok, "saved")
	var backup_path: String = _dir.path_join("slot_0.bak1")
	check(FileAccess.file_exists(backup_path), "the old v1 file was kept as a backup first")
	var envelope: Variant = JSON.parse_string(FileAccess.open(_dir.path_join("slot_0.json"), FileAccess.READ).get_as_text())
	check_eq(int(envelope["schema_version"]), 2, "the new file is schema v2")


func test_migration_does_not_overwrite_existing_sections() -> void:
	var upgraded: Dictionary = SaveMigrations.migrate({"profile": {}, "progress": {"version": 1}, "meta": {"saved_unix": 5}}, 1, 2)["payload"]
	check_eq(upgraded["progress"], {"version": 1}, "an existing progress section is kept")
	check_eq(upgraded["meta"], {"saved_unix": 5}, "and so is existing metadata")


# --- interrupted writes ------------------------------------------------------

func test_a_leftover_temporary_file_does_not_hurt_the_save() -> void:
	_new_game(0, "Safe")
	var stray: FileAccess = FileAccess.open(_dir.path_join("slot_0.tmp"), FileAccess.WRITE)
	stray.store_string("{ half written")
	stray = null
	var loaded: SaveResult = _game.load_slot(0)
	check(loaded.ok and _profiles.current.display_name == "Safe", "an interrupted write leaves the last good save loadable")
	check(_game.save(0).ok, "the next save works over the leftover")
	check(not FileAccess.file_exists(_dir.path_join("slot_0.tmp")), "and cleans it up")


func test_a_corrupt_main_file_falls_back_to_the_backup() -> void:
	_new_game(0, "First")
	_game.save(0)
	var file: FileAccess = FileAccess.open(_dir.path_join("slot_0.json"), FileAccess.WRITE)
	file.store_string("garbage")
	file = null
	var loaded: SaveResult = _game.load_slot(0)
	check(loaded.ok and loaded.recovered_from_backup, "the backup is used")
	check(_game.summaries()[0].describe().contains("restored from backup"), "and the slot card says so")
