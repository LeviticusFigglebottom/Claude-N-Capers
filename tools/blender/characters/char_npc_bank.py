"""Night Deposit NPCs: Harbor Savings & Loan, Pier District branch, at night (D2-02).

Bank livery from the heist palette (style guide §3: slate green ``#3F5A52``, marble cream
``#D9D2C2``, bank red ``#9E2B25``), so the staff read as the bank's own and never as the P1
Glasshouse civilians (camel, navy, black):

* ``char_npc_bank_teller``: young woman, cream blouse with a stand collar, slate-green tailored
  waistcoat, bank-red neckerchief, dark slate knee skirt, black low heels, brown bob, name badge.
* ``char_npc_bank_teller_b``: middle-aged man, cream shirt, bank-red tie, slate knit sweater vest,
  dark slate trousers, silver glasses, name badge (the gender/skin/age mix of the teller pair).
* OF-D1 (Ostrander Federal by day, D-130: 3 tellers + 1 rotating, x1.35 at Cataclysm, so five teller faces), the
  same teller uniform on other people:
  ``char_npc_bank_teller_c``: a young man (early 20s), light skin, short blond hair; teller_b's men's uniform (cream
  shirt, bank-red tie, slate knit sweater vest, dark slate trousers), no glasses.
  ``char_npc_bank_teller_d``: a woman about 50, mid-light skin, brown hair pinned up in a bun; the women's uniform
  (cream band-collar blouse, slate waistcoat, red neckerchief, dark slate knee skirt, low heels).
  ``char_npc_bank_teller_e``: a man about 40, deep skin, dark buzz cut and stubble; cream shirt, bank-red tie and the
  slate tailored waistcoat over dark slate trousers.
* ``char_npc_bank_night_manager``: older woman (grey bob), bank-red skirt suit over a cream blouse,
  dark slate skirt, brass name badge and keyhole lapel badge. She is the ``code_on_manager`` carrier.
* ``char_npc_bank_cleaner``: night cleaner (contractor), grey long-sleeve top under a blue-grey
  tabard with a cream binding and a big front pocket, dark work trousers, yellow rubber gloves.
  The cart is a prop (not part of this asset). ``char_npc_bank_cleaner_b`` (D-130, ``civ_cleaner`` at Cataclysm:
  a second cleaner, never a twin): same contractor uniform; a woman about 50, mid skin, brown hair pinned up in a
  bun.
* ``char_npc_bank_guard``: the contracted **Halden Security** night-shift guard (D-063; it also
  serves as the seated camera operator). Halden livery as on ``char_security_officer`` (pale
  steel-blue ``#8E9DAE`` shirt, charcoal tie and trousers, gold braid, burgundy shield patch with a
  gold "H" on the left sleeve, gold-rimmed burgundy chest badge, gold name bar), but a distinct
  night variant: a charcoal V-neck sweater vest with charcoal epaulettes and gold bars over the
  long-sleeved shirt and tie (the steel-blue sleeves keep the Halden read at range), and
  bare-headed (no peaked cap). Duty belt with the radio (= the ``Hip`` seat where the pager rides),
  shoulder speaker-mic and coiled cable, torch, pouch.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses).
No blend shapes (baked at the params below).
"""

import math

import _cartel_gear as cgr
import _contact_gear as cg
import _gear_kit as gk
import _npc as n
import _outfit as o
from _outfit import Hull, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_npc_bank_teller": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 5, "hair": "bob",
                             "hair_color": "brown", "look": "teller"},
    "char_npc_bank_teller_b": {"height": 1.75, "build": 0.6, "gender": 0.0, "age": 0.6, "skin": 3, "beard_shadow": 0.4,
                               "hair": "side_part", "hair_color": "dark", "look": "teller_b"},
    # OF-D1: tellers c-e (Ostrander Federal day shift)
    "char_npc_bank_teller_c": {"height": 1.78, "build": 0.35, "gender": 0.0, "age": 0.15, "skin": 1,
                               "beard_shadow": 0.2, "hair": "short", "hair_color": "blond", "look": "teller_c"},
    "char_npc_bank_teller_d": {"height": 1.68, "build": 0.55, "gender": 1.0, "age": 0.55, "skin": 3,
                               "hair": "side_part", "hair_color": "brown", "look": "teller_d"},
    "char_npc_bank_teller_e": {"height": 1.73, "build": 0.5, "gender": 0.0, "age": 0.4, "skin": 6,
                               "beard_shadow": 0.6, "hair": "buzz", "hair_color": "dark", "look": "teller_e"},
    "char_npc_bank_night_manager": {"height": 1.71, "build": 0.45, "gender": 1.0, "age": 0.7, "skin": 1, "hair": "bob",
                                    "hair_color": "grey", "look": "manager"},
    "char_npc_bank_cleaner": {"height": 1.74, "build": 0.65, "gender": 0.0, "age": 0.45, "skin": 6, "beard_shadow": 0.8,
                              "hair": "buzz", "hair_color": "dark", "look": "cleaner"},
    "char_npc_bank_cleaner_b": {"height": 1.70, "build": 0.6, "gender": 1.0, "age": 0.5, "skin": 3,
                                "hair": "side_part", "hair_color": "brown", "look": "cleaner_b"},
    "char_npc_bank_guard": {"height": 1.82, "build": 0.6, "gender": 0.0, "age": 0.5, "skin": 4, "beard_shadow": 0.5,
                            "hair": "short", "hair_color": "dark", "look": "guard"},
}

SEC_SHIRT = "char_sec_shirt"
SEC_TROUSERS = "char_sec_trousers"
SEC_KNIT = "char_sec_knit"
CHARCOAL = "char_sec_charcoal"
BURGUNDY = "char_sec_burgundy"
GOLD = "brass"
SLATE = "char_bank_slate"
SLATE_DARK = "char_bank_slate_dark"
CREAM = "char_bank_cream"
RED = "char_bank_red"


def _z(kit: Kit) -> tuple[float, float, float]:
    """(hips z, belt z, shirt tuck z)."""
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _teller_g3(kit: Kit, tag_x: float, pin: bool = True) -> None:
    """G3 close-range detail for the tellers: the Ostrander keyhole pin beside the name tag, a pen clipped in the
    chest pocket on the other side and a steel watch. ``tag_x``: the name tag's x (m before height scaling)."""
    k = kit.k
    hull = kit.hull()
    cy = kit.fit.ring_centre("chest").y
    gear = o.Mesh()
    if pin:
        gear.extend(n.bank_badge(hull, n._front_hit(hull, tag_x * k, 1.355 * k, cy + 0.12 * k), Vector((0, 1, 0.1)),
                                 0.016, 0.019, k, rim="brass", fill=SLATE_DARK, glyph="brass", depth=0.003))
    pen_top = n._front_hit(hull, -tag_x * k, 1.345 * k, cy + 0.12 * k)
    pen = o.Gear()
    pen.cyl(0.0042 * k, 0.11 * k, centre=(0.0, -0.045 * k, 0.0), axis="Y", segs=8, mat="polymer_black")
    pen.box((-0.0012 * k, -0.035 * k, 0.003 * k), (0.0012 * k, 0.006 * k, 0.0055 * k), "char_metal_silver")  # clip
    mtx, loc = o.surface_frame(hull, pen_top, Vector((0.0, 1.0, 0.0)), lift=0.004 * k)
    gear.extend(pen.to_mesh(mtx, anchor=loc))
    kit.add_gear(gear)
    n.watch(kit, "L", strap="char_metal_silver", case="chrome")


def _pencil_in_bun(kit: Kit) -> None:
    """A yellow pencil pushed through the bun (teller_d)."""
    fit, k = kit.fit, kit.k
    c = fit.head_centre()
    top = fit.head_top()
    p = Vector((c.x, c.y - 0.085 * k, top - 0.045 * k))
    a, b = p + Vector((-0.091 * k, 0.0, 0.0325 * k)), p + Vector((0.0975 * k, 0.0, -0.026 * k))  # LEAD: +30 %
    m = o.Mesh()
    o.tube(m, [a, b], 0.0035 * k, "char_rubber_yellow", sides=6)
    o.tube(m, [b, b + (b - a).normalized() * 0.012 * k], 0.0036 * k, "char_bank_red", sides=6)
    kit.add_head(m)


def teller(kit: Kit) -> None:
    k = kit.k
    hips_z, _belt_z, tuck = _z(kit)
    waist_z = kit.fit.ring_centre("waist").z
    n.shoes(kit, heel=True)
    n.shirt(kit, CREAM, tuck, collar="band")
    n.skirt(kit, SLATE_DARK, waist_z + 0.01 * k, 0.47 * k, flare=0.05)
    n.waistcoat(kit, SLATE, hips_z - 0.005 * k, 1.17 * k, point=0.045, neck_w=0.065, buttons=4)
    n.neckerchief(kit, RED, side=1.0)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.085 * k, 0.2, 1.31 * k)), k=k))
    _teller_g3(kit, 0.085)


def teller_b(kit: Kit) -> None:
    k = kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, CREAM, tuck)
    tr = n.trousers(kit, SLATE_DARK, sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z)
    n.tie(kit, RED, belt_z + 0.03 * k, width=0.07)
    n.knit_vest(kit, "char_knit_slate", hips_z - 0.01 * k, 1.13 * k)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.09 * k, 0.2, 1.33 * k)), k=k))
    kit.add_head(gk.glasses(kit.fit, "char_metal_silver"))
    _teller_g3(kit, -0.09)
    n.glasses_cord(kit)


def teller_c(kit: Kit) -> None:
    """OF-D1: teller_b's men's uniform on a young man (no glasses)."""
    k = kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, CREAM, tuck)
    tr = n.trousers(kit, SLATE_DARK, sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z)
    n.tie(kit, RED, belt_z + 0.03 * k, width=0.07)
    n.knit_vest(kit, "char_knit_slate", hips_z - 0.01 * k, 1.13 * k)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((-0.09 * k, 0.2, 1.33 * k)), k=k))
    _teller_g3(kit, -0.09)
    kit.notes["look"] = ("Teller (OF-D1): a young man, light skin, short blond hair; cream shirt, bank-red tie, slate "
                         "knit sweater vest, dark slate trousers, black belt, name badge")


def teller_d(kit: Kit) -> None:
    """OF-D1: the women's teller uniform on a woman about 50 with her hair in a bun."""
    teller(kit)
    kit.add_head(cg.chignon(kit.fit, "char_hair_brown", size=0.9))
    _pencil_in_bun(kit)
    kit.notes["look"] = ("Teller (OF-D1): a woman about 50, mid-light skin, brown hair pinned up in a bun; cream "
                         "band-collar blouse, slate waistcoat, bank-red neckerchief, dark slate knee skirt, low heels, "
                         "name badge")


def teller_e(kit: Kit) -> None:
    """OF-D1: cream shirt, red tie and the slate tailored waistcoat over the slate trousers (a man about 40)."""
    k = kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, CREAM, tuck, point_len=0.054)
    n.trousers(kit, SLATE_DARK, sh, belt_z + 0.022 * k)
    n.tie(kit, RED, belt_z + 0.03 * k, width=0.072)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, SLATE, hips_z - 0.01 * k, 1.13 * k, point=0.05, neck_w=0.068, buttons=5)
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.09 * k, 0.2, 1.32 * k)), k=k))
    kit.add_gear(n.bank_badge(kit.hull(), Vector((-0.09 * k, 0.2, 1.33 * k)), Vector((0, 1, 0.1)), 0.020, 0.024, k,
                              rim="brass", fill=SLATE_DARK, glyph="brass", depth=0.003))
    _teller_g3(kit, 0.09, pin=False)
    hull = kit.hull()                                                             # G3: a gold tie bar
    kit.add_gear(gk.bar(hull, n._front_hit(hull, 0.0, 1.24 * k, kit.fit.ring_centre("chest").y + 0.12 * k),
                        Vector((0.0, 1.0, 0.0)), 0.045, 0.005, 0.003, "brass", k=k))
    kit.notes["look"] = ("Teller (OF-D1): a man about 40, deep skin, dark buzz cut and stubble; cream shirt, bank-red "
                         "tie, slate tailored waistcoat, dark slate trousers, name badge, keyhole pin")


def manager(kit: Kit) -> None:
    k = kit.k
    _hips_z, _belt_z, tuck = _z(kit)
    waist_z = kit.fit.ring_centre("waist").z
    n.shoes(kit, heel=True)
    n.shirt(kit, CREAM, tuck, collar="fold", point_len=0.05)
    n.skirt(kit, SLATE_DARK, waist_z + 0.01 * k, 0.46 * k, flare=0.06)
    n.jacket(kit, RED, 0.80 * k, 1.06 * k, button_mat="brass", lapel_w=0.05, neck_w=0.08)
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.10 * k, 0.2, 1.33 * k)), k=k))
    kit.add_gear(n.bank_badge(hull, Vector((-0.10 * k, 0.2, 1.34 * k)), Vector((0, 1, 0.1)), 0.026, 0.030, k,
                              rim="brass", fill=SLATE, glyph="brass", depth=0.003))
    kit.add_head(gk.glasses(kit.fit, "char_satin_gold"))                            # ND-G3: gold reading glasses


def _cleaner(kit: Kit) -> None:
    n.cleaner_outfit(kit, "char_knit_grey", SLATE_DARK, "char_cleaner_tabard", CREAM, "char_rubber_yellow",
                     "char_bank_cream")


def cleaner(kit: Kit) -> None:
    _cleaner(kit)
    kit.add_head(cgr.beanie(kit.fit, "char_knit_navy"))                               # ND-G3: a night-shift beanie


def cleaner_b(kit: Kit) -> None:
    """D-130: the second night cleaner, same contractor uniform, another person (woman, brown bun)."""
    _cleaner(kit)
    kit.add_head(cg.chignon(kit.fit, "char_hair_brown", size=0.85))
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.20)                  # ND-G3: a contractor's pass
    kit.notes["look"] = ("Night cleaner, second face (D-130): same blue-grey tabard uniform; a woman about 50, mid "
                         "skin, brown hair pinned up in a bun")


def guard(kit: Kit) -> None:
    """Halden Security night-shift guard (D-063): the officer's shirt, tie, trousers and duty belt
    under a charcoal V-neck sweater vest with epaulettes, bare-headed."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    trousers_top = belt_z + 0.026 * k
    sh = n.shoes(kit)
    n.shirt(kit, SEC_SHIRT, tuck, collar="fold", point_len=0.055)
    tr = n.trousers(kit, SEC_TROUSERS, sh, trousers_top, hem_r=0.060)
    n.tie(kit, CHARCOAL, belt_z + 0.045 * k, width=0.074)
    n0 = len(kit.soft.f)
    vest = n.knit_vest(kit, SEC_KNIT, belt_z + 0.032 * k, 1.235 * k, neck_w=0.068)
    n.cull_under(kit, n0, vest, "faces_hidden_by_vest")
    n.epaulettes(kit, CHARCOAL, GOLD, bar_mat=GOLD)
    n.halden_patch(kit, "L", fill=BURGUNDY, rim=GOLD)
    hull = kit.hull()
    gear = o.Mesh()
    gear.extend(gk.shield_badge(hull, Vector((-0.090 * k, 0.2, 1.395 * k)), Vector((0, 1, 0.1)), 0.040, 0.046,
                                GOLD, BURGUNDY, k=k))
    gear.extend(gk.name_tag(hull, Vector((0.090 * k, 0.2, 1.36 * k)), k=k, mat=GOLD))
    kit.add_gear(gear)
    n.duty_belt(kit, tr, belt_z)
    # the same ring n.duty_belt samples (its Belt isn't returned), only to hang the key ring on
    kb = gk.Belt(kit.fit, Hull(kit.fit, [tr], body_regions=set()), belt_z, height=0.046, thick=0.006)
    kit.add_gear(gk.key_ring(kb, math.radians(-25.0)))                           # G3: key ring, watch
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["look"] = ("Halden night-shift guard: steel-blue shirt + charcoal tie under a charcoal V-neck "
                         "sweater vest, charcoal epaulettes with gold bars, burgundy/gold H sleeve patch, gold-rim "
                         "burgundy chest badge, duty belt (radio = Hip), bare-headed")


_looks = {"teller": teller, "teller_b": teller_b, "teller_c": teller_c, "teller_d": teller_d, "teller_e": teller_e,
          "manager": manager, "cleaner": cleaner, "cleaner_b": cleaner_b, "guard": guard}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
