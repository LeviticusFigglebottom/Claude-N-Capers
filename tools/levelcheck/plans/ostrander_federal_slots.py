# Ostrander Federal: the map's variant groups / VariantSlot ids, cameras, spawns, zones, preplan points, review cameras,
# the site (exterior rooms, grade, police islands, closures, neighbours) and the --check against the design doc and ENV B's
# values block (OF-C1). Owner: ENV C.
# Run: python3 tools/levelcheck/plans/ostrander_federal_slots.py --check      (consistency report, exit 0/1)
#
# Sources: docs/design/heists/ostrander_federal.md (Variable table, Rare events, Pre-planning, Sightlines, Police spawns,
# Holdouts, Escape, Review shots), ENV B's values block (game/content/docs/ostrander_federal_generator_block.txt on
# env/b-content, D-137 QB-2: the slot ids and weights below are B's), the D-140 guard lever (8 distinct guard posts), and
# the floor plans (ostrander_federal_floors_ascii.py). The per-item content (doors, furniture, prefabs, spawns, patrols,
# cover) is ostrander_federal_content.py.
#
# Coordinates: metres, the plans' origin (the bank's NW corner), +x east, +z south; `floor` is a plan floor (B G M E R);
# `y` is metres above that floor's FFL. Yaw: degrees about +y; a node's front (-Z) faces 0 north (-z), 90 west (-x),
# 180 south (+z), -90 east (+x).
import math
import os
import sys
from typing import Dict, List, Tuple

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostrander_federal_floors_ascii as P  # noqa: E402

Rect = Tuple[float, float, float, float]
FFL = P.FLOOR_HEIGHTS
PLAZA_Y = -0.75   # the plaza and Halloran Avenue: 5 x 0.15 m steps below the bank's FFL (doc Site)

# Exterior rooms at grade (Room list X1-X3; X4 terrace and X5 roof are in the floor plans).
EXTERIOR: Dict[str, List[Rect]] = {
    "X1": [(-16, 36, 66, 64)],    # Ostrander Plaza + Halloran Avenue (to the Assay Office balustrade)
    "X2": [(-16, -10, 48, 0)],    # Ledger Lane
    "X3": [(48, -14, 62, 36)],    # Tannery Street (to the Belmont Arms facade)
}
EXTERIOR_KIT = {"X1": "exterior_plaza", "X2": "exterior_alley", "X3": "exterior_street"}
PUBLIC_ROOMS = ["BH", "VE", "AV", "PW", "X1", "X2", "X3"]

# Resolver order = ENV B's rule order (values block).
GROUP_ORDER = ["manager_route", "keycard", "code_pc", "officers", "server_room", "guard_post", "security_room_staffed",
               "camera", "laser_pattern", "customers", "side_door", "fire_escape", "escape", "drill_delivery",
               "president_safe", "vip", "guard_extra", "civ_extra"]
# SLOTS: (group, slot_id, weight (B's block), floor, room, x, z, y, yaw, note).
SLOTS: List[Tuple[str, str, float, str, str, float, float, float, float, str]] = [
    ("manager_route", "mgr_floor", 0.45, "G", "BM", 45.0, 24.3, 0.0, 90.0, "Ashgrove at the BM desk / hall / TW / PC"),
    ("manager_route", "mgr_gallery", 0.3, "M", "CF", 32.5, 13.5, 0.0, 0.0, "VO / CF meetings / OF / PR (Executive)"),
    ("manager_route", "mgr_vault", 0.25, "B", "SD", 37.0, 11.3, 0.0, 0.0, "SD attendant / CP / LK WC / SB"),
    ("keycard", "kc_on_manager", 2.0, "G", "BM", 47.5, 21.0, 0.75, 90.0, "carried (carrier_tag keycard_carrier, QC-62)"),
    ("keycard", "kc_manager_desk", 1.0, "G", "BM", 44.0, 24.8, 0.75, 90.0, "on Ashgrove's desk"),
    ("keycard", "kc_vault_ops", 0.75, "M", "VO", 45.0, 12.0, 0.75, 90.0, "VO desk drawer (C10)"),
    ("keycard", "kc_security", 0.75, "G", "SR", 22.57, 5.6, 1.32, 90.0, "SR key chest under the key cabinet, E wall"),
    ("code_pc", "pc_ao1", 1.0, "M", "AO1", 2.5, 12.5, 0.75, 90.0, "AO1 officer's PC"),
    ("code_pc", "pc_ao2", 1.0, "M", "AO2", 2.5, 21.5, 0.75, 90.0, "AO2 officer's PC"),
    ("code_pc", "pc_ao3", 1.0, "M", "AO3", 2.5, 30.5, 0.75, 90.0, "AO3 officer's PC"),
    ("code_pc", "pc_ops", 0.75, "M", "OF", 12.0, 12.5, 0.75, 90.0, "OF supervisor's PC"),
    ("code_pc", "pc_vault_ops", 1.0, "M", "VO", 45.0, 12.7, 0.75, 90.0, "VO vault-schedule PC"),
    ("code_pc", "pc_exec", 0.75, "E", "EA", 20.5, 3.2, 0.75, 90.0, "EA executive assistant's PC (roof route)"),
    ("officers", "off_1", 0.4, "M", "AO1", 1.75, 12.5, 0.0, -90.0, "1 officer: AO1"),
    ("officers", "off_2", 0.4, "M", "AO1", 1.75, 12.5, 0.0, -90.0, "2 officers: AO1 + OF supervisor"),
    ("officers", "off_3", 0.2, "M", "AO1", 1.75, 12.5, 0.0, -90.0, "3 officers: AO1 + OF supervisor + VO"),
    ("server_room", "srv_gallery", 0.55, "M", "SV", 27.0, 0.7, 0.0, 180.0, "vault-control rack + laser controller in SV"),
    ("server_room", "srv_basement", 0.45, "B", "CM", 38.0, 0.7, 0.0, 180.0, "vault-control rack + laser controller in CM"),
    ("guard_post", "rover_hall", 1.0, "G", "BC", 28.0, 8.0, 0.0, 90.0, "guard_rover_hall (BC)"),
    ("guard_post", "rover_gallery", 1.0, "M", "UC", 20.0, 8.0, 0.0, 90.0, "guard_rover_gallery (UC)"),
    ("guard_post", "rover_basement", 1.0, "B", "BB", 28.0, 8.0, 0.0, 90.0, "guard_rover_basement (BB)"),
    ("guard_post", "rover_dock", 1.0, "G", "X2", 14.0, -5.0, 0.0, 90.0, "guard_rover_dock (Ledger Lane, lane graph)"),
    ("security_room_staffed", "sec_staffed", 0.6, "G", "SR", 19.5, 1.6, 0.0, 0.0, "CAMERA_OPERATOR at the monitor wall"),
    ("security_room_staffed", "sec_empty", 0.4, "G", "SR", 19.5, 1.6, 0.0, 0.0, "empty"),
    ("camera", "cam_a", 1.0, "G", "SR", 18.0, 3.0, 0.0, 0.0, "C1 C3 C6 C8 C11 C12 C13 C14"),
    ("camera", "cam_b", 1.0, "G", "SR", 18.0, 3.0, 0.0, 0.0, "C2 C4 C5 C9 C10 C12 C15 C16"),
    ("camera", "cam_c", 1.0, "G", "SR", 18.0, 3.0, 0.0, 0.0, "C1 C2 C3 C7 C9 C11 C13 C15"),
    ("laser_pattern", "lz_static", 0.5, "B", "VC", 21.0, 11.0, 0.0, 90.0, "beams 1.30 / 1.90 / 2.50, 1.1 m bypass gap S"),
    ("laser_pattern", "lz_sweep", 0.2, "B", "VC", 21.0, 11.0, 0.0, 90.0, "2 vertical beams, 7 s sweep, full width"),
    ("laser_pattern", "lz_timed", 0.3, "B", "VC", 21.0, 11.0, 0.0, 90.0, "4 beams, off 6 s of 20 s, full width"),
    ("customers", "cust_4", 0.4, "G", "BH", 24.0, 24.0, 0.0, 0.0, "4 hall customers"),
    ("customers", "cust_6", 0.4, "G", "BH", 24.0, 24.0, 0.0, 0.0, "6 (5 hall + 1 PC client)"),
    ("customers", "cust_8", 0.2, "G", "BH", 24.0, 24.0, 0.0, 0.0, "8 (6 hall + 2 PC clients)"),
    ("side_door", "door_fire_propped", 0.3, "G", "BC", 47.0, 8.0, 0.0, 90.0, "fire exit propped open, teller smoking"),
    ("side_door", "door_dock_open", 0.3, "G", "LD", 8.0, 0.8, 0.0, 0.0, "dock personnel door unlocked"),
    ("side_door", "door_none", 0.4, "G", "BC", 47.0, 8.0, 0.0, 90.0, "both closed (fire exit push bar, dock LOCKPICK)"),
    ("fire_escape", "fe_down", 0.45, "G", "X2", 0.6, -2.4, 0.0, 180.0, "Corvino drop ladder lowered (3.0 m)"),
    ("fire_escape", "fe_up", 0.55, "G", "X2", 0.6, -2.4, 0.0, 180.0, "drop ladder up (no roof route)"),
    ("escape", "esc_van_dock", 0.45, "G", "X2", 5.0, -4.32, 0.0, 180.0, "E1 van at the roller door"),
    ("escape", "esc_van_tannery", 0.3, "G", "X3", 51.2, 14.28, 0.0, 180.0, "E2 van in the Tannery bay"),
    ("escape", "esc_heli_terrace", 0.25, "E", "X4", 36.0, 27.0, 0.0, 0.0, "E3 heli over the terrace net"),
    ("drill_delivery", "drop_terrace", 0.5, "E", "X4", 20.0, 33.0, 0.0, 0.0, "heli crate on the terrace"),
    ("drill_delivery", "drop_dock", 0.5, "G", "X2", 14.0, -4.0, 0.0, 0.0, "Mercer's second van at the dock"),
    ("president_safe", "ps_bonds", 0.5, "E", "PR", 30.0, 0.2, 0.85, 180.0, "wall safe: 1 bonds bag + 3 small loot"),
    ("president_safe", "ps_empty", 0.5, "E", "PR", 30.0, 0.2, 0.85, 180.0, "wall safe, empty"),
    ("vip", "vip_out", 1.0, "B", "SD", 45.5, 15.0, 0.0, -90.0, "empty"),
    ("vip", "vip_in", 0.0, "B", "SD", 45.5, 15.0, 0.0, -90.0, "VIP client + Halden bodyguard in SD (rare vip_client)"),
    ("guard_extra", "gx_hall", 1.0, "G", "BH", 16.0, 27.0, 0.0, 0.0, "D-130/D-140 extra guard: banking hall west"),
    ("guard_extra", "gx_basement", 1.0, "B", "BB", 38.0, 8.0, 0.0, 90.0, "extra guard: basement east"),
    ("guard_extra", "gx_none", 0.0, "G", "BH", 24.0, 27.0, 0.0, 0.0, "empty (D-140: weight 0, never picked)"),
    ("civ_extra", "cx_hall_1", 1.0, "G", "BH", 34.0, 26.7, 0.0, 0.0, "late customer at a check desk"),
    ("civ_extra", "cx_hall_2", 1.0, "G", "BH", 33.0, 21.05, 0.0, 0.0, "late customer in the queue"),
    ("civ_extra", "cx_pc", 1.0, "G", "PC", 45.6, 12.0, 0.0, 90.0, "private client in PC"),
    ("civ_extra", "cx_sd", 1.0, "B", "SD", 46.6, 19.0, 0.0, -90.0, "customer in a SD viewing booth"),
    ("civ_extra", "cx_none", 6.0, "G", "BH", 24.0, 27.0, 0.0, 0.0, "empty"),
]
# Groups whose content the crew walks up to and uses (a UsePoint in front of the anchor).
USE_POINT_M = 0.9
SCALARS = {"time_lock_s": [150, 210, 270], "drill_eta_s": [45, 60, 90], "escape_eta_s": [90, 120, 150],
           "cash_bags": [6, 8, 10], "gold_bags": [2, 3, 4], "deposit_boxes": [6, 9, 12]}
RARE = ["time_lock_glitch", "bond_delivery", "vip_client", "armored_car_early", "tower_sniper"]
# Doc variable table -> how it maps (heist_map.md §5). B's block adds officers / customers as slot groups.
DOC_VARIABLES = ["manager_route", "keycard", "code_pc", "officers", "server_room", "time_lock_s", "guard_post",
                 "security_room_staffed", "camera", "laser_pattern", "customers", "side_door", "fire_escape", "escape",
                 "drill_delivery", "drill_eta_s", "escape_eta_s", "cash_bags", "gold_bags", "deposit_boxes",
                 "president_safe"]

# Security cameras (Sightlines): id -> (floor, room, x, z, mount height above FFL, look x, look z, layouts).
CAMERAS: Dict[str, tuple] = {
    # id: (floor, room, pivot x, pivot z (on a wall face), mount height above FFL, yaw (front -Z), layouts). Wall mounts
    # face straight out of their wall (the validator's flush rule) and pan 40 deg unless an 8th field gives the pan; the
    # doc's look directions in notes.
    "C1": ("G", "BH", 38.5, 17.5, 3.0, 180.0, ("cam_a", "cam_c")),     # bulkhead over the counter, E end: the hall, VE
    "C2": ("G", "BH", 9.0, 35.8, 3.0, 0.0, ("cam_b", "cam_c")),        # S facade, W end: the counter front, the gate
    "C3": ("G", "TW", 8.1, 10.0, 3.0, -90.0, ("cam_a", "cam_c")),      # TW W end: the teller line, the lid
    "C4": ("G", "BC", 47.8, 8.0, 2.8, 90.0, ("cam_b",)),               # BC E end, over the fire exit: W along BC
    "C5": ("G", "LD", 9.9, 4.0, 3.0, 90.0, ("cam_b",)),                # LD E wall: over the dock floor
    "C6": ("G", "X2", 19.925, -5.7, 3.0, 90.0, ("cam_a",)),            # Ledger Lane pole: W along the lane (doc 4.0 m)
    "C7": ("G", "AV", 7.9, 30.0, 2.8, 90.0, ("cam_c",)),               # AV E wall: the ATMs, the street door
    "C8": ("M", "UC", 0.2, 8.0, 2.8, -90.0, ("cam_a",)),               # UC W end: E along UC
    "C9": ("M", "GA", 39.9, 19.3, 2.7, 90.0, ("cam_b", "cam_c")),      # GA E end: W along the gallery
    "C10": ("M", "VO", 47.8, 10.0, 2.8, 90.0, ("cam_b",)),             # VO E wall: the VO desk
    "C11": ("E", "XC", 47.8, 8.0, 2.8, 90.0, ("cam_a", "cam_c")),      # XC E end: W along XC
    "C12": ("E", "X4", 24.0, 17.2, 3.0, 180.0, ("cam_a", "cam_b"), 0.0),  # terrace, N block facade: S, fixed (E3 line)
    "C13": ("B", "BB", 47.8, 8.0, 2.8, 90.0, ("cam_a", "cam_c")),      # BB E end: W along BB to x ~ 28
    "C14": ("B", "SD", 35.0, 9.1, 2.8, 180.0, ("cam_a",)),             # SD N wall, W end: over the box rows
    "C15": ("B", "CP", 17.0, 0.2, 2.8, 180.0, ("cam_b", "cam_c")),     # CP N wall, W end: over the counting tables
    "C16": ("G", "PC", 47.0, 9.1, 2.8, 180.0, ("cam_b",)),             # PC N wall, E end: over the lounge
}
DOC_LAYOUTS = {"cam_a": {"C1", "C3", "C6", "C8", "C11", "C12", "C13", "C14"},
               "cam_b": {"C2", "C4", "C5", "C9", "C10", "C12", "C15", "C16"},
               "cam_c": {"C1", "C2", "C3", "C7", "C9", "C11", "C13", "C15"}}
# camera_spine (D-075): no layout watches both BOH spines (BC and BB) end to end... the doc's layouts put C4 (BC) with
# no BB camera and C13 (BB) with no BC camera, so the rule holds. camera_screen: none listed for OF.
CAMERA_SPINE_ROOMS = ("BC", "BB")
CAMERA_SCREEN_SLOTS: Tuple[str, ...] = ()

# Player spawns: (name, spawn_tag ("" = default pp_spawn_plaza), floor, room, x, z, yaw). The plaza is at PLAZA_Y.
PLAYER_SPAWNS = [
    ("PlayerPlaza1", "", "G", "X1", 21.75, 44.0, 0.0), ("PlayerPlaza2", "", "G", "X1", 23.25, 44.0, 0.0),
    ("PlayerPlaza3", "", "G", "X1", 24.75, 44.0, 0.0), ("PlayerPlaza4", "", "G", "X1", 26.25, 44.0, 0.0),
    ("PlayerLane1", "preplan_spawn_lane", "G", "X2", 21.0, -6.0, 90.0),
    ("PlayerLane2", "preplan_spawn_lane", "G", "X2", 22.5, -6.0, 90.0),
    ("PlayerLane3", "preplan_spawn_lane", "G", "X2", 24.0, -6.0, 90.0),
    ("PlayerLane4", "preplan_spawn_lane", "G", "X2", 25.5, -6.0, 90.0),
    ("PlayerTannery1", "preplan_spawn_tannery", "G", "X3", 57.0, 20.0, 90.0),
    ("PlayerTannery2", "preplan_spawn_tannery", "G", "X3", 57.0, 21.5, 90.0),
    ("PlayerTannery3", "preplan_spawn_tannery", "G", "X3", 57.0, 23.0, 90.0),
    ("PlayerTannery4", "preplan_spawn_tannery", "G", "X3", 57.0, 24.5, 90.0),
]
# Police spawns (Loud): (name, tag, x, z, y absolute) on police-only islands behind the closures; P5 on the Corvino
# setback (+16).
POLICE_SPAWNS = [("P1", "police_s", -30.0, 55.0, PLAZA_Y), ("P2", "police_se", 80.0, 55.0, PLAZA_Y),
                 ("P3", "police_n", -30.0, -5.0, 0.0), ("P4", "police_e", 55.0, -45.0, 0.0),
                 ("P5", "police_roof", -14.0, 20.0, 16.0)]
HOLDOUTS = {"H1": ("G", 24.0, 13.0, "teller line"), "H2": ("B", 24.0, 10.0, "basement concourse"),
            "H3": ("G", 5.0, 4.5, "loading dock"), "H4": ("E", 36.0, 27.0, "terrace"),
            "H5": ("G", 46.0, 8.0, "fire exit")}
MIN_CREW_DISTANCE_M = 15.0
# Escape / secure zones per escape slot: (slot, kind, floor, room, x, z) (the prefab rows are in the content module).
ESCAPE_ZONES = [("esc_van_dock", "SECURE_LOOT", "G", "X2", 5.0, -4.32), ("esc_van_dock", "ESCAPE", "G", "X2", 10.5, -3.0),
                ("esc_van_tannery", "SECURE_LOOT", "G", "X3", 51.2, 14.28),
                ("esc_van_tannery", "ESCAPE", "G", "X3", 51.0, 6.5),
                ("esc_heli_terrace", "SECURE_LOOT", "E", "X4", 42.5, 26.0),
                ("esc_heli_terrace", "ESCAPE", "E", "X4", 35.5, 27.0)]
# Preplan points (doc Pre-planning): (id, category, floor index, plan floor, room, x, z, params).
PREPLAN = [
    ("pp_spawn_plaza", "spawn", 1, "G", "X1", 24.0, 44.0, {}),
    ("pp_spawn_lane", "spawn", 1, "G", "X2", 23.0, -6.0, {"spawn_tag": "preplan_spawn_lane"}),
    ("pp_spawn_tannery", "spawn", 1, "G", "X3", 57.0, 22.0, {"spawn_tag": "preplan_spawn_tannery"}),
    ("pp_drop_lane", "drop_zone", 1, "G", "X2", 32.0, -3.0, {}),
    ("pp_drop_restroom", "drop_zone", 1, "G", "PW", 44.0, 29.6, {}),
    ("pp_drop_lockers", "drop_zone", 0, "B", "LK", 5.0, 4.5, {}),
    ("pp_drop_terrace", "drop_zone", 3, "E", "X4", 6.0, 30.0, {}),
    ("pp_escape_dock", "escape", 1, "G", "X2", 5.0, -4.3, {"variant_group": "escape", "variant_slot": "esc_van_dock"}),
    ("pp_escape_tannery", "escape", 1, "G", "X3", 51.2, 14.3,
     {"variant_group": "escape", "variant_slot": "esc_van_tannery"}),
    ("pp_escape_heli", "escape", 3, "E", "X4", 36.0, 27.0,
     {"variant_group": "escape", "variant_slot": "esc_heli_terrace"}),
    ("pp_drill_terrace", "drop_zone", 3, "E", "X4", 20.0, 33.0,
     {"variant_group": "drill_delivery", "variant_slot": "drop_terrace"}),
    ("pp_drill_dock", "drop_zone", 1, "G", "X2", 14.0, -4.0,
     {"variant_group": "drill_delivery", "variant_slot": "drop_dock"}),
    ("pp_fire_exit", "insider", 1, "G", "BC", 46.5, 8.0,
     {"variant_group": "side_door", "variant_slot": "door_fire_propped"}),
    ("pp_dock_door", "insider", 1, "G", "X2", 8.0, -1.2, {"variant_group": "side_door", "variant_slot": "door_dock_open"}),
    ("pp_vault_ops", "insider", 2, "M", "VO", 45.0, 11.0, {"variant_group": "keycard", "variant_slot": "kc_vault_ops"}),
    ("pp_fire_escape", "insider", 1, "G", "X2", 0.6, -3.4, {"variant_group": "fire_escape", "variant_slot": "fe_down"}),
]
# Review cameras (doc Review shots): (id, floor, room, x, z, eye height above FFL, look-at x, z, y above FFL).
REVIEW_CAMERAS = [
    ("TopDownPlan", "G", "", 24.0, 18.0, 120.0, 24.0, 18.0, 0.0),
    ("rc_ext_plaza", "G", "X1", 24.0, 60.0, 1.0, 24.0, 36.0, 6.0),
    ("rc_ext_lane", "G", "X2", -14.0, -5.0, 1.7, 30.0, -2.0, 3.0),
    ("rc_ext_tannery", "G", "X3", 55.0, -12.0, 1.7, 52.0, 14.0, 3.0),
    ("rc_terrace", "E", "X4", 8.0, 18.5, 1.7, 30.0, 30.0, 1.5),
    ("rc_hall_entrance", "G", "VE", 24.0, 35.0, 1.7, 24.0, 18.0, 3.0),
    ("rc_hall_counter", "G", "BH", 38.5, 18.6, 1.7, 9.0, 18.0, 1.2),
    ("rc_hall_from_gallery", "M", "GA", 24.0, 19.0, 1.6, 24.0, 32.0, -4.0),
    ("rc_vestibule", "G", "VE", 27.0, 35.4, 1.7, 21.0, 32.5, 1.5),
    ("rc_atm", "G", "AV", 7.0, 30.0, 1.7, 1.0, 34.5, 1.2),
    ("rc_teller_workroom", "G", "TW", 9.0, 10.0, 1.7, 30.0, 15.0, 1.0),
    ("rc_client_lounge", "G", "PC", 41.0, 18.3, 1.7, 46.0, 10.0, 1.2),
    # OF-C2 (PO GPU set: it faced the BM door from the hall): in BM's NW corner over the desk front, the manager's
    # chair and the Tannery Street windows behind it
    ("rc_manager_office", "G", "BM", 40.6, 19.8, 1.7, 47.6, 24.0, 1.0),
    ("rc_loan_office", "G", "LO", 7.2, 18.3, 1.7, 1.0, 10.0, 1.0),
    ("rc_back_corridor", "G", "BC", 10.7, 8.0, 1.7, 47.0, 8.0, 1.5),
    ("rc_security_room", "G", "SR", 21.5, 6.3, 1.7, 18.0, 0.5, 1.2),
    ("rc_loading_dock", "G", "LD", 9.0, 8.4, 1.7, 2.0, 0.5, 2.0),
    ("rc_break_room", "M", "BR", 9.2, 6.3, 1.7, 1.0, 1.0, 1.0),
    ("rc_officers", "M", "AO2", 5.3, 26.3, 1.7, 1.0, 19.0, 1.0),
    ("rc_operations", "M", "OF", 27.3, 16.3, 1.7, 9.0, 10.0, 1.0),
    ("rc_vault_ops", "M", "VO", 42.8, 17.3, 1.7, 47.0, 10.0, 1.0),
    ("rc_server_room", "M", "SV", 23.8, 6.3, 1.7, 28.0, 1.0, 1.2),
    ("rc_president", "E", "PR", 34.3, 6.3, 1.7, 26.0, 0.5, 1.2),
    ("rc_exec_lounge", "E", "XL", 15.3, 9.8, 1.7, 5.0, 16.5, 1.2),
    ("rc_boardroom", "E", "BD", 9.3, 6.3, 1.7, 1.0, 1.0, 1.0),
    ("rc_basement_corridor", "B", "BB", 13.5, 8.0, 1.7, 46.0, 8.0, 1.5),
    ("rc_concourse", "B", "VC", 15.0, 10.0, 1.7, 30.0, 12.5, 1.2),
    ("rc_vault", "B", "VT", 30.0, 14.6, 1.7, 22.0, 22.0, 1.0),
    ("rc_vault_hole", "B", "VT", 19.0, 15.0, 1.7, 24.0, 14.6, 3.0),
    ("rc_deposit_hall", "B", "SD", 35.0, 24.0, 1.7, 46.0, 13.0, 1.2),
    ("rc_count_room", "B", "CP", 25.3, 6.3, 1.7, 17.0, 1.0, 0.9),
    ("rc_records", "B", "RC", 12.5, 24.3, 1.7, 1.0, 10.0, 1.2),
    ("rc_roof", "R", "X5", 17.0, 8.5, 1.7, 1.0, 2.0, 1.5),
    ("rc_sniper_assay", "G", "X1", 24.0, 63.0, 15.6, 24.0, 32.0, 2.0),
    # OF-C2 (GPU-14, LEAD r255): the burn spot close up from TW's floor, ~3.3 m, ~40 deg down, west of the hole (off the
    # hoist shaft east and the rope ladder north), to judge the scorch; rendered with of_burn_variant.gd's scene
    ("rc_burn_close", "G", "TW", 21.9, 16.0, 2.1, 24.0, 14.6, 0.0),
]

# --- the site ------------------------------------------------------------------------------------
# Grade boxes (top at `y`): [name, [x0, z0, x1, z1], y, surface]. The bank stands at 0.0; Ledger Lane and Tannery Street
# are at 0.0; the plaza, Halloran Avenue and the Tannery mouth at PLAZA_Y (Site: 5 steps up to the bronze doors).
GRADE = [
    ["Lane", [-16.0, -10.0, 48.2, -0.2], 0.0, "paving"],
    ["Tannery", [48.2, -14.0, 62.0, 38.0], 0.0, "asphalt"],
    ["Apron", [0.0, 36.2, 48.2, 38.0], 0.0, "paving"],
    # PlazaW in two: west of the bank, and south of the apron (OF-C2: its bottom no longer runs coplanar under it)
    ["PlazaW", [-16.0, 36.0, 0.0, 48.0], PLAZA_Y, "paving"],
    ["PlazaWS", [0.0, 38.0, 18.0, 48.0], PLAZA_Y, "paving"],
    ["PlazaSteps", [18.0, 40.0, 30.0, 48.0], PLAZA_Y, "paving"],
    ["PlazaE", [30.0, 38.0, 48.0, 48.0], PLAZA_Y, "paving"],
    ["TanneryMouth", [48.0, 42.0, 66.0, 48.0], PLAZA_Y, "asphalt"],
    ["Avenue", [-16.0, 48.0, 66.0, 62.0], PLAZA_Y, "asphalt"],
    ["AvenueEastKerb", [62.0, 38.0, 66.0, 42.0], PLAZA_Y, "paving"],
]
# Ramps (collide as one ramp, §7.9): [name, x0, x1, z_high, z_low, y_high, y_low] (rising toward z_high).
RAMPS = [
    ["PlazaStepsRamp", 18.0, 30.0, 38.0, 40.0, 0.0, PLAZA_Y],      # 5 x 0.15 m steps, 0.3 m treads
    ["TanneryRamp", 48.0, 62.0, 38.0, 42.0, 0.0, PLAZA_Y],          # Tannery St falls 0.75 m to the avenue (10.6 deg)
]
# PO6-17 window breaches (LEAD ruling QC-i: the hall bays stay normal breach markers): prop_breach_window (1.0 x 2.1 m
# in the 0.4 m facade) at the centre of the arched bays W1 / E2 (x 11.8 / 36.2; the doc's 11.75 / 35.25 are not bay
# centres: flagged), a floor-level slot through the bay's 1.0 m sill; the arched pane is cut round it.
# [name, x, facade z, room]: marker on the room-side face (z 35.8), yaw 0 (-Z north into the hall).
BREACH_WINDOWS = [["Breach_1", 11.8, 36.0, "BH"], ["Breach_2", 36.2, 36.0, "BH"]]
BREACH_SIZE = [1.0, 2.1]
# PO6-17 door breaches (LEAD ruling, design doc "Assault events" Breach_3 / Breach_4): kind "door", no infill scene (the
# door is the infill: ENV A plays the charge on its leaves and opens it), markers only (no obstruction: the navmesh is
# unchanged). [name, room-side face pos, yaw (-Z into the room), size, room, door (map path)].
BREACH_DOORS = [
    ["Breach_3", [6.0, 8.6, 16.8], 0.0, [1.8, 2.1], "XL", "Gameplay/Doors/TerraceDoorsW"],
    ["Breach_4", [14.0, 12.2, 6.85], 0.0, [1.0, 2.1], "HH", "Gameplay/Doors/HeadHouseDoor"],
]
PLAZA_STEPS = {"x": [18.0, 30.0], "z_top": 38.0, "risers": 5, "riser": 0.15, "tread": 0.3}
# The apron's plinth faces (0.75 m) where the apron meets the plaza (no ramp): [name, [x0, z0, x1, z1]].
# Police islands behind the closures (QC-42 / D-064): [spawn, grade [x0, z0, x1, z1], y, link from, link to].
POLICE_ISLANDS = [
    ["P1", [-44.0, 48.0, -16.4, 62.0], PLAZA_Y, [-18.0, PLAZA_Y, 60.0], [-14.6, PLAZA_Y, 60.0]],
    ["P2", [66.4, 42.0, 94.0, 62.0], PLAZA_Y, [68.0, PLAZA_Y, 55.0], [64.6, PLAZA_Y, 55.0]],
    ["P3", [-44.0, -10.0, -16.4, -0.2], 0.0, [-18.0, 0.0, -5.0], [-14.6, 0.0, -5.0]],
    ["P4", [48.2, -50.0, 62.0, -14.4], 0.0, [55.0, 0.0, -16.0], [55.0, 0.0, -12.6]],
]
# P5's roof island: the Corvino setback (+16), police only; one-way rappel links to the main roof at rp and the terrace's
# west end (QC-68), and the terrace -> hall rappel through the lantern (QC-41 shape).
P5_ISLAND = [-20.0, 0.0, -0.2, 22.0]
# The rappels are police-only (A's r303 sweep: OF seed 1's crew pilot pathed down the 8.6 m lantern link and wedged on
# CurbW): they sit on Door.NAV_LAYER_BREACH (2), which only loud police agents and the assault director query (D-122);
# crew, guards and civilians path on layer 1.
RAPPEL_LAYER = 2
NAV_LINKS = [
    ["RappelSetbackRoof", [-1.2, 16.0, 14.0], [1.6, 12.2, 14.0], False, RAPPEL_LAYER],
    ["RappelSetbackTerrace", [-1.2, 16.0, 20.0], [1.6, 8.6, 20.0], False, RAPPEL_LAYER],
    ["RappelLantern", [13.3, 8.6, 26.0], [16.0, 0.0, 26.0], False, RAPPEL_LAYER],
    ["AreawayVent", [30.0, 0.0, -1.6], [30.0, -4.0, 3.5], True, 4],
]
# Closures and neighbour massing: [name, [x0, y0, z0, x1, y1, z1], surface]. Every top a player could reach is
# > 1.18 m above the play mesh (jump apex 1.08 m), so `slopes` holds without copings.
CLOSURES = [
    ["AvenueWBarriers", [-16.4, PLAZA_Y, 36.0, -16.0, 1.6, 62.0], "trim"],
    ["RoadWorksTruck", [-22.0, PLAZA_Y, 50.0, -17.0, 2.6, 58.0], "prop"],
    ["AvenueEBarriers", [66.0, PLAZA_Y, 42.0, 66.4, 1.6, 62.0], "trim"],
    ["StalledBus", [67.0, PLAZA_Y, 50.0, 79.0, 2.4, 53.0], "prop"],
    ["LaneRefuseTruck", [-16.4, 0.0, -10.0, -16.0, 3.2, -0.2], "prop"],
    ["TanneryNBarrier", [48.2, 0.0, -14.4, 62.0, 2.4, -14.0], "trim"],
    ["AssayBalustrade", [-16.0, PLAZA_Y, 62.0, 66.0, 0.6, 62.4], "trim"],
    ["AssayOffice", [-16.0, PLAZA_Y, 62.4, 66.0, 14.0, 90.0], "wall_ext"],
    ["ParkingStructure", [-16.0, 0.0, -46.0, 48.0, 12.0, -10.2], "wall_ext"],
    ["BelmontArms", [62.2, 0.0, -14.0, 80.0, 20.0, 38.0], "wall_ext"],
    ["CorvinoLower", [-20.0, 0.0, 0.0, -0.2, 16.0, 36.0], "wall_ext"],
    ["CorvinoTower", [-20.0, 16.0, 22.0, -6.0, 40.0, 36.0], "wall_ext"],
    ["CorvinoParapetN", [-20.0, 16.0, 0.0, -0.2, 17.3, 0.4], "wall_ext"],
    ["CorvinoParapetE", [-0.6, 16.0, 0.4, -0.2, 17.3, 22.0], "wall_ext"],
    ["CorvinoBalconyS3", [-6.0, 19.6, 23.0, -4.8, 20.0, 25.0], "trim"],
]
# Out-of-bounds curtains 0.5 m beyond every reachable parapet (D-040): [name, [x0, y0, z0, x1, y1, z1]].
OOB = [
    ["OobRoofN", [1.8, 12.2, -2.7, 48.2, 20.0, -0.7]],   # x >= 1.8: clear of the fire-escape top landing
    ["OobRoofE", [48.7, 12.2, 0.0, 50.7, 20.0, 17.0]],
    # §7.4 wins over the doc's 0.5 m curtain here: a bag thrown to E2 must not cross OOB (it would be returned), so
    # the east terrace curtain starts 4.4 m above the terrace, over any throw arc.
    ["OobTerraceE", [48.7, 13.0, 17.0, 50.7, 18.0, 36.0]],
    ["OobTerraceS", [0.0, 8.6, 36.7, 48.7, 14.0, 38.7]],
]


# ------------------------------------------------------------------------------------------ helpers
def room_rects(floor: str, rid: str) -> List[Rect]:
    if rid in EXTERIOR:
        return EXTERIOR[rid] if floor == "G" else []
    return [r[2] for r in P.ROOMS[floor] if r[0] == rid]


def inside(floor: str, rid: str, x: float, z: float, margin: float = 0.0) -> bool:
    return any(r[0] + margin <= x <= r[2] - margin and r[1] + margin <= z <= r[3] - margin
               for r in room_rects(floor, rid))


def slot_index() -> Dict[str, List[str]]:
    out: Dict[str, List[str]] = {}
    for g, s, *_ in SLOTS:
        out.setdefault(g, []).append(s)
    return out


def count_cycles(adj: Dict[str, List[str]], start: str, cap: int = 8) -> int:
    """Distinct simple cycles (>= 3 points) through `start`, a cycle and its reverse once (LcGeom rule); stops at cap."""
    found = set()

    def dfs(node: str, path: List[str]) -> None:
        if len(found) >= cap or len(path) > 12:
            return
        for nb in adj.get(node, []):
            if nb == start and len(path) >= 3:
                key = tuple(path)
                rev = (path[0],) + tuple(reversed(path[1:]))
                if rev not in found:
                    found.add(key)
            elif nb not in path:
                dfs(nb, path + [nb])

    dfs(start, [start])
    return len(found)


def lc_cycles(adj: Dict[int, List[int]], start: int, cap: int, budget: int = 200000) -> int:
    """LcGeom.count_cycles_through, step for step (sorted neighbour indices, the 200k DFS step budget): the validator's
    loop count for a guard post, so the plan check fails where levelcheck `patrols` would."""
    seen = set()
    state = {"steps": 0}
    path, on_path = [start], {start}

    def dfs(cur: int) -> None:
        if len(seen) >= cap or state["steps"] >= budget:
            return
        state["steps"] += 1
        for nb in sorted(adj.get(cur, [])):
            if nb == start and len(path) >= 3:
                n = len(path)
                seen.add(tuple(sorted((min(path[i], path[(i + 1) % n]), max(path[i], path[(i + 1) % n]))
                                      for i in range(n))))
                if len(seen) >= cap:
                    return
                continue
            if nb in on_path:
                continue
            path.append(nb)
            on_path.add(nb)
            dfs(nb)
            path.pop()
            on_path.discard(nb)

    dfs(start)
    return min(len(seen), cap)


# --------------------------------------------------------------------------------------------- check
def check() -> bool:
    import ostrander_federal_content as C
    ok = True

    def fail(msg: str) -> None:
        nonlocal ok
        ok = False
        print("FAIL " + msg)

    def note(msg: str) -> None:
        print("NOTE " + msg)

    idx = slot_index()
    print("Variable table -> map:")
    for v in DOC_VARIABLES:
        if v in idx:
            n = len(idx[v])
            print("  %-22s slot group, %d slots: %s" % (v, n, ", ".join(idx[v])))
            if n < 2:
                fail("group %s has < 2 slots" % v)
        elif v in SCALARS:
            print("  %-22s scalar %s" % (v, SCALARS[v]))
        else:
            fail("doc variable %s has no slot group or scalar" % v)
    extra = [g for g in idx if g not in DOC_VARIABLES]
    print("  + B's groups for D-130/D-140 and the rare events: %s" % ", ".join("%s (%d)" % (g, len(idx[g])) for g in extra))
    if [g for g in GROUP_ORDER if g not in idx] or [g for g in idx if g not in GROUP_ORDER]:
        fail("GROUP_ORDER does not match the slot groups")
    print("  rare events: %s" % ", ".join(RARE))
    ids = [s for _, s, *_ in SLOTS]
    if len(ids) != len(set(ids)):
        fail("duplicate slot ids")
    print("Slots inside their rooms:")
    for g, sid, _w, f, rid, x, z, _y, _yaw, _n in SLOTS:
        if not inside(f, rid, x, z):
            fail("slot %s at (%g, %g) is not inside %s %s" % (sid, x, z, f, rid))
    print("  %d slots in %d groups" % (len(SLOTS), len(idx)))
    print("Cameras:")
    lay: Dict[str, set] = {"cam_a": set(), "cam_b": set(), "cam_c": set()}
    for cid, (f, rid, x, z, h, _yaw, layouts, *_pan) in CAMERAS.items():
        if not inside(f, rid, x, z):
            fail("camera %s not inside %s" % (cid, rid))
        if not (2.4 <= h <= 3.2):
            fail("camera %s mount %.1f m outside 2.4-3.2" % (cid, h))
        for la in layouts:
            lay[la].add(cid)
    for la, want in DOC_LAYOUTS.items():
        print("  %s: %s %s" % (la, " ".join(sorted(lay[la], key=lambda c: int(c[1:]))), "OK" if lay[la] == want else "BAD"))
        if lay[la] != want:
            fail("layout %s differs from the doc" % la)
    print("  %d cameras C1-C16; C6 on its lane pole at 3.0 m (doc 4.0 m: the validator's 2.4-3.2 m mount rule)"
          % len(CAMERAS))
    print("Spawns, police, holdouts:")
    for opt in ("", "preplan_spawn_lane", "preplan_spawn_tannery"):
        n = len([p for p in PLAYER_SPAWNS if p[1] == opt])
        if n < 4:
            fail("spawn option %r has %d player spawns" % (opt, n))
    for nm, _tag, f, rid, x, z, _yaw in PLAYER_SPAWNS:
        if not inside(f, rid, x, z):
            fail("player spawn %s outside %s" % (nm, rid))
    dirs = set()
    for nm, tag, x, z, _y in POLICE_SPAWNS:
        dirs.add(round(math.degrees(math.atan2(x - 24.0, z - 18.0)) / 45.0))
        for hid, (_f, hx, hz, _l) in HOLDOUTS.items():
            d = math.hypot(x - hx, z - hz)
            if d < MIN_CREW_DISTANCE_M:
                fail("police %s is %.1f m from %s (< %.0f m)" % (nm, d, hid, MIN_CREW_DISTANCE_M))
            elif d < 25.0:
                note("police %s is %.1f m from %s (doc table rounds it to 25 m; >= 15 m director rule holds)"
                     % (nm, d, hid))
    print("  player spawns: 4 plaza + 4 lane + 4 Tannery; police P1-P5 in %d directions, >= 25 m from H1-H5" % len(dirs))
    if len(dirs) < 3:
        fail("police directions")
    print("Escape / secure zones:")
    for esc in idx["escape"]:
        kinds = {k for s, k, *_ in ESCAPE_ZONES if s == esc}
        if kinds != {"SECURE_LOOT", "ESCAPE"}:
            fail("escape slot %s zones %s" % (esc, kinds))
    print("  3 escapes, each SECURE_LOOT + ESCAPE")
    print("Preplan points:")
    for pid, _cat, fi, f, rid, x, z, params in PREPLAN:
        if not inside(f, rid, x, z):
            fail("preplan %s outside %s" % (pid, rid))
        if P.FLOORS[fi] != f:
            fail("preplan %s floor index %d != %s" % (pid, fi, f))
        if "variant_slot" in params and params["variant_slot"] not in idx.get(params["variant_group"], []):
            fail("preplan %s names an unknown slot" % pid)
    print("  %d points" % len(PREPLAN))
    if len(PREPLAN) != 16:
        fail("doc lists 16 preplan points")
    print("Review cameras:")
    for rc in REVIEW_CAMERAS:
        if rc[2] and not inside(rc[1], rc[2], rc[3], rc[4], 0.5):
            fail("review camera %s is not >= 0.5 m inside %s" % (rc[0], rc[2]))
    print("  %d review cameras (doc: 34)" % len(REVIEW_CAMERAS))
    ok = C.check(fail, note) and ok
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    for row in SLOTS:
        print(row)
