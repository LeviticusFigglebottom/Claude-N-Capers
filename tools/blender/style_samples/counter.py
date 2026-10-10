"""C1-00 sample asset 1: Glasshouse jewelry display counter (hero prop), ~1.2 x 0.6 x 1.0 m.

One geometry generator for all styles: walnut lacquer cabinet with raised panels and brass inlay,
brass-framed glass case, velvet deck, ring tray (5 rings seated in a slot), two necklace busts
(pearls; gold chain with pendant) and three watches strapped on pillows. The style preset changes
bevels, surface treatment (wear, fingerprints, painterly), lighting rig, practical intensity and grade.

    blender -b --factory-startup --python counter.py -- --style a_gsr [--out PATH] [--scale 0.5]
"""

from __future__ import annotations

import math
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import sslib as L  # noqa: E402
import styles  # noqa: E402
from styles import PALETTE  # noqa: E402

ASSET = "counter"
W, D = 1.20, 0.60                   # cabinet footprint
PLINTH = 0.08
BASE_TOP = 0.70                     # top of cabinet carcass
SLAB = 0.035                        # counter slab under the case
DECK = BASE_TOP + SLAB + 0.018      # velvet deck surface
CASE_TOP = 1.0


def _orient(ob, loc, normal, up=(0, 0, 1)):
    n = Vector(normal).normalized()
    x = Vector(up).cross(n)
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    x.normalize()
    y = n.cross(x)
    M = Matrix(((*x, 0), (*y, 0), (*n, 0), (0, 0, 0, 1))).transposed()
    ob.matrix_world = Matrix.Translation(Vector(loc)) @ M
    return ob


# --------------------------------------------------------------------------- cabinet & case

def build_cabinet(st, m):
    bw, sg = st["bevel"], st["bevel_segments"]
    L.box("Plinth", (W - 0.06, D - 0.06, PLINTH), (0, 0, PLINTH / 2), m["plinth"], bw * 0.5, sg)
    L.box("Carcass", (W, D, BASE_TOP - PLINTH), (0, 0, PLINTH + (BASE_TOP - PLINTH) / 2), m["walnut"], bw, sg)
    L.box("Slab", (W + 0.04, D + 0.04, SLAB), (0, 0, BASE_TOP + SLAB / 2), m["walnut_dark"], bw, sg)
    # brass edge band around the slab and a brass kick plate
    L.box("SlabBand", (W + 0.044, D + 0.044, 0.010), (0, 0, BASE_TOP + SLAB / 2), m["brass"], bw * 0.3, sg)
    L.box("KickPlate", (W - 0.058, D - 0.058, 0.012), (0, 0, 0.012), m["brass"], bw * 0.3, sg)
    # front: three raised panels with brass inlay frames; sides: one panel each
    pw, ph = 0.33, 0.44
    zc = PLINTH + (BASE_TOP - PLINTH) / 2
    for i, x in enumerate((-0.38, 0.0, 0.38)):
        L.box(f"Panel{i}", (pw, 0.016, ph), (x, -D / 2 - 0.004, zc), m["walnut"], bw * 1.2, sg)
        for j, (sx, sz, dx, dz) in enumerate(((pw + 0.03, 0.004, 0, ph / 2 + 0.015), (pw + 0.03, 0.004, 0, -ph / 2 - 0.015),
                                              (0.004, ph + 0.034, pw / 2 + 0.015, 0), (0.004, ph + 0.034, -pw / 2 - 0.015, 0))):
            L.box(f"Inlay{i}_{j}", (sx, 0.004, sz), (x + dx, -D / 2 - 0.0005, zc + dz), m["brass"], 0.0008, 1)
    for s in (-1, 1):
        L.box(f"SidePanel{s}", (0.016, D - 0.12, ph), (s * (W / 2 + 0.004), 0, zc), m["walnut"], bw * 1.2, sg)
    # brass escutcheon / lock on the centre panel (service side is the back, but a lock reads "valuables")
    lk = L.cylinder("Lock", 0.012, 0.01, (0, -D / 2 - 0.014, zc + 0.17), m["brass"], 32, rot=(math.pi / 2, 0, 0),
                    bevel_w=0.0015)


def build_case(st, m):
    bw, sg = st["bevel"], st["bevel_segments"]
    z0 = BASE_TOP + SLAB
    h = CASE_TOP - z0
    t = 0.008
    fw, fd = W - 0.02, D - 0.02
    L.box("Deck", (fw - 0.03, fd - 0.03, 0.018), (0, 0, z0 + 0.009), m["velvet_deck"], 0.004, 2)
    # glass panes
    L.box("GlassFront", (fw, t, h - 0.02), (0, -fd / 2, z0 + h / 2), m["glass"])
    L.box("GlassBack", (fw, t, h - 0.02), (0, fd / 2, z0 + h / 2), m["glass"])
    for s in (-1, 1):
        L.box(f"GlassSide{s}", (t, fd, h - 0.02), (s * fw / 2, 0, z0 + h / 2), m["glass"])
    L.box("GlassTop", (fw + 0.01, fd + 0.01, 0.010), (0, 0, CASE_TOP - 0.005), m["glass"])
    # brass frame: posts and rails (15 mm square)
    p = 0.015
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box(f"Post{sx}{sy}", (p, p, h), (sx * fw / 2, sy * fd / 2, z0 + h / 2), m["brass"], bw * 0.4, sg)
    for zz in (z0 + p / 2, CASE_TOP - p / 2):
        for sy in (-1, 1):
            L.box(f"RailX{sy}{zz:.2f}", (fw + p, p, p), (0, sy * fd / 2, zz), m["brass"], bw * 0.4, sg)
        for sx in (-1, 1):
            L.box(f"RailY{sx}{zz:.2f}", (p, fd + p, p), (sx * fw / 2, 0, zz), m["brass"], bw * 0.4, sg)
    # LED strip under the top rail, inside the case (practical)
    L.box("LEDStrip", (fw - 0.06, 0.008, 0.004), (0, -fd / 2 + 0.02, CASE_TOP - 0.018), m["led"])
    li = bpy.data.lights.new("CaseLED", "AREA")
    li.shape = "RECTANGLE"
    li.size = fw - 0.08
    li.size_y = 0.02
    li.energy = {"a_gsr": 22.0, "b_noir": 26.0, "c_photo": 18.0}[st["_id"]]
    li.color = L.kelvin(3000 if st["_id"] != "c_photo" else 3800)
    ob = bpy.data.objects.new("CaseLED", li)
    L.link(ob)
    ob.location = (0, -fd / 2 + 0.03, CASE_TOP - 0.022)
    ob.rotation_euler = (math.radians(32), 0, 0)


# --------------------------------------------------------------------------- jewelry

def gem_mesh(name, r, mat, table=0.56, crown_h=0.30, pav_h=0.82, segs=16):
    """Round brilliant approximation: table, crown, girdle, pavilion to a culet point."""
    bm = bmesh.new()

    def ring_(rad, z, off=0.0):
        return [bm.verts.new((rad * math.cos(2 * math.pi * (i + off) / segs), rad * math.sin(2 * math.pi * (i + off) / segs), z))
                for i in range(segs)]
    tab = ring_(r * table, r * crown_h, 0.5)
    gt = ring_(r, r * 0.03)
    gb = ring_(r, -r * 0.03)
    cul = bm.verts.new((0, 0, -r * pav_h))
    bm.faces.new(tab)
    for i in range(segs):
        i2 = (i + 1) % segs
        bm.faces.new((gt[i], gt[i2], tab[i]))
        bm.faces.new((tab[(i - 1) % segs], gt[i], tab[i]))
        bm.faces.new((gb[i], gb[i2], gt[i2], gt[i]))
        bm.faces.new((gb[i2], gb[i], cul))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return L.obj_from_bm(name, bm, mat)


def ring(name, center, R, band_r, band_mat, gem_mat, gem_r, setting="solitaire"):
    """Ring standing upright in the x-z plane (seen face-on from the front), gem on top."""
    band = L.torus(f"{name}Band", R, band_r, (0, 0, 0), band_mat, 64, 12, minor_scale=(0.75, 1.25))
    band.rotation_euler = (math.pi / 2, 0, 0)
    band.location = center
    top = Vector(center) + Vector((0, 0, R + band_r * 0.6))
    if setting == "solitaire":
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            px, py = math.cos(a) * gem_r * 0.85, math.sin(a) * gem_r * 0.85
            L.cylinder(f"{name}Prong{k}", 0.0006, gem_r * 1.1, (top.x + px, top.y + py, top.z + gem_r * 0.45), band_mat, 8)
        L.cylinder(f"{name}Basket", gem_r * 0.55, gem_r * 0.6, (top.x, top.y, top.z + gem_r * 0.1), band_mat, 16,
                   r2=gem_r * 0.8)
        g = gem_mesh(f"{name}Gem", gem_r, gem_mat)
        g.location = (top.x, top.y, top.z + gem_r * 0.9)
    elif setting == "halo":
        g = gem_mesh(f"{name}Gem", gem_r, gem_mat)
        g.location = (top.x, top.y, top.z + gem_r * 0.85)
        L.torus(f"{name}Halo", gem_r * 1.25, gem_r * 0.28, (top.x, top.y, top.z + gem_r * 0.6), band_mat, 32, 8)
    elif setting == "band":
        L.torus(f"{name}Pave", R + band_r * 0.55, band_r * 0.45, (0, 0, 0), gem_mat, 64, 8).location = center
        bpy.data.objects[f"{name}Pave"].rotation_euler = (math.pi / 2, 0, 0)
        bpy.data.objects[f"{name}Pave"].scale = (1, 1, 0.6)


def build_ring_tray(st, m, cx, cy):
    """Ring tray tilted 16 deg toward the customer on a brass easel."""
    before = set(bpy.context.scene.objects)
    _ring_tray(st, m, cx, cy)
    piv = bpy.data.objects.new("RingTrayPivot", None)
    L.link(piv)
    piv.location = (cx, cy - 0.075, DECK)
    for ob in set(bpy.context.scene.objects) - before - {piv}:
        if ob.parent is None:
            ob.parent = piv
            ob.location = Vector(ob.location) - Vector(piv.location)
    piv.rotation_euler = (math.radians(16), 0, 0)
    tilt = math.radians(16)
    h = 0.15 * math.sin(tilt)
    for s in (-1, 1):
        L.box(f"Easel{s}", (0.012, 0.012, h + 0.004), (cx + s * 0.14, cy - 0.075 + 0.15 * math.cos(tilt) - 0.01, DECK + h / 2),
              m["brass"], 0.002, 2)


def _ring_tray(st, m, cx, cy):
    tw, td, th = 0.34, 0.15, 0.032
    zt = DECK + th
    L.box("RingTray", (tw, td, th), (cx, cy, DECK + th / 2), m["tray"], 0.006, 3)
    for k, y in enumerate((-0.035, 0.035)):
        L.box(f"RingSlot{k}", (tw - 0.03, 0.0035, 0.004), (cx, cy + y, zt - 0.0012), m["slot"])
    specs = [
        ("RingA", 0.0090, 0.0016, "gold", "diamond", 0.0042, "solitaire"),
        ("RingB", 0.0088, 0.0015, "white_gold", "sapphire", 0.0036, "halo"),
        ("RingC", 0.0092, 0.0019, "rose_gold", "diamond", 0.0, "band"),
        ("RingD", 0.0089, 0.0015, "white_gold", "diamond", 0.0050, "solitaire"),
        ("RingE", 0.0091, 0.0016, "gold", "ruby", 0.0038, "halo"),
    ]
    for i, (nm, R, br, mm, gm, gr, setting) in enumerate(specs):
        x = cx - 0.12 + i * 0.06
        # seated: lower ~40% of the band disappears into the front slot
        ring(nm, (x, cy - 0.035, zt + R * 0.25), R, br, m[mm], m[gm], gr, setting)
    # a second row: two loose rings lying on the tray's back slot
    for i, (mm, gm) in enumerate((("gold", "emerald"), ("white_gold", "diamond"))):
        x = cx - 0.05 + i * 0.1
        ring(f"RingBack{i}", (x, cy + 0.035, zt + 0.009 * 0.25), 0.0088, 0.0015, m[mm], m[gm], 0.0034, "solitaire")


def bust_profile():
    return [(0.0, 0.0), (0.074, 0.0), (0.078, 0.006), (0.076, 0.016), (0.07, 0.04), (0.062, 0.075),
            (0.05, 0.11), (0.036, 0.135), (0.025, 0.152), (0.0215, 0.168), (0.021, 0.20), (0.024, 0.212),
            (0.018, 0.216), (0.0, 0.217)]


def build_bust(st, m, name, cx, cy, height_scale, necklace):
    prof = [(r, z * height_scale) for r, z in bust_profile()]
    ysc = 0.58
    b = L.lathe(name, prof, m["velvet_black"], 64, (cx, cy, DECK), (1.0, ysc, 1.0))
    sub = b.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 2
    rs = np.array([p[0] for p in prof])
    zs = np.array([p[1] for p in prof])

    def r_at(z):
        # profile radius at height z (monotone decreasing in the region we use)
        idx = np.argsort(zs[1:-1]) + 1
        return float(np.interp(z, zs[idx], rs[idx]))

    def drape(z_back, drop, off, n=200, power=1.6):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            fr = (1 + math.cos(a)) / 2                   # 1 at the front, 0 at the back
            z = z_back - drop * fr ** power
            r = r_at(z) + off
            pts.append((cx + r * math.sin(a), cy - r * ysc * math.cos(a) - off * (1 - ysc) * math.cos(a), DECK + z))
        return pts
    if necklace == "pearls":
        pts = drape(0.16 * height_scale, 0.06 * height_scale, 0.0042, 400)
        # pearls spaced by diameter along the path
        pr = 0.0038
        acc = 0.0
        prev = None
        k = 0
        for p in pts:
            if prev is not None:
                acc += (Vector(p) - Vector(prev)).length
            prev = p
            if acc >= 2 * pr * 1.02 or k == 0:
                L.uvsphere(f"{name}Pearl{k}", pr, p, m["pearl"], 16, 8)
                k += 1
                acc = 0.0
        # second, shorter strand
        pts = drape(0.165 * height_scale, 0.035 * height_scale, 0.0032, 400)
        acc, prev = 0.0, None
        for p in pts:
            if prev is not None:
                acc += (Vector(p) - Vector(prev)).length
            prev = p
            if acc >= 2 * 0.0028 * 1.02:
                L.uvsphere(f"{name}PearlS{k}", 0.0028, p, m["pearl"], 12, 6)
                k += 1
                acc = 0.0
    else:
        pts = drape(0.16 * height_scale, 0.055 * height_scale, 0.0012, 300, 2.2)
        L.tube(f"{name}Chain", pts, 0.0009, m["gold"], cyclic=True, bevel_res=2)
        front = min(pts, key=lambda p: p[1])
        # pendant: bail + pear-shaped gem in a bezel
        L.torus(f"{name}Bail", 0.0025, 0.0007, (front[0], front[1] - 0.001, front[2] - 0.003), m["gold"], 16, 6,
                rot=(0, math.pi / 2, 0))
        g = gem_mesh(f"{name}Pendant", 0.0075, m["sapphire"], segs=16)
        _orient(g, (front[0], front[1] - 0.006, front[2] - 0.014), (0, -1, 0.45))
        L.torus(f"{name}Bezel", 0.0076, 0.0011, (0, 0, 0), m["gold"], 32, 6)
        _orient(bpy.data.objects[f"{name}Bezel"], (front[0], front[1] - 0.0055, front[2] - 0.014), (0, -1, 0.45))


def build_watch(st, m, name, cx, cy, yaw, strap, dial, case_mat):
    ry, rz, px = 0.03, 0.024, 0.072
    zc = DECK + rz
    # pillow: pill-shaped cushion along X (super-ellipsoid ends), elliptic cross-section
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        v.co = (math.copysign(abs(x) ** 0.28, x) * px / 2, y * ry, z * rz)
    pil = L.obj_from_bm(f"{name}Pillow", bm, m["velvet_black"], smooth=True)
    piv = bpy.data.objects.new(f"{name}Pivot", None)
    L.link(piv)
    piv.location = (cx, cy, zc)
    piv.rotation_euler = (0, 0, yaw)
    pil.parent = piv
    # strap: band around the cross-section ellipse
    n = 64
    sw = 0.020
    verts, faces = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        y, z = -(ry + 0.0018) * math.sin(a), (rz + 0.0018) * math.cos(a)
        verts += [(-sw / 2, y, z), (sw / 2, y, z)]
    for i in range(n):
        i2 = (i + 1) % n
        faces.append((2 * i, 2 * i2, 2 * i2 + 1, 2 * i + 1))
    sob = L.mesh_obj(f"{name}Strap", verts, faces, m[strap])
    sol = sob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.0028
    sol.offset = 1.0
    sob.parent = piv
    # case on the front-top of the pillow
    th = math.radians(38)
    cy_, cz_ = -(ry + 0.0046) * math.sin(th), (rz + 0.0046) * math.cos(th)
    nrm = Vector((0, -math.sin(th) * rz, math.cos(th) * ry)).normalized()
    case = bpy.data.objects.new(f"{name}Case", None)
    L.link(case)
    case.parent = piv
    M = Matrix.Translation((0, cy_, cz_)) @ nrm.to_track_quat("Z", "Y").to_matrix().to_4x4()
    case.matrix_basis = M
    parts = [
        L.cylinder(f"{name}Body", 0.0185, 0.009, (0, 0, 0.0005), m[case_mat], 64, bevel_w=0.0015, segments=3),
        L.torus(f"{name}BezelRing", 0.0172, 0.0016, (0, 0, 0.005), m[case_mat], 64, 10),
        L.cylinder(f"{name}Dial", 0.0162, 0.001, (0, 0, 0.0047), m[dial], 64),
        L.cylinder(f"{name}Crystal", 0.0165, 0.0016, (0, 0, 0.0062), m["glass"], 64, bevel_w=0.0006),
        L.cylinder(f"{name}Crown", 0.0024, 0.003, (0.0198, 0, 0.0005), m[case_mat], 16, rot=(0, math.pi / 2, 0)),
    ]
    for s in (-1, 1):
        for t in (-1, 1):
            parts.append(L.box(f"{name}Lug{s}{t}", (0.0028, 0.007, 0.0045), (s * 0.0085, t * 0.0195, 0.0), m[case_mat], 0.0008, 2))
    idx_mat = m["brass"] if dial != "dial_white" else m["dial_index_dark"]
    for k in range(12):
        a = 2 * math.pi * k / 12
        ln = 0.0034 if k % 3 == 0 else 0.002
        b = L.box(f"{name}Idx{k}", (0.0009, ln, 0.0006), (math.sin(a) * 0.0128, math.cos(a) * 0.0128, 0.0054), idx_mat)
        b.rotation_euler = (0, 0, -a)
        parts.append(b)
    for k, (ang, ln, wd) in enumerate(((math.radians(-50), 0.0095, 0.0011), (math.radians(60), 0.0135, 0.0008))):
        b = L.box(f"{name}Hand{k}", (wd, ln, 0.0004), (math.sin(ang) * ln * 0.42, math.cos(ang) * ln * 0.42, 0.0058 + k * 0.0004),
                  idx_mat)
        b.rotation_euler = (0, 0, -ang)
        parts.append(b)
    parts.append(L.cylinder(f"{name}Pin", 0.0009, 0.0012, (0, 0, 0.0064), idx_mat, 12))
    for pt in parts:
        pt.parent = case


# --------------------------------------------------------------------------- set

def build_set(st, m):
    L.box("Floor", (10, 10, 0.02), (0, 0, -0.01), m["floor"])
    L.box("BackWall", (10, 0.2, 4), (0, 2.4, 2.0), m["wall"])
    L.box("Wainscot", (10, 0.06, 1.0), (0, 2.27, 0.5), m["walnut"], 0.004)
    L.box("WainscotCap", (10, 0.09, 0.03), (0, 2.27, 1.0), m["brass"], 0.003)
    # neon diamond sign on the back wall, camera-left
    cx, cz = -0.75, 1.95
    pts = []
    for a in np.linspace(0, 2 * math.pi, 5):
        pts.append((cx + 0.32 * math.sin(a), 2.28, cz + 0.22 * math.cos(a) * (1.4 if math.cos(a) < 0 else 0.7)))
    L.tube("NeonDiamond", pts, 0.011, m["neon"])
    L.tube("NeonLine", [(cx - 0.45, 2.28, cz - 0.4), (cx + 0.45, 2.28, cz - 0.4)], 0.011, m["neon"])
    # pendant lamps above the counter (warm practicals)
    for i, x in enumerate((-0.35, 0.35)):
        L.lathe(f"Shade{i}", [(0.0, 0.0), (0.11, 0.0), (0.105, 0.012), (0.05, 0.11), (0.012, 0.13), (0.0, 0.13)],
                m["brass"], 48, (x, 0.05, 1.82))
        L.uvsphere(f"PendBulb{i}", 0.035, (x, 0.05, 1.83), m["bulb"], 24, 12)
        L.tube(f"PendCord{i}", [(x, 0.05, 1.95), (x, 0.05, 3.5)], 0.003, m["plinth"])
        li = bpy.data.lights.new(f"Pend{i}", "SPOT")
        li.energy = {"a_gsr": 40.0, "b_noir": 10.0, "c_photo": 35.0}[st["_id"]]
        li.color = L.kelvin(2700)
        li.spot_size = math.radians(80)
        li.spot_blend = 0.6
        li.shadow_soft_size = 0.03
        ob = bpy.data.objects.new(f"Pend{i}", li)
        L.link(ob)
        ob.location = (x, 0.05, 1.8)


# --------------------------------------------------------------------------- main

def main() -> None:
    args = L.parse_args(ASSET)
    st = dict(styles.get(args.style))
    st["_id"] = args.style
    L.reset()
    t0 = time.time()
    sid = args.style
    m = {
        "walnut": L.material("walnut_lacquer", st, PALETTE["walnut"], 0.32, kind="wood", coat=0.8, grain_dir="z"),
        "walnut_dark": L.material("walnut_lacquer_dark", st, "#4A2F20", 0.3, kind="wood", coat=0.9, grain_dir="x"),
        "plinth": L.material("lacquer_black", st, "#17151A", 0.25, kind="paint", coat=0.7),
        "brass": L.material("brass", st, PALETTE["brass"], 0.22, 1.0, kind="metal"),
        "glass": L.material("glass_case", st, (0.92, 0.96, 0.95), 0.0, kind="glass", transmission=1.0, ior=1.5),
        "velvet_deck": L.material("velvet_wine", st, "#3A0F1A", 0.9, kind="velvet", sheen=1.0),
        "velvet_black": L.material("velvet_black", st, "#1E1B20", 0.9, kind="velvet", sheen=1.0),
        "tray": L.material("leatherette_ivory", st, PALETTE["ivory"], 0.5, kind="fabric"),
        "slot": L.material("slot_shadow", st, "#141215", 0.9, kind="velvet"),
        "gold": L.material("gold_18k", st, "#E2B85A", 0.16, 1.0, kind="metal", wear_scale=0.3),
        "white_gold": L.material("white_gold", st, "#D9D9D6", 0.15, 1.0, kind="metal", wear_scale=0.3),
        "rose_gold": L.material("rose_gold", st, "#D99A82", 0.16, 1.0, kind="metal", wear_scale=0.3),
        "diamond": L.material("diamond", st, (1, 1, 1), 0.0, kind="gem", transmission=1.0, ior=2.42, dispersion=0.4),
        "sapphire": L.material("sapphire", st, (0.10, 0.22, 0.85), 0.0, kind="gem", transmission=1.0, ior=1.77),
        "ruby": L.material("ruby", st, (0.85, 0.05, 0.12), 0.0, kind="gem", transmission=1.0, ior=1.77),
        "emerald": L.material("emerald", st, (0.05, 0.7, 0.3), 0.0, kind="gem", transmission=1.0, ior=1.58),
        "pearl": L.material("pearl", st, "#E9E1D2", 0.22, kind="plastic", coat=0.6, sheen=0.4),
        "steel": L.material("steel_watch", st, "#B8BCC0", 0.2, 1.0, kind="metal"),
        "leather_brown": L.material("leather_brown", st, "#5C3A22", 0.55, kind="fabric"),
        "rubber_black": L.material("rubber_black", st, "#1C1C1E", 0.6, kind="plastic"),
        "dial_black": L.material("dial_black", st, "#141518", 0.25, kind="plastic"),
        "dial_white": L.material("dial_white", st, "#E3DFD6", 0.3, kind="plastic"),
        "dial_blue": L.material("dial_blue", st, "#1E3A6E", 0.2, 0.6, kind="metal"),
        "dial_index_dark": L.material("dial_index_dark", st, "#1A1A1C", 0.3, 0.8, kind="metal"),
        "floor": L.material("terrazzo_floor", st, "#6E655C", 0.35, kind="paint", coat=0.3),
        "wall": L.material("wall_ivory", st, PALETTE["ivory"], 0.85, kind="paint"),
        "led": L.emission_material("led_warm", L.kelvin(3000), 8.0),
        "neon": L.emission_material("neon_magenta", PALETTE["neon_magenta"], {"a_gsr": 10.0, "b_noir": 30.0, "c_photo": 12.0}[sid]),
        "bulb": L.emission_material("bulb_warm", L.kelvin(2400), {"a_gsr": 18.0, "b_noir": 8.0, "c_photo": 15.0}[sid]),
    }
    build_cabinet(st, m)
    build_case(st, m)
    build_ring_tray(st, m, 0.0, -0.12)
    build_bust(st, m, "BustA", -0.43, 0.07, 1.0, "pearls")
    build_bust(st, m, "BustB", -0.22, 0.12, 1.12, "chain")
    build_watch(st, m, "WatchA", 0.25, 0.06, math.radians(-8), "leather_brown", "dial_white", "gold")
    build_watch(st, m, "WatchB", 0.37, 0.10, math.radians(-4), "steel", "dial_blue", "steel")
    build_watch(st, m, "WatchC", 0.49, 0.06, math.radians(6), "rubber_black", "dial_black", "steel")
    build_set(st, m)
    target = Vector((0.02, 0.0, 0.70))
    cam_loc = (0.92, -1.62, 1.50)
    L.camera(cam_loc, target, 38.0, st)
    bpy.context.scene.camera.data.dof.focus_distance = (Vector(cam_loc) - Vector((0.0, -0.1, 0.8))).length
    L.light_rig(st, (0, 0, 0.8), cam_loc, 1.1, gain=0.45)
    L.world(st)
    L.setup_render(st, args)
    print(f"[counter] build {time.time() - t0:.1f}s, tris {L.tri_count(verbose=True)}")
    L.render(args, st)


if __name__ == "__main__":
    main()
