# Ostrander Federal cast perf audit (OF-D1 / D-132, ENV D, 2026-10-20)

Tool: `game/world/characters/_tools/heist_cast_perf.tscn -- --heist=ostrander_federal --detail [--loud] [--view=]`
(HeistLauncher, **Cataclysm**, seed 1037, vip_client forced, 1280x720, opengl3 / llvmpipe). Draw calls are the
renderer's `TOTAL_DRAW_CALLS_IN_FRAME` (all passes, shadows included). Quiet and loud runs on trunk 8ed5fa93
(pre-r245); the shadow proposals on trunk e219930b (r245).

## 1. Where the frame goes (quiet, 28 NPCs: 10 guards, 18 civilians)

| View | Draws | Map | Cast | Cast prims | Full / proxy / off | Shadows off |
|---|---|---|---|---|---|---|
| hall_south_eye | 6052 | 4915 | 1137 (19 %) | 631k of 1.32M | 4 / 22 / 2 | 1653 |
| hall_south_high | 6207 | 4948 | 1259 (20 %) | 622k of 1.31M | 5 / 20 / 3 | 1667 |
| hall_west_diag | 5996 | 4926 | 1070 (18 %) | 560k of 1.24M | 4 / 22 / 2 | 1541 |

Loud (alarm + 90 s, 32 NPCs incl. 4 police), hall_south_eye: **6448** draws (map 4945, cast **1503**, 23 %),
prims 1.41M (cast 725k); shadows off: 1502. (One view: the run hit its time limit; the other two views are the same
room.)

**Readings**
1. **Shadows are ~73 % of the frame.** The only shadowed light is the hall's DirectionalLight3D; turning shadows
   off takes 6052 -> 1653 draws (6448 -> 1502 loud). The map is most of it (it is drawn into every cascade).
2. **The cast is ~20 % of draws but ~half of the primitives** (631k of 1.32M quiet): full-mesh NPCs near the camera
   dominate it: 188-235 draws each (a full NPC is ~5 surfaces x main pass + 4 cascades), a CrowdLod proxy ~51.
3. **Attached never-LOD geometry** (held weapons, hand props, anything without visibility_range_end): 143 nodes /
   45k tris quiet, 196 / 62k loud; hiding it saves 565 draws (9 %) quiet, 582 loud.
4. **The cast on its own shadow layer** (excluded from positional lights' shadow casters) gains nothing on OF: the hall
   has no shadowed positional lights (6052 -> 6002 is noise).

## 2. Proposals, measured (hall_south_eye, quiet, r245)

PROPOSALS_TABLE

## 3. Recommendation

RECOMMENDATION
