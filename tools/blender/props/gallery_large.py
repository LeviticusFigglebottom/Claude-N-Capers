"""Gallery Night large visuals (GN-C2): the gala limousine (secure_zone, E2 at the portico kerb) and the art-lift car
(bag_lift, 3 landings). Blender +Y = Godot -Z; floor pivots.

* ``veh_limo_gala``: a long black sedan (6.5 m): bonnet, a long glasshouse with tinted windows and chrome belt line,
  the boot open (the lid raised; the boot is the secure point, gallery_night.md Escape). Nodes `Body`, `DoorL` /
  `DoorR` (the rear passenger doors, pivots on their front edges, closed), `DropAnchor` behind the boot. The rear
  faces Blender +Y (Godot -Z) as the van's does.
* ``prop_art_lift_car``: the art lift's 2.6 x 5.6 m car (bag_lift visual): chequer floor (top 12 mm over the car
  origin), corner posts, mesh walls on the back and the +X side, the -X side open (the second landing door), a top
  frame with a light bar, the car operating `Panel` on the +X wall by the gate. `DoorL` / `DoorR` are folding scissor
  gates across the front (+Y), each centred on its half so A's `door_fold` (outer edge fixed) concertinas them.
"""

import math

from _pb import Kit

TRI_BUDGET = 12000
VARIANTS = {
    "veh_limo_gala": {"fn": "limo", "cat": {"prefab": "secure_zone", "kind": "limo", "surface": "metal"}},
    "prop_art_lift_car": {"fn": "lift_car", "cat": {"prefab": "bag_lift", "kind": "lift_car", "surface": "metal"}},
    # OF-C2 (Ostrander Federal cash lift, B <-> G in the 2.8 m GL shaft): a 2.4 x 2.4 m car (2.2 m inside, the
    # prefab's car_size_m), the +X side open for the ground-floor landing door.
    "prop_cash_lift_car_w240": {"fn": "lift_car", "w": 2.4, "ln": 2.4, "hgt": 2.6, "open": 1, "tread": (10, 10),
                                "cat": {"prefab": "bag_lift", "kind": "lift_car", "surface": "metal"}},
}


# -------------------------------------------------------------------------------------- limo

def _arch_pts(cy: float, r: float, base: float, axle: float, n: int = 10) -> list[tuple[float, float]]:
    """Wheel-arch notch in a side profile (y, z), front edge first, travelling +Y."""
    pts = [(cy - r, base)]
    for i in range(n + 1):
        a = math.pi - math.pi * i / n
        pts.append((cy + r * math.cos(a), axle + r * math.sin(a)))
    pts.append((cy + r, base))
    return pts


def _glass_strip(p, a: tuple[float, float], b: tuple[float, float], x0: float, x1: float) -> None:
    """Glass on the (y, z) segment a -> b, 4-12 mm proud of the shell on its outer (upper) side."""
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, nz = (b[1] - a[1]) / ln, -(b[0] - a[0]) / ln
    if nz < 0:
        nx, nz = -nx, -nz
    p.profile_x([(a[0] + nx * 0.004, a[1] + nz * 0.004), (b[0] + nx * 0.004, b[1] + nz * 0.004),
                 (b[0] + nx * 0.012, b[1] + nz * 0.012), (a[0] + nx * 0.012, a[1] + nz * 0.012)], x0, x1, "glass_tinted")


def _limo(k: Kit, p: dict) -> None:
    w = 1.96
    hw = w / 2
    yf, yr = -3.25, 3.25
    base, axle, r_arch, r_tyre = 0.22, 0.34, 0.42, 0.34
    fa, ra = -2.2, 1.75
    belt = 0.95
    boot = 2.2
    body = k.obj("Body")
    shell = body.part(bevel=0.03, segments=2)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    run = body.part(bevel=0.0)
    inner = body.part(bevel=0.0)
    # lower body (bonnet to the boot opening), with both wheel arches in the profile
    prof = [(yf + 0.05, base)]
    prof += _arch_pts(fa, r_arch, base, axle)
    prof += _arch_pts(ra, r_arch, base, axle)
    prof += [(boot, base), (boot, belt), (-1.4, belt), (yf + 0.3, 0.84), (yf + 0.02, 0.72), (yf - 0.02, 0.5)]
    shell.profile_x(prof, -hw, hw, "car_black")
    # boot: floor, side walls and the tail, open on top
    shell.bx((-hw, boot, base), (hw, yr - 0.15, 0.5), "car_black")
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw - 0.05)))
        shell.bx((x0, boot, 0.5), (x1, yr - 0.15, belt - 0.02), "car_black")
    shell.profile_x([(yr - 0.15, base), (yr - 0.02, base + 0.05), (yr + 0.02, 0.5), (yr - 0.02, 0.8),
                     (yr - 0.15, belt - 0.02)], -hw, hw, "car_black")
    inner.bx((-hw + 0.06, boot + 0.02, 0.5), (hw - 0.06, yr - 0.17, 0.515), "fabric_charcoal")
    # glasshouse
    gh = [(-1.38, belt), (-0.55, 1.43), (1.45, 1.45), (boot - 0.04, belt)]
    shell.profile_x(gh, -hw + 0.12, hw - 0.12, "car_black")
    _glass_strip(glass, (-1.36, belt + 0.03), (-0.57, 1.41), -hw + 0.2, hw - 0.2)
    _glass_strip(glass, (1.47, 1.43), (boot - 0.07, belt + 0.03), -hw + 0.2, hw - 0.2)
    for sx in (-1, 1):
        # side windows (three lights) proud of the glasshouse sides, chrome surround and belt strip
        g0, g1 = sorted((sx * (hw - 0.12 + 0.004), sx * (hw - 0.12 + 0.012)))
        for y0, y1 in ((-1.2, -0.25), (-0.15, 0.85), (0.95, 1.85)):
            top0 = 1.0 + (1.38 - 1.0) * min(1.0, (y0 + 1.2) / 0.6) if y0 < -0.5 else 1.38
            top1 = 1.38 if y1 < 1.5 else 1.38 - (1.38 - 1.0) * (y1 - 1.5) / 0.65
            glass.profile_x([(y0, 1.0), (y1, 1.0), (y1, top1), (y0, top0)], g0, g1, "glass_tinted")
        c0, c1 = sorted((sx * hw, sx * (hw + 0.008)))
        trim.bx((c0, -1.4, belt - 0.02), (c1, boot - 0.02, belt + 0.005), "chrome")
        trim.bx((c0, yf + 0.4, 0.42), (c1, yr - 0.3, 0.45), "chrome")                     # sill strip
        # door seams: front door, the long middle panel, the rear passenger door (DoorL/DoorR overlay it)
        for yy in (-1.3, -0.2):
            trim.bx((c0, yy, 0.3), (c1, yy + 0.01, belt - 0.03), "plastic_black")
        m0, m1 = sorted((sx * (hw + 0.01), sx * (hw + 0.17)))
        trim.bx((m0, -1.25, 1.02), (m1, -1.18, 1.14), "car_black")                          # mirror
        # wheels: tyre, alloy, hub
        for wy in (fa, ra):
            run.cyl(r_tyre, 0.24, (sx * (hw - 0.14), wy, axle), "rubber", axis="X", segs=24)
            run.cyl(0.22, 0.245, (sx * (hw - 0.14), wy, axle), "chrome", axis="X", segs=18)
            run.cyl(0.07, 0.25, (sx * (hw - 0.14), wy, axle), "steel", axis="X", segs=10)
            run.cyl(0.33, 0.01, (sx * (hw - 0.28), wy, axle), "plastic_black", axis="X", segs=16)
        # tail lights on the rear corners
        l0, l1 = sorted((sx * (hw - 0.2), sx * (hw - 0.02)))
        trim.bx((l0, yr - 0.02, 0.62), (l1, yr + 0.035, 0.76), "metal_red")
        # headlamps
        trim.bx((l0, yf - 0.05, 0.6), (l1, yf + 0.02, 0.7), "emit_cool")
    # grille, bumpers, plates, the bonnet ornament
    trim.bx((-0.42, yf - 0.06, 0.42), (0.42, yf + 0.05, 0.68), "chrome")
    for gz in (0.47, 0.53, 0.59):
        trim.bx((-0.38, yf - 0.07, gz), (0.38, yf - 0.06, gz + 0.02), "plastic_black")
    trim.bx((-hw + 0.05, yf - 0.1, 0.26), (hw - 0.05, yf + 0.1, 0.36), "chrome")
    trim.bx((-hw + 0.05, yr - 0.08, 0.3), (hw - 0.05, yr + 0.1, 0.4), "chrome")
    trim.bx((-0.25, yr + 0.035, 0.44), (0.25, yr + 0.045, 0.56), "plastic_white")
    trim.bx((-0.25, yf - 0.115, 0.37), (0.25, yf - 0.105, 0.41), "plastic_white")
    trim.cyl(0.015, 0.06, (0.0, yf + 0.25, 0.86), "chrome", segs=8)
    # boot lid, raised about its front hinge (65 deg)
    a = math.radians(65)
    ln = yr - 0.2 - boot
    tip = (boot + math.cos(a) * ln, belt + math.sin(a) * ln)
    n = (-math.sin(a), math.cos(a))
    shell.profile_x([(boot, belt), tip, (tip[0] - n[0] * 0.045, tip[1] - n[1] * 0.045),
                     (boot - n[0] * 0.045, belt - n[1] * 0.045)], -hw + 0.04, hw - 0.04, "car_black")
    trim.rod((-0.5, boot + 0.12, belt + 0.02), (-0.5, boot + 0.3, belt + 0.4), 0.008, "steel", segs=6)   # strut
    trim.rod((0.5, boot + 0.12, belt + 0.02), (0.5, boot + 0.3, belt + 0.4), 0.008, "steel", segs=6)
    body.build()
    # rear passenger doors: overlays on the long middle panel, hinged on their front edges
    for name, sx in (("DoorL", -1), ("DoorR", 1)):
        piv = k.empty(name, (sx * (hw + 0.004), -0.2, 0.3))
        dm = k.obj(name + "Mesh", parent=piv)
        dp = dm.part(bevel=0.004)
        x0, x1 = sorted((0.0, sx * 0.012))
        dp.bx((x0, 0.012, 0.0), (x1, 1.05, belt - 0.33), "car_black")
        h0, h1 = sorted((sx * 0.012, sx * 0.03))
        dp.bx((h0, 0.85, 0.5), (h1, 0.98, 0.53), "chrome")
        dm.build()
    k.empty("DropAnchor", (0.0, yr + 0.7, 0.1))


# --------------------------------------------------------------------------------- lift car

def _lift_car(k: Kit, p: dict) -> None:
    """The bag-lift car. Params (defaults = GN's art lift): ``w`` / ``ln`` / ``hgt`` the car (m), ``open`` the side
    left open for the second landing door (-1 = -X, +1 = +X; the mesh wall and the `Panel` go on the other side),
    ``tread`` the chequer grid (columns, rows)."""
    w, ln, hgt = p.get("w", 2.6), p.get("ln", 5.6), p.get("hgt", 2.6)
    so = p.get("open", -1)          # open side sign
    sw = -so                        # walled (+ panel) side sign
    tcols, trows = p.get("tread", (10, 22))
    hw, hl = w / 2, ln / 2
    car = k.obj("Car")
    fl = car.part(bevel=0.003)
    fl.bx((-hw, -hl, 0.0), (hw, hl, 0.012), "metal_grey")
    tread = car.part(bevel=0.0)
    for i in range(tcols):
        for j in range(trows):
            cx = -hw + (i + 0.5) * w / tcols
            cy = -hl + (j + 0.5) * ln / trows
            ang = 0.25 if (i + j) % 2 == 0 else -0.25
            dx, dy = 0.07 * math.cos(ang * math.pi), 0.07 * math.sin(ang * math.pi)
            tread.rod((cx - dx, cy - dy, 0.014), (cx + dx, cy + dy, 0.014), 0.004, "metal_grey", segs=4, square=True)
    fr = car.part(bevel=0.003)
    for sx in (-1, 1):
        for sy in (-1, 1):
            fr.bx((sx * hw - 0.04, sy * hl - 0.04, 0.0), (sx * hw + 0.04, sy * hl + 0.04, hgt), "metal_dark")
        fr.bx((sx * hw - 0.04, -hl, hgt - 0.08), (sx * hw + 0.04, hl, hgt), "metal_dark")
    fr.bx((-hw, -hl - 0.04, hgt - 0.08), (hw, -hl + 0.04, hgt), "metal_dark")
    fr.bx((-hw, hl - 0.04, hgt - 0.08), (hw, hl + 0.04, hgt), "metal_dark")
    fr.bx((-hw, hl - 0.04, 2.08), (hw, hl + 0.04, 2.14), "metal_dark")          # gate head rail
    fr.bx((-hw, -0.03, hgt - 0.1), (hw, 0.03, hgt - 0.04), "metal_dark")         # cross bar with the light
    lamp = car.part(bevel=0.0)
    lx = min(1.0, hw - 0.2)
    lamp.bx((-lx, -0.06, hgt - 0.13), (lx, 0.06, hgt - 0.1), "steel")
    lamp.bx((-lx + 0.05, -0.04, hgt - 0.134), (lx - 0.05, 0.04, hgt - 0.13), "emit_cool")
    # walls: kick plate + mesh on the back (-Y) and the walled side; a handrail on the open side
    mesh = car.part(bevel=0.0)
    kick = car.part(bevel=0.002)
    kick.bx((-hw + 0.04, -hl + 0.005, 0.012), (hw - 0.04, -hl + 0.02, 0.32), "steel")
    kick.bx(*sorted_x(sw * (hw - 0.02), sw * (hw - 0.005), (-hl + 0.04, 0.012), (hl - 0.04, 0.32)), "steel")
    kick.bx((-hw + 0.04, -hl + 0.005, 1.0), (hw - 0.04, -hl + 0.03, 1.05), "metal_dark")
    kick.bx(*sorted_x(sw * (hw - 0.03), sw * (hw - 0.005), (-hl + 0.04, 1.0), (hl - 0.04, 1.05)), "metal_dark")
    x = -hw + 0.12
    while x < hw - 0.1:
        mesh.bx((x - 0.003, -hl + 0.01, 0.32), (x + 0.003, -hl + 0.016, hgt - 0.08), "steel_galv")
        x += 0.12
    y = -hl + 0.14
    while y < hl - 0.1:
        mesh.bx(*sorted_x(sw * (hw - 0.016), sw * (hw - 0.01), (y - 0.003, 0.32), (y + 0.003, hgt - 0.08)), "steel_galv")
        y += 0.14
    z = 0.42
    while z < hgt - 0.1:
        mesh.bx((-hw + 0.04, -hl + 0.01, z - 0.003), (hw - 0.04, -hl + 0.016, z + 0.003), "steel_galv")
        mesh.bx(*sorted_x(sw * (hw - 0.016), sw * (hw - 0.01), (-hl + 0.04, z - 0.003), (hl - 0.04, z + 0.003)),
                "steel_galv")
        z += 0.2
    rail = car.part(bevel=0.0)
    rx = so * (hw + 0.02)
    rail.rod((rx, -hl + 0.2, 0.15), (rx, -hl + 0.2, 1.0), 0.02, "metal_yellow", segs=8)
    rail.rod((rx, hl - 0.2, 0.15), (rx, hl - 0.2, 1.0), 0.02, "metal_yellow", segs=8)
    car_obj = car.build()
    # car operating panel on the walled side by the gate
    pan = k.obj("Panel", parent=car_obj)
    pp = pan.part(bevel=0.003)
    pp.bx(*sorted_x(sw * (hw - 0.06), sw * (hw - 0.016), (hl - 0.5, 0.95), (hl - 0.25, 1.5)), "steel")
    btn = pan.part(bevel=0.0)
    bx = sw * (hw - 0.063)
    for i in range(3):
        btn.cyl(0.02, 0.006, (bx, hl - 0.375, 1.1 + i * 0.1), "emit_neutral" if i else "emit_led_green",
                axis="X", segs=10)
    btn.cyl(0.03, 0.006, (bx, hl - 0.375, 1.4), "emit_led_red", axis="X", segs=12)
    pan.build()
    # folding scissor gates, each centred on its half of the front
    gh = 2.04
    for name, sx in (("DoorL", -1), ("DoorR", 1)):
        half = hw - 0.05
        gate = k.obj(name, parent=car_obj, location=(sx * (half / 2 + 0.01), hl - 0.06, 0.03))
        gp = gate.part(bevel=0.0)
        gw = half / 2 - 0.01
        n = 9
        for i in range(n + 1):
            xg = -gw + 2 * gw * i / n
            gp.bx((xg - 0.006, -0.008, 0.0), (xg + 0.006, 0.008, gh), "metal_dark")
        for i in range(n):
            xa = -gw + 2 * gw * i / n
            xb = -gw + 2 * gw * (i + 1) / n
            for z0 in (0.1, 0.7, 1.3):
                gp.rod((xa, 0.012, z0), (xb, 0.012, z0 + 0.6), 0.004, "steel", segs=4, square=True)
                gp.rod((xb, 0.018, z0), (xa, 0.018, z0 + 0.6), 0.004, "steel", segs=4, square=True)
        gp.bx((-gw, -0.012, gh - 0.04), (gw, 0.012, gh), "metal_dark")
        gp.bx((-gw, -0.012, 0.0), (gw, 0.012, 0.04), "metal_dark")
        gate.build()


def sorted_x(xa: float, xb: float, lo_yz: tuple, hi_yz: tuple) -> tuple:
    """(lo, hi) corners of a box spanning x xa..xb (either order) and the given (y, z) ranges."""
    x0, x1 = min(xa, xb), max(xa, xb)
    return (x0, lo_yz[0], lo_yz[1]), (x1, hi_yz[0], hi_yz[1])


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
