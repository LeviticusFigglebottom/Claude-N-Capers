# Rolling Thunder: per-item map content for the G1 greybox (RT-C1): the door lock table, furniture / cover boxes,
# ENV A's gameplay prefabs, NPC spawns, patrol graphs, tactical points (police entries, rappels, perches, anchors,
# flanks, COVER),
# holdout / objective markers, every VariantSlot's content, the convoy (movers, paths, the four layouts), preplan
# points and review cameras. Owner: ENV C. Imported by rolling_thunder_emit_layout.py. Copy-adapted from
# ostrander_federal_content.py (D-147), but every position here is ABSOLUTE (site x, y, z), not floor-relative.
#
# Row formats (the emitted layout's formats, read by rt_gameplay.gd build_item()):
#   ["prefab", kind, name, pos, yaw, props, use (pos or None), metas, visual ("" = the prefab's placeholder)]
#   ["spawn", name, KIND, pos, yaw, tags, idle, graph ("" none), seat asset ("" none)]
#   ["box", name, base (bottom-centre), size, yaw, kind, support, surface class, metas]   (Props/MapBuilt)
#   ["marker", name, pos, yaw, objective_tag, todo]
#   ["tac", name, KIND, pos, yaw, tags, breachable]
# yaw: the node's front (-Z) faces 0 N, 90 W, 180 S, -90 E.
# RT-C2: the convoy is ENV A's movers (A5-02) carrying the trucks (A5-01, the bullion rear-door burn_point QC-81) with
# a `<Veh>Stop` marker per layout; the mixer is still a static box (TODO(A5-02)); the C4 boxes are markers
# (TODO(A5-03)).
# The design source is docs/design/heists/rolling_thunder.md.
import math
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_convoy as CV  # noqa: E402
import rolling_thunder_floors_ascii as P  # noqa: E402
import rolling_thunder_geometry as GM  # noqa: E402
import rolling_thunder_site_ascii as ST  # noqa: E402

LOCKPICK_S = 8.0
# ENV D's seated / cower placements (RT cast check, docs/status/env_d.md on env/d-art 9252b9ef): world m, yaw 90 faces
# -X, 180 faces +Z.
SEAT_FWD = 0.12                     # a catalog chair's Seat is this far ahead of its pivot (prop_chair_task, _office)
BUS_QUEUE_X = [-38.5, -37.5, -30.5, -29.5]
BUS_ROOT_Z = 13.75                  # standing 0.55 m in front of the bench centre (z 13.2; its front edge 13.45),
                                    # facing the street (LEAD r305 / D's cast read: the seated roots clipped the bench)
TABLE_SEATS = [(19.88, 18.0, -90.0), (19.88, 22.0, -90.0), (21.12, 18.0, 90.0), (21.12, 22.0, 90.0),
               (19.88, 24.5, -90.0)]
# GPU-21: the dining room's booths (centre z, along the west wall's inner face x 14.2) and counter stools (centre z, x
# 23.15: 0.25 m off the counter's front)
DINER_BOOTH_Z = [17.0, 19.45, 24.6]
DINER_STOOL_Z = [17.9, 18.55, 19.2, 19.85, 20.5, 21.15, 21.8]
# cower marks (tag cower): [name, pos, facing yaw, activity]. cower_stand wants a wall 0.21 m behind the root (~0.7 m
# clear in front); the two front marks sit under the front window (sill 0.8 m), so they crouch (`cower`, no wall
# needed, the back below the sill; D's diner fit, env_d.md 2026-10-21).
COWER_DINER = [["CowerFrontW", [20.5, 0.0, 14.41], 180.0, "cower"], ["CowerFrontE", [22.5, 0.0, 14.41], 180.0, "cower"],
               ["CowerCounterN", [23.39, 0.0, 17.0], 90.0, "cower_stand"],
               ["CowerCounterS", [23.39, 0.0, 22.6], 90.0, "cower_stand"]]
COWER_SHELTERS = [["CowerShelter%d" % i, [x, 0.0, 12.24], 0.0] for i, x in enumerate([-38.0, -30.0, -22.0])]
# D-149.7 (QC-RT7): the street civilians leave by `civilians_leave(&"civ_flee")` at the alarm through the four closures
# (PatrolPoints tagged civ_flee + exit, just past each closure on its sidewalk), and a panicking pedestrian phones from
# a sidewalk call point (CivilianTargets.CALL_POINT_GROUP, reason civilian_call): no mobile-phone call exists.
FLEE_EXITS = [["FleeNorth", [-12.0, 0.0, -88.0]], ["FleeSouth", [-12.0, 0.0, 70.0]], ["FleeWest", [-78.0, 0.0, 9.5]],
              ["FleeEast", [102.0, -5.0, -9.5]]]
CALL_POINTS = [["CallNWCorner", [-12.5, 0.0, -12.0]], ["CallNECorner", [12.5, 0.0, -12.6]],
               ["CallSECorner", [12.5, 0.0, 12.6]], ["CallSWCorner", [-12.5, 0.0, 12.0]],
               ["CallOrchardN", [-12.0, 0.0, -50.0]], ["CallOrchardS", [12.0, 0.0, 45.0]],
               ["CallPlaza", [-40.0, 0.0, 22.0]], ["CallUnderpass", [70.0, -5.0, 9.5]]]
# The throw spots (RT plan §7.5, doc Loot path) as levelcheck bag lines (OF-C3 `bag_line`: camera-free in every site
# camera layout): [name, metas, points at the crew's feet: the thrower's spot -> the landing], world m.
LINES = [
    ["ThrowOrchardWestBays", {"bag_line": "throw_orchard_west_bays", "throw_spot": True},
     [[13.0, 0.0, -30.0], [18.0, 0.0, -30.0]]],
    ["ThrowDeck2Forecourt", {"bag_line": "throw_deck2_forecourt", "throw_spot": True},
     [[40.0, 3.5, -15.0], [40.0, 0.0, -12.5]]],
    ["ThrowForecourtTrench", {"bag_line": "throw_forecourt_trench", "throw_spot": True},
     [[50.0, 0.0, -12.0], [50.0, -2.5, -8.0]]],
    ["ThrowSlabYard", {"bag_line": "throw_slab_yard", "throw_spot": True},
     [[-42.0, 3.5, -30.5], [-42.0, 0.0, -28.0]]],
    ["ThrowPadHover", {"bag_line": "throw_pad_hover", "throw_spot": True},
     [[26.6, 7.0, -34.0], [32.0, 7.0, -34.0]]],
]
CAB_N = -13.45  # the signal controller cabinet's north face (site z; rolling_thunder_geometry.site())
CP = P.BUILDINGS["CP"]
DN = P.BUILDINGS["D"]
SI = P.BUILDINGS["S"]


def r3(v: float) -> float:
    return round(float(v) + 0.0, 3)


def cp(x: float, y: float, z: float) -> list:
    return [r3(x + CP[0]), r3(y), r3(z + CP[1])]


def dn(x: float, y: float, z: float) -> list:
    return [r3(x + DN[0]), r3(y), r3(z + DN[1])]


def si(x: float, y: float, z: float) -> list:
    return [r3(x + SI[0]), r3(y), r3(z + SI[1])]


def Pf(
    kind: str,
    name: str,
    pos: list,
    yaw: float,
    props: Dict = None,
    use: list = None,
    metas: Dict = None,
    vis: str = "",
) -> list:
    return ["prefab", kind, name, [r3(v) for v in pos], float(yaw), props or {}, use, metas or {}, vis]


# A5-03: the magazine's two C4 boxes (item_pickup, 4 x item.c4 each; tag charges: picking one completes [charges]),
# against the north wall facing the door (yaw 180: the UsePoint 0.7 m south of the box, inside the room's navmesh; at
# yaw 0 it stood 0.2 m off the north wall, off the eroded navmesh, and a bot outside the shut door pathed to the
# nearest point beyond that wall: P's r280 STUCK at (-23.5, 0, -52.5))
def _c4_boxes() -> list:
    return [
        Pf("item_pickup", "C4Box%d" % (i + 1), si(x, 0.0, 5.0), 180.0,
           {"item_id": "item.c4", "count": 4, "objective_tag": "charges"}, None, {}, "prop_c4_box")
        for i, x in enumerate((36.5, 37.5))
    ]


def S(
    name: str, kind: str, pos: list, yaw: float, tags: list, idle: str = "", graph: str = "", seat: str = ""
) -> list:
    return ["spawn", name, kind, [r3(v) for v in pos], float(yaw), tags, idle, graph, seat]


def B(
    name: str,
    base: list,
    size: list,
    yaw: float,
    kind: str,
    support: bool = False,
    mat: str = "prop",
    metas: Dict = None,
) -> list:
    return ["box", name, [r3(v) for v in base], [float(v) for v in size], float(yaw), kind, support, mat, metas or {}]


def CAT(name: str, pos: list, yaw: float, asset: str, metas: Dict = None, seats: list = None) -> list:
    """A catalog prop placed as furniture: ["catalog", name, pos, yaw, asset, metas, seat marker local positions]."""
    return ["catalog", name, [r3(v) for v in pos], float(yaw), asset, metas or {}, seats or []]


def M(name: str, pos: list, tag: str, todo: str, yaw: float = 0.0) -> list:
    return ["marker", name, [r3(v) for v in pos], float(yaw), tag, todo]


def T(name: str, kind: str, pos: list, yaw: float, tags: list, breach: bool = False) -> list:
    return ["tac", name, kind, [r3(v) for v in pos], float(yaw), tags, breach]


# --------------------------------------------------------------------------------------------- doors
# Door table per plan opening (level, name) -> (node name, lock, front (the -Z / UsePoint side), leaf style, extra).
# Kits by width (rolling_thunder_geometry.kit): 1.0 m route doors -> service (leaf 1.1, meta service), 0.9 m -> single,
# 1.8 m -> double. Locks: NONE public / staff doors; LOCKPICK (8 s) back-of-house; BARRED + a padlock on gates.
FRONT_YAW = {"N": 0.0, "W": 90.0, "S": 180.0, "E": -90.0}
DOOR_SPECS: Dict[tuple, list] = {
    ("CP-G", "sta_street"): ["StairAStreetDoor", "NONE", "W", "steel", {}],
    ("CP-G", "sta_lobby"): ["StairALobbyDoorG", "NONE", "E", "steel", {}],
    ("CP-G", "lf_door"): ["LiftDoorG", "NONE", "N", "liftgate", {"leaf": "metal"}],
    ("CP-G", "ab_door"): ["BoothDoor", "NONE", "E", "ivory", {"npc": ["staff_booth"]}],
    ("CP-G", "cwc_door"): ["CarParkWCDoor", "NONE", "N", "ivory", {}],
    ("CP-G", "cpl_door"): ["PlantDoor", "NONE", "N", "steel", {}],
    ("CP-G", "sb_door"): ["StairBDoorG", "NONE", "W", "steel", {}],
    ("CP-G", "fire_door"): ["CarParkFireDoor", "NONE", "W", "steel", {"push_bar": True}],
    ("CP-2", "sta_lobby"): ["StairALobbyDoor2", "NONE", "E", "steel", {}],
    ("CP-2", "lf_door"): ["LiftDoor2", "NONE", "S", "liftgate", {"leaf": "metal"}],
    ("CP-2", "sb_door"): ["StairBDoor2", "NONE", "W", "steel", {}],
    ("CP-R", "hha_door"): ["HeadHouseADoor", "", "E", "steel", {}],  # player_perch slots build it
    ("CP-R", "lf_door"): ["LiftDoorR", "NONE", "S", "liftgate", {"leaf": "metal"}],
    ("CP-R", "hhb_door"): ["HeadHouseBDoor", "NONE", "W", "steel", {}],  # always unlocked (the E3 route)
    ("DG", "front"): ["DinerFrontDoor", "NONE", "N", "glass", {}],
    ("DG", "side"): ["DinerSideDoor", "NONE", "W", "glass", {}],
    ("DG", "delivery"): ["DinerDeliveryDoor", "LOCKPICK", "N", "steel", {"npc": ["staff_diner"]}],
    ("DG", "k_bc"): ["KitchenDoor", "NONE", "S", "ivory", {}],
    ("DG", "dr_bc"): ["CounterDoor", "NONE", "E", "ivory", {}],  # swings into DR, not the corridor BC (RT-C2)
    ("DG", "bc_st"): ["DryStoreDoor", "NONE", "N", "ivory", {}],
    ("DG", "e_door"): ["ElectricalDoor", "LOCKPICK", "S", "steel", {"npc": ["staff_diner"]}],
    ("DG", "dr_r"): ["RearLobbyDoor", "NONE", "S", "ivory", {}],  # swings into DR, not the corridor R (RT-C2)
    ("DG", "dr_of"): ["DinerOfficeDoor", "LOCKPICK", "N", "ivory", {"npc": ["staff_diner"]}],
    ("DG", "w1"): ["DinerWC1Door", "NONE", "E", "ivory", {}],
    ("DG", "w2"): ["DinerWC2Door", "NONE", "E", "ivory", {}],
    ("DG", "r_sc"): ["DinerStairDoorG", "NONE", "W", "ivory", {}],
    ("DG", "fire_exit"): ["DinerFireExit", "NONE", "N", "steel", {"push_bar": True}],
    ("DG", "st_service"): ["DinerServiceDoor", "LOCKPICK", "N", "steel", {"npc": ["staff_diner"]}],
    ("DG", "yard_gate_w"): ["YardGateW", "LOCKPICK", "W", "steel", {}],
    ("DG", "yard_gate_e"): ["YardGateE", "LOCKPICK", "E", "steel", {}],
    ("DU", "u1_u2"): ["UpperStoreDoor", "NONE", "W", "ivory", {}],
    ("DU", "u1_u3"): ["UpperDryGoodsDoor", "NONE", "W", "ivory", {}],
    ("DU", "u1_uc"): ["FunctionRoomDoor", "NONE", "S", "ivory", {}],
    ("DU", "u1_u5"): ["StaffRoomDoor", "NONE", "N", "ivory", {}],
    ("DU", "u4"): ["UpperWCDoor", "NONE", "E", "ivory", {}],
    ("DU", "uc_sc"): ["DinerStairDoorU", "NONE", "W", "ivory", {}],
    ("DU", "j"): ["JanitorDoor", "NONE", "E", "ivory", {}],
    ("SG", "c1"): ["CabinC1Door", "NONE", "S", "steel", {}],
    ("SG", "c2"): ["CabinC2Door", "NONE", "S", "steel", {}],
    ("SG", "c3"): ["CabinC3Door", "NONE", "S", "steel", {}],
    ("SG", "c4"): ["ToolStoreDoor", "LOCKPICK", "S", "steel", {"tag": "thermite"}],
    ("SG", "mg"): ["MagazineDoor", "BARRED", "S", "steel", {"padlock": "charges"}],
    ("SG", "man_gate"): ["SiteManGate", "BARRED", "E", "steel", {"padlock": "site_gate"}],
}
# Wide gates (two 2.0 m doubles either side of a 0.4 m post: rolling_thunder_geometry.holes_local) and the rail gate.
GATES: List[list] = [
    # [name, level, plan opening, front, lock, extra]
    ["SiteVehicleGateN", "SG", "vehicle_gate", -1, "E", "BARRED", {"padlock": "site_gate"}],
    ["SiteVehicleGateS", "SG", "vehicle_gate", 1, "E", "BARRED", {}],
    # phase 2 (D-149.8): one industrial site gate across the 4.2 m Tannery opening (rolling_thunder_geometry
    # TANNERY_GAP), its leaves swinging out onto the sidewalk (the mixer waits inside), opened by A at the mixer move
    # (objective_tag tannery_gate, A's lookup; meta opens_with), then the mixer drives out through it
    [
        "SiteTanneryGate",
        "SG",
        "tannery_gate",
        0,
        "N",
        "BARRED",
        {"opens_with": "mixer_move", "tag": "tannery_gate", "visual": "prop_door_site_gate_w400_h240", "width": 4.0,
         "kind": "industrial_door", "height": 2.4},
    ],
]


def _door_visual(kind: str, style: str, t: float) -> str:
    tt = "t%02d" % int(round(t * 100))
    if style == "liftgate":
        return "prop_door_double_liftgate_t20"
    if kind == "double" and style == "glass":
        return "prop_door_double_glass_%s" % tt
    if style == "glass" and kind == "service":
        style = "ivory"  # no glazed service kit: an ivory leaf in the shopfront's side door (G2 swaps it)
    return "prop_door_%s_%s_%s" % (kind, style, tt)


def _wall_t_at(level: str, axis: str, fixed: float, c: float) -> float:
    """Thickness of the wall a door sits in (the emitted wall runs)."""
    ox, oz = P.BUILDINGS[P.LEVEL_BUILDING[level]]
    f, a = (fixed + oz, c + ox) if axis == "x" else (fixed + ox, c + oz)
    for w in GM.walls():
        if w[1] == axis and abs(w[2] - f) < 1e-6 and w[3] - 1e-6 <= a <= w[4] + 1e-6:
            return w[5]
    if level == "SG":
        return GM.HOARD_T
    raise SystemExit("door at %s %s %.1f %.1f: no wall" % (level, axis, fixed, c))


def doors() -> List[list]:
    """[name, floor key, origin (bottom-centre on the wall line), yaw, kind, lock, visual, width_m, extra]."""
    out = []
    ops = {(o.level, o.name): o for o in GM.OPENINGS_G1}
    for key, spec in DOOR_SPECS.items():
        o = ops[key]
        name, lock, front, style, extra = spec
        k = GM.kit(o.width, o.route)
        kind, _hw, leaf = k
        axis, fixed, c = ("x", o.z, o.x) if o.along == "x" else ("z", o.x, o.z)
        t = 0.2 if key[1] == "mg" else _wall_t_at(o.level, axis, fixed, c)
        vis = _door_visual(kind, style, t)
        ox, oz = P.BUILDINGS[P.LEVEL_BUILDING[o.level]]
        y = P.LEVEL_FFL[o.level]
        pos = [r3(c + ox), y, r3(fixed + oz)] if axis == "x" else [r3(fixed + ox), y, r3(c + oz)]
        out.append([name, o.level, pos, FRONT_YAW[front], kind, lock, vis, leaf, dict(extra)])
    for name, level, op, side, front, lock, extra in GATES:
        o = ops[(level, op)]
        axis, fixed, c = ("x", o.z, o.x) if o.along == "x" else ("z", o.x, o.z)
        c += side * 1.2
        ox, oz = P.BUILDINGS[P.LEVEL_BUILDING[level]]
        pos = [r3(c + ox), 0.0, r3(fixed + oz)] if axis == "x" else [r3(fixed + ox), 0.0, r3(c + oz)]
        ex = {k: v for k, v in extra.items() if k not in ("visual", "width")}
        out.append([name, level, pos, FRONT_YAW[front], "double", lock,
                    extra.get("visual", "prop_door_double_grille_t20"), float(extra.get("width", 1.8)), ex])
    out.append(
        [
            "RailLaneGate",
            "X5",
            [60.0, 0.0, -72.0],
            0.0,
            "double",
            "BARRED",
            "prop_door_double_grille_t20",
            1.8,
            {"todo": "P_NE ENTRY (police breach); the crew side is south"},
        ]
    )
    return out


# Door slots (OF side_door pattern): slot -> {door: lock}.
SLOT_DOORS: Dict[str, Dict[str, str]] = {
    "perch_carpark_roof": {"HeadHouseADoor": "NONE"},
    "perch_frame": {"HeadHouseADoor": "LOCKPICK"},
    "perch_none": {"HeadHouseADoor": "LOCKPICK"},
}

# --------------------------------------------------------------------------------------------- furniture / cover
# street parked cars [name, base, yaw] (1.9 x 1.45 x 4.6 greybox bodies, length along local z)
STREET_CARS = [
    ("StreetCarOW1", [-9.0, 0.0, 34.0], 0.0),   # clear of OrchardW_S StreetLamp0 (z 28)
    ("StreetCarOW2", [-9.0, 0.0, 45.0], 0.0),
    ("StreetCarOE1", [9.0, 0.0, 40.0], 0.0),
    ("StreetCarOE2", [9.0, 0.0, 55.0], 0.0),
    ("StreetCarTW1", [-30.0, 0.0, 7.0], 90.0),
    ("StreetCarTW2", [-55.0, 0.0, 7.0], 90.0),   # clear of TanneryW_S StreetLamp0 (x -50)
    ("StreetCarON1", [8.5, 0.0, -30.0], 0.0),
]
COVER_OFF = 0.6           # a COVER point stands this far off its cover's face, facing it (OF's pier points)
_CARS = {  # car-park parked cars (plan `cc`, local x, z), 4.6 x 1.9 x 1.45 greybox bodies, along x
    "G": [(12.5, 8.0), (2.4, 12.0), (18.0, 14.0), (12.5, 22.0), (2.4, 24.0), (24.0, 26.5)],
    "2": [(12.5, 8.0), (2.4, 16.0), (18.0, 20.0), (25.5, 33.0), (8.0, 27.0)],
    "R": [(20.0, 27.0), (20.0, 32.0), (14.0, 32.0), (8.0, 32.0)],
}


def furniture() -> List[list]:
    out = []
    ys = {"G": 0.0, "2": 3.5, "R": 7.0}
    for lvl, cars in _CARS.items():
        for i, (x, z) in enumerate(cars):
            # cars keep >= 0.6 m from the 1.1 m facade barriers (RT plan §7.2: nothing standable within 0.5 m)
            out.append(
                B(
                    "ParkedCar%s%d" % (lvl, i),
                    cp(x, ys[lvl], z),
                    [4.6, 1.45, 1.9],
                    90.0,
                    "car",
                    False,
                    "prop",
                    {"cover": "hard"},
                )
            )
    # street: parked cars on Orchard / Tannery kerbs, bus shelters, the newsstand, the clock pillar, planters
    for nm, p, yaw in STREET_CARS:
        out.append(B(nm, p, [1.9, 1.45, 4.6], yaw, "car", False, "prop", {"cover": "hard"}))
    for i, x in enumerate([-38.0, -30.0, -22.0]):
        out.append(B("BusShelter%d" % i, [x, 0.0, 12.6], [5.0, 2.6, 0.3], 0.0, "bus_shelter", False, "prop"))
        # (the bus queue stands in front of the bench since r305: no seats on it)
        out.append(B("ShelterBench%d" % i, [x, 0.0, 13.2], [3.0, 0.45, 0.5], 0.0, "bench", True, "prop"))
    out.append(B("Newsstand", [-12.0, 0.0, -14.0], [2.4, 2.4, 1.6], 0.0, "kiosk", False, "prop", {"cover": "hard"}))
    out.append(B("ClockPillar", [-26.0, 0.0, 20.0], [0.8, 6.0, 0.8], 0.0, "landmark", False, "trim"))
    for i, (x, z) in enumerate([(-50.0, 18.0), (-44.0, 25.0), (-34.0, 25.0), (-18.0, 26.0)]):
        out.append(B("Planter%d" % i, [x, 0.0, z], [1.6, 0.9, 1.6], 0.0, "planter", True, "prop"))
    # the diner: counter (0.9 m, service side east), three tables (sit_eat), the cook's line, the office desk
    out.append(B("DinerCounter", dn(10.0, 0.0, 5.75), [0.8, 0.9, 7.5], 0.0, "counter", True, "counter"))
    # D item 3's 5th customer: a 3rd table. A booth was tried: its bench-to-table gap is 0.115 m, so the
    # sitter's root falls in a sliver the 0.1 m bake cannot hold without a polygon under the bench lip
    # (navmesh: no navmesh on a prop).
    for i, z in enumerate([4.0, 8.0, 10.5]):
        out.append(B("DinerTable%d" % i, dn(6.5, 0.0, z), [0.8, 0.74, 0.8], 0.0, "table", True, "prop"))
    # GPU-21 (the LEAD's render review: DR read as an office): fixed booths along the Orchard windows (no sitters: the
    # sliver above; the table end against the glass, the side door z 21.5-22.5 and the review camera clear) and the
    # fixed counter stools on the customers' side, clear of the counter's two cower marks (z 17.0 / 22.6, 0.7 m)
    for i, z in enumerate(DINER_BOOTH_Z):
        out.append(CAT("DinerBooth%d" % i, [14.82, 0.0, z], 0.0, "prop_diner_booth", {"kind": "booth"}))
    for i, z in enumerate(DINER_STOOL_Z):
        out.append(CAT("CounterStool%d" % i, [23.15, 0.0, z], -90.0, "prop_diner_stool", {"kind": "stool"}))
    out.append(B("Cookline", dn(13.55, 0.0, 4.0), [0.8, 0.9, 5.0], 0.0, "cookline", True, "counter"))
    out.append(B("PrepTable", dn(17.0, 0.0, 4.5), [2.0, 0.9, 0.8], 0.0, "table", True, "counter"))
    out.append(B("OfficeDesk", dn(9.5, 0.0, 13.5), [1.4, 0.75, 0.7], 0.0, "desk", True, "prop"))
    out.append(B("FunctionTable0", dn(3.0, 3.5, 9.0), [1.8, 0.74, 0.8], 0.0, "table", True, "prop"))
    out.append(B("FunctionTable1", dn(9.0, 3.5, 9.0), [1.8, 0.74, 0.8], 0.0, "table", True, "prop"))
    # the car-park booth desk and the plant
    # the attendant's desk, open below for the knees (D item 5): near edge 0.20 m ahead of the seated root
    out.append(CAT("BoothDesk", [18.5, 0.0, -15.1], 0.0, "prop_desk_office", {"kind": "desk"}))
    out.append(B("PlantPumps", cp(17.5, 0.0, 34.6), [4.0, 1.4, 1.2], 0.0, "plant", False, "prop"))
    # the site: formwork stacks and rebar under the slab (cover maze), block pallets on F1, cabins' plan table
    for i, (x, z) in enumerate([(14.0, 13.5), (25.0, 18.5), (31.0, 9.0), (19.0, 23.5)]):
        out.append(
            B(
                "FormworkStack%d" % i,
                si(x, 0.0, z),
                [2.4, 1.2, 1.2],
                0.0,
                "formwork",
                False,
                "prop",
                {"cover": "hard"},
            )
        )
    for i, (x, z) in enumerate([(31.0, 22.0), (15.0, 10.0)]):
        out.append(
            B("BlockPallet%d" % i, si(x, 3.5, z), [1.2, 1.0, 1.2], 0.0, "pallet", False, "prop", {"cover": "hard"})
        )
    out.append(B("PlanTable", si(3.5, 0.0, 34.0), [1.2, 0.9, 2.0], 0.0, "table", True, "prop"))
    # Reyes's mixer: phase 2, the `Mixer` convoy_vehicle mover of each route slot (convoy_sets MIXER_START)
    return out


# --------------------------------------------------------------------------------------------- always-present
def _escape(
    kind: str,
    sec_pos: list,
    sec_yaw: float,
    sec_size: list,
    esc_pos: list,
    esc_size: list,
    vis: str,
    esc_type: str,
    delay: float,
    esc_vis: str,
    label: str,
) -> list:
    props = {"objective_tag": "escape", "escape_type": esc_type, "zone_size_m": esc_size}
    if delay > 0.0:
        props["arrival_delay_s"] = delay
    m = M(
        "EscapeWait" + kind,
        [esc_pos[0], esc_pos[1], esc_pos[2]],
        "escape_wait",
        "loud: hold until the escape arrives",
    )
    return [
        Pf(
            "secure_zone",
            "Secure" + kind,
            sec_pos,
            sec_yaw,
            {"objective_tag": "secure", "zone_size_m": sec_size},
            None,
            {"kind": "vehicle", "escape_label": label},
            vis,
        ),
        Pf("escape_zone", "Escape" + kind, esc_pos, 0.0, props, None, {"escape_label": label}, esc_vis),
        m,
    ]


def always() -> Dict[str, List[list]]:
    hack = [-16.0, 0.0, -13.25]
    return {
        "Gameplay/Devices": [
            # the junction signal controller's rig (silent; 15 s, 0-1 interruptions): the cabinet's padlock is the
            # controller slot's (ctrl_locked); TODO(A): the rig's interaction is not gated by the padlock yet
            Pf(
                "hack_terminal",
                "SignalRig",
                [hack[0] - 0.25, 0.75, CAB_N],
                0.0,
                {"duration_s": 15.0, "interruptions": [0, 1], "objective_tag": "signals"},
                [hack[0] - 0.25, 0.0, CAB_N - 1.0],
                {"mount": "wall"},
                "prop_lift_breaker",
            ),
            # the lift breaker in CPL (lift_dead: 5 s; DB pattern, mission-driven)
            Pf(
                "hack_terminal",
                "LiftBreaker",
                cp(20.9, 1.2, 31.5),
                90.0,
                {"duration_s": 5.0, "interruptions": [0, 0], "objective_tag": "lift_breaker"},
                cp(19.9, 0.0, 31.5),
                {"mount": "wall", "todo": "lift_dead: the breaker restores goods_lift (mission, DB pattern)"},
                "prop_lift_breaker",
            ),
        ],
        "Gameplay/Loot": [
            Pf(
                "safe",
                "PayStation",
                cp(9.0, 0.0, 29.3),
                180.0,
                {
                    "size": "enum:SMALL",
                    "methods": ["saw", "drill", "c4"],
                    "objective_tag": "pay_station",
                    # contents inside the Body (prop_safe_wall_small: z -0.42..0, the door at z 0; Safe PO6-05)
                    "@contents": [
                        [
                            "small_loot",
                            "PayStationCash1",
                            [-0.15, 0.3, -0.21],
                            {"loot_id": "loot.small_valuables", "value": 400, "objective_tag": "pay_station"},
                        ],
                        [
                            "small_loot",
                            "PayStationCash2",
                            [0.15, 0.3, -0.21],
                            {"loot_id": "loot.small_valuables", "value": 400, "objective_tag": "pay_station"},
                        ],
                    ],
                },
                cp(9.0, 0.0, 28.2),
                {},
                "prop_safe_wall_small",
            ),
            Pf(
                "small_loot",
                "DinerTill",
                dn(10.0, 0.9, 4.0),
                90.0,
                {"loot_id": "loot.small_valuables", "value": 300, "objective_tag": "diner_till"},
                dn(11.0, 0.0, 4.0),
                {},
                "prop_cash_register",
            ),
            Pf(
                "safe",
                "DinerOfficeSafe",
                dn(12.5, 0.0, 16.0),
                90.0,
                {
                    "size": "enum:SMALL",
                    "methods": ["drill", "saw", "c4"],
                    "objective_tag": "diner_safe",
                    "@contents": [
                        [
                            "small_loot",
                            "DinerSafeCash1",
                            [-0.15, 0.3, -0.21],
                            {"loot_id": "loot.small_valuables", "value": 600, "objective_tag": "diner_safe"},
                        ],
                        [
                            "small_loot",
                            "DinerSafeCash2",
                            [0.15, 0.3, -0.21],
                            {"loot_id": "loot.small_valuables", "value": 600, "objective_tag": "diner_safe"},
                        ],
                    ],
                },
                dn(11.4, 0.0, 16.0),
                {},
                "prop_safe_wall_small",
            ),
            Pf(
                "small_loot",
                "PettyCash",
                si(3.5, 0.9, 33.5),
                0.0,
                {"loot_id": "loot.small_valuables", "value": 250, "objective_tag": "petty_cash"},
                si(4.4, 0.0, 33.5),
                {},
                "prop_cash_stack",
            ),
        ],
        "Gameplay/Lifts": [
            Pf(
                "bag_lift",
                "GoodsLift",
                cp(4.5, 0.0, 1.5),
                180.0,
                {
                    "travel_s": 8.0,
                    "capacity": 2,
                    "door_fold": True,
                    # A 451c8bff (RT-A6): one send button per other landing on a 3-landing lift
                    "send_prompt_keys": ["ui.prompt.send_lift_ground", "ui.prompt.send_lift_deck2",
                                         "ui.prompt.send_lift_roof"],
                    "car_size_m": [2.6, 2.4, 2.7],   # = the car (P r278: thrown bags rest at the shaft's walls)
                    "objective_tag": "goods_lift",
                    "@landings": [["GoodsLiftLanding2", [0.0, 3.5, 0.0]], ["GoodsLiftLandingR", [0.0, 7.0, 0.0]]],
                },
                cp(4.5, 0.0, 3.6),
                {"walkable": True, "group": "goods_lift"},
                "prop_cash_lift_car_w260_l270",
            ),
        ],
        "Gameplay/Ladders": [
            # the frame ladder (no bags), NW corner: its top lands on the slab in the 1.0 m edge-protection gap
            Pf(
                "ladder",
                "FrameLadder",
                si(10.7, 0.0, 5.92),
                0.0,
                {"height_m": 3.5, "objective_tag": "frame_ladder"},
                None,
                {},
                "prop_ladder_steel_h360_g00",
            ),
        ],
        # breakable windows (WindowPrefab; the shopfront bays are police ENTRYs): front -Z the street side
        "Gameplay/Windows": [
            Pf("window", nm, pos, yaw, {"breakable": True, "see_through": clear}, None, {"kind": "window"}, vis)
            for nm, pos, yaw, vis, clear in GM.window_prefabs()
        ],
        "Gameplay/Containers": [
            Pf(
                "body_container",
                "SiteSkip",
                si(15.0, 0.0, 41.5),
                90.0,
                {"capacity": 2},
                None,
                {"kind": "dumpster"},
                # prop_skip has no `Lid` / `Inside` (body_container visual slots): the dumpster until the skip variant
                "prop_dumpster",
            ),
            Pf(
                "body_container",
                "YardBins",
                dn(14.0, 0.0, 20.0),
                180.0,
                {"capacity": 2},
                None,
                {"kind": "dumpster"},
                "prop_dumpster",
            ),
        ],
        "Gameplay/Markers": [
            *[["call", nm, pos] for nm, pos in CALL_POINTS],
            M("CasingJunction", [0.0, 0.0, 0.0], "casing", "casing objective marker: the junction under the girder"),
            M(
                "ConvoyMarker",
                [0.0, 0.0, -14.0],
                "convoy",
                "the convoy's HUD marker (moves until the stop: B mocks it)",
            ),
            M("AmbushMarker", [0.0, 0.0, 0.0], "ambush", "the stop (clean or crash)"),
            M("MarshalMarker", [-6.0, 0.0, -16.0], "marshal", "the route marshal's scout car stops here (scripted)"),
            M("ChargesMarker", si(37.0, 0.0, 5.5), "charges", "the magazine's C4 boxes (item_pickup)"),
            M("TrucksMarker", [-6.0, 0.0, -38.0], "trucks", "the trucks (the active ConvoyLayout set)"),
            M("CargoMarker", [-6.0, 0.0, -38.0], "cargo", "the trucks' cargo (loot_spawn behind the rear doors)"),
            M("EscortMarker", [-6.0, 0.0, -18.0], "escort", "the escort / Vaultline crews (bonus)"),
            M("ThermiteMarker", si(12.5, 0.0, 35.5), "thermite_bag", "the thermite bag (stores_thermite / both)"),
            M(
                "BondsCourierMarker",
                [-6.0, 0.0, -28.0],
                "bonds_courier",
                "rare bonds_courier: T1's cab safe, 2 x loot.bearer_bonds (mission spawn_loot)",
            ),
        ]
        + [
            M("Holdout" + h, [x, y, z], "holdout_" + h.lower(), "doc Loud holdout " + h)
            for h, x, y, z in [
                ("H1", 35.0, 3.5, -32.0),
                ("H2", 24.0, 3.5, 23.0),
                ("H3", -38.0, 3.5, -40.0),
                ("H4", 75.0, -5.0, 0.0),
            ]
        ],
    }


# --------------------------------------------------------------------------------------------- spawns
STREET_POINTS = {
    # the pedestrians' sidewalk graph (Street): corners, the arms, the plaza; tags civilian, civ_street
    "NWCorner": [-12.0, 0.0, -9.5],
    "NECorner": [12.0, 0.0, -9.5],
    "SECorner": [12.0, 0.0, 9.5],
    "SWCorner": [-12.0, 0.0, 9.5],
    "OrchardWN": [-12.0, 0.0, -45.0],
    "OrchardEN": [12.0, 0.0, -45.0],
    "OrchardWS": [-12.0, 0.0, 45.0],
    "OrchardES": [12.0, 0.0, 45.0],
    "TanneryWN": [-45.0, 0.0, -9.5],
    "TanneryWS": [-45.0, 0.0, 9.5],
    "TanneryEN": [30.0, 0.0, -12.5],
    "TanneryES": [30.0, 0.0, 12.5],
    "PlazaE": [-20.0, 0.0, 17.0],
    "PlazaW": [-48.0, 0.0, 22.0],
    "PlazaClock": [-28.0, 0.0, 18.0],
}
STREET_EDGES = [
    ["NWCorner", "NECorner"],
    ["NECorner", "SECorner"],
    ["SECorner", "SWCorner"],
    ["SWCorner", "NWCorner"],
    ["NWCorner", "OrchardWN"],
    ["NECorner", "OrchardEN"],
    ["OrchardWN", "OrchardEN"],
    ["SWCorner", "OrchardWS"],
    ["SECorner", "OrchardES"],
    ["OrchardWS", "OrchardES"],
    ["NWCorner", "TanneryWN"],
    ["SWCorner", "TanneryWS"],
    ["TanneryWN", "TanneryWS"],
    ["NECorner", "TanneryEN"],
    ["SECorner", "TanneryES"],
    ["SWCorner", "PlazaE"],
    ["PlazaE", "PlazaClock"],
    ["PlazaClock", "PlazaW"],
    ["PlazaW", "TanneryWS"],
]
SITE_POINTS = {
    # the Halden site guard's graph (Site): the gate loop, the frame loop, the cabins loop (>= 3 loops per post)
    "GateN": [-16.5, 0.0, -43.0],
    "GateS": [-16.5, 0.0, -20.0],
    "ControllerCorner": [-17.5, 0.0, -14.5],
    "TanneryGate": [-29.5, 0.0, -13.5],   # east of the mixer parked inside the gate (MIXER_START)
    "Skip": [-42.0, 0.0, -13.5],
    "CabinsE": [-44.0, 0.0, -15.5],
    "CabinsW": [-56.0, 0.0, -15.5],
    "Magazine": [-23.0, 0.0, -47.8],
    "CraneBase": [-22.5, 0.0, -24.0],
    "FrameNE": [-27.0, 0.0, -44.0],
    "FrameSW": [-46.0, 0.0, -33.0],
    "FrameNW": [-46.0, 0.0, -48.0],
    "StairFoot": [-34.0, 0.0, -30.8],
    "FrameSE": [-27.0, 0.0, -33.0],
}
SITE_EDGES = [
    ["GateN", "GateS"],
    ["GateS", "ControllerCorner"],
    ["ControllerCorner", "TanneryGate"],
    ["TanneryGate", "Skip"],
    ["Skip", "CabinsE"],
    ["CabinsE", "CabinsW"],
    ["GateN", "Magazine"],
    ["Magazine", "FrameNE"],
    ["FrameNE", "FrameSE"],
    ["FrameSE", "StairFoot"],
    ["StairFoot", "FrameSW"],
    ["FrameSW", "FrameNW"],
    ["FrameNW", "FrameNE"],
    ["FrameSE", "CraneBase"],
    ["CraneBase", "GateS"],
    ["CraneBase", "TanneryGate"],
    ["FrameSW", "CabinsE"],
    ["Magazine", "FrameNW"],
]
MARSHAL_POINTS = {
    "marshal_carpark": {
        "Forecourt": [40.0, 0.0, -12.5],
        "Entrance": [24.0, 0.0, -12.5],
        "StairADoor": [15.0, 0.0, -46.0],
        "OrchardEN": [12.0, 0.0, -30.0],
    },
    "marshal_site_corner": {
        "ManGate": [-12.0, 0.0, -16.0],
        "Controller": [-12.0, 0.0, -12.5],
        "VehicleGate": [-12.0, 0.0, -43.0],
        "OrchardWMid": [-12.0, 0.0, -30.0],
    },
    "marshal_plaza": {
        "ShelterE": [-22.0, 0.0, 14.5],
        "Clock": [-27.5, 0.0, 18.0],
        "ShelterW": [-38.0, 0.0, 14.5],
        "PlazaN": [-30.0, 0.0, 11.5],
    },
}


def graphs() -> Dict[str, list]:
    """name -> [graph_id, floor index, {point: [pos, pause, anim, tags, yaw or None]}, edges]."""
    out = {
        "Street": [
            "street",
            1,
            dict({k: [v, [2.0, 6.0], "", ["civilian", "civ_street"], None] for k, v in STREET_POINTS.items()},
                 **{nm: [pos, [0.0, 0.0], "cower_stand", ["cower"], yaw] for nm, pos, yaw in COWER_SHELTERS}),
            STREET_EDGES + [["CowerShelter0", "TanneryWS"], ["CowerShelter1", "TanneryWS"],
                            ["CowerShelter2", "SWCorner"]],
        ],
        "CivFlee": [
            "civ_flee",
            1,
            {nm: [pos, [0.0, 0.0], "", ["civ_flee", "exit"], None] for nm, pos in FLEE_EXITS},
            [["FleeNorth", "FleeWest"], ["FleeWest", "FleeSouth"], ["FleeSouth", "FleeEast"],
             ["FleeEast", "FleeNorth"]],
        ],
        "DinerCower": [
            "diner_cower",
            1,
            {nm: [pos, [0.0, 0.0], act, ["cower"], yaw] for nm, pos, yaw, act in COWER_DINER},
            [["CowerFrontW", "CowerFrontE"], ["CowerFrontE", "CowerCounterN"], ["CowerCounterN", "CowerCounterS"],
             ["CowerCounterS", "CowerFrontW"]],
        ],
        "Site": [
            "site",
            1,
            {
                k: [
                    v,
                    [3.0, 8.0],
                    "look" if k in ("TanneryGate", "ControllerCorner") else "",
                    ["guard", "site"],
                    None,
                ]
                for k, v in SITE_POINTS.items()
            },
            SITE_EDGES,
        ],
    }
    for sid, pts in MARSHAL_POINTS.items():
        names = list(pts)
        edges = [[names[i], names[(i + 1) % len(names)]] for i in range(len(names))] + [[names[0], names[2]]]
        out["Marshal_" + sid] = [
            sid,
            1,
            {k: [v, [4.0, 9.0], "radio_call", ["vl_marshal", sid], None] for k, v in pts.items()},
            edges,
        ]
    return out


def fixed_spawns() -> List[list]:
    out = []
    # pedestrians (the civilians scalar picks how many: 6 / 9 / 12; tag civ_street: sidewalks x 12, plaza x 4)
    walk = [
        [-12.0, -20.0],
        [-12.0, -55.0],
        [12.0, -20.0],
        [12.0, -60.0],
        [-12.0, 20.0],
        [-12.0, 55.0],
        [12.0, 25.0],
        [12.0, 50.0],
        [-30.0, -9.5],
        [-60.0, 9.5],
        [24.0, -12.5],
        [24.0, 12.5],
    ]
    for i, (x, z) in enumerate(walk):
        out.append(S("Pedestrian%02d" % i, "CIVILIAN", [x, 0.0, z], 0.0, ["civ_street"], "walk_text", "Street"))
    for i, (x, z) in enumerate([[-44.0, 20.0], [-36.0, 24.0], [-24.0, 22.0], [-52.0, 14.5]]):
        out.append(S("PlazaPedestrian%d" % i, "CIVILIAN", [x, 0.0, z], 0.0, ["civ_street"], "walk_text", "Street"))
    # the bus queue (2-4) at the shelters, the diner customers (2-5), the diner staff, the attendant
    # ENV D's cast check against the clips (docs/status/env_d.md 9252b9ef, items 1-5, 8): roots in world m
    for i, x in enumerate(BUS_QUEUE_X):
        out.append(S("BusQueue%d" % i, "CIVILIAN", [x, 0.0, BUS_ROOT_Z], 180.0, ["civ_bus"], "queue"))
    # customers 0-3 on the two tables' chairs (sit_eat: table near edge 0.22 m ahead; the chair's Seat is 0.12 m ahead
    # of its pivot (prop_diner_chair, GPU-21: prop_chair_task's Seat, so the roots do not move), so the spawn stands
    # on the pivot and NpcSeatSpawns snaps it onto the Seat = D's root)
    for i, (rx, rz, yaw) in enumerate(TABLE_SEATS):
        px = rx + (SEAT_FWD if yaw == 90.0 else -SEAT_FWD)
        out.append(S("DinerCustomer%d" % i, "CIVILIAN", [px, 0.0, rz], yaw, ["civ_diner"], "sit_eat", "",
                     "prop_diner_chair"))
    out.append(S("Waitress", "CIVILIAN", [24.68, 0.0, 20.5], 90.0, ["staff_waitress", "staff_diner", "staff"],
                 "counter_wipe"))
    out.append(S("Cook", "CIVILIAN", [28.25, 0.0, 17.0], 90.0, ["staff_cook", "staff_diner", "staff"], "cook_stove"))
    out.append(S("Attendant", "CIVILIAN", [18.5, 0.0, -15.65 - SEAT_FWD], 180.0, ["staff_booth", "staff"], "desk_work",
                 "", "prop_chair_office"))
    # Reyes in the mixer cab (seated, D: sit_vehicle_drive) - TODO(A5-02): stands by the cab until the mover exists
    out.append(S("ReyesMixer", "CIVILIAN", si(21.0, 0.0, 40.2), -90.0, ["driver_mixer"], "idle"))
    return out


def player_spawns() -> List[list]:
    """[name, spawn_tag, position, yaw]."""
    out = []
    for i, x in enumerate([-24.0, -22.5, -21.0, -19.5]):
        out.append(["PlayerPlaza%d" % (i + 1), "", [x, 0.0, 17.5], -90.0])
    for i, x in enumerate([7.5, 9.0, 10.5, 12.0]):
        out.append(["PlayerCarPark%d" % (i + 1), "preplan_spawn_carpark", cp(x, 3.5, 4.5), 180.0])
    for i, x in enumerate([71.0, 72.5, 74.0, 75.5]):
        out.append(["PlayerUnderpass%d" % (i + 1), "preplan_spawn_underpass", [x, -5.0, -9.3], 90.0])
    return out


def police_spawns() -> List[list]:
    out = []
    for nm, (x, z, y) in ST.POLICE.items():
        tag = "police_" + nm[2:].lower()
        for k, dx in enumerate([-1.5, 1.5]):
            px, pz = (x + dx, z) if nm not in ("P_W", "P_E") else (x, z + dx)
            out.append(["%s_%d" % (nm, k + 1), tag, [r3(px), y, r3(pz)]])
    return out


# --------------------------------------------------------------------------------------------- tactical
def tactical() -> List[list]:
    out = [
        # street closures (vehicle-wide lanes past each closure vehicle; Wrecker / Bulwark routes)
        T("EntryClosureN", "ENTRY", [-3.0, 0.0, -80.0], 180.0, ["closure", "north", "vehicle_wide"]),
        T("EntryClosureS", "ENTRY", [-9.0, 0.0, 62.0], 0.0, ["closure", "south", "vehicle_wide"]),
        T("EntryClosureW", "ENTRY", [-72.0, 0.0, 6.0], -90.0, ["closure", "west", "vehicle_wide"]),
        T("EntryClosureE", "ENTRY", [94.0, -5.0, -2.0], 90.0, ["closure", "east", "vehicle_wide"]),
        T("EntryRailGate", "ENTRY", [60.0, 0.0, -73.0], 180.0, ["rail_lane", "northeast"], True),
        # car park (breach_only: police never spawn inside a building, D-064 / QC-42)
        T("EntryCarParkEntrance", "ENTRY", [24.0, 0.0, -13.0], 180.0, ["carpark", "south", "breach_only"]),
        T("EntryCarParkStairA", "ENTRY", [15.0, 0.0, -46.0], 90.0, ["carpark", "west", "door", "breach_only"], True),
        T(
            "EntryCarParkFireDoor",
            "ENTRY",
            [53.0, 0.0, -35.0],
            -90.0,
            ["carpark", "east", "door", "breach_only"],
            True,
        ),
        # diner doors and the four shopfront bays
        T("EntryDinerFront", "ENTRY", dn(4.5, 0.0, -1.0), 0.0, ["diner", "door", "breach_only"], True),
        T("EntryDinerSide", "ENTRY", dn(-1.0, 0.0, 8.0), 90.0, ["diner", "door", "breach_only"], True),
        T("EntryDinerDelivery", "ENTRY", dn(18.0, 0.0, -1.0), 0.0, ["diner", "door", "breach_only"], True),
        T("EntryDinerFireExit", "ENTRY", dn(4.0, 0.0, 19.0), 180.0, ["diner", "door", "breach_only"], True),
        T("EntryDinerService", "ENTRY", dn(16.0, 0.0, 19.0), 180.0, ["diner", "door", "breach_only"], True),
        T("EntryDinerBayN1", "ENTRY", dn(1.9, 0.0, -1.0), 0.0, ["diner", "window", "breach_only"], True),
        T("EntryDinerBayN2", "ENTRY", dn(9.1, 0.0, -1.0), 0.0, ["diner", "window", "breach_only"], True),
        T("EntryDinerBayW1", "ENTRY", dn(-1.0, 0.0, 3.0), 90.0, ["diner", "window", "breach_only"], True),
        T("EntryDinerBayW2", "ENTRY", dn(-1.0, 0.0, 10.4), 90.0, ["diner", "window", "breach_only"], True),
        # the site gates (chained, breachable) and the diner yard gates
        T("EntrySiteVehicleGate", "ENTRY", [-13.0, 0.0, -43.5], -90.0, ["site", "gate"], True),
        T("EntrySiteManGate", "ENTRY", [-13.0, 0.0, -16.0], -90.0, ["site", "gate"], True),
        T("EntrySiteTanneryGate", "ENTRY", [-33.5, 0.0, -10.0], 180.0, ["site", "gate"], True),
        T("EntryYardGateW", "ENTRY", dn(-1.0, 0.0, 22.0), 90.0, ["diner_yard", "gate"], True),
        T("EntryYardGateE", "ENTRY", dn(21.0, 0.0, 23.0), -90.0, ["diner_yard", "gate"], True),
        # the Skyway rappels (one-way, 9.0 m drop at the parapet gaps; P_SKY's only way down, QC-89)
        T("RappelSkywayW", "RAPPEL", [-13.02, 9.0, -26.0], 90.0, ["skyway", "one_way"]),
        T("RappelSkywayE", "RAPPEL", [13.02, 9.0, 20.0], -90.0, ["skyway", "one_way"]),
        T("EntrySkywayW", "ENTRY", [-13.5, 0.0, -26.0], -90.0, ["skyway", "rappel"]),
        T("EntrySkywayE", "ENTRY", [13.5, 0.0, 20.0], 90.0, ["skyway", "rappel"]),
        # flanks: the storm drain (vent layer, Phantom: a NavigationLink3D pair), the rail lane, the yard alley
        T("FlankStormDrainPlaza", "FLANK", [-40.0, 0.0, 14.5], 0.0, ["storm_drain", "vent", "phantom"]),
        T("FlankStormDrainUnderpass", "FLANK", [75.0, -5.0, 9.0], 0.0, ["storm_drain", "vent", "phantom"]),
        T("FlankRailLane", "FLANK", [58.0, 0.0, -40.0], 180.0, ["rail_lane", "northeast"]),
        T("FlankYardAlley", "FLANK", [51.0, 0.0, 25.0], 0.0, ["alley", "south"]),
        # Bulwark / Aegis anchors
        T("AnchorJunction", "SHIELD_ANCHOR", [0.0, 0.0, 0.0], 0.0, ["junction"]),
        T("AnchorCarParkEntrance", "SHIELD_ANCHOR", [24.0, 0.0, -11.5], 180.0, ["carpark"]),
        T("AnchorUnderpassMouth", "SHIELD_ANCHOR", [64.5, -4.6, 0.0], 90.0, ["underpass"]),
        T("AnchorTanneryGate", "SHIELD_ANCHOR", [-33.0, 0.0, -8.5], 180.0, ["site"]),
        T("AnchorDinerFront", "SHIELD_ANCHOR", [24.0, 0.0, 11.5], 0.0, ["diner"]),
        T("AnchorNorthArm", "SHIELD_ANCHOR", [-3.5, 0.0, -40.0], 0.0, ["north_arm"]),
        # sniper perches: S1 / S2 always; S4 Hazardous+ (min_difficulty rule, mission); S3 the rare crane_sniper
        T("SniperS1Skyway", "SNIPER_PERCH", [12.0, 9.0, -20.0], -90.0, ["s1", "skyway"]),
        T("SniperS2Gantry", "SNIPER_PERCH", [75.0, 7.5, -24.0], 135.0, ["s2", "rail_gantry"]),
        T("SniperS3Crane", "SNIPER_PERCH", [-28.0, 30.0, -24.0], -90.0, ["s3", "crane_sniper"]),
        T("SniperS4Ashby", "SNIPER_PERCH", [-30.0, 15.5, 36.0], -135.0, ["s4", "ashby", "min_difficulty_hazardous"]),
    ]
    # COVER (G1 subset; the per-layout convoy COVER is in the ConvoyLayout sets): piers, car-park columns, frame columns
    for z in (-72.0, -40.0, 30.0, 62.0):
        out.append(T("CoverPier%dW" % int(z), "COVER", [-1.6, 0.0, z], -90.0, ["pier"]))
        out.append(T("CoverPier%dE" % int(z), "COVER", [1.6, 0.0, z], 90.0, ["pier"]))
    for x, z in ((5, 12), (11, 18), (16, 24), (21, 12)):
        for y in (0.0, 3.5):
            out.append(
                T("CoverCPCol%d_%d_%d" % (int(y), x, z), "COVER", cp(x - 0.6, y, z), -90.0, ["carpark_column"])
            )
    for cx, cz in ((16, 11), (22, 16), (28, 21), (16, 21)):
        out.append(T("CoverFrameCol%d_%d" % (cx, cz), "COVER", si(cx - 0.6, 0.0, cz), -90.0, ["frame_column"]))
    return out + static_cover()


def static_cover() -> List[list]:
    """The always-present COVER set (doc Loud, "COVER ~70": with the active convoy layout's points, which live in the
    ConvoyLayout sets, disabled until the stop): parked cars, shelters, the newsstand, the clock, the diner counter,
    formwork, cabins, the crane base, the mixer (tag mixer: the mission disables it when the mixer moves, D-149.1)."""
    out = []
    o = COVER_OFF + 0.95                       # a car's half width + the offset
    ys = {"G": 0.0, "2": 3.5, "R": 7.0}
    for lvl, cars in _CARS.items():            # car-park cars lie along z (yaw 90): the point on their east side
        for i, (x, z) in enumerate(cars):
            out.append(T("CoverCar%s%d" % (lvl, i), "COVER", cp(x + o, ys[lvl], z), 90.0, ["parked_car", "carpark"]))
    for nm, (x, _y, z), yaw in STREET_CARS:    # street cars: the point on their road side
        if yaw == 90.0:
            out.append(T("Cover" + nm, "COVER", [x, 0.0, z - o], 180.0, ["parked_car", "street"]))
        else:
            sx = 1.0 if x < 0 else -1.0
            out.append(T("Cover" + nm, "COVER", [x + sx * o, 0.0, z], 90.0 if sx > 0 else -90.0,
                         ["parked_car", "street"]))
    for i, x in enumerate([-38.0, -30.0, -22.0]):   # the shelters' backs (beside the cower marks)
        out.append(T("CoverShelter%d" % i, "COVER", [x + 1.5, 0.0, 12.45 - COVER_OFF], 180.0, ["shelter", "plaza"]))
    out.append(T("CoverNewsstand", "COVER", [-12.0, 0.0, -13.2 + COVER_OFF], 0.0, ["kiosk", "street"]))
    out.append(T("CoverClock", "COVER", [-26.0, 0.0, 20.4 + COVER_OFF], 0.0, ["clock", "plaza"]))
    for i, z in enumerate([17.5, 21.5]):            # the counter's staff side
        out.append(T("CoverCounter%d" % i, "COVER", [24.4 + COVER_OFF, 0.0, z], 90.0, ["counter", "diner"]))
    for i, (x, z) in enumerate([(14.0, 13.5), (25.0, 18.5), (31.0, 9.0), (19.0, 23.5)]):   # formwork stacks
        out.append(T("CoverFormwork%d" % i, "COVER", si(x, 0.0, z + 0.6 + COVER_OFF), 0.0, ["formwork", "site"]))
    out.append(T("CoverCabinsE", "COVER", [-46.0 + COVER_OFF, 0.0, -22.0], 90.0, ["cabins", "site"]))
    out.append(T("CoverCabinsW", "COVER", [-58.0 - COVER_OFF, 0.0, -22.0], -90.0, ["cabins", "site"]))
    out.append(T("CoverCraneBase", "COVER", [-24.0 + COVER_OFF, 0.0, -24.0], 90.0, ["crane", "site"]))
    # the parked mixer's west side (MIXER_START: x -34.75..-32.25, z -20.6..-12.6), facing it
    out.append(T("CoverMixer", "COVER", [-34.75 - COVER_OFF, 0.0, -17.0], -90.0, ["mixer", "site"]))
    return out


def convoy_cover(nm: str, x: float, z: float, yaw: float, wd: float, route: str) -> List[list]:
    """Two COVER points beside a convoy vehicle (its local +-x sides, COVER_OFF off its faces, facing it)."""
    t = math.radians(yaw)
    lx, lz = math.cos(t), -math.sin(t)        # the vehicle's local +x in the world
    d = wd / 2.0 + COVER_OFF
    out = []
    for side, sgn in (("R", 1.0), ("L", -1.0)):
        px, pz = x + sgn * lx * d, z + sgn * lz * d
        py = r3(ST.ramp_y(px)) if route == "east" else 0.0
        out.append([nm + "Cover" + side, [r3(px), py, r3(pz)], r3(yaw + 90.0 * sgn)])
    return out


# --------------------------------------------------------------------------------------------- slots
GROUP_ORDER = [
    "convoy_route",
    "truck_count",
    "cargo_t3",
    "controller",
    "site_stores",
    "guard_post",
    "camera",
    "cop_on_scene",
    "marshal_walk",
    "goods_lift",
    "player_perch",
    "escape",
]
# [group, slot_id, weight (the doc's G0 weights; B's values block replaces them), room, pos, yaw, note]
SLOTS: List[list] = [
    ["convoy_route", "route_north", 0.55, "X1", [-6.0, 0.0, -35.0], 0.0, "southbound under the Skyway"],
    ["convoy_route", "route_east", 0.45, "X2", [40.0, 0.0, -4.0], 0.0, "westbound up out of the underpass"],
    ["truck_count", "trucks_2", 1.0, "X1", [0.0, 0.0, 0.0], 0.0, "per-difficulty weights in the table"],
    ["truck_count", "trucks_3", 1.0, "X1", [0.0, 0.0, 0.0], 0.0, "the rear car moves back (12.0 / 10.5 m)"],
    ["cargo_t3", "t3_cash", 0.5, "X1", [0.0, 0.0, 0.0], 0.0, "requires trucks_3"],
    ["cargo_t3", "t3_bullion", 0.5, "X1", [0.0, 0.0, 0.0], 0.0, "requires trucks_3"],
    ["controller", "ctrl_locked", 0.7, "X4", [-16.0, 0.0, -13.1], 0.0, "padlock: lockpick 8 s or saw"],
    ["controller", "ctrl_open", 0.3, "X4", [-16.0, 0.0, -13.1], 0.0, "ajar (asset.signal_insider forces it)"],
    ["site_stores", "stores_c4", 0.4, "X4", si(37.0, 0.0, 5.5), 0.0, "two C4 boxes in the magazine"],
    ["site_stores", "stores_thermite", 0.3, "C4", si(12.5, 0.0, 35.5), 0.0, "the thermite bag in the tool store"],
    ["site_stores", "stores_both", 0.3, "X4", si(25.0, 0.0, 20.0), 0.0, "both"],
    ["guard_post", "post_site_gate", 1.0, "X4", [-16.5, 0.0, -30.0], 0.0, "gates <-> controller <-> Tannery gate"],
    ["guard_post", "post_site_frame", 1.0, "FG", [-35.0, 0.0, -42.0], 0.0, "FG aisles, the scaffold, the slab edge"],
    ["guard_post", "post_site_cabins", 1.0, "X4", [-50.0, 0.0, -15.0], 0.0, "cabins <-> magazine <-> crane"],
    ["camera", "cam_mast_cabins", 1.0, "X4", [-44.0, 0.0, -28.0], 0.0, "on a pole by the cabins"],
    ["camera", "cam_magazine", 1.0, "X4", [-23.0, 0.0, -54.5], 0.0, "on a pole at the magazine"],
    ["camera", "cam_gate", 1.0, "X4", [-15.5, 0.0, -40.0], 0.0, "on a pole inside the Orchard gates"],
    ["cop_on_scene", "cop_plaza", 0.4, "X3", [-20.0, 0.0, 22.0], 0.0, "beat cop at the plaza"],
    ["cop_on_scene", "cop_diner", 0.3, "X1", [12.0, 0.0, 12.5], 0.0, "beat cop at the diner corner"],
    ["cop_on_scene", "cop_none", 0.3, "X1", [0.0, 0.0, 0.0], 0.0, "no cop"],
    ["marshal_walk", "marshal_carpark", 1.0, "X6", [40.0, 0.0, -12.5], 0.0, "forecourt, entrance, stair A"],
    ["marshal_walk", "marshal_site_corner", 1.0, "X1", [-12.0, 0.0, -16.0], 0.0, "man-gate and controller sidewalk"],
    ["marshal_walk", "marshal_plaza", 1.0, "X3", [-27.5, 0.0, 18.0], 0.0, "shelters and the clock"],
    ["goods_lift", "lift_powered", 0.6, "LF", cp(4.5, 0.0, 1.5), 0.0, "the lift runs"],
    ["goods_lift", "lift_dead", 0.4, "CPL", cp(19.4, 0.0, 31.5), 0.0, "the breaker in CPL (5 s)"],
    ["player_perch", "perch_carpark_roof", 0.3, "CP-R", cp(3.5, 7.0, 6.8), 0.0, "HH A's roof door unlocked"],
    ["player_perch", "perch_frame", 0.3, "F1", si(32.5, 3.5, 7.5), 0.0, "the slab's NE corner"],
    ["player_perch", "perch_none", 0.4, "X1", [0.0, 0.0, 0.0], 0.0, "no perch"],
    ["escape", "esc_van_carpark", 0.4, "CP-G", [23.0, 0.0, -30.0], 0.0, "E1: the west aisle"],
    ["escape", "esc_van_underpass", 0.35, "X2", [92.0, -5.0, -4.0], 0.0, "E2: the east cut"],
    ["escape", "esc_heli_roof", 0.25, "CP-R", [32.0, 7.0, -34.0], 0.0, "E3: the roof pad"],
]


def _camera(name: str, pos: list, yaw: float, cid: str) -> list:
    return Pf(
        "security_camera",
        name,
        pos,
        yaw,
        {"fov_deg": 60.0, "range_m": 20.0, "pan_deg": 40.0},
        None,
        {"mount": "wall", "kind": "security_camera", "camera_id": cid},
        "prop_security_camera_wall",
    )


POLE = 0.2


def _pole_camera(name: str, x: float, z: float, yaw: float, cid: str) -> list:
    """A 3.2 m site pole (0.2 m square) and the camera on its face toward `yaw` at 2.8 m (camera band 2.4-3.2)."""
    a = math.radians(yaw)
    fx, fz = -math.sin(a), -math.cos(a)
    return [
        B(name + "Pole", [x, 0.0, z], [POLE, 3.2, POLE], 0.0, "pole", False, "trim"),
        _camera(name, [x + fx * POLE / 2, 2.8, z + fz * POLE / 2], yaw, cid),
    ]


def slot_content() -> Dict[str, List[list]]:
    hack = [-16.0, 0.0, -13.25]
    sc: Dict[str, List[list]] = {
        "ctrl_locked": [
            Pf(
                "padlock",
                "ControllerPadlock",
                [hack[0] + 0.4, 1.0, CAB_N - 0.009],
                0.0,
                {"interaction_time_s": LOCKPICK_S, "objective_tag": "signals"},
                [hack[0] + 0.4, 0.0, CAB_N - 0.8],
                {
                    "mount": "wall",
                    "todo": "TODO(A): the rig's interaction is not gated by this padlock (no Door target)",
                },
                "prop_padlock_brass",
            )
        ],
        "ctrl_open": [M("ControllerAjar", [hack[0], 0.0, hack[2] - 0.6], "", "the cabinet door ajar (no padlock)")],
        "stores_c4": [
            *_c4_boxes(),
        ],
        "stores_thermite": [
            Pf(
                "loot_spawn",
                "ThermiteBag",
                si(12.5, 0.0, 35.5),
                180.0,
                {"loot_id": "loot.thermite", "count": 1, "objective_tag": "thermite"},
                si(12.5, 0.0, 37.2),
                {},
                "prop_loot_thermite_drum",
            )
        ],
        "stores_both": [
            *_c4_boxes(),
            Pf(
                "loot_spawn",
                "ThermiteBag",
                si(12.5, 0.0, 35.5),
                180.0,
                {"loot_id": "loot.thermite", "count": 1, "objective_tag": "thermite"},
                si(12.5, 0.0, 37.2),
                {},
                "prop_loot_thermite_drum",
            ),
        ],
        "post_site_gate": [
            S("GuardSiteGate", "GUARD", [-16.5, 0.0, -30.0], 0.0, ["guard_site_gate"], "smoke", "Site")
        ],
        "post_site_frame": [S("GuardSiteFrame", "GUARD", [-35.0, 0.0, -42.0], 0.0, ["guard_site_frame"], "", "Site")],
        "post_site_cabins": [
            S("GuardSiteCabins", "GUARD", [-50.0, 0.0, -15.0], 0.0, ["guard_site_cabins"], "", "Site")
        ],
        # each site camera on its own 3.2 m pole (0.2 m square; the camera on the pole face, back-centre)
        "cam_mast_cabins": _pole_camera("CameraMastCabins", -44.0, -28.0, 180.0, "cam_mast_cabins"),
        "cam_magazine": _pole_camera("CameraMagazine", -23.0, -54.5, 180.0, "cam_magazine"),
        "cam_gate": _pole_camera("CameraGate", -15.5, -40.0, 90.0, "cam_gate"),
        "cop_plaza": [S("CopPlaza", "GUARD", [-20.0, 0.0, 22.0], -90.0, ["cop_plaza"], "look")],
        "cop_diner": [S("CopDiner", "GUARD", [12.0, 0.0, 12.5], 0.0, ["cop_diner"], "look")],
        "cop_none": [],
        "lift_powered": [],
        "lift_dead": [
            M("LiftDead", cp(19.4, 0.0, 31.5), "lift_breaker", "lift_dead: the goods lift needs the breaker")
        ],
        "perch_carpark_roof": [
            M("PerchCarParkRoof", cp(3.5, 7.0, 7.5), "player_perch", "player perch: the car-park roof")
        ],
        "perch_frame": [
            M("PerchFrame", si(32.5, 3.5, 7.5), "player_perch", "player perch: the frame slab's NE corner")
        ],
        "perch_none": [],
        "trucks_2": [],
        "trucks_3": [],
        "t3_cash": [],
        "t3_bullion": [],
        "esc_van_carpark": _escape(
            "CarPark",
            [23.0, 0.0, -26.8],
            0.0,
            [4.0, 3.0, 8.0],
            [23.0, 0.0, -30.0],
            [4.0, 3.0, 7.0],
            "veh_van_secure",
            "van",
            0.0,
            "res://world/heists/shared/escape_van_marker.tscn",
            "E1",
        ),
        "esc_van_underpass": _escape(
            "Underpass",
            [88.8, -5.0, -4.0],
            90.0,
            [4.0, 3.0, 8.0],
            [92.0, -5.0, -4.0],
            [7.0, 3.0, 4.0],
            "veh_van_secure",
            "van",
            0.0,
            "res://world/heists/shared/escape_van_marker.tscn",
            "E2",
        ),
        "esc_heli_roof": _escape(
            "Roof",
            [35.6, 7.0, -34.0],
            0.0,
            [4.0, 3.0, 4.0],
            [32.0, 7.0, -34.0],
            [12.0, 3.0, 14.0],
            "prop_secure_cargo_net",
            "heli",
            20.0,
            "veh_heli_escape",
            "E3",
        ),
    }
    for sid, pts in MARSHAL_POINTS.items():
        first = next(iter(pts.values()))
        sc[sid] = [
            S("MarshalSpawn", "GUARD", first, 0.0, ["scripted", "vl_marshal", sid], "radio_call", "Marshal_" + sid)
        ]
    return sc


# --------------------------------------------------------------------------------------------- convoy layouts
def _support_line(x_lo: float, x_hi: float) -> Tuple[float, float]:
    """(slope s = -dy/dx, y at x = 0 of the line) a rigid body from x_lo to x_hi rests on along the east arm: the ramp
    itself (x 34..66, 0 -> -5), flat ground, or across the x 34 crest on the crest and its downhill end."""
    if x_hi <= ST.RAMP_X[0]:
        return 0.0, 0.0
    if x_lo >= ST.RAMP_X[0]:
        s_r = 5.0 / (ST.RAMP_X[1] - ST.RAMP_X[0])
        return s_r, s_r * ST.RAMP_X[0]
    y_hi = ST.ramp_y(x_hi)
    s_c = -y_hi / (x_hi - ST.RAMP_X[0])
    return s_c, s_c * ST.RAMP_X[0]


VEH_NODE = {"lead": "Lead", "T1": "T1", "T2": "T2", "T3": "T3", "rear": "Rear"}
VEH_HEIGHT = {"car": 1.5, "cash": 3.45, "bullion": 3.85}   # the art's tops (roof beacon), for the nav obstructions
LEAD_BEND = 14.0           # the lead car's path leaves the lane this far (along the arm) before its crash stop


def _ry(route: str, yaw: float) -> float:
    """Godot yaw of a vehicle whose cab (+Z) points at the junction, from a LAYOUTS yaw (`corners` convention)."""
    return r3(float(yaw)) if route == "north" else r3(-90.0 - float(yaw))


def _stop_base(route: str, v: tuple) -> Tuple[list, float]:
    """A vehicle's pivot (bottom-centre) on the road and the slope (-dy/dx) of the line it rests on (east ramp)."""
    _n, kind, a0, a1, lat, yaw = v
    c = (a0 + a1) / 2.0
    if route == "north":
        return [r3(lat), 0.0, r3(c)], 0.0
    ln, wd = CV.LEN[kind], CV.WIDTH[kind]
    ext = ln / 2.0 * math.cos(math.radians(yaw)) + wd / 2.0 * abs(math.sin(math.radians(yaw)))
    slope, y0 = _support_line(c - ext, c + ext)
    return [r3(c), r3(y0 - slope * c), r3(lat)], round(slope, 5)


def _lane_pt(route: str, along: float, lat: float) -> list:
    if route == "north":
        return [r3(lat), 0.0, r3(along)]
    y = -5.0 if along >= ST.RAMP_X[1] else (0.0 if along <= ST.RAMP_X[0] else ST.ramp_y(along))
    return [r3(along), r3(y), r3(lat)]


def _path(route: str, start: tuple) -> List[list]:
    """A mover's drive-in Path3D (world): [[point, in handle, out handle]] from its start pivot along the convoy lane
    (the trench floor, the ramp) past the lead stops into the junction; the lead car's bends onto its crash stop
    (the clean stop's nearest curve point stays on the straight lane)."""
    nm, _kind, a0, a1, lat, _yaw = start
    sgn = -1.0 if route == "north" else 1.0          # along the arm, away from the junction
    pts = [[_lane_pt(route, (a0 + a1) / 2.0, lat), [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]]
    if route == "east":   # the ramp's ends (the trench floor, the crest): onto the convoy lane up the ramp
        pts.append([_lane_pt(route, ST.RAMP_X[1], lat), [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]])
        pts.append([_lane_pt(route, ST.RAMP_X[0], CV.LANE[route]), [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]])
    lat = CV.LANE[route]
    if nm != "lead":
        pts.append([_lane_pt(route, CV.PATH_END[route], lat), [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]])
        return pts
    lead = CV.CRASH_LEAD_VEH[route + "_crash"]
    base, _s = _stop_base(route, lead)
    t = math.radians(_ry(route, lead[5]))
    fwd = (math.sin(t), math.cos(t))
    c_along = (lead[2] + lead[3]) / 2.0
    bend = _lane_pt(route, c_along + sgn * LEAD_BEND, lat)
    out_h = [0.0, 0.0, 4.0] if route == "north" else [-4.0, 0.0, 0.0]
    pts.append([bend, [-v for v in out_h], out_h])
    pts.append([base, [r3(-fwd[0] * 3.0), 0.0, r3(-fwd[1] * 3.0)], [r3(fwd[0] * 2.0), 0.0, r3(fwd[1] * 2.0)]])
    pts.append([[r3(base[0] + fwd[0] * 4.0), base[1], r3(base[2] + fwd[1] * 4.0)], [0.0, 0.0, 0.0],
                [0.0, 0.0, 0.0]])
    return pts


# Phase 2 (D-149.8, the LEAD's ruling of 2026-10-22): Reyes's mixer, one `Mixer` mover per route slot, parked inside
# the Tannery gate (x -36..-31 in the hoarding at z -11) facing it (cab +Z, south), driven by A at the mixer move along
# the active layout's `MixerPath` to its `MixerStop`: a clean stop noses across the convoy's front (about 2 m ahead of
# the lead car), a crash stop rams the lead car from the west along Tannery (0.2-0.5 m off its side).
MIXER_START = [-33.5, 0.0, -16.6]
MIXER_SIZE = [8.0, 3.5, 2.5]          # [length, height (the drum), width] (rolling_thunder.py veh_mixer_truck)
_OUT = [[-33.5, 0.0, -16.6], [0.0, 0.0, 0.0], [0.0, 0.0, 2.0]]       # out of the gate, south


def _arc_out(lane_z: float, r: float, exit_h: float = 3.0) -> List[list]:
    """The mixer's turn out of the Tannery gate (heading south, x -33.5) onto Tannery heading east in the lane at
    `lane_z`: a quarter circle of radius `r` (Bezier handles 0.5523 r), the turn starting r before the lane (the LEAD's
    r283 capture review: the first paths turned within ~5 m and the 8 m truck pivoted almost on the spot)."""
    k = r3(0.5523 * r)
    return [[[-33.5, 0.0, r3(lane_z - r)], [0.0, 0.0, -2.0], [0.0, 0.0, k]],
            [[r3(-33.5 + r), 0.0, lane_z], [-k, 0.0, 0.0], [exit_h, 0.0, 0.0]]]


MIXER = {  # layout key: [stop pivot, Godot yaw, path rows [[point, in handle, out handle]] (world)]
    # (north clean: out along Tannery's south lane like the others, then one long left sweep (>= 8 m radius) across the
    # junction onto the NE stop, nosed in diagonally across the lead car's front, 2.3 m clear of SignalNW's pole)
    "north_clean": [[-4.6, 0.0, -12.4], 135.0, [_OUT] + _arc_out(3.0, 9.0, 14.0) + [
        [[-4.6, 0.0, -12.4], [-7.0, 0.0, 7.0], [0.0, 0.0, 0.0]]]],
    "north_crash": [[-7.9, 0.0, 2.8], 90.0, [_OUT] + _arc_out(2.8, 9.0) + [
        [[-7.9, 0.0, 2.8], [-3.0, 0.0, 0.0], [0.0, 0.0, 0.0]]]],
    "east_clean": [[12.5, 0.0, -3.6], 180.0, [_OUT] + _arc_out(3.0, 9.0) + [
        [[4.5, 0.0, 3.0], [-3.0, 0.0, 0.0], [4.4, 0.0, 0.0]],
        [[12.5, 0.0, -3.6], [0.0, 0.0, 4.0], [0.0, 0.0, 0.0]]]],
    "east_crash": [[-2.2, 0.0, 1.2], 90.0, [_OUT] + _arc_out(2.0, 9.0) + [
        [[-2.2, 0.0, 1.2], [-4.0, 0.0, 0.0], [0.0, 0.0, 0.0]]]],
}


def convoy_sets() -> Dict[str, dict]:
    """{route slot: {movers, layouts}} (rolling_thunder_convoy LAYOUTS / CRASH_LEAD_VEH / starts, RT-C2): movers:
    [[node, kind, start pivot, yaw, path]] (A5-02 ConvoyVehicle at its path's start, a truck carrying its A5-01
    ArmoredTruck; the `Mixer` waits in the site with no path of its own); layouts: [[mode, [[stop node, kind, pivot,
    yaw, slope, size [length, height, width], cover rows]], mixer path rows]] (`MixerStop` and the layout's
    `MixerPath`) (the `<Veh>Stop` markers at the mover pivot, bottom-centre, cab +Z; slope = the east ramp's -dy/dx the
    marker is tilted onto; `RearStop2` the trucks_2 queue end; cover rows [name, pos, yaw] beside each vehicle, not
    beside RearStop2)."""
    out: Dict[str, dict] = {}
    for route in ("north", "east"):
        movers = []
        for v in CV.starts(route):
            base, _s = _stop_base(route, v)
            base[1] = CV.LANE_Y[route]
            movers.append([VEH_NODE[v[0]], v[1], base, _ry(route, 0.0), _path(route, v)])
        movers.append(["Mixer", "mixer", MIXER_START, 0.0, []])   # its paths are per layout (MixerPath)
        layouts = []
        for mode in ("clean", "crash"):
            key = "%s_%s" % (route, mode)
            rows = []
            for v in CV.stops(key):
                kind = v[1]
                base, slope = _stop_base(route, v)
                ry = _ry(route, v[5])
                if v[0] == "rear2":
                    nm, cover = "RearStop2", []
                else:
                    nm = VEH_NODE[v[0]] + "Stop"
                    cover = convoy_cover("%s%s" % (mode.capitalize(), VEH_NODE[v[0]]), base[0], base[2], ry,
                                         CV.WIDTH[kind], route)
                rows.append([nm, kind, base, ry, slope, [CV.LEN[kind], VEH_HEIGHT[kind], CV.WIDTH[kind]], cover])
            m_pos, m_yaw, m_path = MIXER[key]
            rows.append(["MixerStop", "mixer", m_pos, m_yaw, 0.0, MIXER_SIZE,
                         convoy_cover("%sMixer" % mode.capitalize(), m_pos[0], m_pos[2], m_yaw, MIXER_SIZE[2], route)])
            layouts.append([mode, rows, m_path])
        out["route_" + route] = {
            "movers": movers,
            "layouts": layouts,
        }
    return out


# --------------------------------------------------------------------------------------------- preplan, review
def preplan() -> List[list]:
    """[id, category, floor index, position, params]."""
    return [
        ["pp_spawn_plaza", "spawn", 1, [-22.0, 0.0, 17.5], {}],
        ["pp_spawn_carpark", "spawn", 2, cp(9.5, 3.5, 4.5), {"spawn_tag": "preplan_spawn_carpark"}],
        ["pp_spawn_underpass", "spawn", 0, [73.0, -5.0, -9.3], {"spawn_tag": "preplan_spawn_underpass"}],
        ["pp_drop_site", "drop_zone", 1, si(40.0, 0.0, 40.5), {}],
        ["pp_drop_carpark", "drop_zone", 2, cp(13.0, 3.5, 33.0), {}],
        ["pp_drop_diner_yard", "drop_zone", 1, dn(6.0, 0.0, 22.0), {}],
        ["pp_drop_underpass", "drop_zone", 0, [68.0, -5.0, -9.0], {}],
        [
            "pp_escape_carpark",
            "escape",
            1,
            [23.0, 0.0, -30.0],
            {"variant_group": "escape", "slot": "esc_van_carpark"},
        ],
        [
            "pp_escape_underpass",
            "escape",
            0,
            [92.0, -5.0, -4.0],
            {"variant_group": "escape", "slot": "esc_van_underpass"},
        ],
        ["pp_escape_roof", "escape", 3, [32.0, 7.0, -34.0], {"variant_group": "escape", "slot": "esc_heli_roof"}],
        [
            "pp_perch_roof",
            "drop_zone",
            3,
            cp(3.5, 7.0, 7.5),
            {"variant_group": "player_perch", "slot": "perch_carpark_roof"},
        ],
        [
            "pp_perch_frame",
            "drop_zone",
            2,
            si(32.5, 3.5, 7.5),
            {"variant_group": "player_perch", "slot": "perch_frame"},
        ],
        ["pp_signals", "insider", 1, [-16.0, 0.0, -14.4], {"variant_group": "controller", "slot": "ctrl_open"}],
    ]


def review_cameras() -> List[list]:
    """[id, room, eye, look-at] (28; the convoy in its route_north clean layout)."""
    return [
        # TopDownPlan: the doc's rc_top_down (validate_level contract_nodes needs a TopDown* name; as Gallery Night)
        ["TopDownPlan", "", [12.0, 160.0, -9.0], [12.0, 0.0, -9.0]],
        # GPU-21: from the plaza's corner by the Orchard kerb, past the bus shelters' east end, across the junction to
        # the car park under the Skyway fascia (the old eye stood 1.3 m behind a shelter's back panel)
        ["rc_ext_junction", "X3", [-16.5, 1.7, 17.5], [6.0, 3.5, -6.0]],
        ["rc_ext_north_arm", "X1", [-4.0, 1.7, -8.0], [-5.0, 2.0, -60.0]],
        ["rc_ext_east_arm", "X6", [40.0, 1.7, -12.6], [75.0, -3.0, 0.0]],
        ["rc_ext_plaza", "X3", [-16.0, 1.7, 22.0], [-40.0, 3.0, 28.0]],
        ["rc_ext_tannery_west", "X1", [0.0, 1.7, 2.0], [-70.0, 2.0, 0.0]],
        # GPU-22: from Tannery's south sidewalk at the junction corner, east along the diner's Tannery face to the
        # HALFWAY pole sign's W face (32.5, 4.6-6.4, 10)
        ["rc_diner_neon", "X1", [12.0, 1.7, 9.6], [32.5, 4.6, 10.6]],
        # (stage_convoy: review_shots parks the convoy at that layout's stops for the shot, LEAD r305 G3)
        # 3/4 views from the west sidewalk of the convoy stopped in the west lane (x -6: Lead z -18.5, T1 -27.75,
        # T2 -39, T3 -51, Rear -61)
        ["rc_convoy_cash", "X1", [-12.6, 2.2, -19.5], [-6.0, 1.3, -31.0], {"stage_convoy": "north_clean"}],
        ["rc_convoy_bullion", "X1", [-12.6, 2.2, -32.0], [-6.0, 1.3, -48.0], {"stage_convoy": "north_clean"}],
        ["rc_carpark_ground", "CP-G", [24.0, 1.7, -15.5], [20.0, 1.0, -40.0]],
        ["rc_carpark_deck2", "CP-2", [47.5, 5.2, -16.5], [16.0, 4.5, -48.0]],
        ["rc_carpark_ramp", "CP-G", [46.0, 1.7, -16.0], [46.0, 2.5, -40.0]],
        ["rc_carpark_roof", "CP-R", [46.0, 8.7, -18.0], [26.0, 7.5, -44.0]],
        ["rc_carpark_booth", "AB", [19.8, 1.7, -15.0], [17.0, 1.0, -18.0]],
        ["rc_carpark_plant", "CPL", [30.5, 1.7, -19.4], [36.0, 0.8, -15.0]],
        ["rc_carpark_stair", "STA", [17.4, 5.2, -45.0], [17.4, 4.0, -48.0]],
        # GPU-21: from the south-west corner: the Orchard booths left, the tables, the stools, counter and menu board
        ["rc_diner_dining", "DR", [16.4, 1.7, 25.2], [22.5, 1.2, 15.5]],
        ["rc_diner_kitchen", "K", [32.8, 1.7, 21.0], [28.0, 1.0, 15.0]],
        ["rc_diner_function", "U1", [25.5, 5.2, 24.8], [16.0, 4.5, 15.0]],
        ["rc_diner_office", "OF", [22.6, 1.7, 26.6], [26.5, 0.8, 30.0]],
        ["rc_diner_staff", "U5", [22.6, 5.2, 26.6], [26.5, 4.3, 31.0]],
        ["rc_site_controller", "X4", [-16.5, 1.7, -17.0], [-16.0, 0.8, -13.0]],
        ["rc_site_frame", "FG", [-48.0, 1.7, -48.0], [-34.0, 1.0, -30.0]],
        ["rc_site_slab", "F1", [-34.0, 5.2, -30.6], [-30.0, 4.0, -50.0]],
        ["rc_site_cabins", "X4", [-40.0, 1.7, -14.0], [-52.0, 1.0, -22.0]],
        ["rc_site_welfare", "C2", [-53.5, 1.7, -17.8], [-53.5, 0.9, -25.0]],
        ["rc_underpass", "X2", [62.0, -3.3, 2.0], [92.0, -4.0, 0.0]],
        ["rc_sniper_skyway", "", [12.0, 10.6, -20.0], [40.0, 0.0, -14.0]],
    ]
