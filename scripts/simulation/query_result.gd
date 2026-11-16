class_name QueryResult
extends RefCounted
## Outcome of one SIEM-style query. Never throws: bad input yields `ok == false`
## with a code and a message written to teach (it names what was expected).

enum Code {
	OK,
	EMPTY_QUERY,
	TOO_LONG,
	BAD_CHARACTER,
	SYNTAX,
	UNKNOWN_SOURCE,
	UNKNOWN_FIELD,
	BAD_TIME,
	BAD_LIMIT,
	TOO_DEEP,
	TOO_EXPENSIVE,
}

var ok: bool = true
var code: Code = Code.OK
var message: String = ""
var columns: PackedStringArray = PackedStringArray()
## One PackedStringArray per row, aligned with `columns`.
var rows: Array[PackedStringArray] = []
## For each row, the ids of the events behind it (one for a raw row, every
## member for a grouped row), so results can be added to the case as evidence.
var row_event_ids: Array[PackedStringArray] = []
## Rows found before LIMIT was applied.
var matched_count: int = 0
var truncated: bool = false


static func failure(failure_code: Code, failure_message: String) -> QueryResult:
	var result: QueryResult = QueryResult.new()
	result.ok = false
	result.code = failure_code
	result.message = failure_message
	return result
