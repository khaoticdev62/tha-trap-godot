class_name PageBackground
extends ColorRect
## Full-screen page background that follows the active colour scheme (standard
## or high contrast) and updates live when the player changes it in Settings.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var service: Node = get_node_or_null("/root/Settings")
	if service != null and "current" in service:
		color = UiTheme.background_color(service.current)
		service.changed.connect(_on_settings_changed)
	else:
		color = Palette.OBSIDIAN


func _on_settings_changed(settings: AccessibilitySettings) -> void:
	color = UiTheme.background_color(settings)
