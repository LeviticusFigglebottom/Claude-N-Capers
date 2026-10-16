"""Shadow Ledger staff and night detail in Calder Tower (D-063 recast of the D2-02 NPCs).

Heist palette (style guide §3): graphite ``#2E3136``, glass teal ``#5D8C8F``, cold-white LED
``#CFE3EE``. Kessler himself (and the party) stay in ``char_npc_penthouse.py``; this script holds
the people who are really in the tower at 02:10:

* ``char_npc_cleaner_sl``: the tower's night cleaner, a colour variant of ``char_npc_bank_cleaner``
  (same body and cut, ``_npc.cleaner_outfit``): graphite long-sleeve top, glass-teal tabard with a
  graphite binding and pocket, black work trousers, yellow rubber gloves, silver name tag. The cart
  is ENV C's prop.
* ``char_npc_cleaner_sl_b`` (D-SL-2): the second night cleaner in the same Calder uniform (same
  materials and name tag), a clearly different person so two or three cleaners on Brutal are not
  twins: a sturdy woman in her late 50s, light skin, grey hair pinned up in a bun. ``_c`` (D-116, three
  cleaners on Brutal): a slim young man, olive skin, dark short hair, glasses, same uniform.
* ``char_npc_it_contractor`` (``civ_it``): casual contractor: a rust pull-over hoodie (hood down,
  kangaroo pocket, drawstrings), dark jeans, grey trainers, dark-framed glasses, a blue lanyard with
  a white visitor badge on the chest and a dark grey messenger tool/laptop bag on the left hip on a
  strap across the body (rigid Gear, skinned to the hips; the laptop is ENV C's prop).
* ``char_npc_northgate_guard`` / ``_b``: **Northgate Executive Protection**, the firm's own night
  detail (and its camera operator). Executive protection, not a bank guard: a charcoal two-piece
  suit, grey shirt, black tie, an earpiece with a coiled cable behind the right ear, a small
  original Northgate lapel pin (a steel-blue enamel disc with a silver gate: two posts under an
  arch) on the left lapel, and a radio clipped to the waistband under the jacket on the right hip (= the
  ``Hip`` seat where the pager rides). ``_b`` is a woman (different skin, hair in a chignon). D-116 (no twins
  among up to 6 detail + operator): ``_c`` an older heavy-set man, bald, mid-deep skin, glasses; ``_d`` a tall
  young man, light skin, short blond hair, heavy stubble. Same suit, earpiece, pin and radio on all four.
* ``char_npc_helena_moor`` (``civ_partner``): Helena Moor, founding partner working late. About 52,
  tall and composed, silver-grey chin-length bob, reading glasses on, no jacket (it is on her chair,
  a prop): an ivory silk blouse with the sleeves rolled, charcoal tailored trousers with a slim
  belt, low heels, a slim watch on the left wrist, no jewellery. The phone in her hand is a prop
  (not skinned).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses,
chignon). No blend shapes (baked at the params below).
"""

import math

import _contact_gear as cg
import _gear_kit as gk
import _npc as n
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_npc_cleaner_sl": {"height": 1.74, "build": 0.65, "gender": 0.0, "age": 0.45, "skin": 6, "beard_shadow": 0.8,
                            "hair": "buzz", "hair_color": "dark", "look": "cleaner_sl"},
    "char_npc_cleaner_sl_b": {"height": 1.68, "build": 0.75, "gender": 1.0, "age": 0.72, "skin": 2,
                              "hair": "side_part", "hair_color": "grey", "look": "cleaner_sl_b"},
    "char_npc_it_contractor": {"height": 1.78, "build": 0.5, "gender": 0.0, "age": 0.3, "skin": 2,
                               "beard_shadow": 0.7, "hair": "short", "hair_color": "brown", "look": "it"},
    "char_npc_northgate_guard": {"height": 1.84, "build": 0.7, "gender": 0.0, "age": 0.4, "skin": 5,
                                 "beard_shadow": 0.6, "hair": "buzz", "hair_color": "dark", "look": "northgate"},
    "char_npc_northgate_guard_b": {"height": 1.74, "build": 0.45, "gender": 1.0, "age": 0.35, "skin": 2,
                                   "hair": "side_part", "hair_color": "brown", "look": "northgate_b"},
    "char_npc_cleaner_sl_c": {"height": 1.76, "build": 0.35, "gender": 0.0, "age": 0.22, "skin": 3, "beard_shadow": 0.4,
                              "hair": "short", "hair_color": "dark", "look": "cleaner_sl_c"},
    "char_npc_northgate_guard_c": {"height": 1.80, "build": 0.9, "gender": 0.0, "age": 0.68, "skin": 4,
                                   "beard_shadow": 0.5, "hair": "bald", "hair_color": "grey", "look": "northgate_c"},
    "char_npc_northgate_guard_d": {"height": 1.88, "build": 0.55, "gender": 0.0, "age": 0.2, "skin": 1,
                                   "beard_shadow": 0.95, "hair": "short", "hair_color": "blond", "look": "northgate_d"},
    "char_npc_helena_moor": {"height": 1.78, "build": 0.3, "gender": 1.0, "age": 0.65, "skin": 2, "hair": "bob",
                             "hair_color": "grey", "look": "helena"},
}

SUIT = "char_suit_dark"
NG_SHIRT = "char_ng_shirt"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _cleaner_sl(kit: Kit) -> None:
    n.cleaner_outfit(kit, "char_knit_graphite", "char_trousers_black", "char_cleaner_teal", "char_waistcoat_graphite",
                     "char_rubber_yellow", "char_metal_silver")


def cleaner_sl(kit: Kit) -> None:
    _cleaner_sl(kit)
    kit.notes["look"] = "Calder Tower night cleaner: glass-teal tabard, graphite binding and top (cleaner colour variant)"


def cleaner_sl_b(kit: Kit) -> None:
    _cleaner_sl(kit)
    kit.add_head(cg.chignon(kit.fit, "char_hair_grey", size=0.85))
    kit.notes["look"] = ("Calder Tower night cleaner, second face (D-SL-2): same glass-teal tabard uniform; a sturdy "
                         "woman, late 50s, light skin, grey hair pinned up in a bun")


def cleaner_sl_c(kit: Kit) -> None:
    _cleaner_sl(kit)
    kit.add_head(gk.glasses(kit.fit, "char_button_dark"))
    kit.notes["look"] = ("Calder Tower night cleaner, third face (D-116): same glass-teal tabard uniform; a slim "
                         "young man, olive skin, dark short hair, glasses")


def it(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = g.shoes(fit, "char_sneaker_grey", "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(sh)
    n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.062)
    n.hoodie(kit, "char_hoodie_rust", hips_z - 0.06 * k)
    n.lanyard(kit, "char_lanyard", "char_medic_white", card_z=1.20)
    n.messenger_bag(kit, "char_tac_gear", "char_tac_gear")
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    kit.notes["look"] = ("IT contractor: rust hoodie (hood down), jeans, trainers, glasses, blue lanyard + white "
                         "visitor badge, messenger tool/laptop bag on the left hip (Gear)")


def _northgate(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, NG_SHIRT, tuck, point_len=0.054)
    tr = n.trousers(kit, SUIT, sh, belt_z + 0.022 * k)
    n.tie(kit, "char_tie_black", belt_z + 0.03 * k, width=0.068)
    # radio clipped to the waistband under the jacket (right hip = the Hip seat); the belt itself is
    # hidden by the buttoned jacket, so only the ring the radio hangs on is sampled (no belt mesh)
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.034, thick=0.0045)
    bg = Mesh()
    a_radio = math.radians(108.0)
    bg.extend(gk.radio(b, a_radio))
    kit.add_gear(bg)
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, SUIT, 0.80 * k, 1.03 * k, button_mat="char_button_dark", lapel_w=0.055, neck_w=0.078,
                         flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_gear(n.gate_pin(kit.hull(), Vector((-0.088 * k, 0.3, 1.335 * k)), k))
    n.earpiece(kit, "R")
    kit.notes["hip_note"] = "Hip seat = the radio on the belt under the jacket (right hip); the pager rides there"
    kit.notes["look"] = ("Northgate Executive Protection: charcoal suit, grey shirt, black tie, earpiece + coiled "
                         "cable (right ear), Northgate gate lapel pin, belt radio under the jacket")


def northgate(kit: Kit) -> None:
    _northgate(kit)


def northgate_b(kit: Kit) -> None:
    _northgate(kit)
    kit.add_head(cg.chignon(kit.fit, "char_hair_brown"))


def northgate_c(kit: Kit) -> None:
    _northgate(kit)
    kit.add_head(gk.glasses(kit.fit, "char_metal_silver"))
    kit.notes["face"] = "D-116: older heavy-set man, bald, mid-deep skin, silver-rimmed glasses"


def northgate_d(kit: Kit) -> None:
    _northgate(kit)
    kit.notes["face"] = "D-116: tall young man, light skin, short blond hair, heavy stubble"


def helena(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.shirt(kit, "char_silk_ivory", tuck, collar="fold", point_len=0.05, spread=0.32, sleeve=1.3, roll=0.006)
    tr = n.trousers(kit, SUIT, sh, belt_z + 0.022 * k, hem_r=0.056)
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.024)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    kit.notes["look"] = ("Helena Moor: ivory silk blouse with rolled sleeves, charcoal trousers, slim belt, low "
                         "heels, slim watch (left), reading glasses on, silver bob; jacket off (chair prop)")
    kit.notes["prop_note"] = "phone in hand is a prop: attach at HandR/Socket (not skinned)"


_looks = {"cleaner_sl": cleaner_sl, "cleaner_sl_b": cleaner_sl_b, "cleaner_sl_c": cleaner_sl_c, "it": it,
          "northgate": northgate, "northgate_b": northgate_b, "northgate_c": northgate_c, "northgate_d": northgate_d,
          "helena": helena}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
