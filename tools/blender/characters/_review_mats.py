"""Review/portrait render helpers: show the game's library materials in Blender. Blender only.

The character glbs carry flat placeholder colours (``M_<id>`` base colour factors); the game swaps
in ``game/world/materials/<id>.tres``. For stills that should match the game (contact portraits,
review sheets) ``library_textures()`` wires the same texture set into every imported ``M_char_*``
material that has one: albedo (the skins carry the baked face colour), ORM roughness/metallic and
the tangent-space normal map.
``terminator()`` sets Cycles' shadow-terminator offsets so smooth low-poly heads do not show the
faceted self-shadow strokes under a hard key (a render-only artefact; Godot has no such issue).
"""

from __future__ import annotations

import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
TEX = REPO / "game" / "assets" / "characters" / "_textures"


def library_textures(skip_orm: tuple[str, ...] = ()) -> int:
    """Wire library textures into the ``M_char_*`` materials. ``skip_orm``: id prefixes that keep
    their scalar roughness (art-directed tweaks). Returns the number of materials changed."""
    import bpy

    n = 0
    for m in bpy.data.materials:
        if not m.name.startswith("M_char_") or not m.use_nodes:
            continue
        lid = m.name[2:].split(".")[0]
        d = TEX / lid
        if not d.is_dir():
            continue
        nt = m.node_tree
        bsdf = next((x for x in nt.nodes if x.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or nt.nodes.get("lib_albedo") is not None:
            continue

        def img(key: str, non_color: bool, nt=nt, lid=lid, d=d):
            node = nt.nodes.new("ShaderNodeTexImage")
            node.name = f"lib_{key}"
            node.image = bpy.data.images.load(str(d / f"tex_{lid}_{key}.png"), check_existing=True)
            node.image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
            return node
        nt.links.new(img("albedo", False).outputs["Color"], bsdf.inputs["Base Color"])
        if not lid.startswith(skip_orm):
            sep = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(img("orm", True).outputs["Color"], sep.inputs["Color"])
            nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
            nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(img("normal", True).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        n += 1
    return n


def skin_sss(weight: float = 0.12) -> None:
    """Light subsurface on skin and lips (the game material's SSS, approximated)."""
    import bpy

    for m in bpy.data.materials:
        if not m.use_nodes or not ("char_skin" in m.name or "char_lip" in m.name):
            continue
        bsdf = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        bsdf.inputs["Subsurface Weight"].default_value = weight
        bsdf.inputs["Subsurface Radius"].default_value = (0.9, 0.35, 0.2)
        bsdf.inputs["Subsurface Scale"].default_value = 0.01


def terminator(geometry: float = 0.6, shading: float = 0.3) -> None:
    import bpy

    for o in bpy.data.objects:
        if o.type == "MESH":
            o.shadow_terminator_geometry_offset = geometry
            o.shadow_terminator_normal_offset = shading


def prepare(skip_orm: tuple[str, ...] = ()) -> None:
    """``library_textures`` + ``skin_sss`` + ``terminator`` (env ``NO_LIBTEX=1`` keeps placeholders)."""
    if not os.environ.get("NO_LIBTEX"):
        library_textures(skip_orm)
    skin_sss()
    terminator()
