class_name ScenarioPackage
extends RefCounted
## A validated, read-only lab scenario: authored events, assets, identities and
## the settings used to generate background noise. Built from a document that
## already passed ContentCatalog's schema and checks.

var id: String = ""
var events: Array[EventRecord] = []
var assets: Array[Dictionary] = []
var identities: Array[Dictionary] = []
var noise: Dictionary = {}


static func from_document(document: Dictionary) -> ScenarioPackage:
	var package: ScenarioPackage = ScenarioPackage.new()
	package.id = str(document.get("id", ""))
	for raw: Variant in document.get("events", []):
		if typeof(raw) == TYPE_DICTIONARY:
			package.events.append(EventRecord.from_dict(raw))
	for raw: Variant in document.get("assets", []):
		if typeof(raw) == TYPE_DICTIONARY:
			package.assets.append((raw as Dictionary).duplicate(true))
	for raw: Variant in document.get("identities", []):
		if typeof(raw) == TYPE_DICTIONARY:
			package.identities.append((raw as Dictionary).duplicate(true))
	var noise_value: Variant = document.get("noise", {})
	if typeof(noise_value) == TYPE_DICTIONARY:
		package.noise = (noise_value as Dictionary).duplicate(true)
	return package

