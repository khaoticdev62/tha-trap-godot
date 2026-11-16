class_name QueryEngine
extends RefCounted
## Front door for SIEM-style searches: text in, QueryResult out. It never
## throws and never reads anything but the EventStore it is given.


static func run(text: String, store: EventStore) -> QueryResult:
	if text.strip_edges().is_empty():
		return QueryResult.failure(QueryResult.Code.EMPTY_QUERY, "Type a search, for example: FROM auth_events WHERE result = \"failure\"")
	var failure: Array[QueryResult] = []
	var tokens: Array[Dictionary] = QueryTokenizer.tokenize(text, failure)
	if not failure.is_empty():
		return failure[0]
	var query: ParsedQuery = QueryParser.parse(tokens, failure)
	if query == null:
		return failure[0]
	return QueryExecutor.execute(query, store)
