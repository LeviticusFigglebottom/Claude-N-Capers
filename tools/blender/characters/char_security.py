"""Security Officer (Halden Security), the stealth guard (D1-02, pd2_fidelity L4.1).

Hero reference: the officer style sample (``tools/blender/style_samples/officer.py``,
``docs/art/style_samples/a_gsr/officer.png``): pale steel-blue shirt ``#8E9DAE`` with pointed
fold-over collar, charcoal ``#2A2D33`` tie, epaulettes and peaked cap, gold ``#C9A227`` braid and
badge rims (library ``brass``), burgundy ``#6E1E2A`` shield patch with an "H" on the left sleeve,
twin flapped chest pockets with pale buttons, a shoulder speaker-mic with a coiled cable to the radio
on the duty belt. Dark trousers, black duty belt (radio = the ``Hip`` seat where the pager rides,
handcuff case, torch), black shoes.

Two body variants so guards don't look cloned: ``char_security_officer`` (lean, 30s) and
``char_security_officer_b`` (heavy-set, older, darker skin, grey buzz cut).

Meshes (Godot ``<root>/Skeleton3D/``, exported with ``remove_armature``): ``Body`` (covered skin removed), ``Hair``,
``Outfit`` (cloth, belt, cable), ``Gear`` (rigid hard parts), ``Headwear`` (cap). No blend shapes:
the body is baked at the params below (see ``_outfit_build``).
"""

import math

import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_security_officer": {"height": 1.80, "build": 0.45, "gender": 0.0, "age": 0.35, "skin": 2,
                              "hair": "short", "hair_color": "brown"},
    "char_security_officer_b": {"height": 1.76, "build": 0.95, "gender": 0.0, "age": 0.8, "skin": 5, "beard_shadow": 0.85,
                                "hair": "buzz", "hair_color": "grey"},
}

SHIRT = "char_sec_shirt"
CHARCOAL = "char_sec_charcoal"
TROUSERS = "char_sec_trousers"
BURGUNDY = "char_sec_burgundy"
GOLD = "brass"


def recipe(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.038 * k
    trousers_top = belt_z + 0.026 * k
    shirt_bottom = belt_z - 0.02 * k

    # shoes
    shoes = g.shoes(fit, "char_shoe_black", "rubber_black")
    kit.add_soft(shoes)

    # shirt (tucked), long sleeves, fold-over collar
    sh = g.upper_shell(fit, SHIRT, bottom_z=shirt_bottom, sleeve=2.0)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], shirt_bottom)
    hull_body = kit.hull()
    shirt_hull = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
        g.cuff_band(m, loops[key], shirt_hull, 0.055 * k, 0.0022 * k, SHIRT)
    g.shirt_collar(m, fit, sh.ring("neck"), hull_body, SHIRT)
    o.hem_all(m, thick=0.003 * k, depth=0.012 * k)
    kit.add_soft(m)

    # trousers over the shirt tail, resting on the shoes
    tr = g.trousers(fit, TROUSERS, trousers_top, hem_r=0.060, hull=kit.hull())
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    g.trouser_hems(tr, fit, Hull(fit, [shoes], body_regions=set()), TROUSERS)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)

    # shirt details: pockets + flaps + buttons, epaulettes, tie
    hull = kit.hull()
    det = Mesh()
    tips = []
    for sx in (-1.0, 1.0):
        tips.append(g.pocket(det, hull, sx * 0.088 * k, 1.300 * k, 0.105, 0.120, SHIRT, flap=True, k=k))
    nk = g.Neck(fit)
    for sx in (-1.0, 1.0):
        a = sx * math.pi / 2
        start = nk.point(a, 0.0, 0.006 * k) + Vector((0.0, 0.004 * k, 0.0))
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        end = Vector((sh_pt.x + sx * 0.035 * k, sh_pt.y + 0.004 * k, sh_pt.z + 0.06 * k))
        path = [start.lerp(end, t) + Vector((0, 0, 0.03 * k * math.sin(math.pi * t) * 0.3)) for t in [i / 7 for i in range(8)]]
        o.strip(det, hull, path, 0.022 * k, 0.0032 * k, CHARCOAL, segs_across=2, chamfer=0.003 * k)
    knot = g.tie(det, hull, fit, nk.point(0.0, 0.0, 0.0).z - 0.035 * k, belt_z + 0.045 * k, CHARCOAL)
    kit.add_soft(det)
    hull = kit.hull()

    gear = Mesh()
    for t in tips:
        gear.extend(gk.button(hull, t, "char_button_pale", r=0.0052, k=k))
    # epaulette buttons + gold bars
    for sx in (-1.0, 1.0):
        sh_pt = Vector(fit.J["shoulder.R" if sx > 0 else "shoulder.L"])
        p_btn = nk.point(sx * math.pi / 2, 0.0, 0.0).lerp(sh_pt, 0.25) + Vector((0, 0, 0.05 * k))
        gear.extend(gk.button(hull, p_btn, GOLD, r=0.0048, toward=Vector((sx * 0.25, 0.1, 1.0)), k=k))
        p_bar = nk.point(sx * math.pi / 2, 0.0, 0.0).lerp(sh_pt, 0.8) + Vector((0, 0, 0.06 * k))
        gear.extend(gk.bar(hull, p_bar, Vector((sx * 0.3, 0.05, 1.0)), 0.034, 0.008, 0.0022, GOLD, k=k,
                           up=Vector((0, 1, 0))))
    # tie knot + tie bar
    tk = o.Gear()
    tk.prism([(0.017 * k, 0.017 * k), (-0.017 * k, 0.017 * k), (-0.011 * k, -0.019 * k), (0.011 * k, -0.019 * k)],
             0.0, 0.017 * k, CHARCOAL)
    tk.bevel(0.004 * k, 2, 30.0)
    kp = knot + Vector((0.0, 0.002 * k, 0.026 * k))
    gear.extend(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))
    gear.extend(gk.bar(hull, Vector((0.0, 0.2, 1.20 * k)), Vector((0, 1, 0)), 0.05, 0.005, 0.0045, GOLD, k=k))
    # badge (left chest) + name bar (right chest)
    gear.extend(gk.shield_badge(hull, Vector((-0.088 * k, 0.2, 1.405 * k)), Vector((0, 1, 0.1)), 0.040, 0.046,
                                GOLD, BURGUNDY, k=k))
    # sleeve patch (left upper arm): burgundy shield, gold rim, gold "H"
    sh_l, el_l = Vector(fit.J["shoulder.L"]), Vector(fit.J["elbow.L"])
    along = (el_l - sh_l).normalized()
    outward = Vector((-math.sin(math.radians(45.0)), 0.0, math.cos(math.radians(45.0))))
    outward = (outward - along * outward.dot(along)).normalized()
    outward = (outward * 0.55 + Vector((-1.0, 0.25, 0.0)) * 0.45).normalized()
    pc = sh_l + along * (0.115 * k)
    v_ax = -along
    u_ax = v_ax.cross(outward).normalized()
    soft_patch = Mesh()
    o.patch(soft_patch, hull, pc + outward * 0.1, u_ax, v_ax, o.shield_outline(0.072 * k, 0.086 * k), 0.0024 * k,
            BURGUNDY, cast_dir=-outward, rim_mat=GOLD, rings=2, chamfer=0.004 * k)
    kit.add_soft(soft_patch)
    hull = kit.hull()
    gear.extend(gk.shield_badge(hull, pc, outward, 0.050, 0.060, GOLD, BURGUNDY, k=k, up=v_ax, letter="H",
                                depth=0.0016))
    # speaker-mic on the right chest + coiled cable to the radio on the right hip
    mic, exit_pt = gk.speaker_mic(hull, Vector((0.118 * k, 0.2, 1.418 * k)), Vector((0.3, 1.0, 0.2)), k=k)
    gear.extend(mic)
    kit.add_gear(gear)

    # duty belt
    belt = gk.Belt(fit, Hull(fit, [tr.mesh], body_regions=set()), belt_z, height=0.046, thick=0.006)
    kit.add_soft(belt.mesh("char_leather_black"))
    bg = Mesh()
    bg.extend(gk.buckle(belt, GOLD))
    a_radio = math.radians(108.0)
    bg.extend(gk.radio(belt, a_radio))
    bg.extend(gk.pouch(belt, math.radians(-140.0), 0.075, 0.06, 0.03, "char_leather_black", snap=GOLD))
    bg.extend(gk.flashlight(belt, math.radians(-62.0)))
    kit.add_gear(bg)
    radio_top = belt.point(a_radio, dz=0.045 * k, out=0.03 * k)
    hull = kit.hull()
    mid = [exit_pt + Vector((0.01 * k, 0.02 * k, -0.08 * k)), Vector((0.165 * k, 0.07 * k, 1.20 * k)),
           Vector((0.19 * k, 0.03 * k, 1.11 * k))]
    kit.add_soft(gk.coil_cable(fit, hull, exit_pt, radio_top, mid, k=k, coil_to=0.62))
    kit.seats["Hip"] = belt.point(a_radio, dz=0.0, out=0.045 * k)

    # peaked cap
    cap, info = gk.peaked_cap(fit, CHARCOAL, "char_shirt_white", "char_visor_gloss", GOLD)  # PP-D-1: light cap band
    kit.add_head(cap)
    kit.notes["hat"] = "peaked cap (Headwear), crown top z {:.3f} m".format(info["crown_top_z"])


def build(ctx) -> None:
    build_character(ctx, recipe)
