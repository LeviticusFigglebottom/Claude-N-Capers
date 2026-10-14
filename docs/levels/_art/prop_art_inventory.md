# Prop art inventory: GH / ND / DB / SL (ENV C helper, read-only survey, 2026-10-14)

Branch surveyed: env/c-worlds @ 587f9977. Stages: GH = final, ND = final, DB = greybox, SL = greybox.
Method: parsed each heist .tscn for prefab instances and their `visual_scene` override (DEFAULT means the A placeholder
is shown), read the prefab scripts and placeholders, the LootDef/DeployableDef/ThrowableDef data, and the glb material
slots (glb JSON) against the library (`game/world/materials`, `game/world/props/materials`).

## 0. The env_c.md brief is partly stale (update it)
- **Escape zones (item 1): done.** PO-13 (458c9830): SL uses `veh_heli_escape`, `prop_escape_zipline_rig` and
  `prop_escape_lift_fitout`. On GH/ND/DB the escape_zone gets an empty node-only marker (`shared/escape_van_marker`,
  `escape_boat_marker`), and the visible vehicle comes from the secure_zone `veh_van_secure` or the moored launch.
  `test_escape_zone_visuals.gd` pins this. One exception: **the DB moored launch is still greybox boxes**
  (`LaunchHull` / `LaunchGunwale` / `LaunchCabin`), even though `veh_boat_launch` exists and ND uses it.
- **Carried loot bags (item 1): done.** PO-4 (d20e0455): all 20 LootDefs set `bag_model` to `prop_loot_bag_{light,medium,heavy}`.
  Very-heavy loot still uses the heavy bag, and paintings use a duffel.
- **nd_water (item 4): done.** fb72cb28 changed it to a `water.gdshader` ShaderMaterial with a ripple texture
  (`water_harbour_night.tres`). It still needs a windowed look but is no longer flat.
- **DB/SL "flat grey_* materials" (items 2-3): done.** PO-13 surface pass (`db_finishes.gd` / `sl_finishes.gd`, 17cb678b /
  499b3e3f): 36 textured + 6 flat (emissives only) on DB, 35 + 6 on SL. Everything is triplanar texgen. **The geometry is
  still greybox boxes with no props** (counts in item 12).
- `owners.json` lists `game/world/heists/**` and `game/world/props/**` under **both A and C** (overlap). Have the lead confirm
  that C can edit the map generators and the map .tscn files.

## 1. Prefab instance census (visual per instance)
| Prefab | GH | ND | DB | SL |
|---|---|---|---|---|
| door | 23 prop_door_* | 36 prop_door_* / vault | 35 **arch_door_* (flat)** + 7 roller, 6 slide, 1 vault **greybox** | 57 **arch_door_* (flat)** |
| security_camera | 6 prop | 12 prop | – | **18 DEFAULT** |
| loot_spawn | 3 art | 3 prop | **17 DEFAULT** | **12 DEFAULT** |
| small_loot | 4 gh_cash_stack | 3 prop + 6 baked | **6 DEFAULT** | **7 DEFAULT** |
| phone | 2 prop | 2 prop | – | **9 DEFAULT** |
| keycard_pickup / reader | 5 / 1 art | 5 prop | – | **7 / 2 DEFAULT** |
| safe | 1 prop | 3 prop | **2 DEFAULT** | **3 DEFAULT** |
| ladder | 1 prop | 1 prop | **1 DEFAULT** | **5 DEFAULT** |
| code_note / alarm_button | 3 / 2 prop | 3 / 3 prop | – | **4 / 3 DEFAULT** |
| body_container / camera_station | 2 / 1 prop | 1 / 1 prop | – | **2 / 1 DEFAULT** |
| hack_terminal | – | 2 prop | **1 DEFAULT** | **1 DEFAULT** |
| laser_grid | – | 3 nd_laser_* (ND-local) | – | **3 DEFAULT** |
| drill_point | 1 (hidden) drill | 1 thermal + **2 saw** (hidden) | **1 thermal, DEFAULT orange disc** | – |
| burn_point | – | – | **3 DEFAULT** | – |
| bag_lift | – | nd_cash_lift (art) | **goods_lift_visual greybox** | – |
| zipline | – | – | – | **1 DEFAULT** |
| secure_zone | 2 veh_van_secure | van + nd_boat_hatch | 2 van + **boat_drop_visual greybox** | **net / cart / drop greybox** |
| padlock / keypad / deposit_box / display_case | – / – / – / 8 prop | 1 / 1 / 8 baked | 13 prop_padlock_brass | – |

GH and ND have no prefab placeholders left. Their maps contain only 3 BoxMesh (GH light panels) and textured emissive
StandardMaterial3Ds, so they are clean.

## 2. Ranked inventory (screen-time x ugliness)

Abbreviations: Hook = how C can supply the art without touching A files. SC = screen time. Eff = rough effort (S/M/L).

### Top 10, each with an art plan
1. **Deployables: doctor bag, ammo bag, ECM, FAK, trip mine, body-bag case, armor bag.** All 4 maps, on every run that
   equips one, and doctor/ammo bags appear in most loud runs. **State:** 0.45x0.3x0.3 grey box
   (`deployable_placeholder.tscn`), and no DeployableDef sets `model`. ECM, FAK and trip mine have no .tres at all; they
   exist only in `DeployableTweak.DEFS`. **SC: High. Owner: A prefab. Hook:** `DeployableDef.model` (B data) exists for the
   4 .tres files. ECM, FAK and trip mine need B to add def .tres files, or A to add a model path. **Eff: M.**
   *Plan:* new `tools/blender/props/equipment.py` → `prop_deploy_{doctor_bag,ammo_bag,ecm,fak,trip_mine,body_bag_case,armor_bag}`.
   Materials: pr_bag_black, pr_fabric_charcoal, pr_metal_dark, pr_plastic_black/white, pr_metal_red (medic cross),
   pr_metal_yellow (ammo), pr_emit_led_red/green (ECM/mine LEDs), rubber_black, brushed_steel. Then ask B to set `model` in the defs.
2. **SL + DB doors.** SL has 57 and DB 35 `arch_door_{single,service,double}_t*` glbs, which are greybox kit doors with flat
   `M_grey_door` (orange-brown) / `M_grey_frame` and no textures. DB also has 7 roller, 6 slide and 1 vault door built
   from BoxMesh (`dockside_burn/greybox/*_visual.tscn`). **SC: High** (every room on the main path). **Owner:** A door
   prefab; the visual_scene is set by the C generators (`sl_gameplay.gd:166 kit_scene`, `db_gameplay.gd:196`). **Hook: yes. Eff: S/M.**
   *Plan:* copy ND's `nd_gameplay.gd` door mapping into DB/SL so they use the catalog `prop_door_{single,double,service}_{steel,ivory,walnut,glass}_t*`.
   Use `prop_door_roller_steel_w360_h450` (GN-C2) for the DB rollers. Build a sliding steel door, a DB strongroom door and a
   cold-store door in `doors.py` (pr_metal_grey/dark, brushed_steel, rubber_black, paint_safety_orange edging).
3. **DB + SL loot stacks (main objective).** DB has 17 placeholders (6 weapon_crate, 6 contraband, 4 cash_bricks, 1 thermite).
   SL has 12 (4 ledger_laptop, 3 ledger_drives, 2 ledger_books, 2 painting, 1 cash). **State:** 0.6x0.4x0.4 mustard box.
   **SC: High. Owner:** A; visual_scene is set in the C generator. **Hook: yes. Eff: M.**
   *Plan:* reuse `prop_cash_pallet` / `prop_cash_bags` (cash_bricks, cash) and the GN canvases / `prop_canvas_*_crate` (painting).
   Add `tools/blender/props/harbor.py` → `prop_loot_weapon_crate` (pr_wood_pine, pr_metal_green_worn stencil, steel_bare) and
   `prop_loot_contraband_bales` (pr_cardboard, pr_plastic_white shrink-wrap, pr_paper).
   Add `bank.py`/`staff.py` → `prop_loot_ledger_books` (leather_dark, pr_paper), `prop_loot_ledger_drives` (alu_anodized_black,
   pr_plastic_black) and `prop_loot_laptop` (alu_anodized_black, pr_emit_screen). Thermite: drum (pr_metal_red, hazard decal).
4. **SL interactables that already have catalog art but are not wired.** 18 cameras, 9 phones, 7 keycards, 2 readers,
   4 code notes, 3 alarm buttons, 3 safes, 5 ladders, 2 body containers, 1 camera station, 1 hack terminal. On DB: 2 safes,
   1 ladder and 1 hack terminal. **State:** coloured placeholder boxes; the cameras show a red box lens. **SC: High**
   (stealth players look at cameras and keycards constantly). **Hook: yes**, map generator only. **Eff: S** (wiring only).
   *Plan:* port ND's `PREFAB_VISUALS` dict (nd_gameplay.gd:63) to sl_gameplay/db_gameplay, pointing at prop_security_camera_{wall,ceiling},
   prop_phone_{desk,wall}, prop_keycard_bank, prop_keycard_reader, prop_papers / prop_note_counter, prop_alarm_button,
   prop_safe_{large,wall,wall_small}, prop_ladder_{wall_h400,caged_h900,fire_escape_*}, prop_dumpster, prop_camera_station,
   prop_server_rack_terminal. No Blender work is needed. Note that a corporate-tower SL keycard probably wants an SL-branded variant later.
5. **Ammo pickups (enemy drops).** All 4 maps, on every loud kill. **State:** a runtime olive BoxMesh 0.24x0.12x0.16
   (`systems/combat/ammo_pickup.gd`, `AmmoPickup.new()`, uses a `Visual` child if present). **SC: High (loud). Owner: A.
   Hook: none.** A must add a scene or const path, e.g. `G.PROPS_DIR + "pickup/prop_ammo_pickup.tscn"` like PO-12 did for
   drills. **Eff: S** (art) + A wiring.
   *Plan:* `equipment.py` → `prop_ammo_pickup` (a small box of ammo and mags: brass_cartridge, pr_cardboard, polymer_black).
6. **Thermal drill + saw devices.** The ND vault (main path, final map) and the DB strongroom are `device = THERMAL` but show the
   orange drill glb. The 2 ND ATM saw spots show **no device at all** while they run. **SC: High** (ND vault); saw is Med.
   **Owner:** A drill_point. **Hook: yes**: `drill_point.device_scene` (per instance, needs a `Bit` node) can be set from
   nd_gameplay/db_gameplay. **Eff: M.**
   *Plan:* extend the drill-device script (the one that builds `prop_drill_device`, see `prefab_visuals.py`) with
   `prop_thermal_drill_device`: a tripod lance, a thermite canister (pr_metal_red/grey, brushed_steel, chrome) and an
   emissive tip (emissive_pilot_flame) as the `Bit`. Add `prop_saw_device`: a clamp-on rotary saw (pr_metal_yellow,
   pr_metal_dark, steel_bare blade as the `Bit`). Ask A to point DEFAULT for THERMAL/SAW at them.
7. **Bag-secure points on SL/DB.** SL has `secure_net_visual` and `secure_cart_visual` (one BoxMesh each) and
   `secure_drop_marker` (empty). DB has `boat_drop_visual` (1 BoxMesh hatch) and `goods_lift_visual` (4 BoxMesh, the bag_lift).
   **SC: High** (every bag passes them). **Hook: yes** (map-local scenes, C). **Eff: M.**
   *Plan:* `escape.py`/`harbor.py` → `prop_secure_cargo_net` (pr_fabric_charcoal netting, steel_bare frame), `prop_cash_trolley`
   (exists, reuse for the cart), `prop_boat_hatch_drop` (adapt ND `nd_boat_hatch`: brushed_steel + wood_veneer_walnut),
   and `prop_goods_lift_car` (adapt GN `prop_art_lift_car`: pr_metal_grey, paint_safety_orange edge, pr_steel_galv mesh).
8. **DB escape launch + DB burn points.** The moored launch is 3 greybox StaticBody boxes. There are 3 burn_point
   placeholders (a 0.6 m slab with an orange box), which is an objective. **SC: Med-High. Hook:** launch = map dressing (C);
   burn_point visual_scene is set from db_gameplay (C). **Eff: S** (launch) + **M** (burn).
   *Plan:* swap in `veh_boat_launch` (already built, `harbor.py`) at the `Slot_esc_boat` mooring, keeping the collision.
   `harbor.py` → `prop_burn_barrel` (pr_metal_dark rusted drum, emissive_pilot_flame embers, pr_cardboard bales inside) for burn_point.
9. **Small loot on DB/SL.** DB has 6 cash, SL has 7 small_valuables. **State:** 0.16x0.06x0.08 green box. **SC: Med. Hook: yes. Eff: S.**
   *Plan:* use `prop_cash_stack` for cash. Promote GH's `gh_jewelry_stack` to the catalog (`prop_valuables_jewelry`: leather_dark,
   wood_veneer_walnut, brass, chrome) for small_valuables, plus an SL watch/cufflink tray.
10. **SL laser grids (3) + SL bag zipline (1).** **State:** lasers = grey 2 m posts plus a red box line; zipline = 2 grey box posts.
    **SC: Med. Hook: yes. Eff: S** (lasers) / **M** (zipline).
    *Plan:* promote ND `nd_laser_{static,sweep,timed}` (they use embedded flat nd_metal_dark: rebind to brushed_steel /
    alu_anodized_black and keep the emissive red) into the catalog as `prop_laser_emitter_*` and wire them on SL. Zipline: new
    `prop_zipline_anchor` (steel_bare cable reel, pr_metal_yellow housing, rubber_black), reusing the parts of
    `prop_escape_zipline_rig`. Check whether the prefab draws its cable; if not, add the cable to the visual or ask A.

### Below the top 10
11. **Throwables** (frag, concussion, incendiary, throwing_knife, steady_flask, boss_injector). All maps, Med (loud).
    **State:** art done (PO-C, `tools/blender/props/throwables.py`): `res://world/props/throwable/prop_throwable_{frag,
    concussion,incendiary,knife,boss_injector,steady_flask}.tscn` (body-centre origin, +Y up the fuse, `Pin`; shots in
    `_art/throwables/`). Until B sets `ThrowableDef.model` to them the game still shows the 4 cm sphere (`_make_visual`).
12. **DB/SL world dressing (G2).** DB has 1187 MeshInstance3D / 509 BoxMesh / 6 PrismMesh and 1 catalog prop. SL has
    1227 / 481 / 7 and 3 catalog props (all escape art). The surfaces are textured, but every object is a box: on DB
    about 13 container blocks (`prop_container_{20,40}_{blue,green,rust}` exist), about 14 crane parts, 2 forklifts, 4 reefers,
    7 bollards (`prop_mooring_bollard` / `prop_bollard_*` exist), racks and pallets (`prop_pallet(_loaded)` exist). On SL:
    desks, sofas, servers, planters, lockers and the heli/helipad. About 16 (DB) and about 25 (SL) room kits are missing
    (brief items 2-3). **SC: High (ambient), Eff: L.** This is G2 proper. Start from the backups
    origin/backup/2026-10-12/env-c-sl (19 tower props, 26 kits) and env-c-db-wip. Quick wins: swap the greybox containers,
    bollards and pallets for catalog props. New harbor props: `prop_gantry_crane`, `prop_forklift`, `prop_reefer_unit`,
    `prop_net_pile`, `prop_fish_tote`.
13. **ND G3 backlog (brief item 7).** Low. There is no exterior "Harbor Savings & Loan" sign
    (`prop_sign_vossberg` shows the pattern: add `prop_sign_harbor_savings` with pr_emit_warm letters, brass, pr_metal_dark),
    a vault-cage cash-brick dressing pallet beyond the loot_spawn's `prop_cash_pallet`, and teller desk personal touches
    (staff.py: mugs, photo frames, pr_ceramic, pr_paper). Eff S each.
14. **Weak materials.** `arch_door_*` (covered in #2). `nd_water` is now a shader, so the only remaining step is a
    windowed check. DB/SL's 6 flat materials each are emissives or fixtures and are acceptable. All 258 prop and arch glbs
    bind to library or pr_* materials, and every pr_* is texgen-derived (6 texture lines each). The only flat bindings are
    the `M_grey_*` arch kit pieces.

## 3. Not placeholders, but they look wrong
- **DB StrongroomDrill shows the orange disc `drill_point_placeholder`** (DEFAULT), while GH/ND hide it with gh_empty / nd_empty.
  Set the visual to an empty scene in db_gameplay (S).
- **The thermal drill reads as the ordinary drill** on the ND vault (final map, main path) and the DB strongroom (#6).
- **Saw spots (ND AtmSaw1/2) show nothing** while the device runs; only progress and cues indicate it (#6).
- **Painting loot is carried as a black duffel**, and very-heavy loot uses the heavy bag (PO-4 note: ENV D was to make one).
- **DB boat_drop_visual and secure_drop_marker** carry van-style `DoorL`/`DoorR` nodes or are empty. That is harmless, but
  the SL secure drop is invisible in play (nothing marks where to throw bags).
- **Ammo pickups** fall back to a runtime BoxMesh with a raw StandardMaterial3D, the one remaining non-library material in loud play.

## 4. Weapons (not inventoried)
All 212 weapon glbs bind only to C's library: steel_blued 121, polymer_black 106, brass_cartridge 91, alu_anodized_black 68,
metal_matte 51, rubber_black 48, steel_bare 32, polymer_olive/tan/stipple, glass_lens_*, wood_veneer_walnut. There are 0
non-library slots, so changing those library .tres files changes weapon looks too.

## 5. Suggested order
Do #4 (wiring only, about 40 SL/DB instances) and #2 (doors) and the DB launch swap first: they need no new Blender art,
and SL/DB stop looking like greybox at a glance. Then do the equipment.py batch (#1, #5, #6), which affects all 4 heists and
needs B/A hook asks, then the loot stacks (#3) and bag-secure points (#7), then G2 dressing (#12).
