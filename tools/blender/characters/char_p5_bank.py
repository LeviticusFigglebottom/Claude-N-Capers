"""Ostrander Federal cast (D3-01, D-075): a big bank by day (``ostrander_federal``, P5; Big Bank analogue).

Roles follow the D3-01 brief and the D-075 G0 additions (the gallery-level bank officers). D-063 reserved the Night Deposit
tellers for this heist, so the bank staff keep that bank livery (slate green / marble cream / bank
red, the keyhole badge); the new manager wears it too so the staff read as one bank. Daytime
customers are ordinary civilians in daylight colours.

* ``char_bank_manager``: the **day** manager (the keycard carrier), distinct from the night manager
  (an older woman in a red skirt suit): a man in his 40s in a navy three-piece suit (navy waistcoat),
  cream shirt, bank-red tie, a white keycard on a waistcoat reel (OF-G3), silver glasses, a watch, a
  brass name tag and the keyhole bank badge on the lapel.
* ``char_bank_officer`` (D-075): a loan/accounts officer on the gallery level: a woman in her 50s in a
  grey worsted skirt suit over a cream band-collar blouse, the bank's red lanyard with the ID badge,
  a keyhole lapel badge, a brass name tag, black low heels.
* ``char_bank_officer_b`` (D-075): a younger accounts officer in shirt sleeves: a pale blue shirt open
  at the collar (no tie, sleeves rolled), the grey suit trousers and a black belt, the bank lanyard
  and ID badge, a watch, black glasses.
* ``char_bank_customer``: business-casual customer: an unstructured grey blazer over an open-collar
  white shirt, navy chinos, brown shoes, a watch.
* ``char_bank_customer_b``: a parent on an errand: an olive nylon bomber zipped over a cream crew
  knit, jeans, white trainers and a navy daypack on both shoulders.
* OF-D1 (D-130: +35 % civilians at Cataclysm, so the faces don't repeat). Officers, the same grey worsted family:
  ``char_bank_officer_c``: a man about 60, light skin, grey hair: grey two-piece suit, white shirt, burgundy tie, the
  bank lanyard, keyhole lapel badge, brass name tag, watch.
  ``char_bank_officer_d``: a woman in her 30s, deep skin, dark hair in a bun: grey waistcoat and trousers over a white
  shirt (no jacket), the bank lanyard, low heels, watch, black glasses.
  Customers and plaza pedestrians, a weekday-afternoon city-bank crowd:
  ``char_bank_customer_c``: office worker, a woman in her 40s: navy knee pencil skirt, white blouse, open mustard
  cardigan, black low heels, blue office lanyard, gold watch.
  ``char_bank_customer_d``: bike courier, a young man: black nylon bomber over a graphite knit, charcoal work trousers,
  grey trainers, orange cap and a big orange messenger bag.
  ``char_bank_customer_e``: retiree, a woman in her late 70s: long heather wool coat over a navy knit, cream scarf, grey
  slacks, brown shoes, grey hair in a bun, silver glasses.
  ``char_bank_customer_f``: office worker, a tall man about 45: belted double-breasted stone trench coat (knee) over a
  pale blue shirt, navy suit trousers, brown shoes, black glasses.
  ``char_bank_customer_g``: student, a young woman: cream hoodie (hood down), jeans, white trainers, black over-ear
  headphones on, olive messenger bag.
  ``char_bank_customer_h``: tradesperson, a heavy-set man about 55, bald with stubble: tan canvas chore jacket over a
  grey crew knit, navy work trousers, brown work boots, watch.
  ``char_bank_customer_i``: parent, a man in his 30s, blond: maroon crew knit, khaki chinos, grey trainers, watch.
  ``char_bank_customer_j``: a woman in her 60s, deep skin, short grey hair: brown suit jacket over a cream roll-neck,
  black trousers, low heels, silver drop earrings, black glasses.
* ``char_bank_vip_client`` (OF-D1, rare ``vip_client``, ``civ_vip``, seated in the SD hall): a high-value private
  client, an older man (about 70, light skin, silver side-parted hair): a single-breasted camel overcoat to below the
  knee (open, no belt: the seated drape) over a charcoal-grey suit (waistcoat), white shirt and burgundy tie, a sapphire
  silk scarf hanging open, dark brown leather gloves, brown oxfords and a gold watch on the left wrist.
* Reused (listed in ``world/characters/p5_cast.json``, not rebuilt): tellers ``npc_bank_teller`` /
  ``_b`` (D-063), customers ``civilian_customer_a`` (camel coat) / ``_b`` (the elderly customer: grey
  hair, gilet), guards ``security_officer`` / ``_b`` (Halden Security day shift, peaked cap) and
  ``npc_bank_guard`` (Halden, bare-headed; also the camera operator).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses).
No blend shapes (baked at the params below).
"""

import math

import _contact_gear as cg
import _crew_heisters as crew
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
import _p5 as p5
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_bank_manager": {"height": 1.83, "build": 0.55, "gender": 0.0, "age": 0.5, "skin": 6, "beard_shadow": 0.4,
                          "hair": "short", "hair_color": "dark", "look": "manager"},
    "char_bank_officer": {"height": 1.68, "build": 0.5, "gender": 1.0, "age": 0.6, "skin": 2,
                          "hair": "bob", "hair_color": "dark", "look": "officer"},
    "char_bank_officer_b": {"height": 1.79, "build": 0.42, "gender": 0.0, "age": 0.25, "skin": 4,
                            "beard_shadow": 0.5, "hair": "side_part", "hair_color": "dark", "look": "officer_b"},
    "char_bank_customer": {"height": 1.77, "build": 0.45, "gender": 0.0, "age": 0.35, "skin": 3,
                           "beard_shadow": 0.6, "hair": "short", "hair_color": "brown", "look": "business"},
    "char_bank_customer_b": {"height": 1.68, "build": 0.45, "gender": 1.0, "age": 0.35, "skin": 5,
                             "hair": "side_part", "hair_color": "brown", "look": "parent"},
    # OF-D1: officers c-d, customers c-j
    "char_bank_officer_c": {"height": 1.77, "build": 0.7, "gender": 0.0, "age": 0.72, "skin": 2,
                            "beard_shadow": 0.3, "hair": "short", "hair_color": "grey", "look": "officer_c"},
    "char_bank_officer_d": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.3, "skin": 6,
                            "hair": "side_part", "hair_color": "dark", "look": "officer_d"},
    "char_bank_customer_c": {"height": 1.69, "build": 0.5, "gender": 1.0, "age": 0.45, "skin": 4,
                             "hair": "bob", "hair_color": "brown", "look": "office_skirt"},
    "char_bank_customer_d": {"height": 1.76, "build": 0.3, "gender": 0.0, "age": 0.12, "skin": 6,
                             "beard_shadow": 0.2, "hair": "buzz", "hair_color": "dark", "look": "courier"},
    "char_bank_customer_e": {"height": 1.68, "build": 0.6, "gender": 1.0, "age": 0.92, "skin": 2,
                             "hair": "side_part", "hair_color": "grey", "look": "retiree"},
    "char_bank_customer_f": {"height": 1.85, "build": 0.5, "gender": 0.0, "age": 0.5, "skin": 1,
                             "beard_shadow": 0.3, "hair": "side_part", "hair_color": "brown", "look": "trench"},
    "char_bank_customer_g": {"height": 1.69, "build": 0.3, "gender": 1.0, "age": 0.08, "skin": 5,
                             "hair": "bob", "hair_color": "dark", "look": "student"},
    "char_bank_customer_h": {"height": 1.79, "build": 0.85, "gender": 0.0, "age": 0.62, "skin": 3,
                             "beard_shadow": 0.8, "hair": "bald", "hair_color": "grey", "look": "trades"},
    "char_bank_customer_i": {"height": 1.75, "build": 0.55, "gender": 0.0, "age": 0.32, "skin": 2,
                             "beard_shadow": 0.5, "hair": "short", "hair_color": "blond", "look": "parent_knit"},
    "char_bank_customer_j": {"height": 1.72, "build": 0.45, "gender": 1.0, "age": 0.66, "skin": 5,
                             "hair": "short", "hair_color": "grey", "look": "rollneck"},
    # OF-D1 rare vip_client (civ_vip, sit in the SD hall)
    "char_bank_vip_client": {"height": 1.80, "build": 0.55, "gender": 0.0, "age": 0.8, "skin": 2, "beard_shadow": 0.25,
                             "hair": "side_part", "hair_color": "grey", "look": "vip"},
}

NAVY = "char_suit_navy"
SLATE = "char_bank_slate"
CREAM = "char_bank_cream"
RED = "char_bank_red"
GREY = "char_suit_grey"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _pen(kit: Kit, x: float, z: float) -> None:
    """G3: a pen clipped in a chest pocket at (x, z) (m before height scaling), the cap and clip showing."""
    k = kit.k
    hull = kit.hull()
    top = n._front_hit(hull, x * k, z * k, kit.fit.ring_centre("chest").y + 0.12 * k)
    pen = o.Gear()
    pen.cyl(0.0042 * k, 0.05 * k, centre=(0.0, -0.022 * k, 0.0), axis="Y", segs=8, mat="polymer_black")
    pen.box((-0.0012 * k, -0.032 * k, 0.003 * k), (0.0012 * k, 0.004 * k, 0.0055 * k), "char_metal_silver")
    mtx, loc = o.surface_frame(hull, top, Vector((0.0, 1.0, 0.0)), lift=0.004 * k)
    kit.add_gear(pen.to_mesh(mtx, anchor=loc))


def _key_fob(kit: Kit, card_z: float) -> None:
    """G3: a small key on a split ring hanging from the bottom of the lanyard card (``n.lanyard``'s card at card_z)."""
    k = kit.k
    hull = kit.hull()
    p = n._front_hit(hull, 0.0, (card_z - 0.058) * k, kit.fit.ring_centre("chest").y + 0.12 * k)
    key = o.Gear()
    key.cyl(0.008 * k, 0.002 * k, centre=(0.0, 0.010 * k, 0.003 * k), axis="Z", segs=12, mat="char_metal_silver")
    key.box((-0.0035 * k, -0.030 * k, 0.002 * k), (0.0035 * k, 0.004 * k, 0.004 * k), "brass")
    for i in range(3):                                                          # the bit's teeth
        y = -0.028 * k + i * 0.007 * k
        key.box((0.0035 * k, y, 0.002 * k), (0.0065 * k, y + 0.004 * k, 0.004 * k), "brass")
    mtx, loc = o.surface_frame(hull, p, Vector((0.0, 1.0, 0.05)), lift=0.006 * k)
    kit.add_gear(key.to_mesh(mtx, anchor=loc))


def _pencil_ear(kit: Kit, side: float = 1.0) -> None:
    """OF-G3: a carpenter's pencil tucked behind the ear (``side`` +1 = +x)."""
    fit, k = kit.fit, kit.k
    eye = fit.eye_centre()
    c = Vector((side * 0.082 * k, eye.y - 0.085 * k, eye.z + 0.012 * k))
    a, b = c + Vector((0.0, 0.05 * k, -0.012 * k)), c + Vector((0.0, -0.05 * k, 0.012 * k))
    m = Mesh()
    o.tube(m, [a, b], 0.0038 * k, "char_rubber_yellow", sides=6)
    kit.add_head(m)


def _hip_device(kit: Kit, over: Mesh, z: float, a_deg: float, size: tuple[float, float, float], mat: str) -> None:
    """OF-G3: a small device clipped at the waistband at angle ``a_deg`` (0 front, +90 the +x side)."""
    b = gk.Belt(kit.fit, Hull(kit.fit, [over], body_regions=set()), z, height=0.03, thick=0.004)
    w, h, d = size
    kit.add_gear(gk.pouch(b, math.radians(a_deg), w, h, d, mat))


def manager(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, CREAM, tuck, point_len=0.054)
    n.trousers(kit, NAVY, sh, belt_z + 0.022 * k)
    n.tie(kit, RED, belt_z + 0.03 * k, width=0.074)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, NAVY, hips_z - 0.01 * k, 1.13 * k, point=0.05, neck_w=0.07, buttons=5,
                       button_mat="char_button_dark")
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, NAVY, 0.80 * k, 1.04 * k, button_mat="char_button_dark", lapel_w=0.056, neck_w=0.08,
                         flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k, mat="char_satin_gold"))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.345 * k)), Vector((0, 1, 0.1)), 0.024, 0.028, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    # OF-G3: the keycard rides a retractable reel clipped low on the waistcoat, not a lanyard: the red lanyard straps
    # either side of the bank-red tie read as one red wedge in the narrow waistcoat V (the LEAD's review)
    n.front_item(kit, 0.075, 1.09, (0.020, 0.020, 0.008), "char_metal_silver")       # the reel
    n.front_item(kit, 0.075, 1.035, (0.054, 0.084, 0.004), "char_medic_white")       # the keycard
    n.front_item(kit, 0.075, 1.055, (0.050, 0.016, 0.005), SLATE)                    # its bank band
    n.watch(kit, "L", strap="char_leather_black", case="brass")                   # G3: the heavier gold watch
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    hull = kit.hull()                                                             # G3: pocket square, tie bar
    cy = fit.ring_centre("chest").y
    kit.add_gear(gk.bar(hull, n._front_hit(hull, -0.115 * k, 1.27 * k, cy + 0.12 * k), Vector((0.0, 1.0, 0.0)),
                        0.048, 0.020, 0.006, "char_shirt_white", k=k))
    kit.add_gear(gk.bar(hull, n._front_hit(hull, 0.0, 1.235 * k, cy + 0.12 * k), Vector((0.0, 1.0, 0.0)), 0.045,
                        0.005, 0.003, "char_satin_gold", k=k))  # reads gold, not near-black
    kit.notes["look"] = ("Day manager (keycard carrier): navy three-piece suit, cream shirt, bank-red tie, white "
                         "keycard on a waistcoat reel, keyhole lapel badge, brass name tag, silver glasses, watch")
    kit.notes["prop_note"] = "keycard on the waistcoat reel is skinned (Gear); a hand-held keycard prop goes at HandR/Socket"


def officer(kit: Kit) -> None:
    k = kit.k
    hips_z, _belt_z, tuck = _z(kit)
    waist_z = kit.fit.ring_centre("waist").z
    n.shoes(kit, heel=True)
    n.shirt(kit, CREAM, tuck, collar="band")
    n.skirt(kit, GREY, waist_z + 0.01 * k, 0.47 * k, flare=0.05)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, GREY, 0.82 * k, 1.07 * k, button_mat="char_button_dark", lapel_w=0.05, neck_w=0.085,
                         flare=0.06)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k, mat="char_satin_gold"))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.34 * k)), Vector((0, 1, 0.1)), 0.022, 0.026, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    n.lanyard(kit, RED, "char_medic_white", card_z=1.17, band_mat=SLATE)
    _key_fob(kit, 1.17)                                                           # G3
    _pen(kit, 0.10, 1.295)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["look"] = ("Bank officer (gallery level): grey worsted skirt suit, cream band-collar blouse, the bank's "
                         "red lanyard + ID badge, keyhole lapel badge, brass name tag, black low heels")


def officer_b(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_blue", tuck, point_len=0.056, spread=0.34, sleeve=1.3, roll=0.006)
    tr = n.trousers(kit, GREY, sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z, mat="char_leather_black", buckle="chrome")
    n.lanyard(kit, RED, "char_medic_white", card_z=1.19, band_mat=SLATE)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.add_head(gk.glasses(kit.fit, "char_button_dark"))
    _key_fob(kit, 1.19)                                                           # G3
    _pen(kit, -0.09, 1.32)
    kit.notes["look"] = ("Bank officer (gallery level), shirt sleeves: pale blue shirt open at the collar (no tie, "
                         "sleeves rolled), grey suit trousers, black belt, the bank's red lanyard + ID badge, watch, "
                         "black glasses")


def business(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.056, spread=0.34)
    tr = n.trousers(kit, "char_chino_navy", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.belt(kit, tr, belt_z, mat="leather_dark", buckle="chrome")
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_blazer_grey", 0.79 * k, 1.06 * k, button_mat="char_button_dark", lapel_w=0.05,
                         neck_w=0.09, flare=0.06, base=0.010)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.watch(kit, "L", strap="leather_dark", case="chrome")
    n.front_item(kit, -0.105, 1.31, (0.075, 0.035, 0.004), "char_prop_paper")      # OF-G3: a bank envelope
    kit.notes["look"] = ("Business-casual customer: unstructured grey blazer, open-collar white shirt (no tie), navy "
                         "chinos, brown shoes and belt, watch")


def parent(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = g.shoes(fit, "char_sneaker_white", "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(sh)
    knit = g.knit_top(fit, kit.hull(), "char_knit_cream", hips_z - 0.02 * k, neck="crew", base=0.006)
    kit.add_soft(knit)
    n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.058)
    n0 = len(kit.soft.f)
    jk = crew.bomber(kit, "char_nylon_olive", "char_knit_graphite", "char_nylon_olive", hips_z - 0.01 * k, 1.30 * k,
                     neck_w=0.06)
    n.cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    p5.backpack(kit, "char_gilet_navy", "char_tac_gear")
    n.front_item(kit, 0.11, 1.24, (0.014, 0.05, 0.010), "char_rubber_yellow", lift=0.012)   # OF-G3: carabiner
    n.front_item(kit, 0.11, 1.20, (0.010, 0.04, 0.006), "char_metal_silver", lift=0.014)    # keys
    kit.notes["look"] = ("Parent customer: olive nylon bomber over a cream crew knit, jeans, white trainers, navy "
                         "daypack on both shoulders")


# ---------------------------------------------------------------------------------------------
# OF-D1: officers c-d (the grey worsted family) and customers c-j (a weekday-afternoon crowd)
# ---------------------------------------------------------------------------------------------
def _trainers(kit: Kit, mat: str = "char_sneaker_grey") -> Mesh:
    sh = g.shoes(kit.fit, mat, "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(sh)
    return sh


def officer_c(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.056)
    n.trousers(kit, GREY, sh, belt_z + 0.022 * k)
    n.tie(kit, "char_tie_burgundy", belt_z + 0.03 * k, width=0.074)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, GREY, 0.80 * k, 1.04 * k, button_mat="char_button_dark", lapel_w=0.056, neck_w=0.08,
                         flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k, mat="char_satin_gold"))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.345 * k)), Vector((0, 1, 0.1)), 0.022, 0.026, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    n.lanyard(kit, RED, "char_medic_white", card_z=1.15, band_mat=SLATE)
    n.watch(kit, "L", strap="char_leather_black", case="brass")
    _key_fob(kit, 1.15)                                                           # G3
    _pen(kit, 0.10, 1.295)
    kit.notes["look"] = ("Bank officer (OF-D1): a man about 60, grey hair; grey worsted two-piece suit, white shirt, "
                         "burgundy tie, the bank's red lanyard + ID badge, keyhole lapel badge, brass name tag, watch")


def officer_d(kit: Kit) -> None:
    k = kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05, spread=0.38)
    n.trousers(kit, GREY, sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, GREY, hips_z - 0.01 * k, 1.12 * k, point=0.045, neck_w=0.07, buttons=4)
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    n.lanyard(kit, RED, "char_medic_white", card_z=1.17, band_mat=SLATE)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    _key_fob(kit, 1.17)                                                           # G3
    _pen(kit, -0.09, 1.30)
    kit.add_head(cg.chignon(kit.fit, "char_hair_dark", size=0.85))
    kit.add_head(gk.glasses(kit.fit, "char_button_dark"))
    kit.notes["look"] = ("Bank officer (OF-D1): a woman in her 30s, dark hair in a bun; grey worsted waistcoat and "
                         "trousers over a white shirt (no jacket), the bank's red lanyard + ID badge, low heels, "
                         "watch, black glasses")


def office_skirt(kit: Kit) -> None:
    k = kit.k
    _hips_z, _belt_z, tuck = _z(kit)
    waist_z = kit.fit.ring_centre("waist").z
    n.shoes(kit, heel=True)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05, spread=0.36)
    n.skirt(kit, "char_skirt_navy", waist_z + 0.01 * k, 0.48 * k, flare=0.04)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_knit_mustard", 0.80 * k, 1.03 * k, button_mat="char_button_dark", lapel_w=0.03,
                         neck_w=0.09, flare=0.09, chest_welt=False, base=0.013)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.18)
    n.watch(kit, "L", strap="brass", case="brass")
    n.bead_necklace(kit, "char_shirt_white")                                     # OF-G3
    kit.notes["look"] = ("Office worker customer (OF-D1): navy knee pencil skirt, white blouse, open mustard cardigan, "
                         "black low heels, blue office lanyard + card, gold watch")


def courier(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_work_charcoal", sh, belt_z + 0.022 * k, hem_r=0.060)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_graphite", hips_z - 0.02 * k, neck="crew", base=0.006))
    n0 = len(kit.soft.f)
    jk = crew.bomber(kit, "char_nylon_black", "char_knit_graphite", "char_nylon_black", hips_z - 0.01 * k, 1.30 * k,
                     neck_w=0.06)
    n.cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    n.messenger_bag(kit, "char_hivis_orange", "char_nylon_black", a_deg=-120.0, z=0.98, w=0.18, h=0.14, d=0.09)
    _hip_device(kit, kit.soft, hips_z + 0.05 * k, 60.0, (0.06, 0.12, 0.035), "char_rubber_yellow")  # OF-G3 scanner
    cap, _ring = p5.ball_cap(fit, "char_hivis_orange", peak_mat="char_hivis_orange", button_mat="char_nylon_black")
    kit.add_head(cap)
    kit.notes["look"] = ("Bike courier (OF-D1): black nylon bomber over a graphite knit, charcoal work trousers, grey "
                         "trainers, orange cap, big orange messenger bag on a black strap")


def retiree(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    shoes = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.09, base=0.006)
    kit.add_soft(shoes)
    n.trousers(kit, "char_slacks_grey", shoes, hips_z + 0.05 * k, hem_r=0.056)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_navy", hips_z - 0.02 * k, neck="crew", base=0.006))
    crew.scarf(kit, "char_knit_cream", 1.06 * k)
    n0 = len(kit.soft.f)
    jk, _info = g.jacket(fit, kit.hull(), "char_coat_heather", 0.47 * k, 1.05 * k, neck_w=0.075, base=0.016,
                         flare=0.11, open_below=0.05, lapel_w=0.06, sleeve=1.97, keep_shape=0.4)
    kit.add_soft(jk)
    jh = Hull(fit, [jk])
    gear = Mesh()
    for z in (1.05, 0.93, 0.81):
        gear.extend(gk.button(jh, Vector((0.012 * k, 0.3, z * k - 0.012 * k)), "char_button_dark", r=0.011, k=k,
                              thick=0.004))
    kit.add_gear(gear)
    n.cull_under(kit, n0, jk, "faces_hidden_by_coat")
    kit.add_head(cg.chignon(fit, "char_hair_grey", size=0.8))
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    n.glasses_cord(kit)                                                          # OF-G3
    kit.notes["look"] = ("Retiree customer (OF-D1): long heather wool coat (below the knee) over a navy knit, cream "
                         "scarf, grey slacks, brown shoes, grey hair in a bun, silver glasses")


def trench(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_blue", tuck, point_len=0.056, spread=0.34)
    tr = n.trousers(kit, NAVY, sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z, mat="leather_dark", buckle="chrome")
    n0 = len(kit.soft.f)
    coat, _info = n.jacket(kit, "char_coat_stone", 0.50 * k, 1.00 * k, neck_w=0.095, lapel_w=0.075, flare=0.12,
                           base=0.015, open_below=0.06, sleeve=1.93, double=True)
    n.cull_under(kit, n0, coat, "faces_hidden_by_coat")
    waist = fit.ring_centre("waist").z
    cb = gk.Belt(fit, Hull(fit, [coat], body_regions=set()), waist, height=0.04, thick=0.004, drop=0.0)
    kit.add_soft(cb.mesh("char_coat_stone"))
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    n.front_item(kit, 0.14, 0.95, (0.030, 0.16, 0.030), "char_prop_paper", lift=0.010)   # OF-G3: a newspaper
    kit.notes["look"] = ("Office worker customer (OF-D1): belted double-breasted stone trench coat to the knee over a "
                         "pale blue shirt, navy suit trousers, brown shoes and belt, black glasses")


def student(kit: Kit) -> None:
    k = kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit, "char_sneaker_white")
    n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.hoodie(kit, "char_hoodie_cream", hips_z - 0.06 * k, string_mat="char_knit_graphite")
    n.messenger_bag(kit, "char_nylon_olive", "char_nylon_olive", a_deg=-120.0, z=0.97)
    p5.headphones_on(kit, "polymer_black", "rubber_black")
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.16)              # OF-G3: a campus ID
    kit.notes["look"] = ("Student customer (OF-D1): cream hoodie (hood down), jeans, white trainers, black over-ear "
                         "headphones on, olive messenger bag")


def trades(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.006, boot=True)
    kit.add_soft(sh)
    n.trousers(kit, "char_work_navy", sh, belt_z + 0.022 * k, hem_r=0.064)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_grey", hips_z - 0.02 * k, neck="crew", base=0.006))
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_canvas_tan", 0.80 * k, 1.12 * k, button_mat="char_button_dark", lapel_w=0.035,
                         neck_w=0.075, flare=0.07, chest_welt=False, base=0.014)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.watch(kit, "L", strap="char_nylon_black", case="chrome")
    _pencil_ear(kit, 1.0)                                                       # OF-G3
    kit.notes["look"] = ("Tradesperson customer (OF-D1): tan canvas chore jacket over a grey crew knit, navy work "
                         "trousers, brown work boots, watch")


def parent_knit(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_chino_khaki", sh, belt_z + 0.022 * k, hem_r=0.060)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_fleece_maroon", hips_z - 0.02 * k, neck="crew", base=0.007))
    n.watch(kit, "L", strap="char_nylon_black", case="chrome")
    n.messenger_bag(kit, "char_canvas_tan", "char_canvas_tan", a_deg=-55.0, z=0.95, w=0.21, h=0.26, d=0.05)   # tote, on
    # the hip ahead of the side seam (no back depth: cower walls, chair backs; test_cower_offsets)
    kit.notes["look"] = "Parent customer (OF-D1): maroon crew knit, khaki chinos, grey trainers, watch"


def rollneck(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.054)
    kit.add_soft(g.knit_top(fit, kit.hull(), "char_knit_cream", hips_z - 0.02 * k, neck="roll", base=0.006))
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_suit_brown", 0.79 * k, 1.04 * k, button_mat="char_button_dark", lapel_w=0.05,
                         neck_w=0.10, flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_head(cg.earrings(fit, "chrome", drop=True))
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    n.front_item(kit, -0.10, 1.33, (0.022, 0.022, 0.006), "brass")               # OF-G3: a brooch
    n.watch(kit, "L", strap="leather_dark", case="brass")
    kit.notes["look"] = ("Customer (OF-D1): a woman in her 60s, short grey hair; brown suit jacket over a cream "
                         "roll-neck, black trousers, low heels, silver drop earrings, black glasses")


def _drop_faces(m, start: int, pred) -> None:
    """Remove the faces from index ``start`` on whose centroid matches ``pred`` (unused vertices stay)."""
    keep = [i for i in range(len(m.f)) if i < start or not pred(sum((m.v[j] for j in m.f[i]), Vector()) / len(m.f[i]))]
    m.f = [m.f[i] for i in keep]
    m.m = [m.m[i] for i in keep]


def vip(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.054)
    n.trousers(kit, GREY, sh, belt_z + 0.022 * k)
    n.tie(kit, "char_tie_burgundy", belt_z + 0.03 * k, width=0.072)
    n.watch(kit, "L", strap="leather_dark", case="brass")
    kit.add_soft(g.gloves(fit, "leather_dark", cuff_len=0.05))
    # the suit's waistcoat, not its jacket, under the overcoat, and without its back panel (hidden by the coat): every
    # layer behind the chest pushed the coat's back through the chair back seated (check_seated_clip desk_work, Seat
    # 0.12)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, GREY, hips_z - 0.01 * k, 1.13 * k, point=0.05, neck_w=0.07, buttons=5,
                       button_mat="char_button_dark")
    added = len(kit.soft.f) - n0
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    cy = fit.ring_centre("chest").y

    def back(c: Vector) -> bool:
        return c.y < cy - 0.03 * k

    _drop_faces(kit.soft, len(kit.soft.f) - added, back)
    g.delete_faces(vest, back)   # the hull the coat is lofted over
    crew.scarf(kit, "char_satin_sapphire", 1.00 * k)   # not ivory: it vanished on the white shirt
    n0 = len(kit.soft.f)
    # flare / base kept modest: the coat's back skirt must clear the chair back seated (check_seated_clip, Seat 0.12)
    coat, _info = n.jacket(kit, "char_coat_camel", 0.46 * k, 0.99 * k, neck_w=0.100, lapel_w=0.074, flare=0.06,
                           base=0.010, open_below=0.06, sleeve=1.93, buttons=False, chest_welt=False)
    n.cull_under(kit, n0, coat, "faces_hidden_by_coat")
    kit.notes["look"] = ("VIP private client (OF-D1 civ_vip): open camel overcoat below the knee over a charcoal-grey "
                         "suit waistcoat and trousers, white shirt, burgundy tie, sapphire silk scarf, dark brown leather "
                         "gloves, brown oxfords, gold watch (left); about 70, silver side-parted hair")


_looks = {"manager": manager, "officer": officer, "officer_b": officer_b, "business": business, "parent": parent,
          "officer_c": officer_c, "officer_d": officer_d, "office_skirt": office_skirt, "courier": courier,
          "retiree": retiree, "trench": trench, "student": student, "trades": trades, "parent_knit": parent_knit,
          "rollneck": rollneck, "vip": vip}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
