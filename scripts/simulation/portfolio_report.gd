class_name PortfolioReport
extends RefCounted
## Renders the player's finished case as a Markdown incident triage report: the
## portfolio artifact for LAB-001. Pure text in, text out; writing it to disk is
## the job of PortfolioExporter. The report is honest about what it is: a
## self-recorded practice record from a fictional simulation, not a
## certification and not proof of job readiness.

const DISCLAIMER: String = "This is a self-recorded practice record from a fictional training simulation. All people, organisations, systems and data in it are synthetic. It is not a certification, a qualification or evidence of job readiness, and it has not been independently verified."


## `analyst_name` and `date_text` come from the caller (the game owns the clock).
static func render(session: LabSession, assessment: AssessmentResult, analyst_name: String, date_text: String) -> String:
	var case_file: CaseFile = session.case_file
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Incident Triage Report")
	lines.append("")
	lines.append("**SIMULATED TRAINING DATA.** " + DISCLAIMER)
	lines.append("")
	lines.append("- **Analyst:** %s" % _text(analyst_name))
	lines.append("- **Date:** %s" % _text(date_text))
	lines.append("- **Lab:** %s (difficulty: %s)" % [_text(session.package.id), _text(session.difficulty)])
	if assessment != null:
		lines.append("- **Marking guide version:** %s" % _text(assessment.rubric_version))
	lines.append("- **Case:** %s" % CaseFile.CASE_ID)
	lines.append("")

	lines.append("## Summary")
	lines.append("")
	lines.append(_text(case_file.report_summary) if not case_file.report_summary.is_empty() else "_No summary written._")
	lines.append("")
	lines.append("- **Severity:** %s" % ("not set" if case_file.severity == "unset" else _text(case_file.severity)))
	lines.append("- **Affected assets:** %s" % _asset_names(session))
	lines.append("")

	lines.append("## Timeline")
	lines.append("")
	var timeline: Array[Dictionary] = session.build_timeline()
	if timeline.is_empty():
		lines.append("_No evidence collected._")
	else:
		lines.append("| Time | Event | Account | Result | What happened | Evidence |")
		lines.append("|---|---|---|---|---|---|")
		for item: Dictionary in timeline:
			lines.append("| %s | %s | %s | %s | %s | %s |" % [item["time"], _text(item["display_id"]), _text(item["actor"]), _text(item["result"]), _text(item["detail"]), _text(", ".join(item["evidence_ids"]))])
	lines.append("")

	lines.append("## Findings")
	lines.append("")
	_append_entries(lines, case_file, "fact", "Facts (each backed by evidence)")
	_append_entries(lines, case_file, "hypothesis", "Hypotheses (ideas not yet proven)")
	_append_entries(lines, case_file, "unknown", "Open questions")

	lines.append("## Recommendation")
	lines.append("")
	lines.append("- **Response:** %s" % _option_label(session.package.response_options, case_file.recommendation))
	lines.append("- **Escalated to:** %s" % _option_label(session.package.escalation_options, case_file.escalation))
	lines.append("")

	if assessment != null:
		lines.append("## Review result")
		lines.append("")
		lines.append("**%d / %d points** (pass mark %d)%s" % [assessment.total, assessment.max_points, assessment.pass_points, " - passed" if assessment.passed else ""])
		lines.append("")
		for row: Dictionary in assessment.criteria:
			lines.append("- **%s** - %d/%d. %s" % [_text(row["title"]), row["points"], row["max_points"], _text(row["feedback"])])
		for error: Dictionary in assessment.critical_errors:
			lines.append("- **Needs another look:** %s" % _text(error["coaching"]))
		lines.append("- Hints used: %d" % assessment.hints_used)
		lines.append("")
		if not assessment.rationale.is_empty():
			lines.append("## What the evidence shows")
			lines.append("")
			for reason: String in assessment.rationale:
				lines.append("- %s" % _text(reason))
			lines.append("")

	lines.append("## About this record")
	lines.append("")
	lines.append(DISCLAIMER)
	lines.append("")
	return "\n".join(lines)


static func _append_entries(lines: PackedStringArray, case_file: CaseFile, kind: String, heading: String) -> void:
	lines.append("### " + heading)
	lines.append("")
	var found: bool = false
	for entry: CaseEntry in case_file.entries():
		if entry.kind != kind:
			continue
		found = true
		var cited: String = ""
		if not entry.evidence_ids.is_empty():
			cited = " _(evidence: %s)_" % _text(", ".join(entry.evidence_ids))
		lines.append("- %s%s" % [_text(entry.text), cited])
	if not found:
		lines.append("_None recorded._")
	lines.append("")


static func _asset_names(session: LabSession) -> String:
	if session.case_file.scope.is_empty():
		return "not set"
	var names: PackedStringArray = PackedStringArray()
	for asset_id: String in session.case_file.scope:
		var shown: String = asset_id
		for asset: Dictionary in session.package.assets:
			if str(asset.get("id", "")) == asset_id:
				shown = str(asset.get("name", asset_id))
		names.append(_text(shown))
	return ", ".join(names)


static func _option_label(options: Array[Dictionary], option_id: String) -> String:
	if option_id.is_empty():
		return "not chosen"
	for option: Dictionary in options:
		if str(option.get("id", "")) == option_id:
			return _text(str(option.get("label", option_id)))
	return _text(option_id)


## Makes player-written text safe to place in Markdown: no table breaks, no
## raw HTML, no accidental headings or code spans, one line.
static func _text(value: Variant) -> String:
	var text: String = str(value).replace("\n", " ").replace("\r", " ")
	text = text.replace("\\", "\\\\").replace("|", "\\|").replace("`", "'").replace("<", "&lt;").replace(">", "&gt;")
	for marker: String in ["*", "_", "[", "]", "#"]:
		text = text.replace(marker, "\\" + marker)
	return text
