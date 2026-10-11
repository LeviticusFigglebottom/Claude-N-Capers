"""Civilians for ``glasshouse`` (Vossberg Jewelers, an upscale jewelry store at dusk), D1-02.

Five variants with distinct silhouettes, genders, ages, builds and skin tones:

* ``char_civilian_customer_a``: young woman, long camel coat over a cream roll-neck, slim black
  trousers, brown ankle boots, blond bob.
* ``char_civilian_customer_b``: older heavy-set man, quilted navy gilet over a teal sweater, khaki
  chinos, brown shoes, grey hair.
* ``char_civilian_sales``: young sales associate, black short-sleeved dress to the knee with a
  thin belt, brass name badge, black flats, dark bob.
* ``char_civilian_jeweler``: lean older jeweler, white shirt with rolled sleeves and a green tie,
  leather bench apron, grey slacks, glasses with a loupe on the right lens.
* ``char_civilian_manager``: store manager, navy blazer over a pale blue shirt (no tie), grey
  slacks, brown shoes, brass name badge.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses).
No blend shapes (baked at the params below).
"""

import _gear_kit as gk
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character
from char_crew import suit

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False}

VARIANTS = {
    "char_civilian_customer_a": {"height": 1.70, "build": 0.3, "gender": 1.0, "age": 0.3, "skin": 1, "hair": "bob",
                                 "hair_color": "blond", "look": "coat"},
    "char_civilian_customer_b": {"height": 1.76, "build": 0.85, "gender": 0.0, "age": 0.85, "skin": 4,
                                 "hair": "short", "hair_color": "grey", "look": "gilet"},
    "char_civilian_sales": {"height": 1.68, "build": 0.25, "gender": 1.0, "age": 0.15, "skin": 6, "hair": "bob",
                            "hair_color": "dark", "look": "dress"},
    "char_civilian_jeweler": {"height": 1.74, "build": 0.2, "gender": 0.0, "age": 0.75, "skin": 1, "hair": "short",
                              "hair_color": "grey", "look": "apron"},
    "char_civilian_manager": {"height": 1.81, "build": 0.55, "gender": 0.0, "age": 0.45, "skin": 3, "beard_shadow": 0.35,
                              "hair": "buzz", "hair_color": "dark", "look": "blazer"},
}


def _trousers(kit: Kit, mat: str, shoes: Mesh, top_z: float, hem_r: float = 0.058) -> Mesh:
    fit, k = kit.fit, kit.k
    tr = g.trousers(fit, mat, top_z, hem_r=hem_r, hull=kit.hull())
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    g.trouser_hems(tr, fit, Hull(fit, [shoes], body_regions=set()), mat)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)
    return tr.mesh


def coat(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    shoes = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.006, boot=True)
    kit.add_soft(shoes)
    knit = g.knit_top(fit, kit.hull(), "char_knit_cream", hips_z + 0.02 * k, neck="roll", base=0.006)
    kit.add_soft(knit)
    _trousers(kit, "char_trousers_black", shoes, hips_z + 0.05 * k, hem_r=0.050)
    jk, _info = g.jacket(fit, kit.hull(), "char_coat_camel", 0.50 * k, 1.03 * k, neck_w=0.07, base=0.016,
                         flare=0.10, open_below=0.06, lapel_w=0.07, sleeve=1.97, keep_shape=0.4)
    kit.add_soft(jk)
    jh = Hull(fit, [jk])
    gear = Mesh()
    for sx in (-1.0, 1.0):
        for z in (1.03, 0.92):
            gear.extend(gk.button(jh, Vector((sx * 0.06 * k, 0.2, z * k)), "char_button_dark", r=0.010, k=k, thick=0.004))
    kit.add_gear(gear)
    # belt tie of the coat at the waist
    waist = fit.ring_centre("waist").z
    belt = gk.Belt(fit, Hull(fit, [jk], body_regions=set()), waist, height=0.04, thick=0.004, drop=0.0)
    kit.add_soft(belt.mesh("char_coat_camel"))


def gilet(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    shoes = g.shoes(fit, "char_shoe_brown", "rubber_black")
    kit.add_soft(shoes)
    tr = _trousers(kit, "char_chino_khaki", shoes, hips_z + 0.06 * k, hem_r=0.062)
    belt = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), hips_z + 0.035 * k, height=0.032, thick=0.004)
    kit.add_soft(belt.mesh("leather_dark"))
    knit = g.knit_top(fit, kit.hull(), "char_knit_teal", hips_z - 0.02 * k, neck="crew", base=0.009)
    kit.add_soft(knit)
    soft, zipm = g.gilet(fit, kit.hull(), "char_gilet_navy", hips_z - 0.035 * k)
    kit.add_soft(soft)
    kit.add_gear(zipm)


def dress(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    shoes = g.shoes(fit, "char_shoe_black", "rubber_black", top_z=0.075, base=0.004, toe=0.018)
    kit.add_soft(shoes)
    d = g.dress(fit, "char_dress_black", 0.47 * k)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    belt = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.022, thick=0.003, drop=0.0)
    kit.add_soft(belt.mesh("char_leather_black"))
    kit.add_gear(gk.buckle(belt, "brass", w=0.028, h=0.024))
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.085 * k, 0.2, 1.33 * k)), k=k))


def apron(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    shoes = g.shoes(fit, "char_shoe_black", "rubber_black")
    kit.add_soft(shoes)
    sh = g.upper_shell(fit, "char_shirt_white", bottom_z=belt_z - 0.02 * k, sleeve=1.25)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], belt_z - 0.02 * k)
    mh = Hull(fit, [m])
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=3)
        g.cuff_band(m, loops[key], mh, 0.06 * k, 0.006 * k, "char_shirt_white", rows=3)   # rolled-up sleeve
    g.shirt_collar(m, fit, sh.ring("neck"), kit.hull(), "char_shirt_white", point_len=0.055)
    o.hem_all(m, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(m)
    tr = _trousers(kit, "char_slacks_grey", shoes, belt_z + 0.022 * k)
    del tr
    det = Mesh()
    nk = g.Neck(fit)
    knot = g.tie(det, kit.hull(), fit, nk.point(0.0, 0.0, 0.0).z - 0.035 * k, belt_z + 0.03 * k, "char_vest_green",
                 width=0.07)
    kit.add_soft(det)
    tk = o.Gear()
    tk.prism([(0.015 * k, 0.015 * k), (-0.015 * k, 0.015 * k), (-0.009 * k, -0.018 * k), (0.009 * k, -0.018 * k)],
             0.0, 0.015 * k, "char_vest_green")
    tk.bevel(0.004 * k, 2, 30.0)
    kp = knot + Vector((0.0, 0.002 * k, 0.025 * k))
    kit.add_gear(tk.to_mesh(o.frame_from(kp, Vector((0.0, 1.0, 0.35))), anchor=kp))
    ap = g.apron(fit, kit.hull(), "char_apron_leather", 1.33 * k, 0.56 * k, strap_mat="char_apron_leather")
    kit.add_soft(ap)
    ah = Hull(fit, [ap])
    pk = Mesh()
    o.patch(pk, ah, Vector((0.0, 0.0, 0.86 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.24 * k, 0.12 * k, 0.01 * k, 2), 0.003 * k, "char_apron_leather",
            cast_dir=Vector((0, -1, 0)), rings=2, chamfer=0.003 * k)
    kit.add_soft(pk)
    kit.add_head(gk.glasses(fit, "brass", loupe=True))


def blazer(kit: Kit) -> None:
    k = kit.k
    suit(kit, "char_blazer_navy", "char_shirt_blue", None, shoe_mat="char_shoe_brown", trouser_mat="char_slacks_grey",
         hem_z=0.79, button_z=1.05)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.10 * k, 0.2, 1.36 * k)), k=k))


_looks = {"coat": coat, "gilet": gilet, "dress": dress, "apron": apron, "blazer": blazer}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
