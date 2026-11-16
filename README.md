# THA T.R.A.P. — Threat Response And Protection

A single-player, story-driven cybersecurity career RPG built in Godot 4. Learn. Defend. Level Up.

**Status:** Phase 1 (Foundation) in progress. Boots to a working title screen with save/load, an accessibility Settings screen and a character creator, and the dialogue box component (not yet used by a story scene). There is no world, campaign or lab yet. See the production specs (`00`–`10` Markdown files in the parent folder) for the full design.

## Requirements
- Godot 4.7.2 stable (standard build, not .NET). Pinned for reproducibility; bump deliberately.

## Run
```powershell
godot --path .                      # play (opens the title screen)
tools\run-tests.ps1                 # unit + integration tests (headless)
tools\run-tests.ps1 save_service    # only test files whose name contains the filter
```
`tools/run-tests.ps1` finds Godot via `$env:GODOT`, then `PATH`, then `~\tools\godot`.

## Layout
```
scripts/core/      AppConfig, Validate, CharacterOptions, AccessibilitySettings, SettingsService, EventBus, SceneFlow, ProfileService, PlayerProfile, DiagnosticsService, AppBootstrap
scripts/save/      SaveService, SaveResult, SaveMigrations
scripts/platform/  InputActions (keyboard + controller bindings)
scripts/ui/        Palette tokens, UiTheme, ModalDialog, DialogueBox, Typewriter, HintBar, boot, title, settings and character-creator screens
scenes/            boot/, menus/
tests/unit/        headless unit tests (test_*.gd, extend TestCase)
tests/integration/ scene-driven checks that need the real autoloads
tools/             run-tests.ps1
```

## Architecture notes
- **Autoload names differ from class names** (`Saves` is a `SaveService`) because Godot forbids a class and an autoload sharing a name.
- Services never reference each other. `AppBootstrap` forwards their signals to `EventBus`.
- `SceneFlow` takes registered ids, never paths.
- Saves: `user://saves/slot_N.json` plus `.bak1/.bak2`. Slots are integers only, so no caller-supplied path ever reaches the filesystem. Saves from a newer schema are refused and never overwritten.
- Accessibility settings are per machine (`user://settings.json`), not per save. Every UI duration should go through `AccessibilitySettings.motion_duration()`; screens get type variations (`TitleLabel`, `HeadingLabel`, `MutedLabel`) from `UiTheme`.
- Diagnostics are local only, size-capped and redacted. There is no telemetry and no network access.

## Conventions
- Typed GDScript. Tests extend `TestCase`, are named `test_*`, and must make at least one assertion.
- Change the save layout only by bumping `AppConfig.SAVE_SCHEMA_VERSION` and registering a step in `SaveMigrations`.
- Never use `OS.execute`, `eval`-style execution, or the network from game or lab code (see spec `04` §1).

## License
Code: [Apache-2.0](LICENSE). Story, characters, art, audio, curriculum and the project names: all rights reserved. See [LICENSES.md](LICENSES.md).
