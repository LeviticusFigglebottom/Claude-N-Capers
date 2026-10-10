"""Contacts for the heist briefing screen (ENV B request QB-50a): full skinned characters on
``rig_humanoid``, used for the portrait busts (``_contact_portrait.py`` renders the stills,
``game/world/characters/portraits/`` holds the live bust scenes).

* ``char_contact_odile``: Odile Vance, the fence. Middle-aged, slim and sharp; a black tailored
  blazer over a plum silk blouse (open collar, no tie), black trousers, a severe low chignon,
  small gold drop earrings and a gold lapel bar.
* ``char_contact_hollis``: Hollis "Hammer" Reyes, the fixer. Heavy, broad, older, a thick neck;
  a cheap brown suit with an open-collar pale shirt, a tweed flat cap over a grey buzz cut and a
  heavy grey moustache.
* ``char_contact_accountant``: The Accountant. Shown only as a backlit silhouette, so the shape
  carries it: a slim dark suit, white shirt and black tie, a fedora and silver glasses with glossy
  lenses (the glint).

Meshes: ``Body`` (covered skin removed), ``Hair``, ``Outfit``, ``Gear``, ``Headwear``. No blend
shapes (baked at the params below).
"""

import _contact_gear as cg
import _gear_kit as gk
from _outfit import Vector
from _outfit_build import Kit, build_character
from char_crew import suit

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": False, "skins": True, "morph": False}

VARIANTS = {
    "char_contact_odile": {"height": 1.73, "build": 0.15, "gender": 1.0, "age": 0.45, "skin": 2, "hair": "short",
                           "hair_color": "dark", "look": "odile"},
    "char_contact_hollis": {"height": 1.77, "build": 0.85, "gender": 0.0, "age": 0.85, "skin": 2, "hair": "buzz",
                            "hair_color": "grey", "look": "hollis"},
    "char_contact_accountant": {"height": 1.80, "build": 0.3, "gender": 0.0, "age": 0.5, "skin": 2, "hair": "short",
                                "hair_color": "dark", "look": "accountant"},
}


def odile(kit: Kit) -> None:
    k = kit.k
    suit(kit, "char_suit_dark", "char_silk_plum", None, shoe_mat="char_shoe_black", trouser_mat="char_trousers_black",
         hem_z=0.82, button_z=1.04)
    kit.add_gear(cg.lapel_pin(kit.hull(), Vector((-0.085 * k, 0.2, 1.335 * k)), "brass", k=k))
    kit.add_head(cg.chignon(kit.fit, "char_hair_dark"))
    kit.add_head(cg.earrings(kit.fit, "brass"))
    kit.add_head(cg.lips(kit.fit, "char_lip_rose"))
    kit.notes["portrait"] = "QB-50a contact bust: Odile Vance (fence)"


def hollis(kit: Kit) -> None:
    suit(kit, "char_suit_brown", "char_sec_shirt", None, shoe_mat="char_shoe_brown", trouser_mat="char_suit_brown",
         hem_z=0.80, button_z=1.02)
    cap, info = cg.flat_cap(kit.fit, "char_tweed_grey")
    kit.add_head(cap)
    kit.add_head(cg.moustache(kit.fit, "char_hair_dark", thick=0.0058))
    kit.notes["head_note"] = f"flat cap (top z {info['top_z']:.3f} m, Blender axes)"
    kit.notes["portrait"] = "QB-50a contact bust: Hollis 'Hammer' Reyes (fixer)"


def accountant(kit: Kit) -> None:
    suit(kit, "char_suit_dark", "char_shirt_white", "char_tie_black", hem_z=0.80, button_z=1.06)
    hat, info = cg.fedora(kit.fit, "char_suit_dark", "char_tie_black")
    kit.add_head(hat)
    kit.add_head(gk.glasses(kit.fit, "char_metal_silver"))
    kit.add_head(cg.lenses(kit.fit))
    kit.notes["head_note"] = f"fedora (top z {info['top_z']:.3f} m, Blender axes), glasses with lenses"
    kit.notes["portrait"] = "QB-50a contact bust: The Accountant (backlit silhouette)"


_looks = {"odile": odile, "hollis": hollis, "accountant": accountant}


def recipe(kit: Kit) -> None:
    _looks[kit.opts["look"]](kit)


def build(ctx) -> None:
    build_character(ctx, recipe)

