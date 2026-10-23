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

import itertools
import math

import _body as body
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
PARKA = "char_crew_marten_parka"
FUR = "char_crew_marten_fur"
ORANGE = "char_crew_glove_orange"
COBALT = "char_crew_jay_jacket"
STRIPE = "char_crew_jay_stripe"
DRIVING = "char_crew_glove_driving"
MOTO = "char_crew_juno_jacket"
SUEDE = "char_crew_glove_suede"
CHORE = "char_crew_hale_jacket"
WORK = "char_crew_glove_work"

#: What the first-person arms should wear per heister (sleeve, cuff/under-sleeve, glove). Recorded in
#: SOURCE.txt (``fp_sleeve``) for the per-heister FP arm variants (a later task).
FP_SLEEVES = {
    "rook": {"sleeve": ROOK_COAT, "cuff": "char_shirt_white", "glove": "char_leather_black"},
    "sable": {"sleeve": SABLE_BLAZER, "cuff": "char_knit_graphite", "glove": IVORY},
    "dutch": {"sleeve": BOMBER, "cuff": "char_knit_graphite", "glove": TAN},
    "wren": {"sleeve": "char_shirt_blue", "cuff": "bare forearm (skin), sleeve rolled to the elbow",
             "glove": "char_crew_glove_sage"},
    "marten": {"sleeve": PARKA, "cuff": PARKA, "glove": ORANGE},
    "jay": {"sleeve": COBALT + " with two " + STRIPE + " stripes", "cuff": COBALT, "glove": DRIVING},
    "juno": {"sleeve": MOTO, "cuff": MOTO + " with a chrome cuff zip", "glove": SUEDE},
    "hale": {"sleeve": CHORE, "cuff": CHORE, "glove": WORK},
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


def _pocket_square(kit: Kit, mat: str, jacket: Hull, x: float = -0.112, z: float = 1.311,
                  half_w: float = 0.026) -> None:
    """A crisp two-peak ("crown") folded pocket square in the breast pocket, at (``x``, ``z``) on the
    jacket's outer chest (``jacket``: its hull; straight-on ray, clear of the lapel): two layered,
    bevelled cloth points, the taller one behind, their bases sunk into the cloth, leaning a little
    off the chest."""
    k = kit.k
    d = Vector((0.0, -1.0, 0.0))
    hit = jacket.cast(Vector((x * k, 0.5, z * k)), d, 1.0)
    if hit[0] is None:
        return
    nrm = hit[1] if hit[1].dot(d) < 0 else -hit[1]
    p = hit[0]
    mtx = o.frame_from(p, (nrm - UP * 0.22).normalized())
    w = half_w * k / 0.031
    back = [(-0.031 * w, -0.014 * k), (0.007 * w, -0.014 * k), (0.005 * w, 0.004 * k), (-0.012 * w, 0.028 * k),
            (-0.029 * w, 0.006 * k)]
    front = [(-0.006 * w, -0.014 * k), (0.031 * w, -0.014 * k), (0.029 * w, 0.004 * k), (0.014 * w, 0.021 * k),
             (-0.004 * w, 0.006 * k)]
    sq = o.Gear()
    sq.prism(back, -0.0030 * k, 0.0004 * k, mat)
    sq.bevel(0.0007 * k, 1, 30.0)
    sq.prism(front, -0.0012 * k, 0.0016 * k, mat)
    sq.bevel(0.0007 * k, 1, 30.0)
    kit.add_gear(sq.to_mesh(mtx, anchor=p))


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
    _pocket_square(kit, ROOK_SCARF, jh)
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
           neck_w: float = 0.075, collar: bool = True) -> Mesh:
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
    if not collar:          # Marten's parka: the lowered hood takes its place
        _bomber_pockets(kit, mat, bottom_z)
        return m
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
    _bomber_pockets(kit, mat, bottom_z)
    return m


def _bomber_pockets(kit: Kit, mat: str, bottom_z: float) -> None:
    """Patch pockets with snap flaps on the front."""
    k = kit.k
    bh = kit.hull()
    pk = Mesh()
    for sx in (-1.0, 1.0):
        o.patch(pk, bh, Vector((sx * 0.105 * k, 0.0, bottom_z + 0.11 * k)), Vector((1, 0, 0)), UP,
                o.rounded_rect(0.13 * k, 0.05 * k, 0.008 * k, 2), 0.004 * k, mat,
                cast_dir=Vector((0.3 * sx, -1, 0)), rings=2, chamfer=0.003 * k)
    kit.add_soft(pk)


#: Upper edge of Dutch's full beard, head-local (|x|, z) (``_body.HEAD_CENTRE`` frame, before height
#: scaling): just under the lower lip at the front, round the mouth corners into the moustache, then
#: the cheek line of ``_body._beard_top`` up the sideburn to the ear.
BEARD_TOP = ((0.0, -0.0700), (0.012, -0.0690), (0.019, -0.0665), (0.025, -0.0600), (0.030, -0.0520),
             (0.036, -0.0440), (0.042, -0.0370), (0.050, -0.0290), (0.058, -0.0150), (0.064, 0.0000),
             (0.080, 0.0060))


def _beard_line(ax: float) -> float:
    for (x0, z0), (x1, z1) in itertools.pairwise(BEARD_TOP):
        if ax <= x1:
            return lerp(z0, z1, smoothstep(x0, x1, ax))
    return BEARD_TOP[-1][1]


def full_beard(fit, mat: str, az_max: float = 94.0, n_az: int = 84, n_el: int = 16, full: float = 0.011,
               side: float = 0.0045, clumps: int = 15) -> Mesh:
    """A sculpted full beard (cheeks, jaw, chin and under the chin; the moustache is separate) as a
    shell over the face, on rays from a point inside the lower head (``C``): ``n_az`` columns from
    sideburn to sideburn (+-``az_max`` deg from the front) and ``n_el`` rows from the upper edge
    (``BEARD_TOP``) down under the jaw to the throat. The radii are smoothed over the grid (the head
    is low poly, the beard should not copy its facets); the thickness runs from ~1 mm at the edges
    to ``full`` at the chin and ``side`` on the cheeks; strand clumps are cut as grooves between the
    columns (``cg._sweep_clump``), so the beard reads as combed-down hair. 100 % ``head``."""
    from mathutils.bvhtree import BVHTree

    k = fit.k
    hc = Vector(body.HEAD_CENTRE)
    c = Vector((0.0, hc.y + 0.000, hc.z - 0.045)) * k
    # rays hit the face skin (no ears, eyes, brows), the neck and the hair cap
    verts = [tuple(v) for v in fit.P]
    faces = [f for f, r, sd in zip(fit.F, fit.FR, fit.FS) if (r == "head" and sd == 0) or r == "neck"]
    off = len(verts)
    verts += [tuple(v) for v in fit.hair_verts]
    faces += [tuple(i + off for i in f) for f in fit.hair_faces]
    bvh = BVHTree.FromPolygons(verts, faces)

    def dirv(az: float, el: float) -> Vector:
        return Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))

    def radius(d: Vector) -> float:
        hit = bvh.ray_cast(c + d * 0.3 * k, -d, 0.3 * k)
        return (hit[0] - c).length if hit[0] is not None else 0.08 * k

    def above_line(az: float, el: float) -> bool:
        d = dirv(az, el)
        p = c + d * radius(d)
        q = p / k - hc
        return q.z > _beard_line(abs(q.x))

    amax = math.radians(az_max)
    azs = [lerp(-amax, amax, j / (n_az - 1)) for j in range(n_az)]
    tops, bots = [], []
    for az in azs:
        lo, hi = math.radians(-50.0), math.radians(60.0)       # lo below the line, hi above it
        for _ in range(26):
            mid = 0.5 * (lo + hi)
            lo, hi = (lo, mid) if above_line(az, mid) else (mid, hi)
        tops.append(lo)
        f = smoothstep(0.0, math.radians(90.0), abs(az))
        bots.append(math.radians(lerp(-62.0, -26.0, f)))
    tops = _smooth_line(tops, 2)
    for j in range(n_az):                                       # clumps break the cheek line up a little
        _g, bulge = cg._sweep_clump(clumps, j / (n_az - 1), salt=7)
        tops[j] += math.radians(1.6) * (bulge - 0.4) * smoothstep(0.1, 0.4, abs(azs[j]) / amax)
    rad = []
    for j, az in enumerate(azs):
        col = []
        for i in range(n_el):
            el = lerp(tops[j], bots[j], i / (n_el - 1))
            col.append(radius(dirv(az, el)))
        rad.append(col)
    for _ in range(4):                                          # relax the radii over the grid
        new = [col[:] for col in rad]
        for j in range(n_az):
            for i in range(n_el):
                nb = [rad[jj][ii] for jj, ii in ((j - 1, i), (j + 1, i), (j, i - 1), (j, i + 1))
                      if 0 <= jj < n_az and 0 <= ii < n_el]
                new[j][i] = max(rad[j][i], 0.5 * rad[j][i] + 0.5 * sum(nb) / len(nb))
        rad = new
    m = Mesh()
    ids = []
    for j, az in enumerate(azs):
        u = abs(az) / amax
        groove, bulge = cg._sweep_clump(clumps, j / (n_az - 1), salt=7)
        thick_c = lerp(full, side, smoothstep(0.15, 0.75, u)) * k
        back = smoothstep(1.0, 0.86, u)                        # thin back edge in front of the ear
        col_ids = []
        for i in range(n_el):
            s = i / (n_el - 1)
            el = lerp(tops[j], bots[j], s)
            d = dirv(az, el)
            edge = smoothstep(0.0, 0.45, s) * smoothstep(1.0, 0.80, s) * lerp(0.12, 1.0, back)
            th = 0.0008 * k + thick_c * edge * (1.0 + 0.10 * bulge)
            th *= 1.0 - lerp(0.38, 0.22, smoothstep(0.2, 0.7, u)) * groove * smoothstep(0.08, 0.35, s)
            col_ids.append(m.add(c + d * (rad[j][i] + th), dict(cg.HEAD_W)))
        ids.append(col_ids)
    for j in range(n_az - 1):
        for i in range(n_el - 1):
            m.face((ids[j][i], ids[j + 1][i], ids[j + 1][i + 1], ids[j][i + 1]), mat, inside=c)
    # strand UVs (``cg.apply_strand_uvs``): u across the strands along the middle row, v down them
    mid = n_el // 2
    across = [0.0]
    for j in range(1, n_az):
        across.append(across[-1] + (m.v[ids[j][mid]] - m.v[ids[j - 1][mid]]).length)
    uvs = []
    for j in range(n_az):
        down = 0.0
        for i in range(n_el):
            down += (m.v[ids[j][i]] - m.v[ids[j][i - 1]]).length if i else 0.0
            uvs.append((across[j] * cg.STRAND_U_PER_M, down * cg.STRAND_V_PER_M))
    m.strand_uv = (uvs, None)
    return m


def _smooth_line(vals: list[float], iters: int) -> list[float]:
    for _ in range(iters):
        vals = [vals[0]] + [0.25 * vals[i - 1] + 0.5 * vals[i] + 0.25 * vals[i + 1]
                            for i in range(1, len(vals) - 1)] + [vals[-1]]
    return vals


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
    hair = f"char_hair_{fit.params['hair_color']}"
    cg.head_piece(kit, full_beard(fit, hair))
    kit.add_head(cg.moustache(fit, hair, z_off=-0.065, half_w=0.037, thick=0.0068, sides=12))
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
    _gloves(kit, "char_crew_glove_sage", cuff_len=0.03, cuff_off=0.004)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, VEST, hips_z - 0.015 * k, 1.11 * k, point=0.045, neck_w=0.066, buttons=5,
                       button_mat="char_button_dark")
    _cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    headphones(kit)
    satchel(kit, "char_apron_leather", "char_apron_leather")
    kit.notes["look"] = ("Wren: no jacket; fitted mustard waistcoat, pale blue shirt with rolled sleeves, loose "
                         "skinny teal tie, grey slacks, headphones round the neck, messenger satchel on the "
                         "left hip, short tactical gloves")


# =============================================================================================
# Marten (D-111): the field parka
# =============================================================================================
def marten(kit: Kit) -> None:
    """A hip-length olive field parka zipped to the throat over a black roll-neck, the fur-trimmed hood
    down behind the neck, big cargo pockets, dark trousers, black boots, burnt-orange gloves."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    boots = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.16, base=0.007, boot=True)
    kit.add_soft(boots)
    knit = g.knit_top(fit, kit.hull(), "char_knit_graphite", belt_z - 0.01 * k, neck="roll", base=0.006)
    kit.add_soft(knit)
    n.trousers(kit, "char_tac_charcoal", boots, belt_z + 0.022 * k, hem_r=0.062)
    _gloves(kit, ORANGE, cuff_len=0.05, cuff_off=0.005)
    n0 = len(kit.soft.f)
    pk = bomber(kit, PARKA, PARKA, FUR, hips_z - 0.15 * k, 1.42 * k, neck_w=0.040, collar=False)
    _cull_under(kit, n0, pk, "faces_hidden_by_parka")
    n.hood_down(kit, PARKA)
    _fur_trim(kit)
    kit.notes["look"] = ("Marten: hip-length olive field parka zipped high, fur-trimmed hood down behind the neck, "
                         "cargo pockets, black roll-neck, charcoal trousers, black boots, burnt-orange gloves")


def _fur_trim(kit: Kit) -> None:
    """A thick fur ruff along the edge of the lowered hood, round the back of the neck."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    m = Mesh()
    ths = [lerp(0.70, TAU - 0.70, i / 22) for i in range(23)]
    path = [nk.point(th, 0.0, 0.060 * k) - Vector((0.0, 0.0, 0.004 * k)) for th in ths]
    o.strip(m, kit.hull(), path, lambda t: k * lerp(0.010, 0.020, math.sin(math.pi * t) ** 0.6), 0.016 * k, FUR,
            side_hint=UP, segs_across=3, chamfer=0.007 * k, cast_back=0.08)
    kit.add_soft(m)


# =============================================================================================
# Jay (D-111): the racing jacket
# =============================================================================================
#: Rest-pose arm line (humanoid space at 1.78 m, |x|): shoulder joint, elbow, wrist.
_ARM = ((0.175, -0.018, 1.432), (0.380, -0.018, 1.227), (0.559, 0.009, 1.048))
#: The two sleeve stripes: bands of angle (deg) round the arm, measured from its outer-top direction.
_STRIPES = ((-26.0, -12.0), (12.0, 26.0))


def _stripe_mat(k: float):
    import numpy as np  # noqa: PLC0415

    sh, el, wr = (np.array(p, float) * k for p in _ARM)

    def mat(p: Vector, r: str) -> str:
        if r not in ("arms", "upper_arms", "forearms", "hands") and abs(p.x) < sh[0] + 0.02 * k:
            return COBALT
        q = np.array((abs(p.x), p.y, p.z), float)
        a, b = (sh, el) if q[0] < el[0] else (el, wr)
        axis = (b - a) / np.linalg.norm(b - a)
        d = q - a - axis * float(np.dot(q - a, axis))
        if np.linalg.norm(d) < 1e-6:
            return COBALT
        d /= np.linalg.norm(d)
        up_out = np.cross(axis, np.array((0.0, 1.0, 0.0)))   # perpendicular to the arm, in the frontal plane
        if up_out[2] < 0:
            up_out = -up_out
        fwd = np.cross(up_out, axis)
        ang = math.degrees(math.atan2(float(np.dot(d, fwd)), float(np.dot(d, up_out))))
        return STRIPE if any(lo <= ang <= hi for lo, hi in _STRIPES) else COBALT
    return mat


def racing_jacket(kit: Kit, bottom_z: float) -> Mesh:
    """A slim, short nylon racing jacket: a fitted shell to the waist with a ribbed hem and cuffs in the
    shell colour, a high band collar, a full-length zip, and two white stripes down the outside of each
    sleeve from the shoulder to the cuff."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, _stripe_mat(k), bottom_z=bottom_z, sleeve=1.92, base=0.008, waist_blouse=0.004,
                       hull=hull, iters=6, min_off=0.004 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
    mh = Hull(fit, [m])
    g.cuff_band(m, loops["hem"], mh, 0.040 * k, 0.003 * k, COBALT)
    for key in ("cuff.L", "cuff.R"):
        g.cuff_band(m, loops[key], mh, 0.035 * k, 0.003 * k, COBALT)
    g.band_collar(m, fit, sh.ring("neck"), COBALT, height=0.85, rad=0.010)
    o.hem_all(m, thick=0.004 * k, depth=0.014 * k)
    kit.add_soft(m)
    jh = Hull(fit, [m])
    nk = g.Neck(fit)
    zp = Mesh()
    path = g.front_path(jh, 0.0, nk.point(0.0, 0.6).z, bottom_z - 0.03 * k, step=0.02 * k)
    o.strip(zp, jh, path, 0.005 * k, 0.0022 * k, "chrome", segs_across=1, chamfer=0.001 * k)
    kit.add_gear(zp)
    return m


def jay(kit: Kit) -> None:
    """Slim cobalt racing jacket with white sleeve stripes over a white tee, black jeans, white sneakers,
    cognac driving gloves."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    shoes = g.shoes(fit, "char_sneaker_white", "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(shoes)
    tee = g.knit_top(fit, kit.hull(), "char_shirt_white", belt_z - 0.01 * k, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", shoes, belt_z + 0.022 * k, hem_r=0.058)
    _gloves(kit, DRIVING, cuff_len=0.030, cuff_off=0.004)
    n0 = len(kit.soft.f)
    jk = racing_jacket(kit, hips_z + 0.02 * k)
    _cull_under(kit, n0, jk, "faces_hidden_by_racing_jacket")
    kit.notes["look"] = ("Jay: slim, short cobalt racing jacket, high band collar, full zip, two white stripes down "
                         "each sleeve; white tee, black jeans, white sneakers, cognac driving gloves")


# =============================================================================================
# Juno (D4-03): the moto jacket
# =============================================================================================
def _line(hull: Hull, a: tuple[float, float], b: tuple[float, float], fallback_y: float, n_pts: int = 12) -> list:
    """Points on the outer front surface along the straight (x, z) line a -> b."""
    return [_front_hit(hull, lerp(a[0], b[0], i / (n_pts - 1)), lerp(a[1], b[1], i / (n_pts - 1)), fallback_y)
            for i in range(n_pts)]


def moto_jacket(kit: Kit, bottom_z: float) -> Mesh:
    """A fitted, waist-length emerald leather moto jacket: a band collar, an asymmetric chrome zip from the
    left collarbone down to the right hip, a hem belt with a chrome buckle on the right, a zipped chest
    pocket and zipped cuffs."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, MOTO, bottom_z=bottom_z, sleeve=1.92, base=0.008, waist_blouse=0.004, hull=hull,
                       iters=6, min_off=0.004 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
    mh = Hull(fit, [m])
    g.cuff_band(m, loops["hem"], mh, 0.045 * k, 0.003 * k, MOTO)                    # the hem belt
    for key in ("cuff.L", "cuff.R"):
        g.cuff_band(m, loops[key], mh, 0.030 * k, 0.003 * k, MOTO)
    g.band_collar(m, fit, sh.ring("neck"), MOTO, height=0.80, rad=0.010)
    o.hem_all(m, thick=0.004 * k, depth=0.014 * k)
    kit.add_soft(m)
    jh = Hull(fit, [m])
    nk = g.Neck(fit)
    cy = fit.ring_centre("chest").y
    neck_z = nk.point(0.0, 0.0).z
    zp = Mesh()
    zip_pts = _line(jh, (-0.075 * k, neck_z - 0.045 * k), (0.07 * k, bottom_z + 0.05 * k), cy + 0.15 * k, 16)
    o.strip(zp, jh, zip_pts, 0.005 * k, 0.0022 * k, "chrome", segs_across=1, chamfer=0.001 * k)
    pocket = _line(jh, (-0.115 * k, 1.29 * k), (-0.06 * k, 1.25 * k), cy + 0.15 * k, 6)          # chest pocket
    o.strip(zp, jh, pocket, 0.004 * k, 0.0018 * k, "chrome", segs_across=1, chamfer=0.001 * k)
    kit.add_gear(zp)
    buckle = o.Gear()                                                                        # hem belt buckle
    buckle.box((-0.017 * k, -0.013 * k, 0.0), (0.017 * k, 0.013 * k, 0.004 * k), "chrome")
    buckle.bevel(0.002 * k, 1, 30.0)
    bp = _front_hit(jh, 0.13 * k, bottom_z + 0.02 * k, cy + 0.15 * k)
    kit.add_gear(buckle.to_mesh(o.frame_from(bp, Vector((0.35, 1.0, 0.0)).normalized()), anchor=bp))
    return m


def juno(kit: Kit) -> None:
    """An emerald leather moto jacket over a graphite crew-neck, black jeans, heeled black moto boots, grey
    suede gloves, a blond side part."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    boots = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.15, base=0.007, heel=0.03, boot=True)
    kit.add_soft(boots)
    knit = g.knit_top(fit, kit.hull(), "char_knit_graphite", belt_z - 0.01 * k, neck="crew", base=0.004)
    kit.add_soft(knit)
    n.trousers(kit, "char_trousers_black", boots, belt_z + 0.022 * k, hem_r=0.056)
    _gloves(kit, SUEDE, cuff_len=0.030, cuff_off=0.004)
    n0 = len(kit.soft.f)
    jk = moto_jacket(kit, hips_z + 0.03 * k)
    _cull_under(kit, n0, jk, "faces_hidden_by_moto_jacket")
    kit.notes["look"] = ("Juno: fitted emerald leather moto jacket, asymmetric chrome zip, band collar, hem belt; "
                         "graphite crew-neck, black jeans, heeled black moto boots, grey suede gloves, blond side part")


# =============================================================================================
# Hale (D4-03): the chore jacket
# =============================================================================================
def chore_jacket(kit: Kit, bottom_z: float) -> Mesh:
    """A boxy hip-length sand canvas chore jacket buttoned to the collar: a point collar, a button placket,
    two big hip patch pockets and a chest pocket."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, CHORE, bottom_z=bottom_z, sleeve=1.95, base=0.010, hull=hull, iters=6, min_off=0.005 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    o.straighten_loop(m, loops["hem"], iters=3)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        g.cuff_band(m, loops[key], mh, 0.045 * k, 0.003 * k, CHORE)
    g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), CHORE, point_len=0.062, spread=0.30)
    o.hem_all(m, thick=0.005 * k, depth=0.016 * k)
    kit.add_soft(m)
    jh = Hull(fit, [m])
    nk = g.Neck(fit)
    top_z = nk.point(0.0, 0.0).z - 0.05 * k
    det = Mesh()
    path = g.front_path(jh, 0.0, top_z, bottom_z + 0.02 * k, step=0.02 * k)
    o.strip(det, jh, path, 0.024 * k, 0.0016 * k, CHORE, segs_across=1)                       # placket
    o.patch(det, jh, Vector((-0.10 * k, 0.0, 1.27 * k)), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.10 * k, 0.11 * k, 0.008 * k, 2), 0.004 * k, CHORE, cast_dir=Vector((-0.2, -1, 0)),
            rings=2, chamfer=0.003 * k)                                                       # chest pocket
    kit.add_soft(det)
    ph = kit.hull()
    btn = Mesh()
    z = top_z - 0.01 * k
    while z > bottom_z + 0.06 * k:
        btn.extend(gk.button(ph, Vector((0.0, 0.2, z)), "char_button_dark", r=0.0065, k=k, thick=0.004))
        z -= 0.095 * k
    kit.add_gear(btn)
    _bomber_pockets(kit, CHORE, bottom_z + 0.02 * k)
    return m


def hale(kit: Kit) -> None:
    """A sand canvas chore jacket over a navy henley, dark jeans, brown work boots, yellow work gloves; bald,
    a dark moustache."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    boots = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.16, base=0.007, boot=True)
    kit.add_soft(boots)
    knit = g.knit_top(fit, kit.hull(), "char_knit_navy", belt_z - 0.01 * k, neck="crew", base=0.005)
    kit.add_soft(knit)
    n.trousers(kit, "char_denim", boots, belt_z + 0.022 * k, hem_r=0.064)
    _gloves(kit, WORK, cuff_len=0.050, cuff_off=0.005)
    n0 = len(kit.soft.f)
    jk = chore_jacket(kit, hips_z - 0.11 * k)
    _cull_under(kit, n0, jk, "faces_hidden_by_chore_jacket")
    hair = f"char_hair_{fit.params['hair_color']}"
    kit.add_head(cg.moustache(fit, hair, z_off=-0.066, half_w=0.036, thick=0.0064, sides=12))
    kit.notes["look"] = ("Hale: boxy sand canvas chore jacket buttoned to the point collar, patch pockets; navy "
                         "henley, dark jeans, brown work boots, yellow work gloves; bald, dark moustache")


LOOKS = {"rook": rook, "sable": sable, "dutch": dutch, "wren": wren, "marten": marten, "jay": jay, "juno": juno,
         "hale": hale}
