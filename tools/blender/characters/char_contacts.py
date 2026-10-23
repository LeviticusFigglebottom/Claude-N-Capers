"""Contacts for the heist briefing screen (ENV B request QB-50a): full skinned characters on
``rig_humanoid``, used for the portrait busts (``_contact_portrait.py`` renders the stills,
``game/world/characters/portraits/`` holds the live bust scenes).

* ``char_contact_odile``: Odile Vance, the fence. Mature, poised and elegant; a black tailored
  blazer over a plum silk blouse (stand collar, no tie), black trousers, dark hair (no body hair
  cap: ``crown_volume`` is the whole swept-back hair, fuller at the upper sides so the head reads
  less long) with a clear side-swept fringe framing the face and a full chignon, a heavy-lidded
  liner band (``heavy_lids``: unimpressed rather than wide-eyed), rose lipstick (the body's lip
  region, ``lip`` param), small gold drop earrings and a gold lapel bar. Softer, fuller face than
  a gaunt fence: younger ``age`` and more ``build`` (fuller cheeks, no submalar hollow).
* ``char_contact_hollis``: Hollis "Hammer" Reyes, the fixer. Heavy, broad, older, a thick neck;
  a cheap brown suit with an open-collar pale shirt, a tweed flat cap over a grey buzz cut and a
  heavy grey moustache.
* ``char_contact_hollis_rt`` (RT-G3, Rolling Thunder: Reyes at the wheel of his ram mixer, seen through the
  windscreen and in the cab shots): the same man (body, face, grey buzz cut, moustache, flat cap) dressed for the
  site, so he reads at 4-8 m: a high-collared orange hi-vis work jacket zipped up, silver tape hoops round the body
  and the arms, brown work trousers and boots, tan rigger gloves on the wheel, a radio handset clipped at his chest
  (he is "on the radio"). The briefing bust keeps ``char_contact_hollis`` (the suit).
* ``char_contact_accountant``: The Accountant. Shown only as a backlit silhouette, so the shape
  carries it: a slim dark suit, white shirt and black tie, a fedora and silver glasses with glossy
  lenses (the glint).

Meshes: ``Body`` (covered skin removed), ``Hair`` (not Odile: her hair is all ``Headwear``), ``Outfit``,
``Gear``, ``Headwear``. No blend
shapes (baked at the params below).
"""

import math

import _cartel_gear as cgr
import _contact_gear as cg
import _gear_kit as gk
import _npc as n
import _outfit as o
import _outfit_garments as g
from _outfit import Mesh, Vector
from _outfit_build import Kit, build_character
from char_crew import suit

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False, "remove_armature": True}

HIVIS = "char_hivis_orange"   # site orange: never the police yellow or Vaultline amber
TAPE = "char_reflect_silver"

VARIANTS = {
    "char_contact_odile": {"height": 1.73, "build": 0.45, "gender": 1.0, "age": 0.25, "skin": 2, "hair": "none",
                           "hair_color": "dark", "lip": "char_lip_rose", "look": "odile"},
    "char_contact_hollis": {"height": 1.77, "build": 0.85, "gender": 0.0, "age": 0.85, "skin": 2, "hair": "buzz",
                            "hair_color": "grey", "beard_shadow": 0.7, "look": "hollis"},
    "char_contact_hollis_rt": {"height": 1.77, "build": 0.85, "gender": 0.0, "age": 0.85, "skin": 2, "hair": "buzz",
                               "hair_color": "grey", "beard_shadow": 0.8, "look": "hollis_rt"},
    "char_contact_accountant": {"height": 1.80, "build": 0.3, "gender": 0.0, "age": 0.5, "skin": 2, "hair": "short",
                                "hair_color": "dark", "look": "accountant"},
}


def odile(kit: Kit) -> None:
    k = kit.k
    suit(kit, "char_suit_dark", "char_silk_plum", None, shoe_mat="char_shoe_black", trouser_mat="char_trousers_black",
         hem_z=0.82, button_z=1.04)
    kit.add_gear(cg.lapel_pin(kit.hull(), Vector((-0.085 * k, 0.2, 1.335 * k)), "brass", k=k))
    kit.add_head(cg.chignon(kit.fit, "char_hair_dark", size=1.2, lift=0.008))
    crown = (0.004, 0.016)
    cg.head_piece(kit, cg.crown_volume(kit.fit, "char_hair_dark", *crown))
    cg.head_piece(kit, cg.side_fringe(kit.fit, "char_hair_dark", crown=crown))
    kit.add_head(cg.earrings(kit.fit, "brass"))
    bp = kit.fit.params
    kit.add_head(cg.heavy_lids(kit.fit, "char_lash", bp["build"], bp["gender"], bp["age"]))
    kit.notes["portrait"] = "QB-50a contact bust: Odile Vance (fence)"


def hollis(kit: Kit) -> None:
    suit(kit, "char_suit_brown", "char_sec_shirt", None, shoe_mat="char_shoe_brown", trouser_mat="char_suit_brown",
         hem_z=0.80, button_z=1.02)
    cap, info = cg.flat_cap(kit.fit, "char_tweed_grey")
    kit.add_head(cap)
    kit.add_head(cg.moustache(kit.fit, "char_hair_dark", thick=0.0058))
    kit.notes["head_note"] = f"flat cap (top z {info['top_z']:.3f} m, Blender axes)"
    kit.notes["portrait"] = "QB-50a contact bust: Hollis 'Hammer' Reyes (fixer)"


def _hoop(kit: Kit, centre: Vector, axis: Vector, mat: str, width: float, n_pts: int = 24, reach: float = 0.12) -> None:
    """A closed reflective tape band on the current outer surface, round ``axis`` through ``centre``; the rays start
    ``reach`` out from the axis (just outside the limb or torso, so a bind-pose arm is never hit first)."""
    k = kit.k
    hull = kit.hull()
    ref = Vector((0.0, 1.0, 0.0)) if abs(axis.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = (ref - axis * ref.dot(axis)).normalized()
    v = axis.cross(u)
    ring = []
    for i in range(n_pts):
        a = math.tau * i / n_pts
        d = u * math.cos(a) + v * math.sin(a)
        hit = hull.cast(centre + d * reach * k, -d, reach * k)
        ring.append((hit[0] if hit[0] is not None else centre + d * 0.6 * reach * k) + d * 0.004 * k)
    m = Mesh()
    o.strip(m, hull, ring, width * 0.5 * k, 0.0022 * k, mat, segs_across=1, chamfer=0.001 * k, closed=True,
            cast_back=0.03 * k)    # a short re-cast: a long one snaps the inner arm band onto the torso
    kit.add_soft(m)


def hollis_rt(kit: Kit) -> None:
    fit, k = kit.fit, kit.k
    hips_z = fit.ring_centre("hips").z
    belt_z = hips_z + 0.035 * k
    boots = g.shoes(fit, "char_shoe_brown", "rubber_black", top_z=0.15, base=0.0075, toe=0.013, sole_h=0.022,
                    boot=True)
    kit.add_soft(boots)
    n.shirt(kit, "char_sec_shirt", belt_z - 0.02 * k, collar="fold", sleeve=1.35, point_len=0.05)
    n.trousers(kit, "char_suit_brown", boots, belt_z + 0.022 * k, hem_r=0.064)
    cgr.work_jacket(kit, HIVIS, "char_suit_brown", hips_z - 0.06 * k, 1.44 * k)
    chest = fit.ring_centre("chest")
    for z in (1.00, 1.08):                                                     # body hoops (below the armpits)
        _hoop(kit, Vector((0.0, chest.y, z * k)), Vector((0.0, 0.0, 1.0)), TAPE, 0.040, reach=0.22)
    for sfx in ("L", "R"):                                                     # arm hoops above the elbow
        sh, el = Vector(fit.J[f"shoulder.{sfx}"]), Vector(fit.J[f"elbow.{sfx}"])
        _hoop(kit, sh.lerp(el, 0.72), (el - sh).normalized(), TAPE, 0.035, n_pts=16, reach=0.07)
    kit.add_soft(g.gloves(fit, "char_crew_glove_tan", cuff_len=0.06, base=0.0028, cuff_off=0.005))
    hull = kit.hull()
    sh_l = Vector(fit.J["shoulder.L"])
    mic, _exit = gk.speaker_mic(hull, Vector((sh_l.x + 0.06 * k, sh_l.y + 0.08 * k, sh_l.z - 0.10 * k)),
                                Vector((-0.2, 1.0, 0.2)), k=k)
    kit.add_gear(mic)
    cap, info = cg.flat_cap(fit, "char_tweed_grey")
    kit.add_head(cap)
    kit.add_head(cg.moustache(fit, "char_hair_dark", thick=0.0058))
    kit.notes["head_note"] = f"flat cap (top z {info['top_z']:.3f} m, Blender axes)"
    kit.notes["look"] = ("Hollis 'Hammer' Reyes at the mixer's wheel (RT-G3): orange hi-vis work jacket zipped high, "
                         "silver tape hoops (body, arms), pale shirt, brown work trousers and boots, tan rigger "
                         "gloves, radio handset at the chest, tweed flat cap, grey moustache")


def accountant(kit: Kit) -> None:
    suit(kit, "char_suit_dark", "char_shirt_white", "char_tie_black", hem_z=0.80, button_z=1.06)
    hat, info = cg.fedora(kit.fit, "char_suit_dark", "char_tie_black")
    kit.add_head(hat)
    kit.add_head(gk.glasses(kit.fit, "char_metal_silver"))
    kit.add_head(cg.lenses(kit.fit))
    kit.notes["head_note"] = f"fedora (top z {info['top_z']:.3f} m, Blender axes), glasses with lenses"
    kit.notes["portrait"] = "QB-50a contact bust: The Accountant (backlit silhouette)"


_looks = {"odile": odile, "hollis": hollis, "hollis_rt": hollis_rt, "accountant": accountant}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    kits: list[Kit] = []

    def rec(kit: Kit) -> None:
        kits.append(kit)
        recipe(kit)

    build_character(ctx, rec)
    cg.apply_strand_uvs(kits[0])       # crown/fringe: strand UVs instead of the box projection

