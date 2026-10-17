# D-130 character performance audit (ENV D, 2026-10-17)

D-130 raises stealth populations on the M heists (GN, SL, ND) by about +50 % guards and +35 % civilians at
Cataclysm. This audit measures what our characters cost at those counts and at the loud cap (`enemy_cap` 36 at
Cataclysm), and proposes fixes. Tool: `game/world/characters/_tools/bench_crowd.tscn` (`--stats` per character,
or a bench of N animating characters; usage in its header). The data is on env/d-art 53fa7154, trunk round 231.

## 1. Live characters at the Cataclysm max

From the design docs' roster totals x D-130, plus a crew of 4:

| Heist (mode) | Guards | Civilians | Other | Crew | Live skinned characters |
|---|---|---|---|---|---|
| Gallery Night (stealth) | 8 + operator + 2 Vaultline | ~20 (15 x 1.35) | | 4 | **~35** |
| Shadow Ledger (stealth) | ~8 + operator | ~7 | | 4 | **~20** |
| Night Deposit (stealth) | ~6 + operator + 2 armored-car | ~3 | | 4 | **~16** |
| Any loud heist, Cataclysm | police and specials up to 36 | ~10 (not yet fled) | | 4 | **~50** |

The loud case is the real worst case for every heist, not D-130's stealth counts.

## 2. Static cost per character (`bench_crowd --stats`, 93 cast and unit characters)

"Surfaces" are mesh surfaces at LOD0/LOD1, one draw call each, plus one more per surface in each shadow pass. LOD1
is Godot's automatic mesh LOD (first level, picked by screen size). LOD2 is our `CrowdLod` (one merged surface, one
draw).

| Group (n) | Surfaces avg (max) | Materials | Verts | Tris LOD0 | Tris LOD1 | Tris LOD2 | LOD2 from |
|---|---|---|---|---|---|---|---|
| Civilians (42) | 16 (22) | 14 | 20.5k | 28.5k | 14.2k | 4.2k | 20 m |
| Guards (27) | 24 (**32**: Halden security_officer) | 18 | 22.7k | 28.7k | 14.4k | 4.6k | 20 m (GN/SL/staff), 35 m (char_security) |
| Cartel (12) | 19 (24) | 17 | 22.8k | 29.1k | 14.6k | 4.6k | 35 m |
| Police (4) | 23 (27) | 17 | 25.7k | 31.2k | 15.3k | 3.8k | 35 m (one has none) |
| Specials (6) | 21 (23) | 15 | 24.7k | 30.5k | 14.8k | none (D-080 telegraphs) | n/a |
| Crew (2 sampled) | 18 (19) | 15 | 20.8k | 27.5k | 13.7k | none (player bodies) | n/a |

All characters have 52 bones and 12 inactive ragdoll bodies (PO6-19: the simulator is off until death).

Triangles are in good shape (29k at LOD0 is under the 35k budget, and LOD1/LOD2 cut it to 50 % and 15 %). **The cost
is the surface count:** each character within its LOD2 distance costs 16-32 draws, plus the same again per shadow
pass.

## 3. Bench

N characters looping `walk` from seeded offsets (with `--layer`, also the hold_rifle_walk upper-body layer on a second
AnimationPlayer, as AnimDriver does), at seeded spots 4-45 m in front of a camera (eye 1.65 m, FOV 75), one
shadowed directional light.

**CPU, headless (animation + skeleton; no rendering; AnimDriver logic, IK modifiers and AI not included):**

| Case | Process time per frame |
|---|---|
| empty | 0.2 ms |
| 12 characters | 0.6-0.9 ms |
| 34 characters (GN) | 2.0-2.4 ms |
| 34 characters + layer | 3.2-3.4 ms |
| 50 characters + layer (loud) | 4.3-5.5 ms |

So about **0.07 ms per character, 0.1 ms with the upper-body layer**, on this container's CPU, single-threaded.

**Render, windowed (xvfb + llvmpipe, 1280x720, 4 cores, shadows on).** llvmpipe renders on the CPU, so its frame
times only compare runs to each other. Some later runs overlapped other jobs, so read the **counters**, which are
exact:

| Case | Draws / frame | Primitives / frame | Frame ms (llvmpipe) |
|---|---|---|---|
| empty scene | 5 | 10 | 49 |
| GN 34, LOD as built (civilians/staff 20 m) | **1011** | 607k | 675 |
| GN 34, LOD off (all LOD0/1) | 1881 | 661k | 787 |
| GN 34, LOD2 from **15 m** | 738 (-27 %) | 573k | (contended) |
| GN 34, LOD2 from **10 m** | **557 (-45 %)** | 505k (-17 %) | (contended) |
| GN 34, tiny surfaces cast no shadow | 855 (-15 %) | (n/a, see note) | 923 (contended) |
| GN 34, 10 m + tiny surfaces no shadow | **489 (-52 %)** | (n/a) | 657 |
| Loud 50, as built (police 35 m, specials/crew none) | **2860** | 1.12M | 1397 |
| Loud 50, LOD off | 3127 | 1.17M | 2880 |
| Loud 50, police LOD2 from 25 m | 2572 (-10 %) | 1.11M | 1371 |
| Loud 50, 25 m + tiny surfaces no shadow | 2239 (-22 %) | (n/a) | (contended) |

Note: the bench's "no shadow on tiny surfaces" variant rebuilds those meshes without their automatic LODs, so its
primitive count is inflated. Its draw count is exact.

**Reading:** draw calls dominate. A GN crowd costs ~1000 draws per frame, and a Cataclysm loud fight ~2900, before the
map's own ~1-3k. On a real GPU that is the CPU render-thread cost that grows with D-130 (about 30 draws per near
character). Animation CPU (~3-5 ms) is the second cost, and it doesn't shrink with distance today.

## 4. Proposals

### In ENV D's domain (pipeline; no gameplay change)

| # | Change | Expected effect | Effort / risk |
|---|---|---|---|
| D1 | **Per-character material atlas at build:** bake each character's 256² albedo/ORM/normal tiles into one 1024² atlas set (16 tiles) and merge its opaque surfaces into **one surface** (+1 for alpha: hair cards / lashes where alpha is used). Keep the per-material data in SOURCE for the review renders. | Near-character draws **16-32 → 1-2** (-90 %), the same for shadow passes. GN 1011 → ~150, loud 2860 → ~600. The largest win by far. | Medium: tools/blender/characters build + assemble; ENV A's node paths unchanged (Body / Outfit / Gear ... meshes stay as nodes, only their surfaces merge per mesh first, then across meshes). Visual parity checked by review renders. ~1 day. |
| D2 | **Crowd LOD2 from 15 m for civilians/staff** (20 m today), 25 m for armed units (35 m today). | GN draws -27 %. Loud -10 %. | Trivial (`CROWD_SWITCH_M`, `UNIT_SWITCH_M`) + a 15 m review render. Our LOD2 holds up at 15 m after 1b375cb9 (shirt bleed fixed). |
| D3 | **No shadows from tiny surfaces** (eyes, iris, lashes, teeth, badges, < 150 tris): `cast_shadow` off on those surfaces (split into a shadow-less child at assemble). | -15 % draws at GN, -12 % loud. | Small. Redundant after D1. |
| D4 | **LOD2 shadow from a lower level** (optional): the CrowdLod casts its shadow from the same 15 % mesh; fine as is. | n/a | none |

D2 + D3 are cheap and land in one assemble (**-52 % draws at GN**). D1 is the structural fix, and it makes D3
unnecessary.

### For ENV A: animation LOD (AnimDriver)

Today every NPC's AnimationPlayer (plus the hold layer, plus the left-hand IK modifier for armed units) updates every
frame at any distance and off-screen. Proposal (PD2 does the same with its animation LOD):

| Distance from the local camera / state | Update | Notes |
|---|---|---|
| < 15 m, on screen | every frame | as today |
| 15-30 m, on screen | every 2nd frame (`callback_mode_process = MANUAL`, `advance(2 * delta)`) | the hold/aim layer at the same cadence; left-hand IK off beyond 15 m |
| > 30 m, or off screen (VisibleOnScreenNotifier3D on the body) | every 4th frame | no layer: drop the hold layer (influence 0) beyond 30 m |
| off screen and > 30 m | paused, re-synced (`seek`) when it comes back on screen | one-shots with events (reload `done`, death `impact`, mask_on) keep their **events** on a timer, never skipped (gameplay reads them; D-121: gameplay never waits on render-frame poses) |

The cadence offset is staggered per NPC (hash of net id) so the updates spread across frames. Expected effect: the
GN 34 case drops from ~3.3 ms to ~1.3 ms of animation CPU (about two thirds of a typical crowd is past 15 m or off
screen), and the loud 50 from ~5 ms to ~2 ms. Server and replays are unaffected: a peer animates only for its own
camera, and corpse and gameplay anchors are already server-side (D-121).

### Not needed

- Bones (52) and the inactive ragdoll (12 bodies, simulator off) cost nothing measurable while alive. RagdollTweak
  `max_active` 8 already caps simulating corpses.
- Triangles: LOD1/LOD2 already bring a crowd to ~0.5-0.6M primitives, which a GPU handles easily.

## 5. Suggested order

1. D2 + D3 (ENV D, one assemble, ~1 h with review renders).
2. A's animation LOD (ENV A).
3. D1 atlas merge (ENV D, ~1 day), then re-run this bench for the before/after table.
