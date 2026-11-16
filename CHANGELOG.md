# Changelog

All notable changes are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

## [Unreleased]

### Added
- `ContentRegistry` and `ContentLoader` (`scripts/data/`): content is loaded by registered id only (never a caller path), with a per-file size cap, malformed-JSON errors that carry a line number, a required `schema_version` (newer versions refused), schema validation, and `validate_all()` that reports every bad document together. Schemas live in code for now rather than `data/schema/*.json`; revisit when more than one lab exists.
- `SchemaValidator` and `ContentResult` (`scripts/data/`): declarative validation for untrusted content (types, ranges, enums, stable ids, text safety incl. control/zero-width/bidi characters, nesting cap, error cap, safe relative content paths, duplicate-id finder). First piece of milestone M1; no content or loader yet.
- Phase 1 audit documents (`docs/audits`, `docs/architecture`, `docs/production`) and the production specs under version control in `docs/spec/` (decisions D-008 to D-013 recorded in `00`).
- Local pre-push test gate (`tools/hooks/pre-push`, `tools/install-hooks.ps1`) as a stand-in for CI.
- Credential-free export presets for Windows and Linux x86_64 (`export_presets.cfg`, no longer git-ignored; verified to load and pack resources with Godot 4.7.2; full export needs export templates, not yet tested).
- License: Apache-2.0 for code (`LICENSE`, `NOTICE`); creative content and names stay all rights reserved (`LICENSES.md`).
- Phase 1 foundation: Godot 4.7 project (GL Compatibility renderer, 1280x800 base), boot flow, EventBus, SceneFlow with an id registry, SaveService (atomic writes, verification, rotating backups, checksums, schema migrations, corruption recovery), PlayerProfile with strict sanitising, local redacting diagnostics, controller-complete input actions, and a functional title screen (Continue / New Game / Quit).
- UI foundation: palette-driven global Theme (scalable text 75-200%, high-contrast scheme, thick shape-based focus rings), persisted AccessibilitySettings (`user://settings.json`, atomic writes, corrupt files fall back to defaults), `motion_duration()` for reduced motion, and a working Settings screen reachable from the title screen (ui_cancel / B goes back).
- `DialogueBox`: speaker, typewriter reveal, branching choices. Accept finishes a line early, then advances; nothing is timed. Honours reduced motion and a new dialogue text speed setting (Slow / Normal / Fast / Instant). Lines are plain text and capped (1200 chars, 6 choices).
- `HintBar`: help text that follows keyboard/controller focus as well as the mouse; used on the Settings screen.
- Reusable `ModalDialog` (focus trapped between its buttons, starts on the safe choice, ui_cancel cancels, focus returns to the opener) used for the start-over confirmation.
- Character creator wired into New Game: name, optional pronouns, skin tone, hair and outfit colour. Choices are cosmetic, stored as stable ids and validated on load (unknown ids fall back to defaults).
- Headless unit test runner and a title-screen integration test (`tools/run-tests.ps1`), with a per-scene timeout.

### Changed
- CI runner pinned to `ubuntu-24.04`.
- EventBus signals annotated `unused_signal` (they are emitted by forwarding in AppBootstrap); a debug run now reports zero engine warnings.
- Visual review (real renders via `tools/visual/capture.tscn`) found and fixed: modal and dialogue box mis-positioned (anchors without offsets), Settings/Title not scrollable at large text, invisible slider track, unstyled text fields and dropdown popups, toggle state shown only by a tiny icon (now "On/Off" in the label), pillarboxing at 16:9 (stretch aspect is now `expand`), and screens ignoring the high-contrast page colour (`PageBackground`).
- New Game now goes through the character creator; the profile is written only when the creator finishes, so backing out never destroys an existing save.
- Pronouns are a fixed list of options rather than free text.
- Accessibility preferences moved out of `PlayerProfile` into `AccessibilitySettings` so they apply before a save is loaded.
- Pressed-button style now uses the Obsidian background: white on Signal Purple measured 4.39:1, below WCAG AA 4.5:1.
