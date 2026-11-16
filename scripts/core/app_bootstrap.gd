class_name AppBootstrap
extends RefCounted
## Startup wiring. Services stay independent of each other; this is the only
## place that connects them to the EventBus.


static func run(tree: SceneTree) -> void:
	InputActions.register()
	var root: Node = tree.root
	var bus: Node = root.get_node("EventBus")
	var save: SaveService = root.get_node("Saves")
	var profile: ProfileService = root.get_node("Profiles")
	var flow: SceneFlow = root.get_node("Scenes")
	var diagnostics: DiagnosticsService = root.get_node("Diagnostics")
	var progress: ProgressService = root.get_node("Progress")

	_connect_once(save.saved, bus.save_completed)
	_connect_once(save.save_failed, bus.save_failed)
	_connect_once(save.loaded, bus.load_completed)
	_connect_once(save.load_failed, bus.load_failed)
	_connect_once(profile.profile_changed, bus.profile_changed)
	_connect_once(flow.scene_requested, bus.scene_requested)
	_connect_once(flow.scene_changed, bus.scene_changed)
	_connect_once(progress.progress_changed, bus.progress_changed)
	_connect_once(progress.mission_state_changed, bus.mission_state_changed)

	diagnostics.info("%s v%s started (save schema v%d)." % [AppConfig.GAME_TITLE, AppConfig.VERSION, AppConfig.SAVE_SCHEMA_VERSION])


static func _connect_once(source: Signal, target: Signal) -> void:
	if not source.is_connected(target.emit):
		source.connect(target.emit)
