"""glTF 2.0 binary export with fixed options (Blender only).

Fixed policy (style guide §6): .glb, +Y up, modifiers applied, rotation/scale of mesh objects
applied, tangents on, no cameras or lights, no custom-property extras, no compression.
Materials are exported by name with flat factors only (``export_image_format="NONE"``) unless
``embed=True``. Every option is passed explicitly so a different exporter default cannot change the
output silently. After writing, ``lib.glb.normalise()`` rewrites the JSON chunk in a canonical form
(sorted keys, fixed generator string) so the bytes are reproducible.
"""

from __future__ import annotations

import pathlib

import bpy

from . import glb, naming, scene

GENERATOR = "CAPERWORKS tools/blender (Khronos glTF Blender I/O)"


class ExportError(RuntimeError):
    pass


def validate(tri_budget: int | None = None) -> list[str]:
    """Check names/materials before export. Returns warnings; raises ExportError on hard errors."""
    errors: list[str] = []
    warnings: list[str] = []
    tris = 0
    for obj in scene.all_objects():
        if obj.type in {"CAMERA", "LIGHT"}:
            continue
        if obj.type != "MESH":
            continue
        if naming.is_collision_name(obj.name):
            continue
        mats = [m for m in obj.data.materials if m is not None]
        if not mats:
            errors.append(f"{obj.name}: mesh without material (default material is forbidden)")
        for m in mats:
            if naming.library_id_from_material(m.name) is None:
                errors.append(f"{obj.name}: material {m.name!r} is not named M_<library_id>")
        if not obj.data.uv_layers:
            warnings.append(f"{obj.name}: no UV layer (tangents need UVs)")
        from . import geo  # local: geo imports scene; avoid import cycles at module load
        tris += geo.tri_count(obj)
    if tri_budget is not None and tris > tri_budget:
        errors.append(f"LOD0 has {tris} triangles, budget is {tri_budget}")
    if errors:
        raise ExportError("; ".join(errors))
    return warnings


def _apply_rot_scale() -> None:
    meshes = [o for o in scene.all_objects() if o.type == "MESH"
              and (o.rotation_euler[:] != (0.0, 0.0, 0.0) or o.scale[:] != (1.0, 1.0, 1.0))]
    if not meshes:
        return
    for o in bpy.context.view_layer.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True, properties=False)


def _triangulate_ngons() -> None:
    """Tangents need tris/quads: add a final Triangulate modifier to meshes that contain n-gons."""
    for obj in scene.all_objects():
        if obj.type != "MESH" or not any(len(p.vertices) > 4 for p in obj.data.polygons):
            continue
        if any(m.type == "TRIANGULATE" for m in obj.modifiers):
            continue
        mod = obj.modifiers.new("ExportTriangulate", "TRIANGULATE")
        mod.min_vertices = 5
        mod.quad_method = "BEAUTY"
        mod.ngon_method = "BEAUTY"
        mod.keep_custom_normals = True


def export_glb(path: pathlib.Path | str, embed: bool = False, animations: bool = False,
               skins: bool = False, morph: bool = False) -> pathlib.Path:
    """Export the whole scene to ``path`` (.glb) and normalise it. Returns the path."""
    out = pathlib.Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj)
    _apply_rot_scale()
    _triangulate_ngons()
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        check_existing=False,
        export_format="GLB",
        export_copyright="",
        export_image_format="AUTO" if embed else "NONE",
        export_keep_originals=False,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_draco_mesh_compression_enable=False,
        export_use_gltfpack=False,
        export_materials="EXPORT",
        export_unused_images=False,
        export_unused_textures=False,
        export_vertex_color="MATERIAL",
        export_attributes=False,
        use_mesh_edges=False,
        use_mesh_vertices=False,
        export_cameras=False,
        export_lights=False,
        use_selection=False,
        use_visible=False,
        use_renderable=False,
        use_active_collection=False,
        use_active_scene=False,
        export_extras=False,
        export_yup=True,
        export_apply=True,
        export_shared_accessors=False,
        export_gpu_instances=False,
        export_hierarchy_full_collections=False,
        export_hierarchy_flatten_objs=False,
        export_animations=animations,
        export_skins=skins,
        export_morph=morph,
        export_original_specular=False,
        will_save_settings=False,
    )
    glb.normalise(out, generator=f"{GENERATOR} {_exporter_version()}")
    return out


def _exporter_version() -> str:
    import addon_utils

    for mod in addon_utils.modules():
        if mod.__name__ == "io_scene_gltf2":
            return ".".join(str(x) for x in mod.bl_info.get("version", ()))
    return "unknown"
