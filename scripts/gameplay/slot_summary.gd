class_name SlotSummary
extends RefCounted
## What a save slot card shows, read leniently from a slot without changing any
## game state.

var slot: int = 0
var exists: bool = false
## False when a file is there but cannot be used (corrupt, or from a newer game).
var usable: bool = false
var player_name: String = ""
var playtime_seconds: float = 0.0
var missions_completed: int = 0
var lab_in_progress: bool = false
var saved_unix: int = 0
var recovered_from_backup: bool = false
## Why an unusable slot cannot be loaded.
var problem: String = ""


## One line for the slot button, for example
## "Slot 1: Kai Lee - 1h 05m - 1 mission completed".
func describe() -> String:
	var label: String = "Slot %d" % (slot + 1)
	if not exists:
		return "%s: Empty" % label
	if not usable:
		return "%s: Cannot be loaded (%s)" % [label, problem]
	var parts: PackedStringArray = PackedStringArray([player_name, format_playtime(playtime_seconds)])
	parts.append("%d %s completed" % [missions_completed, "mission" if missions_completed == 1 else "missions"])
	if lab_in_progress:
		parts.append("lab in progress")
	if recovered_from_backup:
		parts.append("restored from backup")
	return "%s: %s" % [label, " - ".join(parts)]


static func format_playtime(seconds: float) -> String:
	var total_minutes: int = int(maxf(seconds, 0.0)) / 60
	if total_minutes < 1:
		return "under 1m"
	return "%dh %02dm" % [total_minutes / 60, total_minutes % 60]
