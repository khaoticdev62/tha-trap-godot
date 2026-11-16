# 05 — UI/UX and Art Bible

## 1. Visual identity
**Direction:** premium 16-bit SNES-inspired pixel art with modern HD presentation. The UI blends a retro RPG menu system with a credible SOC command center. Use crisp pixel edges, intentional palette ramps, restrained glow and readable typography. Do not apply a blanket CRT filter that reduces legibility.

## 2. Proposed custom palette
| Token | Hex | Use |
|---|---|---|
| Obsidian | #100D1B | Main background |
| Deep Panel | #1B1630 | Panels and HUD surfaces |
| Night Violet | #34205C | Secondary surfaces |
| Signal Purple | #8B45E8 | Primary highlight |
| Electric Lilac | #C5A2FF | Focus, selection and accents |
| Copper | #C87945 | Warm accent, important interactions |
| Streetlight Gold | #F4C95D | Objectives and rewards |
| Ice Blue | #64C8E8 | Informational telemetry |
| Alert Red | #F05A67 | High-risk alert only |
| Safe Green | #69D69B | Verified success |
| Warm White | #F3EEDC | Main text |
| Muted Slate | #A6A0B8 | Secondary text |

Color is never the only signal. Pair color with icons, labels, shapes and text.

## 3. Pixel-art production rules
- Establish a base tile grid (recommended 16×16 or 32×32) and document exceptions.
- Character sprites: consistent height, outline weight, light source and animation timing.
- Environment tiles: modular ground, wall, storefront, street, foliage, signage and interior sets.
- Use parallax layers sparingly: distant skyline, midground architecture, foreground props.
- Keep gameplay silhouettes readable at 1280×800 and on smaller screens.
- Export pixel art without unintended smoothing; verify texture filtering settings.
- Use a limited palette per scene and preserve contrast for text overlays.

## 4. Screen inventory
1. Boot/loading.
2. Title screen: New Game, Continue, Settings, Credits, Accessibility.
3. Character creator.
4. World map with district unlock states.
5. District exploration HUD.
6. Dialogue and choice panel.
7. Switchboard HQ hub.
8. Mission briefing and objectives.
9. SOC dashboard.
10. Alert queue and alert detail.
11. SIEM query workbench.
12. Endpoint investigation.
13. Network topology.
14. Identity and access console.
15. Case timeline/evidence board.
16. Incident response action panel.
17. Lab terminal and help.
18. Knowledge check.
19. Debrief and skill progression.
20. Portfolio/report viewer.
21. Settings, controls and accessibility.
22. Pause/save menu.

## 5. Key layout specification
**SOC dashboard**
- Top bar: current case, time, environment label, connection state (simulation).
- Left rail: alert queue, severity and filters.
- Center: event timeline and correlation workspace.
- Right rail: selected evidence, affected asset, confidence and recommended next actions.
- Bottom: action tabs — Investigate, Evidence, Contain, Report.
- Every alert has a clear source and timestamp. Avoid decorative fake telemetry.

**Terminal**
- Large fixed-width font, line spacing, clear prompt and output separation.
- On Deck: virtual keyboard support, command history, syntax help, controller-driven token editing.
- Always show “SIMULATED ENVIRONMENT — NO HOST COMMANDS” in the lab shell.
- Provide command palette and examples.

**World map**
- Nine district nodes, each with icon, short description, story state, available mission count and completion marker.
- Use large selection targets and avoid tiny hover-only controls.

## 6. Typography
Use an open-license pixel/display face for headings and a highly readable sans-serif or mono face for body and terminal text. Check glyph coverage, punctuation and localization. Do not use decorative pixel fonts for long paragraphs. Include scalable UI font sizes.

## 7. Motion and effects
- 60 FPS target for UI animation on capable hardware; graceful reduced-motion mode.
- Short transitions, subtle screen wipes, restrained glow, animated map nodes and clear alert-state changes.
- Avoid constant scanlines, flicker, shake or parallax that can trigger discomfort.
- Respect OS reduced-motion preferences where available and offer in-game toggle.

## 8. Accessibility
- Remappable controller and keyboard controls.
- Full navigation without mouse.
- Adjustable text scale and contrast.
- Color-blind-safe redundant indicators.
- Captions for dialogue and audio cues.
- Pauseable dialogue and adjustable text speed.
- Reduced motion and screen shake toggle.
- No timed response requirement for core learning objectives.
- Glossary and plain-English definitions available everywhere.
- Dyslexia-friendly font option only if tested and licensed.

## 9. Steam Deck requirements
Design and test at 1280×800 and 1280×720. Valve's current compatibility guidance recommends 1280×800 where possible and text at least 9 px high, with 12 px recommended. All content must be reachable through default physical controls; text entry must support the on-screen keyboard or a built-in controller-only entry method. Trackpads may support cursor-like interactions but must never be mandatory.

## 10. Mockup interpretation
The generated visual concept sheet is an art-direction reference, not final pixel-perfect production art. It contains six target screen concepts: title, city map, Switchboard HQ, SIEM investigation, safe terminal lab and case report. Rebuild each as a separate native Godot screen with responsive layouts and real data bindings.
