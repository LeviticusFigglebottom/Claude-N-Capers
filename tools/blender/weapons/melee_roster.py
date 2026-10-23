"""P5 melee roster: first-person item models for the 11 melees after the folding knife (folding_knife.py).

Original designs, one variant each (``kind``): combat dagger, prison shank, telescopic baton, aluminium bat,
claw hammer, lead pipe, crowbar, sledgehammer, machete, fire axe, meat cleaver.

Item contract (contracts/visual_slots.md "Items", D-069), as folding_knife.py, in Blender axes:
* origin on the handle axis 20 mm below the top of the fist (the fist spans about z -0.075 .. +0.020);
* handle along Godot +Y = Blender +Z (the head / blade points up from the fist);
* cutting edge / striking face toward Godot -Z = Blender +Y;
* Blender +X = Godot +X = the blade flat normal.

Nodes (Godot names): ``Handle`` (what the hand holds, with ``Grip`` wraps where there are any) and ``Head`` (the
blade, shaft or striking head) with ``Hardware`` (guards, rivets, ferrules, caps). No markers.
"""

import math

import bmesh

import _common as c

TRI_BUDGET = 6000
VARIANTS = {
    "wpn_melee_combat_dagger": {"kind": "combat_dagger"},
    "wpn_melee_prison_shank": {"kind": "prison_shank"},
    "wpn_melee_telescopic_baton": {"kind": "telescopic_baton"},
    "wpn_melee_aluminium_bat": {"kind": "aluminium_bat"},
    "wpn_melee_claw_hammer": {"kind": "claw_hammer"},
    "wpn_melee_lead_pipe": {"kind": "lead_pipe"},
    "wpn_melee_crowbar": {"kind": "crowbar"},
    "wpn_melee_sledgehammer": {"kind": "sledgehammer"},
    "wpn_melee_machete": {"kind": "machete"},
    "wpn_melee_fire_axe": {"kind": "fire_axe"},
    "wpn_melee_meat_cleaver": {"kind": "meat_cleaver"},
}


# --- shape helpers --------------------------------------------------------------------------------
def _faces(bm, rings, mat, cap0=True, cap1=True, mats=None):
    """Quads between consecutive closed rings (lists of BMVerts), optional end caps. ``mats[k]`` overrides the
    material of the band between ring k and k+1."""
    for k, (a, b) in enumerate(zip(rings, rings[1:])):
        n = len(a)
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mats[k] if mats is not None else mat
    if cap0:
        bm.faces.new(list(reversed(rings[0]))).material_index = mat
    if cap1:
        bm.faces.new(rings[-1]).material_index = mat


def _fan(bm, ring, tip, mat):
    t = bm.verts.new(tip)
    for i in range(len(ring)):
        bm.faces.new((ring[i], ring[(i + 1) % len(ring)], t)).material_index = mat


def sweep(mb, path, radii, mat, sides=12, cap0=True, cap1=True, mats=None, tip0=None, tip1=None, phase=0.0,
          x0=0.0):
    """Tube along a path in the plane x = ``x0``: ``path`` [(y, z)], ``radii`` [(rx, ry)] per point (rx across X,
    ry in the path plane). Optional pointed ends (``tip0`` / ``tip1`` = (y, z))."""
    bm = mb.bm
    rings = []
    for k, (y, z) in enumerate(path):
        a = path[max(k - 1, 0)]
        b = path[min(k + 1, len(path) - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(ty, tz) or 1.0
        ny, nz = -tz / ln, ty / ln
        rx, ry = radii[k]
        ring = []
        for i in range(sides):
            ang = 2.0 * math.pi * i / sides + phase
            ring.append(bm.verts.new((x0 + rx * math.cos(ang), y + ny * ry * math.sin(ang), z + nz * ry * math.sin(ang))))
        rings.append(ring)
    _faces(bm, rings, mat, cap0 and tip0 is None, cap1 and tip1 is None, mats)
    if tip0 is not None:
        t = bm.verts.new((x0, tip0[0], tip0[1]))
        r = rings[0]
        for i in range(sides):
            bm.faces.new((r[(i + 1) % sides], r[i], t)).material_index = mat
    if tip1 is not None:
        _fan(bm, rings[-1], (x0, tip1[0], tip1[1]), mat)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def lathe(mb, prof, mat, sides=16, rx_scale=1.0, mats=None, cap0=True, cap1=True):
    """Round (or elliptical, ``rx_scale``) solid along +Z from a profile [(r, z)]."""
    sweep(mb, [(0.0, z) for _r, z in prof], [(r * rx_scale, r) for r, _z in prof], mat, sides, cap0, cap1, mats)


def blade(mb, zs, spine, edge, half_t, flat, bev, grind=0.45, edge_t=0.0002, tip=None, double=False, cap_end=False):
    """Blade loft along +Z: ``spine(z)`` / ``edge(z)`` give the y of the back and the cutting edge (edge toward +Y),
    ``half_t(z)`` the half thickness. A single-edged section is spine flats + grind bevels + edge (folding_knife.py);
    ``double`` grinds both sides. Closed by ``tip`` (y, z) or a flat end cap."""
    bm = mb.bm
    rings = []
    for z in zs:
        s, e, h = spine(z), edge(z), half_t(z)
        if double:
            m = 0.5 * (s + e)
            loop = [(-edge_t, s), (-h, m), (-edge_t, e), (edge_t, e), (h, m), (edge_t, s)]
            fm = [bev, bev, bev, bev, bev, bev]
        else:
            g = s + grind * (e - s)
            loop = [(-h, s), (-h, g), (-edge_t, e), (edge_t, e), (h, g), (h, s)]
            fm = [flat, bev, bev, bev, flat, flat]
        rings.append([bm.verts.new((x, y, z)) for x, y in loop])
    for a, b in zip(rings, rings[1:]):
        for i in range(6):
            j = (i + 1) % 6
            bm.faces.new((a[i], a[j], b[j], b[i])).material_index = fm[i]
    bm.faces.new(list(reversed(rings[0]))).material_index = flat
    if tip is not None:
        _fan(bm, rings[-1], (0.0, tip[0], tip[1]), bev)
    else:
        bm.faces.new(rings[-1]).material_index = flat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


def _span(z0, z1, n, power=1.0):
    return [z0 + (z1 - z0) * (i / n) ** power for i in range(n + 1)]


def _wrap(ctx, mat, z0, z1, r, parent, rx_scale=1.0, bands=0, name="Grip"):
    """A grip wrap (tape, foam, rubber) around a round handle, with optional raised bands."""
    mb = ctx.builder()
    m = mb.material(mat)
    lathe(mb, [(r * 0.96, z0), (r, z0 + 0.002), (r, z1 - 0.002), (r * 0.96, z1)], m, 16, rx_scale)
    for i in range(bands):
        z = z0 + (z1 - z0) * (i + 0.5) / bands
        lathe(mb, [(r * 1.04, z - 0.0025), (r * 1.06, z), (r * 1.04, z + 0.0025)], m, 16, rx_scale)
    return c.finish(mb, name, parent=parent)


# --- the melees -----------------------------------------------------------------------------------
def combat_dagger(ctx, mats):
    mb = ctx.builder()
    rub = mb.material(mats.rubber())
    prof = []
    for i, z in enumerate(_span(-0.088, 0.024, 14)):  # ringed grip, swelling in the middle of the fist
        swell = 1.0 + 0.10 * math.sin(math.pi * (z + 0.088) / 0.112)
        prof.append(((0.0118 if i % 2 == 0 else 0.0128) * swell, z))
    lathe(mb, prof, rub, 14, rx_scale=0.78)
    handle = c.finish(mb, "Handle")
    hw = ctx.builder()
    st = hw.material(mats.steel())
    lathe(hw, [(0.006, -0.102), (0.0125, -0.098), (0.0125, -0.090), (0.010, -0.087)], st, 14, rx_scale=0.8)
    hw.box((-0.0055, -0.034, 0.024), (0.0055, 0.034, 0.032), mat=st)          # cross guard
    for s in (-1.0, 1.0):
        hw.cylinder(0.0055, 0.011, 10, (0.0, s * 0.034, 0.028), axis="X", mat=st)
    c.finish(hw, "Hardware", bevel=0.0006, parent=handle)
    bl = ctx.builder()
    flat = bl.material(mats.steel())
    bev = bl.material(mats.bare())
    zs = _span(0.032, 0.196, 14, 1.2)
    w = lambda z: 0.0145 * (1.0 - max(0.0, (z - 0.12) / 0.085) ** 1.6)
    blade(bl, zs, lambda z: -w(z), w, lambda z: 0.0032 * (1.0 - 0.5 * (z - 0.032) / 0.17), flat, bev,
          tip=(0.0, 0.205), double=True)
    c.finish(bl, "Head")


def prison_shank(ctx, mats):
    mb = ctx.builder()
    pl = mb.material(ctx.material("plastic_matte", "#7FA7C2", roughness=0.45))
    body = c.rounded_rect(0.0058, 0.0028, 0.0024, corner_segments=3)
    pts = [(x, y) for x, y in body]
    zs = _span(-0.090, 0.058, 10)
    rings = [[mb.bm.verts.new((y * 1.0, x * (1.0 + 0.25 * math.sin(math.pi * (z + 0.09) / 0.148)), z))
              for x, y in pts] for z in zs]
    _faces(mb.bm, rings, pl)
    bmesh.ops.recalc_face_normals(mb.bm, faces=mb.bm.faces)
    handle = c.finish(mb, "Handle")
    gr = ctx.builder()
    tape = gr.material(ctx.material("fabric_upholstery", "#C9C2B0", roughness=0.95))
    for i in range(7):  # cloth strip wound round the grip
        z = -0.080 + i * 0.0135
        sweep(gr, [(0.0, z), (0.0, z + 0.010)], [(0.0045, 0.0083), (0.0045, 0.0083)], tape, 10, phase=0.3 * i)
    c.finish(gr, "Grip", parent=handle)
    hd = ctx.builder()
    edge = hd.material(ctx.material("plastic_matte", "#7FA7C2", roughness=0.45))
    zs = _span(0.058, 0.084, 4)
    sweep(hd, [(0.0, z) for z in zs], [(0.0028 * (1 - 0.8 * (z - 0.058) / 0.026), 0.0058 * (1 - 0.8 * (z - 0.058) / 0.026))
                                       for z in zs], edge, 8, tip1=(0.0, 0.088))
    c.finish(hd, "Head")


def telescopic_baton(ctx, mats):
    mb = ctx.builder()
    foam = mb.material(mats.rubber())
    lathe(mb, [(0.0118, -0.088), (0.0135, -0.084), (0.0140, -0.020), (0.0132, 0.050), (0.0120, 0.056)], foam, 16)
    handle = c.finish(mb, "Handle")
    hw = ctx.builder()
    st = hw.material(mats.steel())
    lathe(hw, [(0.004, -0.100), (0.0120, -0.097), (0.0125, -0.088), (0.0110, -0.086)], st, 16)
    lathe(hw, [(0.0118, 0.054), (0.0118, 0.062), (0.0100, 0.066)], st, 16)
    c.finish(hw, "Hardware", bevel=0.0004, parent=handle)
    sh = ctx.builder()
    tube = sh.material(mats.steel())
    tip = sh.material(mats.bare())
    for r, z0, z1 in ((0.0092, 0.062, 0.230), (0.0074, 0.226, 0.380), (0.0058, 0.376, 0.505)):
        lathe(sh, [(r, z0), (r, z1 - 0.006), (r * 1.08, z1 - 0.004), (r * 1.08, z1)], tube, 14)
    lathe(sh, [(0.004, 0.503), (0.0085, 0.508), (0.0095, 0.516), (0.0080, 0.524), (0.003, 0.528)], tip, 14)
    c.finish(sh, "Head")


def aluminium_bat(ctx, mats):
    paint = ctx.material("metal_painted", "#2E5E9A", roughness=0.35, metallic=0.8)
    mb = ctx.builder()
    body = mb.material(paint)
    lathe(mb, [(0.006, -0.104), (0.021, -0.100), (0.022, -0.094), (0.0135, -0.086), (0.0122, -0.070),
               (0.0122, 0.100)], body, 20)
    handle = c.finish(mb, "Handle")
    _wrap(ctx, mats.rubber(), -0.084, 0.080, 0.0132, handle, bands=0)
    hd = ctx.builder()
    hb = hd.material(paint)
    cap = hd.material(mats.rubber())
    dec = hd.material(ctx.material("paint_white", "#D8D8D2", roughness=0.5))
    lathe(hd, [(0.0122, 0.100), (0.0145, 0.200), (0.0215, 0.300), (0.0290, 0.380), (0.0325, 0.440), (0.0330, 0.640),
               (0.0320, 0.650)], hb, 20)
    lathe(hd, [(0.0320, 0.648), (0.0300, 0.658), (0.0200, 0.664), (0.004, 0.666)], cap, 20)
    for z in (0.470, 0.600):  # two painted bands on the barrel
        lathe(hd, [(0.0332, z), (0.0333, z + 0.006)], dec, 20)
    c.finish(hd, "Head")


def _wood_handle(ctx, mats, z0, z1, r0, r1, rx_scale, grip_to=None, wood="walnut"):
    mb = ctx.builder()
    mat = mats.wood() if wood == "walnut" else ctx.material("wood_panel_oak", "#9A7A52", roughness=0.6)
    w = mb.material(mat)
    zs = _span(z0, z1, 10)
    prof = [((r0 + (r1 - r0) * (z - z0) / (z1 - z0)) * (1.10 if z < z0 + 0.03 else 1.0), z) for z in zs]
    prof[0] = (prof[0][0] * 0.85, z0)
    lathe(mb, prof, w, 14, rx_scale=rx_scale)
    handle = c.finish(mb, "Handle")
    if grip_to is not None:
        _wrap(ctx, mats.rubber(), z0 + 0.004, grip_to, r0 * 1.12, handle, rx_scale=rx_scale, bands=3)
    return handle


def claw_hammer(ctx, mats):
    _wood_handle(ctx, mats, -0.092, 0.215, 0.0150, 0.0120, 0.72, grip_to=0.030)
    hd = ctx.builder()
    st = hd.material(mats.steel())
    face = hd.material(mats.bare())
    hd.box((-0.0120, -0.016, 0.200), (0.0120, 0.016, 0.240), mat=st)              # eye block over the handle
    sweep(hd, [(0.014, 0.220), (0.040, 0.220)], [(0.0115, 0.0115), (0.0135, 0.0135)], st, 16, cap1=False)
    sweep(hd, [(0.040, 0.220), (0.052, 0.220)], [(0.0135, 0.0135), (0.0140, 0.0140)], face, 16)  # striking face
    path = [(-0.014 - 0.075 * math.sin(math.radians(a)), 0.232 - 0.045 * (1 - math.cos(math.radians(a))))
            for a in range(0, 76, 15)]
    rad = [(0.0045 * (1 - 0.55 * k / 5), 0.0085 * (1 - 0.6 * k / 5)) for k in range(6)]
    for s in (-1.0, 1.0):  # split claw curving back and down toward -Y
        sweep(hd, path, rad, st, 8, x0=s * 0.0055)
    c.finish(hd, "Head", bevel=0.0005)


def lead_pipe(ctx, mats):
    mb = ctx.builder()
    iron = mb.material(ctx.material("metal_matte", "#55585C", roughness=0.7, metallic=0.85))
    lathe(mb, [(0.0165, -0.105), (0.0168, 0.395)], iron, 16)
    for i in range(5):  # cut threads at the bottom end
        z = -0.104 + i * 0.003
        lathe(mb, [(0.0166, z), (0.0172, z + 0.0012), (0.0166, z + 0.0024)], iron, 16)
    handle = c.finish(mb, "Handle")
    _wrap(ctx, mats.rubber(), -0.082, 0.026, 0.0175, handle, bands=0, name="Grip")
    hd = ctx.builder()
    fit = hd.material(mats.matte())
    prof = [(0.0170, 0.385), (0.0215, 0.388), (0.0215, 0.432), (0.0170, 0.436), (0.0165, 0.445)]
    lathe(hd, prof, fit, 8)   # hex-ish coupling at the striking end
    c.finish(hd, "Head", bevel=0.0006)


def crowbar(ctx, mats):
    paint = ctx.material("metal_painted", "#8E1F1A", roughness=0.4, metallic=0.7)
    mb = ctx.builder()
    p = mb.material(paint)
    sweep(mb, [(0.0, -0.118), (0.0, 0.360)], [(0.0098, 0.0098), (0.0098, 0.0098)], p, 6, phase=math.pi / 6)
    handle = c.finish(mb, "Handle")
    hd = ctx.builder()
    hp = hd.material(paint)
    bare = hd.material(mats.bare())
    # gooseneck: up, over and down toward +Y, flattening into a split claw
    path = [(0.0, 0.360)]
    for a in range(15, 181, 15):
        r = math.radians(a)
        path.append((0.042 - 0.042 * math.cos(r), 0.360 + 0.050 * math.sin(r)))
    path += [(0.084, 0.335), (0.086, 0.318)]
    n = len(path)
    rad = [(0.0098 if k < n - 3 else 0.0098 + 0.004 * (k - n + 3), 0.0098 if k < n - 3 else 0.0098 - 0.0028 * (k - n + 3))
           for k in range(n)]
    sweep(hd, path, rad, hp, 6, phase=math.pi / 6, mats=[hp] * (n - 2) + [bare])
    # the other end: a short chisel bend toward +Y
    path2 = [(0.0, -0.118), (0.002, -0.128), (0.008, -0.138), (0.016, -0.146)]
    rad2 = [(0.0098, 0.0098), (0.0105, 0.0085), (0.0115, 0.0060), (0.0125, 0.0030)]
    sweep(hd, path2, rad2, hp, 6, phase=math.pi / 6, mats=[hp, hp, bare])
    c.finish(hd, "Head")


def sledgehammer(ctx, mats):
    _wood_handle(ctx, mats, -0.102, 0.640, 0.0170, 0.0150, 0.72, grip_to=0.090, wood="oak")
    hd = ctx.builder()
    st = hd.material(mats.steel())
    face = hd.material(mats.bare())
    octo = [(0.030, 0.012), (0.030, -0.012), (0.012, -0.030), (-0.012, -0.030), (-0.030, -0.012), (-0.030, 0.012),
            (-0.012, 0.030), (0.012, 0.030)]
    sect = [(x, z + 0.632) for x, z in octo]
    hd.prism(sect, axis="Y", start=-0.072, end=0.072, mat=st)
    for y0, y1 in ((0.072, 0.080), (-0.080, -0.072)):
        hd.prism([(x * 0.94, (z - 0.632) * 0.94 + 0.632) for x, z in sect], axis="Y", start=y0, end=y1, mat=face)
    c.finish(hd, "Head", bevel=0.0012)


def machete(ctx, mats):
    mb = ctx.builder()
    pol = mb.material(mats.polymer())
    prof = [(-0.0135, 0.026), (-0.0150, -0.010), (-0.0150, -0.060), (-0.0120, -0.085), (-0.0040, -0.096),
            (0.0110, -0.094), (0.0175, -0.080), (0.0160, -0.062), (0.0185, -0.045), (0.0160, -0.028), (0.0185, -0.010),
            (0.0160, 0.008), (0.0155, 0.026)]
    mb.prism(prof, axis="X", start=-0.0085, end=0.0085, mat=pol)
    handle = c.finish(mb, "Handle", bevel=0.0018, segments=2)
    hw = ctx.builder()
    br = hw.material(ctx.material("brass", "#B48F3E", roughness=0.35, metallic=1.0))
    for z in (-0.070, -0.035, 0.000):
        hw.cylinder(0.0032, 0.0186, 10, (0.0, 0.001, z), axis="X", mat=br)
    c.finish(hw, "Hardware", parent=handle)
    bl = ctx.builder()
    flat = bl.material(ctx.material("brushed_steel", "#A7AAAE", roughness=0.32, metallic=1.0))
    bev = bl.material(mats.bare())
    zs = _span(0.024, 0.388, 18)
    edge = lambda z: 0.020 + 0.016 * math.sin(math.pi * min(1.0, (z - 0.024) / 0.36) * 0.9)
    spine = lambda z: -0.0125 if z < 0.33 else -0.0125 + (z - 0.33) * 0.30
    blade(bl, zs, spine, edge, lambda z: 0.0013, flat, bev, grind=0.55, tip=(0.010, 0.402))
    c.finish(bl, "Head")


def fire_axe(ctx, mats):
    _wood_handle(ctx, mats, -0.104, 0.650, 0.0175, 0.0160, 0.70, grip_to=None, wood="oak")
    hd = ctx.builder()
    paint = hd.material(ctx.material("paint_safety_orange", "#C8341E", roughness=0.45))
    bare = hd.material(mats.bare())
    bm = hd.bm
    # blade: XZ sections lofted toward +Y, flaring into a long bare edge
    secs = [(-0.022, 0.018, 0.590, 0.665), (0.010, 0.014, 0.592, 0.662), (0.045, 0.008, 0.575, 0.676),
            (0.080, 0.004, 0.556, 0.692), (0.094, 0.0018, 0.550, 0.698), (0.100, 0.0003, 0.548, 0.700)]
    rings = []
    for y, hx, z0, z1 in secs:
        rings.append([bm.verts.new(p) for p in ((-hx, y, z0), (hx, y, z0), (hx, y, z1), (-hx, y, z1))])
    _faces(bm, rings, paint, mats=[paint, paint, paint, bare, bare])
    # pick: toward -Y, a square section closing to a point
    picks = [(-0.022, 0.015, 0.600, 0.655), (-0.052, 0.010, 0.612, 0.646), (-0.080, 0.005, 0.620, 0.638)]
    prs = []
    for y, hx, z0, z1 in picks:
        prs.append([bm.verts.new(p) for p in ((-hx, y, z0), (-hx, y, z1), (hx, y, z1), (hx, y, z0))])
    _faces(bm, prs, paint, cap1=False)
    _fan(bm, prs[-1], (0.0, -0.094, 0.626), paint)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    c.finish(hd, "Head")


def meat_cleaver(ctx, mats):
    mb = ctx.builder()
    wood = mb.material(mats.wood())
    prof = [(-0.0120, 0.022), (-0.0125, -0.050), (-0.0105, -0.082), (-0.0050, -0.092), (0.0070, -0.092),
            (0.0125, -0.082), (0.0140, -0.050), (0.0130, 0.022)]
    mb.prism(prof, axis="X", start=-0.0080, end=0.0080, mat=wood)
    handle = c.finish(mb, "Handle", bevel=0.0018, segments=2)
    hw = ctx.builder()
    st = hw.material(mats.bare())
    for z in (-0.068, -0.036, -0.004):
        hw.cylinder(0.0030, 0.0166, 10, (0.0, 0.0005, z), axis="X", mat=st)
    hw.box((-0.0084, -0.0130, 0.016), (0.0084, 0.0140, 0.026), mat=st)         # bolster
    c.finish(hw, "Hardware", bevel=0.0004, parent=handle)
    bl = ctx.builder()
    flat = bl.material(ctx.material("brushed_steel", "#A7AAAE", roughness=0.32, metallic=1.0))
    bev = bl.material(mats.bare())
    zs = _span(0.026, 0.205, 10)
    blade(bl, zs, lambda z: -0.0140, lambda z: 0.072 + 0.004 * math.sin(math.pi * (z - 0.026) / 0.18),
          lambda z: 0.0021, flat, bev, grind=0.70)
    c.finish(bl, "Head")


def build(ctx) -> None:
    mats = c.Mats(ctx)
    globals()[ctx.param("kind")](ctx, mats)  # VARIANTS kind = the builder function
    ctx.source_extra["tris_lod0"] = c.tris_of_scene()
    ctx.source_extra["origin"] = "handle axis, 20 mm below the top of the fist; handle +Y, edge / face -Z (Godot)"
