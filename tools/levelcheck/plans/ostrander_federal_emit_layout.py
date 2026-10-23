# Emits game/world/heists/ostrander_federal/greybox/ostrander_federal_layout.gd (the generator's data) from the floor plans
# (ostrander_federal_floors_ascii.py), the slot / contract-node list (ostrander_federal_slots.py), the content rows
# (ostrander_federal_content.py) and the shell primitives (ostrander_federal_geometry.py). Owner: ENV C (OF-C1).
# Run: python3 tools/levelcheck/plans/ostrander_federal_emit_layout.py            (writes both .gd files)
#      python3 tools/levelcheck/plans/ostrander_federal_emit_layout.py --stdout [--content]   (prints one)
# Two outputs (the 1500-line file rule): ostrander_federal_layout.gd (shell, site, rooms) and
# ostrander_federal_layout_content.gd (slots, cameras, doors, spawns, items, graphs, tactical).
# Deterministic: plain lists in source order, fixed float formatting. Never hand-edit the output; change the plan data
# (or these modules) and re-emit. All heights in the output are absolute.
import os
import sys
from typing import Dict, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostrander_federal_content as C  # noqa: E402
import ostrander_federal_floors_ascii as P  # noqa: E402
import ostrander_federal_geometry as GM  # noqa: E402
import ostrander_federal_slots as S  # noqa: E402

OUT_DIR = os.path.join(S.ROOT, "game", "world", "heists", "ostrander_federal", "greybox")
OUT = os.path.join(OUT_DIR, "ostrander_federal_layout.gd")
OUT_CONTENT = os.path.join(OUT_DIR, "ostrander_federal_layout_content.gd")
FFL = P.FLOOR_HEIGHTS
WIDTH = 124


def fmt(v: object) -> str:
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = "%.3f" % v
        if s == "-0.000":
            s = "0.000"
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


def pp(v: object, depth: int) -> str:
    """fmt(), broken over lines where a line would pass WIDTH: list elements are packed several per line."""
    one = fmt(v)
    if depth + len(one) <= WIDTH or not isinstance(v, (list, tuple, dict)):
        return one
    tabs = "\t" * (depth + 1)
    if isinstance(v, dict):
        items = ["%s: %s" % (fmt(k), pp(x, depth + 1)) for k, x in v.items()]
        return "{\n" + "".join(tabs + it + ",\n" for it in items) + "\t" * depth + "}"
    lines: list = []
    cur = ""
    for x in v:
        part = pp(x, depth + 1)
        if "\n" in part:
            if cur:
                lines.append(cur)
                cur = ""
            lines.append(part + ",")
            continue
        cand = (cur + " " if cur else "") + part + ","
        if cur and depth + 1 + len(cand) > WIDTH:
            lines.append(cur)
            cur = part + ","
        else:
            cur = cand
    if cur:
        lines.append(cur)
    return "[\n" + "".join(tabs + ln + "\n" for ln in lines) + "\t" * depth + "]"


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


def absy(f: str, p: list) -> list:
    return [float(p[0]), round(FFL[f] + p[1], 3), float(p[2])]


def item(it: list) -> list:
    """A content row with absolute positions (see ostrander_federal_content.py for the formats)."""
    k = it[0]
    if k == "prefab":
        _k, kind, name, f, pos, yaw, props, use, metas, vis = it
        return ["prefab", kind, name, absy(f, pos), float(yaw), props, absy(f, use) if use is not None else None, metas,
                vis]
    if k == "spawn":
        _k, name, kind, f, pos, yaw, tags, idle, graph, seat = it
        return ["spawn", name, kind, absy(f, pos), float(yaw), tags, idle, graph, seat]
    if k == "box":
        _k, name, f, base, size, yaw, kind, support, mat, metas = it
        return ["box", name, absy(f, base), [float(v) for v in size], float(yaw), kind, support, mat, metas]
    if k == "marker":
        _k, name, f, pos, yaw, tag, todo = it
        return ["marker", name, absy(f, pos), float(yaw), tag, todo]
    if k == "route":
        _k, name, rid, order, tags, start, stops = it
        return ["route", name, rid, order, tags, start, [[st[0], absy(st[1], st[2]), [float(st[3][0]), float(st[3][1])],
                                                          st[4], st[5], None if st[6] is None else float(st[6])]
                                                         for st in stops]]
    if k == "tac":
        _k, name, kind, f, pos, yaw, tags, breach = it
        return ["tac", name, kind, absy(f, pos), float(yaw), tags, breach]
    raise ValueError(it)


def emit() -> tuple:
    hdr = (
        "## Ostrander Federal greybox layout data. GENERATED by tools/levelcheck/plans/ostrander_federal_emit_layout.py from\n"
        "## ostrander_federal_floors_ascii.py (rooms, openings), ostrander_federal_slots.py (slots, cameras, spawns, zones,\n"
        "## preplan points, review cameras, site), ostrander_federal_content.py (doors, furniture, prefabs, spawns, patrols,\n"
        "## tactical) and ostrander_federal_geometry.py (shell primitives). Do not edit: change the plan data and re-emit.\n"
        "## Owner: ENV C (OF-C1). Metres; world x = plan x (east), z = plan z (south), +y up; origin = the bank's NW corner on\n"
        "## the wall centre lines. Heights are absolute (FFL B -4.0, G 0.0, M 5.0, E 8.6, R 12.2).\n"
        "extends RefCounted\n\n"
    )
    s = hdr
    s += "const FLOORS: Array[String] = %s\n" % fmt(list(P.FLOORS))
    s += "const FLOOR_HEIGHTS: Array[float] = %s\n" % fmt([float(FFL[f]) for f in P.FLOORS])
    s += "## HeistMap.floor_names (D-054), parallel to FLOOR_HEIGHTS.\n"
    s += "const FLOOR_NAMES: Array[String] = %s\n" % fmt([P.FLOOR_NAMES[f] for f in P.FLOORS])
    s += "const FFL: Dictionary = %s\n" % fmt({f: float(FFL[f]) for f in P.FLOORS})
    s += const("FOOT", {f: [float(v) for v in P.FOOT[f]] for f in P.FLOORS}, "Dictionary") + "\n"
    rooms = []
    for f in P.FLOORS:
        for rid, purpose, r in P.ROOMS[f]:
            rooms.append([f, rid, purpose, [float(v) for v in r], float(GM.ROOM_CEIL.get(rid, 0.0)),
                          GM.ROOM_KIT.get(rid, ""), [float(v) for v in GM.OVERRIDES.get(rid, [])]])
    s += const("ROOMS", rooms, doc="[floor, id, RoomVolume.purpose, [x0, z0, x1, z1], ceiling above FFL (0 = open), kit, "
               "ceiling_range override ([] = none)]. An id may have several rects.")
    s += const("EXTERIOR", [[rid, "exterior", [float(v) for v in r], S.EXTERIOR_KIT[rid]] for rid, rects in
                            S.EXTERIOR.items() for r in rects],
               doc="Exterior rooms at grade: [id, purpose, [x0, z0, x1, z1], kit].")
    s += const("VOIDS", [[f, v[0], [float(x) for x in v[1]]] for f in P.FLOORS for v in P.VOID.get(f, [])],
               doc="No floor on this level: [floor, id, [x0, z0, x1, z1]].")
    s += "const PUBLIC_ROOMS: Array[String] = %s\n" % fmt(S.PUBLIC_ROOMS)
    s += const("WALLS", GM.walls(), doc="Wall runs: [floor, axis (x: along x at z = fixed; z: along z at x = fixed), fixed, "
               "a0, a1, thickness, y0, y1, surface class, holes [[a0, a1, y0, y1]]].")
    s += const("PANES", GM.panes(), doc="Window glass: [name, min, max].")
    s += const("SLABS", GM.slabs(), doc="Slabs and roofs: [name, outer [x0, z0, x1, z1], holes, y0, y1, class].")
    s += const("CEILINGS", GM.ceilings(), doc="Ceiling planes (0.05 m): [name, [x0, z0, x1, z1], y].")
    s += "const CEIL_T: float = %s\n" % fmt(GM.CEIL_T)
    lb, lhull = GM.lantern()
    fb, fhull = GM.fire_escape()
    flights, sboxes, srails = GM.stairs()
    gboxes, ghulls, gflights = GM.site()
    shell = GM.sills() + GM.hall() + GM.cages() + lb + sboxes + fb
    s += const("SHELL_BOXES", shell, doc="Shell boxes (Geometry/Building/<group>): [group, name, min, max, class].")
    s += const("SITE_BOXES", gboxes, doc="Site boxes (Geometry/Site/<group>): grade, police islands, closures, neighbours.")
    cop = []
    for nm, axis, fixed, a0, a1, y, _t, prof in GM.copings():
        pts = []
        for a in (a0, a1):
            for q in prof:
                pts.append([GM.r3(a), GM.r3(y + q[1]), GM.r3(fixed + q[0])] if axis == "x"
                           else [GM.r3(fixed + q[0]), GM.r3(y + q[1]), GM.r3(a)])
        cop.append(["Coping", nm, pts, "wall_ext"])
    hulls = [[h[0], h[1], h[2], GM.hull_faces(h[2]), h[3]] for h in lhull + fhull + ghulls + cop]
    s += const("HULLS", hulls, doc="Convex hulls (collision + mesh): [group, name, points, faces (point-index polygons, "
               "counter-clockwise seen from outside), class]: the lantern glazing, the fire-escape flights / rails, the "
               "Tannery St ramp, the parapet copings (a 0.3 m ridge over the 0.2 m half wall: 56 deg >= 50, §7.5; the "
               "terrace east parapet's throw-spot coping falls 0.6 m outward from its 1.1 m inner edge: 56 deg, §7.4).")
    s += const("FLIGHTS", flights + gflights, doc="Stair flights (ramp collision, visual steps): [name, origin (first riser "
               "line), yaw, width, risers, riser, tread]; Stairs A / B (U-stairs, first riser z %.2f) and the plaza steps."
               % GM.Z_START)
    s += const("HANDRAILS", srails, doc="Handrails (5 cm bars): [name, from, to].")
    vis = [["Meridian", [23.95, 0.002, 17.5], [24.05, 0.006, 31.9], "trim"],
           # the grate east of DumpsterE's footprint (x <= 29.95; OF-C2: its casters z-fought the plate), over the vent
           ["AreawayGrate", [29.97, 0.002, -1.6], [30.63, 0.006, -0.4], "trim"]]
    s += const("VISUALS", vis, doc="Visual-only boxes (no collision): [name, min, max, class].")
    links = [["IslandLink" + p[0], p[3], p[4], False, 1] for p in S.POLICE_ISLANDS] + S.NAV_LINKS
    s += const("NAV_LINKS", links, doc="Always-present nav links: [name, from, to, bidirectional, navigation_layers] (1 "
               "walkable, 2 police-only rappels, 4 vent): the street islands' one-way links, P5's rappels, the lantern rappel, the areaway vent.")
    brs = [[nm, "window", "prop_breach_window", [float(bx), FFL["G"], round(bz - 0.2, 3)], 0.0, list(S.BREACH_SIZE),
            rid, 0.0] for nm, bx, bz, rid in S.BREACH_WINDOWS]
    brs += [[nm, "door", "", list(pos), float(yaw), list(size), rid, 0.0, door]
            for nm, pos, yaw, size, rid, door in S.BREACH_DOORS]
    s += const("ASSAULT_BREACHES", brs, doc="PO6-17 breaches (assault_markers.gd rows): [name, kind, scene id, room-side "
               "face pos, yaw, size, room, depth(, door: the map path of the Door a \"door\" breach blows open)].")
    s += const("OOB", S.OOB, doc="OUT_OF_BOUNDS curtains (D-040): [name, [x0, y0, z0, x1, y1, z1]].")
    slots = []
    for g, sid, w, f, rid, x, z, y, yaw, note in S.SLOTS:
        slots.append([g, sid, float(w), f, rid, float(x), round(FFL[f] + y, 3), float(z), float(yaw), note])
    s += const("SLOTS", slots, doc="VariantSlots (resolver order): [group, slot_id, weight (ENV B's block), floor, room, x, y, "
               "z, yaw, note].")
    s += const("GROUP_ORDER", S.GROUP_ORDER, "Array[String]")
    s += const("SLOT_PARAMS", C.SLOT_PARAMS, "Dictionary", "VariantSlot.params per slot (mission data).")
    cams = [[cid, r[0], r[1], [float(r[2]), round(FFL[r[0]] + r[4], 3), float(r[3])], float(r[5]), list(r[6]),
             float(r[7]) if len(r) > 7 else 40.0]
            for cid, r in S.CAMERAS.items()]
    s += const("CAMERAS", cams, doc="Security cameras: [id, floor, room, pivot (on its wall face), yaw, layouts, pan_deg].")
    s += "const CAMERA_SPINE_ROOMS: Array[String] = %s\n" % fmt(list(S.CAMERA_SPINE_ROOMS))
    doors = []
    for d in GM.resolved_doors():
        doors.append(d[:9])
    s += const("DOORS", doors, doc="Doors (lock table): [name, floor, origin (bottom-centre of the opening on the wall line), "
               "yaw (front -Z = UsePoint side), kind, lock (\"\" = per side_door slot), visual, width_m, extra].")
    s += const("SIDE_DOORS", C.SIDE_DOORS, "Dictionary", "side_door slot -> {door: [lock, extra]}.")
    s += const("SIDE_DOOR_EXTRA", C.SIDE_DOOR_EXTRA, "Dictionary")
    s += const("ROUTE_DOORS", C.ROUTE_DOORS, "Array[String]")
    lid = GM.lid()[0]
    s += const("ROUTES", {k: [item(i) for i in v] for k, v in C.ROUTE_ROWS.items()}, "Dictionary",
               "Civilian routes (OF-A4 CivilianRoute rows, see ostrander_federal_content.py): {parent path or slot id: rows}.")
    s += const("LID", {"origin": [round((C.HOLE[0] + C.HOLE[2]) * 0.5, 3), 0.0, round((C.HOLE[1] + C.HOLE[3]) * 0.5, 3)],
                       "plug": [lid[2], lid[3], lid[4]], "panel": [[C.LID[0], 0.002, C.LID[1]], [C.LID[2], 0.006, C.LID[3]],
                                                                   "trim"]},
               "Dictionary", "The lid (QC-61, OF-A6): a GameplayPrefab tagged `lid` at Gameplay/Devices/Lid holding the plug "
               "(Plug: the 1.2 x 2.2 m hole's 0.8 m slab body) and the marble panel (Visual/LidPanel); the hole's footprint "
               "is a permanent navmesh hole (projected obstruction), so nothing paths over it before or after the burn.")
    shell_text = s
    s = hdr.replace("layout data. GENERATED", "layout data, content half. GENERATED")
    s += const("PLAYER_SPAWNS", [[nm, tag, absy(f, [x, S.PLAZA_Y if rid == "X1" else 0.0, z]), float(yaw)]
                                 for nm, tag, f, rid, x, z, yaw in S.PLAYER_SPAWNS],
               doc="PLAYER spawns: [name, spawn_tag (\"\" = default), position, yaw].")
    s += const("POLICE_SPAWNS", [[nm, tag, [float(x), float(y), float(z)]] for nm, tag, x, z, y in S.POLICE_SPAWNS],
               doc="POLICE spawns (police-only islands): [name, tag, position].")
    s += const("PREPLAN", [[pid, cat, fi, absy(f, [x, S.PLAZA_Y if rid == "X1" else 0.0, z]), params]
                           for pid, cat, fi, f, rid, x, z, params in S.PREPLAN],
               doc="PREPLAN_POINT markers: [id, category, floor index, position, params].")
    rcs = [[rc[0], rc[2], [float(rc[3]), round(FFL[rc[1]] + rc[5] + (S.PLAZA_Y if rc[2] == "X1" else 0.0), 3),
                           float(rc[4])],
            [float(rc[6]), round(FFL[rc[1]] + rc[8], 3), float(rc[7])]] for rc in S.REVIEW_CAMERAS]
    s += const("REVIEW_CAMERAS", rcs, doc="Review cameras: [id, room, eye, look-at].")
    s += const("FURNITURE", [item(i) for i in C.FURNITURE], doc="Props/MapBuilt support boxes.")
    s += const("ALWAYS", {k: [item(i) for i in v] for k, v in C.ALWAYS.items()}, "Dictionary",
               "Always-present content: {parent path: rows}.")
    s += const("FIXED_SPAWNS", [item(i) for i in C.FIXED_SPAWNS])
    s += const("SLOT_ITEMS", {k: [item(i) for i in v] for k, v in C.SLOT_CONTENT.items()}, "Dictionary",
               "VariantSlot content: {slot_id: rows}.")
    lasers = {}
    for sid, lz in C.LASERS.items():
        d = dict(lz)
        lasers[sid] = d
    s += const("LASERS", lasers, "Dictionary", "laser_pattern slots: the grid at x %.1f across VC (floor %.1f)."
               % (C.LASER_X, FFL["B"]))
    s += "const LASER_X: float = %s\nconst LASER_FLOOR: float = %s\n" % (fmt(C.LASER_X), fmt(float(FFL["B"])))
    graphs = {}
    for gname, (gid, fi, pts, edges) in C.GRAPHS.items():
        rows = {pn: [absy(p[0], [p[1], S.PLAZA_Y if p[0] == "G" and p[2] > 38.0 else 0.0, p[2]]), [float(p[3][0]),
                                                                                                  float(p[3][1])],
                     p[4], p[5], p[6]] for pn, p in pts.items()}
        graphs[gname] = [gid, fi, rows, edges]
    s += const("GRAPHS", graphs, "Dictionary", "Patrol graphs: name -> [graph_id, floor index, {point: [position, pause, "
               "anim, tags, facing yaw or null]}, edges].")
    s += const("LINES", [[nm, metas, [absy(f, [x, 0.0, z]) for f, x, z in pts]] for nm, metas, pts in C.LINES],
               doc="OF-C3 levelcheck lines (bag_line / hide_spot): [name, metas, points at the crew's feet].")
    s += const("MAP_METAS", {"laser_min_gap_m": 1.0, "laser_crouch_face_m": 1.215, "camera_layout_group": "camera"},
               "Dictionary", "HeistMap metas for levelcheck (OF-C3: lasers §7.1).")
    s += const("TACTICAL", [item(i) for i in C.TACTICAL], doc="TacticalPoints: police entries (breach_only), rappels, "
               "flanks, shield anchors, sniper perches S1-S3, COVER.")
    return shell_text, s


if __name__ == "__main__":
    texts = emit()
    if "--stdout" in sys.argv:
        sys.stdout.write(texts[0] if "--content" not in sys.argv else texts[1])
    else:
        os.makedirs(OUT_DIR, exist_ok=True)
        for path, text in ((OUT, texts[0]), (OUT_CONTENT, texts[1])):
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
            print("wrote %s (%d lines)" % (os.path.relpath(path, S.ROOT), text.count("\n")))
