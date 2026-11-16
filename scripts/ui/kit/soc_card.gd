class_name SocCard
extends PanelContainer
## A titled panel: a heading and a body column. Add content to `body`.
##   var card: SocCard = SocCard.create("Alert counters")
##   card.body.add_child(...)

var title_label: Label
var body: VBoxContainer


static func create(title: String, variation: StringName = &"", expand: bool = false) -> SocCard:
	var card: SocCard = SocCard.new()
	if variation != &"":
		card.theme_type_variation = variation
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if expand:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SocTokens.SPACE_S)
	card.add_child(column)
	if not title.is_empty():
		card.title_label = Label.new()
		card.title_label.text = title
		card.title_label.theme_type_variation = &"SocHeading"
		card.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(card.title_label)
	card.body = VBoxContainer.new()
	card.body.add_theme_constant_override("separation", SocTokens.SPACE_S)
	card.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card.body)
	return card


## Removes everything from the body so it can be rebuilt.
func clear_body() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
