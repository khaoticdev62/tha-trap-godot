class_name ProgressService
extends Node
## What the player has done: mission results, story flags, the checkpoint, and
## the lab currently in progress (autoload "Progress"). It owns this state and
## nothing else; saving is SaveGame's job.
##
## Rules that protect the player's record:
##  - A completed mission stays completed. Replays can only raise the best score.
##  - Every result is stored with the marking-guide version it was earned under.
##  - Loading is all-or-nothing: damaged progress is refused, not half-applied.
##  - Unknown mission ids in a save are kept and written back unchanged, but
##    they never unlock anything (only MissionService's known definitions do).

signal progress_changed
signal mission_state_changed(mission_id: String, state: String)

const FORMAT_VERSION: int = 1
const MAX_MISSIONS: int = 100
const MAX_FLAGS: int = 200
const MAX_ATTEMPTS: int = 100000
const MAX_SCORE: int = 1000
const MAX_VERSION_CHARS: int = 16
const MAX_PLAY_SECONDS_HELD: float = 86400.0
const BASE_SEED: int = 1000
const STATES: Array[String] = ["in_progress", "completed"]

var active_slot: int = 0
var difficulty: String = ScenarioGenerator.DEFAULT_DIFFICULTY
## The live lab, if any. Not saved directly; its snapshot is (see checkpoint_lab).
var current_session: LabSession = null
## Why the last resume failed, for the UI to show.
var last_error: String = ""
## Which mode the slot screen opens in: "load" or "new". Not saved.
var slot_screen_mode: String = "load"

var _missions: Dictionary = {}
var _flags: Dictionary = {}
var _checkpoint: String = ""
var _active_lab: Dictionary = {}
var _play_seconds: float = 0.0


func _process(delta: float) -> void:
	_play_seconds = minf(_play_seconds + delta, MAX_PLAY_SECONDS_HELD)


## Forgets everything: a brand-new game.
func reset() -> void:
	_missions = {}
	_flags = {}
	_checkpoint = ""
	_active_lab = {}
	current_session = null
	difficulty = ScenarioGenerator.DEFAULT_DIFFICULTY
	_play_seconds = 0.0
	progress_changed.emit()


# --- missions ---------------------------------------------------------------

func is_completed(mission_id: String) -> bool:
	return _record(mission_id).get("state", "") == "completed"


func attempts(mission_id: String) -> int:
	return int(_record(mission_id).get("attempts", 0))


func best_score(mission_id: String) -> int:
	return int(_record(mission_id).get("best_score", 0))


func content_version(mission_id: String) -> String:
	return str(_record(mission_id).get("content_version", ""))


## "completed", "in_progress" or "" when the mission has not been started.
func recorded_state(mission_id: String) -> String:
	return str(_record(mission_id).get("state", ""))


func has_active_lab() -> bool:
	return not _active_lab.is_empty()


func active_mission_id() -> String:
	return str(_active_lab.get("mission_id", ""))


## Starts a fresh attempt. The seed changes with every attempt so a replay has
## different background noise but the same story and the same right answers.
func begin_lab(mission_id: String, content: LabContent) -> LabSession:
	if not content.is_ready() or not _is_id(mission_id):
		return null
	var attempt_seed: int = BASE_SEED + attempts(mission_id)
	current_session = content.new_session(difficulty, attempt_seed)
	_active_lab = {"mission_id": mission_id, "lab_key": content.lab_key, "snapshot": current_session.snapshot()}
	if not is_completed(mission_id):
		_set_record(mission_id, {"state": "in_progress", "attempts": attempts(mission_id), "best_score": best_score(mission_id), "content_version": content_version(mission_id)})
	progress_changed.emit()
	return current_session


## Picks up the saved attempt exactly where it stopped. Returns null (and sets
## last_error) if there is nothing to resume or the saved work is damaged.
func resume_lab(content: LabContent) -> LabSession:
	last_error = ""
	if _active_lab.is_empty():
		last_error = "There is no lab in progress."
		return null
	if not content.is_ready() or content.lab_key != str(_active_lab.get("lab_key", "")):
		last_error = "The saved lab does not match the lab content in this version."
		return null
	var snapshot: Variant = _active_lab.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		last_error = "The saved lab is missing its progress."
		return null
	var seed_text: String = str((snapshot as Dictionary).get("seed", ""))
	var difficulty_text: String = str((snapshot as Dictionary).get("difficulty", ""))
	if not seed_text.is_valid_int() or not ScenarioGenerator.DIFFICULTIES.has(difficulty_text):
		last_error = "The saved lab has invalid settings."
		return null
	var session: LabSession = content.new_session(difficulty_text, int(seed_text))
	var restored: ActionResult = session.restore(snapshot)
	if not restored.ok:
		last_error = restored.message
		return null
	current_session = session
	progress_changed.emit()
	return session


## Copies the live lab into the part of the record that gets saved.
func checkpoint_lab() -> void:
	if current_session == null or _active_lab.is_empty():
		return
	_active_lab["snapshot"] = current_session.snapshot()
	progress_changed.emit()


## Records a reviewed attempt. Returns the mission's new state.
func finish_lab(assessment: AssessmentResult) -> String:
	var mission_id: String = active_mission_id()
	if mission_id.is_empty() or assessment == null:
		return ""
	var record: Dictionary = _record(mission_id)
	var previous_best: int = int(record.get("best_score", 0))
	var better: bool = assessment.total > previous_best or not record.has("content_version") or str(record.get("content_version", "")).is_empty()
	var state: String = "completed" if (assessment.passed or str(record.get("state", "")) == "completed") else "in_progress"
	_set_record(mission_id, {
		"state": state,
		"attempts": mini(int(record.get("attempts", 0)) + 1, MAX_ATTEMPTS),
		"best_score": clampi(maxi(previous_best, assessment.total), 0, MAX_SCORE),
		"content_version": assessment.rubric_version.left(MAX_VERSION_CHARS) if better else str(record.get("content_version", "")),
	})
	_active_lab = {}
	current_session = null
	mission_state_changed.emit(mission_id, state)
	progress_changed.emit()
	return state


## Gives up the current attempt without recording a result.
func abandon_lab() -> void:
	var mission_id: String = active_mission_id()
	_active_lab = {}
	current_session = null
	if not mission_id.is_empty() and attempts(mission_id) == 0 and not is_completed(mission_id):
		_missions.erase(mission_id)
		mission_state_changed.emit(mission_id, "")
	progress_changed.emit()


# --- flags and checkpoint ---------------------------------------------------

func set_flag(flag: String) -> bool:
	if not _is_id(flag) or (_flags.size() >= MAX_FLAGS and not _flags.has(flag)):
		return false
	if not _flags.has(flag):
		_flags[flag] = true
		progress_changed.emit()
	return true


func has_flag(flag: String) -> bool:
	return _flags.has(flag)


func set_checkpoint(checkpoint: String) -> bool:
	if not checkpoint.is_empty() and not _is_id(checkpoint):
		return false
	_checkpoint = checkpoint
	progress_changed.emit()
	return true


func checkpoint() -> String:
	return _checkpoint


func set_difficulty(level: String) -> bool:
	if not ScenarioGenerator.DIFFICULTIES.has(level):
		return false
	difficulty = level
	progress_changed.emit()
	return true


# --- play time --------------------------------------------------------------

## Seconds played since the last save; the save adds them to the profile.
func take_play_seconds() -> float:
	var taken: float = _play_seconds
	_play_seconds = 0.0
	return taken


func add_play_seconds(seconds: float) -> void:
	_play_seconds = clampf(_play_seconds + maxf(seconds, 0.0), 0.0, MAX_PLAY_SECONDS_HELD)


# --- saving and loading -----------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"difficulty": difficulty,
		"missions": _missions.duplicate(true),
		"flags": _flags.duplicate(true),
		"checkpoint": _checkpoint,
		"active_lab": _active_lab.duplicate(true),
	}


## Replaces everything from saved data, or changes nothing and says why. An
## empty dictionary means "new game" (this is what a v1 save upgrades to).
func load_from_dict(data: Variant) -> ActionResult:
	if typeof(data) != TYPE_DICTIONARY:
		return ActionResult.failure("The saved progress is not readable.")
	var source: Dictionary = data
	if source.is_empty():
		reset()
		return ActionResult.success()
	var version: Variant = source.get("version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or int(version) < 1:
		return ActionResult.failure("The saved progress has no valid version.")
	if int(version) > FORMAT_VERSION:
		return ActionResult.failure("The saved progress was made by a newer version of the game.")

	var level: Variant = source.get("difficulty", ScenarioGenerator.DEFAULT_DIFFICULTY)
	if typeof(level) != TYPE_STRING or not ScenarioGenerator.DIFFICULTIES.has(level):
		return ActionResult.failure("The saved difficulty is not valid.")

	var staged_missions: Dictionary = {}
	var raw_missions: Variant = source.get("missions", {})
	if typeof(raw_missions) != TYPE_DICTIONARY or (raw_missions as Dictionary).size() > MAX_MISSIONS:
		return ActionResult.failure("The saved mission list is not valid.")
	for mission_id: Variant in raw_missions:
		var row: Variant = (raw_missions as Dictionary)[mission_id]
		var checked: Dictionary = _checked_record(mission_id, row)
		if checked.is_empty():
			return ActionResult.failure("The saved record for a mission is not valid.")
		staged_missions[str(mission_id)] = checked

	var staged_flags: Dictionary = {}
	var raw_flags: Variant = source.get("flags", {})
	if typeof(raw_flags) != TYPE_DICTIONARY or (raw_flags as Dictionary).size() > MAX_FLAGS:
		return ActionResult.failure("The saved story flags are not valid.")
	for flag: Variant in raw_flags:
		if typeof(flag) != TYPE_STRING or not _is_id(flag) or not Validate.strict_bool((raw_flags as Dictionary)[flag]):
			return ActionResult.failure("The saved story flags are not valid.")
		staged_flags[flag] = true

	var saved_checkpoint: Variant = source.get("checkpoint", "")
	if typeof(saved_checkpoint) != TYPE_STRING or (saved_checkpoint != "" and not _is_id(saved_checkpoint)):
		return ActionResult.failure("The saved checkpoint is not valid.")

	var staged_lab: Dictionary = {}
	var raw_lab: Variant = source.get("active_lab", {})
	if typeof(raw_lab) != TYPE_DICTIONARY:
		return ActionResult.failure("The saved lab in progress is not valid.")
	if not (raw_lab as Dictionary).is_empty():
		var lab: Dictionary = raw_lab
		if typeof(lab.get("mission_id")) != TYPE_STRING or not _is_id(lab["mission_id"]) or typeof(lab.get("lab_key")) != TYPE_STRING or not _is_id(lab["lab_key"]) or typeof(lab.get("snapshot")) != TYPE_DICTIONARY:
			return ActionResult.failure("The saved lab in progress is not valid.")
		staged_lab = {"mission_id": lab["mission_id"], "lab_key": lab["lab_key"], "snapshot": (lab["snapshot"] as Dictionary).duplicate(true)}

	difficulty = level
	_missions = staged_missions
	_flags = staged_flags
	_checkpoint = saved_checkpoint
	_active_lab = staged_lab
	current_session = null
	progress_changed.emit()
	return ActionResult.success()


## Counts for a slot card, from raw saved data. Never fails.
static func summarise(data: Variant) -> Dictionary:
	var summary: Dictionary = {"completed": 0, "attempts": 0, "in_progress": false}
	if typeof(data) != TYPE_DICTIONARY:
		return summary
	var missions: Variant = (data as Dictionary).get("missions", {})
	if typeof(missions) == TYPE_DICTIONARY:
		for row: Variant in (missions as Dictionary).values():
			if typeof(row) == TYPE_DICTIONARY:
				if (row as Dictionary).get("state", "") == "completed":
					summary["completed"] += 1
				summary["attempts"] += clampi(int((row as Dictionary).get("attempts", 0)), 0, MAX_ATTEMPTS)
	var lab: Variant = (data as Dictionary).get("active_lab", {})
	summary["in_progress"] = typeof(lab) == TYPE_DICTIONARY and not (lab as Dictionary).is_empty()
	return summary


# --- internals --------------------------------------------------------------

func _record(mission_id: String) -> Dictionary:
	var row: Variant = _missions.get(mission_id, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


func _set_record(mission_id: String, row: Dictionary) -> void:
	if _missions.size() >= MAX_MISSIONS and not _missions.has(mission_id):
		return
	_missions[mission_id] = row


## A clean copy of one saved mission record, or {} if it is not valid.
static func _checked_record(mission_id: Variant, row: Variant) -> Dictionary:
	if typeof(mission_id) != TYPE_STRING or not _is_id(mission_id) or typeof(row) != TYPE_DICTIONARY:
		return {}
	var record: Dictionary = row
	var state: Variant = record.get("state")
	var score: Variant = record.get("best_score", 0)
	var count: Variant = record.get("attempts", 0)
	var version: Variant = record.get("content_version", "")
	if typeof(state) != TYPE_STRING or not STATES.has(state):
		return {}
	if typeof(score) not in [TYPE_INT, TYPE_FLOAT] or int(score) < 0 or int(score) > MAX_SCORE or float(score) != floorf(float(score)):
		return {}
	if typeof(count) not in [TYPE_INT, TYPE_FLOAT] or int(count) < 0 or int(count) > MAX_ATTEMPTS or float(count) != floorf(float(count)):
		return {}
	if typeof(version) != TYPE_STRING or version.length() > MAX_VERSION_CHARS or SimText.has_forbidden(version):
		return {}
	return {"state": state, "best_score": int(score), "attempts": int(count), "content_version": version}


static func _is_id(text: String) -> bool:
	return SchemaValidator.validate(text, {"type": "id"}).ok()
