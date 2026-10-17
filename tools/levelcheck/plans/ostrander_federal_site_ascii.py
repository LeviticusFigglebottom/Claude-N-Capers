# Scaled site plan for docs/design/heists/ostrander_federal.md ("Site plan"), generated from the same coordinates the
# greybox uses (ostrander_federal_slots.py: exterior rooms, grade, closures, neighbours, police islands, spawns,
# perches, escapes). Owner: ENV C (OF-C1).
# Run: python3 tools/levelcheck/plans/ostrander_federal_site_ascii.py            (the plan, 1 char = 2 m)
#      python3 tools/levelcheck/plans/ostrander_federal_site_ascii.py --check    (every marker inside the drawn area)
import os
import sys
from typing import List, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ostrander_federal_slots as S  # noqa: E402

X0, X1, Z0, Z1 = -46, 96, -50, 92
STEP = 2.0
LEGEND = ("# the bank  % neighbours / Corvino  = parking deck  ~ the avenue / plaza (-0.75)  . lane / Tannery (0.0)\n"
          "! closures  p police islands  P player spawns  1-5 police spawns P1-P5  S sniper perches  E escapes  "
          "f fire escape  * lantern  ^ plaza steps")


def _grid() -> List[List[str]]:
    w = int((X1 - X0) / STEP) + 1
    h = int((Z1 - Z0) / STEP) + 1
    return [[" "] * w for _ in range(h)]


def _fill(g: List[List[str]], x0: float, z0: float, x1: float, z1: float, ch: str) -> None:
    for j in range(len(g)):
        z = Z0 + j * STEP
        for i in range(len(g[0])):
            x = X0 + i * STEP
            if x0 <= x < x1 and z0 <= z < z1:
                g[j][i] = ch


def _put(g: List[List[str]], x: float, z: float, ch: str) -> bool:
    i, j = int(round((x - X0) / STEP)), int(round((z - Z0) / STEP))
    if 0 <= j < len(g) and 0 <= i < len(g[0]):
        g[j][i] = ch
        return True
    return False


def plan() -> Tuple[str, List[str]]:
    g = _grid()
    missing: List[str] = []
    for nm, r, y, _cls in S.GRADE:
        _fill(g, r[0], r[1], r[2], r[3], "~" if y < 0 else ".")
    for p in S.POLICE_ISLANDS:
        r = p[1]
        _fill(g, r[0], r[1], r[2], r[3], "p")
    for nm, b, _cls in S.CLOSURES:
        ch = "=" if nm == "ParkingStructure" else ("%" if b[4] > 4.0 else "!")
        _fill(g, b[0], b[2], b[3], b[5], ch)
    _fill(g, 0, 0, 48, 36, "#")
    _fill(g, 14, 22, 30, 30, "*")
    _fill(g, 18, 38, 30, 40, "^")
    _fill(g, -6, -2.4, 1.6, -0.2, "f")
    marks = [(x, z, "P") for _n, _t, _f, _r, x, z, _y in S.PLAYER_SPAWNS]
    marks += [(x, z, nm[1]) for nm, _t, x, z, _y in S.POLICE_SPAWNS]
    marks += [(24.0, 63.4, "S"), (40.0, -11.0, "S"), (-5.4, 24.0, "S")]
    marks += [(x, z, "E") for _s, k, _f, _r, x, z in S.ESCAPE_ZONES if k == "SECURE_LOOT"]
    for x, z, ch in marks:
        if not _put(g, x, z, ch):
            missing.append("%s at (%g, %g)" % (ch, x, z))
    lines = ["     x " + "".join(("%-10d" % (X0 + i * STEP)) for i in range(0, len(g[0]), 5))]
    for j, row in enumerate(g):
        z = Z0 + j * STEP
        lines.append(("%5d " % z if j % 2 == 0 else "      ") + "".join(row).rstrip())
    return "\n".join(lines) + "\n" + LEGEND, missing


if __name__ == "__main__":
    text, miss = plan()
    if "--check" in sys.argv:
        for m in miss:
            print("FAIL marker outside the site drawing: " + m)
        print("RESULT:", "PASS" if not miss else "FAIL")
        sys.exit(0 if not miss else 1)
    print(text)
