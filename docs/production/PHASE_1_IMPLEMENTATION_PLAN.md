# Phase 1 Implementation Plan — LAB-001 Vertical Slice

Dependency-aware plan from the current foundation to a playable "Somebody's In The Network" slice. Companion docs: `docs/audits/REPOSITORY_AUDIT.md`, `docs/audits/GAP_ANALYSIS.md`, `docs/architecture/VERTICAL_SLICE_ARCHITECTURE.md`, `PHASE_1_RISK_REGISTER.md`.

**Sizing.** One "session" = one focused AI-assisted working block that ends with passing tests and a commit. Estimates are planning guesses for a solo developer, not measurements; revise after M2.

**Rules for every milestone** (from `09` global contract): inspect, plan, implement, test, review, summarise. One milestone in flight at a time. Run `tools\run-tests.ps1` before and after; never claim results not produced by a real run. Update `CHANGELOG.md`. Commit and push after each completed milestone.

## 1. Dependency graph

```
M0 housekeeping & decisions
 └─ M1 data foundation ──┬─ M2 simulation kernel ─┬─ M3 query engine ──┐
                         │                        ├─ M4 terminal parser ┤
                         │                        └─ M5 evidence/case ──┴─ M6 assessment & portfolio
                         └─ M7 progress, save v2, slot UI ───────────────────────────┐
M8 UI kit + SOC dashboard (needs M3,M4,M5,M6 APIs) ──┐                               │
M9 dialogue + HQ + briefing (needs M1,M7) ───────────┴─ M10 end-to-end flow ─ M11 hardening ─ M12 exit review
```
M3, M4, M5 can proceed in any order after M2. M7 can run in parallel with M3-M6 if time allows. M8 and M9 can overlap once their APIs exist.

## 2. Decisions required before M1 (record in `docs/spec/00` decision register)

| Id | Decision | Proposal |
|---|---|---|
| D-008 | Lab id and identity (S-1, S-2) | `LAB-001` stable id; synthetic user `j.smith`; manifest alias `LAB-MR-001`. |
| D-009 | Query grammar v1 (S-3) | EBNF in architecture §6; drop `SELECT` for v1. |
| D-010 | Scenario and scoring model (S-4 to S-7) | Canonical 6 events + seeded noise; add asset table; score evidence-id set and fact/hypothesis tagging, not query text. |
| D-011 | Controller-only text entry | Primary: token/palette command builder + guided query builder (no typing needed). Secondary: on-screen keyboard via OS/Steam where available. Name entry gets a controller character picker fallback. |
| D-012 | Walkable space scope | Switchboard HQ only for Phase 1, with menu-hub fallback; The Block deferred to Phase 2 (changes `08 §2` first-milestone list). |
| D-013 | Repo layout and autoloads | Layout in architecture §3; add exactly one autoload (`Progress`); update `00` and `06` layout sections in the same commit. |

---

## M0 — Housekeeping and unblock (1 session + user action)

- **Objective:** make the work verifiable and protected before building.
- **Required systems:** none new.
- **Files:** `docs/spec/*` (copy of the 11 files and `INDEX.md`), edits to `CLAUDE.md` autoload list, `ci.yml` (pin `ubuntu-24.04`), `README.md` link fix, `.gitignore` (stop ignoring credential-free `export_presets.cfg`), `export_presets.cfg` (Windows x86_64, Linux x86_64, no credentials).
- **Dependencies:** user resolves the GitHub billing lock (cannot be done by code).
- **Acceptance:** specs committed; CI run executes real steps (green or red for real reasons); presets exist; decisions D-008..D-013 recorded.
- **Automated tests:** existing suite still 86/473/0 plus 4 scenes pass; CI green once billing is fixed.
- **Manual tests:** open Godot editor, Project > Export shows both presets without errors.
- **Risks:** billing outside our control (R-01); presets must not contain secrets.
- **Definition of done:** CI shows a passing run on `main`; specs under version control; decision records merged.

## M1 — Data foundation (2-3 sessions)

- **Objective:** versioned, validated, data-driven content loading (D-003).
- **Systems:** `ContentLoader`, `SchemaValidator`, `ContentRegistry`, `tools/content_validator`.
- **Files:** `scripts/data/{content_loader,schema_validator,content_registry,content_result}.gd`, `data/schema/*.json`, `data/missions/mission_lab_001.json` (skeleton), `data/labs/lab_001/manifest.json`, `tests/unit/test_schema_validator.gd`, `tests/content/*`, `tools/content_validator/validate.gd` + wrapper.
- **Dependencies:** M0.
- **Acceptance:** loader reads only `res://data/**` via registry ids; rejects `..`, absolute, `user://` paths; enforces file size cap (proposed 1 MB each), depth cap, type/enum/range checks, unique ids, resolvable references, `schema_version` present; unknown schema version refused with a clear message; malformed JSON returns an error result, never crashes; validator runs headless with non-zero exit on failure.
- **Automated tests:** unit (types, ranges, refs, duplicate ids), malformed-JSON corpus, traversal-id corpus, content test that validates every file under `data/` (wired into CI).
- **Manual tests:** break a data file on purpose; the validator names the file, field and reason.
- **Risks:** over-building a schema language; keep it to the field types the slice needs (R-06).
- **DoD:** `godot --headless -s tools/content_validator/validate.gd` exits 0 on real data and 1 on seeded-bad data; tests green.

## M2 — Simulation kernel (3-4 sessions)

- **Objective:** deterministic, resettable lab runtime with no UI dependency.
- **Systems:** `EventRecord`, `EventStore`, `ScenarioPackage`, `ScenarioGenerator`, `LabSession` (load, state_hash, reset), difficulty profiles.
- **Files:** `scripts/simulation/*.gd`, `data/labs/lab_001/{events,assets,identities}.json`, `tests/unit/test_lab_session.gd`, `tests/unit/test_scenario_generator.gd`, `tests/security/test_simulation_isolation.gd`.
- **Dependencies:** M1.
- **Acceptance:** loading LAB-001 yields the 6 canonical events with fixed ids/ticks (EVT-001..006); same `(manifest, difficulty, seed)` gives identical `state_hash`; reset after arbitrary mutation restores the baseline hash; difficulty changes noise volume only, never canonical events; `scripts/simulation/**` references no UI class (static check).
- **Automated tests:** determinism, reset, difficulty invariance, isolation scan, large dataset build time recorded (informational).
- **Manual tests:** none (headless).
- **Risks:** accidental non-determinism (dictionary order, time calls) (R-07); mitigate with `state_hash` over sorted canonical JSON.
- **DoD:** reset and determinism tests pass on Windows and (once CI runs) Linux.

## M3 — Query engine (2-3 sessions)

- **Objective:** safe SIEM-style search over the event store.
- **Systems:** `QueryTokenizer`, `QueryParser`, `QueryExecutor`, `QueryResult`.
- **Files:** `scripts/simulation/query/*.gd`, `tests/unit/test_query_*.gd`, `tests/security/test_query_fuzz.gd`, `tests/content/test_query_golden.gd`.
- **Dependencies:** M2, D-009.
- **Acceptance:** grammar from architecture §6 fully implemented; unknown field/source gives a teaching error with valid options; limits enforced (512 chars, depth 8, LIMIT <= 500, operation budget); no use of `Expression` or dynamic evaluation; golden queries for LAB-001 return exactly the expected event ids (e.g. failed auth for `j.smith` returns EVT-001, EVT-002; `AFTER 09:15` includes EVT-003).
- **Automated tests:** parser unit tests per production rule; golden dataset tests; fuzz corpus (random token soup, deep nesting, huge numbers, bidi/NUL) asserting no crash, bounded time and bounded output.
- **Manual tests:** run five sample queries from a debug script and read the output.
- **Risks:** grammar creep (R-06); keep v1 small.
- **DoD:** all golden and fuzz tests pass; every error message is actionable.

## M4 — Terminal parser (2 sessions)

- **Objective:** allowlisted, sandboxed fictional command shell.
- **Systems:** `TerminalTokenizer`, `CommandTable`, `CommandHandlers`, `CommandResult`, history, help text from data.
- **Files:** `scripts/simulation/terminal/*.gd`, `data/labs/lab_001/commands.json` (help/examples), `tests/security/test_terminal_*.gd`, `tests/unit/test_terminal_*.gd`.
- **Dependencies:** M2 (and M3 for `logs search`, which reuses `QueryEngine`).
- **Acceptance:** every command in architecture §5 works against LAB-001 data; host-style commands (`dir`, `ls`, `cat`, `rm`, `curl`, `powershell`, `cmd`, `bash`), pipes, `;`, `&&`, backticks, `$()`, redirection, `../`, drive letters and absolute paths are rejected with a teaching message and **no** side effect; static scan finds no `OS.*` execution, `Expression`, network or `load()` of player-derived text; output capped.
- **Automated tests:** the full `04 §10` safety list that applies at this layer; fuzz corpus; "help documents every command" check (each command has help and an example).
- **Manual tests:** type five malicious strings in a debug harness; confirm nothing leaves the sandbox (Process Monitor optional).
- **Risks:** SEC-1; the single most important safety property (R-02).
- **DoD:** security suite green and wired into CI as a required step.

## M5 — Evidence, case file, timeline (2 sessions)

- **Objective:** evidence collection with provenance, case notes, severity, timeline data.
- **Systems:** `EvidenceLedger`, `CaseFile`, `TimelineBuilder`, signals to `EventBus` through `Progress`/session wiring.
- **Files:** `scripts/simulation/{evidence_ledger,case_file,timeline_builder}.gd`, `tests/unit/test_evidence_*.gd`, `test_case_file.gd`, `test_timeline_builder.gd`.
- **Dependencies:** M2.
- **Acceptance:** evidence references only existing event ids; duplicate add idempotent; remove works; case entries require kind and (for facts) at least one evidence id; timeline is ordered by tick and stable; all mutations emit one signal each; session snapshot is JSON-serialisable and restores exactly.
- **Automated tests:** unit tests for each rule; snapshot round trip; invalid ids and oversize notes rejected (note cap proposed 500 chars, 50 entries).
- **Manual tests:** none.
- **Risks:** UI-driven shape changes later; keep API small (R-06).
- **DoD:** snapshot -> JSON -> snapshot is lossless in a test.

## M6 — Assessment and portfolio (2 sessions)

- **Objective:** evidence-based scoring with explanatory feedback and a local artifact.
- **Systems:** `AssessmentEngine` (closed set of named checks), `Rubric` loader, `HintLadder`, `PortfolioExporter`.
- **Files:** `scripts/simulation/{assessment_engine,rubric,hint_ladder,portfolio_exporter}.gd`, `data/labs/lab_001/{rubric,hints}.json`, `tests/unit/test_assessment_*.gd`, `tests/content/test_rubric_paths.gd`.
- **Dependencies:** M3 (query history), M5.
- **Acceptance:** `04 §7` rubric implemented (20/20/20/15/15/10 = 100); critical errors (confirmed exfiltration without evidence; broad shutdown without scope/impact) trigger coaching and a retry flag, not a failed end state; perfect, partial, and critical-error golden snapshots score as authored; assessment is pure (same snapshot, same result); exporter writes only to `user://exports/` with generated names, plain Markdown, labelled synthetic and self-recorded.
- **Automated tests:** golden snapshots (>= 6 paths including "valid alternative path"), export path test, rubric-references-only-known-checks content test, difficulty does not change correct answers.
- **Manual tests:** open the exported file; read the feedback text for tone and plain English.
- **Risks:** subjective rubric; validate with the content owner (R-08).
- **DoD:** every rubric criterion has a passing and failing golden case.

## M7 — Progress, save v2, slot selection (2 sessions)

- **Objective:** persist progression; make slots usable.
- **Systems:** `Progress` autoload, `MissionService`, sectioned payload, `SaveMigrations` v1->v2, slot picker screen, delete with confirm.
- **Files:** `scripts/gameplay/{progress,mission_service}.gd`, `scripts/ui/save_slots.gd`, `scenes/menus/save_slots.tscn`, `project.godot` (add `Progress` autoload, via editor-approved change), `AppConfig.SAVE_SCHEMA_VERSION = 2`, `tests/unit/test_progress.gd`, `test_save_v1_to_v2.gd`, `tests/integration/save_slots_flow.gd`.
- **Dependencies:** M1 (mission definitions), M5 (case snapshot), D-013.
- **Acceptance:** a stored v1 fixture upgrades to v2 with no data loss; unknown/forged mission data cannot unlock content; mission results record the content version; `PRIMARY_SLOT` constants removed in favour of an active-slot concept; slot cards show name, playtime, progress; deleting needs confirmation; controller-only operation; interrupted write leaves the previous save loadable.
- **Automated tests:** migration fixture, forged payload, interrupted-write simulation (temp file left behind), slot isolation with real payload, integration flow.
- **Manual tests:** create two characters in two slots, play, quit, relaunch, continue each.
- **Risks:** R-05 (save compatibility mistakes are the most expensive kind to ship).
- **DoD:** v1 save from this audit's build loads into the v2 build in a test.

## M8 — UI kit and SOC dashboard (4-5 sessions)

- **Objective:** controller-first investigation screens bound to real simulation data.
- **Systems:** `UiKit` (extract duplicated helpers), monospace + body fonts registered, alert queue, alert detail, query workbench (typed + guided builder), terminal panel (history, palette, SIMULATED banner), evidence board, timeline view, response/recommendation panel, input contexts (world vs ui) and focus map, on-screen keyboard path (D-011).
- **Files:** `scripts/ui/ui_kit.gd`, `scripts/ui/soc/*.gd`, `scenes/soc/*.tscn`, `assets/fonts/*` + `data/assets/register.json` entries, `tests/integration/soc_flow.gd`.
- **Dependencies:** M3, M4, M5, M6 APIs; fonts licensed per `07 §3`.
- **Acceptance:** every control reachable and operable by controller alone; focus never lost or trapped; text readable at 1280x800 and 1280x720 at 100% and 200% text scale; no information by colour alone (icon + label for severity); reduced motion respected; UI contains no simulation logic (UI calls services, listens to signals); terminal echo has BBCode disabled.
- **Automated tests:** scripted controller-input traversal of every pane; focus-trap tests for modals; capture tool extended with SOC screens at both sizes; a test that no `scripts/ui` script writes to `EventStore` directly.
- **Manual tests:** play with a gamepad only; run capture tool and inspect PNGs (CLAUDE.md requires eyes on UI); 200% text pass.
- **Risks:** largest UI surface and the main schedule risk (R-03, R-09); no concept sheet exists to match (R-10).
- **DoD:** investigation can be completed from query to report with a controller and no keyboard.

## M9 — Dialogue, Switchboard HQ, briefing (3-4 sessions)

- **Objective:** story framing and the first walkable (or menu-hub) space.
- **Systems:** `DialogueRunner` + dialogue graph format (nodes, choices, flags, conditions, speakers), HQ scene with interactables, menu-hub fallback, intro sequence, mission briefing screen, debrief screen.
- **Files:** `scripts/gameplay/{dialogue_runner,hq_world}.gd`, `scenes/world/hq/*.tscn`, `data/dialogue/*.json`, `data/glossary/glossary.json`, `tests/unit/test_dialogue_runner.gd`, `tests/content/test_dialogue_reachability.gd`.
- **Dependencies:** M1, M7, D-012; M8 UI kit.
- **Acceptance:** every dialogue node reachable and every branch reaches an ending (validator); flags set only through declared effects; text plain only and length-capped (existing `DialogueBox` limits); HQ playable with keyboard and controller, interaction prompts show the correct glyph/label; menu-hub offers identical actions; no cosmetic choice affects outcomes; art placeholder geometry is used only in development and tracked for replacement (R-04).
- **Automated tests:** dialogue graph validation (dead ends, cycles without exit, unknown flags), runner unit tests, HQ interaction integration test.
- **Manual tests:** play intro to briefing with pad; read all dialogue for tone with the cultural reviewer.
- **Risks:** R-04 (art), R-08 (cultural review), scope creep into a full world.
- **DoD:** player can reach the briefing and start the lab from HQ with controller only.

## M10 — End-to-end flow and reset (2 sessions)

- **Objective:** one connected run, new save to portfolio.
- **Systems:** wiring through `SceneFlow` ids (`intro, hq, briefing, soc, debrief, portfolio`), checkpoints, abandon/retry/reset, return to HQ, progression state shown.
- **Files:** `scripts/core/scene_flow.gd` (new ids), `tests/e2e/lab_001_full_run.gd` (scripted input, uses real autoloads and a temp save dir).
- **Dependencies:** M7, M8, M9.
- **Acceptance:** scripted run New Game -> creator -> intro -> HQ -> briefing -> lab -> evidence -> timeline -> recommendation -> assessment -> debrief -> portfolio export -> save -> relaunch -> Continue resumes; reset returns the lab to baseline hash; a deliberately bad answer (critical error) leads to coaching and a retry; quitting mid-lab resumes from the last autosave.
- **Automated tests:** the e2e script (success path, critical-error path, resume path); EventBus relay assertions.
- **Manual tests:** a full human playthrough, timed, by someone who has not read the code.
- **Risks:** SceneFlow frees the active scene during awaits (known gotcha in `CLAUDE.md`); e2e harness must set `current_scene = null` pattern (R-11).
- **DoD:** e2e green locally and in CI; a person finishes the slice in 30-45 min (`08 §1` gate).

## M11 — Hardening (3 sessions)

- **Objective:** meet the Phase 1 exit criteria with evidence.
- **Work:** Steam Deck/handheld resolution passes (1280x800, 1280x720), controller-only audit, text-scale audit, large-dataset performance measurement, memory/frame timing on a real run, accessibility checklist (`05 §8`), Linux export smoke test, credits screen with Godot attribution, asset register complete, security suite review, CHANGELOG/README refresh.
- **Dependencies:** M10.
- **Acceptance:** documented test evidence for each item (screenshots, timings, commands); no critical/high defects open; every asset in the register has a reviewed license; no placeholder control in the release path.
- **Automated tests:** performance test with a 10,000-event dataset recording query time (report numbers, do not assert unmeasured targets); `tools/asset_audit` check that fails on `unknown`/`unreviewed`.
- **Manual tests:** Deck hardware if available (otherwise a Linux box with a gamepad at 1280x800); report as "not verified on Deck hardware" if not done.
- **Risks:** R-12 (no Deck hardware), R-09.
- **DoD:** hardening report written; claims limited to what was run.

## M12 — Exit review (1 session)

- Checklist against `08 §1` Phase 3/5 gates and `08 §4` acceptance criteria for the slice scope; list what is intentionally out of Phase 1; update the risk register; tag `v0.2.0-slice`.

## 3. Rough budget (estimate, not commitment)

M0 1 · M1 2-3 · M2 3-4 · M3 2-3 · M4 2 · M5 2 · M6 2 · M7 2 · M8 4-5 · M9 3-4 · M10 2 · M11 3 · M12 1 = **29-37 sessions**. Content authoring (events, rubric text, dialogue, glossary, hints, report templates) is inside those numbers but is the part most likely to run over; art is excluded and is the dominant unknown (R-04).

## 4. Recommended order of attack and cut line

Build **bottom-up through the safety kernel first (M1-M6)**, because it is headless, testable, and carries the project's principal risk (D-006). Do UI (M8) only after the APIs are stable. If time runs short, cut in this order: HQ walkable movement (keep menu hub), guided query builder (keep typed + examples), Intro dialogue length, SOC secondary tabs. **Never cut:** terminal safety tests, reset/determinism tests, evidence-based scoring, controller operability, save migration test.

## 5. Exact next implementation task

**Task 002 = M0, then M1-T1.**

1. **Needs the user (outside code):** clear the GitHub Actions billing lock for `khaoticdev62/tha-trap-godot` and approve decisions D-008 to D-013 (or amend them).
2. **First code change after approval (M0):** copy the spec files into `tha-trap/docs/spec/`, pin `ubuntu-24.04` in `ci.yml`, add credential-free `export_presets.cfg` and stop ignoring it, fix the `CLAUDE.md` autoload list, push, and confirm a real CI run.
3. **First feature code (M1-T1):** create `scripts/data/schema_validator.gd` with its unit tests (`tests/unit/test_schema_validator.gd`): type, enum, range, required-field, unique-id and path-safety checks returning a typed `ContentResult`, driven by tests first. No game content yet.
