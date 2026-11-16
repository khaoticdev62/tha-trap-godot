class_name TerminalTokenizer
extends RefCounted
## Splits one line of terminal input into tokens. There is no shell here: no
## pipes, chains, redirects, variables, globs, paths or escapes (other than \"
## and \\ inside quotes). Characters that mean something to a real shell are
## refused with an explanation. Quoted text is data and is never interpreted.

const MAX_LINE_CHARS: int = 256
const MAX_TOKENS: int = 24
const MAX_TOKEN_CHARS: int = 120

const SHELL_CHARACTERS: String = ";|&<>`$(){}[]*?~!#^%"


## Returns tokens as {text, quoted}; `quoted` is true only for a token that is
## entirely quoted text (key="text" is an option, not a quoted token). On a problem returns an empty array and
## appends the failure to `failure`.
static func tokenize(line: String, failure: Array[TerminalResult]) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	if line.length() > MAX_LINE_CHARS:
		failure.append(TerminalResult.failure(TerminalResult.Code.TOO_LONG, "That line is %d characters; the limit is %d." % [line.length(), MAX_LINE_CHARS]))
		return tokens
	var length: int = line.length()
	var index: int = 0
	while index < length:
		var code: int = line.unicode_at(index)
		if _is_forbidden(code):
			failure.append(TerminalResult.failure(TerminalResult.Code.BAD_CHARACTER, "Position %d has a control, zero-width or direction-override character. Type plain text." % (index + 1)))
			return []
		if code == 0x20 or code == 0x09:
			index += 1
			continue
		if tokens.size() >= MAX_TOKENS:
			failure.append(TerminalResult.failure(TerminalResult.Code.TOO_LONG, "That line has more than %d parts." % MAX_TOKENS))
			return []
		var token_text: String = ""
		var quoted: bool = false
		while index < length:
			code = line.unicode_at(index)
			if code == 0x20 or code == 0x09:
				break
			if _is_forbidden(code):
				failure.append(TerminalResult.failure(TerminalResult.Code.BAD_CHARACTER, "Position %d has a control, zero-width or direction-override character. Type plain text." % (index + 1)))
				return []
			if code == 0x22:
				# A quote opens text only at the start of a token or right after '='.
				if not token_text.is_empty() and not token_text.ends_with("="):
					failure.append(TerminalResult.failure(TerminalResult.Code.SHELL_SYNTAX, "Put a space before an opening quote, or write it as key=\"text\" (position %d)." % (index + 1)))
					return []
				var quoted_result: Dictionary = _read_quoted(line, index)
				if not quoted_result["ok"]:
					failure.append(TerminalResult.failure(quoted_result["code"], quoted_result["message"]))
					return []
				# Standalone quoted text is a "quoted" token; key="text" stays an option.
				quoted = token_text.is_empty()
				token_text += quoted_result["value"]
				index = quoted_result["next"]
				if index < length and line.unicode_at(index) != 0x20 and line.unicode_at(index) != 0x09:
					failure.append(TerminalResult.failure(TerminalResult.Code.SHELL_SYNTAX, "Put a space after the closing quote (position %d)." % (index + 1)))
					return []
				break
			if not _is_bare_character(code):
				failure.append(TerminalResult.failure(_problem_code(code), _explain(line, index)))
				return []
			token_text += String.chr(code)
			index += 1
		if token_text.length() > MAX_TOKEN_CHARS:
			failure.append(TerminalResult.failure(TerminalResult.Code.TOO_LONG, "One part of that line is longer than %d characters." % MAX_TOKEN_CHARS))
			return []
		tokens.append({"text": token_text, "quoted": quoted})
	return tokens


static func _read_quoted(line: String, start: int) -> Dictionary:
	var value: String = ""
	var index: int = start + 1
	while index < line.length():
		var code: int = line.unicode_at(index)
		if code == 0x22:
			return {"ok": true, "value": value, "next": index + 1}
		if _is_forbidden(code) or code == 0x09:
			return {"ok": false, "code": TerminalResult.Code.BAD_CHARACTER, "message": "Position %d has a control, zero-width or direction-override character. Type plain text." % (index + 1)}
		if code == 0x5C:
			var next_code: int = line.unicode_at(index + 1) if index + 1 < line.length() else 0
			if next_code == 0x22 or next_code == 0x5C:
				value += String.chr(next_code)
				index += 2
				continue
			return {"ok": false, "code": TerminalResult.Code.SHELL_SYNTAX, "message": "Inside quotes a backslash can only be followed by a quote or another backslash (position %d)." % (index + 1)}
		value += String.chr(code)
		index += 1
	return {"ok": false, "code": TerminalResult.Code.SHELL_SYNTAX, "message": "The quoted text starting at position %d never closes. Add the closing double quote." % (start + 1)}


## Letters, digits and _ - . = : , are the only characters allowed outside quotes.
static func _is_bare_character(code: int) -> bool:
	return (code >= 0x61 and code <= 0x7A) or (code >= 0x41 and code <= 0x5A) or (code >= 0x30 and code <= 0x39) \
		or code == 0x5F or code == 0x2D or code == 0x2E or code == 0x3D or code == 0x3A or code == 0x2C


static func _problem_code(code: int) -> TerminalResult.Code:
	return TerminalResult.Code.SHELL_SYNTAX if SHELL_CHARACTERS.contains(String.chr(code)) or code == 0x2F or code == 0x5C or code == 0x27 else TerminalResult.Code.BAD_CHARACTER


static func _explain(line: String, index: int) -> String:
	var shown: String = line.substr(index, 1)
	if SHELL_CHARACTERS.contains(shown):
		return "'%s' means something to a real shell, and this terminal has no shell: no pipes, chains, redirects, variables or wildcards (position %d). Type help to see what it can do." % [shown, index + 1]
	if shown == "/" or shown == "\\":
		return "This terminal has no files or folders, so paths are not used (position %d). Type assets list to see what exists here." % (index + 1)
	if shown == "'":
		return "Use double quotes for text, like \"this\" (position %d)." % (index + 1)
	return "'%s' is not allowed here (position %d). Use letters, numbers and - _ . : = , or put text in double quotes." % [shown, index + 1]


static func _is_forbidden(code: int) -> bool:
	if code < 0x20:
		return code != 0x09
	if code >= 0x7F and code <= 0x9F:
		return true
	if code >= 0x200B and code <= 0x200F:
		return true
	if code >= 0x202A and code <= 0x202E:
		return true
	if code >= 0x2066 and code <= 0x2069:
		return true
	return code == 0xFEFF
