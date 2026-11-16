class_name SimText
extends RefCounted
## Checks for free text the player types into the case (notes, entries). Text is
## plain: no control characters (so no newlines), no zero-width or
## direction-override characters. Everything else, including emoji and RTL
## scripts, is allowed and is only ever displayed as text.


static func has_forbidden(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x20 or (code >= 0x7F and code <= 0x9F):
			return true
		if (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069) or code == 0xFEFF:
			return true
	return false


## Trims the ends and collapses runs of spaces into one.
static func tidy(text: String) -> String:
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	return " ".join(parts)
