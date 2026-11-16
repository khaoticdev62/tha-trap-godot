class_name AssessmentEngine
extends RefCounted
## Reviews a case against a rubric. A pure function of (rubric, lab state): it
## changes nothing, uses no clock and no randomness, and gives the same answer
## for the same state. Criteria are a closed set of named checks; the rubric
## picks checks and supplies numbers but cannot define new behaviour.
##
## Scoring rests on what the player collected and wrote (evidence ids, tagged
## facts and hypotheses, scope, recommendation), never on query text, never on
## difficulty, and never on hints used.


static func evaluate(rubric: Rubric, session: LabSession) -> AssessmentResult:
	var result: AssessmentResult = AssessmentResult.new()
	result.rubric_id = rubric.id
	result.rubric_version = rubric.content_version
	result.max_points = rubric.max_points
	result.pass_points = rubric.pass_points
	result.rationale = rubric.rationale
	for used: Variant in session.hints_used.values():
		result.hints_used += int(used)

	var unsupported: bool = _has_unsupported_claim(rubric, session)
	for criterion: Dictionary in rubric.criteria:
		var outcome: Dictionary = _score(criterion, rubric, session, unsupported)
		var ceiling: int = int(criterion.get("max_points", 0))
		var points: int = clampi(int(outcome["points"]), 0, ceiling)
		var status: String = "met" if points >= ceiling else ("unmet" if points <= 0 else "partial")
		var feedback_key: String = status + "_feedback"
		var feedback: String = str(criterion.get(feedback_key, ""))
		var missing: PackedStringArray = outcome["missing"]
		feedback = feedback.replace("{missing}", ", ".join(missing) if not missing.is_empty() else "nothing")
		if outcome.has("extra_feedback") and not str(outcome["extra_feedback"]).is_empty():
			feedback = str(outcome["extra_feedback"])
		result.criteria.append({"id": criterion["id"], "title": criterion["title"], "points": points, "max_points": ceiling, "status": status, "feedback": feedback})
		result.total += points

	for definition: Dictionary in rubric.critical_errors:
		if _critical_error_applies(definition, rubric, session):
			result.critical_errors.append({"id": definition["id"], "coaching": definition["coaching"]})
	result.needs_retry = not result.critical_errors.is_empty()
	result.passed = result.total >= rubric.pass_points and not result.needs_retry
	return result


## The first criterion (in rubric order) that is not yet fully met, or "".
static func first_unmet_criterion(rubric: Rubric, session: LabSession) -> String:
	for row: Dictionary in evaluate(rubric, session).criteria:
		if row["status"] != "met":
			return row["id"]
	return ""


# --- criteria ---------------------------------------------------------------

static func _score(criterion: Dictionary, rubric: Rubric, session: LabSession, unsupported_claim: bool) -> Dictionary:
	var params: Dictionary = criterion.get("params", {})
	match str(criterion.get("check", "")):
		"events_collected":
			return _events_collected(params, session)
		"fact_cites_events":
			return _fact_cites_events(params, session)
		"facts_and_hypotheses":
			return _facts_and_hypotheses(params, session, unsupported_claim)
		"scope_and_severity":
			return _scope_and_severity(params, session)
		"response_quality":
			return _response_quality(rubric, session)
		"report_quality":
			return _report_quality(params, rubric, session)
	return {"points": 0, "missing": PackedStringArray()}


static func _events_collected(params: Dictionary, session: LabSession) -> Dictionary:
	var collected: Dictionary = _collected_event_ids(session)
	var points: int = 0
	var missing: PackedStringArray = PackedStringArray()
	for required: Variant in params.get("required", []):
		if collected.has(str(required)):
			points += int(params.get("points_each", 0))
		else:
			var event: EventRecord = session.store.get_event(str(required))
			missing.append(event.display_id if event != null else str(required))
	return {"points": points, "missing": missing}


static func _fact_cites_events(params: Dictionary, session: LabSession) -> Dictionary:
	var points: int = 0
	var missing: PackedStringArray = PackedStringArray()
	var fact_events: Array[Dictionary] = []
	for entry: CaseEntry in session.case_file.entries():
		if entry.kind == "fact":
			fact_events.append(_events_cited_by(entry, session))
	for group: Variant in params.get("groups", []):
		var needed: Array = (group as Dictionary).get("events_all", [])
		var satisfied: bool = false
		for cited: Dictionary in fact_events:
			var covers_all: bool = true
			for event_id: Variant in needed:
				if not cited.has(str(event_id)):
					covers_all = false
					break
			if covers_all:
				satisfied = true
				break
		if satisfied:
			points += int((group as Dictionary).get("points", 0))
		else:
			missing.append(str((group as Dictionary).get("label", "")))
	return {"points": points, "missing": missing}


static func _facts_and_hypotheses(params: Dictionary, session: LabSession, unsupported_claim: bool) -> Dictionary:
	var facts: int = 0
	var open_items: int = 0
	for entry: CaseEntry in session.case_file.entries():
		if entry.kind == "fact" and not entry.evidence_ids.is_empty():
			facts += 1
		elif entry.kind != "fact":
			open_items += 1
	var points: int = 0
	var missing: PackedStringArray = PackedStringArray()
	var wanted: int = int(params.get("min_facts", 1))
	if facts >= wanted:
		points += int(params.get("points_facts", 0))
	else:
		missing.append("at least %d facts backed by evidence (you have %d)" % [wanted, facts])
	if open_items >= 1:
		points += int(params.get("points_open", 0))
	else:
		missing.append("a hypothesis or an unknown for what you cannot prove yet")
	# Credit for careful claims needs at least one claim: an empty case has not
	# been careful, it has just not said anything yet.
	if unsupported_claim:
		missing.append("a fact that claims more than the evidence shows")
	elif facts > 0:
		points += int(params.get("points_claims", 0))
	return {"points": points, "missing": missing}


static func _scope_and_severity(params: Dictionary, session: LabSession) -> Dictionary:
	var points: int = 0
	var missing: PackedStringArray = PackedStringArray()
	var scope_points: Dictionary = params.get("scope_points", {})
	for asset_id: Variant in scope_points:
		if session.case_file.scope.has(str(asset_id)):
			points += int(scope_points[asset_id])
		else:
			missing.append(_asset_name(session, str(asset_id)) + " (in your scope)")
	var severity_points: Dictionary = params.get("severity_points", {})
	if severity_points.has(session.case_file.severity):
		points += int(severity_points[session.case_file.severity])
	elif session.case_file.severity == "unset":
		missing.append("a severity")
	return {"points": points, "missing": missing}


static func _response_quality(rubric: Rubric, session: LabSession) -> Dictionary:
	var chosen: String = session.case_file.recommendation
	if chosen.is_empty() or not rubric.response_scores.has(chosen):
		return {"points": 0, "missing": PackedStringArray(["a recommended response"])}
	var row: Dictionary = rubric.response_scores[chosen]
	return {"points": int(row.get("points", 0)), "missing": PackedStringArray(), "extra_feedback": str(row.get("feedback", ""))}


static func _report_quality(params: Dictionary, rubric: Rubric, session: LabSession) -> Dictionary:
	var points: int = 0
	var missing: PackedStringArray = PackedStringArray()
	var minimum: int = int(params.get("min_summary_chars", 1))
	if session.case_file.report_summary.length() >= minimum:
		points += int(params.get("summary_points", 0))
	else:
		missing.append("a summary of at least %d characters" % minimum)
	var chosen: String = session.case_file.escalation
	if not chosen.is_empty() and rubric.escalation_scores.has(chosen):
		points += int((rubric.escalation_scores[chosen] as Dictionary).get("points", 0))
	else:
		missing.append("who you escalate to")
	return {"points": points, "missing": missing}


# --- critical errors --------------------------------------------------------

static func _critical_error_applies(definition: Dictionary, rubric: Rubric, session: LabSession) -> bool:
	match str(definition.get("check", "")):
		"unsupported_claim":
			return _has_unsupported_claim(rubric, session)
		"broad_response_without_analysis":
			var chosen: String = session.case_file.recommendation
			if not rubric.response_scores.has(chosen) or (rubric.response_scores[chosen] as Dictionary).get("broad", false) != true:
				return false
			var minimum: int = int((definition.get("params", {}) as Dictionary).get("min_evidence", 1))
			return session.case_file.scope.is_empty() or session.case_file.severity == "unset" or session.ledger.size() < minimum
	return false


## A fact that states a conclusion the evidence cannot support (for example
## "data was stolen") with nothing backing it and no hedging. This is a
## keyword heuristic: it catches the plain statement, not every paraphrase.
static func _has_unsupported_claim(rubric: Rubric, session: LabSession) -> bool:
	var definition: Dictionary = rubric.critical_error_for("unsupported_claim")
	if definition.is_empty():
		return false
	var params: Dictionary = definition.get("params", {})
	for entry: CaseEntry in session.case_file.entries():
		if entry.kind != "fact":
			continue
		var text: String = entry.text.to_lower()
		if not _contains_any(text, params.get("claim_stems", [])) or _contains_any(text, params.get("negation_markers", [])):
			continue
		if not _evidence_has_tag(entry, session, params.get("supporting_tags", [])):
			return true
	return false


static func _contains_any(text: String, needles: Array) -> bool:
	for needle: Variant in needles:
		if text.contains(str(needle).to_lower()):
			return true
	return false


static func _evidence_has_tag(entry: CaseEntry, session: LabSession, tags: Array) -> bool:
	for event_id: Variant in _events_cited_by(entry, session):
		var event: EventRecord = session.store.get_event(str(event_id))
		if event == null:
			continue
		for tag: Variant in tags:
			if event.tags.has(str(tag)):
				return true
	return false


# --- helpers ----------------------------------------------------------------

static func _collected_event_ids(session: LabSession) -> Dictionary:
	var found: Dictionary = {}
	for record: EvidenceRecord in session.ledger.all():
		for event_id: String in record.event_ids:
			found[event_id] = true
	return found


## Set of event ids behind every piece of evidence an entry cites.
static func _events_cited_by(entry: CaseEntry, session: LabSession) -> Dictionary:
	var found: Dictionary = {}
	for evidence_id: String in entry.evidence_ids:
		var record: EvidenceRecord = session.ledger.get_record(evidence_id)
		if record == null:
			continue
		for event_id: String in record.event_ids:
			found[event_id] = true
	return found


static func _asset_name(session: LabSession, asset_id: String) -> String:
	for asset: Dictionary in session.package.assets:
		if str(asset.get("id", "")) == asset_id:
			return str(asset.get("name", asset_id))
	return asset_id
