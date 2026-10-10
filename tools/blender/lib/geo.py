"""Geometry helpers (Blender only).

Coordinates here are **Blender** coordinates: +Z up, and the glTF exporter maps Blender +Y to
Godot -Z. So "forward" (Godot -Z: the side facing the room / the user, a weapon's muzzle direction)
is **Blender +Y**. ``godot_to_blender()`` converts if you think in Godot axes.

Typical use::

    mb = geo.MeshBuilder()
    wall = mb.material(materials.material("grey_wall", "#B8B2A6"))
    mb.box((0, -0.1, 0), (2, 0.1, 3), mat=wall)
    col = mb.copy()                       # unbevelled copy for collision
    mb.bevel(0.005)
    uv.box_project(mb.bm, density=512)
    obj = mb.to_object("Wall")
    geo.finish_hard_surface(obj)
    geo.collision_from_builder(col, kind="trimesh")
"""

from __future__ import annotations

import math
from collections.abc import Iterable, Sequence

import bmesh
import bpy
from mathutils import Matrix, Vector, geometry

from . import naming, scene

Vec3 = Sequence[float]
Vec2 = Sequence[float]

DEFAULT_BEVEL = 0.005  # 5 mm: style guide 2-8 mm chamfers
SHARP_ANGLE_DEG = 30.0


def godot_to_blender(v: Vec3) -> Vector:
    """Godot (x, y up, z back) -> Blender (x, y forward, z up)."""
    return Vector((v[0], -v[2], v[1]))


def blender_to_godot(v: Vec3) -> Vector:
    return Vector((v[0], v[2], -v[1]))


class MeshBuilder:
    """Accumulates bmesh geometry with per-face material slots, then becomes one mesh object."""

    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.materials: list[bpy.types.Material | None] = []

    # -- materials -------------------------------------------------------------------------
    def material(self, mat: bpy.types.Material | None) -> int:
        """Slot index for ``mat`` (added on first use)."""
        if mat in self.materials:
            return self.materials.index(mat)
        self.materials.append(mat)
        return len(self.materials) - 1

    def _set_mat(self, faces: Iterable[bmesh.types.BMFace], mat: int | None) -> None:
        if mat is None:
            return
        for f in faces:
            f.material_index = mat

    # -- primitives ------------------------------------------------------------------------
    def box(self, lo: Vec3, hi: Vec3, mat: int | None = None) -> list[bmesh.types.BMFace]:
        """Axis-aligned box from min corner ``lo`` to max corner ``hi``."""
        size = Vector(hi) - Vector(lo)
        if min(size) <= 0:
            raise ValueError(f"box with non-positive size {tuple(size)}")
        centre = (Vector(lo) + Vector(hi)) * 0.5
        mtx = Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1.0))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx)
        faces = list({f for v in res["verts"] for f in v.link_faces})
        faces.sort(key=lambda f: f.index)
        self._set_mat(faces, mat)
        return faces

    def prism(self, outer: Sequence[Vec2], holes: Sequence[Sequence[Vec2]] = (), axis: str = "Y",
              start: float = 0.0, end: float = 1.0, mat: int | None = None,
              cap_mat: int | None = None) -> list[bmesh.types.BMFace]:
        """Extrude a 2D profile (with optional holes) between ``start`` and ``end`` along ``axis``.

        2D (u, v) maps to 3D as: axis Y -> (x=u, z=v) [wall elevations]; axis X -> (y=u, z=v)
        [stair side profiles]; axis Z -> (x=u, y=v) [floor plans]. Loops may be either winding.
        ``cap_mat`` (defaults to ``mat``) is used for the two end caps."""
        def to3(p: Vec2, d: float) -> Vector:
            if axis == "Y":
                return Vector((p[0], d, p[1]))
            if axis == "X":
                return Vector((d, p[0], p[1]))
            return Vector((p[0], p[1], d))

        loops = [list(outer)] + [list(h) for h in holes]
        bm = self.bm
        verts_a = [[bm.verts.new(to3(p, start)) for p in loop] for loop in loops]
        verts_b = [[bm.verts.new(to3(p, end)) for p in loop] for loop in loops]
        faces: list[bmesh.types.BMFace] = []
        side: list[bmesh.types.BMFace] = []
        for la, lb in zip(verts_a, verts_b):
            n = len(la)
            for i in range(n):
                j = (i + 1) % n
                side.append(bm.faces.new((la[i], la[j], lb[j], lb[i])))
        caps: list[bmesh.types.BMFace] = []
        if not holes:
            caps.append(bm.faces.new(verts_a[0]))
            caps.append(bm.faces.new(list(reversed(verts_b[0]))))
        else:
            flat_a = [v for loop in verts_a for v in loop]
            flat_b = [v for loop in verts_b for v in loop]
            tris = geometry.tessellate_polygon([[v.co.copy() for v in loop] for loop in verts_a])
            for t in tris:
                caps.append(bm.faces.new((flat_a[t[0]], flat_a[t[1]], flat_a[t[2]])))
                caps.append(bm.faces.new((flat_b[t[2]], flat_b[t[1]], flat_b[t[0]])))
        faces = side + caps
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._set_mat(side, mat)
        self._set_mat(caps, cap_mat if cap_mat is not None else mat)
        return faces

    def cylinder(self, radius: float, depth: float, segments: int = 16, centre: Vec3 = (0, 0, 0),
                 axis: str = "Z", mat: int | None = None) -> list[bmesh.types.BMFace]:
        """Closed cylinder centred on ``centre`` along ``axis``."""
        rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"),
               "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        mtx = Matrix.Translation(Vector(centre)) @ rot
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=radius, radius2=radius, depth=depth, matrix=mtx)
        faces = sorted({f for v in res["verts"] for f in v.link_faces}, key=lambda f: f.index)
        self._set_mat(faces, mat)
        return faces

    # -- operations ------------------------------------------------------------------------
    def bevel(self, width: float = DEFAULT_BEVEL, segments: int = 1, angle_deg: float = SHARP_ANGLE_DEG) -> None:
        """Chamfer every edge sharper than ``angle_deg`` (geometry is baked into the bmesh).

        Call before ``uv.box_project``: bevel's UV interpolation is not byte-deterministic."""
        limit = math.radians(angle_deg)
        self.bm.normal_update()
        edges = [e for e in self.bm.edges if e.is_manifold and e.calc_face_angle(0.0) > limit]
        if edges:
            bmesh.ops.bevel(self.bm, geom=edges, offset=width, offset_type="OFFSET", segments=segments,
                            profile=0.5, affect="EDGES", clamp_overlap=True, material=-1)

    def merge(self, dist: float = 1e-5) -> None:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=dist)

    def transform(self, mtx: Matrix) -> None:
        bmesh.ops.transform(self.bm, matrix=mtx, verts=self.bm.verts)

    def translate(self, offset: Vec3) -> None:
        self.transform(Matrix.Translation(Vector(offset)))

    def copy(self) -> MeshBuilder:
        other = MeshBuilder()
        other.bm.free()
        other.bm = self.bm.copy()
        other.materials = list(self.materials)
        return other

    def tri_count(self) -> int:
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def to_object(self, name: str, parent: bpy.types.Object | None = None,
                  location: Vec3 = (0, 0, 0)) -> bpy.types.Object:
        """Create a mesh object (consumes the builder)."""
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.materials:
            me.materials.append(m)
        obj = bpy.data.objects.new(name, me)
        obj.location = Vector(location)
        scene.link(obj, parent)
        return obj


# -- object-level helpers -------------------------------------------------------------------

def box_object(name: str, lo: Vec3, hi: Vec3, mat: bpy.types.Material | None = None,
               bevel: float = 0.0, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    mb = MeshBuilder()
    mb.box(lo, hi, mat=mb.material(mat) if mat is not None else None)
    if bevel > 0:
        mb.bevel(bevel)
    return mb.to_object(name, parent)


def empty(name: str, location: Vec3 = (0, 0, 0), rotation_euler: Vec3 = (0, 0, 0),
          parent: bpy.types.Object | None = None, size: float = 0.05) -> bpy.types.Object:
    """Named empty: exported as a plain glTF node, imported by Godot as a Node3D with this exact name.

    Use for markers (``Muzzle``, ``Handle``...) and pivots (``Leaf``). ``location`` is local to
    ``parent``. Markers point along Blender +Y (= Godot -Z) unless rotated."""
    naming.check_node_name(name)
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = size
    obj.location = Vector(location)
    obj.rotation_euler = Vector(rotation_euler)
    return scene.link(obj, parent)


def mark_sharp(obj: bpy.types.Object, angle_deg: float = SHARP_ANGLE_DEG) -> None:
    """Smooth-shade ``obj`` and mark edges sharper than ``angle_deg`` as sharp."""
    me = obj.data
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(angle_deg))


def add_bevel(obj: bpy.types.Object, width: float = DEFAULT_BEVEL, segments: int = 1,
              angle_deg: float = SHARP_ANGLE_DEG) -> bpy.types.Modifier:
    """Non-destructive bevel modifier (applied at export).

    WARNING: not byte-deterministic in Blender 4.5 when the mesh already has UVs (see
    ``bevel_object``). Fine for look-dev; use ``bevel_object`` / ``MeshBuilder.bevel`` for outputs."""
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle_deg)
    mod.use_clamp_overlap = True
    mod.harden_normals = False
    return mod


def add_weighted_normals(obj: bpy.types.Object, weight: int = 50) -> bpy.types.Modifier:
    mod = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    mod.mode = "FACE_AREA"
    mod.weight = weight
    mod.keep_sharp = True
    return mod


def bevel_object(obj: bpy.types.Object, width: float = DEFAULT_BEVEL, segments: int = 1,
                 angle_deg: float = SHARP_ANGLE_DEG) -> None:
    """Bake a chamfer into ``obj``'s mesh (bmesh bevel on edges sharper than ``angle_deg``).

    Prefer this over ``add_bevel()``: the Bevel *modifier* in Blender 4.5 interpolates UVs
    non-deterministically (last-bit float noise from run to run), which breaks byte-identical
    output. The bmesh operator is deterministic."""
    if obj.data.uv_layers:
        print(f"[lib.geo] WARN {obj.name}: bevelling a mesh that already has UVs; UV interpolation is "
              "address-dependent in Blender 4.5 (non-deterministic bytes). Bevel first, UV after.")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    limit = math.radians(angle_deg)
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > limit]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segments,
                        profile=0.5, affect="EDGES", clamp_overlap=True, material=-1)
    bm.to_mesh(obj.data)
    bm.free()


def finish_hard_surface(obj: bpy.types.Object, bevel: float = 0.0, segments: int = 1,
                        angle_deg: float = SHARP_ANGLE_DEG) -> bpy.types.Object:
    """Style-guide shading: optional baked bevel, sharp edges by angle, weighted normals modifier."""
    if bevel > 0:
        bevel_object(obj, bevel, segments, angle_deg)
    mark_sharp(obj, angle_deg)
    add_weighted_normals(obj)
    return obj


def boolean(obj: bpy.types.Object, cutter: bpy.types.Object, operation: str = "DIFFERENCE",
            apply: bool = True, delete_cutter: bool = True) -> None:
    """Exact-solver boolean (``DIFFERENCE``/``UNION``/``INTERSECT``) of ``cutter`` on ``obj``."""
    mod = obj.modifiers.new("Boolean", "BOOLEAN")
    mod.operation = operation
    mod.solver = "EXACT"
    mod.object = cutter
    if apply:
        apply_modifiers(obj)
    if delete_cutter:
        me = cutter.data
        bpy.data.objects.remove(cutter)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


def apply_modifiers(obj: bpy.types.Object) -> None:
    """Bake all modifiers of ``obj`` into its mesh."""
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=deps)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    me.name = obj.name


def tri_count(obj: bpy.types.Object) -> int:
    """Triangles of the evaluated (modifiers applied) mesh."""
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = ev.to_mesh()
    try:
        return sum(len(p.vertices) - 2 for p in me.polygons)
    finally:
        ev.to_mesh_clear()


def bounds(objs: Iterable[bpy.types.Object]) -> tuple[Vector, Vector]:
    """World-space AABB (min, max) of the evaluated meshes in ``objs``."""
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in objs:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        for v in me.vertices:
            w = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


PIVOTS = ("floor", "wall", "ceiling", "none")


def align_pivot(objs: Sequence[bpy.types.Object], mode: str) -> Vector:
    """Move root objects so the asset origin sits at the contract pivot (contracts/visual_slots.md).

    * ``floor``: bottom-centre contact point (x/y centred, min z = 0)
    * ``wall``: back-centre (x/z centred, back = min Blender y = 0; front faces Blender +Y = Godot -Z)
    * ``ceiling``: top-centre (x/y centred, max z = 0)
    Returns the applied offset. Children move with their roots."""
    if mode not in PIVOTS:
        raise ValueError(f"pivot mode {mode!r} not in {PIVOTS}")
    if mode == "none":
        return Vector()
    bpy.context.view_layer.update()
    meshes = [o for o in objs if not naming.is_collision_name(o.name)]
    lo, hi = bounds(meshes)
    c = (lo + hi) * 0.5
    if mode == "floor":
        ref = Vector((c.x, c.y, lo.z))
    elif mode == "wall":
        ref = Vector((c.x, lo.y, c.z))
    else:
        ref = Vector((c.x, c.y, hi.z))
    for o in objs:
        if o.parent is None:
            o.location -= ref
    bpy.context.view_layer.update()
    return -ref


def collision_from_builder(mb: MeshBuilder, kind: str = "trimesh", name: str = "Collision",
                           parent: bpy.types.Object | None = None) -> bpy.types.Object:
    """Collision-only mesh, converted by Godot's importer into a ``StaticBody3D`` named ``name``.

    ``kind="trimesh"`` -> ``<name>-colonly`` (concave; architecture only, style guide §5);
    ``kind="convex"`` -> ``<name>-convcolonly`` (props). The mesh is removed on import; only the
    body + CollisionShape3D remain. One collision object per asset (names must be unique)."""
    suffix = {"trimesh": "-colonly", "convex": "-convcolonly"}[kind]
    for f in mb.bm.faces:
        f.material_index = 0
    mb.materials = []
    return mb.to_object(name + suffix, parent)
