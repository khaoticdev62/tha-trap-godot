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
	_make_sample_saves(saves)

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
		["slots_load_800", &"save_slots", "800", 1.0, false],
		["slots_load_720", &"save_slots", "720", 1.0, false],
		["slots_load_scale200", &"save_slots", "720", 2.0, false],
		["slots_load_contrast", &"save_slots", "800", 1.0, true],
		["slots_new_800", &"save_slots", "800", 1.0, false],
	]
	for entry: Array in cases:
		await _capture_scene(entry[0], entry[1], entry[2], entry[3], entry[4], settings)

	await _capture_soc_screens(settings)
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
	get_tree().root.get_node("Progress").slot_screen_mode = "new" if file_name.contains("_new") else "load"
	var scene: Node = load(SceneFlow.path_for(scene_id)).instantiate()
	get_tree().root.add_child(scene)
	await _settle()
	_save_png(file_name)
	scene.queue_free()
	await get_tree().process_frame


## SOC screens over a case with some work done, so tables and panels are populated.
## name, screen id, window key, text scale, high contrast
const SOC_CASES: Array = [
	["soc_design_800", &"design_system", "800", 1.0, false],
	["soc_design_720", &"design_system", "720", 1.0, false],
	["soc_dashboard_800", &"command_center", "800", 1.0, false],
	["soc_dashboard_720", &"command_center", "720", 1.0, false],
	["soc_dashboard_scale200", &"command_center", "800", 2.0, false],
	["soc_dashboard_contrast", &"command_center", "800", 1.0, true],
	["soc_investigation_800", &"investigation", "800", 1.0, false],
	["soc_investigation_720", &"investigation", "720", 1.0, false],
	["soc_investigation_scale200", &"investigation", "800", 2.0, false],
	["soc_cases_800", &"cases", "800", 1.0, false],
	["soc_cases_720", &"cases", "720", 1.0, false],
	["soc_cases_contrast", &"cases", "800", 1.0, true],
	["soc_terminal_800", &"terminal", "800", 1.0, false],
	["soc_terminal_720", &"terminal", "720", 1.0, false],
	["soc_mission_800", &"mission", "800", 1.0, false],
	["soc_mission_720", &"mission", "720", 1.0, false],
	["soc_mission_scale200", &"mission", "800", 2.0, false],
]


func _capture_soc_screens(settings: SettingsService) -> void:
	var progress: ProgressService = get_tree().root.get_node("Progress")
	for entry: Array in SOC_CASES:
		_apply(settings, entry[2], entry[3], entry[4])
		progress.reset()
		var shell: SocShell = load(SceneFlow.path_for(&"soc")).instantiate()
		get_tree().root.add_child(shell)
		await get_tree().process_frame
		_populate_soc_case(shell.model)
		shell.show_screen(entry[1])
		if entry[1] == &"terminal":
			var terminal: Control = shell.screen_node(&"terminal")
			for line: String in ["help", "logs search source=auth user=j.smith after=09:00", "hosts show HOST-014", "rm -rf /"]:
				terminal.run_line(line)
		if entry[1] == &"investigation":
			var table: Tree = shell.screen_node(&"investigation")._table
			for item: TreeItem in table.get_root().get_children():
				if item.get_text(1).begins_with("EVT-004"):
					item.select(0)
		await _settle()
		_save_png(entry[0])
		shell.queue_free()
		await get_tree().process_frame


func _populate_soc_case(model: SocModel) -> void:
	for event_id: String in ["evt_001", "evt_002", "evt_003", "evt_004", "evt_005"]:
		model.collect_evidence(event_id)
	model.add_note("fact", "Two failed sign-ins were followed by a success from an outside source.", PackedStringArray(["ev_001", "ev_003"]))
	model.add_note("hypothesis", "The password may have been guessed or reused.")
	model.set_severity("high")
	model.toggle_scope("host_014")
	model.toggle_scope("member_portal")
	model.apply_response("escalate", "soc_lead")
	model.apply_response("contain", "verify_then_protect")
	model.request_hint()


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


## One healthy slot (with a completed mission), one empty, one damaged, so the
## title and slot screens show every state.
func _make_sample_saves(saves: SaveService) -> void:
	var root: Window = get_tree().root
	var game: SaveGame = SaveGame.from_tree(get_tree())
	game.fixed_unix_time = 100
	game.start_new(0, "Kai Lee", "they/them", "tone_tan", "hair_locs", "outfit_copper")
	root.get_node("Profiles").current.playtime_seconds = 3900.0
	var progress: ProgressService = root.get_node("Progress")
	var content: LabContent = LabContent.load_lab(ContentLoader.new(ContentCatalog.build_registry()), "lab_001")
	progress.begin_lab("mission_lab_001", content)
	var done: AssessmentResult = AssessmentResult.new()
	done.total = 92
	done.passed = true
	done.rubric_version = "1.0.0"
	progress.finish_lab(done)
	game.save(0)
	saves.save_slot(2, {"profile": {}, "progress": {"version": 1, "difficulty": "nightmare"}, "meta": {}})
