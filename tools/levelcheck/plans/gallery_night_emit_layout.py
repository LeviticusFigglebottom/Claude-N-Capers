# Emits game/world/heists/gallery_night/greybox/gallery_night_layout.gd (the generator's data) from the floor-plan
# data (gallery_night_floors_ascii.py) and the slot / contract-node list (gallery_night_slots.py). Owner: ENV C.
# Run: python3 tools/levelcheck/plans/gallery_night_emit_layout.py            (writes the .gd)
#      python3 tools/levelcheck/plans/gallery_night_emit_layout.py --stdout   (prints it)
# Deterministic: plain lists in source order, sorted wall lines, fixed float formatting. Never hand-edit the
# output; change the plan / slot data (or this file) and re-emit.
import os
import sys
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gallery_night_floors_ascii as P  # noqa: E402
import gallery_night_slots as S  # noqa: E402

OUT = os.path.join(S.ROOT, "game", "world", "heists", "gallery_night", "greybox", "gallery_night_layout.gd")
FFL = P.FLOOR_HEIGHTS
SLAB_T = 0.3
EXT_T = 0.4     # outer face 0.2 m out of the centre line (Site: outer face 44.4 x 30.4)
INT_T = 0.2
VAULT_T = 0.4
CORE_T = 0.3    # Stair SS / head house
PARAPET = 1.1

# Room list: id -> (ceiling above FFL (0 = open / shaft), kit). Ceiling heights from the Room list / vertical data.
ROOM_META: Dict[str, Tuple[float, str]] = {
    "SS": (0.0, ""), "LF": (0.0, ""), "HH": (2.7, ""), "LM": (2.7, "lift_motor_room"), "X4": (0.0, "exterior_roof"),
    "LK": (3.0, "locker_room"), "FR": (3.0, "storage_frames"), "QR": (3.0, "storage_quarantine"),
    "BB": (3.0, "corridor_service"), "PL": (3.4, "plant_climate"), "AS": (3.4, "art_store"),
    "BR": (3.0, "break_room"), "WC": (3.0, "restroom_multi"), "SC": (3.0, "security_office"),
    "RG": (3.0, "office_registrar"), "J": (3.0, "janitor_gallery"), "E1": (3.0, "electrical_closet"),
    "BC": (3.0, "corridor_service"), "LD": (4.5, "loading_dock_gallery"), "GH": (9.8, "great_hall_gala"),
    "VE": (4.5, "vestibule_bronze"), "CK": (4.5, "cloakroom"), "GS": (4.5, "gift_shop"), "WG": (4.5, "gallery_hang"),
    "DC": (4.5, "gallery_cabinet"), "PWW": (3.0, "restroom_public"), "PWM": (3.0, "restroom_public"),
    "EG": (4.5, "gallery_hang"), "EB": (4.5, "gallery_hang"), "UC": (3.0, "corridor_office"),
    "CO": (3.0, "office_curator"), "AO": (3.0, "office_development"), "SV": (3.0, "server_room"),
    "UW": (3.0, "restroom_single"), "FS": (3.0, "storage_frames"), "CS": (4.0, "conservation_studio"),
    "BW": (4.4, "gallery_balcony"), "BE": (4.4, "gallery_balcony"), "SL": (4.4, "gallery_balcony"),
    "UG1": (6.0, "gallery_toplit"), "UG2": (6.0, "gallery_toplit"), "UG3": (6.0, "gallery_toplit"),
    "AT": (3.0, "attendant_station"), "TR": (4.0, "treasury_cabinet"),
}
# Roof / slab-above top (absolute) per upper room: the north strip under the roof deck slab (8.7-9.0), the Great
# Hall group under its roof (10.7-11.0), the galleries under the laylight attic (placeholder flat roof 11.4-11.7),
# CS / AT / TR under their own roofs.
U_TOP = {"CO": 9.0, "AO": 9.0, "UW": 9.0, "FS": 9.0, "SV": 9.0, "LF": 9.0, "UC": 9.0, "SS": 9.0,
         "BW": 11.0, "BE": 11.0, "SL": 11.0, "GH_VOID": 11.0, "UG1": 11.7, "UG2": 11.7, "UG3": 11.7,
         "CS": 9.7, "AT": 9.7, "TR": 9.7}
ROOF_DECK_ROOMS = {"CO", "AO", "UW", "FS", "SV", "LF", "UC", "SS"}
PUBLIC_ROOMS = ["GH", "VE", "CK", "WG", "DC", "PWW", "PWM", "EG", "EB"]   # until last call (+ X1, X3)

# --- G1 to-dos (GN-C1): site, closures, police islands, the areaway, the oculus. Doc: Site, Play-space closure,
# Police spawns (D-064 / QC-41), Basement notes (QC-64). Rects [x0, z0, x1, z1]; boxes [x0, y0, z0, x1, y1, z1].
# Openings the plan grid cannot carry (the areaway passage is outside the basement footprint, QC-64).
EXTRA_OPENINGS = [("B", "D", 0.0, 13.5, 0.0, 14.5, "areaway passage into PL (QC-64)")]
# Areaway light well (QC-64): a 2 x 2 m well at x -4..-2, z 13..15 under the court grate, its floor at the PL FFL,
# and a passage (x -2..-0.2, roofed by the court grade) to the 1.0 m opening in the basement wall at x 0.
AREAWAY = {"well": [-4.0, 13.0, -2.0, 15.0], "pit": [-4.0, 13.0, -0.2, 15.0], "wall_t": 0.2, "floor_y": -4.2,
           "ladder": [-3.85, -4.2, 14.0]}
# No grade over these rects (per exterior room): the light well (the grate is the `areaway` slot's prefab).
SITE_HOLES = {"X3": [[-4.0, 13.0, -2.0, 15.0]]}
# Grade in play outside the exterior rooms: the Parade east end (x 58..70) to the press-van barriers (Play-space
# closure).
GRADE_EXTRA = [["ParadeEast", "asphalt", [58.0, 30.0, 70.0, 50.0]]]
# Police street islands behind the closures (QC-42 / D-064: never inside the building): [spawn, island grade, link
# from (island), link to (play side)]. An island joins play only through its one-way link (the police open the
# barrier / gate); its spawn carries meta police_only, so reachability is checked spawn -> crew.
POLICE_ISLANDS = [
    ["P1", [-54.0, 30.0, -40.4, 50.0], [-42.0, 0.0, 33.0], [-38.8, 0.0, 33.0]],
    ["P2", [70.4, 30.0, 84.0, 50.0], [72.0, 0.0, 34.0], [68.5, 0.0, 34.0]],
    ["P3", [44.0, -34.0, 58.0, -22.4], [46.0, 0.0, -23.5], [46.0, 0.0, -20.5]],
    ["P4", [-54.0, -8.0, -40.4, 0.0], [-42.0, 0.0, -2.0], [-38.8, 0.0, -2.0]],
]
# Play-space closures and neighbour massing (greybox): [name, box, surface class]. Every top is out of jump reach
# (> 1.18 m above the play mesh), so the `slopes` rule holds without copings.
CLOSURES = [
    ["ParadeWBarriers", [-40.4, 0.0, 30.0, -40.0, 2.2, 50.0], "trim"],
    ["GalaCoach", [-43.4, 0.0, 36.0, -40.8, 3.2, 48.0], "prop"],
    ["ParadeEBarriers", [70.0, 0.0, 30.0, 70.4, 2.2, 50.0], "trim"],
    ["PressVan", [70.8, 0.0, 40.0, 73.2, 2.8, 46.0], "prop"],
    ["WexleyNBarriers", [44.0, 0.0, -22.4, 58.0, 2.2, -22.0], "trim"],
    ["CateringTruck", [50.0, 0.0, -26.0, 56.0, 3.4, -23.2], "prop"],
    ["MewsGate", [-40.4, 0.0, -8.0, -40.0, 2.4, 0.0], "door"],
    ["MewsHouses", [-40.0, 0.0, -16.0, 43.8, 7.0, -8.0], "wall_ext"],
    ["GrandWexleyHotel", [58.4, 0.0, -34.0, 70.0, 22.0, 30.0], "wall_ext"],
    ["OstranderConservatory", [-40.0, 0.0, 0.4, -16.4, 14.0, 30.0], "wall_ext"],
    ["CourtWallW", [-16.4, 0.0, 0.0, -16.0, 3.0, 30.0], "wall_ext"],
    ["CourtWallN", [-16.0, 0.0, 0.0, -0.2, 3.0, 0.4], "wall_ext"],
    ["CourtWallSW", [-16.0, 0.0, 29.6, -10.0, 3.0, 30.0], "wall_ext"],
    ["CourtWallSE", [-6.0, 0.0, 29.6, -0.2, 3.0, 30.0], "wall_ext"],
    ["ParkRailings", [-40.0, 0.0, 50.0, 70.0, 1.8, 50.1], "trim"],
]
# Great Hall oculus (22, 17): a 3 x 3 m glazed opening through the laylight (+9.8) and the roof (+11.0). P5's one-way
# rappel link drops through it to the hall floor (QC-41); a second one-way link drops from the hall roof's north-east
# edge onto the roof deck (doc Police spawns); the areaway link is the Phantom flank (nav layer `vent`).
OCULUS = [20.5, 15.5, 23.5, 18.5]
NAV_LINKS = [
    ["RappelLinkOculus", [22.0, 11.0, 17.0], [22.0, 0.0, 17.0], False, 1],
    ["RoofDropLinkDeck", [30.5, 11.0, 8.8], [30.5, 9.0, 7.0], False, 1],
    ["AreawayLink", [-5.0, 0.0, 14.0], [-3.0, -4.2, 14.0], True, 4],
]


def room_top(fl: str, rid: Optional[str]) -> float:
    if rid is None:
        return -1e9
    if fl == "B":
        return FFL["G"] - SLAB_T
    if fl == "G":
        return FFL["U"] if rid == "GH" else FFL["U"] - SLAB_T
    if fl == "U":
        return U_TOP[rid]
    return FFL["R"] + 2.7 + SLAB_T if rid in ("HH", "LM") else FFL["R"]


def on_vault(fl: str, e: Tuple[int, int, int, int]) -> bool:
    for (x0, z0, x1, z1) in P.VAULT.get(fl, []):
        if x0 == x1 == e[0] == e[2] and z0 <= e[1] and e[3] <= z1:
            return True
        if z0 == z1 == e[1] == e[3] and x0 <= e[0] and e[2] <= x1:
            return True
    return False


def wall_runs(fl: str) -> List[list]:
    """Merged straight wall runs: [axis, fixed, a0, a1, thickness, y0, y1] (absolute heights)."""
    c = P.cells(fl)
    rows = []
    for e in sorted(P.walls(fl)):
        s0, s1 = P.sides(c, e)
        ext = s0 is None or s1 is None
        t = EXT_T if ext else VAULT_T if on_vault(fl, e) else CORE_T if {s0, s1} & {"SS", "HH"} else INT_T
        top = max(room_top(fl, s0), room_top(fl, s1))
        if ext and fl in ("B", "G"):   # the facade runs past the slab edge to the next FFL (no slot at the slab)
            top = FFL["G"] if fl == "B" else FFL["U"]
        if ext and fl == "U":
            inner = s0 or s1
            top = top if inner in ROOF_DECK_ROOMS else top + PARAPET
        if ext and fl == "R" and (s0 or s1) == "X4":
            top = FFL["R"] + (1.2 if e[0] == e[2] == 32 else PARAPET)   # 1.2 m by the sawtooth (B4.5)
        axis, fixed, a = ("z", e[0], e[1]) if e[0] == e[2] else ("x", e[1], e[0])
        rows.append([axis, float(fixed), float(a), float(a + 1), t, FFL[fl], round(top, 3)])
    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    out: List[list] = []
    for r in rows:
        if out and out[-1][0] == r[0] and out[-1][1] == r[1] and out[-1][3] == r[2] and out[-1][4:] == r[4:]:
            out[-1][3] = r[3]
        else:
            out.append(list(r))
    return out


def opening_heights(fl: str, k: str, note: str) -> Tuple[float, float]:
    if k == "D":
        return 0.0, 2.1
    if k in ("A", "S"):
        return 0.0, 3.6
    if k == "R":
        return 0.0, 4.5
    if k == "V":
        return 0.0, 2.2
    if k == "h":
        return 0.0, PARAPET + 0.5
    if "shop-front" in note:
        return 0.3, 3.6
    if "tall window" in note:
        return 0.9, 3.6
    if fl == "U" and note.startswith("CS"):
        return 0.9, 3.4
    return 0.9, 2.4


def fmt(v: object) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = "%.3f" % v
        s = s.rstrip("0")
        return s + "0" if s.endswith(".") else s
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join("%s: %s" % (fmt(k), fmt(x)) for k, x in v.items()) + "}"
    raise TypeError(v)


WIDTH = 124   # gdlint max-line-length 140 (a tab counts as one column)


def pp(v: object, depth: int) -> str:
    """fmt(), broken over lines (one element per line) where a line would pass WIDTH."""
    one = fmt(v)
    if depth + len(one) <= WIDTH or not isinstance(v, (list, tuple, dict)):
        return one
    tabs = "\t" * (depth + 1)
    if isinstance(v, dict):
        items = ["%s: %s" % (fmt(k), pp(x, depth + 1)) for k, x in v.items()]
        return "{\n" + "".join(tabs + it + ",\n" for it in items) + "\t" * depth + "}"
    return "[\n" + "".join(tabs + pp(x, depth + 1) + ",\n" for x in v) + "\t" * depth + "]"


def wrap_doc(doc: str) -> str:
    out, line = "", "##"
    for w in doc.split():
        if len(line) + 1 + len(w) > WIDTH:
            out += line + "\n"
            line = "##"
        line += " " + w
    return out + line + "\n"


def const(name: str, rows: object, typ: str = "Array", doc: str = "") -> str:
    out = wrap_doc(doc) if doc else ""
    head = "const %s: %s = " % (name, typ)
    if isinstance(rows, list) and len(head) + len(fmt(rows)) > WIDTH:
        out += head + "[\n"
        for r in rows:
            out += "\t%s,\n" % pp(r, 1)
        return out + "]\n"
    if isinstance(rows, dict) and len(head) + len(fmt(rows)) > WIDTH:
        return out + head + "{\n" + "".join("\t%s: %s,\n" % (fmt(k), pp(x, 1)) for k, x in rows.items()) + "}\n"
    return out + head + pp(rows, 0) + "\n"


def emit() -> str:
    fl_idx = {f: i for i, f in enumerate(P.FLOORS)}
    hdr = (
        "## Gallery Night greybox layout data. GENERATED by tools/levelcheck/plans/gallery_night_emit_layout.py from\n"
        "## gallery_night_floors_ascii.py (rooms, openings) and gallery_night_slots.py (slots, cameras, spawns, zones,\n"
        "## preplan points, review cameras). Do not edit: change the plan data and re-emit. Owner: ENV C (GN-C1).\n"
        "## Coordinates: metres, world x = plan x (east), world z = plan z (south), +y up; origin = the gallery's NW\n"
        "## corner on the wall centre lines. Heights are absolute (FFL B -4.2, G 0.0, U 5.4, R 9.0).\n"
        "extends RefCounted\n\n"
    )
    s = hdr
    s += "const FLOORS: Array[String] = %s\n" % fmt(list(P.FLOORS))
    s += "const FLOOR_HEIGHTS: Array[float] = %s\n" % fmt([float(FFL[f]) for f in P.FLOORS])
    s += "## HeistMap.floor_names (D-054), parallel to FLOOR_HEIGHTS.\n"
    s += 'const FLOOR_NAMES: Array[String] = ["Basement", "Ground", "Upper", "Roof"]\n'
    s += "const FFL: Dictionary = %s\n" % fmt({f: float(FFL[f]) for f in P.FLOORS})
    s += "const SLAB_T: float = %s\nconst EXT_T: float = %s\nconst INT_T: float = %s\n" % (fmt(SLAB_T), fmt(EXT_T),
                                                                                        fmt(INT_T))
    s += const("FOOT", {f: [float(v) for v in P.FOOT[f]] for f in P.FLOORS}, "Dictionary") + "\n"
    rooms = []
    for f in P.FLOORS:
        for rid, purpose, r in P.ROOMS[f]:
            ceil, kit = ROOM_META[rid]
            rooms.append([f, rid, purpose, float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(ceil), kit])
    s += const("ROOMS", rooms, doc="[floor, id, RoomVolume.purpose, x0, z0, x1, z1, ceiling above FFL (0 = open), kit].")
    ext = []
    for rid, rects in S.EXTERIOR.items():
        for r in rects:
            ext.append([rid, S.EXTERIOR_PURPOSE[rid], [float(v) for v in r], S.EXTERIOR_KIT[rid]])
    s += const("EXTERIOR", ext, doc="Exterior rooms at grade: [id, purpose, [x0, z0, x1, z1], kit].")
    s += const("VOIDS", [[f, v[0], [float(x) for x in v[1]]] for f in P.FLOORS for v in P.VOID.get(f, [])],
               doc="No floor on this level: [floor, id, [x0, z0, x1, z1]].")
    s += "const PUBLIC_ROOMS: Array[String] = %s\n" % fmt(PUBLIC_ROOMS)
    s += "const ROOF_DECK_ROOMS: Array[String] = %s\n" % fmt(sorted(ROOF_DECK_ROOMS))
    s += const("U_TOP", {k: float(v) for k, v in U_TOP.items()}, "Dictionary",
               "Roof slab top per upper room (absolute; the slab is SLAB_T thick).") + "\n"
    walls = [[f] + r for f in P.FLOORS for r in wall_runs(f)]
    s += const("WALLS", walls, doc="Wall runs from the room edges: [floor, axis (x: along x at z = fixed; z: along z at "
               "x = fixed), fixed, a0, a1, thickness, y0, y1].")
    ops = []
    for (f, k, x0, z0, x1, z1, note) in list(P.OPEN) + EXTRA_OPENINGS:
        sill, head = opening_heights(f, k, note)
        axis, fixed, a0, a1 = ("z", x0, z0, z1) if x0 == x1 else ("x", z0, x0, x1)
        ops.append([f, k, axis, float(fixed), float(a0), float(a1), round(FFL[f] + sill, 3), round(FFL[f] + head, 3),
                    note.split(":")[0].split(" (")[0][:60]])
    s += const("OPENINGS", ops, doc="Openings: [floor, kind (D door, A arch, S shuttered arch, R roller, V vault, W "
               "window, h ladder top), axis, fixed, a0, a1, y0, y1, note]. Glass in W.")
    rails = []
    for f in P.FLOORS:
        for (x0, z0, x1, z1) in P.RAIL.get(f, []):
            axis, fixed, a0, a1 = ("z", x0, z0, z1) if x0 == x1 else ("x", z0, x0, x1)
            spans = [[float(a0), float(a1)]]
            if axis == "z":   # the return-flight landings (z 14.4-16.4) join the balconies through the rail
                spans = [[float(a0), 14.4], [16.4, float(a1)]]
            for sp in spans:
                rails.append([f, axis, float(fixed), sp[0], sp[1], FFL[f], FFL[f] + PARAPET])
    s += const("RAILS", rails, doc="Balustrades (1.1 m): [floor, axis, fixed, a0, a1, y0, y1].")
    ss = [[st[1], st[2], st[4], st[5]] for st in P.STAIRS if st[0] == "SS"]
    s += "## Stair SS (service U-stair) in the core %s: per storey [y0, y1, risers per flight, riser]; tread 0.28, flights\n" \
         "## 1.2 wide (west up-flight x 0.15-1.35 rising north, well 1.35-1.55, east return flight 1.55-2.75 rising south),\n" \
         "## first riser line z 6.35 (the floor landing z 6.35-7.85 takes the 1.0 m stair door at z 6.5-7.5).\n" % (P.SS,)
    s += "const SS_RECT: Array = %s\n" % fmt([float(v) for v in P.SS])
    s += "const SS_STOREYS: Array = %s\n" % fmt([[float(a), float(b), int(m), float(r)] for a, b, m, r in ss])
    s += "const SS_TREAD: float = 0.28\nconst SS_Z_START: float = 6.35\nconst SS_CLEAR: Array = [0.15, 0.15, 2.85, 7.85]\n"
    s += "const SS_WEST: Array = [0.15, 1.35]\nconst SS_EAST: Array = [1.55, 2.75]\nconst SS_WELL: Array = [1.35, 1.55]\n\n"
    s += ("## Grand (imperial) stair (vertical data): central flight x 20.8-23.2 rising north from z 14.4 to the half\n"
          "## landing (z 8.2-10.2, x 15.0-29.0, +2.7); return flights x 15.0-16.6 / x 27.4-29.0 rising south to z 14.4 onto\n"
          "## the balcony landings (z 14.4-16.4, +5.4). 15 risers @ 0.18, tread 0.30 per flight.\n")
    s += const("GRAND", {
        "risers": 15, "riser": 0.18, "tread": 0.30, "z_foot": 14.4, "z_land": 10.2, "half_landing": [15.0, 8.2, 29.0, 10.2],
        "central": [20.8, 23.2], "returns": [[15.0, 16.6], [27.4, 29.0]], "upper_landing_z": [14.4, 16.4]}, "Dictionary") + "\n"
    s += const("AREAWAY", AREAWAY, "Dictionary", "Areaway light well + passage into PL (QC-64); rects [x0, z0, x1, z1].")
    s += const("SITE_HOLES", SITE_HOLES, "Dictionary", "No grade over these rects (per exterior room).")
    s += const("GRADE_EXTRA", GRADE_EXTRA, doc="Grade in play outside the exterior rooms: [name, surface, [x0, z0, x1, z1]].")
    s += const("POLICE_ISLANDS", POLICE_ISLANDS, doc="Police street islands: [spawn, grade [x0, z0, x1, z1], one-way link "
               "from (island), to (play)].")
    s += const("CLOSURES", CLOSURES, doc="Play-space closures / neighbour massing: [name, [x0, y0, z0, x1, y1, z1], surface].")
    s += "const OCULUS: Array = %s\n" % fmt(OCULUS)
    s += const("NAV_LINKS", NAV_LINKS, doc="Always-present nav links: [name, from, to, bidirectional, navigation_layers] "
               "(1 walkable, 4 vent).") + "\n"
    slots = []
    for g, sid, w, f, rid, x, z, y, yaw, note in S.SLOTS:
        slots.append([g, sid, float(w), f, rid, float(x), round(FFL[f] + y, 3), float(z), float(yaw), sid in S.WALL_HUNG,
                      g in S.USE_POINT_GROUPS, note])
    s += const("SLOTS", slots, doc="VariantSlots (resolver order): [group, slot_id, weight, floor, room, x, y, z, yaw (front "
               "-Z), wall-hung, has a UsePoint, note].")
    s += "const USE_POINT_M: float = %s\n" % fmt(float(S.USE_POINT_M))
    s += const("GROUP_ORDER", S.GROUP_ORDER, "Array[String]")
    cams = [[cid, r[0], r[1], float(r[2]), round(FFL[r[0]] + r[4], 3), float(r[3]), list(r[5])] for cid, r in S.CAMERAS.items()]
    s += const("CAMERAS", cams, doc="Security cameras: [id, floor, room, x, mount y, z, layouts (cam_* slots or always)].")
    s += "const CAMERA_SPINE_ROOMS: Array[String] = %s\n" % fmt(list(S.CAMERA_SPINE_ROOMS))
    s += "const CAMERA_SCREEN_SLOTS: Array[String] = %s\n" % fmt(list(S.CAMERA_SCREEN_SLOTS))
    s += const("SCREENS", [[r, float(a), float(b), float(c), float(d)] for r, a, b, c, d in S.SCREENS],
               doc="Partition screens (2.4 m, meta kind partition_screen): [room, x0, z0, x1, z1] on the upper floor.")
    s += const("PLAYER_SPAWNS", [[nm, tag, f, rid, float(x), FFL[f], float(z), float(yaw)]
                                 for nm, tag, f, rid, x, z, yaw in S.PLAYER_SPAWNS],
               doc="PLAYER spawns: [name, spawn_tag (\"\" = default), floor, room, x, y, z, yaw].")
    s += const("POLICE_SPAWNS", [[nm, tag, float(x), float(y), float(z)] for nm, tag, x, z, y in S.POLICE_SPAWNS],
               doc="POLICE spawns: [name, tag, x, y, z] (outside the play space; P5 on the Great Hall roof).")
    s += const("ESCAPE_ZONES", [[sl, k, f, rid, float(x), FFL[f], float(z)] for sl, k, f, rid, x, z in S.ESCAPE_ZONES],
               doc="Escape / secure zones (children of their escape slot): [slot, kind, floor, room, x, y, z].")
    s += const("PREPLAN", [[pid, cat, fi, f, rid, float(x), FFL[f], float(z), params]
                           for pid, cat, fi, f, rid, x, z, params in S.PREPLAN],
               doc="PREPLAN_POINT markers: [id, category, floor index, floor, room, x, y, z, params].")
    s += const("REVIEW_CAMERAS", [[rc[0], rc[1], rc[2], float(rc[3]), round(FFL[rc[1]] + rc[5], 3), float(rc[4]),
                                   float(rc[6]), round(FFL[rc[1]] + rc[8], 3), float(rc[7])] for rc in S.REVIEW_CAMERAS],
               doc="Review cameras: [id, floor, room, x, y, z, look-at x, y, z].")
    _ = fl_idx
    return s


if __name__ == "__main__":
    text = emit()
    if "--stdout" in sys.argv:
        sys.stdout.write(text)
    else:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        with open(OUT, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("wrote %s (%d lines)" % (os.path.relpath(OUT, S.ROOT), text.count("\n")))
