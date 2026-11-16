# Changelog

All notable changes are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

## [Unreleased]

### Added
- License: Apache-2.0 for code (`LICENSE`, `NOTICE`); creative content and names stay all rights reserved (`LICENSES.md`).
- Phase 1 foundation: Godot 4.7 project (GL Compatibility renderer, 1280x800 base), boot flow, EventBus, SceneFlow with an id registry, SaveService (atomic writes, verification, rotating backups, checksums, schema migrations, corruption recovery), PlayerProfile with strict sanitising, local redacting diagnostics, controller-complete input actions, and a functional title screen (Continue / New Game / Quit).
- UI foundation: palette-driven global Theme (scalable text 75-200%, high-contrast scheme, thick shape-based focus rings), persisted AccessibilitySettings (`user://settings.json`, atomic writes, corrupt files fall back to defaults), `motion_duration()` for reduced motion, and a working Settings screen reachable from the title screen (ui_cancel / B goes back).
- Reusable `ModalDialog` (focus trapped between its buttons, starts on the safe choice, ui_cancel cancels, focus returns to the opener) used for the start-over confirmation.
- Character creator wired into New Game: name, optional pronouns, skin tone, hair and outfit colour. Choices are cosmetic, stored as stable ids and validated on load (unknown ids fall back to defaults).
- Headless unit test runner and a title-screen integration test (`tools/run-tests.ps1`), with a per-scene timeout.

### Changed
- New Game now goes through the character creator; the profile is written only when the creator finishes, so backing out never destroys an existing save.
- Pronouns are a fixed list of options rather than free text.
- Accessibility preferences moved out of `PlayerProfile` into `AccessibilitySettings` so they apply before a save is loaded.
- Pressed-button style now uses the Obsidian background: white on Signal Purple measured 4.39:1, below WCAG AA 4.5:1.
