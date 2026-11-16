# M8 specification review

Reviews the M8 SOC interface against the eleven production specifications. All eleven were read in full for this review (`docs/spec/00` to `10`; `INDEX.md` only lists them). The baseline is commit `683150e` plus the three fixes made during this review (section 3).

**Status words used, and what each needs:**
- **Compliant**: the requirement is met and the evidence column names a test, a file, or something that was observed. Nothing is marked compliant on intent.
- **Partial**: some of it is met; the deviation column says what is not.
- **Deviation**: the code does something different from the spec. The reason is given.
- **Pending hardware**: can only be settled on a physical controller or Steam Deck. Not claimed.
- **Outside M8**: the requirement belongs to another milestone; listed so it is not lost.
- **Unverified**: no evidence either way.

Evidence names: `unit` = `tests/unit/test_soc_*.gd`, `iso` = `tests/security/test_soc_ui_isolation.gd`, `flow` = `tests/integration/soc_flow`, `ctl` = `tests/integration/soc_controller`, `shots` = the windowed captures from `tools/visual/capture.tscn`, which I looked at.

## 1. Review table

| Document | Requirements relevant to M8 | Implementation evidence | Status | Outstanding deviations |
|---|---|---|---|---|
| **00 Charter** | P2: defensive, authorized, no live targeting | All data synthetic and labelled; `iso` forbids process/file/network APIs in SOC code | Compliant | none |
| | P4: plain English before acronyms | Learning text defines MFA, SIEM, evidence in plain words (`mission_lab_001_learning.json`) | Partial | Header and screen titles say "SOC" and "SIEM" before the learning screen defines them. No glossary (see 05). |
| | P7: no job-readiness or certification claim | Career preview caption: "not a qualification or a promise of a job" (`shots`: mission) | Compliant | none |
| | P8: offline, no telemetry | No network classes in SOC code (`iso`); no new dependency | Compliant | none |
| | P9: fully playable with a controller | `ctl`: D-pad, A, B, LB, RB drive focus, selection, screen switching, dialogs; `flow`: no focus traps | Partial / Pending hardware | Left stick, real hardware, and text entry are unverified. Writing the report summary needs a keyboard (see 04). |
| | P10: no placeholder or fake functionality in release | Every SOC control calls the model; no stub screens | Partial | The Design System screen's sample buttons only show a notification. It is a QA reference; decide whether it ships in a release build. |
| | D-006: no unrestricted shell | `iso`; terminal safety suite (existing); `flow` hostile-input list | Compliant | none |
| | D-008 / D-010: `j.smith`; evidence-id scoring | Case account is `j.smith`; mastery is the rubric review (`unit`: objectives follow the rubric) | Compliant | none |
| | D-011: controller-only text entry | Terminal sample-command buttons run any example (`ctl`, `flow`); filters are cycle buttons | Partial | Case notes, the filter text and the terminal command line still need typing. No token builder or template phrases. |
| | Release definition: Deck controls and text verified | `shots` at 1280x800 and 1280x720; automated layout checks | Pending hardware | Not verified on a Steam Deck. |
| **01 Game Bible** | Core loop steps 4, 5, 7, 8 (investigate, decide, validate, reflect) | Investigation, Case Management, knowledge checks, case review (`flow`) | Partial | Steps 1 to 3 and 6 (hear, frame, communicate) are other milestones. |
| | Evidence-led: facts must cite evidence | `CaseFile` refuses a fact without evidence; UI refusal shown (`flow`) | Compliant | none |
| | XP is never a substitute for assessment | Knowledge checks never change mastery (`unit`, `flow`) | Compliant | none |
| | Consequence model (trust, availability, ...) | Not built | Outside M8 | No consequence meters. |
| | No timed response for core objectives | No timers except the 4 s notification text reset | Compliant | none |
| **02 Story** | Name and setting: New Meridian, Market Row | Header and overview use "New Meridian"; briefing names Market Row Community Credit Union | Compliant | none |
| | Mission template fields (hook, affected people, ..., debrief, portfolio artifact, accessibility notes) | Briefing, community impact, objectives, hints are shown | Partial | Framework mappings, debrief, portfolio artifact and accessibility notes are not shown on the screen. |
| | Dialogue and cultural representation rules | Briefing written plainly with no slang; no review by local readers | Unverified | The spec requires cultural review. None has happened. |
| **03 Curriculum** | Career pathway stage names | Career preview now uses the spec's names: Stage 2 SOC Foundations, 3 Endpoint & Identity Defense, 4 Threat Hunting & IR (changed in this review) | Compliant | none |
| | Four-part assessment (concept, tool, evidence reasoning, communication) | Concept: knowledge checks. Tool and reasoning: rubric review. Communication: report summary | Partial | The report summary can only be written in the terminal (see 04). |
| | Do not award independent mastery from multiple choice | Mastery comes only from the rubric (`unit`, `flow`) | Compliant | none |
| | Mastery levels (Introduced ... Applied in a new context) | UI shows a percentage and per-objective bars | Deviation | The five named levels are not shown. |
| | Framework source and version visible | Manifest `framework_mappings` is empty; nothing shown | Outside M8 | No framework data exists yet. |
| **04 Lab spec** | Allowlisted terminal, no host access, `../` rejected, no network, no eval | Existing parser and safety suite; `iso`; `flow` hostile list (`rm -rf /`, `powershell`, `help; whoami`, `../`, pipes, `$(...)`, markup) | Compliant | none |
| | Example commands (help, assets list, hosts show, logs search, timeline build, evidence add, case note, case report) | All eight run (`flow`, `unit`); palette offers seven (not `case note`) | Compliant | The spec's `user=jsmith` finds nothing because the synthetic account is `j.smith` (D-008). The palette uses `j.smith`. |
| | Interaction modes: visual, terminal, query, case file, assessment | Visual, terminal, case file and assessment are built | Partial | The SIEM query language has no screen (open item OI-5). |
| | Evidence tasks and ticket: "write a ticket" | Evidence, notes, severity, scope, escalation and containment choice are in the UI | Deviation | **There is no UI to write the report summary**, only `case report CASE-001 "text"` in the terminal. A controller-only player cannot earn the report criterion. Not fixed here: it is a missing feature, not a defect in an existing control. |
| | Reset and replay (§9): a reset action | `LabSession.reset()` exists and is tested at the simulation level | Deviation | The SOC offers no "reset lab" action. |
| | Hints by difficulty; critical-error coaching | `HintLadder`, review output (`flow`, `unit`) | Compliant | The guided query builder for beginners is not built. |
| **05 UI/UX** | Palette (Obsidian #100D1B ...) | SOC uses the M8 brief's palette (#10121B ...); contrast tested (`unit`) | Deviation | Two palettes now coexist (OI-1). Needs a decision. |
| | SOC dashboard layout: top bar (case, time, environment, connection), left alert rail, centre timeline, right evidence rail, bottom action tabs | Header with case status, synthetic badge, alert count; left navigation; card grid | Deviation | Layout follows the M8 brief, not this spec. No clock or connection state. |
| | Terminal: large mono font, prompt/output separation, history, help, palette | `shots`: terminal; `flow`; `ctl` | Compliant | none |
| | Terminal: always show "SIMULATED ENVIRONMENT - NO HOST COMMANDS" | Now shown in the banner; `flow` and `unit` check the exact text | Compliant | Fixed in this review (defect D1). |
| | Terminal on Deck: virtual keyboard, controller token editing | Sample buttons; Steam keyboard untested | Partial / Pending hardware | No token editing. |
| | Typography: open-license pixel face for headings | Bold system sans stands in | Deviation | No pixel face shipped (OI-2). |
| | Motion: reduced-motion mode | The SOC has no animation; notification text simply replaces itself | Compliant | Nothing to reduce. |
| | Accessibility: full navigation without mouse | `flow` (no traps, full tab order), `ctl` (event level) | Partial / Pending hardware | Hardware unverified. |
| | Accessibility: adjustable text scale and contrast | 100% and 200% text, high contrast (`flow`, `shots`, `unit`) | Compliant | none |
| | Accessibility: colour-blind-safe redundant indicators | Severity: marker plus word. Status: `OK/WARN/ERROR/INFO`. Objectives: `[x] [~] [ ]`. Nav: `>` plus outline (`unit`, `flow`) | Compliant | none |
| | Accessibility: remappable controls | No remap UI | Deviation | Not built (gap G-10). |
| | Accessibility: glossary available everywhere | No glossary | Deviation | Not built. |
| | Steam Deck: 1280x800 and 1280x720; text at least 9 px, 12 recommended | Layout checks at both sizes; smallest text is 14 px (`unit`: font floor); `shots` | Compliant (headless) / Pending hardware | Real Deck screen not checked. |
| | Steam Deck: all content via default physical controls | `ctl` at event level | Pending hardware | |
| | Concept sheet fidelity (§10) | The six-screen sheet is not in the repository | Unverified | Risk R-10. |
| | Screen inventory 9, 10, 15, 16, 17, 18 | Dashboard, alert queue, evidence and timeline, response panel, terminal, knowledge check exist | Partial | No SIEM workbench (11), network topology (13), identity console (14), debrief (19), pause menu (22). Outside M8 or open. |
| **06 Architecture** | UI never mutates simulation data directly | Only `SocModel` calls `LabSession`; `iso` forbids `EventStore` edits and `.store.add/remove` in UI | Compliant | none |
| | Typed signals; no giant singleton | `SocModel.changed/notified`; no new autoload | Compliant | none |
| | Event flow through the EventBus | SOC listens to `LabSession` signals and `Progress`, not the EventBus | Deviation | Minor; the bus is not yet used for evidence events. |
| | Save: autosave after checkpoints | The SOC checkpoints into `Progress` (`unit`, `flow`: save and resume) but writes no save file | Deviation | Progress is lost on quit unless saved by another path. There is no pause or save menu yet. This matters for real play. |
| | Content pipeline validates data | Learning document has a schema and cross-checks; validator reports 0 problems | Compliant | none |
| | Security §10, no eval, file access limited | `iso` | Compliant | none |
| | Performance targets | None measured | Unverified | Targets are proposals; no frame, memory or load measurement was taken. |
| | Folder layout (D-013) | `scripts/ui/soc`, `scripts/ui/kit`, `scripts/gameplay/soc_model.gd`, `scenes/soc/` | Compliant | none |
| **07 Assets** | Only licensed assets; unknown licence blocks release | No assets shipped. Fonts come from the player's system; nothing is bundled | Compliant | Depending on system fonts is a risk (OI-2), not a licence breach. |
| | Audio accessibility; nothing by sound alone | No sound | Compliant | none |
| **08 Roadmap, QA** | QA layers: unit, integration, accessibility, compatibility | Unit, security and integration pass; accessibility partly automated | Partial | Compatibility on Deck Game and Desktop Mode pending. |
| | Acceptance: every screen navigable by controller | See 05 | Partial / Pending hardware | |
| | Acceptance: Deck text readable at both sizes | `shots`, layout checks | Pending hardware | |
| | Acceptance: no critical mission depends on colour alone | See 05 | Compliant | none |
| | Acceptance: no certification or job claims | See 00 | Compliant | none |
| | Release checklist: Deck controls, text, accessibility settings | | Pending hardware | |
| **09 Prompt pack** | Prompt 3: tokens, components, focus system, scalable text, reduced motion | `SocTokens`, `SocTheme`, `UiKit`; `flow`, `ctl` | Partial | A tooltip component exists only as `tooltip_text`. No pause screen (other milestone). |
| | Prompt 11: glyph correctness for the controller | A text legend: "A / Enter, B / Esc, LB RB" | Deviation | No per-device glyphs. |
| | Prompt 11: sleep and resume, on-screen keyboard, trackpad cursor | | Pending hardware | |
| | Global contract: inspect, plan, implement, test, review, summarize; no invented results | M8 report and this review | Compliant | |
| **10 Research** | Source-use and IP: original text, no third-party content | All SOC and learning text is original (`mission_lab_001_learning.json`) | Compliant | none |
| | Framework facts | M8 uses none | Outside M8 | |

## 2. What this review found

1. Three verified defects in the shipped M8 code, all now fixed with tests (section 3).
2. One verified content mismatch (career stage names), fixed.
3. Gaps that are missing features rather than defects, not fixed here and listed so they are decided on purpose: no report-summary field in the UI, no lab reset action, no autosave, no mastery level names, no glossary, no remapping, two palettes.
4. Everything involving physical hardware is pending. No row above claims otherwise.

## 3. Defects fixed during this review

| Id | Defect | Cause | Fix | Regression test |
|---|---|---|---|---|
| D1 | The terminal never showed the banner spec 05 §5 requires; the exact text appeared only inside `help` | The screen used its own wording | `SocModel.terminal_banner()` returns the parser's constant; the screen shows it | `unit`: banner text; `flow`: a visible label has that exact text |
| D2 | In the terminal's command line, D-pad Up was consumed even at the oldest history entry, so focus could not move up out of the field | The history handler always called `accept_event` for Up | Up is passed through when already at the oldest entry | `ctl`: Up at the oldest entry leaves the field. It failed before the fix. |
| D3 | D-pad and stick Up/Down did not scroll the focused terminal console, though keyboard Up did | The engine's `RichTextLabel` scrolls only for key events | The screen scrolls for non-key events and passes the event on at the top or bottom, so focus is never held | `ctl`: Up scrolls the console, Down scrolls back, the console can be left. It failed before the fix. |

## 4. Not fixed on purpose

Nothing in section 3's "missing features" was built, because the brief for this task limits fixes to verified defects. Each is a candidate for a later milestone; none blocks the manual hardware pass.
