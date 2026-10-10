# Level standards

Owner: **LEAD**. Binding on ENV C. The lead enforces it in review. A heist that violates any **MUST**
is rejected.

AI-built levels fail in predictable ways: floating props, clipping, single props in empty rooms,
nonsense floor plans, light from nowhere, default grey. This document exists to make those failures
**impossible to merge**.

---

## 1. Process (gates)

| Gate | Deliverable | Reviewer action |
|---|---|---|
| **G0 Design** | `docs/design/heists/<id>.md` using the template in §9: fiction, ASCII floor plan with real dimensions, room list with purpose, circulation, sightlines, stealth routes vs loud chokepoints, loot path, variable table, escape. | Lead approves or returns. **No geometry before G0 is approved** (status header `Status: APPROVED (lead, date)`). |
| **G1 Greybox** | Geometry from modular greybox kit (CSG or generated meshes, one flat material per surface class), navmesh, all contract nodes (spawns, patrols, zones, rooms, variants, gameplay prefabs with placeholder visuals), mission script working. `validate_level --stage greybox` passes. Walkthrough bot passes (§6). Top-down plan render + review shots. | Lead plays/inspects headless results and the review shots; approves layout. Changes to layout after G1 need a lead OK. |
| **G2 Art pass** | Final modular architecture, materials, props via dressing kits, lighting, audio ambience. `validate_level --stage final` passes. Full screenshot set. | Lead reviews every screenshot (§8). Rejections are listed per shot. |
| **G3 Polish** | Variant coverage shots (one set per variant option), perf capture, bug fixes. | Lead sign-off; heist is "shipped" in `docs/roadmap.md`. |

## 2. Architecture MUSTs

1. **Rooms have reasons.** Every room in the room list has a purpose consistent with the fiction;
   every `RoomVolume.purpose` matches the list. A building of that type would plausibly have it.
2. **Support spaces exist.** Any staffed building has restrooms (per floor or per 50 staff), a
   break room or staff kitchen, janitor/storage, an electrical/IT closet; commercial buildings have
   a loading/back entrance; multi-floor buildings have ≥ 1 stair core (2 if > 2 floors) plus fire exit.
3. **Circulation works.** Doors lead somewhere; corridors connect; no dead-end corridors without a
   reason (storage at end is a reason). Every room reachable on foot. Fire exits exist and are
   plausible.
4. **Exterior = interior.** The exterior shell matches the interior footprint; wall thickness
   0.15–0.3 m interior, 0.3–0.5 m exterior. No interior rooms poking outside the shell; no hollow
   shell areas without a room/plenum explanation.
5. **Windows only on exterior walls** (or interior glazing with clear purpose: office fronts, teller
   glass, vision panels). Window sill 0.8–1.0 m (offices), shop fronts from 0.3 m.
6. **Human scale (validated):**

| Element | Value |
|---|---|
| Door leaf | 0.9 × 2.1 m (single), 1.8 × 2.1 m (double); service doors 1.0–1.2 m; frame depth = wall |
| Ceiling height | 2.6–3.0 m residential/office, 3.0–4.5 m retail/lobby, 3.5–6 m warehouse/banking hall, ≤ 10 m atriums |
| Floor-to-floor | ceiling + 0.4–0.8 m plenum/slab |
| Stairs | riser 0.15–0.19 m, tread 0.25–0.32 m, width ≥ 1.1 m, landing every ≤ 16 risers, headroom ≥ 2.1 m |
| Counters | 0.9 m (service), 1.05–1.1 m (bar/teller transaction ledge) |
| Desk | 0.72–0.76 m, chair seat 0.45 m |
| Corridor width | ≥ 1.2 m public / ≥ 0.9 m service |
| Light switch | 1.2 m; outlets 0.3 m; thermostat 1.5 m |
| Pictures (centre) | 1.45–1.6 m; signs above doors 2.2–2.4 m; exit signs over doors |
| Security camera | 2.4–3.2 m (or ceiling), pointed at an entry/asset |
| Railing | 1.0–1.1 m |

7. **Stairs match floor heights** from `HeistMap.floor_heights` exactly (validated).
8. **Ceilings exist** wherever the design says indoors; no "open to sky" interiors unless atrium.

## 3. Props and decoration MUSTs (the "nothing floats, nothing clips" rules)

1. **Nothing floats.** Every prop rests on a support (floor, counter, shelf, other prop that is
   designated a support) or is mounted (wall, ceiling). Tolerance: base ≤ 0.01 m above support,
   ≤ 0.005 m penetration. Mounted props declare `meta mount = "wall"|"ceiling"` and must be within
   0.01 m of the surface. **Validated programmatically** (§7).
2. **Nothing clips.** No prop's collision/AABB-OBB intersects walls, floors, other props, doors'
   swing arcs, windows, or navmesh-critical clearances. Fix by placement — never by hiding,
   disabling collision, or scaling into a gap.
3. **Flush and oriented.** Wall items flat (|normal · wall normal| ≥ 0.999) and facing into the room.
   Desks face sensibly (back to wall or island with walk-around); chairs face their desk/table
   (±20°); monitors face the chair; TVs face seating; toilets/sinks against walls with plumbing
   logic; doors swing into rooms (not corridors) unless fire-exit; door swings never hit props.
4. **Nothing half-done.** No room with < its kit's minimum prop count; no lone prop in the middle of
   a room; no untextured faces; no missing back faces / back walls visible from any reachable
   point; no visible level edge (skybox or exterior dressing beyond play space; no void); no
   z-fighting (coplanar surfaces offset ≥ 0.002 m or merged); **no default material** (validated).
5. **Natural density and logic.** Rooms use **dressing kits** (`world/kits/<kit>.tres`) per purpose,
   each with: required items (a break room *must* have fridge, table, chairs, counter+sink,
   microwave/coffee, bulletin board), optional items with weights, clutter groups (desk clutter,
   counter clutter, floor clutter near walls/doors), min/max density per m². Kit placement is
   seeded and **varied** so no two rooms of the same kit are identical (validated: layout hash
   differs). Clutter clusters where humans leave it (desks, near doors, corners, counters) — never
   uniformly scattered.
6. **Distinct and readable.** Each heist has a palette (style guide §3), ≥ 2 landmark features
   visible from main circulation (e.g. Glasshouse: the circular chandelier display; the neon
   storefront sign), and lighting that differentiates zones (public warm/bright, back-of-house
   cooler/dimmer, security room monitor glow). Stealth-relevant objects (cameras, keycard readers,
   guard posts) are readable silhouettes without being signposted (no glowing outlines in default
   state).
7. **Lighting is deliberate.** Every light source has a visible fixture (validated: each Light3D
   is parented to or within 0.3 m of a fixture mesh tagged `fixture`), except the sun/sky and
   designated fill/bounce probes (`meta fill = true`, energy ≤ 0.3, shadows off, ≤ 2 per room).
   Exteriors: one time-of-day per heist; window light direction matches sun.

## 4. Navigation and AI MUSTs

* Navmesh covers all walkable areas; no navmesh on counters/tables; door openings connected.
* Every PatrolGraph is connected; every PatrolPoint on navmesh; every guard post has ≥ 3 route
  options (heist_map.md §4).
* Police spawn points ≥ 3 directions, out of sight of loot/escape; ENTRY points at plausible
  breach places (doors, windows, roof hatch).
* Objectives, loot, escape, secure zones reachable from every player spawn, **for every variant
  option** (validated).
* Stealth routes exist that a skilled player can complete without kills on the hardest variant
  roll (verified by the design doc's route description + G3 playtest).

## 5. Performance MUSTs

Per-heist budgets from architecture.md §10; occlusion culling baked (OccluderInstance3D) for
interiors; ≤ 8 shadowed lights in any review shot; texture budget per style guide.

## 6. Walkthrough bot (headless, G1+)

`tools/levelcheck/walkthrough` (ENV C, using ENV A's nav + CrewIntent once available; before that,
pure navmesh path queries): from each player spawn, path to every objective, loot spawn, secure
zone, escape zone, and every interactable `UsePoint`; fail on any unreachable target or path
longer than 3× straight-line distance (suspicious detour) unless whitelisted in the design doc.

## 7. `validate_level` — the automated gate (spec; ENV C implements)

Command: `tools/levelcheck/validate_all.sh` → for each heist runs
`godot --headless --path game res://world/tools/validate_level.tscn -- --heist=<id> --stage=<greybox|final> [--variants=all]`
and writes `docs/levels/<id>/validation.md` + exit code. Checks (each prints offending node paths
and positions):

| Check | Rule | Stage |
|---|---|---|
| contract_nodes | required children exist with exact names; HeistDef/VariantTable assigned | all |
| floating | each prop (group `prop` / under `Props`) not mounted: downward ray/shape cast from AABB-bottom finds support within 0.01 m; mounted: within 0.01 m of surface along -Z (wall) / +Y (ceiling) | all |
| clipping | pairwise OBB/convex overlap between props and with static world (Jolt `intersect_shape`); penetration > 0.005 m fails; door swing arcs swept | all |
| orientation | wall-mounted alignment, chairs→desk, monitors→chair (meta `faces` links) | final |
| scale | door sizes, ceiling heights per room purpose, stair riser/tread vs floor_heights, counter heights (meta `kind`) | all |
| navmesh | coverage (sample points on walkable floors), all contract markers within 0.25 m of navmesh | all |
| reachability | from all player spawns to all targets, for each variant option (`--variants=all`) | all |
| patrols | connectivity, ≥ 3 route options per post | all |
| materials | no surface with null/default material; no missing textures; texel density within style guide ±50% | final |
| zfight | coplanar overlapping faces with different materials | final |
| lights | fixture rule, shadow-light count per room, fill-light limits | final |
| density | per RoomVolume: kit required items present, prop count within kit min/max per m², no lone prop (prop with no neighbour within 2 m in rooms > 12 m²) | final |
| variety | same-kit rooms have different layout hashes | final |
| bounds | no reachable point sees the void (sample camera rays from navmesh points at eye height hit geometry or sky within 500 m) | final |
| perf | draw calls / triangles / lights in each review camera within budget | final |

Validation must be **deterministic** and run in < 5 min per heist in CI.

## 8. Review screenshots (G1/G2/G3)

* `HeistMap.review_cameras` lists ≥ 12 fixed shots per heist (≥ 1 per major room, 2 exterior, 1
  top-down plan, 1 per landmark, 1 per security room/vault). Rendered by
  `res://world/tools/review_shots.tscn` (ENV C) at 1920×1080 with final lighting to
  `docs/levels/<id>/<stage>/<camera>.png` plus a contact sheet `contact_sheet.png` and a
  `shots.md` with captions. CI headless can't render; ENV C renders with `--rendering-driver opengl3`
  / xvfb as available and commits the images (≤ 400 KB each, JPEG quality 85 allowed).
* **Lead review checklist per shot:** plausible architecture; nothing floating/clipping; density and
  grouping natural; no repetition visible; materials not default/stretched; light sources visible;
  readable stealth objects; palette consistent; scale feels human (compare door/counter).

## 9. Heist design doc template (`docs/design/heists/<id>.md`)

```
# <Name> (<id>)
Status: DRAFT | APPROVED (lead, YYYY-MM-DD) | CHANGES REQUESTED
## Fiction            who, what, why, contact, time of day, weather
## Modes              stealth+loud / stealth-only / loud-only; difficulty notes
## Site               lot size (m), street context, neighbours, exterior landmarks
## Floor plans        ASCII per floor, 1 char = 0.5 m or 1 m (state it), with dimensions,
                      doors (D), windows (W), cameras (C), guard posts (G), loot (L), escape (E)
## Room list          id | purpose | size m | ceiling m | kit | notes
## Circulation        public flow, staff flow, guard patrol loops, civilian flows
## Sightlines         key LOS lines (camera cones, guard posts), blind spots that make stealth routes
## Stealth routes     ≥ 2 distinct approaches; tools needed; pager budget expectations
## Loud               chokepoints, holdout spots, police entry points, sniper perches, special spawns
## Loot path          loot → bag → secure zone path(s), throw spots
## Objectives         ordered list (stealth) and (loud), with mission script notes
## Variable table     variable | options (slot ids) | weights | gameplay effect (what decision it changes)
## Rare events        good/bad outcomes with chance and effect
## Escape             types, timing, locations
## Pre-planning       assets, favors, spawn/drop choices
## Audio/lighting     ambience, palette, lighting moods, music track
```
