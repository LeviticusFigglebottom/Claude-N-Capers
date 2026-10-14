# Next heist: Gallery Night build plan (D-103)

Owner: LEAD. Status: **planning** (content freeze D-082 still on; this plan is paper only until the freeze lifts).
Design source of truth: `docs/design/heists/gallery_night.md` (G0, APPROVED D-075). This file is the *build* plan:
what changed since G0, who builds what, in which order, and how we prove it is playable.

## 1. Why Gallery Night first
| Heist | Size | Mode | New systems it needs | Verdict |
|---|---|---|---|---|
| **Gallery Night** | M | stealth + loud | few (see §3 audit) | **first** |
| Ostrander Federal | L | stealth + loud | NPC-carried keycard, computer hunt, long time lock | second |
| Afterhours | M | civilian start → stealth / loud | crowds (D4-02 dormant), civilian mode polish | third |
| Rolling Thunder | L | loud (ambush) | armored_truck, convoy_vehicle, C4 (A5-01..03) | last |

## 2. Freeze-lift gate (D-082 / D-086)
The build starts only when all three pass windowed through the real menus (ENV A `run_po5.sh`):
`gh_loud` (Glasshouse loud → payday → hub), `gh_stealth` (Glasshouse stealth win), `auto_loud` on Night Deposit.
A product-owner playthrough of Glasshouse that holds up also counts.

## 3. Audit of the G0 doc against today's code
(filled from the lead's audit, see §3 below once complete)

## 4. Rules the build must satisfy (lessons from the playability pass)
- Every objective carries `marker_tags` (ui_hud 1.8, D-089); casing objectives too.
- Public doors are casing-allowed by default (PO-5.11); locked/staff doors need the mask.
- Every NPC spawn tag maps to a real character via `NpcVisualTweak` (no capsules, PO-5.7).
- Key interior lights carry `viewmodel_lit` (layer 21, D-095).
- Director caps scale by crew (D-099); specials gated by difficulty.
- Bag weights per D-102 (paintings: LIGHT/MEDIUM per D-081).
- Stealth-only failure rules and fail_reason surfaced on the results screen (B's failure-path lane).
- `validate_level` PASS + PO-3 snag probe 0 + PP-C walk with no STUCK rows before G2.
- A windowed e2e flow for the heist (`auto_loud` + a stealth flow) is part of "done", not an afterthought.

## 5. Staffing (proposal, needs the product owner's OK)
Building a map and its cast is ENV C / ENV D work (both dormant). Options:
- **(a) Re-activate ENV C (Worlds) and ENV D (Characters)** as two more cloud sessions when the freeze lifts: C builds the
  Gallery Night greybox → G1 → G2 art pass; D builds the gallery cast (D3-01) and gala NPC animations (D3-02).
- **(b) Keep three sessions:** A takes the greybox (it already co-owns game/world/heists/** for the pass, D-086), B the
  content data, P the player-facing verification; art passes wait.
Recommendation: (a) for the map and cast; A/B/P keep their current lanes plus the Gallery Night systems/data work below.

## 6. Work breakdown (draft; ids become roadmap rows when the freeze lifts)
| Id | Owner | Task |
|---|---|---|
| GN-L1 | LEAD | Fold the §3 audit gaps into gallery_night.md (lead rulings), roadmap rows, gate test plan |
| GN-C1 | C (or A) | Greybox G1 per the doc's floor plans; all contract nodes; marker tags; validate_level |
| GN-C2 | C | G2 art pass + lighting (viewmodel_lit), review shots |
| GN-D1 | D | Gallery cast (curator, attendants, guards, gala patrons) + NpcVisualTweak tag map |
| GN-A1 | A | Missing prefabs/systems from §3; mission script; objective marker_tags; e2e flows (stealth + loud) |
| GN-B1 | B | HeistDef, contract/briefing/strings, loot defs (painting, painting_study $700 LIGHT), variant table data, pre-planning assets |
| GN-P1 | P | Real-menu windowed feel pass + snag probe on the greybox, then on G2 |
