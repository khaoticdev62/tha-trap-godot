# Vertical Slice Architecture — LAB-001 "Somebody's In The Network"

Proposed target architecture for the first playable slice. Builds on the existing foundation (`REPOSITORY_AUDIT.md`) and closes the gaps in `GAP_ANALYSIS.md`. It is a proposal: nothing here is implemented. Decisions marked **D-0xx** need approval (see `PHASE_1_IMPLEMENTATION_PLAN.md` §2).

## 1. Principles

1. **Simulation never imports presentation.** `scripts/simulation/**` and `scripts/data/**` may reference only `RefCounted`/core types. A test fails if they reference `scripts/ui` or any `Control`/`Node` UI class.
2. **UI never mutates simulation data.** UI calls a service method and listens to a signal. Simulation exposes immutable views (`Dictionary`/typed value objects copied out).
3. **Data in, behaviour out.** Missions, scenarios, rubrics, dialogue and glossary are versioned files under `data/`, validated at load. Code contains no mission text and no event ids.
4. **Typed GDScript, no `Variant` in public APIs** except at the untrusted-input boundary (JSON parsing), where values are validated and converted immediately into typed objects.
5. **Autoloads only for state that must outlive a scene swap.** Existing six stay. Add exactly one: `Progress` (D-013 below). Everything else is created per session or per scene.
6. **Results, not exceptions.** Parsers and services return result objects (`QueryResult`, `CommandResult`, `SaveResult` style) with a machine-readable code and a player-friendly message. No parser path may call `push_error` for ordinary bad input.

## 2. Layers and module ownership

```
┌──────────────────────────── PRESENTATION (scripts/ui, scenes/) ────────────────────────────┐
│ Title/Settings/Creator (done) · SaveSlots · Intro/Briefing · HQ world · SOC dashboard       │
│ Query workbench · Terminal panel · Evidence board · Timeline · Response panel · Debrief     │
│ Portfolio viewer · UiKit (shared widgets) · DialogueBox (done) · ModalDialog (done)         │
└───────────────▲──────────────────────────────────────────────────────────────┬─────────────┘
                │ signals (typed)                                              │ calls
┌───────────────┴────────────────────── GAME SERVICES (scripts/core, gameplay) ▼─────────────┐
│ SceneFlow* · Saves* · Profiles* · Settings* · Diagnostics* · EventBus* (existing autoloads) │
│ Progress (new autoload) · DialogueRunner · MissionService · AudioService (later)            │
└───────────────▲──────────────────────────────────────────────────────────────┬─────────────┘
                │ results/signals                                              │ calls
┌───────────────┴──────────────────────── SIMULATION (scripts/simulation) ──────▼─────────────┐
│ LabSession (owns one running lab) ── ScenarioPackage ── EventStore                          │
│   ├ QueryEngine (parse → plan → execute over EventStore)                                    │
│   ├ TerminalParser (tokenise → allowlisted command table → handler → CommandResult)         │
│   ├ EvidenceLedger · CaseFile · TimelineBuilder                                             │
│   └ AssessmentEngine (rubric + evidence → AssessmentResult)   ·   PortfolioExporter         │
└───────────────▲─────────────────────────────────────────────────────────────────────────────┘
                │ validated typed objects
┌───────────────┴───────────────────────── DATA (scripts/data, data/) ────────────────────────┐
│ ContentLoader · SchemaValidator · ContentRegistry (ids, versions) · JSON in data/**          │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

`*` = already exists. Dependency rule: arrows only point downward in calls and upward in signals. Presentation -> Services -> Simulation -> Data. Data and Simulation depend on nothing above them.

### Ownership table

| Module | Owns | Lifetime | Emits | Never does |
|---|---|---|---|---|
| `Progress` (autoload, new) | Mission states, flags, last checkpoint, per-lab best result | App | `progress_changed`, `mission_state_changed(id, state)` | Parse content, run labs |
| `MissionService` | Mission definitions (read-only), prerequisites, objective state machine | Created by `Progress` | `objective_completed` | Touch UI |
| `DialogueRunner` | Current dialogue node, flags it may set | Per scene | `line_ready`, `choices_ready`, `dialogue_finished` | Render |
| `LabSession` | One loaded scenario, event store, ledger, case, rng | Per lab attempt | `query_executed`, `command_executed`, `evidence_added`, `case_changed`, `assessment_ready`, `session_reset` | Read files after load, touch the scene tree |
| `QueryEngine` | Parser + executor, stateless | Created by `LabSession` | none (returns `QueryResult`) | Evaluate arbitrary expressions, read host data |
| `TerminalParser` | Command table, history | Per `LabSession` | none (returns `CommandResult`) | Spawn a process, open a path |
| `EvidenceLedger` | Evidence records (id, source event ids, note, added-at tick) | Per `LabSession` | `evidence_added/removed` | Hold UI state |
| `CaseFile` | Severity, scope, entries (fact/hypothesis/unknown), recommendation | Per `LabSession` | `case_changed` | Score |
| `AssessmentEngine` | Rubric evaluation, pure function of (rubric, case, ledger, queries) | Stateless | none | Mutate state |
| `PortfolioExporter` | Renders a text/Markdown artifact into `user://exports/` | Stateless | none | Accept a caller path |
| `ContentLoader/SchemaValidator` | File reads under `res://data/` only | Stateless | none | Read `user://` or absolute paths |

### Autoload policy (D-013)

Keep: `EventBus, Diagnostics, Settings, Saves, Profiles, Scenes`. Add: `Progress`. Do **not** add autoloads for simulation, query, terminal, or assessment. Screens create a `LabSession` via `Progress`/`SceneFlow` hand-off and free it on exit. This keeps tests simple (construct a `LabSession` directly with no scene tree) and keeps the safety kernel instantiable in headless unit tests.

## 3. Folder structure (D-013)

Reconciles `00`, `06 §11` and the existing repo (existing folders unchanged):

```
tha-trap/
  data/
    schema/            JSON-schema-like descriptors consumed by SchemaValidator
    missions/          mission_lab_001.json
    labs/lab_001/      manifest.json, events.json, assets.json, identities.json, rubric.json, hints.json
    dialogue/          intro.json, briefing_lab_001.json, debrief_lab_001.json
    glossary/          glossary.json
    frameworks/        mappings_lab_001.json   (version + source metadata, may be empty/not_applicable)
  docs/
    audits/ architecture/ production/ spec/    (spec/ = the 11 production files, versioned)
  scenes/
    boot/ menus/ world/hq/ soc/ reports/
  scripts/
    core/ save/ platform/ ui/                  (existing)
    data/                                      ContentLoader, SchemaValidator, ContentRegistry
    simulation/                                LabSession, EventStore, EventRecord, QueryEngine, TerminalParser, ...
    gameplay/                                  Progress, MissionService, DialogueRunner, HqWorld
  tests/
    unit/ integration/                         (existing)
    content/ security/ performance/ e2e/       (new)
  tools/
    content_validator/                         headless CLI wrapper over SchemaValidator (CI)
```

Rule: **content ids are stable lowercase strings** (`lab_001`, `evt_001`); display ids players see (`EVT-001`) are derived or stored as `display_id`.

## 4. Data model for LAB-001 (typed objects built from validated JSON)

All carry `id`, `schema_version`. Unknown keys are rejected by the validator in dev and ignored (logged) in release.

```
EventRecord   { id, display_id, tick:int (seconds from scenario start), source:StringName(auth|mfa|app|helpdesk),
                actor:String, result:StringName, ip_label:String (synthetic label e.g. "ext-203-0-113-x"),
                device:String, detail:String, tags:PackedStringArray, canonical:bool }
Asset         { id, kind, name, owner, notes }
Identity      { id, name, role, normal_hours, normal_sources }
EvidenceRecord{ id, event_ids:PackedStringArray, note:String, added_tick:int }
CaseEntry     { id, kind:fact|hypothesis|unknown, text:String, evidence_ids:PackedStringArray }
CaseFile      { severity:StringName, scope:Array[CaseEntry-ish ids], entries, recommendation:StringName, report_text }
Rubric        { id, version, criteria:[{id, points, check:StringName, params:Dictionary, feedback_pass, feedback_fail}], critical_errors:[{id, check, coaching}] }
AssessmentResult { total:int, max:int, per_criterion:[...], critical_errors:[...], coaching:[...] }
```

Synthetic-only rules: IPs use documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24) or opaque labels; names are fictional; every artifact and UI surface shows a "SIMULATED / SYNTHETIC DATA" label.

### Determinism and reset (D-010)

- Canonical events (EVT-001..006) are authored data, always present, fixed ids and ticks.
- Benign noise and decoys are generated by `ScenarioGenerator.generate(manifest, difficulty, seed)` using a `RandomNumberGenerator` seeded explicitly. **No call to `randi()`, `Time`, or `OS` inside simulation code.**
- `LabSession.reset()` rebuilds the `EventStore`, clears ledger/case/history/rng from `(manifest, difficulty, seed)`. Reset is defined as "same inputs give a byte-identical state hash"; a test enforces it (`state_hash()` over canonical JSON).
- Replay seeds change noise only; canonical ids and the answer set never change (`04 §8`: difficulty changes hints and noise, never truth).

## 5. Safe terminal design (`TerminalParser`)

Flow: `raw line -> length/charset gate -> tokenizer -> command lookup -> argument schema validation -> handler (pure, reads LabSession) -> CommandResult`.

- **Gate:** max 256 chars, reject all control characters (including NUL and newlines), strip bidi and zero-width characters, normalise Unicode whitespace; anything over limit returns `ERR_TOO_LONG`.
- **Tokenizer:** hand-written; supports bare words and double-quoted strings with `\"` escape only. No variable expansion, no globbing, no pipes, no redirection, no `;`/`&&`, no backticks, no `$`. These characters outside quotes yield a teaching error ("this simulated shell has no pipes").
- **Command table** (static `const`): `help, assets list, hosts show <id>, logs search <k=v ...>, timeline build <case>, evidence add <evt> <case>, evidence list, case note <case> "<text>", case severity <level>, case report <case>, clear`. Each entry declares arity, argument validators (id pattern `^[A-Za-z0-9_-]{1,32}$`), and a handler method name resolved from a **fixed map**, never from player text.
- **Unknown command:** returns `unknown command`, suggests nearest known command (edit distance), and never forwards. Host-style commands (`dir`, `ls`, `cat`, `rm`, `curl`, `powershell`, `bash`, `cmd`, `..\`) get an explicit "not available in the simulation" lesson.
- **No filesystem:** arguments are ids resolved only against the loaded scenario. A string containing `/`, `\`, `..`, `:` where an id is required is rejected by the id validator before any lookup.
- **Output:** plain text lines, capped (e.g. 200 lines, 2,000 chars per line); UI renders as `Label`/`RichTextLabel` with `bbcode_enabled = false` (player text is echoed, so BBCode must be off).
- **Static guard (CI):** a `tests/security` test greps `scripts/` for `OS.execute|OS.create_process|OS.shell_open|Expression|HTTPRequest|HTTPClient|TCP|UDP|WebSocket|ENet|load\(|preload\(` and fails on any match outside an explicit allowlist file.

## 6. SIEM query engine (`QueryEngine`) (D-009)

Proposed v1 grammar (EBNF), case-insensitive keywords, `AFTER`/`BEFORE` take `HH:MM` or ISO-like synthetic timestamps:

```
query     = "FROM" source [ "WHERE" cond ] [ range ] [ "GROUP BY" field ] [ "COUNT" ]
            [ "SORT" field [ "ASC" | "DESC" ] ] [ "LIMIT" integer ] ;
source    = "auth_events" | "mfa_events" | "app_events" | "helpdesk_tickets" ;
cond      = term { "OR" term } ;
term      = factor { "AND" factor } ;
factor    = [ "NOT" ] ( comparison | "(" cond ")" ) ;
comparison= field ( "=" | "!=" | "CONTAINS" ) string ;
range     = ( "AFTER" time ) [ "BEFORE" time ] | "BEFORE" time ;
```

- Fields come from a **fixed per-source field list**; unknown field -> teaching error listing valid fields.
- Limits: query text <= 512 chars, nesting depth <= 8, `LIMIT` default 100 and max 500, result rows capped, execution is a linear scan with an operation budget (abort with `ERR_TOO_EXPENSIVE` beyond N row-visits so a pathological query cannot hang the UI).
- Parser is recursive descent over a token array; no regex-built-from-input, no `Expression`, no string-to-callable.
- `QueryResult { ok, code, message, columns, rows, row_event_ids, truncated }` so evidence can reference real event ids.
- Beginner guided builder (dropdowns/chips) emits the same query text and goes through the same parser, so there is exactly one execution path.

## 7. Evidence, case, timeline, assessment

- Evidence is added only from event ids that exist in the store (UI passes ids from results; terminal passes ids typed by the player, validated). Duplicate adds are idempotent.
- `TimelineBuilder` orders evidence by `tick` and groups by source; output is data (`Array[TimelineItem]`), rendered by UI.
- `CaseFile` entries must be tagged fact/hypothesis/unknown (S-7). Recommendation is chosen from a fixed enum list with the risk trade-off text coming from data (proportionate vs broad shutdown).
- `AssessmentEngine.evaluate(rubric, session_snapshot)` is a pure function: same snapshot gives the same result (unit-testable with golden snapshots). Criteria checks are a closed set of named functions (`evidence_includes_all`, `timeline_ordered`, `facts_cite_evidence`, `no_unsupported_exfil_claim`, ...). Rubric JSON picks checks by name and supplies params; it cannot define new logic.
- Critical errors (`04 §7`) produce coaching and a retry path, never a failed-state dead end.

## 8. Save design changes (schema v1 -> v2)

Sectioned payload; each section owned by one service that validates it on load:

```
{ "profile": {...},                       // v1, unchanged
  "progress": { "missions": { "lab_001": {"state":"completed","best_score":86,"attempts":2, "content_version":"1.0.0"} },
                "flags": {"met_nia": true}, "checkpoint": "hq_briefing" },
  "case_drafts": { "lab_001": { ...ledger+case snapshot... } },   // optional, enables resume mid-lab
  "playtime_seconds": 0.0 }
```

- First real migration step registered at `v1` in `SaveMigrations._steps()` (adds empty `progress`). Test: v1 fixture file loads and upgrades; v2 file refused by older build logic already covered.
- Scores store the **content version** they were earned under (`03 §4`/`06 §6`): re-releasing LAB-001 data must not rewrite earned results.
- All numbers coerced from JSON floats deliberately; unknown mission ids are kept, not dropped (forward compatibility), but never trusted for unlocks.
- Autosave at: mission accepted, lab started, each evidence add (debounced), lab completed, before scene transitions. Saves go through the existing atomic writer; no new write path.

## 9. Presentation plan (controller-first)

- **SOC dashboard** follows `05 §5`: top bar (case, sim clock, `SIMULATED ENVIRONMENT` badge), left alert queue, centre timeline/workspace, right evidence/asset detail, bottom tabs Investigate / Evidence / Contain / Report. Focus model: tab row and panes form a grid; `ui_left/right` moves between panes, `ui_up/down` within a list; shoulder buttons switch tabs; `ui_cancel` backs out one level.
- **Terminal panel** always shows "SIMULATED ENVIRONMENT — NO HOST COMMANDS", command history (up/down), command palette and example insertion buttons so a controller user can build commands by token without typing (G-07). Text entry also supports the OS/Steam on-screen keyboard where available (D-011).
- **HQ** (D-012): a single small walkable room (top-down, 4-6 interactables: briefing board, SOC console, Nia, Malik, door, save point) plus an always-available **"menu hub"** fallback list of the same interactions, so the slice is playable even if movement/art slips.
- **Shared widgets** extracted into `UiKit` first: labelled button, section label, `describe()` (accessible name/description), panel, list with focus ring, tab bar, badge (icon + text, never colour only).
- Motion durations go through `AccessibilitySettings.motion_duration()`; no screen shake; no scanline filter.

## 10. Safety requirements mapped to tests

| Requirement (Task D) | Mechanism | Test location |
|---|---|---|
| No host command execution | Command table + static scan | `tests/security/test_no_host_exec.gd` (grep) + `test_terminal_rejects_host_commands.gd` |
| No shell, eval, dynamic code | No `Expression`/`OS.*` in scripts | static scan above |
| No network | No network classes; scan | static scan |
| No real credentials | Synthetic data only; secret-pattern scan over `data/` | `tests/content/test_no_secrets_in_data.gd` |
| No unrestricted filesystem | Id-only lookups; fixed export dir | `test_path_traversal_ids.gd`, `test_export_path_fixed.gd` |
| Synthetic + deterministic | Seeded rng; `state_hash` | `test_lab_determinism.gd` |
| Reset to baseline | `LabSession.reset()` | `test_lab_reset_restores_baseline.gd` |
| Malformed and malicious input | Fuzz corpus for terminal, query, JSON | `test_terminal_fuzz.gd`, `test_query_fuzz.gd`, `test_malformed_content.gd` |

Fuzz corpora include: empty/whitespace, 10k-char lines, NUL and control chars, bidi overrides, `../..`, `C:\`, `$(...)`, backticks, `;` chains, pipe/redirect, SQL-like strings, unbalanced quotes/parentheses, deep nesting, huge integers in `LIMIT`, and non-UTF-8 sequences. Property to assert: **never crashes, never returns an unbounded result, never touches the host.**

## 11. Open architecture risks

- `Progress` autoload is the one new global; if it grows into the "giant singleton" `06 §1` warns about, split mission state from flags early.
- A `LabSession` held across scene swaps needs a clear owner (proposal: `Progress` keeps the session for the active mission, freed on completion/abandon).
- GDScript has no interfaces; keep contracts small and covered by tests rather than abstract base classes.
