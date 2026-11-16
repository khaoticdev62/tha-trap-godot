# 08 — Production Roadmap, QA and Release Plan

## 1. Production phases and exit gates
| Phase | Work | Exit gate |
|---|---|---|
| 0. Preproduction | Lock scope, core loop, threat model, story outline, curriculum map | Approved charter and vertical-slice plan |
| 1. Foundation | Godot project, input, save, scene flow, data models | Boot/menu/save/load works |
| 2. Visual slice | One district, player, dialogue, UI kit, pixel pipeline | Art and UI direction validated |
| 3. Simulation core | Event datasets, safe terminal, SIEM query engine, evidence | Deterministic LAB-001 passes tests |
| 4. Learning engine | Curriculum, hints, assessment, mastery and portfolio | Full learning loop works |
| 5. Vertical slice | The Block → Switchboard → LAB-001 → report | End-to-end playable 30–45 minute slice |
| 6. Campaign build | Districts, cast, missions, branches and consequences | All main acts playable |
| 7. Specialist curriculum | AI, cloud, OT/ICS, appsec, forensics, automation | Specialist capstones validated |
| 8. Content/art/audio | Final assets, localization-ready strings, music | License and content audits pass |
| 9. Hardening | Accessibility, performance, security, save migration | No open critical/high defects |
| 10. Release candidate | Windows/Linux/Deck tests, packaging, docs | Release checklist signed off |
| 11. Post-release | Framework updates, bug fixes, content packs | Maintained version and changelog |

## 2. Solo-developer execution strategy
Build one complete vertical slice before expanding the map. Use placeholder geometry only during development and remove it from release. Avoid producing all art before the core loop is proven. Implement data schemas and validators early so content volume does not create unmanageable manual work.

Recommended first milestone:
- Title and profile setup.
- The Block exploration.
- Switchboard HQ.
- One NPC dialogue chain.
- One SOC dashboard.
- One safe terminal.
- LAB-001 with synthetic logs.
- Case report and assessment.
- Save/load.
- Controller navigation.

## 3. QA layers
**Unit:** parsers, query engine, scoring, save migration, state transitions.  
**Integration:** mission-to-lab flow, evidence collection, report generation, progression.  
**End-to-end:** new game through campaign capstone, save/load, replay.  
**Content:** objective validity, dialogue branches, rubric correctness, mapping version.  
**Security:** no host shell, no external network, path traversal, malformed data, injection, unsafe execution.  
**Performance:** frame pacing, memory, loading, long log datasets, low-power Deck mode.  
**Accessibility:** controller-only, keyboard-only, text scaling, color contrast, captions, reduced motion.  
**Compatibility:** Windows, Linux, Steam Deck Game Mode and Desktop Mode.  
**Recovery:** corrupt save, interrupted write, missing asset, invalid content pack.

## 4. Acceptance criteria
- All core gameplay works offline.
- All labs reset reliably.
- Every terminal command is documented and sandboxed.
- Every assessment has a tested rubric and answer rationale.
- No critical mission depends on color alone.
- Every screen is navigable by controller.
- Deck text is readable at 1280×800 and 1280×720.
- Saves survive update and migration.
- No unknown-license assets ship.
- No critical/high security or crash defects remain.
- Framework source/version metadata is visible in curriculum references.
- No claims of certification or guaranteed employment.

## 5. Release checklist
- [ ] Version and changelog frozen.
- [ ] Framework mappings reviewed.
- [ ] All mission branches tested.
- [ ] Asset licenses and attributions audited.
- [ ] Privacy policy matches actual behavior.
- [ ] No telemetry by default unless clearly disclosed and consented.
- [ ] Windows installer and uninstall tested.
- [ ] Linux package tested on target distributions.
- [ ] Steam Deck physical controls verified.
- [ ] Steam Deck text and resolution verified.
- [ ] Save backup and migration tested.
- [ ] Accessibility settings verified.
- [ ] Crash logs contain no secrets or unnecessary personal data.
- [ ] Known issues documented.
- [ ] Store description does not overclaim job readiness.
- [ ] Support and update process documented.

## 6. Maintenance policy
Review framework sources at least monthly or when a major official release is announced. Use a change-impact matrix to identify affected lessons, mappings, hints, scoring and portfolio descriptions. Never silently alter a previously earned assessment. Publish a changelog and preserve historical curriculum versions.
