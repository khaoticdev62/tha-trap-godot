extends Node
## Typed, decoupled event hub (autoload "EventBus").
## Services emit their own signals; AppBootstrap forwards them here so UI and
## other systems can listen without depending on a concrete service.
## The bus owns no state and no logic.

signal save_completed(slot: int)
signal save_failed(slot: int, reason: String)
signal load_completed(slot: int, recovered_from_backup: bool)
signal load_failed(slot: int, reason: String)

signal profile_changed(profile: PlayerProfile)

signal scene_requested(scene_id: StringName)
signal scene_changed(scene_id: StringName)
