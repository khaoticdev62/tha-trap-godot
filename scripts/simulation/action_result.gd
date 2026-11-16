class_name ActionResult
extends RefCounted
## Outcome of a change the player asked for (collect evidence, add a case
## entry, ...). Never throws; failures carry a message that says how to fix it.

var ok: bool = true
## Id of the thing created or found (for example "ev_001").
var id: String = ""
var message: String = ""
## False when the request was valid but nothing needed to change.
var changed: bool = true


static func success(item_id: String = "", note: String = "") -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.id = item_id
	result.message = note
	return result


static func unchanged(item_id: String, note: String) -> ActionResult:
	var result: ActionResult = ActionResult.success(item_id, note)
	result.changed = false
	return result


static func failure(reason: String) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.ok = false
	result.changed = false
	result.message = reason
	return result
