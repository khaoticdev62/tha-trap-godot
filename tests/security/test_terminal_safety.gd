extends TestCase
## Safety of the simulated terminal (spec 04 §1 and §10, decision D-006):
## host commands, shell syntax, paths, injection-looking text, hostile and random
## input. Core property for every input: it returns a result, prints bounded
## text, changes nothing in the lab, and is never run by the host.

const MAX_LINES: int = TerminalParser.MAX_OUTPUT_LINES + 1

var _session: LabSession
var _terminal: TerminalParser
var _baseline: String


func before_each() -> void:
	var content: LabContent = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	check(content.is_ready(), "the lab loads: %s" % str(content.errors))
	_session = content.new_session("expert", 3)
	_terminal = TerminalParser.new(_session)
	_baseline = _session.state_hash()


func _well_behaved(line: String, context: String) -> TerminalResult:
	var result: TerminalResult = _terminal.run(line)
	var sane: bool = result != null and result.lines.size() <= MAX_LINES
	if result != null:
		for text: String in result.lines:
			sane = sane and text.length() <= TerminalParser.MAX_LINE_CHARS
		if not result.ok:
			sane = sane and not result.lines.is_empty()
	check(sane, "%s: bounded, explained output for: %s" % [context, line.left(60).c_escape()])
	check_eq(_session.state_hash(), _baseline, "%s: the lab is unchanged by: %s" % [context, line.left(60).c_escape()])
	return result


func test_host_commands_are_refused_by_name() -> void:
	var samples: Array[String] = ["dir", "ls", "cat", "rm", "del", "whoami", "curl", "wget", "ping", "nmap", "ssh", "powershell",
		"pwsh", "cmd", "bash", "sh", "python", "node", "sudo", "chmod", "kill", "taskkill", "ipconfig", "netstat", "echo",
		"format", "shutdown", "reg", "eval", "exec", "start", "open", "git", "docker", "mimikatz", "hashcat", "sqlmap"]
	for command: String in samples:
		for variant: String in [command, command.to_upper(), command + " -la", command + " status", command.capitalize() + " now"]:
			var result: TerminalResult = _well_behaved(variant, "host command")
			check_eq(result.code, TerminalResult.Code.HOST_COMMAND, "refused as a host command: %s" % variant)
			check(result.lines[0].contains("simulated"), "and explained: %s" % variant)


func test_host_command_list_does_not_overlap_the_real_commands() -> void:
	for key: String in TerminalCommands.TABLE:
		check(not TerminalCommands.HOST_COMMANDS.has(key.get_slice(" ", 0)), "'%s' is a real command, so it must not be on the host list" % key)


func test_shell_syntax_is_refused() -> void:
	var samples: Array[String] = [
		"help; ls", "help && whoami", "help || id", "help | more", "assets list > out.txt", "assets list >> out.txt",
		"help < in.txt", "hosts show $(whoami)", "hosts show `id`", "hosts show ${HOME}", "hosts show $HOME", "logs search user=*",
		"logs search user=?", "help ~", "help !!", "help #comment", "help %PATH%", "help ^", "help {a,b}", "help [a-z]",
		"help &", "help (x)", "logs search contains='x'", "help \\",
	]
	for line: String in samples:
		var result: TerminalResult = _well_behaved(line, "shell syntax")
		check(not result.ok, "refused: %s" % line)


func test_paths_are_refused() -> void:
	var samples: Array[String] = [
		"hosts show ../../etc/passwd", "hosts show /etc/passwd", "hosts show C:\\Windows\\system32", "hosts show ..\\..\\x",
		"hosts show ./x", "hosts show res://project.godot", "hosts show user://saves/slot_0.json", "hosts show file:///c:/x",
		"hosts show %2e%2e%2f", "assets list /", "logs search source=../x",
	]
	for line: String in samples:
		var result: TerminalResult = _well_behaved(line, "path")
		check(not result.ok, "refused: %s" % line)


func test_quoted_text_is_data_never_a_command() -> void:
	for payload: String in ["$(whoami)", "`id`", "; rm -rf /", "../../etc/passwd", "C:\\Windows", "<script>alert(1)</script>", "' OR '1'='1", "%s%s%n", "\\u0000", "{{7*7}}", "${jndi:ldap://x}"]:
		var as_argument: TerminalResult = _well_behaved('hosts show "%s"' % payload.replace("\\", "\\\\").replace('"', '\\"'), "quoted argument")
		check(not as_argument.ok, "a quoted payload is not a valid host name: %s" % payload)
		var as_search: TerminalResult = _well_behaved('logs search contains="%s"' % payload.replace("\\", "\\\\").replace('"', '\\"'), "quoted search")
		check(as_search.ok and as_search.lines[0].contains("No events matched"), "a quoted payload is only searched for as text: %s" % payload)


func test_malformed_lines_are_explained() -> void:
	var samples: Array[String] = ['help "', 'help "unterminated', 'logs search contains="a" extra"', 'help "a"b', 'help a"b"',
		'help "a\\z"', "help \u0001", "help " + String.chr(0x202E) + "x", "help " + String.chr(0x200B), "   \u0007 ", "logs search =x", "= = ="]
	for line: String in samples:
		_well_behaved(line, "malformed")


func test_size_limits() -> void:
	check_eq(_terminal.run("a".repeat(TerminalTokenizer.MAX_LINE_CHARS + 1)).code, TerminalResult.Code.TOO_LONG, "an over-long line is refused")
	check_eq(_terminal.run(" ".join(PackedStringArray(range(TerminalTokenizer.MAX_TOKENS + 1).map(func(n: int) -> String: return "w%d" % n)))).code, TerminalResult.Code.TOO_LONG, "too many parts is refused")
	check_eq(_terminal.run("help " + "x".repeat(TerminalTokenizer.MAX_TOKEN_CHARS + 1)).code, TerminalResult.Code.TOO_LONG, "a long single part is refused")
	for huge: String in ["A".repeat(100000), "\"".repeat(5000), "(".repeat(2000), " ".repeat(50000), "\n".repeat(1000)]:
		_well_behaved(huge, "huge input")


func test_random_lines_never_escape_the_sandbox() -> void:
	var vocabulary: Array[String] = ["help", "clear", "history", "assets", "list", "hosts", "show", "logs", "search", "HOST-014", "source=auth",
		"user=j.smith", "after=09:00", "limit=3", "contains=", "\"", "'", ";", "|", "&", ">", "<", "`", "$(x)", "..", "/", "\\", "~", "*",
		"ls", "cat", "rm", "curl", "powershell", "=", ":", ",", "\u00e9", "\U0001F600", "x".repeat(30)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1116
	var started: int = Time.get_ticks_msec()
	for _i: int in 2000:
		var parts: PackedStringArray = PackedStringArray()
		for _j: int in rng.randi_range(0, 10):
			parts.append(vocabulary[rng.randi_range(0, vocabulary.size() - 1)])
		_well_behaved(" ".join(parts), "random line")
	for _i: int in 1000:
		var text: String = ""
		for _j: int in rng.randi_range(0, 40):
			text += String.chr(rng.randi_range(1, 0x2FF))
		_well_behaved(text, "random characters")
	check(Time.get_ticks_msec() - started < 30000, "the fuzz run finished within the time budget")


func test_every_command_rejects_wrong_arguments_without_running() -> void:
	for key: String in TerminalCommands.command_keys():
		var spec: Dictionary = TerminalCommands.TABLE[key]
		var too_many: String = key + " " + " ".join(PackedStringArray(range(int(spec["positional_max"]) + 1).map(func(n: int) -> String: return "arg%d" % n)))
		var result: TerminalResult = _well_behaved(too_many, "arity")
		check(not result.ok, "'%s' refuses extra arguments" % key)
		var unknown_option: TerminalResult = _well_behaved(key + " bogus=1", "options")
		check(not unknown_option.ok, "'%s' refuses an unknown option" % key)


func test_terminal_has_no_path_or_execution_surface() -> void:
	# The argument validators must reject anything path-like or shell-like outright.
	for text: String in ["", "a/b", "a\\b", "a b", "a;b", "a|b", "a$b", "a`b", "a'b", "a\"b", "a" + String.chr(0x202E), "x".repeat(33), "%41", "~", "*", "?"]:
		check(not TerminalParser._is_plain_word(text), "not a plain word: %s" % text.c_escape())
	for text: String in ["HOST-014", "j.smith", "evt_001", "ext-203-0-113-45", "a:b"]:
		check(TerminalParser._is_plain_word(text), "plain word: %s" % text)


func test_random_case_building_never_corrupts_the_lab() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5150
	var events: Array[String] = ["EVT-001", "EVT-002", "EVT-003", "EVT-004", "EVT-005", "EVT-006", "EVT-007", "evt_n0001", "EVT-999", "$x", "..", "", "EVT-001,EVT-002"]
	var evidence_ids: Array[String] = ["ev_001", "ev_002", "ev_003", "ev_004", "ev_005", "ev_006", "ev_404", "ev_x", "EV_001"]
	var kinds: Array[String] = ["fact", "hypothesis", "unknown", "FACT", "bad", ""]
	var texts: Array[String] = ["A short note", "Two failures then a success", "x".repeat(300), "x".repeat(301), "$(whoami)", "Café 🙂", "a\\\"b"]
	var levels: Array[String] = ["low", "medium", "high", "critical", "unset", "urgent", ""]
	var assets: Array[String] = ["host_014", "HOST-022", "member_portal,sso_main", "host_999", "a/b", "host_014,host_014"]
	var started: int = Time.get_ticks_msec()
	for _i: int in 3000:
		var line: String = ""
		match rng.randi_range(0, 8):
			0:
				line = "evidence add %s" % events[rng.randi_range(0, events.size() - 1)]
			1:
				line = "evidence add %s note=\"%s\"" % [events[rng.randi_range(0, events.size() - 1)], texts[rng.randi_range(0, texts.size() - 1)]]
			2:
				line = "evidence remove %s" % evidence_ids[rng.randi_range(0, evidence_ids.size() - 1)]
			3, 4:
				line = "case note CASE-001 \"%s\" kind=%s evidence=%s" % [texts[rng.randi_range(0, texts.size() - 1)], kinds[rng.randi_range(0, kinds.size() - 1)], evidence_ids[rng.randi_range(0, evidence_ids.size() - 1)]]
			5:
				line = "case severity %s" % levels[rng.randi_range(0, levels.size() - 1)]
			6:
				line = "case scope %s" % assets[rng.randi_range(0, assets.size() - 1)]
			7:
				line = "timeline build"
			8:
				line = "case show"
		var result: TerminalResult = _terminal.run(line)
		check(result != null and result.lines.size() <= MAX_LINES, "bounded output for: %s" % line.left(60).c_escape())
		var problems: PackedStringArray = _session.state_problems()
		check(problems.is_empty(), "the lab stays consistent after '%s': %s" % [line.left(60).c_escape(), str(problems)])
		if not problems.is_empty():
			return
	var copy: LabSession = LabSession.new(_session.package, _session.difficulty, _session.seed_value)
	var restored: ActionResult = copy.restore(JSON.parse_string(JSON.stringify(_session.snapshot())))
	check(restored.ok, "whatever the fuzz built can be saved and loaded again: %s" % restored.message)
	check_eq(copy.state_hash(), _session.state_hash(), "with an identical state")
	check(_session.ledger.size() > 0 and _session.case_file.entries().size() > 0, "the fuzz really built something (%d evidence, %d entries)" % [_session.ledger.size(), _session.case_file.entries().size()])
	check(Time.get_ticks_msec() - started < 30000, "finished within the time budget")
