"""Police first responders (D1-02, pd2_fidelity L4.2): Patrol Officer and TAC Light.

* ``char_patrol_officer``: navy (#1E2A44) uniform, long-sleeved shirt, a boxy navy duty/stab vest
  standing well off the shirt (wider and squarer than any jacket) with hi-vis (#D7E34A) bands, a
  hi-vis back panel and hi-vis epaulettes, padded shoulders, side straps with buckles, two front and
  two side pouches, a vest-mounted radio (antenna up) with a coiled cable to a speaker-mic on the
  right epaulette, silver badge; duty belt with holstered pistol, cuff/glove pouches and torch;
  police patrol cap (tall structured crown, flat top, chequered hi-vis/navy band, silver badge).
* ``char_tac_light``: charcoal (#2B2F33) tactical uniform, plate carrier (front/back plates, deep
  cummerbund, padded shoulder straps, three magazine pouches, admin and radio pouches), an
  oversized high-cut helmet with rails and big ear-pro cups, gloves, knee pads, boots, drop-leg
  holster.

30 m silhouettes (``_review/outfits_silhouette_30m.png``): Patrol = tall flat-topped cap + wide,
straight-sided vest torso; TAC = round, wide helmet + square padded shoulders + narrower chest with a
deep cummerbund; Halden Security = flat saucer cap on a slim shirted torso; suits/civilians are
bare-headed with tapered torsos.

Faction variants (D2-01): ``char_patrol_officer_<v>`` / ``char_tac_light_<v>`` for ``v`` in frd, sentinel,
zero (``_faction``: recolour + original insignia; zero adds the bone face mask and, on the Light,
pauldrons). The base ids are faction ``tac`` and are unchanged.

Duty looks (D-145.3, PO-18): ``char_patrol_officer_duty`` / ``char_tac_light_duty`` carry no body armour for Routine and
Tense. Patrol: the uniform shirt with the hi-vis epaulettes, chest radio and badge, no stab vest (a slim shirted torso
under the tall chequered cap). TAC: the charcoal tactical uniform, gloves, knee pads and drop-leg holster with the
magazine and radio pouches on the belt, no plate carrier, and a soft charcoal cap instead of the helmet.

FRD field agent (D-067, ``enemy.frd_agent``, FRD-only): ``char_frd_agent`` / ``char_frd_agent_b`` (a second
body: woman, darker skin, younger) = the FRD look: a plain-clothes agent in suit trousers, white shirt and
dark tie under a navy nylon raid windbreaker (cropped above the belt, zipped to mid-chest) with gold
FRD block letters across the back and on the left chest (``_faction`` lettering), an earpiece, a gold
badge on the belt and a holstered pistol; bare head. ``char_frd_agent_sentinel``: the Sentinel Corp
reskin of the role (grey windbreaker, the Sentinel logo, crimson tie).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (cap, helmet).
No blend shapes (baked at the params below).
"""

import math

import _faction as faction
import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
import _p5 as p5
import _special_gear as sg
from _outfit import Hull, Mesh, Vector, smoothstep
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

BASE_VARIANTS = {
    "char_patrol_officer": {"height": 1.79, "build": 0.6, "gender": 0.0, "age": 0.4, "skin": 3, "beard_shadow": 0.6, "hair": "short",
                            "hair_color": "dark", "unit": "patrol"},
    "char_tac_light": {"height": 1.81, "build": 0.7, "gender": 0.0, "age": 0.3, "skin": 2, "beard_shadow": 0.5, "hair": "buzz",
                       "hair_color": "brown", "unit": "tac"},
}
#: D2-01 faction reskins (``_faction``): ``char_<id>_<variant>`` = the base look + faction colours/insignia
FACTIONS = ("frd", "sentinel", "zero")
#: D2-01 / D-067 FRD field agent (``enemy.frd_agent``): FRD-only, so the base id is the FRD look; ``_b`` is a
#: second body for variety and ``_sentinel`` the Sentinel Corp reskin (``EnemyDef.params.visual_variant``)
AGENT = {"height": 1.82, "build": 0.55, "gender": 0.0, "age": 0.55, "skin": 2, "beard_shadow": 0.55,
         "hair": "side_part", "hair_color": "brown", "unit": "frd_agent"}
AGENT_VARIANTS = {
    "char_frd_agent": AGENT,
    "char_frd_agent_b": {"height": 1.72, "build": 0.4, "gender": 1.0, "age": 0.3, "skin": 5, "hair": "bob",
                         "hair_color": "dark", "unit": "frd_agent"},
    "char_frd_agent_sentinel": {**AGENT, "faction": "sentinel"},
}
#: D-145.3 (PO-18): no visible body armour on police at Routine/Tense: ``char_<id>_duty`` = the base look without the
#: stab vest / plate carrier and (TAC) without the ballistic helmet; ENV A picks it there (EnemyDef visual_variant
#: ``duty``), the armoured base looks from Hazardous
DUTY_VARIANTS = {f"{aid}_duty": {**p, "armored": False} for aid, p in BASE_VARIANTS.items()}
VARIANTS = {**BASE_VARIANTS, **AGENT_VARIANTS, **DUTY_VARIANTS,
            **{f"{aid}_{fac}": {**p, "faction": fac} for aid, p in BASE_VARIANTS.items() for fac in FACTIONS}}

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
        # ... but always outside the boot shaft (its top edge poked through the tapered leg): flare
        # each leg radially by the worst intrusion, fading out above the boot top (no kinks)
        boot_hull = Hull(fit, [shoes], body_regions=set())
        for sfx, sx in (("L", -1.0), ("R", 1.0)):
            cc = fit.ring_centre(f"calf.{sfx}")
            ids = [i for i, q in enumerate(tr.mesh.v) if q.z < 0.32 * k and q.x * sx > 0.0]
            need = 0.0
            for i in ids:
                q = tr.mesh.v[i]
                if 0.15 * k < q.z < 0.235 * k:          # around the boot top edge only
                    need = max(need, (o.push_out(q, boot_hull, 0.004 * k) - q).length)
            need = min(need, 0.010 * k)
            for i in ids:
                q = tr.mesh.v[i]
                rd = Vector((q.x - cc.x, q.y - cc.y, 0.0))
                if rd.length < 1e-6:
                    continue
                w = 1.0 - o.smoothstep(0.215 * k, 0.32 * k, q.z)
                tr.mesh.v[i] = q + rd.normalized() * (need * w)
    else:
        g.trouser_hems(tr, fit, Hull(fit, [shoes], body_regions=set()), trouser_mat)
    legs = [set(tl[key]) for key in ("leg.L", "leg.R") if boots and key in tl]
    leg_loops = [lp for lp in o.boundary_loops(tr.mesh.f) if set(lp) in legs]
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k, skip=lambda lp: set(lp) in legs)
    for lp in leg_loops:
        # bloused over the boot top: a shallow turn-in (a deep one pokes through the tapered leg)
        o.hem(tr.mesh, lp, thick=0.003 * k, depth=0.004 * k)
    kit.add_soft(tr.mesh)
    belt = gk.Belt(fit, Hull(fit, [tr.mesh], body_regions=set()), belt_z, height=0.05, thick=0.007)
    kit.add_soft(belt.mesh("char_leather_black"))
    return {"belt": belt, "belt_z": belt_z, "shirt": m, "trousers": tr.mesh}


def patrol(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    armored = kit.opts.get("armored", True)
    base = _base_uniform(kit, "char_police_shirt", NAVY, "fold", boots=False)
    belt = base["belt"]
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    chest_z = fit.ring_centre("chest").z
    # duty stab vest with hi-vis bands: a stiff, boxy carrier standing off the shirt (wider and
    # squarer than any jacket at 30 m), padded shoulders
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

    def shoulder_pad(p: Vector, r: str) -> float:
        d = 0.0
        for sfx in ("L", "R"):
            sh_pt = Vector(fit.J[f"shoulder.{sfx}"])
            dd = (p - sh_pt - Vector((0, 0, 0.035 * k))).length
            d += 0.010 * k * smoothstep(0.11 * k, 0.03 * k, dd)
        return d

    box = None
    det = Mesh()
    if armored:
        vest = g.upper_shell(fit, vest_mat, bottom_z=base["belt_z"] + 0.03 * k, base=0.016, sleeveless=True,
                             hull=kit.hull(), top_cut=cut, iters=4, waist_blouse=0.0, min_off=0.009 * k,
                             extra=shoulder_pad)
        vm = vest.mesh
        box = g.box_out(vm, chest_z + 0.02 * k, chest_z + 0.13 * k, 0.034 * k, 0.020 * k, 0.016 * k, power=4.0)
        for loop in o.boundary_loops(vm.f):
            o.straighten_loop(vm, loop, iters=3)
        o.hem_all(vm, thick=0.013 * k, depth=0.018 * k)
        kit.add_soft(vm)
        vh = Hull(fit, [vm])
        # hi-vis back panel (reads from behind at range)
        back = []
        for i in range(9):
            x = -0.12 * k + 0.24 * k * i / 8
            hit = vh.cast(Vector((x, -0.6, 1.195 * k)), Vector((0, 1, 0)), 1.2)
            back.append(hit[0] if hit[0] is not None else Vector((x, -0.12, 1.195 * k)))
        o.strip(det, vh, back, 0.034 * k, 0.0025 * k, HIVIS, side_hint=Vector((0, 0, 1)), segs_across=2,
                chamfer=0.003 * k)
    else:
        # D-145.3 duty look: no stab vest; the epaulettes sit on the shirt shoulders
        vh = kit.hull()
    # hi-vis epaulettes on the vest (duty: shirt) shoulders
    for sx in (-1.0, 1.0):
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        start = nk.point(sx * math.pi / 2, 0.0, 0.016 * k)
        end = Vector((sh_pt.x - sx * 0.005 * k, sh_pt.y + 0.004 * k, sh_pt.z + 0.07 * k))
        path = []
        for q in [start.lerp(end, t) for t in [i / 6 for i in range(7)]]:
            # drop onto the padded vest shoulder from above (never onto the shirt under it)
            hit = vh.cast(Vector((q.x, q.y, q.z + 0.3)), Vector((0, 0, -1)), 0.6)
            path.append(hit[0] if hit[0] is not None else q)
        o.strip(det, vh, path, 0.024 * k, 0.005 * k, HIVIS, segs_across=1, chamfer=0.003 * k, cast_back=0.05)
    kit.add_soft(det)
    hull = kit.hull()
    gear = Mesh()
    gear.extend(gk.shield_badge(hull, Vector((-0.095 * k, 0.3, 1.37 * k)), Vector((0, 1, 0.1)), 0.042, 0.05,
                                "char_metal_silver", "char_metal_silver", k=k))
    # side straps joining the front and back panels (elastic + buckle), two per side
    for sx in ((-1.0, 1.0) if armored else ()):
        for z in (1.12, 1.23):
            mtx, loc = o.surface_frame(hull, Vector((sx * 0.4, box["cy"], z * k)), Vector((sx, 0, 0)), up=o.UP)
            gp = o.Gear()
            gp.box((-0.050 * k, -0.019 * k, -0.002 * k), (0.050 * k, 0.019 * k, 0.005 * k), "polymer_black")
            gp.box((-0.016 * k, -0.023 * k, 0.003 * k), (0.016 * k, 0.023 * k, 0.012 * k), "polymer_black")
            gp.bevel(0.002 * k, 1, 30.0)
            gear.extend(gp.to_mesh(mtx, anchor=loc))
    # vest-front pouches between the hi-vis bands (notebook, gloves) and two side pouches
    for x in ((-0.085, 0.085) if armored else ()):
        mtx, loc = o.surface_frame(hull, Vector((x * k, 0.3, 1.20 * k)), Vector((0, 1, 0)))
        gp = o.Gear()
        gp.box((-0.040 * k, -0.042 * k, 0.0), (0.040 * k, 0.040 * k, 0.030 * k), NAVY)
        gp.box((-0.042 * k, 0.012 * k, 0.026 * k), (0.042 * k, 0.046 * k, 0.036 * k), NAVY)    # flap
        gp.bevel(0.004 * k, 1, 30.0)
        gp.cyl(0.005 * k, 0.004 * k, centre=(0.0, 0.026 * k, 0.038 * k), axis="Z", segs=10, mat="char_metal_silver")
        gear.extend(gp.to_mesh(mtx, anchor=loc))
    for sx in ((-1.0, 1.0) if armored else ()):
        a = sx * math.radians(68.0)
        d = Vector((math.sin(a), math.cos(a), 0.0))
        mtx, loc = o.surface_frame(hull, Vector((0.0, box["cy"], 1.17 * k)) + d * 0.1, d)
        gp = o.Gear()
        gp.box((-0.034 * k, -0.05 * k, 0.0), (0.034 * k, 0.045 * k, 0.040 * k), NAVY)
        gp.box((-0.036 * k, 0.015 * k, 0.036 * k), (0.036 * k, 0.050 * k, 0.046 * k), NAVY)
        gp.bevel(0.005 * k, 1, 30.0)
        gear.extend(gp.to_mesh(mtx, anchor=loc))
    # radio on the right chest of the vest (antenna up past the shoulder line) with a coiled cable
    # to the speaker-mic clipped on the right epaulette
    mtx, loc = o.surface_frame(hull, Vector((0.105 * k, 0.3, 1.315 * k)), Vector((0.12, 1, 0)))
    rw, rh, rd = 0.058 * k, 0.11 * k, 0.036 * k
    gp = o.Gear()
    gp.box((-rw / 2 - 0.005 * k, -rh / 2, 0.0), (rw / 2 + 0.005 * k, rh / 2 - 0.02 * k, 0.012 * k), "polymer_black")
    gp.box((-rw / 2, -rh / 2, 0.008 * k), (rw / 2, rh / 2, 0.008 * k + rd), "polymer_black")
    gp.box((-rw / 2 + 0.007 * k, -rh / 2 + 0.012 * k, 0.008 * k + rd - 0.001), (rw / 2 - 0.007 * k, -0.004 * k,
           0.008 * k + rd + 0.002 * k), "rubber_black")
    gp.bevel(0.004 * k, 1, 30.0)
    gp.cyl(0.0048 * k, 0.13 * k, centre=(-rw / 2 + 0.013 * k, rh / 2 + 0.065 * k, 0.008 * k + rd * 0.5), axis="Y",
           segs=8, mat="rubber_black")
    gp.cyl(0.007 * k, 0.014 * k, centre=(rw / 2 - 0.014 * k, rh / 2 + 0.007 * k, 0.008 * k + rd * 0.5), axis="Y",
           segs=10, mat="rubber_black")
    gp.cyl(0.003 * k, 0.004 * k, centre=(0.0, rh / 2 + 0.002 * k, 0.008 * k + rd * 0.5), axis="Y", segs=6,
           mat="char_led_red")
    gear.extend(gp.to_mesh(mtx, anchor=loc))
    radio_jack = mtx @ Vector((rw / 2 - 0.014 * k, rh / 2 + 0.014 * k, 0.008 * k + rd * 0.5))
    sh_r = Vector(fit.J["shoulder.R"])
    mic_at = Vector((sh_r.x - 0.035 * k, sh_r.y + 0.02 * k, sh_r.z + 0.07 * k))
    mic, mic_exit = gk.speaker_mic(hull, mic_at, Vector((0.25, 0.75, 0.6)), k=k)
    gear.extend(mic)
    gear.extend(gk.buckle(belt, "char_metal_silver", w=0.05, h=0.04))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    gear.extend(gk.pouch(belt, math.radians(-150.0), 0.07, 0.06, 0.03, "char_leather_black", snap="char_metal_silver"))
    gear.extend(gk.pouch(belt, math.radians(150.0), 0.06, 0.06, 0.028, "char_leather_black", snap="char_metal_silver"))
    gear.extend(gk.pouch(belt, math.radians(-105.0), 0.05, 0.075, 0.03, "char_leather_black", snap="char_metal_silver"))
    gear.extend(gk.flashlight(belt, math.radians(-55.0)))
    kit.add_gear(gear)
    hull = kit.hull()
    kit.add_soft(gk.coil_cable(fit, hull, radio_jack, mic_exit,
                               [radio_jack.lerp(mic_exit, 0.5) + Vector((0.012 * k, 0.025 * k, 0.0))], k=k,
                               coil_r=0.005, coil_from=0.15, coil_to=0.85))
    kit.seats["Hip"] = belt.point(math.radians(-105.0), dz=0.0, out=0.045 * k)
    # police patrol cap: tall structured crown, flat top, chequered hi-vis/navy (Sillitoe) band,
    # black chin strap, silver badge; taller and squarer than the Halden saucer cap at range
    cap, info = gk.peaked_cap(fit, NAVY, (HIVIS, NAVY), "char_visor_gloss", "char_leather_black", flare=1.07,
                              rise=(0.050, 0.068), band_h=0.048, check_rows=3, crown_dome=0.003,
                              badge_mats=("char_metal_silver", NAVY), visor_reach=0.062)
    kit.add_head(cap)
    kit.notes["hat"] = "police patrol cap, chequered band (Headwear), crown top z {:.3f} m".format(info["crown_top_z"])


def tac(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    armored = kit.opts.get("armored", True)
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
    if armored:
        # plate carrier: front/back plates conforming to the chest, cummerbund, shoulder straps
        hull = kit.hull()
        pc = Mesh()
        o.patch(pc, hull, Vector((0.0, 0.0, 1.255 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                o.rounded_rect(0.31 * k, 0.33 * k, 0.03 * k, 3), 0.042 * k, TAC_GEAR, cast_dir=Vector((0, -1, 0)),
                rings=4, chamfer=0.008 * k)
        o.patch(pc, hull, Vector((0.0, 0.0, 1.27 * k)), Vector((-1, 0, 0)), Vector((0, 0, 1)),
                o.rounded_rect(0.32 * k, 0.35 * k, 0.03 * k, 3), 0.040 * k, TAC_GEAR, cast_dir=Vector((0, 1, 0)),
                rings=4, chamfer=0.008 * k)
        cb = gk.Belt(fit, Hull(fit, [base["shirt"]], body_regions=set()), 1.15 * k, height=0.15, thick=0.028, drop=0.0,
                     gap=0.006)
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
        # padded carrier shoulders: thick pads on the straps over the shoulder tops (squares the
        # shoulder line so TAC never reads as the Patrol officer in silhouette)
        for sx in (-1.0, 1.0):
            sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
            # seated out on the shoulder cap (over the deltoid), tilted with the shoulder slope
            top = nk.point(sx * math.pi / 2, 0.0).lerp(sh_pt, 1.0)
            mtx, loc = o.surface_frame(hull, Vector((top.x + sx * 0.13, top.y, top.z + 0.2)), Vector((sx * 0.62, 0.0, 1.0)),
                                       up=Vector((0, 1, 0)))
            gp = o.Gear()
            gp.box((-0.040 * k, -0.062 * k, -0.004 * k), (0.040 * k, 0.062 * k, 0.026 * k), TAC_GEAR)
            gp.box((-0.030 * k, -0.050 * k, 0.022 * k), (0.030 * k, 0.050 * k, 0.032 * k), TAC_GEAR)
            gp.bevel(0.006 * k, 1, 30.0)
            gear.extend(gp.to_mesh(mtx, anchor=loc))
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
    else:
        # D-145.3 duty look: no plate carrier; three magazine pouches and the radio ride on the belt instead
        gear = Mesh()
        for a_deg in (-28.0, -48.0, -68.0):
            gear.extend(gk.pouch(belt, math.radians(a_deg), 0.05, 0.085, 0.032, TAC_GEAR, snap="polymer_black"))
        gear.extend(gk.radio(belt, math.radians(-100.0)))
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
    if armored:
        helm, info = gk.helmet(fit, "char_tac_helmet", gap=0.031, cup_r=0.041)
        kit.add_head(helm)
        kit.notes["hat"] = "helmet + ear protection (Headwear), top z {:.3f} m".format(info["top_z"])
    else:
        cap, _ring = p5.ball_cap(fit, TAC, peak_mat=TAC, button_mat="polymer_black")
        kit.add_head(cap)
        kit.notes["hat"] = "soft charcoal duty cap (Headwear), no helmet (D-145.3)"
    kit.seats["Hip"] = belt.point(math.radians(140.0), dz=0.0, out=0.05 * k)


# =============================================================================================
# FRD field agent (D-067)
# =============================================================================================
#: windbreaker colour and emblem per look (base = FRD; the Sentinel reskin wears its own corporate grey)
AGENT_LOOK = {"frd": ("char_frd_navy", "char_tie_black"), "sentinel": ("char_sen_grey", "char_sen_red")}


def windbreaker(kit: Kit, mat: str, bottom_z: float, v_z: float, neck_w: float = 0.07) -> Mesh:
    """Nylon raid windbreaker: a roomy torso + sleeve shell bloused over a ribbed waistband (cropped
    above the belt so the badge and holster show) and ribbed cuffs, zipped up to ``v_z`` (shirt
    collar and tie show in the V), a turned-down collar, slash pockets."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()

    def extra(p: Vector, r: str) -> float:
        if r in ("torso", "pelvis", "neck"):
            return 0.008 * k * smoothstep(bottom_z + 0.02 * k, bottom_z + 0.14 * k, p.z) \
                * smoothstep(1.50 * k, 1.36 * k, p.z) + 0.003 * k
        return 0.007 * k

    sh = g.upper_shell(fit, mat, bottom_z=bottom_z, sleeve=1.9, base=0.013, waist_blouse=0.014, arm_ease=2.4,
                       hull=hull, iters=6, min_off=0.007 * k, extra=extra)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
    mh = Hull(fit, [m])
    g.cuff_band(m, loops["hem"], mh, 0.05 * k, 0.004 * k, mat)
    for key in ("cuff.L", "cuff.R"):
        g.cuff_band(m, loops[key], mh, 0.045 * k, 0.0035 * k, mat)
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y

    def v_half(z: float) -> float:
        t = o.clamp((z - v_z) / max(neck_z - v_z, 1e-3), 0.0, 1.0)
        return o.lerp(0.004 * k, neck_w * k, t ** 0.9)

    g.delete_faces(m, lambda c: c.y > cy and c.z >= v_z and abs(c.x) < v_half(c.z) and c.z < neck_z + 0.08)
    g.snap_opening(m, v_half, cy, v_z, neck_z + 0.02, hull, 0.005 * k)
    o.hem_all(m, thick=0.005 * k, depth=0.016 * k)
    kit.add_soft(m)
    bh = Hull(fit, [m])
    zp = Mesh()
    path = g.front_path(bh, 0.0, v_z + 0.004 * k, bottom_z - 0.045 * k, step=0.02 * k)
    o.strip(zp, bh, path, 0.005 * k, 0.002 * k, "polymer_black", segs_across=1, chamfer=0.001 * k)
    kit.add_gear(zp)
    pull = o.Gear()
    pull.box((-0.005 * k, -0.016 * k, 0.0), (0.005 * k, 0.004 * k, 0.004 * k), "chrome")
    pull.bevel(0.0015 * k, 1, 30.0)
    hit = bh.cast(Vector((0.0, 0.6, v_z - 0.006 * k)), Vector((0, -1, 0)), 1.2)
    pp = hit[0] if hit[0] is not None else Vector((0.0, cy + 0.15 * k, v_z - 0.006 * k))
    kit.add_gear(pull.to_mesh(o.frame_from(pp, Vector((0.0, 1.0, 0.1))), anchor=pp))
    # turned-down collar: narrow lapels up the V edges and a band round the back of the neck
    col = Mesh()
    rows = 8
    for sx in (-1.0, 1.0):
        pts = []
        for i in range(rows):
            t = i / (rows - 1)
            z = o.lerp(v_z + 0.006 * k, neck_z - 0.004 * k, t)
            w = o.lerp(0.010, 0.026, smoothstep(0.0, 0.8, t)) * k
            hit = bh.cast(Vector((sx * (v_half(z) + w * 1.1), 0.6, z)), Vector((0, -1, 0)), 1.2)
            pts.append(hit[0] if hit[0] is not None else Vector((sx * (v_half(z) + w), cy + 0.12 * k, z)))
        o.strip(col, bh, pts, lambda t: o.lerp(0.010, 0.026, smoothstep(0.0, 0.8, t)) * k, 0.006 * k, mat,
                side_hint=Vector((sx, 0, 0)), segs_across=2, chamfer=0.003 * k)
    back = [nk.point(th, 0.0, 0.024 * k) - Vector((0.0, 0.0, 0.010 * k))
            for th in [o.lerp(0.62, o.TAU - 0.62, i / 20) for i in range(21)]]
    o.strip(col, kit.hull(), back, 0.032 * k, 0.007 * k, mat, side_hint=o.UP, segs_across=2, chamfer=0.003 * k,
            cast_back=0.06)
    kit.add_soft(col)
    # slash pockets (welts) on the front
    bh = kit.hull()
    pk = Mesh()
    for sx in (-1.0, 1.0):
        o.patch(pk, bh, Vector((sx * 0.11 * k, 0.0, bottom_z + 0.10 * k)), Vector((1, 0, 0)), o.UP,
                o.rounded_rect(0.022 * k, 0.12 * k, 0.006 * k, 2), 0.003 * k, mat,
                cast_dir=Vector((0.3 * sx, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)
    return m


def earpiece(kit: Kit, sfx: str = "R", mat: str = "char_cable_black") -> None:
    """Earpiece bud in the ear with a coiled cable curling down behind the ear into the collar."""
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
    gr.cyl(0.0055 * k, 0.006 * k, centre=(0, 0, 0.002 * k), axis="Z", segs=10, mat=mat)
    gr.bevel(0.0015 * k, 1, 30.0)
    m.extend(gr.to_mesh(o.frame_from(best, Vector((sx, 0.0, 0.0))), weights=head_w))
    nk = g.Neck(fit)
    hull = kit.hull()
    a = best + Vector((sx * 0.004 * k, -0.006 * k, -0.006 * k))
    b = o.push_out(nk.point(sx * 2.3, 0.70, 0.012 * k), hull, 0.008 * k)
    pts = []
    for i in range(23):
        t = i / 22
        p = a.lerp(b, t) + Vector((sx * 0.012 * k, -0.010 * k, 0.0)) * math.sin(math.pi * t)
        coil = 0.0045 * k * smoothstep(0.15, 0.3, t) * smoothstep(0.95, 0.75, t)
        ang = t * 2 * math.pi * 6
        pts.append(p + Vector((math.cos(ang) * coil * sx, math.sin(ang) * coil, 0.0)))

    def w(q: Vector, t: float) -> dict:
        h = smoothstep(0.55, 0.25, t)
        return {"head": h, "neck": 1.0 - h} if 0.0 < h < 1.0 else (head_w if h >= 1.0 else {"neck": 1.0})

    o.tube(m, pts, 0.0016 * k, mat, sides=5, weights=w)
    kit.add_gear(m, layer=False)


def belt_badge(belt: gk.Belt, a: float, k: float, rim: str = "brass", fill: str = "brass") -> Mesh:
    """Gold shield badge on a black leather belt clip, worn on the belt beside the buckle."""
    gp = o.Gear()
    gp.box((-0.026 * k, -0.040 * k, 0.0), (0.026 * k, 0.026 * k, 0.005 * k), "char_leather_black")
    gp.bevel(0.002 * k, 1, 30.0)
    outline = [(x, y - 0.006 * k) for x, y in o.shield_outline(0.040 * k, 0.050 * k)]
    gp.prism(outline, 0.0045 * k, 0.0080 * k, rim)
    inner = [(x, y - 0.008 * k) for x, y in o.shield_outline(0.028 * k, 0.036 * k)]
    gp.prism(inner, 0.0075 * k, 0.0092 * k, fill)
    return gp.to_mesh(belt.frame(a, dz=-0.004 * k), anchor=belt.point(a))


def frd_agent(kit: Kit) -> None:
    """Plain-clothes federal agent: dark suit trousers, white shirt and dark tie under a navy nylon raid
    windbreaker with gold FRD block letters across the back and on the left chest; earpiece, gold
    badge on the belt, holstered pistol on the right hip. Bare head (no cap / helmet): the bare-headed,
    jacketed silhouette is distinct from the capped Patrol and helmeted TAC at 30 m."""
    fit, k = kit.fit, kit.k
    emblem = kit.opts.get("faction") or "frd"
    jacket_mat, tie_mat = AGENT_LOOK[emblem]
    base = _base_uniform(kit, "char_shirt_white", "char_suit_dark", "fold", boots=False)
    belt = base["belt"]
    nk = g.Neck(fit)
    det = Mesh()
    knot = g.tie(det, kit.hull(), fit, nk.point(0.0, 0.0, 0.0).z - 0.035 * k, base["belt_z"] + 0.03 * k, tie_mat,
                 width=0.07)
    kit.add_soft(det)
    tk = o.Gear()
    tk.prism([(0.015 * k, 0.015 * k), (-0.015 * k, 0.015 * k), (-0.010 * k, -0.018 * k), (0.010 * k, -0.018 * k)],
             0.0, 0.015 * k, tie_mat)
    tk.bevel(0.004 * k, 2, 30.0)
    kp = knot + Vector((0.0, 0.002 * k, 0.026 * k))
    kit.add_gear(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))
    n0 = len(kit.soft.f)
    jk = windbreaker(kit, jacket_mat, base["belt_z"] + 0.04 * k, 1.30 * k)
    kit.notes["faces_hidden_by_windbreaker"] = str(sg.cull_hidden(kit.soft, n0, Hull(fit, [jk], body_regions=set())))
    gear = Mesh()
    gear.extend(gk.buckle(belt, "chrome", w=0.045, h=0.04))
    gear.extend(belt_badge(belt, math.radians(-32.0), k))
    gear.extend(gk.holster(belt, math.radians(100.0)))
    gear.extend(gk.pouch(belt, math.radians(-115.0), 0.05, 0.06, 0.026, "char_leather_black", snap="chrome"))
    kit.add_gear(gear)
    earpiece(kit, "R")
    # faction marks (the base look is FRD): big letters across the back, small on the left chest
    faction.torso_mark(kit, emblem, 1.27, front=False, h=0.12 if emblem == "frd" else 0.13)
    faction.torso_mark(kit, emblem, 1.36, front=True, h=0.032 if emblem == "frd" else 0.044)
    kit.seats["Hip"] = belt.point(math.radians(100.0), dz=0.0, out=0.05 * k)
    kit.notes["look"] = ("FRD field agent: {} windbreaker with {} marks (back + left chest), white shirt, tie, suit "
                         "trousers, earpiece (right), gold belt badge, holster; bare head").format(jacket_mat, emblem)


def tac_placard(kit: Kit, mat: str = "char_bank_cream") -> None:
    """PP-D: matte high-value placard bars across the front and back plates (TAC Light only, not the Corpsman),
    so TAC Light reads apart from Bulwark in shadow; a chest/back bar, unlike TAC Heavy's white shoulders."""
    k = kit.k
    hull = kit.hull()
    pl = Mesh()
    o.patch(pl, hull, Vector((0.0, 0.0, 1.30 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.26 * k, 0.075 * k, 0.012 * k, 2), 0.006 * k, mat, cast_dir=Vector((0, -1, 0)),
            rings=1, chamfer=0.003 * k)
    o.patch(pl, hull, Vector((0.0, 0.0, 1.32 * k)), Vector((-1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.28 * k, 0.085 * k, 0.012 * k, 2), 0.006 * k, mat, cast_dir=Vector((0, 1, 0)),
            rings=1, chamfer=0.003 * k)
    kit.add_soft(pl)


def recipe(kit: Kit) -> None:
    {"patrol": patrol, "tac": tac, "frd_agent": frd_agent}[kit.opts["unit"]](kit)
    if kit.opts["unit"] == "tac" and kit.opts.get("armored", True):
        tac_placard(kit, kit.opts.get("placard", "char_bank_cream"))
    faction.dress(kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
