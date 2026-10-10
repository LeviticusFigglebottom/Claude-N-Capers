"""World-scaled box-projection UVs (Blender only).

Texel density rule (style guide §4): 512 px/m within reach, 256 px/m ceilings/distant geometry,
1024 px/m first-person weapons. With ``texture_px`` = the size of the tileable texture, one UV unit
equals one texture repeat, so ``uv = metres * density / texture_px``. Library tileables are
authored at 1024 px, i.e. one repeat covers 2 m at 512 px/m.

Projection is per face along its dominant normal axis, oriented so textures are never mirrored and
"up" on vertical faces is +Z. Coordinates are in asset space (relative to the asset origin), plus an
optional ``offset``; pieces placed on the 0.5 m grid therefore line up wherever the placement offset
is a multiple of the texture period (2 m at the defaults). For perfectly continuous tiling across
arbitrary placements use a world-triplanar library material on the Godot side.
"""

from __future__ import annotations

from collections.abc import Sequence

import bmesh
import bpy
from mathutils import Vector

DENSITY_NEAR = 512.0
DENSITY_FAR = 256.0
DENSITY_FIRST_PERSON = 1024.0
TEXTURE_PX = 1024.0


def box_project(bm: bmesh.types.BMesh, density: float = DENSITY_NEAR, texture_px: float = TEXTURE_PX,
                offset: Sequence[float] = (0.0, 0.0, 0.0), layer_name: str = "UVMap",
                faces: Sequence[bmesh.types.BMFace] | None = None) -> None:
    """Box-project UVs on ``bm`` (all faces, or ``faces``) at ``density`` px/m."""
    s = density / texture_px
    uv = bm.loops.layers.uv.get(layer_name) or bm.loops.layers.uv.new(layer_name)
    off = Vector(offset)
    bm.normal_update()
    for f in faces if faces is not None else bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            p = loop.vert.co + off
            if ax == 0:
                u, v = (p.y if n.x > 0 else -p.y), p.z
            elif ax == 1:
                u, v = (-p.x if n.y > 0 else p.x), p.z
            else:
                u, v = p.x, (p.y if n.z > 0 else -p.y)
            loop[uv].uv = (u * s, v * s)


def box_project_object(obj: bpy.types.Object, density: float = DENSITY_NEAR,
                       texture_px: float = TEXTURE_PX, world: bool = False) -> None:
    """Box-project an existing mesh object. ``world=True`` uses its world location as offset."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    box_project(bm, density, texture_px, obj.matrix_world.translation if world else (0, 0, 0))
    bm.to_mesh(obj.data)
    bm.free()
