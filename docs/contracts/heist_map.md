# Contract: heist map (v1.4)

Producer: **ENV C** (maps). Consumer: **ENV A** (`HeistRuntime`, AI, stealth, director). ENV B reads
`HeistDef` for job board / briefing / pre-planning UI.

## 1. Files per heist

```
game/world/heists/<id>/
  <id>.tscn                 root node: HeistMap; launcher finds it via core `HeistRegistry.map_scene_path(id)` (contracts/map/heist_map.gd)
  <id>_def.tres             HeistDef
  <id>_variants.tres        HeistVariantTable
  <id>_mission.gd           heist-specific mission script (objectives wiring), extends HeistMission (ENV A base)
  greybox/                  greybox scene(s) kept until detail pass is approved
docs/design/heists/<id>.md  design doc (approved by lead before geometry)
docs/levels/<id>/           review screenshots + validate_level report
```

## 2. Required scene structure

```
<Id> (HeistMap)
├── Geometry            (Node3D) static meshes + StaticBody3D colliders, layer world_static
├── Props               (Node3D) dressing (validated: no float/clip)
├── Lighting            (Node3D) lights + WorldEnvironment + LightmapGI/VoxelGI as decided per heist
├── Navigation          (NavigationRegion3D) baked navmesh, layer `walkable`; vents use layer `vent`
├── Zones               (Node3D) MapZone volumes: PUBLIC, RESTRICTED, SECURE_LOOT, ESCAPE, BODY_HIDE, OUT_OF_BOUNDS
├── Rooms               (Node3D) RoomVolume per room in the design doc room list
├── Spawns              (Node3D) SpawnPoint: PLAYER (≥4, + pre-planning alternates), GUARD, CIVILIAN,
│                                 POLICE (≥3 directions), CAMERA_OPERATOR
├── Patrols             (Node3D) PatrolGraph(s) with PatrolPoints
├── Tactical            (Node3D) TacticalPoint: COVER, ENTRY (police breach), FLANK, SNIPER_PERCH, RAPPEL
├── Gameplay            (Node3D) instances of ENV A gameplay prefabs (doors, cameras, loot spots,
│                                 keypads, vault, escape vehicle...) with visual_scene set
├── Variants            (Node3D) VariantSlot nodes (each holds the content for that option)
├── Mission             (Node) script <id>_mission.gd
├── Preplan             (Node3D, optional) PREPLAN_POINT Marker3Ds; node name = point id (contracts/preplanning.md)
└── ReviewCameras       (Node3D) Marker3D × N fixed review shots (referenced by HeistMap.review_cameras)
```

Node names above are **exact** (consumers find them by name). Additional children are allowed.

## 3. Navigation

* One `NavigationRegion3D` named `Navigation` (may have child regions per floor). **NPC agent radius 0.3 m**
  (player capsule stays 0.35), height 1.8 m, max climb 0.3 m, max slope 40°, **cell size 0.1 / cell height 0.1**
  (project defaults, D-025) so 0.9 m doors stay open.
* Every PatrolPoint, SpawnPoint (non-sniper), interaction prefab's `UsePoint` marker, and loot spawn
  must be within 0.25 m of navmesh and mutually reachable (validated).
* Doors: navmesh passes through door openings; prefab doors toggle `NavigationLink3D`/obstacles at
  runtime (ENV A).

## 4. Patrols

* Guard routes are generated at runtime from `PatrolGraph` by ENV A: each guard gets a route of
  N points (loop or ping-pong) chosen via `GameRng.stream(&"patrols")`, respecting `tags`.
* ENV C must provide **enough graph branching that routes actually vary**: ≥ 3 distinct loop
  options per guard post on graphs serving ≥ 2 guards.
* Civilians use PatrolPoints tagged `civilian` / `staff` for ambient wandering.

## 5. Variants (dynamic per-run variables)

* Every variable in the heist design doc's **variable table** maps to: a `slot_group` with ≥ 2
  `VariantSlot`s and a rule in `<id>_variants.tres`, or a `scalars` entry, or a `rare_events` entry.
* VariantSlot content is placed by ENV C as **children of the slot**. The resolver deletes inactive
  slots' children before NPC spawning, so inactive options leave nothing behind.
* Slots with a `prefab` get it instantiated by the resolver; the prefab's `configure_variant(params)`
  receives `params`.
* Standard slot groups (use these names when they apply; add heist-specific ones freely):
  `guard_post`, `guard_extra`, `camera`, `keycard`, `code_note`, `locked_door`, `code_door`,
  `open_window`, `vent_open`, `vault_location`, `safe_location`, `civilian_cluster`,
  `loot_spot`, `escape`, `security_room_staffed`, `cop_on_scene`, `server_room`, `extra_loot`.
* Rule semantics (D-025): `requires: {group: [slot_ids]}`: the rule rolls only if any listed slot is active
  (an empty list means any slot of that group). `excludes: {group: [slot_ids]}`: if any listed slot of that group is active,
  this rule picks 0 (an empty list means any). Rules resolve in table order. A rule may only reference groups
  resolved earlier in the table (validated). Per-slot exclusion: put the excluded slots in their own group.
* Resolved variants Dictionary (replicated, logged): `{ group: [active slot_ids], scalar_id: value,
  "rare": [rare_event_ids] }`. ENV A's `VariantResolver` is the only code that rolls.
* `validate_level` checks **every** combination class: for each group, each slot individually
  must leave the heist completable (reachability of objectives + escape).

* Extended rule fields (A2-08, D-043; full semantics in `game/systems/heist/README.md` "Variant rule fields"):
  `force_if: [{"if": {group: [slots]}, "then": [slots]}]` (conditional pinning), `slot_requires: {slot: {group: [slots]}}`
  (per-slot eligibility), `min_difficulty` on rare events, and per-difficulty weights for slot groups and scalars.
  Referenced groups must resolve earlier in the table.
* `UsePoint` convention (D-025, QA-8): it sits on the object's −Z side (the side facing the room/user),
  rotated so the UsePoint's own −Z faces the object. Exception: `drill_point`, whose −Z points into the lock.

## 6. Mission scripting

* ENV A provides `HeistMission` (base class, `game/systems/heist/heist_mission.gd`) with an objective
  API (`add_objective`, `complete`, `on_event(signal, callable)`, `require_items`, timers, Mercer
  voice-line hooks). ENV C writes `<id>_mission.gd` against it. Mission scripts may use ONLY
  `HeistMission` API, `EventBus`, `Services`, and node paths **inside their own map**.

* `floor_heights` must be ascending and contain 0.0 (the ground floor); basements are negative (D-040).
* Optional `floor_names: PackedStringArray` parallel to `floor_heights` (e.g. `L40`, `L41`, `Roof`); empty = tools
  name floors by height; when set it must have the same size (validated). `HeistMap.floor_name(i)` (D-054, QC-32).

## 7. Scale & coordinate rules

Meters; +Y up; ground floor finished level = 0.0; floor heights listed in `HeistMap.floor_heights`.
Player capsule 1.8 m tall, crouched 1.2 m, radius 0.35 m. Eye height 1.65 m standing.

## 8. Validation (blocking)

`tools/levelcheck/validate_all.sh` (ENV C) must pass for every heist; see `docs/design/level_standards.md` §7.

## v1.3 (OF-A1/A2/A3/A5, A a0ce305b)
§6 mission scripting adds: `HeistMission.spawn_loot(loot_id, tag, count = 1, respawn = false)` at markers carrying
`objective_tag` (property or Marker3D meta; respawn: a destroyed or lost-off-map bag returns at the marker, D-136.9);
`reveal_variant_group(group)`, `is_variant_revealed(group)`, override `_on_variant_revealed(group)`.
Rappel: a RAPPEL TacticalPoint tagged `rappel_disabled` + a tag of your own builds disabled;
`RappelLinks.set_enabled(map, tag, on)` turns it on. Chained island rappels are allowed (police chain 16 → 12.2 → 8.6 m):
each RAPPEL point within ~0.3 m of its island's navmesh edge, its ray landing on the next island's navmesh.
Police spawns may stand on navmesh islands (no reachability rule).

## v1.4 (OF-A6, A c017fd51)
`Ladder.height_m` is settable at runtime (re-fits its nav link; replicated). A map may stow a ladder short and carry the
runtime length in node meta (`burn_height_m` on OF's RopeLadder); the mission sets it and enables the ladder.
D-121 burn-through: holes cut at runtime are baked as nav holes from the start (nav obstacle carve under the lid);
the runtime route through is ladder / hoist / rappel links only, never a navmesh rebake.
