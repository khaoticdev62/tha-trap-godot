# M8 physical controller test plan
Status: **ready to run. No physical hardware has been used.** Everything in `tests/integration/soc_controller` is event-level automation (synthetic input events fed through Godot's normal input path). It is useful evidence that the mappings reach the controls, and it is **not** a substitute for the tests below.

Companion files: results go in [`M8_MANUAL_TEST_RECORD.md`](M8_MANUAL_TEST_RECORD.md); the review that produced the plan is [`../production/M8_SPECIFICATION_REVIEW.md`](../production/M8_SPECIFICATION_REVIEW.md).

## 1. What the project actually binds

Read from the running engine after `InputActions.register()` (a dump of the real InputMap), not from documentation. Godot's own names for the buttons are given with the common labels.

| Purpose | Action | Keyboard | Gamepad |
|---|---|---|---|
| Move focus | `ui_up` `ui_down` `ui_left` `ui_right` | Arrow keys | D-pad (Joypad Button 11, 12, 13, 14) and Left Stick (axis 1 for up/down, axis 0 for left/right), dead-zone 0.50 |
| Confirm | `ui_accept` | Enter, Keypad Enter, Space | Joypad Button 0 (Bottom Action: Xbox A, Sony Cross) |
| Cancel / back | `ui_cancel` | Escape | Joypad Button 1 (Right Action: Xbox B, Sony Circle) |
| Previous screen | `nav_prev` | `[`, PageUp | Joypad Button 9 (Left Shoulder: Xbox LB, Sony L1) |
| Next screen | `nav_next` | `]`, PageDown | Joypad Button 10 (Right Shoulder: Xbox RB, Sony R1) |
| Focus next / previous | `ui_focus_next` / `ui_focus_prev` | Tab / Shift+Tab | not bound |
| Pause | `open_pause` | Escape | Joypad Button 6 (Start) |
| Not used by the SOC | `ui_select` (Y or Space), `interact`, `move_*`, `open_map`, `open_glossary` | | |

Notes that matter when testing:
- **Start does nothing in the SOC.** There is no pause menu yet.
- **PageUp and PageDown are bound to screen switching and are also used by tables and the console** for their own scrolling. Inside a table, the console or a text field the control keeps its own meaning; the shoulder buttons always switch screens.
- **Steam Deck:** in Game Mode, Steam Input decides what the game receives. Record the layout that was active. The project's bindings above assume the game receives standard gamepad buttons (A, B, bumpers, D-pad, left stick); whether the Deck's default layout does that for this game is something to confirm on the device, not assumed here.
- **Tab and Shift+Tab** are keyboard-only.

## 2. What each screen focuses when it opens

From the code (`SocScreen.default_focus`); each is a control near the top of its page.

| Screen | Opens focused on |
|---|---|
| Command Center | the 'Open investigation' button |
| Investigation | the 'Source: All' filter button |
| Case Management | the 'Severity' button |
| Terminal | the command line (text field) |
| Mission & Learning | the 'Ask for a hint' button |
| Design System | the 'Default' button |

A screen always opens on its default control. It does not remember where focus was the last time (test RST-01 records this on purpose).

## 3. How to run

1. Get a build of the commit under test (`git rev-parse --short HEAD`). Write it in the record header.
2. Start the game. Open **SOC Console** from the title menu.
3. Work through the cases for your platform in order. For each, follow the action sequence exactly and compare to the expected result.
4. Record **Pass**, **Fail** or **Not tested**. Write what actually happened in the Actual column even when it passes. Never leave a failed case without a defect id.
5. Take a screenshot as evidence for each fail and for these cases: FOC-01, DLG-03, SCR-02, RES-03, RES-05. Windows: Win+PrtSc. Steam Deck: Steam button + R1. Save screenshots next to the record and put the file name in the Evidence column.
6. Defect ids: `M8-D-NNN`, starting at 001. Add each to the Defects section of the record with steps and a screenshot.
7. When every applicable case has a result, the record's sign-off section can be completed. Until then M8 stays **not fully verified**.

## 4. Test areas and what they prove

| Area | Cases | Proves |
|---|---|---|
| Initial focus | FOC | Each screen opens with a visible, sensible focus |
| D-pad | DPD | Directional navigation reaches and leaves every control |
| Left stick | STK | The stick works as well as the D-pad and does not drift |
| Confirm and cancel | CNF | A activates, B goes back, Start does nothing |
| LB / RB | SHD | Screen switching works everywhere, including with a text field focused |
| Focus between panels | PNL | Multi-column and stacked layouts are navigable |
| Scrolling | SCR | Tables, the console and long pages scroll by controller and never trap focus |
| Dialog | DLG | Dialog opens, traps focus, closes and restores focus |
| Button activation | BTN | Actions fire once and report their result |
| Focus restoration | RST | Focus behaves predictably after returning, dialogs, sleep |
| Disconnect / reconnect | DIS | Hot-plug and layout changes do not break the game |
| Text field active | TXT | Typing, history and the platform keyboard work without trapping focus |
| Simultaneous input | MIX | Mouse, keyboard and controller can be mixed |
| Resolution and readability | RES | 1280x800, 1280x720, 200% text, high contrast |
| Keyboard and mouse | KBM | Regression: nothing for keyboard and mouse broke |
| End to end | E2E | A whole investigation, and where a controller-only player gets blocked |

## 5. Cases

Applies to: A = Windows 11 + gamepad, B = Steam Deck Game Mode, C = Steam Deck Desktop Mode, D = keyboard and mouse regression. In Desktop Mode (C) the pad cases only apply if Steam Input presents a gamepad to the game; record the layout, and mark pad cases Not tested with that reason otherwise.

| ID | Area | Starting screen | Action sequence | Expected result | Applies | Automated evidence so far |
|---|---|---|---|---|---|---|
| FOC-01 | Initial focus | Title > SOC Console | Open the SOC. Do not touch any input. | Command Center is open. A thick outline is on the 'Open investigation' button. The page is at the top. | ABCD | ctl/flow: default focus on every screen |
| FOC-02 | Initial focus | Command Center | Press RB once. | Investigation opens. Outline is on the 'Source: All' button. Page at the top. | ABC | flow: default focus |
| FOC-03 | Initial focus | Investigation | Press RB once. | Case Management opens. Outline is on the 'Severity' button. | ABC | flow: default focus |
| FOC-04 | Initial focus | Case Management | Press RB once. | Terminal opens. The caret is in the command line and the outline is on it. | ABC | flow: default focus |
| FOC-05 | Initial focus | Terminal | Press RB once. | Mission & Learning opens. Outline is on 'Ask for a hint'. | ABC | flow: default focus |
| FOC-06 | Initial focus | Mission & Learning | Press RB once. | Design System opens. Outline is on the 'Default' button. | ABC | flow: default focus |
| DPD-01 | D-pad | Command Center, focus on 'Command Center' in the left navigation | Press D-pad Down 6 times, then Up 6 times. | Focus visits Command Center, Investigation, Case Management, Terminal, Mission & Learning, Design System, then 'Back to title'. Up reverses it. Each step moves exactly one item. | ABC | ctl: D-pad Down/Up between nav items |
| DPD-02 | D-pad | Investigation, focus on the events table | Press D-pad Down 5 times, then Up 5 times. | The selected row moves one row per press and the 'Selected event' panel updates each time. Up returns to the first row. | ABC | ctl: D-pad moves table selection |
| DPD-03 | D-pad | Investigation, focus on 'Source: All' | Move through the screen with the D-pad only: filters, table, Selected event panel, notes row, cite toggle, 'Open case management'. Then return to the navigation. | Every control on the screen can be reached and left. Record any control that cannot be reached or any place where focus cannot leave. | ABC | flow: no focus traps; tab order complete |
| DPD-04 | D-pad | Case Management, focus on 'Severity' | Using Left, Right, Up and Down only, reach every control: severity, four scope toggles, Investigate, Escalation, Escalate, Response, Contain, Preserve evidence, Recover, the evidence table and Remove, the timeline, the notes table and Remove, 'Add notes in investigation'. | Every control is reachable and focus can come back to the navigation. Record any that is not. | ABC | flow: no focus traps; tab order complete |
| DPD-05 | D-pad | Case Management, focus on the 'Severity' button | Press D-pad Left, then Right. | Focus moves to a neighbouring control or stays. The Severity value does NOT change (only A changes it). | ABC | none |
| DPD-06 | D-pad | Terminal, caret in the command line with text typed | Press D-pad Left and Right. | Left and Right move the caret inside the text. They do not move focus. Record what happens at the first and last character. | ABC | none |
| STK-01 | Left stick | Command Center, focus on the first nav item | Push the left stick down 6 times (return to centre each time), then up 6 times. | Same visit order as DPD-01, one item per push. No skipped items. | ABC | NOT covered: synthetic stick events did not register in headless tests, so this is unverified by automation |
| STK-02 | Left stick | Investigation, focus on the events table | Hold the stick down for 2 seconds, then release. Hold it up for 2 seconds, then release. | The selection moves down while held, repeating at a readable rate, and stops on release. Record the repeat rate and whether it overshoots. | ABC | NOT covered by automation |
| STK-03 | Left stick | Any screen | Leave the stick untouched for 60 seconds. Then push it diagonally and release. | No focus movement from a resting stick (no drift). Diagonal pushes move focus in one direction, not both. Record the controller's rest value if drift occurs. | ABC | ctl: configured dead-zone is 0.50 (config only) |
| CNF-01 | Confirm and cancel | Command Center, focus on 'Investigation' in the navigation | Press A. | Investigation opens. | ABC | ctl: A on a nav item opens the screen |
| CNF-02 | Confirm and cancel | Case Management, focus on the 'Severity' button | Press A five times. | The value steps Not set, Low, Medium, High, Critical, then back to Not set (setting a real level shows a severity badge in the header area of the overview). | ABC | none |
| CNF-03 | Confirm and cancel | Case Management, focus on an 'Assets in scope' toggle | Press A twice. | The toggle switches on then off. Switching the last asset off is refused with a message in the notification area. | ABC | none |
| CNF-04 | Confirm and cancel | Investigation, focus inside the screen | Press B. | Focus moves to the 'Investigation' navigation item. The screen does not change. | ABC | ctl: B moves focus from a screen to its nav item |
| CNF-05 | Confirm and cancel | Investigation, focus on the navigation | Press B. | The game returns to the title screen. | ABC | ctl: B on the navigation requests the title |
| CNF-06 | Confirm and cancel | Investigation, focus on a table row | Press A. | The row stays selected and nothing else changes. | ABC | ctl: A on a row keeps the selection |
| CNF-07 | Confirm and cancel | Any screen | Press Start (the Menu/+ button). | Nothing happens (there is no pause menu yet). Record anything that does. | ABC | Start is bound to open_pause; no pause menu exists |
| SHD-01 | LB / RB | Command Center | Press RB six times. | Screens open in order: Investigation, Case Management, Terminal, Mission & Learning, Design System, then Command Center (wraps). | ABC | ctl: RB opens the next screen |
| SHD-02 | LB / RB | Command Center | Press LB once, then LB again. | Design System opens (wrap), then Mission & Learning. | ABC | ctl: LB wraps to the last screen |
| SHD-03 | LB / RB | Investigation, with a row selected and a filter set | Press RB then LB. | On return the filter and the selected event are still set (view state is kept). | ABC | flow: filter state kept in the model |
| SHD-04 | LB / RB | Terminal, caret in the command line | Press RB, then LB. | The screens switch even though a text field had focus. The field is not typed into. | ABC | ctl: RB and LB switch screens while the field is focused |
| SHD-05 | LB / RB | Any screen | Press RB and LB alternately as fast as possible for 10 seconds. | No crash, no stuck or duplicated screen, header and navigation always agree on the current screen. | ABC | none |
| PNL-01 | Focus between panels | Mission & Learning | Use the D-pad to move down the left column, across to the middle column and the right column, and to the quiz options. | Focus can reach every column. The page scrolls so the focused control is on screen. | ABC | flow: page fits width; follow_focus enabled |
| PNL-02 | Focus between panels | Command Center at 100% text | Use the D-pad to reach: the four quick-navigation buttons, the incident queue, the event stream, the network table. | Each table can be entered and left. The page scrolls to keep the focused table in view. | ABC | none |
| PNL-03 | Focus between panels | Any screen at 200% text | Repeat DPD-03 or DPD-04 on one screen. | Layout stacks into one column. Order is still logical (top to bottom). No control is cut off. | ABC | flow: layout at 200% |
| SCR-01 | Scrolling | Investigation, events table (24 or more rows) | Focus the table. Press D-pad Down until past the last visible row. | The table scrolls so the selection stays visible. The last row can be reached. | ABC | ctl: D-pad moves table selection |
| SCR-02 | Scrolling | Terminal, after running 'help' several times | Focus the console (the output area, not the input). Press D-pad Up, then Down. | The console scrolls up and back down by about a quarter of a page per press. Focus stays on the console. | ABC | ctl: D-pad scrolls the focused console (fixed in this review) |
| SCR-03 | Scrolling | Terminal, console focused | Scroll to the very top, then press Up again. Scroll to the bottom, then press Down again. | Up at the top and Down at the bottom do not scroll further and do not trap focus; Left and Down/Right still lead out of the console. | ABC | ctl: Up at the top does not scroll; neighbours exist |
| SCR-04 | Scrolling | Any long screen (Mission & Learning) | Move focus to controls below the fold using the D-pad. | The page scrolls to keep the focused control visible. Record any control that scrolls off screen. | ABC | flow: follow_focus |
| SCR-05 | Scrolling | Command Center at 200% text | Focus the incident queue. Press D-pad Right. | If columns are wider than the table, the table scrolls sideways. Record whether this is discoverable and whether a controller can do it. | ABC | Known limitation: tables scroll sideways at 200% text |
| SCR-06 | Scrolling | Terminal | Press D-pad Up repeatedly in the command line after running 4 commands. | Recalls commands newest to oldest. At the oldest entry the next Up leaves the field (does not trap focus). | ABC | ctl: Up recalls; Up at the oldest leaves (fixed in this review) |
| DLG-01 | Dialog | Design System | Focus 'Open sample dialog' and press A. | A dialog opens over the screen. | ABC | ctl: A opens the dialog |
| DLG-02 | Dialog | Dialog open | Look at the focus. | Focus is on 'Cancel' (the safe choice). | ABC | ctl: starts on the safe choice |
| DLG-03 | Dialog | Dialog open | Press D-pad Up, Down, Left and Right repeatedly. | Focus moves only between the two buttons. It never reaches the screen behind. | ABC | ctl: focus stays inside the dialog |
| DLG-04 | Dialog | Dialog open | Press B. | The dialog closes. Focus returns to 'Open sample dialog'. The screen shows 'Dialog result: cancelled.' | ABC | ctl: B closes; focus returns |
| DLG-05 | Dialog | Dialog open | Move to 'Confirm' and press A. | The dialog closes. The screen shows 'Dialog result: confirmed.' Focus returns to the opener. | ABC | none |
| BTN-01 | Button activation | Case Management | Press A on each of Investigate, Escalate, Contain, Preserve evidence, Recover in turn (set Escalation and Response first). | Each one updates the case status badge and adds a row to the Audit history. Preserve is refused with no evidence. Recover is refused before Contain. | ABC | flow: all five actions |
| BTN-02 | Button activation | Investigation, an event selected | Hold A for about one second on 'Collect ... as evidence'. | Exactly one piece of evidence is added. The button then reads 'Collected as ev_...' and is disabled. | ABC | unit: collecting twice changes nothing |
| BTN-03 | Button activation | Terminal | Focus a sample command button and press A twice quickly. | The command runs twice and both outputs appear. Nothing freezes. | ABC | none |
| RST-01 | Focus restoration | Investigation, focus on the events table | Press RB, then LB to come back. | Focus is on the screen's default control ('Source: All'), not on the table. (This is the current, documented behaviour.) | ABC | ctl: returning puts focus on the default control |
| RST-02 | Focus restoration | Design System | Open and close the dialog (DLG-04). | Focus is back on the opener. | ABC | ctl |
| RST-03 | Focus restoration | Any screen | Put the Deck to sleep and wake it (Game Mode), or lock and unlock the PC. | Focus is still on the same control, the screen is unchanged, and input works without restarting. | ABC | none |
| DIS-01 | Disconnect and reconnect | Investigation, focus on a table row | Unplug the controller (or switch off a wireless one). | No crash or error. Focus stays on the same control. Mouse and keyboard still work. | A | none |
| DIS-02 | Disconnect and reconnect | After DIS-01 | Reconnect the controller. Press D-pad Down. | Input resumes without restarting the game. Focus moves from where it was. | A | none |
| DIS-03 | Disconnect and reconnect | Terminal, text typed in the field | Disconnect, then reconnect, then press B. | The typed text is kept. B moves focus to the navigation after reconnecting. | A | none |
| DIS-04 | Disconnect and reconnect | Any screen | Switch to another Steam Input layout or disable Steam Input, then switch back (Game Mode). | The game keeps running and responds to the current layout. Record any layout that makes a screen unusable. | B | none |
| TXT-01 | Text field active | Investigation | Move focus to the filter text box and press A. | Record what happens: whether an on-screen keyboard appears (Steam Deck), whether the caret appears, and whether the box accepts typing. Do not assume. | ABC | none |
| TXT-02 | Text field active | Terminal | Focus the command line. Press the D-pad Up, Down, Left, Right and the stick. | Up and Down recall history or leave the field. Left and Right move the caret. Nothing is typed. | ABC | ctl: Up/Down behaviour |
| TXT-03 | Text field active | Terminal, field focused | Press B. | Focus moves to the 'Terminal' navigation item. Text typed so far is kept. | ABC | ctl: B in the field moves focus to the navigation |
| TXT-04 | Text field active | Terminal, field focused | Open the platform's on-screen keyboard (Deck: Steam button + X) and type 'help', then submit. | The text appears in the field, submit runs 'help', and the on-screen keyboard closes or can be closed with B. Record the exact steps that worked. | B | none |
| TXT-05 | Text field active | Terminal, field focused | Type '[' on a keyboard. | The bracket is typed into the field. The screen does NOT change. | ACD | ctl: a typed bracket does not switch screens |
| TXT-06 | Text field active | Investigation, event collected and selected | Type a one-sentence note with the on-screen keyboard, press Enter or the keyboard's submit, then use A on 'Add note'. | The note appears under 'Investigation notes'. Record how a controller-only player enters the text and any step that was not possible. | ABC | none |
| TXT-07 | Text field active | Terminal | Press RB and LB while the field has focus and text typed. | Screens switch and come back. The typed text is still there. | ABC | ctl: shoulders work with the field focused |
| TXT-08 | Text field active | Terminal | Run each of the eight sample commands using only the controller. | Each runs and prints output. No typing is needed. | ABC | flow: sample buttons run commands |
| MIX-01 | Simultaneous input | Command Center | Click 'Case Management' with the mouse (or trackpad or touch), then press D-pad Down. | Case Management opens, and the D-pad moves focus to the next item from the clicked one. | ABC | ctl: focus continues from a clicked control (click itself not simulated) |
| MIX-02 | Simultaneous input | Any screen | Press Tab, then D-pad Down, then Shift+Tab, then D-pad Up. | Focus moves one control each time in the expected direction. Nothing is skipped or doubled. | AD | ctl: keyboard Up and D-pad together |
| MIX-03 | Simultaneous input | Terminal with long output | Scroll the console with the mouse wheel while the controller has focus on the command line. | The console scrolls. Focus does not move. | ABC | none |
| MIX-04 | Simultaneous input | Case Management | Press Enter on the keyboard and A on the controller at the same moment on 'Investigate'. | The action happens once or twice but never breaks the screen. Record which. | A | none |
| MIX-05 | Simultaneous input | Any screen | Use mouse, keyboard and controller alternately for 2 minutes. | No stuck focus, no lost focus, no duplicated activations. | ABC | none |
| RES-01 | Resolution and readability | Command Center | Set the window or display to 1280x800. Visit all six screens. | Nothing is cut off at the right edge. All text is readable at normal viewing distance. | ABC | flow: layout at 1280x800; shots |
| RES-02 | Resolution and readability | Command Center | Set 1280x720. Visit all six screens. | As RES-01. | ABC | flow: layout at 1280x720; shots |
| RES-03 | Resolution and readability | Settings, then SOC | Set text size to 200% in Settings. Visit all six screens. | Layout stacks to one column; nothing runs off the right edge; the navigation words do not break in the middle. | ABC | flow: layout at 200%; shots |
| RES-04 | Resolution and readability | Any screen | Switch on High contrast in Settings. Visit all six screens. | Pure black background, white text, yellow focus. Every control and focus outline is visible. | ABC | unit: contrast; shots |
| RES-05 | Resolution and readability | Terminal and Investigation | On the Deck's own screen, read the smallest text (table cells and captions) at normal handheld distance. | Record whether the smallest text (14 to 16 px) is comfortably readable. Pass only if you can read it without leaning in. | BC | none |
| KBM-01 | Keyboard and mouse | Title > SOC Console | Click each of the six navigation items with the mouse. | Each screen opens and the active item shows '> ' and an outline. | CD | flow: nav buttons |
| KBM-02 | Keyboard and mouse | Investigation | Click a table row, then click 'Collect ... as evidence'. | The detail panel updates; evidence is added; the header status changes to Investigating. | CD | flow |
| KBM-03 | Keyboard and mouse | Investigation | Click the filter box and type 'j.smith'. | The table narrows and the count line updates. 'Clear filters' restores all rows. | CD | flow: text filter |
| KBM-04 | Keyboard and mouse | Any screen | Press Tab through the whole screen, then Shift+Tab back. | Every control is visited in a logical order and the order wraps. | CD | flow: tab order |
| KBM-05 | Keyboard and mouse | Investigation | Press Esc, then Esc again. | First Esc: focus moves to the navigation. Second Esc: returns to the title. | CD | ctl: cancel behaviour |
| KBM-06 | Keyboard and mouse | Any screen | Press ] and [ (and PageDown / PageUp when not in a table or text field). | Screens switch next and previous. In a table or the console, PageUp and PageDown scroll that control instead. | CD | ctl |
| KBM-07 | Keyboard and mouse | Terminal, Investigation | Scroll with the mouse wheel over a table, the console and the page. | Each scrolls without moving focus. | CD | none |
| KBM-08 | Keyboard and mouse | Terminal | Type 'help', 'assets list', 'hosts show HOST-014', then 'rm -rf /' and 'powershell -c whoami'. | The first three print simulated output. The last two print an ERROR explaining the terminal is simulated. Nothing runs on the computer. | CD | flow: hostile input list |
| KBM-09 | Keyboard and mouse | Any screen | Resize the window from small to large. | Layout adapts; nothing overlaps; no horizontal scrolling of the page. | CD | flow: layout checks |
| KBM-10 | Keyboard and mouse | Title | Open Settings and each of New Game, Load Game, Continue, then return to the SOC. | The earlier screens still work (regression check for the new 'SOC Console' button). | CD | title_flow, save_slots_flow, settings_flow |
| E2E-01 | End to end | Title | Using only the controller: open the SOC; collect EVT-001 to EVT-005; add two notes (a fact citing evidence, a hypothesis); set severity and scope; choose an escalation and a response and press Escalate and Contain; press Review my case. | Record exactly where a controller-only player was blocked. Known expectation: typing the two notes and a report summary needs a text field, so a controller-only run is expected to be blocked there unless the platform keyboard works (see TXT-04 and TXT-06). | ABC | none |
| E2E-02 | End to end | SOC with work done | Return to the title, choose Continue or Load Game, and reopen the SOC. | If the game was saved by another route, evidence and notes return. Record whether any save happened automatically (it is not expected to). | ABCD | flow: save and resume through SaveGame |

## 6. Known expectations, so they are not mistaken for defects

- Left stick behaviour is **unverified by automation**; STK cases are the first evidence.
- At 200% text, tables scroll sideways (SCR-05). Whether that is acceptable on a controller is a question this test should answer.
- A controller-only player cannot type notes or the report summary unless the platform keyboard works; the terminal has sample-command buttons only (E2E-01).
- There is no way to write the report summary outside the terminal, no lab reset, no pause menu and no autosave. They are listed in the specification review, not here.
