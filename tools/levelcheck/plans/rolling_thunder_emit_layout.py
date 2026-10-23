# Emits game/world/heists/rolling_thunder/greybox/rolling_thunder_layout.gd (shell, site, rooms, zones) and
# rolling_thunder_layout_content.gd (doors, prefabs, spawns, slots, convoy sets, graphs, tactical, preplan, review
# cameras) from the --check plan scripts (rolling_thunder_floors_ascii / _site_ascii / _convoy / _slots) and the G1
# modules rolling_thunder_geometry.py (shell + site primitives) and rolling_thunder_content.py (content rows).
# Owner: ENV C (RT-C1). Copy-adapted from ostrander_federal_emit_layout.py.
# Run: python3 tools/levelcheck/plans/rolling_thunder_emit_layout.py                    (writes both .gd files)
#      python3 tools/levelcheck/plans/rolling_thunder_emit_layout.py --stdout [--content] (prints one)
#      python3 tools/levelcheck/plans/rolling_thunder_emit_layout.py --check              (exit 1 if a plan check
#                                                                                         fails or a file is stale)
# Deterministic: plain lists in source order, fixed float formatting. Never hand-edit the output; change the plan data
# (or these modules) and re-emit. All coordinates in the output are SITE coordinates, heights absolute.
import os
import sys
from typing import Dict, List, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_check as CHK  # noqa: E402
import rolling_thunder_content as C  # noqa: E402
import rolling_thunder_floors_ascii as P  # noqa: E402
import rolling_thunder_geometry as GM  # noqa: E402
import rolling_thunder_markings as MK  # noqa: E402
import rolling_thunder_slots as SL  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_DIR = os.path.join(ROOT, "game", "world", "heists", "rolling_thunder", "greybox")
OUT = os.path.join(OUT_DIR, "rolling_thunder_layout.gd")
OUT_CONTENT = os.path.join(OUT_DIR, "rolling_thunder_layout_content.gd")
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


# --------------------------------------------------------------------------------------------- rooms and zones
Rect = Tuple[float, float, float, float]


def rect_minus(outer: Rect, holes: List[Rect]) -> List[Rect]:
    """`outer` minus `holes` as disjoint rectangles (grid decomposition, rows merged), deterministic."""
    xs = sorted({outer[0], outer[2]} | {v for h in holes for v in (h[0], h[2]) if outer[0] < v < outer[2]})
    zs = sorted({outer[1], outer[3]} | {v for h in holes for v in (h[1], h[3]) if outer[1] < v < outer[3]})
    out: List[list] = []
    for j in range(len(zs) - 1):
        cz = (zs[j] + zs[j + 1]) / 2.0
        run = None
        for i in range(len(xs) - 1):
            cx = (xs[i] + xs[i + 1]) / 2.0
            inside = any(h[0] < cx < h[2] and h[1] < cz < h[3] for h in holes)
            if not inside and run is None:
                run = xs[i]
            if inside and run is not None:
                out.append([run, zs[j], xs[i], zs[j + 1]])
                run = None
        if run is not None:
            out.append([run, zs[j], xs[-1], zs[j + 1]])
    merged: List[list] = []
    for r in out:
        for m in merged:
            if m[0] == r[0] and m[2] == r[2] and abs(m[3] - r[1]) < 1e-9:
                m[3] = r[3]
                break
        else:
            merged.append(r)
    return [tuple(GM.r3(v) for v in r) for r in merged]


def _site(level: str, r: tuple) -> Rect:
    ox, oz = P.BUILDINGS[P.LEVEL_BUILDING[level]]
    return (r[0] + ox, r[1] + oz, r[2] + ox, r[3] + oz)


ROOM_KIT = {
    "CP-G": "car_park_deck",
    "CP-2": "car_park_deck",
    "CP-R": "car_park_roof",
    "AB": "attendant_booth",
    "CWC": "restroom_single",
    "CPL": "plant_carpark",
    "DR": "diner_dining",
    "K": "kitchen_commercial",
    "BC": "corridor_service",
    "ST": "storage_receiving",
    "E": "electrical_closet",
    "W1": "restroom_single",
    "W2": "restroom_single",
    "R": "corridor_service",
    "OF": "office_manager",
    "U1": "function_room",
    "U2": "storage_archive",
    "U3": "storage_receiving",
    "U4": "restroom_single",
    "J": "janitor_closet_of",
    "UC": "corridor_service",
    "U5": "break_room",
    "YD": "exterior_yard_small",
    "C1": "site_office",
    "C2": "break_room",
    "C3": "site_wc",
    "C4": "site_tool_store",
    "FG": "site_frame_ground",
    "F1": "site_frame_slab",
    "X1": "exterior_street_rt",
    "X2": "exterior_underpass",
    "X3": "exterior_plaza",
    "X4": "exterior_site",
    "X5": "exterior_lane",
    "X6": "exterior_street",
    "X7": "exterior_lane",
}
PUBLIC = ["X1", "X2", "X3", "X6", "CP-G", "CP-2", "CP-R", "STA", "SB", "LF", "R1R2", "DR", "W1", "W2"]
CEIL = {
    "AB": 2.7,
    "CWC": 2.7,
    "CPL": 2.7,
    "C1": GM.CABIN_TOP,
    "C2": GM.CABIN_TOP,
    "C3": GM.CABIN_TOP,
    "C4": GM.CABIN_TOP,
}


def rooms() -> List[list]:
    """[id, purpose, floor index, kit, boxes [[x0, y0, z0, x1, y1, z1]]]."""
    out = []
    strip = GM.CP_STRIP
    cpg = P.LEVELS["CP-G"]
    holes_g = [r.rect for r in cpg.rooms]
    deck_rows = [
        ("CP-G", "car_park", 1, holes_g, 0.0, 2.7),
        ("CP-2", "car_park", 2, [r.rect for r in P.LEVELS["CP-2"].rooms], 3.5, 6.2),
        ("CP-R", "roof", 3, [r.rect for r in P.LEVELS["CP-R"].rooms], 7.0, 10.0),
    ]
    for rid, purpose, fi, holes, y0, y1 in deck_rows:
        rects = rect_minus((0.0, 0.0, 36.0, 36.0), [tuple(float(v) for v in h) for h in holes])
        out.append([rid, purpose, fi, ROOM_KIT[rid], [[*_xy(_site("CP-G", r), y0, y1)] for r in rects]])
    for rid, rect in (("STA", P.STA), ("SB", P.SB), ("LF", P.LF)):
        out.append(
            [rid, "stair" if rid != "LF" else "elevator", 1, "", [_xy(_site("CP-G", rect), 0.0, GM.CP_HH_TOP)]]
        )
    out.append(["R1R2", "stair", 1, "", [_xy(_site("CP-G", strip), 0.0, 7.0)]])
    for rm in cpg.rooms:
        if rm.rid in ("AB", "CWC", "CPL"):
            out.append([rm.rid, rm.purpose, 1, ROOM_KIT[rm.rid], [_xy(_site("CP-G", rm.rect), 0.0, CEIL[rm.rid])]])
    # the diner: one volume per id (ST has two rects; SC spans both floors)
    for key, fi in (("DG", 1), ("DU", 2)):
        y = P.LEVEL_FFL[key]
        seen: Dict[str, list] = {}
        for rm in P.LEVELS[key].rooms:
            if rm.rid == "SC":
                if key == "DG":
                    out.append(["SC", "stair", 1, "", [_xy(_site("DG", rm.rect), 0.0, 6.7)]])
                continue
            if rm.rid == "YD":
                y1 = 6.0
            else:
                y1 = y + GM.CEIL_ROOMS[rm.rid]
            box = _xy(_site(key, rm.rect), y, y1)
            if rm.rid in seen:
                seen[rm.rid][4].append(box)
                continue
            row = [rm.rid, rm.purpose, fi, ROOM_KIT.get(rm.rid, ""), [box]]
            seen[rm.rid] = row
            out.append(row)
    # the site: cabins, the scaffold tower, FG / F1, the yard X4 (minus the cabins, the frame and the tower)
    sg = P.LEVELS["SG"]
    for rm in sg.rooms:
        if rm.rid in ("C1", "C2", "C3", "C4"):
            out.append([rm.rid, rm.purpose, 1, ROOM_KIT[rm.rid], [_xy(_site("SG", rm.rect), 0.0, CEIL[rm.rid])]])
    out.append(["STW", "stair", 1, "", [_xy(_site("SG", (24.0, 26.0, 28.0, 32.0)), 0.0, 4.6)]])
    frame = (10.0, 6.0, 34.0, 26.0)
    out.append(["FG", "exterior", 1, ROOM_KIT["FG"], [_xy(_site("SG", frame), 0.0, GM.SITE_SLAB[0])]])
    out.append(["F1", "exterior", 2, ROOM_KIT["F1"], [_xy(_site("SG", frame), GM.SITE_SLAB[1], 7.0)]])
    x4 = rect_minus((0.0, 0.0, 46.0, 45.0), [(2.0, 30.0, 14.0, 39.0), frame, (24.0, 26.0, 28.0, 32.0)])
    out.append(["X4", "exterior", 1, ROOM_KIT["X4"], [_xy(_site("SG", r), 0.0, 6.0) for r in x4]])
    # the streets (site coordinates)
    ext = {
        "X1": [
            ((-14.0, -92.0, 14.0, 72.0), -0.5, 7.5),
            ((-80.0, -11.0, -14.0, 11.0), -0.5, 7.5),
            ((14.0, -11.0, 34.0, 11.0), -0.5, 7.5),
            ((14.0, 11.0, 64.0, 14.0), -0.5, 7.5),
        ],
        "X2": [((34.0, -10.8, 104.0, 10.8), -5.5, 4.0)],
        "X3": [((-60.0, 11.0, -14.0, 30.0), -0.5, 7.5), ((-24.0, 30.0, -14.0, 50.0), -0.5, 7.5)],
        "X5": [((52.0, -90.0, 64.0, -14.0), -0.5, 6.0)],
        "X6": [
            ((14.0, -14.0, 64.0, -11.0), -0.5, 6.0),
            ((14.0, -56.0, 16.0, -14.0), -0.5, 6.0),
            ((16.0, -56.0, 52.0, -50.0), -0.5, 6.0),
        ],
        "X7": [((34.0, 32.0, 52.0, 40.0), -0.5, 6.0), ((50.0, 14.0, 52.0, 32.0), -0.5, 6.0)],
    }
    for rid, boxes in ext.items():
        out.append([rid, "exterior", 0 if rid == "X2" else 1, ROOM_KIT[rid], [_xy(r, a, b) for r, a, b in boxes]])
    return out


def _xy(r: Rect, y0: float, y1: float) -> list:
    return [GM.r3(r[0]), GM.r3(y0), GM.r3(r[1]), GM.r3(r[2]), GM.r3(y1), GM.r3(r[3])]


def zones(rms: List[list]) -> Dict[str, list]:
    pub, res = [], []
    for rid, _p, _f, _k, boxes in rms:
        (pub if rid in PUBLIC else res).extend(boxes)
    return {"public": pub, "restricted": res}


# --------------------------------------------------------------------------------------------- emit
def emit() -> tuple:
    hdr = (
        "## Rolling Thunder greybox layout data. GENERATED by tools/levelcheck/plans/rolling_thunder_emit_layout.py"
        " from\n"
        "## the --check plan scripts (rolling_thunder_floors_ascii / _site_ascii / _convoy / _slots)"
        " and the G1 modules\n"
        "## rolling_thunder_geometry.py (shell + site primitives) and rolling_thunder_content.py (content rows).\n"
        "## Do not edit: change the plan data and re-emit. Owner: ENV C (RT-C1). Site coordinates:"
        " origin = the junction\n"
        "## centre, +x east, +z south, metres; heights absolute (Underpass -5.0, Street 0.0, Upper 3.5, Roof 7.0).\n"
        "extends RefCounted\n\n"
    )
    s = hdr
    s += "const FLOOR_HEIGHTS: Array[float] = %s\n" % fmt([float(v) for v in P.FLOOR_HEIGHTS])
    s += "## HeistMap.floor_names (D-054), parallel to FLOOR_HEIGHTS.\n"
    s += "const FLOOR_NAMES: Array[String] = %s\n" % fmt(list(P.FLOOR_NAMES))
    rms = rooms()
    s += const(
        "ROOMS",
        rms,
        doc="RoomVolumes: [id, purpose, floor index, kit, boxes [[x0, y0, z0, x1, y1, z1]]] (one "
        "volume per id; the fill rooms are the footprint minus the other rooms).",
    )
    s += const(
        "ZONES",
        zones(rms),
        "Dictionary",
        "PUBLIC / RESTRICTED MapZone boxes (doc Circulation: streets, the car "
        "park and the diner front of house are public; the site, the diner's back of house, the booth, the plant "
        "room and the rail lane restricted).",
    )
    s += const(
        "WALLS",
        GM.walls(),
        doc="Wall runs: [building, axis (x: along x at z = fixed; z: along z at x = fixed), "
        "fixed, a0, a1, thickness, y0, y1, surface class, holes [[a0, a1, y0, y1]]].",
    )
    s += const("PANES", GM.panes(), doc="Clear window glass (D-142): [name, min, max].")
    s += const("SLABS", GM.slabs(), doc="Slabs and roofs: [name, outer [x0, z0, x1, z1], holes, y0, y1, class].")
    s += const("CEILINGS", GM.ceilings(), doc="Ceiling planes (0.05 m): [name, [x0, z0, x1, z1], y].")
    s += "const CEIL_T: float = %s\n" % fmt(GM.CEIL_T)
    flights, sboxes, rails = GM.stairs()
    s += const(
        "SHELL_BOXES",
        GM.shell_boxes() + sboxes,
        doc="Shell boxes (Geometry/Building/<group>): [group, name, "
        "min, max, class]: the car-park guards, columns, stair half landings / dividers / top rails, scaffold.",
    )
    gboxes, ghulls = GM.site()
    s += const(
        "SITE_BOXES",
        gboxes,
        doc="Site boxes (Geometry/Site/<group>): grade, trench, rail, Skyway, hoarding, "
        "magazine, frame, scaffold cladding, crane, neighbours, closures.",
    )
    hl = [[h[0], h[1], h[2], GM.hull_faces(h[2]), h[3]] for h in ghulls + GM.hulls()]
    s += const(
        "HULLS",
        hl,
        doc="Convex hulls (collision + mesh): [group, name, points, faces (point-index polygons, "
        "counter-clockwise from outside), class]: the trench ramp, the car-park ramps R1 / R2 and their guards, "
        "the car-park roof copings (a 0.3 m ridge: >= 50 deg, RT plan §7.3).",
    )
    s += const(
        "FLIGHTS",
        flights,
        doc="Stair flights (ramp collision, visual steps): [name, origin (first riser line), "
        "yaw, width, risers, riser, tread]: stair A / B, the diner stair SC, the scaffold tower.",
    )
    s += const("HANDRAILS", rails, doc="Handrails (5 cm bars): [name, from, to].")
    links = [
        ["StormDrain", [-40.0, 0.0, 14.5], [75.0, -5.0, 9.0], True, 4],
        ["RappelSkywayW", [-13.02, 9.0, -26.0], [-13.5, 0.0, -26.0], False, 1],
        ["RappelSkywayE", [13.02, 9.0, 20.0], [13.5, 0.0, 20.0], False, 1],
    ]
    s += const(
        "NAV_LINKS",
        links,
        doc="Always-present nav links: [name, from, to, bidirectional, navigation_layers] (1 "
        "walkable, 4 vent): the storm drain (Phantom, DB culvert precedent), the Skyway's one-way rappels.",
    )
    s += const(
        "NAV_CULL",
        GM.NAV_CULL,
        doc="Projected bake obstructions over tops nobody stands on: [name, [x0, z0, x1, "
        "z1], y0, height] (no navmesh islands on neighbour roofs, the rail bank, closure vehicles).",
    )
    s += const("OOB", GM.oob(), doc="OUT_OF_BOUNDS curtains (D-040): [name, [x0, y0, z0, x1, y1, z1]].")
    s += const("MARKINGS", MK.markings(), doc="Road markings (rolling_thunder_markings.py, LEAD r305 G3): [feature, [quad, "
               "...]], a quad = 4 corners x, y, z; visual only (rt_markings.gd, paint_white).")
    shell_text = s
    s = hdr.replace("layout data. GENERATED", "layout data, content half. GENERATED")
    s += const(
        "PLAYER_SPAWNS", C.player_spawns(), doc='PLAYER spawns: [name, spawn_tag ("" = default), position, yaw].'
    )
    s += const("POLICE_SPAWNS", C.police_spawns(), doc="POLICE spawns (6 groups, doc Loud): [name, tag, position].")
    s += const("PREPLAN", C.preplan(), doc="PREPLAN_POINT markers: [id, category, floor index, position, params].")
    s += const("REVIEW_CAMERAS", C.review_cameras(), doc="Review cameras: [id, room, eye, look-at].")
    s += const(
        "DOORS",
        C.doors(),
        doc="Doors: [name, floor key, origin (bottom-centre on the wall line), yaw (front -Z "
        '= UsePoint side), kind, lock ("" = built by a SLOT_DOORS slot), visual, width_m, extra].',
    )
    s += const(
        "SLOT_DOORS", C.SLOT_DOORS, "Dictionary", "slot -> {door: lock} (the head house A door per player_perch)."
    )
    s += const(
        "FURNITURE",
        C.furniture(),
        doc="Props/MapBuilt boxes: parked cars, shelters, counter, booths, formwork, " "the mixer (static G1 cover).",
    )
    s += const("ALWAYS", C.always(), "Dictionary", "Always-present content: {parent path: rows}.")
    s += const("FIXED_SPAWNS", C.fixed_spawns(), doc="NPC spawns: pedestrians, bus queue, diner, attendant, Reyes.")
    s += const("GROUP_ORDER", C.GROUP_ORDER, "Array[String]")
    s += const(
        "SLOTS",
        C.SLOTS,
        doc="VariantSlots (resolver order): [group, slot_id, weight (the doc's G0 numbers until "
        "ENV B's values block), room, position, yaw, note].",
    )
    s += const("SLOT_ITEMS", C.slot_content(), "Dictionary", "VariantSlot content: {slot_id: rows}.")
    s += const(
        "CONVOY",
        C.convoy_sets(),
        "Dictionary",
        "The convoy under each convoy_route slot (RT-C2, A5-01 / A5-02, D-149.1): {route slot: {movers [[node, "
        "kind, start pivot, yaw, path [[point, in, out]]]], layouts [[clean|crash, [[stop node, kind, pivot, yaw, "
        "slope, size [length, height, width], cover]]]]}}.",
    )
    s += const(
        "GRAPHS",
        C.graphs(),
        "Dictionary",
        "Patrol graphs: name -> [graph_id, floor index, {point: [position, "
        "pause, anim, tags, facing yaw or null]}, edges].",
    )
    s += const(
        "TACTICAL",
        C.tactical(),
        doc="TacticalPoints: police entries, rappels, flanks, shield anchors, perches " "S1-S4, COVER.",
    )
    s += const("LINES", C.LINES, doc="Levelcheck lines (bag_line): [name, metas, points at the crew's feet].")
    s += const("MAP_METAS", {"camera_layout_group": "camera"}, "Dictionary", "HeistMap metas for levelcheck.")
    s += const(
        "VARIABLES",
        [[v[0], v[1], v[3]] for v in SL.VARIABLES],
        doc="The doc's 18 variables (rule order): "
        "[id, options, scalar?] (rolling_thunder_slots.py; the values are ENV B's).",
    )
    return shell_text, s


def check() -> int:
    rc = CHK.main()
    texts = emit()
    for path, text in ((OUT, texts[0]), (OUT_CONTENT, texts[1])):
        cur = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if cur != text:
            print(
                "STALE %s (re-run tools/levelcheck/plans/rolling_thunder_emit_layout.py)"
                % os.path.relpath(path, ROOT)
            )
            rc = 1
        else:
            print("ok   %s is current" % os.path.relpath(path, ROOT))
    return rc


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(check())
    texts = emit()
    if "--stdout" in sys.argv:
        sys.stdout.write(texts[0] if "--content" not in sys.argv else texts[1])
    else:
        os.makedirs(OUT_DIR, exist_ok=True)
        for path, text in ((OUT, texts[0]), (OUT_CONTENT, texts[1])):
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
            print("wrote %s (%d lines)" % (os.path.relpath(path, ROOT), text.count("\n")))
