extends TestCase
## The simulated terminal: allowed commands, arguments and teaching errors.
## Safety properties (host commands, shell syntax, fuzzing) are in
## tests/security/test_terminal_safety.gd.

var _session: LabSession
var _terminal: TerminalParser


func before_each() -> void:
	var content: LabContent = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	check(content.is_ready(), "the lab loads: %s" % str(content.errors))
	_session = content.new_session("standard", 1)
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
	var ran: int = 0
	for key: String in TerminalCommands.command_keys():
		if TerminalCommands.TABLE[key].get("mutates", false):
			continue
		_terminal.run(TerminalCommands.TABLE[key]["example"])
		ran += 1
	check(ran >= 6, "several read-only commands were exercised (%d)" % ran)
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


# --- commands that build the case -------------------------------------------

func test_collecting_evidence_from_the_terminal() -> void:
	var added: TerminalResult = _terminal.run("evidence add EVT-004 CASE-001")
	check(added.ok and _text(added).contains("Added ev_001") and _text(added).contains("EVT-004"), "adds and shows the event: %s" % _text(added))
	check(_terminal.run("evidence add evt_003 note=\"new source\"").ok, "a note can be attached")
	check(_text(_terminal.run("evidence list")).contains("new source"), "the note is listed")
	var again: TerminalResult = _terminal.run("evidence add EVT-004")
	check(again.ok and _text(again).contains("Already collected"), "repeating is harmless: %s" % _text(again))
	check_eq(_session.ledger.size(), 2, "two records")
	check(_session.state_problems().is_empty(), "healthy")


func test_evidence_command_errors() -> void:
	for line: String in ["evidence add", "evidence add EVT-999", "evidence add EVT-001 CASE-002", "evidence add EVT-001 CASE-001 extra",
			"evidence add EVT-001 note=", "evidence add $x", "evidence remove ev_404", "evidence remove", "evidence list extra"]:
		var result: TerminalResult = _terminal.run(line)
		check(not result.ok and not result.lines.is_empty(), "refused with a reason: %s" % line)
	check_eq(_session.ledger.size(), 0, "nothing was collected")
	check(_text(_terminal.run("evidence list")).contains("No evidence collected yet"), "an empty list guides the player")


func test_case_commands_from_the_terminal() -> void:
	_terminal.run("evidence add EVT-001")
	var hypothesis: TerminalResult = _terminal.run('case note CASE-001 "Possible password guessing"')
	check(hypothesis.ok and _text(hypothesis).contains("hypothesis"), "defaults to a hypothesis: %s" % _text(hypothesis))
	var bare_fact: TerminalResult = _terminal.run('case note CASE-001 "Failures happened" kind=fact')
	check(not bare_fact.ok and _text(bare_fact).contains("evidence"), "a fact without evidence is refused: %s" % _text(bare_fact))
	var fact: TerminalResult = _terminal.run('case note CASE-001 "Failures happened" kind=fact evidence=ev_001')
	check(fact.ok, "a fact with evidence is accepted: %s" % _text(fact))
	check(_terminal.run('case note CASE-001 "What was accessed?" kind=UNKNOWN').ok, "kind ignores case")
	check(_terminal.run("case severity high").ok, "severity")
	check(_terminal.run("case scope host_014,HOST-022").ok, "scope")
	var shown: String = _text(_terminal.run("case show"))
	check(shown.contains("Severity: high") and shown.contains("host_014, host_022"), "case show reports severity and scope: %s" % shown)
	check(shown.contains("[FACT]") and shown.contains("[HYPOTHESIS]") and shown.contains("[UNKNOWN]") and shown.contains("(ev_001)"), "entries are labelled by kind: %s" % shown)


func test_case_command_errors() -> void:
	for line: String in ['case note CASE-002 "x"', "case note CASE-001", 'case note CASE-001 "x" kind=guess', 'case note CASE-001 "x" evidence=ev_1/2',
			'case note CASE-001 "x" evidence=nothing', "case severity urgent", "case severity", "case scope", "case scope host_999",
			"case scope a/b", 'case note CASE-001 "x" colour=red', "case show extra"]:
		var result: TerminalResult = _terminal.run(line)
		check(not result.ok and not result.lines.is_empty(), "refused with a reason: %s" % line)
	check_eq(_session.case_file.entries().size(), 0, "no entries were stored")
	check(_session.state_problems().is_empty(), "healthy")


func test_timeline_command() -> void:
	check(_text(_terminal.run("timeline build")).contains("No evidence collected yet"), "empty timeline guides the player")
	_terminal.run("evidence add EVT-003")
	_terminal.run("evidence add EVT-001")
	var text: String = _text(_terminal.run("timeline build CASE-001"))
	check(text.find("EVT-001") < text.find("EVT-003") and text.contains("2 events on the timeline"), "time ordered: %s" % text)
	check(not _terminal.run("timeline build CASE-009").ok, "only the real case id is accepted")


func test_removing_cited_evidence_from_the_terminal() -> void:
	_terminal.run("evidence add EVT-003")
	_terminal.run('case note CASE-001 "A new source signed in" kind=fact evidence=ev_001')
	var blocked: TerminalResult = _terminal.run("evidence remove ev_001")
	check(not blocked.ok and _text(blocked).contains("ce_001"), "the citing entry is named: %s" % _text(blocked))
	check_eq(_session.ledger.size(), 1, "the evidence is still there")


func test_a_full_lab_001_investigation_through_the_terminal() -> void:
	var steps: Array[String] = [
		"logs search source=auth user=j.smith",
		"evidence add EVT-001 note=\"first failure\"",
		"evidence add EVT-002",
		"evidence add EVT-003 note=\"success from a new source\"",
		"evidence add EVT-004 note=\"new MFA device\"",
		"evidence add EVT-005",
		"case note CASE-001 \"Two failed sign-ins were followed by a success from an unfamiliar source.\" kind=fact evidence=ev_001,ev_002,ev_003",
		"case note CASE-001 \"A new MFA device was requested three minutes after the success.\" kind=fact evidence=ev_004",
		"case note CASE-001 \"Someone other than the employee may have taken over the account.\" kind=hypothesis",
		"case note CASE-001 \"Was any member data copied?\" kind=unknown",
		"case severity high",
		"case scope host_014,member_portal",
		"timeline build",
		"case show",
	]
	for line: String in steps:
		var result: TerminalResult = _terminal.run(line)
		check(result.ok, "step works: %s -> %s" % [line.left(50), _text(result).left(80)])
	check_eq(_session.ledger.size(), 5, "five pieces of evidence")
	check_eq(_session.case_file.entries().size(), 4, "four entries")
	check(_session.state_problems().is_empty(), "the finished lab is consistent")
	var restored: LabSession = LabSession.new(_session.package, _session.difficulty, _session.seed_value)
	check(restored.restore(JSON.parse_string(JSON.stringify(_session.snapshot()))).ok, "and it survives a save and load")
	check_eq(restored.state_hash(), _session.state_hash(), "with identical state")
