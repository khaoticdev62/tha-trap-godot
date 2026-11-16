extends Node
## Visual capture tool: renders each screen in a real (windowed) Godot run and
## saves PNGs, because headless runs draw nothing. Developer tool only.
##   godot --path . res://tools/visual/capture.tscn -- --out=<dir>
## Uses throwaway save/settings paths; the player's real data is never touched.
## Cases cover the 1280x800 base, Steam Deck 1280x720, 200% text and high contrast.

const SIZES: Dictionary = {"800": Vector2i(1280, 800), "720": Vector2i(1280, 720)}
const SETTLE_FRAMES: int = 6

var _out_dir: String = ""


func _ready() -> void:
	var tree: SceneTree = get_tree()
	tree.current_scene = null
	# Scenes must sit directly under the root Window, as in the real game: a plain
	# Node in between would break theme inheritance and the shots would be unthemed.
	await tree.process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		print("capture: pass --out=<directory>")
		tree.quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var root: Window = tree.root
	var settings: SettingsService = root.get_node("Settings")
	var saves: SaveService = root.get_node("Saves")
	var temp_tag: int = Time.get_ticks_usec()
	settings.settings_path = "user://capture_settings_%d.json" % temp_tag
	saves.save_dir = "user://capture_saves_%d" % temp_tag
	AppBootstrap.run(tree)

	# name, scene id, window key, text scale, high contrast
	var cases: Array = [
		["title_800", &"title", "800", 1.0, false],
		["title_720", &"title", "720", 1.0, false],
		["title_scale200", &"title", "800", 2.0, false],
		["title_contrast", &"title", "800", 1.0, true],
		["settings_800", &"settings", "800", 1.0, false],
		["settings_720", &"settings", "720", 1.0, false],
		["settings_scale200", &"settings", "720", 2.0, false],
		["settings_contrast", &"settings", "800", 1.0, true],
		["creator_800", &"creator", "800", 1.0, false],
		["creator_720", &"creator", "720", 1.0, false],
		["creator_scale200", &"creator", "720", 2.0, false],
		["creator_contrast", &"creator", "800", 1.0, true],
	]
	for entry: Array in cases:
		await _capture_scene(entry[0], entry[1], entry[2], entry[3], entry[4], settings)

	await _capture_modal(settings)
	await _capture_dialogue(settings, "dialogue_800", false)
	await _capture_dialogue(settings, "dialogue_choices", true)

	if FileAccess.file_exists(settings.settings_path):
		DirAccess.remove_absolute(settings.settings_path)
	print("capture: done -> %s" % _out_dir)
	tree.quit(0)


func _apply(settings: SettingsService, size_key: String, scale: float, contrast: bool) -> void:
	settings.update(scale, false, contrast, "normal")
	get_window().size = SIZES[size_key]


func _settle() -> void:
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save_png(file_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name + ".png")
	var error: Error = image.save_png(path)
	print("capture: %s %dx%d %s" % [file_name, image.get_width(), image.get_height(), "ok" if error == OK else "FAILED"])


func _capture_scene(file_name: String, scene_id: StringName, size_key: String, scale: float, contrast: bool, settings: SettingsService) -> void:
	_apply(settings, size_key, scale, contrast)
	var scene: Node = load(SceneFlow.path_for(scene_id)).instantiate()
	get_tree().root.add_child(scene)
	await _settle()
	_save_png(file_name)
	scene.queue_free()
	await get_tree().process_frame


func _capture_modal(settings: SettingsService) -> void:
	_apply(settings, "800", 1.0, false)
	var title: Node = load(SceneFlow.path_for(&"title")).instantiate()
	get_tree().root.add_child(title)
	await get_tree().process_frame
	ModalDialog.open(title, "Start over?", "Creating a new character replaces your saved progress.", "Replace save and start new", "Keep my save")
	await _settle()
	_save_png("modal_800")
	title.queue_free()
	await get_tree().process_frame


func _capture_dialogue(settings: SettingsService, file_name: String, with_choices: bool) -> void:
	_apply(settings, "800", 1.0, false)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Palette.OBSIDIAN
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(backdrop)
	var box: DialogueBox = DialogueBox.new()
	box.settings = AccessibilitySettings.new()
	box.settings.text_speed = "instant"
	backdrop.add_child(box)
	await get_tree().process_frame
	var choices: Array[String] = []
	if with_choices:
		choices = ["Gather the evidence first.", "Contain the account now."]
	box.show_line("Sample speaker", "This is a sample line used only to check how the dialogue panel looks.", choices)
	await _settle()
	_save_png(file_name)
	backdrop.queue_free()
	await get_tree().process_frame
