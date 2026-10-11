"""Gallery Night cast (D3-01): the Halberd Gallery gala at night (``gallery_night``, P5).

No gallery_night design doc yet: the roles and the proposed palette follow the D3-01 brief and
docs/design/game_overview.md §7 (Framing Frame analogue). Proposed palette: gallery white (walls),
charcoal / tuxedo black (the crowd) and Halberd gold + wine (the gallery's own colours). Gala
guests are dark (black tie), staff are black-and-white with gold, security is bottle green, and the
one pale suit in the room is the curator (the person the crew looks for).

The **Halberd Gallery** insignia (original): a gold halberd head (spear point, crescent axe blade,
back spike) on wine enamel; staff wear it as a small round pin, security as a breast-pocket crest.

* ``char_gallery_curator``: the chief curator (key / code carrier). Tall woman, 50s, dark bob, heavy
  black glasses, a bone-white tailored long jacket (mid-thigh, black satin lapels) and matching
  trousers over a black roll-neck, low heels, gold earrings, a black lanyard with a gold band and a
  white keycard. The only pale full-length figure at the gala.
* ``char_gallery_attendant``: gallery attendant (man): white band-collar shirt, black waistcoat,
  black trousers, white cotton art-handling gloves, the Halberd pin on the waistcoat.
* ``char_gallery_attendant_b``: gallery attendant (woman): black jacket over a white shirt, black
  trousers, white gloves, the pin on the lapel, a silver name tag, dark chignon.
* ``char_gallery_guard`` / ``_b``: **Halberd Gallery Security**, the gallery's own in-house guards
  (not Halden, not Northgate): a bottle-green blazer with gold buttons and the wine/gold Halberd
  crest on the breast pocket, white shirt, wine tie, mid-grey trousers, an earpiece (right ear) and
  a belt radio under the blazer on the right hip (= the ``Hip`` seat where the pager rides).
  ``_b`` is a woman (different skin, bob).
* ``char_gallery_patron``: gala guest (woman): a sleeveless wine satin midi cocktail dress, gold
  belt, gold earrings, heels, dark bob.
* ``char_gallery_patron_b``: gala guest (man, older): a midnight-blue velvet dinner jacket with
  black satin shawl lapels, white shirt, black bow tie, black trousers, wine pocket square.
* Reused (listed in ``world/characters/p5_cast.json``, not rebuilt; D-063 reserved them for this
  heist): ``npc_penthouse_guest_a`` / ``_b`` (more gala guests) and ``npc_penthouse_staff`` (the
  waitress).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (glasses,
chignon). No blend shapes (baked at the params below).
"""

import math

import _contact_gear as cg
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
    "char_gallery_curator": {"height": 1.79, "build": 0.3, "gender": 1.0, "age": 0.6, "skin": 5, "hair": "bob",
                             "hair_color": "dark", "lip": "char_lip_rose", "look": "curator"},
    "char_gallery_attendant": {"height": 1.80, "build": 0.4, "gender": 0.0, "age": 0.25, "skin": 3,
                               "beard_shadow": 0.3, "hair": "short", "hair_color": "dark", "look": "attendant"},
    "char_gallery_attendant_b": {"height": 1.68, "build": 0.3, "gender": 1.0, "age": 0.3, "skin": 6,
                                 "hair": "side_part", "hair_color": "dark", "look": "attendant_b"},
    "char_gallery_guard": {"height": 1.85, "build": 0.75, "gender": 0.0, "age": 0.5, "skin": 1, "beard_shadow": 0.5,
                           "hair": "buzz", "hair_color": "grey", "look": "guard"},
    "char_gallery_guard_b": {"height": 1.72, "build": 0.5, "gender": 1.0, "age": 0.4, "skin": 4, "hair": "bob",
                             "hair_color": "brown", "look": "guard"},
    "char_gallery_patron": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.45, "skin": 4, "hair": "bob",
                            "hair_color": "dark", "lip": "char_lip_rose", "look": "patron"},
    "char_gallery_patron_b": {"height": 1.79, "build": 0.55, "gender": 0.0, "age": 0.7, "skin": 2,
                              "beard_shadow": 0.3, "hair": "side_part", "hair_color": "grey", "look": "patron_b"},
}

BONE = "char_gallery_bone"
GREEN = "char_gallery_green"
WINE = "char_gallery_wine"
GLOVE = "char_glove_white"
BLACK = "char_tux_black"
SATIN = "char_satin_black"
VELVET = "char_velvet_midnight"
DRESS = "char_satin_wine"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def curator(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, _tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    knit = g.knit_top(fit, kit.hull(), "char_knit_graphite", belt_z - 0.01 * k, neck="roll", base=0.006)
    kit.add_soft(knit)
    n.trousers(kit, BONE, sh, belt_z + 0.022 * k, hem_r=0.060)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, BONE, 0.66 * k, 1.04 * k, lapel_mat=SATIN, button_mat="char_button_dark",
                         lapel_w=0.06, neck_w=0.08, flare=0.09, base=0.012)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.lanyard(kit, "char_tie_black", "char_medic_white", card_z=1.15, band_mat="brass")
    kit.add_head(gk.glasses(fit, "char_button_dark"))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.notes["look"] = ("Curator: bone-white tailored long jacket (black satin lapels) + trousers, black roll-neck, "
                         "heavy black glasses, gold earrings, black lanyard with keycard; the one pale suit at the gala")
    kit.notes["prop_note"] = "keycard on the lanyard is skinned (Gear); a hand-held keycard prop goes at HandR/Socket"


def attendant(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, collar="band")
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n0 = len(kit.soft.f)
    vest = n.waistcoat(kit, BLACK, hips_z - 0.01 * k, 1.12 * k, point=0.05, neck_w=0.07, buttons=5,
                       button_mat="brass")
    n.cull_under(kit, n0, vest, "faces_hidden_by_waistcoat")
    kit.add_soft(g.gloves(fit, GLOVE, cuff_len=0.05, base=0.0025, cuff_off=0.005))
    kit.add_gear(p5.halberd_pin(kit.hull(), Vector((-0.085 * k, 0.3, 1.31 * k)), k))
    kit.notes["look"] = ("Gallery attendant: white band-collar shirt, black waistcoat with gold buttons, black "
                         "trousers, white art-handling gloves, Halberd pin")


def attendant_b(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05, spread=0.32)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, BLACK, 0.80 * k, 1.05 * k, button_mat="char_button_dark", lapel_w=0.05, neck_w=0.075,
                         flare=0.07)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_soft(g.gloves(fit, GLOVE, cuff_len=0.05, base=0.0025, cuff_off=0.005))
    hull = kit.hull()
    kit.add_gear(p5.halberd_pin(hull, Vector((-0.092 * k, 0.3, 1.33 * k)), k))
    kit.add_gear(gk.name_tag(hull, Vector((0.095 * k, 0.3, 1.30 * k)), k=k, mat="char_metal_silver"))
    kit.add_head(cg.chignon(fit, "char_hair_dark"))
    kit.notes["look"] = ("Gallery attendant: black jacket over a white shirt, black trousers, white gloves, Halberd "
                         "lapel pin, silver name tag, chignon")


def guard(kit: Kit) -> None:
    """Halberd Gallery Security (in-house): bottle-green blazer with the Halberd crest, white shirt,
    wine tie, grey trousers, earpiece, belt radio under the blazer (Hip)."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.054)
    tr = n.trousers(kit, "char_slacks_grey", sh, belt_z + 0.022 * k)
    n.tie(kit, WINE, belt_z + 0.03 * k, width=0.07)
    b = gk.Belt(fit, Hull(fit, [tr], body_regions=set()), belt_z, height=0.034, thick=0.0045)
    a_radio = math.radians(108.0)
    bg = Mesh()
    bg.extend(gk.radio(b, a_radio))
    kit.add_gear(bg)
    kit.seats["Hip"] = b.point(a_radio, dz=0.0, out=0.045 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, GREEN, 0.80 * k, 1.03 * k, button_mat="brass", lapel_w=0.055, neck_w=0.078,
                         flare=0.07, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    p5.halberd_crest(kit, -0.098, 1.305)
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.098 * k, 0.3, 1.33 * k)), k=k, mat="brass"))
    n.earpiece(kit, "R")
    kit.notes["hip_note"] = "Hip seat = the radio on the belt under the blazer (right hip); the pager rides there"
    kit.notes["look"] = ("Halberd Gallery Security (in-house): bottle-green blazer, gold buttons, wine/gold Halberd "
                         "breast crest, white shirt, wine tie, grey trousers, earpiece, belt radio under the blazer")


def patron(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, DRESS, 0.30 * k, sleeve=0.0, scoop=0.06, flare=0.10)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.016, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh("brass"))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.notes["look"] = "Gala guest: sleeveless wine satin midi cocktail dress, thin gold belt, gold earrings, heels"


def patron_b(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05)
    tr = n.trousers(kit, "char_tux_black", sh, belt_z + 0.022 * k)
    n.trouser_stripes(kit, tr, SATIN, belt_z + 0.022 * k, half_w=0.007)
    n.bow_tie(kit, "char_tie_black")
    n.jacket(kit, VELVET, 0.79 * k, 1.02 * k, lapel_mat=SATIN, button_mat=SATIN, lapel_w=0.07, neck_w=0.09)
    pk = Mesh()
    o.patch(pk, kit.hull(), Vector((-0.095 * k, 0.0, 1.318 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            [(-0.035 * k, -0.006 * k), (0.035 * k, -0.006 * k), (0.03 * k, 0.014 * k), (0.012 * k, 0.022 * k),
             (-0.008 * k, 0.015 * k), (-0.03 * k, 0.02 * k)], 0.004 * k, WINE,
            cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)
    kit.notes["look"] = ("Gala guest: midnight-blue velvet dinner jacket, black satin shawl lapels, white shirt, "
                         "black bow tie, satin-striped trousers, wine pocket square")


_looks = {"curator": curator, "attendant": attendant, "attendant_b": attendant_b, "guard": guard,
          "patron": patron, "patron_b": patron_b}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
