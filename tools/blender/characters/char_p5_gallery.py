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
* D-130 (Cataclysm: about +50 % guards, up to 7 guards + the operator + inspectors on the floor): seven more
  Halberd faces so the guard pool (``gallery_guard`` a-i) never shows twins. Same livery; small
  variations only (``jacket: False`` = shirtsleeve order: the bottle-green waistcoat with gold buttons and
  the crest, the radio clipped to the waistband under its hem; glasses; a chignon):

  * ``char_gallery_guard_c``: woman, mid-20s, deep skin, dark hair in a chignon; blazer.
  * ``char_gallery_guard_d``: man, 30s, mid skin, short dark hair, stubble; shirtsleeve order (waistcoat).
  * ``char_gallery_guard_e``: heavy older man (about 60), mid-deep skin, bald, beard shadow, silver glasses; blazer.
  * ``char_gallery_guard_f``: woman, 50s, light skin, grey bob, gold-rimmed glasses; blazer.
  * ``char_gallery_guard_g``: tall lean young man, light skin, short blond hair; shirtsleeve order.
  * ``char_gallery_guard_h``: woman, 30s, mid skin, dark bob; shirtsleeve order.
  * ``char_gallery_guard_i``: man, 40s, deep skin, side-parted dark hair, heavy stubble; blazer.
  * GN Cataclysm inspection (up to 11 guards on screen): three more faces so the pool (12) has no twins.
  * ``char_gallery_guard_j``: woman, early 60s, mid-deep skin, short grey hair; blazer.
  * ``char_gallery_guard_k``: man, 30s, light skin, side-parted brown hair, light stubble; blazer.
  * ``char_gallery_guard_l``: woman, late 20s, fair skin, blond bob; shirtsleeve order.
* ``char_gallery_patron``: gala guest (woman): a sleeveless wine satin midi cocktail dress, gold
  belt, gold earrings, heels, dark bob.
* ``char_gallery_patron_b``: gala guest (man, older): a midnight-blue velvet dinner jacket with
  black satin shawl lapels, white shirt, black bow tie, black trousers, wine pocket square.
* ``char_gallery_admin``: the development office's admin PA (QC-58c, rare ``late_paperwork``),
  the one office worker in the building after hours: a teal knit cardigan (open, one button) over a
  pale-blue shirt, charcoal trousers, low heels, silver glasses, a wristwatch and the
  gallery staff lanyard (wine strap, gold band, white card). Day office wear, so it never reads as a
  gala guest (black tie) or front-of-house staff (black and white).
* GN-D1 polish (D-115 queue): up to 9 patrons are live at once (12 ``civ_patron`` spawns), so the
  gala gets five more guests (nine patron looks with the four below plus ``npc_penthouse_guest_a``/
  ``_b``: five women, four men), all evening wear in dark or jewel tones (the curator stays the one
  pale suit):

  * ``char_gallery_patron_c``: woman, 60s, silver chignon: a half-sleeved black cocktail dress, gold
    belt and earrings, gold-rimmed glasses.
  * ``char_gallery_patron_d``: man, 30s: an all-black dinner suit over a black open-collar shirt (no
    tie), plum silk pocket square, watch.
  * ``char_gallery_patron_e``: woman, 30s, blond bob: a sapphire satin cocktail dress with cap
    sleeves, silver belt and drop earrings.
  * ``char_gallery_patron_f``: man, 60s, heavy, bald with a grey beard: a navy dinner suit with black
    satin lapels, white shirt, wine bow tie, silver glasses and watch.
  * ``char_gallery_patron_g``: woman, 40s, dark chignon: an amethyst satin dress with short
    sleeves and a wide black satin belt, gold earrings.
* D-130 (Cataclysm: about +35 % civilians, up to 12 live patrons): three more guests (twelve patron looks,
  seven women and five men), still dark or jewel-toned evening wear:

  * ``char_gallery_patron_h``: woman, 20s, deep skin, side-parted dark hair: a sleeveless gold satin cocktail dress,
    thin black satin belt, gold earrings.
  * ``char_gallery_patron_i``: man, 40s, mid-deep skin, short dark hair, stubble: a plum dinner jacket with black
    satin lapels, white shirt, black bow tie, satin-striped black trousers, watch.
  * ``char_gallery_patron_j``: woman, about 60, mid skin, grey bob: a long-sleeved graphite silk dress with a wide
    gold satin belt, silver drop earrings.
* ``char_gallery_waiter``: the second waitstaff (1-2 spawn): a young man in a white shirt, black bow
  tie, Halberd-wine waistcoat with gold buttons, long black bistro apron, Halberd pin and name tag
  (beside ``npc_penthouse_staff``, the waitress in the graphite waistcoat).
* D-130 (``gala_extra``: cloakroom waitstaff and a drawings-cabinet attendant), a third look for each pool:

  * ``char_gallery_waiter_b``: the cloakroom waitstaff: a woman in her 50s, light skin, brown hair in a
    chignon: a short Halberd-wine waiter's jacket with gold buttons over a white shirt, black bow tie, black
    trousers, no apron (cloakroom, not the floor), Halberd pin, brass name tag, gold earrings.
  * ``char_gallery_attendant_c``: the drawings-cabinet attendant: a man about 50, deep skin, bald, beard
    shadow: a grey knit cardigan over a white band-collar shirt, black trousers, white cotton gloves
    for handling works on paper, the gallery staff lanyard (wine, gold) and the Halberd pin.
* ``char_gallery_conservator``: the paintings conservator (QC-58, rare ``cons_late``) in his own
  look instead of the attendant's (GN-D-c): an older man, grey side parting, beard: pale-blue shirt,
  grey knit sweater vest, a long charcoal canvas work apron, khaki trousers, white art-handling
  gloves, reading glasses with a loupe, the gallery staff lanyard. Work wear, never gala or
  front-of-house black and white.
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
    # D-130: the nine-face guard pool (c-i)
    "char_gallery_guard_c": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.25, "skin": 6,
                             "hair": "side_part", "hair_color": "dark", "look": "guard", "chignon": "char_hair_dark"},
    "char_gallery_guard_d": {"height": 1.80, "build": 0.6, "gender": 0.0, "age": 0.32, "skin": 3, "beard_shadow": 0.6,
                             "hair": "short", "hair_color": "dark", "look": "guard", "jacket": False},
    "char_gallery_guard_e": {"height": 1.77, "build": 0.85, "gender": 0.0, "age": 0.7, "skin": 5, "beard_shadow": 0.7,
                             "hair": "bald", "hair_color": "grey", "look": "guard", "glasses": "char_metal_silver"},
    "char_gallery_guard_f": {"height": 1.68, "build": 0.55, "gender": 1.0, "age": 0.55, "skin": 2, "hair": "bob",
                             "hair_color": "grey", "look": "guard", "glasses": "brass"},
    "char_gallery_guard_g": {"height": 1.88, "build": 0.3, "gender": 0.0, "age": 0.2, "skin": 1, "beard_shadow": 0.2,
                             "hair": "short", "hair_color": "blond", "look": "guard", "jacket": False},
    "char_gallery_guard_h": {"height": 1.74, "build": 0.5, "gender": 1.0, "age": 0.35, "skin": 3, "hair": "bob",
                             "hair_color": "dark", "look": "guard", "jacket": False},
    "char_gallery_guard_i": {"height": 1.83, "build": 0.7, "gender": 0.0, "age": 0.45, "skin": 6, "beard_shadow": 0.85,
                             "hair": "side_part", "hair_color": "dark", "look": "guard"},
    "char_gallery_guard_j": {"height": 1.68, "build": 0.6, "gender": 1.0, "age": 0.62, "skin": 5, "hair": "short",
                             "hair_color": "grey", "look": "guard"},
    "char_gallery_guard_k": {"height": 1.79, "build": 0.55, "gender": 0.0, "age": 0.35, "skin": 2, "beard_shadow": 0.3,
                             "hair": "side_part", "hair_color": "brown", "look": "guard"},
    "char_gallery_guard_l": {"height": 1.71, "build": 0.4, "gender": 1.0, "age": 0.28, "skin": 1, "hair": "bob",
                             "hair_color": "blond", "look": "guard", "jacket": False},
    "char_gallery_patron": {"height": 1.70, "build": 0.35, "gender": 1.0, "age": 0.45, "skin": 4, "hair": "bob",
                            "hair_color": "dark", "lip": "char_lip_rose", "look": "patron"},
    "char_gallery_patron_b": {"height": 1.79, "build": 0.55, "gender": 0.0, "age": 0.7, "skin": 2,
                              "beard_shadow": 0.3, "hair": "side_part", "hair_color": "grey", "look": "patron_b"},
    "char_gallery_admin": {"height": 1.68, "build": 0.45, "gender": 1.0, "age": 0.35, "skin": 3, "hair": "bob",
                           "hair_color": "brown", "look": "admin"},
    "char_gallery_patron_c": {"height": 1.68, "build": 0.4, "gender": 1.0, "age": 0.75, "skin": 1, "hair": "side_part",
                              "hair_color": "grey", "lip": "char_lip_rose", "look": "patron_c"},
    "char_gallery_patron_d": {"height": 1.83, "build": 0.4, "gender": 0.0, "age": 0.2, "skin": 5, "beard_shadow": 0.2,
                              "hair": "short", "hair_color": "dark", "look": "patron_d"},
    "char_gallery_patron_e": {"height": 1.74, "build": 0.3, "gender": 1.0, "age": 0.25, "skin": 2, "hair": "bob",
                              "hair_color": "blond", "lip": "char_lip_rose", "look": "patron_e"},
    "char_gallery_patron_f": {"height": 1.76, "build": 0.85, "gender": 0.0, "age": 0.75, "skin": 3,
                              "beard_shadow": 0.8, "hair": "bald", "hair_color": "grey", "look": "patron_f"},
    "char_gallery_patron_g": {"height": 1.71, "build": 0.5, "gender": 1.0, "age": 0.5, "skin": 5, "hair": "side_part",
                              "hair_color": "dark", "lip": "char_lip_rose", "look": "patron_g"},
    # D-130: three more patrons (twelve-look pool)
    "char_gallery_patron_h": {"height": 1.72, "build": 0.3, "gender": 1.0, "age": 0.2, "skin": 6, "hair": "side_part",
                              "hair_color": "dark", "lip": "char_lip_rose", "look": "patron_h"},
    "char_gallery_patron_i": {"height": 1.81, "build": 0.6, "gender": 0.0, "age": 0.45, "skin": 4, "beard_shadow": 0.6,
                              "hair": "short", "hair_color": "dark", "look": "patron_i"},
    "char_gallery_patron_j": {"height": 1.69, "build": 0.55, "gender": 1.0, "age": 0.62, "skin": 3, "hair": "bob",
                              "hair_color": "grey", "lip": "char_lip_rose", "look": "patron_j"},
    "char_gallery_waiter": {"height": 1.77, "build": 0.35, "gender": 0.0, "age": 0.15, "skin": 4, "beard_shadow": 0.1,
                            "hair": "side_part", "hair_color": "brown", "look": "waiter"},
    # D-130 gala_extra: third waitstaff (cloakroom) and third attendant (drawings cabinet)
    "char_gallery_waiter_b": {"height": 1.68, "build": 0.5, "gender": 1.0, "age": 0.55, "skin": 2, "hair": "side_part",
                              "hair_color": "brown", "lip": "char_lip_rose", "look": "waiter_b"},
    "char_gallery_attendant_c": {"height": 1.78, "build": 0.6, "gender": 0.0, "age": 0.55, "skin": 6,
                                 "beard_shadow": 0.6, "hair": "bald", "hair_color": "dark", "look": "attendant_c"},
    "char_gallery_conservator": {"height": 1.75, "build": 0.45, "gender": 0.0, "age": 0.7, "skin": 2,
                                 "beard_shadow": 0.7, "hair": "side_part", "hair_color": "grey", "look": "conservator"},
}

BONE = "char_gallery_bone"
GREEN = "char_gallery_green"
WINE = "char_gallery_wine"
GLOVE = "char_glove_white"
BLACK = "char_tux_black"
SATIN = "char_satin_black"
VELVET = "char_velvet_midnight"
DRESS = "char_satin_wine"
SAPPHIRE = "char_satin_sapphire"
AMETHYST = "char_satin_amethyst"


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
    kit.add_gear(p5.halberd_pin(kit.hull(), Vector((0.09 * k, 0.3, 1.33 * k)), k))   # GN-G3
    _pocket_square(kit, WINE)
    n.glasses_cord(kit, "brass")
    n.watch(kit, "L", strap="char_leather_black", case="brass")
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
    n.earpiece(kit, "R")                                                         # GN-G3: event radio
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
    n.earpiece(kit, "R")                                                         # GN-G3: event radio
    kit.notes["look"] = ("Gallery attendant: black jacket over a white shirt, black trousers, white gloves, Halberd "
                         "lapel pin, silver name tag, chignon")


def guard(kit: Kit) -> None:
    """Halberd Gallery Security (in-house): bottle-green blazer with the Halberd crest, white shirt,
    wine tie, grey trousers, earpiece, belt radio under the blazer (Hip). D-130 options (kit.opts):
    ``jacket: False`` = shirtsleeve order (bottle-green waistcoat with the crest, black belt carrying the
    radio clipped to the waistband under its hem), ``glasses: <frame mat>``, ``chignon: <hair mat>``."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    jacket = bool(kit.opts.get("jacket", True))
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
    if jacket:
        cover, _info = n.jacket(kit, GREEN, 0.80 * k, 1.03 * k, button_mat="brass", lapel_w=0.055, neck_w=0.078,
                                flare=0.07, chest_welt=False)
        n.cull_under(kit, n0, cover, "faces_hidden_by_jacket")
    else:
        cover = n.waistcoat(kit, GREEN, hips_z - 0.01 * k, 1.13 * k, point=0.05, neck_w=0.07, buttons=5,
                            button_mat="brass", base=0.012)
        n.cull_under(kit, n0, cover, "faces_hidden_by_waistcoat")
    p5.halberd_crest(kit, -0.098, 1.305)
    hull = kit.hull()
    kit.add_gear(gk.name_tag(hull, Vector((0.098 * k, 0.3, 1.33 * k)), k=k, mat="brass"))
    n.earpiece(kit, "R")
    n.front_item(kit, 0.0, 1.235, (0.045, 0.005, 0.003), "brass", lift=0.0)        # GN-G3: a gold tie bar, a watch
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    if not jacket:                                                                # the belt shows: a key ring
        kit.add_gear(gk.key_ring(b, math.radians(-25.0)))
    if "glasses" in kit.opts:
        kit.add_head(gk.glasses(fit, str(kit.opts["glasses"])))
    if "chignon" in kit.opts:
        kit.add_head(cg.chignon(fit, str(kit.opts["chignon"])))
    if jacket:
        kit.notes["hip_note"] = "Hip seat = the radio on the belt under the blazer (right hip); the pager rides there"
        kit.notes["look"] = ("Halberd Gallery Security (in-house): bottle-green blazer, gold buttons, wine/gold "
                             "Halberd breast crest, white shirt, wine tie, grey trousers, earpiece, belt radio under "
                             "the blazer")
    else:
        kit.notes["hip_note"] = "Hip seat = the radio on the waistband under the waistcoat (right hip); the pager rides there"
        kit.notes["look"] = ("Halberd Gallery Security (in-house), shirtsleeve order: bottle-green waistcoat with "
                             "gold buttons and the wine/gold Halberd crest, white shirt, wine tie, grey trousers, "
                             "belt radio under the waistcoat, earpiece")


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


def admin(kit: Kit) -> None:
    """Admin PA (QC-58c): office wear, the cardigan is a knit jacket without contrast lapels."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, heel=True)
    n.shirt(kit, "char_shirt_blue", tuck, point_len=0.05, spread=0.32)
    # Trousers, not a skirt: the shared skirt loft lets the thighs poke through in walk/cower/seated.
    n.trousers(kit, "char_suit_dark", sh, belt_z + 0.022 * k, hem_r=0.056)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_knit_teal", 0.76 * k, 1.02 * k, button_mat="char_button_dark", lapel_w=0.03,
                         neck_w=0.09, flare=0.05, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    n.lanyard(kit, WINE, "char_medic_white", card_z=1.16, band_mat="brass")
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    kit.add_gear(p5.halberd_pin(kit.hull(), Vector((-0.095 * k, 0.3, 1.33 * k)), k))  # GN-G3
    n.front_item(kit, 0.10, 1.30, (0.009, 0.05, 0.009), "polymer_black", lift=0.004)     # a pen
    kit.notes["look"] = ("Admin PA (development office): teal knit cardigan over a pale-blue shirt, charcoal "
                         "trousers, low heels, silver glasses, watch, gallery staff lanyard (wine, gold)")


def _pocket_square(kit: Kit, mat: str) -> None:
    k = kit.k
    pk = Mesh()
    o.patch(pk, kit.hull(), Vector((-0.095 * k, 0.0, 1.318 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            [(-0.035 * k, -0.006 * k), (0.035 * k, -0.006 * k), (0.03 * k, 0.014 * k), (0.012 * k, 0.022 * k),
             (-0.008 * k, 0.015 * k), (-0.03 * k, 0.02 * k)], 0.004 * k, mat,
            cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)


def patron_c(kit: Kit) -> None:
    """Older woman: half-sleeved black cocktail dress, gold belt, earrings and glasses, silver chignon."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_dress_black", 0.30 * k, sleeve=0.80, scoop=0.04, flare=0.10)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.020, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh("brass"))
    kit.add_head(cg.chignon(fit, "char_hair_grey"))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.add_head(gk.glasses(fit, "brass"))
    kit.notes["look"] = ("Gala guest (woman, 60s): half-sleeved black cocktail dress, gold belt, gold earrings, "
                         "gold-rimmed glasses, silver chignon")


def patron_d(kit: Kit) -> None:
    """Young man, modern black tie: all-black dinner suit, black open-collar shirt, plum pocket square."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_black", tuck, point_len=0.05)
    n.trousers(kit, BLACK, sh, belt_z + 0.022 * k)
    n.jacket(kit, BLACK, 0.80 * k, 1.03 * k, lapel_mat=SATIN, button_mat=SATIN, lapel_w=0.05, neck_w=0.09)
    _pocket_square(kit, "char_silk_plum")
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.notes["look"] = ("Gala guest (man, 30s): all-black dinner suit with satin lapels over a black open-collar "
                         "shirt (no tie), plum silk pocket square, watch")


def patron_e(kit: Kit) -> None:
    """Young woman: sapphire satin cocktail dress with cap sleeves, silver belt and drop earrings."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, SAPPHIRE, 0.36 * k, sleeve=0.14, scoop=0.08, flare=0.14)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.014, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh("chrome"))
    kit.add_head(cg.earrings(fit, "chrome"))
    kit.notes["look"] = ("Gala guest (woman, 30s): sapphire satin cocktail dress with cap sleeves, thin silver belt, "
                         "silver drop earrings, blond bob")


def patron_f(kit: Kit) -> None:
    """Older heavy man: navy dinner suit, black satin lapels, wine bow tie, silver glasses, beard."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05)
    tr = n.trousers(kit, "char_suit_navy", sh, belt_z + 0.022 * k)
    n.trouser_stripes(kit, tr, SATIN, belt_z + 0.022 * k, half_w=0.006)
    n.bow_tie(kit, WINE)
    n.jacket(kit, "char_suit_navy", 0.79 * k, 1.02 * k, lapel_mat=SATIN, button_mat=SATIN, lapel_w=0.075,
             neck_w=0.09)
    n.watch(kit, "L", strap="char_leather_black", case="chrome")
    kit.add_head(gk.glasses(fit, "char_metal_silver"))
    kit.notes["look"] = ("Gala guest (man, 60s, heavy): navy dinner suit with black satin lapels and stripes, white "
                         "shirt, wine bow tie, silver glasses, watch, grey beard")


def patron_g(kit: Kit) -> None:
    """Woman, 40s: amethyst satin dress with short sleeves, black satin belt, chignon."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, AMETHYST, 0.32 * k, sleeve=0.42, scoop=0.065, flare=0.12)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.026, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh(SATIN))
    kit.add_head(cg.chignon(fit, "char_hair_dark"))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.notes["look"] = ("Gala guest (woman, 40s): amethyst satin dress with short sleeves, wide black satin "
                         "belt, gold earrings, dark chignon")


def patron_h(kit: Kit) -> None:
    """D-130, young woman: sleeveless gold satin cocktail dress, thin black satin belt, gold earrings."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_satin_gold", 0.33 * k, sleeve=0.0, scoop=0.07, flare=0.13)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.014, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh(SATIN))
    kit.add_head(cg.earrings(fit, "brass"))
    kit.notes["look"] = ("Gala guest (woman, 20s): sleeveless gold satin cocktail dress, thin black satin belt, gold "
                         "earrings, side-parted dark hair")


def patron_i(kit: Kit) -> None:
    """D-130, man in his 40s: plum dinner jacket, black satin lapels, black bow tie, striped trousers, watch."""
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05)
    tr = n.trousers(kit, BLACK, sh, belt_z + 0.022 * k)
    n.trouser_stripes(kit, tr, SATIN, belt_z + 0.022 * k, half_w=0.006)
    n.bow_tie(kit, "char_tie_black")
    n.jacket(kit, "char_suit_plum", 0.79 * k, 1.02 * k, lapel_mat=SATIN, button_mat=SATIN, lapel_w=0.065,
             neck_w=0.09)
    n.watch(kit, "L", strap="char_leather_black", case="brass")
    kit.notes["look"] = ("Gala guest (man, 40s): plum dinner jacket with black satin lapels, white shirt, black bow "
                         "tie, satin-striped black trousers, gold watch")


def patron_j(kit: Kit) -> None:
    """D-130, older woman: long-sleeved graphite silk dress, wide gold satin belt, silver drop earrings."""
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, "char_silk_graphite", 0.28 * k, sleeve=1.8, scoop=0.05, flare=0.10)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.030, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh("char_satin_gold"))
    kit.add_head(cg.earrings(fit, "chrome"))
    kit.notes["look"] = ("Gala guest (woman, about 60): long-sleeved graphite silk dress, wide gold satin belt, "
                         "silver drop earrings, grey bob")


def waiter(kit: Kit) -> None:
    """Second waitstaff (man): white shirt, black bow tie, wine waistcoat, long black bistro apron."""
    k = kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.048)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n.bow_tie(kit, "char_tie_black", half_w=0.046)
    n.waistcoat(kit, WINE, hips_z - 0.01 * k, 1.12 * k, point=0.05, neck_w=0.07, buttons=4, button_mat="brass")
    n.waist_apron(kit, BLACK, belt_z + 0.01 * k, 0.30 * k)
    hull = kit.hull()
    kit.add_gear(p5.halberd_pin(hull, Vector((-0.085 * k, 0.3, 1.31 * k)), k))
    kit.add_gear(gk.name_tag(hull, Vector((0.085 * k, 0.2, 1.30 * k)), k=k, mat="brass"))
    n.arm_band(kit, "L", 1.45, 0.10, WINE, height=0.006)          # GN-G3: a wine napkin over the forearm
    n.front_item(kit, 0.085, 1.22, (0.012, 0.055, 0.008), "char_metal_silver")       # a wine key in the pocket
    kit.notes["look"] = ("Gala waiter: white shirt, black bow tie, Halberd-wine waistcoat with gold buttons, long "
                         "black bistro apron, Halberd pin, brass name tag")


def waiter_b(kit: Kit) -> None:
    """D-130 cloakroom waitstaff (woman): short wine waiter's jacket, white shirt, black bow tie, no apron."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.048)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k, hem_r=0.056)
    n.bow_tie(kit, "char_tie_black", half_w=0.044)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, WINE, 0.88 * k, 1.06 * k, button_mat="brass", lapel_w=0.045, neck_w=0.075,
                         flare=0.05, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    hull = kit.hull()
    kit.add_gear(p5.halberd_pin(hull, Vector((-0.09 * k, 0.3, 1.32 * k)), k))
    kit.add_gear(gk.name_tag(hull, Vector((0.092 * k, 0.3, 1.30 * k)), k=k, mat="brass"))
    kit.add_head(cg.chignon(fit, "char_hair_brown"))
    kit.add_head(cg.earrings(fit, "brass"))
    n.front_item(kit, -0.09, 1.24, (0.045, 0.06, 0.006), "char_prop_paper")           # GN-G3: cloakroom tickets
    n.watch(kit, "L", strap="char_leather_black", case="brass")
    kit.notes["look"] = ("Cloakroom waitstaff (woman, 50s): short Halberd-wine waiter's jacket with gold buttons, "
                         "white shirt, black bow tie, black trousers, Halberd pin, brass name tag, brown chignon")


def attendant_c(kit: Kit) -> None:
    """D-130 drawings-cabinet attendant (man): grey knit cardigan, band-collar shirt, cotton gloves, lanyard."""
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, collar="band")
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n0 = len(kit.soft.f)
    jk, _info = n.jacket(kit, "char_knit_grey", 0.80 * k, 1.04 * k, button_mat="char_button_dark",
                         lapel_w=0.03, neck_w=0.085, flare=0.05, chest_welt=False)
    n.cull_under(kit, n0, jk, "faces_hidden_by_jacket")
    kit.add_soft(g.gloves(fit, GLOVE, cuff_len=0.05, base=0.0025, cuff_off=0.005))
    n.lanyard(kit, WINE, "char_medic_white", card_z=1.17, band_mat="brass")
    kit.add_gear(p5.halberd_pin(kit.hull(), Vector((-0.095 * k, 0.3, 1.33 * k)), k))
    n.earpiece(kit, "R")                                                         # GN-G3: event radio
    kit.notes["look"] = ("Drawings-cabinet attendant (man, about 50): grey knit cardigan over a white band-collar "
                         "shirt, black trousers, white cotton gloves for works on paper, staff lanyard, Halberd pin")


def conservator(kit: Kit) -> None:
    """Paintings conservator (QC-58, GN-D-c): work wear in the conservation studio after hours."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit, mat="char_shoe_brown")
    n.shirt(kit, "char_shirt_blue", tuck, point_len=0.05)
    n.trousers(kit, "char_chino_khaki", sh, belt_z + 0.022 * k)
    n.knit_vest(kit, "char_knit_grey", hips_z - 0.02 * k, 1.16 * k)
    n.waist_apron(kit, "char_work_charcoal", belt_z + 0.01 * k, 0.40 * k, width=0.56)
    kit.add_soft(g.gloves(fit, GLOVE, cuff_len=0.05, base=0.0025, cuff_off=0.005))
    n.lanyard(kit, WINE, "char_medic_white", card_z=1.18, band_mat="brass")
    kit.add_head(gk.glasses(fit, "char_metal_silver", loupe=True))
    kit.add_gear(p5.halberd_pin(kit.hull(), Vector((-0.09 * k, 0.3, 1.33 * k)), k))   # GN-G3
    for dx, ln, mat in ((-0.012, 0.11, "char_bank_red"), (0.006, 0.13, "char_rubber_yellow")):  # brushes in the
        n.front_item(kit, 0.10 + dx, 0.98, (0.007, ln, 0.007), mat, lift=0.008)                   # apron pocket
    kit.notes["look"] = ("Paintings conservator: pale-blue shirt, grey knit sweater vest, long charcoal canvas work "
                         "apron, khaki trousers, white art-handling gloves, glasses with a loupe, staff lanyard")


_looks = {"admin": admin, "curator": curator, "attendant": attendant, "attendant_b": attendant_b, "guard": guard,
          "patron": patron, "patron_b": patron_b, "patron_c": patron_c, "patron_d": patron_d, "patron_e": patron_e,
          "patron_f": patron_f, "patron_g": patron_g, "patron_h": patron_h, "patron_i": patron_i,
          "patron_j": patron_j, "waiter": waiter, "waiter_b": waiter_b, "attendant_c": attendant_c,
          "conservator": conservator}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
