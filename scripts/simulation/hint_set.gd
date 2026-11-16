class_name HintSet
extends RefCounted
## A lab's hint ladder: up to three hints per scoring criterion, each a little
## more direct than the last. Difficulty decides how many levels a player may
## ask for. Hints never change the answer or the score.

var levels_by_difficulty: Dictionary = {}
var _texts: Dictionary = {}  # "criterion_id/level" -> text


static func from_document(document: Dictionary) -> HintSet:
	var set: HintSet = HintSet.new()
	var levels: Variant = document.get("levels_by_difficulty", {})
	if typeof(levels) == TYPE_DICTIONARY:
		set.levels_by_difficulty = (levels as Dictionary).duplicate(true)
	for raw: Variant in document.get("hints", []):
		if typeof(raw) == TYPE_DICTIONARY:
			var row: Dictionary = raw
			set._texts["%s/%d" % [str(row.get("criterion_id", "")), int(row.get("level", 0))]] = str(row.get("text", ""))
	return set


## How many hint levels this difficulty allows (0 to 3).
func levels_for(difficulty: String) -> int:
	return clampi(int(levels_by_difficulty.get(difficulty, 0)), 0, 3)


func text_for(criterion_id: String, level: int) -> String:
	return str(_texts.get("%s/%d" % [criterion_id, level], ""))
