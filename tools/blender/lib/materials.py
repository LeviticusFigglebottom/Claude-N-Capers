"""Material slots ``M_<library_id>`` (Blender only).

By default materials carry only a name plus a flat base colour/roughness/metallic. The .glb then
holds no textures; Godot's post-import script swaps every ``M_<id>`` surface for
``res://world/materials/<id>.tres`` from the shared library. The flat colour is the visible
fallback if that library material does not exist yet, so pick a colour close to the real one.

Unique assets (a hero prop, a weapon skin) can embed textures with ``pbr_material()`` and export
with ``embed=True``. Their library id should then not collide with a library .tres, or the
library material wins.
"""

from __future__ import annotations

import pathlib
from collections.abc import Sequence

import bpy

from . import naming

Color = Sequence[float]


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_srgb(hex_color: str) -> tuple[float, float, float]:
    """``"#B8B2A6"`` -> sRGB floats 0..1."""
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0)


def _rgb(color: Color | str) -> tuple[float, float, float]:
    if isinstance(color, str):
        return hex_to_srgb(color)
    return (float(color[0]), float(color[1]), float(color[2]))


def _principled(mat: bpy.types.Material) -> bpy.types.Node:
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return bsdf


def material(library_id: str, color: Color | str = (0.5, 0.5, 0.5), roughness: float = 0.8,
             metallic: float = 0.0, alpha: float = 1.0) -> bpy.types.Material:
    """Get or create ``M_<library_id>``.

    ``color`` is sRGB (0..1 floats or ``"#RRGGBB"``); it becomes the viewport colour and the glTF
    baseColorFactor (placeholder look in Godot until the library .tres exists). If the material
    already exists it is returned unchanged."""
    name = naming.material_name(library_id)
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    srgb = _rgb(color)
    lin = tuple(srgb_to_linear(c) for c in srgb)
    mat.diffuse_color = (*lin, alpha)
    mat.roughness = roughness
    mat.metallic = metallic
    bsdf = _principled(mat)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        mat.surface_render_method = "BLENDED"
    return mat


def _image_node(mat: bpy.types.Material, path: pathlib.Path, non_color: bool, x: float, y: float) -> bpy.types.Node:
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    node.location = (x, y)
    return node


def _gltf_output_group() -> bpy.types.NodeTree:
    """The node group the Khronos exporter reads ambient occlusion from."""
    name = "glTF Material Output"
    group = bpy.data.node_groups.get(name)
    if group is None:
        group = bpy.data.node_groups.new(name, "ShaderNodeTree")
        group.interface.new_socket(name="Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        group.interface.new_socket(name="Thickness", in_out="INPUT", socket_type="NodeSocketFloat")
    return group


def pbr_material(library_id: str, albedo: pathlib.Path | str, orm: pathlib.Path | str | None = None,
                 normal: pathlib.Path | str | None = None) -> bpy.types.Material:
    """Textured material for unique assets (export with ``embed=True``).

    ``albedo`` sRGB PNG; ``orm`` linear PNG packed R=AO, G=roughness, B=metallic (style guide §4);
    ``normal`` OpenGL (Y+) tangent-space normal map. Paths are files on disk (typically produced by
    tools/texgen into the asset's own folder)."""
    mat = material(library_id)
    bsdf = _principled(mat)
    links = mat.node_tree.links
    alb = _image_node(mat, pathlib.Path(albedo), False, -600, 300)
    links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    if orm is not None:
        orm_node = _image_node(mat, pathlib.Path(orm), True, -600, 0)
        sep = mat.node_tree.nodes.new("ShaderNodeSeparateColor")
        sep.location = (-350, 0)
        links.new(orm_node.outputs["Color"], sep.inputs["Color"])
        links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        ao = mat.node_tree.nodes.new("ShaderNodeGroup")
        ao.node_tree = _gltf_output_group()
        ao.location = (0, -400)
        links.new(sep.outputs["Red"], ao.inputs["Occlusion"])
    if normal is not None:
        nrm = _image_node(mat, pathlib.Path(normal), True, -600, -300)
        nmap = mat.node_tree.nodes.new("ShaderNodeNormalMap")
        nmap.location = (-300, -300)
        links.new(nrm.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def slot_index(obj: bpy.types.Object, mat: bpy.types.Material) -> int:
    """Index of ``mat`` in ``obj``'s material slots, appending it if needed."""
    mats = obj.data.materials
    for i, m in enumerate(mats):
        if m == mat:
            return i
    mats.append(mat)
    return len(mats) - 1


def assign(obj: bpy.types.Object, mat: bpy.types.Material, face_indices: Sequence[int] | None = None) -> int:
    """Assign ``mat`` to all faces (or ``face_indices``) of mesh object ``obj``. Returns slot index."""
    idx = slot_index(obj, mat)
    polys = obj.data.polygons
    targets = range(len(polys)) if face_indices is None else face_indices
    for i in targets:
        polys[i].material_index = idx
    return idx
