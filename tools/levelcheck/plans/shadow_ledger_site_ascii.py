# Generates the ASCII site plan in docs/design/heists/shadow_ledger.md (G0).
# Run: python3 tools/levelcheck/plans/shadow_ledger_site_ascii.py
# 1 char = 2 m (x), 1 row = 2 m (z). Origin = NW corner of Calder Tower's floor plate (same as the
# floor plans), +x east, +z south. Heights are relative to the Calder Tower roof (RF, +11.6 local;
# the street is ~160 m below L40).
X0, X1, Z0, Z1 = -60, 100, -24, 52
S = 2
W = (X1 - X0) // S + 1
H = (Z1 - Z0) // S + 1
g = [[" "] * W for _ in range(H)]


def put(x, z, ch):
    i, j = (x - X0) // S, (z - Z0) // S
    if 0 <= i < W and 0 <= j < H: g[j][i] = ch


def fill(x0, z0, x1, z1, ch):
    for z in range(z0, z1 + 1, S):
        for x in range(x0, x1 + 1, S): put(x, z, ch)


def box(x0, z0, x1, z1, ch="#"):
    for x in range(x0, x1 + 1, S): put(x, z0, ch); put(x, z1, ch)
    for z in range(z0, z1 + 1, S): put(x0, z, ch); put(x1, z, ch)


def txt(x, z, s):
    i, j = (x - X0) // S, (z - Z0) // S
    for k, ch in enumerate(s):
        if 0 <= i + k < W and 0 <= j < H: g[j][i + k] = ch


# gaps / streets far below (drawn first; labels overwrite)
for z in range(-6, 32, S): put(-10, z, ":")
for z in range(-6, 32, S): put(50, z, ":")
# river and Riverside Drive (north, far below)
fill(-60, -24, 100, -20, "~"); txt(-56, -22, " KESTREL RIVER (far below; bridges lit) ")
txt(-56, -16, "RIVERSIDE DRIVE (street level, ~160 m below)")
# Arden Tower (west, taller: roof +22 m) and Vantage House (east, lower: roof -12 m)
fill(-60, -6, -22, 30, "%"); txt(-56, 8, " ARDEN TOWER "); txt(-56, 10, " 48 st, roof+22 ")
box(66, -2, 100, 28, "%"); fill(68, 0, 98, 26, "."); txt(70, 8, "VANTAGE HOUSE"); txt(70, 10, "roof -12 (L40)")
txt(70, 14, "E2 line end"); txt(70, 16, "[SECURE]")
# Calder Tower: roof 0..36 x 0..18 ; terrace 18..24 (3.6 m lower)
box(0, 0, 36, 18, "#"); box(0, 18, 36, 24, "r")
txt(2, 4, "CALDER"); txt(2, 6, "TOWER RF"); txt(2, 20, "terrace L42")
box(24, 2, 34, 12, "*"); txt(26, 6, "pad"); txt(26, 8, "E1")
txt(-20, 26, "QUARRY LN (20 m)"); txt(38, 26, "HALE ST (30 m)")
# insertion line from Arden (west) and the bag/escape line to Vantage (east)
for x in range(-20, 0, S): put(x, 14, "-")
txt(-20, 12, "insertion line ->")
for x in range(38, 66, S): put(x, 16, "=")
txt(38, 12, "E2 bag+escape")
txt(38, 14, "line, -12 m")
txt(2, 16, "P spawn SW")
# Calder Street (south) and the towers beyond
txt(-56, 36, "CALDER STREET (street level, ~160 m below; LED street lights, traffic)")
fill(-60, 42, 100, 52, "%"); txt(-50, 46, " SOUTH SKYLINE: 30-40 storey towers, lit floors, beacons ")
# police (unused in stealth-only; required by the contract)
txt(4, -6, "P3 roof (rappel from heli)")
txt(-8, 30, "P1 Stair A (below)"); txt(30, 30, "P2 Stair B (below)"); txt(4, 32, "P4 passenger lifts (L41)")
r = [" "] * W
for x in (-60, -40, -20, 0, 20, 40, 60, 80, 100):
    for k, ch in enumerate(str(x)):
        i = (x - X0) // S + k
        if i < W: r[i] = ch
print("   x  " + "".join(r).rstrip())
for j, row in enumerate(g):
    z = Z0 + j * S
    print(("%4d  " % z if (z % 4 == 0) else "      ") + "".join(row).rstrip())
