class_name SaveResult
extends RefCounted
## Outcome of a save or load operation. Never throws; callers branch on `ok`.

enum Code {
	OK,
	INVALID_SLOT,
	NOT_FOUND,
	CORRUPT,
	TOO_NEW,
	MIGRATION_FAILED,
	TOO_LARGE,
	IO_ERROR,
}

var ok: bool = false
var code: Code = Code.IO_ERROR
var message: String = ""
var payload: Dictionary = {}
## True when the primary file was unusable and a backup was loaded instead.
var recovered_from_backup: bool = false


static func success(data: Dictionary, recovered: bool = false) -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.ok = true
	result.code = Code.OK
	result.payload = data
	result.recovered_from_backup = recovered
	return result


static func failure(failure_code: Code, failure_message: String) -> SaveResult:
	var result: SaveResult = SaveResult.new()
	result.ok = false
	result.code = failure_code
	result.message = failure_message
	return result
