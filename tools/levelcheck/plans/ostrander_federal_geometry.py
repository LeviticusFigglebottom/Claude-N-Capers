# Ostrander Federal: the greybox shell as primitives (walls with holes, slabs with holes, ceilings, glass, sills, the
# teller counter, the gallery guard, the loggia glazing, stairs A / B, the lantern, copings, the fire escape, the cages,
# the lid, the site) computed from the plan data, for ostrander_federal_emit_layout.py. Owner: ENV C (OF-C1).
# Heights are absolute (FFL B -4.0, G 0.0, M 5.0, E 8.6, R 12.2). Boxes are [group, name, [x0, y0, z0], [x1, y1, z1],
# surface class]; hexahedra / hulls are [group, name, [points], class]; flights are GN's flight() rows.
import math
from typing import Dict, List, Optional, Tuple

import ostrander_federal_content as C
import ostrander_federal_floors_ascii as P
import ostrander_federal_slots as S

FFL = P.FLOOR_HEIGHTS
NEXT = {"B": 0.0, "G": 5.0, "M": 8.6, "E": 12.2, "R": 15.2}
SLAB_UNDER = {"B": -0.8, "G": 4.2, "M": 8.0, "E": 11.6}    # underside of the slab above each floor's rooms
EXT_T, INT_T, CORE_T, VAULT_T = 0.4, 0.2, 0.3, 0.6
PARAPET = 1.1
COPING_RISE = 0.3          # a ridge over the half thickness 0.2 m: 56 deg (>= 50, §7.5)
OUTSIDE = (None, "X4", "X5")
CORES = ("SA", "SB", "HH")
DOOR_HEAD = 2.2
CEIL_T = 0.05
VE_TOP = 4.4               # the vestibule's ceiling slab top (4.2 m ceiling inside the 8 m hall)
HH_TOP = 15.2              # head house roof (2.7 m clear + 0.3)
RP_TOP = 15.5              # roof plant enclosure roof (3.0 m + 0.3)
ROOM_CEIL: Dict[str, float] = {
    "LK": 3.2, "GL": 0.0, "CQ": 3.2, "SA": 0.0, "CP": 3.2, "PL": 3.2, "CM": 3.2, "SS": 3.2, "SB": 0.0, "BB": 3.2,
    "RC": 3.2, "VC": 3.2, "VT": 3.2, "SD": 3.2, "LD": 4.2, "E1": 3.0, "SR": 3.0, "GR": 3.0, "WM": 3.0, "WW": 3.0,
    "J1": 3.0, "MO": 3.0, "BC": 3.0, "LO": 3.0, "TW": 4.2, "PC": 4.2, "CN1": 3.0, "CN2": 3.0, "AV": 4.2, "BH": 8.0,
    "VE": 4.2, "BM": 3.0, "PW": 3.0, "NA": 3.0, "X4": 0.0, "X5": 0.0, "HH": 2.7, "RP": 3.0,
}
ROOM_KIT: Dict[str, str] = {
    "LK": "locker_room", "CQ": "cash_transfer", "CP": "count_room", "PL": "plant_room", "CM": "server_room",
    "SS": "storage_supplies", "BB": "corridor_service", "RC": "storage_archive", "VC": "vault_antechamber",
    "VT": "vault_main", "SD": "deposit_hall", "LD": "sally_port", "E1": "electrical_closet", "SR": "security_office",
    "GR": "locker_room", "WM": "restroom_multi", "WW": "restroom_multi", "J1": "janitor_closet", "MO": "copy_room",
    "BC": "corridor_service", "LO": "office_loan", "TW": "teller_line", "PC": "lounge_client", "CN1": "meeting_small",
    "CN2": "meeting_small", "AV": "atm_vestibule", "BH": "banking_hall_grand", "VE": "vestibule_bronze",
    "BM": "office_manager", "PW": "restroom_single", "NA": "office_small", "BR": "break_room",
    "E2": "electrical_closet", "IT": "office_it", "SV": "server_room", "WM2": "restroom_multi",
    "WW2": "restroom_multi", "J2": "janitor_closet", "AR": "storage_archive", "UC": "corridor_office",
    "AO1": "office_small", "AO2": "office_small", "AO3": "office_small", "WL": "corridor_glazed",
    "EL": "corridor_glazed", "OF": "office_open", "CF": "conference_room", "CO": "office_small",
    "GA": "gallery_mezzanine", "VO": "office_vault_ops", "TR": "office_small", "TT": "meeting_small",
    "BD": "boardroom", "E3": "electrical_closet", "EA": "office_small", "PR": "office_partner", "PN": "break_room",
    "XW": "restroom_single", "XC": "corridor_office", "XL": "lounge_exec", "LG": "office_open", "CT": "office_open",
    "RA": "storage_archive", "X4": "exterior_terrace", "X5": "exterior_roof", "RP": "plant_room",
}
# ceiling_range overrides (D-048 / D-075): the basement's 3.2 m (Night Deposit precedent), XL (Shadow Ledger QC-31).
OVERRIDES = {"LK": [2.6, 3.2], "CQ": [2.6, 3.2], "CP": [2.6, 3.2], "CM": [2.6, 3.2], "SS": [2.6, 3.2],
             "BB": [2.6, 3.2], "RC": [2.6, 3.2], "XL": [2.6, 3.0]}
for _f in ("M", "E"):
    for _rid, _p, _r in P.ROOMS[_f]:
        ROOM_CEIL.setdefault(_rid, 3.0)


def r3(v: float) -> float:
    return round(v + 0.0, 3)


def box(group: str, name: str, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, cls: str) -> list:
    return [group, name, [r3(min(x0, x1)), r3(min(y0, y1)), r3(min(z0, z1))],
            [r3(max(x0, x1)), r3(max(y0, y1)), r3(max(z0, z1))], cls]


# --------------------------------------------------------------------------------------------- doors
def _wall_t(f: str, axis: str, fixed: float, a: float) -> float:
    for w in walls_raw(f):
        if w[0] == axis and abs(w[1] - fixed) < 1e-6 and w[2] - 1e-6 <= a <= w[3] + 1e-6:
            return w[4]
    return INT_T


def resolved_doors() -> List[list]:
    """[name, floor, pos (abs), yaw, kind, lock, visual, width_m, extra, hole [axis, fixed, a0, a1, y0, y1] or None]."""
    out = []
    front_yaw = {"N": 0.0, "W": 90.0, "S": 180.0, "E": -90.0}
    for d in C.DOORS:
        name, f, axis, fixed, a0, lock, fr, extra = d
        ex = dict(extra)
        if axis == "cage":
            pos = [ex["pos"][0], FFL[f] + ex["pos"][1], ex["pos"][2]]
            out.append([name, f, pos, ex["yaw"], "double", lock, ex["visual"], ex.get("w", 1.8), ex, None])
            continue
        op = [o for o in P.OPEN if o[0] == f and ((axis == "x" and o[3] == o[5] == fixed and o[2] == a0)
                                                  or (axis == "z" and o[2] == o[4] == fixed and o[3] == a0))]
        if not op:
            raise SystemExit("door %s: no plan opening" % name)
        o = op[0]
        span = (o[2], o[4]) if axis == "x" else (o[3], o[5])
        width = round(span[1] - span[0], 3)
        c = ex.get("c", (span[0] + span[1]) / 2.0)
        kind = {1.0: "single", 1.2: "service", 2.0: "double", 4.2: "double", 2.4: "vault", 3.8: "roller"}[width]
        hw = {"single": 0.5, "service": 0.6, "double": 1.0, "vault": 1.2, "roller": 1.9}[kind]
        head = {"vault": 2.3, "roller": 4.1}.get(kind, DOOR_HEAD)
        t = _wall_t(f, axis, fixed, c)
        tt = "t%02d" % int(round(t * 100))
        vis = ex.get("visual") or "prop_door_%s_%s_%s" % (kind, "steel" if ex.get("leaf") == "metal" or tt == "t30"
                                                           else "ivory", tt)
        if kind in ("single", "service", "double") and "liftgate" not in vis and not vis.endswith(tt):
            raise SystemExit("door %s: visual %s does not fit the %.1f m wall" % (name, vis, t))
        leaf = {"single": 0.9, "service": 1.1, "double": 1.8, "vault": 2.2, "roller": 3.6}[kind]
        line = ex.get("line", fixed)
        pos = [r3(c), FFL[f], r3(line)] if axis == "x" else [r3(line), FFL[f], r3(c)]
        hole = [axis, fixed, r3(c - hw), r3(c + hw), FFL[f], r3(FFL[f] + head)]
        out.append([name, f, pos, front_yaw[fr], kind, lock, vis, ex.get("w", leaf), ex, hole])
    return out


# --------------------------------------------------------------------------------------------- walls
def _edge_kind(f: str, e: Tuple[int, int, int, int], s0: Optional[str], s1: Optional[str]) -> Tuple[float, float, float,
                                                                                                    str, bool]:
    """(thickness, y0, y1, class, coping) of a plain wall unit edge."""
    y0 = FFL[f]
    o0, o1 = s0 in OUTSIDE, s1 in OUTSIDE
    inner = s1 if o0 else s0
    if o0 and o1:   # parapet (terrace / roof edge)
        return EXT_T, y0, y0 + PARAPET, "wall_ext", True
    if o0 or o1:    # facade (incl. the N block's face onto the terrace, the head house, the roof plant)
        if inner in CORES and f == "R":
            return (CORE_T if None not in (s0, s1) else EXT_T), y0, HH_TOP, "wall_ext", False
        if inner == "RP":
            return INT_T if None not in (s0, s1) else EXT_T, y0, RP_TOP, "wall_ext", False
        return EXT_T, y0, NEXT[f], "wall_ext", False
    on_vault = any((x0 == x1 == e[0] == e[2] and z0 <= e[1] and e[3] <= z1) or
                   (z0 == z1 == e[1] == e[3] and x0 <= e[0] and e[2] <= x1)
                   for (x0, z0, x1, z1) in P.VAULT.get(f, []))
    if on_vault:
        return VAULT_T, y0, SLAB_UNDER[f], "wall_vault", False
    if {s0, s1} & set(CORES):
        return CORE_T, y0, NEXT[f], "wall", False
    if f == "G" and "VE" in (s0, s1):
        return INT_T, y0, VE_TOP, "wall", False
    return INT_T, y0, SLAB_UNDER[f], "wall", False


_WALL_CACHE: Dict[str, list] = {}


def walls_raw(f: str) -> List[list]:
    """Merged straight runs [axis, fixed, a0, a1, t, y0, y1, class, coping] of floor f (plan walls only)."""
    if f in _WALL_CACHE:
        return _WALL_CACHE[f]
    c = P.cells(f)
    rows = []
    for e in sorted(P.walls(f)):
        s0, s1 = P.sides(c, e)
        t, y0, y1, cls, cop = _edge_kind(f, e, s0, s1)
        axis, fixed, a = ("z", e[0], e[1]) if e[0] == e[2] else ("x", e[1], e[0])
        rows.append([axis, float(fixed), float(a), float(a + 1), t, r3(y0), r3(y1), cls, cop])
    rows.sort(key=lambda r: (r[0], r[1], r[2]))
    out: List[list] = []
    for r in rows:
        if out and out[-1][0] == r[0] and out[-1][1] == r[1] and out[-1][3] == r[2] and out[-1][4:] == r[4:]:
            out[-1][3] = r[3]
        else:
            out.append(list(r))
    _WALL_CACHE[f] = out
    return out


def _opening_y(o: tuple) -> Tuple[float, float]:
    f, k, note = o[0], o[1], o[6]
    y = FFL[f]
    if k == "W":
        if "arched" in note:
            return y + 1.0, y + 6.5
        return y + 0.9, y + 2.4
    if k == "h":
        if note.startswith("fire-escape"):
            return y + 0.6, y + PARAPET + COPING_RISE + 0.1
        return y, y + PARAPET + COPING_RISE + 0.1
    return y, y + DOOR_HEAD


def holes() -> List[list]:
    """Every wall hole [axis, fixed, a0, a1, y0, y1]: the door kits' openings and the plan's windows / ladder tops."""
    out = [d[9] for d in resolved_doors() if d[9] is not None]
    for _nm, bx, bz, _rid in S.BREACH_WINDOWS:
        out.append(["x", bz, r3(bx - S.BREACH_SIZE[0] / 2), r3(bx + S.BREACH_SIZE[0] / 2), FFL["G"],
                    r3(FFL["G"] + S.BREACH_SIZE[1])])
    for o in P.OPEN:
        if o[1] in ("W", "h"):
            y0, y1 = _opening_y(o)
            axis, fixed, a0, a1 = ("x", o[3], o[2], o[4]) if o[3] == o[5] else ("z", o[2], o[3], o[5])
            out.append([axis, fixed, a0, a1, r3(y0), r3(y1)])
    return out


def walls() -> List[list]:
    """[floor, axis, fixed, a0, a1, t, y0, y1, class, holes]."""
    hs = holes()
    out = []
    for f in P.FLOORS:
        for w in walls_raw(f):
            axis, fixed, a0, a1, t, y0, y1, cls, _cop = w
            hh = [[h[2], h[3], h[4], h[5]] for h in hs if h[0] == axis and abs(h[1] - fixed) < 1e-6
                  and h[3] > a0 + 1e-6 and h[2] < a1 - 1e-6 and h[5] > y0 + 1e-6 and h[4] < y1 - 1e-6]
            out.append([f, axis, fixed, a0, a1, t, y0, y1, cls, hh])
    return out


def copings() -> List[list]:
    """Coping ridges over the parapets, cut at the ladder top / fire-escape openings: [name, axis, fixed, a0, a1, y, t]."""
    out = []
    for f in P.FLOORS:
        for w in walls_raw(f):
            if not w[8]:
                continue
            axis, fixed, a0, a1, t, _y0, y1 = w[:7]
            spans = [[a0, a1]]
            for o in P.OPEN:
                if o[0] == f and o[1] == "h":
                    oa, of, o0, o1 = ("x", o[3], o[2], o[4]) if o[3] == o[5] else ("z", o[2], o[3], o[5])
                    if oa == axis and abs(of - fixed) < 1e-6:
                        nxt = []
                        for s in spans:
                            if o0 > s[0] and o1 < s[1]:
                                nxt += [[s[0], o0], [o1, s[1]]]
                            else:
                                nxt.append(s)
                        spans = nxt
            for s in spans:
                out.append(["Coping%s%s%04d_%04d" % (f, axis.upper(), int(round(fixed * 10)), int(round(s[0] * 10))),
                            axis, fixed, s[0], s[1], y1, t])
    return out


def panes() -> List[list]:
    """Greybox glass panes in the windows: [name, mn, mx] (0.04 m on the wall line)."""
    out = []
    for i, o in enumerate(P.OPEN):
        if o[1] != "W":
            continue
        y0, y1 = _opening_y(o)
        if o[3] == o[5]:
            mn, mx = [o[2], y0, o[3] - 0.02], [o[4], y1, o[3] + 0.02]
        else:
            mn, mx = [o[2] - 0.02, y0, o[3]], [o[2] + 0.02, y1, o[5]]
        cut = [b for b in S.BREACH_WINDOWS if o[0] == "G" and o[3] == o[5] == b[2] and o[2] < b[1] < o[4]]
        if cut:   # the breach slot: panes W / E of it and over its 2.1 m head
            bx, hw, top = cut[0][1], S.BREACH_SIZE[0] / 2, FFL["G"] + S.BREACH_SIZE[1]
            for sfx, a, b, ya in [("W", mn[0], bx - hw, mn[1]), ("E", bx + hw, mx[0], mn[1]),
                                  ("Head", bx - hw, bx + hw, top)]:
                out.append(["Pane%02d_%s%s" % (i, o[0], sfx), [r3(a), r3(ya), r3(mn[2])], [r3(b), r3(mx[1]), r3(mx[2])]])
            continue
        out.append(["Pane%02d_%s" % (i, o[0]), [r3(v) for v in mn], [r3(v) for v in mx]])
    return out


def sills() -> List[list]:
    """Floor under every walk-through facade opening (the slabs stop at the facade's inner face, the grade at its outer
    face): a box the opening's width x the wall thickness, top at FFL (GN rehearsal F1)."""
    out = []
    for d in resolved_doors():
        h = d[9]
        if h is None:
            continue
        f = d[1]
        foot = P.FOOT[f]
        axis, fixed = h[0], h[1]
        on_foot = (axis == "x" and fixed in (foot[1], foot[3])) or (axis == "z" and fixed in (foot[0], foot[2]))
        if not on_foot:
            continue
        t = _wall_t(f, axis, fixed, (h[2] + h[3]) / 2)
        y = FFL[f]
        if axis == "x":
            out.append(box("Sills", "Sill_" + d[0], h[2], y - 0.3, fixed - t / 2, h[3], y, fixed + t / 2, "floor"))
        else:
            out.append(box("Sills", "Sill_" + d[0], fixed - t / 2, y - 0.3, h[2], fixed + t / 2, y, h[3], "floor"))
    for nm, bx, bz, _rid in S.BREACH_WINDOWS:   # the blown breach is walked through at FFL
        out.append(box("Sills", "Sill_" + nm, bx - S.BREACH_SIZE[0] / 2, -0.3, bz - EXT_T / 2, bx + S.BREACH_SIZE[0] / 2,
                       0.0, bz + EXT_T / 2, "floor"))
    # the caged-ladder top (roof parapet z 17) and the fire-escape crossing (north parapet, lowered to 0.6 m)
    out.append(box("Sills", "Sill_CagedLadderTop", 45.4, 11.9, 16.8, 46.6, 12.2, 17.2, "roof"))
    return out


# --------------------------------------------------------------------------------------------- slabs
C_LANDING = P.CORE_LANDING
Z_START = round(P.SA[3] - 0.15 - C_LANDING, 3)     # first riser line (5.55)


def slabs() -> List[list]:
    """[name, outer [x0, z0, x1, z1], holes, y0, y1, class]."""
    def inset(r: P.Rect, d: float = 0.2) -> list:
        return [r[0] + d, r[1] + d, r[2] - d, r[3] - d]

    sa = [P.SA[0] + 0.15, P.SA[1] + 0.15, P.SA[2] - 0.15, Z_START]
    sb = [P.SB[0] + 0.15, P.SB[1] + 0.15, P.SB[2] - 0.15, Z_START]
    lantern = [14.3, 22.3, 29.7, 29.7]
    return [
        ["SlabB", inset(P.FOOT["B"]), [], -4.3, -4.0, "floor"],
        ["SlabG", inset(P.FOOT["G"]), [sa, sb, C.HOLE], -0.8, 0.0, "floor"],
        ["SlabM", inset(P.FOOT["M"]), [sa, sb, [8.0, 20.0, 40.0, 36.0]], 4.2, 5.0, "floor"],
        ["SlabE", inset(P.FOOT["E"]), [sa, sb, lantern], 8.0, 8.6, "roof"],
        ["SlabR", inset(P.FOOT["R"]), [sa], 11.6, 12.2, "roof"],
        ["RoofHH", [P.SA[0], P.SA[1] + 0.2, P.SA[2], P.SA[3]], [], HH_TOP - 0.3, HH_TOP, "roof"],
        ["RoofRP", [20.0, 2.0, 34.0, 10.0], [], RP_TOP - 0.3, RP_TOP, "roof"],
        ["CeilingVE", [20.0, 32.0, 28.0, 35.8], [], 4.2, VE_TOP, "ceiling"],
    ]


def ceilings() -> List[list]:
    """Ceiling planes where a room's ceiling is below the slab above: [name, [x0, z0, x1, z1], y]."""
    out = []
    for f in P.FLOORS:
        if f not in SLAB_UNDER:
            continue
        for rid, _p, r in P.ROOMS[f]:
            ce = ROOM_CEIL.get(rid, 0.0)
            if ce <= 0.0 or rid in ("BH", "VE"):
                continue
            y = FFL[f] + ce
            if y < SLAB_UNDER[f] - 0.01:
                out.append(["Ceil%s" % rid, list(r), r3(y)])
    return out


# --------------------------------------------------------------------------------------------- hall pieces
def hall() -> List[list]:
    k = C.COUNTER
    out = []
    xa, xb = k["x"]
    g0, g1 = k["gate"]
    pieces = [[xa, k["piers"][0][0]], [k["piers"][1][1], xb]]
    for i, (a, b) in enumerate(pieces):
        nm = "W" if i == 0 else "E"
        out.append(box("Counter", "ScreenBase" + nm, a, 0.0, k["upstand"][0], b, k["upstand"][2], k["upstand"][1],
                       "counter"))
        out.append(box("Counter", "CustomerLedge" + nm, a, 0.0, k["ledge"][0], b, k["ledge"][2], k["ledge"][1],
                       "counter"))
        out.append(box("Counter", "BanditGlass" + nm, a, k["glass"][2], k["glass"][0], b, k["glass"][3], k["glass"][1],
                       "glass"))
    for i, (a, b) in enumerate(k["piers"]):
        out.append(box("Counter", "GatePier%d" % i, a, 0.0, k["pier_z"][0], b, k["bulkhead"][2], k["pier_z"][1],
                       "wall"))
    out.append(box("Counter", "Bulkhead", xa, k["bulkhead"][2], k["bulkhead"][0], xb, SLAB_UNDER["G"],
                   k["bulkhead"][1], "wall"))
    out.append(box("Counter", "GateHeader", g0, k["gate_head"], k["pier_z"][0], g1, k["bulkhead"][2],
                   k["pier_z"][1], "wall"))
    # the officers' gallery guard (§7.3: true to the 1.1 m visual, solid bronze base to 1.0 m + glass cap)
    out.append(box("GalleryGuard", "GuardBase", 8.1, 5.0, 19.9, 39.9, 6.0, 20.0, "trim"))
    out.append(box("GalleryGuard", "GuardCap", 8.1, 6.0, 19.9, 39.9, 6.1, 20.0, "glass"))
    # the loggias' full-height glazing to the hall void
    out.append(box("Glazing", "LoggiaGlazingW", 7.96, 5.0, 20.0, 8.0, 8.0, 36.0 - 0.2, "glass"))
    out.append(box("Glazing", "LoggiaGlazingE", 40.0, 5.0, 20.0, 40.04, 8.0, 36.0 - 0.2, "glass"))
    for x in C.PILLARS:
        out.append(box("Pillars", "Pillar%02d" % int(x), x - 0.25, 0.0, 19.75, x + 0.25, SLAB_UNDER["G"], 20.25, "wall"))
    return out


def cages() -> List[list]:
    out = []
    t, h, vy = C.CAGE_T, C.CAGE_H, FFL["B"]
    x0, z0, x1, z1 = C.CASH_CAGE
    out += [box("Cages", "CashCageN_W", x0, vy, z0 - t / 2, 23.0, vy + h, z0 + t / 2, "trim"),
            box("Cages", "CashCageN_E", 25.0, vy, z0 - t / 2, x1, vy + h, z0 + t / 2, "trim"),
            box("Cages", "CashCageN_Head", 23.0, vy + DOOR_HEAD, z0 - t / 2, 25.0, vy + h, z0 + t / 2, "trim"),
            box("Cages", "CashCageS", x0, vy, z1 - t / 2, x1, vy + h, z1 + t / 2, "trim"),
            box("Cages", "CashCageW", x0 - t / 2, vy, z0 + t / 2, x0 + t / 2, vy + h, z1 - t / 2, "trim"),
            box("Cages", "CashCageE", x1 - t / 2, vy, z0 + t / 2, x1 + t / 2, vy + h, z1 - t / 2, "trim")]
    x0, z0, x1, z1 = C.GOLD_CAGE
    out += [box("Cages", "GoldCageW_N", x0 - t / 2, vy, z0, x0 + t / 2, vy + h, 18.0, "trim"),
            box("Cages", "GoldCageW_S", x0 - t / 2, vy, 20.0, x0 + t / 2, vy + h, z1, "trim"),
            box("Cages", "GoldCageW_Head", x0 - t / 2, vy + DOOR_HEAD, 18.0, x0 + t / 2, vy + h, 20.0, "trim"),
            box("Cages", "GoldCageN", x0 + t / 2, vy, z0 - t / 2, x1, vy + h, z0 + t / 2, "trim"),
            box("Cages", "GoldCageS", x0 + t / 2, vy, z1 - t / 2, x1, vy + h, z1 + t / 2, "trim")]
    return out


def lid() -> List[list]:
    h = C.HOLE
    return [box("Lid", "Lid", h[0], -0.8, h[1], h[2], 0.0, h[3], "floor")]


def lantern() -> Tuple[List[list], List[list]]:
    """The lantern skylight (§7.5): a 0.6 m curb round x 14-30 z 22-30 and hip glazing at 51 deg from the curb's outer top
    edge (the curb top is under the glass: no standing on it). Boxes and the glazing hull."""
    y0, yc, yr = FFL["E"], FFL["E"] + 0.6, FFL["E"] + 0.6 + 5.0
    b = [box("Lantern", "CurbN", 14.0, y0, 22.0, 30.0, yc, 22.3, "wall_ext"),
         box("Lantern", "CurbS", 14.0, y0, 29.7, 30.0, yc, 30.0, "wall_ext"),
         box("Lantern", "CurbW", 14.0, y0, 22.3, 14.3, yc, 29.7, "wall_ext"),
         box("Lantern", "CurbE", 29.7, y0, 22.3, 30.0, yc, 29.7, "wall_ext")]
    hull = [["Lantern", "Glazing", [[14.0, yc, 22.0], [30.0, yc, 22.0], [30.0, yc, 30.0], [14.0, yc, 30.0],
                                    [18.0, yr, 26.0], [26.0, yr, 26.0]], "glass"]]
    return b, hull


LANTERN_SLOPE_DEG = math.degrees(math.atan2(5.0, 4.0))


# --------------------------------------------------------------------------------------------- stairs
def stairs() -> Tuple[List[list], List[list], List[list]]:
    """Flights [name, origin, yaw, w, nr, r, t], boxes (half landings, dividers, top rails), handrails [name, a, b]."""
    flights, boxes, rails = [], [], []
    storeys = {"SA": [s for s in P.STAIRS if s[0] == "SA"], "SB": [s for s in P.STAIRS if s[0] == "SB"]}
    for core, rect in (("SA", P.SA), ("SB", P.SB)):
        cx0, cz0, cx1 = rect[0] + 0.15, rect[1] + 0.15, rect[2] - 0.15
        lw = (cx1 - cx0 - 0.2) / 2.0
        west = [cx0, cx0 + lw]
        well = [cx0 + lw, cx0 + lw + 0.2]
        east = [well[1], cx1]
        xw, xe = (west[0] + west[1]) / 2, (east[0] + east[1]) / 2
        n = len(storeys[core])
        for i, (_nm, y0, y1, _fn, m, r, t) in enumerate(storeys[core]):
            zh = r3(Z_START - (m - 1) * t)
            yh = r3(y0 + m * r)
            flights.append(["%sFlight%dW" % (core, i), [r3(xw), y0, Z_START], 180.0, r3(lw), m, r, t])
            flights.append(["%sFlight%dE" % (core, i), [r3(xe), yh, zh], 0.0, r3(lw), m, r, t])
            boxes.append(box("Stairs", "%sHalfLanding%d" % (core, i), cx0, yh - 0.3, cz0, cx1, yh, zh, "stair"))
            top = y1 + (PARAPET if i == n - 1 else 0.0)
            boxes.append(box("Stairs", "%sDivider%d" % (core, i), well[0], y0, zh, well[1], top, Z_START, "wall"))
            run = (m - 1) * t
            hr, off = 1.025, 0.07
            sides_w = [west[0] + off, well[0] - off]
            sides_e = [well[1] + off, east[1] - off]
            for k in range(2):
                rails.append(["%sFlight%dWRail%d" % (core, i, k), [r3(sides_w[k]), r3(y0 + r + hr), Z_START],
                              [r3(sides_w[k]), r3(yh + hr), r3(Z_START - run)]])
                rails.append(["%sFlight%dERail%d" % (core, i, k), [r3(sides_e[k]), r3(yh + r + hr), zh],
                              [r3(sides_e[k]), r3(y1 + hr), r3(zh + run)]])
        ytop = storeys[core][-1][2]
        boxes.append(box("Stairs", "%sTopRail" % core, cx0, ytop, Z_START - 0.06, well[0], ytop + PARAPET, Z_START,
                         "trim"))
    return flights, boxes, rails


# --------------------------------------------------------------------------------------------- fire escape
FE_LANES = {"A": [-1.3, -0.25], "B": [-2.4, -1.3]}
FE_X = [-5.0, -1.2]
FE_EAST = [-1.2, 1.6]
FE_WEST = [-6.2, -5.0]
FE_LEVELS = [3.0, 5.3, 7.6, 9.9, 12.2]


def fire_escape() -> Tuple[List[list], List[list]]:
    """The Corvino rear fire escape (§7.6): landings (E at 3.0 / 7.6 / 12.2, W at 5.3 / 9.9), four 2.3 m flights as ramps in
    two lanes on Corvino's north face, the lane divider, 1.1 m rails; the 0.6 m crossing over the bank's lowered north
    coping at x 0.4-1.4 as 2 x 0.3 m steps with 1.1 m rails. Boxes and hulls (the flights)."""
    b, hulls = [], []
    zl = [FE_LANES["B"][0], FE_LANES["A"][1]]
    for i, y in enumerate(FE_LEVELS):
        xs = FE_EAST if i % 2 == 0 else FE_WEST
        b.append(box("FireEscape", "Landing%d" % i, xs[0], y - 0.15, zl[0], xs[1], y, zl[1], "trim"))
        if i % 2 == 0:   # east landings: N rail (gap for the drop ladder on the first), E rail
            if i == 0:
                b.append(box("FireEscape", "Landing0RailNW", xs[0], y, zl[0], 0.05, y + PARAPET, zl[0] + 0.05, "trim"))
                b.append(box("FireEscape", "Landing0RailNE", 1.15, y, zl[0], xs[1], y + PARAPET, zl[0] + 0.05, "trim"))
            else:
                b.append(box("FireEscape", "Landing%dRailN" % i, xs[0], y, zl[0], xs[1], y + PARAPET, zl[0] + 0.05,
                             "trim"))
            b.append(box("FireEscape", "Landing%dRailE" % i, xs[1] - 0.05, y, zl[0], xs[1], y + PARAPET, zl[1], "trim"))
        else:
            b.append(box("FireEscape", "Landing%dRailN" % i, xs[0], y, zl[0], xs[1], y + PARAPET, zl[0] + 0.05, "trim"))
            b.append(box("FireEscape", "Landing%dRailW" % i, xs[0], y, zl[0], xs[0] + 0.05, y + PARAPET, zl[1], "trim"))
    for i in range(4):
        lane = FE_LANES["B" if i % 2 == 0 else "A"]
        ya, yb = FE_LEVELS[i], FE_LEVELS[i + 1]
        # rising west on lane B (from the east landing), east on lane A; 0.3 m flat tongues onto both landings
        xl, xh = (FE_X[1], FE_X[0]) if i % 2 == 0 else (FE_X[0], FE_X[1])
        d = -1.0 if i % 2 == 0 else 1.0
        pts = []
        for z in lane:
            for (x, y) in [(xl - d * 0.3, ya), (xl, ya), (xh, yb), (xh + d * 0.3, yb)]:
                pts.append([r3(x), r3(y), r3(z)])
                pts.append([r3(x), r3(y - 0.15), r3(z)])
        hulls.append(["FireEscape", "Flight%d" % i, pts, "trim"])
        if i % 2 == 0:   # the outer rail panel on lane B (sloped)
            rail = []
            for z in (lane[0], lane[0] + 0.05):
                for (x, y) in [(xl, ya), (xh, yb)]:
                    rail.append([r3(x), r3(y), r3(z)])
                    rail.append([r3(x), r3(y + PARAPET), r3(z)])
            hulls.append(["FireEscape", "Flight%dRail" % i, rail, "trim"])
    # landing edges where no flight meets them: landing 0 (3.0) lane A west, landing 4 (12.2) lane B west
    b.append(box("FireEscape", "Landing0RailW", FE_EAST[0], FE_LEVELS[0], FE_LANES["A"][0], FE_EAST[0] + 0.05,
                 FE_LEVELS[0] + PARAPET, FE_LANES["A"][1], "trim"))
    b.append(box("FireEscape", "Landing4RailW", FE_EAST[0], FE_LEVELS[4], FE_LANES["B"][0], FE_EAST[0] + 0.05,
                 FE_LEVELS[4] + PARAPET, FE_LANES["B"][1], "trim"))
    b.append(box("FireEscape", "LaneDivider", FE_X[0], FE_LEVELS[0], -1.33, FE_X[1], FE_LEVELS[-1] + PARAPET, -1.27,
                 "trim"))
    y = FFL["R"]
    b += [box("FireEscape", "CrossingStepOut", 0.4, y, -0.55, 1.4, y + 0.3, -0.2, "trim"),
          box("FireEscape", "CrossingStepIn", 0.4, y, 0.2, 1.4, y + 0.3, 0.55, "trim"),
          box("FireEscape", "CrossingRailW", 0.3, y + 0.6, -0.55, 0.4, y + 0.6 + PARAPET, 0.55, "trim"),
          box("FireEscape", "CrossingRailE", 1.4, y + 0.6, -0.55, 1.5, y + 0.6 + PARAPET, 0.55, "trim")]
    return b, hulls


# --------------------------------------------------------------------------------------------- site
def site() -> Tuple[List[list], List[list], List[list]]:
    """Grade boxes, ramp hulls and the plaza steps flight."""
    b, hulls = [], []
    for nm, r, y, cls in S.GRADE:
        b.append(box("Grade", "Grade" + nm, r[0], -1.5, r[1], r[2], y, r[3], cls))
    st = S.PLAZA_STEPS
    run = (st["risers"] - 1) * st["tread"]
    b.append(box("Grade", "GradeApronSteps", st["x"][0], -1.5, st["z_top"], st["x"][1], 0.0,
                 r3(S.RAMPS[0][4] - run), "paving"))
    for nm, x0, x1, zh, zl, yh, yl in S.RAMPS[1:]:
        pts = []
        for x in (x0, x1):
            for (z, y) in [(zh, yh), (zl, yl)]:
                pts.append([x, y, z])
                pts.append([x, -1.5, z])
        hulls.append(["Grade", nm, pts, "asphalt"])
    for p in S.POLICE_ISLANDS:
        r = p[1]
        b.append(box("PoliceIslands", "PoliceIsland" + p[0], r[0], p[2] - 0.6, r[1], r[2], p[2], r[3], "asphalt"))
    for nm, bx, cls in S.CLOSURES:
        b.append(box("Closures", nm, bx[0], bx[1], bx[2], bx[3], bx[4], bx[5], cls))
    flight = ["PlazaSteps", [r3((st["x"][0] + st["x"][1]) / 2), S.PLAZA_Y, S.RAMPS[0][4]], 180.0,
              r3(st["x"][1] - st["x"][0]), st["risers"], st["riser"], st["tread"]]
    return b, hulls, [flight]


# --------------------------------------------------------------------------------------------- hull faces
def _sub(a: list, b: list) -> list:
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _cross(a: list, b: list) -> list:
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def _dot(a: list, b: list) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def hull_faces(pts: List[list]) -> List[List[int]]:
    """Faces of the convex hull of `pts` (small sets): each a polygon of point indices, counter-clockwise seen from
    outside (outward normal by the right-hand rule). Duplicate points are allowed (the first one is used)."""
    uniq: List[int] = []
    for i, p in enumerate(pts):
        if not any(abs(p[0] - pts[j][0]) + abs(p[1] - pts[j][1]) + abs(p[2] - pts[j][2]) < 1e-6 for j in uniq):
            uniq.append(i)
    centre = [sum(pts[i][k] for i in uniq) / len(uniq) for k in range(3)]
    faces: List[List[int]] = []
    seen: List[tuple] = []
    for a in range(len(uniq)):
        for b in range(a + 1, len(uniq)):
            for c in range(b + 1, len(uniq)):
                pa, pb, pc = pts[uniq[a]], pts[uniq[b]], pts[uniq[c]]
                nrm = _cross(_sub(pb, pa), _sub(pc, pa))
                ln = _dot(nrm, nrm) ** 0.5
                if ln < 1e-9:
                    continue
                nrm = [v / ln for v in nrm]
                d = _dot(nrm, pa)
                if _dot(nrm, centre) > d:
                    nrm, d = [-v for v in nrm], -d
                if any(_dot(nrm, pts[i]) > d + 1e-6 for i in uniq):
                    continue
                key = (round(nrm[0], 5), round(nrm[1], 5), round(nrm[2], 5), round(d, 4))
                if key in seen:
                    continue
                seen.append(key)
                on = [i for i in uniq if abs(_dot(nrm, pts[i]) - d) < 1e-6]
                fc = [sum(pts[i][k] for i in on) / len(on) for k in range(3)]
                ref = _sub(pts[on[0]], fc)
                ref2 = _cross(nrm, ref)
                faces.append(sorted(on, key=lambda i: math.atan2(_dot(_sub(pts[i], fc), ref2),
                                                                 _dot(_sub(pts[i], fc), ref))))
    return faces
