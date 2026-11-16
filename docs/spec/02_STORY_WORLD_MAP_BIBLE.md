# 02 — Story, Lore and World Map Bible

## 1. New Meridian
New Meridian is a fictional Great Lakes city inspired by the texture and diversity of Detroit and neighboring communities, not a one-to-one copy. It has historic neighborhoods, renovated industrial corridors, independent businesses, hospitals, schools, music spaces, municipal infrastructure, a riverfront, transit systems and a growing technology scene.

The city is alive beyond the cyber plot. People commute, make music, run shops, coach youth teams, organize block events, study, build businesses and look after one another.

## 2. Main campaign: THE GHOST NETWORK
A series of incidents initially appear unrelated:
- A neighborhood credit union reports suspicious account access.
- A hospital scheduling platform becomes unreliable.
- A school district sees account takeovers.
- A music label discovers unreleased files accessed by an unknown account.
- A logistics operator experiences disruption after a vendor compromise.
- A municipal AI assistant exposes information it should not reveal.

The Switchboard finds repeated identity, supplier, monitoring and recovery weaknesses. The Ghost Network has been exploiting the gaps between organizations. The final act is not a boss fight against a keyboard wizard; it is a coordinated defense and resilience operation.

## 3. District map
Suggested connected layout:
```text
                 [CLOUD NINE]
                      |
[IRONWORKS] — [SWITCHBOARD HQ] — [SIGNAL STUDIOS]
      |               |                 |
[THE UNDERGRID] — [MARKET ROW] — [EASTSIDE ACADEMY]
                      |
               [MERIDIAN MEDICAL]
                      |
                  [THE BLOCK]
```
This is a logical map, not a geographic claim. Each district has a hub, side stories, key contacts, a main mission chain and a visible “community resilience” state.

## 4. District design
| District | Story role | Technical curriculum | Visual identity |
|---|---|---|---|
| The Block | Meet residents and local businesses | Digital safety, fundamentals, phishing, accounts | Brick storefronts, murals, warm streetlights |
| Switchboard HQ | Main player base | SOC operations, SIEM, case management, reporting | Purple/black ops floor, CRT-inspired accents |
| Market Row | Credit union and small business corridor | Fraud, identity, MFA, access control, privacy | Busy storefronts, market signage, buses |
| Meridian Medical | Hospital and care network | IR, availability, risk, privacy, critical services | Clean teal/blue lighting, calm clinical spaces |
| Eastside Academy | School and training center | Windows, Linux, AD, endpoint, identity | Classrooms, labs, gym, community center |
| Signal Studios | Music and media businesses | AppSec, cloud, data protection, supply chain | Recording booths, creative workspaces |
| Ironworks | Industrial and logistics zone | Network defense, OT/ICS, segmentation, safety | Warehouses, rail, industrial lighting |
| Cloud Nine | City innovation campus | AI security, cloud, secure agents, governance | Glass towers, rooftop labs, violet-blue light |
| The Undergrid | Threat intel and adversary story layer | Threat intel, ATT&CK, forensics, malware triage | Substations, tunnels, server rooms; fictional only |

## 5. Campaign acts
**Prologue — First Signal:** A local business reports account trouble. Teach basic account hygiene, what an alert is, and how to ask good questions.

**Act I — The Block Is Connected:** Investigate phishing and suspicious sign-ins across Market Row. Introduce logs, identity, MFA, ticketing and evidence.

**Act II — Patterns in the Noise:** At Switchboard HQ and Eastside Academy, correlate endpoint, Windows, Linux and directory events. Introduce SIEM queries, alert triage and ATT&CK mapping.

**Act III — Keep the Lights On:** Meridian Medical and Ironworks incidents teach impact analysis, containment trade-offs, backups, OT safety and coordinated incident response.

**Act IV — The Data Has a Route:** Signal Studios and Cloud Nine reveal cloud, application, supply-chain and AI system weaknesses.

**Act V — Ghost Protocol:** Combine threat intelligence, forensic timeline, identity containment, vendor coordination, recovery and executive/community communication.

**Epilogue — Stronger Together:** The player presents a defensible incident report, resilience plan and learning portfolio. New optional specialist investigations unlock.

## 6. Story-to-curriculum integration
Every major technical concept must be motivated by a character or community need:
- MFA protects a credit union member, not an abstract account.
- Logging helps a hospital understand a service disruption.
- Secure development protects an artist's unreleased work and customer data.
- AI prompt injection matters because a city assistant has access to sensitive knowledge.
- OT safety matters because industrial control decisions can affect physical operations.

## 7. Dialogue rules
- Write natural dialogue with varied voices; avoid every character using the same slang.
- Use local references sparingly and accurately; hire local readers/consultants.
- Let characters disagree respectfully about trade-offs.
- Explain acronyms after the character has a reason to use them.
- Do not use poverty, crime or trauma as shorthand for Black identity.
- Show joy, expertise, ambition, family, humor, art, care and ordinary daily life.

## 8. Mission template
Each mission contains: hook, affected people, asset inventory, player role, prerequisites, learning objectives, briefing, guided lesson, simulated environment, evidence list, tasks, optional clues, safe terminal commands, assessment rubric, debrief, framework mappings, portfolio artifact, story consequence, reset state and accessibility notes.
