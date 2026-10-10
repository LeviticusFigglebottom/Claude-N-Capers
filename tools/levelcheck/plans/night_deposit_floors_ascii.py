# Generates the ASCII floor plans in docs/design/heists/night_deposit.md (G0).
# Run: python3 tools/levelcheck/plans/night_deposit_floors_ascii.py
# 1 char = 0.5 m; each char is a grid POINT (x = 0.5*col). Rooms are rectangles (x0,z0,x1,z1) in
# metres between wall centre lines. Origin = NW corner, +x east, +z south (Harbor St at the bottom).
W, H = 26, 20
ROOMS = {
 "G": [
  ("G1", "LOADING/SALLY", (0, 0, 7, 6)), ("G2", "STAIR", (7, 0, 10, 6)),
  ("G3", "SECURITY", (10, 0, 14, 6)), ("G4", "BREAK", (14, 0, 18, 6)),
  ("G5", "ELEC", (18, 0, 21, 6)), ("G6", "STORAGE", (21, 0, 26, 6)),
  ("G7", "STAFF CORRIDOR", (0, 6, 26, 7.5)), ("G8", "TELLER WORKROOM", (0, 7.5, 21, 10)),
  ("G9", "BANKING HALL", (0, 10, 21, 20)), ("G10", "VEST", (8.5, 18, 12.5, 20)),
  ("G11", "LOAN", (21, 7.5, 26, 12)), ("G12", "MANAGER", (21, 12, 26, 16)),
  ("G13", "ATM 24h", (21, 16, 26, 20))],
 "B": [
  ("B1", "XFER", (0, 0, 7, 6)), ("G2", "STAIR", (7, 0, 10, 6)),
  ("B2", "LOCKERS+WC", (10, 0, 16, 6)), ("B3", "PLANT", (16, 0, 21, 6)),
  ("B4", "SERVER", (21, 0, 26, 6)), ("B5", "CORRIDOR", (0, 6, 26, 7.5)),
  ("B6", "RECORDS", (0, 7.5, 7, 20)), ("B7", "INSP", (7, 7.5, 9, 20)),
  ("B8", "ANTECHAMBER", (9, 7.5, 19, 10)), ("B9", "VAULT", (9, 10, 19, 20)),
  ("B10", "INSP", (19, 7.5, 21, 20)), ("B11", "COUNT RM", (21, 7.5, 26, 14)),
  ("B12", "DEPOSITORY", (21, 14, 26, 20)), ("B13", "WC", (13.5, 0, 16, 2.5)), ("B14", "JAN", (7, 3.5, 8.5, 6))],
}
# openings: (floor, kind, x0, z0, x1, z1)  D door, W window, O open (no wall), R roller door
OPEN = [
 ("G", "R", 2, 0, 5, 0), ("G", "D", 6, 0, 6, 0),            # sally roller door + personnel door (lot)
 ("G", "D", 6, 6, 6, 6), ("G", "O", 7.5, 6, 8, 6),          # loading->corridor; stair entry (flight 1 down)
 ("G", "R", 8.5, 6, 10, 6),                                  # 1.05 m railing over the shaft (flight 2 below)
 ("G", "C", 2, 10, 19, 10),                                  # teller counter 1.05 m with bandit glass
 ("G", "D", 12, 6, 12, 6), ("G", "D", 16, 6, 16, 6), ("G", "D", 19.5, 6, 19.5, 6), ("G", "D", 23.5, 6, 23.5, 6),
 ("G", "D", 26, 6.5, 26, 7), ("G", "D", 2, 7.5, 2, 7.5),    # fire exit Wharf Ln; teller workroom door
 ("G", "D", 23.5, 7.5, 23.5, 7.5), ("G", "D", 1, 10, 1, 10),  # loan->corridor; teller gate
 ("G", "D", 21, 10.5, 21, 10.5), ("G", "D", 21, 14, 21, 14),  # loan->hall, manager->hall (glass fronts)
 ("G", "D", 21, 18, 21, 18),                                # ATM vestibule inner glass door
 ("G", "D", 10, 18, 11, 18), ("G", "D", 10, 20, 11, 20),    # vestibule inner/outer double doors
 ("G", "D", 24, 20, 24.5, 20),                              # ATM street door
 ("G", "W", 1, 20, 7.5, 20), ("G", "W", 13.5, 20, 20, 20),  # banking hall tall windows (sill 1.0)
 ("G", "W", 26, 13, 26, 15), ("G", "W", 26, 9, 26, 11), ("G", "W", 22, 20, 23, 20), ("G", "W", 25, 20, 25.5, 20),
 ("B", "O", 9, 6, 9.5, 6), ("B", "D", 7.75, 6, 7.75, 6), ("B", "D", 3.5, 6, 3.5, 6), ("B", "D", 12, 6, 12, 6), ("B", "D", 18.5, 6, 18.5, 6),
 ("B", "D", 23.5, 6, 23.5, 6), ("B", "D", 3.5, 7.5, 3.5, 7.5), ("B", "D", 8, 7.5, 8, 7.5),
 ("B", "D", 13, 7.5, 15, 7.5), ("B", "D", 20, 7.5, 20, 7.5), ("B", "D", 23.5, 7.5, 23.5, 7.5),
 ("B", "D", 13.5, 10, 14.5, 10),                            # vault door (round, 2.2 m)
 ("B", "D", 23.5, 14, 23.5, 14),                            # count room -> depository
 ("B", "D", 14.75, 2.5, 14.75, 2.5),                        # WC cubicle door
]
MARK = {"G": [(2, 2, "L"), (4.5, 0.5, "lift"), (7.5, 1.5, "v  ^"), (7.5, 3, "v  ^"), (7.5, 4.5, "v  ^"), (11, 2, "#mon"), (11, 3, "o"), (13, 4.5, "K"), (15, 2, "K"),
              (22, 13, "K"), (1, 8.5, "K"), (10, 13, "(@)"), (4, 12, "G"), (17, 17, "G"),
              (22.5, 18.5, "$ $ v")],
       "B": [(4.5, 0.5, "lift"), (7.5, 1.5, "v  ^"), (7.5, 2.5, "v  ^"), (13, 15, "[cage]"), (12, 17.5, "L L L"), (9.5, 12, "|box"),
             (17.5, 12, "box|"), (10, 8.5, ":::::laser:::::"), (17, 8.5, "TL"), (17, 3, "H^"),
             (23, 3, "SRV"), (22, 17, "S L"), (3, 15, "K"), (14, 6.5, "G")]}


def grid(w: float, h: float) -> list:
    return [[" "] * (int(w * 2) + 1) for _ in range(int(h * 2) + 1)]


def put(g: list, x: float, z: float, ch: str) -> None:
    i, j = int(round(x * 2)), int(round(z * 2))
    if 0 <= j < len(g) and 0 <= i < len(g[0]):
        g[j][i] = ch


def seg(g: list, x0: float, z0: float, x1: float, z1: float, ch: str) -> None:
    n = int(round(max(abs(x1 - x0), abs(z1 - z0)) * 2))
    for k in range(n + 1):
        t = k / max(n, 1)
        put(g, x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, ch)


def txt(g: list, x: float, z: float, s: str) -> None:
    i, j = int(round(x * 2)), int(round(z * 2))
    for k, ch in enumerate(s):
        if 0 <= i + k < len(g[0]):
            g[j][i + k] = ch


def plan(fl: str) -> str:
    g = grid(W, H)
    for _rid, _lab, (a, b, c, d) in ROOMS[fl]:
        for (p, q, r, s, ch) in [(a, b, c, b, "-"), (a, d, c, d, "-"), (a, b, a, d, "|"), (c, b, c, d, "|")]:
            seg(g, p, q, r, s, ch)
    for (p, q, r, s) in [(0, 0, W, 0), (0, H, W, H), (0, 0, 0, H), (W, 0, W, H)]:
        seg(g, p, q, r, s, "#")
    if fl == "B":  # vault walls 0.6 m drawn heavy
        for (p, q, r, s) in [(9, 10, 19, 10), (9, 20, 19, 20), (9, 10, 9, 20), (19, 10, 19, 20)]:
            seg(g, p, q, r, s, "%")
    for (f, k, a, b, c, d) in OPEN:
        if f == fl:
            seg(g, a, b, c, d, {"O": " ", "C": "=", "R": "r" if f == "G" and b == 6 else "R"}.get(k, k))
    for rid, lab, (a, b, c, d) in ROOMS[fl]:
        w = c - a
        s = rid + " " + lab if len(rid + " " + lab) <= int(w * 2) - 1 else rid
        if (d - b) <= 1.5 and rid not in ("G7", "B5"):
            continue
        txt(g, a + 0.5, b + 0.5, s)
    for (x, z, s) in MARK.get(fl, []):
        txt(g, x, z, s)
    out = ["      " + "".join((str(int(k / 2) % 10) if k % 2 == 0 else " ") for k in range(int(W * 2) + 1))]
    for j, row in enumerate(g):
        out.append(("%5.1f " % (j * 0.5) if j % 2 == 0 else "      ") + "".join(row).rstrip())
    return "\n".join(out)


if __name__ == "__main__":
    print("GROUND (FFL 0.0)")
    print(plan("G"))
    print()
    print("BASEMENT (FFL -4.0)")
    print(plan("B"))
