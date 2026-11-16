# Gap Analysis — Repository vs. Production Package

Companion to `REPOSITORY_AUDIT.md`. Severity: **Blocker** (slice cannot ship without it), **High**, **Medium**, **Low**. `[V]` verified, `[A]` assumption.

## 1. LAB-001 slice requirements vs. current state

| # | Slice requirement | State | Gap |
|---|---|---|---|
| 1 | Main menu and startup | Done | Add Credits (and a link to Settings/Accessibility is present). |
| 2 | New game and save selection | Partial | Service has 3 slots; UI hardwires slot 0. Needs slot picker, slot summary (name, playtime, progress), delete with confirm. |
| 3 | Player intro and dialogue | Partial | `DialogueBox` widget exists, unused. No dialogue data format, graph, speaker/portrait model. |
| 4 | Switchboard HQ environment | Missing | No world scene, movement, interactables, camera, art. |
| 5 | Mission briefing | Missing | No mission definition or briefing UI. |
| 6 | Interactive SOC dashboard | Missing | No screens or components. |
| 7 | Synthetic auth + MFA data | Missing | No `data/`, no EventRecord, no scenario package. |
| 8 | Safe simulated terminal | Missing | No parser, grammar or UI. |
| 9 | SIEM search/filter | Missing | No query engine. |
| 10 | Evidence + case management | Missing | |
| 11 | Investigation timeline | Missing | |
| 12 | Risk-based response recommendation | Missing | |
| 13 | Assessment + explanatory feedback | Missing | |
| 14 | Mission completion + progression | Missing | No progress model in save. |
| 15 | Local portfolio artifact | Missing | No export path/format; `user://` export dir policy undefined. |
| 16 | Save/load + mission reset | Partial | Save/load infrastructure done; mission reset has nothing to reset. |

Roughly 3 of 16 are done or mostly done. The finished parts are the ones that carry the most safety and robustness risk, which is the right order.

## 2. Findings

### Blockers

**G-01 No data-driven content layer.** [V] No `data/`, loader, schema, or validator. D-003 and principle 6 require content to be versioned data with stable ids and schema versions. Everything else in the slice depends on this. *Fix: M1.*

**G-02 Simulation kernel absent.** [V] `EventRecord`, scenario package, `LabSession` (load, deterministic run, reset), `QueryEngine`, `TerminalParser`. The safety boundary (D-006) has no code or tests yet, so it is currently a promise, not a property. *Fix: M2-M4.*

**G-03 No evidence, case, assessment, mission or portfolio services.** [V] *Fix: M5-M7.*

**G-04 Save payload contains only the profile.** [V] `Profiles.to_payload()` is the entire save. Progress, mission state, case and score data need a sectioned payload and the first real migration (v1 -> v2) to prove the migration chain with real data. *Fix: M7.*

### High

**G-05 CI has never run.** [V] 7/7 runs fail with "account is locked due to a billing issue". Until the user resolves the GitHub billing state, there is no automated gate, and the `ci.yml` itself is unvalidated. Interim gate is the local `run-tests.ps1`. *Action: user resolves billing; then re-run; pin `ubuntu-24.04`. Tracked as M0.*

**G-06 Specs are not under version control.** [V] The 11 production files and `INDEX.md` sit in `New folder (7)`, which is not a git repo; `tha-trap/README.md` links to them by "parent folder". Any edit or deletion is unrecoverable and CI cannot check content against them. *Fix: copy to `tha-trap/docs/spec/` (keeps the parent `CLAUDE.md` pointer updated), commit.*

**G-07 No controller-only text entry path.** [V] Character creator name field is a `LineEdit`; there is no on-screen keyboard or controller token-entry fallback. `05 §9` requires text entry via the Steam keyboard or a built-in method. The terminal and case notes will make this worse. *Fix: decide approach in M0 (see D-011), implement before M8.*

**G-08 Spec contradictions that block exact implementation.** [V] See section 3. The LAB-001 example data and grammar cannot be implemented literally.

**G-09 No world/HQ/NPC/dialogue-graph stack.** [V] Slice items 3-5. Largest art-dependent area; sized as risk R-03.

### Medium

**G-10 Input conflicts and remap fragility.** [V] `interact` = Enter and `ui_accept` = Enter; `open_pause` = Escape and `ui_cancel` = Escape. When a world scene hosts overlay UI, one key press triggers both. `InputActions.register()` erases events every call, so loading remaps before it would lose them. No remap UI (`05 §8`). *Fix: input contexts (world vs ui) and remap persistence in M8/M9.*

**G-11 No export presets, and `export_presets.cfg` is gitignored.** [V] Release builds are not reproducible from the repo. Prompt 2 asked for Windows/Linux presets. The ignore rule exists to avoid credentials in presets; presets without credentials are safe to commit. *Fix: commit credential-free presets, keep `export_credentials.cfg` ignored.*

**G-12 Layering leaks core -> ui.** [V] `CharacterOptions` -> `Palette`; `SettingsService` -> `UiTheme`. Harmless today, but the simulation layer must never import `scripts/ui`. *Fix: move colour data for options into ui, and have a ui-side listener on `Settings.changed` apply the theme.*

**G-13 Duplicated UI helpers.** [V] `_describe` x3, `_label` x3, `_button` x3, `PRIMARY_SLOT` x2. *Fix: `UiKit` in M8 before the SOC screens multiply it.*

**G-14 No fonts or art; default engine font.** [V] `05 §6` requires a readable body/mono face and an open-license pixel/display face with glyph coverage checked. A monospace face is mandatory for the terminal. No asset register file exists. *Fix: pick and register fonts in M8; license review per `07 §3`.*

**G-15 No Credits or Accessibility entry on the title screen.** [V] Spec screen inventory §4.2. Godot attribution must appear before release (`LICENSES.md`).

**G-16 Test categories from `08 §3` do not exist.** [V] No `tests/content`, `tests/security`, `tests/performance`, `tests/e2e`. Safety tests for D-006 are the most important missing suite.

### Low

**G-17 Diagnostics cost.** [V] Regex rules rebuilt per message, log file reopened per line. Fine now; matters if the lab logs per command.

**G-18 `SaveService._write` triple read.** [V] Optimise only if payload grows.

**G-19 Integration runner duplicated** between `run-tests.ps1` and `ci.yml`; no bash runner. [V]

**G-20 Doc drift.** [V] Parent `CLAUDE.md` omits the `Settings` autoload; `00` and `06` disagree on `scripts/` layout and the repo uses a third variant (`core, save, platform, ui`).

## 3. Specification defects to resolve before building LAB-001

These are errors or ambiguities in the package. Each needs a recorded decision (proposed as D-008 to D-013 in `PHASE_1_IMPLEMENTATION_PLAN.md`).

| # | Defect | Where | Proposed resolution |
|---|---|---|---|
| S-1 | Lab id is `LAB-001` in the catalogue and `LAB-MR-001` in the schema sample | `04 §5-6` | Use `LAB-001` as the stable id; `district: market_row`. Keep `LAB-MR-001` as an alias in the manifest if needed. |
| S-2 | Account is `jsmith` in terminal sample, `j.smith` in the query sample | `04 §3-4` | Pick one synthetic identity (`j.smith`) everywhere; fictional credit-union employee. |
| S-3 | Query ops list says "SELECT/FROM" but the grammar sample has no SELECT; AND/OR precedence and "AFTER" vs a general time range are undefined | `04 §4` | Define a formal grammar (EBNF) in M3: `FROM`, optional `WHERE` (comparisons, `CONTAINS`, `AND`/`OR`/`NOT`, parentheses, `OR` binds looser than `AND`), `AFTER`/`BEFORE`, `GROUP BY`, `COUNT`, `SORT`, `LIMIT`. Drop `SELECT` for v1 (project columns later). |
| S-4 | Terminal sample references `hosts show HOST-014` and `assets list`, but LAB-001 evidence lists no hosts or assets | `04 §3, §7` | Add a small asset table to the LAB-001 scenario package (employee workstation, member portal, IdP) so every documented command returns data. |
| S-5 | LAB-001 lists 6 events, but adaptive difficulty (`04 §8`) needs noise and decoys; replay needs seeded variation (`04 §9`) | `04 §7-9` | Baseline = the 6 canonical events (always present, ids stable) + a seeded generator for benign noise per difficulty. Scoring uses canonical ids only. |
| S-6 | Scoring needs "correct query and event selection" (20 pts) but a "correct query" is not defined; many queries return the same set | `04 §7` | Score the **result set** the player gathered (evidence ids), not query text. Record queries for feedback only. |
| S-7 | "Distinguishes confirmed facts from hypotheses" (20 pts) has no structure to score | `04 §7`, `03 §6` | Case file entries carry a `kind` (fact / hypothesis / unknown) and evidence ids; rubric checks that conclusions cite ids and that hypotheses are not asserted as facts. |
| S-8 | `00` target layout vs `06 §11` layout vs repo layout | `00`, `06` | Adopt the repo layout plus `scripts/simulation`, `scripts/gameplay`, `scripts/data`; update `00` and `06` in the same change (`CLAUDE.md` already requires this). |
| S-9 | First milestone in `08 §2` includes "The Block exploration"; the slice requested here does not | `08 §2` | Treat Switchboard HQ as the first and only walkable space for Phase 1; defer The Block (decision D-012). |
| S-10 | Spec dates (e.g. NICE v2.2.0 announced 2026-04-28, OWASP GenAI 2026 list) are asserted as verified | `03 §4`, `10` | Out of scope for this audit; re-verify against official sources before any framework mapping is shipped, per `10 §4`. |

## 4. Technical debt register (current code)

| Id | Debt | Severity | Cost to fix |
|---|---|---|---|
| T-1 | core -> ui imports (G-12) | Medium | Small |
| T-2 | Duplicate UI helpers (G-13) | Medium | Small |
| T-3 | Hardcoded slot (G-04, section 1 row 2) | High | Small, with UI |
| T-4 | Input context conflicts (G-10) | Medium | Medium |
| T-5 | Test harness lacks approx/expect-error helpers | Low | Small |
| T-6 | Duplicated integration runner | Low | Small |
| T-7 | Per-message regex compile in diagnostics | Low | Small |

## 5. Security risks

| Id | Risk | State | Mitigation in plan |
|---|---|---|---|
| SEC-1 | Player input reaching a shell/eval (D-006) | No code path today. [V] | Parser kernel M4 with a static test that fails CI if `OS.execute`, `Expression`, `OS.shell_open`, `HTTP*` appear under `scripts/` outside an allowlist. |
| SEC-2 | Malformed or hostile scenario/content JSON crashing the game | No loader yet | Size caps, type checks, schema validation (M1); fuzz tests. |
| SEC-3 | Path traversal via content paths (`scenario_data`, assets) | No loader yet | Resolve only ids from a registry; reject `..`, absolute paths, `user://` and `res://` prefixes in content strings. |
| SEC-4 | Save tampering to forge mastery/portfolio | Possible (integrity checksum only) | Document as accepted offline risk; portfolio labelled "self-recorded"; recompute scores from stored evidence where possible. |
| SEC-5 | Unbounded input (terminal line, query, notes) | No input yet | Length/tokens/result caps in every parser. |
| SEC-6 | Export path writes outside game-owned dir | No exporter yet | Fixed `user://exports/` directory, generated file names only, never player-chosen paths. |

## 6. Performance concerns

- Synthetic datasets for adaptive/advanced difficulty may reach thousands of events. Query engine must be non-quadratic and run off the UI frame budget for large sets (`06 §8` targets are proposals, not measurements). [A]
- UI lists (alert queue, result tables) must be virtualised or paged beyond a few hundred rows; Godot `ItemList`/`Tree` are fine for thousands, per-row `Control` trees are not. [A]
- Saves will grow once case notes and evidence are stored; the 4 MB cap and the triple read are acceptable at LAB-001 scale. [A]

## 7. Platform compatibility concerns

Windows verified; Linux/Deck only through unproven CI. Deck-specific: controller-only text entry (G-07), glyph prompts that switch between Xbox/Deck/keyboard, sleep/resume safety of in-progress cases (autosave checkpoints), and monospace terminal legibility at 1280x720. None can be closed without a real Deck or at least a Linux box with a gamepad. [A]

## 8. Missing content summary

Authored content required for the slice and absent today: LAB-001 scenario package, rubric, hint ladder, glossary entries (about 15-25 terms), briefing and debrief text, intro dialogue (about 3 characters: Nia "Patch" Brooks, Malik "M-Stack" Carter, Auntie Rochelle are the likely cast), HQ environment, SOC dashboard art/tokens, terminal help text, report template, one portfolio template. All must be original and culturally reviewed per `02 §7` (no reviewer is identified in the repo).
