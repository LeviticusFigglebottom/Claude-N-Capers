# Generates the ASCII site plan in docs/design/heists/night_deposit.md (G0). 1 char = 1 m.
X0, X1, Z0, Z1 = -14, 40, -16, 40
W, H = X1 - X0 + 1, Z1 - Z0 + 1
g = [[" "] * W for _ in range(H)]


def put(x: int, z: int, ch: str) -> None:
    if 0 <= x - X0 < W and 0 <= z - Z0 < H:
        g[z - Z0][x - X0] = ch


def fill(x0: int, z0: int, x1: int, z1: int, ch: str) -> None:
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            put(x, z, ch)


def txt(x: int, z: int, s: str) -> None:
    for k, ch in enumerate(s):
        put(x + k, z, ch)


def box(x0: int, z0: int, x1: int, z1: int) -> None:
    for x in range(x0, x1 + 1):
        put(x, z0, "#")
        put(x, z1, "#")
    for z in range(z0, z1 + 1):
        put(x0, z, "#")
        put(x1, z, "#")


fill(-14, -16, 26, -15, "%"); txt(-12, -16, " WAREHOUSE BACKS + chain-link (dressing) ")
txt(-12, -13, "ALLEY (5 m) W->E"); put(-14, -12, "X"); put(-14, -11, "X"); txt(-12, -12, "gate P4")
for x in range(-14, 27):
    put(x, -10, "_")
txt(-2, -7, "STAFF PARKING LOT"); fill(0, -5, 3, -3, "v"); txt(4, -4, "E1 van")
txt(6, -2, "[BH]"); txt(17, -2, "=grate"); txt(22, -6, "cars")
box(0, 0, 26, 20); txt(3, 6, "HARBOR SAVINGS & LOAN"); txt(5, 8, "(1 storey + basement)")
txt(3, 13, "banking hall roof +6.5"); txt(3, 3, "back wing roof +3.6")
fill(-14, 0, -1, 20, "%"); txt(-12, 9, " PELL & SONS "); txt(-12, 10, " CHANDLERY  ")
for z in range(-10, 21):
    put(27, z, ":")
    put(29, z, "|")
    put(36, z, "|")
txt(30, 4, "WHARF"); txt(30, 5, "LANE"); txt(30, -12, "P3"); txt(30, 12, "P2->")
fill(37, -14, 40, 20, "%"); txt(31, -15, "CRANE YD")
for x in range(-14, 41):
    put(x, 21, "_")
    put(x, 23, "_")
    put(x, 31, "_")
txt(-12, 22, "SIDEWALK  P P P P"); txt(-12, 27, "HARBOR STREET (2 lanes + parking)"); txt(-13, 29, "<-P1")
txt(-12, 32, "QUAY  [bollards]"); txt(6, 32, "steps"); fill(6, 34, 11, 35, "b"); txt(12, 34, "E2 boat")
fill(-14, 34, 5, 40, "~"); fill(12, 35, 40, 40, "~"); fill(6, 36, 11, 40, "~"); txt(-10, 37, " HARBOR WATER (fog; moored boats, far shore lights) ")
r = [" "] * W
for x in (-10, 0, 10, 20, 30, 40):
    for k, ch in enumerate(str(x)):
        if x - X0 + k < W:
            r[x - X0 + k] = ch
print("   x  " + "".join(r))
for j, row in enumerate(g):
    z = Z0 + j
    print(("%4d  " % z if z % 2 == 0 else "      ") + "".join(row).rstrip())
