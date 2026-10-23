# Afterhours: per-item map content for the G1 greybox (AH-C1, D-165): the door lock table, furniture / cover boxes,
# ENV A's gameplay prefabs, NPC spawns (bouncers, bartenders, the box office, patrons, dancer clusters), patrol graphs,
# tactical points (police entries, flanks, shield anchors, perches S1-S3, COVER), holdout / objective markers, every
# VariantSlot's content, preplan points and review cameras. Owner: ENV C. Imported by afterhours_emit_layout.py.
# Copy-adapted from rolling_thunder_content.py (D-147); every position is ABSOLUTE (x, y, z; origin the Velvet's NW
# corner, +x east, +z south; Ground 0.0, Balcony 4.2). Design: docs/design/heists/afterhours.md.
#
# Row formats (read by ah_gameplay.gd build_item(), as RT's):
#   ["prefab", kind, name, pos, yaw, props, use (pos or None), metas, visual ("" = the prefab's placeholder)]
#   ["spawn", name, KIND, pos, yaw, tags, idle, graph ("" none), seat asset ("" none)]
#   ["box", name, base (bottom-centre), size [x, y, z], yaw, kind, support, surface class, metas]   (Props/MapBuilt)
#   ["marker", name, pos, yaw, objective_tag, todo]
#   ["tac", name, KIND, pos, yaw, tags, breachable]
# yaw: the node's front (-Z) faces 0 N, 90 W, 180 S, -90 E.
from __future__ import annotations

import math
import os
import sys
from typing import Dict, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import afterhours_floors_ascii as P  # noqa: E402
import afterhours_geometry as GM  # noqa: E402

LOCKPICK_S = 8.0
U = 4.2                                   # the balcony floor
BAR_TOP = 1.05                            # every bar top (doc Ambient-clip placement)
BAR_BEHIND = 0.28                         # bartender roots behind the top's staff-side edge
STAFF = "staff"


def r3(v: float) -> float:
    return round(float(v) + 0.0, 3)


def on_wall(level: str, x: float, z: float, off: float) -> List[float]:
    """(x, z) moved onto the nearest wall face(s) within 0.8 m, `off` out from the face on the point's side (a wall
    mount: cameras 0, cower spots 0.21, wall boards the prop's half depth)."""
    ox, oz = x, z
    for w in GM.walls():
        if w[0] != level:
            continue
        axis, fixed, a0, a1, t = w[1], w[2], w[3], w[4], w[5]
        if axis == "x" and a0 - 0.3 <= x <= a1 + 0.3 and abs(z - fixed) < 0.8:
            oz = fixed + (1.0 if z >= fixed else -1.0) * (t / 2.0 + off)
        elif axis == "z" and a0 - 0.3 <= z <= a1 + 0.3 and abs(x - fixed) < 0.8:
            ox = fixed + (1.0 if x >= fixed else -1.0) * (t / 2.0 + off)
    return [r3(ox), r3(oz)]


def Pf(kind: str, name: str, pos: list, yaw: float, props: Dict = None, use: list = None, metas: Dict = None,
       vis: str = "") -> list:
    return ["prefab", kind, name, [r3(v) for v in pos], float(yaw), props or {},
            [r3(v) for v in use] if use is not None else None, metas or {}, vis]


def S(name: str, kind: str, pos: list, yaw: float, tags: list, idle: str = "", graph: str = "", seat: str = "") -> list:
    return ["spawn", name, kind, [r3(v) for v in pos], float(yaw), tags, idle, graph, seat]


def B(name: str, base: list, size: list, yaw: float, kind: str, support: bool = False, mat: str = "prop",
      metas: Dict = None) -> list:
    return ["box", name, [r3(v) for v in base], [float(v) for v in size], float(yaw), kind, support, mat, metas or {}]


def M(name: str, pos: list, tag: str, todo: str, yaw: float = 0.0) -> list:
    return ["marker", name, [r3(v) for v in pos], float(yaw), tag, todo]


def T(name: str, kind: str, pos: list, yaw: float, tags: list, breach: bool = False) -> list:
    return ["tac", name, kind, [r3(v) for v in pos], float(yaw), tags, breach]


# --------------------------------------------------------------------------------------------- doors
# (level, plan opening) -> [node, lock ("" = a SLOT_DOORS slot builds it), front (the -Z / UsePoint side), style,
# extra]. NPC-authorised staff doors (D-048): npc tags. Push-bar fire exits: lock NONE, push_bar (police breach).
FRONT_YAW = {"N": 0.0, "W": 90.0, "S": 180.0, "E": -90.0}
NPC_STAFF = ["staff", "guard"]
DOOR_SPECS: Dict[tuple, list] = {
    ("G", "d_g10"): ["StockRoomDoor", "LOCKPICK", "S", "steel", {"npc": NPC_STAFF}],
    ("G", "d_g11"): ["GreenRoomDoor", "NONE", "S", "ivory", {}],
    ("G", "d_g12"): ["StaffRoomDoor", "NONE", "S", "ivory", {}],
    ("G", "d_g14"): ["LockerRoomDoor", "NONE", "S", "ivory", {}],
    ("G", "d_g15"): ["JanitorDoor", "NONE", "S", "steel", {}],
    ("G", "d_g16"): ["ElectricalDoor", "LOCKPICK", "E", "steel", {"npc": NPC_STAFF}],
    ("G", "d_g21"): ["LoadingDoor", "NONE", "S", "steel", {}],
    ("G", "fx_g13_w"): ["BackCorridorDoorW", "NONE", "E", "steel", {"push_bar": True}],
    ("G", "fx_g13_e"): ["BackCorridorDoorE", "NONE", "W", "steel", {"push_bar": True}],
    ("G", "rear_door"): ["RearDoor", "", "N", "steel", {"npc": NPC_STAFF}],
    ("G", "d_backstage"): ["BackstageDoor", "NONE", "S", "steel", {}],
    ("G", "fx_hall_n"): ["HallFireExitN", "NONE", "E", "steel", {"push_bar": True}],
    ("G", "fx_hall_s"): ["HallFireExitS", "NONE", "E", "steel", {"push_bar": True}],
    ("G", "d_east_bar"): ["EastBarServiceDoor", "NONE", "W", "steel", {}],
    ("G", "d_g23"): ["BarStoreDoor", "NONE", "W", "steel", {}],
    ("G", "d_g22_g25"): ["StaffStairDoorG", "NONE", "S", "steel", {}],
    ("G", "d_g20_g25"): ["StaffEntranceDoor", "NONE", "W", "ivory", {}],
    ("G", "staff_door"): ["StaffStreetDoor", "LOCKPICK", "E", "steel",
                          {"npc": NPC_STAFF, "todo": "one_way: push bar inside, LOCKPICK from Tolley St"}],
    ("G", "d_g24"): ["DoorTeamRoomDoor", "NONE", "N", "ivory", {}],
    ("G", "d_g3a"): ["WCDoorG3a", "NONE", "N", "ivory", {}],
    ("G", "d_g3b"): ["WCDoorG3b", "NONE", "N", "ivory", {}],
    ("G", "dd_hall_w"): ["HallDoorsW", "NONE", "S", "walnut", {}],
    ("G", "dd_hall_e"): ["HallDoorsE", "NONE", "S", "walnut", {}],
    ("G", "d_g20_g26"): ["DoorOfficeDoorN", "LOCKPICK", "N", "steel", {"npc": NPC_STAFF}],
    ("G", "d_g24_g27"): ["EventStoreDoor", "NONE", "N", "ivory", {}],
    ("G", "d_g2_g26"): ["DoorOfficeDoorW", "LOCKPICK", "W", "steel", {"npc": NPC_STAFF}],
    ("G", "d_g1_g2"): ["BoxOfficeFlap", "NONE", "W", "walnut", {"todo": "staff flap, not civilian_allowed"}],
    ("G", "dd_main_w"): ["MainDoorsW", "NONE", "S", "glass", {}],
    ("G", "dd_main_e"): ["MainDoorsE", "NONE", "S", "glass", {}],
    ("U", "d_u10"): ["CountRoomDoor", "LOCKPICK", "S", "steel", {"npc": NPC_STAFF}],
    ("U", "d_u7"): ["StaffStairDoorU", "NONE", "S", "steel", {}],
    ("U", "d_vip_staff"): ["VIPStaffDoor", "LOCKPICK", "W", "walnut", {"npc": NPC_STAFF}],
    ("U", "d_office"): ["OfficeDoor", "KEYCARD", "W", "walnut", {"tag": "office_door"}],
    ("U", "d_u12"): ["PrivateRoomDoor", "NONE", "N", "walnut", {}],
    ("U", "d_u5"): ["SecurityRoomDoor", "LOCKPICK", "E", "steel", {"npc": NPC_STAFF}],
    ("U", "d_u13"): ["StaffWCDoor", "NONE", "W", "ivory", {}],
    ("U", "d_u4a"): ["WCDoorU4a", "NONE", "N", "ivory", {}],
    ("U", "d_u4b"): ["WCDoorU4b", "NONE", "N", "ivory", {}],
    ("U", "rope_gate"): ["RopeGate", "NONE", "W", "walnut", {"todo": "VIP rope gate: a guest door, civilian_allowed"}],
}
SLOT_DOORS: Dict[str, Dict[str, str]] = {
    "rear_propped": {"RearDoor": "NONE"},
    "rear_locked": {"RearDoor": "LOCKPICK"},
    "gate_open": {"PassageGateN": "NONE"},
    "gate_chained": {"PassageGateN": "BARRED"},
}
# the smokers' passage north gate (a double steel gate between the Hallam wall and the Velvet, x -3 .. -0.2)
PASSAGE_GATE = [-1.6, 0.0, 0.0]


def _door_visual(kind: str, style: str, t: float) -> str:
    """The catalog leaf matching the wall: double t20 / t40; service t20 / t40, and t30 (the 0.3 m core walls) only
    in steel (door_frame_gap)."""
    if kind == "double":
        return "prop_door_double_%s_%s" % (style, "t40" if t > 0.25 else "t20")
    if style == "glass":
        style = "ivory"
    if abs(t - 0.3) < 1e-6:
        return "prop_door_service_steel_t30"
    return "prop_door_%s_%s_%s" % (kind, style, "t40" if t > 0.3 else "t20")


def _wall_t_at(level: str, axis: str, fixed: float, c: float) -> float:
    for w in GM.walls():
        if w[0] == level and w[1] == axis and abs(w[2] - fixed) < 1e-6 and w[3] - 1e-6 <= c <= w[4] + 1e-6:
            return w[5]
    raise SystemExit("door at %s %s %.1f %.1f: no wall" % (level, axis, fixed, c))


def doors() -> List[list]:
    """[name, floor key, origin (bottom-centre on the wall line), yaw, kind, lock, visual, width_m, extra]."""
    out = []
    ops = {(o.level, o.name): o for o in P.OPENINGS}
    for key, spec in DOOR_SPECS.items():
        o = ops[key]
        name, lock, front, style, extra = spec
        kind, _hw, leaf = GM.door_kit(o)
        axis, fixed, c = ("x", o.z, o.x) if o.along == "x" else ("z", o.x, o.z)
        t = _wall_t_at(o.level, axis, fixed, c)
        y = P.LEVEL_FFL[o.level]
        pos = [r3(c), y, r3(fixed)] if axis == "x" else [r3(fixed), y, r3(c)]
        out.append([name, o.level, pos, FRONT_YAW[front], kind, lock, _door_visual(kind, style, t), leaf, dict(extra)])
    out.append(["PassageGateN", "G", PASSAGE_GATE, FRONT_YAW["N"], "double", "", "prop_door_double_grille_t20", 1.8,
                {"padlock": "side_gate"}])
    # the stock cage's gate (G10, prod_stock): a BARRED mesh gate with a padlock (lockpick 8 s or saw 20 s, D-057)
    out.append(["StockCageGate", "G", [3.0, 0.0, 2.55], FRONT_YAW["S"], "single", "BARRED",
                "prop_door_single_steel_t10", 0.9, {"padlock": "prod_stock"}])
    return out


# --------------------------------------------------------------------------------------------- furniture / cover
def furniture() -> List[list]:
    out = [
        # the main bar (west wall, z 10-17): back bar, the staff aisle (1.0 m), the counter (top 1.05)
        B("MainBarBack", [0.6, 0.0, 13.5], [0.6, 1.0, 7.0], 0.0, "counter", True, "counter"),
        B("MainBarCounter", [2.2, 0.0, 13.5], [0.6, BAR_TOP, 7.0], 0.0, "counter", True, "counter"),
        # the east bar (x 24, z 8-14) and its back bar against the hall's east wall
        # (split round the service door at z 11)
        B("EastBarBackN", [25.5, 0.0, 9.1], [0.6, 1.0, 2.2], 0.0, "counter", True, "counter"),
        B("EastBarBackS", [25.5, 0.0, 12.9], [0.6, 1.0, 2.2], 0.0, "counter", True, "counter"),
        B("EastBarCounter", [23.9, 0.0, 11.0], [0.6, BAR_TOP, 6.0], 0.0, "counter", True, "counter"),
        # the VIP bar on U2's south wall (x 12-20)
        B("VIPBarBack", [16.0, U, 27.5], [8.0, 1.0, 0.6], 0.0, "counter", True, "counter"),
        B("VIPBarCounter", [16.0, U, 25.9], [8.0, BAR_TOP, 0.6], 0.0, "counter", True, "counter"),
        # the box-office counter on the foyer side of G2 (the cloakroom hatch at its south end)
        B("BoxOfficeCounter", [22.4, 0.0, 24.0], [0.6, BAR_TOP, 4.4], 0.0, "counter", True, "counter"),
        # the stage: the DJ booth (1.0 m deck) and the speaker stacks
        B("DJBooth", [15.5, 0.3, 8.2], [3.0, 1.0, 1.0], 0.0, "counter", True, "counter"),   # clear of the backstage door
        B("SpeakerStackW", [8.0, 0.3, 8.0], [1.2, 2.2, 1.0], 0.0, "speaker"),
        B("SpeakerStackE", [18.0, 0.3, 8.0], [1.2, 2.2, 1.0], 0.0, "speaker"),
        # G7 booths: banquettes (1.1 m backs) along the circle's south wall and the reserved corner booth (east end)
        B("BoothW1", [6.6, 0.0, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),   # clear of the WC door (x 4)
        B("BoothW2", [9.6, 0.0, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),
        B("BoothE1", [22.0, 0.0, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),
        B("BoothReserved", [24.6, 0.0, 19.8], [1.6, 1.1, 1.6], 0.0, "sofa"),
        B("HighTable1", [6.5, 0.0, 17.5], [0.7, 1.05, 0.7], 0.0, "table", True),
        B("HighTable2", [21.0, 0.0, 17.5], [0.7, 1.05, 0.7], 0.0, "table", True),
        # U1 VIP booths along the rail, U2 sofas
        B("VIPBooth1", [6.6, U, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),
        B("VIPBooth2", [9.6, U, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),
        B("VIPTable2", [9.6, U, 19.5], [0.8, 0.75, 0.6], 0.0, "table", True),
        B("VIPBooth3", [20.0, U, 20.35], [2.4, 1.1, 0.6], 0.0, "sofa"),
        B("VIPSofa", [16.0, U, 22.4], [3.0, 0.9, 0.9], 0.0, "sofa"),
        B("VIPCoffeeTable", [16.0, U, 23.3], [1.2, 0.45, 0.6], 0.0, "table", True),
        # G13: crate stacks at x 9 and x 24 (1.4 m crouch cover) and keg trolleys
        B("CratesG13W", [9.0, 0.0, 5.55], [1.2, 1.4, 0.7], 0.0, "crate"),
        B("CratesG13E", [24.0, 0.0, 5.55], [1.2, 1.4, 0.7], 0.0, "crate"),
        B("KegTrolley", [16.0, 0.0, 5.5], [0.6, 1.0, 0.6], 0.0, "crate"),
        # G21: keg racks, the bottle bank
        B("KegRack", [35.4, 0.0, 2.5], [0.8, 1.6, 2.4], 0.0, "shelving"),   # the east wall, clear of the doors
        B("BottleBank", [33.2, 0.0, 3.7], [1.2, 1.2, 0.9], 0.0, "bin"),
        # U10 counting tables, U9 desk, U12 shelving, G11 flight cases
        B("CountTable", [29.0, U, 10.5], [2.4, 0.9, 1.2], 0.0, "table", True),
        B("CountDesk", [32.0, U, 11.4], [1.4, 0.75, 0.7], 0.0, "desk", True),
        B("DoorLogDesk", [30.0, 0.0, 20.55], [1.2, 1.0, 0.5], 0.0, "counter", True, "counter"),
        B("StaffTable", [17.5, 0.0, 2.6], [1.4, 0.75, 0.8], 0.0, "table", True),
        B("OfficeDesk", [31.0, U, 18.0], [1.8, 0.75, 0.9], 0.0, "desk", True),
        B("PrivateShelving", [35.4, U, 23.0], [0.6, 2.0, 3.0], 0.0, "shelving", True),
        B("FlightCases", [12.5, 0.0, 1.0], [1.6, 1.0, 0.8], 0.0, "crate"),
        # Marlin Ave: the queue barriers (posts), parked cars on Tolley St
        B("QueueRail", [8.0, 0.0, 30.5], [6.0, 1.0, 0.1], 0.0, "barrier"),
        B("CarTolley1", [44.5, 0.0, 6.0], [1.9, 1.45, 4.6], 0.0, "car", False, "prop"),
        B("CarTolley2", [44.5, 0.0, 26.0], [1.9, 1.45, 4.6], 0.0, "car", False, "prop"),
        B("CarMarlin1", [30.0, 0.0, 33.5], [4.6, 1.45, 1.9], 0.0, "car", False, "prop"),
        B("CarMarlin2", [-8.0, 0.0, 33.5], [4.6, 1.45, 1.9], 0.0, "car", False, "prop"),
        # the passage's south rope barrier (PUBLIC) and its gate's fill posts
        B("PassageRope", [-1.6, 0.0, 28.6], [2.6, 1.0, 0.1], 0.0, "barrier"),
        # the loading roller door: closed shutter at G1 (the personnel door beside it is the route)
        B("RollerShutter", [31.0, 0.0, 0.0], [3.0, 3.0, 0.12], 0.0, "shutter", False, "door"),
    ]
    return out


# --------------------------------------------------------------------------------------------- always-present
def _escape(kind: str, sec_pos: list, sec_yaw: float, sec_size: list, esc_pos: list, esc_size: list,
            label: str) -> list:
    """The escape slot's SECURE_LOOT zone (the van), ESCAPE zone and wait marker (OF / RT pattern)."""
    m = M("EscapeWait" + kind, [esc_pos[0], 0.0, esc_pos[2]], "escape_wait", "loud: hold until the van arrives")
    return [Pf("secure_zone", "Secure" + kind, sec_pos, sec_yaw, {"objective_tag": "loot_secure", "zone_size_m": sec_size},
               None, {"kind": "vehicle", "escape_label": label}, "veh_van_secure"),
            Pf("escape_zone", "Escape" + kind, esc_pos, 0.0,
               {"objective_tag": "escape_van", "escape_type": "van", "zone_size_m": esc_size}, None,
               {"escape_label": label}, "res://world/heists/shared/escape_van_marker.tscn"), m]


def always() -> Dict[str, List[list]]:
    sl = [
        # bar tills, the box-office till, the cloakroom tip jar, bottle-service cash, the U9 desk drawer (D-068 values)
        ("TillMainBar", [2.2, BAR_TOP, 12.0], 0.0, 600, [3.0, 0.0, 12.0]),
        ("TillEastBar", [23.9, BAR_TOP, 10.0], 0.0, 600, [23.1, 0.0, 10.0]),
        ("TillVIPBar", [18.0, U + BAR_TOP, 25.9], 0.0, 600, [18.0, U, 25.2]),
        ("TillBoxOffice", [22.4, BAR_TOP, 23.0], 0.0, 600, [23.3, 0.0, 23.0]),
        ("TipJarCloak", [22.4, BAR_TOP, 26.0], 0.0, 300, [23.3, 0.0, 26.0]),
        ("BottleServiceU1", [9.6, U + 0.75, 19.5], 0.0, 800, [9.6, U, 18.6]),
        ("BottleServiceU2", [16.0, U + 0.45, 23.3], 0.0, 800, [16.0, U, 24.1]),
        ("DeskDrawerU9", [31.6, U + 0.75, 18.1], 0.0, 1200, [31.6, U, 19.3]),
    ]
    small = [Pf("small_loot", n, p, y, {"loot_id": "loot.small_valuables", "value": v}, u, {}, "prop_cash_stack")
             for n, p, y, v, u in sl]
    return {
        "Gameplay/Devices": [
            Pf("keycard_reader", "OfficeReader", [27.9, U + 1.2, 17.2], 90.0,
               {"objective_tag": "office_reader", "@targets": ["OfficeDoor"]}, [27.3, U, 17.2], {"mount": "wall"},
               "prop_keycard_reader"),
        ],
        "Gameplay/Loot": [
            # Crale's safe (LARGE, against U9's internal south wall): code / drill (A's afterhours_mission: the mission
            # spawns `safe_bags` loot.cash_bricks at the SafeLoot marker; loud it disables the CODE method)
            Pf("safe", "OfficeSafe", [33.5, U, 20.35], 0.0,
               {"size": "enum:LARGE", "methods": ["code", "drill"], "code_group": "office", "objective_tag": "safe"},
               [33.5, U, 19.2], {}, "prop_safe_large"),
            Pf("drill_point", "SafeDrill", [33.5, U + 0.05, 19.6], 0.0, {"objective_tag": "safe_drill",
                                                                        "@target": "OfficeSafe"},
               [33.5, U, 19.2], {}, ""),
            # the door take: G26's drop safe (SMALL, drill / saw; saw 60 s), small loot x3 inside
            Pf("safe", "DropSafe", [28.0, 0.0, 27.45], 0.0,
               {"size": "enum:SMALL", "methods": ["drill", "saw"], "saw_duration_s": 60.0,
                "@contents": [["small_loot", "DropSafeTake%d" % (i + 1), [-0.15 + 0.15 * i, 0.05, 0.0],
                               {"loot_id": "loot.small_valuables", "value": 900}] for i in range(3)]},
               [28.0, 0.0, 26.5], {"saw_target": True}, "prop_safe_wall_small"),
        ] + small,
        "Gameplay/Ladders": [
            # the drop ladder from the alley to the BOH roof (+4.2), through the parapet gap at x 30
            Pf("ladder", "DropLadder", [30.0, 0.0, -0.6], 0.0, {"height_m": 4.2, "objective_tag": "drop_ladder"}, None,
               {"todo": "ladders need the mask (doc Stealth routes 3)"}, "prop_ladder_fire_escape_h420"),
        ],
        "Gameplay/Markers": [
            M("CasingFoyer", [16.0, 0.0, 24.5], "casing", "casing objective marker: the foyer"),
            M("SafeLoot", [33.5, U + 0.3, 20.35], "safe_loot", "safe_bags x loot.cash_bricks (+1 on count_done)"),
            M("DJStage", [15.5, 1.3, 8.2], "dj_stage", "the DJ's alarm / shout-out lines play here (3D, the stage)"),
        ] + [M("Holdout" + h, [x, y, z], "holdout_" + h.lower(), "doc Loud holdout " + h)
             for h, x, y, z in [("H1", 31.0, U, 18.0), ("H2", 13.0, U, 20.0), ("H3", 31.0, 0.0, 4.0),
                                ("H4", 32.0, 0.0, 17.0)]],
        "Gameplay/Containers": [
            Pf("body_container", "DumpsterW", [21.0, 0.0, -0.85], 0.0, {"capacity": 2}, None, {"kind": "dumpster"},
               "prop_dumpster"),
            Pf("body_container", "DumpsterE", [24.0, 0.0, -0.85], 0.0, {"capacity": 2}, None, {"kind": "dumpster"},
               "prop_dumpster"),
            Pf("body_container", "JanitorCart", [26.0, 0.0, 3.0], 180.0, {"capacity": 1}, None, {"kind": "cart"},
               "prop_cart_hide"),
            Pf("body_container", "EventStoreCrate1", [35.2, 0.0, 24.5], 90.0, {"capacity": 1}, None, {"kind": "crate"},
               "prop_crate_hide"),
            Pf("body_container", "EventStoreCrate2", [35.2, 0.0, 26.3], 90.0, {"capacity": 1}, None, {"kind": "crate"},
               "prop_crate_hide"),
        ],
    }


# --------------------------------------------------------------------------------------------- NPCs
CLUSTERS = [(10.5, 12.5), (14.0, 12.5), (17.5, 12.5), (10.5, 15.0), (14.0, 15.0), (17.5, 15.0)]
DANCE = ["dance_a", "dance_b", "dance_c"]
PATRONS = [
    # [name, pos, yaw, idle]: bars, booths, the foyer, the WCs, the passage, the balcony, the VIP lounge
    ("PatronMainBar1", [3.0, 0.0, 11.5], -90.0, "walk_text"), ("PatronMainBar2", [3.0, 0.0, 15.0], -90.0, "walk_text"),
    ("PatronEastBar1", [22.8, 0.0, 9.5], 90.0, "walk_text"), ("PatronEastBar2", [22.8, 0.0, 12.5], 90.0, "walk_text"),
    ("PatronBoothW1", [6.6, 0.0, 19.6], 180.0, "sit"), ("PatronBoothW2", [9.6, 0.0, 19.6], 180.0, "sit"),
    ("PatronBoothE1", [22.0, 0.0, 19.6], 180.0, "sit"), ("PatronHighTable1", [6.5, 0.0, 16.8], 180.0, "walk_text"),
    ("PatronHighTable2", [21.0, 0.0, 16.8], 180.0, "walk_text"), ("PatronFoyer1", [12.5, 0.0, 24.0], 90.0, "walk_text"),
    ("PatronFoyer2", [19.5, 0.0, 25.5], -90.0, "queue"), ("PatronWC", [2.0, 0.0, 25.0], 0.0, "walk_text"),
    ("PatronPassage1", [-1.6, 0.0, 22.0], 90.0, "smoke"), ("PatronPassage2", [-1.4, 0.0, 25.5], -90.0, "smoke"),
    ("PatronBalcony1", [6.6, U, 19.6], 180.0, "sit"), ("PatronBalcony2", [20.0, U, 19.6], 180.0, "sit"),
    ("PatronVIP1", [14.0, U, 23.0], 0.0, "walk_text"), ("PatronVIP2", [18.0, U, 23.5], 0.0, "walk_text"),
    ("PatronVIP3", [13.6, U, 22.4], -90.0, "walk_text"), ("PatronUnderCircle", [13.0, 0.0, 18.5], 0.0, "walk_text"),
]


def fixed_spawns() -> List[list]:
    out = [
        S("DoorBouncer", "GUARD", [16.5, 0.0, 29.6], 180.0, ["guard_door"], "bouncer_idle"),
        S("RopeBouncer", "GUARD", [9.2, U, 26.6], -90.0, ["guard_rope"], "bouncer_idle", "Rope"),
        S("BartenderMain1", "CIVILIAN", [1.9 - BAR_BEHIND, 0.0, 12.0], -90.0, ["civ_bar_main", STAFF, "staff_bar"],
          "bartender_wipe"),
        S("BartenderMain2", "CIVILIAN", [1.9 - BAR_BEHIND, 0.0, 15.5], -90.0, ["civ_bar_main", STAFF, "staff_bar"],
          "bartender_pour"),
        S("BartenderEast", "CIVILIAN", [24.2 + BAR_BEHIND, 0.0, 11.0], 90.0, ["civ_bar_east", STAFF, "staff_bar"],
          "bartender_wipe"),
        S("BartenderVIP", "CIVILIAN", [16.0, U, 26.2 + BAR_BEHIND], 0.0, ["civ_bar_vip", STAFF, "staff_bar"],
          "bartender_pour"),
        S("BoxOffice", "CIVILIAN", [22.7 + BAR_BEHIND, 0.0, 23.5], 90.0, ["civ_box_office", STAFF, "staff_front"],
          "desk_work"),
    ]
    # rare co_op_pickup (A: 14:00): two cartel couriers at the loading door, held back (HeistRuntime's scripted tag)
    for i, x in enumerate([33.6, 36.4]):
        # (no graph on the spawn: A's mission walks them over the `courier` PatrolPoints by tag)
        out.append(S("Courier%d" % (i + 1), "GUARD", [x, 0.0, -2.4], 0.0, ["cartel_courier", "cartel", "scripted"]))
    # rare off_duty_cop: a patron in a U1 booth (A spawns enemy.patrol_officer here)
    out.append(S("OffDutyCop", "CIVILIAN", [20.0, U, 19.6], 180.0, ["civ_offduty"], "sit"))
    for nm, pos, yaw, idle in PATRONS:
        out.append(S(nm, "CIVILIAN", pos, yaw, ["civ_patron"], idle, "Patrons"))
    for c, (cx, cz) in enumerate(CLUSTERS):
        for k in range(5):
            a = 2.0 * math.pi * k / 5.0 + 0.3 * c
            pos = [cx + 0.8 * math.cos(a), 0.0, cz + 0.8 * math.sin(a)]
            yaw = math.degrees(math.atan2(pos[0] - cx, pos[2] - cz))   # facing the cluster's centre
            out.append(S("Dancer%d_%d" % (c + 1, k + 1), "CIVILIAN", pos, round(yaw, 1),
                         ["civ_dancer", "dance_cluster_%d" % (c + 1)], DANCE[(c + k) % 3]))
    return out


# --------------------------------------------------------------------------------------------- graphs
FOH = {"Foyer": [16.0, 0.0, 24.5], "HallDoorW": [13.0, 0.0, 19.4], "Booths": [8.0, 0.0, 18.4],
       "WCs": [2.5, 0.0, 19.6], "WestBar": [3.6, 0.0, 13.5], "StageFront": [13.0, 0.0, 10.8],
       "EastBar": [22.4, 0.0, 12.6], "G20": [27.0, 0.0, 9.5], "G13Mid": [13.0, 0.0, 6.0],
       "StageBack": [13.0, 0.3, 9.6]}
FOH_EDGES = [["Foyer", "HallDoorW"], ["HallDoorW", "Booths"], ["Booths", "WCs"], ["WCs", "WestBar"],
             ["WestBar", "StageFront"], ["StageFront", "EastBar"], ["EastBar", "Booths"], ["EastBar", "G20"],
             ["G20", "G13Mid"], ["G13Mid", "StageBack"], ["StageBack", "StageFront"]]
BOH = {"G13W": [3.0, 0.0, 6.0], "G10": [4.0, 0.0, 3.6], "G13Mid": [13.0, 0.0, 6.0], "G12": [15.5, 0.0, 3.0],
       "G13E": [31.0, 0.0, 6.0], "G21": [31.0, 0.0, 3.0], "G20": [27.0, 0.0, 14.0], "G25": [31.0, 0.0, 15.5],
       "G24": [32.0, 0.0, 19.0]}
BOH_EDGES = [["G13W", "G10"], ["G13W", "G13Mid"], ["G13Mid", "G12"], ["G13Mid", "G13E"], ["G13E", "G21"],
             ["G13E", "G20"], ["G20", "G25"], ["G25", "G24"]]
UPPER = {"U6E": [34.5, U, 15.0], "U10": [30.0, U, 12.0], "U6bN": [27.0, U, 17.0], "Balcony": [20.0, U, 16.3],
         "U2": [16.0, U, 24.0], "U1W": [6.0, U, 17.5], "U6bS": [27.0, U, 25.0], "U13": [31.0, U, 26.5],
         "StairTop": [34.5, U, 13.0], "G25": [31.0, 0.0, 15.5], "G20": [27.0, 0.0, 16.0]}
UPPER_EDGES = [["U6E", "U10"], ["U6E", "U6bN"], ["U6bN", "Balcony"], ["Balcony", "U2"], ["U2", "U1W"],
               ["U1W", "Balcony"], ["U6bN", "U6bS"], ["U6bS", "U13"], ["U6E", "StairTop"], ["StairTop", "G25"],
               ["G25", "G20"]]
ALLEY = {"RearDoor": [35.0, 0.0, -1.6], "Ladder": [30.0, 0.0, -1.6], "Dumpsters": [22.5, 0.0, -2.6],
         "Mouth": [37.0, 0.0, -3.0]}
ALLEY_EDGES = [["RearDoor", "Ladder"], ["Ladder", "Dumpsters"], ["RearDoor", "Mouth"]]
PATRON_PTS = {"Foyer": [16.0, 0.0, 25.5], "MainBar": [3.4, 0.0, 14.0], "EastBar": [22.6, 0.0, 11.0],
              "Booths": [10.0, 0.0, 19.0], "WCs": [2.0, 0.0, 22.5], "Passage": [-1.5, 0.0, 24.0],
              "DanceEdge": [13.0, 0.0, 17.2]}
PATRON_EDGES = [["Foyer", "Booths"], ["Booths", "MainBar"], ["MainBar", "WCs"], ["Booths", "EastBar"],
                ["Booths", "DanceEdge"], ["MainBar", "Passage"]]
COWER_RAW = [  # 0.21 m off walls (cower_stand, snapped by on_wall), facing away from the wall
    ("CowerHallW1", "G", 0.4, 9.5, 0.0, -90.0), ("CowerHallW2", "G", 0.4, 18.0, 0.0, -90.0),
    ("CowerCircleS1", "G", 4.0, 20.6, 0.0, 0.0), ("CowerCircleS2", "G", 16.0, 20.6, 0.0, 0.0),
    ("CowerFoyerW", "G", 10.3, 23.5, 0.0, -90.0), ("CowerFoyerE", "G", 21.7, 22.5, 0.0, 90.0),
    ("CowerVIP", "U", 11.0, 21.3, U, 180.0),
]
COWER = [(nm, [on_wall(lv, x, z, 0.21)[0], y, on_wall(lv, x, z, 0.21)[1]], yaw) for nm, lv, x, z, y, yaw in COWER_RAW]
# just outside each crowd exit: the main doors (Marlin Ave) and the hall's two west fire exits (the passage)
FLEE = [("FleeMainW", [15.0, 0.0, 31.0]), ("FleeMainE", [18.0, 0.0, 31.0]), ("FleeFireN", [-1.5, 0.0, 8.3]),
        ("FleeFireS", [-1.5, 0.0, 19.0]), ("FleePassageS", [-1.5, 0.0, 30.0])]
# the couriers' walk: the loading door -> G21 -> G13 -> the product rooms
COURIER = {"Door": [35.0, 0.0, -1.6], "G21": [33.0, 0.0, 3.0], "G13E": [31.0, 0.0, 6.0], "G13Mid": [13.0, 0.0, 6.0],
           "G10": [4.0, 0.0, 3.6], "G11": [11.0, 0.0, 3.6]}


def graphs() -> Dict[str, list]:
    def pts(d: Dict[str, list], pause: list, tags: list, special: Dict[str, list] = None) -> Dict[str, list]:
        out = {}
        for k, v in d.items():
            sp = (special or {}).get(k)
            out[k] = sp if sp is not None else [v, pause, "", tags, None]
        return out
    return {
        "Foh": ["foh", 0, pts(FOH, [2.0, 5.0], ["guard", "guard_foh"],
                              {"StageFront": [FOH["StageFront"], [6.0, 10.0], "look", ["guard", "guard_foh"], 180.0],
                               "EastBar": [FOH["EastBar"], [15.0, 15.0], "look", ["guard", "guard_foh"], 90.0]}),
                FOH_EDGES],
        "Boh": ["boh", 0, pts(BOH, [2.0, 5.0], ["guard", "guard_boh"],
                              {"G13Mid": [BOH["G13Mid"], [6.0, 10.0], "look", ["guard", "guard_boh"], None],
                               "G20": [BOH["G20"], [6.0, 10.0], "look", ["guard", "guard_boh"], 0.0]}), BOH_EDGES],
        "Upper": ["upper", 1, pts(UPPER, [2.0, 5.0], ["guard", "guard_upper"],
                                  {"U6E": [UPPER["U6E"], [6.0, 10.0], "look", ["guard", "guard_upper"], None],
                                   "Balcony": [UPPER["Balcony"], [10.0, 10.0], "look", ["guard", "guard_upper"], 0.0]}),
                  UPPER_EDGES],
        "Alley": ["alley", 0, pts(ALLEY, [3.0, 6.0], ["guard_alley"],
                                  {"Mouth": [ALLEY["Mouth"], [20.0, 40.0], "smoke", ["guard_alley"], 90.0]}),
                  ALLEY_EDGES],
        "Rope": ["rope", 1, {"Gate": [[9.2, U, 26.6], [20.0, 30.0], "", ["guard_rope"], -90.0],
                             "StairHead": [[8.0, U, 26.8], [5.0, 8.0], "", ["guard_rope"], 0.0]},
                 [["Gate", "StairHead"]]],
        "Patrons": ["patrons", 0, pts(PATRON_PTS, [4.0, 12.0], ["civilian"]), PATRON_EDGES],
        "Cower": ["cower", 0, {nm: [p, [0.0, 0.0], "cower_stand", ["cower"], y] for nm, p, y in COWER},
                  [[COWER[i][0], COWER[i + 1][0]] for i in range(len(COWER) - 1)]],
        "CivFlee": ["civ_flee", 0, {nm: [p, [0.0, 0.0], "", ["civ_flee", "civ_exit", "exit"], None] for nm, p in FLEE},
                    [["FleeMainW", "FleeMainE"], ["FleeMainW", "FleePassageS"], ["FleePassageS", "FleeFireS"],
                     ["FleeFireS", "FleeFireN"]]],
        "Courier": ["courier", 0, pts(COURIER, [3.0, 6.0], ["courier"]),
                    [["Door", "G21"], ["G21", "G13E"], ["G13E", "G13Mid"], ["G13Mid", "G11"], ["G13Mid", "G10"]]],
    }


# --------------------------------------------------------------------------------------------- spawns, preplan
def player_spawns() -> List[list]:
    out = []
    for i, x in enumerate([15.0, 17.0, 19.0, 21.0]):
        out.append(["PlayerFoyer%d" % (i + 1), "", [x, 0.0, 26.6], 0.0])
    for i, x in enumerate([13.0, 14.5, 17.5, 19.0]):
        out.append(["PlayerVIP%d" % (i + 1), "preplan_spawn_vip", [x, U, 24.0], 0.0])
    for i, x in enumerate([20.0, 21.5, 23.0, 24.5]):
        out.append(["PlayerAlley%d" % (i + 1), "preplan_spawn_alley", [x, 0.0, -3.6], -90.0])
    return out


def police_spawns() -> List[list]:
    return [
        ["P1_1", "police_w", [-17.5, 0.0, 36.0]], ["P1_2", "police_w", [-17.5, 0.0, 39.0]],
        ["P2_1", "police_e", [59.0, 0.0, 30.5]], ["P2_2", "police_e", [59.0, 0.0, 46.5]],
        ["P3_1", "police_n", [40.5, 0.0, -21.5]], ["P3_2", "police_n", [43.5, 0.0, -21.5]],
        ["P4_1", "police_alley", [-10.5, 0.0, -2.5]], ["P4_2", "police_alley", [-10.5, 0.0, -4.5]],
    ]


def preplan() -> List[list]:
    """[id, category, floor index, position, params]."""
    return [
        ["pp_spawn_foyer", "spawn", 0, [18.0, 0.0, 26.0], {}],
        ["pp_spawn_vip", "spawn", 1, [16.0, U, 24.0], {"spawn_tag": "preplan_spawn_vip"}],
        ["pp_spawn_alley", "spawn", 0, [22.0, 0.0, -3.6], {"spawn_tag": "preplan_spawn_alley"}],
        ["pp_gear_wc", "insider", 0, [4.5, 0.0, 26.5], {"variant_group": "gear_drop", "slot": "gear_wc"}],
        ["pp_gear_cloak", "insider", 0, [22.9, 0.0, 25.5], {"variant_group": "gear_drop", "slot": "gear_cloak"}],
        ["pp_gear_booth", "insider", 0, [24.6, 0.0, 19.3], {"variant_group": "gear_drop", "slot": "gear_booth"}],
        ["pp_gear_van", "insider", 0, [27.4, 0.0, -4.0], {"variant_group": "gear_drop", "slot": "gear_van"}],
        ["pp_insider_keycard", "insider", 0, [19.0, 0.0, 1.5], {"variant_group": "keycard", "slot": "kc_staff_room"}],
        ["pp_back_door", "insider", 0, [35.0, 0.0, -0.8], {"variant_group": "rear_door", "slot": "rear_propped"}],
        ["pp_count_window", "insider", 1, [30.0, U, 6.0], {"variant_group": "open_window", "slot": "ow_count_open"}],
        ["pp_drop_alley", "drop_zone", 0, [19.0, 0.0, -4.5], {}],
        ["pp_drop_roof", "drop_zone", 1, [28.5, U, 3.0], {}],
        ["pp_drop_tolley", "drop_zone", 0, [37.3, 0.0, 13.0], {}],
        ["pp_escape_alley", "escape", 0, [30.5, 0.0, -4.0], {"variant_group": "escape", "slot": "esc_alley"}],
        ["pp_escape_tolley", "escape", 0, [40.0, 0.0, 17.0], {"variant_group": "escape", "slot": "esc_tolley"}],
    ]


def review_cameras() -> List[list]:
    """[id, room, eye, look-at] (doc Review shots, 27)."""
    return [
        ["TopDownPlan", "", [22.0, 90.0, 16.0], [22.0, 0.0, 16.0]],
        ["rc_ext_marquee", "X2", [17.0, 1.7, 45.0], [17.0, 4.0, 28.0]],
        ["rc_ext_tolley", "X2", [42.0, 1.7, -14.0], [38.0, 4.0, 20.0]],
        ["rc_ext_alley", "X1", [-10.5, 1.7, -3.0], [34.0, 2.0, -2.0]],
        ["rc_ext_passage", "X2", [-1.6, 1.7, 33.0], [-1.6, 1.5, 4.0]],
        ["rc_boh_roof", "X1R", [30.0, U + 1.7, 1.0], [30.0, U + 1.5, 6.8]],
        ["rc_foyer", "G1", [16.5, 1.7, 27.2], [12.0, 1.4, 21.5]],
        ["rc_hall_club", "G7", [20.0, 1.7, 20.2], [12.0, 2.5, 8.0]],
        ["rc_hall_house", "G7", [19.5, 1.7, 20.2], [12.0, 2.5, 8.0]],
        ["rc_hall_crowd", "G6", [7.0, 1.0, 16.0], [16.0, 1.2, 12.0]],
        ["rc_main_bar", "G6", [6.0, 1.7, 9.0], [1.5, 1.2, 14.0]],
        ["rc_east_bar", "G6", [19.0, 1.7, 13.5], [25.5, 1.2, 10.5]],
        ["rc_under_circle", "G7", [24.0, 1.7, 16.0], [2.0, 1.0, 20.0]],
        ["rc_balcony", "U1", [25.3, U + 1.7, 16.0], [2.0, U + 1.0, 18.5]],
        ["rc_vip_lounge", "U2", [21.3, U + 1.7, 21.8], [10.5, U + 1.0, 27.0]],
        ["rc_projection_box", "U5", [23.0, U + 1.7, 21.8], [24.5, U + 1.0, 27.5]],
        ["rc_office", "U9", [28.8, U + 1.7, 16.8], [34.5, U + 0.8, 20.5]],
        ["rc_private_room", "U12", [28.8, U + 1.7, 21.8], [35.5, U + 1.0, 24.0]],
        ["rc_count_room", "U10", [32.5, U + 1.7, 13.3], [26.5, U + 1.0, 10.5]],
        ["rc_upper_corridor", "U6b", [27.0, U + 1.7, 27.2], [27.0, U + 1.2, 16.5]],
        ["rc_back_corridor", "G13", [0.8, 1.7, 6.0], [36.0, 1.2, 6.0]],
        ["rc_east_corridor", "G20", [27.0, 1.7, 7.6], [27.0, 1.2, 20.5]],
        ["rc_stock_room", "G10", [6.5, 1.7, 4.5], [2.5, 1.0, 1.0]],
        ["rc_green_room", "G11", [13.5, 1.7, 4.5], [9.0, 1.0, 0.8]],
        ["rc_staff_room", "G12", [19.5, 1.7, 4.5], [15.0, 1.0, 0.8]],
        ["rc_loading", "G21", [28.6, 1.7, 1.0], [34.0, 1.0, 3.5]],
        ["rc_door_team", "G24", [28.6, 1.7, 17.6], [35.5, 1.0, 20.5]],
    ]


def nav_links() -> List[list]:
    return []


# --------------------------------------------------------------------------------------------- tactical
def tactical() -> List[list]:
    bo = ["breach_only"]
    out = [
        T("EntryMainDoorsW", "ENTRY", [15.0, 0.0, 29.4], 0.0, bo + ["main_doors"]),
        T("EntryMainDoorsE", "ENTRY", [18.0, 0.0, 29.4], 0.0, bo + ["main_doors"]),
        T("EntryFireExitN", "ENTRY", [-1.2, 0.0, 8.3], -90.0, bo + ["passage"], True),
        T("EntryFireExitS", "ENTRY", [-1.2, 0.0, 19.0], -90.0, bo + ["passage"], True),
        T("EntryG13W", "ENTRY", [-1.2, 0.0, 6.0], -90.0, bo + ["passage"], True),
        T("EntryG13E", "ENTRY", [37.2, 0.0, 6.0], 90.0, bo + ["tolley"], True),
        T("EntryLoadingDoor", "ENTRY", [35.0, 0.0, -1.2], 180.0, bo + ["alley"], True),
        T("EntryStaffDoor", "ENTRY", [37.2, 0.0, 15.0], 90.0, bo + ["tolley"], True),
        T("EntryCountWindow", "ENTRY", [30.0, U, 6.0], 180.0, bo + ["roof"], True),
        T("EntryPassageS", "ENTRY", [-1.5, 0.0, 29.0], 0.0, ["passage"]),
        T("EntryPassageN", "ENTRY", [-1.5, 0.0, -1.0], 180.0, ["passage"], True),
        T("FlankRoof", "FLANK", [30.0, 0.0, -1.6], 180.0, ["roof", "ladder"]),
        T("FlankPassage", "FLANK", [-1.5, 0.0, 14.0], 0.0, ["passage"]),
        T("AnchorMarquee", "SHIELD_ANCHOR", [16.0, 0.0, 30.0], 0.0, ["marlin"]),
        T("AnchorStaffDoor", "SHIELD_ANCHOR", [38.0, 0.0, 15.0], 90.0, ["tolley"]),
        T("AnchorFoyer", "SHIELD_ANCHOR", [16.0, 0.0, 22.0], 0.0, ["foyer"]),
        T("AnchorAlley", "SHIELD_ANCHOR", [30.0, 0.0, -3.0], 180.0, ["alley"]),
        T("PerchS1", "SNIPER_PERCH", [-10.0, 18.0, 50.0], 0.0, ["s1"]),
        T("PerchS2", "SNIPER_PERCH", [52.0, 16.0, 4.0], 90.0, ["s2"]),
        T("PerchS3", "SNIPER_PERCH", [24.0, 10.0, -14.0], 180.0, ["s3", "rooftop_watch"]),
    ]
    cover = [("CoverMainBarN", [3.0, 0.0, 9.6], 180.0), ("CoverMainBarS", [3.0, 0.0, 17.4], 0.0),
             ("CoverEastBarN", [23.2, 0.0, 7.6], 180.0), ("CoverEastBarS", [23.2, 0.0, 14.4], 0.0),
             ("CoverStageW", [7.0, 0.0, 10.6], 0.0), ("CoverStageE", [19.0, 0.0, 10.6], 0.0),
             ("CoverBoothW1", [6.6, 0.0, 19.4], 0.0), ("CoverBoothE1", [22.0, 0.0, 19.4], 0.0),
             ("CoverRailW", [6.0, U, 15.6], 0.0), ("CoverRailE", [20.0, U, 15.6], 0.0),
             ("CoverCratesG13W", [10.0, 0.0, 6.4], 0.0), ("CoverCratesG13E", [25.0, 0.0, 6.4], 0.0),
             ("CoverKegRack", [34.5, 0.0, 2.5], 90.0), ("CoverDumpsterW", [21.0, 0.0, -2.0], 0.0),
             ("CoverCarTolley1", [43.0, 0.0, 6.0], -90.0), ("CoverCarMarlin1", [30.0, 0.0, 32.0], 180.0),
             ("CoverVIPBar", [16.0, U, 24.9], 180.0), ("CoverDJBooth", [15.5, 0.3, 9.2], 0.0)]
    out += [T(n, "COVER", p, y, ["cover"]) for n, p, y in cover]
    return out


LINES = [
    ["ThrowRoofAlley", {"bag_line": "throw_roof_alley", "throw_spot": True}, [[30.5, U, 0.3], [30.5, 0.0, -3.0]]],
]

# --------------------------------------------------------------------------------------------- variants
GROUP_ORDER = ["gear_drop", "dj_set", "keycard", "code_note", "count_room", "product_location", "laser_pattern",
               "guard_post", "security_room_staffed", "camera", "rear_door", "open_window", "side_gate", "escape"]
# [group, slot_id, weight (ENV B's ah_b1_values.md §2; per-difficulty rows live in the variant table), room, pos, yaw,
# note]
SLOTS: List[list] = [
    ["gear_drop", "gear_wc", 1.0, "G3b", [4.5, 0.0, 27.3], 0.0, "the duct panel in the patrons' WC"],
    ["gear_drop", "gear_cloak", 1.0, "G2", [22.4, 0.0, 25.5], 0.0, "across the cloakroom counter from the foyer"],
    ["gear_drop", "gear_booth", 1.0, "G7", [24.6, 0.0, 18.8], 0.0, "under the reserved booth's banquette"],
    ["gear_drop", "gear_van", 1.0, "X1", [26.6, 0.0, -4.0], 0.0, "the van (E1)"],
    ["dj_set", "dj_on", 0.65, "G6", [15.5, 0.3, 9.4], 0.0, "the DJ on stage"],
    ["dj_set", "dj_break", 0.35, "G11", [11.0, 0.0, 2.5], 0.0, "the DJ in the green room"],
    ["keycard", "kc_staff_room", 1.0, "G12", [18.0, 0.75, 2.6], 0.0, "the staff-room table under the rota"],
    ["keycard", "kc_bouncer_board", 1.0, "G24", [30.4, 1.0, 20.55], 0.0, "the door-log desk"],
    ["keycard", "kc_vip_bar", 1.0, "U2", [12.5, U + BAR_TOP, 25.9], 0.0, "behind the VIP register"],
    ["keycard", "kc_count_room", 0.75, "U10", [32.0, U + 0.75, 11.4], 0.0, "the count-room desk"],
    ["keycard", "kc_dj_booth", 0.75, "G6", [16.7, 1.3, 8.2], 0.0, "beside the decks (requires dj_break)"],
    ["code_note", "code_staff_board", 1.0, "G12", [17.0, 1.5, 0.2], 0.0, "the rota board"],
    ["code_note", "code_bouncer_log", 1.0, "G24", [29.6, 1.0, 20.55], 0.0, "the door log"],
    ["code_note", "code_count_board", 1.0, "U10", [31.6, U + 1.5, 13.9], 0.0, "the whiteboard beside the door"],
    ["code_note", "code_office_blotter", 0.5, "U9", [31.0, U + 0.75, 18.0], 0.0, "the office desk blotter"],
    ["count_room", "count_running", 0.6, "U10", [29.0, U, 10.5], 0.0, "the counter at the tables, 2 cash bags"],
    ["count_room", "count_done", 0.4, "U10", [29.0, U, 10.5], 0.0, "empty (+1 safe bag)"],
    ["product_location", "prod_stock", 1.0, "G10", [3.0, 0.0, 1.0], 0.0, "the stock cage (padlock)"],
    ["product_location", "prod_green", 0.8, "G11", [12.5, 0.0, 1.0], 0.0, "the DJs' flight cases"],
    ["product_location", "prod_private", 1.0, "U12", [35.4, U, 23.0], 0.0, "the lock boxes behind the lasers"],
    ["laser_pattern", "lz_static", 0.5, "U12", [34.3, U, 23.0], 0.0, "3 beams, a crouch gap"],
    ["laser_pattern", "lz_sweep", 0.2, "U12", [34.3, U, 23.0], 0.0, "sweeping, period 6 s"],
    ["laser_pattern", "lz_timed", 0.3, "U12", [34.3, U, 23.0], 0.0, "off 4 s every 16 s"],
    ["guard_post", "rover_floor", 1.0, "G6", FOH["Foyer"], 0.0, "front of house (foh)"],
    ["guard_post", "rover_boh", 1.0, "G13", BOH["G13W"], 0.0, "back of house (boh)"],
    ["guard_post", "rover_upper", 1.0, "U6", UPPER["U6E"], 0.0, "the staff wing (upper)"],
    ["guard_post", "alley_smoker", 1.0, "X1", ALLEY["Mouth"], 0.0, "the alley"],
    ["security_room_staffed", "sec_staffed", 0.6, "U5", [24.0, U, 26.5], 0.0, "the operator at the monitors"],
    ["security_room_staffed", "sec_empty", 0.4, "U5", [24.0, U, 26.5], 0.0, "nobody watching"],
    ["camera", "cam_a", 1.0, "G1", [21.6, 3.2, 21.4], 0.0, "C1 C2 C5 C7 C8"],
    ["camera", "cam_b", 1.0, "G1", [21.6, 3.2, 21.4], 0.0, "C1 C3 C4 C9 C10"],
    ["camera", "cam_c", 1.0, "G1", [21.6, 3.2, 21.4], 0.0, "C1 C3 C6 C8 C10"],
    ["rear_door", "rear_propped", 0.35, "G21", [35.0, 0.0, 0.0], 0.0, "propped open (the smoker props it)"],
    ["rear_door", "rear_locked", 0.65, "G21", [35.0, 0.0, 0.0], 0.0, "lockpick 8 s"],
    ["open_window", "ow_count_open", 0.4, "U10", [30.0, U, 7.0], 0.0, "the count-room window open"],
    ["open_window", "ow_count_latched", 0.6, "U10", [30.0, U, 7.0], 0.0, "latched (break the glass)"],
    ["side_gate", "gate_open", 0.4, "X2", PASSAGE_GATE, 0.0, "the passage's north gate open"],
    ["side_gate", "gate_chained", 0.6, "X2", PASSAGE_GATE, 0.0, "chained (lockpick 8 s / saw 20 s)"],
    ["escape", "esc_alley", 0.55, "X1", [30.5, 0.0, -4.0], 0.0, "E1: the alley van"],
    ["escape", "esc_tolley", 0.45, "X2", [40.0, 0.0, 17.0], 0.0, "E2: Tolley St"],
]
# the doc's cameras (x, z, height above the floor, floor y, yaw: the view direction)
CAMS = {"C1": (21.0, 21.4, 3.2, 0.0, 180.0), "C2": (0.4, 6.0, 2.8, 0.0, -90.0), "C3": (27.0, 7.4, 2.8, 0.0, 180.0),
        "C4": (34.0, 0.4, 3.2, 0.0, 180.0), "C5": (33.0, -0.4, 3.0, 0.0, 0.0), "C6": (28.4, 14.9, 2.8, 0.0, -90.0),
        "C7": (27.0, 27.6, 2.8, U, 0.0), "C8": (32.6, 8.0, 2.8, U, 90.0), "C9": (0.4, 3.8, 2.8, 0.0, -90.0),
        "C10": (25.6, 15.4, 3.0, U, 90.0)}
CAM_LAYOUTS = {"cam_a": ["C1", "C2", "C5", "C7", "C8"], "cam_b": ["C1", "C3", "C4", "C9", "C10"],
               "cam_c": ["C1", "C3", "C6", "C8", "C10"]}


CAM_BACK = 0.0   # the wall camera's pivot is its back-centre: flush on the face


def _camera(cid: str) -> list:
    x, z, h, y, yaw = CAMS[cid]
    x, z = on_wall("U" if y > 0.0 else "G", x, z, CAM_BACK)
    # C5 is fixed (no pan): it watches the rear door, not the roof throw west of it (bag_line)
    pan = 0.0 if cid == "C5" else 40.0
    return Pf("security_camera", "Camera" + cid, [x, y + h, z], yaw, {"fov_deg": 60.0, "range_m": 20.0, "pan_deg": pan},
              None, {"mount": "wall", "kind": "security_camera", "camera_id": cid}, "prop_security_camera_wall")


def _gear(pos: list, yaw: float, use: list) -> list:
    return [Pf("gear_pickup", "GearBag", pos, yaw, {"objective_tag": "gear"}, use, {}, "prop_bag_floor")]


def _keycard(pos: list, yaw: float, use: list, wall: str = "") -> list:
    """A keycard on a desk / counter top, or (wall = level) hung on the nearest wall face (the key hooks / board)."""
    metas = {}
    if wall:
        x, z = on_wall(wall, pos[0], pos[2], 0.0)
        pos, metas = [x, pos[1], z], {"mount": "wall"}
    return [Pf("keycard_pickup", "Keycard", pos, yaw, {"objective_tag": "keycard"}, use, metas, "prop_keycard_bank")]


def _wall_pt(level: str, p: list) -> list:
    x, z = on_wall(level, p[0], p[2], 0.0)
    return [x, p[1], z]


def _code(pos: list, yaw: float, use: list, mount: str = "", vis: str = "prop_notebook") -> list:
    return [Pf("code_note", "SafeCode", pos, yaw, {"code_group": "office", "objective_tag": "safe_code",
                                                   "casing_allowed": True}, use, {"mount": mount} if mount else {},
               vis)]


def _laser(pattern: str, props: Dict, width: float = 3.6, z: float = 23.0) -> list:
    p = {"pattern": pattern, "size_m": [width, 2.2, 0.1], "objective_tag": "lasers"}
    p.update(props)
    return [Pf("laser_grid", "PrivateLasers", [34.3, U, z], 90.0, p, None, {}, "")]


def _rover(nm: str, graph: str, tag: str, pos: list) -> list:
    return [S(nm, "GUARD", pos, 0.0, ["guard", tag], "", graph)]


def slot_content() -> Dict[str, List[list]]:
    station = Pf("camera_station", "CameraStation", [24.0, U, 27.3], 0.0, {}, [24.0, U, 26.5], {},
                 "prop_camera_station")
    sc: Dict[str, List[list]] = {
        "gear_wc": _gear([4.5, 0.0, 27.3], 0.0, [4.5, 0.0, 26.5]),
        "gear_cloak": _gear([22.4, BAR_TOP, 25.5], 90.0, [23.3, 0.0, 25.5]),
        "gear_booth": _gear([24.6, 0.0, 18.8], 0.0, [24.6, 0.0, 18.0]),
        "gear_van": _gear([26.6, 0.0, -4.0], 90.0, [25.8, 0.0, -4.0]),
        "dj_on": [S("DJ", "CIVILIAN", [15.5, 0.3, 9.4], 180.0, ["civ_dj_stage", STAFF, "staff_dj"], "dj_mix")],
        "dj_break": [S("DJ", "CIVILIAN", [11.0, 0.0, 2.5], 0.0, ["civ_dj_green", STAFF, "staff_dj"], "sit")],
        "kc_staff_room": _keycard([18.0, 0.75, 2.6], 0.0, [18.0, 0.0, 3.4]),
        "kc_bouncer_board": _keycard([30.4, 1.0, 20.55], 0.0, [30.4, 0.0, 19.8]),
        "kc_vip_bar": _keycard([12.5, U + BAR_TOP, 25.9], 0.0, [12.5, U, 26.6]),
        "kc_count_room": _keycard([32.0, U + 0.75, 11.4], 0.0, [32.0, U, 12.2]),
        "kc_dj_booth": _keycard([16.7, 1.3, 8.2], 180.0, [16.7, 0.3, 9.2]),
        "code_staff_board": _code(_wall_pt("G", [17.0, 1.2, 0.2]), 180.0, [17.0, 0.0, 1.0], "wall",
                                  "prop_bulletin_board"),
        "code_bouncer_log": _code([29.6, 1.0, 20.55], 0.0, [29.6, 0.0, 19.8]),
        "code_count_board": _code(_wall_pt("U", [31.6, U + 1.2, 13.9]), 0.0, [31.6, U, 13.0], "wall",
                                  "prop_whiteboard"),
        "code_office_blotter": _code([31.0, U + 0.75, 18.0], 0.0, [31.0, U, 17.2]),
        "count_running": [
            S("Counter", "CIVILIAN", [29.0, U, 11.3], 0.0, ["civ_count", STAFF, "staff_upper"], "desk_work"),
            M("CountCash", [28.4, U + 0.9, 10.5], "count_cash", "2 x loot.cash (the mission spawns them)"),
        ],
        "count_done": [],
        # product: markers only (A's mission spawns product_bags x loot.parcels, +2 with extra_product)
        "prod_stock": [M("ProductStock", [3.0, 0.1, 1.0], "product", "the stock cage (padlocked gate)")],
        "prod_green": [M("ProductGreen", [12.5, 1.0, 1.0], "product", "on the DJs' flight cases")],
        "prod_private": [M("ProductPrivate", [35.4, U + 0.1, 23.0], "product", "the shelving behind the lasers")],
        "lz_static": _laser("static", {"beam_count": 3}, 2.6, 22.5),   # the bypass: 1.0 m on the south side
        "lz_sweep": _laser("sweep", {"period_s": 6.0, "sweep_beams": 1}),
        "lz_timed": _laser("timed", {"period_s": 16.0, "off_s": 4.0}),
        "rover_floor": _rover("RoverFloor", "Foh", "guard_floor", FOH["Foyer"]),
        "rover_boh": _rover("RoverBoh", "Boh", "guard_boh", BOH["G13W"]),
        "rover_upper": _rover("RoverUpper", "Upper", "guard_upper", UPPER["U6E"]),
        "alley_smoker": _rover("AlleySmoker", "Alley", "guard_alley", ALLEY["RearDoor"]),
        "sec_staffed": [
            Pf("camera_station", "CameraStation", [24.0, U, 27.3], 0.0, {"@operator_spawn": "CameraOperatorSeat"},
               [24.0, U, 26.5], {}, "prop_camera_station"),
            S("CameraOperatorSeat", "CAMERA_OPERATOR", [24.0, U, 26.5], 180.0, ["guard", "camera_operator"],
              "desk_work"),
        ],
        "sec_empty": [station],
        "rear_propped": [], "rear_locked": [],
        "ow_count_open": [Pf("window", "CountWindow", [30.0, U + GM.WINDOW[0], 7.0], 0.0,
                             {"openable": True, "breakable": True, "walkable": True}, [30.0, U, 7.8],
                             {"open": True}, "prop_window_w120_h210")],
        "ow_count_latched": [Pf("window", "CountWindow", [30.0, U + GM.WINDOW[0], 7.0], 0.0,
                                {"openable": False, "breakable": True, "walkable": True}, [30.0, U, 7.8], {},
                                "prop_window_w120_h210")],
        "gate_open": [], "gate_chained": [],
        "esc_alley": _escape("Alley", [30.5, 0.0, -4.0], 90.0, [4.0, 3.0, 7.0], [25.0, 0.0, -3.6], [4.0, 3.0, 4.0],
                             "E1"),
        "esc_tolley": _escape("Tolley", [40.0, 0.0, 17.0], 0.0, [4.0, 3.0, 7.0], [40.0, 0.0, 22.5], [4.0, 3.0, 4.0],
                              "E2"),
    }
    for lay, cams in CAM_LAYOUTS.items():
        sc[lay] = [_camera(c) for c in cams]
    return sc


# the doc's variables in rule order: [id, options, scalar?] (values: ENV B's ah_b1_values.md)
VARIABLES = [
    ["gear_drop", ["gear_wc", "gear_cloak", "gear_booth", "gear_van"], False],
    ["dj_set", ["dj_on", "dj_break"], False],
    ["keycard", ["kc_staff_room", "kc_bouncer_board", "kc_vip_bar", "kc_count_room", "kc_dj_booth"], False],
    ["code_note", ["code_staff_board", "code_bouncer_log", "code_count_board", "code_office_blotter"], False],
    ["count_room", ["count_running", "count_done"], False],
    ["product_location", ["prod_stock", "prod_green", "prod_private"], False],
    ["product_bags", ["3", "4", "5"], True],
    ["safe_bags", ["4", "5", "6"], True],
    ["laser_pattern", ["lz_static", "lz_sweep", "lz_timed"], False],
    ["guard_post", ["rover_floor", "rover_boh", "rover_upper", "alley_smoker"], False],
    ["security_room_staffed", ["sec_staffed", "sec_empty"], False],
    ["camera", ["cam_a", "cam_b", "cam_c"], False],
    ["rear_door", ["rear_propped", "rear_locked"], False],
    ["open_window", ["ow_count_open", "ow_count_latched"], False],
    ["side_gate", ["gate_open", "gate_chained"], False],
    ["escape", ["esc_alley", "esc_tolley"], False],
    ["crowd", ["12", "14", "16", "18", "20"], True],
    ["dance_clusters", ["4", "5", "6"], True],
]
