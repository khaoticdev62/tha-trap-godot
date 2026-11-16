extends TestCase
## Static safety scan of scripts/simulation: the lab engine must stay free of
## the scene tree, UI, clock, global randomness, files, network, dynamic
## execution and resource loading. A match here is a bug until proven otherwise
## (spec 04 §1 and §10, decision D-006).

const SIMULATION_DIR: String = "res://scripts/simulation"

## [pattern, why it is forbidden]
const FORBIDDEN: Array = [
	["\\bOS\\.", "host operating system access"],
	["\\bTime\\.", "wall-clock time breaks determinism"],
	["(?<![\\w.])(randi|randf|randomize|rand_range|randi_range|randf_range)\\(", "global randomness is unseeded"],
	["\\b(FileAccess|DirAccess|ResourceLoader|ResourceSaver)\\b", "file access"],
	["\\b(HTTPRequest|HTTPClient|TCPServer|StreamPeer\\w*|PacketPeer\\w*|UDPServer|WebSocket\\w*|ENet\\w*|WebRTC\\w*|IP)\\b", "network access"],
	["\\bExpression\\b", "dynamic expression evaluation"],
	["\\b(load|preload)\\(", "resource loading from a path"],
	["\\bget_tree\\(", "scene tree access"],
	["^\\s*extends\\s+(Node\\w*|Control|CanvasItem|Window|Viewport)\\b", "presentation base class"],
	["\\b(Palette|UiTheme|DialogueBox|ModalDialog|EventBus|Saves|Profiles|Settings|Scenes|Diagnostics)\\b", "presentation or service dependency"],
	["\\bpush_(error|warning)\\(|\\bprint(_rich)?\\(", "simulation reports through results, not the console"],
	["\\.(call|callv|call_deferred|bind|bindv|unbind)\\(|\\bCallable\\b|\\b(set_script|get_script)\\(|\\bClassDB\\b|\\bEngine\\.|\\bJavaScriptBridge\\b|\\bGDExtension\\w*", "dynamic dispatch or reflection"],
]


func _simulation_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(SIMULATION_DIR)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(SIMULATION_DIR.path_join(file_name))
	return found


func _code_lines(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return lines
	for line: String in file.get_as_text().split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return lines


func test_simulation_files_exist_so_the_scan_is_not_vacuous() -> void:
	check(_simulation_files().size() >= 5, "the scan found the simulation scripts (%d)" % _simulation_files().size())


func test_simulation_code_uses_no_forbidden_apis() -> void:
	for pattern: Array in FORBIDDEN:
		var regex: RegEx = RegEx.new()
		check_eq(regex.compile(pattern[0]), OK, "pattern compiles: %s" % pattern[0])
		for path: String in _simulation_files():
			for line: String in _code_lines(path):
				check(regex.search(line) == null, "%s uses %s (%s): %s" % [path.get_file(), pattern[0], pattern[1], line.strip_edges()])


func test_the_scanner_itself_catches_violations() -> void:
	var samples: Dictionary = {
		"OS.execute(\"cmd\", [])": 0,
		"var t = Time.get_ticks_msec()": 1,
		"var r = randi()": 2,
		"FileAccess.open(p, FileAccess.READ)": 3,
		"var c = HTTPRequest.new()": 4,
		"var e = Expression.new()": 5,
		"var s = load(path)": 6,
		"get_tree().quit()": 7,
		"extends Control": 8,
		"Saves.save_slot(0, {})": 9,
		"print(\"debug\")": 10,
		"handler.call(text)": 11,
		"var c: Callable = Callable(self, name)": 11,
		"obj.set_script(s)": 11,
		"ClassDB.instantiate(name)": 11,
	}
	for sample: String in samples:
		var regex: RegEx = RegEx.new()
		regex.compile(FORBIDDEN[samples[sample]][0])
		check(regex.search(sample) != null, "scanner flags: %s" % sample)
	var clean: RegEx = RegEx.new()
	clean.compile(FORBIDDEN[2][0])
	check(clean.search("rng.randi_range(0, 5)") == null, "seeded generator calls are allowed")
