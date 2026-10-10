# levelcheck: validate_level, walkthrough bot, review shots (C1-04)

Owner: ENV C. Spec: `docs/design/level_standards.md` §6–§8, `docs/contracts/heist_map.md`.
This is the automated gate that keeps AI-built level failures (floating props, clipping, nonsense
plans, lights without fixtures, default materials) out of trunk. If a check is wrong, fix the check
(or ask the lead to change the tolerance in level_standards). Do not work around it in the map.

## Usage

```bash
tools/levelcheck/validate_all.sh [heist_id ...]      # every heist, --variants=all, CI entry point
tools/levelcheck/walkthrough.sh  [heist_id ...]      # walkthrough bot only -> docs/levels/<id>/walkthrough.md
tools/levelcheck/render_shots.sh <heist_id> <g1|g2|g3> [--plan] [--cameras=a,b]   # needs xvfb, not CI
```

* `validate_all.sh` finds every `game/world/heists/<id>/<id>.tscn` and prints `no heists` (exit 0)
  if there are none. Stage per heist: `game/world/heists/<id>/stage.txt` containing `greybox` or
  `final`, else a `Stage: final` line in `docs/design/heists/<id>.md`, else `greybox`. Exits 1 if any
  heist fails. It writes `docs/levels/<id>/validation.md` and `docs/levels/<id>/walkthrough.md`.
* Direct call (headless, no rendering needed):

```bash
/opt/godot/godot --headless --path game res://world/tools/validate_level.tscn -- \
  --heist=<id> --stage=<greybox|final> [--variants=all] [--report=<path>] \
  [--scene=<res path>] [--only=floating,clipping] [--walkthrough-report=<path>] \
  [--kits=<res dir>,...] [--timeout=<s, default 600>]
```

  Exit codes: 0 pass, 1 fail, 2 usage or load error, 3 watchdog timeout (a script error inside a
  check). Every failure prints `FAIL `node/path` @ (x, y, z): message`. `--scene` validates any
  HeistMap scene, such as the test fixtures, and writes a report only when `--report` is given.
  `--only` skips the default report so a partial run never overwrites `validation.md`.
* Review shots (Vulkan Forward+ through lavapipe; `LC_DRIVER=opengl3` switches to the
  compatibility renderer):

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" /opt/godot/godot --path game --resolution 1920x1080 \
  res://world/tools/review_shots.tscn -- --heist=<id> --stage=<g1|g2|g3> [--plan] [--out=<dir>] \
  [--scene=<res path>] [--cameras=a,b] [--warmup=<frames, default 12>]
```

  Output goes to `docs/levels/<id>/<stage>/`. Each review camera gives `<camera_snake>.jpg`
  (1920×1080 JPEG at quality 85, quality is lowered until the file is ≤ 400 000 bytes). The run also
  writes `contact_sheet.jpg` (a labelled grid) and `shots.md` (captions). `--plan` (always run for
  `g1` by the wrapper) renders `plan_floor<i>.jpg` + `plan.md`. Each plan is an orthographic
  top-down view per `HeistMap.floor_heights` entry, framed on that floor's non-exterior RoomVolumes
  (+1.5 m margin, so site dressing does not shrink the building), with a flat unshaded look and a
  neutral camera environment that ignores the map's tonemap and exposure. It is cut at floor + 1.5 m: the camera sits at the cut
  and looks down, with near 0.01 m and far 2.5 m. Cut solids such as walls render black, floors
  grey, props warm, gameplay prefabs blue and variant content violet. Overlays show player spawns
  (green), guards (red), police (blue), civilians (yellow), patrol points and links (orange), loot
  (magenta), UsePoints (cyan), escape zones (green) and secure zones (magenta). If a map has no
  lights or no WorldEnvironment, the renderer adds neutral fill light for the shot. This is never
  saved to the map.
* Blueprint (pre-planning board, `docs/contracts/preplanning.md`, D-038):
  `tools/levelcheck/render_shots.sh <id> blueprint`, which runs `review_shots.tscn -- --blueprint`.
  It writes `docs/levels/<id>/blueprint.png` (floors side by side, 2 per row, one shared scale),
  `docs/levels/<id>/blueprint_floor<i>.png`, and a copy at
  `game/world/heists/<id>/<id>_blueprint.png`. PNGs are downscaled until each is ≤ 1 MB.
  * Framing and look: like the plans (non-exterior rooms + 2 m, ortho cut at floor + 1.5 m), but
    clean. Navy ground, blue floors, off-white walls, light-blue furniture footprints, door leaves
    and windows, and stair treads shaded by height.
  * Labels: each room shows `PURPOSE` + `room_id` at its centre. Each floor also gets a title,
    a north mark and a 5 m scale bar.
  * Hidden: debug markers, variant content (hidden information), Lighting, and props with a
    footprint under 0.2 m².
  * Wall cut: kit wall meshes are open at top and bottom, so walls come from collision rather
    than the render. Point queries on a 4 cm grid at floor + 1.2 m inside the floor's rooms
    (+0.8 m) mark wall pixels. Solids with a walkable top within 1 m above the sample (landings,
    stair ramps) are left to the render.
* Tests: `tools/ci/run_tests.sh c validate` (fixtures + mutation tests + geometry unit tests).

## Conventions map authors MUST follow

### Props

| What | Convention |
|---|---|
| Prop root | Every content node under `Props` is a prop root: an instanced scene, a GeometryInstance3D or a CollisionObject3D. A plain Node3D under `Props` is a folder and is descended. Under `Gameplay`, `Lighting` and `Variants`, prefab instances and geometry nodes that carry geometry are prop roots too, so a floating safe or lamp is caught. Wall- and ceiling-mounted prefabs (cameras, keypads, fixtures) therefore need meta `mount`. Anywhere else, any Node3D in group `prop` or `fixture`, or with meta `kind` / `mount` / `support` / `prop` / `fixture`, is a prop root. `Geometry` is never props. The prop's children belong to the prop. |
| Bounds | Merged AABB of the root's MeshInstance3D / CSG root / MultiMesh / Sprite3D / Label3D descendants in root-local space. This gives an OBB with the root transform. Without visuals, the collision shapes' bounds are used. |
| Colliders | StaticBody3D and similar descendants (not Areas). **Support props must have colliders.** Props without colliders are still checked through their OBB. |
| `meta mount` | `"wall"`: pivot at back-centre, −Z faces the room, the wall is behind (+Z). `"ceiling"`: pivot at top-centre, ceiling above. If absent, the prop must rest on a support. |
| `meta support = true` | Other props may rest on it (counters, desks, shelves). Resting on a prop without it fails. |
| `meta kind` | Required at final. Used for kits and scale rules: `door`, `window`, `stairs`, `counter_service`, `counter_transaction`, `counter_bar`, `desk`, `table`, `chair` (needs a `Seat` marker at seat height), `monitor`, `tv`, `camera`/`security_camera`, `sign`, `exit_sign`, `picture`, `switch`, `outlet`, `thermostat`, `railing`, `toilet`/`sink`/`urinal`, `loot_spawn`, `light_fixture`, plus free kit kinds (`box`, `plant` …). |
| `meta faces` (NodePath) | Orientation link: chair→desk/table, monitor→chair, TV→seating. The prop's −Z must point at the target's centre within ±20° of yaw (`meta faces_tolerance_deg` overrides). |
| `meta tilted = true` | Deliberately non-upright prop, such as a knocked-over chair. |
| `meta walkable = true` | A prop that legitimately carries navmesh, such as a ramp or a platform. |
| Doors | `meta kind = "door"` or a descendant named `Leaf` (pivot = hinge, rotates around Y, closed = 0); `Leaf2` for doubles. `meta swing_side` = `"front"` (leaf −Z, default) / `"back"` / `"both"`; a `swing` property == 2 (DOUBLE) means both. `meta service = true` allows 1.0–1.2 m leaves. `meta fire_exit = true` allows swinging into corridors. |
| Stairs | `meta kind = "stairs"` on each straight **flight** (Geometry allowed). Steps run along the node's local Z. The flight's meshes define the steps. Accepted collision: (a) stepped collision that follows the visual steps within 0.02 m, or (b) a smooth **ramp** that envelopes the steps: never more than 0.02 m below a tread and never more than one max riser + 0.02 m above it, so it passes through the nosings. Ramps are recommended for character controllers. Multi-flight stairs (U or L stairs) are separate flights joined by landings, which are plain geometry. |
| Fixtures | Light fixtures: geometry in group `fixture` or with meta `fixture = true` (on the mesh or an ancestor). |
| Fill lights | `meta fill = true` on the Light3D. |
| Materials | `meta untextured_ok = true` on a material for glass, pure emissive and similar surfaces. `meta greybox = true` (or a path containing `/greybox`) marks greybox materials, which are banned at final. Node meta `texel_target` (px/m) overrides the density target. Node meta `distant = true` uses the 256 px/m target. |
| Rooms | `RoomVolume` with BoxShape3D children spanning floor to ceiling. `purpose` from the room list. `dressing_kit` = id of `game/world/kits/<id>.tres` (`DressingKit`). `meta ceiling_range = Vector2(lo, hi)` overrides the ceiling table, and every override is listed in the report for lead review. |
| Markers | PatrolPoint, SpawnPoint (except sniper perch), `UsePoint`, loot spawns (meta `kind = "loot_spawn"`, or a scene/script file named `loot_spawn*`) sit at floor level. |
| Objectives | Any node with a non-empty `objective_tag` property. Its `UsePoint` child, else its origin, is the walkthrough target. |
| Review cameras | Marker3D or Camera3D listed in `HeistMap.review_cameras`. Metas: `fov` (deg, default 75), `caption`. A name starting with `TopDown` makes an orthographic shot, with meta `size` (m, default 40). |
| Navmesh | Committed, baked `NavigationMesh` on `Navigation` (layer 1 `walkable`), NPC agent radius 0.3 m (players stay 0.35), height 1.8, climb 0.3, slope 40°, cell size/height 0.1/0.1 (heist_map.md v1.1, D-025; project defaults). The validator never bakes. It sets the navigation map cell size to the navmesh's own. |
| Variants | The navmesh is baked once with every slot's geometry as authored. A slot that *changes navigation* (an open vent, a removed barricade) must carry its own `NavigationRegion3D` or `NavigationLink3D` children. The validator enables those only while the slot is active. Doors count as open for reachability, because players can always breach them. |

### DressingKit (`game/world/kits/dressing_kit.gd`)

`id`, `purpose`, `required_items: Array[StringName]` (kinds), `optional_items: {kind: weight}`,
`clutter_groups: {group: {anchors, items, count, radius}}`, `min_density` / `max_density`
(props per m² of room footprint), `min_props`, `lone_ok_kinds`, `seed_salt`, `notes`.

## Checks: algorithms and tolerances

Stage matrix (level_standards §7): **all stages** run contract_nodes, floating, clipping, scale,
navmesh, reachability, walkthrough and patrols. **Final** adds orientation, materials, zfight,
lights, density, variety, bounds and perf. Everything is deterministic: fixed sample grids, sorted
iteration, no RNG, and report issues are sorted. Inactive variant content is ignored where
relevant.

| Check | Algorithm | Tolerances |
|---|---|---|
| contract_nodes | Exact child names and types (heist_map.md §2). `heist_def` / `variant_table` set; `heist_def.id` and `map_scene` match the heist. The Mission node has a script. `floor_heights` starts at 0 and ascends. ≥ 4 PLAYER spawns. POLICE spawns in ≥ 3 directions (bearings from the rooms' centre clustered at ≥ 45° apart, with wraparound). ESCAPE and SECURE_LOOT zones exist. Rooms have unique ids and a purpose. Review cameras resolve. Every VariantSlot sits under `Variants` with a unique `slot_id`. Each group has ≥ 2 slots and a rule, and each rule's group has slots. A baked navmesh is present. | ≥ 1 review camera at greybox; ≥ 12 plus a `TopDown*` at final |
| floating | Resting props: 5 downward rays (centre + 4 inset corners of the OBB bottom) from 5 cm above the base. A hit counts as support when it lies within the tolerance and is not the prop itself. A prop hit must be a `support` prop (or a door, window or stair). Support props without colliders count through their OBB top face. The prop is stable when the centre ray is supported or two diagonal corners are. Mounted props: one ray from the pivot along +Z (wall) or +Y (ceiling). | gap ≤ 0.01 m; penetration ≤ 0.005 m (deeper is reported by clipping) |
| clipping | (1) Each collision shape of the prop, plus its visual OBB as a box, runs Jolt `intersect_shape` against the world. For each candidate, `collide_shape` with every other candidate excluded measures the penetration depth (max contact-pair distance). The visual OBB is tested against the shell, and against other props only when the prop has no colliders. Doors, windows and stairs are exempt against the shell (they sit in openings). (2) Pairs where neither prop has colliders use an OBB-vs-OBB separating-axis test (15 axes). Props in different slots of the same variant group are never paired. (3) Door swings: every Leaf/Leaf2 quarter circle on its swing side is sampled every 5°, every 0.1 m radially and at 6 heights from 0.1 to 2.0 m. A sample inside any prop OBB (inflated 0.05 m) fails that prop. | penetration > 0.005 m fails |
| orientation | Wall items: the hit normal of the wall behind satisfies `normal · −Z ≥ 0.999` (flush, facing the room). Ceiling items and floor props: `up · Y ≥ 0.999` unless `tilted`. `faces` links within ±20° yaw. A chair within 1 m of a desk, table or counter without a `faces` link fails. Monitors and TVs without a link warn. Toilets, sinks and urinals need the shell within 0.15 m behind them. Doors must not swing into a `corridor` room unless `fire_exit` (probe 0.6 m in front of the leaf). | as stated |
| scale | Doors: leaf AABB height 2.1; width 0.9 single, 1.8 double, 1.0–1.2 with `service` (±0.03). Ceilings: 1 m grid in each room (0.5 m inset). The shell floor ray and the shell ceiling ray give the median height, compared with the purpose table in `lc_check_scale.gd` (§2.6). Purposes without a rule fail, `exterior`/`stair`/`shaft`/`elevator`/`roof`/`plenum` are exempt, and `vault` gets 2.6–6.0 (lead to confirm). Any sample without a ceiling fails ("open to the sky"); headroom < 2.1 m fails. Props by kind: counter_service 0.9, transaction/bar 1.05–1.1, desk 0.72–0.76, railing 1.0–1.1 (top above floor); switch 1.2, outlet 0.3, thermostat 1.5, picture 1.45–1.6, sign 2.2–2.4 (centre above floor); camera 2.4–3.2 or a ceiling mount; chair `Seat` 0.45. Stairs, per flight: downward rays every 1 cm along local Z (half-sample offset, misses retried ±2 mm) give a *visual* profile, from single-sided proxies of the flight's meshes (beyond the meshes, whatever collision lies there other than the flight's own), and a *collision* profile. The visual profile is segmented into flats at jumps > 2 cm: every riser 0.15–0.19, every tread 0.25–0.32, a flat ≥ 0.8 m is a landing, more than 16 risers without a landing fails. The collision must be stepped or an enveloping ramp (see Conventions), and a hole in it fails. Width ≥ 1.1 m. Headroom ≥ 2.1 m. **Chaining:** flights connect when one's top equals the next one's bottom (±0.01 m) and the top and bottom riser lines are ≤ 4 m apart horizontally (a shared landing). Every flight must lie on a chain that starts at one `floor_heights` entry and ends at a higher one, so a U-stair 0 → 2.1 → 4.2 passes. | ±0.02–0.03 m unless stated |
| navmesh | Agent settings and layer match the contract. Every marker is within 0.25 m horizontally and 0.5 m vertically of `map_get_closest_point`. Coverage: each room gets a 0.5 m grid (coarsened to ≤ 900 samples). A sample is walkable when it has a shell floor with slope ≤ 40° and a 0.5 m-radius, 1.6 m cylinder starting 0.35 m above the floor hits nothing; it is covered when the closest navmesh point is within 0.3 m horizontally. Furniture: a ray down through each navmesh polygon centroid that hits a prop (not a door or stair, and not `walkable`) fails. | coverage ≥ 95% per room |
| reachability | Variant configurations: the baseline is the first slot (by `slot_id`) of every group. With `--variants=all`, each slot of each group runs alone, with the other groups at baseline. Per configuration: the slots' nav regions and links are toggled and the navigation server re-syncs. Targets are objectives, loot spawns, secure and escape zones (a navmesh point inside the zone), UsePoints, and every NPC marker (mutual reachability). Each must be reached from every PLAYER spawn by `map_get_path`. The failure lists the variant labels. | path end within 0.3 m horizontally and 0.5 m vertically |
| walkthrough | §6 bot on the baseline configuration: every player spawn to every objective, loot spawn, secure zone, escape zone and UsePoint. It fails on an unreachable target, or when the path is longer than 3 × max(straight-line, 3 m), unless the pair is whitelisted in `game/world/heists/<id>/walkthrough_whitelist.txt`. Whitelist lines are `<spawn name or path or *> <target name or path or *>`, with `#` comments. The full table goes to `walkthrough.md`. | ratio 3 |
| patrols | Every link resolves to a PatrolPoint of the same graph, is not a self-link and is bidirectional. A point without links fails. The graph is one connected component. Linked points have a navmesh path. Guard posts: graphs used by ≥ 2 GUARD spawns (`patrol_graph`) need, for each guard's start point (the nearest PatrolPoint), ≥ 3 distinct simple cycles of ≥ 3 points through it. A cycle and its reverse count once. Deterministic DFS, capped at 3 and 200k steps. | ≥ 3 loops |
| materials | Every surface of every visible GeometryInstance3D (MeshInstance3D active material, MultiMesh, CSG root mesh) must have a material, not a greybox one. BaseMaterial3D needs an albedo texture (unless `untextured_ok`). Normal maps enabled without a texture fail, as does an ORM material without an ORM texture. Texel density per triangle: UV-mapped is √(uv_area × w × h × uv1_scale² / world_area); triplanar is w × uv1_scale. More than 20% of a surface's area out of range fails. | 512 px/m → 256–768; down-facing or `distant` → 128–768 |
| zfight | World-space triangles are binned by quantised plane (normal × 40, offset / 2 mm, neighbouring offset bins compared) and hashed on a 1 m in-plane grid. Pairs from different owners or surfaces with different materials, facing the same way (dot ≥ 0.999), with a plane offset < 2 mm and a 2D clipped overlap > 4 cm² fail. Mesh-local planes with < 2 cm² of total area (tessellated curved surfaces) are skipped up front, which keeps the check fast. Reports are capped at 40. | 2 mm, 4 cm² |
| lights | Each Light3D except DirectionalLight3D and fill lights needs a fixture ancestor, or fixture geometry within 0.3 m of the light (AABB distance). More than 1 DirectionalLight3D fails. Shadow-casting lights per room ≤ 8. Fill lights: energy ≤ 0.3, no shadows, ≤ 2 per room. | as stated |
| density | Every prop needs a `kind`. Rooms need a kit unless the purpose is exempt (corridor, stair, exterior, shaft, elevator, roof, plenum, vault). The kit must exist, and its purpose must match the room. Props (OBB centre in the room, doors excluded) must cover all `required_items`, number ≥ `min_props`, and give a count per m² within [min, max]. Lone prop: in rooms > 12 m², a floor prop with no other prop within a 2 m footprint distance fails, unless its kind is in `lone_ok_kinds`. | per kit |
| variety | Layout hash per room: md5 of the sorted (kind, room-local centre quantised to 0.25 m, yaw quantised to 15°) entries. Two rooms with the same kit must not share a hash. | |
| bounds | Single-sided trimesh proxies of the visual meshes go on physics layer 20; back faces are not hit unless the material disables culling. From navmesh polygon centroids (≤ 300) at 1.65 m eye height, rays fire in 16 yaws × pitches {−30, −10, 0, 15, 45}°, plus straight up, out to 500 m. A ray that hits no front face fails (void or a visible back face). Upward rays may escape when a WorldEnvironment has a sky background. | 500 m |
| perf | For each review camera, a frustum (fov, 16:9, 0.05–500 m, or orthographic) is tested against the world AABB of every visible render piece, honouring `visibility_range_end`. Totals: draw calls = surfaces, triangles, and shadow-casting lights whose range sphere touches the frustum. No occlusion culling, so the estimate is conservative. | draw calls ≤ 2500, shadow lights ≤ 8 (architecture §10); triangles ≤ 3M (provisional, lead to confirm) |

## Files

| Path | Role |
|---|---|
| `game/world/tools/validate_level.{tscn,gd}` | CLI entry, report writer, watchdog |
| `game/world/tools/review_shots.{tscn,gd}` | screenshot and plan renderer |
| `game/world/tools/levelcheck/lc_runner.gd` | check list, `prepare()` (loads the map, detaches the mission script, syncs servers), markdown report |
| `game/world/tools/levelcheck/lc_context.gd` | shared state: props, doors, rooms, rays, navigation, variant configuration |
| `lc_prop.gd`, `lc_geom.gd`, `lc_areas.gd`, `lc_targets.gd`, `lc_visual.gd`, `lc_util.gd` | helpers (OBB/SAT, polygon clipping, frustum, cycle counting, area boxes, targets, render pieces and proxies) |
| `lc_check_*.gd`, `walkthrough.gd` | one module per check (`class_name LcCheck<Name>`, base `LcCheck`) |
| `game/world/kits/dressing_kit.gd` | `DressingKit` schema |
| `game/tests/c/test_validate_level.gd` | tests |
| `game/tests/c/fixtures/` | `lc_fixture_builder.gd` (programmatic maps), `make_lc_fixtures.gd` (bakes navmesh, writes `lc_fixture_good.tscn` / `lc_fixture_bad.tscn`), fixture kit and stub scripts |

Regenerate fixtures: `/opt/godot/godot --headless --path game --script res://tests/c/fixtures/make_lc_fixtures.gd`.

## Known limits / TODO

* The walkthrough uses pure navmesh queries. Switch it to ENV A's nav + CrewIntent bots when they
  exist (§6).
* Clipping uses collision shapes plus the visual OBB. Concave visual overlaps (a chair tucked under
  a desk with a box collider) are judged on the colliders, so author tight colliders.
* Reachability treats doors as open, and handles navigation-changing variants only through
  slot-owned NavigationRegion3D / NavigationLink3D. Combinations across groups are not
  exhaustively enumerated: each slot runs alone with the other groups at baseline.
* Perf has no occlusion culling and no LOD switching beyond visibility ranges. The triangle budget
  is provisional.
* Texel density is not estimated for ShaderMaterials (texture presence is not checked either).
* Sky detection for `bounds` only looks at WorldEnvironment background mode `BG_SKY`.
