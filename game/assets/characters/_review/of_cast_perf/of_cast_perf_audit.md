# Ostrander Federal cast perf audit (OF-D1 / D-132, ENV D, 2026-10-20)

Tool: `game/world/characters/_tools/heist_cast_perf.tscn -- --heist=ostrander_federal --detail [--loud] [--view=]`
(HeistLauncher, **Cataclysm**, seed 1037, vip_client forced, 1280x720, opengl3 / llvmpipe). Draw calls are the
renderer's `TOTAL_DRAW_CALLS_IN_FRAME` (all passes, shadows included). Quiet and loud runs on trunk 8ed5fa93
(pre-r245); the shadow proposals on r246 (181957dd, 1280x720) and r249 (fe567f9f, `--shadows-only` at 320x180: draw
counts do not depend on resolution, llvmpipe does).

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
4. **The cast on its own shadow layer** (excluded from positional lights' shadow casters) gained nothing pre-r245: the hall
   had no shadowed positional lights then (6052 -> 6002 is noise); on r249 it saves 319 (section 2).

## 2. Proposals, measured

Budget (D-146, LEAD 2026-10-20): main pass <= 2,500 and total incl. shadow passes <= 4,000, with the peak cast.

**r246 (hall_south_eye, 1280x720)**: frame 12,885 (6 SpotLight3D + 1 OmniLight3D shadowed lights added in r246, plus
the sun); all shadows off 2,722; the cast's attached never-LOD geometry is down to 15 nodes (weapons now LOD).

**r249 (hall_south_eye, 320x180)**: frame **11,479**; 1 sun (4 splits, 90 m) + 7 positional shadowed lights.

| Option (each alone, measured) | Draws | Saving | Over the 4,000 after it |
|---|---|---|---|
| none (frame) | 11,479 | - | 7,479 |
| sun shadows off | 3,281 | -8,198 (sun = 71 % of the frame) | 0 (under, -719) |
| positional shadows off | 9,274 | -2,205 | 5,274 |
| sun 2 splits (was 4) | 7,140 | -4,339 | 3,140 |
| sun max_distance 45 m (was 90) | 8,952 | -2,527 | 4,952 |
| **cast** casts no shadows (r246) | -17 % of 12,885 | -2,242 | - |
| **cast** shadows off beyond 15 m only (r246) | | -788 | - |
| **cast** on its own layer, excluded from the 7 positional casters | 11,160 | -319 | 7,160 |
| main pass (all shadows off) | 1,395 = map 1,306 + **cast 89** | | under the 2,500 main budget |

The cast proposals (the D side) save 300-2,200 draws: worth taking, but they cannot meet 4,000 alone. The sun's 4
cascades re-drawing the roofed hall's map are the overage.

## 3. Recommendation

1. **C (map lighting, the lever):** the sun first. C's env/c-worlds 7153d4fa (r250-bound) takes the sun to 2 splits and
   30 m, turns the 6 room-fixture spot shadows off, makes the BH pendant dual-paraboloid and stops small props / dressing
   / doors casting outside BH; C's counter puts rc_hall_entrance at 3,696 map-only after it. If the sun still overruns:
   no sun shadow from interior meshes in the roofed hall (the sun only reaches through the lantern and windows).
2. **D (cast, after C's pass, if the total still exceeds 4,000):** in order of saving per change:
   (a) far NPCs cast no shadow beyond 15 m (CrowdLod proxies: `cast_shadow` off on the proxy mesh; measured -788 at
   r246, more at the peak loud cast), a one-line change in `crowd_lod.gd`; (b) the cast on its own render layer
   excluded from positional lights' shadow casters (-319 at r249; needs C's lights to drop the layer from
   `shadow_caster_mask`, and A to place NPCs on it). The cast's main pass (89) is already small.
3. Re-measure on C's head with `heist_cast_perf --shadows-only --view=rc_hall_entrance,rc_hall_counter,
   rc_hall_from_gallery,hall_south_eye` at 320x180 (C is running it), plus `--loud` for the peak cast.
