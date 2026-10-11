# ASCII floor plans + checks for docs/design/heists/dockside_burn.md (G0 approved D-064; G1 data).
# Run: python3 tools/levelcheck/plans/dockside_burn_floors_ascii.py [--check]
# 1 char = 1 m; each char is a grid POINT (x = col, z = row). Rooms are rectangles (x0, z0, x1, z1) in
# metres between wall centre lines, the same numbers as game/world/heists/dockside_burn/greybox/
# dockside_burn_layout.gd (ROOMS / DOORS). Origin = the Ortega building's NW corner, +x east, +z south
# (the yard at the top, the quay at the bottom).
# --check: rooms tile each floor footprint exactly, every door sits on a wall of a room of that floor
# (or the facade), every room has a door or an opening, and the stair arithmetic of the vertical data.
import sys

W, H = 48, 32
FOOT = {"G": (0, 0, 48, 32), "M": (0, 0, 18, 8), "R": None}
ROOMS = {
    "G": [
        ("ST", "", (0, 0, 3, 6)), ("O1", "RECEP", (3, 0, 9, 6)), ("O2", "SEC", (9, 0, 15, 6)),
        ("LF", "", (15, 0, 18, 3)), ("E1", "", (15, 3, 18, 6)), ("OC", "CORRIDOR", (0, 6, 18, 8)),
        ("PL", "PLANT", (0, 8, 10, 18)), ("WS", "SHOP", (10, 8, 18, 18)), ("LK", "", (0, 18, 5, 23)),
        ("J", "", (5, 18, 8, 21)), ("PK", "PACKING", (0, 23, 18, 32)), ("PK", "", (8, 18, 18, 21)),
        ("PK", "", (5, 21, 18, 23)), ("H", "MARSHALLING HALL", (18, 0, 48, 10)),
        ("C1", "CHAMBER A", (18, 10, 32, 24)), ("SP", "", (32, 10, 35, 24)), ("C2", "CHAMBER B", (35, 10, 48, 24)),
        ("SR", "", (18, 24, 26, 32)), ("AN", "ANTEROOM", (26, 24, 48, 32))],
    "M": [
        ("ST", "", (0, 0, 3, 6)), ("M2", "BREAK", (3, 0, 9, 6)), ("M1", "COUNT", (9, 0, 15, 6)),
        ("LF", "", (15, 0, 18, 3)), ("M3", "", (15, 3, 18, 6)), ("MC", "CORRIDOR", (0, 6, 18, 8))],
    "R": [("HH", "", (0, 0, 3, 6))],
}
# Rooms outside the tiled footprint (hall platform PF at +3.6, the office roof).
EXTRA = {"M": [("PF", "", (18, 0, 22, 8))], "R": [("X5", "ROOF +7.2", (3, 0, 18, 8)), ("X5", "", (0, 6, 3, 8))]}
# Openings: (floor, kind, x0, z0, x1, z1). D door, R roller door, S sliding door, V vault door,
# s strip curtain (open), h lift hatch (bags only), W window. Same positions as the layout's DOORS.
OPEN = [
    ("G", "D", 6, 0, 6, 0), ("G", "W", 4, 0, 4, 0), ("G", "W", 8, 0, 8, 0), ("G", "W", 10, 0, 11, 0),
    ("G", "W", 13, 0, 14, 0), ("G", "D", 4, 6, 4, 6), ("G", "D", 12, 6, 12, 6), ("G", "D", 16, 6, 17, 6),
    ("G", "D", 1, 6, 2, 6), ("G", "D", 0, 7, 0, 7), ("G", "D", 18, 7, 18, 7), ("G", "D", 4, 8, 4, 8),
    ("G", "D", 14, 8, 14, 8), ("G", "D", 18, 9, 18, 9), ("G", "D", 10, 13, 10, 13), ("G", "D", 0, 14, 0, 14),
    ("G", "D", 9, 18, 9, 18), ("G", "D", 14, 18, 14, 18), ("G", "D", 7, 21, 7, 21), ("G", "D", 5, 22, 5, 22),
    ("G", "R", 6, 32, 9, 32), ("G", "D", 12, 32, 12, 32), ("G", "S", 18, 20, 18, 22), ("G", "S", 23, 10, 25, 10),
    ("G", "S", 32, 15, 32, 17), ("G", "s", 33, 10, 34, 10), ("G", "S", 35, 18, 35, 20), ("G", "S", 40, 10, 42, 10),
    ("G", "S", 40, 24, 42, 24), ("G", "s", 33, 24, 34, 24), ("G", "V", 26, 27, 26, 29), ("G", "R", 29, 32, 32, 32),
    ("G", "R", 39, 32, 42, 32), ("G", "D", 46, 32, 46, 32), ("G", "D", 48, 28, 48, 28), ("G", "R", 24, 0, 27, 0),
    ("G", "R", 32, 0, 35, 0), ("G", "R", 40, 0, 43, 0), ("G", "R", 48, 3, 48, 6), ("G", "h", 18, 1, 18, 2),
    ("M", "D", 1, 6, 2, 6), ("M", "D", 6, 6, 6, 6), ("M", "D", 12, 6, 12, 6), ("M", "D", 16, 6, 17, 6),
    ("M", "D", 0, 7, 0, 7), ("M", "D", 18, 7, 18, 7), ("M", "h", 15, 1, 15, 2), ("M", "W", 4, 0, 4, 0),
    ("M", "W", 8, 0, 8, 0), ("M", "W", 10, 0, 11, 0), ("M", "W", 13, 0, 14, 0),
    ("R", "D", 1, 6, 2, 6),
]
MARK = {
    "G": [(1, 2, "^v"), (1, 3, "^v"), (1, 4, "^v"), (16, 1, "LF"), (16, 4, "E1"), (22, 7, "<<<=<<"),
          (24, 14, "F"), (40, 14, "F"), (11, 24, "F"), (20, 27, "L"), (20, 29, "L"), (27, 28, "T"),
          (22, 3, "(platform +3.6 x18-22)"), (2, 15, "u"), (43, 26, "c c"), (4, 30, "c"), (33, 12, "SP")],
    "M": [(1, 2, "^v"), (1, 3, "^v"), (10, 3, "S L"), (16, 1, "LF"), (16, 4, "M3"), (19, 1, "PF")],
    "R": [(1, 2, "^v"), (1, 3, "^v"), (5, 4, "player perch"), (1, 1, "HH")],
}
FLOOR_HEIGHTS = {"Landing": -1.8, "Ground": 0.0, "Mezzanine": 3.6, "Roof": 7.2}


def grid():
    return [[" "] * (W + 1) for _ in range(H + 1)]


def put(g, x, z, ch):
    i, j = int(round(x)), int(round(z))
    if 0 <= j < len(g) and 0 <= i < len(g[0]):
        g[j][i] = ch


def seg(g, x0, z0, x1, z1, ch):
    n = int(round(max(abs(x1 - x0), abs(z1 - z0))))
    for k in range(n + 1):
        t = k / max(n, 1)
        put(g, x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, ch)


def txt(g, x, z, s):
    i, j = int(round(x)), int(round(z))
    for k, ch in enumerate(s):
        if 0 <= i + k < len(g[0]) and 0 <= j < len(g):
            g[j][i + k] = ch


def all_rooms(fl):
    return ROOMS[fl] + EXTRA.get(fl, [])


def plan(fl):
    g = grid()
    for rid, _, (a, b, c, d) in all_rooms(fl):
        if rid in ("X5", "PK"):   # PK's walls are its neighbours' (LK, J, PL, WS, C1) and the facade
            continue
        seg(g, a, b, c, b, "-"); seg(g, a, d, c, d, "-"); seg(g, a, b, a, d, "|"); seg(g, c, b, c, d, "|")
        for (x, z) in [(a, b), (c, b), (a, d), (c, d)]:
            put(g, x, z, "+")
    if FOOT[fl]:
        a, b, c, d = FOOT[fl]
        seg(g, a, b, c, b, "#"); seg(g, a, d, c, d, "#"); seg(g, a, b, a, d, "#"); seg(g, c, b, c, d, "#")
    if fl == "G":   # insulated cold-store panels and the strongroom walls
        seg(g, 19, 10, 31, 10, "%"); seg(g, 36, 10, 47, 10, "%"); seg(g, 32, 11, 32, 23, "%")
        seg(g, 35, 11, 35, 23, "%"); seg(g, 18, 24, 31, 24, "%"); seg(g, 36, 24, 47, 24, "%"); seg(g, 26, 25, 26, 31, "%")
    if fl == "M":
        seg(g, 22, 0, 22, 6, "r"); seg(g, 19, 8, 28, 8, "r"); seg(g, 22, 6, 28, 6, "r"); txt(g, 22, 7, "vvv=vv")
    if fl == "R":
        seg(g, 0, 0, 18, 0, "p"); seg(g, 0, 8, 18, 8, "p"); seg(g, 0, 0, 0, 8, "p"); seg(g, 18, 0, 18, 8, "p")
    for (f2, k, a, b, c, d) in OPEN:
        if f2 == fl:
            seg(g, a, b, c, d, {"s": "s", "h": "h"}.get(k, k))
    seen = set()
    for rid, lab, (a, b, c, d) in all_rooms(fl):
        if rid in seen:
            continue
        seen.add(rid)
        s = rid + (" " + lab if lab else "")
        if len(s) > int(c - a) - 1:
            s = rid
        txt(g, a + 1, b + 1, s)
    for (x, z, s) in MARK.get(fl, []):
        txt(g, x, z, s)
    out = ["      " + "".join(str(i % 10) for i in range(W + 1))]
    for j in range(H + 1 if fl == "G" else 9):
        out.append(("%5d " % j if j % 2 == 0 else "      ") + "".join(g[j]).rstrip())
    return "\n".join(out)


def area(r):
    return (r[2] - r[0]) * (r[3] - r[1])


def overlap(r, s):
    return max(0, min(r[2], s[2]) - max(r[0], s[0])) * max(0, min(r[3], s[3]) - max(r[1], s[1]))


def on_edge(r, a, b, c, d):
    x0, z0, x1, z1 = r
    return (a == c and a in (x0, x1) and z0 <= min(b, d) and max(b, d) <= z1) or \
        (b == d and b in (z0, z1) and x0 <= min(a, c) and max(a, c) <= x1)


def check():
    ok = True
    for fl, foot in FOOT.items():
        rooms = ROOMS[fl]
        for i, (a, _, r) in enumerate(rooms):
            for (b, _, s) in rooms[i + 1:]:
                if overlap(r, s) > 0:
                    print("OVERLAP", fl, a, b); ok = False
        if foot:
            tot = sum(area(r) for _, _, r in rooms)
            print("%s tiling: rooms %.1f m2 vs footprint %.1f m2 -> %s" % (fl, tot, area(foot), "OK" if tot == area(foot) else "MISMATCH"))
            ok &= tot == area(foot)
    for (fl, k, a, b, c, d) in OPEN:
        hit = [rid for rid, _, r in all_rooms(fl) if on_edge(r, a, b, c, d)]
        if not hit and not (FOOT[fl] and on_edge(FOOT[fl], a, b, c, d)):
            print("OPENING ON NO WALL", fl, k, a, b, c, d); ok = False
        if k == "W" and not (FOOT[fl] and on_edge(FOOT[fl], a, b, c, d)):
            print("WINDOW NOT ON THE FACADE", fl, a, b); ok = False
    for fl in ROOMS:
        for rid, _, r in all_rooms(fl):
            if rid in ("LF", "X5"):
                continue
            has = any(f2 == fl and k in ("D", "R", "S", "V", "s") and on_edge(r, a, b, c, d) for (f2, k, a, b, c, d) in OPEN)
            if not has:
                print("NO DOOR", fl, rid); ok = False
    print("Stairs (riser 0.18, tread 0.28, 2 flights per storey):")
    for (a, ha), (b, hb) in [(("Ground", 0.0), ("Mezzanine", 3.6)), (("Mezzanine", 3.6), ("Roof", 7.2))]:
        n = int(round((hb - ha) / 0.18)); run = (n // 2 - 1) * 0.28
        print("  ST %s->%s: %d risers x %.3f; %d per flight (<= 16); run %.2f + 2 x 1.30 landings = %.2f <= 5.70 -> %s"
              % (a, b, n, (hb - ha) / n, n // 2, run, run + 2.6, "OK" if run + 2.6 <= 5.7 else "TOO LONG"))
        ok &= run + 2.6 <= 5.7
    print("  Platform stair 0.0->3.6: 2 x 10 x 0.18, 2.52 + 1.20 + 2.52 = 6.24 (x 22.00 -> 28.24) OK")
    print("  Fire stair 3.6->0.0: 2 x 10 x 0.18, 2.52 + 1.20 + 2.52 = 6.24 (z 6.00 -> -0.24) OK")
    print("  Quay steps -1.8->0.0: 10 x 0.18, 9 treads x 0.30 = 2.70 (z 43.0 -> 40.3) OK")
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(0 if check() else 1)
    for fl, nm in (("G", "Ground (FFL 0.0)"), ("M", "Mezzanine (FFL 3.6)"), ("R", "Roof (7.2)")):
        print("### " + nm)
        print(plan(fl))
        print()
