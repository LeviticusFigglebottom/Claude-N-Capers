# Generates the ASCII floor plans in docs/design/heists/shadow_ledger.md (G0).
# Run:   python3 tools/levelcheck/plans/shadow_ledger_floors_ascii.py           (plans)
#        python3 tools/levelcheck/plans/shadow_ledger_floors_ascii.py --check   (consistency report)
# 1 char = 0.5 m; each char is a grid POINT (x = 0.5*col). Rooms are rectangles (x0,z0,x1,z1) in
# metres between wall centre lines. Origin = NW corner of the tower floor plate, +x east, +z south
# (north facade / river at the top, Calder Street at the bottom). Levels: L40 (service, FFL 0.0),
# L41 (offices, FFL 3.6), L42 (partners' floor, FFL 8.0), RF (roof, 11.6).
import sys

W, H = 36, 24
FLOOR_HEIGHTS = {"L40": 0.0, "L41": 3.6, "L42": 8.0, "RF": 11.6}

# Shared core (same plan position on every level).
CORE = [("J", "", (12, 7.5, 15, 10.5)), ("LF1", "", (15, 7.5, 18, 10)), ("LF2", "", (18, 7.5, 21, 10)),
        ("SL", "", (21, 7.5, 24, 10.5)), ("SA", "", (12, 10.5, 15, 16.5)), ("WCW", "", (15, 10, 18, 16.5)),
        ("WCM", "", (18, 10, 21, 16.5)), ("SB", "", (21, 10.5, 24, 16.5))]

ROOMS = {
 "L40": [  # only the core and the service rooms are in play; the rest is the sealed vacant floor
  ("S1", "SVC LOBBY", (24, 7.5, 30, 12.5)), ("S3", "", (24, 12.5, 25.5, 16.5)),
  ("S2", "REFUSE", (25.5, 12.5, 30, 16.5))] + CORE,
 "L41": [
  ("K1", "KESSLER", (0, 0, 7, 6)), ("K2", "CONF", (7, 0, 12, 6)), ("K3", "RECEPTION", (12, 0, 24, 7.5)),
  ("K4", "ASSIST", (24, 0, 29, 6)), ("K5", "MOOR", (29, 0, 36, 6)),
  ("K6", "", (0, 6, 12, 7.5)), ("K7", "", (24, 6, 36, 7.5)),
  ("K8", "OPEN OFFICE", (0, 7.5, 10.5, 16.5)), ("K9", "", (10.5, 7.5, 12, 16.5)),
  ("K10", "", (24, 7.5, 25.5, 16.5)), ("K11", "SERVER", (25.5, 7.5, 31, 12.5)),
  ("K12", "IT OFF", (31, 7.5, 36, 12.5)), ("K13", "SECURITY", (25.5, 12.5, 30, 16.5)),
  ("K14", "ELEC", (30, 12.5, 32.5, 16.5)), ("K15", "COPY", (32.5, 12.5, 36, 16.5)),
  ("K16", "CORRIDOR (C2)", (0, 16.5, 36, 18)),
  ("K17", "ARCHIVE", (0, 18, 6, 24)), ("K18", "BREAK", (6, 18, 12, 24)), ("K19", "LIBRARY", (12, 18, 18, 24)),
  ("K20", "", (18, 18, 21, 24)), ("K21", "", (21, 18, 24, 24)), ("K22", "", (24, 18, 27, 24)),
  ("K23", "", (27, 18, 30, 24)), ("K24", "INTERVIEW", (30, 18, 36, 24))] + CORE,
 "L42": [
  ("M1", "LOUNGE", (0, 0, 12, 7.5)), ("M2", "", (12, 0, 24, 7.5)), ("M3", "ART HALL", (24, 0, 29, 7.5)),
  ("M4", "STUDY", (29, 0, 36, 7.5)), ("M5", "BEDROOM", (0, 7.5, 6.5, 13)), ("M6", "BATH", (6.5, 7.5, 10.5, 11)),
  ("M7", "", (6.5, 11, 10.5, 13)), ("M8", "DINING", (0, 13, 10.5, 18)), ("M9", "", (10.5, 7.5, 12, 16.5)),
  ("M10", "", (24, 7.5, 25.5, 16.5)), ("M11", "PANTRY", (25.5, 7.5, 31, 12)),
  ("M12", "ELEC", (25.5, 12, 28, 16.5)), ("M13", "WINE", (28, 12, 31, 16.5)),
  ("M14", "BOARDRM", (31, 7.5, 36, 16.5)), ("M15", "TERRACE CORRIDOR (S42)", (10.5, 16.5, 36, 18))] + CORE,
 "RF": [
  ("R1", "", (12, 7.5, 15, 10.5)), ("R2", "", (12, 10.5, 15, 16.5)), ("R3", "PLANT", (15, 7.5, 24, 16.5))],
}
# Enclosed footprint per level (exterior wall line) and voids (no floor) for the tiling check.
FOOT = {"L40": None, "L41": (0, 0, 36, 24), "L42": (0, 0, 36, 18), "RF": None}
VOID = {"L42": [(12, 0, 20.5, 4)]}   # double-height reception void (open to L41)

# openings: (level, kind, x0, z0, x1, z1); D door, O open (no wall), A facade access panel (openable
# window prefab), X locked door to the sealed vacant floor, g interior glazing (no door)
OPEN = [
 # L40
 ("L40", "D", 24, 9, 24, 9.5), ("L40", "O", 24, 12.5, 25.5, 12.5), ("L40", "D", 25.5, 14.5, 25.5, 14.5),
 ("L40", "D", 24, 15.5, 24, 16), ("L40", "X", 30, 10, 30, 10), ("L40", "X", 12, 15.5, 12, 16),
 # L41 north band
 ("L41", "D", 5.5, 6, 5.5, 6), ("L41", "D", 9.5, 6, 9.5, 6), ("L41", "D", 12, 6.5, 12, 7),
 ("L41", "D", 24, 6.5, 24, 7), ("L41", "D", 26.5, 6, 26.5, 6), ("L41", "D", 30.5, 6, 30.5, 6),
 ("L41", "O", 10.5, 7.5, 12, 7.5), ("L41", "O", 24, 7.5, 25.5, 7.5),
 ("L41", "O", 10.5, 16.5, 12, 16.5), ("L41", "O", 24, 16.5, 25.5, 16.5),
 # L41 open office, core
 ("L41", "D", 2, 7.5, 2, 7.5), ("L41", "D", 10.5, 12, 10.5, 12), ("L41", "D", 5, 16.5, 5, 16.5),
 ("L41", "D", 12, 9, 12, 9), ("L41", "D", 16, 7.5, 17, 7.5), ("L41", "D", 19, 7.5, 20, 7.5),
 ("L41", "D", 24, 9, 24, 9.5), ("L41", "D", 12, 15.5, 12, 16), ("L41", "D", 24, 15.5, 24, 16),
 ("L41", "D", 16.5, 16.5, 16.5, 16.5), ("L41", "D", 19.5, 16.5, 19.5, 16.5),
 # L41 east wing
 ("L41", "D", 25.5, 10, 25.5, 10), ("L41", "g", 31, 9, 31, 11), ("L41", "D", 33.5, 7.5, 33.5, 7.5),
 ("L41", "D", 25.5, 14.5, 25.5, 14.5), ("L41", "D", 31.5, 16.5, 31.5, 16.5), ("L41", "D", 34, 16.5, 34, 16.5),
 # L41 south band
 ("L41", "D", 3, 18, 3, 18), ("L41", "D", 9, 18, 9, 18), ("L41", "D", 15, 18, 15, 18),
 ("L41", "D", 19.5, 18, 19.5, 18), ("L41", "D", 22.5, 18, 22.5, 18), ("L41", "D", 25.5, 18, 25.5, 18),
 ("L41", "D", 28.5, 18, 28.5, 18), ("L41", "D", 33, 18, 33, 18),
 ("L41", "A", 0, 2.5, 0, 3.5),   # gondola west stop: Kessler's facade access panel
 # L42
 ("L42", "O", 12, 4, 12, 7.5), ("L42", "g", 12, 0.5, 12, 3.5), ("L42", "O", 10.5, 7.5, 12, 7.5),
 ("L42", "D", 24, 2.5, 24, 3.5), ("L42", "D", 25, 7.5, 25, 7.5), ("L42", "D", 29, 3.5, 29, 3.5),
 ("L42", "D", 12, 9, 12, 9), ("L42", "D", 16, 7.5, 17, 7.5), ("L42", "D", 19, 7.5, 20, 7.5),
 ("L42", "D", 24, 9, 24, 9.5), ("L42", "D", 12, 15.5, 12, 16), ("L42", "D", 24, 15.5, 24, 16),
 ("L42", "D", 16.5, 16.5, 16.5, 16.5), ("L42", "D", 19.5, 16.5, 19.5, 16.5),
 ("L42", "O", 10.5, 16.5, 12, 16.5), ("L42", "O", 24, 16.5, 25.5, 16.5),
 ("L42", "D", 6.5, 12, 6.5, 12), ("L42", "D", 8.5, 11, 8.5, 11), ("L42", "D", 10.5, 12, 10.5, 12),
 ("L42", "D", 10.5, 15, 10.5, 15),
 ("L42", "D", 25.5, 10, 25.5, 10), ("L42", "D", 25.5, 14, 25.5, 14), ("L42", "D", 29.5, 16.5, 29.5, 16.5),
 ("L42", "D", 33.5, 16.5, 33.5, 16.5),
 ("L42", "D", 4, 18, 5, 18), ("L42", "D", 14, 18, 15, 18), ("L42", "D", 30, 18, 31, 18),  # terrace sliders
 ("L42", "A", 32.5, 0, 33.5, 0),  # gondola north stop: study facade access panel
 # RF (head house, plant)
 ("RF", "D", 12, 15.5, 12, 16), ("RF", "D", 12, 9, 12, 9), ("RF", "D", 15, 12, 15, 12),
 ("RF", "D", 19, 7.5, 20, 7.5),
]
# Facade glazing: every exterior room edge is curtain wall (W) except these solid bays (spandrel /
# party structure). Format (level, x0, z0, x1, z1).
SOLID = [("L42", 34, 18, 35, 18), ("L42", 5.5, 18, 6.5, 18)]  # terrace ladder bay; C12 camera bay

MARK = {
 "L40": [(26, 9.5, "P P"), (21.5, 9.5, "E3"), (26.5, 15, "[BH]"), (16, 6.5, "vacant floor (sealed)"),
         (12.5, 16.5, "gate"), (21.5, 16.5, "gate"), (12.5, 12, "^"), (12.5, 13, "^"), (12.5, 14, "^"),
         (14.5, 12, "v"), (14.5, 13, "v"), (14.5, 14, "v"), (21.5, 12, "^"), (21.5, 13, "^"), (21.5, 14, "^"),
         (23.5, 12, "v"), (23.5, 13, "v"), (23.5, 14, "v"), (16, 12.5, "core WCs"), (16, 13.5, "(no access)")],
 "L41": [(13, 1.0, "^^^^^^___^^^^^^^"), (13, 1.5, "^^^^^^___^^^^^^^"), (16.5, 5, "======="), (17, 4.5, "G K"),
         (13.5, 3, "feature stair"), (1.5, 2.5, "K"), (3, 2, "T"), (32, 2, "T c"), (35.5, 9, "c"), (33, 10.5, "K"),
         (27, 8.5, "xxxxxxxx"), (27, 9, "xL L L x"), (27, 9.5, "x      x"), (27, 10, "x RACK x"), (27, 10.5, "xxxDxxxx"),
         (26.5, 11.5, "c"), (29.5, 13.5, "M"), (29.5, 14, "M"), (29.5, 14.5, "M"), (29.5, 15, "M"), (29, 14.5, "o"),
         (26, 13.5, "K"), (26, 16, "c"), (1, 23, "S L"), (14.5, 9, "R"),
         (12.5, 12, "^"), (12.5, 13, "^"), (12.5, 14, "^"), (14.5, 12, "v"), (14.5, 13, "v"), (14.5, 14, "v"),
         (21.5, 12, "^"), (21.5, 13, "^"), (21.5, 14, "^"), (23.5, 12, "v"), (23.5, 13, "v"), (23.5, 14, "v"),
         (22.5, 0.5, "@1"), (0.5, 7, "@2"), (24.5, 10.5, "@3"), (34.5, 17, "@4"), (34.5, 7, "@5"), (0.5, 8.5, "@11"),
         (4, 12, "G"), (11, 11, "G"), (29, 17, "G")],
 "L42": [(12.5, 0.5, "........ VOID ..."), (12.5, 1.5, "................"), (12.5, 2.5, "................"),
         (12.5, 3.5, "................"), (12, 4, "rrrrrrrrrrrrrrrrr"), (20.5, 0.5, "r"), (20.5, 2.5, "r"), (20.5, 3.5, "r"),
         (21, 1.0, "<"), (21, 1.5, "<"), (1, 1, "K"), (1, 9, "K"), (13, 9.5, "K"), (14.5, 9, "R"), (13, 5, "M2 GALLERY"),
         (31, 2, "T"), (33, 7, "S"), (34, 7, "L"), (33.5, 12, "T"), (27.5, 7, "L L"), (12.5, 7, "@6"),
         (28, 0.5, "@7"), (11, 17.5, "@8"), (6, 18.5, "@12"), (22, 5.5, "G"), (11, 14, "G"), (30, 17, "G"),
         (12.5, 12, "^"), (12.5, 13, "^"), (12.5, 14, "^"), (14.5, 12, "v"), (14.5, 13, "v"), (14.5, 14, "v"),
         (21.5, 12, "="), (21.5, 13, "="), (21.5, 14, "="),
         (23.5, 12, "v"), (23.5, 13, "v"), (23.5, 14, "v")]
        + [(26.5, z * 0.5, ":") for z in range(1, 15)],
 "RF": [(0.5, 0.5, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"),
        (0.5, 1, "~"), (0.5, 1.5, "~"), (0.5, 2, "~"), (0.5, 2.5, "~"), (0.5, 3, "~"),
        (1.5, 1.5, "[BMU + cradle garage]"), (1.5, 2, "BMU rail ~ (N + W parapets)"), (1, 3, "h"), (33, 0.5, "h"),
        (25, 3, "*********************"), (25, 13, "*********************"),
        (25, 8, "*   HELIPAD 10x10   *"), (28.5, 8.5, "E1 (heli)"),
        (14.5, 9, "R"), (12.5, 11.5, "HEAD"), (12.5, 12, "HSE"), (12.5, 12.5, "St.A"),
        (11, 11, "@9"), (23, 6.5, "@10"), (34.5, 17.5, "H"), (34, 16.5, "E2>"), (2, 15.5, "P P P P"),
        (3, 14.5, "(insertion line from Arden Tower, W)"), (6, 10, "G"), (30, 15.5, "G")]
       + [(25, z * 0.5, "*") for z in range(7, 26)] + [(35, z * 0.5, "*") for z in range(7, 26)],
}
CROP = {"L40": (10, 6, 32, 18), "L41": (0, 0, 36, 24), "L42": (0, 0, 36, 24), "RF": (0, 0, 36, 24)}


def grid(w, h): return [[" "] * (int(w * 2) + 1) for _ in range(int(h * 2) + 1)]


def put(g, x, z, ch):
    i, j = int(round(x * 2)), int(round(z * 2))
    if 0 <= j < len(g) and 0 <= i < len(g[0]): g[j][i] = ch


def seg(g, x0, z0, x1, z1, ch):
    n = int(round(max(abs(x1 - x0), abs(z1 - z0)) * 2))
    for k in range(n + 1):
        t = k / max(n, 1); put(g, x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, ch)


def txt(g, x, z, s):
    i, j = int(round(x * 2)), int(round(z * 2))
    for k, ch in enumerate(s):
        if 0 <= i + k < len(g[0]) and 0 <= j < len(g): g[j][i + k] = ch


def ext_edges(lv):
    """Exterior wall segments of a level (facade line)."""
    if lv == "L41": return [(0, 0, 36, 0), (0, 24, 36, 24), (0, 0, 0, 24), (36, 0, 36, 24)]
    if lv == "L42": return [(0, 0, 36, 0), (0, 18, 36, 18), (0, 0, 0, 18), (36, 0, 36, 18)]
    return []


def on_exterior(lv, a, b, c, d):
    for (p, q, r, s) in ext_edges(lv):
        if p == r == a == c and min(q, s) <= min(b, d) and max(b, d) <= max(q, s): return True
        if q == s == b == d and min(p, r) <= min(a, c) and max(a, c) <= max(p, r): return True
    return False


def plan(lv):
    g = grid(W, H)
    rooms = ROOMS[lv]
    for _, _, (a, b, c, d) in rooms:
        for (p, q, r, s) in [(a, b, c, b), (a, d, c, d), (a, b, a, d), (c, b, c, d)]:
            seg(g, p, q, r, s, "+")
    for _, _, (a, b, c, d) in rooms:
        for (p, q, r, s, ch) in [(a, b, c, b, "-"), (a, d, c, d, "-"), (a, b, a, d, "|"), (c, b, c, d, "|")]:
            n = int(round(max(abs(r - p), abs(s - q)) * 2))
            for k in range(1, n):
                t = k / n; i, j = int(round((p + (r - p) * t) * 2)), int(round((q + (s - q) * t) * 2))
                if g[j][i] == "+": g[j][i] = ch
    for e in ext_edges(lv): seg(g, *e, "#")
    if lv in ("L41", "L42"):   # curtain wall: glaze each room's exterior edge between partitions
        for _, _, (a, b, c, d) in rooms:
            for (p, q, r, s) in [(a, b, c, b), (a, d, c, d), (a, b, a, d), (c, b, c, d)]:
                if on_exterior(lv, p, q, r, s):
                    if p == r: seg(g, p, min(q, s) + 0.5, r, max(q, s) - 0.5, "W")
                    else: seg(g, min(p, r) + 0.5, q, max(p, r) - 0.5, s, "W")
        for (l2, a, b, c, d) in SOLID:
            if l2 == lv: seg(g, a, b, c, d, "#")
    if lv == "L42":   # terrace (exterior, L42 level) with 1.1 m glass balustrade
        seg(g, 0, 24, 36, 24, "r"); seg(g, 0, 18, 0, 24, "r"); seg(g, 36, 18, 36, 24, "r")
        txt(g, 2, 21, "TERRACE (exterior; glass balustrade r 1.1 m; OOB zone beyond)")
    if lv == "RF":    # roof parapet; terrace 3.6 m below
        seg(g, 0, 0, 36, 0, "#"); seg(g, 0, 0, 0, 18, "#"); seg(g, 36, 0, 36, 18, "#"); seg(g, 0, 18, 36, 18, "#")
        seg(g, 0, 24, 36, 24, "r"); seg(g, 0, 18, 0, 24, "r"); seg(g, 36, 18, 36, 24, "r")
        txt(g, 2, 21, "(terrace below, L42 level: 3.6 m down; ladder H at the SE parapet)")
    for (l2, k, a, b, c, d) in OPEN:
        if l2 == lv: seg(g, a, b, c, d, " " if k == "O" else ("|" if (k == "g" and a == c) else k))
    for rid, lab, (a, b, c, d) in rooms:
        if rid in ("LF1", "LF2", "SL", "SA", "SB", "WCW", "WCM", "J", "R1", "R2"):
            short = {"LF1": "LIFT", "LF2": "LIFT", "SL": "SVC", "SA": "ST.A", "SB": "ST.B", "WCW": "WC-W",
                     "WCM": "WC-M", "J": "JAN" if lv == "L41" else ("LINEN" if lv == "L42" else ("RISER" if lv == "RF" else "JAN")),
                     "R1": "RISER", "R2": ""}[rid]
            s = short
        else:
            w = c - a
            s = rid if w < 3.5 else (rid + " " + lab if lab and len(rid + " " + lab) <= int(w * 2) - 1 else rid)
        if lv == "L40" and rid in ("WCW", "WCM", "J", "LF1", "LF2"): s = ""
        txt(g, a + 0.5, b + 0.5, s)
    for (x, z, s) in MARK.get(lv, []): txt(g, x, z, s)
    x0, z0, x1, z1 = CROP[lv]
    i0, i1, j0, j1 = int(x0 * 2), int(x1 * 2), int(z0 * 2), int(z1 * 2)
    out = ["      " + "".join((str(int(k / 2) % 10) if k % 2 == 0 else " ") for k in range(i0, i1 + 1))]
    for j in range(j0, j1 + 1):
        row = "".join(g[j][i0:i1 + 1]).rstrip()
        out.append(("%5.1f " % (j * 0.5) if j % 2 == 0 else "      ") + row)
    return "\n".join(out)


def area(r): return (r[2] - r[0]) * (r[3] - r[1])


def overlap(r, s):
    return max(0, min(r[2], s[2]) - max(r[0], s[0])) * max(0, min(r[3], s[3]) - max(r[1], s[1]))


def check():
    ok = True
    for lv, foot in FOOT.items():
        rooms = ROOMS[lv]
        for i, (a, _, r) in enumerate(rooms):
            for (b, _, s) in rooms[i + 1:]:
                if overlap(r, s) > 0: print("OVERLAP", lv, a, b); ok = False
        if foot:
            tot = sum(area(r) for _, _, r in rooms) - sum(area(v) for v in VOID.get(lv, []))
            fa = area(foot) - sum(area(v) for v in VOID.get(lv, []))
            print("%s tiling: rooms %.2f m2 (minus void) vs footprint %.2f m2 -> %s"
                  % (lv, tot, fa, "OK" if abs(tot - fa) < 1e-6 else "MISMATCH"))
            ok &= abs(tot - fa) < 1e-6
    # every door/opening lies on an edge of >= 1 room of that level; windows only on exterior lines
    for (lv, k, a, b, c, d) in OPEN:
        hit = []
        for rid, _, (x0, z0, x1, z1) in ROOMS[lv]:
            if (a == c and a in (x0, x1) and z0 <= min(b, d) and max(b, d) <= z1) or \
               (b == d and b in (z0, z1) and x0 <= min(a, c) and max(a, c) <= x1): hit.append(rid)
        ext = on_exterior(lv, a, b, c, d)
        if k == "A" and not ext: print("ACCESS PANEL NOT ON FACADE", lv, a, b); ok = False
        if lv == "L42" and b == d == 18 and k == "D": ext = True
        if not hit and not ext: print("OPENING ON NO WALL", lv, k, a, b, c, d); ok = False
        if k in ("D", "O") and len(hit) < 2 and not ext and lv != "RF" and k != "X":
            print("NOTE single-sided opening", lv, k, a, b, hit)
    # every room (except shafts/voids) has a door or opening
    for lv in ROOMS:
        for rid, _, (x0, z0, x1, z1) in ROOMS[lv]:
            if rid in ("LF1", "LF2") or (lv == "L40" and rid in ("J", "WCW", "WCM")): continue
            has = any(l2 == lv and ((a == c and a in (x0, x1) and z0 <= min(b, d) and max(b, d) <= z1) or
                                    (b == d and b in (z0, z1) and x0 <= min(a, c) and max(a, c) <= x1))
                      for (l2, k, a, b, c, d) in OPEN if k in ("D", "O", "X"))
            if not has: print("NO DOOR", lv, rid); ok = False
    # stairs vs floor heights
    print("Stairs (riser 0.15-0.19, tread 0.28, 2 flights per storey, landing every flight):")
    lv = list(FLOOR_HEIGHTS.items())
    for (a, ha), (b, hb) in zip(lv, lv[1:]):
        h = hb - ha
        for n in range(16, 33, 2):
            if 0.15 <= h / n <= 0.19:
                f = n // 2; run = (f - 1) * 0.28
                print("  %s->%s: %.2f m = %d risers x %.4f m; %d per flight (<=16), run %.2f m; "
                      "core clear length 5.70 >= run + 2 x 1.30 landings = %.2f -> %s"
                      % (a, b, h, n, h / n, f, run, run + 2.6, "OK" if run + 2.6 <= 5.7 else "TOO LONG"))
                break
    print("Feature stair L41->L42: 4.40 m = 24 x 0.1833, 2 x 12, 11 treads x 0.28 = 3.08 per flight, "
          "landing 1.50: 3.08+1.50+3.08 = 7.66 m (x 12.84 -> 20.50)")
    print("RESULT:", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    if "--check" in sys.argv: check()
    else:
        for lv in ("L40", "L41", "L42", "RF"):
            print("### %s (FFL %.1f)" % (lv, FLOOR_HEIGHTS[lv])); print(plan(lv)); print()
