extends TestCase
## The simulated terminal: allowed commands, arguments and teaching errors.
## Safety properties (host commands, shell syntax, fuzzing) are in
## tests/security/test_terminal_safety.gd.

var _session: LabSession
var _terminal: TerminalParser


func before_each() -> void:
	var loader: ContentLoader = ContentLoader.new(ContentCatalog.build_registry())
	var scenario: ContentResult = loader.load_content("lab_001_scenario")
	check(scenario.ok(), "scenario loads: %s" % str(scenario.errors))
	_session = LabSession.new(ScenarioPackage.from_document(scenario.data), "standard", 1)
	_terminal = TerminalParser.new(_session)


func _text(result: TerminalResult) -> String:
	return "\n".join(result.lines)


func test_help_lists_every_command_and_the_banner() -> void:
	var result: TerminalResult = _terminal.run("help")
	check(result.ok, "help works")
	var text: String = _text(result)
	check(text.contains(TerminalCommands.BANNER), "the SIMULATED ENVIRONMENT banner is shown")
	for key: String in TerminalCommands.command_keys():
		check(text.contains(key), "help lists '%s'" % key)


func test_help_for_one_command() -> void:
	var result: TerminalResult = _terminal.run("help logs search")
	check(result.ok and _text(result).contains("Usage:") and _text(result).contains("Example:"), "usage and example shown")
	check_eq(result.command, "help", "the command that ran is reported")
	check_eq(_terminal.run("help nonsense").code, TerminalResult.Code.NOT_FOUND, "unknown topic")
	check(_terminal.run("HELP LOGS SEARCH").ok, "case does not matter")


func test_every_documented_example_runs() -> void:
	for key: String in TerminalCommands.command_keys():
		var example: String = TerminalCommands.TABLE[key]["example"]
		var result: TerminalResult = _terminal.run(example)
		check(result.ok, "the example for '%s' works: %s -> %s" % [key, example, _text(result)])
		check(example.begins_with(key), "the example for '%s' actually uses it" % key)
		check(not str(TerminalCommands.TABLE[key]["summary"]).is_empty(), "'%s' has a summary" % key)


func test_assets_list() -> void:
	var result: TerminalResult = _terminal.run("assets list")
	var text: String = _text(result)
	check(result.ok and text.contains("HOST-014") and text.contains("Member support portal"), "lists the scenario assets")
	check(text.contains("4 assets"), "reports the count")


func test_hosts_show() -> void:
	var result: TerminalResult = _terminal.run("hosts show HOST-014")
	var text: String = _text(result)
	check(result.ok, "works: %s" % text)
	check(text.contains("Owner: j.smith"), "owner shown")
	check(text.contains("EVT-007"), "events on that device shown")
	check(_terminal.run("hosts show host-014").ok, "case does not matter")
	check(_terminal.run("hosts show host_014").ok, "the asset id works too")
	var portal: TerminalResult = _terminal.run("hosts show member_portal")
	check(not portal.ok and portal.code == TerminalResult.Code.BAD_ARGUMENT and _text(portal).contains("not a host"), "non-workstations are explained")
	check_eq(_terminal.run("hosts show HOST-999").code, TerminalResult.Code.NOT_FOUND, "unknown host")
	check_eq(_terminal.run("hosts show").code, TerminalResult.Code.BAD_ARGUMENT, "missing argument")
	check_eq(_terminal.run("hosts show a b").code, TerminalResult.Code.BAD_ARGUMENT, "too many arguments")


func test_logs_search_filters() -> void:
	var result: TerminalResult = _terminal.run("logs search source=auth user=j.smith after=09:00")
	var text: String = _text(result)
	check(result.ok, "runs: %s" % text)
	check(text.contains("EVT-001") and text.contains("EVT-003"), "the story sign-ins are found")
	check(not text.contains("EVT-007"), "the 08:31 baseline is before 09:00")
	check(text.contains("3 events matched."), "count reported: %s" % text)
	check(_text(_terminal.run("logs search result=failure user=j.smith")).contains("2 events matched."), "result filter")
	check(_text(_terminal.run("logs search user=j.smith")).contains("7 events matched."), "all sources when none given")
	check(_text(_terminal.run("logs search ip=ext-203-0-113-45")).contains("5 events matched."), "source address filter")
	check(_text(_terminal.run("logs search device=HOST-014")).contains("EVT-007"), "device filter")
	check(_text(_terminal.run("logs search source=auth user=j.smith before=09:13")).contains("2 events matched."), "before is exclusive")


func test_logs_search_quoted_text() -> void:
	var result: TerminalResult = _terminal.run('logs search contains="no recent"')
	check(result.ok and _text(result).contains("EVT-006"), "quoted option values may contain spaces: %s" % _text(result))
	check(_text(_terminal.run('logs search contains="a=b"')).contains("No events matched."), "an equals sign inside quotes is text")
	check(_text(_terminal.run('logs search contains="; rm -rf /"')).contains("No events matched."), "shell-looking text in quotes is only data")
	check(_text(_terminal.run('logs search contains="Café 🙂 مرحبا"')).contains("No events matched."), "unicode is fine")


func test_logs_search_limits() -> void:
	var limited: TerminalResult = _terminal.run("logs search user=j.smith limit=2")
	check(_text(limited).contains("showing the first 2"), "truncation is announced: %s" % _text(limited))
	for bad: String in ["0", "51", "-1", "+3", "abc", "1.5", "9999", ""]:
		check(not _terminal.run("logs search limit=%s" % bad).ok, "limit=%s rejected" % bad)


func test_logs_search_rejects_bad_options() -> void:
	for line: String in [
		"logs search source=shell", "logs search result=maybe", "logs search after=99:99", "logs search before=abc",
		"logs search after=10:00 before=09:00", "logs search colour=red", "logs search user=a user=b", "logs search user=",
		"logs search extra", 'logs search contains="%s"' % "x".repeat(61),
	]:
		var result: TerminalResult = _terminal.run(line)
		check(not result.ok and result.code == TerminalResult.Code.BAD_ARGUMENT, "rejected: %s" % line.left(50))
		check(not result.lines.is_empty(), "with an explanation: %s" % line.left(50))


func test_history_and_clear() -> void:
	check(_text(_terminal.run("history")).contains("Nothing run yet"), "empty history says so")
	_terminal.run("assets list")
	_terminal.run("nonsense")
	_terminal.run("hosts show HOST-014")
	var text: String = _text(_terminal.run("history"))
	check(text.contains("assets list") and text.contains("hosts show HOST-014"), "accepted commands are kept")
	check(not text.contains("nonsense"), "rejected input is not kept")
	var cleared: TerminalResult = _terminal.run("clear")
	check(cleared.ok and cleared.clear_screen, "clear asks the screen to clear")


func test_history_is_capped() -> void:
	for _i: int in TerminalParser.MAX_HISTORY + 20:
		_terminal.run("assets list")
	check_eq(_terminal.history.size(), TerminalParser.MAX_HISTORY, "history keeps only the most recent commands")


func test_unknown_commands_get_suggestions() -> void:
	var typo: TerminalResult = _terminal.run("halp")
	check(typo.code == TerminalResult.Code.UNKNOWN_COMMAND and _text(typo).contains("Did you mean 'help'"), "typo suggestion: %s" % _text(typo))
	check(_text(_terminal.run("asets list")).contains("Did you mean 'assets list'") or _text(_terminal.run("asets list")).contains("assets"), "close match suggested")
	check(not _text(_terminal.run("zzzzzzzz")).contains("Did you mean"), "no suggestion for nonsense")
	check(_text(_terminal.run("logs")).contains("logs search"), "a command group names its subcommands")
	check(_text(_terminal.run("logs delete")).contains("logs search"), "an unknown subcommand names the real ones")


func test_empty_input_is_quiet() -> void:
	for line: String in ["", "   ", "\t"]:
		var result: TerminalResult = _terminal.run(line)
		check(result.ok and result.lines.is_empty(), "blank input prints nothing")
	check_eq(_terminal.history.size(), 0, "and is not remembered")


func test_commands_do_not_change_the_lab() -> void:
	var before: String = _session.state_hash()
	for key: String in TerminalCommands.command_keys():
		_terminal.run(TerminalCommands.TABLE[key]["example"])
	check_eq(_session.state_hash(), before, "read-only commands never change the lab state")


func test_output_is_capped() -> void:
	var flood: TerminalResult = TerminalResult.new()
	for _i: int in 500:
		flood.lines.append("x".repeat(1000))
	var capped: TerminalResult = TerminalParser.limit_output(flood)
	check_eq(capped.lines.size(), TerminalParser.MAX_OUTPUT_LINES + 1, "line count capped plus a notice")
	check(capped.lines[capped.lines.size() - 1].contains("cut off"), "the cut is announced")
	for line: String in capped.lines:
		check(line.length() <= TerminalParser.MAX_LINE_CHARS, "line length capped")
