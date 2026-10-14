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

## 3. Audit of the G0 doc against today's code (lead, 2026-10-14)
**Exists and reusable:** cameras + camera_station operator, ECM, keycard pickup, keypad/code notes, display cases,
small loot, deposit boxes (saw), safe SMALL (drill/lockpick/saw), thermal drill point, windows (+ rappel links), padlocks,
ladders, bag_lift, secure/escape zones, body containers, alarm buttons/phones, pagers/cuffs/civilian flee, HeistMission
timers + timed guard spawns, VariantResolver (pick-N, requires, min_difficulty), `gallery`/`atrium` scale bands.
**Cast: delivered** (game/world/characters: gallery_curator, gallery_attendant(_b), gallery_guard(_b), gallery_patron(_b),
penthouse guests/staff, armored_car_crew(_b); p5_cast.json). Content stubs exist: 4 painting loot defs, painting_study,
heist name/brief strings, Board entry (contact.vance), heist_list entry, accent.

**Partial:** keycard_reader (no off/on), hack_terminal (no runtime reconfigure API / alarm-group clear), laser_grid
(no `set_enabled`), loot_spawn (no `alarm_on_take`, no cut-canvas prompt), door (no relock/BAR + replication; NPC
door authorisation is guards-only; no NPC through VAULT doors), ambient clips `curator_inspect`, `cower_stand`,
`cower_seated`, `walk_text` exist in anim_humanoid but are unmapped in anim_driver / civilian activities.

**Missing:** QC-51..QC-59 (no code at all): runtime replicated MapZone kind flip + calm civilian exit/despawn (gala clock),
NPC-carried keycard, NPC bag carry (Vaultline), sensor alarm groups, intel pre-planning assets; the map (no
game/world/heists/gallery_night/), floor-plan script, validators `camera_spine`/`camera_screen`; HeistDef, variant table,
mission script, objective/VO/music strings, music track, blueprint; NpcVisualTweak gallery tags.
**Wrong:** `loot.painting_study` is $1,100 (D-081 says $700; test_p5_catalogue pins 1100).

## 3b. Lead rulings for the build (D-103)
1. **NPC visuals:** a SpawnPoint tag that maps in `NpcVisualTweak.tag_characters` takes priority over the EnemyDef's default
   character (so `guard_hall` etc. wear `gallery_guard`, and Shadow Ledger's Northgate guards can be fixed the same way).
   ENV A changes NpcVisuals' resolution order; EnemyDef stays the fallback.
2. **QC-56 dropped:** PO-5.11 (unlocked doors open while casing) covers it; staff doors that should be walkable while
   casing are simply NONE-locked. The doc gains a door lock table (public NONE / BOH lockpick / keycard / code / vault).
3. **No stealth-only fail** on Gallery Night; fail reasons are custody and abort only; required canvases must always stay
   reachable (a Vaultline delivery to the art store moves the canvas, it never destroys it).
4. **Every objective gets `marker_tags`**; key lights get `viewmodel_lit`; loud holdouts are re-checked per difficulty under
   D-099 (Routine = SWAT + shields only); paintings are LIGHT under D-102 (×1.0, sprint, 4 m throw), body bags MEDIUM.
5. **`painting_study` → $700** when the freeze lifts (B + its test).
6. **System groundwork first (general, reused by Ostrander/Afterhours):** ENV A builds the engine APIs before the map:
   door relock/BAR (replicated), keycard_reader set_disabled, laser_grid set_enabled, loot alarm groups + `&"sensor"`
   reason, hack reconfigure, runtime MapZone kind flip (replicated) + calm civilian exit/despawn, NPC-carried keycard,
   NPC door authorisation for staff roles, ambient clip mapping. Each with a unit test. This can start right after the
   freeze-lift runs, before the map exists.

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
- Automated: `game/tests/integration/test_heist_readiness.gd` (lead) checks marker_tags resolve on the real map and that
  no NPC is a capsule, for every delivered heist; Gallery Night is in its list and must pass once its map lands.

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
