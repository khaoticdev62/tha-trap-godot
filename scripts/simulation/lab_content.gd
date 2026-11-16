class_name LabContent
extends RefCounted
## Everything a lab needs, loaded and cross-checked: the scenario, the rubric
## and the hints. Use new_session() to start an attempt with scoring and hints
## attached.

var package: ScenarioPackage = null
var rubric: Rubric = null
var hints: HintSet = null
## Problems found while loading. Empty means the lab is ready to play.
var errors: PackedStringArray = PackedStringArray()


## `lab_key` is the content prefix, for example "lab_001".
static func load_lab(loader: ContentLoader, lab_key: String) -> LabContent:
	var content: LabContent = LabContent.new()
	var scenario: ContentResult = loader.load_content("%s_scenario" % lab_key)
	var rubric_result: ContentResult = loader.load_content("%s_rubric" % lab_key)
	var hints_result: ContentResult = loader.load_content("%s_hints" % lab_key)
	for loaded: ContentResult in [scenario, rubric_result, hints_result]:
		content.errors.append_array(loaded.errors)
	if not content.errors.is_empty():
		return content
	content.errors.append_array(ContentCatalog.lab_cross_problems(scenario.data, rubric_result.data, hints_result.data))
	if not content.errors.is_empty():
		return content
	content.package = ScenarioPackage.from_document(scenario.data)
	content.rubric = Rubric.from_document(rubric_result.data)
	content.hints = HintSet.from_document(hints_result.data)
	return content


func is_ready() -> bool:
	return errors.is_empty() and package != null and rubric != null and hints != null


func new_session(difficulty: String, seed_number: int) -> LabSession:
	var session: LabSession = LabSession.new(package, difficulty, seed_number)
	session.rubric = rubric
	session.hints = hints
	return session
