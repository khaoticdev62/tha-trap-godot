# Changelog

All notable changes are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

## [Unreleased]

### Added
- Phase 1 foundation: Godot 4.7 project (GL Compatibility renderer, 1280x800 base), boot flow, EventBus, SceneFlow with an id registry, SaveService (atomic writes, verification, rotating backups, checksums, schema migrations, corruption recovery), PlayerProfile with strict sanitising, local redacting diagnostics, controller-complete input actions, and a functional title screen (Continue / New Game / Quit).
- Headless unit test runner and a title-screen integration test (`tools/run-tests.ps1`).
