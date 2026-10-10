"""Blender-side helpers for the character scripts: numpy mesh soup -> skinned mesh object."""

from __future__ import annotations

import bmesh
import bpy
import numpy as np

from lib import scene, uv


def mesh_object(name: str, verts: np.ndarray, faces: list[tuple], face_mat: list[int],
                materials: list, weights: list[dict], armature: bpy.types.Object,
                flat_faces: set[int] | None = None, uv_density: float = uv.DENSITY_NEAR) -> bpy.types.Object:
    """Create a mesh object skinned to ``armature``.

    ``face_mat`` holds material slot indices into ``materials``; ``weights`` one {bone: w} per
    vertex. UVs are box-projected (pure math, deterministic). Faces in ``flat_faces`` are flat
    shaded (hem steps), everything else smooth."""
    bm = bmesh.new()
    bverts = [bm.verts.new((float(p[0]), float(p[1]), float(p[2]))) for p in verts]
    bm.verts.index_update()
    for fi, f in enumerate(faces):
        face = bm.faces.new([bverts[i] for i in f])
        face.material_index = int(face_mat[fi])
        face.smooth = not (flat_faces and fi in flat_faces)
    bm.faces.index_update()
    bm.normal_update()
    uv.box_project(bm, density=uv_density)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for mat in materials:
        me.materials.append(mat)
    obj = bpy.data.objects.new(name, me)
    scene.link(obj)
    obj.parent = armature
    obj.matrix_parent_inverse.identity()
    groups: dict[str, bpy.types.VertexGroup] = {}
    bone_names = [b.name for b in armature.data.bones]
    for b in bone_names:
        groups[b] = obj.vertex_groups.new(name=b)
    # add weights grouped by (bone, weight) for speed, in a stable order
    per_bone: dict[str, list[tuple[int, float]]] = {b: [] for b in bone_names}
    for vi, w in enumerate(weights):
        for b, x in sorted(w.items()):
            per_bone[b].append((vi, float(x)))
    for b in bone_names:
        for vi, x in per_bone[b]:
            groups[b].add([vi], x, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    mod.use_vertex_groups = True
    return obj
