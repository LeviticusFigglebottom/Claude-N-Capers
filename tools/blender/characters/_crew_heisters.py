"""The four playable heisters (D2-03): Rook, Sable, Dutch and Wren. Blender only (via ``_outfit``).

The cast has no art brief beyond the names and the voice lines (``game/content/data/strings``), so
the looks are written from the voices. PD2 rule: the crew wear suits by default and each heister's
suit/kit is distinct in cut, colour, gloves and accessories, with one silhouette each that reads at
30 m. Everything is hat-free (the mask seats on ``Head/Socket`` at the face centre) and nothing rises
above the collar at the front, so every mask fits.

* **Rook** (calm, steady, the de facto lead: "Quiet's done. Work fast."): a man in his 40s, tall,
  mid skin tone, dark side-parted hair and stubble. Silhouette: the **long coat**, a charcoal
  single-breasted overcoat to mid-calf over a white shirt and black tie, an oxblood scarf hanging
  open under the lapels (+ pocket square), black leather gloves, black oxfords.
* **Sable** (dry, sardonic, elegant: "Well, that's subtle gone."): a slim woman in her 30s, deep
  skin, dark bob, chrome drop earrings. Silhouette: **slim and sharp**, a cropped aubergine blazer
  with strongly padded shoulders, a flared peplum hem and black satin lapels over a black roll-neck, narrow black trousers,
  heeled ankle boots, ivory kid gloves (the brightest hands in the crew).
* **Dutch** (big, loud, jovial bruiser: "Here we go. Loud and proud."): a heavy older man, the
  tallest and widest, fair skin, grey buzz cut and a full grey beard. Silhouette: the **bulky
  bomber**, a brown leather flight jacket with a big cream shearling collar, ribbed cuffs and
  waistband, zipped to mid-chest over a white shirt and black tie, suit trousers, brown work boots,
  tan gloves.
* **Wren** (young, quick, nervy: "Okay, plan B, plan B!"): a young woman, the smallest, light skin,
  short brown hair. Silhouette: **no jacket**, a fitted mustard waistcoat over a pale blue shirt with
  the sleeves rolled to the elbow (bare forearms), a loosened skinny teal tie, grey slacks, black
  black headphones round the neck, a brown leather messenger satchel on the left hip on a strap across
  the body (the asymmetric bump that tells her from Sable at 30 m), short black tactical gloves.
"""

from __future__ import annotations

import math

import _contact_gear as cg
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Hull, Mesh, Vector, clamp, lerp, smoothstep
from _outfit_build import Kit

UP = Vector((0.0, 0.0, 1.0))
TAU = 2.0 * math.pi

ROOK_COAT = "char_crew_rook_coat"
ROOK_SCARF = "char_crew_rook_scarf"
SABLE_BLAZER = "char_crew_sable_blazer"
IVORY = "char_crew_glove_ivory"
BOMBER = "char_crew_dutch_bomber"
SHEARLING = "char_crew_shearling"
TAN = "char_crew_glove_tan"
VEST = "char_crew_wren_vest"

#: What the first-person arms should wear per heister (sleeve, cuff/under-sleeve, glove). Recorded in
#: SOURCE.txt (``fp_sleeve``) for the per-heister FP arm variants (a later task).
FP_SLEEVES = {
    "rook": {"sleeve": ROOK_COAT, "cuff": "char_shirt_white", "glove": "char_leather_black"},
    "sable": {"sleeve": SABLE_BLAZER, "cuff": "char_knit_graphite", "glove": IVORY},
    "dutch": {"sleeve": BOMBER, "cuff": "char_knit_graphite", "glove": TAN},
    "wren": {"sleeve": "char_shirt_blue", "cuff": "bare forearm (skin), sleeve rolled to the elbow",
             "glove": "char_tac_glove"},
}


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _front_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


def _gloves(kit: Kit, mat: str, cuff_len: float = 0.045, cuff_off: float = 0.004) -> None:
    kit.add_soft(g.gloves(kit.fit, mat, cuff_len=cuff_len, cuff_off=cuff_off))


def _pocket_square(kit: Kit, mat: str, x: float = -0.095) -> None:
    k = kit.k
    pk = Mesh()
    o.patch(pk, kit.hull(), Vector((x * k, 0.0, 1.318 * k)), Vector((1, 0, 0)), UP,
            [(-0.034 * k, -0.006 * k), (0.034 * k, -0.006 * k), (0.030 * k, 0.014 * k), (0.014 * k, 0.024 * k),
             (-0.006 * k, 0.014 * k), (-0.028 * k, 0.022 * k)], 0.004 * k, mat,
            cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)


def _cull_under(kit: Kit, upto: int, cover: Mesh, key: str) -> None:
    """Drop faces of the layers under ``cover`` that it hides completely (tri budget)."""
    kit.notes[key] = str(sg.cull_hidden(kit.soft, upto, Hull(kit.fit, [cover], body_regions=set())))


# =============================================================================================
# Rook: the long coat
# =============================================================================================
def scarf(kit: Kit, mat: str, tail_z: float, x: float = 0.045, half_w: float = 0.028) -> None:
    """An open scarf: round the back of the neck over the collar, both ends hanging straight down
    the shirt front either side of the tie."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    m = Mesh()
    path: list[Vector] = []
    # left end (x < 0): bottom up
    rows = 9
    for i in range(rows):
        z = lerp(tail_z, neck_z - 0.04 * k, i / (rows - 1))
        path.append(_front_hit(hull, -x * k * lerp(1.0, 1.35, i / (rows - 1)), z, cy + 0.12 * k))
    # round the back of the neck (theta -0.75 .. -pi .. +0.75), narrower and high on the collar so
    # it shows above the coat collar instead of fighting it
    for i in range(1, 16):
        th = -0.75 - (TAU - 1.5) * i / 16
        path.append(nk.point(th, 0.32, 0.016 * k))
    for i in range(rows):
        z = lerp(neck_z - 0.04 * k, tail_z - 0.02 * k, i / (rows - 1))
        path.append(_front_hit(hull, x * k * lerp(1.35, 1.0, i / (rows - 1)), z, cy + 0.12 * k))
    n_all = len(path)

    def hw(t: float) -> float:
        i = t * (n_all - 1)
        edge = min(i, n_all - 1 - i)          # path points from the nearer tail end
        return k * lerp(0.013, half_w, smoothstep(rows + 1.0, rows - 3.0, edge))

    o.strip(m, hull, path, hw, 0.006 * k, mat, segs_across=2, chamfer=0.003 * k, cast_back=0.04)
    kit.add_soft(m)


def rook(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.056)
    n.trousers(kit, "char_suit_dark", sh, belt_z + 0.022 * k)
    n.tie(kit, "char_tie_black", belt_z + 0.03 * k, width=0.072)
    scarf(kit, ROOK_SCARF, 1.02 * k)
    _gloves(kit, "char_leather_black", cuff_len=0.05)
    n0 = len(kit.soft.f)
    coat, _info = n.jacket(kit, ROOK_COAT, 0.40 * k, 0.98 * k, neck_w=0.100, lapel_w=0.078, flare=0.14,
                           base=0.015, open_below=0.06, sleeve=1.93)
    jh = Hull(fit, [coat])
    btn = Mesh()
    for dz in (0.13, 0.26):
        btn.extend(gk.button(jh, Vector((0.012 * k, 0.3, 0.98 * k - 0.012 * k - dz * k)), "char_button_dark",
                             r=0.010, k=k, thick=0.004))
    kit.add_gear(btn)
    _pocket_square(kit, ROOK_SCARF, x=-0.10)
    _cull_under(kit, n0, coat, "faces_hidden_by_coat")
    kit.notes["look"] = ("Rook: long charcoal overcoat (mid-calf) over white shirt + black tie, open oxblood "
                         "scarf, black gloves")


# =============================================================================================
# Sable: the cropped blazer
# =============================================================================================
def sable(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, _tuck = _z(kit)
    boots = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.13, base=0.005, toe=0.016, heel=0.032,
                    boot=True)
    kit.add_soft(boots)
    knit = g.knit_top(fit, kit.hull(), "char_knit_graphite", belt_z - 0.01 * k, neck="roll", base=0.005)
    kit.add_soft(knit)
    n.trousers(kit, "char_trousers_black", boots, belt_z + 0.022 * k, hem_r=0.048)
    _gloves(kit, IVORY, cuff_len=0.07, cuff_off=0.003)
    n0 = len(kit.soft.f)
    bz = 1.03 * k
    jk, _info = g.jacket(fit, kit.hull(), SABLE_BLAZER, 0.88 * k, bz, neck_w=0.068, base=0.009, flare=0.16,
                         lapel_w=0.050, lapel_mat="char_satin_black", collar_mat="char_satin_black",
                         shoulder_pad=0.024, sleeve=1.90, open_below=0.06, keep_shape=0.5)
    kit.add_soft(jk)
    jh = Hull(fit, [jk])
    kit.add_gear(gk.button(jh, Vector((0.010 * k, 0.3, bz - 0.012 * k)), "char_satin_black", r=0.010, k=k,
                           thick=0.004))
    pk = Mesh()
    for sx in (-1.0, 1.0):
        o.patch(pk, jh, Vector((sx * 0.10 * k, 0.0, 0.95 * k)), Vector((1, 0, 0)), UP,
                o.rounded_rect(0.12 * k, 0.014 * k, 0.003 * k, 1), 0.0025 * k, "char_satin_black",
                cast_dir=Vector((0.25 * sx, -1, 0)), rings=1, chamfer=0.0015 * k)
    kit.add_soft(pk)
    _cull_under(kit, n0, jk, "faces_hidden_by_blazer")
    kit.add_head(cg.earrings(fit, "chrome"))
    kit.notes["look"] = ("Sable: cropped aubergine blazer, sharp shoulders, black satin lapels, black roll-neck, "
                         "narrow trousers, heeled ankle boots, ivory gloves")


# =============================================================================================
# Dutch: the bomber
# =============================================================================================
def bomber(kit: Kit, mat: str, rib_mat: str, collar_mat: str, bottom_z: float, v_z: float,
           neck_w: float = 0.075) -> Mesh:
    """Leather flight jacket: a roomy torso + sleeve shell bloused over a ribbed waistband and cuffs,
    zipped up to ``v_z`` (open V above it, the shirt collar and tie show) with a thick turned-down
    shearling collar round the V and the back of the neck."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()

    def extra(p: Vector, r: str) -> float:
        if r in ("torso", "pelvis", "neck"):
            return 0.006 * k * smoothstep(bottom_z + 0.02 * k, bottom_z + 0.14 * k, p.z) \
                * smoothstep(1.50 * k, 1.36 * k, p.z) + 0.003 * k
        return 0.006 * k

    sh = g.upper_shell(fit, mat, bottom_z=bottom_z, sleeve=1.88, base=0.014, waist_blouse=0.012, arm_ease=2.2,
                       hull=hull, iters=6, min_off=0.007 * k, extra=extra)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
    mh = Hull(fit, [m])
    g.cuff_band(m, loops["hem"], mh, 0.065 * k, 0.004 * k, rib_mat)
    for key in ("cuff.L", "cuff.R"):
        g.cuff_band(m, loops[key], mh, 0.06 * k, 0.004 * k, rib_mat)
    # open V above the zip
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def v_half(z: float) -> float:
        t = clamp((z - v_z) / max(neck_z - v_z, 1e-3), 0.0, 1.0)
        return lerp(0.004 * k, neck_w * k, t ** 0.9)

    g.delete_faces(m, lambda c: c.y > cy and c.z >= v_z and abs(c.x) < v_half(c.z) and c.z < neck_z + 0.08)
    g.snap_opening(m, v_half, cy, v_z, neck_z + 0.02, hull, 0.005 * k)
    o.hem_all(m, thick=0.006 * k, depth=0.016 * k)
    kit.add_soft(m)
    bh = Hull(fit, [m])
    # zip from the V point down to the waistband
    zp = Mesh()
    path = g.front_path(bh, 0.0, v_z + 0.004 * k, bottom_z - 0.05 * k, step=0.02 * k)
    o.strip(zp, bh, path, 0.006 * k, 0.0025 * k, "chrome", segs_across=1, chamfer=0.001 * k)
    kit.add_gear(zp)
    pull = o.Gear()
    pull.box((-0.006 * k, -0.016 * k, 0.0), (0.006 * k, 0.004 * k, 0.004 * k), "chrome")
    pull.bevel(0.0015 * k, 1, 30.0)
    pp = _front_hit(bh, 0.0, v_z - 0.006 * k, cy + 0.15 * k)
    kit.add_gear(pull.to_mesh(o.frame_from(pp, Vector((0.0, 1.0, 0.1))), anchor=pp))
    # shearling collar: wide lapels up the V edges and a turned-down band round the back
    col = Mesh()
    rows = 9
    for sx in (-1.0, 1.0):
        pts = []
        for i in range(rows):
            t = i / (rows - 1)
            z = lerp(v_z + 0.006 * k, neck_z - 0.004 * k, t)
            w = lerp(0.016, 0.042, smoothstep(0.0, 0.8, t)) * k
            pts.append(_front_hit(bh, sx * (v_half(z) + w * 1.1), z, cy + 0.12 * k))
        o.strip(col, bh, pts, lambda t: lerp(0.016, 0.042, smoothstep(0.0, 0.8, t)) * k, 0.012 * k, collar_mat,
                side_hint=Vector((sx, 0, 0)), segs_across=2, chamfer=0.005 * k)
    back = [nk.point(th, 0.0, 0.028 * k) - Vector((0.0, 0.0, 0.012 * k))
            for th in [lerp(0.62, TAU - 0.62, i / 20) for i in range(21)]]
    o.strip(col, kit.hull(), back, 0.042 * k, 0.012 * k, collar_mat, side_hint=UP, segs_across=2,
            chamfer=0.005 * k, cast_back=0.06)
    kit.add_soft(col)
    # patch pockets with snap flaps on the front
    bh = kit.hull()
    pk = Mesh()
    for sx in (-1.0, 1.0):
        o.patch(pk, bh, Vector((sx * 0.105 * k, 0.0, bottom_z + 0.11 * k)), Vector((1, 0, 0)), UP,
                o.rounded_rect(0.13 * k, 0.05 * k, 0.008 * k, 2), 0.004 * k, mat,
                cast_dir=Vector((0.3 * sx, -1, 0)), rings=2, chamfer=0.003 * k)
    kit.add_soft(pk)
    return m


def dutch(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    boots = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(boots)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.058)
    n.trousers(kit, "char_suit_dark", boots, belt_z + 0.022 * k, hem_r=0.064)
    n.tie(kit, "char_tie_black", belt_z + 0.03 * k, width=0.08)
    _gloves(kit, TAN, cuff_len=0.05, cuff_off=0.005)
    n0 = len(kit.soft.f)
    jk = bomber(kit, BOMBER, "char_knit_graphite", SHEARLING, hips_z - 0.02 * k, 1.27 * k)
    _cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    kit.notes["look"] = ("Dutch: brown leather bomber, cream shearling collar, ribbed waist/cuffs, zipped to "
                         "mid-chest over shirt + black tie, suit trousers, brown boots, tan gloves, full beard")


# =============================================================================================
# Wren: waistcoat and rolled sleeves
# =============================================================================================
def rolled_shirt(kit: Kit, mat: str, tuck_z: float, sleeve: float = 1.25) -> Mesh:
    """Shirt with the sleeves rolled to just below the elbow: a thick turned-up roll at each end."""
    fit, k = kit.fit, kit.k
    sh = g.upper_shell(fit, mat, bottom_z=tuck_z, sleeve=sleeve, base=0.0055, hull=kit.hull(), arm_ease=1.6)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], tuck_z)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
        g.cuff_band(m, loops[key], mh, 0.06 * k, 0.007 * k, mat)
    g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), mat, point_len=0.054, spread=0.30)
    o.hem_all(m, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(m)
    return m


def loose_tie(kit: Kit, mat: str, z_tip: float, width: float = 0.052, drop: float = 0.045) -> None:
    """Skinny tie pulled loose: the knot sits ``drop`` below the collar."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    det = Mesh()
    knot = g.tie(det, kit.hull(), fit, nk.point(0.0, 0.0, 0.0).z - (0.035 + drop) * k, z_tip, mat, width=width)
    kit.add_soft(det)
    tk = o.Gear()
    tk.prism([(0.012 * k, 0.013 * k), (-0.012 * k, 0.013 * k), (-0.008 * k, -0.016 * k), (0.008 * k, -0.016 * k)],
             0.0, 0.014 * k, mat)
    tk.bevel(0.0035 * k, 2, 30.0)
    kp = knot + Vector((0.0, 0.004 * k, 0.010 * k))   # knot overlaps the blade top (no collar over it)
    kit.add_gear(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))


def headphones(kit: Kit, mat: str = "polymer_black", pad_mat: str = "rubber_black") -> None:
    """Over-ear headphones worn round the neck: the band behind the neck, the cups resting on the
    collarbones either side of the collar (below the jaw, clear of the mask)."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    band = Mesh()
    ths = [lerp(1.05, TAU - 1.05, i / 18) for i in range(19)]
    path = [o.push_out(nk.point(th, 0.12, 0.034 * k), hull, 0.010 * k) for th in ths]
    o.tube(band, path, 0.0075 * k, mat, sides=8)
    kit.add_gear(band, layer=False)
    for sx in (-1.0, 1.0):
        th = sx * 1.05
        base = nk.point(th, 0.0, 0.050 * k) + Vector((0.0, 0.006 * k, -0.026 * k))
        rad = nk.radial(th)
        axis = (rad * 0.55 + UP * 0.45 + Vector((0.0, 0.35, 0.0))).normalized()
        p = o.push_out(base, hull, 0.020 * k)
        cup = o.Gear()
        cup.cyl(0.036 * k, 0.026 * k, centre=(0.0, 0.0, 0.0), axis="Z", segs=16, mat=mat)
        cup.cyl(0.031 * k, 0.012 * k, centre=(0.0, 0.0, -0.018 * k), axis="Z", segs=16, mat=pad_mat)
        cup.bevel(0.003 * k, 1, 30.0)
        kit.add_gear(cup.to_mesh(o.frame_from(p, axis), anchor=p), layer=False)


def satchel(kit: Kit, mat: str, strap_mat: str, a_deg: float = -125.0, z: float = 0.97) -> None:
    """Messenger bag on the left hip, behind the side seam (clear of the right-hip ``Hip`` seat and
    the ``Back`` bag seat), on a strap across the body from the right shoulder."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    hips = fit.ring_centre("hips")
    zb = z * k
    a = math.radians(a_deg)
    r = hull.outer_radius(zb, a, hips.x, hips.y)
    out = Vector((math.sin(a), math.cos(a), 0.0))
    p = Vector((hips.x, hips.y, zb)) + out * (r + 0.004 * k)
    w, h, d = 0.115 * k, 0.085 * k, 0.065 * k
    bag = o.Gear()
    bag.box((-w, -h, 0.0), (w, h, d), mat)
    bag.bevel(0.012 * k, 2, 30.0)
    flap = o.Gear()
    flap.box((-w - 0.004 * k, -0.02 * k, d - 0.002 * k), (w + 0.004 * k, h + 0.006 * k, d + 0.006 * k), mat)
    flap.bevel(0.003 * k, 1, 30.0)
    flap.box((-0.012 * k, -0.035 * k, d + 0.004 * k), (0.012 * k, -0.012 * k, d + 0.009 * k), "chrome")
    mtx = o.frame_from(p, out)
    kit.add_gear(bag.to_mesh(mtx, anchor=p), layer=False)
    kit.add_gear(flap.to_mesh(mtx, anchor=p), layer=False)
    # strap: from the bag's top corners over the right shoulder, front and back
    cy = fit.ring_centre("chest").y
    sh_r = Vector(fit.J["shoulder.R"])
    top = p + Vector((0.0, 0.0, h * 0.95))
    pts: list[Vector] = []
    steps = 10
    front0 = Vector((top.x + 0.02 * k, 0.0, top.z))
    for i in range(steps + 1):
        t = i / steps
        x = lerp(front0.x, sh_r.x - 0.03 * k, t)
        zz = lerp(front0.z, sh_r.z + 0.02 * k, t)
        pts.append(_front_hit(hull, x, zz, cy + 0.12 * k))
    for i in range(1, 4):
        yy = lerp(cy + 0.06 * k, cy - 0.06 * k, i / 4)
        hit = hull.cast(Vector((sh_r.x - 0.03 * k, yy, sh_r.z + 0.5)), Vector((0, 0, -1)), 1.0)
        pts.append(hit[0] if hit[0] is not None else Vector((sh_r.x - 0.03 * k, yy, sh_r.z + 0.06 * k)))
    for i in range(steps + 1):
        t = i / steps
        x = lerp(sh_r.x - 0.03 * k, top.x + 0.04 * k, t)
        zz = lerp(sh_r.z + 0.02 * k, top.z, t)
        hit = hull.cast(Vector((x, -0.6, zz)), Vector((0, 1, 0)), 1.2)
        pts.append(hit[0] if hit[0] is not None else Vector((x, cy - 0.15 * k, zz)))
    m = Mesh()
    o.strip(m, hull, pts, 0.017 * k, 0.004 * k, strap_mat, segs_across=1, chamfer=0.002 * k)
    kit.add_soft(m)


def wren(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    rolled_shirt(kit, "char_shirt_blue", tuck)
    n.trousers(kit, "char_slacks_grey", sh, belt_z + 0.022 * k, hem_r=0.054)
    loose_tie(kit, "char_satin_teal", belt_z + 0.05 * k)
    _gloves(kit, "char_tac_glove", cuff_len=0.03, cuff_off=0.004)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, VEST, hips_z - 0.015 * k, 1.11 * k, point=0.045, neck_w=0.066, buttons=5,
                       button_mat="char_button_dark")
    _cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    headphones(kit)
    satchel(kit, "char_apron_leather", "char_apron_leather")
    kit.notes["look"] = ("Wren: no jacket; fitted mustard waistcoat, pale blue shirt with rolled sleeves, loose "
                         "skinny teal tie, grey slacks, headphones round the neck, messenger satchel on the "
                         "left hip, short tactical gloves")


LOOKS = {"rook": rook, "sable": sable, "dutch": dutch, "wren": wren}
