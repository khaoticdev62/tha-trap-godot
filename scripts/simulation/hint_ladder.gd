class_name HintLadder
extends RefCounted
## Gives the next hint for the first part of the review that is not yet met.
## Each request moves one rung up for that part, up to the limit the
## difficulty allows. Hints are recorded but never change the score.


static func request(session: LabSession) -> ActionResult:
	if session.rubric == null or session.hints == null:
		return ActionResult.failure("This lab has no hints.")
	var allowed: int = session.hints.levels_for(session.difficulty)
	if allowed <= 0:
		return ActionResult.failure("No hints at this difficulty. Use help and the glossary, and trust your evidence.")
	var criterion_id: String = AssessmentEngine.first_unmet_criterion(session.rubric, session)
	if criterion_id.is_empty():
		return ActionResult.unchanged("", "You have everything the review looks for. Check your wording, then review the case.")
	var next_level: int = int(session.hints_used.get(criterion_id, 0)) + 1
	if next_level > allowed:
		return ActionResult.unchanged(criterion_id, "No more hints at this difficulty for this step. Look back over your evidence and the sample commands in help.")
	var text: String = session.hints.text_for(criterion_id, next_level)
	if text.is_empty():
		return ActionResult.failure("No hint is written for this step yet.")
	session.record_hint(criterion_id, next_level)
	return ActionResult.success("%s/%d" % [criterion_id, next_level], "Hint %d of %d: %s" % [next_level, allowed, text])
