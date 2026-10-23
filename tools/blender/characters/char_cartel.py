"""Ortega Fisheries Co-op gunmen (QC-36, ``enemy.cartel_gunman``, pd2_fidelity L4.10) for Dockside
Burn: the Co-op's own armed crew at the Pier 9 cold store, 05:10, harbor fog. Armed civilians in
dock and fishing work wear, never uniforms: no insignia, no badges, no vests, no peaked caps, no
police/TAC/faction colours or material ids. Heist palette accents (style guide §3): rust
``#7A4A2E`` (the waxed jacket), concrete greys, flare orange ``#FF6B1A`` (toned to the saturation
cap: the bandana, the oilskin overalls).

30 m read (vs police caps + vests, vs civilians): beanie / hood-up heads, bulky work jackets, a
sling strap diagonally across every chest, and on two of three a slung long gun on the back whose
barrel stands above one shoulder and whose stock sticks out at the opposite hip. The held weapon is
ENV A/B's (``HandR/Socket``); the slung gun is a simplified, original non-weapon ``Gear`` shape.

* ``char_cartel_gunman``: heavy-set dockhand in his 40s, mid-deep skin, stubble, buzz cut. Rust
  waxed dock jacket (corduroy collar, zip, flap pockets), graphite watch-cap beanie, flare-orange
  bandana worn as a gaiter round the neck, drab cargo trousers, tall dark-green rubber fishing
  boots, fingerless leather gloves. Sling over the left shoulder with a row of shotgun shells in
  loops across the chest; pump-gun slung on the back (muzzle up behind the left shoulder).
* ``char_cartel_gunman_b``: lean young man, deep skin. Heather-grey hoodie with the **hood up**,
  graphite gaiter **pulled up over the nose**, black quilted puffer vest, a belt over the hoodie
  with a pistol holster (right hip) and a magazine pouch, black cargo trousers, brown work boots,
  fingerless gloves. Sling across the chest; no slung gun (his long gun is the held one).
* ``char_cartel_gunman_c``: wiry older deckhand, light skin, grey buzz cut and moustache, bare
  head. Cream fisherman's roll-neck, flare-orange oilskin bib-and-brace overalls, tall rubber
  boots. Sling (left shoulder) and a leather shell bandolier (right shoulder) crossed on the
  chest; pump-gun slung on the back.

D-116 (6-12 posted gunmen + 4 reinforcements; no pair of twins at a post):

* ``char_cartel_gunman_d``: a woman in her 30s, mid skin, dark hair pinned up in a bun. Cream fisherman's
  roll-neck under the black quilted puffer vest, a flare-orange gaiter round the neck, drab cargo trousers, tall
  green rubber boots, fingerless gloves. Sling across the chest; no slung gun.
* ``char_cartel_gunman_e``: a big heavy man, deep skin, heavy stubble. Flare-orange oilskin work jacket with a
  corduroy collar, cream watch-cap beanie, drab cargos, rubber boots, fingerless gloves. Sling with shell loops,
  pump-gun slung on the back.
* ``char_cartel_gunman_f``: a slim young man, light skin. Graphite beanie and a graphite gaiter pulled over the
  nose (balaclava read), a graphite knit pull-over under the black puffer vest, black cargos, brown work boots,
  fingerless gloves. Sling across the chest; no slung gun.

D-115 (GN-D1 standard for Dockside Burn: up to 12 posted gunmen at Cataclysm + 4 reinforcements; a pool of 12 faces):

* ``char_cartel_gunman_g``: a stocky young man, mid-deep skin, buzz cut. Navy hoodie with the **hood up** and the
  face bare (no gaiter, no vest), drab cargos, tall green rubber boots, fingerless gloves. Sling over the **right**
  shoulder; pump-gun slung on the back (muzzle up behind the right shoulder).
* ``char_cartel_gunman_h``: a young woman, deep-mid skin, dark bob under a flare-orange watch-cap beanie. Charcoal
  canvas work jacket with a corduroy collar, black cargos, brown work boots, fingerless gloves. Sling across the
  chest; no slung gun.
* ``char_cartel_gunman_i``: a big old deckhand in his 60s, mid skin, grey short hair and a grey beard shadow, bare
  head. Slate-green fisherman's roll-neck under **drab** canvas bib-and-brace overalls, tall rubber boots. Sling
  and a leather shell bandolier crossed on the chest; pump-gun slung on the back.
* ``char_cartel_gunman_j``: a woman in her 40s, light-mid skin, brown bob under a **rust bandana tied on the head**
  (knot at the nape). Concrete-grey fleece pull-over, belted drab cargos, rubber boots, fingerless gloves. Sling
  across the chest; no slung gun.
* ``char_cartel_gunman_k``: a broad man in his 30s, light skin, short blond hair, bare head, beard shadow. Olive
  nylon work jacket with a corduroy collar, a graphite gaiter round the neck, drab cargos, rubber boots, fingerless
  gloves. Sling with shell loops (right shoulder); pump-gun slung on the back.
* ``char_cartel_gunman_l``: a tall lean man in his 50s, deep skin, shaved bald head. Cream pull-over hoodie (hood
  down on the shoulders, kangaroo pocket, dark drawstrings), black cargos, brown work boots, fingerless gloves.
  Sling across the chest; no slung gun.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (beanie; hood
+ gaiter; moustache). No blend shapes (baked at the params below). Seats in SOURCE.txt
(``attach_*``); the ``Back`` seat sits on the garment, inside the slung gun on A and C (enemies
carry no bags; see ``slung_gun`` in SOURCE).
"""

import math

import _cartel_gear as cg
import _contact_gear as contact
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
import _special_gear as sg
from _outfit import Hull, Mesh, Vector, patch, rounded_rect, straighten_loop
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_cartel_gunman": {"height": 1.80, "build": 0.85, "gender": 0.0, "age": 0.55, "skin": 4, "beard_shadow": 0.9,
                           "hair": "buzz", "hair_color": "dark", "look": "dockhand"},
    "char_cartel_gunman_b": {"height": 1.77, "build": 0.3, "gender": 0.0, "age": 0.15, "skin": 6, "beard_shadow": 0.3,
                             "hair": "buzz", "hair_color": "dark", "look": "hood"},
    "char_cartel_gunman_c": {"height": 1.73, "build": 0.45, "gender": 0.0, "age": 0.78, "skin": 2, "beard_shadow": 0.6,
                             "hair": "buzz", "hair_color": "grey", "look": "deckhand"},
    "char_cartel_gunman_d": {"height": 1.70, "build": 0.55, "gender": 1.0, "age": 0.38, "skin": 3,
                             "hair": "side_part", "hair_color": "dark", "look": "deck_woman"},
    "char_cartel_gunman_e": {"height": 1.86, "build": 1.0, "gender": 0.0, "age": 0.45, "skin": 5, "beard_shadow": 0.95,
                             "hair": "buzz", "hair_color": "dark", "look": "smock"},
    "char_cartel_gunman_f": {"height": 1.79, "build": 0.25, "gender": 0.0, "age": 0.24, "skin": 1, "beard_shadow": 0.3,
                             "hair": "buzz", "hair_color": "brown", "look": "balaclava"},
    # D-115: the 12-face pool (g-l)
    "char_cartel_gunman_g": {"height": 1.76, "build": 0.7, "gender": 0.0, "age": 0.2, "skin": 4, "beard_shadow": 0.4,
                             "hair": "buzz", "hair_color": "dark", "look": "navy_hood"},
    "char_cartel_gunman_h": {"height": 1.68, "build": 0.4, "gender": 1.0, "age": 0.27, "skin": 5,
                             "hair": "bob", "hair_color": "dark", "look": "flare_beanie"},
    "char_cartel_gunman_i": {"height": 1.78, "build": 0.9, "gender": 0.0, "age": 0.85, "skin": 3, "beard_shadow": 1.0,
                             "hair": "short", "hair_color": "grey", "look": "drab_bib"},
    "char_cartel_gunman_j": {"height": 1.71, "build": 0.6, "gender": 1.0, "age": 0.52, "skin": 2,
                             "hair": "bob", "hair_color": "brown", "look": "bandana"},
    "char_cartel_gunman_k": {"height": 1.83, "build": 0.8, "gender": 0.0, "age": 0.36, "skin": 1, "beard_shadow": 0.8,
                             "hair": "short", "hair_color": "blond", "look": "olive_jacket"},
    "char_cartel_gunman_l": {"height": 1.88, "build": 0.2, "gender": 0.0, "age": 0.6, "skin": 6, "beard_shadow": 0.5,
                             "hair": "bald", "hair_color": "dark", "look": "cream_hoodie"},
}

WAX = "char_cartel_wax_rust"
CORD = "char_cartel_cord"
CARGO = "char_cartel_cargo"
RUBBER = "char_cartel_rubber"
FLARE = "char_cartel_flare"
OILSKIN = "char_cartel_oilskin"
HOODIE = "char_cartel_hoodie"
PUFFER = "char_cartel_puffer"
WEBBING = "char_cartel_webbing"
WOOD = "char_cartel_wood"
GUNMETAL = "char_cartel_gunmetal"
SHELL = "char_cartel_shell"
KNIT_DARK = "char_knit_graphite"
KNIT_CREAM = "char_knit_cream"
KNIT_NAVY = "char_knit_navy"
KNIT_GREY = "char_knit_grey"
KNIT_SLATE = "char_knit_slate"
BANDANA = "char_hoodie_rust"


def _z(kit: Kit) -> tuple[float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    return hips_z, hips_z + 0.035 * kit.k


def _gun_note(kit: Kit, info: dict) -> None:
    mz, bt = info["muzzle"], info["butt"]
    kit.notes["slung_gun"] = ("non-weapon Gear on the back (chest-rigid), muzzle model [{:.3f}, {:.3f}, {:.3f}], "
                              "butt [{:.3f}, {:.3f}, {:.3f}] (Godot axes), {:.0f} deg from vertical"
                              ).format(mz.x, mz.z, -mz.y, bt.x, bt.z, -bt.y, info["angle_from_vertical_deg"])


def dockhand(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    tr = g.trousers(fit, CARGO, belt_z + 0.022 * k, hem_r=0.064, base=0.0085, hull=kit.hull()).mesh
    tl = g.classify_loops(tr)
    straighten_loop(tr, tl["top"], iters=3)
    cg.rubber_boots(kit, tr, RUBBER, top_z=0.34)
    kit.add_soft(tr)
    cg.cargo_pockets(kit, tr, CARGO, z=0.58)
    cg.fingerless_gloves(kit, "char_leather_black")
    cg.work_jacket(kit, WAX, CORD, hips_z - 0.075 * k, 1.36 * k)
    cg.neck_gaiter(kit, FLARE, t0=0.10, t1=0.85, radial=0.016)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.02 * k)
    strap = loop.build(kit, WEBBING, 0.020, 0.004)
    cg.shell_row(kit, strap, loop.front, 0.40, 0.72, 8, 0.004, SHELL)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.24, WOOD, GUNMETAL))
    kit.add_head(cg.beanie(fit, KNIT_DARK))
    kit.notes["hat"] = "knit watch-cap beanie (Headwear)"
    n.front_item(kit, -0.095, 1.300, (0.055, 0.085, 0.020), "char_medic_white", lift=0.002)  # DB-G3: a cigarette
    n.front_item(kit, -0.095, 1.335, (0.056, 0.020, 0.021), "char_tie_burgundy", lift=0.002)  # pack, red top
    kit.notes["look"] = ("dockhand: rust waxed dock jacket, graphite beanie, flare-orange bandana gaiter, drab "
                         "cargos, green rubber boots, fingerless gloves; sling + shell loops, slung pump-gun")


def hood(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    boots = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(boots)
    tr = n.trousers(kit, "char_trousers_black", boots, belt_z + 0.022 * k, hem_r=0.062)
    cg.cargo_pockets(kit, tr, "char_trousers_black", z=0.57)
    cg.fingerless_gloves(kit, "char_leather_black", cuff_len=0.05)
    knit = g.knit_top(fit, kit.hull(), HOODIE, hips_z - 0.05 * k, neck="none", base=0.010)
    kit.add_soft(knit)
    # kangaroo pocket
    pk = Mesh()
    patch(pk, kit.hull(), Vector((0.0, 0.0, hips_z + 0.06 * k)), Vector((1, 0, 0)), cg.UP,
          rounded_rect(0.24 * k, 0.12 * k, 0.03 * k, 2), 0.005 * k, HOODIE, cast_dir=Vector((0, -1, 0)), rings=2,
          chamfer=0.004 * k)
    kit.add_soft(pk)
    soft, zipm = g.gilet(fit, kit.hull(), PUFFER, hips_z + 0.07 * k, base=0.014, quilt=0.012)
    kit.add_soft(soft)
    kit.add_gear(zipm)
    # belt over the hoodie hem: holster on the right hip (behind the Hip seat), mag pouch on the left
    belt = gk.Belt(fit, Hull(fit, [knit, tr], body_regions=set()), belt_z - 0.025 * k, height=0.042, thick=0.006)
    kit.add_soft(belt.mesh("char_leather_black"))
    bg = gk.buckle(belt, "chrome", w=0.05, h=0.042)
    bg.extend(gk.holster(belt, math.radians(118.0)))
    bg.extend(gk.pouch(belt, math.radians(-110.0), 0.06, 0.075, 0.028, "char_leather_black", snap="chrome"))
    kit.add_gear(bg)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.01 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    kit.add_head(cg.gaiter_up(fit, KNIT_DARK))
    kit.add_head(cg.hood_up(fit, HOODIE, cord_mat="char_knit_cream"))
    kit.notes["hat"] = "hood up + gaiter pulled over the nose (Headwear)"
    n.front_item(kit, 0.090, 1.290, (0.070, 0.135, 0.009), "polymer_black", lift=0.002)   # DB-G3: a phone
    kit.notes["look"] = ("hood: grey hoodie with the hood up, gaiter over the nose, black puffer vest, belt with "
                         "holster + pouch, black cargos, brown work boots, fingerless gloves; sling across the chest")


def deckhand(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, _belt_z = _z(kit)
    waist_z = fit.ring_centre("waist").z
    # the sweater hangs over the overalls' waistband at the sides and back (the bib goes over it)
    knit = g.knit_top(fit, kit.hull(), KNIT_CREAM, waist_z - 0.005 * k, neck="roll", base=0.011)
    kit.add_soft(knit)
    tr, _bib = cg.bib_overalls(kit, OILSKIN, 1.29 * k, waist_z + 0.03 * k)
    cg.rubber_boots(kit, tr, RUBBER, top_z=0.38)
    kit.add_soft(tr)
    loop = cg.StrapLoop(kit, -1.0, waist_z - 0.03 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    band = cg.StrapLoop(kit, 1.0, waist_z - 0.06 * k, shoulder_in=0.115)
    bstrap = band.build(kit, "leather_dark", 0.026, 0.005)
    cg.shell_row(kit, bstrap, band.front, 0.18, 0.80, 12, 0.005, SHELL)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.22, WOOD, GUNMETAL, stand_off=0.032))
    kit.add_head(contact.moustache(fit, "char_hair_grey"))
    kit.notes["hat"] = "bare head (grey buzz cut); moustache (Headwear)"
    n.watch(kit, "L", strap="char_satin_gold", case="char_satin_gold")                # DB-G3: a gold watch
    kit.notes["look"] = ("deckhand: cream fisherman roll-neck, flare-orange oilskin bib overalls, green rubber "
                         "boots, bare head + moustache; sling and shell bandolier crossed, slung pump-gun")


def _cargos_boots(kit: Kit, belt_z: float) -> Mesh:
    k = kit.k
    tr = g.trousers(kit.fit, CARGO, belt_z + 0.022 * k, hem_r=0.064, base=0.0085, hull=kit.hull()).mesh
    straighten_loop(tr, g.classify_loops(tr)["top"], iters=3)
    cg.rubber_boots(kit, tr, RUBBER, top_z=0.34)
    kit.add_soft(tr)
    cg.cargo_pockets(kit, tr, CARGO, z=0.58)
    return tr


def deck_woman(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _cargos_boots(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black")
    knit = g.knit_top(fit, kit.hull(), KNIT_CREAM, hips_z - 0.05 * k, neck="roll", base=0.011)
    kit.add_soft(knit)
    soft, zipm = g.gilet(fit, kit.hull(), PUFFER, hips_z + 0.06 * k, base=0.014, quilt=0.012)
    kit.add_soft(soft)
    kit.add_gear(zipm)
    cg.neck_gaiter(kit, FLARE, t0=0.10, t1=0.85, radial=0.016)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.01 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    kit.add_head(contact.chignon(fit, "char_hair_dark", size=0.8))
    kit.notes["hat"] = "bare head, dark hair in a bun (Headwear)"
    kit.add_head(contact.earrings(fit, "char_satin_gold"))                            # DB-G3: gold hoops
    kit.notes["look"] = ("deck_woman: cream roll-neck under a black puffer vest, flare-orange gaiter, drab cargos, "
                         "green rubber boots, fingerless gloves; sling across the chest")


def smock(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _cargos_boots(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black")
    cg.work_jacket(kit, OILSKIN, CORD, hips_z - 0.075 * k, 1.36 * k)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.02 * k)
    strap = loop.build(kit, WEBBING, 0.020, 0.004)
    cg.shell_row(kit, strap, loop.front, 0.40, 0.72, 8, 0.004, SHELL)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.24, WOOD, GUNMETAL))
    kit.add_head(cg.beanie(fit, KNIT_CREAM))
    kit.notes["hat"] = "cream knit watch-cap beanie (Headwear)"
    n.front_item(kit, 0.085, 1.290, (0.058, 0.110, 0.034), "polymer_black", lift=0.002)   # DB-G3: a walkie-talkie
    n.front_item(kit, 0.100, 1.370, (0.008, 0.070, 0.008), "polymer_black", lift=0.020)   # and its antenna
    kit.notes["look"] = ("smock: flare-orange oilskin work jacket, cream beanie, drab cargos, green rubber boots, "
                         "fingerless gloves; sling + shell loops, slung pump-gun")


def balaclava(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    boots = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(boots)
    tr = n.trousers(kit, "char_trousers_black", boots, belt_z + 0.022 * k, hem_r=0.062)
    cg.cargo_pockets(kit, tr, "char_trousers_black", z=0.57)
    cg.fingerless_gloves(kit, "char_leather_black", cuff_len=0.05)
    knit = g.knit_top(fit, kit.hull(), KNIT_DARK, hips_z - 0.05 * k, neck="roll", base=0.010)
    kit.add_soft(knit)
    soft, zipm = g.gilet(fit, kit.hull(), PUFFER, hips_z + 0.07 * k, base=0.014, quilt=0.012)
    kit.add_soft(soft)
    kit.add_gear(zipm)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.01 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    kit.add_head(cg.gaiter_up(fit, KNIT_DARK))
    kit.add_head(cg.beanie(fit, KNIT_DARK))
    kit.notes["hat"] = "graphite beanie + gaiter pulled over the nose: a balaclava read (Headwear)"
    for i, x in enumerate((0.110, 0.122)):                                            # DB-G3: zip ties
        n.front_item(kit, x, 1.020 - 0.008 * i, (0.006, 0.130, 0.003), "char_medic_white", lift=0.003)
    kit.notes["look"] = ("balaclava: graphite beanie and gaiter over the nose, graphite knit pull-over, black puffer "
                         "vest, black cargos, brown work boots, fingerless gloves; sling across the chest")


# =============================================================================================
# D-115: the 12-face pool (g-l)
# =============================================================================================
def _black_cargos(kit: Kit, belt_z: float) -> Mesh:
    boots = g.shoes(kit.fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.007, boot=True)
    kit.add_soft(boots)
    tr = n.trousers(kit, "char_trousers_black", boots, belt_z + 0.022 * kit.k, hem_r=0.062)
    cg.cargo_pockets(kit, tr, "char_trousers_black", z=0.57)
    return tr


def navy_hood(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _cargos_boots(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black")
    knit = g.knit_top(fit, kit.hull(), KNIT_NAVY, hips_z - 0.06 * k, neck="none", base=0.011)
    kit.add_soft(knit)
    pk = Mesh()
    patch(pk, kit.hull(), Vector((0.0, 0.0, hips_z + 0.05 * k)), Vector((1, 0, 0)), cg.UP,
          rounded_rect(0.25 * k, 0.12 * k, 0.03 * k, 2), 0.005 * k, KNIT_NAVY, cast_dir=Vector((0, -1, 0)), rings=2,
          chamfer=0.004 * k)
    kit.add_soft(pk)
    loop = cg.StrapLoop(kit, 1.0, fit.ring_centre("waist").z - 0.02 * k)
    loop.build(kit, WEBBING, 0.020, 0.004)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.24, WOOD, GUNMETAL))
    kit.add_head(cg.hood_up(fit, KNIT_NAVY, cord_mat=KNIT_CREAM))
    kit.notes["hat"] = "navy hood up, face bare (Headwear)"
    kit.add_head(gk.glasses(fit, "char_button_dark"))                                # DB-G3: dark glasses
    kit.notes["look"] = ("navy_hood: navy hoodie with the hood up (face bare), drab cargos, green rubber boots, "
                         "fingerless gloves; sling over the right shoulder, slung pump-gun")


def flare_beanie(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _black_cargos(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black", cuff_len=0.05)
    cg.work_jacket(kit, "char_work_charcoal", CORD, hips_z - 0.07 * k, 1.36 * k)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.02 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    kit.add_head(cg.beanie(fit, FLARE))
    kit.notes["hat"] = "flare-orange knit watch-cap beanie over a dark bob (Headwear)"
    n.front_item(kit, 0.120, 0.985, (0.020, 0.032, 0.006), "char_satin_gold", lift=0.003)  # DB-G3: a carabiner
    n.front_item(kit, 0.118, 0.950, (0.012, 0.040, 0.003), "char_metal_silver", lift=0.004)  # of keys
    kit.notes["look"] = ("flare_beanie: flare-orange beanie, charcoal canvas work jacket with a corduroy collar, "
                         "black cargos, brown work boots, fingerless gloves; sling across the chest")


def drab_bib(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    waist_z = fit.ring_centre("waist").z
    knit = g.knit_top(fit, kit.hull(), KNIT_SLATE, waist_z - 0.005 * k, neck="roll", base=0.011)
    kit.add_soft(knit)
    tr, _bib = cg.bib_overalls(kit, CARGO, 1.29 * k, waist_z + 0.03 * k)
    cg.rubber_boots(kit, tr, RUBBER, top_z=0.38)
    kit.add_soft(tr)
    loop = cg.StrapLoop(kit, -1.0, waist_z - 0.03 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    band = cg.StrapLoop(kit, 1.0, waist_z - 0.06 * k, shoulder_in=0.115)
    bstrap = band.build(kit, "leather_dark", 0.026, 0.005)
    cg.shell_row(kit, bstrap, band.front, 0.18, 0.80, 12, 0.005, SHELL)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.22, WOOD, GUNMETAL, stand_off=0.032))
    kit.notes["hat"] = "bare head (grey short hair, grey beard shadow)"
    n.ear_item(kit, 1.0)                                                             # DB-G3: a tally pencil
    kit.notes["look"] = ("drab_bib: slate roll-neck under drab canvas bib overalls, green rubber boots, bare grey "
                         "head; sling and shell bandolier crossed, slung pump-gun")


def bandana(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    tr = _cargos_boots(kit, belt_z)
    n.belt(kit, tr, belt_z, mat="char_leather_black", buckle="chrome", height=0.034)
    cg.fingerless_gloves(kit, "char_leather_black")
    knit = g.knit_top(fit, kit.hull(), KNIT_GREY, hips_z - 0.06 * k, neck="crew", base=0.013, rib=0.04)
    kit.add_soft(knit)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.01 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    # a bandana tied flat over the head: a snug cap (no cuff, no slouch) and a knot at the nape
    kit.add_head(cg.beanie(fit, BANDANA, front_el=16.0, back_el=-4.0, cuff=0.04, slouch=0.0))
    knot = contact.chignon(fit, BANDANA, size=0.5, lift=-0.01)
    kc = sum(knot.v, Vector()) / len(knot.v)
    for sx in (-1.0, 1.0):   # the two tails hanging from the knot
        tail = [kc + Vector((sx * 0.006 * k, -0.010 * k, -0.004 * k)),
                kc + Vector((sx * 0.016 * k, -0.020 * k, -0.045 * k)),
                kc + Vector((sx * 0.024 * k, -0.022 * k, -0.085 * k))]
        o.tube(knot, tail, lambda t: (0.011 - 0.006 * t) * k, BANDANA, sides=6, weights=lambda p, t: sg.HEAD_W)
    kit.add_head(knot)
    kit.notes["hat"] = "rust bandana tied on the head, knot at the nape (Headwear)"
    for x in (-0.030, 0.030):                                                         # DB-G3: sunglasses hung
        n.front_item(kit, x, 1.395, (0.048, 0.036, 0.004), "char_button_dark", lift=0.003)  # at the collar
    n.front_item(kit, 0.0, 1.408, (0.014, 0.005, 0.003), "char_button_dark", lift=0.003)
    kit.notes["look"] = ("bandana: rust head bandana, concrete-grey fleece pull-over, drab cargos, green rubber "
                         "boots, fingerless gloves; sling across the chest")


def olive_jacket(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _cargos_boots(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black")
    cg.work_jacket(kit, "char_nylon_olive", CORD, hips_z - 0.075 * k, 1.36 * k)
    cg.neck_gaiter(kit, KNIT_DARK, t0=0.10, t1=0.85, radial=0.016)
    loop = cg.StrapLoop(kit, 1.0, fit.ring_centre("waist").z - 0.02 * k)
    strap = loop.build(kit, WEBBING, 0.020, 0.004)
    cg.shell_row(kit, strap, loop.front, 0.40, 0.72, 8, 0.004, SHELL)
    _gun_note(kit, cg.slung_gun(kit, loop, 1.24, WOOD, GUNMETAL))
    kit.notes["hat"] = "bare head (short blond hair)"
    n.front_item(kit, -0.105, 1.255, (0.014, 0.075, 0.006), "polymer_black", lift=0.002)  # DB-G3: a pocket-knife
    n.front_item(kit, -0.105, 1.285, (0.008, 0.030, 0.003), "char_metal_silver", lift=0.006)  # clip
    kit.notes["look"] = ("olive_jacket: olive nylon work jacket, graphite neck gaiter, bare blond head, drab cargos, "
                         "green rubber boots, fingerless gloves; sling + shell loops (right shoulder), slung pump-gun")


def cream_hoodie(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z = _z(kit)
    _black_cargos(kit, belt_z)
    cg.fingerless_gloves(kit, "char_leather_black", cuff_len=0.05)
    n.hoodie(kit, "char_hoodie_cream", hips_z - 0.06 * k, string_mat=CORD)
    loop = cg.StrapLoop(kit, -1.0, fit.ring_centre("waist").z - 0.01 * k)
    loop.build(kit, WEBBING, 0.019, 0.004)
    kit.notes["hat"] = "bare shaved head"
    n.bead_necklace(kit, "char_satin_gold", beads=20, r=0.0034)                       # DB-G3: a gold chain
    kit.notes["look"] = ("cream_hoodie: cream pull-over hoodie (hood down), shaved head, black cargos, brown work "
                         "boots, fingerless gloves; sling across the chest")


_looks = {"dockhand": dockhand, "hood": hood, "deckhand": deckhand, "deck_woman": deck_woman, "smock": smock,
          "balaclava": balaclava, "navy_hood": navy_hood, "flare_beanie": flare_beanie, "drab_bib": drab_bib,
          "bandana": bandana, "olive_jacket": olive_jacket, "cream_hoodie": cream_hoodie}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)
    kit.notes["insignia"] = "none (plain work wear; no police/faction material ids)"


def build(ctx) -> None:
    build_character(ctx, recipe)
