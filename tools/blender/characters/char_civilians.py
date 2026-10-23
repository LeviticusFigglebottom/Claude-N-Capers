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

D-115 (heist cast audit 2026-10-15, glasshouse.md roster):

* ``char_civilian_manager_vossberg``: Greta Vossberg, the owner-manager (``civ_staff_manager``,
  rare ``nervous_manager``), a woman in her 50s: tailored deep-plum trouser suit (brass buttons),
  cream silk blouse open at the collar, a fine gold chain with a small pendant, gold stud earrings,
  gold reading glasses pushed up on her silver hair (side part + chignon), gold watch, black low heels.
* ``char_civilian_sales_b``: the second sales associate (``civ_staff_floor``), so the two on the
  floor are not twins: a young man in the boutique's black (fitted near-black suit, black shirt open
  at the collar, no tie) with the shop's brass: name badge and lapel pin; light skin, brown side part.
* ``char_civilian_clerk``: the upstairs admin clerk (``civ_staff_admin``): office wear, not the shop
  floor: an oatmeal knit cardigan (open, one button) over a white shirt, navy chinos, brown shoes,
  black glasses, a watch and the staff lanyard (black strap, brass band, white ID card).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses, chignon,
earrings).
No blend shapes (baked at the params below).
"""

import math

import _contact_gear as cg
import _crew_heisters as crew
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Hull, Mesh, Vector
from mathutils import Matrix
from _outfit_build import Kit, build_character
from char_crew import suit

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

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
    # D-115
    "char_civilian_manager_vossberg": {"height": 1.69, "build": 0.45, "gender": 1.0, "age": 0.68, "skin": 1,
                                       "hair": "side_part", "hair_color": "grey", "lip": "char_lip_rose",
                                       "look": "vossberg"},
    "char_civilian_sales_b": {"height": 1.79, "build": 0.35, "gender": 0.0, "age": 0.22, "skin": 2,
                              "beard_shadow": 0.3, "hair": "side_part", "hair_color": "brown", "look": "sales_b"},
    "char_civilian_clerk": {"height": 1.75, "build": 0.6, "gender": 0.0, "age": 0.35, "skin": 5,
                            "beard_shadow": 0.5, "hair": "short", "hair_color": "dark", "look": "clerk"},
}
PLUM = "char_suit_plum"


def _wrist_keys(kit: Kit, side: str = "R") -> None:
    """GH-G3: the display-case keys on a spiral wrist coil: a burgundy coil round the wrist and a small gold key
    cluster lying on the back of the wrist."""
    fit, k = kit.fit, kit.k
    n.arm_band(kit, side, 1.86, 0.010, "char_tie_burgundy", height=0.004)
    hull = kit.hull()
    el, wr = Vector(fit.J[f"elbow.{side}"]), Vector(fit.J[f"wrist.{side}"])
    axis = (wr - el).normalized()
    c = el.lerp(wr, 0.845)
    out = Vector((1.0 if side == "R" else -1.0, 0.0, 0.0))
    out = (out - axis * out.dot(axis)).normalized()
    hit = hull.cast(c + out * 0.08 * k, -out, 0.12 * k)
    if hit[0] is not None:
        kit.add_gear(gk.bar(hull, hit[0] + out * 0.003 * k, out, 0.010, 0.026, 0.003, "char_satin_gold", k=k, up=axis))


def _brooch(kit: Kit, x: float, z: float, mat: str, gem: str) -> None:
    """GH-G3: a jewelled brooch (a setting with a stone at its centre) on the left breast / lapel."""
    n.front_item(kit, x, z, (0.022, 0.022, 0.003), mat, lift=0.0)
    n.front_item(kit, x, z, (0.009, 0.009, 0.003), gem, lift=0.003)


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
    n.watch(kit, "L", strap="leather_dark", case="brass")                      # OF-G3


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
    n.watch(kit, "L", strap="char_nylon_black", case="chrome")                 # OF-G3


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
    _wrist_keys(kit, "R")                                                           # GH-G3: display-case keys


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
    n.front_item(kit, 0.060, 1.300, (0.008, 0.075, 0.007), "polymer_black", lift=0.002)    # GH-G3: a pen and
    n.front_item(kit, 0.075, 1.295, (0.005, 0.085, 0.003), "char_satin_gold", lift=0.002)  # gold tweezers at the bib


def blazer(kit: Kit) -> None:
    k = kit.k
    suit(kit, "char_blazer_navy", "char_shirt_blue", None, shoe_mat="char_shoe_brown", trouser_mat="char_slacks_grey",
         hem_z=0.79, button_z=1.05)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.10 * k, 0.2, 1.36 * k)), k=k))


# ---------------------------------------------------------------------------------------------
# D-115: Vossberg Jewelers staff
# ---------------------------------------------------------------------------------------------
def _z(kit: Kit) -> tuple[float, float]:
    """(belt z, shirt tuck z)."""
    belt_z = kit.fit.ring_centre("hips").z + 0.035 * kit.k
    return belt_z, belt_z - 0.02 * kit.k


def _necklace(kit: Kit, mat: str, drop: float = 0.055, half_w: float = 0.052) -> None:
    """Fine chain in the open collar: an arc over the chest from under the collar on either side,
    dipping ``drop`` below the neck base, with a small round pendant at the bottom."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    nk = g.Neck(fit)
    neck_z = nk.point(0.0, 0.0).z
    cy = fit.ring_centre("chest").y
    path = []
    for i in range(15):
        u = -1.0 + 2.0 * i / 14
        z = neck_z + 0.004 * k - drop * k * (1.0 - u * u) ** 1.2
        hit = hull.cast(Vector((u * half_w * k, 0.6, z)), Vector((0, -1, 0)), 1.2)
        q = hit[0] if hit[0] is not None else Vector((u * half_w * k, cy + 0.11 * k, z))
        path.append(o.push_out(q, hull, 0.0022 * k))
    m = Mesh()
    o.tube(m, path, 0.0011 * k, mat, sides=4)
    bot = path[7]
    gr = o.Gear()
    gr.cyl(0.0055 * k, 0.0025 * k, centre=(0, 0, 0.0012 * k), axis="Z", segs=10, mat=mat)
    gr.bevel(0.0008 * k, 1, 30.0)
    pc = bot - Vector((0.0, 0.0, 0.0065 * k))
    pc = o.push_out(pc, hull, 0.0012 * k)
    m.extend(gr.to_mesh(o.frame_from(pc, Vector((0.0, 1.0, 0.1))), anchor=pc))
    kit.add_gear(m, layer=False)


def _glasses_up(fit, mat: str, tilt_deg: float = 64.0, clear: float = 0.0035) -> Mesh:
    """Reading glasses pushed up onto the hair: ``gk.glasses`` turned up about the ear line, then
    lifted radially so every point clears the hair surface by ``clear``."""
    k = fit.k
    m = gk.glasses(fit, mat)
    c = fit.head_centre()
    eye = fit.eye_centre()
    piv = Vector((0.0, c.y - 0.010 * k, eye.z - 0.006 * k))
    rot = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(tilt_deg), 4, "X") @ Matrix.Translation(-piv)
    for i, v in enumerate(m.v):
        q = rot @ v
        d = q - c
        az = math.atan2(d.x, d.y)
        el = math.atan2(d.z, math.hypot(d.x, d.y))
        r = sg.head_radius(fit, az, el, c)
        if r is not None and d.length < r + clear * k:
            q = c + d.normalized() * (r + clear * k)
        m.v[i] = q
    return m


def vossberg(kit: Kit) -> None:
    """Greta Vossberg (owner-manager): the boss, not the floor staff's black."""
    fit, k = kit.fit, kit.k
    belt_z, tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.shirt(kit, "char_silk_ivory", tuck, point_len=0.05, spread=0.40)
    n.trousers(kit, PLUM, sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, PLUM, 0.83 * k, 1.05 * k, button_mat="brass", lapel_w=0.052, neck_w=0.092, flare=0.06)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    _necklace(kit, "brass")
    n.watch(kit, "L", strap="brass", case="brass")
    kit.add_head(cg.chignon(fit, "char_hair_grey", size=0.9))
    kit.add_head(cg.earrings(fit, "brass", drop=False))
    kit.add_head(_glasses_up(fit, "brass"))
    _brooch(kit, -0.088, 1.355, "char_satin_gold", "char_tie_burgundy")              # GH-G3: a garnet brooch
    kit.notes["look"] = ("Greta Vossberg (owner-manager): deep-plum trouser suit with brass buttons, cream silk "
                         "blouse open at the collar, gold chain + pendant, gold studs, gold reading glasses pushed "
                         "up on silver hair (chignon), gold watch, black low heels")


def sales_b(kit: Kit) -> None:
    """Second associate: the boutique's black with the brass badge (a man, so never a twin of ``sales``)."""
    k = kit.k
    belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_black", tuck, point_len=0.054, spread=0.34)
    n.trousers(kit, "char_suit_dark", sh, belt_z + 0.022 * k, hem_r=0.055)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_suit_dark", 0.80 * k, 1.05 * k, button_mat="char_button_dark", lapel_w=0.05,
                         neck_w=0.085, flare=0.05)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.335 * k)), k=k))
    kit.add_gear(cg.lapel_pin(hull, Vector((-0.095 * k, 0.3, 1.36 * k)), "brass", k=k))
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    crew._pocket_square(kit, "char_silk_ivory", Hull(kit.fit, [jk]))                  # GH-G3: an ivory pocket square
    kit.notes["look"] = ("Sales associate B: fitted near-black suit, black shirt open at the collar (no tie), brass "
                         "name badge and lapel pin (the boutique's brass), black shoes, watch")


def clerk(kit: Kit) -> None:
    """Upstairs admin clerk: office wear (cardigan + lanyard), not the shop floor's black."""
    fit, k = kit.fit, kit.k
    belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.054, spread=0.32)
    n.trousers(kit, "char_chino_navy", sh, belt_z + 0.022 * k, hem_r=0.060)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_knit_oat", 0.78 * k, 1.03 * k, button_mat="char_button_dark", lapel_w=0.03,
                         neck_w=0.09, flare=0.09, chest_welt=False, base=0.013)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.lanyard(kit, "char_dress_black", "char_medic_white", card_z=1.17, band_mat="brass")
    n.watch(kit, "L", strap="leather_dark", case="chrome")
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    n.front_item(kit, -0.092, 1.290, (0.008, 0.070, 0.007), "char_denim", lift=0.003)      # GH-G3: a blue pen
    kit.notes["look"] = ("Admin clerk (upstairs office): oatmeal knit cardigan over a white shirt, navy chinos, brown "
                         "shoes, black glasses, watch, staff lanyard (black strap, brass band, white ID card)")


_looks = {"coat": coat, "gilet": gilet, "dress": dress, "apron": apron, "blazer": blazer, "vossberg": vossberg,
          "sales_b": sales_b, "clerk": clerk}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
