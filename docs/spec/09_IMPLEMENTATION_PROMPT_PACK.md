# 09 — Implementation Prompt Pack for Claude Code / Codex

Use prompts in order. The agent must inspect the repository before modifying it, preserve working features, write tests, and report evidence. Never claim a feature is complete if it is stubbed.

## Global engineering contract
You are the lead Godot 4 engineer implementing THA T.R.A.P., a modular single-player cybersecurity education RPG. Read all project documentation first. Treat the product charter and safety rules as binding. Use GDScript-first architecture, typed APIs where practical, data-driven content, deterministic simulation and controller-first UI.

**Never:**
- execute player-entered text in a real shell,
- access external networks from a lab,
- run malware or exploit code,
- store real credentials,
- use arbitrary eval/dynamic execution,
- bypass OS or user permissions,
- invent test results,
- leave placeholder controls in release paths,
- silently remove existing functionality.

For each task: inspect → plan → implement → test → review → summarize changed files, test commands, results, risks and remaining work.

## Prompt 1 — Repository audit and implementation plan
Inspect the repository and compare it against the production package. Identify current engine version, project structure, existing systems, broken paths, missing assets, tests and platform assumptions. Produce a gap analysis and phased implementation plan. Do not modify files until the audit is complete and the plan is presented.

## Prompt 2 — Godot foundation
Create the modular Godot project foundation: bootstrap, scene flow, event bus, configuration, profile, save service, input abstraction, diagnostics and test harness. Use signals and clear ownership boundaries. Add typed interfaces and tests. Verify Windows/Linux exports can be configured and that no credentials are committed.

## Prompt 3 — UI system
Implement the custom palette, typography tokens, panel/button/tab components, dialogue box, modal, tooltip, navigation focus system, scalable text and reduced-motion support. Build title, pause, settings and character creator screens. Every interactive control must work with controller and keyboard. Do not create static mock controls.

## Prompt 4 — World and campaign
Implement district data, New Meridian map, player movement, NPC interaction, dialogue graph, mission unlocks, story flags and community consequence state. Build The Block and Switchboard HQ as the first playable spaces. Add content validation for IDs and branches.

## Prompt 5 — Simulation safety kernel
Implement a deterministic local simulation runtime. The lab terminal must use an allowlisted parser and scenario data only. Do not call OS.execute, shell, network, eval or arbitrary script execution. Add negative security tests for host command attempts, path traversal, injection and malformed input. Prove reset restores baseline state.

## Prompt 6 — SIEM and evidence system
Implement synthetic event records, query grammar, filters, grouping, timeline, alert queue, evidence IDs, case notes, case severity and report generation. Keep simulation logic separate from UI. Add parser fuzz tests and golden dataset tests.

## Prompt 7 — Learning and assessment engine
Implement curriculum data, glossary, lesson cards, guided hints, adaptive difficulty, rubrics, mastery states, skill graph and portfolio artifacts. Require evidence-based assessment; multiple choice alone cannot award independent mastery. Add content validation.

## Prompt 8 — LAB-001 vertical slice
Build “Somebody’s In The Network” from briefing to debrief. Include synthetic authentication and MFA events, query tasks, evidence collection, timeline, ticket, risk-based recommendation, rubric, hints, reset and portfolio export. Test the full path from a new save.

## Prompt 9 — Campaign content production
Create mission packages for all campaign acts and districts. Each mission must follow the lab schema, include story motivation, learning objectives, safe actions, evidence, answer rationale, framework mappings and accessibility notes. Do not copy third-party lab content.

## Prompt 10 — AI security module
Build synthetic AI assistant and agent scenarios covering prompt injection, sensitive data disclosure, retrieval poisoning, insecure output handling, excessive agency/tool permissions, supply-chain risk and monitoring. Use offline simulated components only. Map to current OWASP GenAI and MITRE ATLAS versions with source metadata.

## Prompt 11 — Platform and Steam Deck hardening
Test 1280×800 and 1280×720, controller-only navigation, on-screen keyboard, trackpad optional cursor mode, glyph correctness, text scale, focus order, sleep/resume, save integrity and low-power performance. Create Windows and Linux export presets. Record real test evidence; do not claim Deck Verified unless Valve has granted it.

## Prompt 12 — Release audit
Run unit, integration, E2E, content, security, performance, accessibility and compatibility suites. Audit licenses, privacy, save migration, installer/uninstaller and documentation. Block release for any critical/high defect, unreviewed asset license, unsafe execution path or broken controller-only progression. Produce release candidate report and known-issues list.

## Required completion report
1. Implemented features.
2. Files changed.
3. Tests run and exact outcomes.
4. Manual tests still required.
5. Security and safety findings.
6. Performance measurements.
7. License and attribution changes.
8. Known defects and risks.
9. Recommended next milestone.
