# RT convoy escort EnemyDefs (RT-B1, D-149.12): handoff copies

The LEAD ruled the `enemy.convoy_lead` / `enemy.convoy_rear` EnemyDefs are B's data, but EnemyDefs live in
`game/systems/ai/data/enemies/` (ENV A's path in `tools/ci/owners.json`). Until the LEAD adds an ownership carve-out,
these are the files as B wrote them. Install map (`__` = subfolder):

| Copy | Install as |
|---|---|
| `convoy_lead.tres.txt` / `convoy_rear.tres.txt` | `game/systems/ai/data/enemies/convoy_<car>.tres` |
| `frd__convoy_<car>.tres.txt` | `game/systems/ai/data/enemies/frd/convoy_<car>.tres` |
| `sentinel__convoy_<car>.tres.txt` | `game/systems/ai/data/enemies/sentinel/convoy_<car>.tres` |
| `zero__convoy_<car>.tres.txt` | `game/systems/ai/data/enemies/zero/convoy_<car>.tres` |

## Values (from the design doc's "Convoy units per difficulty" table)
- **Base def** (`faction.tac`, Routine/Tense under `DirectorTweak.faction_by_difficulty`): the patrol car. Patrol
  Officer health / damage / speed / aim, `weapon.npc_pistol`, voice `police`. Its Hazardous+ columns are TAC Light's,
  used only if the faction table changes.
- **Faction defs** (FRD Hazardous/Brutal, Sentinel Lethal, Zero Cataclysm): the SUV. A copy of that faction's
  `tac_light.tres` (stats, rifle, voice, `visual_variant`, Zero's `surrender_immune`) under the convoy id.
- Neither def has body armor, so the PO-18 armored remap never touches them.

## Not in these files
- **Look (A / D, `npc_visual_tweak.tres`):** without an `enemy_characters` row the id `convoy_lead` has no character
  scene and the escort is a capsule. B tested with `enemy.convoy_lead` / `enemy.convoy_rear` -> `tac_light`
  (duty on Routine/Tense, faction reskins above). D picks the real ids.
- **The rear TAC Heavy and the Lethal+ Wrecker (A, mission):** `_spawn_convoy_units` currently fills every slot of a
  car with the convoy def, which would drop the doc's rear TAC Heavy (Hazardous+) and the rare Wrecker. Proposed: swap
  only the light-escort slots (`patrol_officer` / `tac_light`) and keep `tac_heavy` / `wrecker`.

## Verified (B, scratch install + the tac_light row, not committed)
`run_tests.sh a test_rt_`: 17/17, `test_rt_convoy_looks` PASS (no skip). Also green: `test_npc_weapon_models` (b) 3,
`test_po17_low_difficulty_police` 5, `test_d145_tense_pd2_hard` 2, `test_a1_09_police_ai` 6.
