# M8 implementation report: UI kit and SOC dashboard

Scope: the six SOC screens, shared shell, design system, controller focus, tests and documentation, per the M8 brief. Everything stated as done below was run or looked at; things not verified are listed under Known defects and Remaining work.

## 1. Summary

The SOC interface exists as real Godot scenes running over the real simulation. A player opens it from the title menu ("SOC Console"), moves between six screens, filters and selects events, collects evidence, writes notes, applies simulated response actions, runs allowlisted terminal commands, and reads the mission and learning material. Every change goes through `LabSession`, is checkpointed into saved progress, and shows up on every screen. The terminal is the existing sandboxed parser; the interface adds no new way to run anything.

## 1a. Verification status (read this first)

**M8 is built and automatically tested. It is NOT fully verified**, because no physical gamepad or Steam Deck test has been run.

| Question | Answer |
|---|---|
| Automated verification passed? | **Yes.** 353 unit and security tests (74,177 assertions), 6 content documents, 8 integration scenes, all 0 failures. Run on the committed code with `tools\run-tests.ps1`, exit code 0. |
| Manual verification passed? | **No manual test has been run.** None can be claimed. |
| Manual verification pending? | **Yes, all of it.** 81 cases are written and every result is `Not tested`: [`docs/qa/M8_PHYSICAL_CONTROLLER_TEST_PLAN.md`](../qa/M8_PHYSICAL_CONTROLLER_TEST_PLAN.md) and [`docs/qa/M8_MANUAL_TEST_RECORD.md`](../qa/M8_MANUAL_TEST_RECORD.md) (Windows 11 + gamepad, Steam Deck Game Mode, Steam Deck Desktop Mode, keyboard and mouse regression). |
| Specification review completed? | **Yes.** All eleven specs were read in full: [`M8_SPECIFICATION_REVIEW.md`](M8_SPECIFICATION_REVIEW.md). |
| Outstanding defects? | **None open that are known.** Three defects were found by that review and fixed with regression tests (D1 to D3, below). Missing features and spec deviations are listed in the review and in section 7; they are not defects in existing controls. |
| Known platform limitations? | Left-stick behaviour and real mouse clicks could not be simulated headlessly, so they are untested by automation. Nothing has run on a Steam Deck. Fonts depend on the player's system. See section 7. |

### Defects found and fixed after the first report

| Id | Defect | Fix | Regression test (failed before the fix where noted) |
|---|---|---|---|
| D1 | Terminal did not show the banner spec 05 §5 requires | Screen shows `TerminalCommands.BANNER` via `SocModel.terminal_banner()` | `test_soc_model`, `soc_flow` |
| D2 | D-pad Up was swallowed at the oldest history entry, so focus could not leave the command line upward | Up passes through at the oldest entry | `soc_controller` (failed before) |
| D3 | D-pad and stick did not scroll the focused console (the engine scrolls it only for keyboard keys) | Screen scrolls for non-key events and passes them on at either end | `soc_controller` (failed before) |

One content mismatch was also fixed: the career preview now uses spec 03 §2's stage names.

## 2. Screens (all six are scenes that share one theme and shell)

| # | Screen | Scene | What is wired |
|---|---|---|---|
| 01 | Design System | `scenes/soc/design_system.tscn` | palette with hex and measured contrast, type hierarchy, live buttons and states (drawn from the theme), cards, badges, navigation items, a data table, tabs, progress bars, a working dialog (`ModalDialog`), spacing/radius/focus tokens |
| 02 | Command Center | `command_center.tscn` | mission status, alert counters (from detection rules over the live events), incident queue, event stream, network overview with scope markers, analyst activity, objectives (from the rubric review), quick navigation |
| 03 | Investigation | `investigation.tscn` | CASE-001 summary, source/result/text filters, event table, selection, event detail with user, host and MFA context, collect evidence, notes (fact needs cited evidence), link to cases |
| 04 | Case Management | `case_management.tscn` | overview and status, severity, scope toggles, Investigate/Escalate/Contain/Preserve/Recover, evidence locker with remove, timeline, notes with remove, risk and impact, audit history |
| 05 | Terminal | `terminal.tscn` | allowlisted `TerminalParser`, SIMULATED banner, scrollable plain-text console, Up/Down history, sample-command buttons for controller use |
| 06 | Mission & Learning | `mission_learning.tscn` | briefing, community impact, six objectives, eight learning objectives (authentication, MFA, suspicious login patterns, SIEM filtering, evidence handling, timeline reconstruction, incident response, documentation), skill mastery, hints, four knowledge checks, case review, career preview |

Shell (`soc_shell.tscn`): persistent navigation, title and context, status badges (synthetic data, alert count, case status), notification area with text markers, controller legend, consistent margins.

## 3. Files

Created:
- Scripts: `scripts/gameplay/soc_model.gd`; `scripts/ui/soc_tokens.gd`, `scripts/ui/soc_theme.gd`; `scripts/ui/kit/{ui_kit,soc_card,cycle_button}.gd`; `scripts/ui/soc/{soc_shell,soc_screen,command_center,investigation,case_management,terminal_screen,mission_learning,design_system}.gd`
- Scenes: `scenes/soc/{soc_shell,command_center,investigation,case_management,terminal,mission_learning,design_system}.tscn`
- Data: `data/missions/mission_lab_001_learning.json`
- Tests: `tests/unit/test_soc_model.gd`, `tests/unit/test_soc_theme.gd`, `tests/security/test_soc_ui_isolation.gd`, `tests/integration/soc_flow.{gd,tscn}`
- Docs: `docs/architecture/M8_UI_SYSTEM.md`, this report

Modified:
- `scripts/core/scene_flow.gd` (registers `soc`), `scripts/ui/title_menu.gd` ("SOC Console" button), `scripts/platform/input_actions.gd` (`nav_prev`, `nav_next`), `scripts/data/content_catalog.gd` (learning schema, registration, cross-checks), `tools/visual/capture.gd` (17 SOC captures), `CHANGELOG.md`, `README.md`

## 4. Commands run and results

| Command | Result |
|---|---|
| `tools\run-tests.ps1` | exit 0 |
| (unit + security) `godot --headless -s tests/run_tests.gd` | **353 tests, 74,177 assertions, 0 failures** (313 before M8; 40 added) |
| (content) `tools/content_validator/validate.gd` | **6 documents checked, 0 problems** (5 before; the learning document is the sixth) |
| (integration) 8 scenes: creator, dialogue, save slots, settings, **soc_controller**, **soc_flow**, title | all 0 failures |
| `godot --path . res://tools/visual/capture.tscn -- --out=<dir>` (windowed) | 17 SOC screenshots rendered and inspected |
| Godot MCP `run_project` on `soc_shell.tscn`, `get_debug_output` | scene ran; no errors; no warnings from new files after two shadowing warnings were fixed; the remaining warnings are the older ones in `scripts/simulation/` and `progress_service.gd` |

`soc_flow` drives the real shell: navigation (buttons, `nav_next`/`nav_prev` wrap, unknown ids refused); dashboard counters equal the model's; the header badge and notification follow a collect action; queue activation opens the investigation filtered to the account; filters, empty results, selection, collect, fact with and without evidence; all five response actions in order including refusals; terminal commands, hostile input (`rm -rf /`, `powershell`, `help; whoami`, `../` paths, pipes, `$(...)`, `[b]` markup), history recall, sample buttons, bounded output; hint, quiz feedback, review; focus on every screen; save, clear, load and resume. A guard fails the run unless all 11 steps finish, because a script error aborts a step silently (found when a type error printed "0 failures").

## 5. Controller results

**Automated (headless), event level.** `tests/integration/soc_controller` feeds the real events a gamepad produces (Joypad Button 0, 1, 9, 10, 11, 12) through Godot's normal input path and checks the result. Passing: D-pad Up/Down moves focus between navigation items and moves table selection; A activates the focused navigation item; RB and LB switch screens and wrap; B moves focus from a screen to the navigation and from the navigation to the title; a typed `[` does not switch screens while a text field has focus, and RB/LB still do; D-pad Up/Down recall terminal history and Up at the oldest entry leaves the field; D-pad scrolls the focused console and Up at the top does not hold focus; the dialog opens on A, starts on the safe choice, traps focus, closes on B and returns focus; returning to a screen focuses its default control. The configured InputMap is also asserted: D-pad buttons, Left Stick axes, A, B, LB, RB and a 0.50 stick dead-zone. `soc_flow` additionally checks default focus on every screen, no focus traps, a complete tab order, and that the terminal is operable without typing through the sample buttons.

**What this is not.** These are synthetic events, not a controller. They show the bindings reach the controls; they do not show how a pad or a Deck feels or behaves.

**Not verified by automation:** left-stick navigation (synthetic stick events did not register even on stock focus movement, so no assertion was made), real mouse clicks, controller hot-plug, sleep and resume, Steam Input layouts, and the on-screen keyboard.

**Manual:** pending. See the test plan and the record linked in section 1a.

## 6. Resolution and scale results

Automated layout checks (headless) at 1280x800 and 1280x720, each at 100% and 200% text, on all six screens: the page is never wider than its scroll area, nothing is laid out past the window's right edge, no button or text field has a degenerate size, and no label or button runs off the right edge. Windowed captures at 1280x800, 1280x720, 200% text and high contrast were looked at.

Found by looking at renders rather than by the first tests, and fixed: clipped table columns, a column pushed off the right edge of Case Management, progress text unreadable over the fill (white on cyan, about 1.6:1), screens opening scrolled to the middle, header badges wrapping into a tall stack, invisible palette swatches. The layout test was tightened afterwards so these classes of fault now fail a test.

**Not done:** no 1366x768, 1920x1080 or ultrawide check; no Steam Deck hardware. Reading smallest text (14 to 16 px) on the Deck screen is test RES-05.

## 7. Known defects and limits

1. At 200% text, tables scroll sideways rather than fitting; the page itself never does.
2. The `SocDisplay` heading style is a bold system sans, not pixel-art type (open item OI-2). Text rendering depends on the player's installed fonts.
3. Case status, audit history, preserved-snapshot reference and hint log are not saved (OI-3). After loading, status is re-derived from restored work and history restarts.
4. The Continue button still reports that the world map is not built; the SOC opens from its own title button.
5. The timeline's Detail column wraps onto several lines at 1280x720 (readable, not elegant).
6. Alert counts vary with difficulty and seed (noise); the story alerts are constant.
7. The SOC has no animation, so reduced motion has nothing to disable; the notification simply replaces its text.
8. Palette conflict between the brief and the art bible is unresolved (OI-1); fidelity to the missing concept sheet is unverified (OI-6).

Missing features and deviations found by the specification review (not defects in existing controls; full table in `M8_SPECIFICATION_REVIEW.md`):

9. **No UI to write the report summary.** It can only be set with `case report CASE-001 "text"` in the terminal, so a controller-only player cannot earn that rubric criterion without a platform keyboard.
10. **No autosave.** The SOC checkpoints into saved progress in memory, but nothing writes a save file; progress is lost on quit unless another route saves it. There is no pause or save menu yet.
11. No "reset lab" action in the SOC (the simulation supports it).
12. No remappable controls, no glossary, no per-device controller glyphs (the legend is text), no named mastery levels.
13. The SOC dashboard layout follows the M8 brief, not the layout in spec 05 §5.
14. The Design System screen is a developer QA reference whose sample buttons only show a notification; decide whether it ships in a release build.

## 8. Security findings

- A static scan (`test_soc_ui_isolation.gd`) over every SOC script and the model forbids `OS` process/shell calls, `Expression`, file and network classes, reflection, simulation-event edits and BBCode. It passes. It is a scan, not a proof, and was not mutation-tested by planting violations the way the simulation scan was.
- The terminal screen contains no parsing: lines go to `SocModel.run_command` and then `TerminalParser`. Hostile inputs listed in section 4 are refused with an explanation and echoed as literal text.
- Detection rules do not read answer-bearing fields (a test checks the source for `tags` and `canonical`).
- Shell navigation accepts only registered screen ids.
- No new dependencies, no network use, no telemetry.

## 9. Performance findings

Screens are built once and kept; hidden screens do not refresh; refreshes are merged to one per frame. Not measured: frame time, memory, and scene load time. No profiling was done, so no performance claim is made. The integration scene, including layout passes over six screens at four size/scale combinations, finishes inside its 60 s watchdog (the exact time was not recorded).

## 10. Remaining integration dependencies and future work (not part of this milestone)

- Save schema v3 for case status, audit history and hint log (OI-3).
- Query workbench using `QueryEngine` with a guided builder (OI-5); controller text entry with template phrases (OI-4).
- Fonts: choose, license and register a pixel display face and a bundled mono face (OI-2).
- Concept sheet and palette reconciliation (OI-1, OI-6).
- Debrief and `finish_lab` (M9); HQ hub and dialogue (M9).
- Hardware pass: real gamepad and Steam Deck at 1280x800 and 1280x720.
- Migrate the older menu screens to `UiKit` (OI-8).
