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
    # D-165: the patron pool 4 -> 12 for Afterhours' 12-20 live patrons (bars, booths, foyer, VIP, queue)
    "char_club_patron_e": {"height": 1.70, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 2, "hair": "side_part",
                           "hair_color": "brown", "lip": "char_lip_rose", "look": "patron_e"},
    "char_club_patron_f": {"height": 1.83, "build": 0.6, "gender": 0.0, "age": 0.35, "skin": 6, "beard_shadow": 0.6,
                           "hair": "buzz", "hair_color": "dark", "look": "patron_f"},
    "char_club_patron_g": {"height": 1.69, "build": 0.4, "gender": 1.0, "age": 0.32, "skin": 4, "hair": "bob",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "patron_g"},
    "char_club_patron_h": {"height": 1.77, "build": 0.35, "gender": 0.0, "age": 0.15, "skin": 1, "beard_shadow": 0.2,
                           "hair": "short", "hair_color": "brown", "look": "patron_h"},
    "char_club_patron_i": {"height": 1.72, "build": 0.55, "gender": 1.0, "age": 0.5, "skin": 3, "hair": "side_part",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "patron_i"},
    "char_club_patron_j": {"height": 1.80, "build": 0.6, "gender": 0.0, "age": 0.5, "skin": 5, "beard_shadow": 0.5,
                           "hair": "side_part", "hair_color": "grey", "look": "patron_j"},
    "char_club_patron_k": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.18, "skin": 5, "hair": "short",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "patron_k"},
    "char_club_patron_l": {"height": 1.82, "build": 0.55, "gender": 0.0, "age": 0.35, "skin": 3, "beard_shadow": 0.7,
                           "hair": "bald", "hair_color": "dark", "look": "patron_l"},
    # D-165: the dance-floor pool (4-6 clusters x 5 dancers playing dance_a/b/c), lighter clubwear than the patrons
    "char_club_dancer": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 3, "hair": "bob",
                         "hair_color": "dark", "lip": "char_lip_rose", "look": "dancer"},
    "char_club_dancer_b": {"height": 1.82, "build": 0.55, "gender": 0.0, "age": 0.2, "skin": 5, "beard_shadow": 0.3,
                           "hair": "buzz", "hair_color": "dark", "look": "dancer_b"},
    "char_club_dancer_c": {"height": 1.72, "build": 0.3, "gender": 1.0, "age": 0.25, "skin": 1, "hair": "side_part",
                           "hair_color": "blond", "lip": "char_lip_rose", "look": "dancer_c"},
    "char_club_dancer_d": {"height": 1.78, "build": 0.4, "gender": 0.0, "age": 0.2, "skin": 2, "beard_shadow": 0.3,
                           "hair": "short", "hair_color": "brown", "look": "dancer_d"},
    "char_club_dancer_e": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.3, "skin": 6, "hair": "short",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "dancer_e"},
    "char_club_dancer_f": {"height": 1.80, "build": 0.6, "gender": 0.0, "age": 0.4, "skin": 3, "beard_shadow": 0.6,
                           "hair": "bald", "hair_color": "dark", "look": "dancer_f"},
    "char_club_dancer_g": {"height": 1.69, "build": 0.4, "gender": 1.0, "age": 0.25, "skin": 4, "hair": "side_part",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "dancer_g"},
    "char_club_dancer_h": {"height": 1.84, "build": 0.5, "gender": 0.0, "age": 0.25, "skin": 6, "beard_shadow": 0.4,
                           "hair": "short", "hair_color": "dark", "look": "dancer_h"},
    "char_club_dancer_i": {"height": 1.71, "build": 0.35, "gender": 1.0, "age": 0.3, "skin": 2, "hair": "bob",
                           "hair_color": "brown", "lip": "char_lip_rose", "look": "dancer_i"},
    "char_club_dancer_j": {"height": 1.79, "build": 0.45, "gender": 0.0, "age": 0.3, "skin": 1, "beard_shadow": 0.3,
                           "hair": "side_part", "hair_color": "blond", "look": "dancer_j"},
    "char_club_dancer_k": {"height": 1.73, "build": 0.4, "gender": 1.0, "age": 0.35, "skin": 5, "hair": "side_part",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "dancer_k"},
    "char_club_dancer_l": {"height": 1.81, "build": 0.55, "gender": 0.0, "age": 0.3, "skin": 4, "beard_shadow": 0.5,
                           "hair": "buzz", "hair_color": "dark", "look": "dancer_l"},
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
    # D-165 AH special roles: the rare off-duty cop (civ_offduty, a police observer in plain clothes) and the
    # vip_party pool (+6 VIP patrons on U1/U2: a birthday host and five guests, so the party has no twins with the floor)
    "char_club_offduty_cop": {"height": 1.82, "build": 0.7, "gender": 0.0, "age": 0.6, "skin": 2, "beard_shadow": 0.8,
                              "hair": "short", "hair_color": "grey", "look": "offduty_cop"},
    "char_club_vip": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.3, "skin": 4, "hair": "side_part",
                      "hair_color": "dark", "lip": "char_lip_rose", "look": "vip"},
    "char_club_vip_b": {"height": 1.84, "build": 0.55, "gender": 0.0, "age": 0.4, "skin": 6, "beard_shadow": 0.7,
                        "hair": "buzz", "hair_color": "dark", "look": "vip_b"},
    "char_club_vip_c": {"height": 1.69, "build": 0.4, "gender": 1.0, "age": 0.28, "skin": 1, "hair": "bob",
                        "hair_color": "blond", "lip": "char_lip_rose", "look": "vip_c"},
    "char_club_vip_d": {"height": 1.79, "build": 0.65, "gender": 0.0, "age": 0.35, "skin": 3, "beard_shadow": 0.9,
                        "hair": "side_part", "hair_color": "brown", "look": "vip_d"},
    "char_club_vip_e": {"height": 1.73, "build": 0.3, "gender": 1.0, "age": 0.25, "skin": 5, "hair": "short",
                        "hair_color": "dark", "look": "vip_e"},
    "char_club_vip_f": {"height": 1.86, "build": 0.45, "gender": 0.0, "age": 0.5, "skin": 1, "beard_shadow": 0.4,
                        "hair": "short", "hair_color": "grey", "look": "vip_f"},
}

BLACK = "char_shirt_black"
VIOLET = "char_club_violet"
PALE = "char_button_pale"
LIME = "char_club_lime"
CORAL = "char_club_coral"
#: The door team's SECURITY back print (LEAD r-AH1: it must read under the magenta floor light at 10 m): white print
#: with a UV glow, bold block letters 0.056 m tall (strokes padded to ~1.9 units), about 0.34 m across: wider and the
#: S / Y land on the A-pose upper arms and swing out with them.
SECURITY_H = 0.056
SECURITY_MAT = "char_club_print"


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
    p5.stamp_back(kit, "SECURITY", 1.31, SECURITY_H, SECURITY_MAT, bold=0.45)
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
    p5.stamp_back(kit, "SECURITY", 1.31, 0.050, SECURITY_MAT, bold=0.45)  # short sleeves: narrower
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
    n.arm_band(kit, "L", 1.87, 0.012, LIME, height=0.003)                             # AH-G3: the entry wristband
    kit.notes["look"] = "Club patron: sleeveless gold satin mini dress, heels, silver earrings, blond bob"


def patron_b(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    n.shirt(kit, "char_satin_teal", tuck, point_len=0.06, spread=0.34)
    tr = n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n.belt(kit, tr, belt_z, buckle="chrome")
    n.watch(kit, "L", strap="char_metal_silver", case="chrome")
    n.bead_necklace(kit, "char_satin_gold", beads=20, r=0.0032)                        # AH-G3: a fine gold chain
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
    for t in (1.84, 1.90):                                                             # AH-G3: gold bangles
        n.arm_band(kit, "L", t, 0.007, "char_satin_gold", height=0.003)
    kit.notes["look"] = "Club patron: sleeveless magenta knit top, wide black trousers, heels, high chignon"
    del hips_z


def patron_d(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sh = _trainers(kit)
    n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.hoodie(kit, "char_hoodie_cream", hips_z - 0.06 * k, string_mat="char_knit_graphite")
    kit.add_head(cgear.beanie(fit, "char_knit_grey"))
    n.arm_band(kit, "R", 1.84, 0.012, CORAL, height=0.003)                            # AH-G3: a coral wristband
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
    p5.stamp_back(kit, "SECURITY", 1.31, SECURITY_H, SECURITY_MAT, bold=0.45)
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
    p5.stamp_back(kit, "SECURITY", 1.31, SECURITY_H, SECURITY_MAT, bold=0.45)
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
    p5.stamp_back(kit, "SECURITY", 1.31, 0.044, SECURITY_MAT, bold=0.45)  # short sleeves: narrower
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


# ---------------------------------------------------------------------------------------------
# D-165: patrons e-l. Palette for the magenta / violet floor light: strong value contrast (ivory, gold, black, lime,
# coral, teal, denim); no deep reds or purples; heads bare (no brims).
def _track_jacket(kit: Kit, mat: str, bottom_z: float) -> Mesh:
    """A zipped track top: a fitted shell to the hip, a band collar, a full chrome zip."""
    fit, k = kit.fit, kit.k
    hull = kit.hull()
    sh = g.upper_shell(fit, mat, bottom_z=bottom_z, sleeve=1.92, base=0.008, waist_blouse=0.004, hull=hull, iters=6,
                       min_off=0.004 * k)
    m = sh.mesh
    loops = g.classify_loops(m)
    g.bottom_tuck(m, loops["hem"], bottom_z)
    mh = Hull(fit, [m])
    g.cuff_band(m, loops["hem"], mh, 0.040 * k, 0.003 * k, mat)
    for key in ("cuff.L", "cuff.R"):
        o.straighten_loop(m, loops[key], iters=2)
        g.cuff_band(m, loops[key], mh, 0.035 * k, 0.003 * k, mat)
    g.band_collar(m, fit, sh.ring("neck"), mat, height=0.8, rad=0.010)
    o.hem_all(m, thick=0.004 * k, depth=0.014 * k)
    kit.add_soft(m)
    jh = Hull(fit, [m])
    nk = g.Neck(fit)
    zp = Mesh()
    path = g.front_path(jh, 0.0, nk.point(0.0, 0.6).z, bottom_z - 0.03 * k, step=0.02 * k)
    o.strip(zp, jh, path, 0.005 * k, 0.0022 * k, "chrome", segs_across=1, chamfer=0.001 * k)
    kit.add_gear(zp)
    return m


def patron_e(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_club_satin_ivory", 0.50 * k, sleeve=0.0, scoop=0.08, flare=0.05)
    kit.add_soft(d)
    kit.add_head(cg.earrings(fit, "char_satin_gold"))                                 # AH-G3: gold drop earrings
    kit.notes["look"] = "Club patron: ivory satin slip mini dress, heels, gold drop earrings, brown side part"


def patron_f(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    tee = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.058)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_leather_black", 0.84 * k, 1.03 * k, lapel_w=0.06, neck_w=0.09, flare=0.04,
                         buttons=False, open_below=0.06, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_head(gk.glasses(fit, "char_button_dark"))                                 # AH-G3: club shades
    kit.add_head(cg.lenses(fit, "char_lens"))
    kit.notes["look"] = ("Club patron: open black leather jacket over a white tee, black jeans, white trainers, dark "
                         "shades")
    del hips_z


def patron_g(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, _tuck = _z(kit)
    bt = _boots(kit)
    waist_z = fit.ring_centre("waist").z
    top = g.knit_top(fit, kit.hull(), LIME, belt_z - 0.01 * k, sleeve=0.0, neck="crew", base=0.004, rib=0.02)
    kit.add_soft(top)
    n.skirt(kit, "char_club_satin_black", waist_z + 0.01 * k, 0.52 * k, flare=0.05)
    kit.add_head(cg.earrings(fit, "char_satin_gold"))                                 # AH-G3: big gold hoops
    kit.notes["look"] = "Club patron: sleeveless lime top, black satin mini skirt, black boots, gold hoops, dark bob"
    del bt


def patron_h(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    tee = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_tac_charcoal", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk = _track_jacket(kit, CORAL, hips_z + 0.02 * k)
    n.cull_under(kit, n0, jk, "faces_hidden_by_track_top")
    n.bead_necklace(kit, LIME, beads=20, r=0.0034)                                     # AH-G3: a lime glow necklace
    kit.notes["look"] = ("Club patron: coral zipped track top over a white tee, charcoal joggers, white trainers, "
                         "lime glow necklace")


def patron_i(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_club_satin_black", 0.42 * k, sleeve=0.40, scoop=0.06, flare=0.08)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.020, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh("char_satin_gold"))
    n.arm_band(kit, "R", 1.80, 0.022, "char_satin_gold", height=0.004)                # AH-G3: a wide gold cuff
    kit.notes["look"] = ("Club patron: black satin knee dress with short sleeves, thin gold belt, heels, a wide gold "
                         "cuff bracelet")


def patron_j(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_silk_ivory", tuck, point_len=0.056, spread=0.36, sleeve=1.3, roll=0.007)
    tr = n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.030)
    n.watch(kit, "L", strap="char_satin_gold", case="char_satin_gold")                 # AH-G3: a gold watch
    kit.notes["look"] = ("Club patron: ivory shirt with rolled sleeves, black trousers, belt, brown loafers, gold "
                         "watch, grey side part")


def patron_k(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _trainers(kit)
    d = g.dress(fit, "char_satin_teal", 0.48 * k, sleeve=0.0, scoop=0.07, flare=0.08)
    kit.add_soft(d)
    n.bead_necklace(kit, CORAL, beads=20, r=0.0034)                                    # AH-G3: a coral glow necklace
    kit.notes["look"] = "Club patron: teal satin slip dress, white trainers, coral glow necklace, short dark hair"


def patron_l(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.060)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_denim", 0.86 * k, 1.03 * k, lapel_w=0.05, neck_w=0.09, flare=0.04,
                         buttons=False, open_below=0.06, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_head(cg.earrings(fit, "char_satin_gold", drop=False))                     # AH-G3: gold ear studs
    kit.notes["look"] = "Club patron: open denim jacket over a white tee, black jeans, boots, shaved head, gold studs"


# ---------------------------------------------------------------------------------------------
# D-165: the dance-floor pool. Light clubwear (crop and sleeveless tops, satin, a gold bomber), mostly trousers so the
# dance_a/b/c leg work cannot pull a hem through a thigh; the two short dresses are checked under the loops.
def _crop(kit: Kit, mat: str, sleeve: float = 0.0) -> Mesh:
    """A crop top ending at the waist."""
    fit = kit.fit
    top = g.knit_top(fit, kit.hull(), mat, fit.ring_centre("waist").z, sleeve=sleeve, neck="crew", base=0.004,
                     rib=0.02)
    kit.add_soft(top)
    return top


def _wide(kit: Kit, mat: str, sh: Mesh, hem_r: float = 0.095) -> Mesh:
    _hips_z, belt_z, _tuck = _z(kit)
    return n.trousers(kit, mat, sh, belt_z + 0.03 * kit.k, hem_r=hem_r)


def _shorts(kit: Kit, mat: str) -> Mesh:
    """Knee-length shorts (the thigh shell), turned hems."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, _tuck = _z(kit)
    tr = g.trousers(fit, mat, belt_z + 0.022 * k, hem_r=0.07, hull=kit.hull(), shorts=True)
    tl = g.classify_loops(tr.mesh)
    o.straighten_loop(tr.mesh, tl["top"], iters=3)
    o.hem_all(tr.mesh, thick=0.004 * k, depth=0.012 * k)
    kit.add_soft(tr.mesh)
    return tr.mesh


def dancer(kit: Kit) -> None:
    sh = _trainers(kit)
    _crop(kit, "char_satin_gold")
    _wide(kit, "char_trousers_black", sh, hem_r=0.07)
    n.arm_band(kit, "R", 1.86, 0.012, LIME, height=0.004)                             # AH-G3: a lime glow bracelet
    kit.notes["look"] = ("Club dancer: gold satin crop top, black high-waist trousers, white trainers, lime glow "
                         "bracelet")


def dancer_b(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    top = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, sleeve=0.0, neck="crew", base=0.004, rib=0.02)
    kit.add_soft(top)
    n0 = len(kit.soft.f)
    tr = n.trousers(kit, "char_tac_charcoal", sh, belt_z + 0.022 * k, hem_r=0.062)
    n.cull_under(kit, n0, tr, "faces_hidden_by_trousers")                           # no hem through the waist
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.030)                             # covers the tuck line
    n.bead_necklace(kit, "char_satin_gold", beads=20, r=0.0034)                       # AH-G3: a gold chain
    kit.notes["look"] = "Club dancer: white tank top, charcoal trousers, white trainers, gold chain"


def dancer_c(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _trainers(kit)
    d = g.dress(fit, CORAL, 0.50 * k, sleeve=0.0, scoop=0.07, flare=0.10)
    kit.add_soft(d)
    kit.add_head(cg.earrings(fit, "char_satin_gold"))                                 # AH-G3: gold hoops
    kit.notes["look"] = "Club dancer: coral satin slip mini dress, white trainers, gold hoops, blond side part"


def dancer_d(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    n.shirt(kit, LIME, tuck, point_len=0.052, spread=0.36, sleeve=0.55, cuff=False)
    n0 = len(kit.soft.f)
    tr = n.trousers(kit, "char_shirt_white", sh, belt_z + 0.022 * k, hem_r=0.060)
    n.cull_under(kit, n0, tr, "faces_hidden_by_trousers")
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.030)
    kit.add_head(gk.glasses(fit, "char_button_dark"))                                 # AH-G3: club shades
    kit.add_head(cg.lenses(fit, "char_lens"))
    kit.notes["look"] = "Club dancer: lime short-sleeved shirt, white jeans, white trainers, dark shades"


def dancer_e(kit: Kit) -> None:
    bt = _boots(kit)
    _crop(kit, BLACK, sleeve=0.5)
    _wide(kit, "char_satin_teal", bt)
    n.bead_necklace(kit, CORAL, beads=20, r=0.0034)                                    # AH-G3: a coral glow necklace
    kit.notes["look"] = "Club dancer: black crop tee, wide teal satin trousers, boots, coral glow necklace"


def dancer_f(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_silk_ivory", tuck, point_len=0.056, spread=0.38)
    n0 = len(kit.soft.f)
    tr = n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n.cull_under(kit, n0, tr, "faces_hidden_by_trousers")
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.030)
    n.watch(kit, "L", strap="char_satin_gold", case="char_satin_gold")                 # AH-G3: a gold watch
    kit.notes["look"] = "Club dancer: ivory satin shirt open at the collar, black trousers, brown loafers, gold watch"


def dancer_g(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    _boots(kit)
    top = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, sleeve=0.0, neck="crew", base=0.004, rib=0.02)
    kit.add_soft(top)
    n0 = len(kit.soft.f)
    sr = _shorts(kit, "char_club_satin_black")
    n.cull_under(kit, n0, sr, "faces_hidden_by_shorts")
    n.belt(kit, sr, belt_z, buckle="chrome", height=0.028)                             # covers the tuck line
    n.arm_band(kit, "L", 1.86, 0.012, CORAL, height=0.004)                            # AH-G3: a coral wristband
    kit.notes["look"] = "Club dancer: white sleeveless top, black satin shorts, ankle boots, coral wristband"


def dancer_h(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    tee = g.knit_top(fit, kit.hull(), BLACK, tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.058)
    n0 = len(kit.soft.f)
    jk = crew.bomber(kit, "char_satin_gold", BLACK, BLACK, hips_z - 0.03 * k, 1.27 * k, neck_w=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_bomber")
    kit.add_head(cg.earrings(fit, "char_satin_gold", drop=False))                     # AH-G3: gold studs
    kit.notes["look"] = "Club dancer: gold satin bomber over a black tee, black jeans, white trainers, gold studs"


def dancer_i(kit: Kit) -> None:
    sh = n.shoes(kit, heel=True)
    _crop(kit, "char_silk_ivory")
    _wide(kit, CORAL, sh)
    n.bead_necklace(kit, "char_satin_gold", beads=20, r=0.0032)                       # AH-G3: a gold chain
    kit.notes["look"] = "Club dancer: ivory satin crop top, wide coral trousers, heels, gold chain"


def dancer_j(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    n.shirt(kit, "char_polo_teal", tuck, point_len=0.048, spread=0.34, sleeve=0.55, cuff=False)
    n0 = len(kit.soft.f)
    tr = n.trousers(kit, "char_tac_charcoal", sh, belt_z + 0.022 * k, hem_r=0.058)
    n.cull_under(kit, n0, tr, "faces_hidden_by_trousers")
    n.belt(kit, tr, belt_z, buckle="chrome", height=0.030)
    n.arm_band(kit, "R", 1.86, 0.012, LIME, height=0.004)                             # AH-G3: a lime glow bracelet
    kit.notes["look"] = "Club dancer: teal polo, charcoal trousers, white trainers, lime glow bracelet"


def dancer_k(kit: Kit) -> None:
    fit = kit.fit
    sh = n.shoes(kit, heel=True)
    _crop(kit, "char_satin_gold")
    _wide(kit, "char_satin_gold", sh)
    kit.add_head(cg.chignon(fit, "char_hair_dark", size=1.0, lift=0.02))
    for t in (1.84, 1.90):                                                             # AH-G3: coral bangles
        n.arm_band(kit, "L", t, 0.007, CORAL, height=0.003)
    kit.notes["look"] = ("Club dancer: gold satin two-piece (crop top, wide trousers), heels, high chignon, coral "
                         "bangles")


def dancer_l(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    bt = _boots(kit)
    tee = g.knit_top(fit, kit.hull(), "char_shirt_white", tuck, neck="crew", base=0.004)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", bt, belt_z + 0.022 * k, hem_r=0.060)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, "char_leather_black", hips_z - 0.01 * k, 1.12 * k, point=0.0, neck_w=0.07, buttons=3,
                       button_mat="char_button_dark")
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    n.watch(kit, "L", strap=LIME, case="polymer_black")                               # AH-G3: a lime sports watch
    kit.notes["look"] = "Club dancer: black leather waistcoat over a white tee, black jeans, boots, lime sports watch"


# ---------------------------------------------------------------------------------------------
# D-165 AH special roles
def offduty_cop(kit: Kit) -> None:
    """The off-duty cop (civ_offduty): a night out in plain clothes, the job showing only at the belt: a black leather
    jacket hanging open over a grey henley tucked into jeans, the gold shield badge on a belt clip beside the buckle
    and a holstered pistol on the right hip under the jacket. Bare head (head shots read clear)."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.13, base=0.007, boot=True)
    kit.add_soft(sh)
    top = g.knit_top(fit, kit.hull(), "char_knit_grey", tuck, neck="crew", base=0.004, rib=0.02)
    kit.add_soft(top)
    tr = n.trousers(kit, "char_denim", sh, belt_z + 0.022 * k, hem_r=0.062)
    b = n.belt(kit, tr, belt_z, buckle="chrome", height=0.036)
    a_holster = math.radians(100.0)
    kit.add_gear(gk.holster(b, a_holster))
    kit.seats["Hip"] = b.point(a_holster, dz=0.0, out=0.05 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_leather_black", belt_z - 0.06 * k, 1.20 * k, buttons=False, lapel_w=0.05,
                         neck_w=0.08, flare=0.05, open_below=0.10, pockets=False, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    _belt_badge(kit, b, math.radians(-30.0))                                         # AH-G3: the tell
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["hip_note"] = "Hip seat = the holster on the belt (right hip), under the open jacket"
    kit.notes["look"] = ("Off-duty cop: black leather jacket open over a grey henley, jeans, brown boots, gold shield "
                         "badge on the belt beside the buckle, holstered pistol on the right hip, grey short hair")


def _belt_badge(kit: Kit, belt: gk.Belt, a: float) -> None:
    """A gold shield on a black leather belt clip (char_police belt_badge, in the diffuse satin gold)."""
    k = kit.k
    gp = o.Gear()
    gp.box((-0.026 * k, -0.040 * k, 0.0), (0.026 * k, 0.026 * k, 0.005 * k), "char_leather_black")
    gp.bevel(0.002 * k, 1, 30.0)
    gp.prism([(x, y - 0.006 * k) for x, y in o.shield_outline(0.040 * k, 0.050 * k)], 0.0045 * k, 0.0080 * k,
             "char_satin_gold")
    gp.prism([(x, y - 0.008 * k) for x, y in o.shield_outline(0.028 * k, 0.036 * k)], 0.0075 * k, 0.0092 * k,
             "char_satin_gold")
    kit.add_gear(gp.to_mesh(belt.frame(a, dz=-0.004 * k), anchor=belt.point(a)))


def _vip_band(kit: Kit, side: str = "L") -> None:
    """The party's gold VIP wristband (every vip_party guest wears one: the party reads as a group)."""
    n.arm_band(kit, side, 1.87, 0.012, "char_satin_gold", height=0.003)


def vip(kit: Kit) -> None:
    """The birthday host: a black satin mini dress, an ivory satin sash over the right shoulder, gold earrings."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_club_satin_black", 0.52 * k, sleeve=0.0, scoop=0.065, flare=0.07)
    kit.add_soft(d)
    hips_z = fit.ring_centre("hips").z
    cgear.StrapLoop(kit, 1.0, hips_z - 0.01 * k, shoulder_in=0.11).build(kit, "char_club_satin_ivory", 0.036,
                                                                          height=0.003)  # AH-G3: the sash
    kit.add_head(cg.earrings(fit, "char_satin_gold"))
    _vip_band(kit)
    kit.notes["look"] = ("VIP party host (birthday): black satin mini dress, ivory satin sash over the right shoulder, "
                         "heels, gold drop earrings, gold VIP wristband")


def vip_b(kit: Kit) -> None:
    """A guest in an ivory dinner jacket with black satin lapels over a black open-collar shirt."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, BLACK, tuck, point_len=0.06, spread=0.36)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.058)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_silk_ivory", 0.70 * k, 1.04 * k, lapel_mat="char_satin_black",
                         button_mat="char_button_dark", lapel_w=0.06, neck_w=0.08, flare=0.08)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.watch(kit, "R", strap="char_satin_gold", case="char_satin_gold")             # AH-G3: a gold watch
    _vip_band(kit)
    kit.notes["look"] = ("VIP party guest: ivory dinner jacket with black satin lapels, black open-collar shirt, "
                         "black trousers, gold watch, gold VIP wristband")


def vip_c(kit: Kit) -> None:
    """A guest in a coral mini dress with a gold bead necklace."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, CORAL, 0.53 * k, sleeve=0.0, scoop=0.06, flare=0.09)
    kit.add_soft(d)
    n.bead_necklace(kit, "char_satin_gold", beads=22, r=0.0045)                     # AH-G3: gold beads
    _vip_band(kit)
    kit.notes["look"] = "VIP party guest: coral mini dress, heels, gold bead necklace, blond bob, gold VIP wristband"


def vip_d(kit: Kit) -> None:
    """A guest in a black satin shirt worn open at the neck with a gold chain, ivory trousers."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_satin_black", tuck, point_len=0.06, spread=0.38)
    tr = n.trousers(kit, "char_silk_ivory", sh, belt_z + 0.022 * k, hem_r=0.058)
    n.belt(kit, tr, belt_z, buckle="char_satin_gold")
    n.bead_necklace(kit, "char_satin_gold", beads=24, r=0.0034)                     # AH-G3: a gold chain
    _vip_band(kit, "R")
    kit.notes["look"] = ("VIP party guest: black satin shirt open at the neck, gold chain, ivory trousers, brown "
                         "shoes, gold VIP wristband")


def vip_e(kit: Kit) -> None:
    """A guest in a lime knit top and a black satin midi skirt, gold studs."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    n.shoes(kit, heel=True)
    top = g.knit_top(fit, kit.hull(), LIME, tuck, sleeve=0.0, neck="crew", base=0.004, rib=0.025)
    kit.add_soft(top)
    n0 = len(kit.soft.f)
    sk = n.skirt(kit, "char_club_satin_black", belt_z + 0.02 * k, 0.40 * k, flare=0.06)
    n.cull_under(kit, n0, sk, "faces_hidden_by_skirt")
    kit.add_head(cg.earrings(fit, "char_satin_gold", drop=False))                    # AH-G3: gold studs
    _vip_band(kit)
    kit.notes["look"] = ("VIP party guest: sleeveless lime knit top, black satin midi skirt, heels, gold studs, "
                         "short dark hair, gold VIP wristband")
    del hips_z


def vip_f(kit: Kit) -> None:
    """An older guest: a midnight velvet blazer over a white tee, black trousers, white trainers, a pocket square."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = _trainers(kit)
    tee = g.knit_top(kit.fit, kit.hull(), "char_shirt_white", tuck, neck="crew", base=0.004, rib=0.02)
    kit.add_soft(tee)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_velvet_midnight", 0.72 * k, 1.02 * k, button_mat="char_button_dark",
                         lapel_w=0.055, neck_w=0.08, flare=0.08)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    crew._pocket_square(kit, "char_satin_gold", Hull(kit.fit, [jk]))                # AH-G3: a gold pocket square
    _vip_band(kit)
    kit.notes["look"] = ("VIP party guest (older): midnight velvet blazer over a white tee, black trousers, white "
                         "trainers, gold pocket square, gold VIP wristband")


_looks = {"bouncer": bouncer, "bouncer_b": bouncer_b, "bartender": bartender, "bartender_b": bartender_b, "dj": dj,
          "patron": patron, "patron_b": patron_b, "patron_c": patron_c, "patron_d": patron_d,
          "bouncer_c": bouncer_c, "bouncer_d": bouncer_d, "bouncer_e": bouncer_e, "bouncer_f": bouncer_f,
          "bartender_c": bartender_c, "bartender_d": bartender_d,
          "patron_e": patron_e, "patron_f": patron_f, "patron_g": patron_g, "patron_h": patron_h, "patron_i": patron_i,
          "patron_j": patron_j, "patron_k": patron_k, "patron_l": patron_l,
          "dancer": dancer, "dancer_b": dancer_b, "dancer_c": dancer_c, "dancer_d": dancer_d, "dancer_e": dancer_e,
          "dancer_f": dancer_f, "dancer_g": dancer_g, "dancer_h": dancer_h, "dancer_i": dancer_i, "dancer_j": dancer_j,
          "dancer_k": dancer_k, "dancer_l": dancer_l,
          "offduty_cop": offduty_cop, "vip": vip, "vip_b": vip_b, "vip_c": vip_c, "vip_d": vip_d, "vip_e": vip_e,
          "vip_f": vip_f}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
