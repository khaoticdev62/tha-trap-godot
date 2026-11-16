class_name ScenarioGenerator
extends RefCounted
## Produces background noise and decoys for a scenario. Deterministic: the same
## (package, difficulty, seed) always yields the same events, so a lab can be
## reset and replayed exactly. It uses only an explicitly seeded generator, no
## clock and no global random calls. Difficulty changes how much noise there is,
## never the authored (canonical) events, so the answer never changes.

const DIFFICULTIES: Array[String] = ["beginner", "standard", "advanced", "expert"]
const DEFAULT_DIFFICULTY: String = "standard"

## Share of noise rolls (out of 100) that are a normal sign-in, a single typo
## failure, or a portal visit.
const NORMAL_SIGN_IN_MAX_ROLL: int = 85
const TYPO_FAILURE_MAX_ROLL: int = 97
const DECOY_FAILURE_GAP_SECONDS: int = 40
const DECOY_SUCCESS_GAP_SECONDS: int = 95
const DECOY_WINDOW_MARGIN_SECONDS: int = 300


static func normalise_difficulty(value: String) -> String:
	return value if DIFFICULTIES.has(value) else DEFAULT_DIFFICULTY


static func generate(package: ScenarioPackage, difficulty: String, seed_value: int) -> Array[EventRecord]:
	var level: String = normalise_difficulty(difficulty)
	var noise: Dictionary = package.noise
	var accounts: Array = noise.get("accounts", [])
	var sources: Array = noise.get("sources", [])
	var devices: Array = noise.get("devices", [])
	if accounts.is_empty() or sources.size() != accounts.size() or devices.size() != accounts.size():
		return []

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var day_start: int = int(noise.get("day_start_tick", 0))
	var day_end: int = int(noise.get("day_end_tick", EventRecord.SECONDS_PER_DAY - 1))
	var counts: Dictionary = noise.get("counts", {})
	var decoys: Dictionary = noise.get("decoys", {})

	var drafts: Array[Dictionary] = []
	for _i: int in int(counts.get(level, 0)):
		var who: int = rng.randi_range(0, accounts.size() - 1)
		var when: int = rng.randi_range(day_start, day_end)
		var roll: int = rng.randi_range(1, 100)
		if roll <= NORMAL_SIGN_IN_MAX_ROLL:
			drafts.append(_draft(when, "auth", accounts[who], "success", sources[who], devices[who], "Sign-in succeeded.", "noise"))
		elif roll <= TYPO_FAILURE_MAX_ROLL:
			drafts.append(_draft(when, "auth", accounts[who], "failure", sources[who], devices[who], "Sign-in failed: incorrect password.", "noise"))
		else:
			drafts.append(_draft(when, "app", accounts[who], "success", sources[who], devices[who], "Member support portal accessed.", "noise"))

	# Decoy: an ordinary typo burst (two failures, then success) from the
	# account's usual source. It looks alarming at a glance but is benign.
	for _i: int in int(decoys.get(level, 0)):
		var who: int = rng.randi_range(0, accounts.size() - 1)
		var when: int = rng.randi_range(day_start, maxi(day_start, day_end - DECOY_WINDOW_MARGIN_SECONDS))
		drafts.append(_draft(when, "auth", accounts[who], "failure", sources[who], devices[who], "Sign-in failed: incorrect password.", "decoy"))
		drafts.append(_draft(when + DECOY_FAILURE_GAP_SECONDS, "auth", accounts[who], "failure", sources[who], devices[who], "Sign-in failed: incorrect password.", "decoy"))
		drafts.append(_draft(when + DECOY_SUCCESS_GAP_SECONDS, "auth", accounts[who], "success", sources[who], devices[who], "Sign-in succeeded.", "decoy"))

	# Number the events in time order (creation order breaks ties) so ids are
	# stable for a given seed.
	for index: int in drafts.size():
		drafts[index]["order"] = index
	drafts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["tick"] < b["tick"] or (a["tick"] == b["tick"] and a["order"] < b["order"]))
	var events: Array[EventRecord] = []
	for index: int in drafts.size():
		var draft: Dictionary = drafts[index]
		draft["id"] = "evt_n%04d" % (index + 1)
		draft["display_id"] = "EVT-N%04d" % (index + 1)
		events.append(EventRecord.from_dict(draft))
	return events


static func _draft(tick: int, source: String, actor: String, result: String, ip_label: String, device: String, detail: String, tag: String) -> Dictionary:
	return {
		"tick": tick, "source": source, "actor": actor, "result": result,
		"ip_label": ip_label, "device": device, "detail": detail,
		"tags": [tag], "canonical": false,
	}
