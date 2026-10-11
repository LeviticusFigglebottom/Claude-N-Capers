"""Night Deposit NPCs: Harbor Savings & Loan, Pier District branch, at night (D2-02).

Bank livery from the heist palette (style guide §3: slate green ``#3F5A52``, marble cream
``#D9D2C2``, bank red ``#9E2B25``), so the staff read as the bank's own and never as the P1
Glasshouse civilians (camel, navy, black):

* ``char_npc_bank_teller``: young woman, cream blouse with a stand collar, slate-green tailored
  waistcoat, bank-red neckerchief, dark slate knee skirt, black low heels, brown bob, name badge.
* ``char_npc_bank_teller_b``: middle-aged man, cream shirt, bank-red tie, slate knit sweater vest,
  dark slate trousers, silver glasses, name badge (the gender/skin/age mix of the teller pair).
* ``char_npc_bank_night_manager``: older woman (grey bob), bank-red skirt suit over a cream blouse,
  dark slate skirt, brass name badge and keyhole lapel badge. She is the ``code_on_manager`` carrier.
* ``char_npc_bank_cleaner``: night cleaner (contractor), grey long-sleeve top under a blue-grey
  tabard with a cream binding and a big front pocket, dark work trousers, yellow rubber gloves.
  The cart is a prop (not part of this asset).
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

import _gear_kit as gk
import _npc as n
import _outfit as o
from _outfit import Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False}

VARIANTS = {
    "char_npc_bank_teller": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 5, "hair": "bob",
                             "hair_color": "brown", "look": "teller"},
    "char_npc_bank_teller_b": {"height": 1.75, "build": 0.6, "gender": 0.0, "age": 0.6, "skin": 3, "beard_shadow": 0.4,
                               "hair": "side_part", "hair_color": "dark", "look": "teller_b"},
    "char_npc_bank_night_manager": {"height": 1.71, "build": 0.45, "gender": 1.0, "age": 0.7, "skin": 1, "hair": "bob",
                                    "hair_color": "grey", "look": "manager"},
    "char_npc_bank_cleaner": {"height": 1.74, "build": 0.65, "gender": 0.0, "age": 0.45, "skin": 6, "beard_shadow": 0.8,
                              "hair": "buzz", "hair_color": "dark", "look": "cleaner"},
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


def cleaner(kit: Kit) -> None:
    n.cleaner_outfit(kit, "char_knit_grey", SLATE_DARK, "char_cleaner_tabard", CREAM, "char_rubber_yellow",
                     "char_bank_cream")


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
    kit.notes["look"] = ("Halden night-shift guard: steel-blue shirt + charcoal tie under a charcoal V-neck "
                         "sweater vest, charcoal epaulettes with gold bars, burgundy/gold H sleeve patch, gold-rim "
                         "burgundy chest badge, duty belt (radio = Hip), bare-headed")


_looks = {"teller": teller, "teller_b": teller_b, "manager": manager, "cleaner": cleaner, "guard": guard}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
