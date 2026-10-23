"""Garments and insignia for the heist NPCs (D2-02: ``char_npc_bank.py``, ``char_npc_penthouse.py``).
Blender only (through ``_outfit``). Built on the shared outfit API (``_outfit_garments``,
``_gear_kit``); everything here is new garment logic the P1 kit does not have:

* ``shirt`` / ``trousers``: the tucked shirt and the hemmed trousers every uniform starts from,
* ``skirt``: a waist-to-knee skirt (the dress loft without the bodice),
* ``waistcoat`` (tailored, pointed front, V-neck) and ``knit_vest`` (ribbed sleeveless V-neck),
* ``tabard``: a cleaner's sleeveless over-tunic to mid-thigh with a front pocket,
* ``waist_apron``: a waiter's long bistro apron (no bib) with a waist tie,
* ``bow_tie`` and ``neckerchief`` (small hard pieces at the collar),
* ``jacket``: a tailored jacket / long coat with contrasting lapels and single- or double-breasted
  buttons,
* ``trouser_stripes``: livery side stripes,
* ``keyhole`` / ``bank_badge`` / ``bank_patch``: the Harbor Savings & Loan insignia (an original
  keyhole emblem in a shield),
* ``duty_belt``: the security officer's belt (radio = the ``Hip`` seat where the pager rides,
  speaker-mic and coiled cable, pouch, torch), as in ``char_security.py``.
"""

from __future__ import annotations

import math

import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit

UP = Vector((0.0, 0.0, 1.0))


def smoothstep(e0: float, e1: float, x: float) -> float:
    return o.smoothstep(e0, e1, x)


# =============================================================================================
# base layers
# =============================================================================================
def shirt(kit: Kit, mat: str, tuck_z: float, collar: str = "fold", sleeve: float = 2.0, cuff: bool = True,
          base: float = 0.0055, point_len: float = 0.056, spread: float = 0.28, roll: float = 0.0) -> Mesh:
    """Long-sleeved shirt/blouse tucked at ``tuck_z``; collar ``fold`` (pointed), ``band`` (stand)
    or ``none`` (a plain neckline). ``sleeve`` < 2 with ``roll`` > 0: sleeves rolled up (a thick
    turned-up roll of ``roll`` m)."""
    fit, k = kit.fit, kit.k
    sh = g.upper_shell(fit, mat, bottom_z=tuck_z, sleeve=sleeve, base=base, hull=kit.hull())
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], tuck_z)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=2)
            if cuff:
                g.cuff_band(m, loops[key], mh, (0.05 + roll * 1.5) * k, (0.002 + roll) * k, mat)
    if collar == "fold":
        g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), mat, point_len=point_len, spread=spread)
    elif collar == "band":
        g.band_collar(m, fit, sh.ring("neck"), mat, height=0.42, rad=0.006)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    kit.add_soft(m)
    return m


def shoes(kit: Kit, mat: str = "char_shoe_black", heel: bool = False, sole: str = "rubber_black") -> Mesh:
    fit = kit.fit
    if heel:
        s = g.shoes(fit, mat, sole, top_z=0.07, base=0.004, toe=0.016, heel=0.035)
    else:
        s = g.shoes(fit, mat, sole)
    kit.add_soft(s)
    return s


def trousers(kit: Kit, mat: str, shoes_mesh: Mesh, top_z: float, hem_r: float = 0.058) -> Mesh:
    fit, k = kit.fit, kit.k
    tr = g.trousers(fit, mat, top_z, hem_r=hem_r, hull=kit.hull())
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    g.trouser_hems(tr, fit, Hull(fit, [shoes_mesh], body_regions=set()), mat)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)
    return tr.mesh


def belt(kit: Kit, over: Mesh, z: float, mat: str = "char_leather_black", buckle: str = "chrome",
         height: float = 0.03) -> gk.Belt:
    b = gk.Belt(kit.fit, Hull(kit.fit, [over], body_regions=set()), z, height=height, thick=0.004)
    kit.add_soft(b.mesh(mat))
    kit.add_gear(gk.buckle(b, buckle, w=0.036, h=height + 0.002))
    return b


def skirt(kit: Kit, mat: str, top_z: float, hem_z: float, flare: float = 0.08, base: float = 0.006,
          slit: bool = False) -> Mesh:
    """Skirt from ``top_z`` (the waistband) to ``hem_z``: the pelvis band of the body hung straight
    down to the hem (``g.dress`` without its bodice), with a waistband."""
    fit, k = kit.fit, kit.k
    hips = fit.ring_centre("hips")
    z0 = hips.z - 0.03 * k
    sh = g.upper_shell(fit, mat, bottom_z=z0, sleeveless=True, base=base, waist_blouse=0.0,
                       top_cut=lambda c: c.z > top_z, iters=4, hull=kit.hull())
    m = sh.mesh
    loops = g.classify_loops(m)
    bottom = loops["hem"]
    o.straighten_loop(m, bottom, iters=3)
    for v in bottom:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, z0))
    o.straighten_loop(m, loops["top"], iters=3)
    rows = max(3, int((z0 - hem_z) / (0.035 * k)))
    # A closed skirt follows the thighs early (ramp) and fully at the hem, else a striding thigh pokes through the
    # front (walk / cower / seated); the cloth between the legs stretching is the right read. D-116 stride drape: the
    # same weights as g.dress (shin past the knee, a narrow centre band, less back relax: the back of a striding thigh
    # came through the back panel) and slack over the knees.
    rings = o.loft_down(m, bottom, lambda th: hem_z, kit.hull(), rows, clearance=0.015 * k, flare=flare, centre=hips,
                        weights=g.stride_drape(fit, z0, hem_z), keep_shape=0.35)
    g.knee_slack(m, rings, fit)
    top = g.classify_loops(m)["top"]
    g.cuff_band(m, top, Hull(fit, [m]), 0.03 * k, 0.002 * k, mat, rows=1)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    kit.add_soft(m)
    return m


# =============================================================================================
# vests and over-garments
# =============================================================================================
def _v_opening(fit, m: Mesh, hull: Hull, v_z: float, neck_w: float, min_off: float) -> None:
    """Cut a V-neck from the neck down to ``v_z`` at the front of a torso shell."""
    k = fit.k
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def v_half(z: float) -> float:
        t = min(max((z - v_z) / max(neck_z - v_z, 1e-3), 0.0), 1.0)
        return o.lerp(0.004 * k, neck_w * k, t ** 0.9)

    g.delete_faces(m, lambda c: c.y > cy and c.z >= v_z and abs(c.x) < v_half(c.z) and c.z < neck_z + 0.08)
    g.snap_opening(m, v_half, cy, v_z, neck_z + 0.02, hull, min_off)


def waistcoat(kit: Kit, mat: str, bottom_z: float, v_z: float, point: float = 0.05, neck_w: float = 0.07,
              button_mat: str = "char_button_dark", buttons: int = 4, base: float = 0.008,
              pockets: bool = True) -> Mesh:
    """Tailored waistcoat: sleeveless, V-neck down to ``v_z``, the front hem dropping into two points
    (``point`` below ``bottom_z``), a button line and two welt pockets."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, mat, bottom_z=bottom_z, sleeveless=True, base=base, waist_blouse=0.0, hull=hull,
                       iters=5, min_off=0.004 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    hem_ids = set(loops["hem"])
    cy = fit.ring_centre("chest").y
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for v in hem_ids:
        p = m.v[v]
        if p.y > cy:
            drop = point * k * smoothstep(0.13 * k, 0.03 * k, abs(p.x)) * smoothstep(0.0, 0.025 * k, abs(p.x) + 0.02 * k)
            m.v[v] = o.push_out(Vector((p.x, p.y, bottom_z - drop)), hull, 0.004 * k)
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=3)
    _v_opening(fit, m, hull, v_z, neck_w, 0.004 * k)
    o.drape(m, hull, 0.004 * k, max_off=0.05, iters=2)
    o.hem_all(m, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(m)
    vh = Hull(fit, [m])
    if pockets:
        pk = Mesh()
        for sx in (-1.0, 1.0):
            o.patch(pk, vh, Vector((sx * 0.085 * k, 0.0, bottom_z + 0.06 * k)), Vector((1, 0, 0)), UP,
                    o.rounded_rect(0.085 * k, 0.014 * k, 0.003 * k, 1), 0.0025 * k, mat,
                    cast_dir=Vector((0.2 * sx, -1, 0)), rings=1, chamfer=0.0015 * k)
        kit.add_soft(pk)
        vh = kit.hull()
    btn = Mesh()
    for i in range(buttons):
        z = o.lerp(v_z - 0.012 * k, bottom_z + 0.02 * k, i / max(buttons - 1, 1))
        btn.extend(gk.button(vh, Vector((0.0, 0.3, z)), button_mat, r=0.0058, k=k, thick=0.003))
    kit.add_gear(btn)
    return m


def knit_vest(kit: Kit, mat: str, bottom_z: float, v_z: float, neck_w: float = 0.075) -> Mesh:
    """Sleeveless V-neck sweater vest over a shirt: ribbed hem, armholes and V band."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, mat, bottom_z=bottom_z, sleeveless=True, base=0.008, waist_blouse=0.006, hull=hull,
                       iters=6, min_off=0.004 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=3)
    _v_opening(fit, m, hull, v_z, neck_w, 0.004 * k)
    mh = Hull(fit, [m])
    for loop in o.boundary_loops(m.f):
        c = o.loop_centre(m, loop)
        if c.z < bottom_z + 0.02 * k:
            g.cuff_band(m, loop, mh, 0.05 * k, 0.0025 * k, mat)
    o.hem_all(m, thick=0.004 * k, depth=0.014 * k)
    kit.add_soft(m)
    return m


def tabard(kit: Kit, mat: str, hem_z: float, trim_mat: str | None = None) -> Mesh:
    """Cleaner's tabard: a loose sleeveless over-tunic from the shoulders to ``hem_z`` (mid-thigh),
    hung straight from the hips, with a big front pocket and contrasting edge binding."""
    fit, k = kit.fit, kit.k
    hips = fit.ring_centre("hips")
    hull = kit.hull()
    sh = g.upper_shell(fit, mat, bottom_z=hips.z, sleeveless=True, base=0.014, waist_blouse=0.01, hull=hull,
                       iters=4, min_off=0.010 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    bottom = loops["hem"]
    o.straighten_loop(m, bottom, iters=3)
    for v in bottom:
        m.v[v] = Vector((m.v[v].x, m.v[v].y, hips.z))
    for key in ("cuff.L", "cuff.R"):
        if key in loops:
            o.straighten_loop(m, loops[key], iters=3)
    rows = max(2, int((hips.z - hem_z) / (0.035 * k)))
    o.loft_down(m, bottom, lambda th: hem_z, hull, rows, clearance=0.014 * k, flare=0.10, centre=hips,
                # D-115 clip audit: a closed panel, so it follows the thighs like a skirt (``skirt``): almost fully at
                # the hem, the front from just below the crease, the back relaxed under the seat; at 0.6 / 0.12 the
                # thighs broke through the front in cower_stand and the hem swung loose behind the legs.
                weights=o.skirt_weights(fit, hips.z, hem_z, thigh_max=0.95, centre_w=0.04, ramp=0.6, back_relax=0.6,
                                        front_ramp=0.25),
                keep_shape=0.5)
    o.drape(m, kit.hull(), 0.008 * k, max_off=0.08, iters=1)
    hem_loop = g.classify_loops(m)["hem"]
    if trim_mat:
        g.cuff_band(m, hem_loop, Hull(fit, [m]), 0.022 * k, 0.0015 * k, trim_mat, rows=1)
    o.hem_all(m, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(m)
    th = Hull(fit, [m])
    pk = Mesh()
    o.patch(pk, th, Vector((0.0, 0.0, hips.z + 0.07 * k)), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.24 * k, 0.12 * k, 0.012 * k, 2), 0.003 * k, mat, rim_mat=trim_mat,
            cast_dir=Vector((0, -1, 0)), rings=2, chamfer=0.004 * k, min_gap=0.001 * k)
    kit.add_soft(pk)
    return m


def waist_apron(kit: Kit, mat: str, top_z: float, hem_z: float, width: float = 0.52, tie_mat: str | None = None) -> Mesh:
    """Bistro apron: a straight panel from the waist to ``hem_z`` (below the knee) wrapping round the
    front of the hips, and a waist band tied at the back."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    hips = fit.ring_centre("hips")
    m = Mesh()
    nj = max(8, int((top_z - hem_z) / (0.03 * k)))
    ni = 14
    grid: list[list[int]] = []
    y_prev: list[float | None] = [None] * (ni + 1)
    wts = o.skirt_weights(fit, hips.z, hem_z)
    for j in range(nj + 1):
        z = o.lerp(top_z, hem_z, j / nj)
        row = []
        for i in range(ni + 1):
            # wrap: angle from -a..a round the front, radius from the hull
            a = o.lerp(-1.0, 1.0, i / ni) * math.radians(78.0)
            c = hips
            r = hull.outer_radius(min(z, top_z), a, c.x, c.y)
            if z < hips.z:
                r = max(r, hull.outer_radius(hips.z, a, c.x, c.y))
            r = (r if r > 0 else 0.15 * k) + 0.006 * k
            x = c.x + r * math.sin(a)
            y = c.y + r * math.cos(a)
            if z < hips.z and y_prev[i] is not None:
                y = max(y, y_prev[i] - 0.001 * k)
            y_prev[i] = y
            p = o.push_out(Vector((x, y, z)), hull, 0.006 * k)
            w = wts(p, 0.0) if z < hips.z else None
            row.append(m.add(p, w))
        grid.append(row)
    for j in range(nj):
        a_, b_ = grid[j], grid[j + 1]
        for i in range(ni):
            m.face((a_[i], a_[i + 1], b_[i + 1], b_[i]), mat, inside=Vector((0.0, -0.2, 1.0)))
    o.hem_all(m, thick=0.003 * k, depth=0.010 * k)
    kit.add_soft(m)
    b = gk.Belt(fit, Hull(fit, [m] + kit.layers, body_regions=set()), top_z - 0.012 * k, height=0.026, thick=0.003,
                drop=0.0)
    kit.add_soft(b.mesh(tie_mat or mat))
    return m


# =============================================================================================
# neckwear
# =============================================================================================
def _collar_front(kit: Kit, dz: float = 0.0) -> tuple[Vector, Vector]:
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    z = nk.point(0.0, 0.0).z - 0.012 * k + dz
    hit = kit.hull().cast(Vector((0.0, 0.6, z)), Vector((0, -1, 0)), 1.2)
    p = hit[0] if hit[0] is not None else Vector((0.0, fit.ring_centre("chest").y + 0.08 * k, z))
    return p, Vector((0.0, 1.0, 0.28)).normalized()


def bow_tie(kit: Kit, mat: str, half_w: float = 0.052, dz: float = 0.004) -> None:
    k = kit.k
    p, n = _collar_front(kit, dz * k)
    s = k
    outline = [(0.008, -0.006), (0.040, -0.020), (half_w, -0.012), (half_w + 0.002, 0.0), (half_w, 0.012),
               (0.040, 0.020), (0.008, 0.006), (-0.008, 0.006), (-0.040, 0.020), (-half_w, 0.012),
               (-half_w - 0.002, 0.0), (-half_w, -0.012), (-0.040, -0.020), (-0.008, -0.006)]
    gr = o.Gear()
    gr.prism([(x * s, y * s) for x, y in outline], 0.001 * k, 0.013 * k, mat)
    gr.bevel(0.002 * k, 1, 30.0)
    gr.box((-0.009 * k, -0.011 * k, 0.002 * k), (0.009 * k, 0.011 * k, 0.017 * k), mat)
    gr.bevel(0.003 * k, 1, 30.0)
    kit.add_gear(gr.to_mesh(o.frame_from(p, n), anchor=p))


def neckerchief(kit: Kit, mat: str, side: float = 1.0) -> None:
    """Small silk neckerchief: a band round the neck just above the collar, knotted at the front
    off-centre with two short pointed tails."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    band = Mesh()
    path = [nk.point(th, 0.36, 0.012 * k) for th in [o.lerp(-math.pi, math.pi, i / 24) for i in range(25)]]
    o.strip(band, hull, path, 0.012 * k, 0.003 * k, mat, side_hint=UP, segs_across=1, chamfer=0.0015 * k,
            closed=True, end_caps=False)
    kit.add_soft(band)
    th0 = side * 0.35
    p = nk.point(th0, 0.32, 0.020 * k)
    n = (nk.radial(th0) + Vector((0, 0, 0.15))).normalized()
    gr = o.Gear()
    gr.box((-0.013 * k, -0.011 * k, 0.0), (0.013 * k, 0.011 * k, 0.014 * k), mat)
    gr.bevel(0.004 * k, 1, 30.0)
    for sx, rot in ((-1.0, -0.35), (1.0, 0.25)):
        tail = [(0.0, 0.0), (0.012, -0.004), (0.006, -0.055), (-0.004, -0.050), (-0.010, -0.004)]
        cs, sn = math.cos(rot), math.sin(rot)
        pts = [((x * cs - y * sn + sx * 0.006) * k, (x * sn + y * cs - 0.004) * k) for x, y in tail]
        gr.prism(pts, 0.002 * k, 0.006 * k, mat)
    gr.bevel(0.0012 * k, 1, 30.0)
    kit.add_gear(gr.to_mesh(o.frame_from(p, n), anchor=p))


def tie(kit: Kit, mat: str, z_tip: float, width: float = 0.074) -> None:
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    det = Mesh()
    knot = g.tie(det, kit.hull(), fit, nk.point(0.0, 0.0, 0.0).z - 0.035 * k, z_tip, mat, width=width)
    kit.add_soft(det)
    tk = o.Gear()
    tk.prism([(0.016 * k, 0.016 * k), (-0.016 * k, 0.016 * k), (-0.010 * k, -0.019 * k), (0.010 * k, -0.019 * k)],
             0.0, 0.016 * k, mat)
    tk.bevel(0.004 * k, 2, 30.0)
    kp = knot + Vector((0.0, 0.002 * k, 0.026 * k))
    kit.add_gear(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))


# =============================================================================================
# tailoring
# =============================================================================================
def jacket(kit: Kit, mat: str, hem_z: float, button_z: float, lapel_mat: str | None = None,
           double: bool = False, button_mat: str = "char_button_dark", neck_w: float = 0.075,
           lapel_w: float = 0.055, flare: float = 0.08, pockets: bool = True, base: float = 0.011,
           open_below: float = 0.03, sleeve: float = 1.95, buttons: bool = True,
           chest_welt: bool = True) -> tuple[Mesh, dict]:
    """Tailored jacket or (with a low ``hem_z``) a long coat over the current layers: contrasting
    lapels (``lapel_mat``: satin on a dinner jacket), single button or a double-breasted 2 x 3
    button stance (``buttons=False``: none, a wrap robe), hip pocket flaps and a chest welt."""
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    jk, info = g.jacket(fit, kit.hull(), mat, hem_z, button_z, neck_w=neck_w, base=base, flare=flare,
                        lapel_w=lapel_w, lapel_mat=lapel_mat, collar_mat=lapel_mat, open_below=open_below,
                        sleeve=sleeve, keep_shape=0.45 if hem_z < 0.7 * k else 0.6)
    kit.add_soft(jk)
    jh = Hull(fit, [jk])
    gear = Mesh()
    if not buttons:
        pass
    elif double:
        for sx in (-1.0, 1.0):
            for dz in (0.0, -0.10, -0.20):
                gear.extend(gk.button(jh, Vector((sx * 0.066 * k, 0.3, button_z - 0.012 * k + dz * k)), button_mat,
                                      r=0.0105, k=k, thick=0.0045))
    else:
        gear.extend(gk.button(jh, Vector((0.012 * k, 0.3, button_z - 0.012 * k)), button_mat, r=0.009, k=k,
                              thick=0.004))
    if gear.f:
        kit.add_gear(gear)
    if pockets:
        pk = Mesh()
        pz = hips_z - 0.045 * k
        for sx in (-1.0, 1.0):
            o.patch(pk, jh, Vector((sx * 0.105 * k, 0.0, pz)), Vector((1, 0, 0)), UP,
                    o.rounded_rect(0.15 * k, 0.05 * k, 0.006 * k, 2), 0.0035 * k, mat,
                    cast_dir=Vector((0.25 * sx, -1, 0)), rings=2, chamfer=0.003 * k)
        if chest_welt:
            o.patch(pk, jh, Vector((-0.095 * k, 0.0, 1.30 * k)), Vector((1, 0, 0)), UP,
                    o.rounded_rect(0.10 * k, 0.018 * k, 0.003 * k, 1), 0.0025 * k, mat,
                    cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
        kit.add_soft(pk)
    return jk, info


def trouser_stripes(kit: Kit, tr: Mesh, mat: str, top_z: float, half_w: float = 0.009) -> None:
    """Livery stripe down the outer seam of each trouser leg (hip to hem)."""
    fit, k = kit.fit, kit.k
    th = Hull(fit, [tr], body_regions=set())
    m = Mesh()
    for sfx, sx in (("L", -1.0), ("R", 1.0)):
        hip, knee, ank = Vector(fit.J[f"hip.{sfx}"]), Vector(fit.J[f"knee.{sfx}"]), Vector(fit.J[f"ankle.{sfx}"])
        path = []
        z = top_z - 0.03 * k
        while z > ank.z + 0.05 * k:
            if z > knee.z:
                t = (hip.z - z) / max(hip.z - knee.z, 1e-3)
                c = hip.lerp(knee, min(max(t, 0.0), 1.0))
            else:
                t = (knee.z - z) / max(knee.z - ank.z, 1e-3)
                c = knee.lerp(ank, min(max(t, 0.0), 1.0))
            hit = th.cast(Vector((c.x + sx * 0.5, c.y, z)), Vector((-sx, 0, 0)), 1.0)
            if hit[0] is not None:
                path.append(hit[0])
            z -= 0.03 * k
        if len(path) >= 2:
            o.strip(m, th, path, half_w * k, 0.0018 * k, mat, side_hint=Vector((0, 1, 0)), segs_across=1,
                    chamfer=0.001 * k)
    kit.add_soft(m)


# =============================================================================================
# Harbor Savings & Loan insignia (original): a keyhole in a shield
# =============================================================================================
def keyhole_outline(s: float, n: int = 12) -> list[tuple[float, float]]:
    """A keyhole (round head over a tapering slot), ccw, height ~ ``s``, centred."""
    r = 0.30 * s
    cy = 0.16 * s
    top_hw, bot_hw, bot_y = 0.11 * s, 0.22 * s, -0.48 * s
    a0 = math.atan2(-math.sqrt(max(r * r - top_hw * top_hw, 0.0)), top_hw)    # right slot join (below centre)
    pts = [(bot_hw, bot_y)]
    a1 = math.pi - a0
    for i in range(n + 1):
        a = o.lerp(a0, a1 + 2 * math.pi if a1 < a0 else a1, i / n)
        pts.append((r * math.cos(a), cy + r * math.sin(a)))
    pts.append((-bot_hw, bot_y))
    return pts


def bank_badge(hull: Hull, p: Vector, toward: Vector, w: float, h: float, k: float, up: Vector = UP,
               rim: str = "brass", fill: str = "char_bank_red", glyph: str = "brass", depth: float = 0.004) -> Mesh:
    """Shield badge (rim + enamel) with a raised keyhole."""
    out = gk.shield_badge(hull, p, toward, w, h, rim, fill, k=k, up=up, depth=depth)
    mtx, loc = o.surface_frame(hull, p, toward, up=up)
    gr = o.Gear()
    s = min(w, h) * k * 0.62
    gr.prism([(x, y - h * k * 0.03) for x, y in keyhole_outline(s)], depth * k, depth * k + 0.0022 * k, glyph)
    out.extend(gr.to_mesh(mtx, anchor=loc))
    return out


def bank_patch(kit: Kit, sfx: str = "L", fill: str = "char_bank_red", rim: str = "char_bank_cream",
               glyph: str = "char_bank_cream") -> None:
    """Sleeve patch on the upper arm: a red shield with a cream border and keyhole."""
    fit, k = kit.fit, kit.k
    sx = -1.0 if sfx == "L" else 1.0
    sh, el = Vector(fit.J[f"shoulder.{sfx}"]), Vector(fit.J[f"elbow.{sfx}"])
    along = (el - sh).normalized()
    outward = Vector((sx * math.sin(math.radians(45.0)), 0.0, math.cos(math.radians(45.0))))
    outward = (outward - along * outward.dot(along)).normalized()
    outward = (outward * 0.55 + Vector((sx, 0.25, 0.0)) * 0.45).normalized()
    pc = sh + along * (0.115 * k)
    v_ax = -along
    u_ax = v_ax.cross(outward).normalized() if sx < 0 else outward.cross(v_ax).normalized()
    hull = kit.hull()
    soft = Mesh()
    o.patch(soft, hull, pc + outward * 0.1, u_ax, v_ax, o.shield_outline(0.072 * k, 0.086 * k), 0.0024 * k, fill,
            cast_dir=-outward, rim_mat=rim, rings=2, chamfer=0.004 * k)
    kit.add_soft(soft)
    hull = kit.hull()
    mtx, loc = o.surface_frame(hull, pc, outward, up=v_ax)
    gr = o.Gear()
    gr.prism([(x, y - 0.004 * k) for x, y in keyhole_outline(0.040 * k)], -0.0004, 0.0016 * k, glyph)
    kit.add_gear(gr.to_mesh(mtx, anchor=loc))


# =============================================================================================
# duty belt (security officer structure)
# =============================================================================================
def duty_belt(kit: Kit, tr: Mesh, belt_z: float, buckle: str = "brass", snap: str = "brass") -> None:
    """Duty belt with radio (the ``Hip`` seat: the pager rides there), pouch, torch, a speaker-mic
    on the right chest and the coiled cable down to the radio, as on the Halden officer."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    mic, exit_pt = gk.speaker_mic(hull, Vector((0.118 * k, 0.2, 1.418 * k)), Vector((0.3, 1.0, 0.2)), k=k)
    kit.add_gear(mic)
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.046, thick=0.006)
    kit.add_soft(b.mesh("char_leather_black"))
    bg = Mesh()
    bg.extend(gk.buckle(b, buckle))
    a_radio = math.radians(108.0)
    bg.extend(gk.radio(b, a_radio))
    bg.extend(gk.pouch(b, math.radians(-140.0), 0.075, 0.06, 0.03, "char_leather_black", snap=snap))
    bg.extend(gk.flashlight(b, math.radians(-62.0)))
    kit.add_gear(bg)
    radio_top = b.point(a_radio, dz=0.045 * k, out=0.03 * k)
    hull = kit.hull()
    mid = [exit_pt + Vector((0.01 * k, 0.02 * k, -0.08 * k)), Vector((0.165 * k, 0.07 * k, 1.20 * k)),
           Vector((0.19 * k, 0.03 * k, 1.11 * k))]
    kit.add_soft(gk.coil_cable(fit, hull, exit_pt, radio_top, mid, k=k, coil_to=0.62))
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    kit.notes["hip_note"] = "Hip seat = the radio on the duty belt (right hip); the pager rides there"


# =============================================================================================
# D-063 recast: Halden night-shift guard, the Shadow Ledger cleaner, IT contractor, Kessler at home
# =============================================================================================
def cull_under(kit: Kit, upto: int, cover: Mesh, key: str) -> None:
    """Drop the faces of the layers built before ``upto`` that ``cover`` hides completely (budget)."""
    import _special_gear as sg

    kit.notes[key] = str(sg.cull_hidden(kit.soft, upto, Hull(kit.fit, [cover], body_regions=set())))


def _front_hit(hull: Hull, x: float, z: float, fallback_y: float) -> Vector:
    hit = hull.cast(Vector((x, 0.6, z)), Vector((0, -1, 0)), 1.2)
    return hit[0] if hit[0] is not None else Vector((x, fallback_y, z))


def epaulettes(kit: Kit, mat: str, button_mat: str, bar_mat: str | None = None) -> None:
    """Shoulder straps (neck to shoulder point) with a button at the neck end and an optional rank bar."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    nk = g.Neck(fit)
    det = Mesh()
    for sx in (-1.0, 1.0):
        a = sx * math.pi / 2
        start = nk.point(a, 0.0, 0.008 * k) + Vector((0.0, 0.004 * k, 0.0))
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        end = Vector((sh_pt.x + sx * 0.035 * k, sh_pt.y + 0.004 * k, sh_pt.z + 0.065 * k))
        path = [start.lerp(end, t) + Vector((0, 0, 0.03 * k * math.sin(math.pi * t) * 0.3)) for t in [i / 7 for i in range(8)]]
        o.strip(det, hull, path, 0.022 * k, 0.0034 * k, mat, segs_across=2, chamfer=0.003 * k)
    kit.add_soft(det)
    hull = kit.hull()
    gear = Mesh()
    for sx in (-1.0, 1.0):
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        p_btn = nk.point(sx * math.pi / 2, 0.0, 0.0).lerp(sh_pt, 0.25) + Vector((0, 0, 0.055 * k))
        gear.extend(gk.button(hull, p_btn, button_mat, r=0.0048, toward=Vector((sx * 0.25, 0.1, 1.0)), k=k))
        if bar_mat:
            p_bar = nk.point(sx * math.pi / 2, 0.0, 0.0).lerp(sh_pt, 0.8) + Vector((0, 0, 0.065 * k))
            gear.extend(gk.bar(hull, p_bar, Vector((sx * 0.3, 0.05, 1.0)), 0.034, 0.008, 0.0022, bar_mat, k=k,
                               up=Vector((0, 1, 0))))
    kit.add_gear(gear)


def halden_patch(kit: Kit, sfx: str = "L", fill: str = "char_sec_burgundy", rim: str = "brass") -> None:
    """Halden Security sleeve patch (as on ``char_security_officer``): a burgundy shield with a gold
    rim and a raised gold "H" on the upper arm."""
    fit, k = kit.fit, kit.k
    sx = -1.0 if sfx == "L" else 1.0
    sh, el = Vector(fit.J[f"shoulder.{sfx}"]), Vector(fit.J[f"elbow.{sfx}"])
    along = (el - sh).normalized()
    outward = Vector((sx * math.sin(math.radians(45.0)), 0.0, math.cos(math.radians(45.0))))
    outward = (outward - along * outward.dot(along)).normalized()
    outward = (outward * 0.55 + Vector((sx, 0.25, 0.0)) * 0.45).normalized()
    pc = sh + along * (0.115 * k)
    v_ax = -along
    u_ax = v_ax.cross(outward).normalized() if sx < 0 else outward.cross(v_ax).normalized()
    hull = kit.hull()
    soft = Mesh()
    o.patch(soft, hull, pc + outward * 0.1, u_ax, v_ax, o.shield_outline(0.072 * k, 0.086 * k), 0.0024 * k, fill,
            cast_dir=-outward, rim_mat=rim, rings=2, chamfer=0.004 * k)
    kit.add_soft(soft)
    hull = kit.hull()
    kit.add_gear(gk.shield_badge(hull, pc, outward, 0.050, 0.060, rim, fill, k=k, up=v_ax, letter="H", depth=0.0016))


def cleaner_outfit(kit: Kit, top: str, trousers_mat: str, tabard_mat: str, trim: str, gloves: str,
                   tag: str) -> None:
    """Night cleaner (contractor): long-sleeve knit top under a tabard with a contrast binding and a
    big front pocket, work trousers, rubber gloves, a name tag."""
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    sh = shoes(kit)
    knit = g.knit_top(fit, kit.hull(), top, hips_z - 0.03 * k, neck="crew", base=0.007)
    kit.add_soft(knit)
    trousers(kit, trousers_mat, sh, belt_z + 0.02 * k, hem_r=0.062)
    tabard(kit, tabard_mat, 0.66 * k, trim_mat=trim)
    kit.add_soft(g.gloves(fit, gloves, cuff_len=0.10, base=0.0035, cuff_off=0.008))
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.09 * k, 0.2, 1.31 * k)), k=k, mat=tag))


def hood_down(kit: Kit, mat: str) -> None:
    """A hoodie's hood lying folded on the shoulders behind the neck: a thick rolled band round the
    back of the neck that tapers into the neckline at the front."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    m = Mesh()
    ths = [o.lerp(0.55, 2 * math.pi - 0.55, i / 22) for i in range(23)]
    path = [nk.point(th, 0.0, 0.030 * k) - Vector((0.0, 0.0, 0.020 * k)) for th in ths]

    def hw(t: float) -> float:
        return k * o.lerp(0.016, 0.055, math.sin(math.pi * t) ** 0.7)

    o.strip(m, hull, path, hw, 0.020 * k, mat, side_hint=UP, segs_across=3, chamfer=0.008 * k, cast_back=0.08)
    kit.add_soft(m)


def drawstrings(kit: Kit, mat: str, length: float = 0.13) -> None:
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    cy = fit.ring_centre("chest").y
    z0 = nk.point(0.0, 0.0).z - 0.03 * k
    gear = Mesh()
    for sx in (-1.0, 1.0):
        path = [o.push_out(_front_hit(hull, sx * 0.032 * k, z0 - length * k * t, cy + 0.12 * k), hull, 0.004 * k)
                for t in [i / 5 for i in range(6)]]
        o.tube(gear, path, 0.0032 * k, mat, sides=6)
    kit.add_gear(gear, layer=False)


def hoodie(kit: Kit, mat: str, bottom_z: float, string_mat: str = "char_medic_white") -> Mesh:
    """Pull-over hoodie: a loose knit shell to below the hips, ribbed hem and cuffs, a crew neckband,
    the hood folded on the shoulders, a kangaroo pocket and drawstrings."""
    fit, k = kit.fit, kit.k
    knit = g.knit_top(fit, kit.hull(), mat, bottom_z, base=0.012, rib=0.06, neck="crew")
    kit.add_soft(knit)
    hips_z = fit.ring_centre("hips").z
    pk = Mesh()
    o.patch(pk, Hull(fit, [knit]), Vector((0.0, 0.0, hips_z + 0.06 * k)), Vector((1, 0, 0)), UP,
            o.rounded_rect(0.27 * k, 0.12 * k, 0.03 * k, 3), 0.004 * k, mat, cast_dir=Vector((0, -1, 0)), rings=2,
            chamfer=0.004 * k)
    kit.add_soft(pk)
    hood_down(kit, mat)
    drawstrings(kit, string_mat)
    return knit


def lanyard(kit: Kit, strap_mat: str, card_mat: str, card_z: float = 1.22, band_mat: str | None = None) -> None:
    """ID lanyard: the strap from either side of the neck down to a clip and a badge card on the chest."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    cy = fit.ring_centre("chest").y
    top = _front_hit(hull, 0.0, card_z * k + 0.055 * k, cy + 0.12 * k)
    m = Mesh()
    for sx in (-1.0, 1.0):
        a = nk.point(sx * 0.95, 0.10, 0.012 * k)
        path = []
        for i in range(9):
            t = i / 8
            p = a.lerp(top + Vector((sx * 0.006 * k, 0.0, 0.0)), t)
            path.append(o.push_out(_front_hit(hull, p.x, p.z, p.y) if t > 0.15 else p, hull, 0.003 * k))
        o.strip(m, hull, path, 0.0075 * k, 0.0018 * k, strap_mat, segs_across=1, chamfer=0.001 * k)
    kit.add_soft(m)
    hull = kit.hull()
    pc = _front_hit(hull, 0.0, card_z * k, cy + 0.12 * k)
    mtx, loc = o.surface_frame(hull, pc, Vector((0.0, 1.0, 0.05)))
    gr = o.Gear()
    w, h = 0.056 * k, 0.086 * k
    gr.box((-w / 2, -h / 2, 0.001 * k), (w / 2, h / 2, 0.004 * k), card_mat)
    gr.bevel(0.0012 * k, 1, 30.0)
    gr.box((-w / 2 + 0.002 * k, h / 2 - 0.022 * k, 0.0035 * k), (w / 2 - 0.002 * k, h / 2 - 0.006 * k,
           0.0048 * k), band_mat or strap_mat)
    gr.box((-0.008 * k, h / 2 - 0.002 * k, 0.0015 * k), (0.008 * k, h / 2 + 0.014 * k, 0.0055 * k), "chrome")
    gr.bevel(0.0006 * k, 1, 30.0)
    kit.add_gear(gr.to_mesh(mtx, anchor=loc))


def messenger_bag(kit: Kit, mat: str, strap_mat: str, buckle_mat: str = "chrome", a_deg: float = -120.0,
                  z: float = 0.96, w: float = 0.16, h: float = 0.12, d: float = 0.075) -> None:
    """Shoulder messenger bag (laptop / tool bag) on the left hip, behind the side seam (clear of the
    right-hip ``Hip`` seat and the ``Back`` seat), on a strap across the body from the right shoulder."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    hips = fit.ring_centre("hips")
    zb = z * k
    a = math.radians(a_deg)
    r = hull.outer_radius(zb, a, hips.x, hips.y)
    out = Vector((math.sin(a), math.cos(a), 0.0))
    p = Vector((hips.x, hips.y, zb)) + out * (r + 0.005 * k)
    w, h, d = w * k, h * k, d * k
    bag = o.Gear()
    bag.box((-w, -h, 0.0), (w, h, d), mat)
    bag.bevel(0.014 * k, 2, 30.0)
    flap = o.Gear()
    flap.box((-w - 0.004 * k, -0.035 * k, d - 0.002 * k), (w + 0.004 * k, h + 0.006 * k, d + 0.007 * k), mat)
    flap.bevel(0.003 * k, 1, 30.0)
    for bx in (-0.5, 0.5):
        flap.box((bx * w - 0.010 * k, -0.06 * k, d + 0.005 * k), (bx * w + 0.010 * k, -0.025 * k, d + 0.010 * k),
                 buckle_mat)
    mtx = o.frame_from(p, out)
    kit.add_gear(bag.to_mesh(mtx, anchor=p), layer=False)
    kit.add_gear(flap.to_mesh(mtx, anchor=p), layer=False)
    cy = fit.ring_centre("chest").y
    sh_r = Vector(fit.J["shoulder.R"])
    top = p + Vector((0.0, 0.0, h * 0.95))
    pts: list[Vector] = []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        x = o.lerp(top.x + 0.02 * k, sh_r.x - 0.03 * k, t)
        zz = o.lerp(top.z, sh_r.z + 0.02 * k, t)
        pts.append(_front_hit(hull, x, zz, cy + 0.12 * k))
    for i in range(1, 4):
        yy = o.lerp(cy + 0.06 * k, cy - 0.06 * k, i / 4)
        hit = hull.cast(Vector((sh_r.x - 0.03 * k, yy, sh_r.z + 0.5)), Vector((0, 0, -1)), 1.0)
        pts.append(hit[0] if hit[0] is not None else Vector((sh_r.x - 0.03 * k, yy, sh_r.z + 0.06 * k)))
    for i in range(steps + 1):
        t = i / steps
        x = o.lerp(sh_r.x - 0.03 * k, top.x + 0.04 * k, t)
        zz = o.lerp(sh_r.z + 0.02 * k, top.z, t)
        hit = hull.cast(Vector((x, -0.6, zz)), Vector((0, 1, 0)), 1.2)
        pts.append(hit[0] if hit[0] is not None else Vector((x, cy - 0.15 * k, zz)))
    m = Mesh()
    o.strip(m, hull, pts, 0.019 * k, 0.004 * k, strap_mat, segs_across=1, chamfer=0.002 * k)
    kit.add_soft(m)


def sash(kit: Kit, robe: Mesh, mat: str, z: float, side: float = 1.0) -> None:
    """Dressing-gown sash: a soft belt round the robe at ``z`` tied off-centre with a knot and two
    hanging tails."""
    fit, k = kit.fit, kit.k
    rh = Hull(fit, [robe], body_regions=set())
    b = gk.Belt(fit, rh, z, height=0.045, thick=0.006, drop=0.0, gap=0.002)
    # re-sample from outside: the robe's front edges leave a slit the inside-out rays slip through
    rs = [max(rh.outer_radius(zz + dz * b.h, a, b.c.x, b.c.y) for dz in (-0.45, 0.0, 0.45))
          for a, zz in zip(b.theta, b.zc)]
    good = [r for r in rs if r > 0.0]
    fallback = sum(good) / max(len(good), 1)
    for i, r in enumerate(rs):
        if r <= 0.0:
            rs[i] = max(rs[i - 1], rs[(i + 1) % len(rs)], fallback * 0.9)
    b.r = gk._smooth_circ([r + 0.002 * k for r in rs], 3)
    kit.add_soft(b.mesh(mat))
    a = side * 0.30
    p = b.point(a, out=0.006 * k)
    n = Vector((math.sin(a), math.cos(a), 0.0))
    gr = o.Gear()
    gr.box((-0.028 * k, -0.026 * k, 0.0), (0.028 * k, 0.026 * k, 0.020 * k), mat)
    gr.bevel(0.008 * k, 2, 30.0)
    for tx, rot, ln in ((-0.012, -0.10, 0.30), (0.014, 0.12, 0.25)):
        cs, sn = math.cos(rot), math.sin(rot)
        tail = [(-0.020, 0.0), (0.020, 0.0), (0.022, -ln), (-0.022, -ln)]
        pts = [((x * cs - y * sn + tx) * k, (x * sn + y * cs - 0.012) * k) for x, y in tail]
        gr.prism(pts, 0.002 * k, 0.010 * k, mat)
    gr.bevel(0.002 * k, 1, 30.0)
    kit.add_gear(gr.to_mesh(o.frame_from(p, n), anchor=p))


def watch(kit: Kit, sfx: str = "L", strap: str = "char_leather_black", case: str = "chrome") -> None:
    """Slim wristwatch just above the wrist: a strap ring round the forearm and a small round case."""
    import _special_gear as sg

    fit, k = kit.fit, kit.k
    el, wr = Vector(fit.J[f"elbow.{sfx}"]), Vector(fit.J[f"wrist.{sfx}"])
    axis = (wr - el).normalized()
    c = wr - axis * 0.028 * k
    hull = kit.hull()
    r = sg.limb_radius(hull, c, axis) + 0.0025 * k
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((0, 1, 0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    wts = {f"forearm.{sfx}": 1.0}
    m = Mesh()
    path = [c + (u * math.cos(t) + v * math.sin(t)) * r for t in [2 * math.pi * i / 16 for i in range(17)]]
    o.tube(m, path, 0.0032 * k, strap, sides=6, weights=lambda q, t: wts, caps=False)
    # case on the back of the wrist (outward = +x for the left arm in A-pose: the arm's top side)
    top = v if v.z > 0 else -v
    p = c + top * (r + 0.002 * k)
    gr = o.Gear()
    gr.cyl(0.011 * k, 0.005 * k, centre=(0.0, 0.0, 0.0), axis="Z", segs=14, mat=case)
    gr.bevel(0.0012 * k, 1, 30.0)
    mm = gr.to_mesh(o.frame_from(p, top), anchor=p)
    mm.w = [wts for _ in mm.w]
    m.extend(mm)
    kit.add_gear(m, layer=False)


def earpiece(kit: Kit, sfx: str = "R", bud: str = "char_cable_black", cable: str = "char_cable_black") -> None:
    """Close-protection earpiece: a bud in the ear and an air-tube / coiled cable curling down behind
    the ear into the back of the collar."""
    fit, k = kit.fit, kit.k
    sx = 1.0 if sfx == "R" else -1.0
    eye = fit.eye_centre()
    c = fit.head_centre()
    hh = gk.HeadHull(fit)
    best = None
    for dy in (0.000, -0.006, 0.006, -0.012):
        for dz in (-0.028, -0.022, -0.034):
            hit = hh.cast(Vector((sx * 0.3, c.y + dy * k, eye.z + dz * k)), Vector((-sx, 0, 0)), 0.4)
            if hit[0] is not None and (best is None or sx * hit[0].x > sx * best.x):
                best = hit[0]
    if best is None:
        return
    head_w = {"head": 1.0}
    m = Mesh()
    gr = o.Gear()
    gr.cyl(0.0055 * k, 0.006 * k, centre=(0, 0, 0.002 * k), axis="Z", segs=10, mat=bud)
    gr.bevel(0.0015 * k, 1, 30.0)
    mm = gr.to_mesh(o.frame_from(best, Vector((sx, 0.0, 0.0))), weights=head_w)
    m.extend(mm)
    nk = g.Neck(fit)
    hull = kit.hull()
    a = best + Vector((sx * 0.004 * k, -0.006 * k, -0.006 * k))
    b = o.push_out(nk.point(sx * 2.3, 0.70, 0.012 * k), hull, 0.008 * k)
    pts = []
    n_pts = 22
    for i in range(n_pts + 1):
        t = i / n_pts
        p = a.lerp(b, t) + Vector((sx * 0.012 * k, -0.010 * k, 0.0)) * math.sin(math.pi * t)
        coil = 0.0045 * k * o.smoothstep(0.15, 0.3, t) * o.smoothstep(0.95, 0.75, t)
        ang = t * 2 * math.pi * 6
        p = p + Vector((math.cos(ang) * coil * sx, math.sin(ang) * coil, 0.0))
        pts.append(p)
    neck_w = {"neck": 1.0}

    def w(q: Vector, t: float) -> dict:
        h = o.smoothstep(0.55, 0.25, t)
        return {"head": h, "neck": 1.0 - h} if 0.0 < h < 1.0 else (head_w if h >= 1.0 else neck_w)

    o.tube(m, pts, 0.0016 * k, cable, sides=5, weights=w)
    kit.add_gear(m, layer=False)


def gate_pin(hull: Hull, p: Vector, k: float, metal: str = "chrome", enamel: str = "char_ng_enamel") -> Mesh:
    """Northgate Executive Protection lapel pin (original): a small round enamel disc with a raised
    metal gate (two posts under an arch)."""
    mtx, loc = o.surface_frame(hull, p, Vector((0.0, 1.0, 0.15)), lift=0.0005)
    gr = o.Gear()
    r = 0.0085 * k
    gr.cyl(r, 0.0022 * k, centre=(0.0, 0.0, 0.0011 * k), axis="Z", segs=16, mat=metal)
    gr.cyl(r * 0.80, 0.0012 * k, centre=(0.0, 0.0, 0.0024 * k), axis="Z", segs=16, mat=enamel)
    s = r * 0.62
    pw = 0.20 * s
    for x in (-0.62 * s, 0.62 * s - pw):
        gr.box((x, -0.70 * s, 0.0026 * k), (x + pw, 0.35 * s, 0.0040 * k), metal)
    outer = [(0.62 * s * math.cos(math.pi * i / 6), 0.35 * s + 0.40 * s * math.sin(math.pi * i / 6)) for i in range(7)]
    inner = [(x * 0.68, 0.35 * s + (y - 0.35 * s) * 0.55) for x, y in outer]
    for i in range(6):
        gr.prism([outer[i], outer[i + 1], inner[i + 1], inner[i]], 0.0026 * k, 0.0040 * k, metal)
    gr.box((-0.62 * s, -0.10 * s, 0.0026 * k), (0.62 * s, 0.06 * s, 0.0036 * k), metal)
    return gr.to_mesh(mtx, anchor=loc)


# ---------------------------------------------------------------------------------------------
# G3 close-range detail (RT / OF / GN polish), shared by the cast scripts
# ---------------------------------------------------------------------------------------------
def glasses_cord(kit: Kit, mat: str = "brass") -> None:
    """A thin cord from the glasses' temple tips round behind the neck."""
    fit, k = kit.fit, kit.k
    eye = fit.eye_centre()
    nk = g.Neck(fit)
    left, right = (Vector((sx * 0.072 * k, eye.y - 0.075 * k, eye.z - 0.004 * k)) for sx in (-1.0, 1.0))
    # Neck angles: 0 = front, -pi/2 = the -x side, pi = behind; the cord dips round the back of the neck
    arc = [nk.point(a * math.pi, 0.6, 0.012 * k) for a in (-0.55, -0.75, 1.0, 0.75, 0.55)]
    m = Mesh()
    o.tube(m, [left] + arc + [right], 0.0012 * k, mat, sides=4)
    kit.add_gear(m)


def front_item(kit: Kit, x: float, z: float, size: tuple[float, float, float], mat: str, lift: float = 0.004,
               up: Vector | None = None) -> None:
    """A flat item (w, h, d m) standing on the outermost front surface at (x, z) (before height scaling)."""
    k = kit.k
    hull = kit.hull()
    p = _front_hit(hull, x * k, z * k, kit.fit.ring_centre("chest").y + 0.15 * k)
    w, h, d = size
    kit.add_gear(gk.bar(hull, p + Vector((0.0, lift * k, 0.0)), Vector((0.0, 1.0, 0.0)), w, h, d, mat, k=k,
                        up=up or Vector((0.0, 0.0, 1.0))))


def arm_band(kit: Kit, side: str, t: float, width: float, mat: str, height: float = 0.003) -> None:
    """A closed band round the arm at arm parameter ``t`` (0 shoulder, 1 elbow, 2 wrist): an armband, tape, or a
    napkin folded over the forearm. Rays start just outside the sleeve, so the bind-pose torso is never hit."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh, el, wr = (Vector(fit.J[f"{j}.{side}"]) for j in ("shoulder", "elbow", "wrist"))
    a0, a1, tt = (sh, el, t) if t <= 1.0 else (el, wr, t - 1.0)
    axis = (a1 - a0).normalized()
    c = a0.lerp(a1, tt)
    ref = Vector((0.0, 1.0, 0.0))
    u = (ref - axis * ref.dot(axis)).normalized()
    v = axis.cross(u)
    ring = []
    for i in range(20):
        a = 2.0 * math.pi * i / 20
        d = u * math.cos(a) + v * math.sin(a)
        hit = hull.cast(c + d * 0.07 * k, -d, 0.07 * k)
        ring.append((hit[0] if hit[0] is not None else c + d * 0.04 * k) + d * 0.004 * k)
    m = Mesh()
    o.strip(m, hull, ring, width * 0.5 * k, height * k, mat, segs_across=1, chamfer=0.001 * k, closed=True,
            cast_back=0.03 * k)
    kit.add_soft(m)


def bead_necklace(kit: Kit, mat: str, beads: int = 18, r: float = 0.0045) -> None:
    """G3: a single strand of beads (pearls, a gold chain) lying round the base of the neck, dipping at the front."""
    fit, k = kit.fit, kit.k
    nk = g.Neck(fit)
    hull = kit.hull()
    gear = Mesh()
    for i in range(beads):
        a = math.tau * i / beads
        t = 0.0 if abs(math.cos(a)) < 0.3 else -0.25 * max(0.0, math.cos(a))
        p = o.push_out(nk.point(a, t, 0.006 * k), hull, 0.004 * k)
        gear.extend(gk.button(hull, p, mat, r=r, toward=nk.radial(a), k=k, thick=0.004))
    kit.add_gear(gear)
