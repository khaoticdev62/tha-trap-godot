# M8 UI system: SOC interface

How the SOC interface is built, what it depends on, and what is still open. Written against the code as of milestone M8. Facts below were checked against the running scenes and the test suite, not assumed.

## 1. Layers

```
Screen scenes (scenes/soc/*.tscn)         presentation only
  scripts/ui/soc/{command_center, investigation, case_management,
                  terminal_screen, mission_learning, design_system}.gd
  shell: scripts/ui/soc/soc_shell.gd      header, navigation, footer, notifications
  base:  scripts/ui/soc/soc_screen.gd     lifecycle, coalesced refresh, scroll/focus
        |  reads state, calls methods
        v
SocModel (scripts/gameplay/soc_model.gd)  no scene tree, no files, no network
        |  changes the case only through
        v
LabSession / TerminalParser / AssessmentEngine   (scripts/simulation, unchanged)
ProgressService (autoload "Progress")            checkpoints after every change
```

Design kit (shared by every SOC screen, nothing else uses it):

| File | Role |
|---|---|
| `scripts/ui/soc_tokens.gd` | colours, severity ids/labels/markers, spacing, radius, border and focus widths, type sizes, motion timings |
| `scripts/ui/soc_theme.gd` | builds the `Theme` from tokens + `AccessibilitySettings` (text scale, high contrast) |
| `scripts/ui/kit/ui_kit.gd` | factory functions: labels, buttons, badges, tables, progress, flow rows, scroll |
| `scripts/ui/kit/soc_card.gd` | titled panel with a `body` column |
| `scripts/ui/kit/cycle_button.gd` | one button that steps through a fixed list (the controller-friendly dropdown) |

Rule kept by test (`tests/security/test_soc_ui_isolation.gd`): UI scripts never run a process, evaluate text, touch files or the network, create or edit simulation events, or enable BBCode.

## 2. Data flow

1. `SocShell._ready` calls `SocModel.open(Progress)`. It loads `lab_001` content (scenario, rubric, hints) and the learning document, then reuses the live `Progress.current_session`, resumes the saved attempt, or starts a new one, in that order.
2. A screen action calls a `SocModel` method (`collect_evidence`, `add_note`, `apply_response`, `run_command`, ...). The model calls `LabSession`, which changes the case and emits `evidence_changed` or `case_changed`.
3. The model reacts to those signals by calling `Progress.checkpoint_lab()` (so the lab survives a save) and emitting `changed`.
4. Every visible screen refreshes once per frame; a hidden screen only marks itself stale and refreshes when shown.
5. Results (success or refusal) go to `SocModel.notified`, which the shell shows in the notification area with a text marker (`OK`, `ERROR`, `INFO`).

The terminal screen sends each line to `SocModel.run_command`, which passes it to the existing allowlisted `TerminalParser`. The screen adds the returned lines with `RichTextLabel.add_text` (plain text, BBCode off).

## 3. Dashboard data source

Alerts are produced by `SocModel.DETECTION_RULES` applied to the synthetic events of the running `LabSession`. A rule looks only at fields a real SIEM would see: source, result, and whether the origin is outside the network. Rules never read an event's tags or its `canonical` flag, because that would reveal which events matter. A test asserts this.

| Rule | Fires on | Severity |
|---|---|---|
| `mfa_change` | any MFA-source event | high |
| `external_portal_access` | app event from an `ext-` origin | high |
| `external_signin` | successful auth from an `ext-` origin | medium |
| `user_report` | help-desk event | medium |
| `failed_signin` | failed auth | low |

Counters, the incident queue (one row per account with alerts; the reported account is CASE-001), the event stream and the network overview all derive from this list. Counts change with difficulty and seed because background noise changes; the story events do not.

## 4. Controller and input

- Focus movement uses Godot's built-in `ui_up/down/left/right` (D-pad and left stick are already bound). Confirm is `ui_accept`, cancel is `ui_cancel`.
- New actions `nav_prev` / `nav_next` (LB/RB, `[` `]`, PageUp/PageDown) switch screens. They are handled once, in `SocShell._unhandled_input`.
- `ui_cancel` moves focus from a screen to the navigation; from the navigation it returns to the title.
- Each screen opens with focus on a control near the top of its page, and the page is scrolled to the top.
- Every control that needs typing has a controller path: terminal sample-command buttons run any example; case notes and filters use a `LineEdit` plus cycle buttons. See open item OI-4.

## 5. Layout rules

- Reference size 1280x800; also checked at 1280x720 and at 100% and 200% text.
- Side-by-side groups use `HFlowContainer` with a minimum width per column, so they stack when there is not enough room (200% text, small windows).
- Tables are `Tree` controls with column widths stored at 100% and scaled by the text scale; a width of 0 means "take the remaining space and wrap". If the window is still too narrow, the table scrolls sideways rather than pushing the screen past the edge.
- Button text wraps only inside fixed-width columns (navigation, sample commands, quiz options); never inside flow rows.
- Colour is never the only signal: severity badges carry a marker and a word, status badges carry `OK/WARN/ERROR/INFO`, progress bars carry a text readout above the bar, objectives use `[x] [~] [ ]`, the active nav item is prefixed `>` and outlined.

## 6. Decisions and open items

| Id | Item | State |
|---|---|---|
| OI-1 | The M8 brief's palette (#10121B ...) differs from the art bible's palette (`Palette`, #100D1B ...). The SOC uses the brief's; the menus still use the art bible's. | Open: reconcile in the art bible (`05 §2`) or migrate the menus. Needs a product decision. |
| OI-2 | No fonts are shipped. Body text uses the engine's default sans; monospace uses system faces (`SystemFont` list with fallbacks); `SocDisplay` is a bold system sans, **not** a pixel face. | Open (gap G-14): choose and license a pixel display face and a bundled mono face per `07 §3`. Until then rendering depends on the player's system fonts. |
| OI-3 | Case status, the preserved-snapshot reference, the audit history and the hint log live in `SocModel` for the current session only. After a save/load the status is re-derived from the restored work (investigating at least); the audit history starts again. | Open: needs a save-schema change (v3) and a migration test. |
| OI-4 | No controller-only text entry for notes or the terminal beyond the sample buttons (risk R-09, decision D-011 partly done). Steam Deck's on-screen keyboard works with `LineEdit`; template phrases are not built. | Open. |
| OI-5 | `QueryEngine` (the SIEM-style typed query language) is not surfaced in a screen. Investigation uses simple filters; the typed language is available in the terminal only through `logs search key=value`. | Open: query workbench with a guided builder. |
| OI-6 | The concept sheet (`05 §10`) is not in the repository, so fidelity to it is unverified. The screens follow the written brief. | Open (risk R-10). |
| OI-7 | `finish_lab` and a debrief screen are not wired; "Review my case" shows the rubric result without recording it. | Belongs to M9. |
| OI-8 | The menu scripts still have their own `_label/_button/_describe` helpers (gap G-13). New screens use `UiKit`; the menus were not migrated. | Open, low risk. |

## 7. How to extend

- New screen: add a script extending `SocScreen` and a one-node scene, then one entry in `SocShell.SCREENS`. Implement `screen_id`, `screen_title`, `screen_context`, `build`, `refresh`, `default_focus`. Read from `SocModel`; add model methods rather than touching `LabSession` from the UI.
- New token: add it to `SocTokens`, give it a role in `SocTheme.scheme_for` if it is a colour, and add a contrast assertion in `tests/unit/test_soc_theme.gd`.
- New detection rule: add a row to `SocModel.DETECTION_RULES` using observable fields only.
