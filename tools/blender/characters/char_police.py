"""Police first responders (D1-02, pd2_fidelity L4.2): Patrol Officer and TAC Light.

* ``char_patrol_officer``: navy (#1E2A44) uniform, long-sleeved shirt with flapped pockets, a navy
  stab vest with hi-vis (#D7E34A) bands front and back and a hi-vis back panel, silver badge,
  shoulder speaker-mic, duty belt with holstered pistol, radio, cuff pouch and torch. Bare head.
* ``char_tac_light``: charcoal (#2B2F33) tactical uniform, plate carrier (front/back plates,
  cummerbund, shoulder straps, three magazine pouches, admin and radio pouches), high-cut helmet
  with rails and ear protection, gloves, knee pads, boots, drop-leg holster. At 30 m it reads as a
  bulky, helmeted, boxy-torso figure, unlike the slim, bare-headed, striped Patrol Officer.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (TAC).
No blend shapes (baked at the params below).
"""

import math

import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector, smoothstep
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False}

VARIANTS = {
    "char_patrol_officer": {"height": 1.79, "build": 0.6, "gender": 0.0, "age": 0.4, "skin": 3, "hair": "short",
                            "hair_color": "dark", "unit": "patrol"},
    "char_tac_light": {"height": 1.81, "build": 0.7, "gender": 0.0, "age": 0.3, "skin": 2, "hair": "buzz",
                       "hair_color": "brown", "unit": "tac"},
}

NAVY = "char_police_navy"
HIVIS = "char_hivis"
TAC = "char_tac_charcoal"
TAC_GEAR = "char_tac_gear"


def _base_uniform(kit: Kit, shirt_mat: str, trouser_mat: str, collar: str, boots: bool) -> dict:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    shirt_bottom = belt_z - 0.02 * k
    if boots:
        shoes = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.20, base=0.008, toe=0.012, sole_h=0.022,
                        boot=True)
    else:
        shoes = g.shoes(fit, "char_shoe_black", "rubber_black")
    kit.add_soft(shoes)
    sh = g.upper_shell(fit, shirt_mat, bottom_z=shirt_bottom, sleeve=2.0, base=0.0065 if boots else 0.0055)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], shirt_bottom)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
        g.cuff_band(m, loops[key], mh, 0.05 * k, 0.0022 * k, shirt_mat)
    if collar == "fold":
        g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), shirt_mat, point_len=0.055)
    else:
        g.band_collar(m, fit, sh.ring("neck"), shirt_mat, height=0.5, rad=0.008)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    kit.add_soft(m)
    tr = g.trousers(fit, trouser_mat, belt_z + 0.022 * k, hem_r=0.054 if boots else 0.060, hull=kit.hull(),
                    base=0.008 if boots else 0.0065)
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    if boots:
        # trousers bloused into the boots: end the legs inside the boot tops
        for key in ("leg.L", "leg.R"):
            if key in tl:
                o.straighten_loop(tr.mesh, tl[key], iters=2)
    else:
        g.trouser_hems(tr, fit, Hull(fit, [shoes], body_regions=set()), trouser_mat)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)
    belt = gk.Belt(fit, Hull(fit, [tr.mesh], body_regions=set()), belt_z, height=0.05, thick=0.007)
    kit.add_soft(belt.mesh("char_leather_black"))
    return {"belt": belt, "belt_z": belt_z, "shirt": m, "trousers": tr.mesh}


def patrol(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    base = _base_uniform(kit, "char_police_shirt", NAVY, "fold", boots=False)
    belt = base["belt"]
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    # stab vest with hi-vis bands
    bands = ((1.255, 1.300), (1.105, 1.145))

    def vest_mat(c: Vector, _r: str) -> str:
        for z0, z1 in bands:
            if z0 * k <= c.z <= z1 * k:
                return HIVIS
        return NAVY

    def cut(c: Vector) -> bool:
        if c.y > cy:
            return c.z > neck_z - 0.045 * k * smoothstep(0.11 * k, 0.0, abs(c.x)) - 0.008 * k
        return c.z > neck_z + 0.012 * k

    vest = g.upper_shell(fit, vest_mat, bottom_z=base["belt_z"] + 0.03 * k, base=0.014, sleeveless=True,
                         hull=kit.hull(), top_cut=cut, iters=4, waist_blouse=0.0, min_off=0.008 * k)
    vm = vest.mesh
    for loop in o.boundary_loops(vm.f):
        o.straighten_loop(vm, loop, iters=3)
    o.hem_all(vm, thick=0.009 * k, depth=0.015 * k)
    kit.add_soft(vm)
    vh = Hull(fit, [vm])
    det = Mesh()
    # hi-vis back panel (reads from behind at range)
    back = []
    for i in range(9):
        x = -0.12 * k + 0.24 * k * i / 8
        hit = vh.cast(Vector((x, -0.6, 1.195 * k)), Vector((0, 1, 0)), 1.2)
        back.append(hit[0] if hit[0] is not None else Vector((x, -0.12, 1.195 * k)))
    o.strip(det, vh, back, 0.034 * k, 0.0025 * k, HIVIS, side_hint=Vector((0, 0, 1)), segs_across=2,
            chamfer=0.003 * k)
    # hi-vis shoulder tabs
    for sx in (-1.0, 1.0):
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        start = nk.point(sx * math.pi / 2, 0.0, 0.016 * k)
        end = Vector((sh_pt.x - sx * 0.01 * k, sh_pt.y + 0.004 * k, sh_pt.z + 0.06 * k))
        path = [start.lerp(end, t) for t in [i / 6 for i in range(7)]]
        o.strip(det, vh, path, 0.02 * k, 0.003 * k, HIVIS, segs_across=1, chamfer=0.003 * k)
    kit.add_soft(det)
    hull = kit.hull()
    gear = Mesh()
    gear.extend(gk.shield_badge(hull, Vector((-0.095 * k, 0.2, 1.37 * k)), Vector((0, 1, 0.1)), 0.042, 0.05,
                                "char_metal_silver", "char_metal_silver", k=k))
    mic, _exit = gk.speaker_mic(hull, Vector((0.11 * k, 0.2, 1.36 * k)), Vector((0.2, 1.0, 0.1)), k=k)
    gear.extend(mic)
    gear.extend(gk.buckle(belt, "char_metal_silver", w=0.05, h=0.04))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    a_radio = math.radians(-105.0)
    gear.extend(gk.radio(belt, a_radio))
    gear.extend(gk.pouch(belt, math.radians(-150.0), 0.07, 0.06, 0.03, "char_leather_black", snap="char_metal_silver"))
    gear.extend(gk.pouch(belt, math.radians(150.0), 0.06, 0.06, 0.028, "char_leather_black", snap="char_metal_silver"))
    gear.extend(gk.flashlight(belt, math.radians(-55.0)))
    kit.add_gear(gear)
    kit.seats["Hip"] = belt.point(a_radio, dz=0.0, out=0.045 * k)


def tac(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    base = _base_uniform(kit, TAC, TAC, "band", boots=True)
    belt = base["belt"]
    trousers = base["trousers"]
    # cargo pockets on the thigh sides
    th = Hull(fit, [trousers], body_regions=set())
    cp = Mesh()
    for sx in (-1.0, 1.0):
        hc = fit.ring_centre("thigh.R" if sx > 0 else "thigh.L")
        org = Vector((hc.x + sx * 0.2, hc.y + 0.01 * k, 0.70 * k))
        o.patch(cp, th, org, Vector((0, -sx, 0)), Vector((0, 0, 1)), o.rounded_rect(0.13 * k, 0.16 * k, 0.012 * k, 2),
                0.012 * k, TAC, cast_dir=Vector((-sx, 0, 0)), rings=2, chamfer=0.005 * k)
        o.patch(cp, th, org + Vector((0, 0, 0.07 * k)), Vector((0, -sx, 0)), Vector((0, 0, 1)),
                o.rounded_rect(0.14 * k, 0.04 * k, 0.006 * k, 2), 0.018 * k, TAC, cast_dir=Vector((-sx, 0, 0)),
                rings=1, chamfer=0.004 * k)
    kit.add_soft(cp)
    kit.add_gear(g_knees := gk.knee_pads(fit, kit.hull()))
    del g_knees
    kit.add_soft(g.gloves(fit, "char_tac_glove", base=0.003, cuff_len=0.06, cuff_off=0.006))
    # plate carrier: front/back plates conforming to the chest, cummerbund, shoulder straps
    hull = kit.hull()
    pc = Mesh()
    o.patch(pc, hull, Vector((0.0, 0.0, 1.255 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.31 * k, 0.33 * k, 0.03 * k, 3), 0.042 * k, TAC_GEAR, cast_dir=Vector((0, -1, 0)),
            rings=4, chamfer=0.008 * k)
    o.patch(pc, hull, Vector((0.0, 0.0, 1.27 * k)), Vector((-1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.32 * k, 0.35 * k, 0.03 * k, 3), 0.040 * k, TAC_GEAR, cast_dir=Vector((0, 1, 0)),
            rings=4, chamfer=0.008 * k)
    cb = gk.Belt(fit, Hull(fit, [base["shirt"]], body_regions=set()), 1.15 * k, height=0.13, thick=0.018, drop=0.0,
                 gap=0.004)
    pc.extend(cb.mesh(TAC_GEAR))
    ph = Hull(fit, [pc, base["shirt"]])
    nk = g.Neck(fit)
    for sx in (-1.0, 1.0):
        pts = []
        for t in [i / 10 for i in range(11)]:
            a = sx * (0.35 + (math.pi - 0.7) * t)
            q = nk.point(a, 0.0, 0.035 * k)
            q.z = 1.40 * k + 0.07 * k * math.sin(math.pi * t)
            q.x = sx * (0.085 * k + 0.035 * k * math.sin(math.pi * t))
            pts.append(q)
        pts = [o.push_out(q, ph, 0.004 * k) for q in pts]
        o.strip(pc, ph, pts, 0.028 * k, 0.008 * k, TAC_GEAR, segs_across=2, chamfer=0.003 * k)
    kit.add_soft(pc)
    hull = kit.hull()
    gear = Mesh()
    # magazine pouches (3) + admin pouch on the front plate
    for i, x in enumerate((-0.065, 0.0, 0.065)):
        mtx, loc = o.surface_frame(hull, Vector((x * k, 0.3, 1.19 * k)), Vector((0, 1, 0)))
        gp = o.Gear()
        gp.box((-0.028 * k, -0.06 * k, 0.0), (0.028 * k, 0.05 * k, 0.034 * k), TAC_GEAR)
        gp.box((-0.022 * k, 0.03 * k, 0.006 * k), (0.022 * k, 0.078 * k, 0.028 * k), "polymer_black")
        gp.box((-0.03 * k, 0.035 * k, 0.03 * k), (0.03 * k, 0.05 * k, 0.038 * k), TAC_GEAR)
        gp.bevel(0.004 * k, 1, 30.0)
        gear.extend(gp.to_mesh(mtx, anchor=loc))
        del i
    mtx, loc = o.surface_frame(hull, Vector((0.0, 0.3, 1.33 * k)), Vector((0, 1, 0)))
    gp = o.Gear()
    gp.box((-0.07 * k, -0.035 * k, 0.0), (0.07 * k, 0.035 * k, 0.022 * k), TAC_GEAR)
    gp.box((-0.05 * k, -0.02 * k, 0.02 * k), (0.05 * k, 0.02 * k, 0.026 * k), "char_tac_helmet")
    gp.bevel(0.004 * k, 1, 30.0)
    gear.extend(gp.to_mesh(mtx, anchor=loc))
    # radio pouch on the left side of the cummerbund with antenna
    a = math.radians(-100.0)
    mtx = cb.frame(a, dz=0.0)
    gp = o.Gear()
    gp.box((-0.03 * k, -0.06 * k, 0.0), (0.03 * k, 0.06 * k, 0.04 * k), TAC_GEAR)
    gp.box((-0.024 * k, 0.05 * k, 0.008 * k), (0.024 * k, 0.07 * k, 0.034 * k), "polymer_black")
    gp.bevel(0.004 * k, 1, 30.0)
    gp.cyl(0.004 * k, 0.12 * k, centre=(0.012 * k, 0.12 * k, 0.02 * k), axis="Y", segs=6, mat="rubber_black")
    gear.extend(gp.to_mesh(mtx, anchor=cb.point(a)))
    # duty belt: buckle, pouches, drop-leg holster on the right thigh
    gear.extend(gk.buckle(belt, "polymer_black", w=0.055, h=0.045))
    gear.extend(gk.pouch(belt, math.radians(-140.0), 0.08, 0.07, 0.035, TAC_GEAR, snap="polymer_black"))
    gear.extend(gk.pouch(belt, math.radians(140.0), 0.08, 0.07, 0.035, TAC_GEAR, snap="polymer_black"))
    thigh = fit.ring_centre("thigh.R")
    mtx, loc = o.surface_frame(kit.hull(), Vector((thigh.x + 0.03 * k, thigh.y, 0.74 * k)), Vector((1.0, 0.25, 0.0)))
    gp = o.Gear()
    gp.box((-0.035 * k, -0.11 * k, 0.0), (0.035 * k, 0.07 * k, 0.012 * k), TAC_GEAR)          # leg panel
    gp.box((-0.024 * k, -0.10 * k, 0.010 * k), (0.024 * k, 0.04 * k, 0.05 * k), "polymer_black")  # holster
    gp.box((-0.016 * k, 0.03 * k, 0.016 * k), (0.016 * k, 0.10 * k, 0.046 * k), "rubber_black")    # grip
    gp.bevel(0.004 * k, 1, 30.0)
    gear.extend(gp.to_mesh(mtx @ o.Matrix.Rotation(math.radians(6.0), 4, "Z"), anchor=loc))
    kit.add_gear(gear)
    helm, info = gk.helmet(fit, "char_tac_helmet")
    kit.add_head(helm)
    kit.notes["hat"] = "helmet + ear protection (Headwear), top z {:.3f} m".format(info["top_z"])
    kit.seats["Hip"] = belt.point(math.radians(140.0), dz=0.0, out=0.05 * k)


def recipe(kit: Kit) -> None:
    {"patrol": patrol, "tac": tac}[kit.opts["unit"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
