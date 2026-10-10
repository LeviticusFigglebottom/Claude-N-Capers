"""Deterministic scene reset (Blender only).

``reset()`` returns Blender to factory settings with an empty scene, removes every datablock
(including orphan meshes, materials, images and node groups) and fixes units, so each asset is
built from exactly the same starting state no matter what ran before it in the same process.
"""

from __future__ import annotations

import bpy

# Datablock collections cleared on reset. Order matters a little: objects first so their data
# become orphans, then everything else.
_DATA_COLLECTIONS = (
    "objects", "meshes", "curves", "materials", "images", "textures", "node_groups", "actions",
    "armatures", "cameras", "lights", "collections", "fonts", "grease_pencils", "lattices",
    "metaballs", "particles", "shape_keys", "worlds",
)


def reset() -> bpy.types.Scene:
    """Factory-reset Blender, purge all data, set metric units. Returns the (only) scene."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for attr in _DATA_COLLECTIONS:
        coll = getattr(bpy.data, attr, None)
        if coll is None:
            continue
        for block in list(coll):
            try:
                coll.remove(block)
            except (RuntimeError, ReferenceError, TypeError):
                pass
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    scene = bpy.context.scene
    scene.name = "Scene"
    units = scene.unit_settings
    units.system = "METRIC"
    units.scale_length = 1.0
    units.length_unit = "METERS"
    units.mass_unit = "KILOGRAMS"
    units.time_unit = "SECONDS"
    scene.frame_start = 1
    scene.frame_end = 1
    scene.frame_set(1)
    scene.render.fps = 30
    return scene


def collection() -> bpy.types.Collection:
    """The collection new objects are linked into (the scene's master collection)."""
    return bpy.context.scene.collection


def link(obj: bpy.types.Object, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    """Link ``obj`` into the scene and optionally parent it (keeping its local transform)."""
    if obj.name not in collection().objects:
        collection().objects.link(obj)
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse.identity()
    return obj


def all_objects() -> list[bpy.types.Object]:
    """Scene objects sorted by name (stable iteration for validation/export)."""
    return sorted(bpy.context.scene.objects, key=lambda o: o.name)
