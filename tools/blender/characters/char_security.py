"""Security Officer (Halden Security), the stealth guard (D1-02, pd2_fidelity L4.1).

Hero reference: the officer style sample (``tools/blender/style_samples/officer.py``,
``docs/art/style_samples/a_gsr/officer.png``): pale steel-blue shirt ``#8E9DAE`` with pointed
fold-over collar, charcoal ``#2A2D33`` tie, epaulettes and peaked cap, gold ``#C9A227`` braid and
badge rims (library ``brass``), burgundy ``#6E1E2A`` shield patch with an "H" on the left sleeve,
twin flapped chest pockets with pale buttons, a shoulder speaker-mic with a coiled cable to the radio
on the duty belt. Dark trousers, black duty belt (radio = the ``Hip`` seat where the pager rides,
handcuff case, torch), black shoes.

Two body variants so guards don't look cloned: ``char_security_officer`` (lean, 30s) and
``char_security_officer_b`` (heavy-set, older, darker skin, grey buzz cut); D-116: ``_c`` a woman in her 30s, mid
skin, dark bob under the cap, and ``_d`` a tall young man, deep skin, buzz cut. D-130 (Night Deposit at Cataclysm: about
+50 % guards, up to 6 on the floor): ``_e`` a woman in her 50s, light skin, grey bob, gold-rimmed glasses (``glasses``
option), and ``_f`` a broad man in his 40s, mid-deep skin, short dark hair, a dark moustache (``moustache`` option).
OF-D1 (Ostrander Federal, the L heist's Halden day shift: up to 6 guards + the VIP bodyguard, D-130-sized): ``_g`` a slim
young woman, deep skin, dark hair in a low bun under the cap (``bun`` option); ``_h`` a man in his 60s, light skin, short
grey hair, a grey moustache; ``_i`` a tall broad woman in her 40s, olive skin, blond bob, small gold ear studs
(``earrings`` option); ``_j`` a slight young man, light skin, short blond hair. Same uniform and badge set on all ten.

``char_security_bodyguard`` (OF-D1, ``guard_vip``): the Halden close-protection officer who escorts the VIP client.
Plainclothes but clearly security: a near-black two-piece suit, white shirt open at the collar (no tie), an earpiece
with a coiled cable behind the right ear, the Halden lapel pin (a small gold-rimmed burgundy shield with the gold "H")
on the left lapel, and a radio clipped to the waistband under the jacket on the right hip (the jacket rides over it:
the bulge; the radio = the ``Hip`` seat where the pager rides). No cap, no shirt livery: a suit silhouette. A big man in
his 40s, mid-deep skin, shaved head, heavy stubble (not the bare-headed npc_bank_guard's face).

Meshes (Godot ``<root>/Skeleton3D/``, exported with ``remove_armature``): ``Body`` (covered skin removed), ``Hair``,
``Outfit`` (cloth, belt, cable), ``Gear`` (rigid hard parts), ``Headwear`` (cap). No blend shapes:
the body is baked at the params below (see ``_outfit_build``).
"""

import math

import _contact_gear as cg
import _gear_kit as gk
import _npc as n
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
    # D-116 (Night Deposit: hall + basement + 1-2 rovers): two more Halden faces so 4 guards are never twins
    "char_security_officer_c": {"height": 1.70, "build": 0.4, "gender": 1.0, "age": 0.3, "skin": 4,
                                "hair": "bob", "hair_color": "dark"},
    "char_security_officer_d": {"height": 1.84, "build": 0.6, "gender": 0.0, "age": 0.22, "skin": 6, "beard_shadow": 0.7,
                                "hair": "buzz", "hair_color": "dark"},
    # D-130 (Cataclysm: up to 6 Halden guards on the Night Deposit floor): two more faces
    "char_security_officer_e": {"height": 1.68, "build": 0.6, "gender": 1.0, "age": 0.55, "skin": 1,
                                "hair": "bob", "hair_color": "grey", "glasses": "brass"},
    "char_security_officer_f": {"height": 1.86, "build": 0.75, "gender": 0.0, "age": 0.5, "skin": 4, "beard_shadow": 0.6,
                                "hair": "short", "hair_color": "dark", "moustache": "char_hair_dark"},
    # OF-D1 (Ostrander Federal day shift, D-130-sized: up to 6 Halden guards + the bodyguard): four more faces
    "char_security_officer_g": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 6,
                                "hair": "side_part", "hair_color": "dark", "bun": "char_hair_dark"},
    "char_security_officer_h": {"height": 1.78, "build": 0.5, "gender": 0.0, "age": 0.72, "skin": 1, "beard_shadow": 0.45,
                                "hair": "short", "hair_color": "grey", "moustache": "char_hair_grey"},
    "char_security_officer_i": {"height": 1.76, "build": 0.8, "gender": 1.0, "age": 0.45, "skin": 3,
                                "hair": "bob", "hair_color": "blond", "earrings": "brass"},
    "char_security_officer_j": {"height": 1.72, "build": 0.28, "gender": 0.0, "age": 0.15, "skin": 2, "beard_shadow": 0.2,
                                "hair": "short", "hair_color": "blond"},
    # OF-D1 vip_client: the Halden close-protection officer (guard_vip)
    "char_security_bodyguard": {"height": 1.87, "build": 0.8, "gender": 0.0, "age": 0.5, "skin": 5, "beard_shadow": 0.9,
                                "hair": "bald", "hair_color": "dark", "look": "bodyguard"},
}

SHIRT = "char_sec_shirt"
CHARCOAL = "char_sec_charcoal"
TROUSERS = "char_sec_trousers"
BURGUNDY = "char_sec_burgundy"
GOLD = "brass"


def recipe(kit: Kit) -> None:
    if kit.opts.get("look") == "bodyguard":
        bodyguard(kit)
    else:
        uniform(kit)


def uniform(kit: Kit) -> None:
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
    bg.extend(gk.key_ring(belt, math.radians(-25.0)))                              # G3: the key ring
    kit.add_gear(bg)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.088 * k, 0.2, 1.345 * k)), k=k, mat=GOLD))  # G3: under the badge
    radio_top = belt.point(a_radio, dz=0.045 * k, out=0.03 * k)
    hull = kit.hull()
    mid = [exit_pt + Vector((0.01 * k, 0.02 * k, -0.08 * k)), Vector((0.165 * k, 0.07 * k, 1.20 * k)),
           Vector((0.19 * k, 0.03 * k, 1.11 * k))]
    kit.add_soft(gk.coil_cable(fit, hull, exit_pt, radio_top, mid, k=k, coil_to=0.62))
    kit.seats["Hip"] = belt.point(a_radio, dz=0.0, out=0.045 * k)

    # peaked cap
    cap, info = gk.peaked_cap(fit, CHARCOAL, "char_shirt_white", "char_visor_gloss", GOLD)  # PP-D-1: light cap band
    kit.add_head(cap)
    if "glasses" in kit.opts:
        kit.add_head(gk.glasses(fit, str(kit.opts["glasses"])))
    if "moustache" in kit.opts:
        kit.add_head(cg.moustache(fit, str(kit.opts["moustache"])))
    if "bun" in kit.opts:
        # a low bun at the nape, under the cap's back band
        kit.add_head(cg.chignon(fit, str(kit.opts["bun"]), size=0.72, lift=-0.045))
    if "earrings" in kit.opts:
        kit.add_head(cg.earrings(fit, str(kit.opts["earrings"]), drop=False))
    kit.notes["hat"] = "peaked cap (Headwear), crown top z {:.3f} m".format(info["crown_top_z"])


BG_SUIT = "char_tux_black"


def halden_pin(hull: Hull, p: Vector, k: float) -> Mesh:
    """Halden lapel pin: a small gold-rimmed burgundy shield with the raised gold "H" (the sleeve patch in miniature)."""
    return gk.shield_badge(hull, p, Vector((0.0, 1.0, 0.15)), 0.020, 0.024, GOLD, BURGUNDY, k=k, letter="H",
                           depth=0.0016)


def bodyguard(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    tuck = belt_z - 0.02 * k
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.056, spread=0.34)
    tr = n.trousers(kit, BG_SUIT, sh, belt_z + 0.022 * k)
    # radio (the Hip seat) clipped to the waistband under the jacket: the jacket is lofted over it, so it reads as the
    # bulge on the right hip. The belt itself is hidden by the jacket (only its ring is sampled, no belt mesh); a duty
    # holster hung below the jacket hem at the back, so the sidearm is left to HandR (drawn) like the Northgate detail
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.034, thick=0.0045)
    bg = Mesh()
    a_radio = math.radians(100.0)
    bg.extend(gk.radio(b, a_radio))
    kit.add_gear(bg)
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, BG_SUIT, 0.79 * k, 1.03 * k, button_mat="char_button_dark", lapel_w=0.052, neck_w=0.085,
                         flare=0.08)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_gear(halden_pin(kit.hull(), Vector((-0.090 * k, 0.3, 1.335 * k)), k))
    n.earpiece(kit, "R")
    kit.add_head(gk.glasses(fit, "char_button_dark"))                            # G3: dark glasses, a watch
    kit.add_head(cg.lenses(fit))
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["hip_note"] = "Hip seat = the radio on the belt under the jacket (right hip); the pager rides there"
    kit.notes["look"] = ("Halden close protection (OF-D1 guard_vip): near-black suit, white shirt open at the collar, no "
                         "tie, earpiece + coiled cable (right ear), Halden shield lapel pin, belt radio bulge on "
                         "the right hip under the jacket")


def build(ctx) -> None:
    build_character(ctx, recipe)
