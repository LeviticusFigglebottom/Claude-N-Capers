# Ostrander Federal: per-item map content for the G1 greybox (OF-C1): the door lock table, furniture (support boxes),
# ENV A's gameplay prefabs, NPC spawns, patrol graphs, tactical points (police entries, perches, anchors, COVER),
# holdout / objective markers, for every VariantSlot and the always-present layer. Owner: ENV C.
# Imported by ostrander_federal_slots.py (--check) and ostrander_federal_emit_layout.py (-> ostrander_federal_layout.gd).
#
# Row formats (positions [x, y, z]: y above the row's floor FFL; yaw: front -Z faces 0 N, 90 W, 180 S, -90 E):
#   ["prefab", kind, name, floor, pos, yaw, props, use (pos or None), metas, visual ("" = the prefab's placeholder)]
#       props: export -> value; "enum:KEY" looks up the prefab's enum; "@targets" / "@target" / "@operator_spawn" take
#       node names (resolved in the built map); StringName / typed-array exports are coerced by the generator.
#   ["spawn", name, KIND, floor, pos, yaw, tags, idle, graph ("" none), seat asset ("" none)]
#   ["box", name, floor, base (bottom-centre), size, yaw, kind, support, surface class]   (Props/MapBuilt)
#   ["marker", name, floor, pos, yaw, objective_tag, todo]
#   ["tac", name, KIND, floor, pos, yaw, tags, breachable]
#   ["route", name, route_id, ORDER, bind_tags, start_index, stops]   (A's CivilianRoute, OF-A4; ROUTE_ROWS)
#       stop: [name, floor, pos, pause [min, max] s, pause_anim, away_window ("" none), facing yaw or None]
# Design: docs/design/heists/ostrander_federal.md (Room list, Circulation, roster, Sightlines, Loud, Loot path,
# Objectives); next_heist_ostrander.md §3b (D-136) / §4 / §7; D-138 (cage gates: keypad + padlock on the gate);
# ENV D's placement conventions (teller_count root 0.28 m behind the 1.00 m work top's near edge; counter customers
# 0.30 m off the hall face; check desks top 1.0 m, near edge 0.25 m ahead; queue spawns 0.9 m apart; cower_stand 0.21 m
# off a wall or the counter front; seated NPCs on a catalog chair's Seat).
import math
from typing import Callable, Dict, List

G_GUARDS = ["guard_lobby", "guard_vault", "guard_rover_hall", "guard_rover_gallery", "guard_rover_basement",
            "guard_rover_dock", "guard_extra_hall", "guard_extra_basement", "guard_vaultline", "guard_vip"]
G_STAFF = ["civ_teller", "civ_manager_mgr_floor", "civ_manager_mgr_gallery", "civ_manager_mgr_vault", "civ_officer"]
LOCKPICK_S = 8.0
# Spawn / placement tags for ENV D (OF-D1): the counter windows and the check desks.
TAG_COUNTER = "counter_window"
TAG_CHECK = "check_desk"
TAG_QUEUE = "queue"
# Cage gates (D-138): the gate is a Door (BARRED, opened by its lock prefabs targeting it).
CASH_CAGE = [22.5, 17.5, 25.5, 22.5]     # x0, z0, x1, z1 (vault floor), gate N (x 23-25)
GOLD_CAGE = [29.0, 17.0, 33.7, 21.0]     # gate W (z 18-20)
CAGE_H = 2.6
CAGE_T = 0.1
# The lid (24, 14.6) over the hole (QC-61): the 2.4 m marble panel, the 1.2 x 2.2 m burn hole (the rope ladder on its
# north edge, the 1.0 m hoist car in its south half; §7.7). Doc: hole at (24, 14) -> (24, 14.6) so the hole is fully
# inside the vault (inner face z 13.3) and both fit.
LID = [22.8, 13.4, 25.2, 15.8]
HOLE = [23.4, 13.5, 24.6, 15.7]
# OF-P1 (ENV P windowed pass) §7.7: the car is 1.0 x 0.75 m (x, z; 2 bags: two HEAVY 0.75 x 0.4 bags stack or sit side
# by side across x) against the hole's south edge, and the rope ladder hangs 0.04 m inside the north edge, so the ladder's
# Bottom grab point (0.4 m off its climb face, ladder_placeholder.tscn) stands >= 1.0 m clear of the car footprint.
TANNERY_SECURE_X = 51.2       # the E2 SECURE_LOOT strip's centre (x 48.2-54.2; ostrander_federal_slots.ESCAPE_ZONES)
HOIST_CAR = [1.0, 1.0, 0.75]
HOIST_Z = round(HOLE[3] - HOIST_CAR[2] / 2, 3)          # 15.325
ROPE_Z = round(HOLE[1] + 0.04, 3)                       # 13.54 (rails 0.05 thick: clear of the slab edge)
LADDER_BOTTOM_OFF = 0.4                                 # ladder_placeholder.tscn Bottom (0, 0, -0.4)
ROPE_STOWED_M = 3.2           # the rope ladder rolled up to the lid's underside (0.8 m slab) until the burn
# The hoist rig (OF-P1 §7.7; built under Gameplay/Lifts/Hoist, so it appears with the hoist at the burn and is gone
# before it: GameplayPrefab disabled = hidden + out of physics). World boxes [name, min, max]; world_dynamic (layer 2:
# crew and bags collide, interaction / vision rays (layer 1) pass, so the car's bags stay pick-up-able over the guard).
# Vault (FFL -4): a shaft round the car open to the south over a 0.6 m sill (ND's lift-hatch precedent): a bag thrown
# north from the vault floor hits the backstop (the first contact keeps 15 % of its speed, LootTweak) and drops into the
# car. TW (FFL 0): 1.5 m guard screens on the hole's W / E / S edges (the north edge stays open for the ladder top and
# the hole_rappel point): a bag thrown across the hole from an edge hits the far screen flush with the edge and falls in.
HOIST_RIG = [
    ["ShaftBackstop", [23.36, -4.0, 14.92], [24.65, -1.6, 14.97]],
    ["ShaftW", [23.36, -4.0, 14.97], [23.41, -1.6, 15.75]],
    ["ShaftE", [24.6, -4.0, 14.97], [24.65, -1.6, 15.75]],
    ["ShaftSill", [23.36, -4.0, 15.75], [24.65, -3.4, 15.8]],
    ["HoleGuardW", [23.35, 0.0, 13.5], [23.4, 1.5, 15.75]],
    ["HoleGuardE", [24.6, 0.0, 13.5], [24.65, 1.5, 15.75]],
    ["HoleGuardS", [23.4, 0.0, 15.7], [24.6, 1.5, 15.75]],
]
# The hoist's call / send panel (OF-C1, ENV P burn run 7df78180): a 0.04 x 0.12 m riser standing against ShaftE's east
# face (floor to 1.2 m, the panel at 1.1 m: [min, max, panel y]), square in front of the UsePoint (x 25.1, z HOIST_Z), as
# the bag_lift's external `Panel` (the Interactable moves onto it; bag_lift copies it to the TW landing, + 4 m: against
# HoleGuardE's east face, so ShaftE's east face is HoleGuardE's, x 24.65). The placeholder visual's own panel sat 0.66 m
# north of the UsePoint in mid-air (the default 1.2 m car's offset).
HOIST_PANEL = [[24.65, -4.0, round(HOIST_Z - 0.06, 3)], [24.69, -2.8, round(HOIST_Z + 0.06, 3)], -2.9]
# Teller counter (z 17 line; §7.2, D-128 / D-136 §3b.11 and OF-C0): 12 work tops (props, kind teller_worktop, top 1.00,
# z 16.35-16.83, 0.48 deep, teller side north = local -Z), a SOLID bandit-screen base to 1.50 m (z 16.83-16.93; QC-g
# amended by the LEAD: the original 1.35 m is teller_worktop's perpendicular formula, but hide_los samples observers
# along the counter at the 2.0 m uncover radius, whose sight line to the 1.05 m crouched point crosses the face at
# ~1.44 m), the customers' 1.05 m ledge in front of it (z 16.93-17.45, 0.52 deep), bandit glass 1.50-2.40 m (meta + group
# see_through), the bulkhead 2.40 m -> the slab (z 16.83-17.5: C1 hangs on its south face over the hall floor), the
# teller gate's piers x 22.9-23.4 / 24.6-25.1 and its header on the screen line z 16.93 (z 16.83-17.03: a 0.2 m "wall"
# the service-door kit fits). QC-67 (ENV D probe of counter_customer): the screen face is 0.82 m ahead of the customer
# marks (z 17.75), clear of the clip's forearms (0.69 m ahead at 1.04-1.2 m).
COUNTER = {"z": 17.0, "line": 16.93, "body": [16.35, 17.45], "ledge": [16.93, 17.45, 1.05], "top": [16.35, 16.83, 1.0],
           "upstand": [16.83, 16.93, 1.5], "glass": [16.86, 16.90, 1.5, 2.40], "bulkhead": [16.83, 17.5, 2.40],
           "x": [8.1, 39.9], "gate": [23.4, 24.6], "piers": [[22.9, 23.4], [24.6, 25.1]], "gate_head": 2.2,
           "pier_z": [16.83, 17.03]}
STATIONS = [13.0, 15.0, 17.0, 31.0, 33.0, 35.0]     # the 6 staffed of 12 windows
TELLERS = [15.0, 17.0, 31.0, 33.0]                  # 3 staffed + 1 rotating (doc roster)
TELLER_Z = COUNTER["top"][0] - 0.28                 # D: root 0.28 m behind the work top's near edge
COUNTER_CUSTOMER_Z = COUNTER["body"][1] + 0.30      # D: root 0.30 m off the hall face
HIDE_Z = COUNTER["top"][0] - 0.35                   # a crouched crew centre 0.35 m behind the work top's teller edge
CHECK_DESKS = [[14.0, 25.5], [19.5, 25.5], [28.5, 25.5], [34.0, 25.5]]   # 1.6 x 0.6, top 1.0
CHECK_D = [1.6, 1.0, 0.6]
# ENV D clip marks (env/d-art b2527e4d): check_desk_write root 0.25 m off the desk's near (hall) edge; queue_idle marks
# >= 0.91 m apart, the first >= 0.62 m in front of the rope rail (z 21.5) on the counter side.
CHECK_Z = 25.5 + 0.3 + 0.25
QUEUE_Z = 21.5 - 0.62
QUEUE_RAILS = [[10.5, 19.5, 21.5], [28.5, 37.5, 21.5]]   # [x0, x1, z]: one collider per run (§7.13)
PILLARS = [11.0, 15.0, 19.0, 29.0, 33.0, 37.0]           # z 20, under the gallery slab edge
LASER_X = 21.0
LASER_Z = [9.1, 12.7]          # VC clear width (N wall face 9.1, vault wall face 12.7)
LASER_GAP = [11.55, 12.7]      # lz_static bypass gap at the S wall: 1.15 m clear (§7.1 >= 1.0)


def _doc_note() -> str:
    return "see the module header"


# --- doors (lock table) ----------------------------------------------------------------------------
# [name, floor, axis, fixed, a0 (the plan opening's start), lock, front, extra]. The kind (single 1.0 / service 1.2 /
# double 2.0 kit opening) follows the plan opening's width; a 4.2 m opening is two doubles (extra "c": centres).
# extra: visual (catalog id), leaf (leaf_surface), npc (npc_authorized_tags: "@guards", "@staff"), push_bar, starts_open,
# fire_door (meta fire_exit without a push bar: a two-way cross-corridor smoke door),
# out (swing OUTWARD), tag (objective_tag), slot (built by that slot instead), bake_closed (D-073 / D-122), kind_meta.
DOORS: List[list] = [
    # --- Basement ---
    ["LockerDoor", "B", "x", 7, 4.4, "NONE", "S", {}],
    ["CashLiftDoorB", "B", "x", 3, 10.5, "NONE", "N", {"visual": "prop_door_double_liftgate_t20", "leaf": "metal",
                                                        "w": 1.8}],
    ["CartQueueDoor", "B", "x", 7, 11.4, "NONE", "S", {}],
    ["StairDoorSAB", "B", "x", 7, 13.9, "NONE", "S", {"leaf": "metal"}],
    ["CountRoomDoor", "B", "x", 7, 20.5, "LOCKPICK", "S", {"npc": ["@guards", "@staff"]}],
    ["PlantDoor", "B", "x", 7, 29.5, "NONE", "S", {}],
    ["CommsDoor", "B", "x", 7, 36.5, "LOCKPICK", "S", {"npc": ["@guards"], "leaf": "metal"}],
    ["SuppliesDoor", "B", "x", 7, 41.5, "NONE", "S", {}],
    ["StairDoorSBB", "B", "x", 7, 45.9, "NONE", "S", {"leaf": "metal"}],
    ["RecordsDoor", "B", "x", 9, 5.4, "NONE", "N", {}],
    ["VaultGate", "B", "x", 9, 16.0, "KEYCARD", "N", {"visual": "prop_door_double_grille_t20", "leaf": "metal",
                                                       "npc": ["guard_vault", "guard_rover_basement", "guard_vaultline",
                                                               "guard_extra_basement"], "tag": "vault_gate",
                                                       "bake_closed": True, "w": 1.8}],
    ["DepositHallDoor", "B", "x", 9, 41.4, "NONE", "N", {}],
    ["VaultDoor", "B", "x", 13, 28.8, "VAULT", "N", {"visual": "prop_vault_door_round", "leaf": "metal", "w": 2.2,
                                                      "tag": "vault_door", "kind_meta": "vault_door",
                                                      "bake_closed": True}],
    # --- Ground ---
    ["DockRollerDoor", "G", "x", 0, 3.1, "ELECTRONIC", "N", {"visual": "prop_door_roller_twin_w360_h400", "leaf": "metal",
                                                              "w": 3.6, "kind_meta": "industrial_door",
                                                              "bake_closed": True}],
    ["DockPersonnelDoor", "G", "x", 0, 7.4, "", "N", {"slot": "side_door"}],
    ["CashLiftDoorG", "G", "z", 10, 0.5, "NONE", "E", {"visual": "prop_door_double_liftgate_t20", "leaf": "metal",
                                                        "w": 1.8}],
    ["DockCorridorDoor", "G", "z", 10, 7.4, "NONE", "E", {"leaf": "metal"}],
    ["ElectricalDoorG", "G", "x", 7, 11.5, "NONE", "S", {}],
    ["StairDoorSAG", "G", "x", 7, 13.9, "NONE", "S", {"leaf": "metal"}],
    ["SecurityDoor", "G", "x", 7, 18.5, "NONE", "S", {}],
    ["GuardLockerDoor", "G", "x", 7, 25.5, "NONE", "S", {}],
    ["StaffWCDoorM", "G", "x", 7, 29.5, "NONE", "S", {}],
    ["StaffWCDoorW", "G", "x", 7, 32.5, "NONE", "S", {}],
    ["JanitorDoorG", "G", "x", 7, 35.4, "NONE", "S", {}],
    ["MailDoor", "G", "x", 7, 40.5, "NONE", "S", {}],
    ["StairDoorSBG", "G", "x", 7, 45.9, "NONE", "S", {"leaf": "metal"}],
    ["FireExitDoor", "G", "z", 48, 7.4, "", "W", {"slot": "side_door"}],
    ["StaffDoorTWW", "G", "x", 9, 13.4, "LOCKPICK", "N", {"npc": ["@guards", "@staff"]}],
    ["StaffDoorTWE", "G", "x", 9, 33.4, "LOCKPICK", "N", {"npc": ["@guards", "@staff"]}],
    ["ClientServiceDoor", "G", "x", 9, 43.4, "NONE", "N", {}],
    ["LoanTellerDoor", "G", "z", 8, 11.5, "LOCKPICK", "W", {"npc": ["@guards", "@staff"]}],
    ["ClientTellerDoor", "G", "z", 40, 11.5, "LOCKPICK", "E", {"npc": ["@guards", "@staff"]}],
    ["LoanHallDoor", "G", "z", 8, 17.5, "NONE", "E", {}],
    ["ClientHallDoor", "G", "z", 40, 17.5, "NONE", "W", {}],
    ["TellerGate", "G", "x", 17, 23.4, "LOCKPICK", "S", {"npc": ["@guards", "@staff"], "leaf": "metal", "line": COUNTER["line"]}],
    ["ConsultDoor1", "G", "z", 8, 20.5, "NONE", "E", {}],
    ["ConsultDoor2", "G", "z", 8, 25.5, "NONE", "E", {}],
    ["ATMHallDoor", "G", "z", 8, 31.5, "NONE", "E", {"visual": "prop_door_single_glass_t20", "leaf": "glass",
                                                      "starts_open": True}],
    ["ManagerDoor", "G", "z", 40, 22.5, "NONE", "W", {}],
    ["RestroomDoor", "G", "z", 40, 28.5, "NONE", "W", {}],
    ["NewAccountsDoor", "G", "z", 40, 32.5, "NONE", "W", {}],
    ["VestibuleDoorsW", "G", "x", 32, 21.9, "NONE", "S", {"c": 22.9, "visual": "prop_door_double_glass_t20",
                                                           "leaf": "glass", "starts_open": True}],
    ["VestibuleDoorsE", "G", "x", 32, 21.9, "NONE", "S", {"c": 25.1, "visual": "prop_door_double_glass_t20",
                                                           "leaf": "glass", "starts_open": True}],
    ["BronzeDoorsW", "G", "x", 36, 21.9, "NONE", "N", {"c": 22.9, "visual": "prop_door_double_bronze_t40",
                                                        "leaf": "metal", "starts_open": True, "bake_closed": True,
                                                        "tag": "bronze_doors"}],
    ["BronzeDoorsE", "G", "x", 36, 21.9, "NONE", "N", {"c": 25.1, "visual": "prop_door_double_bronze_t40",
                                                        "leaf": "metal", "starts_open": True, "bake_closed": True,
                                                        "tag": "bronze_doors"}],
    ["ATMStreetDoor", "G", "x", 36, 3.0, "NONE", "N", {"visual": "prop_door_double_glass_t40", "leaf": "glass",
                                                        "starts_open": True, "bake_closed": True,
                                                        "tag": "bronze_doors"}],
    # --- Gallery ---
    ["BreakRoomDoor", "M", "x", 7, 4.5, "NONE", "S", {}],
    ["ElectricalDoorM", "M", "x", 7, 11.5, "NONE", "S", {}],
    ["StairDoorSAM", "M", "x", 7, 13.9, "NONE", "S", {"leaf": "metal"}],
    ["ITDoor", "M", "x", 7, 18.5, "NONE", "S", {}],
    ["ServerDoor", "M", "x", 7, 25.4, "LOCKPICK", "S", {"npc": ["@guards"], "leaf": "metal"}],
    ["GalleryWCDoorM", "M", "x", 7, 29.5, "NONE", "S", {}],
    ["GalleryWCDoorW", "M", "x", 7, 32.5, "NONE", "S", {}],
    ["JanitorDoorM", "M", "x", 7, 35.5, "NONE", "S", {}],
    ["ArchiveDoor", "M", "x", 7, 40.5, "NONE", "S", {}],
    ["StairDoorSBM", "M", "x", 7, 45.9, "NONE", "S", {"leaf": "metal"}],
    # the loggias' cross-corridor smoke doors (UC | WL / EL: a corridor both sides; the loggias are open to the hall
    # void): fire doors (meta fire_exit, no push bar: two-way), swinging north with the egress to the stairs (OF-C2)
    ["LoggiaDoorW", "M", "x", 9, 6.5, "NONE", "S", {"fire_door": True}],
    ["OperationsDoor", "M", "x", 9, 11.5, "NONE", "N", {}],
    ["ConferenceDoor", "M", "x", 9, 30.5, "NONE", "N", {}],
    ["ComplianceDoor", "M", "x", 9, 36.5, "NONE", "N", {}],
    ["LoggiaDoorE", "M", "x", 9, 40.5, "NONE", "S", {"fire_door": True}],
    ["OfficerDoor1", "M", "z", 6, 12.5, "NONE", "E", {}],
    ["OfficerDoor2", "M", "z", 6, 21.5, "NONE", "E", {}],
    ["OfficerDoor3", "M", "z", 6, 30.5, "NONE", "E", {}],
    ["VaultOpsDoor", "M", "z", 42, 12.5, "NONE", "W", {}],
    ["TreasuryDoor", "M", "z", 42, 21.5, "NONE", "W", {}],
    ["TrainingDoor", "M", "z", 42, 30.5, "NONE", "W", {}],
    ["OperationsGalleryDoor", "M", "x", 17, 17.5, "NONE", "S", {}],
    ["ConferenceGalleryDoor", "M", "x", 17, 30.5, "NONE", "S", {}],
    ["GalleryDoorW", "M", "z", 8, 17.5, "NONE", "W", {}],
    ["GalleryDoorE", "M", "z", 40, 17.5, "NONE", "E", {}],
    # --- Executive ---
    ["BoardroomDoor", "E", "x", 7, 4.5, "NONE", "S", {}],
    ["ElectricalDoorE", "E", "x", 7, 11.5, "NONE", "S", {}],
    ["StairDoorSAE", "E", "x", 7, 13.9, "NONE", "S", {"leaf": "metal"}],
    ["AssistantDoor", "E", "x", 7, 18.4, "NONE", "S", {}],
    ["PresidentDoor", "E", "x", 7, 27.5, "NONE", "S", {}],
    ["PantryDoor", "E", "x", 7, 37.5, "NONE", "S", {}],
    ["ExecWCDoor", "E", "x", 7, 42.5, "NONE", "S", {}],
    ["StairDoorSBE", "E", "x", 7, 45.9, "NONE", "S", {"leaf": "metal"}],
    ["LoungeDoor", "E", "x", 9, 5.4, "NONE", "N", {}],
    ["LegalDoor", "E", "x", 9, 21.5, "NONE", "N", {}],
    ["TrustDoor", "E", "x", 9, 33.5, "NONE", "N", {}],
    ["RecordsDoorE", "E", "x", 9, 43.5, "NONE", "N", {}],
    ["TerraceDoorsW", "E", "x", 17, 4.6, "LOCKPICK", "S", {"visual": "prop_door_double_glass_t40", "leaf": "glass",
                                                            "npc": ["guard_rover_gallery"],
                                                            "bake_closed": True}],
    ["TerraceDoorsE", "E", "x", 17, 9.6, "LOCKPICK", "S", {"visual": "prop_door_double_glass_t40", "leaf": "glass",
                                                            "npc": ["guard_rover_gallery"],
                                                            "bake_closed": True}],
    # --- Roof ---
    ["HeadHouseDoor", "R", "x", 7, 13.9, "LOCKPICK", "S", {"leaf": "metal", "bake_closed": True,
                                                            "npc": ["guard_rover_gallery"], "tag": "head_house"}],
    ["RoofPlantDoor", "R", "x", 10, 26.5, "NONE", "S", {"leaf": "metal"}],
    # --- Vault cages (D-138: the gate is a Door; its locks target it) ---
    ["CashCageGate", "B", "cage", 0, 0, "BARRED", "N", {"visual": "prop_door_double_steel_t10", "leaf": "metal",
                                                         "w": 1.8, "pos": [24.0, 0.0, 17.5], "yaw": 0.0,
                                                         "tag": "cash_cage", "bake_closed": True}],
    ["GoldCageGate", "B", "cage", 0, 0, "BARRED", "W", {"visual": "prop_door_double_steel_t10", "leaf": "metal",
                                                         "w": 1.8, "pos": [29.0, 0.0, 19.0], "yaw": 90.0,
                                                         "tag": "gold_cage", "bake_closed": True}],
]
# side_door slots: the fire exit (push bar, front W = inside BC) and the dock personnel door (front N = the lane).
SIDE_DOORS = {
    "door_fire_propped": {"FireExitDoor": ["NONE", {"push_bar": True, "starts_open": True}],
                          "DockPersonnelDoor": ["LOCKPICK", {}]},
    "door_dock_open": {"FireExitDoor": ["NONE", {"push_bar": True}], "DockPersonnelDoor": ["NONE", {}]},
    "door_none": {"FireExitDoor": ["NONE", {"push_bar": True}], "DockPersonnelDoor": ["LOCKPICK", {}]},
}
SIDE_DOOR_EXTRA = {"FireExitDoor": {"leaf": "metal", "bake_closed": True, "tag": "fire_exit",
                                    "npc": ["guard_rover_hall", "civ_teller"]},
                   "DockPersonnelDoor": {"leaf": "metal", "bake_closed": True, "tag": "dock_door",
                                         "npc": ["guard_rover_dock", "guard_vaultline", "guard_rover_hall"]}}
# Doors on the §7.12 routes (>= 1.0 m leaves): stairs, BC, PC service, LK, J1, SV, EA, XL, HH, the teller gate, the TW
# staff doors, the dock / fire-exit doors.
ROUTE_DOORS = ["StairDoorSAB", "StairDoorSAG", "StairDoorSAM", "StairDoorSAE", "StairDoorSBB", "StairDoorSBG",
               "StairDoorSBM", "StairDoorSBE", "DockCorridorDoor", "ClientServiceDoor", "LockerDoor", "JanitorDoorG",
               "ServerDoor", "AssistantDoor", "LoungeDoor", "HeadHouseDoor", "TellerGate", "StaffDoorTWW",
               "StaffDoorTWE", "RecordsDoor", "DepositHallDoor", "CartQueueDoor"]


def P(kind: str, name: str, f: str, pos: list, yaw: float, props: Dict = None, use: list = None, metas: Dict = None,
      vis: str = "") -> list:
    return ["prefab", kind, name, f, pos, yaw, props or {}, use, metas or {}, vis]


def S(name: str, kind: str, f: str, pos: list, yaw: float, tags: list, idle: str = "", graph: str = "",
      seat: str = "") -> list:
    return ["spawn", name, kind, f, pos, yaw, tags, idle, graph, seat]


def B(name: str, f: str, base: list, size: list, yaw: float, kind: str, support: bool = False,
      mat: str = "prop", metas: Dict = None) -> list:
    return ["box", name, f, base, size, yaw, kind, support, mat, metas or {}]


def M(name: str, f: str, pos: list, tag: str, todo: str, yaw: float = 0.0) -> list:
    return ["marker", name, f, pos, yaw, tag, todo]


def T(name: str, kind: str, f: str, pos: list, yaw: float, tags: list, breach: bool = False) -> list:
    return ["tac", name, kind, f, pos, yaw, tags, breach]


def wall(kind: str, name: str, f: str, pos: list, yaw: float, props: Dict = None, vis: str = "",
         reach: float = 0.7) -> list:
    """A wall-mounted prefab (pivot on the wall face, front -Z away from it) with its UsePoint `reach` m in front."""
    a = math.radians(yaw)
    use = [round(pos[0] - math.sin(a) * reach, 3), 0.0, round(pos[2] - math.cos(a) * reach, 3)]
    return P(kind, name, f, pos, yaw, props, use, {"mount": "wall"}, vis)


def front(pos: list, yaw: float, d: float, y: float = 0.0) -> list:
    a = math.radians(yaw)
    return [round(pos[0] - math.sin(a) * d, 3), y, round(pos[2] - math.cos(a) * d, 3)]


# --- furniture (Props/MapBuilt support boxes; greybox) -------------------------------------------------
def _desk(name: str, f: str, x: float, z: float, along_z: bool = True) -> list:
    return B(name, f, [x, 0.0, z], [0.7, 0.75, 1.4] if along_z else [1.4, 0.75, 0.7], 0.0, "desk", True)


FURNITURE: List[list] = [
    # Basement
    B("LockersLK", "B", [0.47, 0.0, 4.65], [0.52, 1.8, 3.0], 0.0, "lockers", False),
    B("WCPartitionLK1", "B", [6.5, 0.0, 0.95], [0.05, 2.0, 1.5], 0.0, "partition", False, "trim"),
    B("WCPartitionLK2", "B", [8.0, 0.0, 0.95], [0.05, 2.0, 1.5], 0.0, "partition", False, "trim"),
    B("SinksLK", "B", [9.6, 0.0, 4.0], [0.5, 0.9, 1.6], 0.0, "counter", True),
    B("BenchLK", "B", [4.0, 0.0, 4.5], [1.6, 0.45, 0.4], 0.0, "bench", True),
    B("CartShelfCQ", "B", [10.35, 0.0, 5.5], [0.4, 1.8, 2.2], 0.0, "shelf", True),
    B("CountTableW", "B", [19.0, 0.0, 3.5], [2.4, 0.9, 1.0], 0.0, "table", True),
    B("CountTableE", "B", [23.5, 0.0, 3.5], [2.4, 0.9, 1.0], 0.0, "table", True),
    B("BoilerPL", "B", [28.2, 0.0, 2.0], [2.0, 1.6, 2.0], 0.0, "plant", False),
    B("AHUPL", "B", [32.4, 0.0, 2.0], [2.4, 1.6, 2.2], 0.0, "plant", False),
    B("TelecomFrameCM", "B", [35.6, 0.0, 2.5], [0.6, 2.0, 2.4], 0.0, "rack", False),
    B("ShelvesSS", "B", [44.55, 0.0, 3.5], [0.6, 2.0, 4.0], 0.0, "shelf", True),
] + [B("RecordsShelf%d" % (i + 1), "B", [2.0 + 1.8 * i, 0.0, 17.0], [0.6, 2.4, 12.0], 0.0, "shelf", True)
     for i in range(6)] + [
    B("ViewingBench", "B", [26.0, 0.0, 9.35], [1.6, 0.45, 0.45], 0.0, "bench", True),
    B("AttendantDesk", "B", [37.0, 0.0, 10.25], [1.6, 0.75, 0.7], 0.0, "desk", True),
] + [B("BoxUnit%d" % (i + 1), "B", [40.25, 0.0, z + 0.25], [9.5, 2.2, 0.5], 0.0, "deposit_boxes", False)
     for i, z in enumerate([11.8, 16.8, 21.8])] + [
    B("BoothCounterSD", "B", [47.5, 0.0, 17.0], [0.6, 0.9, 9.0], 0.0, "counter", True),
] + [B("BoothPartition%d" % (i + 1), "B", [46.9, 0.0, z], [0.6, 2.0, 0.05], 0.0, "partition", False, "trim")
     for i, z in enumerate([14.0, 17.0, 20.0])] + [
    # Ground
    B("CartsLD", "G", [1.0, 0.0, 6.5], [1.2, 1.2, 1.6], 0.0, "cart", False),
    B("BenchLD", "G", [7.0, 0.0, 8.55], [1.6, 0.45, 0.4], 0.0, "bench", True),
    B("PanelsE1", "G", [11.5, 0.0, 3.4], [2.0, 2.0, 0.4], 0.0, "panel", False),
    B("CoffeeCounterSR", "G", [16.45, 0.0, 5.0], [0.5, 0.9, 1.2], 0.0, "counter", True),
    B("KeyChestSR", "G", [22.57, 0.0, 5.6], [0.65, 1.32, 0.47], 0.0, "file_cabinet", True),
    B("LockersGR", "G", [26.0, 0.0, 0.47], [4.0, 1.8, 0.52], 0.0, "lockers", False),
    B("KitBenchGR", "G", [26.0, 0.0, 3.5], [1.6, 0.45, 0.4], 0.0, "bench", True),
    B("SortingTableMO", "G", [41.5, 0.0, 3.0], [2.4, 0.9, 1.0], 0.0, "table", True),
    B("CopierMO", "G", [44.4, 0.0, 1.0], [0.7, 1.2, 0.8], 0.0, "copier", False),
    _desk("DeskLO1", "G", 2.5, 12.0), _desk("DeskLO2", "G", 2.5, 16.0),
    B("FilesLO", "G", [7.6, 0.0, 15.0], [0.47, 1.32, 1.3], 0.0, "file_cabinet", True),
    B("TableCN1", "G", [4.0, 0.0, 21.5], [1.2, 0.75, 1.2], 0.0, "table", True),
    B("TableCN2", "G", [4.0, 0.0, 26.5], [1.2, 0.75, 1.2], 0.0, "table", True),
    B("ATM1", "G", [0.55, 0.0, 31.0], [0.7, 1.7, 0.8], 0.0, "atm", False),
    B("ATM2", "G", [0.55, 0.0, 33.0], [0.7, 1.7, 0.8], 0.0, "atm", False),
    B("ManagerDesk", "G", [44.0, 0.0, 24.3], [0.8, 0.75, 1.6], 0.0, "desk", True),
    B("ManagerCredenza", "G", [47.55, 0.0, 21.0], [0.45, 0.75, 1.6], 0.0, "credenza", True),
    _desk("DeskNA", "G", 45.0, 33.5),
    B("WCPartitionPW", "G", [44.0, 0.0, 28.0], [0.05, 2.0, 1.8], 0.0, "partition", False, "trim"),
    B("CoffeeServicePC", "G", [47.55, 0.0, 16.5], [0.45, 0.9, 1.6], 0.0, "counter", True),
    B("CoffeeTablePC", "G", [44.25, 0.0, 14.0], [0.8, 0.45, 0.8], 0.0, "table", True),
] + [B("TellerWorktop%02d" % (i + 1), "G", [x0 + 1.233 + 2.467 * k, 0.0, (COUNTER["top"][0] + COUNTER["top"][1]) / 2],
       [2.46, COUNTER["top"][2], round(COUNTER["top"][1] - COUNTER["top"][0], 3)], 0.0,
       "teller_worktop", True, "counter", {"hide_behind": True}) for i, (x0, k) in
     enumerate([(8.1, k) for k in range(6)] + [(25.1, k) for k in range(6)])] + [B("CheckDesk%d" % (i + 1), "G", [x, 0.0, z], CHECK_D, 0.0, "check_desk", True) for i, (x, z) in enumerate(CHECK_DESKS)
     ] + [
    B("HallBenchW1", "G", [8.35, 0.0, 23.0], [0.5, 0.45, 1.8], 0.0, "bench", True),
    B("HallBenchW2", "G", [8.35, 0.0, 28.5], [0.5, 0.45, 1.8], 0.0, "bench", True),
    B("HallBenchE1", "G", [39.65, 0.0, 21.0], [0.5, 0.45, 1.8], 0.0, "bench", True),
    B("HallBenchE2", "G", [39.65, 0.0, 26.0], [0.5, 0.45, 1.8], 0.0, "bench", True),
    B("HallBenchSW", "G", [16.0, 0.0, 31.0], [1.8, 0.45, 0.5], 0.0, "bench", True),
    B("HallBenchSE", "G", [32.0, 0.0, 31.0], [1.8, 0.45, 0.5], 0.0, "bench", True),
] + [B("QueueRail%d" % (i + 1), "G", [(a + b) / 2, 0.0, z], [b - a, 1.0, 0.05], 0.0, "queue_rail", False, "trim")
     for i, (a, b, z) in enumerate(QUEUE_RAILS)] + [
    # Gallery
    B("BreakTable", "M", [5.0, 0.0, 3.5], [2.4, 0.75, 1.0], 0.0, "table", True),
    B("BreakCounter", "M", [7.0, 0.0, 0.5], [3.0, 0.9, 0.6], 0.0, "counter", True),
    B("BreakFridge", "M", [9.5, 0.0, 0.55], [0.7, 1.8, 0.7], 0.0, "fridge", False),
    B("PanelsE2", "M", [11.5, 0.0, 0.4], [2.0, 2.0, 0.4], 0.0, "panel", False),
    _desk("DeskIT1", "M", 18.0, 3.0), _desk("DeskIT2", "M", 21.5, 3.0),
    B("RacksSV", "M", [24.0, 0.0, 3.5], [0.6, 2.0, 3.0], 0.0, "rack", False),
    B("ShelvesAR", "M", [44.55, 0.0, 3.5], [0.6, 2.0, 4.0], 0.0, "shelf", True),
    _desk("DeskAO1", "M", 2.5, 12.5), _desk("DeskAO2", "M", 2.5, 21.5), _desk("DeskAO3", "M", 2.5, 30.5),
    _desk("DeskOF", "M", 12.0, 12.5),
    B("WorkstationsOF1", "M", [18.0, 0.0, 11.5], [3.2, 0.75, 1.6], 0.0, "desk", True),
    B("WorkstationsOF2", "M", [23.5, 0.0, 11.5], [3.2, 0.75, 1.6], 0.0, "desk", True),
    B("ConferenceTable", "M", [31.0, 0.0, 13.0], [3.0, 0.75, 1.2], 0.0, "table", True),
    _desk("DeskCO", "M", 37.5, 13.0),
    B("WritingDeskGAW", "M", [14.0, 0.0, 17.4], [1.6, 0.75, 0.6], 0.0, "desk", True),
    B("WritingDeskGAE", "M", [34.0, 0.0, 17.4], [1.6, 0.75, 0.6], 0.0, "desk", True),
    _desk("DeskVO", "M", 45.0, 12.5),
    _desk("DeskTR", "M", 45.0, 22.0), B("TableTT", "M", [45.0, 0.0, 31.5], [1.2, 0.75, 2.4], 0.0, "table", True),
    # Executive
    B("BoardTable", "E", [5.0, 0.0, 3.5], [6.0, 0.75, 1.6], 0.0, "table", True),
    _desk("DeskEA", "E", 20.5, 3.2),
    B("PresidentDesk", "E", [27.0, 0.0, 4.0], [2.0, 0.75, 1.0], 0.0, "desk", True),
    B("PresidentShelves", "E", [34.55, 0.0, 3.5], [0.6, 2.0, 4.0], 0.0, "shelf", True),
    B("PantryCounter", "E", [38.5, 0.0, 0.5], [3.0, 0.9, 0.6], 0.0, "counter", True),
    B("PantryTable", "E", [38.5, 0.0, 4.0], [1.2, 0.75, 1.2], 0.0, "table", True),
    B("LoungeBar", "E", [14.0, 0.0, 12.5], [0.6, 1.05, 3.0], 0.0, "counter_bar", True),
    B("LoungeSofaW", "E", [4.0, 0.0, 11.0], [3.0, 0.45, 0.9], 0.0, "sofa", True),
    B("TableLG", "E", [22.0, 0.0, 13.0], [3.2, 0.75, 1.6], 0.0, "desk", True),
    B("TableCT", "E", [34.0, 0.0, 13.0], [3.2, 0.75, 1.6], 0.0, "desk", True),
    B("ShelvesRA", "E", [47.55, 0.0, 12.5], [0.45, 2.0, 5.0], 0.0, "shelf", True),
] + [B("TerracePlanter%d" % (i + 1), "E", [x, 0.0, z], [1.2, 0.8, 1.2], 0.0, "planter", True)
     for i, (x, z) in enumerate([[3.0, 32.0], [3.0, 26.0], [10.0, 34.0], [32.0, 34.0], [44.0, 33.5]])] + [
    B("TerraceBench1", "E", [24.0, 0.0, 34.2], [1.8, 0.45, 0.5], 0.0, "bench", True),
    # Roof
    B("RoofAHU", "R", [39.0, 0.0, 4.5], [3.0, 2.0, 2.4], 0.0, "plant", False),
    B("RoofTank", "R", [39.0, 0.0, 12.5], [2.0, 2.5, 2.0], 0.0, "plant", False),
    B("RoofCondensers", "R", [8.0, 0.0, 9.0], [3.0, 1.2, 1.2], 0.0, "plant", False),
    # Exterior
    B("CameraPoleC6", "G", [20.0, 0.0, -5.7], [0.15, 3.4, 0.15], 0.0, "pole", False, "trim"),
    B("Kiosk", "G", [36.0, -0.75, 43.0], [2.0, 2.6, 2.0], 0.0, "kiosk", False),
] + [B("PlazaPlanter%d" % (i + 1), "G", [x, -0.75, z], [1.2, 0.8, 1.2], 0.0, "planter", True)
     for i, (x, z) in enumerate([[4.0, 40.5], [12.0, 40.5], [36.0, 40.5], [44.0, 40.5], [-8.0, 42.0]])] + [
    B("PlazaBench1", "G", [8.0, -0.75, 45.0], [1.8, 0.45, 0.5], 0.0, "bench", True),
    B("PlazaBench2", "G", [40.0, -0.75, 45.0], [1.8, 0.45, 0.5], 0.0, "bench", True),
    B("ParkedCar1", "G", [55.5, 0.0, 26.0], [2.0, 1.45, 4.6], 0.0, "car", False),
    B("ParkedCar2", "G", [-6.0, -0.75, 50.5], [4.6, 1.45, 2.0], 0.0, "car", False),
    B("ParkedCar3", "G", [52.0, -0.75, 59.0], [4.6, 1.45, 2.0], 0.0, "car", False),
]


# --- always-present gameplay ----------------------------------------------------------------------------
def _alarm(name: str, f: str, pos: list, yaw: float) -> list:
    return wall("alarm_button", name, f, pos, yaw, {}, "prop_alarm_button")


def _phone(name: str, f: str, pos: list, yaw: float) -> list:
    return wall("phone", name, f, pos, yaw, {}, "prop_phone_wall")


def _deposit(name: str, pos: list, yaw: float) -> list:
    return wall("deposit_box", name, "B", pos, yaw, {"loot_id": "loot.small_valuables", "value": 1600,
                                                     "objective_tag": "deposit_boxes"}, "prop_deposit_box_consign", 0.85)


VAULT_BOXES = ([_deposit("VaultBoxN%02d" % (i + 1), [15.0 + i, 1.0, 13.3], 180.0) for i in range(8)]
               + [_deposit("VaultBoxN%02d" % (9 + i), [x, 1.0, 13.3], 180.0) for i, x in enumerate([25.6, 26.4, 27.2])]
               + [_deposit("VaultBoxS%02d" % (i + 1), [16.0 + 2 * i, 1.0, 24.8], 0.0) for i in range(9)])
SD_BOXES = [_deposit("HallBox%02d" % (8 * r + i + 1), [36.0 + 1.2 * i, 1.0, z + 0.5], 180.0)
            for r, z in enumerate([11.8, 16.8, 21.8]) for i in range(8)]

ALWAYS: Dict[str, List[list]] = {
    "Gameplay/Devices": [
        P("camera_station", "CameraStation", "G", [19.5, 0.0, 0.6], 180.0, {"@operator_spawn": "CameraOperatorSeat"},
          None, {}, "prop_camera_station_bank"),
        P("keycard_reader", "VaultGateReader", "B", [18.65, 1.2, 8.9], 0.0, {"objective_tag": "vault_gate",
                                                                           "@targets": ["VaultGate"]},
          [18.65, 0.0, 8.2], {"mount": "wall"}, "prop_keycard_reader"),
        # OF-A6 / D-136.1: no door target (the mission opens the vault door when the time lock runs out)
        P("keypad", "TimeLockConsole", "B", [33.9, 1.2, 11.6], 90.0, {"code_group": "vault", "stealth_only": True,
                                                                     "objective_tag": "time_lock"},
          [33.0, 0.0, 11.6], {"mount": "wall"}, "prop_keypad"),
        P("keypad", "CashCageKeypad", "B", [25.25, 1.2, 17.45], 0.0, {"code_group": "vault", "objective_tag": "cash_cage",
                                                                     "@targets": ["CashCageGate"]},
          [25.25, 0.0, 16.6], {"mount": "wall"}, "prop_keypad"),
        # A r305 (the PO: "standing upright, isn't it meant to drill into something?"): the lance burns DOWN through the
        # lid. The spot sits on the lid's centre, pitched so its -Z (the bit) points at the floor; the drill-down rig
        # (prop_thermal_drill_down: the tripod's feet in the tip plane, r 0.55) is the placed device, and the spot shows
        # nothing until it is placed (visual: the shared empty scene, as RT's truck saw spots).
        P("drill_point", "LidDrill", "G", [24.0, 0.0, 14.0], 0.0, {"device": "enum:THERMAL", "duration_s": 360.0,
                                                                "loud_only": True, "objective_tag": "vault_drill",
                                                                "requires_loot": "loot.thermal_drill_part",
                                                                "requires_count": 2,
                                                                "device_scene": "prop_thermal_drill_down"},
          [25.7, 0.0, 14.0], {"requires_loot": "loot.thermal_drill_part", "requires_count": 2, "pitch": -90.0,
                                                                  "tilted": True},
          "res://world/heists/glasshouse/art/gh_empty.tscn"),
        _alarm("AlarmSR", "G", [18.2, 1.1, 0.2], 180.0), _alarm("AlarmBM", "G", [47.8, 1.1, 22.5], 90.0),
        _alarm("AlarmSD", "B", [34.1, 1.1, 11.0], -90.0),
    ] + [_alarm("AlarmTeller%d" % (i + 1), "G", [x + 0.3, 0.75, COUNTER["top"][0]], 0.0) for i, x in enumerate(STATIONS)] + [
        _phone("PhoneBM", "G", [47.8, 1.4, 26.0], 90.0), _phone("PhoneLO", "G", [0.2, 1.4, 10.5], -90.0),
        _phone("PhoneNA", "G", [47.8, 1.4, 35.0], 90.0), _phone("PhonePC", "G", [47.8, 1.4, 18.4], 90.0),
        _phone("PhoneSR", "G", [16.15, 1.4, 3.0], -90.0), _phone("PhoneSD", "B", [34.1, 1.4, 10.0], -90.0),
        _phone("PhoneBR", "M", [0.2, 1.4, 5.0], -90.0), _phone("PhoneVO", "M", [47.8, 1.4, 16.0], 90.0),
        _phone("PhoneEA", "E", [22.9, 1.4, 1.5], 90.0),
    ],
    "Gameplay/Loot": [
        P("loot_spawn", "VaultCash", "B", [24.0, 0.0, 20.5], 0.0, {"loot_id": "loot.cash_bricks", "count": 10,
                                                                  "objective_tag": "vault_loot"},
          [24.0, 0.0, 19.0], {}, "prop_cash_pallet"),
        P("loot_spawn", "VaultGold", "B", [32.0, 0.0, 19.0], 90.0, {"loot_id": "loot.gold", "count": 4,
                                                                   "objective_tag": "gold_cage"},
          [30.4, 0.0, 19.0], {}, "prop_cash_pallet"),
        P("safe", "BondSafe", "B", [14.71, 0.0, 20.5], -90.0, {"size": "enum:SMALL",
                                                             "methods": ["drill", "saw", "lockpick"],
                                                             "objective_tag": "bond_safe",
                                                             "@contents": [["loot_spawn", "VaultBonds", [0.0, 0.3, 0.0],
                                                                            {"loot_id": "loot.bearer_bonds", "count": 1,
                                                                             "objective_tag": "bond_safe"}]]},
          [15.9, 0.0, 20.5], {}, "prop_safe_large"),
        P("loot_spawn", "ServerDrives", "M", [26.0, 0.0, 4.0], 180.0, {"loot_id": "loot.server_drives", "count": 2,
                                                                      "objective_tag": "server_drives"},
          [26.0, 0.0, 5.3], {}, "prop_cash_bags"),
    ] + [P("small_loot", "TellerDrawer%d" % (i + 1), "G", [x, 1.0, 16.7], 0.0,
           {"loot_id": "loot.small_valuables", "value": 500, "objective_tag": "teller_drawer"}, [x - 0.6, 0.0, 15.8],
           {}, "prop_cash_stack") for i, x in enumerate(STATIONS)] + [
        P("small_loot", "CountStraps%d" % (i + 1), "B", [x, 0.9, 3.5], 0.0,
          {"loot_id": "loot.small_valuables", "value": 800, "objective_tag": "cp_cash"}, [x, 0.0, 4.6], {},
          "prop_cash_stack") for i, x in enumerate([18.3, 19.7, 22.8, 24.2])
    ] + VAULT_BOXES + SD_BOXES,
    "Gameplay/Lifts": [
        # LEAD GPU-22 / ENV P ghost note: the car fills GL's shaft (B's inner faces z 0.24 / x 12.81) so a bag thrown
        # in from either landing door, which stops at the shaft's back wall (1.22 m off the car centre), rests inside
        # the count box (test_of_cash_lift_throw.gd)
        P("bag_lift", "CashLift", "B", [11.5, 0.0, 1.55], 180.0, {"travel_s": 8.0, "capacity": 2, "door_fold": True,
                                                                 "car_size_m": [2.55, 2.4, 2.55],
                                                                 "objective_tag": "cash_lift",
                                                                 "@landings": [["CashLiftLandingG", [0.0, 4.0, 0.0]]]},
          [11.5, 0.0, 2.2], {"walkable": True}, "prop_cash_lift_car_w255"),
        P("bag_lift", "Hoist", "B", [24.0, 0.0, HOIST_Z], 0.0, {"travel_s": 6.0, "capacity": 2, "car_size_m": HOIST_CAR,
                                                            "loud_only": True, "objective_tag": "hoist",
                                                            "phase_block_key": "ui.blocked.after_breach",
                                                            "enabled_at_start": False,
                                                            "@landings": [["HoistLandingTW", [0.0, 4.0, 0.0]]],
                                                            "@rig": HOIST_RIG, "@panel": HOIST_PANEL},
          [25.1, 0.0, HOIST_Z], {"starts_disabled": True, "hidden": True}, "prop_hoist_cradle_w110"),
    ],
    "Gameplay/Ladders": [
        # rolled up under the lid until the burn (full length, its rails would sit in the lid plug): 3.2 m to the lid's
        # underside; OF-A2 sets height_m = burn_height_m (4.0, B -> G) when it enables the ladder at the burn (QC-61).
        P("ladder", "RopeLadder", "B", [24.0, 0.0, ROPE_Z], 180.0, {"height_m": ROPE_STOWED_M, "usable": False,
                                                              "enabled_at_start": False, "objective_tag": "rope_ladder"},
          None, {"loud_only": True, "starts_disabled": True, "hidden": True, "burn_height_m": 4.0,
                 "never_with": ["Lid"]},   # enabled by the burn that disables the lid (validate_level clipping)
          "prop_ladder_rope_h400"),
        P("ladder", "CagedLadder", "E", [46.0, 0.0, 17.55], 180.0, {"height_m": 3.6, "objective_tag": "caged_ladder"},
          None, {}, "prop_ladder_steel_h360_g35_cage"),
    ],
    "Gameplay/Markers": [
        M("CasingHall", "G", [24.0, 0.0, 27.5], "casing", "casing objective marker: the hall at the meridian line"),
        # Ashgrove's desk planner (QC-63): reading it reveals the code_pc group (no code_group: it names the PC only)
        P("code_note", "CodeHintPlanner", "G", [43.9, 0.75, 23.9], 90.0, {"objective_tag": "code_hint",
                                                                       "reveals_variant_group": "code_pc"},
          [42.9, 0.0, 23.9], {}, "prop_notebook"),
        M("TimeLockWait", "B", [6.5, 0.0, 10.4], "time_lock_wait", "RC: the time-lock wait room"),
        M("VaultBreach", "G", [24.0, 0.0, 14.6], "vault_breach", "the lid / the hole (24, 14.6): burn-through"),
        # rare bond_delivery (+2 loot.bearer_bonds, HeistMission.spawn_loot): the open vault floor E of the bond safe
        M("BondDelivery", "B", [16.5, 0.0, 18.0], "bond_delivery", "rare bond_delivery: +2 bond bags (OF-A6)"),
        M("RappelLanding", "R", [2.0, 0.0, 14.0], "police_rappel_roof", "rp: P5 rappel landing (police only)"),
    ] + [M("Holdout" + h, f, [x, 0.0, z], "holdout_" + h.lower(), "doc Loud holdout " + h)
         for h, f, x, z in [("H1", "G", 24.0, 13.0), ("H2", "B", 24.0, 10.0), ("H3", "G", 5.0, 4.5),
                            ("H4", "E", 36.0, 27.0), ("H5", "G", 46.0, 8.0)]],
    "Gameplay/Containers": [
        P("body_container", "DumpsterW", "G", [26.5, 0.0, -0.76], 0.0, {"capacity": 2}, None, {"kind": "dumpster"},
          "prop_dumpster"),
        P("body_container", "DumpsterE", "G", [29.0, 0.0, -0.76], 0.0, {"capacity": 2}, None, {"kind": "dumpster"},
          "prop_dumpster"),
        P("body_container", "LockerHideLK1", "B", [0.63, 0.0, 1.0], -90.0, {"capacity": 1}, None, {"kind": "lockers"},
          "prop_crate_hide"),
        P("body_container", "LockerHideLK2", "B", [0.63, 0.0, 2.45], -90.0, {"capacity": 1}, None, {"kind": "lockers"},
          "prop_crate_hide"),
        P("body_container", "JanitorCartJ1", "G", [36.5, 0.0, 0.66], 180.0, {"capacity": 1}, None, {"kind": "cart"},
          "prop_cart_hide"),
        P("body_container", "JanitorCartJ2", "M", [36.5, 0.0, 0.66], 180.0, {"capacity": 1}, None, {"kind": "cart"},
          "prop_cart_hide"),
        P("body_container", "PlantCratePL", "B", [34.48, 0.0, 5.3], 90.0, {"capacity": 1}, None, {"kind": "crate"},
          "prop_crate_hide"),
    ],
}

# --- NPC spawns ----------------------------------------------------------------------------------------
FIXED_SPAWNS: List[list] = [
    S("GuardLobby", "GUARD", "G", [24.0, 0.0, 30.0], 0.0, ["guard_lobby"], "look", "Bank"),
    S("GuardVault", "GUARD", "B", [26.0, 0.0, 11.0], 90.0, ["guard_vault"], "look", "Bank"),
    S("CameraOperatorSeat", "CAMERA_OPERATOR", "G", [19.5, 0.0, 1.6], 0.0, ["security_operator"], "desk_work", "",
      "prop_chair_office"),
] + [S("Teller%d" % (i + 1), "CIVILIAN", "G", [x, 0.0, TELLER_Z], 180.0,
       ["civ_teller"] + (["civ_teller_rotating"] if i == 3 else []), "teller_count") for i, x in enumerate(TELLERS)] + [
    # D-136 §3b.5 (LEAD, OF-C1): the SD attendant, always, at her desk (AttendantDesk z 9.9-10.6) on lane B's
    # ChairSDAttendant (of_art_rooms.gd: prop_chair_office at (37, -4, 9.55), yaw 180): on its Seat, 0.12 m to the chair's
    # front (catalog `seat`), facing the desk. The art rooms are built after NpcSeatSpawns.snap, so the Seat is
    # placed here. Tags: `civ_sd_attendant` (the doc's roster tag; no D look yet) then `civ_teller` (D's teller looks,
    # staff doors; NOT civ_officer: the mission binds any unrouted civ_officer to officer_coffee).
    S("SDAttendant", "CIVILIAN", "B", [37.0, 0.0, 9.67], 180.0, ["civ_sd_attendant", "civ_teller"], "desk_work"),
    S("PlazaPedestrian1", "CIVILIAN", "G", [10.0, -0.75, 44.0], 90.0, ["civ_plaza"], "walk_text"),
    S("PlazaPedestrian2", "CIVILIAN", "G", [44.0, -0.75, 44.0], -90.0, ["civ_plaza"], "walk_text"),
    # Rare armored_car_early (QC-25 timed spawn, HeistRuntime scripted tag): the Vaultline crew at the dock.
    S("VaultlineA", "GUARD", "G", [3.0, 0.0, 4.5], 0.0, ["scripted", "guard_vaultline"], "", "Bank"),
    S("VaultlineB", "GUARD", "G", [7.0, 0.0, 4.5], 0.0, ["scripted", "guard_vaultline"], "", "Bank"),
]
CARRIER = "keycard_carrier"   # QC-62: KeycardPickup.carrier_tag on kc_on_manager; every manager spawn carries it


def _customer(name: str, pos: list, yaw: float, idle: str, tag: str) -> list:
    return S(name, "CIVILIAN", "G", pos, yaw, ["civ_customer", tag], idle)


HALL_CUSTOMERS = [
    _customer("CustomerWindow1", [15.0, 0.0, COUNTER_CUSTOMER_Z], 0.0, "counter_customer", TAG_COUNTER),
    _customer("CustomerWindow2", [31.0, 0.0, COUNTER_CUSTOMER_Z], 0.0, "counter_customer", TAG_COUNTER),
    _customer("CustomerQueue1", [12.0, 0.0, QUEUE_Z], 0.0, "queue_idle", TAG_QUEUE),
    _customer("CustomerCheck1", [19.5, 0.0, CHECK_Z], 0.0, "check_desk_write", TAG_CHECK),
    _customer("CustomerWindow3", [17.0, 0.0, COUNTER_CUSTOMER_Z], 0.0, "counter_customer", TAG_COUNTER),
    _customer("CustomerQueue2", [13.0, 0.0, QUEUE_Z], 0.0, "queue_idle", TAG_QUEUE),
    _customer("CustomerCheck2", [28.5, 0.0, CHECK_Z], 0.0, "check_desk_write", TAG_CHECK),
    _customer("CustomerQueue3", [29.5, 0.0, QUEUE_Z], 0.0, "queue_idle", TAG_QUEUE),
]


def _client(name: str, pos: list, yaw: float) -> list:
    return S(name, "CIVILIAN", "G", pos, yaw, ["civ_client"], "sit", "", "prop_chair_office")


def _officer(name: str, f: str, x: float, z: float) -> list:   # its own coffee route binds its per-desk tag
    return S(name, "CIVILIAN", f, [x, 0.0, z], -90.0, ["civ_officer", "civ_officer_" + name[7:].lower()], "desk_work", "",
             "prop_chair_office")


OFFICER_SEATS = [("OfficerAO1", "M", 1.75, 12.5), ("OfficerOF", "M", 11.25, 12.5), ("OfficerVO", "M", 44.25, 12.5)]


# --- civilian routes (OF-A4 CivilianRoute, D-136 §3b.4; doc Circulation) -------------------------------------------
def R(name: str, rid: str, tags: list, stops: list, start: int = 0, order: str = "LOOP") -> list:
    return ["route", name, rid, order, tags, start, stops]


def _station(nm: str) -> list:   # the rotating teller's window (Teller4's mark, 0.1 m back onto the navmesh)
    return [nm, "G", [33.0, 0.0, round(TELLER_Z - 0.1, 3)], [60, 120], "teller_count", "", 180.0]


# Manager: mgr_away on his isolated stops (BM with the door shut, CF / PR upstairs, the LK WC). Officers: officer_away
# on the coffee / WC run (50-90 s away from the desk with the walk). Teller: teller_away on BR / WC (40-80 s).
ROUTES: List[list] = [
    R("ManagerFloorRoute", "mgr_floor", ["civ_manager_mgr_floor"], [
        ["Desk", "G", [45.4, 0.0, 25.6], [20, 40], "phone", "mgr_away", 90.0],
        ["Hall", "G", [26.0, 0.0, 27.0], [10, 20], "idle", "", None],
        ["TellerLine", "G", [28.0, 0.0, 13.0], [10, 20], "look", "", None],
        ["Lounge", "G", [46.0, 0.0, 11.5], [10, 20], "idle", "", None]]),
    R("ManagerGalleryRoute", "mgr_gallery", ["civ_manager_mgr_gallery"], [
        ["VaultOps", "M", [45.5, 0.0, 15.5], [20, 40], "phone", "", None],
        ["Conference", "M", [32.5, 0.0, 14.7], [30, 60], "phone", "mgr_away", None],
        ["OpenOffice", "M", [20.0, 0.0, 14.5], [10, 20], "look", "", None],
        ["Partner", "E", [30.0, 0.0, 4.5], [30, 60], "phone", "mgr_away", None]], 1),
    R("ManagerVaultRoute", "mgr_vault", ["civ_manager_mgr_vault"], [
        ["Attendant", "B", [37.0, 0.0, 11.3], [30, 60], "phone", "", 0.0],
        ["CountRoom", "B", [21.0, 0.0, 5.0], [10, 20], "look", "", None],
        ["LockerWC", "B", [7.25, 0.0, 2.2], [40, 70], "idle", "mgr_away", None],
        ["ServiceCorridor", "G", [40.0, 0.0, 8.0], [10, 20], "idle", "", None]]),
    R("CoffeeOfficerAO1", "officer_coffee", ["civ_officer_ao1"], [
        ["Desk", "M", [4.0, 0.0, 15.5], [60, 120], "desk", "", None],
        ["Coffee", "M", [7.5, 0.0, 5.5], [30, 60], "mug", "officer_away", None]]),
    R("CoffeeOfficerOF", "officer_coffee_of", ["civ_officer_of"], [
        ["Desk", "M", [14.0, 0.0, 15.0], [60, 120], "desk", "", None],
        ["WC", "M", [33.5, 0.0, 3.5], [20, 40], "idle", "officer_away", None]]),
    R("CoffeeOfficerVO", "officer_coffee_vo", ["civ_officer_vo"], [
        ["Desk", "M", [45.5, 0.0, 14.5], [60, 120], "desk", "", None],
        ["WC", "M", [33.5, 0.0, 3.5], [25, 55], "idle", "officer_away", None]]),
]
# The rotating teller (Teller4): BR coffee / the WW WC, or (door_fire_propped) a smoke outside the propped fire exit.
# One `teller_rotation` route per roll: it lives in the side_door slots.
TELLER_ROUTE = R("TellerRotation", "teller_rotation", ["civ_teller_rotating"], [
    _station("Station"), ["Coffee", "M", [7.5, 0.0, 5.5], [8, 15], "mug", "teller_away", None],
    _station("Station2"), ["WC", "G", [33.5, 0.0, 3.5], [25, 50], "idle", "teller_away", None]])
TELLER_SMOKE_ROUTE = R("TellerRotation", "teller_rotation", ["civ_teller_rotating"], [
    _station("Station"), ["Smoke", "G", [50.5, 0.0, 6.0], [30, 50], "smoke", "teller_away", 90.0]])

# --- slot content ------------------------------------------------------------------------------------------
def _code_pc(sid: str, f: str, x: float, z: float) -> list:
    return [P("hack_terminal", "CodePC", f, [x, 0.75, z], 90.0, {"duration_s": 45.0, "interruptions": [1, 1],
                                                                "objective_tag": "code_pc", "reveals_code_group": "vault"},
              [x, 0.0, z + 1.1], {"reveals_code_group": "vault"}, "")]


def _server(f: str, rack: list, ctrl: list) -> list:
    return [P("hack_terminal", "VaultControlRack", f, rack, 180.0, {"duration_s": 90.0, "interruptions": [2, 2],
                                                                    "objective_tag": "server"},
              [rack[0], 0.0, rack[2] + 1.3], {}, "prop_server_rack_terminal"),
            wall("hack_terminal", "LaserController", f, ctrl, 90.0, {"duration_s": 20.0, "interruptions": [0, 0],
                                                                      "objective_tag": "lasers"}, "prop_lift_breaker")]


def _escape(kind: str, sec_pos: list, sec_yaw: float, sec_size: list, esc_pos: list, esc_size: list, f: str,
            vis: str, esc_type: str, delay: float, esc_vis: str, label: str) -> list:
    """The escape slot's SECURE_LOOT zone, ESCAPE zone and wait marker. objective_tag stays `secure` / `escape` /
    `escape_wait` (the mission binds those; one escape slot is resolved per run, so tag + class is unique in a run);
    meta `escape_label` (E1 / E2 / E3, the doc's ids) names which escape a node belongs to for tools and tests."""
    props = {"objective_tag": "escape", "escape_type": esc_type, "zone_size_m": esc_size}
    if delay > 0.0:
        props["arrival_delay_s"] = delay
    m = M("EscapeWait" + kind, f, [esc_pos[0], 0.0, esc_pos[2]], "escape_wait", "loud: hold until the escape arrives")
    return [P("secure_zone", "Secure" + kind, f, sec_pos, sec_yaw, {"objective_tag": "secure", "zone_size_m": sec_size},
              None, {"kind": "vehicle", "escape_label": label}, vis),
            P("escape_zone", "Escape" + kind, f, esc_pos, 0.0, props, None, {"escape_label": label}, esc_vis), m]


SLOT_CONTENT: Dict[str, List[list]] = {
    "mgr_floor": [S("ManagerFloor", "CIVILIAN", "G", [45.0, 0.0, 24.3], 90.0, ["civ_manager_mgr_floor", CARRIER], "phone")],
    "mgr_gallery": [S("ManagerGallery", "CIVILIAN", "M", [32.5, 0.0, 14.7], 0.0, ["civ_manager_mgr_gallery", CARRIER],
                      "phone")],
    "mgr_vault": [S("ManagerVault", "CIVILIAN", "B", [37.0, 0.0, 11.3], 0.0, ["civ_manager_mgr_vault", CARRIER], "phone")],
    "kc_on_manager": [P("keycard_pickup", "Keycard", "G", [47.5, 0.75, 21.0], 90.0,
                        {"objective_tag": "keycard", "carrier_tag": CARRIER}, [46.5, 0.0, 21.0], {}, "prop_keycard_bank")],
    "kc_manager_desk": [P("keycard_pickup", "Keycard", "G", [44.0, 0.75, 24.8], 90.0, {"objective_tag": "keycard"},
                          [42.9, 0.0, 24.8], {}, "prop_keycard_bank")],
    "kc_vault_ops": [P("keycard_pickup", "Keycard", "M", [45.0, 0.75, 12.0], 90.0, {"objective_tag": "keycard"},
                       [45.0, 0.0, 11.0], {}, "prop_keycard_bank")],
    "kc_security": [P("keycard_pickup", "Keycard", "G", [22.57, 1.32, 5.6], 90.0, {"objective_tag": "keycard"},
                      [21.6, 0.0, 5.6], {}, "prop_keycard_bank")],
    "pc_ao1": _code_pc("pc_ao1", "M", 2.5, 12.5), "pc_ao2": _code_pc("pc_ao2", "M", 2.5, 21.5),
    "pc_ao3": _code_pc("pc_ao3", "M", 2.5, 30.5), "pc_ops": _code_pc("pc_ops", "M", 12.0, 12.5),
    "pc_vault_ops": _code_pc("pc_vault_ops", "M", 45.0, 12.7), "pc_exec": _code_pc("pc_exec", "E", 20.5, 3.2),
    "off_1": [_officer(*OFFICER_SEATS[0])],
    "off_2": [_officer(*OFFICER_SEATS[0]), _officer(*OFFICER_SEATS[1])],
    "off_3": [_officer(*OFFICER_SEATS[0]), _officer(*OFFICER_SEATS[1]), _officer(*OFFICER_SEATS[2])],
    "srv_gallery": _server("M", [27.0, 0.0, 0.8], [28.9, 1.2, 4.5]),
    "srv_basement": _server("B", [38.0, 0.0, 0.8], [39.9, 1.2, 4.5]),
    "rover_hall": [S("GuardRoverHall", "GUARD", "G", [28.0, 0.0, 8.0], 90.0, ["guard_rover_hall"], "", "Bank")],
    "rover_gallery": [S("GuardRoverGallery", "GUARD", "M", [20.0, 0.0, 8.0], 90.0, ["guard_rover_gallery"], "", "Bank")],
    "rover_basement": [S("GuardRoverBasement", "GUARD", "B", [28.0, 0.0, 8.0], 90.0, ["guard_rover_basement"], "",
                         "Bank")],
    "rover_dock": [S("GuardRoverDock", "GUARD", "G", [14.0, 0.0, -5.0], 90.0, ["guard_rover_dock"], "smoke", "Lane")],
    "cust_4": HALL_CUSTOMERS[:4],
    "cust_6": HALL_CUSTOMERS[:5] + [_client("ClientPC1", [43.25, 0.0, 14.0], -90.0)],
    "cust_8": HALL_CUSTOMERS[:6] + [_client("ClientPC1", [43.25, 0.0, 14.0], -90.0),
                                    _client("ClientPC2", [45.25, 0.0, 14.0], 90.0)],
    "fe_down": [P("ladder", "FireEscapeDropLadder", "G", [0.6, 0.0, -2.75], 0.0, {"height_m": 3.0,
                                                                                 "objective_tag": "fire_escape"},
                  None, {}, "prop_ladder_fire_escape_h300_g00")],
    "fe_up": [M("FireEscapeLadderUp", "G", [0.6, 3.0, -2.6], "", "the drop ladder raised (no climb)")],
    "esc_van_dock": _escape("Dock", [5.0, 0.0, -4.32], 180.0, [4.0, 3.0, 8.0], [10.5, 0.0, -3.0], [4.0, 3.0, 4.0], "G",
                            "veh_van_secure", "van", 0.0, "res://world/heists/shared/escape_van_marker.tscn", "E1"),
    # E2: the SECURE_LOOT strip runs from the van's rear doors (z 7.3) north under the terrace's SE corner (z 21.3), so
    # the terrace east parapet throw (§7.4) lands in it: x 48.2-54.2 (6.0 m: a HEAVY throw from the face lands at
    # x 51.5-52.9, a MEDIUM one at 54.7-56.3, within 2.1 m beside it).
    "esc_van_tannery": _escape("Tannery", [TANNERY_SECURE_X, 0.0, 14.28], 180.0, [6.0, 3.0, 14.0], [51.0, 0.0, 6.5],
                               [4.0, 3.0, 3.0], "G", "veh_van_secure", "van", 0.0,
                               "res://world/heists/shared/escape_van_marker.tscn", "E2"),
    "esc_heli_terrace": _escape("Terrace", [42.5, 0.0, 26.0], 0.0, [4.0, 3.0, 5.0], [35.5, 0.0, 27.0], [6.0, 3.0, 6.0],
                                "E", "prop_secure_cargo_net", "heli", 45.0, "veh_heli_escape", "E3"),
    "drop_terrace": [M("DrillDrop", "E", [20.0, 0.0, 33.0], "drill_delivery",
                       "loud: 2 x loot.thermal_drill_part (HeistMission.spawn_loot, OF-A1)")],
    "drop_dock": [M("DrillDrop", "G", [14.0, 0.0, -4.0], "drill_delivery",
                    "loud: Mercer's second van; 2 x loot.thermal_drill_part (OF-A1)")],
    "ps_bonds": [],   # filled below (the safe + its contents)
    "ps_empty": [],
    "vip_out": [],
    "vip_in": [S("VIPClient", "CIVILIAN", "B", [46.5, 0.0, 15.5], -90.0, ["civ_vip"], "sit", "", "prop_chair_consult"),
               S("VIPBodyguard", "GUARD", "B", [44.0, 0.0, 15.0], 90.0, ["guard_vip"], "look")],
    "gx_hall": [S("GuardExtraHall", "GUARD", "G", [16.0, 0.0, 27.0], 0.0, ["guard_extra_hall"], "", "Bank")],
    "gx_basement": [S("GuardExtraBasement", "GUARD", "B", [38.0, 0.0, 8.0], 90.0, ["guard_extra_basement"], "", "Bank")],
    "gx_none": [],
    "cx_hall_1": [_customer("LateCustomerCheck", [34.0, 0.0, CHECK_Z], 0.0, "check_desk_write", TAG_CHECK)],
    "cx_hall_2": [_customer("LateCustomerQueue", [34.0, 0.0, QUEUE_Z], 0.0, "queue_idle", TAG_QUEUE)],
    "cx_pc": [S("LateClientPC", "CIVILIAN", "G", [45.6, 0.0, 12.0], 90.0, ["civ_client"], "browse")],
    "cx_sd": [S("LateCustomerSD", "CIVILIAN", "B", [46.6, 0.0, 19.0], -90.0, ["civ_customer"], "browse")],
    "cx_none": [],
}
# The president's wall safe: its contents sit in the body's hollow (z -0.21, the LootAnchor depth; safe.gd interior_aabb
# is the body less 2 cm: on the back plane, z 0, they were moved to the anchor with a warning, PO GPU run)
for _sid in ("ps_bonds", "ps_empty"):
    SLOT_CONTENT[_sid] = [P("safe", "PresidentSafe", "E", [30.0, 0.85, 0.2], 180.0,
                            {"size": "enum:MEDIUM", "methods": ["drill", "saw"], "objective_tag": "president_safe",
                             "@contents": [] if _sid == "ps_empty" else [
                                                   ["loot_spawn", "PresidentBonds", [0.0, 0.05, -0.21],
                                                    {"loot_id": "loot.bearer_bonds", "count": 1,
                                                     "objective_tag": "president_safe"}],
                                                   ["small_loot", "PresidentValuables1", [-0.15, 0.05, -0.21],
                                                    {"loot_id": "loot.small_valuables", "value": 1500}],
                                                   ["small_loot", "PresidentValuables2", [0.0, 0.11, -0.21],
                                                    {"loot_id": "loot.small_valuables", "value": 1500}],
                                                   ["small_loot", "PresidentValuables3", [0.15, 0.05, -0.21],
                                                    {"loot_id": "loot.small_valuables", "value": 1500}]]},
                            [30.0, 0.0, 1.2], {"mount": "wall"}, "prop_safe_wall_small")]
SLOT_CONTENT["sec_staffed"] = []
# Routes by parent: "Patrols/Routes" (always) or a slot id (emitted into ostrander_federal_layout.gd: the line budget).
ROUTE_ROWS: Dict[str, list] = {"Patrols/Routes": ROUTES}
for _sid in ("door_fire_propped", "door_dock_open", "door_none"):
    ROUTE_ROWS[_sid] = [TELLER_SMOKE_ROUTE if _sid == "door_fire_propped" else TELLER_ROUTE]
SLOT_CONTENT["sec_empty"] = []
SLOT_PARAMS = {"sec_staffed": {"operator_spawn": "Spawns/CameraOperatorSeat",
                               "station": "Gameplay/Devices/CameraStation"},
               "esc_van_dock": {"label": "E1", "vehicle": "van"}, "esc_van_tannery": {"label": "E2", "vehicle": "van"},
               "esc_heli_terrace": {"label": "E3", "vehicle": "heli"},
               "cust_4": {"customers": 4, "pc_clients": 0}, "cust_6": {"customers": 6, "pc_clients": 1},
               "cust_8": {"customers": 8, "pc_clients": 2}, "off_1": {"officers": 1}, "off_2": {"officers": 2},
               "off_3": {"officers": 3}}
# Laser grids (laser_pattern slots): the grid plane at x 21 across VC; its local X runs along -z (yaw 90).
# lz_sweep (OF-P1 §7.1): 2 vertical beams half a cycle apart sweep the 3.3 m width and back every 7 s, so they cross the
# centre together every 3.5 s and the centre lane (0.8 m: capsule 0.35 + 0.05 each side, beams 0.03) is clear for
# 3.5 - 0.83 / 0.943 = 2.62 s (>= 2.0; a MEDIUM carrier needs 4 m / 2.63 m/s = 1.52 s). The 3-beam 8 s sweep left
# 0.33 s at the centre (6 passes per cycle). sweep_window_s() below is the same arithmetic as ENV P's lane read-out.
SWEEP_BEAMS = 2
SWEEP_PERIOD_S = 7.0
SWEEP_LANE_HALF_M = 0.4
SWEEP_BEAM_T_M = 0.03


def sweep_window_s(lx: float, beams: int = SWEEP_BEAMS, period: float = SWEEP_PERIOD_S, width: float = 3.3,
                   dt: float = 0.01) -> float:
    """Longest clear window (s) over two cycles for the lane centred at local x `lx` (LaserGrid.beam_offset)."""
    best = run = 0.0
    th = SWEEP_BEAM_T_M / 2
    for k in range(int(2 * period / dt)):
        t = k * dt
        clear = True
        for i in range(beams):
            u = (t / period + i / beams) % 1.0
            x = (1.0 - abs(2.0 * u - 1.0) - 0.5) * width
            if x + th >= lx - SWEEP_LANE_HALF_M and x - th <= lx + SWEEP_LANE_HALF_M:
                clear = False
        run = run + dt if clear else 0.0
        best = max(best, run)
    return best
LASERS = {
    "lz_static": {"pattern": "static", "z": [LASER_Z[0] + 0.15, LASER_GAP[0] - 0.15], "y": 1.0, "h": 1.8, "beams": 3,
                  "posts": [[LASER_Z[0], LASER_Z[0] + 0.15], [LASER_GAP[0] - 0.15, LASER_GAP[0]]],
                  "metas": {"crouch_under": True, "bypass": True}, "visual": "prop_laser_beams_h215x3"},
    "lz_sweep": {"pattern": "sweeping", "z": [LASER_Z[0] + 0.15, LASER_Z[1] - 0.15], "y": 0.0, "h": 2.6,
                 "sweep_beams": SWEEP_BEAMS, "period_s": SWEEP_PERIOD_S,
                 "posts": [[LASER_Z[0], LASER_Z[0] + 0.15], [LASER_Z[1] - 0.15, LASER_Z[1]]], "metas": {"bypass": False},
                 "visual": "prop_laser_beams_v260x2"},
    "lz_timed": {"pattern": "timed_off", "z": [LASER_Z[0] + 0.15, LASER_Z[1] - 0.15], "y": 0.0, "h": 2.6, "beams": 4,
                 "period_s": 20.0, "off_s": 6.0,
                 "posts": [[LASER_Z[0], LASER_Z[0] + 0.15], [LASER_Z[1] - 0.15, LASER_Z[1]]], "metas": {"bypass": False},
                 "visual": "prop_laser_beams_h330x4"},
}

# --- patrol graphs -------------------------------------------------------------------------------------------
# name -> [floor, x, z, pause (s, a b), pause anim, tags, facing yaw or None]
BANK: Dict[str, list] = {
    # ground: the hall (post_lobby), TW, BC, SR, LD, PC, LO, MO
    "HallLobby": ["G", 24.0, 30.0, [15, 30], "look", ["guard", "guard_ground"], 0.0],
    "HallSW": ["G", 12.0, 27.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallSE": ["G", 36.0, 27.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallNW": ["G", 12.5, 23.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallNE": ["G", 35.5, 23.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallWindowsW": ["G", 14.5, 34.5, [4, 8], "look", ["guard", "guard_ground"], 180.0],
    "HallWindowsE": ["G", 33.5, 34.5, [4, 8], "look", ["guard", "guard_ground"], 180.0],
    "HallVestibule": ["G", 24.0, 34.3, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallPW": ["G", 38.3, 30.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallGate": ["G", 24.0, 19.2, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallLO": ["G", 10.0, 19.2, [0, 0], "idle", ["guard", "guard_ground"], None],
    "HallPC": ["G", 38.0, 19.2, [0, 0], "idle", ["guard", "guard_ground"], None],
    "TWGate": ["G", 24.0, 12.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "TWWest": ["G", 12.0, 12.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "TWEast": ["G", 36.0, 12.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "LO": ["G", 5.0, 13.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "PC": ["G", 44.0, 11.5, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCWest": ["G", 12.0, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCStairA": ["G", 15.5, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCSecurity": ["G", 20.5, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCMid": ["G", 28.0, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCEastTW": ["G", 35.0, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCMail": ["G", 39.5, 8.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "BCFireExit": ["G", 46.0, 8.0, [6, 12], "look", ["guard", "guard_ground"], -90.0],
    "SRCoffee": ["G", 20.0, 4.8, [15, 25], "idle", ["guard", "guard_ground"], 90.0],
    "MO": ["G", 41.5, 5.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "LDCheck": ["G", 5.0, 3.0, [6, 10], "look", ["guard", "guard_ground"], 0.0],
    "LDInner": ["G", 7.5, 6.0, [0, 0], "idle", ["guard", "guard_ground"], None],
    "LDLift": ["G", 8.6, 2.6, [0, 0], "idle", ["guard", "guard_ground"], None],
    "StairAG": ["G", 14.75, 6.2, [0, 0], "idle", ["guard"], None],
    "StairBG": ["G", 46.75, 6.2, [0, 0], "idle", ["guard"], None],
    # basement (post_vault)
    "StairAB": ["B", 14.75, 6.2, [0, 0], "idle", ["guard"], None],
    "StairBB": ["B", 46.75, 6.2, [0, 0], "idle", ["guard"], None],
    "BBWest": ["B", 9.0, 8.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    "BBGate": ["B", 17.0, 8.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    "BBMid": ["B", 28.0, 8.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    "BBEast": ["B", 40.0, 8.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    "VCPost": ["B", 26.0, 11.0, [15, 30], "look", ["guard", "guard_basement"], 90.0],
    "VCGate": ["B", 17.0, 11.2, [0, 0], "idle", ["guard", "guard_basement"], None],
    "VCLaserW": ["B", 19.5, 10.4, [0, 0], "idle", ["guard", "guard_basement"], None],
    "VCDoor": ["B", 31.5, 11.0, [4, 8], "look", ["guard", "guard_basement"], 180.0],
    "VCBench": ["B", 23.5, 10.4, [0, 0], "idle", ["guard", "guard_basement"], None],
    "RCNorth": ["B", 6.5, 10.2, [0, 0], "idle", ["guard", "guard_basement"], None],
    "RCSouth": ["B", 6.5, 23.9, [0, 0], "idle", ["guard", "guard_basement"], None],
    "RCEast": ["B", 12.5, 17.0, [4, 8], "look", ["guard", "guard_basement"], 180.0],
    "SDDesk": ["B", 38.6, 11.6, [10, 20], "idle", ["guard", "guard_basement"], 0.0],
    "SDAisle": ["B", 40.0, 14.5, [0, 0], "idle", ["guard", "guard_basement"], None],
    "SDSouth": ["B", 40.0, 24.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    "CP": ["B", 21.0, 5.6, [0, 0], "idle", ["guard", "guard_basement"], None],
    "PL": ["B", 30.0, 5.0, [4, 8], "look", ["guard", "guard_basement"], 0.0],
    "SS": ["B", 42.5, 5.0, [0, 0], "idle", ["guard", "guard_basement"], None],
    # gallery level (rover_gallery)
    "StairAM": ["M", 14.75, 6.2, [0, 0], "idle", ["guard"], None],
    "StairBM": ["M", 46.75, 6.2, [0, 0], "idle", ["guard"], None],
    "UCWest": ["M", 4.0, 8.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "UCMid": ["M", 20.0, 8.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "UCEast": ["M", 38.0, 8.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "WLNorth": ["M", 7.0, 11.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "WLSouth": ["M", 7.0, 33.0, [4, 8], "look", ["guard", "guard_gallery"], 180.0],
    "GAWest": ["M", 10.0, 18.8, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "GAPost": ["M", 24.0, 18.8, [10, 20], "look", ["guard", "guard_gallery"], 180.0],
    "GAEast": ["M", 38.0, 18.8, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "ELNorth": ["M", 41.0, 11.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "ELSouth": ["M", 41.0, 33.0, [4, 8], "look", ["guard", "guard_gallery"], 180.0],
    "OF": ["M", 18.0, 15.0, [0, 0], "idle", ["guard", "guard_gallery"], None],
    "CF": ["M", 31.0, 15.5, [0, 0], "idle", ["guard", "guard_gallery"], None],
    # executive
    "StairAE": ["E", 14.75, 6.2, [0, 0], "idle", ["guard"], None],
    "StairBE": ["E", 46.75, 6.2, [0, 0], "idle", ["guard"], None],
    "XCWest": ["E", 6.0, 8.0, [0, 0], "idle", ["guard", "guard_exec"], None],
    "XCMid": ["E", 24.0, 8.0, [0, 0], "idle", ["guard", "guard_exec"], None],
    "XCEast": ["E", 40.0, 8.0, [0, 0], "idle", ["guard", "guard_exec"], None],
    "XCPresident": ["E", 28.0, 8.0, [4, 8], "look", ["guard", "guard_exec"], 0.0],
    "XLTerrace": ["E", 8.0, 15.5, [6, 12], "look", ["guard", "guard_exec"], 180.0],
    "XLBar": ["E", 10.0, 11.0, [0, 0], "idle", ["guard", "guard_exec"], None],
}
BANK_EDGES = [
    # hall loops (post_lobby (a)-(c))
    ["HallLobby", "HallSW"], ["HallLobby", "HallSE"], ["HallLobby", "HallVestibule"], ["HallVestibule", "HallWindowsW"],
    ["HallVestibule", "HallWindowsE"], ["HallWindowsW", "HallSW"], ["HallWindowsE", "HallSE"], ["HallSE", "HallPW"],
    ["HallPW", "HallLobby"], ["HallSW", "HallNW"], ["HallSE", "HallNE"], ["HallNW", "HallGate"], ["HallNE", "HallGate"],
    ["HallNW", "HallLO"], ["HallNE", "HallPC"], ["HallGate", "HallLobby"], ["HallLO", "HallGate"], ["HallPC", "HallGate"],
    ["HallGate", "TWGate"], ["TWGate", "TWWest"], ["TWGate", "TWEast"], ["TWWest", "LO"], ["LO", "HallLO"],
    ["TWEast", "PC"], ["PC", "HallPC"], ["TWWest", "BCWest"], ["TWEast", "BCEastTW"], ["PC", "BCMail"],
    # BC and back of house
    ["BCWest", "BCStairA"], ["BCStairA", "BCSecurity"], ["BCSecurity", "BCMid"], ["BCMid", "BCEastTW"],
    ["BCEastTW", "BCMail"], ["BCMail", "BCFireExit"], ["BCSecurity", "SRCoffee"], ["SRCoffee", "BCMid"],
    ["BCMail", "MO"], ["MO", "BCEastTW"], ["BCWest", "LDInner"], ["LDInner", "LDCheck"], ["LDCheck", "BCWest"], ["LDCheck", "LDLift"],
    ["LDLift", "LDInner"], ["LDLift", "BCWest"],
    ["BCStairA", "StairAG"], ["BCFireExit", "StairBG"], ["StairBG", "BCMail"], ["StairAG", "BCWest"],
    # stairs
    ["StairAG", "StairAB"], ["StairAG", "StairAM"], ["StairAM", "StairAE"],
    ["StairBG", "StairBB"], ["StairBG", "StairBM"], ["StairBM", "StairBE"],
    # basement
    ["StairAB", "BBWest"], ["StairAB", "BBGate"], ["BBWest", "BBGate"], ["BBGate", "BBMid"], ["BBMid", "BBEast"],
    ["BBEast", "StairBB"], ["BBGate", "VCGate"], ["VCGate", "VCLaserW"], ["VCLaserW", "VCBench"], ["VCBench", "VCPost"],
    ["VCPost", "VCDoor"], ["VCDoor", "VCBench"], ["VCPost", "VCLaserW"], ["VCGate", "VCBench"], ["BBWest", "RCNorth"],
    ["RCNorth", "RCSouth"], ["RCSouth", "RCEast"], ["RCEast", "RCNorth"], ["BBMid", "CP"], ["CP", "BBGate"],
    ["BBMid", "PL"], ["PL", "BBEast"], ["BBEast", "SDDesk"], ["SDDesk", "SDAisle"], ["SDAisle", "SDSouth"],
    ["SDSouth", "SDDesk"], ["SDDesk", "BBMid"], ["BBEast", "SS"], ["SS", "StairBB"], ["SDAisle", "BBEast"],
    # gallery
    ["StairAM", "UCWest"], ["StairAM", "UCMid"], ["UCWest", "UCMid"], ["UCMid", "UCEast"], ["UCEast", "StairBM"],
    ["UCWest", "WLNorth"], ["WLNorth", "WLSouth"], ["WLNorth", "GAWest"], ["GAWest", "GAPost"], ["GAPost", "GAEast"],
    ["GAEast", "ELNorth"], ["ELNorth", "ELSouth"], ["ELNorth", "UCEast"], ["UCMid", "OF"], ["OF", "GAPost"],
    ["GAEast", "CF"], ["CF", "UCEast"], ["GAWest", "OF"], ["WLSouth", "WLNorth"], ["ELSouth", "ELNorth"],
    # executive
    ["StairAE", "XCWest"], ["StairAE", "XCMid"], ["XCWest", "XCMid"], ["XCMid", "XCPresident"],
    ["XCPresident", "XCEast"], ["XCEast", "StairBE"], ["XCWest", "XLBar"], ["XLBar", "XLTerrace"],
    ["XLTerrace", "XCWest"], ["XLBar", "XCMid"],
]
LANE: Dict[str, list] = {
    "LaneApron": ["G", 9.5, -3.0, [0, 0], "idle", ["guard_dock"], None],
    "LaneWest": ["G", -13.0, -5.0, [6, 12], "look", ["guard_dock"], 90.0],
    "LaneFireEscape": ["G", -3.0, -4.5, [0, 0], "idle", ["guard_dock"], None],
    "LaneMid": ["G", 18.0, -6.5, [0, 0], "idle", ["guard_dock"], None],
    "LaneDumpsters": ["G", 27.5, -3.0, [0, 0], "idle", ["guard_dock"], None],
    "LaneCorner": ["G", 46.0, -5.0, [20, 40], "smoke", ["guard_dock"], -90.0],
    "TanneryNorth": ["G", 55.0, -2.0, [0, 0], "idle", ["guard_dock"], None],
    "TanneryBay": ["G", 55.0, 9.0, [6, 12], "look", ["guard_dock"], 90.0],
    "TannerySouth": ["G", 55.0, 22.0, [0, 0], "idle", ["guard_dock"], None],
}
LANE_EDGES = [["LaneApron", "LaneFireEscape"], ["LaneFireEscape", "LaneWest"], ["LaneWest", "LaneMid"],
              ["LaneMid", "LaneApron"], ["LaneApron", "LaneDumpsters"], ["LaneMid", "LaneDumpsters"],
              ["LaneDumpsters", "LaneCorner"], ["LaneCorner", "TanneryNorth"], ["TanneryNorth", "TanneryBay"],
              ["TanneryBay", "TannerySouth"], ["TannerySouth", "TanneryNorth"], ["LaneCorner", "TanneryBay"],
              ["LaneFireEscape", "LaneMid"]]
CIV: Dict[str, list] = {
    "CivQueueW": ["G", 15.0, 21.0, [10, 30], "queue", ["civilian"], 0.0],
    "CivQueueE": ["G", 33.0, 21.0, [10, 30], "queue", ["civilian"], 0.0],
    "CivCheckW": ["G", 14.0, 26.6, [10, 30], "browse", ["civilian"], 0.0],
    "CivCheckE": ["G", 34.0, 26.6, [10, 30], "browse", ["civilian"], 0.0],
    "CivBenchW": ["G", 16.0, 29.8, [10, 30], "browse", ["civilian"], 180.0],
    "CivBenchE": ["G", 32.0, 29.8, [10, 30], "browse", ["civilian"], 180.0],
    "CivMeridian": ["G", 22.5, 23.5, [5, 15], "browse", ["civilian"], None],
    "CivPW": ["G", 44.0, 30.2, [10, 20], "idle", ["civilian"], None],
    "CivAV": ["G", 4.5, 31.0, [5, 15], "browse", ["civilian"], -90.0],
    "CivVE": ["G", 26.5, 30.8, [5, 10], "browse", ["civilian"], None],
    "CowerCounterW": ["G", 12.0, COUNTER["body"][1] + 0.21, [0, 0], "cower_stand", ["cower"], 180.0],
    "CowerCounterE": ["G", 36.0, COUNTER["body"][1] + 0.21, [0, 0], "cower_stand", ["cower"], 180.0],
    "CowerWallW": ["G", 8.31, 30.5, [0, 0], "cower_stand", ["cower"], -90.0],
    "CowerWallE": ["G", 39.69, 31.0, [0, 0], "cower_stand", ["cower"], 90.0],
    "CowerPillar": ["G", 19.0, 20.46, [0, 0], "cower_stand", ["cower"], 180.0],   # back to the pillar (QC-67)
    "ExitPlaza": ["G", 24.0, 42.0, [0, 0], "idle", ["exit", "exit_guests"], 180.0],
    "PlazaW": ["G", 6.0, 44.0, [10, 20], "walk_text", ["civilian_plaza"], None],
    "PlazaE": ["G", 42.0, 44.0, [10, 20], "walk_text", ["civilian_plaza"], None],
    "PlazaTannery": ["G", 56.0, 33.0, [10, 20], "walk_text", ["civilian_plaza"], None],
}
CIV_EDGES = [["CivQueueW", "CivMeridian"], ["CivQueueE", "CivMeridian"], ["CivMeridian", "CivCheckW"],
             ["CivMeridian", "CivCheckE"], ["CivCheckW", "CivBenchW"], ["CivCheckE", "CivBenchE"],
             ["CivBenchW", "CivAV"], ["CivBenchE", "CivPW"], ["CivBenchW", "CivVE"], ["CivBenchE", "CivVE"],
             ["CivCheckW", "CivQueueW"], ["CivCheckE", "CivQueueE"], ["CowerCounterW", "CivQueueW"],
             ["CowerCounterE", "CivQueueE"], ["CowerWallW", "CivAV"], ["CowerWallW", "CivBenchW"],
             ["CowerWallE", "CivPW"], ["CowerWallE", "CivBenchE"], ["CowerPillar", "CivQueueW"],
             ["CivVE", "ExitPlaza"], ["ExitPlaza", "PlazaW"], ["ExitPlaza", "PlazaE"], ["PlazaE", "PlazaTannery"],
             ["PlazaW", "PlazaE"]]
STAFF: Dict[str, list] = {
    "TellerStationW": ["G", 16.0, TELLER_Z, [20, 40], "teller", ["staff", "staff_teller"], 180.0],
    "TellerStationE": ["G", 32.0, TELLER_Z, [20, 40], "teller", ["staff", "staff_teller"], 180.0],
    "TellerTW": ["G", 24.0, 11.0, [0, 0], "idle", ["staff"], None],
    "StaffBCWest": ["G", 14.0, 8.0, [0, 0], "idle", ["staff"], None],
    "StaffBCEast": ["G", 40.0, 8.0, [0, 0], "idle", ["staff"], None],
    "StaffStairAG": ["G", 14.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffStairBG": ["G", 46.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffWCW": ["G", 33.5, 3.5, [20, 40], "idle", ["staff", "staff_teller"], None],
    "StaffSmokeFireExit": ["G", 50.5, 6.0, [40, 70], "smoke", ["staff", "staff_smoke_fire"], 90.0],
    "ManagerDesk": ["G", 45.4, 25.6, [20, 40], "phone", ["staff", "staff_manager_floor"], 90.0],
    "ManagerHall": ["G", 26.0, 27.0, [10, 20], "idle", ["staff", "staff_manager_floor"], None],
    "ManagerTW": ["G", 28.0, 13.0, [10, 20], "idle", ["staff", "staff_manager_floor"], None],
    "ManagerPC": ["G", 46.0, 11.5, [10, 20], "idle", ["staff", "staff_manager_floor"], None],
    "StaffStairAM": ["M", 14.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffStairBM": ["M", 46.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffUCWest": ["M", 7.0, 8.0, [0, 0], "idle", ["staff"], None],
    "StaffUCEast": ["M", 41.0, 8.0, [0, 0], "idle", ["staff"], None],
    "StaffBRCoffee": ["M", 7.5, 5.5, [20, 40], "idle", ["staff", "staff_teller", "staff_gallery"], None],
    "StaffWCW2": ["M", 33.5, 3.5, [20, 40], "idle", ["staff", "staff_gallery"], None],
    "OfficerAO1": ["M", 4.0, 15.5, [0, 0], "idle", ["staff", "staff_gallery"], None],
    "OfficerOF": ["M", 14.0, 15.0, [0, 0], "idle", ["staff", "staff_gallery"], None],
    "ManagerVO": ["M", 45.5, 15.5, [20, 40], "phone", ["staff", "staff_manager_gallery"], None],
    "ManagerCF": ["M", 32.5, 14.7, [30, 60], "phone", ["staff", "staff_manager_gallery"], None],
    "ManagerOF": ["M", 20.0, 14.5, [10, 20], "idle", ["staff", "staff_manager_gallery"], None],
    "StaffStairAE": ["E", 14.25, 6.2, [0, 0], "idle", ["staff"], None],
    "ManagerPR": ["E", 30.0, 4.5, [30, 60], "phone", ["staff", "staff_manager_gallery"], None],
    "StaffStairAB": ["B", 14.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffStairBB": ["B", 46.25, 6.2, [0, 0], "idle", ["staff"], None],
    "StaffBBWest": ["B", 8.0, 8.0, [0, 0], "idle", ["staff"], None],
    "StaffBBEast": ["B", 40.0, 8.0, [0, 0], "idle", ["staff"], None],
    "ManagerSD": ["B", 37.0, 11.3, [30, 60], "phone", ["staff", "staff_manager_vault"], 0.0],
    "ManagerCP": ["B", 21.0, 5.0, [10, 20], "idle", ["staff", "staff_manager_vault"], None],
    "ManagerLKWC": ["B", 7.25, 2.2, [40, 70], "idle", ["staff", "staff_manager_vault"], None],
}
STAFF_EDGES = [["TellerStationW", "TellerTW"], ["TellerStationE", "TellerTW"], ["TellerTW", "StaffBCWest"],
               ["TellerTW", "StaffBCEast"], ["StaffBCWest", "StaffStairAG"], ["StaffBCEast", "StaffStairBG"],
               ["StaffBCEast", "StaffWCW"], ["StaffBCEast", "StaffSmokeFireExit"], ["StaffBCWest", "StaffBCEast"],
               ["ManagerDesk", "ManagerHall"], ["ManagerHall", "ManagerTW"], ["ManagerTW", "ManagerPC"],
               ["ManagerPC", "ManagerDesk"], ["ManagerTW", "TellerTW"], ["ManagerPC", "StaffBCEast"],
               ["StaffStairAG", "StaffStairAM"], ["StaffStairBG", "StaffStairBM"], ["StaffStairAM", "StaffStairAE"],
               ["StaffStairAG", "StaffStairAB"], ["StaffStairBG", "StaffStairBB"],
               ["StaffStairAM", "StaffUCWest"], ["StaffStairBM", "StaffUCEast"], ["StaffUCWest", "StaffBRCoffee"],
               ["StaffUCWest", "StaffUCEast"], ["StaffUCEast", "StaffWCW2"], ["StaffUCWest", "OfficerAO1"],
               ["StaffUCWest", "OfficerOF"], ["StaffUCEast", "ManagerVO"], ["ManagerVO", "ManagerCF"],
               ["ManagerCF", "ManagerOF"], ["ManagerOF", "StaffUCWest"], ["StaffStairAE", "ManagerPR"],
               ["StaffStairAB", "StaffBBWest"], ["StaffStairBB", "StaffBBEast"], ["StaffBBWest", "StaffBBEast"],
               ["StaffBBEast", "ManagerSD"], ["ManagerSD", "ManagerCP"], ["ManagerCP", "ManagerLKWC"],
               ["ManagerLKWC", "StaffBBWest"]]
# The bank's guard graph per level group (each its own PatrolGraph): one 73-point graph exhausts levelcheck's cycle
# budget (LcGeom.count_cycles_through, 200k DFS steps) before it finds the posts' loops; guards do not change level on
# patrol at G1 (the stair points stay as each graph's stair-door ends). [node name, graph_id, floor_index, floors].
BANK_PARTS = [["BankBasement", "bank_basement", 0, ("B",)], ["BankGround", "bank_ground", 1, ("G",)],
              ["BankUpper", "bank_upper", 2, ("M", "E")]]
GRAPHS: Dict[str, list] = {}
for _nm, _gid, _fi, _fl in BANK_PARTS:
    _pts = {k: v for k, v in BANK.items() if v[0] in _fl}
    GRAPHS[_nm] = [_gid, _fi, _pts, [e for e in BANK_EDGES if e[0] in _pts and e[1] in _pts]]
GRAPHS.update({"Lane": ["lane", 1, LANE, LANE_EDGES], "Civilians": ["civilians", 1, CIV, CIV_EDGES],
               "Staff": ["staff", 1, STAFF, STAFF_EDGES]})


def _bank_graph(f: str) -> str:
    return next(nm for nm, _g, _i, fl in BANK_PARTS if f in fl)


for _row in FIXED_SPAWNS + [it for _items in SLOT_CONTENT.values() for it in _items]:
    if _row[0] == "spawn" and _row[8] == "Bank":
        _row[8] = _bank_graph(_row[3])

# --- tactical points --------------------------------------------------------------------------------------------
TACTICAL: List[list] = [
    T("EntryBronzeDoors", "ENTRY", "G", [24.0, 0.0, 37.2], 0.0, ["door", "south", "breach_only"], True),
    T("EntryATMStreet", "ENTRY", "G", [4.0, 0.0, 37.2], 0.0, ["door", "south", "breach_only"], True),
] + [T("EntryHallWindow%d" % (i + 1), "ENTRY", "G", [x, 0.0, 37.3], 0.0, ["window", "south", "breach_only"], True)
     for i, x in enumerate([11.8, 16.2, 31.8, 36.2])] + [
    T("EntryDockRoller", "ENTRY", "G", [5.0, 0.0, -1.0], 180.0, ["roller", "north", "breach_only"], True),
    T("EntryDockPersonnel", "ENTRY", "G", [8.0, 0.0, -1.0], 180.0, ["door", "north", "breach_only"], True),
    T("EntryFireExit", "ENTRY", "G", [49.2, 0.0, 8.0], 90.0, ["door", "east", "breach_only"], True),
    T("EntryHeadHouse", "ENTRY", "R", [14.5, 0.0, 8.0], 0.0, ["door", "roof", "breach_only"], True),
    T("EntryTerraceDoorsW", "ENTRY", "E", [5.6, 0.0, 18.2], 0.0, ["door", "roof", "breach_only"], True),
    T("EntryTerraceDoorsE", "ENTRY", "E", [10.6, 0.0, 18.2], 0.0, ["door", "roof", "breach_only"], True),
    T("RappelLantern", "RAPPEL", "E", [13.3, 0.0, 26.0], -90.0, ["lantern", "roof", "breach_only"], True),
    T("EntryLantern", "ENTRY", "E", [13.3, 0.0, 26.0], -90.0, ["skylight", "roof", "breach_only"], True),
    T("RappelHole", "RAPPEL", "G", [24.0, 0.0, 13.3], 180.0, ["hole_rappel", "rappel_disabled", "breach_only"], False),
    T("RappelSetbackRoof", "RAPPEL", "R", [1.6, 0.0, 14.0], -90.0, ["setback", "roof", "one_way"], False),
    T("RappelSetbackTerrace", "RAPPEL", "E", [1.6, 0.0, 20.0], -90.0, ["setback", "roof", "one_way"], False),
    T("FlankAreaway", "FLANK", "G", [30.0, 0.0, -1.6], 180.0, ["areaway", "vent", "phantom"], False),
    T("FlankColonnade", "FLANK", "G", [1.0, -0.75, 39.0], 0.0, ["plaza", "south"], False),
    T("FlankTanneryBay", "FLANK", "G", [53.0, 0.0, 4.0], 90.0, ["tannery", "east"], False),
    T("AnchorPlazaSteps", "SHIELD_ANCHOR", "G", [24.0, -0.75, 41.0], 0.0, ["plaza"], False),
    T("AnchorMeridian", "SHIELD_ANCHOR", "G", [24.0, 0.0, 24.0], 0.0, ["hall"], False),
    T("AnchorLaneDock", "SHIELD_ANCHOR", "G", [12.0, 0.0, -4.0], 0.0, ["lane"], False),
    T("AnchorTanneryBay", "SHIELD_ANCHOR", "G", [55.0, 0.0, 8.0], 90.0, ["tannery"], False),
    T("AnchorTerraceWest", "SHIELD_ANCHOR", "E", [4.0, 0.0, 24.0], -90.0, ["terrace"], False),
    T("SniperAssay", "SNIPER_PERCH", "G", [24.0, 14.0, 63.4], 0.0, ["s1", "assay_office"], False),
    T("SniperGarage", "SNIPER_PERCH", "G", [40.0, 12.0, -11.0], 180.0, ["s2", "garage_deck"], False),
    T("SniperTower", "SNIPER_PERCH", "G", [-5.4, 20.0, 24.0], -90.0, ["s3", "tower_sniper"], False),
]


# OF-C3 levelcheck lines (doc §Budgets "Levelcheck configuration"): [name, metas, [[floor, x, z], ...]] -> a Node3D with
# Marker3D children at the crew's feet (LcLines). Bag lines must be camera-free per layout; hide spots hidden by LOS.
# vault_e2: C13 (BB E end, W along BB to x ~ 28, doc Sightlines) watches the BB leg in cam_a / cam_c, so the line is
# camera-free in cam_b only (doc claim "every layout": flagged for the lead). RC: observers from RC itself would see
# into the aisle (a line in an aisle is open along it), so hide_from is BB only (flagged).
LINES = [
    ["BagLineVaultSACQ", {"bag_line": "vault_sa_cq"},
     [["B", 24.0, 16.6], ["B", 30.0, 14.5], ["B", 30.0, 12.2], ["B", 21.0, 12.2], ["B", 17.0, 11.0], ["B", 17.0, 8.0],
      ["B", 14.5, 8.0], ["B", 12.0, 8.0], ["B", 12.0, 5.0]]],
    ["BagLineVaultE2", {"bag_line": "vault_e2", "bag_line_layouts": ["cam_b"]},
     [["B", 17.0, 8.0], ["B", 30.0, 8.0], ["B", 46.5, 8.0], ["B", 46.5, 6.3], ["G", 46.5, 6.3], ["G", 46.5, 8.0],
      ["G", 49.5, 8.0]]],
    ["BagLineVaultE3", {"bag_line": "vault_e3"},
     [["E", 14.5, 6.3], ["E", 14.5, 8.0], ["E", 6.0, 8.0], ["E", 6.0, 12.0], ["E", 5.6, 16.0], ["E", 5.6, 17.7],
      ["E", 20.0, 17.7], ["E", 40.0, 17.7], ["E", 44.0, 21.0], ["E", 42.5, 25.0]]],
    ["BagLineE1", {"bag_line": "vault_e1", "bag_line_layouts": ["cam_b", "cam_c"]},
     [["G", 9.0, 1.5], ["G", 8.0, 0.8], ["G", 8.0, -0.8], ["G", 6.5, -2.0]]],
    ["HideCounterW", {"hide_spot": True, "hide_from": ["BH"], "hide_posture": "crouch"},
     [["G", 9.5, HIDE_Z], ["G", 22.5, HIDE_Z]]],
    ["HideCounterE", {"hide_spot": True, "hide_from": ["BH"], "hide_posture": "crouch"},
     [["G", 25.5, HIDE_Z], ["G", 38.5, HIDE_Z]]],
    ["HideGallery", {"hide_spot": True, "hide_from": ["BH"], "hide_posture": "crouch"},
     [["M", 9.0, 18.6], ["M", 39.0, 18.6]]],
    ["HideRecordsAisle", {"hide_spot": True, "hide_from": ["BB"], "hide_posture": "crouch"},
     [["B", 0.95, 11.5], ["B", 0.95, 22.5]]],
]


def _covers() -> List[list]:
    c: List[list] = []
    add = lambda nm, f, x, z, yaw, tags: c.append(T(nm, "COVER", f, [x, -0.75 if tags[0] == "plaza" else 0.0, z], yaw,  # noqa: E731
                                                    tags))
    for i, x in enumerate([10.0, 14.0, 18.0, 30.0, 34.0, 38.0]):       # the counter front (hall side), H1
        add("CoverCounterHall%d" % (i + 1), "G", x, COUNTER["body"][1] + 0.45, 0.0, ["counter", "h1"])
    for i, x in enumerate([11.0, 20.0, 28.0, 37.0]):                   # behind the counter (TW side), H1
        add("CoverCounterTW%d" % (i + 1), "G", x, COUNTER["top"][0] - 0.5, 180.0, ["counter", "h1"])
    for i, x in enumerate(PILLARS):                                    # under the gallery
        add("CoverPillar%d" % (i + 1), "G", x, 20.7, 0.0, ["pillar", "h1"])
    for i, (x, z) in enumerate(CHECK_DESKS):
        add("CoverCheckDesk%d" % (i + 1), "G", x, z + 0.75, 0.0, ["check_desk", "h1"])
    for i, (x, z) in enumerate([[16.0, 30.4], [32.0, 30.4]]):
        add("CoverHallBench%d" % (i + 1), "G", x, z, 0.0, ["bench", "h1"])
    for i, (a, b, z) in enumerate(QUEUE_RAILS):
        add("CoverQueueRail%dW" % (i + 1), "G", a - 0.6, z, 90.0, ["queue_rail", "soft", "h1"])
    for i, x in enumerate([12.0, 21.0, 30.0, 40.0, 44.0]):              # BC door recesses, H5
        add("CoverBC%d" % (i + 1), "G", x, 8.0, 90.0, ["door_recess", "h5"])
    for i, (x, z) in enumerate([[2.4, 6.5], [7.0, 7.8], [4.0, 8.4]]):   # LD carts / bench, H3
        add("CoverLD%d" % (i + 1), "G", x, z, 0.0, ["carts", "h3"])
    for i, x in enumerate([9.0, 20.0, 33.0, 43.0]):                     # BB recesses, H2
        add("CoverBB%d" % (i + 1), "B", x, 8.0, 90.0, ["door_recess", "h2"])
    for i, (x, z) in enumerate([[24.5, 10.2], [27.5, 10.2], [32.5, 10.4]]):   # VC bench / TL, H2
        add("CoverVC%d" % (i + 1), "B", x, z, 0.0, ["bench", "h2"])
    for i, (x, z) in enumerate([[4.0, 39.6], [12.0, 39.6], [36.0, 39.6], [44.0, 39.6], [36.0, 41.6], [8.0, 45.6],
                                [40.0, 45.6], [-8.0, 41.0]]):
        add("CoverPlaza%d" % (i + 1), "G", x, z, 0.0, ["plaza", "planter"])
    for i, (x, z) in enumerate([[55.5, 23.3], [55.5, 28.7], [3.5, 31.0], [3.5, 27.0], [10.0, 33.0], [32.0, 33.0],
                                [44.0, 32.6], [13.4, 24.0], [13.4, 28.0], [30.6, 24.0], [30.6, 28.0]]):
        f = "G" if i < 2 else "E"
        tags = ["car", "h5"] if i < 2 else (["planter", "h4"] if i < 7 else ["lantern_curb", "h4"])
        add("CoverMisc%d" % (i + 1), f, x, z, 90.0 if i >= 7 else 0.0, tags)
    for i, (x, z) in enumerate([[2.0, 16.5], [6.0, 13.0], [12.5, 13.0]]):   # XL furniture, H4
        add("CoverXL%d" % (i + 1), "E", x, z, 0.0, ["furniture", "h4"])
    for i, (x, z) in enumerate([[10.0, 18.6], [38.0, 18.6], [18.0, 18.6], [30.0, 18.6]]):   # GA guard (high ground)
        add("CoverGA%d" % (i + 1), "M", x, z, 180.0, ["guard_rail", "ga"])
    for i, (x, z) in enumerate([[35.0, 13.8], [35.0, 18.8], [35.0, 23.4]]):   # SD box units, H2
        add("CoverSD%d" % (i + 1), "B", x, z, 90.0, ["box_unit", "h2"])
    for i, (x, z) in enumerate([[22.0, 16.0], [26.0, 16.0]]):                 # the lid's TW desks side, H1
        add("CoverTWMid%d" % (i + 1), "G", x, z, 180.0, ["counter", "h1"])
    return c


TACTICAL += _covers()


# --- check ------------------------------------------------------------------------------------------------------
def check(fail: Callable[[str], None], note: Callable[[str], None]) -> bool:
    import ostrander_federal_floors_ascii as PL
    import ostrander_federal_slots as SL
    ok = [True]

    def bad(msg: str) -> None:
        ok[0] = False
        fail(msg)

    print("Doors (lock table):")
    opens = {(o[0], "x" if o[3] == o[5] else "z", o[3] if o[3] == o[5] else o[2], o[2] if o[3] == o[5] else o[3]): o
             for o in PL.OPEN}
    n = 0
    for d in DOORS:
        if d[2] == "cage":
            n += 1
            continue
        key = (d[1], d[2], float(d[3]), float(d[4]))
        if key not in {(k[0], k[1], float(k[2]), float(k[3])) for k in opens}:
            bad("door %s: no plan opening %s" % (d[0], key))
        n += 1
    print("  %d doors (+ 2 cage gates); route doors >= 1.0 m: %d" % (n, len(ROUTE_DOORS)))
    print("Guard posts (D-140: 8 distinct posts, each its own spawn and route):")
    posts = [s[1] for s in FIXED_SPAWNS if s[2] == "GUARD" and "scripted" not in s[6]]
    for sid, items in SLOT_CONTENT.items():
        for it in items:
            if it[0] == "spawn" and it[2] == "GUARD" and sid not in ("vip_in",):
                posts.append(it[1])
    print("  %d posts: %s" % (len(posts), ", ".join(posts)))
    if len(set(posts)) < 8:
        bad("fewer than 8 distinct guard posts")
    print("Patrol graphs (>= 3 loops through each guard start on a graph serving >= 2 guards):")
    for gname, (gid, _fi, pts, edges) in GRAPHS.items():
        adj: Dict[str, List[str]] = {p: [] for p in pts}
        for a, b in edges:
            if a not in pts or b not in pts:
                bad("graph %s edge %s-%s names an unknown point" % (gname, a, b))
                continue
            adj[a].append(b)
            adj[b].append(a)
        seen = {next(iter(pts))}
        todo = list(seen)
        while todo:
            for nb in adj[todo.pop()]:
                if nb not in seen:
                    seen.add(nb)
                    todo.append(nb)
        if len(seen) != len(pts):
            bad("graph %s is not connected (%d / %d)" % (gname, len(seen), len(pts)))
        for pn, p in pts.items():
            if not SL.inside(p[0], _room_at(PL, p[0], p[1], p[2]), p[1], p[2]):
                bad("patrol point %s outside any room" % pn)
        starts = []
        names = list(pts)
        for s in FIXED_SPAWNS + [it for items in SLOT_CONTENT.values() for it in items if it[0] == "spawn"]:
            if s[2] == "GUARD" and s[8] == gname:
                sy = PL.FLOOR_HEIGHTS[s[3]] + s[4][1]
                best = min(names, key=lambda k: ((pts[k][1] - s[4][0]) ** 2 + (pts[k][2] - s[4][2]) ** 2
                                                 + (PL.FLOOR_HEIGHTS[pts[k][0]] - sy) ** 2, names.index(k)))
                starts.append((s[1], best))
        idx_adj = {names.index(k): sorted(names.index(n) for n in v) for k, v in adj.items()}
        for sname, st in starts:
            loops = SL.lc_cycles(idx_adj, names.index(st), 3)
            if len(starts) >= 2 and loops < 3:
                bad("guard %s start %s has %d loops in %s" % (sname, st, loops, gname))
        print("  %-12s %3d points, %3d edges, %d guard start(s) -> %s" % (gname, len(pts), len(edges), len(starts),
                                                                         "OK" if ok[0] else "see FAIL"))
    print("Content inside rooms:")
    items = [it for v in ALWAYS.values() for it in v] + FIXED_SPAWNS + [it for v in SLOT_CONTENT.values() for it in v]
    items += FURNITURE + TACTICAL + [it for v in ROUTE_ROWS.values() for it in v]
    cnt = 0
    for it in [it for it in items if it[0] != "route"] + [["stop", r[1] + "/" + st[0], st[1], st[2]]
                                                         for r in items if r[0] == "route" for st in r[6]]:
        f, pos = (it[3], it[4]) if it[0] in ("prefab", "spawn", "tac") else (it[2], it[3])
        if it[0] == "tac" and it[2] == "SNIPER_PERCH":
            continue
        if _room_at(PL, f, pos[0], pos[2]) is None:
            bad("%s %s at (%g, %g) on %s is in no room" % (it[0], it[1], pos[0], pos[2], f))
        cnt += 1
    print("  %d items placed" % cnt)
    covers = [t for t in TACTICAL if t[2] == "COVER"]
    body = sum(int(it[6].get("capacity", 1)) for it in ALWAYS["Gameplay/Containers"])
    custs = {sid: len([it for it in SLOT_CONTENT[sid] if it[0] == "spawn"]) for sid in ("cust_4", "cust_6", "cust_8")}
    print("  COVER %d (doc ~70); BODY_HIDE containers %d, capacity %d (doc: dumpsters 2 each, LK 2, J1, J2, PL);"
          " customers per slot %s + 2 plaza; code-PC desks 6" % (len(covers), len(ALWAYS["Gameplay/Containers"]), body,
                                                                custs))
    if len(covers) < 65:
        bad("COVER count")
    if custs != {"cust_4": 4, "cust_6": 6, "cust_8": 8}:
        bad("customer slots must hold 4 / 6 / 8")
    print("§7 numbers:")
    gap = LASER_GAP[1] - LASER_GAP[0]
    print("  7.1 laser bypass gap %.2f m (>= 1.0); lz_static low beam centre %.2f m" % (gap, LASERS["lz_static"]["y"] + 0.3))
    if gap < 1.0:
        bad("laser bypass gap")
    win = sweep_window_s(0.0)
    print("  7.1 lz_sweep %d beams, %.1f s: centre lane clear %.2f s (>= 2.0)" % (SWEEP_BEAMS, SWEEP_PERIOD_S, win))
    if win < 2.0:
        bad("lz_sweep centre window")
    print("  7.2 counter solid upstand %.2f m (crouch capsule 1.2); ledge %.2f, work top %.2f" %
          (COUNTER["upstand"][2], COUNTER["ledge"][2], COUNTER["top"][2]))
    if COUNTER["upstand"][2] < 1.25:
        bad("counter upstand")
    import ostrander_federal_geometry as GM
    tp = GM.THROW_PARAPET
    slope = math.degrees(math.atan2(tp["fall"], GM.EXT_T))
    print("  7.4 terrace east parapet (x %.0f): guard %.2f m (solid %.2f + mono coping %.2f m outward, %.1f deg)" %
          (tp["fixed"], tp["guard"], tp["guard"] - tp["fall"], tp["fall"], slope))
    if slope < 50.0 or tp["guard"] < 1.1 - 1e-6 or tp["guard"] >= 1.3:
        bad("throw parapet: guard >= 1.1 (fall safety, jump apex 1.08) and < 1.3 (the throw release height)")
    hole_w = HOLE[2] - HOLE[0]
    print("  7.7 hole %.1f x %.1f m, hoist car %.1f m in its south half, ladder landing %.2f m" %
          (hole_w, HOLE[3] - HOLE[1], HOIST_CAR[0], (HOLE[3] - HOIST_CAR[2]) - HOLE[1]))
    if hole_w < 1.2 or (HOLE[3] - HOIST_CAR[2]) - HOLE[1] < 1.0:
        bad("hole / hoist / ladder landing")
    sep = (HOIST_Z - HOIST_CAR[2] / 2) - (ROPE_Z + LADDER_BOTTOM_OFF)
    print("  7.7 rope ladder Bottom z %.2f, hoist car z %.3f-%.2f: %.2f m clear (>= 1.0)" %
          (ROPE_Z + LADDER_BOTTOM_OFF, HOIST_Z - HOIST_CAR[2] / 2, HOIST_Z + HOIST_CAR[2] / 2, sep))
    if sep < 1.0 - 1e-6 or HOIST_Z + HOIST_CAR[2] / 2 > HOLE[3] + 1e-6:
        bad("rope ladder landing vs the hoist car")
    for a, b, _z in QUEUE_RAILS:
        pass
    return ok[0]


def _room_at(PL, f: str, x: float, z: float):
    import ostrander_federal_slots as SL
    if f == "G":
        for rid, rects in SL.EXTERIOR.items():
            if any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in rects):
                return rid
    for rid, _p, r in PL.ROOMS[f]:
        if r[0] <= x <= r[2] and r[1] <= z <= r[3]:
            return rid
    if f == "B" and -1.0 < z < 0.0:
        return None
    return None
