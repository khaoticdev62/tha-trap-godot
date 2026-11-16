# 03 — Curriculum and Framework Bible

## 1. Curriculum model
Teach in a spiral: explain a concept, demonstrate it, practice it with support, test it independently, then revisit it in a more complex scenario. Use plain-English definitions, visual diagrams, short glossaries and “why this matters at work” explanations.

## 2. Career pathway
| Stage | Role fantasy | Core competencies | Capstone |
|---|---|---|---|
| 0. Digital Foundations | Community tech helper | Devices, accounts, files, privacy, basic troubleshooting | Secure a small business workstation |
| 1. IT & Network Foundations | Junior support technician | TCP/IP, DNS, DHCP, ports, Windows/Linux, users/groups | Diagnose a connectivity and account issue |
| 2. SOC Foundations | SOC trainee | Logs, alerts, triage, SIEM, ticketing, escalation | Investigate a suspicious sign-in |
| 3. Endpoint & Identity Defense | Junior security analyst | EDR concepts, Windows events, Linux auth, AD, MFA, privilege | Reconstruct endpoint + identity incident |
| 4. Threat Hunting & IR | SOC analyst | Hypothesis, timeline, ATT&CK, evidence, containment, recovery | Multi-source incident response |
| 5. Security Engineering | Developing practitioner | Vulnerability management, app/cloud security, automation, governance | Risk-based remediation plan |
| 6. AI & Specialist Defense | Specialist trainee | LLM/agent risks, ATLAS, OT/ICS, architecture, malware triage | AI service compromise investigation |
| 7. Professional Portfolio | Job candidate | Reporting, communication, metrics, ethics, prioritization | Integrated citywide capstone |

## 3. Module inventory
1. Digital citizenship, privacy and safe computing.
2. Hardware, operating systems, files, processes and services.
3. Networking: IP, subnet basics, DNS, DHCP, routing, ports, protocols, TLS.
4. Windows fundamentals, Event Viewer concepts, PowerShell concepts.
5. Linux filesystem, permissions, processes, auth logs and shell concepts.
6. Identity: users, groups, authentication, authorization, MFA, least privilege, directory services.
7. Endpoint security: telemetry, EDR concepts, baselines, isolation and false positives.
8. SOC operations: roles, alert triage, severity, escalation, ticket quality and metrics.
9. SIEM: event normalization, parsing, fields, correlation, searches, dashboards, detections.
10. Threat intelligence: indicators, context, confidence, freshness, sharing and limitations.
11. MITRE ATT&CK: tactics, techniques, sub-techniques, data sources, detection and mitigations.
12. Incident response: preparation, detection, analysis, containment, eradication, recovery, lessons learned.
13. Digital forensics: preservation, chain of custody, timelines, hashes, artifact interpretation.
14. Vulnerability management: asset inventory, scanning concepts, prioritization, remediation validation.
15. Penetration testing: authorization, scope, rules of engagement, safe lab methodology and reporting.
16. Application security: secure design, access control, input handling, secrets, logging, supply chain.
17. Cloud security: shared responsibility, IAM, storage exposure, audit logs, network controls.
18. Governance, risk and compliance: policy, risk register, control evidence, third-party risk.
19. Python and automation: parsing synthetic logs, enrichment, reporting, safe workflow automation.
20. AI security: prompt injection, sensitive data disclosure, retrieval poisoning, output handling, model supply chain, agent tools and permissions.
21. Malware analysis: safe static triage of synthetic metadata, hashes, strings and behavior reports; never execute live malware.
22. Digital privacy: data minimization, retention, consent, breach communications.
23. OT/ICS: safety, segmentation, asset visibility, change windows and incident coordination.
24. Security architecture: threat modeling, defense in depth, resilience and secure-by-design decisions.

## 4. Framework use — verified baseline vs implementation policy
**Verified facts checked for this package:**
- NIST CSF 2.0 uses six functions: Govern, Identify, Protect, Detect, Respond and Recover.
- NIST SP 800-61 Rev. 3 was finalized April 3, 2025 and supersedes Rev. 2. It integrates incident response with CSF 2.0 risk management.
- NICE Framework Components describe work roles, competency areas and task/knowledge/skill statements. NIST announced v2.2.0 on April 28, 2026.
- MITRE ATT&CK is a knowledge base of adversary tactics and techniques grounded in real-world observations.
- MITRE ATLAS is a living knowledge base for adversarial tactics and techniques against AI-enabled systems.
- OWASP Top 10:2025 is the current web application Top 10 in the official project pages checked for this package.
- OWASP GenAI published a 2026 Top 10 for LLM Applications (announced September 2026); therefore the wizard's 2025 LLM list is a historical baseline, not the latest version as of this package date.

**Implementation recommendation:** use the wizard's requested versions as explicit curriculum baselines, but provide a “framework version” selector and mark superseded material. At implementation time, compare the official current releases and use the newest version for new content. Do not silently label a 2025 list current when a 2026 version exists.

## 5. Mapping policy
Each learning objective may map to:
- NIST CSF 2.0 outcome(s), with rationale.
- NICE task/knowledge/skill statement(s), with exact version and ID.
- ATT&CK technique(s), only where the scenario demonstrates the behavior.
- ATLAS technique(s), only for AI threat scenarios.
- OWASP category, for application/LLM security.
- CISA guidance, where directly relevant.

Never force a mapping just to fill a field. Record `not_applicable` when no defensible mapping exists.

## 6. Learning assessment
Use a four-part assessment:
- Concept check: can the player explain the idea?
- Tool task: can the player use the simulated tool?
- Evidence reasoning: can the player cite artifacts and distinguish fact from hypothesis?
- Communication: can the player write a concise report for the intended audience?

Mastery levels:
- Introduced
- Guided
- Practiced
- Independently demonstrated
- Applied in a new context

Do not award “independently demonstrated” for a multiple-choice answer alone.

## 7. Reference links
- NIST CSF 2.0: https://www.nist.gov/cyberframework
- NIST SP 800-61 Rev. 3: https://csrc.nist.gov/pubs/sp/800/61/r3/final
- NICE current versions: https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center/nice-framework-current-versions
- MITRE ATT&CK Enterprise: https://attack.mitre.org/matrices/enterprise/
- MITRE ATLAS: https://atlas.mitre.org/
- OWASP Top 10:2025: https://top10.owasp.org/2025/
- OWASP GenAI: https://genai.owasp.org/
- CISA Secure by Design: https://www.cisa.gov/securebydesign
- TryHackMe SOC Level 1: https://tryhackme.com/path/outline/soclevel1
- InfoSecLabs: https://infoseclabs.io/

## 8. Learning design inspiration
TryHackMe's SOC Level 1 pathway demonstrates a structured progression through SOC roles, alert triage, SIEM, EDR, Windows/Linux monitoring, threat intelligence and capstone investigations. InfoSecLabs describes simulated SOC investigations, virtual desktop/CLI labs and sandboxed practice. Use these as learning-design references only. Do not copy their room content, proprietary scenarios, branding, screenshots, or assessment text.
