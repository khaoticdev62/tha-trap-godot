extends TestCase


func test_every_gameplay_action_has_keyboard_and_controller_bindings() -> void:
	InputActions.register()
	for action: StringName in InputActions.action_names():
		check(InputMap.has_action(action), "%s registered" % action)
		var has_key: bool = false
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				has_key = true
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		check(has_key, "%s has a keyboard binding" % action)
		check(has_pad, "%s has a controller binding (controller-only play)" % action)


func test_register_is_idempotent() -> void:
	InputActions.register()
	var first: int = InputMap.action_get_events(&"interact").size()
	InputActions.register()
	check_eq(InputMap.action_get_events(&"interact").size(), first, "no duplicate events on re-register")


func test_builtin_ui_actions_have_controller_bindings() -> void:
	InputActions.register()
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		check(has_pad, "%s works on a controller" % action)


func test_scene_registry_only_points_at_existing_scenes() -> void:
	for scene_id: StringName in SceneFlow.SCENES:
		var path: String = SceneFlow.path_for(scene_id)
		check(path.begins_with("res://"), "%s stays inside res://" % scene_id)
		check(ResourceLoader.exists(path), "%s exists at %s" % [scene_id, path])


func test_unknown_scene_id_resolves_to_nothing() -> void:
	check_eq(SceneFlow.path_for(&"../../etc/passwd"), "", "path-like id is not a scene")
	check_eq(SceneFlow.path_for(&""), "", "empty id")
	check_eq(SceneFlow.path_for(&"res://scenes/boot/boot.tscn"), "", "raw paths are not ids")


func test_redaction_removes_user_names_and_secrets() -> void:
	check(not DiagnosticsService.redact("open C:\\Users\\jane\\AppData\\x").contains("jane"), "windows home dir")
	check(not DiagnosticsService.redact("open /home/jane/.local").contains("jane"), "posix home dir")
	check(not DiagnosticsService.redact("password=hunter2 ok").contains("hunter2"), "password value")
	check(not DiagnosticsService.redact("Authorization: Bearer abc").contains("Bearer abc"), "auth header value")
	check(not DiagnosticsService.redact("key " + "A".repeat(40)).contains("A".repeat(40)), "long opaque token")
	check_eq(DiagnosticsService.redact("Loaded slot 0"), "Loaded slot 0", "ordinary text unchanged")


func test_diagnostics_keeps_a_bounded_redacted_history() -> void:
	var diagnostics: DiagnosticsService = DiagnosticsService.new()
	diagnostics.write_to_disk = false
	for index: int in DiagnosticsService.MEMORY_LIMIT + 50:
		diagnostics.info("event %d token=secret%d" % [index, index])
	var entries: PackedStringArray = diagnostics.recent_entries()
	check_eq(entries.size(), DiagnosticsService.MEMORY_LIMIT, "history is capped")
	check(not entries[0].contains("secret"), "stored entries are redacted")
	diagnostics.free()


func test_profile_service_emits_and_round_trips() -> void:
	var service: ProfileService = ProfileService.new()
	var changes: Array[int] = []
	service.profile_changed.connect(func(_p: PlayerProfile) -> void: changes.append(1))
	service.start_new("  Kai  ")
	check_eq(service.current.display_name, "Kai", "name sanitised on new game")
	var payload: Dictionary = service.to_payload()
	service.load_from_payload({})
	check_eq(service.current.display_name, AppConfig.DEFAULT_PROFILE_NAME, "empty payload gives defaults")
	service.load_from_payload(payload)
	check_eq(service.current.display_name, "Kai", "payload restores the profile")
	check_eq(changes.size(), 3, "profile_changed emitted for each change")
	service.free()
