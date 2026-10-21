# Ostrander Federal G2: draw-call budget (D-146, OF-C2)

D-146 (addendum 6) judges the budget on **Forward+ on the GPU box**, with the Cataclysm cast and a loud assault:
main pass ≤ 2,500 and total ≤ 4,000 per view, shadowed lights ≤ 8. levelcheck `perf` is a conservative
Compatibility model and only reports (warnings). It has no occlusion and keeps every variant active.

## Shipping renderer: Forward+, RX 9070 XT, loud, Cataclysm, 33 NPCs (origin/gpu/renders gpu/perf/ostrander_federal_loud.txt)

| view | total | map | cast | all shadows off |
|---|---|---|---|---|
| hall_south_eye | 2,196 | 1,455 | 741 | 722 |
| hall_south_high | 2,018 | 1,288 | 730 | 539 |
| hall_west_diag | 2,258 | 1,449 | 809 | 817 |
| rc_hall_entrance | 2,201 | 1,481 | 720 | 769 |
| rc_hall_counter | 2,010 | 1,382 | 628 | 691 |
| rc_hall_from_gallery | 1,539 | 858 | 681 | 487 |

OF passes D-146 with about 1,750 draws to spare.

## Fallback renderer: Compatibility (opengl3, llvmpipe), D's heist_cast_perf, stealth, Cataclysm, seed 1037, 29 NPCs

Measured on c426eb96 plus D's CrowdLod no-shadow change (7ba413d8), at 320x180 (draw counts do not depend on
resolution), with occlusion culling on and the variants resolved by the game:

| view | frame (with the cast) | sun shadows off | positional off | main = map + cast | cast out of the pendant's casters |
|---|---|---|---|---|---|
| hall_south_eye | 3,163 | 2,000 | 2,033 | 1,167 = 1,069 + 98 | 2,981 |
| rc_hall_entrance | 3,102 | 1,982 | 2,089 | 1,210 = 1,069 + 141 | 3,050 |
| rc_hall_counter | 2,508 | 1,041 | 2,123 | 1,041 = 857 + 184 | 2,433 |
| rc_hall_from_gallery | 2,197 | 1,368 | 1,139 | 636 = 546 + 90 | 2,070 |

Before the cuts (r246) D measured 12,885 at hall_south_eye. NPC cast_shadow off beyond 12 m is not needed.

## levelcheck model vs the renderer (opengl3, 1280x720, map only, every variant active, no occlusion)

The model follows Godot's own culling (renderer_scene_cull.cpp, rendering_light_culler.cpp) and the Compatibility
passes (rasterizer_scene_gles3.cpp):
- **main**: surfaces in the frustum, out to the visibility range plus its margin;
- **lit**: one extra colour pass per surface for each paired shadowed positional light, plus one per shadowed sun;
- **shadow**: sun cascades, spot pyramid, omni ×6 cube faces, each with Godot's tighter caster culling.

Shadow draws are counted under VISIBLE in opengl3. Positional shadows were forced dirty each frame, as the moving
cast does.

| view, state | measured | model | diff |
|---|---|---|---|
| rc_hall_entrance r246, all shadows | 14,086 | 14,864 | +5.5 % |
| rc_hall_entrance r246, shadows off | 2,889 | 2,889 | 0 |
| rc_hall_entrance r246, sun only (shadow draws) | 8,160 | 8,392 | +2.8 % |
| rc_hall_counter r246, all shadows | 9,575 | 10,213 | +6.7 % |
| rc_hall_counter r246, shadows off | 2,381 | 2,381 | 0 |
| rc_hall_from_gallery r246, all | 2,376 | 2,393 (old margins) | +0.7 % |
| rc_hall_entrance 7231c5d6, all | 3,469 | 3,716 | +7.1 % |
| rc_back_corridor 7231c5d6, all | 3,641 | 3,888 | +6.8 % |

The model runs 0 to +10 % over the renderer, i.e. conservative. With occlusion on, the renderer drew less:
rc_hall_counter 3,307 → 2,055, rc_teller_workroom 3,602 → 1,890, rc_back_corridor 3,641 → 1,728,
hall_south_eye 3,551 → 2,255. A pixel diff of occlusion on vs off finds 0 changed pixels in 5 views (no
over-occlusion). The gap to D's game numbers (map main ~1,070 vs the model's 2,200-2,450) comes from occlusion and
from the variants resolved in the game.

## levelcheck, worst 10 views (Compatibility model, map only)

Before = r246 lighting; after = c426eb96 plus the VT soffit (this commit). Each cell is main / lit / shadow /
**total**, then shadowed lights in view.

| view | before | after |
|---|---|---|
| `rc_server_room` | 882 / 92 / 16300 / **17274**, 3 | 836 / 0 / 911 / **1747**, 1 |
| `rc_back_corridor` | 2637 / 704 / 12624 / **15965**, 7 | 2427 / 0 / 845 / **3272**, 1 |
| `rc_basement_corridor` | 2136 / 432 / 12732 / **15300**, 6 | 1971 / 0 / 933 / **2904**, 1 |
| `rc_client_lounge` | 1014 / 0 / 13831 / **14845**, 1 | 978 / 0 / 1016 / **1994**, 1 |
| `rc_hall_entrance` | 2889 / 758 / 11124 / **14771**, 8 | 2186 / 389 / 1349 / **3924**, 2 |
| `rc_deposit_hall` | 1387 / 0 / 13000 / **14387**, 1 | 1358 / 0 / 1131 / **2489**, 1 |
| `rc_vault_ops` | 878 / 0 / 12559 / **13437**, 1 | 846 / 0 / 857 / **1703**, 1 |
| `rc_teller_workroom` | 2697 / 800 / 9156 / **12653**, 7 | 2440 / 0 / 765 / **3205**, 1 |
| `rc_concourse` | 2100 / 454 / 8996 / **11550**, 6 | 1964 / 0 / 868 / **2832**, 1 |
| `rc_ext_lane` | 2447 / 599 / 7890 / **10936**, 8 | 2021 / 0 / 464 / **2485**, 1 |

## Changes (OF-C2)

- Sun: 2 splits over 30 m (was 4 over 90 m).
- PendantS2: CUBE shadow (Compatibility has no dual paraboloid) that distance-fades at 14 m (+5 m).
- The 6 room-fixture spot shadows are off.
- `Lighting/RenderBudgetPolicy` (game/world/lighting/render_budget_policy.gd):
  - interior dressing, loot, devices, containers and small variant props cast no shadow outside BH, and neither do
    doors between two interior rooms;
  - BH's dressing moves to render layer 5 (`sun_shadow_skip`, visual_slots v1.6), out of the sun's casters; the
    pendant still shadows it;
  - dressing visibility ranges outside BH/TW are cut to 24 m.
  - The shell, the finishes and the exterior doors keep casting, so no light leaks in.
- The navmesh is unchanged.
- VT's ceiling now uses a pale painted soffit (GPU review r250: the raw concrete read near black).

## Windowed evidence (opengl3, 1280x720)

`rc_hall_entrance_before_r246.jpg` / `rc_hall_entrance_after_7231c5d6.jpg` and the same pair for `rc_hall_counter`.
The sun shafts through the lantern and the glazing stay. The hall's floor keeps the shell and lantern shadows.

What these shots lose:
- The after shots are from 7231c5d6, where the pendant used dual paraboloid, so its shadow does not render in
  Compatibility. c426eb96 restores it.
- Small sun shadows of the hall dressing (the podium, the desks) are gone, by design of the layer-5 lever.

Shots of the final state go to the GPU box (D-146 addendum 6).
