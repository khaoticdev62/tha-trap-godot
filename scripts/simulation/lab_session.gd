class_name LabSession
extends RefCounted
## One running attempt at a lab. Owns the event store and can return to its
## exact starting state with reset(). It never touches the scene tree, the
## clock, the filesystem or the network, so it runs the same in headless tests
## and in the game.

signal session_reset

var package: ScenarioPackage
var difficulty: String
var seed_value: int
var store: EventStore = EventStore.new()


func _init(scenario: ScenarioPackage, difficulty_id: String = ScenarioGenerator.DEFAULT_DIFFICULTY, seed_number: int = 0) -> void:
	package = scenario
	difficulty = ScenarioGenerator.normalise_difficulty(difficulty_id)
	seed_value = seed_number
	_rebuild()


## Discards every change made during the attempt and restores the baseline.
func reset() -> void:
	_rebuild()
	session_reset.emit()


## Fingerprint of everything that defines this session's state.
func state_hash() -> String:
	var summary: String = "%s|%s|%d|%s" % [package.id, difficulty, seed_value, store.canonical_json()]
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(summary.to_utf8_buffer())
	return hasher.finish().hex_encode()


func _rebuild() -> void:
	store = EventStore.new()
	# Copies, so changing a record during play can never alter the package.
	for authored: EventRecord in package.events:
		store.add(EventRecord.from_dict(authored.to_dict()))
	for generated: EventRecord in ScenarioGenerator.generate(package, difficulty, seed_value):
		store.add(generated)
