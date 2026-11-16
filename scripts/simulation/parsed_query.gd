class_name ParsedQuery
extends RefCounted
## A validated query, ready to run. Produced only by QueryParser.

## Search sources as players type them, and the event source each maps to.
const SOURCES: Dictionary = {
	"auth_events": "auth",
	"mfa_events": "mfa",
	"app_events": "app",
	"helpdesk_tickets": "helpdesk",
}

## Fields a query may use, in display order. See QueryExecutor.field_value.
const FIELDS: Array[String] = ["event_id", "time", "user", "source_ip", "device", "result", "detail", "tags"]

const DEFAULT_LIMIT: int = 100
const MAX_LIMIT: int = 500

var source_name: String = ""
var source: String = ""
## Condition tree, or empty for "no WHERE".
## Nodes: {"op":"or"|"and","items":[..]}, {"op":"not","item":node},
## {"op":"cmp","field":f,"cmp":"="|"!="|"contains","value":text}
var condition: Dictionary = {}
## Inclusive lower and exclusive upper time bound in seconds; -1 = none.
var after_tick: int = -1
var before_tick: int = -1
var group_by: String = ""
var count_only: bool = false
var sort_field: String = ""
var sort_descending: bool = false
var limit: int = DEFAULT_LIMIT
var node_count: int = 0
