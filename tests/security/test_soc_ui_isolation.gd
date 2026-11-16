extends TestCase
## Static safety scan of the SOC interface (spec 04 §1, decision D-006, M8
## acceptance): the terminal screen and every other SOC script must never run a
## process, evaluate text, touch files or the network, or write simulation data.
## The UI only calls SocModel; it does not edit the EventStore.

const SCAN_DIRS: Array[String] = ["res://scripts/ui/soc", "res://scripts/ui/kit"]
const MODEL_FILE: String = "res://scripts/gameplay/soc_model.gd"

## [pattern, why it is forbidden]
const FORBIDDEN: Array = [
	["\\bOS\\.(execute|create_process|create_instance|shell_open|shell_show_in_file_manager|kill|set_environment|move_to_trash)", "host process or shell access"],
	["\\bExpression\\b", "dynamic expression evaluation"],
	["\\b(FileAccess|DirAccess|ResourceSaver)\\b", "file access"],
	["\\b(HTTPRequest|HTTPClient|TCPServer|StreamPeer\\w*|PacketPeer\\w*|UDPServer|WebSocket\\w*|ENet\\w*|WebRTC\\w*|IP)\\b", "network access"],
	["\\b(set_script|JavaScriptBridge|GDExtension\\w*|ClassDB)\\b", "reflection or script injection"],
	["\\bEventStore\\b|\\.store\\.(add|remove)\\(", "UI must not create or edit simulation events"],
	["\\bbbcode_enabled\\s*=\\s*true|\\bappend_text\\(|\\.parse_bbcode\\(", "terminal output must stay plain text"],
]


func _files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray([MODEL_FILE])
	for directory: String in SCAN_DIRS:
		var dir: DirAccess = DirAccess.open(directory)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			if file_name.ends_with(".gd"):
				found.append(directory.path_join(file_name))
	return found


func _code_lines(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return lines


func test_scan_covers_the_soc_scripts() -> void:
	var files: PackedStringArray = _files()
	check(files.size() >= 12, "the scan found the SOC scripts (%d)" % files.size())
	check(files.has("res://scripts/ui/soc/terminal_screen.gd"), "the terminal screen is scanned")


func test_soc_code_uses_no_forbidden_apis() -> void:
	for pattern: Array in FORBIDDEN:
		var regex: RegEx = RegEx.new()
		check_eq(regex.compile(pattern[0]), OK, "pattern compiles: %s" % pattern[0])
		for path: String in _files():
			for line: String in _code_lines(path):
				check(regex.search(line) == null, "%s uses %s (%s): %s" % [path.get_file(), pattern[0], pattern[1], line.strip_edges()])


func test_terminal_screen_only_talks_to_the_model() -> void:
	var code: String = "\n".join(_code_lines("res://scripts/ui/soc/terminal_screen.gd"))
	check(code.contains("model.run_command("), "commands go through SocModel.run_command")
	check(not code.contains("TerminalParser"), "the screen never builds a parser itself")
	check(code.contains("bbcode_enabled = false"), "BBCode is explicitly off")
	check(code.contains("add_text("), "output is added as plain text")


func test_model_runs_commands_only_through_the_parser() -> void:
	var source: String = FileAccess.get_file_as_string(MODEL_FILE)
	check(source.contains("terminal.run(line)"), "the model passes the line to the parser")
	check(not source.contains(".execute("), "nothing is executed")
