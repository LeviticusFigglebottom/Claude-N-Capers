"""Ostrander Federal cast (D3-01, D-075): a big bank by day (``ostrander_federal``, P5; Big Bank analogue).

Roles follow the D3-01 brief and the D-075 G0 additions (the gallery-level bank officers). D-063 reserved the Night Deposit
tellers for this heist, so the bank staff keep that bank livery (slate green / marble cream / bank
red, the keyhole badge); the new manager wears it too so the staff read as one bank. Daytime
customers are ordinary civilians in daylight colours.

* ``char_bank_manager``: the **day** manager (the keycard carrier), distinct from the night manager
  (an older woman in a red skirt suit): a man in his 40s in a navy three-piece suit (navy waistcoat),
  cream shirt, bank-red tie, a bank-red lanyard with a white keycard, silver glasses, a watch, a
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

import _crew_heisters as crew
import _gear_kit as gk
import _npc as n
import _outfit_garments as g
import _p5 as p5
from _outfit import Vector
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
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.345 * k)), Vector((0, 1, 0.1)), 0.024, 0.028, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    n.lanyard(kit, RED, "char_medic_white", card_z=1.15, band_mat=SLATE)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    kit.notes["look"] = ("Day manager (keycard carrier): navy three-piece suit, cream shirt, bank-red tie, bank-red "
                         "lanyard + white keycard, keyhole lapel badge, brass name tag, silver glasses, watch")
    kit.notes["prop_note"] = "keycard on the lanyard is skinned (Gear); a hand-held keycard prop goes at HandR/Socket"


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
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.34 * k)), Vector((0, 1, 0.1)), 0.022, 0.026, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    n.lanyard(kit, RED, "char_medic_white", card_z=1.17, band_mat=SLATE)
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
    kit.notes["look"] = ("Parent customer: olive nylon bomber over a cream crew knit, jeans, white trainers, navy "
                         "daypack on both shoulders")


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
          "vip": vip}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
