# M8 manual test record
**Status: no manual test has been run. Every result below is `Not tested`.** Physical gamepad and Steam Deck verification is pending. Do not change a result to Pass without actually running the case on the hardware named in the section.

The cases and their steps are defined once in [`M8_PHYSICAL_CONTROLLER_TEST_PLAN.md`](M8_PHYSICAL_CONTROLLER_TEST_PLAN.md) and repeated here with the same ids and wording, with the result columns added. Mapping reference: plan section 1.

## Run header (complete before testing)

| Field | Value |
|---|---|
| Commit under test | |
| Tester | |
| Date | |
| Godot version / export type | |
| Display and text scale | |
| Notes | |

## Result key

`Pass` the actual result matched the expected result. `Fail` it did not (add a defect id). `Not tested` not run (the default). Write the observed behaviour in **Actual** whenever a case is run.

## A. Windows 11 with a physical gamepad

Hardware and environment for every row in this section: **Windows 11 + gamepad: model _______ / connection _______**

| Test ID | Hardware and environment | Starting screen | Action sequence | Expected result | Actual result | Result | Evidence or screenshot | Defect ID |
|---|---|---|---|---|---|---|---|---|
| FOC-01 | A | Title > SOC Console | Open the SOC. Do not touch any input. | Command Center is open. A thick outline is on the 'Open investigation' button. The page is at the top. |  | Not tested |  |  |
| FOC-02 | A | Command Center | Press RB once. | Investigation opens. Outline is on the 'Source: All' button. Page at the top. |  | Not tested |  |  |
| FOC-03 | A | Investigation | Press RB once. | Case Management opens. Outline is on the 'Severity' button. |  | Not tested |  |  |
| FOC-04 | A | Case Management | Press RB once. | Terminal opens. The caret is in the command line and the outline is on it. |  | Not tested |  |  |
| FOC-05 | A | Terminal | Press RB once. | Mission & Learning opens. Outline is on 'Ask for a hint'. |  | Not tested |  |  |
| FOC-06 | A | Mission & Learning | Press RB once. | Design System opens. Outline is on the 'Default' button. |  | Not tested |  |  |
| DPD-01 | A | Command Center, focus on 'Command Center' in the left navigation | Press D-pad Down 6 times, then Up 6 times. | Focus visits Command Center, Investigation, Case Management, Terminal, Mission & Learning, Design System, then 'Back to title'. Up reverses it. Each step moves exactly one item. |  | Not tested |  |  |
| DPD-02 | A | Investigation, focus on the events table | Press D-pad Down 5 times, then Up 5 times. | The selected row moves one row per press and the 'Selected event' panel updates each time. Up returns to the first row. |  | Not tested |  |  |
| DPD-03 | A | Investigation, focus on 'Source: All' | Move through the screen with the D-pad only: filters, table, Selected event panel, notes row, cite toggle, 'Open case management'. Then return to the navigation. | Every control on the screen can be reached and left. Record any control that cannot be reached or any place where focus cannot leave. |  | Not tested |  |  |
| DPD-04 | A | Case Management, focus on 'Severity' | Using Left, Right, Up and Down only, reach every control: severity, four scope toggles, Investigate, Escalation, Escalate, Response, Contain, Preserve evidence, Recover, the evidence table and Remove, the timeline, the notes table and Remove, 'Add notes in investigation'. | Every control is reachable and focus can come back to the navigation. Record any that is not. |  | Not tested |  |  |
| DPD-05 | A | Case Management, focus on the 'Severity' button | Press D-pad Left, then Right. | Focus moves to a neighbouring control or stays. The Severity value does NOT change (only A changes it). |  | Not tested |  |  |
| DPD-06 | A | Terminal, caret in the command line with text typed | Press D-pad Left and Right. | Left and Right move the caret inside the text. They do not move focus. Record what happens at the first and last character. |  | Not tested |  |  |
| STK-01 | A | Command Center, focus on the first nav item | Push the left stick down 6 times (return to centre each time), then up 6 times. | Same visit order as DPD-01, one item per push. No skipped items. |  | Not tested |  |  |
| STK-02 | A | Investigation, focus on the events table | Hold the stick down for 2 seconds, then release. Hold it up for 2 seconds, then release. | The selection moves down while held, repeating at a readable rate, and stops on release. Record the repeat rate and whether it overshoots. |  | Not tested |  |  |
| STK-03 | A | Any screen | Leave the stick untouched for 60 seconds. Then push it diagonally and release. | No focus movement from a resting stick (no drift). Diagonal pushes move focus in one direction, not both. Record the controller's rest value if drift occurs. |  | Not tested |  |  |
| CNF-01 | A | Command Center, focus on 'Investigation' in the navigation | Press A. | Investigation opens. |  | Not tested |  |  |
| CNF-02 | A | Case Management, focus on the 'Severity' button | Press A five times. | The value steps Not set, Low, Medium, High, Critical, then back to Not set (setting a real level shows a severity badge in the header area of the overview). |  | Not tested |  |  |
| CNF-03 | A | Case Management, focus on an 'Assets in scope' toggle | Press A twice. | The toggle switches on then off. Switching the last asset off is refused with a message in the notification area. |  | Not tested |  |  |
| CNF-04 | A | Investigation, focus inside the screen | Press B. | Focus moves to the 'Investigation' navigation item. The screen does not change. |  | Not tested |  |  |
| CNF-05 | A | Investigation, focus on the navigation | Press B. | The game returns to the title screen. |  | Not tested |  |  |
| CNF-06 | A | Investigation, focus on a table row | Press A. | The row stays selected and nothing else changes. |  | Not tested |  |  |
| CNF-07 | A | Any screen | Press Start (the Menu/+ button). | Nothing happens (there is no pause menu yet). Record anything that does. |  | Not tested |  |  |
| SHD-01 | A | Command Center | Press RB six times. | Screens open in order: Investigation, Case Management, Terminal, Mission & Learning, Design System, then Command Center (wraps). |  | Not tested |  |  |
| SHD-02 | A | Command Center | Press LB once, then LB again. | Design System opens (wrap), then Mission & Learning. |  | Not tested |  |  |
| SHD-03 | A | Investigation, with a row selected and a filter set | Press RB then LB. | On return the filter and the selected event are still set (view state is kept). |  | Not tested |  |  |
| SHD-04 | A | Terminal, caret in the command line | Press RB, then LB. | The screens switch even though a text field had focus. The field is not typed into. |  | Not tested |  |  |
| SHD-05 | A | Any screen | Press RB and LB alternately as fast as possible for 10 seconds. | No crash, no stuck or duplicated screen, header and navigation always agree on the current screen. |  | Not tested |  |  |
| PNL-01 | A | Mission & Learning | Use the D-pad to move down the left column, across to the middle column and the right column, and to the quiz options. | Focus can reach every column. The page scrolls so the focused control is on screen. |  | Not tested |  |  |
| PNL-02 | A | Command Center at 100% text | Use the D-pad to reach: the four quick-navigation buttons, the incident queue, the event stream, the network table. | Each table can be entered and left. The page scrolls to keep the focused table in view. |  | Not tested |  |  |
| PNL-03 | A | Any screen at 200% text | Repeat DPD-03 or DPD-04 on one screen. | Layout stacks into one column. Order is still logical (top to bottom). No control is cut off. |  | Not tested |  |  |
| SCR-01 | A | Investigation, events table (24 or more rows) | Focus the table. Press D-pad Down until past the last visible row. | The table scrolls so the selection stays visible. The last row can be reached. |  | Not tested |  |  |
| SCR-02 | A | Terminal, after running 'help' several times | Focus the console (the output area, not the input). Press D-pad Up, then Down. | The console scrolls up and back down by about a quarter of a page per press. Focus stays on the console. |  | Not tested |  |  |
| SCR-03 | A | Terminal, console focused | Scroll to the very top, then press Up again. Scroll to the bottom, then press Down again. | Up at the top and Down at the bottom do not scroll further and do not trap focus; Left and Down/Right still lead out of the console. |  | Not tested |  |  |
| SCR-04 | A | Any long screen (Mission & Learning) | Move focus to controls below the fold using the D-pad. | The page scrolls to keep the focused control visible. Record any control that scrolls off screen. |  | Not tested |  |  |
| SCR-05 | A | Command Center at 200% text | Focus the incident queue. Press D-pad Right. | If columns are wider than the table, the table scrolls sideways. Record whether this is discoverable and whether a controller can do it. |  | Not tested |  |  |
| SCR-06 | A | Terminal | Press D-pad Up repeatedly in the command line after running 4 commands. | Recalls commands newest to oldest. At the oldest entry the next Up leaves the field (does not trap focus). |  | Not tested |  |  |
| DLG-01 | A | Design System | Focus 'Open sample dialog' and press A. | A dialog opens over the screen. |  | Not tested |  |  |
| DLG-02 | A | Dialog open | Look at the focus. | Focus is on 'Cancel' (the safe choice). |  | Not tested |  |  |
| DLG-03 | A | Dialog open | Press D-pad Up, Down, Left and Right repeatedly. | Focus moves only between the two buttons. It never reaches the screen behind. |  | Not tested |  |  |
| DLG-04 | A | Dialog open | Press B. | The dialog closes. Focus returns to 'Open sample dialog'. The screen shows 'Dialog result: cancelled.' |  | Not tested |  |  |
| DLG-05 | A | Dialog open | Move to 'Confirm' and press A. | The dialog closes. The screen shows 'Dialog result: confirmed.' Focus returns to the opener. |  | Not tested |  |  |
| BTN-01 | A | Case Management | Press A on each of Investigate, Escalate, Contain, Preserve evidence, Recover in turn (set Escalation and Response first). | Each one updates the case status badge and adds a row to the Audit history. Preserve is refused with no evidence. Recover is refused before Contain. |  | Not tested |  |  |
| BTN-02 | A | Investigation, an event selected | Hold A for about one second on 'Collect ... as evidence'. | Exactly one piece of evidence is added. The button then reads 'Collected as ev_...' and is disabled. |  | Not tested |  |  |
| BTN-03 | A | Terminal | Focus a sample command button and press A twice quickly. | The command runs twice and both outputs appear. Nothing freezes. |  | Not tested |  |  |
| RST-01 | A | Investigation, focus on the events table | Press RB, then LB to come back. | Focus is on the screen's default control ('Source: All'), not on the table. (This is the current, documented behaviour.) |  | Not tested |  |  |
| RST-02 | A | Design System | Open and close the dialog (DLG-04). | Focus is back on the opener. |  | Not tested |  |  |
| RST-03 | A | Any screen | Put the Deck to sleep and wake it (Game Mode), or lock and unlock the PC. | Focus is still on the same control, the screen is unchanged, and input works without restarting. |  | Not tested |  |  |
| DIS-01 | A | Investigation, focus on a table row | Unplug the controller (or switch off a wireless one). | No crash or error. Focus stays on the same control. Mouse and keyboard still work. |  | Not tested |  |  |
| DIS-02 | A | After DIS-01 | Reconnect the controller. Press D-pad Down. | Input resumes without restarting the game. Focus moves from where it was. |  | Not tested |  |  |
| DIS-03 | A | Terminal, text typed in the field | Disconnect, then reconnect, then press B. | The typed text is kept. B moves focus to the navigation after reconnecting. |  | Not tested |  |  |
| TXT-01 | A | Investigation | Move focus to the filter text box and press A. | Record what happens: whether an on-screen keyboard appears (Steam Deck), whether the caret appears, and whether the box accepts typing. Do not assume. |  | Not tested |  |  |
| TXT-02 | A | Terminal | Focus the command line. Press the D-pad Up, Down, Left, Right and the stick. | Up and Down recall history or leave the field. Left and Right move the caret. Nothing is typed. |  | Not tested |  |  |
| TXT-03 | A | Terminal, field focused | Press B. | Focus moves to the 'Terminal' navigation item. Text typed so far is kept. |  | Not tested |  |  |
| TXT-05 | A | Terminal, field focused | Type '[' on a keyboard. | The bracket is typed into the field. The screen does NOT change. |  | Not tested |  |  |
| TXT-06 | A | Investigation, event collected and selected | Type a one-sentence note with the on-screen keyboard, press Enter or the keyboard's submit, then use A on 'Add note'. | The note appears under 'Investigation notes'. Record how a controller-only player enters the text and any step that was not possible. |  | Not tested |  |  |
| TXT-07 | A | Terminal | Press RB and LB while the field has focus and text typed. | Screens switch and come back. The typed text is still there. |  | Not tested |  |  |
| TXT-08 | A | Terminal | Run each of the eight sample commands using only the controller. | Each runs and prints output. No typing is needed. |  | Not tested |  |  |
| MIX-01 | A | Command Center | Click 'Case Management' with the mouse (or trackpad or touch), then press D-pad Down. | Case Management opens, and the D-pad moves focus to the next item from the clicked one. |  | Not tested |  |  |
| MIX-02 | A | Any screen | Press Tab, then D-pad Down, then Shift+Tab, then D-pad Up. | Focus moves one control each time in the expected direction. Nothing is skipped or doubled. |  | Not tested |  |  |
| MIX-03 | A | Terminal with long output | Scroll the console with the mouse wheel while the controller has focus on the command line. | The console scrolls. Focus does not move. |  | Not tested |  |  |
| MIX-04 | A | Case Management | Press Enter on the keyboard and A on the controller at the same moment on 'Investigate'. | The action happens once or twice but never breaks the screen. Record which. |  | Not tested |  |  |
| MIX-05 | A | Any screen | Use mouse, keyboard and controller alternately for 2 minutes. | No stuck focus, no lost focus, no duplicated activations. |  | Not tested |  |  |
| RES-01 | A | Command Center | Set the window or display to 1280x800. Visit all six screens. | Nothing is cut off at the right edge. All text is readable at normal viewing distance. |  | Not tested |  |  |
| RES-02 | A | Command Center | Set 1280x720. Visit all six screens. | As RES-01. |  | Not tested |  |  |
| RES-03 | A | Settings, then SOC | Set text size to 200% in Settings. Visit all six screens. | Layout stacks to one column; nothing runs off the right edge; the navigation words do not break in the middle. |  | Not tested |  |  |
| RES-04 | A | Any screen | Switch on High contrast in Settings. Visit all six screens. | Pure black background, white text, yellow focus. Every control and focus outline is visible. |  | Not tested |  |  |
| E2E-01 | A | Title | Using only the controller: open the SOC; collect EVT-001 to EVT-005; add two notes (a fact citing evidence, a hypothesis); set severity and scope; choose an escalation and a response and press Escalate and Contain; press Review my case. | Record exactly where a controller-only player was blocked. Known expectation: typing the two notes and a report summary needs a text field, so a controller-only run is expected to be blocked there unless the platform keyboard works (see TXT-04 and TXT-06). |  | Not tested |  |  |
| E2E-02 | A | SOC with work done | Return to the title, choose Continue or Load Game, and reopen the SOC. | If the game was saved by another route, evidence and notes return. Record whether any save happened automatically (it is not expected to). |  | Not tested |  |  |

## B. Steam Deck, Game Mode

Hardware and environment for every row in this section: **Steam Deck, Game Mode: OS build _______ / Steam Input layout _______**

| Test ID | Hardware and environment | Starting screen | Action sequence | Expected result | Actual result | Result | Evidence or screenshot | Defect ID |
|---|---|---|---|---|---|---|---|---|
| FOC-01 | B | Title > SOC Console | Open the SOC. Do not touch any input. | Command Center is open. A thick outline is on the 'Open investigation' button. The page is at the top. |  | Not tested |  |  |
| FOC-02 | B | Command Center | Press RB once. | Investigation opens. Outline is on the 'Source: All' button. Page at the top. |  | Not tested |  |  |
| FOC-03 | B | Investigation | Press RB once. | Case Management opens. Outline is on the 'Severity' button. |  | Not tested |  |  |
| FOC-04 | B | Case Management | Press RB once. | Terminal opens. The caret is in the command line and the outline is on it. |  | Not tested |  |  |
| FOC-05 | B | Terminal | Press RB once. | Mission & Learning opens. Outline is on 'Ask for a hint'. |  | Not tested |  |  |
| FOC-06 | B | Mission & Learning | Press RB once. | Design System opens. Outline is on the 'Default' button. |  | Not tested |  |  |
| DPD-01 | B | Command Center, focus on 'Command Center' in the left navigation | Press D-pad Down 6 times, then Up 6 times. | Focus visits Command Center, Investigation, Case Management, Terminal, Mission & Learning, Design System, then 'Back to title'. Up reverses it. Each step moves exactly one item. |  | Not tested |  |  |
| DPD-02 | B | Investigation, focus on the events table | Press D-pad Down 5 times, then Up 5 times. | The selected row moves one row per press and the 'Selected event' panel updates each time. Up returns to the first row. |  | Not tested |  |  |
| DPD-03 | B | Investigation, focus on 'Source: All' | Move through the screen with the D-pad only: filters, table, Selected event panel, notes row, cite toggle, 'Open case management'. Then return to the navigation. | Every control on the screen can be reached and left. Record any control that cannot be reached or any place where focus cannot leave. |  | Not tested |  |  |
| DPD-04 | B | Case Management, focus on 'Severity' | Using Left, Right, Up and Down only, reach every control: severity, four scope toggles, Investigate, Escalation, Escalate, Response, Contain, Preserve evidence, Recover, the evidence table and Remove, the timeline, the notes table and Remove, 'Add notes in investigation'. | Every control is reachable and focus can come back to the navigation. Record any that is not. |  | Not tested |  |  |
| DPD-05 | B | Case Management, focus on the 'Severity' button | Press D-pad Left, then Right. | Focus moves to a neighbouring control or stays. The Severity value does NOT change (only A changes it). |  | Not tested |  |  |
| DPD-06 | B | Terminal, caret in the command line with text typed | Press D-pad Left and Right. | Left and Right move the caret inside the text. They do not move focus. Record what happens at the first and last character. |  | Not tested |  |  |
| STK-01 | B | Command Center, focus on the first nav item | Push the left stick down 6 times (return to centre each time), then up 6 times. | Same visit order as DPD-01, one item per push. No skipped items. |  | Not tested |  |  |
| STK-02 | B | Investigation, focus on the events table | Hold the stick down for 2 seconds, then release. Hold it up for 2 seconds, then release. | The selection moves down while held, repeating at a readable rate, and stops on release. Record the repeat rate and whether it overshoots. |  | Not tested |  |  |
| STK-03 | B | Any screen | Leave the stick untouched for 60 seconds. Then push it diagonally and release. | No focus movement from a resting stick (no drift). Diagonal pushes move focus in one direction, not both. Record the controller's rest value if drift occurs. |  | Not tested |  |  |
| CNF-01 | B | Command Center, focus on 'Investigation' in the navigation | Press A. | Investigation opens. |  | Not tested |  |  |
| CNF-02 | B | Case Management, focus on the 'Severity' button | Press A five times. | The value steps Not set, Low, Medium, High, Critical, then back to Not set (setting a real level shows a severity badge in the header area of the overview). |  | Not tested |  |  |
| CNF-03 | B | Case Management, focus on an 'Assets in scope' toggle | Press A twice. | The toggle switches on then off. Switching the last asset off is refused with a message in the notification area. |  | Not tested |  |  |
| CNF-04 | B | Investigation, focus inside the screen | Press B. | Focus moves to the 'Investigation' navigation item. The screen does not change. |  | Not tested |  |  |
| CNF-05 | B | Investigation, focus on the navigation | Press B. | The game returns to the title screen. |  | Not tested |  |  |
| CNF-06 | B | Investigation, focus on a table row | Press A. | The row stays selected and nothing else changes. |  | Not tested |  |  |
| CNF-07 | B | Any screen | Press Start (the Menu/+ button). | Nothing happens (there is no pause menu yet). Record anything that does. |  | Not tested |  |  |
| SHD-01 | B | Command Center | Press RB six times. | Screens open in order: Investigation, Case Management, Terminal, Mission & Learning, Design System, then Command Center (wraps). |  | Not tested |  |  |
| SHD-02 | B | Command Center | Press LB once, then LB again. | Design System opens (wrap), then Mission & Learning. |  | Not tested |  |  |
| SHD-03 | B | Investigation, with a row selected and a filter set | Press RB then LB. | On return the filter and the selected event are still set (view state is kept). |  | Not tested |  |  |
| SHD-04 | B | Terminal, caret in the command line | Press RB, then LB. | The screens switch even though a text field had focus. The field is not typed into. |  | Not tested |  |  |
| SHD-05 | B | Any screen | Press RB and LB alternately as fast as possible for 10 seconds. | No crash, no stuck or duplicated screen, header and navigation always agree on the current screen. |  | Not tested |  |  |
| PNL-01 | B | Mission & Learning | Use the D-pad to move down the left column, across to the middle column and the right column, and to the quiz options. | Focus can reach every column. The page scrolls so the focused control is on screen. |  | Not tested |  |  |
| PNL-02 | B | Command Center at 100% text | Use the D-pad to reach: the four quick-navigation buttons, the incident queue, the event stream, the network table. | Each table can be entered and left. The page scrolls to keep the focused table in view. |  | Not tested |  |  |
| PNL-03 | B | Any screen at 200% text | Repeat DPD-03 or DPD-04 on one screen. | Layout stacks into one column. Order is still logical (top to bottom). No control is cut off. |  | Not tested |  |  |
| SCR-01 | B | Investigation, events table (24 or more rows) | Focus the table. Press D-pad Down until past the last visible row. | The table scrolls so the selection stays visible. The last row can be reached. |  | Not tested |  |  |
| SCR-02 | B | Terminal, after running 'help' several times | Focus the console (the output area, not the input). Press D-pad Up, then Down. | The console scrolls up and back down by about a quarter of a page per press. Focus stays on the console. |  | Not tested |  |  |
| SCR-03 | B | Terminal, console focused | Scroll to the very top, then press Up again. Scroll to the bottom, then press Down again. | Up at the top and Down at the bottom do not scroll further and do not trap focus; Left and Down/Right still lead out of the console. |  | Not tested |  |  |
| SCR-04 | B | Any long screen (Mission & Learning) | Move focus to controls below the fold using the D-pad. | The page scrolls to keep the focused control visible. Record any control that scrolls off screen. |  | Not tested |  |  |
| SCR-05 | B | Command Center at 200% text | Focus the incident queue. Press D-pad Right. | If columns are wider than the table, the table scrolls sideways. Record whether this is discoverable and whether a controller can do it. |  | Not tested |  |  |
| SCR-06 | B | Terminal | Press D-pad Up repeatedly in the command line after running 4 commands. | Recalls commands newest to oldest. At the oldest entry the next Up leaves the field (does not trap focus). |  | Not tested |  |  |
| DLG-01 | B | Design System | Focus 'Open sample dialog' and press A. | A dialog opens over the screen. |  | Not tested |  |  |
| DLG-02 | B | Dialog open | Look at the focus. | Focus is on 'Cancel' (the safe choice). |  | Not tested |  |  |
| DLG-03 | B | Dialog open | Press D-pad Up, Down, Left and Right repeatedly. | Focus moves only between the two buttons. It never reaches the screen behind. |  | Not tested |  |  |
| DLG-04 | B | Dialog open | Press B. | The dialog closes. Focus returns to 'Open sample dialog'. The screen shows 'Dialog result: cancelled.' |  | Not tested |  |  |
| DLG-05 | B | Dialog open | Move to 'Confirm' and press A. | The dialog closes. The screen shows 'Dialog result: confirmed.' Focus returns to the opener. |  | Not tested |  |  |
| BTN-01 | B | Case Management | Press A on each of Investigate, Escalate, Contain, Preserve evidence, Recover in turn (set Escalation and Response first). | Each one updates the case status badge and adds a row to the Audit history. Preserve is refused with no evidence. Recover is refused before Contain. |  | Not tested |  |  |
| BTN-02 | B | Investigation, an event selected | Hold A for about one second on 'Collect ... as evidence'. | Exactly one piece of evidence is added. The button then reads 'Collected as ev_...' and is disabled. |  | Not tested |  |  |
| BTN-03 | B | Terminal | Focus a sample command button and press A twice quickly. | The command runs twice and both outputs appear. Nothing freezes. |  | Not tested |  |  |
| RST-01 | B | Investigation, focus on the events table | Press RB, then LB to come back. | Focus is on the screen's default control ('Source: All'), not on the table. (This is the current, documented behaviour.) |  | Not tested |  |  |
| RST-02 | B | Design System | Open and close the dialog (DLG-04). | Focus is back on the opener. |  | Not tested |  |  |
| RST-03 | B | Any screen | Put the Deck to sleep and wake it (Game Mode), or lock and unlock the PC. | Focus is still on the same control, the screen is unchanged, and input works without restarting. |  | Not tested |  |  |
| DIS-04 | B | Any screen | Switch to another Steam Input layout or disable Steam Input, then switch back (Game Mode). | The game keeps running and responds to the current layout. Record any layout that makes a screen unusable. |  | Not tested |  |  |
| TXT-01 | B | Investigation | Move focus to the filter text box and press A. | Record what happens: whether an on-screen keyboard appears (Steam Deck), whether the caret appears, and whether the box accepts typing. Do not assume. |  | Not tested |  |  |
| TXT-02 | B | Terminal | Focus the command line. Press the D-pad Up, Down, Left, Right and the stick. | Up and Down recall history or leave the field. Left and Right move the caret. Nothing is typed. |  | Not tested |  |  |
| TXT-03 | B | Terminal, field focused | Press B. | Focus moves to the 'Terminal' navigation item. Text typed so far is kept. |  | Not tested |  |  |
| TXT-04 | B | Terminal, field focused | Open the platform's on-screen keyboard (Deck: Steam button + X) and type 'help', then submit. | The text appears in the field, submit runs 'help', and the on-screen keyboard closes or can be closed with B. Record the exact steps that worked. |  | Not tested |  |  |
| TXT-06 | B | Investigation, event collected and selected | Type a one-sentence note with the on-screen keyboard, press Enter or the keyboard's submit, then use A on 'Add note'. | The note appears under 'Investigation notes'. Record how a controller-only player enters the text and any step that was not possible. |  | Not tested |  |  |
| TXT-07 | B | Terminal | Press RB and LB while the field has focus and text typed. | Screens switch and come back. The typed text is still there. |  | Not tested |  |  |
| TXT-08 | B | Terminal | Run each of the eight sample commands using only the controller. | Each runs and prints output. No typing is needed. |  | Not tested |  |  |
| MIX-01 | B | Command Center | Click 'Case Management' with the mouse (or trackpad or touch), then press D-pad Down. | Case Management opens, and the D-pad moves focus to the next item from the clicked one. |  | Not tested |  |  |
| MIX-03 | B | Terminal with long output | Scroll the console with the mouse wheel while the controller has focus on the command line. | The console scrolls. Focus does not move. |  | Not tested |  |  |
| MIX-05 | B | Any screen | Use mouse, keyboard and controller alternately for 2 minutes. | No stuck focus, no lost focus, no duplicated activations. |  | Not tested |  |  |
| RES-01 | B | Command Center | Set the window or display to 1280x800. Visit all six screens. | Nothing is cut off at the right edge. All text is readable at normal viewing distance. |  | Not tested |  |  |
| RES-02 | B | Command Center | Set 1280x720. Visit all six screens. | As RES-01. |  | Not tested |  |  |
| RES-03 | B | Settings, then SOC | Set text size to 200% in Settings. Visit all six screens. | Layout stacks to one column; nothing runs off the right edge; the navigation words do not break in the middle. |  | Not tested |  |  |
| RES-04 | B | Any screen | Switch on High contrast in Settings. Visit all six screens. | Pure black background, white text, yellow focus. Every control and focus outline is visible. |  | Not tested |  |  |
| RES-05 | B | Terminal and Investigation | On the Deck's own screen, read the smallest text (table cells and captions) at normal handheld distance. | Record whether the smallest text (14 to 16 px) is comfortably readable. Pass only if you can read it without leaning in. |  | Not tested |  |  |
| E2E-01 | B | Title | Using only the controller: open the SOC; collect EVT-001 to EVT-005; add two notes (a fact citing evidence, a hypothesis); set severity and scope; choose an escalation and a response and press Escalate and Contain; press Review my case. | Record exactly where a controller-only player was blocked. Known expectation: typing the two notes and a report summary needs a text field, so a controller-only run is expected to be blocked there unless the platform keyboard works (see TXT-04 and TXT-06). |  | Not tested |  |  |
| E2E-02 | B | SOC with work done | Return to the title, choose Continue or Load Game, and reopen the SOC. | If the game was saved by another route, evidence and notes return. Record whether any save happened automatically (it is not expected to). |  | Not tested |  |  |

## C. Steam Deck, Desktop Mode

Hardware and environment for every row in this section: **Steam Deck, Desktop Mode: OS build _______ / Steam Input layout _______**

Steam Input layout used in Desktop Mode (pad cases only apply if this presents a gamepad): _______

| Test ID | Hardware and environment | Starting screen | Action sequence | Expected result | Actual result | Result | Evidence or screenshot | Defect ID |
|---|---|---|---|---|---|---|---|---|
| FOC-01 | C | Title > SOC Console | Open the SOC. Do not touch any input. | Command Center is open. A thick outline is on the 'Open investigation' button. The page is at the top. |  | Not tested |  |  |
| FOC-02 | C | Command Center | Press RB once. | Investigation opens. Outline is on the 'Source: All' button. Page at the top. |  | Not tested |  |  |
| FOC-03 | C | Investigation | Press RB once. | Case Management opens. Outline is on the 'Severity' button. |  | Not tested |  |  |
| FOC-04 | C | Case Management | Press RB once. | Terminal opens. The caret is in the command line and the outline is on it. |  | Not tested |  |  |
| FOC-05 | C | Terminal | Press RB once. | Mission & Learning opens. Outline is on 'Ask for a hint'. |  | Not tested |  |  |
| FOC-06 | C | Mission & Learning | Press RB once. | Design System opens. Outline is on the 'Default' button. |  | Not tested |  |  |
| DPD-01 | C | Command Center, focus on 'Command Center' in the left navigation | Press D-pad Down 6 times, then Up 6 times. | Focus visits Command Center, Investigation, Case Management, Terminal, Mission & Learning, Design System, then 'Back to title'. Up reverses it. Each step moves exactly one item. |  | Not tested |  |  |
| DPD-02 | C | Investigation, focus on the events table | Press D-pad Down 5 times, then Up 5 times. | The selected row moves one row per press and the 'Selected event' panel updates each time. Up returns to the first row. |  | Not tested |  |  |
| DPD-03 | C | Investigation, focus on 'Source: All' | Move through the screen with the D-pad only: filters, table, Selected event panel, notes row, cite toggle, 'Open case management'. Then return to the navigation. | Every control on the screen can be reached and left. Record any control that cannot be reached or any place where focus cannot leave. |  | Not tested |  |  |
| DPD-04 | C | Case Management, focus on 'Severity' | Using Left, Right, Up and Down only, reach every control: severity, four scope toggles, Investigate, Escalation, Escalate, Response, Contain, Preserve evidence, Recover, the evidence table and Remove, the timeline, the notes table and Remove, 'Add notes in investigation'. | Every control is reachable and focus can come back to the navigation. Record any that is not. |  | Not tested |  |  |
| DPD-05 | C | Case Management, focus on the 'Severity' button | Press D-pad Left, then Right. | Focus moves to a neighbouring control or stays. The Severity value does NOT change (only A changes it). |  | Not tested |  |  |
| DPD-06 | C | Terminal, caret in the command line with text typed | Press D-pad Left and Right. | Left and Right move the caret inside the text. They do not move focus. Record what happens at the first and last character. |  | Not tested |  |  |
| STK-01 | C | Command Center, focus on the first nav item | Push the left stick down 6 times (return to centre each time), then up 6 times. | Same visit order as DPD-01, one item per push. No skipped items. |  | Not tested |  |  |
| STK-02 | C | Investigation, focus on the events table | Hold the stick down for 2 seconds, then release. Hold it up for 2 seconds, then release. | The selection moves down while held, repeating at a readable rate, and stops on release. Record the repeat rate and whether it overshoots. |  | Not tested |  |  |
| STK-03 | C | Any screen | Leave the stick untouched for 60 seconds. Then push it diagonally and release. | No focus movement from a resting stick (no drift). Diagonal pushes move focus in one direction, not both. Record the controller's rest value if drift occurs. |  | Not tested |  |  |
| CNF-01 | C | Command Center, focus on 'Investigation' in the navigation | Press A. | Investigation opens. |  | Not tested |  |  |
| CNF-02 | C | Case Management, focus on the 'Severity' button | Press A five times. | The value steps Not set, Low, Medium, High, Critical, then back to Not set (setting a real level shows a severity badge in the header area of the overview). |  | Not tested |  |  |
| CNF-03 | C | Case Management, focus on an 'Assets in scope' toggle | Press A twice. | The toggle switches on then off. Switching the last asset off is refused with a message in the notification area. |  | Not tested |  |  |
| CNF-04 | C | Investigation, focus inside the screen | Press B. | Focus moves to the 'Investigation' navigation item. The screen does not change. |  | Not tested |  |  |
| CNF-05 | C | Investigation, focus on the navigation | Press B. | The game returns to the title screen. |  | Not tested |  |  |
| CNF-06 | C | Investigation, focus on a table row | Press A. | The row stays selected and nothing else changes. |  | Not tested |  |  |
| CNF-07 | C | Any screen | Press Start (the Menu/+ button). | Nothing happens (there is no pause menu yet). Record anything that does. |  | Not tested |  |  |
| SHD-01 | C | Command Center | Press RB six times. | Screens open in order: Investigation, Case Management, Terminal, Mission & Learning, Design System, then Command Center (wraps). |  | Not tested |  |  |
| SHD-02 | C | Command Center | Press LB once, then LB again. | Design System opens (wrap), then Mission & Learning. |  | Not tested |  |  |
| SHD-03 | C | Investigation, with a row selected and a filter set | Press RB then LB. | On return the filter and the selected event are still set (view state is kept). |  | Not tested |  |  |
| SHD-04 | C | Terminal, caret in the command line | Press RB, then LB. | The screens switch even though a text field had focus. The field is not typed into. |  | Not tested |  |  |
| SHD-05 | C | Any screen | Press RB and LB alternately as fast as possible for 10 seconds. | No crash, no stuck or duplicated screen, header and navigation always agree on the current screen. |  | Not tested |  |  |
| PNL-01 | C | Mission & Learning | Use the D-pad to move down the left column, across to the middle column and the right column, and to the quiz options. | Focus can reach every column. The page scrolls so the focused control is on screen. |  | Not tested |  |  |
| PNL-02 | C | Command Center at 100% text | Use the D-pad to reach: the four quick-navigation buttons, the incident queue, the event stream, the network table. | Each table can be entered and left. The page scrolls to keep the focused table in view. |  | Not tested |  |  |
| PNL-03 | C | Any screen at 200% text | Repeat DPD-03 or DPD-04 on one screen. | Layout stacks into one column. Order is still logical (top to bottom). No control is cut off. |  | Not tested |  |  |
| SCR-01 | C | Investigation, events table (24 or more rows) | Focus the table. Press D-pad Down until past the last visible row. | The table scrolls so the selection stays visible. The last row can be reached. |  | Not tested |  |  |
| SCR-02 | C | Terminal, after running 'help' several times | Focus the console (the output area, not the input). Press D-pad Up, then Down. | The console scrolls up and back down by about a quarter of a page per press. Focus stays on the console. |  | Not tested |  |  |
| SCR-03 | C | Terminal, console focused | Scroll to the very top, then press Up again. Scroll to the bottom, then press Down again. | Up at the top and Down at the bottom do not scroll further and do not trap focus; Left and Down/Right still lead out of the console. |  | Not tested |  |  |
| SCR-04 | C | Any long screen (Mission & Learning) | Move focus to controls below the fold using the D-pad. | The page scrolls to keep the focused control visible. Record any control that scrolls off screen. |  | Not tested |  |  |
| SCR-05 | C | Command Center at 200% text | Focus the incident queue. Press D-pad Right. | If columns are wider than the table, the table scrolls sideways. Record whether this is discoverable and whether a controller can do it. |  | Not tested |  |  |
| SCR-06 | C | Terminal | Press D-pad Up repeatedly in the command line after running 4 commands. | Recalls commands newest to oldest. At the oldest entry the next Up leaves the field (does not trap focus). |  | Not tested |  |  |
| DLG-01 | C | Design System | Focus 'Open sample dialog' and press A. | A dialog opens over the screen. |  | Not tested |  |  |
| DLG-02 | C | Dialog open | Look at the focus. | Focus is on 'Cancel' (the safe choice). |  | Not tested |  |  |
| DLG-03 | C | Dialog open | Press D-pad Up, Down, Left and Right repeatedly. | Focus moves only between the two buttons. It never reaches the screen behind. |  | Not tested |  |  |
| DLG-04 | C | Dialog open | Press B. | The dialog closes. Focus returns to 'Open sample dialog'. The screen shows 'Dialog result: cancelled.' |  | Not tested |  |  |
| DLG-05 | C | Dialog open | Move to 'Confirm' and press A. | The dialog closes. The screen shows 'Dialog result: confirmed.' Focus returns to the opener. |  | Not tested |  |  |
| BTN-01 | C | Case Management | Press A on each of Investigate, Escalate, Contain, Preserve evidence, Recover in turn (set Escalation and Response first). | Each one updates the case status badge and adds a row to the Audit history. Preserve is refused with no evidence. Recover is refused before Contain. |  | Not tested |  |  |
| BTN-02 | C | Investigation, an event selected | Hold A for about one second on 'Collect ... as evidence'. | Exactly one piece of evidence is added. The button then reads 'Collected as ev_...' and is disabled. |  | Not tested |  |  |
| BTN-03 | C | Terminal | Focus a sample command button and press A twice quickly. | The command runs twice and both outputs appear. Nothing freezes. |  | Not tested |  |  |
| RST-01 | C | Investigation, focus on the events table | Press RB, then LB to come back. | Focus is on the screen's default control ('Source: All'), not on the table. (This is the current, documented behaviour.) |  | Not tested |  |  |
| RST-02 | C | Design System | Open and close the dialog (DLG-04). | Focus is back on the opener. |  | Not tested |  |  |
| RST-03 | C | Any screen | Put the Deck to sleep and wake it (Game Mode), or lock and unlock the PC. | Focus is still on the same control, the screen is unchanged, and input works without restarting. |  | Not tested |  |  |
| TXT-01 | C | Investigation | Move focus to the filter text box and press A. | Record what happens: whether an on-screen keyboard appears (Steam Deck), whether the caret appears, and whether the box accepts typing. Do not assume. |  | Not tested |  |  |
| TXT-02 | C | Terminal | Focus the command line. Press the D-pad Up, Down, Left, Right and the stick. | Up and Down recall history or leave the field. Left and Right move the caret. Nothing is typed. |  | Not tested |  |  |
| TXT-03 | C | Terminal, field focused | Press B. | Focus moves to the 'Terminal' navigation item. Text typed so far is kept. |  | Not tested |  |  |
| TXT-05 | C | Terminal, field focused | Type '[' on a keyboard. | The bracket is typed into the field. The screen does NOT change. |  | Not tested |  |  |
| TXT-06 | C | Investigation, event collected and selected | Type a one-sentence note with the on-screen keyboard, press Enter or the keyboard's submit, then use A on 'Add note'. | The note appears under 'Investigation notes'. Record how a controller-only player enters the text and any step that was not possible. |  | Not tested |  |  |
| TXT-07 | C | Terminal | Press RB and LB while the field has focus and text typed. | Screens switch and come back. The typed text is still there. |  | Not tested |  |  |
| TXT-08 | C | Terminal | Run each of the eight sample commands using only the controller. | Each runs and prints output. No typing is needed. |  | Not tested |  |  |
| MIX-01 | C | Command Center | Click 'Case Management' with the mouse (or trackpad or touch), then press D-pad Down. | Case Management opens, and the D-pad moves focus to the next item from the clicked one. |  | Not tested |  |  |
| MIX-03 | C | Terminal with long output | Scroll the console with the mouse wheel while the controller has focus on the command line. | The console scrolls. Focus does not move. |  | Not tested |  |  |
| MIX-05 | C | Any screen | Use mouse, keyboard and controller alternately for 2 minutes. | No stuck focus, no lost focus, no duplicated activations. |  | Not tested |  |  |
| RES-01 | C | Command Center | Set the window or display to 1280x800. Visit all six screens. | Nothing is cut off at the right edge. All text is readable at normal viewing distance. |  | Not tested |  |  |
| RES-02 | C | Command Center | Set 1280x720. Visit all six screens. | As RES-01. |  | Not tested |  |  |
| RES-03 | C | Settings, then SOC | Set text size to 200% in Settings. Visit all six screens. | Layout stacks to one column; nothing runs off the right edge; the navigation words do not break in the middle. |  | Not tested |  |  |
| RES-04 | C | Any screen | Switch on High contrast in Settings. Visit all six screens. | Pure black background, white text, yellow focus. Every control and focus outline is visible. |  | Not tested |  |  |
| RES-05 | C | Terminal and Investigation | On the Deck's own screen, read the smallest text (table cells and captions) at normal handheld distance. | Record whether the smallest text (14 to 16 px) is comfortably readable. Pass only if you can read it without leaning in. |  | Not tested |  |  |
| KBM-01 | C | Title > SOC Console | Click each of the six navigation items with the mouse. | Each screen opens and the active item shows '> ' and an outline. |  | Not tested |  |  |
| KBM-02 | C | Investigation | Click a table row, then click 'Collect ... as evidence'. | The detail panel updates; evidence is added; the header status changes to Investigating. |  | Not tested |  |  |
| KBM-03 | C | Investigation | Click the filter box and type 'j.smith'. | The table narrows and the count line updates. 'Clear filters' restores all rows. |  | Not tested |  |  |
| KBM-04 | C | Any screen | Press Tab through the whole screen, then Shift+Tab back. | Every control is visited in a logical order and the order wraps. |  | Not tested |  |  |
| KBM-05 | C | Investigation | Press Esc, then Esc again. | First Esc: focus moves to the navigation. Second Esc: returns to the title. |  | Not tested |  |  |
| KBM-06 | C | Any screen | Press ] and [ (and PageDown / PageUp when not in a table or text field). | Screens switch next and previous. In a table or the console, PageUp and PageDown scroll that control instead. |  | Not tested |  |  |
| KBM-07 | C | Terminal, Investigation | Scroll with the mouse wheel over a table, the console and the page. | Each scrolls without moving focus. |  | Not tested |  |  |
| KBM-08 | C | Terminal | Type 'help', 'assets list', 'hosts show HOST-014', then 'rm -rf /' and 'powershell -c whoami'. | The first three print simulated output. The last two print an ERROR explaining the terminal is simulated. Nothing runs on the computer. |  | Not tested |  |  |
| KBM-09 | C | Any screen | Resize the window from small to large. | Layout adapts; nothing overlaps; no horizontal scrolling of the page. |  | Not tested |  |  |
| KBM-10 | C | Title | Open Settings and each of New Game, Load Game, Continue, then return to the SOC. | The earlier screens still work (regression check for the new 'SOC Console' button). |  | Not tested |  |  |
| E2E-01 | C | Title | Using only the controller: open the SOC; collect EVT-001 to EVT-005; add two notes (a fact citing evidence, a hypothesis); set severity and scope; choose an escalation and a response and press Escalate and Contain; press Review my case. | Record exactly where a controller-only player was blocked. Known expectation: typing the two notes and a report summary needs a text field, so a controller-only run is expected to be blocked there unless the platform keyboard works (see TXT-04 and TXT-06). |  | Not tested |  |  |
| E2E-02 | C | SOC with work done | Return to the title, choose Continue or Load Game, and reopen the SOC. | If the game was saved by another route, evidence and notes return. Record whether any save happened automatically (it is not expected to). |  | Not tested |  |  |

## D. Keyboard and mouse regression (Windows 11)

Hardware and environment for every row in this section: **Windows 11, keyboard and mouse: model _______**

| Test ID | Hardware and environment | Starting screen | Action sequence | Expected result | Actual result | Result | Evidence or screenshot | Defect ID |
|---|---|---|---|---|---|---|---|---|
| FOC-01 | D | Title > SOC Console | Open the SOC. Do not touch any input. | Command Center is open. A thick outline is on the 'Open investigation' button. The page is at the top. |  | Not tested |  |  |
| TXT-05 | D | Terminal, field focused | Type '[' on a keyboard. | The bracket is typed into the field. The screen does NOT change. |  | Not tested |  |  |
| MIX-02 | D | Any screen | Press Tab, then D-pad Down, then Shift+Tab, then D-pad Up. | Focus moves one control each time in the expected direction. Nothing is skipped or doubled. |  | Not tested |  |  |
| KBM-01 | D | Title > SOC Console | Click each of the six navigation items with the mouse. | Each screen opens and the active item shows '> ' and an outline. |  | Not tested |  |  |
| KBM-02 | D | Investigation | Click a table row, then click 'Collect ... as evidence'. | The detail panel updates; evidence is added; the header status changes to Investigating. |  | Not tested |  |  |
| KBM-03 | D | Investigation | Click the filter box and type 'j.smith'. | The table narrows and the count line updates. 'Clear filters' restores all rows. |  | Not tested |  |  |
| KBM-04 | D | Any screen | Press Tab through the whole screen, then Shift+Tab back. | Every control is visited in a logical order and the order wraps. |  | Not tested |  |  |
| KBM-05 | D | Investigation | Press Esc, then Esc again. | First Esc: focus moves to the navigation. Second Esc: returns to the title. |  | Not tested |  |  |
| KBM-06 | D | Any screen | Press ] and [ (and PageDown / PageUp when not in a table or text field). | Screens switch next and previous. In a table or the console, PageUp and PageDown scroll that control instead. |  | Not tested |  |  |
| KBM-07 | D | Terminal, Investigation | Scroll with the mouse wheel over a table, the console and the page. | Each scrolls without moving focus. |  | Not tested |  |  |
| KBM-08 | D | Terminal | Type 'help', 'assets list', 'hosts show HOST-014', then 'rm -rf /' and 'powershell -c whoami'. | The first three print simulated output. The last two print an ERROR explaining the terminal is simulated. Nothing runs on the computer. |  | Not tested |  |  |
| KBM-09 | D | Any screen | Resize the window from small to large. | Layout adapts; nothing overlaps; no horizontal scrolling of the page. |  | Not tested |  |  |
| KBM-10 | D | Title | Open Settings and each of New Game, Load Game, Continue, then return to the SOC. | The earlier screens still work (regression check for the new 'SOC Console' button). |  | Not tested |  |  |
| E2E-02 | D | SOC with work done | Return to the title, choose Continue or Load Game, and reopen the SOC. | If the game was saved by another route, evidence and notes return. Record whether any save happened automatically (it is not expected to). |  | Not tested |  |  |

## Defects found during manual testing

| Defect ID | Test ID | Platform | What happened | Steps to reproduce | Screenshot | Status |
|---|---|---|---|---|---|---|
| (none recorded: no manual test has been run) | | | | | | |

## Sign-off

| Platform | Cases applicable | Passed | Failed | Not tested | Signed off by | Date |
|---|---|---|---|---|---|---|
| Windows 11 with a physical gamepad | 68 | 0 | 0 | 68 |  |  |
| Steam Deck, Game Mode | 65 | 0 | 0 | 65 |  |  |
| Steam Deck, Desktop Mode | 74 | 0 | 0 | 74 |  |  |
| Keyboard and mouse regression (Windows 11) | 14 | 0 | 0 | 14 |  |  |

M8 may be called **fully verified** only when sections A, B and C show no `Not tested` and no open `Fail`, and section D shows no open `Fail`. Until then it is **built and automatically tested, not fully verified**.
