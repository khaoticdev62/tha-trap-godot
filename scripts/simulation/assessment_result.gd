class_name AssessmentResult
extends RefCounted
## The outcome of reviewing a case against a rubric. Plain data.

var rubric_id: String = ""
var rubric_version: String = ""
var total: int = 0
var max_points: int = 0
var pass_points: int = 0
## True only with enough points and no critical error.
var passed: bool = false
## A critical error asks for coaching and another attempt; it is never a dead end.
var needs_retry: bool = false
## One per criterion: {id, title, points, max_points, status, feedback}.
## status is "met", "partial" or "unmet".
var criteria: Array[Dictionary] = []
## One per critical error: {id, coaching}.
var critical_errors: Array[Dictionary] = []
var rationale: PackedStringArray = PackedStringArray()
var hints_used: int = 0


## Readable lines for the terminal and the debrief.
func summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Review: %d / %d points (pass mark %d)" % [total, max_points, pass_points])
	for row: Dictionary in criteria:
		var marker: String = "MET    " if row["status"] == "met" else ("PARTIAL" if row["status"] == "partial" else "UNMET  ")
		lines.append("[%s] %s  %d/%d" % [marker, row["title"], row["points"], row["max_points"]])
		lines.append("          %s" % row["feedback"])
	for error: Dictionary in critical_errors:
		lines.append("CRITICAL ERROR: %s" % error["coaching"])
	if needs_retry:
		lines.append("Fix this and review again; nothing is lost.")
	elif passed:
		lines.append("Passed.")
	else:
		lines.append("Not at the pass mark yet. Use the feedback above and review again.")
	return lines
