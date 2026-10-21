# Next-heist prep (D-144): Rolling Thunder and Afterhours, ENV B side

Notes only (LEAD 2026-10-21): what B content / strings / UI exists today (trunk e91fa3c0) and what is missing, with
Ostrander Federal (OF-B1) as the checklist. Neither heist has a world folder (`game/world/heists/<id>/`) yet, so
everything map-derived waits on C's G1.

## Inventory

| Item (B unless noted) | Ostrander Federal | Rolling Thunder | Afterhours |
|---|---|---|---|
| `heist_list.tres` entry | yes, shown | yes, **hidden** | yes, **hidden** |
| Board city map, heist accent | yes | yes | yes |
| `heist.<id>.*` strings (name, tagline, briefing, ...) | 5 | 4 | 4 |
| `objective.<id>.*` strings | 21 | 13 (= all 13 doc tags) | 12 (= all 12 doc tags) |
| `ui.briefing.step.<id>.*` (merged briefing steps) | 2 | 0 | 0 |
| Voice lines (`voice.vo.*`, `lines.tres`) | 77 strings, wired | **0** | **0** |
| Heist achievements (+ mask-part rewards) | 6 | **0** | **0** |
| Briefing intel (`briefing/intel/<id>.tres`, scanned from the map) | yes | **no** (needs map) | **no** (needs map) |
| Pre-planning blueprint (`preplanning/blueprints/<id>.tres`) | yes | **no** (needs map) | **no** (needs map) |
| Pre-planning assets naming the heist | via def | none | 2 (`intel_safe_code`, `intel_product`) |
| Loot defs named in the design doc | all exist | all exist (cash_bricks, gold, bearer_bonds, thermite) | all exist (cash_bricks, cash, parcels, body_bag) |
| Contact | Accountant | Reyes (exists) | Accountant + Reyes (exist) |
| Music track | `ostrander_federal` | **none** (heist default) | **none** (heist default) |
| B tests that name the heist | 11 | 2 | 4 |
| World dir / HeistDef / mission (C / A) | yes | **no** | **no** |

## Missing on the B side (in order, once C's G1 lands)

1. **Def values + variant data** (OF-B1 §6 shape): base_payout (RT doc: $85k; AH doc: $75k, D-120 shape), difficulty
   rows, the variant / rare-event values block for C's generator (guard_post `difficulty_add`, scalars), small-loot
   values (AH doc lists the prefab values for B, D-068).
2. **Briefing intel + blueprint**: run `intel_export.gd` and the blueprint export on the G1 map; briefing lines per
   difficulty (pager / D-140 GUARDS row, Titan), located lines.
3. **Strings**: `ui.briefing.step.<id>.*` merges; pre-planning point / asset labels; blueprint labels; escape names;
   rare-event and surprise names; the D-142 glazing flag if the map has notable glass.
4. **Voice**: the full contact / Mercer line set (radio objective lines, ETA lines, last pager, mission says) in
   `lines.tres` + strings, then `test_vo_coverage` (every written line said, or deleted).
5. **Achievements**: the heist set (stealth / speed / loud signature / all-bags / Cataclysm), each with a mask-part
   reward (D's parts), `test_heist_achievements` cases, and the payday e2e (copy `test_of_payday_e2e.gd`).
6. **Music**: a heist track id (ENV D / audio) or keep "heist default".
7. **Tests to extend**: `test_heist_text_audit.HEISTS`, `test_heist_achievements.HEISTS`, `test_briefing_intel`,
   `test_heist_readiness`, `test_p5_catalogue`, `test_vo_coverage` allowlists.
8. **Un-hide** in `heist_list.tres` only after A's phase-2 e2e is green (same gate as OF), then the real-input menu
   pass at 720p / 1080p (`real_input_run_capture.gd -- <out> <id>`) and the HUD timer probe if the heist has timers.

## Ready now (no map needed)

- Objective strings already cover every doc tag for both heists; contact and loot defs exist.
- Afterhours already has its two intel pre-planning assets.
- RT is LOUD-leaning with an ambush/convoy line: check early that the HUD handles a moving objective marker (convoy)
  and an escort objective; B can mock both in `contrast_worker` / the HUD mock before the map lands.
