"""Escape-zone visuals (PO-13, gameplay_prefabs.md `escape_zone` v1.2, visual_slots.md).

The escape_zone prefab shows its visual only once the escape has arrived (heli lands, the line is
rigged, the lift is live). Pivot = the zone's origin: the centre of its floor footprint. Blender +Y =
Godot -Z. No collision (the prefab owns none; the crew walk into the zone).

* ``veh_heli_escape``: light single-engine helicopter on skids, cabin doors slid open. Nodes `Body`
  (fuselage, skids, tail), `Rotor` (main rotor pivot on the mast axis; ENV A spins it about Godot Y),
  `TailRotor` (pivot on the tail-rotor axis, Godot X). The parked main blades lie fore-aft so the
  model stays on the pad (9 m disc when spinning, well above the parapets). Cabin centred on the
  pivot, nose to Godot -Z.
* ``prop_escape_zipline_rig``: the crew's clip-on station at the E2 anchor: a steel stand with four
  harnesses and their line trolleys, backed against the parapet behind the zone (Godot +Z).
* ``prop_escape_lift_fitout``: the service-lift car made ready: chequer-plate floor, padded freight
  blankets on the side walls, a handrail on the back wall, the car panel lit by the opening and the
  car light on (car 2.7 x 2.7 x 2.6 m, opening on Godot +X).
"""

import math

from _pb import Kit

TRI_BUDGET = 12000
VARIANTS = {
    "veh_heli_escape": {"fn": "heli", "cat": {"prefab": "escape_zone", "kind": "heli", "surface": "metal"}},
    "prop_escape_zipline_rig": {"fn": "zipline_rig", "cat": {"prefab": "escape_zone", "kind": "zipline", "surface": "metal"}},
    # the car light comes on with the escape (the visual is shown on arrival); spot down from the ceiling panel
    "prop_escape_lift_fitout": {"fn": "lift_fitout", "cat": {"prefab": "escape_zone", "kind": "lift", "surface": "metal",
                                                             "light": {"type": "spot", "color": "#F4EEE4", "energy": 2.0, "range": 2.75,
                                                                       "angle": 27, "pos": [0.0, 2.54, 0.0]}}},
}


# ------------------------------------------------------------------------------------- heli

W = 0.78          # fuselage half width
FLOOR = 0.65      # cabin floor underside
ROOF = 2.05


def _glass_on(p, a: tuple[float, float], b: tuple[float, float], x0: float, x1: float) -> None:
    """Glass strip along the (y, z) segment a -> b, 4-14 mm proud of the shell (outward normal +z side)."""
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, nz = (b[1] - a[1]) / ln, -(b[0] - a[0]) / ln
    if nz < 0:
        nx, nz = -nx, -nz
    p.profile_x([(a[0] + nx * 0.004, a[1] + nz * 0.004), (b[0] + nx * 0.004, b[1] + nz * 0.004),
                 (b[0] + nx * 0.014, b[1] + nz * 0.014), (a[0] + nx * 0.014, a[1] + nz * 0.014)], x0, x1, "glass_tinted")


def _heli(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    shell = body.part(bevel=0.03, segments=2)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    gear = body.part(bevel=0.0)
    cabin = body.part(bevel=0.01)
    # nose section (forward of the doorway, y 1.0 .. 2.9) and the rear section (y -1.9 .. -0.4)
    nose = [(1.0, FLOOR), (2.3, FLOOR), (2.75, 0.85), (2.92, 1.15), (2.72, 1.55), (2.0, 2.0), (1.0, ROOF)]
    shell.profile_x(nose, -W, W, "car_navy")
    rear = [(-0.4, FLOOR), (-0.4, ROOF), (-1.0, 2.0), (-1.9, 1.86), (-1.9, 1.28), (-1.5, 0.92), (-1.15, FLOOR)]
    shell.profile_x(rear, -W, W, "car_navy")
    # doorway (doors slid back): cabin floor and roof between the sections
    shell.bx((-W, -0.4, FLOOR), (W, 1.0, 0.73), "car_navy")
    shell.bx((-W, -0.4, 1.97), (W, 1.0, ROOF), "car_navy")
    # engine / gearbox fairing and exhaust
    shell.profile_x([(-1.75, 1.95), (0.95, 2.0), (0.75, 2.33), (-0.35, 2.45), (-1.5, 2.3)], -0.52, 0.52, "metal_white")
    trim.cyl(0.09, 0.22, (0.0, -1.8, 2.12), "metal_dark", axis="Y", segs=12)
    # windscreen, chin bubble and the cockpit side windows
    _glass_on(glass, (2.72, 1.55), (2.0, 2.0), -W + 0.08, W - 0.08)
    _glass_on(glass, (2.92, 1.15), (2.72, 1.55), -W + 0.14, W - 0.14)
    for sx in (-1, 1):
        g0, g1 = sorted((sx * (W + 0.004), sx * (W + 0.012)))
        glass.profile_x([(1.12, 1.22), (2.05, 1.22), (2.45, 1.55), (1.95, 1.9), (1.12, 1.93)], g0, g1, "glass_tinted")
        # side door slid back over the rear section, with its window and rail
        d0, d1 = sorted((sx * (W + 0.006), sx * (W + 0.05)))
        trim.bx((d0, -1.55, 0.76), (d1, -0.36, 1.92), "car_navy")
        w0, w1 = sorted((sx * (W + 0.05), sx * (W + 0.056)))
        glass.bx((w0, -1.4, 1.3), (w1, -0.52, 1.8), "glass_tinted")
        r0, r1 = sorted((sx * (W + 0.004), sx * (W + 0.03)))
        trim.bx((r0, -1.6, 1.94), (r1, 1.0, 1.97), "metal_dark")
        # livery stripe along the nose and the rear section (clear of the door and windows)
        s0, s1 = sorted((sx * (W + 0.004), sx * (W + 0.008)))
        trim.bx((s0, 1.05, 0.95), (s1, 2.3, 1.05), "metal_white")
        trim.bx((s0, -1.85, 0.95), (s1, -1.6, 1.05), "metal_white")
        # skid gear: skid tube with an upturned toe, two arched cross tubes
        x = sx * 1.1
        gear.tube([(x, -1.55, 0.05), (x, 1.65, 0.05), (x, 1.98, 0.2)], 0.05, "metal_dark", segs=10)
    for y in (-0.95, 1.25):
        gear.tube([(-1.1, y, 0.05), (-1.02, y, 0.42), (-0.72, y, FLOOR + 0.02), (0.72, y, FLOOR + 0.02),
                   (1.02, y, 0.42), (1.1, y, 0.05)], 0.04, "metal_dark", segs=8)
    # cabin interior: rear bench facing forward, pilot seat backs, floor mat
    cabin.bx((-W + 0.06, -0.39, 0.73), (W - 0.06, 0.05, 1.08), "fabric_charcoal")
    cabin.bx((-W + 0.06, -0.39, 1.08), (W - 0.06, -0.27, 1.8), "fabric_charcoal")
    for sx in (-1, 1):
        c0, c1 = sorted((sx * 0.08, sx * (W - 0.08)))
        cabin.bx((c0, 0.84, 0.73), (c1, 0.99, 1.75), "fabric_charcoal")
    cabin.bx((-W + 0.04, 0.06, 0.73), (W - 0.04, 0.83, 0.736), "rubber")
    cabin.bx((-W + 0.02, -0.4, 1.965), (W - 0.02, 1.0, 1.97), "plastic_grey")
    # tail boom, fins, stabiliser with end plates, tail skid
    shell.profile_x([(-1.85, 1.3), (-6.3, 1.62), (-6.3, 1.84), (-1.85, 1.84)], -0.18, 0.18, "car_navy")
    trim.profile_x([(-5.9, 1.62), (-6.45, 1.62), (-6.78, 2.75), (-6.38, 2.75)], -0.035, 0.035, "car_navy")
    trim.profile_x([(-6.0, 1.62), (-6.4, 1.62), (-6.5, 1.16), (-6.32, 1.16)], -0.03, 0.03, "car_navy")
    trim.bx((-0.95, -5.35, 1.66), (0.95, -4.95, 1.71), "car_navy")
    for sx in (-1, 1):
        e0, e1 = sorted((sx * 0.95, sx * 0.99))
        trim.bx((e0, -5.38, 1.5), (e1, -4.92, 1.9), "metal_white")
    gear.rod((0.0, -6.35, 1.2), (0.0, -6.55, 0.95), 0.025, "metal_dark", segs=6)
    # mast, nav lights (red port, green starboard), beacons
    gear.cyl(0.07, 0.3, (0.0, 0.3, 2.5), "metal_grey", segs=12)
    trim.sphere(0.04, (-0.99, -5.15, 1.92), "emit_led_red", segs=8, rings=4)
    trim.sphere(0.04, (0.99, -5.15, 1.92), "emit_led_green", segs=8, rings=4)
    trim.sphere(0.05, (0.0, -6.6, 2.78), "emit_led_red", segs=8, rings=4)
    trim.bx((-0.12, 1.6, 0.6), (0.12, 1.84, 0.65), "emit_cool")
    body.build()
    # main rotor: pivot on the mast axis, blades parked fore-aft
    rotor = k.empty("Rotor", (0.0, 0.3, 2.65))
    rm = k.obj("RotorBlades", parent=rotor)
    hub = rm.part(bevel=0.01)
    hub.cyl(0.18, 0.12, (0.0, 0.0, 0.0), "metal_grey", segs=16)
    hub.cyl(0.05, 0.12, (0.0, 0.0, 0.11), "metal_dark", segs=10)
    bl = rm.part(bevel=0.004)
    for sy in (-1, 1):
        y0, y1 = sorted((sy * 0.12, sy * 0.45))
        bl.bx((-0.07, y0, -0.03), (0.07, y1, 0.04), "metal_dark")
        y0, y1 = sorted((sy * 0.42, sy * 4.5))
        bl.bx((-0.15, y0, -0.015), (0.15, y1, 0.015), "metal_grey")
        t0, t1 = sorted((sy * 4.3, sy * 4.5))
        bl.bx((-0.152, t0, -0.017), (0.152, t1, 0.017), "metal_yellow")
    rm.build()
    # tail rotor: pivot on its axis (Blender X), two blades
    tail = k.empty("TailRotor", (0.11, -6.45, 2.25))
    tm = k.obj("TailRotorBlades", parent=tail)
    th = tm.part(bevel=0.004)
    th.cyl(0.06, 0.08, (0.0, 0.0, 0.0), "metal_grey", axis="X", segs=10)
    th.bx((0.0, -0.05, -0.62), (0.03, 0.05, 0.62), "metal_grey")
    th.bx((-0.002, -0.052, 0.5), (0.032, 0.052, 0.62), "metal_yellow")
    th.bx((-0.002, -0.052, -0.62), (0.032, 0.052, -0.5), "metal_yellow")
    tm.build()


# ------------------------------------------------------------------------------ zipline rig

def _zipline_rig(k: Kit, p: dict) -> None:
    """Stand 1.4 x 0.4 m, 1.78 m tall, backed 0.05 m off the parapet at Godot z +1.2 (Blender y -1.2)."""
    yc, hw, hd, top = -0.95, 0.7, 0.2, 1.72
    o = k.obj("Rig")
    fr = o.part(bevel=0.003)
    for sx in (-1, 1):
        x = sx * hw
        fr.bx((x - 0.03, yc - hd, 0.0), (x + 0.03, yc + hd, 0.04), "metal_dark")
        fr.rod((x, yc - hd + 0.03, 0.04), (x, yc, top), 0.022, "metal_grey", segs=8)
        fr.rod((x, yc + hd - 0.03, 0.04), (x, yc, top), 0.022, "metal_grey", segs=8)
    fr.rod((-hw - 0.03, yc, top), (hw + 0.03, yc, top), 0.026, "metal_grey", segs=10)
    shelf = o.part(bevel=0.003)
    shelf.bx((-hw + 0.04, yc - 0.12, 0.42), (hw - 0.04, yc + 0.12, 0.445), "metal_dark")
    for sx in (-1, 1):
        shelf.rod((sx * hw, yc - hd + 0.06, 0.43), (sx * hw, yc + hd - 0.06, 0.43), 0.015, "metal_dark", segs=6)
    gear = o.part(bevel=0.002)
    straps = o.part(bevel=0.0)
    for x in (-0.48, -0.16, 0.16, 0.48):
        # hook, harness (two shoulder straps, waist belt, leg loops) hanging from the bar
        gear.torus(0.035, 0.008, (x, yc, top - 0.05), "steel", segs=12, rsegs=4, axis="Y")
        straps.tube([(x, yc, top - 0.085), (x - 0.09, yc - 0.03, 1.38), (x - 0.11, yc - 0.03, 1.1)], 0.012, "plastic_black", segs=6)
        straps.tube([(x, yc, top - 0.085), (x + 0.09, yc - 0.03, 1.38), (x + 0.11, yc - 0.03, 1.1)], 0.012, "plastic_black", segs=6)
        straps.torus(0.13, 0.014, (x, yc - 0.03, 1.08), "metal_orange", segs=16, rsegs=4, axis="Z")
        for sx in (-1, 1):
            straps.torus(0.075, 0.012, (x + sx * 0.06, yc - 0.03, 0.88), "plastic_black", segs=12, rsegs=4, axis="Z")
            straps.rod((x + sx * 0.06, yc - 0.03 - 0.06, 1.06), (x + sx * 0.06, yc - 0.03 - 0.06, 0.9), 0.01, "plastic_black", segs=6)
        gear.torus(0.03, 0.007, (x, yc - 0.16, 1.08), "steel", segs=10, rsegs=4, axis="X")
        # line trolley on the shelf: two side plates, twin sheaves, a carabiner
        tx = x
        for sy in (-0.035, 0.035):
            gear.bx((tx - 0.07, yc + sy - 0.006, 0.445), (tx + 0.07, yc + sy + 0.006, 0.56), "metal_yellow")
        for wx in (-0.04, 0.04):
            gear.cyl(0.03, 0.058, (tx + wx, yc, 0.5), "metal_dark", axis="Y", segs=10)
        gear.torus(0.03, 0.006, (tx, yc, 0.6), "steel", segs=10, rsegs=4, axis="Y")
    # rope bag on the ground beside the stand
    o.build()
    bag = k.obj("RopeBag")
    b = bag.part(bevel=0.01, segments=2)
    b.cyl(0.17, 0.36, (hw + 0.32, yc + 0.02, 0.18), "canvas_teal", segs=16)
    b.cyl(0.12, 0.03, (hw + 0.32, yc + 0.02, 0.375), "rubber", segs=14)
    bag.build()


# ------------------------------------------------------------------------------ lift fit-out

def _lift_fitout(k: Kit, p: dict) -> None:
    """Car interior: x / Blender y -1.35 .. 1.35 (walls), opening on +X between Blender y -0.85 and
    0.35 (Godot z -0.35 .. 0.85). Everything stays 4 mm off the walls."""
    e = 1.346
    o = k.obj("Fitout")
    fl = o.part(bevel=0.0)
    fl.bx((-e, -e, 0.0), (e, e, 0.008), "metal_grey")
    tread = o.part(bevel=0.0)
    n = 14
    for i in range(n):
        for j in range(n):
            cx = -e + (i + 0.5) * (2 * e / n)
            cy = -e + (j + 0.5) * (2 * e / n)
            ang = 0.25 if (i + j) % 2 == 0 else -0.25
            dx, dy = 0.05 * math.cos(ang * math.pi), 0.05 * math.sin(ang * math.pi)
            tread.rod((cx - dx, cy - dy, 0.0095), (cx + dx, cy + dy, 0.0095), 0.0035, "metal_grey", segs=4, square=True)
    # padded freight blankets on the two side walls, hung from a rail
    pads = o.part(bevel=0.006, segments=1)
    trim = o.part(bevel=0.002)
    for sy in (-1, 1):
        y0, y1 = sorted((sy * e, sy * (e - 0.025)))
        pads.bx((-e + 0.06, y0, 0.12), (e - 0.12, y1, 2.18), "canvas_teal")
        q0, q1 = sorted((sy * (e - 0.025), sy * (e - 0.029)))
        for z in (0.55, 1.0, 1.45, 1.9):
            trim.bx((-e + 0.08, q0, z), (e - 0.14, q1, z + 0.02), "fabric_charcoal")
        for x in (-0.7, 0.0, 0.7):
            trim.bx((x, q0, 0.14), (x + 0.02, q1, 2.16), "fabric_charcoal")
        r0, r1 = sorted((sy * e, sy * (e - 0.05)))
        trim.bx((-e + 0.04, r0, 2.18), (e - 0.1, r1, 2.22), "steel")
    # handrail on the back wall (-X)
    rail = o.part(bevel=0.0)
    rx = -e + 0.07
    rail.rod((rx, -1.0, 0.92), (rx, 1.0, 0.92), 0.019, "steel", segs=12)
    for y in (-0.9, 0.9):
        rail.rod((-e, y, 0.92), (rx, y, 0.92), 0.012, "steel", segs=8)
        rail.cyl(0.035, 0.012, (-e + 0.006, y, 0.92), "steel", axis="X", segs=12)
    # car operating panel on the +X wall beside the opening (Blender y 0.45 .. 0.85), lit
    cop = o.part(bevel=0.003)
    cx0 = e - 0.025
    cop.bx((cx0, 0.5, 0.85), (e, 0.8, 1.65), "steel")
    btn = o.part(bevel=0.0)
    for i in range(5):
        z = 0.95 + i * 0.1
        btn.cyl(0.018, 0.006, (cx0 - 0.003, 0.65, z), "emit_led_green" if i == 0 else "emit_neutral", axis="X", segs=10)
    btn.bx((cx0 - 0.004, 0.55, 1.47), (cx0, 0.75, 1.58), "emit_amber")
    btn.cyl(0.026, 0.006, (cx0 - 0.003, 0.65, 1.4), "emit_led_red", axis="X", segs=12)
    # ceiling light panel under the car roof (2.6 m), the fixture of the car light
    lamp = o.part(bevel=0.002)
    lamp.bx((-0.42, -0.42, 2.565), (0.42, 0.42, 2.596), "steel")
    lamp.bx((-0.38, -0.38, 2.559), (0.38, 0.38, 2.565), "emit_cool")
    o.build()


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
