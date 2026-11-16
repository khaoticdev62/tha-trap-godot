# 04 — Lab and Simulation Specification

## 1. Lab engine principles
The lab engine is a deterministic simulation, not a real shell or network. Every lab loads a versioned scenario package containing synthetic assets, events, identities, network topology, evidence, expected outcomes, hints and reset data.

**Hard safety boundary:** commands are parsed by a custom allowlisted command interpreter. Never pass player input to `OS.execute`, a system shell, PowerShell, Bash, a real database, a real network socket, or an external service. No public IP targets, live credential capture, real malware, uncontrolled exploit code or host filesystem access.

## 2. Lab interaction modes
- Visual: dashboards, endpoint cards, identity maps, network diagrams, timelines.
- Terminal: safe, fictional command syntax with a visible help system.
- Query: limited SIEM query language over scenario datasets.
- Case file: evidence collection, notes, severity, scope, recommendations and handoff.
- Assessment: objective checks, rubric, hints, debrief and retry.

## 3. Example safe terminal
```text
help
assets list
hosts show HOST-014
logs search source=auth user=jsmith after=09:00
timeline build CASE-001
evidence add EVT-004 CASE-001
case note CASE-001 "Repeated failures then unusual success"
case report CASE-001
```
The parser returns simulated data only. Invalid syntax teaches through error messages; it never falls through to the host OS.

## 4. SIEM query language
Implement a deliberately small grammar:
```text
FROM auth_events
WHERE result = "failure"
AND user = "j.smith"
AFTER "2026-10-04T09:00:00"
GROUP BY source_ip
COUNT
SORT count DESC
LIMIT 20
```
Supported operations: SELECT/FROM, WHERE, AND/OR with parentheses, equality/inequality, contains, time range, GROUP BY, COUNT, SORT, LIMIT. No arbitrary SQL, file reads, network functions, dynamic evaluation or user-defined code execution.

## 5. Lab package schema
```json
{
  "id": "LAB-MR-001",
  "version": "1.0.0",
  "title": "Somebody's In The Network",
  "district": "market_row",
  "difficulty": "adaptive",
  "estimated_minutes": 25,
  "prerequisites": ["identity_basics", "log_basics"],
  "objectives": ["identify suspicious authentication pattern", "build evidence-backed timeline"],
  "scenario_data": "data/labs/market_row_001/",
  "allowed_actions": ["search_logs", "inspect_identity", "add_evidence", "write_report"],
  "forbidden_actions": ["host_shell", "external_network", "real_credentials"],
  "assessment": "rubrics/market_row_001.json",
  "framework_mappings": [],
  "reset_policy": "full_reset",
  "portfolio_artifact": "incident_triage_report"
}
```

## 6. Initial lab catalogue
| ID | Mission | Skills | Evidence/output |
|---|---|---|---|
| LAB-001 | Somebody's In The Network | Auth logs, SIEM search, timeline | Triage ticket |
| LAB-002 | Ghost in the Endpoint | Process tree, EDR concepts, host events | Endpoint investigation |
| LAB-003 | Code Blue | IR, patient safety, containment trade-offs | Incident action plan |
| LAB-004 | Don't Trust the Bot | Prompt injection, RAG poisoning, permissions | AI risk assessment |
| LAB-005 | Protect the Block | Scope, asset inventory, vuln prioritization | Authorized assessment report |
| LAB-006 | The Quiet Admin | Privileged identity, AD events, least privilege | Identity incident report |
| LAB-007 | Supply Chain Blues | Vendor access, software integrity, provenance | Third-party risk review |
| LAB-008 | Lights Out? | OT/ICS segmentation and safety | Safe OT incident plan |
| LAB-009 | Signal Lost | DNS, network telemetry, beaconing patterns | Network timeline |
| LAB-010 | The Long Weekend | Backups, recovery, ransomware response | Recovery validation |
| LAB-011 | The Leaky Studio | App security, access control, secrets, cloud logs | Secure remediation plan |
| LAB-012 | Ghost Protocol | Multi-domain capstone | Full case portfolio |

## 7. Fully specified sample: LAB-001
**Brief:** A Market Row credit union reports a member account takeover. A staff account has repeated authentication failures followed by a successful sign-in from an unfamiliar source. The player must determine whether the activity is suspicious, what is affected, what is still unknown and what should happen next.

**Learning objectives**
1. Parse authentication events.
2. Compare normal and unusual sign-in patterns.
3. Build a timeline with event IDs.
4. Distinguish indicator from conclusion.
5. Recommend proportional next steps.

**Synthetic evidence**
- EVT-001: failed sign-in, employee account, 09:12.
- EVT-002: failed sign-in, same account, 09:13.
- EVT-003: successful sign-in, new source, 09:16.
- EVT-004: new MFA enrollment request, 09:19.
- EVT-005: successful access to member support portal, 09:24.
- EVT-006: help-desk ticket says employee reports no recent login.

**Tasks**
- Search auth events for the account.
- Compare source, time, result and device.
- Correlate MFA and application events.
- Add at least four evidence records.
- Build a timeline.
- Classify severity and write a ticket.
- Recommend account protection and session revocation only after verifying identity and business impact.

**Scoring (100 points)**
- 20: correct query and event selection.
- 20: accurate timeline.
- 20: distinguishes confirmed facts from hypotheses.
- 15: impact and scope reasoning.
- 15: proportionate response recommendation.
- 10: clear report and escalation.

**Critical error:** declaring confirmed exfiltration without evidence, or recommending broad shutdown without scope/impact analysis. A critical error triggers coaching and reassessment, not a punitive dead end.

## 8. Adaptive difficulty
Adapt hints and dataset complexity, not the truth of the answer:
- Beginner: glossary, highlighted fields, guided query builder, small dataset.
- Standard: normal-size dataset, limited hints, partial query templates.
- Advanced: noisy telemetry, decoys, multiple hosts and ambiguous context.
- Expert: sparse hints, competing hypotheses, incomplete data and executive communication.

Never make a harder version depend on obscure trivia or hidden UI tricks.

## 9. Lab reset and replay
Every lab has deterministic seed, state snapshot, reset action, versioned scoring rubric and expected result set. Replays may change usernames, IP-like synthetic identifiers, event times and decoy records while preserving learning objective and answer validity.

## 10. Safety tests
- Host shell commands are rejected.
- `../` traversal and arbitrary file paths are rejected.
- No DNS/network request occurs from a lab.
- No user input reaches an eval/dynamic code path.
- Scenario reset restores baseline.
- Malformed JSON cannot crash the game.
- All logs and artifacts are synthetic and clearly labeled.
