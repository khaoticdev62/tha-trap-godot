class_name QueryTokenizer
extends RefCounted
## Splits query text into tokens. Hand written and deliberately small: words,
## numbers, double-quoted strings, `=`, `!=` and parentheses. Anything else is
## rejected with a message, never interpreted.

const MAX_QUERY_CHARS: int = 512
const MAX_TOKENS: int = 128
const MAX_NUMBER_DIGITS: int = 9

const WORD: String = "word"
const STRING: String = "string"
const NUMBER: String = "number"
const OPERATOR: String = "op"
const LEFT_PAREN: String = "lparen"
const RIGHT_PAREN: String = "rparen"
const END: String = "end"


## Returns the tokens (always ending with an END token) or, on a problem, an
## empty array and the failure in `failure`[0].
static func tokenize(text: String, failure: Array[QueryResult]) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	if text.length() > MAX_QUERY_CHARS:
		failure.append(QueryResult.failure(QueryResult.Code.TOO_LONG, "That query is %d characters; the limit is %d." % [text.length(), MAX_QUERY_CHARS]))
		return tokens
	var length: int = text.length()
	var index: int = 0
	while index < length:
		var code: int = text.unicode_at(index)
		if _is_forbidden(code):
			failure.append(QueryResult.failure(QueryResult.Code.BAD_CHARACTER, "Position %d has a control, zero-width or direction-override character. Queries are plain text." % (index + 1)))
			return []
		if code == 0x20 or code == 0x09 or code == 0x0A or code == 0x0D:
			index += 1
			continue
		if tokens.size() >= MAX_TOKENS:
			failure.append(QueryResult.failure(QueryResult.Code.TOO_LONG, "That query has more than %d parts. Try a shorter one." % MAX_TOKENS))
			return []
		var start: int = index
		if code == 0x22:  # "
			var parsed: Dictionary = _read_string(text, index)
			if not parsed["ok"]:
				failure.append(QueryResult.failure(parsed["code"], parsed["message"]))
				return []
			tokens.append(_token(STRING, parsed["value"], start))
			index = parsed["next"]
		elif _is_digit(code):
			while index < length and _is_digit(text.unicode_at(index)):
				index += 1
			if index - start > MAX_NUMBER_DIGITS:
				failure.append(QueryResult.failure(QueryResult.Code.SYNTAX, "The number at position %d is too long." % (start + 1)))
				return []
			tokens.append(_token(NUMBER, text.substr(start, index - start), start))
		elif _is_word_start(code):
			while index < length and _is_word_part(text.unicode_at(index)):
				index += 1
			tokens.append(_token(WORD, text.substr(start, index - start), start))
		elif code == 0x3D:  # =
			tokens.append(_token(OPERATOR, "=", start))
			index += 1
		elif code == 0x21 and index + 1 < length and text.unicode_at(index + 1) == 0x3D:  # !=
			tokens.append(_token(OPERATOR, "!=", start))
			index += 2
		elif code == 0x28:
			tokens.append(_token(LEFT_PAREN, "(", start))
			index += 1
		elif code == 0x29:
			tokens.append(_token(RIGHT_PAREN, ")", start))
			index += 1
		else:
			failure.append(QueryResult.failure(QueryResult.Code.SYNTAX, _unexpected_character(text, index)))
			return []
	tokens.append(_token(END, "", length))
	return tokens


static func _token(type: String, text: String, position: int) -> Dictionary:
	return {"type": type, "text": text, "pos": position}


static func _read_string(text: String, start: int) -> Dictionary:
	var value: String = ""
	var index: int = start + 1
	while index < text.length():
		var code: int = text.unicode_at(index)
		if code == 0x22:
			return {"ok": true, "value": value, "next": index + 1}
		if _is_forbidden(code) or code == 0x0A or code == 0x0D or code == 0x09:
			return {"ok": false, "code": QueryResult.Code.BAD_CHARACTER, "message": "Position %d has a control, zero-width or direction-override character. Queries are plain text." % (index + 1)}
		if code == 0x5C:  # backslash: only \" and \\ are understood
			if index + 1 < text.length() and (text.unicode_at(index + 1) == 0x22 or text.unicode_at(index + 1) == 0x5C):
				value += String.chr(text.unicode_at(index + 1))
				index += 2
				continue
			return {"ok": false, "code": QueryResult.Code.SYNTAX, "message": "In text, a backslash can only be followed by a quote or another backslash (position %d)." % (index + 1)}
		value += String.chr(code)
		index += 1
	return {"ok": false, "code": QueryResult.Code.SYNTAX, "message": "The text starting at position %d never closes. Add the closing double quote." % (start + 1)}


static func _unexpected_character(text: String, index: int) -> String:
	var shown: String = text.substr(index, 1)
	match shown:
		"<", ">":
			return "'%s' is not available. To filter by time use AFTER \"09:00\" or BEFORE \"09:30\"." % shown
		"*":
			return "There is no SELECT or * here (position %d). A query starts with FROM and a source, for example: FROM auth_events." % (index + 1)
		".", "-", "@", "/", ":":
			return "Text such as a user or address needs double quotes, for example \"j.smith\" (position %d)." % (index + 1)
		"'":
			return "Text must use double quotes (\"like this\"), not single quotes (position %d)." % (index + 1)
		";", "|", "&", "`", "$":
			return "'%s' is not part of this search language (position %d). It has no pipes, chains or commands; use FROM, WHERE, AFTER, BEFORE, GROUP BY, COUNT, SORT and LIMIT." % [shown, index + 1]
	return "Unexpected character '%s' at position %d." % [shown, index + 1]


static func _is_digit(code: int) -> bool:
	return code >= 0x30 and code <= 0x39


static func _is_word_start(code: int) -> bool:
	return (code >= 0x61 and code <= 0x7A) or (code >= 0x41 and code <= 0x5A) or code == 0x5F


static func _is_word_part(code: int) -> bool:
	return _is_word_start(code) or _is_digit(code)


static func _is_forbidden(code: int) -> bool:
	if code < 0x20:
		return not (code == 0x09 or code == 0x0A or code == 0x0D)
	if code >= 0x7F and code <= 0x9F:
		return true
	if code >= 0x200B and code <= 0x200F:
		return true
	if code >= 0x202A and code <= 0x202E:
		return true
	if code >= 0x2066 and code <= 0x2069:
		return true
	return code == 0xFEFF
