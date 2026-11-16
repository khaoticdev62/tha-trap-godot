extends Node
## Typed, decoupled event hub (autoload "EventBus").
## Services emit their own signals; AppBootstrap forwards them here so UI and
## other systems can listen without depending on a concrete service.
## The bus owns no state and no logic.
##
## Nothing in this file emits: AppBootstrap connects each service signal to the
## matching signal below (`source.connect(target.emit)`), which the static
## analyzer cannot see, hence the unused_signal annotations.

@warning_ignore("unused_signal")
signal save_completed(slot: int)
@warning_ignore("unused_signal")
signal save_failed(slot: int, reason: String)
@warning_ignore("unused_signal")
signal load_completed(slot: int, recovered_from_backup: bool)
@warning_ignore("unused_signal")
signal load_failed(slot: int, reason: String)

@warning_ignore("unused_signal")
signal profile_changed(profile: PlayerProfile)

@warning_ignore("unused_signal")
signal scene_requested(scene_id: StringName)
@warning_ignore("unused_signal")
signal scene_changed(scene_id: StringName)

@warning_ignore("unused_signal")
signal progress_changed
@warning_ignore("unused_signal")
signal mission_state_changed(mission_id: String, state: String)
