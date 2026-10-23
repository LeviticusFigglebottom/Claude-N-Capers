"""Afterhours cast (D3-01): the Velvet nightclub (``afterhours``, P5; Nightclub analogue).

No afterhours design doc yet: roles follow the D3-01 brief (D-065: Afterhours starts in civilian
mode, so the crew walks in among these people). Proposed palette: club black, the Velvet's violet
and a magenta accent under coloured light; staff are black with violet, patrons mixed and varied in
silhouette (dress, wide trousers, beanie + hoodie, shirt).

* ``char_club_bouncer``: door security, the biggest build in the game (1.88 m, build 1.0, bald, full
  stubble): a black nylon bomber zipped over a black tee, SECURITY in pale block letters across the
  back, a radio clipped outside the bomber on its ribbed waistband (right hip, over the hem; = the
  ``Hip`` seat where the pager rides), black trousers, boots, an earpiece with a coiled cable (right ear).
* ``char_club_bouncer_b``: the second bouncer (big build, buzz cut): no jacket, a tight black
  short-sleeved tee tucked in (SECURITY on the back), a belt with the radio on the right hip (= the
  ``Hip`` seat where the pager rides), black trousers, boots, earpiece.
* ``char_club_bartender``: a bearded man: a black shirt with the sleeves rolled, a dark denim bib
  apron with leather straps, black trousers.
* ``char_club_bartender_b``: a woman: a white shirt with rolled sleeves, a violet waistcoat, a long
  black bistro apron, black trousers, blond chignon.
* ``char_club_dj``: the resident DJ: over-ear headphones worn on the head (violet cup accents), tinted
  glasses, an oversized violet hoodie (hood down, drawstrings), black trousers, white trainers.
* ``char_club_patron``: a woman in a sleeveless gold satin mini dress, heels, earrings, blond bob.
* ``char_club_patron_b``: a man in a teal satin shirt, black trousers, belt, white trainers, watch.
* ``char_club_patron_c``: a woman in a sleeveless magenta knit top and wide black trousers, heels, a
  high chignon.
* ``char_club_patron_d``: a young man in a cream hoodie and a grey knit beanie, jeans, white trainers.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (headphones,
glasses, beanie, chignon, earrings). No blend shapes (baked at the params below).
"""

import math

import _cartel_gear as cgear
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
    "char_club_bouncer": {"height": 1.88, "build": 1.0, "gender": 0.0, "age": 0.4, "skin": 6, "beard_shadow": 0.85,
                          "hair": "bald", "hair_color": "dark", "look": "bouncer"},
    "char_club_bouncer_b": {"height": 1.86, "build": 0.95, "gender": 0.0, "age": 0.5, "skin": 2, "beard_shadow": 0.6,
                            "hair": "buzz", "hair_color": "brown", "look": "bouncer_b"},
    "char_club_bartender": {"height": 1.80, "build": 0.5, "gender": 0.0, "age": 0.3, "skin": 1, "beard_shadow": 0.95,
                            "hair": "side_part", "hair_color": "brown", "look": "bartender"},
    "char_club_bartender_b": {"height": 1.69, "build": 0.35, "gender": 1.0, "age": 0.25, "skin": 3,
                              "hair": "side_part", "hair_color": "blond", "look": "bartender_b"},
    "char_club_dj": {"height": 1.78, "build": 0.4, "gender": 0.0, "age": 0.3, "skin": 5, "beard_shadow": 0.5,
                     "hair": "short", "hair_color": "dark", "look": "dj"},
    # D-165: the door team and bar staff for Afterhours' live counts (up to 6 bouncers, 4-6 bar / front staff)
    "char_club_bouncer_c": {"height": 1.74, "build": 0.7, "gender": 1.0, "age": 0.35, "skin": 5, "hair": "side_part",
                            "hair_color": "dark", "look": "bouncer_c"},
    "char_club_bouncer_d": {"height": 1.84, "build": 0.95, "gender": 0.0, "age": 0.75, "skin": 1, "beard_shadow": 0.9,
                            "hair": "short", "hair_color": "grey", "look": "bouncer_d"},
    "char_club_bouncer_e": {"height": 1.85, "build": 0.65, "gender": 0.0, "age": 0.12, "skin": 3, "beard_shadow": 0.2,
                            "hair": "buzz", "hair_color": "blond", "look": "bouncer_e"},
    "char_club_bouncer_f": {"height": 1.70, "build": 0.5, "gender": 1.0, "age": 0.45, "skin": 2, "hair": "bob",
                            "hair_color": "brown", "look": "bouncer_f"},
    "char_club_bartender_c": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.22, "skin": 6, "hair": "short",
                              "hair_color": "dark", "look": "bartender_c"},
    "char_club_bartender_d": {"height": 1.79, "build": 0.45, "gender": 0.0, "age": 0.35, "skin": 4, "beard_shadow": 0.4,
                              "hair": "side_part", "hair_color": "dark", "look": "bartender_d"},
    "char_club_patron": {"height": 1.72, "build": 0.3, "gender": 1.0, "age": 0.25, "skin": 1, "hair": "bob",
                         "hair_color": "blond", "lip": "char_lip_rose", "look": "patron"},
    "char_club_patron_b": {"height": 1.81, "build": 0.5, "gender": 0.0, "age": 0.3, "skin": 4, "beard_shadow": 0.5,
                           "hair": "buzz", "hair_color": "dark", "look": "patron_b"},
    "char_club_patron_c": {"height": 1.68, "build": 0.45, "gender": 1.0, "age": 0.3, "skin": 6, "hair": "side_part",
                           "hair_color": "dark", "look": "patron_c"},
    "char_club_patron_d": {"height": 1.76, "build": 0.35, "gender": 0.0, "age": 0.2, "skin": 3, "beard_shadow": 0.3,
                           "hair": "short", "hair_color": "brown", "look": "patron_d"},
}

BLACK = "char_shirt_black"
VIOLET = "char_club_violet"
PALE = "char_button_pale"
LIME = "char_club_lime"
CORAL = "char_club_coral"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def _boots(kit: Kit) -> Mesh:
    s = g.shoes(kit.fit, "char_shoe_black", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(s)
    return s


def _trainers(kit: Kit) -> Mesh:
    s = g.shoes(kit.fit, "char_sneaker_white", "char_button_pale", top_z=0.085, base=0.007, toe=0.016)
    kit.add_soft(s)
    return s


def bouncer(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), BLACK, hips_z - 0.02 * k, neck="crew", base=0.005)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.064)
    n0 = len(kit.soft.f)
    jk = crew.bomber(kit, "char_nylon_black", "char_knit_graphite", "char_knit_graphite", hips_z - 0.03 * k, 1.27 * k,
                     neck_w=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    # pager role (QC-70): the radio is clipped OUTSIDE the bomber on its ribbed waistband (right hip),
    # hanging over the hem so it reads at a glance; the Hip seat sits on it like the belt radios
    hem_z = hips_z - 0.03 * k
    wb = gk.Belt(fit, Hull(fit, [jk], body_regions=set()), hem_z + 0.032 * k, height=0.03, thick=0.003)
    a_radio = math.radians(96.0)  # more to the side than the belt radios: the bomber stands further out
    kit.add_gear(gk.radio(wb, a_radio))
    kit.seats["Hip"] = wb.point(a_radio, dz=0.0, out=0.045 * k)
    p5.stamp_back(kit, "SECURITY", 1.33, 0.045, PALE)
    n.earpiece(kit, "R")
    kit.notes["hip_note"] = ("Hip seat = the radio clipped outside the bomber on its ribbed waistband (right hip); "
                             "the pager rides there")
    n.arm_band(kit, "L", 1.86, 0.010, LIME, height=0.003)                             # AH-G3: event
    n.arm_band(kit, "L", 1.80, 0.010, CORAL, height=0.003)                            # wristbands
    kit.notes["look"] = ("Velvet bouncer: biggest build, bald; black nylon bomber over a black tee, SECURITY across "
                         "the back, radio clipped on the bomber waistband, black trousers, boots, earpiece")


def bouncer_b(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), BLACK, tuck, sleeve=0.52, neck="crew", base=0.004, rib=0.025)
    kit.add_soft(tee)
    tr = n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.064)
    b = n.belt(kit, tr, belt_z, buckle="chrome", height=0.036)
    a_radio = math.radians(108.0)
    kit.add_gear(gk.radio(b, a_radio))
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    p5.stamp_back(kit, "SECURITY", 1.33, 0.045, PALE)
    n.earpiece(kit, "R")
    kit.notes["hip_note"] = "Hip seat = the radio on the belt (right hip); the pager rides there"
    n.front_item(kit, -0.070, belt_z / k - 0.005, (0.034, 0.046, 0.022), "char_metal_silver", lift=0.004)  # AH-G3: a
                                                                                  # door clicker on the belt
    kit.notes["look"] = ("Velvet bouncer: big build, tight black short-sleeved tee tucked in, SECURITY on the back, "
                         "belt radio, black trousers, boots, earpiece")


def bartender(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    crew.rolled_shirt(kit, BLACK, tuck)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    ap = g.apron(fit, kit.hull(), "char_denim", 1.30 * k, 0.50 * k, strap_mat="char_apron_leather")
    kit.add_soft(ap)
    pk = Mesh()
    o.patch(pk, Hull(fit, [ap]), Vector((0.0, 0.0, 0.88 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.24 * k, 0.11 * k, 0.01 * k, 2), 0.003 * k, "char_denim", cast_dir=Vector((0, -1, 0)),
            rings=2, chamfer=0.003 * k)
    kit.add_soft(pk)
    n.front_item(kit, 0.145, 0.950, (0.075, 0.170, 0.006), "char_medic_white", lift=0.003,
                 up=Vector((0.15, 0.0, 1.0)))                                         # AH-G3: a bar towel
    kit.notes["look"] = "Velvet bartender: black shirt with rolled sleeves, dark denim bib apron with leather straps"


def bartender_b(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    crew.rolled_shirt(kit, "char_shirt_white", tuck)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, VIOLET, hips_z - 0.01 * k, 1.12 * k, point=0.045, neck_w=0.068, buttons=4,
                       button_mat="char_metal_silver")
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    n.waist_apron(kit, "char_tux_black", belt_z + 0.01 * k, 0.36 * k)
    kit.add_head(cg.chignon(fit, "char_hair_blond"))
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.090 * k, 0.2, 1.31 * k)), k=k, mat="char_satin_gold"))  # AH-G3
    kit.notes["look"] = ("Velvet bartender: white shirt with rolled sleeves, violet waistcoat, long black bistro "
                         "apron, blond chignon")


def dj(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.062)
    knit = g.knit_top(fit, kit.hull(), VIOLET, hips_z - 0.09 * k, base=0.018, rib=0.07, neck="crew")
    kit.add_soft(knit)
    hp = Mesh()
    o.patch(hp, Hull(fit, [knit]), Vector((0.0, 0.0, hips_z + 0.03 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            o.rounded_rect(0.28 * k, 0.12 * k, 0.03 * k, 3), 0.004 * k, VIOLET, cast_dir=Vector((0, -1, 0)), rings=2,
            chamfer=0.004 * k)
    kit.add_soft(hp)
    n.hood_down(kit, VIOLET)
    n.drawstrings(kit, PALE)
    p5.headphones_on(kit, "polymer_black", "rubber_black", accent=VIOLET)
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    kit.add_head(cg.lenses(fit, "char_lens"))
    n.lanyard(kit, "char_club_magenta", "char_medic_white", card_z=1.16)               # AH-G3: an artist pass
    kit.notes["look"] = ("Velvet DJ: over-ear headphones on the head (violet accents), tinted glasses, oversized "
                         "violet hoodie, black trousers, white trainers")


def patron(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_satin_gold", 0.50 * k, sleeve=0.0, scoop=0.07, flare=0.06)
    kit.add_soft(d)
    kit.add_head(cg.earrings(fit, "chrome"))
    kit.notes["look"] = "Club patron: sleeveless gold satin mini dress, heels, silver earrings, blond bob"


def patron_b(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    n.shirt(kit, "char_satin_teal", tuck, point_len=0.06, spread=0.34)
    tr = n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n.belt(kit, tr, belt_z, buckle="chrome")
    n.watch(kit, "L", strap="char_metal_silver", case="chrome")
    kit.notes["look"] = "Club patron: teal satin shirt, black trousers and belt, white trainers, silver watch"


def patron_c(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    top = g.knit_top(fit, kit.hull(), "char_club_magenta", belt_z - 0.01 * k, sleeve=0.0, neck="crew", base=0.004,
                     rib=0.03)
    kit.add_soft(top)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.03 * k, hem_r=0.095)
    kit.add_head(cg.chignon(fit, "char_hair_dark", size=1.1, lift=0.03))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.notes["look"] = "Club patron: sleeveless magenta knit top, wide black trousers, heels, high chignon"
    del hips_z


def patron_d(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.hoodie(kit, "char_hoodie_cream", hips_z - 0.06 * k, string_mat="char_knit_graphite")
    kit.add_head(cgear.beanie(fit, "char_knit_grey"))
    kit.notes["look"] = "Club patron: cream hoodie (hood down), grey knit beanie, jeans, white trainers"


# ---------------------------------------------------------------------------------------------
# D-165: more of the door team and the bar
def bouncer_c(kit: Kit) -> None:
    """A woman on the door team: the bomber, a high bun, a staff laminate on a magenta lanyard."""
    bouncer(kit)
    kit.add_head(cg.chignon(kit.fit, "char_hair_dark", size=0.9, lift=0.02))
    n.lanyard(kit, "char_club_magenta", "char_medic_white", card_z=1.17)              # AH-G3: a staff laminate
    kit.notes["look"] = ("Velvet bouncer (woman): black nylon bomber over a black tee, SECURITY across the back, radio "
                         "on the bomber waistband, earpiece, high bun, staff laminate on a magenta lanyard")


def bouncer_d(kit: Kit) -> None:
    """The head doorman: older and heavy, a long black wool coat over the black tee, grey beard."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), BLACK, tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    tr = n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.064)
    b = n.belt(kit, tr, belt_z, buckle="chrome", height=0.036)
    a_radio = math.radians(108.0)
    kit.add_gear(gk.radio(b, a_radio))
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_suit_dark", 0.58 * k, 1.08 * k, button_mat="char_button_dark", lapel_w=0.06,
                         neck_w=0.085, flare=0.08, open_below=0.0)
    n.cull_under(kit, n0, jk, "faces_hidden_by_coat")
    p5.stamp_back(kit, "SECURITY", 1.33, 0.045, PALE)
    n.earpiece(kit, "R")
    n.watch(kit, "L", strap="char_satin_gold", case="char_satin_gold")                 # AH-G3: a gold watch
    kit.notes["hip_note"] = "Hip seat = the radio on the belt under the coat (right hip); the pager rides there"
    kit.notes["look"] = ("Velvet head doorman: older, heavy, grey beard; long black wool coat over a black tee, "
                         "SECURITY across the back, belt radio, earpiece, gold watch")


def bouncer_e(kit: Kit) -> None:
    """The youngest of the door team: a black hoodie over the belt radio, a torch clipped at the chest."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), BLACK, tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    tr = n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.062)
    b = n.belt(kit, tr, belt_z, buckle="chrome", height=0.034)
    a_radio = math.radians(108.0)
    kit.add_gear(gk.radio(b, a_radio))
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.050 * k)
    n.hoodie(kit, "char_nylon_black", hips_z - 0.05 * k, string_mat="char_knit_graphite")
    p5.stamp_back(kit, "SECURITY", 1.33, 0.045, PALE)
    n.earpiece(kit, "R")
    n.front_item(kit, -0.090, 1.290, (0.018, 0.110, 0.018), "polymer_black", lift=0.003)  # AH-G3: a torch
    n.front_item(kit, -0.090, 1.348, (0.022, 0.012, 0.020), "char_medic_white", lift=0.003)  # and its lens
    kit.notes["hip_note"] = "Hip seat = the radio on the belt under the hoodie (right hip); the pager rides there"
    kit.notes["look"] = ("Velvet bouncer (young): black hoodie, SECURITY across the back, belt radio under it, black "
                         "trousers, boots, earpiece, a torch clipped at the chest")


def bouncer_f(kit: Kit) -> None:
    """The door team's camera operator: a black short-sleeved polo, glasses, belt radio, a pen."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    n.shirt(kit, BLACK, tuck, point_len=0.048, spread=0.34, sleeve=0.55, cuff=False)
    tr = n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.058)
    b = n.belt(kit, tr, belt_z, buckle="chrome", height=0.034)
    a_radio = math.radians(108.0)
    kit.add_gear(gk.radio(b, a_radio))
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    p5.stamp_back(kit, "SECURITY", 1.33, 0.045, PALE)
    n.earpiece(kit, "R")
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    n.front_item(kit, -0.092, 1.300, (0.008, 0.075, 0.007), "char_medic_white", lift=0.003)  # AH-G3: a white pen
    kit.notes["hip_note"] = "Hip seat = the radio on the belt (right hip); the pager rides there"
    kit.notes["look"] = ("Velvet door team (camera operator): black short-sleeved polo, SECURITY on the back, belt "
                         "radio, black trousers, boots, earpiece, glasses, a white pen")


def bartender_c(kit: Kit) -> None:
    """East-bar bartender: a black sleeveless knit top, a short black waist apron, gold bangles."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    top = g.knit_top(fit, kit.hull(), BLACK, tuck, sleeve=0.0, neck="crew", base=0.004, rib=0.025)
    kit.add_soft(top)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n.waist_apron(kit, "char_tux_black", belt_z + 0.01 * k, 0.70 * k)
    for t in (1.84, 1.90):                                                             # AH-G3: gold bangles
        n.arm_band(kit, "R", t, 0.007, "char_satin_gold", height=0.003)
    kit.notes["look"] = ("Velvet bartender (east bar): black sleeveless knit top, short black waist apron, black "
                         "trousers, short dark hair, stacked gold bangles")


def bartender_d(kit: Kit) -> None:
    """The cocktail bartender: white shirt, black bow tie, long black apron, black sleeve garters."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.054, spread=0.30)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n.bow_tie(kit, "char_tie_black")
    n.waist_apron(kit, "char_tux_black", belt_z + 0.01 * k, 0.36 * k)
    for side in ("L", "R"):                                                            # AH-G3: sleeve garters
        n.arm_band(kit, side, 0.55, 0.022, "char_tux_black", height=0.004)
    kit.notes["look"] = ("Velvet cocktail bartender: white shirt, black bow tie, long black bistro apron, black "
                         "trousers, black sleeve garters")


_looks = {"bouncer": bouncer, "bouncer_b": bouncer_b, "bartender": bartender, "bartender_b": bartender_b, "dj": dj,
          "patron": patron, "patron_b": patron_b, "patron_c": patron_c, "patron_d": patron_d,
          "bouncer_c": bouncer_c, "bouncer_d": bouncer_d, "bouncer_e": bouncer_e, "bouncer_f": bouncer_f,
          "bartender_c": bartender_c, "bartender_d": bartender_d}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
