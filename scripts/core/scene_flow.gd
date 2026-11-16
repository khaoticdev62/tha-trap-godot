class_name SceneFlow
extends Node
## Scene transitions (autoload "Scenes").
## Callers pass a registered id, never a path, so a bad id cannot load an
## arbitrary resource.

signal scene_requested(scene_id: StringName)
signal scene_changed(scene_id: StringName)

const SCENES: Dictionary = {
	&"boot": "res://scenes/boot/boot.tscn",
	&"title": "res://scenes/menus/title.tscn",
	&"settings": "res://scenes/menus/settings.tscn",
	&"creator": "res://scenes/menus/character_creator.tscn",
	&"save_slots": "res://scenes/menus/save_slots.tscn",
	&"soc": "res://scenes/soc/soc_shell.tscn",
}

var current_id: StringName = &""


static func path_for(scene_id: StringName) -> String:
	return SCENES.get(scene_id, "")


func go_to(scene_id: StringName) -> Error:
	var path: String = path_for(scene_id)
	if path.is_empty():
		push_error("SceneFlow: unknown scene id '%s'." % scene_id)
		return ERR_DOES_NOT_EXIST
	scene_requested.emit(scene_id)
	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		return result
	current_id = scene_id
	scene_changed.emit(scene_id)
	return OK
