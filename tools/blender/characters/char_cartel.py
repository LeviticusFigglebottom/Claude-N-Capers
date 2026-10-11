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
import _outfit_garments as g
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
    kit.notes["look"] = ("deckhand: cream fisherman roll-neck, flare-orange oilskin bib overalls, green rubber "
                         "boots, bare head + moustache; sling and shell bandolier crossed, slung pump-gun")


_looks = {"dockhand": dockhand, "hood": hood, "deckhand": deckhand}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)
    kit.notes["insignia"] = "none (plain work wear; no police/faction material ids)"


def build(ctx) -> None:
    build_character(ctx, recipe)
