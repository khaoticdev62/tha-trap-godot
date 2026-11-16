# 06 — Technical Architecture

## 1. Architecture overview
Godot 4, GDScript-first, modular single-player application. Use scene composition and Resources for content definitions. Keep simulation rules independent from UI. Use signals for decoupled event communication. Avoid a giant global singleton that owns every system.

## 2. Major modules
- `AppBootstrap`: startup, configuration, version checks.
- `SceneFlow`: menu, district, mission and lab transitions.
- `SaveService`: versioned save data, backups and migrations.
- `ProfileService`: player identity, accessibility and preferences.
- `WorldService`: district unlocks, NPC state, world consequences.
- `DialogueService`: dialogue graph and branching choices.
- `MissionService`: mission state, objectives, prerequisites.
- `LabRuntime`: scenario loading, deterministic simulation and reset.
- `TerminalParser`: allowlisted command grammar; no host shell.
- `QueryEngine`: safe query parser over synthetic event records.
- `EvidenceService`: evidence IDs, provenance and chain-of-custody simulation.
- `AssessmentService`: rubric scoring, feedback and mastery.
- `CurriculumService`: objectives, lessons, glossaries and framework links.
- `PortfolioService`: local report and skill-artifact export.
- `AccessibilityService`: input, text, motion, contrast and captions.
- `AudioService`: music, ambience, UI sounds and mix profiles.
- `DiagnosticsService`: local crash logs and performance counters; opt-in export only.

## 3. Data model
Use typed Resources for authored content and JSON/CSV for bulk versioned data where appropriate. Validate all data on load.

Core entities:
- PlayerProfile
- District
- Character
- Organization
- MissionDefinition
- LabScenario
- AssetDefinition
- EventRecord
- EvidenceRecord
- CaseFile
- Objective
- AssessmentRubric
- Skill
- FrameworkReference
- DialogueNode
- PortfolioArtifact

All entities require stable IDs, schema version and optional localized display strings.

## 4. Event-driven flow
```text
Player Input
   -> UI Controller
      -> Mission/Lab Service
         -> Simulation Engine
            -> Event Bus
               -> Evidence / Assessment / UI / Save
```
Use typed signals. Do not allow UI nodes to mutate simulation datasets directly.

## 5. Save design
- Local save slots, atomic writes, rotating backups.
- Schema version and migration chain.
- Autosave after mission checkpoints and before major transitions.
- No credentials or secrets stored.
- Save corruption recovery with last-known-good backup.
- Player may export/import saves explicitly.
- Do not sync saves to cloud without later explicit product decision and consent.

## 6. Framework data updates
Store framework source metadata separately from authored missions:
`framework_id`, `framework_name`, `version`, `release_date`, `source_url`, `retrieved_at`, `status`, `mapping_id`, `rationale`, `reviewed_by`, `review_date`.
A framework update must not silently change completed mission scoring. New mappings are versioned and reviewed.

## 7. Content pipeline
Author content in structured data and Markdown. Provide validation scripts that check:
- unique IDs,
- valid references,
- required objectives and assessment,
- valid framework IDs and versions,
- localization keys,
- missing audio/image assets,
- asset license metadata,
- no forbidden command strings,
- all mission branches have a reachable ending.

## 8. Performance targets (proposed)
- 60 FPS target on mainstream Windows/Linux hardware; stable 30 FPS minimum on Steam Deck in worst-case scenes.
- UI interaction response under 100 ms target.
- Scene transition under 2 seconds target on supported baseline hardware.
- Typical memory target under 1.5 GB; tune based on measured content.
- No long synchronous parsing on main thread for large event sets.
These are design targets, not measured results. Benchmark real builds before publishing claims.

## 9. Build and distribution
- Separate export presets for Windows x86_64 and Linux x86_64.
- Steam Deck target is Linux/Proton compatibility verified through Steamworks testing.
- Use reproducible version tags and signed release artifacts where feasible.
- Never commit export credentials or secrets.
- Keep content packs and engine version pinned per release.
- Maintain release notes and rollback package.

## 10. Security requirements
- No arbitrary code evaluation.
- No unrestricted shell.
- No network connection required by core gameplay.
- If optional update checks are added later, use a fixed allowlist, TLS, no sensitive data and user-visible setting.
- Parse untrusted content defensively.
- Restrict file access to game-owned save/export directories.
- No telemetry by default.
- Include threat model and security test report before release.

## 11. Suggested Godot folder layout
```text
scripts/core/       # bootstrap, event bus, service interfaces
scripts/simulation/ # event models, lab runtime, parsers
scripts/gameplay/   # world, missions, dialogue, progression
scripts/ui/         # screen controllers and reusable widgets
scripts/data/       # loaders and validators
scripts/platform/   # input, export, OS integration
scenes/ui/
scenes/world/
scenes/labs/
resources/
data/
tests/
```

Note (D-013, 2026-11-16): the built repo uses `scripts/{core,save,platform,ui}` and adds `scripts/{data,simulation,gameplay}`; see `docs/architecture/VERTICAL_SLICE_ARCHITECTURE.md` §3 for the authoritative tree.
