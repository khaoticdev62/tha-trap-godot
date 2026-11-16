# Repository Audit — THA T.R.A.P. (Phase 1 / Task 001)

Audit date: 2026-11-16. Scope: `tha-trap/` (game repo) read against the 11-file production package in the parent folder. Audit-only: no existing file was modified, no dependency installed, no project setting changed.

**Evidence tags.** `[V]` verified by reading code or running a command in this audit. `[A]` assumption or inference that still needs a check. Test results below come from a real run on this machine, not from documentation.

## 1. Executive summary

- The repo is a **clean, disciplined Phase 1 foundation**: boot, event bus, atomic checksummed saves, profile, accessibility settings, themed UI, modal, dialogue box, character creator, title screen. [V]
- It contains **no game content and no simulation**. There is no `data/` folder, no event model, no query engine, no terminal parser, no mission, evidence, case or assessment code, no world scene, and no art, font or audio asset. [V]
- Everything LAB-001 needs beyond "boot, settings, save, dialogue widget" is still to build. The foundation is a good base; nothing in it needs replacing.
- **CI has never executed.** All 7 GitHub Actions runs failed in about 3 seconds with: "The job was not started because your account is locked due to a billing issue." The workflow file is unproven. [V]
- The **production specs live outside any git repository** (parent folder `New folder (7)` is not a repo). [V]

## 2. Environment and configuration [V]

| Item | Finding |
|---|---|
| Engine | Godot 4.7.2 stable, standard build (`config/features = "4.7", "GL Compatibility"`). Binary found at `~/tools/godot/Godot_v4.7.2-stable_win64(_console).exe`. |
| Renderer | `gl_compatibility` for desktop and mobile. Sensible for Deck and low-end GPUs. |
| Display | Base 1280x800, stretch `canvas_items`, aspect `expand`. Matches the Deck target. |
| Main scene | `res://scenes/boot/boot.tscn` |
| Autoloads (6) | `EventBus`, `Diagnostics`, `Settings`, `Saves`, `Profiles`, `Scenes`. Note `Settings` is missing from the autoload list in the parent `CLAUDE.md` (doc drift). |
| Input map in `project.godot` | None. Actions are registered at runtime by `InputActions.register()` (called from `AppBootstrap.run`). |
| Plugins/addons | None. No `addons/`. No third-party dependency. |
| Assets | None. No `assets/`, fonts, textures, audio, or `.import` source art. UI uses the engine default font. |
| Export presets | None. `export_presets.cfg` is **gitignored** (see Gap G-11). |
| Git | 7 commits on `main`, remote `origin` = `khaoticdev62/tha-trap-godot`, working tree clean before and after the test run. |
| License | Apache-2.0 code, all-rights-reserved creative content (`LICENSE`, `NOTICE`, `LICENSES.md`). |

## 3. Code inventory [V]

105 tracked files; roughly 3,800 lines of GDScript, scenes and docs.

```
scripts/core/      app_config, app_bootstrap, event_bus, scene_flow, profile_service,
                   player_profile, character_options, accessibility_settings,
                   settings_service, diagnostics_service, validate
scripts/save/      save_service, save_migrations, save_result
scripts/platform/  input_actions
scripts/ui/        palette, ui_theme, page_background, boot, title_menu, settings_menu,
                   character_creator, modal_dialog, dialogue_box, typewriter, hint_bar
scenes/            boot/boot, menus/{title, settings, character_creator}  (each a thin root + script)
tests/             run_tests.gd, test_case.gd, unit/ (10 files), integration/ (4 scenes)
tools/             run-tests.ps1, visual/capture.{gd,tscn}
.github/workflows/ci.yml
```

### 3.1 Systems status

| System | Status | Notes |
|---|---|---|
| Boot / bootstrap | Complete | `AppBootstrap.run` wires services to `EventBus`; `_connect_once` is idempotent. |
| EventBus | Complete but thin | Only save/profile/scene signals. No simulation, evidence or mission signals yet. |
| SceneFlow | Complete | Id registry only (`boot,title,settings,creator`); unknown ids rejected; no paths accepted from callers. No transition effect. |
| SaveService | Complete for its scope | Slot-int-only paths, temp write + read-back verify + rotate backups + SHA-256 envelope + newer-schema refusal + corruption fallback. 16 unit tests. |
| SaveMigrations | Framework only | Chain exists and is tested with injected steps; `_steps()` is empty at schema v1. |
| Save payload | **Minimal** | `ProfileService.to_payload()` returns only `{"profile": ...}`. No progress, mission, evidence or case state. |
| Save slots in UI | **Partial** | Service supports 3 slots; both `title_menu.gd` and `character_creator.gd` hardcode `PRIMARY_SLOT = 0`. No slot picker. |
| PlayerProfile / CharacterOptions | Complete | Strict sanitising incl. bidi/zero-width stripping; ids validated on load. |
| AccessibilitySettings / SettingsService | Complete | Text scale 75-200%, reduced motion, high contrast, text speed; per-machine `user://settings.json`; atomic write; corrupt file -> defaults. |
| UiTheme / Palette | Complete for tokens | Spec §2 hex values match exactly. Contrast ratios unit-tested. No pixel/pixel-UI styling, no custom fonts. |
| ModalDialog | Complete | Focus trap, safe default focus, cancel, focus return. |
| DialogueBox | Widget only | Speaker, typewriter, up to 6 choices. **Not used by any scene**; no dialogue graph/data. |
| HintBar | Used on Settings only | Follows keyboard/controller focus. |
| Diagnostics | Complete | Local, size-capped, regex-redacted; no network. |
| InputActions | Partial | 8 gameplay actions with keyboard + pad bindings; adds pad buttons to `ui_accept/ui_cancel`. No remap UI. |
| Title / Settings / Creator screens | Complete | Title has Continue/New Game/Settings/Quit; spec §4 also lists Credits and Accessibility. |
| Pause / save menu | Missing | Needs a world to pause. |
| World, districts, NPCs, movement | Missing | Nothing. |
| Dialogue graph, missions, progression | Missing | Nothing. |
| Data loaders/validators, `data/` | Missing | Nothing; violates D-003 until built. |
| LabRuntime, EventRecord, scenario package | Missing | |
| QueryEngine, TerminalParser | Missing | |
| Evidence, Case, Timeline, Assessment, Portfolio | Missing | |
| Curriculum / glossary / framework data | Missing | |
| Audio, fonts, art | Missing | |
| Export presets, packaging | Missing | |

## 4. Tests [V]

Executed in this audit with `tools\run-tests.ps1` (the project's own runner):

```
86 tests, 473 assertions, 0 failures          (unit, headless, 10 files)
creator_flow:  0 failures
dialogue_flow: 0 failures
settings_flow: 0 failures
title_flow:    0 failures                      (integration, 4 scenes)
exit code 0, ~6 s wall time, git tree unchanged afterwards
```

| Area | Coverage that exists | Missing |
|---|---|---|
| Save | Round trip, rotation, corruption fallback, tamper, oversize, newer schema, unicode, slot isolation, signals | Interrupted-write simulation, concurrent save, save of a real multi-section payload |
| Profile/settings | Sanitising (bidi, control chars, length), strict bools, clamps, atomic write | |
| UI | Contrast ratios, theme scaling, typewriter, hint bar | Controller-only traversal of every screen, 1280x720 layout assertion |
| Flow | Title, creator, settings, dialogue via real autoloads | Anything past the creator |
| Security / safety | None specific to labs (no lab exists) | Entire `04 §10` list |
| Content validation | None | `06 §7` validators |
| Performance | None | Large-dataset query timing |
| Platform | None | Linux run, Deck run |

Harness notes: custom, small, effective. `run_tests.gd` fails a test that makes no assertions and fails the run when zero tests are found. `TestCase` has `check`/`check_eq` only (no approx compare, no "expect error"). The integration runner exists twice (PowerShell with 60 s timeout, and a shell loop in CI); there is no bash runner for Linux/Deck dev. [V]

## 5. CI [V]

`.github/workflows/ci.yml`: ubuntu-latest, downloads Godot 4.7.2 from the official release URL **with SHA-512 verification** (good), runs `--import`, unit tests, integration scenes. `permissions: contents: read` (good). Issues:

1. **Never ran.** 7/7 runs fail with a billing lock before any step starts. Whether the workflow itself is correct is unknown. [V]
2. `ubuntu-latest` is announced to migrate to Ubuntu 26; pin `ubuntu-24.04` for reproducibility. [V annotation shown by GitHub]
3. `actions/checkout@v4` is tag-pinned, not SHA-pinned. Low risk, noted. [V]
4. Windows is the primary dev OS but CI is Linux only; that is acceptable (it also proves the Linux path) once CI runs. [A]

## 6. Safety and security scan [V]

Search of `scripts/` and `tools/` for `OS.execute`, `OS.shell_open`, `OS.create_process`, `Expression`, `eval`, `HTTPRequest`, `HTTPClient`, `TCPServer`, `StreamPeer`, `PacketPeer`, `WebSocket`, `ENet`: **zero matches.** The only `FileAccess/DirAccess` uses are on `user://` paths built from constants and integer slots (`save_service`, `settings_service`, `diagnostics_service`). The only runtime `load()` calls are `tools/visual/capture.gd`, resolved through the `SceneFlow` registry.

Posture notes:
- Saves and settings are plain JSON with a SHA-256 **integrity** checksum. That detects accidental corruption, not tampering by the player (they can recompute it). Offline single-player makes that acceptable, but portfolio artifacts and mastery must never be presented as externally verified. [V]
- `Validate.strict_bool` and `PlayerProfile.sanitize_name` show the right habit for untrusted data. The same discipline has to be applied to scenario packages and content JSON before anything is parsed from `data/`. [V]
- Diagnostics redaction rules compile on every message (perf nit, not a risk). [V]

## 7. Platform assumptions

| Topic | Finding |
|---|---|
| Windows | Primary dev target; all tests executed here. [V] |
| Linux | Only via CI that has not run. `run-tests.ps1` is PowerShell only. Paths use `path_join`/`user://`, no Windows-specific code found. [V grep, A runtime] |
| Steam Deck | 1280x800 base and `expand` aspect are right; capture tool renders 1280x720 too. No hardware test. **Name entry (`LineEdit`) has no controller-only text path** (no on-screen keyboard handling found; `DisplayServer.virtual_keyboard_*` unused). Required by `05 §9`. [V grep] |
| Input | `interact` shares Enter with `ui_accept`, and `open_pause` shares Escape with `ui_cancel`; both pairs will fire together once a world exists under UI. `register()` calls `action_erase_events` on every run, which will erase any future remap loaded earlier. [V] |
| Text size | Base font 26 px at 1280x800, scalable to 200%. Above Valve's 9 px/12 px guidance. Default engine font only; glyph coverage unverified. [V] |

## 8. Broken, incomplete or duplicated items [V]

- **Layering leaks:** `scripts/core/character_options.gd` depends on `Palette` (ui); `scripts/core/settings_service.gd` calls `UiTheme.build` (ui). README says "services never reference each other"; core -> ui is the leak, not service -> service.
- **Duplicated UI helpers:** `_describe(control, name, description)` is copied in `character_creator`, `dialogue_box`, `modal_dialog`; `_label` in three screens; `_button` in three. Extract one `UiKit` before adding the SOC screens.
- **`PRIMARY_SLOT` defined twice** (`title_menu.gd:7`, `character_creator.gd:7`).
- **`SaveService._write` reads the primary file twice plus the temp file** (newer-schema check, rotation check, verify). Fine at today's size; revisit when payload approaches the 4 MB cap.
- JSON numbers load as floats in Godot; `SaveService` coerces the version with `int()`, but future payload sections (counters, scores) must coerce deliberately.
- Parent `CLAUDE.md` autoload list omits `Settings`; the spec folder has no repo (see Gap G-06).

## 9. Documentation convention

No `docs/` folder existed in `tha-trap/`. Conventions in use: root `README.md`, `CHANGELOG.md` (Keep a Changelog), `LICENSES.md`, in-file `##` doc comments. The five deliverables were therefore created under a new `docs/` tree exactly as requested (`docs/audits`, `docs/architecture`, `docs/production`). No existing file was edited. Recommendation: keep `README.md`/`CHANGELOG.md` where they are and move the 11 spec files into `docs/spec/` (see Gap G-06).

## 10. What was not checked

- Godot debug-run warnings (`-d`) were not re-run; the changelog claims zero. [A]
- Windowed rendering and screenshots (needs a display session). [A]
- Linux, Steam Deck, controller hardware. [A]
- GitHub Actions behaviour once the billing lock is cleared. [A]
