class_name QueryParser
extends RefCounted
## Recursive-descent parser for the SIEM-style query language (decision D-009):
##
##   query   = FROM source [WHERE cond] [AFTER time] [BEFORE time]
##             [GROUP BY field] [COUNT] [SORT field [ASC|DESC]] [LIMIT n]
##   cond    = term {OR term};  term = factor {AND factor}
##   factor  = [NOT] ( field (= | != | CONTAINS) "text" | "(" cond ")" )
##
## Clauses must appear in that order. Keywords and field names ignore case, and
## so do comparisons. The parser only builds a ParsedQuery; nothing here
## evaluates text or touches data.

const MAX_NESTING: int = 8

var _tokens: Array[Dictionary] = []
var _position: int = 0
var _depth: int = 0
var _nodes: int = 0
var _failure: QueryResult = null


## Returns the ParsedQuery, or null with the problem in `failure`[0].
static func parse(tokens: Array[Dictionary], failure: Array[QueryResult]) -> ParsedQuery:
	var parser: QueryParser = QueryParser.new()
	parser._tokens = tokens
	var query: ParsedQuery = parser._parse_query()
	if parser._failure != null:
		failure.append(parser._failure)
		return null
	return query


## Time text as "H:MM", "HH:MM", "HH:MM:SS", or an ISO-style stamp such as
## "2026-10-04T09:00:00" (the date part is checked for shape and ignored: a lab
## covers a single day). Returns seconds since midnight, or -1 if invalid.
static func parse_time(text: String) -> int:
	var clock: String = text
	if text.contains("T"):
		var halves: PackedStringArray = text.split("T")
		if halves.size() != 2 or not _is_date(halves[0]):
			return -1
		clock = halves[1]
	var parts: PackedStringArray = clock.split(":")
	if parts.size() < 2 or parts.size() > 3:
		return -1
	for part: String in parts:
		if part.is_empty() or part.length() > 2 or not _all_digits(part):
			return -1
	var hours: int = int(parts[0])
	var minutes: int = int(parts[1])
	var seconds: int = int(parts[2]) if parts.size() == 3 else 0
	if hours > 23 or minutes > 59 or seconds > 59 or parts[1].length() != 2 or (parts.size() == 3 and parts[2].length() != 2):
		return -1
	return hours * 3600 + minutes * 60 + seconds


static func _is_date(text: String) -> bool:
	var parts: PackedStringArray = text.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part: String in parts:
		if not _all_digits(part):
			return false
	return int(parts[1]) >= 1 and int(parts[1]) <= 12 and int(parts[2]) >= 1 and int(parts[2]) <= 31


static func _all_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x30 or code > 0x39:
			return false
	return true


func _parse_query() -> ParsedQuery:
	var query: ParsedQuery = ParsedQuery.new()
	if not _accept_word("from"):
		_fail(QueryResult.Code.SYNTAX, "A query starts with FROM and a source, for example: FROM auth_events. Sources: %s." % ", ".join(PackedStringArray(ParsedQuery.SOURCES.keys())))
		return null
	var source_token: Dictionary = _current()
	var source_text: String = source_token["text"].to_lower() if source_token["type"] == QueryTokenizer.WORD else ""
	if not ParsedQuery.SOURCES.has(source_text):
		_fail(QueryResult.Code.UNKNOWN_SOURCE, "Unknown source %s. Choose one of: %s." % [_describe(source_token), ", ".join(PackedStringArray(ParsedQuery.SOURCES.keys()))])
		return null
	query.source_name = source_text
	query.source = ParsedQuery.SOURCES[source_text]
	_position += 1

	if _accept_word("where"):
		query.condition = _parse_or()
		if _failure != null:
			return null
	if _accept_word("after"):
		query.after_tick = _parse_time_value("AFTER")
		if _failure != null:
			return null
	if _accept_word("before"):
		query.before_tick = _parse_time_value("BEFORE")
		if _failure != null:
			return null
	if query.after_tick >= 0 and query.before_tick >= 0 and query.before_tick <= query.after_tick:
		_fail(QueryResult.Code.BAD_TIME, "BEFORE must be later than AFTER.")
		return null
	if _accept_word("group"):
		if not _accept_word("by"):
			_fail(QueryResult.Code.SYNTAX, "GROUP must be followed by BY and a field, for example: GROUP BY source_ip.")
			return null
		query.group_by = _parse_field()
		if _failure != null:
			return null
	if _accept_word("count"):
		query.count_only = true
	if _accept_word("sort"):
		_parse_sort(query)
		if _failure != null:
			return null
	if _accept_word("limit"):
		query.limit = _parse_limit()
		if _failure != null:
			return null
	if _current()["type"] != QueryTokenizer.END:
		_fail(QueryResult.Code.SYNTAX, "Unexpected %s. Clauses go in this order: WHERE, AFTER, BEFORE, GROUP BY, COUNT, SORT, LIMIT." % _describe(_current()))
		return null
	query.node_count = _nodes
	return query


func _parse_or() -> Dictionary:
	var items: Array = [_parse_and()]
	while _failure == null and _accept_word("or"):
		items.append(_parse_and())
	if _failure != null:
		return {}
	_nodes += 1
	return items[0] if items.size() == 1 else {"op": "or", "items": items}


func _parse_and() -> Dictionary:
	var items: Array = [_parse_factor()]
	while _failure == null and _accept_word("and"):
		items.append(_parse_factor())
	if _failure != null:
		return {}
	_nodes += 1
	return items[0] if items.size() == 1 else {"op": "and", "items": items}


func _parse_factor() -> Dictionary:
	if _failure != null:
		return {}
	if not _enter():
		return {}
	var node: Dictionary = {}
	if _accept_word("not"):
		var inner: Dictionary = _parse_factor()
		node = {"op": "not", "item": inner}
	elif _current()["type"] == QueryTokenizer.LEFT_PAREN:
		_position += 1
		node = _parse_or()
		if _failure == null:
			if _current()["type"] != QueryTokenizer.RIGHT_PAREN:
				_fail(QueryResult.Code.SYNTAX, "A '(' was opened but not closed. Add a ')' after the condition.")
			else:
				_position += 1
	else:
		node = _parse_comparison()
	_depth -= 1
	_nodes += 1
	return {} if _failure != null else node


func _parse_comparison() -> Dictionary:
	var field: String = _parse_field()
	if _failure != null:
		return {}
	var operator_token: Dictionary = _current()
	var comparison: String = ""
	if operator_token["type"] == QueryTokenizer.OPERATOR:
		comparison = operator_token["text"]
	elif operator_token["type"] == QueryTokenizer.WORD and operator_token["text"].to_lower() == "contains":
		comparison = "contains"
	else:
		_fail(QueryResult.Code.SYNTAX, "After the field '%s' use =, != or CONTAINS (found %s)." % [field, _describe(operator_token)])
		return {}
	_position += 1
	var value_token: Dictionary = _current()
	if value_token["type"] != QueryTokenizer.STRING:
		_fail(QueryResult.Code.SYNTAX, "Put the text to match in double quotes, for example: %s %s \"value\" (found %s)." % [field, comparison.to_upper(), _describe(value_token)])
		return {}
	_position += 1
	return {"op": "cmp", "field": field, "cmp": comparison, "value": value_token["text"]}


func _parse_field() -> String:
	var token: Dictionary = _current()
	var name: String = token["text"].to_lower() if token["type"] == QueryTokenizer.WORD else ""
	if not ParsedQuery.FIELDS.has(name):
		_fail(QueryResult.Code.UNKNOWN_FIELD, "Unknown field %s. Fields you can use: %s." % [_describe(token), ", ".join(PackedStringArray(ParsedQuery.FIELDS))])
		return ""
	_position += 1
	return name


func _parse_time_value(keyword: String) -> int:
	var token: Dictionary = _current()
	var seconds: int = -1
	if token["type"] == QueryTokenizer.STRING:
		seconds = parse_time(token["text"])
	if seconds < 0:
		_fail(QueryResult.Code.BAD_TIME, "%s needs a time in double quotes, like %s \"09:15\" or %s \"2026-10-04T09:15:00\" (found %s)." % [keyword, keyword, keyword, _describe(token)])
		return -1
	_position += 1
	return seconds


func _parse_sort(query: ParsedQuery) -> void:
	var allowed: PackedStringArray = PackedStringArray()
	if not query.group_by.is_empty():
		allowed = PackedStringArray([query.group_by, "count"])
	elif query.count_only:
		allowed = PackedStringArray(["count"])
	else:
		allowed = PackedStringArray(ParsedQuery.FIELDS)
	var token: Dictionary = _current()
	var name: String = token["text"].to_lower() if token["type"] == QueryTokenizer.WORD else ""
	if not allowed.has(name):
		_fail(QueryResult.Code.UNKNOWN_FIELD, "You can SORT by: %s (found %s)." % [", ".join(allowed), _describe(token)])
		return
	query.sort_field = name
	_position += 1
	if _accept_word("desc"):
		query.sort_descending = true
	else:
		_accept_word("asc")


func _parse_limit() -> int:
	var token: Dictionary = _current()
	if token["type"] != QueryTokenizer.NUMBER:
		_fail(QueryResult.Code.BAD_LIMIT, "LIMIT needs a whole number from 1 to %d (found %s)." % [ParsedQuery.MAX_LIMIT, _describe(token)])
		return 0
	var value: int = int(token["text"])
	if value < 1 or value > ParsedQuery.MAX_LIMIT:
		_fail(QueryResult.Code.BAD_LIMIT, "LIMIT must be from 1 to %d (found %d)." % [ParsedQuery.MAX_LIMIT, value])
		return 0
	_position += 1
	return value


func _enter() -> bool:
	_depth += 1
	if _depth > MAX_NESTING:
		_fail(QueryResult.Code.TOO_DEEP, "That condition is nested too deeply (limit %d levels of NOT and parentheses)." % MAX_NESTING)
		return false
	return true


func _current() -> Dictionary:
	return _tokens[mini(_position, _tokens.size() - 1)]


func _accept_word(keyword: String) -> bool:
	var token: Dictionary = _current()
	if token["type"] == QueryTokenizer.WORD and token["text"].to_lower() == keyword:
		_position += 1
		return true
	return false


func _fail(code: QueryResult.Code, message: String) -> void:
	if _failure == null:
		_failure = QueryResult.failure(code, message)


## Short, safe description of a token for error messages.
func _describe(token: Dictionary) -> String:
	if token["type"] == QueryTokenizer.END:
		return "the end of the query"
	var text: String = token["text"]
	if text.length() > 24:
		text = text.left(24) + "..."
	return "'%s'" % text
