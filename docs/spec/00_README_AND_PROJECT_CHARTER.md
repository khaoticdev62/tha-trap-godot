# THA T.R.A.P. — Production Package
**Threat Response And Protection**  
Version 1.0 · Baseline date: 16 November 2026 · Status: Production blueprint, not a completed game build

## Product charter
THA T.R.A.P. is a single-player, story-driven cybersecurity career RPG set in New Meridian, a fictional Detroit-inspired American city. Players begin as a curious beginner and develop into a capable defensive security practitioner by investigating incidents, learning systems, interpreting evidence, operating simulated SOC tools, communicating with stakeholders, and documenting defensible decisions.

**Promise:** Learn. Defend. Level Up.  
**World motto:** Stronger Together. Safer Tomorrow.  
**Core line:** The streets got networks. The networks got problems. And somebody has to protect the block.

## Locked wizard decisions
- Acronym: Threat Response And Protection.
- Premise: Build a community-centered cybersecurity defense collective protecting New Meridian from an interconnected cybercrime operation.
- Scope: Maximal, production-ready.
- Audience: Beginner to job-ready.
- Gameplay: Story-driven career progression.
- Labs: Hybrid realistic simulations + interactive terminal.
- Difficulty: Adaptive.
- Safety: Sandboxed, authorized, resettable; no real-world unauthorized targeting.
- Setting: Detroit-inspired fictional American city.
- Culture: Authentic contemporary Black American culture, locally grounded dialogue, music, fashion, humor, community and real-world social situations.
- Art: Premium 16-bit SNES pixel art with modern HD presentation.
- Palette: Custom palette.
- UI: Premium 2D 16-bit RPG menus blended with SIEM/SOC screens.
- Engine: Godot 4.
- Platforms: Windows, Linux, Steam Deck.
- Architecture: Modular single-player game with simulated cyber range.
- Assets: Free/open-source only; prioritize CC0.
- Deliverables: Game, curriculum, story, map, UI, art, lab, architecture, asset, production, QA/release and implementation documentation.

## Non-negotiable product principles
1. Every mission teaches a real skill and requires observable evidence of learning.
2. The game teaches defensive, authorized work. No live targeting, public IP scanning, credential theft, malware deployment, or uncontrolled exploit execution.
3. Player decisions have operational consequences; containment is not always the first or safest action.
4. Concepts are taught in plain English before acronyms and formal terminology.
5. Cultural representation is specific, respectful, collaborative and reviewed; no caricatures or token characters.
6. Framework mappings are versioned data, not hardcoded lore.
7. Job readiness is represented by demonstrated competencies and portfolio artifacts, never a job guarantee or certification claim.
8. All gameplay is usable offline after installation. No mandatory account, cloud AI, telemetry, or paid service.
9. The game must be fully playable with controller; keyboard/mouse are optional.
10. No fake, mocked, or placeholder functionality in release builds.

## Product boundaries
**In scope:** single-player campaign, simulated organizations, synthetic logs, local scenario engine, terminal emulator, query language, SIEM-like investigation interface, case management, adaptive tutoring, skill graph, portfolio exports, accessibility, save system, offline play.

**Out of scope for initial release:** multiplayer, live cloud range, real production integrations, real malware execution, unrestricted shell, public network interaction, AI assistant that can execute arbitrary tools, user-supplied executable samples.

## Release definition
A release candidate is complete only when all campaign-critical systems work, all labs have validated answer paths and feedback, safety tests pass, Windows/Linux builds launch, Steam Deck controls and text are verified, save migration works, licenses are documented, and no critical/high-severity defects remain open.

## Recommended repository layout
```text
tha-trap/
  project.godot
  README.md
  LICENSES.md
  CHANGELOG.md
  .gitignore
  addons/
  assets/
    characters/ environments/ props/ ui/ icons/ audio/ fonts/
  data/
    curriculum/ frameworks/ missions/ dialogue/ items/ organizations/
  docs/
  scenes/
    boot/ menus/ world/ districts/ characters/ soc/ labs/ reports/
  scripts/
    core/ game/ ui/ world/ soc/ labs/ learning/ save/ accessibility/
  tests/
    unit/ integration/ e2e/ content/ security/ performance/
  tools/
    content_validator/ asset_audit/ framework_sync/
  builds/
```

## Decision register
| ID | Decision | Reason |
|---|---|---|
| D-001 | Godot 4 + GDScript-first | Efficient 2D production and accessible solo-dev workflow |
| D-002 | Deterministic local simulation | Safe, reproducible labs and offline support |
| D-003 | Data-driven curriculum and mission content | Framework changes should not require rewriting gameplay code |
| D-004 | Fictional city and organizations | Avoid real victim data, defamation, or operational exposure |
| D-005 | Controller-first UI | Steam Deck and living-room usability |
| D-006 | No unrestricted shell | Prevent the training terminal becoming an unsafe host command runner |
| D-007 | Skills proven by artifacts | Better evidence of competence than XP alone |

## Definition of done for this blueprint
This package is a detailed implementation specification. It does not mean the game has already been coded, tested, licensed, or released. All unverified assets, external integrations, platform approvals, and framework mappings must be validated during production.
| D-008 | Lab id `LAB-001` is the stable id (`LAB-MR-001` kept as manifest alias); synthetic account is `j.smith` | Remove id/account contradictions between `04 §3-7` |
| D-009 | SIEM query grammar v1 per `docs/architecture/VERTICAL_SLICE_ARCHITECTURE.md` §6 (no `SELECT` in v1) | Implementable, testable subset |
| D-010 | LAB-001 = 6 canonical events + seeded noise; scoring uses evidence-id sets and fact/hypothesis tagging, not query text | Deterministic, fair scoring |
| D-011 | Controller-only text entry via token/palette builders and pickers; OS or Steam keyboard where available | Steam Deck requirement (`05 §9`) |
| D-012 | Phase 1 walkable space is Switchboard HQ only (with menu-hub fallback); The Block deferred | Keeps the slice shippable |
| D-013 | Repo layout follows the built repo plus `scripts/{data,simulation,gameplay}`; one new autoload `Progress` | Reconciles `00` and `06 §11` |
