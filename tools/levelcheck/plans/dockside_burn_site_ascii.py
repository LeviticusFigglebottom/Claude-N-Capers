# ASCII site plan for docs/design/heists/dockside_burn.md (G0 approved D-064). 1 char = 2 m (x and z).
# Run: python3 tools/levelcheck/plans/dockside_burn_site_ascii.py
# Same origin and axes as the floor plans (the Ortega building's NW corner, +x east, +z south); the
# numbers are those of game/world/heists/dockside_burn/greybox/dockside_burn_layout.gd (site blocks,
# fences, spawns, perches, escapes).
X0, X1, Z0, Z1 = -30, 110, -52, 60
S = 2
W, H = (X1 - X0) // S + 1, (Z1 - Z0) // S + 1
g = [[" "] * W for _ in range(H)]


def put(x: float, z: float, ch: str) -> None:
    i, j = int((x - X0) // S), int((z - Z0) // S)
    if 0 <= i < W and 0 <= j < H:
        g[j][i] = ch


def fill(x0: float, z0: float, x1: float, z1: float, ch: str) -> None:
    z = z0
    while z < z1:
        x = x0
        while x < x1:
            put(x, z, ch)
            x += S
        z += S


def txt(x: float, z: float, s: str) -> None:
    for k, ch in enumerate(s):
        put(x + k * S, z, ch)


def hline(x0: float, x1: float, z: float, ch: str) -> None:
    fill(x0, z, x1, z + 0.1, ch)


def vline(x: float, z0: float, z1: float, ch: str) -> None:
    fill(x, z0, x + 0.1, z1, ch)


fill(-30, 44, 110, 62, "~"); fill(62, -32, 72, 44, "~")                 # harbour, the slip
hline(-30, 110, -52, "="); txt(8, -52, "S3"); txt(20, -52, "RAIL VIADUCT +7.0")
txt(-24, -46, "P1w"); txt(70, -46, "P1e"); txt(10, -46, "FERRO STREET")
vline(-12, -52, -34, "x"); vline(66, -52, -34, "x"); put(-12, -43, "g"); put(66, -43, "g")
hline(-8, 30, -34, "#"); hline(38, 84, -34, "#"); put(-4, -34, "g"); txt(30, -36, "gate PPPP")
fill(-30, -32, -10, -18, "%"); fill(-30, -10, -10, 40, "%"); txt(-28, 0, "BELLWEATHER"); txt(-16, 38, "S2")
txt(-26, -14, "P2"); vline(-8, -34, 44, "|"); put(-8, -14, "g")
for z in (-28.0, -22.0, -16.0):                                          # K1-K3, K4-K6 (one high)
    fill(2, z, 14, z + 2.4, "K"); fill(46, z, 58, z + 2.4, "K")
txt(4, -26, "K1"); txt(4, -20, "K2"); txt(4, -14, "K3"); txt(48, -26, "K4"); txt(48, -20, "K5"); txt(48, -14, "K6")
fill(2, -8, 14, -5.6, "k"); txt(4, -6, "D1x2")
fill(24, -32, 30, -28, "h"); txt(24, -30, "GH"); fill(30, -32, 38, -18, "w"); txt(32, -24, "E1")
fill(0, 0, 48, 32, "#"); txt(4, 4, "OFFICE+7.2"); txt(22, 4, "HALL +6.6"); txt(22, 18, "COLD STORE +9.0 P5")
txt(4, 24, "PACKING"); txt(-6, 6, "E2")
fill(12, 34, 20, 40, "s"); txt(14, 36, "QS"); fill(23, 44, 25, 50, ":"); fill(16, 50, 32, 54, "=")
txt(22, 52, "PP"); fill(17, 54, 30, 58, "b"); txt(32, 56, "E3 boat")
fill(56, 40, 58, 44, "v"); fill(52, 44, 62, 48, "-"); txt(58, 46, "P4"); fill(63, 48, 80, 53, "T"); txt(70, 50, "S4")
fill(61, -14.5, 73, -11.5, "="); txt(64, -10, "gangway")
fill(72, -34, 84, 44, " "); vline(84, -34, 44, "|"); put(84, -14, "g"); txt(88, -14, "P3")
fill(88, -34, 100, -18, "%"); fill(88, -10, 100, 44, "%")
for x in (74, 80):
    vline(x, -8, 8, "H")
txt(78, 0, "S1"); txt(-8, 44, "o")
ruler = [" "] * W
for x in range(X0, X1 + 1, 10):
    for k, ch in enumerate(str(x)):
        i = (x - X0) // S + k
        if i < W:
            ruler[i] = ch
print("     x " + "".join(ruler))
for j, row in enumerate(g):
    z = Z0 + j * S
    print(("%5d " % z if z % 4 == 0 else "      ") + "".join(row).rstrip())
