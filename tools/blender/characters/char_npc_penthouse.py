"""Shadow Ledger NPCs: the Kessler & Moor penthouse at night, in the rain (D2-02).

Heist palette (style guide §3): graphite ``#2E3136`` dominant, glass teal ``#5D8C8F`` secondary,
cold-white LED ``#CFE3EE`` accent. The guests and staff stay dark (graphite, black, deep teal) so
the one pale figure in the room is the target:

* ``char_npc_penthouse_guest_a``: woman in a deep glass-teal satin cocktail dress (cap sleeves,
  scoop neck, knee length), black heels, a blond chignon and silver drop earrings.
* ``char_npc_penthouse_guest_b``: man in a dinner suit: black jacket with satin lapels and a white
  pocket square, white shirt, black bow tie, trousers with a satin side stripe.
* ``char_npc_penthouse_staff``: waitress / butler's staff: white shirt, black bow tie, graphite
  waistcoat, long black bistro apron over black trousers, dark hair in a chignon.
* ``char_npc_kessler``: Victor Kessler at home (D-063 default: ``kessler_sleepover``, reading in the bedside armchair (D-116, ``sit_chair_read``)
  in the M5 guest suite): the same body as below; graphite silk pyjamas with ice piping, a long
  ice-silk dressing robe (graphite shawl collar, graphite sash tied at the side) and graphite
  slippers. Still the only pale full-length figure.
* ``char_npc_kessler_coat``: Victor Kessler, the target. The tallest figure (1.88 m, the rig's limit),
  silver hair with a side parting, a long double-breasted ice-white overcoat (the cold-white
  accent, toned into the albedo range) with a graphite collar over a graphite roll-neck, and a
  glass-teal pocket square. Readable at 20-30 m in a crowd by value alone: the only pale full-length
  figure among dark suits and dresses.

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear`` (updos,
earrings). No blend shapes (baked at the params below).
"""

import _contact_gear as cg
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
from _outfit import Hull, Mesh, Vector
from _outfit_build import Kit, build_character

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

VARIANTS = {
    "char_npc_penthouse_guest_a": {"height": 1.73, "build": 0.25, "gender": 1.0, "age": 0.35, "skin": 3,
                                   "hair": "side_part", "hair_color": "blond", "lip": "char_lip_rose", "look": "guest_a"},
    "char_npc_penthouse_guest_b": {"height": 1.84, "build": 0.5, "gender": 0.0, "age": 0.4, "skin": 6, "beard_shadow": 0.3,
                                   "hair": "buzz", "hair_color": "dark", "look": "guest_b"},
    "char_npc_penthouse_staff": {"height": 1.70, "build": 0.3, "gender": 1.0, "age": 0.25, "skin": 4, "hair": "side_part",
                                 "hair_color": "dark", "look": "staff"},
    "char_npc_kessler": {"height": 1.88, "build": 0.35, "gender": 0.0, "age": 0.8, "skin": 1, "beard_shadow": 0.25,
                         "hair": "side_part", "hair_color": "grey", "look": "kessler_robe"},
    "char_npc_kessler_coat": {"height": 1.88, "build": 0.35, "gender": 0.0, "age": 0.8, "skin": 1,
                              "beard_shadow": 0.25, "hair": "side_part", "hair_color": "grey", "look": "kessler"},
}

TEAL = "char_satin_teal"
TUX = "char_tux_black"
SATIN = "char_satin_black"
GRAPHITE = "char_waistcoat_graphite"
ICE = "char_coat_ice"
SILK_ICE = "char_silk_ice"
SILK_GRAPHITE = "char_silk_graphite"


def _z(kit: Kit) -> tuple[float, float, float]:
    hips_z = kit.fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * kit.k
    return hips_z, belt_z, belt_z - 0.02 * kit.k


def guest_a(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    n.shoes(kit, heel=True)
    d = g.dress(fit, TEAL, 0.44 * k, sleeve=0.16, scoop=0.07, flare=0.12)
    kit.add_soft(d)
    waist = fit.ring_centre("waist").z
    b = gk.Belt(fit, Hull(fit, [d], body_regions=set()), waist, height=0.018, thick=0.003, drop=0.0)
    kit.add_soft(b.mesh(TEAL))
    kit.add_head(cg.chignon(fit, "char_hair_blond"))
    kit.add_head(cg.earrings(fit, "chrome"))


def guest_b(kit: Kit) -> None:
    k = kit.k
    _hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.05)
    tr = n.trousers(kit, TUX, sh, belt_z + 0.022 * k)
    n.trouser_stripes(kit, tr, SATIN, belt_z + 0.022 * k, half_w=0.007)
    n.bow_tie(kit, "char_tie_black")
    n.jacket(kit, TUX, 0.80 * k, 1.03 * k, lapel_mat=SATIN, button_mat=SATIN, lapel_w=0.06, neck_w=0.085)
    pk = Mesh()
    o.patch(pk, kit.hull(), Vector((-0.095 * k, 0.0, 1.318 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            [(-0.035 * k, -0.006 * k), (0.035 * k, -0.006 * k), (0.03 * k, 0.012 * k), (0.012 * k, 0.02 * k),
             (-0.008 * k, 0.014 * k), (-0.03 * k, 0.018 * k)], 0.004 * k, "char_shirt_white",
            cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)


def staff(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z, belt_z, tuck = _z(kit)
    sh = n.shoes(kit)
    n.shirt(kit, "char_shirt_white", tuck, point_len=0.048)
    n.trousers(kit, "char_trousers_black", sh, belt_z + 0.022 * k)
    n.bow_tie(kit, "char_tie_black", half_w=0.046)
    n.waistcoat(kit, GRAPHITE, hips_z - 0.01 * k, 1.12 * k, point=0.05, neck_w=0.07, buttons=4,
                button_mat="char_metal_silver")
    n.waist_apron(kit, TUX, belt_z + 0.01 * k, 0.30 * k)
    kit.add_gear(gk.name_tag(kit.hull(), Vector((0.085 * k, 0.2, 1.30 * k)), k=k, mat="char_metal_silver"))
    kit.add_head(cg.chignon(fit, "char_hair_dark"))


def kessler(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    _hips_z, belt_z, _tuck = _z(kit)
    sh = n.shoes(kit)
    knit = g.knit_top(fit, kit.hull(), "char_knit_graphite", belt_z - 0.01 * k, neck="roll", base=0.006)
    kit.add_soft(knit)
    n.trousers(kit, "char_suit_dark", sh, belt_z + 0.022 * k)
    n.jacket(kit, ICE, 0.42 * k, 1.13 * k, lapel_mat=GRAPHITE, double=True, button_mat="char_button_dark",
             lapel_w=0.085, neck_w=0.095, flare=0.12, base=0.013, open_below=0.05)
    hull = kit.hull()
    pk = Mesh()
    o.patch(pk, hull, Vector((-0.10 * k, 0.0, 1.318 * k)), Vector((1, 0, 0)), Vector((0, 0, 1)),
            [(-0.035 * k, -0.006 * k), (0.035 * k, -0.006 * k), (0.032 * k, 0.016 * k), (0.016 * k, 0.026 * k),
             (-0.006 * k, 0.016 * k), (-0.028 * k, 0.024 * k)], 0.004 * k, TEAL,
            cast_dir=Vector((-0.2, -1, 0)), rings=1, chamfer=0.002 * k)
    kit.add_soft(pk)
    kit.notes["target_note"] = ("Kessler: unique silhouette = tallest, long pale double-breasted coat, "
                                "silver hair; colour accent = ice-white coat + glass-teal pocket square")


def kessler_robe(kit: Kit) -> None:
    """Kessler at home in the guest suite (reading in the bedside armchair, D-063 / D-116): graphite silk pyjamas with ice
    piping under a long ice-silk dressing robe with a graphite shawl collar and sash, slippers."""
    fit, k = kit.fit, kit.k
    hips_z, belt_z, _tuck = _z(kit)
    sl = g.shoes(fit, SILK_GRAPHITE, "leather_dark", top_z=0.05, base=0.0045, toe=0.012)
    kit.add_soft(sl)
    n.shirt(kit, SILK_GRAPHITE, hips_z - 0.01 * k, collar="fold", point_len=0.052, spread=0.30)
    tr = n.trousers(kit, SILK_GRAPHITE, sl, belt_z + 0.022 * k, hem_r=0.066)
    robe_hem = 0.36 * k
    # D-116: the ice piping only where it shows, below the robe hem. Under the robe the trouser faces are culled but a
    # stripe on them was not, so seated (the robe side lifting off the thigh) it stood out as a pale strip from the
    # waist to the floor.
    n.trouser_stripes(kit, tr, SILK_ICE, robe_hem + 0.05 * k, half_w=0.0045)
    n0 = len(kit.soft.f)
    wrap_z = 1.00 * k
    robe, _info = n.jacket(kit, SILK_ICE, robe_hem, wrap_z, lapel_mat=SILK_GRAPHITE, buttons=False, chest_welt=False,
                           neck_w=0.085, lapel_w=0.075, flare=0.10, base=0.012, open_below=0.06, sleeve=1.88)
    n.cull_under(kit, n0, robe, "faces_hidden_by_robe")
    n.sash(kit, robe, SILK_GRAPHITE, wrap_z - 0.01 * k, side=1.0)
    kit.add_head(gk.glasses(fit, "char_satin_gold"))                                  # SL-G3: gold reading glasses
    kit.notes["target_note"] = ("Kessler (default, reading in the armchair): tallest, silver hair; long ice-silk robe with a "
                                "graphite shawl collar and sash over graphite pyjamas with ice piping. The long-coat "
                                "version is char_npc_kessler_coat")


_looks = {"guest_a": guest_a, "guest_b": guest_b, "staff": staff, "kessler": kessler, "kessler_robe": kessler_robe}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)
