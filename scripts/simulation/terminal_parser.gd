class_name TerminalParser
extends RefCounted
## The simulated lab terminal. One line in, a TerminalResult out.
##
## Safety design (spec 04 §1, decision D-006):
##  - Input is tokenised by a hand-written tokenizer with no shell features.
##  - The first words must match an entry in TerminalCommands.TABLE exactly;
##    host commands are named and refused, unknown words are refused.
##  - The handler is chosen by `match` on the table key, never by text.
##  - Arguments are checked against fixed patterns and only ever used as keys
##    into the loaded scenario, never as paths, commands or code.
##  - Handlers read the LabSession and print text. Nothing here can reach the
##    host, the filesystem or the network.

const MAX_HISTORY: int = 50
const MAX_OUTPUT_LINES: int = 200
const MAX_LINE_CHARS: int = 240
const MAX_WORD_CHARS: int = 32
const MAX_SEARCH_TEXT_CHARS: int = 60
const MAX_SEARCH_LIMIT: int = 50
const DEFAULT_SEARCH_LIMIT: int = 20
const SUGGESTION_DISTANCE: int = 2

var history: PackedStringArray = PackedStringArray()

var _session: LabSession


func _init(session: LabSession) -> void:
	_session = session


## Runs one line. Every result, including every error, passes through
## limit_output so nothing can print an unbounded amount.
func run(line: String) -> TerminalResult:
	return limit_output(_run_line(line))


func _run_line(line: String) -> TerminalResult:
	if line.strip_edges().is_empty():
		return TerminalResult.new()
	var failure: Array[TerminalResult] = []
	var tokens: Array[Dictionary] = TerminalTokenizer.tokenize(line, failure)
	if not failure.is_empty():
		return failure[0]

	var resolved: Dictionary = _resolve(tokens)
	if not resolved["ok"]:
		return resolved["result"]
	var key: String = resolved["key"]
	var arguments: Dictionary = _read_arguments(key, tokens.slice(resolved["used"]))
	if not arguments["ok"]:
		return arguments["result"]

	var result: TerminalResult = _dispatch(key, arguments["positional"], arguments["options"])
	result.command = key
	if result.ok and not result.clear_screen:
		_remember(line.strip_edges())
	return result


## Longest-first match of the leading words against the command table.
func _resolve(tokens: Array[Dictionary]) -> Dictionary:
	var first: String = String(tokens[0]["text"]).to_lower()
	if TerminalCommands.HOST_COMMANDS.has(first):
		return _refuse(TerminalResult.Code.HOST_COMMAND, "'%s' is a command for a real computer. This terminal is simulated and cannot run it. Type help to see the commands that work here." % first)
	if TerminalCommands.TABLE.has(first):
		return {"ok": true, "key": first, "used": 1}
	var group_keys: PackedStringArray = PackedStringArray()
	for key: String in TerminalCommands.TABLE:
		if key.begins_with(first + " "):
			group_keys.append(key)
	if not group_keys.is_empty():
		var second: String = String(tokens[1]["text"]).to_lower() if tokens.size() > 1 and not tokens[1]["quoted"] else ""
		var combined: String = first + " " + second
		if TerminalCommands.TABLE.has(combined):
			return {"ok": true, "key": combined, "used": 2}
		return _refuse(TerminalResult.Code.UNKNOWN_COMMAND, "'%s' needs one of: %s." % [first, ", ".join(group_keys)])
	var message: String = "Unknown command '%s'." % _clip_word(first)
	var suggestion: String = _closest_command(first)
	if not suggestion.is_empty():
		message += " Did you mean '%s'?" % suggestion
	return _refuse(TerminalResult.Code.UNKNOWN_COMMAND, message + " Type help to see the commands.")


func _refuse(code: TerminalResult.Code, message: String) -> Dictionary:
	return {"ok": false, "result": TerminalResult.failure(code, message)}


## Splits the rest of the line into positional words and key=value options and
## checks them against the command's declared shape.
func _read_arguments(key: String, rest: Array) -> Dictionary:
	var spec: Dictionary = TerminalCommands.TABLE[key]
	var allowed_options: Array = spec["options"]
	var positional: PackedStringArray = PackedStringArray()
	var options: Dictionary = {}
	for token: Dictionary in rest:
		var text: String = token["text"]
		if not token["quoted"] and text.contains("="):
			var split_at: int = text.find("=")
			var name: String = text.left(split_at).to_lower()
			var value: String = text.substr(split_at + 1)
			if not allowed_options.has(name):
				return _bad_arguments("'%s' is not an option of '%s'. Usage: %s" % [_clip_word(name), key, spec["usage"]])
			if options.has(name):
				return _bad_arguments("'%s' was given twice." % name)
			if value.is_empty():
				return _bad_arguments("'%s=' needs a value. Usage: %s" % [name, spec["usage"]])
			options[name] = value
		else:
			positional.append(text)
	if positional.size() < int(spec["positional_min"]) or positional.size() > int(spec["positional_max"]):
		return _bad_arguments("Usage: %s   Example: %s" % [spec["usage"], spec["example"]])
	return {"ok": true, "positional": positional, "options": options}


func _bad_arguments(message: String) -> Dictionary:
	return {"ok": false, "result": TerminalResult.failure(TerminalResult.Code.BAD_ARGUMENT, message)}


## The only place a command runs. The key was matched against the table above.
func _dispatch(key: String, positional: PackedStringArray, options: Dictionary) -> TerminalResult:
	match key:
		"help":
			return _help(positional)
		"clear":
			var cleared: TerminalResult = TerminalResult.new()
			cleared.clear_screen = true
			return cleared
		"history":
			return _show_history()
		"assets list":
			return _assets_list()
		"hosts show":
			return _hosts_show(positional[0])
		"logs search":
			return _logs_search(options)
	return TerminalResult.failure(TerminalResult.Code.UNKNOWN_COMMAND, "Unknown command.")


# --- handlers (read-only) ---------------------------------------------------

func _help(topic_words: PackedStringArray) -> TerminalResult:
	var result: TerminalResult = TerminalResult.new()
	if topic_words.is_empty():
		result.lines.append(TerminalCommands.BANNER)
		result.lines.append("Commands (type help <command> for details):")
		for key: String in TerminalCommands.command_keys():
			result.lines.append("  %s  %s" % [key.rpad(12), TerminalCommands.TABLE[key]["summary"]])
		return result
	var topic: String = " ".join(topic_words).to_lower()
	if not TerminalCommands.TABLE.has(topic):
		return TerminalResult.failure(TerminalResult.Code.NOT_FOUND, "No command called '%s'. Type help for the list." % _clip_word(topic))
	var spec: Dictionary = TerminalCommands.TABLE[topic]
	result.lines.append(spec["summary"])
	result.lines.append("Usage:   %s" % spec["usage"])
	result.lines.append("Example: %s" % spec["example"])
	return result


func _show_history() -> TerminalResult:
	var result: TerminalResult = TerminalResult.new()
	if history.is_empty():
		result.lines.append("Nothing run yet.")
	for index: int in history.size():
		result.lines.append("%3d  %s" % [index + 1, history[index]])
	return result


func _assets_list() -> TerminalResult:
	var result: TerminalResult = TerminalResult.new()
	result.lines.append("%s  %s  %s  %s" % ["ID".rpad(16), "KIND".rpad(18), "NAME".rpad(28), "OWNER"])
	for asset: Dictionary in _session.package.assets:
		result.lines.append("%s  %s  %s  %s" % [str(asset.get("id", "")).rpad(16), str(asset.get("kind", "")).rpad(18), str(asset.get("name", "")).rpad(28), str(asset.get("owner", ""))])
	result.lines.append("%d assets. Use: hosts show <host>" % _session.package.assets.size())
	return result


func _hosts_show(name: String) -> TerminalResult:
	if not _is_plain_word(name):
		return TerminalResult.failure(TerminalResult.Code.BAD_ARGUMENT, "That is not a host name. Hosts look like HOST-014; type assets list to see them.")
	var wanted: String = name.to_lower()
	for asset: Dictionary in _session.package.assets:
		if str(asset.get("name", "")).to_lower() != wanted and str(asset.get("id", "")).to_lower() != wanted:
			continue
		if str(asset.get("kind", "")) != "workstation":
			return TerminalResult.failure(TerminalResult.Code.BAD_ARGUMENT, "%s is a %s, not a host. hosts show works on workstations; assets list shows everything." % [asset.get("name", ""), str(asset.get("kind", "")).replace("_", " ")])
		var result: TerminalResult = TerminalResult.new()
		result.lines.append("%s  (workstation)" % asset.get("name", ""))
		result.lines.append("Owner: %s" % asset.get("owner", ""))
		result.lines.append("Notes: %s" % asset.get("notes", ""))
		var shown: int = 0
		result.lines.append("Recent events on this device:")
		for event: EventRecord in _session.store.all():
			if event.device.to_lower() == str(asset.get("name", "")).to_lower():
				result.lines.append("  %s  %s  %s  %s" % [event.display_id, EventRecord.clock_text(event.tick), event.actor, event.result])
				shown += 1
				if shown >= 5:
					break
		if shown == 0:
			result.lines.append("  (none)")
		return result
	return TerminalResult.failure(TerminalResult.Code.NOT_FOUND, "No host called '%s' in this scenario. Type assets list to see what exists." % _clip_word(name))


func _logs_search(options: Dictionary) -> TerminalResult:
	var query: ParsedQuery = ParsedQuery.new()
	query.limit = DEFAULT_SEARCH_LIMIT
	var tests: Array = []
	if options.has("source"):
		var source: String = String(options["source"]).to_lower()
		if not EventRecord.SOURCES.has(source):
			return _bad_option("source", "one of: %s" % ", ".join(PackedStringArray(EventRecord.SOURCES)))
		query.source = source
	if options.has("result"):
		var outcome: String = String(options["result"]).to_lower()
		if not EventRecord.RESULTS.has(outcome):
			return _bad_option("result", "one of: %s" % ", ".join(PackedStringArray(EventRecord.RESULTS)))
		tests.append(_compare("result", "=", outcome))
	for name: String in ["user", "ip", "device"]:
		if options.has(name):
			var value: String = options[name]
			if not _is_plain_word(value):
				return _bad_option(name, "letters, numbers and - _ . : only, up to %d characters" % MAX_WORD_CHARS)
			tests.append(_compare("source_ip" if name == "ip" else name, "=", value))
	if options.has("contains"):
		var text: String = options["contains"]
		if text.length() > MAX_SEARCH_TEXT_CHARS:
			return _bad_option("contains", "at most %d characters" % MAX_SEARCH_TEXT_CHARS)
		tests.append(_compare("detail", "contains", text))
	for name: String in ["after", "before"]:
		if options.has(name):
			var seconds: int = QueryParser.parse_time(options[name])
			if seconds < 0:
				return _bad_option(name, "a time such as 09:15")
			if name == "after":
				query.after_tick = seconds
			else:
				query.before_tick = seconds
	if query.after_tick >= 0 and query.before_tick >= 0 and query.before_tick <= query.after_tick:
		return _bad_option("before", "later than after")
	if options.has("limit"):
		var limit_text: String = options["limit"]
		if not limit_text.is_valid_int() or limit_text.length() > 3 or limit_text.begins_with("+") or limit_text.begins_with("-") or int(limit_text) < 1 or int(limit_text) > MAX_SEARCH_LIMIT:
			return _bad_option("limit", "a whole number from 1 to %d" % MAX_SEARCH_LIMIT)
		query.limit = int(limit_text)
	if not tests.is_empty():
		query.condition = tests[0] if tests.size() == 1 else {"op": "and", "items": tests}
	query.node_count = tests.size() + 1

	var found: QueryResult = QueryExecutor.execute(query, _session.store)
	var result: TerminalResult = TerminalResult.new()
	if not found.ok:
		return TerminalResult.failure(TerminalResult.Code.BAD_ARGUMENT, found.message)
	if found.rows.is_empty():
		result.lines.append("No events matched.")
		return result
	result.lines.append("%s  %s  %s  %s  %s  %s  %s" % ["EVENT".rpad(10), "TIME".rpad(5), "USER".rpad(11), "SOURCE".rpad(17), "DEVICE".rpad(16), "RESULT".rpad(9), "DETAIL"])
	for row: PackedStringArray in found.rows:
		result.lines.append("%s  %s  %s  %s  %s  %s  %s" % [row[0].rpad(10), row[1].rpad(5), row[2].rpad(11), row[3].rpad(17), row[4].rpad(16), row[5].rpad(9), row[6]])
	if found.truncated:
		result.lines.append("%d events matched; showing the first %d. Narrow the search or raise limit=." % [found.matched_count, found.rows.size()])
	else:
		result.lines.append("%d events matched." % found.matched_count)
	return result


# --- helpers ----------------------------------------------------------------

static func _compare(field: String, comparison: String, value: String) -> Dictionary:
	return {"op": "cmp", "field": field, "cmp": comparison, "value": value}


static func _bad_option(name: String, expectation: String) -> TerminalResult:
	return TerminalResult.failure(TerminalResult.Code.BAD_ARGUMENT, "%s= must be %s." % [name, expectation])


## Letters, digits and - _ . : only, 1 to MAX_WORD_CHARS long. Used for every
## id-like argument, so path separators and shell characters can never pass.
static func _is_plain_word(text: String) -> bool:
	if text.is_empty() or text.length() > MAX_WORD_CHARS:
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var allowed: bool = (code >= 0x61 and code <= 0x7A) or (code >= 0x41 and code <= 0x5A) or (code >= 0x30 and code <= 0x39) or code == 0x5F or code == 0x2D or code == 0x2E or code == 0x3A
		if not allowed:
			return false
	return true


func _remember(line: String) -> void:
	history.append(line)
	if history.size() > MAX_HISTORY:
		history.remove_at(0)


## Caps the number and length of printed lines so no command can flood the UI.
static func limit_output(result: TerminalResult) -> TerminalResult:
	var capped: PackedStringArray = PackedStringArray()
	for line: String in result.lines:
		if capped.size() >= MAX_OUTPUT_LINES:
			capped.append("(output cut off)")
			break
		capped.append(line if line.length() <= MAX_LINE_CHARS else line.left(MAX_LINE_CHARS - 3) + "...")
	result.lines = capped
	return result


static func _clip_word(text: String) -> String:
	return text if text.length() <= 24 else text.left(24) + "..."


func _closest_command(word: String) -> String:
	var best: String = ""
	var best_distance: int = SUGGESTION_DISTANCE + 1
	for key: String in TerminalCommands.TABLE:
		var head: String = key.get_slice(" ", 0)
		var distance: int = _edit_distance(word, head)
		if distance < best_distance:
			best_distance = distance
			best = key if not key.contains(" ") else head
	return best


static func _edit_distance(first: String, second: String) -> int:
	if first.length() > 32 or second.length() > 32:
		return 99
	var previous: Array[int] = []
	for column: int in second.length() + 1:
		previous.append(column)
	for row: int in first.length():
		var current: Array[int] = [row + 1]
		for column: int in second.length():
			var cost: int = 0 if first.unicode_at(row) == second.unicode_at(column) else 1
			current.append(mini(mini(current[column] + 1, previous[column + 1] + 1), previous[column] + cost))
		previous = current
	return previous[second.length()]
