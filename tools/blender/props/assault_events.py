"""PO6-17 RNG assault-event visuals (D-114 §5): turret van, sentry turret, police helicopter, breach points.

Contract (node names, axes, map markers): docs/levels/_art/po6_17/README.md. Visual scenes only; ENV A's
event code instances them and owns the behaviour. Blender +Y = Godot -Z. Palette: style guide §3 police
navy `#1E2A44` + hi-vis `#D7E34A` trim, TAC charcoal `#2B2F33` armour.

* ``prop_turret_van``: armoured police van. Nose at Godot **+Z** (it parks on a `TurretVan_<n>` marker,
  whose +Z is the van's forward), rear doors at -Z. Nodes `Body`, `DoorL` / `DoorR` (hinge pivots,
  closed = identity; L = Godot +X, the driver's left), `TurretMount` (roof ring top), `ExitPoint`
  (behind the rear doors, -Z = away from the van). No collision (the event prefab owns it).
* ``prop_sentry_turret``: tripod auto-turret. `Base`, `Yaw` (pivot, turns about Godot Y), `Yaw/Pitch`
  (pivot, tilts about Godot X), `Muzzle` under Pitch (-Z = fire direction). Pivot = floor, centre.
* ``prop_police_helicopter``: light police helicopter, nose -Z, cabin doors slid open both sides.
  `Body`, `Rotor` (main rotor pivot on the mast, spins about Godot Y), `TailRotor` (spins about
  Godot X), `RopeL` / `RopeR` (rope anchors on davits over the doors, L = Godot -X), `SniperSeat` (+ child `SniperKneel`, ENV D's kneel root)
  (bench end at the open left door, -Z facing out), `Spotlight` (nose gimbal lens, -Z = beam).
  Pivot = skid bottom under the cabin centre. No collision.
* ``prop_breach_wall`` / ``prop_breach_window`` / ``prop_breach_ceiling``: breach points sized to the
  Glasshouse openings. Each has `Intact` (the infill that closes the map's opening, with its own
  `Intact/Collision`) and `Blown` (hidden in the wrapper: scorched ragged frame, rubble; no collision),
  plus `Charge`, `EntryPoint` (cops' side) and `ExitPoint` (inside). Origin = the opening on the
  **room-side face** (wall/window: bottom-centre; ceiling: centre of the ceiling underside); Godot
  -Z points into the room (the ceiling scene is authored rotated so -Z points down).
"""

import math

import bpy
from mathutils import Matrix

from _pb import Kit
from lib import geo

TRI_BUDGET = 8000
VARIANTS = {
    "prop_turret_van": {"fn": "turret_van", "cat": {"prefab": "assault_event", "kind": "turret_van", "surface": "metal"}},
    "prop_sentry_turret": {"fn": "sentry_turret", "cat": {"prefab": "assault_event", "kind": "sentry_turret", "surface": "metal"}},
    "prop_police_helicopter": {"fn": "police_heli", "cat": {"prefab": "assault_event", "kind": "police_helicopter", "surface": "metal"}},
    # interior partition 0.2 m (GH U7 -> U6, G4 -> G5): infilled old doorway, 1.0 x 2.2 m (single-door opening)
    "prop_breach_wall": {"fn": "breach_wall", "w": 1.0, "h": 2.2, "t": 0.2, "room": "plaster", "out": "drywall",
                         "cat": {"prefab": "assault_event", "kind": "breach_wall", "surface": "plaster", "hidden": ["Blown"]}},
    # exterior wall 0.4 m (GH U6 south facade): 1.0 x 1.2 window over a 0.9 m sill, blown to the floor (2.1 m)
    "prop_breach_window": {"fn": "breach_window", "w": 1.0, "h": 2.1, "sill": 0.9, "t": 0.4, "room": "plaster",
                           "out": "brick", "parapet": 4.6,
                           "cat": {"prefab": "assault_event", "kind": "breach_window", "surface": "brick", "hidden": ["Blown"]}},
    # roof slab 7.6-7.8 over a 7.2 ceiling (GH upper floor): sealed skylight, 1.2 x 1.2 m; floor 3.0 m below
    "prop_breach_ceiling": {"fn": "breach_ceiling", "w": 1.2, "plenum": 0.6, "drop": 3.0,
                            "cat": {"prefab": "assault_event", "kind": "breach_ceiling", "surface": "concrete", "hidden": ["Blown"]}},
}


# ------------------------------------------------------------------------------------ helpers

def _glass_on(p, a: tuple[float, float], b: tuple[float, float], x0: float, x1: float, key: str = "glass_tinted") -> None:
    """Glass strip along the (y, z) segment a -> b, 4-14 mm proud of the shell (outward = +z side)."""
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, nz = (b[1] - a[1]) / ln, -(b[0] - a[0]) / ln
    if nz < 0:
        nx, nz = -nx, -nz
    p.profile_x([(a[0] + nx * 0.004, a[1] + nz * 0.004), (b[0] + nx * 0.004, b[1] + nz * 0.004),
                 (b[0] + nx * 0.014, b[1] + nz * 0.014), (a[0] + nx * 0.014, a[1] + nz * 0.014)], x0, x1, key)


def _chunk(p, rng, centre: tuple[float, float, float], size: float, key: str) -> None:
    """Broken masonry lump: a square bar of random direction (length 1-2x its width)."""
    a = rng.uniform(0.0, math.tau)
    b = rng.uniform(-0.6, 0.6)
    ln = size * rng.uniform(0.6, 1.1)
    d = (math.cos(a) * math.cos(b) * ln, math.sin(a) * math.cos(b) * ln, math.sin(b) * ln)
    c = centre
    p.rod((c[0] - d[0], c[1] - d[1], c[2] - d[2]), (c[0] + d[0], c[1] + d[1], c[2] + d[2]), size * 0.5, key, square=True)


def _rubble(p, rng, n: int, x: tuple[float, float], y: tuple[float, float], z: float, sizes: tuple[float, float],
            keys: list[str]) -> None:
    """n chunks resting on the floor at height z inside the x/y box; bigger ones near the start of y."""
    for _ in range(n):
        s = rng.uniform(*sizes)
        t = rng.random() ** 1.6
        cx = rng.uniform(*x) * (0.55 + 0.45 * t)
        cy = y[0] + (y[1] - y[0]) * t
        _chunk(p, rng, (cx, cy, z + s * 0.32), s * (1.0 - 0.45 * t), keys[rng.randrange(len(keys))])


def _wobble(rng, n: int, amp: float) -> list[float]:
    """n smooth radial factors (1 +- amp): three low-frequency sines with random phases plus fine chips."""
    ph = [rng.uniform(0.0, math.tau) for _ in range(3)]
    out = []
    for i in range(n):
        t = math.tau * i / n
        v = 0.5 * math.sin(2 * t + ph[0]) + 0.3 * math.sin(3 * t + ph[1]) + 0.2 * math.sin(5 * t + ph[2])
        out.append(1.0 + amp * v + rng.uniform(-0.04, 0.04))
    return out


def _jagged_u(rng, w: float, h: float, margin: float, noise: float) -> list[tuple[float, float]]:
    """Scorch outline (x, z) round a floor-level opening w x h: up the right jamb, an arch over the head,
    down the left jamb, then back along the opening edges (a simple U). The band is `margin` wide,
    wobbling by +-`noise` x margin, so it never enters the opening."""
    hw = w / 2
    path: list[tuple[float, float, float, float]] = []      # (x, z, outward nx, nz) on the opening outline
    for k in range(6):
        z = h * k / 6
        path.append((hw, z, 1.0, 0.0))
    for k in range(9):
        a = math.pi * k / 8
        path.append((hw * math.cos(a), h, math.cos(a), 0.6 + 0.4 * math.sin(a)))
    for k in range(5, -1, -1):
        path.append((-hw, h * k / 6, -1.0, 0.0))
    wob = _wobble(rng, len(path), noise)
    outer = []
    for (x, z, nx, nz), f in zip(path, wob):
        ln = math.hypot(nx, nz)
        d = margin * f * (0.55 if z < 0.3 * h and nz == 0.0 else 1.0)
        outer.append((x + nx / ln * d, z + nz / ln * d))
    outer[0] = (outer[0][0], 0.0)
    outer[-1] = (outer[-1][0], 0.0)
    return outer + [(-hw, 0.0), (-hw, h), (hw, h), (hw, 0.0)]


def _jagged_ring(rng, half: float, margin: float, noise: float, n: int = 24) -> list[tuple[float, float]]:
    """Jagged outline (x, y) around a square hole of half-size `half` (star-shaped about the centre)."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        c, s = math.cos(a), math.sin(a)
        r = (half + margin) / max(abs(c), abs(s)) * (0.82 + 0.18 * abs(math.cos(2 * a)))
        r = max(r, (half + 0.06) / max(abs(c), abs(s)))
        r *= 1.0 + rng.uniform(0.0, noise)
        pts.append((c * r, s * r))
    return pts


def _scorch(obj, rng, w: float, h: float, face_y: float, out: float, size: float = 1.0) -> None:
    """Blast scorching on a wall face at `face_y` (`out` = +1 / -1: the face's outward Blender Y): a wide
    sooty haze 4-5 mm and a dark core 9-10 mm proud of the face (layers > 3.5 mm apart: no dezfight push,
    no levelcheck zfight). `obj` is the scorch-only mesh object."""
    p = obj.part(bevel=0.0)
    for key, margin, noise, d0 in (("soot_haze", 0.5 * size, 0.35, 0.004), ("soot", 0.24 * size, 0.45, 0.009)):
        y0, y1 = sorted((face_y + out * d0, face_y + out * (d0 + 0.001)))
        p.prism(_jagged_u(rng, w, h, margin, noise), axis="Y", start=y0, end=y1, mat=p.m(key))


def _ragged_reveal(p, rng, w: float, h: float, y0: float, y1: float, keys: list[str], bottom: bool = False) -> None:
    """Broken lumps sticking out of the reveal (jambs and head) of a w x h opening between wall faces y0..y1."""
    hw = w / 2
    depth = y1 - y0
    for sx in (-1, 1):
        z = 0.15
        while z < h - 0.1:
            s = rng.uniform(0.06, 0.12)
            _chunk(p, rng, (sx * (hw + 0.005 - s * 0.2), rng.uniform(y0 + 0.03, y1 - 0.03), z), min(s, depth * 0.6),
                   keys[rng.randrange(len(keys))])
            z += rng.uniform(0.18, 0.34)
    x = -hw + 0.12
    while x < hw - 0.1:
        s = rng.uniform(0.06, 0.12)
        _chunk(p, rng, (x, rng.uniform(y0 + 0.03, y1 - 0.03), h + 0.005 - s * 0.2), min(s, depth * 0.6),
               keys[rng.randrange(len(keys))])
        x += rng.uniform(0.18, 0.3)
    if bottom:
        x = -hw + 0.1
        while x < hw - 0.1:
            s = rng.uniform(0.05, 0.1)
            _chunk(p, rng, (x, rng.uniform(y0 + 0.03, y1 - 0.03), s * 0.3), min(s, depth * 0.6),
                   keys[rng.randrange(len(keys))])
            x += rng.uniform(0.2, 0.32)


def _ring(p, outer: list[tuple[float, float]], half: float, z0: float, z1: float, key: str) -> None:
    """Decal ring (x, y) from a square hole of half-size `half` out to the star-shaped `outer`, as thin
    quad slabs (one per outline segment; closed n-gon caps, no hole tessellation)."""
    def inner(pt: tuple[float, float]) -> tuple[float, float]:
        m = max(abs(pt[0]), abs(pt[1]))
        return (pt[0] / m * half, pt[1] / m * half)
    n = len(outer)
    for i in range(n):
        a, b = outer[i], outer[(i + 1) % n]
        p.slab([inner(a), a, b, inner(b)], z0, z1, key)


def _collision(boxes, name: str, parent) -> None:
    mb = geo.MeshBuilder()
    for lo, hi in boxes:
        mb.box(lo, hi)
    geo.collision_from_builder(mb, "convex", name=name, parent=parent)


# -------------------------------------------------------------------------------- turret van

def _turret_van(k: Kit, p: dict) -> None:
    """Armoured police van, nose to Blender -Y (Godot +Z), rear doors at Blender +Y (Godot -Z)."""
    w, h, clear = 2.2, 2.6, 0.4
    yf, yr = -2.9, 2.9
    body = k.obj("Body")
    shell = body.part(bevel=0.04, segments=1)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    run = body.part(bevel=0.0)
    bars = body.part(bevel=0.0)
    prof = [(yf + 0.05, clear + 0.1), (yf, 0.72), (yf + 0.04, 1.15), (yf + 0.55, 1.3), (yf + 1.1, h - 0.22),
            (yf + 1.25, h - 0.04), (yr - 0.03, h - 0.04), (yr, h - 0.12), (yr, clear + 0.12), (yr - 0.2, clear + 0.08)]
    shell.profile_x(prof, -w / 2, w / 2, "police_navy")
    # armoured windscreen behind a three-bar guard, slit cab side windows
    a, b = (yf + 0.58, 1.33), (yf + 1.08, h - 0.26)
    _glass_on(glass, a, b, -w / 2 + 0.16, w / 2 - 0.16)
    for t in (0.3, 0.55, 0.8):
        yy, zz = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        bars.rod((-w / 2 + 0.12, yy - 0.03, zz + 0.03), (w / 2 - 0.12, yy - 0.03, zz + 0.03), 0.018, "metal_dark", segs=8)
    for sx in (-1, 1):
        g0, g1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.012)))
        glass.bx((g0, yf + 0.95, 1.62), (g1, yf + 1.5, 1.98), "glass_tinted")
        # lower armour skirt, hi-vis band, gun ports, grab rail
        a0, a1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.03)))
        trim.bx((a0, yf + 0.45, clear + 0.06), (a1, yr - 0.2, 1.02), "armor_charcoal")
        s0, s1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.008)))
        trim.bx((s0, yf + 0.3, 1.14), (s1, yr - 0.12, 1.3), "hivis")
        for py in (-0.2, 0.9, 2.0):
            trim.bx((s0, py, 1.62), (s1, py + 0.32, 1.7), "plastic_black")
        r0, r1 = sorted((sx * (w / 2 + 0.03), sx * (w / 2 + 0.05)))
        trim.bx((r0, -0.6, 2.1), (r1, 2.3, 2.13), "metal_dark")
        m0, m1 = sorted((sx * (w / 2 + 0.03), sx * (w / 2 + 0.22)))
        trim.bx((m0, yf + 0.9, 1.55), (m1, yf + 0.96, 1.8), "plastic_black")                    # mirror
        for wy in (yf + 1.0, yr - 1.1):
            arch = [(sx * (w / 2 + 0.032), wy - 0.5 * math.cos(math.pi * i / 10), 0.42 + 0.5 * math.sin(math.pi * i / 10))
                    for i in range(11)]
            bars.tube(arch, 0.035, "armor_charcoal", segs=6)
            run.cyl(0.42, 0.3, (sx * (w / 2 - 0.17), wy, 0.42), "rubber", axis="X", segs=20)
            run.cyl(0.25, 0.305, (sx * (w / 2 - 0.17), wy, 0.42), "metal_dark", axis="X", segs=16)
            run.cyl(0.08, 0.31, (sx * (w / 2 - 0.17), wy, 0.42), "steel", axis="X", segs=12)
        l0, l1 = sorted((sx * (w / 2 + 0.004), sx * (w / 2 + 0.014)))
        trim.bx((l0, yr - 0.14, 1.05), (l1, yr - 0.02, 1.6), "metal_red")                        # tail lights
    # front: grille, headlamps, push bar
    trim.bx((-0.65, yf - 0.012, 0.66), (0.65, yf + 0.03, 0.95), "plastic_black")
    for sx in (-1, 1):
        trim.bx((sx * 0.85 - 0.17, yf + 0.0, 0.9), (sx * 0.85 + 0.17, yf + 0.06, 1.04), "emit_cool")
    for z in (0.55, 0.95):
        bars.rod((-0.95, yf - 0.28, z), (0.95, yf - 0.28, z), 0.035, "metal_dark", segs=10)
    for sx in (-1, 1):
        bars.rod((sx * 0.7, yf - 0.28, 0.45), (sx * 0.7, yf - 0.28, 1.05), 0.035, "metal_dark", segs=10)
        bars.rod((sx * 0.7, yf - 0.28, 0.6), (sx * 0.7, yf + 0.02, 0.6), 0.03, "metal_dark", segs=8)
    trim.bx((-w / 2 + 0.02, yf - 0.1, clear), (w / 2 - 0.02, yf + 0.15, clear + 0.22), "plastic_black")
    trim.bx((-w / 2 + 0.02, yr - 0.15, clear), (w / 2 - 0.02, yr + 0.12, clear + 0.2), "plastic_black")
    trim.bx((-0.45, yr + 0.12, clear + 0.04), (0.45, yr + 0.3, clear + 0.08), "steel")              # rear step
    # light bar over the cab (blue left, red right) and the turret ring on the cargo roof
    trim.bx((-0.7, yf + 1.45, h - 0.04), (0.7, yf + 1.75, h + 0.02), "plastic_black")
    trim.bx((-0.66, yf + 1.47, h + 0.02), (-0.04, yf + 1.73, h + 0.12), "emit_police_blue")
    trim.bx((0.04, yf + 1.47, h + 0.02), (0.66, yf + 1.73, h + 0.12), "emit_led_red")
    ty = 1.0
    trim.cyl(0.6, 0.1, (0.0, ty, h + 0.01), "armor_charcoal", segs=20)
    trim.cyl(0.46, 0.012, (0.0, ty, h + 0.066), "metal_dark", segs=24)
    for i in range(8):
        a = math.tau * i / 8
        bars.cyl(0.025, 0.02, (math.cos(a) * 0.53, ty + math.sin(a) * 0.53, h + 0.07), "steel", segs=8)
    trim.bx((-0.7, yr - 0.6, h - 0.04), (0.7, yr - 0.5, h + 0.02), "metal_dark")                   # roof rail
    body.build()
    # rear doors: hinged at the outer edges, closed = flush with the rear (Blender +Y)
    dh = h - 0.18 - clear - 0.1
    for name, sx in (("DoorL", 1), ("DoorR", -1)):
        piv = k.empty(name, (sx * (w / 2 - 0.04), yr, clear + 0.1))
        dm = k.obj(name + "Mesh", parent=piv)
        dp = dm.part(bevel=0.02, segments=2)
        dt = dm.part(bevel=0.003)
        x0, x1 = sorted((0.0, -sx * (w / 2 - 0.045)))
        dp.bx((x0, -0.035, 0.0), (x1, 0.03, dh), "police_navy")
        dt.bx((x0 + 0.06, 0.03, 0.05), (x1 - 0.06, 0.045, 0.75), "armor_charcoal")
        g = dm.part(bevel=0.0)
        g.bx((x0 + 0.2, 0.03, dh - 0.5), (x1 - 0.2, 0.036, dh - 0.32), "glass_tinted")
        dt.bx((x0 + 0.16, 0.03, dh - 0.54), (x1 - 0.16, 0.034, dh - 0.28), "plastic_black")
        dt.bx((x0 + 0.02, 0.03, 0.9), (x1 - 0.02, 0.036, 1.02), "hivis")
        hx0, hx1 = (x1 - 0.14, x1 - 0.05) if sx > 0 else (x0 + 0.05, x0 + 0.14)
        dt.bx((hx0, 0.03, 0.85), (hx1, 0.065, 0.89), "plastic_black")
        hinge_x = 0.012 if sx > 0 else -0.012
        for hz in (0.3, dh - 0.3):
            dt.cyl(0.02, 0.14, (hinge_x, 0.03, hz), "steel", segs=10)
        dm.build()
    k.empty("TurretMount", (0.0, ty, h + 0.06))
    k.empty("ExitPoint", (0.0, yr + 1.3, 0.0))


# ------------------------------------------------------------------------------ sentry turret

def _sentry_turret(k: Kit, p: dict) -> None:
    """Tripod auto-turret; the gun points Blender +Y (Godot -Z)."""
    base = k.obj("Base")
    b = base.part(bevel=0.004)
    hub_z = 0.52
    for i in range(3):
        a = math.pi / 2 + math.tau * i / 3 + math.pi
        fx, fy = math.cos(a) * 0.55, math.sin(a) * 0.55
        b.rod((0.0, 0.0, hub_z), (fx, fy, 0.04), 0.022, "metal_dark", segs=8)
        b.cyl(0.05, 0.04, (fx, fy, 0.02), "rubber", segs=12)
        b.rod((0.0, 0.0, hub_z - 0.22), (fx * 0.55, fy * 0.55, 0.3), 0.012, "steel", segs=6)
    b.cyl(0.07, 0.12, (0.0, 0.0, hub_z), "police_navy", segs=16)
    b.cyl(0.045, 0.2, (0.0, 0.0, hub_z + 0.15), "steel", segs=14)
    b.bx((0.07, -0.08, hub_z - 0.12), (0.17, 0.08, hub_z + 0.04), "metal_dark")                    # battery
    b.bx((0.17, -0.03, hub_z - 0.06), (0.172, 0.03, hub_z - 0.02), "emit_led_green")
    base.build()
    yaw = k.empty("Yaw", (0.0, 0.0, 0.75))
    ym = k.obj("YawMesh", parent=yaw)
    y = ym.part(bevel=0.004)
    y.cyl(0.13, 0.06, (0.0, 0.0, 0.03), "police_navy", segs=24)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.15, sx * 0.19))
        y.bx((x0, -0.08, 0.04), (x1, 0.08, 0.3), "police_navy")
    ym.build()
    pitch = k.empty("Pitch", (0.0, 0.0, 0.24), parent=yaw)
    pm = k.obj("PitchMesh", parent=pitch)
    g = pm.part(bevel=0.006, segments=2)
    t = pm.part(bevel=0.002)
    g.bx((-0.11, -0.32, -0.1), (0.11, 0.24, 0.1), "police_navy")
    t.cyl(0.03, 0.08, (0.0, 0.0, 0.0), "steel", axis="X", segs=12)                                  # trunnion
    t.cyl(0.02, 0.4, (0.0, 0.0, 0.0), "steel", axis="X", segs=10)
    t.bx((-0.27, -0.16, -0.13), (-0.11, 0.1, 0.07), "metal_dark")                                   # ammo box
    t.bx((-0.27, -0.16, 0.07), (-0.11, 0.1, 0.09), "hivis")
    t.cyl(0.04, 0.5, (0.0, 0.49, 0.0), "metal_dark", axis="Y", segs=14)                             # shroud
    for i in range(6):
        t.cyl(0.042, 0.02, (0.0, 0.3 + i * 0.07, 0.0), "steel", axis="Y", segs=14)
    t.cyl(0.022, 0.12, (0.0, 0.8, 0.0), "steel", axis="Y", segs=10)
    t.cyl(0.03, 0.06, (0.0, 0.86, 0.0), "metal_dark", axis="Y", segs=10)                            # flash hider
    # armour shield (barrel gap), sensor head with its red eye
    for x0, x1, z0, z1 in ((-0.3, -0.06, -0.16, 0.26), (0.06, 0.3, -0.16, 0.26), (-0.06, 0.06, 0.06, 0.26),
                           (-0.06, 0.06, -0.16, -0.06)):
        t.bx((x0, 0.24, z0), (x1, 0.27, z1), "armor_charcoal")
    t.bx((-0.3, 0.235, 0.24), (0.3, 0.275, 0.26), "hivis")
    t.bx((-0.07, -0.08, 0.1), (0.07, 0.12, 0.2), "metal_dark")
    t.cyl(0.03, 0.012, (0.0, 0.126, 0.15), "emit_led_red", axis="Y", segs=12)
    pm.build()
    k.empty("Muzzle", (0.0, 0.89, 0.0), parent=pitch)


# ------------------------------------------------------------------------- police helicopter

W = 0.78
FLOOR = 0.65
ROOF = 2.15  # PO6-17 r: +0.1 m so ENV D's heli_door kneel clears the headliner


def _police_heli(k: Kit, p: dict) -> None:
    body = k.obj("Body")
    shell = body.part(bevel=0.03, segments=2)
    trim = body.part(bevel=0.004)
    glass = body.part(bevel=0.0)
    gear = body.part(bevel=0.0)
    cabin = body.part(bevel=0.01)
    nose = [(1.0, FLOOR), (2.3, FLOOR), (2.75, 0.85), (2.92, 1.15), (2.72, 1.55), (2.0, 2.1), (1.0, ROOF)]
    shell.profile_x(nose, -W, W, "police_navy")
    rear = [(-0.4, FLOOR), (-0.4, ROOF), (-1.0, 2.1), (-1.9, 1.86), (-1.9, 1.28), (-1.5, 0.92), (-1.15, FLOOR)]
    shell.profile_x(rear, -W, W, "police_navy")
    shell.bx((-W, -0.4, FLOOR), (W, 1.0, 0.73), "police_navy")
    shell.bx((-W, -0.4, 2.07), (W, 1.0, ROOF), "police_navy")
    shell.profile_x([(-1.75, 2.05), (0.95, 2.1), (0.75, 2.43), (-0.35, 2.55), (-1.5, 2.4)], -0.52, 0.52, "metal_white")
    trim.cyl(0.09, 0.22, (0.0, -1.8, 2.22), "metal_dark", axis="Y", segs=12)
    _glass_on(glass, (2.72, 1.55), (2.0, 2.1), -W + 0.08, W - 0.08)
    _glass_on(glass, (2.92, 1.15), (2.72, 1.55), -W + 0.14, W - 0.14)
    for sx in (-1, 1):
        g0, g1 = sorted((sx * (W + 0.004), sx * (W + 0.012)))
        glass.profile_x([(1.12, 1.22), (2.05, 1.22), (2.45, 1.55), (1.95, 1.9), (1.12, 1.93)], g0, g1, "glass_tinted")
        d0, d1 = sorted((sx * (W + 0.006), sx * (W + 0.05)))
        trim.bx((d0, -1.55, 0.76), (d1, -0.36, 1.92), "police_navy")                              # door slid back
        w0, w1 = sorted((sx * (W + 0.05), sx * (W + 0.056)))
        glass.bx((w0, -1.4, 1.3), (w1, -0.52, 1.8), "glass_tinted")
        r0, r1 = sorted((sx * (W + 0.004), sx * (W + 0.03)))
        trim.bx((r0, -1.6, 2.04), (r1, 1.0, 2.07), "metal_dark")
        s0, s1 = sorted((sx * (W + 0.004), sx * (W + 0.008)))
        trim.bx((s0, 1.05, 0.88), (s1, 2.3, 1.08), "hivis")                                       # hi-vis band
        trim.bx((s0, -1.85, 0.88), (s1, -1.6, 1.08), "hivis")
        trim.bx((s0, 1.05, 0.84), (s1, 2.3, 0.88), "metal_white")
        x = sx * 1.1
        gear.tube([(x, -1.55, 0.05), (x, 1.65, 0.05), (x, 1.98, 0.2)], 0.05, "metal_dark", segs=10)
        # rope davit over the doorway: arm from the roof rail out to a pulley
        trim.rod((sx * W, 0.3, 2.09), (sx * (W + 0.32), 0.3, 2.12), 0.025, "metal_dark", segs=8)
        trim.rod((sx * W, 0.0, 2.09), (sx * (W + 0.3), 0.28, 2.11), 0.016, "metal_dark", segs=6)
        trim.torus(0.04, 0.012, (sx * (W + 0.32), 0.3, 2.07), "metal_yellow", segs=12, rsegs=4, axis="Y")
    for y in (-0.95, 1.25):
        gear.tube([(-1.1, y, 0.05), (-1.02, y, 0.42), (-0.72, y, FLOOR + 0.02), (0.72, y, FLOOR + 0.02),
                   (1.02, y, 0.42), (1.1, y, 0.05)], 0.04, "metal_dark", segs=8)
    cabin.bx((-W + 0.06, -0.39, 0.73), (W - 0.06, 0.05, 1.08), "fabric_charcoal")
    cabin.bx((-W + 0.06, -0.39, 1.08), (W - 0.06, -0.27, 1.8), "fabric_charcoal")
    for sx in (-1, 1):
        c0, c1 = sorted((sx * 0.08, sx * (W - 0.08)))
        cabin.bx((c0, 0.84, 0.73), (c1, 0.99, 1.75), "fabric_charcoal")
    cabin.bx((-W + 0.04, 0.06, 0.73), (W - 0.04, 0.83, 0.736), "rubber")
    cabin.bx((-W + 0.02, -0.4, 2.065), (W - 0.02, 1.0, 2.07), "plastic_grey")
    # tail boom, fins, stabiliser, tail skid
    shell.profile_x([(-1.85, 1.3), (-6.3, 1.62), (-6.3, 1.84), (-1.85, 1.84)], -0.18, 0.18, "police_navy")
    trim.profile_x([(-5.9, 1.62), (-6.45, 1.62), (-6.78, 2.75), (-6.38, 2.75)], -0.035, 0.035, "police_navy")
    trim.profile_x([(-6.0, 1.62), (-6.4, 1.62), (-6.5, 1.16), (-6.32, 1.16)], -0.03, 0.03, "police_navy")
    trim.bx((-0.95, -5.35, 1.66), (0.95, -4.95, 1.71), "police_navy")
    for sx in (-1, 1):
        e0, e1 = sorted((sx * 0.95, sx * 0.99))
        trim.bx((e0, -5.38, 1.5), (e1, -4.92, 1.9), "hivis")
        b0, b1 = sorted((sx * 0.18, sx * 0.184))
        trim.bx((b0, -4.6, 1.6), (b1, -2.2, 1.7), "hivis")
    gear.rod((0.0, -6.35, 1.2), (0.0, -6.55, 0.95), 0.025, "metal_dark", segs=6)
    gear.cyl(0.07, 0.3, (0.0, 0.3, 2.6), "metal_grey", segs=12)
    trim.sphere(0.04, (-0.99, -5.15, 1.92), "emit_led_red", segs=8, rings=4)
    trim.sphere(0.04, (0.99, -5.15, 1.92), "emit_led_green", segs=8, rings=4)
    trim.sphere(0.05, (0.0, -6.6, 2.78), "emit_led_red", segs=8, rings=4)
    trim.bx((-0.14, -1.2, 2.4), (0.14, -0.95, 2.46), "emit_police_blue")                           # roof beacon
    # nose spotlight gimbal (Spotlight marker on the lens)
    gear.rod((0.0, 2.35, FLOOR), (0.0, 2.35, 0.5), 0.03, "metal_dark", segs=8)
    trim.sphere(0.13, (0.0, 2.35, 0.42), "metal_dark", segs=14, rings=7)
    trim.cyl(0.09, 0.02, (0.0, 2.47, 0.36), "emit_cool", axis="Y", segs=14)
    body.build()
    rotor = k.empty("Rotor", (0.0, 0.3, 2.75))
    rm = k.obj("RotorBlades", parent=rotor)
    hub = rm.part(bevel=0.01)
    hub.cyl(0.2, 0.12, (0.0, 0.0, 0.0), "metal_grey", segs=16)
    hub.cyl(0.05, 0.12, (0.0, 0.0, 0.11), "metal_dark", segs=10)
    bl = rm.part(bevel=0.004)
    for i in range(4):
        a = math.pi / 4 + math.tau * i / 4
        c, s = math.cos(a), math.sin(a)
        # blade along (c, s): a rod-shaped flat bar, yellow tip
        bl.rod((c * 0.15, s * 0.15, 0.0), (c * 0.45, s * 0.45, 0.0), 0.05, "metal_dark", square=True)
        bl.rod((c * 0.42, s * 0.42, 0.0), (c * 4.3, s * 4.3, 0.0), 0.11, "metal_grey", square=True)
        bl.rod((c * 4.3, s * 4.3, 0.0), (c * 4.5, s * 4.5, 0.0), 0.112, "metal_yellow", square=True)
    rm.build()
    # flatten the square blades to 3 cm thickness
    blades = bpy.data.objects["RotorBlades"]
    for v in blades.data.vertices:
        if math.hypot(v.co.x, v.co.y) > 0.43:
            v.co.z = max(-0.015, min(0.015, v.co.z))
    tail = k.empty("TailRotor", (0.11, -6.45, 2.25))
    tm = k.obj("TailRotorBlades", parent=tail)
    th = tm.part(bevel=0.004)
    th.cyl(0.06, 0.08, (0.0, 0.0, 0.0), "metal_grey", axis="X", segs=10)
    th.bx((0.0, -0.05, -0.62), (0.03, 0.05, 0.62), "metal_grey")
    th.bx((-0.002, -0.052, 0.5), (0.032, 0.052, 0.62), "metal_yellow")
    th.bx((-0.002, -0.052, -0.62), (0.032, 0.052, -0.5), "metal_yellow")
    tm.build()
    # L = Godot -X (the pilot's left with the nose at -Z)
    k.empty("RopeL", (-(W + 0.32), 0.3, 2.03))
    k.empty("RopeR", (W + 0.32, 0.3, 2.03))
    seat = k.empty("SniperSeat", (-(W - 0.25), -0.12, 1.08), rotation=(0.0, 0.0, math.pi / 2))
    # ENV D heli_door kneel root: SniperSeat x Godot-local (0.50, -0.344, 0.15) = Blender-local (0.50, -0.15, -0.344).
    k.empty("SniperKneel", (0.50, -0.15, -0.344), parent=seat)
    k.empty("Spotlight", (0.0, 2.49, 0.36), rotation=(-math.pi / 6, 0.0, 0.0))


# --------------------------------------------------------------------------- breach: wall

def _breach_wall(k: Kit, p: dict) -> None:
    """Infilled old doorway in a partition: room face at Blender y = 0 (room = +Y), cops' face at y = -t."""
    rng = k.ctx.rng
    w, h, t = p["w"], p["h"], p["t"]
    hw = w / 2
    intact = k.empty("Intact")
    plug = k.obj("Infill", parent=intact)
    face = plug.part(bevel=0.0)
    face.bx((-hw, -t, 0.0), (hw, -t / 2, h), p["out"])
    face.bx((-hw, -t / 2, 0.0), (hw, 0.0, h), p["room"])
    trim = plug.part(bevel=0.003)
    # old door casing + plinth blocks on both faces (cover the 0.18 m baseboard stop of a door opening)
    for y0, y1, b0y, b1y in ((0.0, 0.018, 0.0, 0.026), (-t - 0.018, -t, -t - 0.026, -t)):
        for sx in (-1, 1):
            c0, c1 = sorted((sx * hw, sx * (hw + 0.1)))
            trim.bx((c0, y0, 0.21), (c1, y1, h + 0.1), "paint_ivory")
            b0, b1 = sorted((sx * hw, sx * (hw + 0.18)))
            trim.bx((b0, b0y, 0.0), (b1, b1y, 0.21), "paint_ivory")
        trim.bx((-hw - 0.1, y0, h), (hw + 0.1, y1, h + 0.1), "paint_ivory")
    plug.build()
    _collision([((-hw, -t, 0.0), (hw, 0.0, h))], "Collision", intact)
    blown = k.empty("Blown")
    bo = k.obj("BlownFrame", parent=blown)
    keys = ["concrete", "concrete_light", p["room"], p["out"], "brick"]
    _ragged_reveal(bo.part(bevel=0.0), rng, w, h, -t, 0.0, keys)
    sc = k.obj("Scorch", parent=blown)
    _scorch(sc, rng, w, h, 0.0, 1.0, 0.9)
    _scorch(sc, rng, w, h, -t, -1.0, 1.1)
    sc.build()
    deb = bo.part(bevel=0.0)
    _rubble(deb, rng, 34, (-0.9, 0.9), (0.05, 1.7), 0.0, (0.05, 0.2), keys)
    _rubble(deb, rng, 10, (-0.6, 0.6), (-t - 0.05, -t - 0.6), 0.0, (0.04, 0.12), keys)
    # a torn casing board and a slab of infill thrown into the room
    deb.rod((-0.4, 1.1, 0.03), (0.55, 1.45, 0.03), 0.025, "paint_ivory", square=True)
    deb.rod((0.2, 0.55, 0.06), (0.75, 0.7, 0.06), 0.06, p["room"], square=True)
    bo.build()
    k.empty("Charge", (0.0, -t - 0.03, 1.1))
    k.empty("EntryPoint", (0.0, -t - 0.9, 0.0))
    k.empty("ExitPoint", (0.0, 1.0, 0.0))


# ------------------------------------------------------------------------- breach: window

def _breach_window(k: Kit, p: dict) -> None:
    """Window over a sill infill in an exterior wall: room face y = 0, outside face y = -t."""
    rng = k.ctx.rng
    w, h, t, sill = p["w"], p["h"], p["t"], p["sill"]
    hw = w / 2
    yc = -t / 2
    intact = k.empty("Intact")
    plug = k.obj("Infill", parent=intact)
    face = plug.part(bevel=0.0)
    face.bx((-hw, -t, 0.0), (hw, yc, sill), p["out"])
    face.bx((-hw, yc, 0.0), (hw, 0.0, sill), p["room"])
    # window (as prop_window_w100_h120): bronze-black frame set toward the outside, boards, glass
    fw, fd, y0 = 0.055, 0.08, yc - 0.13
    alu = plug.part(bevel=0.002)
    gh = h - sill
    alu.bx((-hw, y0, sill), (-hw + fw, y0 + fd, h), "metal_dark")
    alu.bx((hw - fw, y0, sill), (hw, y0 + fd, h), "metal_dark")
    alu.bx((-hw, y0, sill), (hw, y0 + fd, sill + fw), "metal_dark")
    alu.bx((-hw, y0, h - fw), (hw, y0 + fd, h), "metal_dark")
    board = plug.part(bevel=0.003, segments=2)
    board.bx((-hw - 0.04, y0 + fd, sill), (hw + 0.04, 0.03, sill + 0.028), "marble")
    board.bx((-hw - 0.03, -t - 0.05, sill), (hw + 0.03, y0, sill + 0.035), "concrete_light")
    # radiator console under the window (covers the window-casing stop of the room baseboard)
    board.bx((-hw - 0.08, 0.0, 0.0), (hw + 0.08, 0.13, 0.12), "metal_dark")
    board.bx((-hw - 0.08, 0.0, 0.12), (hw + 0.08, 0.13, 0.72), "metal_white")
    grille = plug.part(bevel=0.0)
    for i in range(12):
        x = -hw + 0.02 + i * (w + 0.12) / 12
        grille.bx((x, 0.13, 0.5), (x + 0.03, 0.134, 0.68), "metal_dark")
    gl = plug.part(bevel=0.0)
    gy = y0 + fd * 0.5
    gl.bx((-hw + fw - 0.005, gy - 0.003, sill + fw - 0.005), (hw - fw + 0.005, gy + 0.003, h - fw + 0.005), "glass")
    plug.build()
    _collision([((-hw, -t, 0.0), (hw, 0.0, h))], "Collision", intact)
    blown = k.empty("Blown")
    bo = k.obj("BlownFrame", parent=blown)
    keys = ["concrete", "concrete_light", "brick", "brick", p["room"]]
    _ragged_reveal(bo.part(bevel=0.0), rng, w, h, -t, 0.0, keys)
    sc = k.obj("Scorch", parent=blown)
    _scorch(sc, rng, w, h, 0.0, 1.0, 0.9)
    _scorch(sc, rng, w, h, -t, -1.0, 1.1)
    sc.build()
    deb = bo.part(bevel=0.0)
    _rubble(deb, rng, 30, (-0.9, 0.9), (0.05, 1.6), 0.0, (0.05, 0.18), keys)
    # bent window frame and glass shards on the floor, the radiator console knocked over
    deb.rod((-0.45, 0.9, 0.03), (0.4, 1.3, 0.05), 0.028, "metal_dark", square=True)
    deb.rod((-0.3, 0.6, 0.03), (-0.55, 1.4, 0.03), 0.028, "metal_dark", square=True)
    for _ in range(14):
        x, y = rng.uniform(-0.8, 0.8), rng.uniform(0.2, 1.8)
        s = rng.uniform(0.04, 0.1)
        deb.bx((x - s, y - s * 0.7, 0.0), (x + s, y + s * 0.7, 0.004), "glass")
    deb.bx((0.2, 1.3, 0.0), (1.36, 1.9, 0.13), "metal_white")
    bo.build()
    k.empty("Charge", (0.0, -t - 0.03, 1.0))
    # cops reach the window on a rope from the parapet (RopeAnchor): EntryPoint hangs outside the sill
    k.empty("EntryPoint", (0.0, -t - 0.6, 0.0))
    k.empty("RopeAnchor", (0.0, -t / 2, p["parapet"]))
    k.empty("ExitPoint", (0.0, 1.0, 0.0))


# ------------------------------------------------------------------------ breach: ceiling

def _breach_ceiling(k: Kit, p: dict) -> None:
    """Sealed skylight through a roof slab + plenum + ceiling. Authored Z-up (origin = ceiling underside
    centre, roof top at z = plenum, room floor at z = -drop), then turned +90 deg about Blender X so the
    scene's Godot -Z points down into the room (A's `Breach_<n>` marker frame; Godot +Y = world north)."""
    rng = k.ctx.rng
    w, top, drop = p["w"], p["plenum"], p["drop"]
    hw = w / 2
    cw, ch = 0.15, 0.2          # skylight curb width / height above the roof
    co = hw + cw
    frame = k.empty("Frame")
    fo = k.obj("Curb", parent=frame)
    cb = fo.part(bevel=0.01)
    for lo, hi in (((-co, -co, top), (co, -hw, top + ch)), ((-co, hw, top), (co, co, top + ch)),
                   ((-co, -hw, top), (-hw, hw, top + ch)), ((hw, -hw, top), (co, hw, top + ch))):
        cb.bx(lo, hi, "concrete")
    fo.build()
    curb_boxes = [((-co, -co, top), (co, -hw, top + ch)), ((-co, hw, top), (co, co, top + ch)),
                  ((-co, -hw, top), (-hw, hw, top + ch)), ((hw, -hw, top), (co, hw, top + ch))]
    _collision(curb_boxes, "CurbCollision", frame)
    intact = k.empty("Intact")
    plug = k.obj("Seal", parent=intact)
    cov = plug.part(bevel=0.006)
    cov.bx((-co - 0.04, -co - 0.04, top + ch), (co + 0.04, co + 0.04, top + ch + 0.035), "metal_dark")
    for sx in (-1, 1):
        for sy in (-1, 1):
            cov.cyl(0.02, 0.012, (sx * (co - 0.05), sy * (co - 0.05), top + ch + 0.04), "steel", segs=8)
    cov.bx((-co - 0.04, -0.05, top + ch + 0.035), (co + 0.04, 0.05, top + ch + 0.04), "hivis")
    # ceiling access panel under the hole (flush with the ceiling, a 4 cm frame lapping onto it)
    pan = plug.part(bevel=0.002)
    for lo, hi in (((-hw - 0.05, -hw - 0.05), (hw + 0.05, -hw + 0.03)), ((-hw - 0.05, hw - 0.03), (hw + 0.05, hw + 0.05)),
                   ((-hw - 0.05, -hw + 0.03), (-hw + 0.03, hw - 0.03)), ((hw - 0.03, -hw + 0.03), (hw + 0.05, hw - 0.03))):
        pan.bx((lo[0], lo[1], -0.014), (hi[0], hi[1], -0.002), "metal_dark")
    pan.bx((-hw + 0.03, -hw + 0.03, -0.01), (hw - 0.03, hw - 0.03, 0.04), "metal_white")
    for sx in (-1, 1):
        pan.bx((sx * 0.3 - 0.05, hw - 0.12, -0.016), (sx * 0.3 + 0.05, hw - 0.08, -0.01), "metal_dark")   # latches
    plug.build()
    _collision([((-hw, -hw, -0.012), (hw, hw, 0.05)), ((-co - 0.04, -co - 0.04, top + ch), (co + 0.04, co + 0.04, top + ch + 0.035))],
               "Collision", intact)
    blown = k.empty("Blown")
    bo = k.obj("BlownFrame", parent=blown)
    keys = ["concrete", "concrete_light", "plaster", "metal_grey"]
    liner = bo.part(bevel=0.0)
    for lo, hi in (((-hw - 0.03, -hw - 0.03, 0.0), (hw + 0.03, -hw, top)), ((-hw - 0.03, hw, 0.0), (hw + 0.03, hw + 0.03, top)),
                   ((-hw - 0.03, -hw, 0.0), (-hw, hw, top)), ((hw, -hw, 0.0), (hw + 0.03, hw, top))):
        liner.bx(lo, hi, "concrete")
    rim = bo.part(bevel=0.0)
    # broken lumps on the curb top and round the ceiling hole, a torn panel flap hanging down
    for z in (top + ch, 0.0):
        for i in range(16):
            a = math.tau * (i + rng.random() * 0.5) / 16
            c, s = math.cos(a), math.sin(a)
            r = (hw + 0.02) / max(abs(c), abs(s))
            _chunk(rim, rng, (c * r, s * r, z + (0.02 if z > 0 else -0.02)), rng.uniform(0.06, 0.12), keys[rng.randrange(len(keys))])
    rim.rod((hw - 0.02, -0.4, -0.01), (hw - 0.3, -0.25, -0.55), 0.02, "metal_white", square=True)
    rim.rod((-hw + 0.02, 0.3, -0.01), (-hw + 0.12, 0.45, -0.35), 0.025, "plaster", square=True)
    sc = k.obj("Scorch", parent=blown)
    soot = sc.part(bevel=0.0)
    for key, m, z0 in (("soot_haze", 0.42, -0.005), ("soot", 0.18, -0.01)):
        _ring(soot, _jagged_ring(rng, hw, m, 0.3), hw, z0, z0 + 0.001, key)
    for key, m, z0 in (("soot_haze", 0.45, top + 0.004), ("soot", 0.2, top + 0.009)):
        _ring(soot, _jagged_ring(rng, co, m, 0.35), co, z0, z0 + 0.001, key)
    sc.build()
    deb = bo.part(bevel=0.0)
    # the blown cover lands on the roof, the panel and slab debris on the room floor below
    deb.bx((co + 0.35, -0.5, top), (co + 1.3, 0.45, top + 0.035), "metal_dark")
    _rubble(deb, rng, 30, (-1.0, 1.0), (-1.0, 1.0), -drop, (0.05, 0.2), keys)
    deb.bx((-0.6, -0.2, -drop), (0.15, 0.5, -drop + 0.03), "plaster")
    bo.build()
    k.empty("Charge", (0.0, 0.0, top + ch + 0.04))
    k.empty("EntryPoint", (0.0, co + 0.9, top))
    k.empty("RopeAnchor", (0.0, co - 0.05, top + ch))
    k.empty("ExitPoint", (0.0, 0.0, -drop))
    # turn the whole asset +90 deg about Blender X: Z-up authoring -> Godot -Z pointing down
    rot = Matrix.Rotation(math.pi / 2, 4, "X")
    bpy.context.view_layer.update()
    for obj in list(bpy.context.scene.objects):
        if obj.parent is None:
            obj.matrix_world = rot @ obj.matrix_world


def build(ctx) -> None:
    k = Kit(ctx)
    globals()["_" + ctx.params["fn"]](k, ctx.params)
