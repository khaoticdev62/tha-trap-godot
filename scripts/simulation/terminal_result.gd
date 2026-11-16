class_name TerminalResult
extends RefCounted
## What the simulated terminal prints for one line of input. Never throws.
## Failures are written to teach: they say what the terminal can do instead.

enum Code {
	OK,
	TOO_LONG,
	BAD_CHARACTER,
	SHELL_SYNTAX,
	HOST_COMMAND,
	UNKNOWN_COMMAND,
	BAD_ARGUMENT,
	NOT_FOUND,
}

var ok: bool = true
var code: Code = Code.OK
var lines: PackedStringArray = PackedStringArray()
## The command that ran, such as "logs search"; empty if none was recognised.
var command: String = ""
## True when the screen should be cleared (the `clear` command).
var clear_screen: bool = false


static func failure(failure_code: Code, message: String) -> TerminalResult:
	var result: TerminalResult = TerminalResult.new()
	result.ok = false
	result.code = failure_code
	result.lines = PackedStringArray([message])
	return result
