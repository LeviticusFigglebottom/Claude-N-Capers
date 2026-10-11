"""Prop builder helpers (C1-07): parts with their own chamfer, merged into one mesh object, then
world-scaled box UVs (bevel first, UV after: docs/art/pipeline.md §4). Blender only.

Coordinates are Blender (Z up, +Y = Godot -Z = the front / the side facing the room). Floor props
are modelled around their pivot (x/y centred, bottom at z = 0), wall props with the back at y = 0
and ceiling props with the top at z = 0, so no pivot pass is needed.

    k = Kit(ctx)
    body = k.obj("Body")
    p = body.part(bevel=0.004)
    p.box((-0.5, -0.3, 0), (0.5, 0.3, 0.9), "walnut")
    body.build()
    k.collision([((-0.5, -0.3, 0), (0.5, 0.3, 0.9))])
"""

from __future__ import annotations

import math
from collections.abc import Sequence

import bmesh
import bpy
from mathutils import Matrix, Vector

from lib import geo, materials, uv

import _matlib

Vec3 = Sequence[float]


class Kit:
    """Per-asset helper: material slots by key, objects, collision, markers."""

    def __init__(self, ctx) -> None:
        self.ctx = ctx

    def mat(self, key: str) -> bpy.types.Material:
        lib_id, hex_color, rough, metal, alpha = _matlib.slot(key)
        m = self.ctx.material(lib_id, hex_color, roughness=rough, metallic=metal, alpha=alpha)
        if key in _matlib.EMISSIVE:
            e = _matlib.EMISSIVE[key]
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            lin = tuple(materials.srgb_to_linear(c) for c in materials.hex_to_srgb(e["emission"]))
            bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.0
        return m

    def obj(self, name: str, parent: bpy.types.Object | None = None, location: Vec3 = (0, 0, 0)) -> Obj:
        return Obj(self, name, parent, location)

    def empty(self, name: str, location: Vec3 = (0, 0, 0), rotation: Vec3 = (0, 0, 0),
              parent: bpy.types.Object | None = None) -> bpy.types.Object:
        return geo.empty(name, location, rotation, parent)

    def collision(self, boxes: Sequence[tuple[Vec3, Vec3]], kind: str = "convex",
                  parent: bpy.types.Object | None = None, cylinders: Sequence[tuple] = ()) -> bpy.types.Object:
        """Collision from unbevelled boxes ``(lo, hi)`` (and ``(r, depth, centre)`` Z cylinders)."""
        mb = geo.MeshBuilder()
        for lo, hi in boxes:
            mb.box(lo, hi)
        for r, depth, centre in cylinders:
            mb.cylinder(r, depth, segments=12, centre=centre)
        return geo.collision_from_builder(mb, kind, parent=parent)


class Part(geo.MeshBuilder):
    """A MeshBuilder with material keys and one chamfer setting."""

    def __init__(self, kit: Kit, bevel: float, segments: int, angle: float) -> None:
        super().__init__()
        self.kit = kit
        self.bevel_w = bevel
        self.bevel_segments = segments
        self.bevel_angle = angle

    def m(self, key: str) -> int:
        return self.material(self.kit.mat(key))

    # -- primitives (material by key) ------------------------------------------------------
    def bx(self, lo: Vec3, hi: Vec3, key: str):
        return self.box(lo, hi, mat=self.m(key))

    def cbox(self, centre: Vec3, size: Vec3, key: str):
        c, s = Vector(centre), Vector(size) * 0.5
        return self.box(c - s, c + s, mat=self.m(key))

    def cyl(self, r: float, depth: float, centre: Vec3, key: str, axis: str = "Z", segs: int = 16):
        return self.cylinder(r, depth, segments=segs, centre=centre, axis=axis, mat=self.m(key))

    def rod(self, p0: Vec3, p1: Vec3, r: float, key: str, segs: int = 8, square: bool = False):
        """Cylinder (or square bar) from p0 to p1."""
        a, b = Vector(p0), Vector(p1)
        d = b - a
        length = d.length
        if length < 1e-6:
            return []
        rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        mtx = Matrix.Translation((a + b) * 0.5) @ rot
        if square:
            mtx = mtx @ Matrix.Diagonal((2 * r, 2 * r, length, 1.0))
            res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx)
        else:
            res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                                        radius1=r, radius2=r, depth=length, matrix=mtx)
        faces = sorted({f for v in res["verts"] for f in v.link_faces}, key=lambda f: f.index)
        self._set_mat(faces, self.m(key))
        return faces

    def tube(self, pts: Sequence[Vec3], r: float, key: str, segs: int = 8, closed: bool = False,
             joints: bool = True):
        """Polyline of rods; spheres at the joints hide the seams."""
        n = len(pts)
        last = n if closed else n - 1
        for i in range(last):
            self.rod(pts[i], pts[(i + 1) % n], r, key, segs)
        if joints:
            inner = range(n) if closed else range(1, n - 1)
            for i in inner:
                self.sphere(r, pts[i], key, segs=segs, rings=max(3, segs // 2))

    def sphere(self, r: float, centre: Vec3, key: str, segs: int = 16, rings: int = 8, scale: Vec3 = (1, 1, 1)):
        """UV sphere built with pure math (bmesh create_uvsphere output is not byte-stable)."""
        prof = [(0.0, -r * scale[2])]
        for i in range(1, rings):
            phi = math.pi * i / rings
            prof.append((r * math.sin(phi), -r * math.cos(phi) * scale[2]))
        prof.append((0.0, r * scale[2]))
        return self.lathe(prof, key, centre=centre, segs=segs, scale_xy=(scale[0], scale[1]))

    def lathe(self, profile: Sequence[tuple[float, float]], key: str, centre: Vec3 = (0, 0, 0),
              segs: int = 24, scale_xy: tuple[float, float] = (1.0, 1.0)):
        """Surface of revolution around Z through ``centre``. ``profile`` = [(radius, z), ...]
        bottom to top; a radius of 0 closes the end (pole), otherwise ends are capped flat."""
        bm = self.bm
        cx, cy, cz = centre
        rings: list[list | bmesh.types.BMVert] = []
        for r, z in profile:
            if r <= 1e-6:
                rings.append(bm.verts.new((cx, cy, cz + z)))
            else:
                ring = []
                for i in range(segs):
                    a = 2 * math.pi * i / segs
                    ring.append(bm.verts.new((cx + r * math.cos(a) * scale_xy[0], cy + r * math.sin(a) * scale_xy[1], cz + z)))
                rings.append(ring)
        faces = []
        for i in range(len(rings) - 1):
            a, b = rings[i], rings[i + 1]
            if isinstance(a, list) and isinstance(b, list):
                for j in range(segs):
                    k = (j + 1) % segs
                    faces.append(bm.faces.new((a[j], a[k], b[k], b[j])))
            elif isinstance(a, list):
                for j in range(segs):
                    faces.append(bm.faces.new((a[j], a[(j + 1) % segs], b)))
            elif isinstance(b, list):
                for j in range(segs):
                    faces.append(bm.faces.new((a, b[(j + 1) % segs], b[j])))
        if isinstance(rings[0], list):
            faces.append(bm.faces.new(list(reversed(rings[0]))))
        if isinstance(rings[-1], list):
            faces.append(bm.faces.new(rings[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._set_mat(faces, self.m(key))
        return faces

    def leaf(self, base: Vec3, tip: Vec3, width: float, key: str, up: Vec3 = (0, 0, 1), fold: float = 0.25):
        """Thin two-sided leaf blade from ``base`` to ``tip`` (diamond outline, folded along the
        midrib by ``fold`` x width so it catches light from both sides)."""
        b, t = Vector(base), Vector(tip)
        d = t - b
        if d.length < 1e-6:
            return []
        side = d.cross(Vector(up))
        if side.length < 1e-6:
            side = d.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(d).normalized()
        mid = b + d * 0.42
        hw = width * 0.5
        lift = nrm * (width * fold)
        th = nrm * 0.0015
        bm = self.bm
        faces = []
        for sgn in (1.0, -1.0):
            o = th * sgn
            vb = bm.verts.new(b + o)
            vt = bm.verts.new(t + o)
            vm = bm.verts.new(mid + o + lift * 0.3)
            vl = bm.verts.new(mid - side * hw + o + lift)
            vr = bm.verts.new(mid + side * hw + o + lift)
            quads = ((vb, vl, vm), (vl, vt, vm), (vb, vm, vr), (vm, vt, vr))
            for q in quads:
                faces.append(bm.faces.new(q if sgn > 0 else tuple(reversed(q))))
        self._set_mat(faces, self.m(key))
        return faces

    def torus(self, big_r: float, small_r: float, centre: Vec3, key: str, segs: int = 32, rsegs: int = 8,
              axis: str = "Z", arc: float = 2 * math.pi):
        """Torus (or a torus arc) around ``axis`` through ``centre``."""
        bm = self.bm
        rot = {"Z": Matrix.Identity(3), "X": Matrix.Rotation(math.pi / 2, 3, "Y"),
               "Y": Matrix.Rotation(math.pi / 2, 3, "X")}[axis]
        full = arc >= 2 * math.pi - 1e-6
        n = segs if full else segs + 1
        loops = []
        for i in range(n):
            a = arc * i / segs
            ring = []
            for j in range(rsegs):
                b = 2 * math.pi * j / rsegs
                rr = big_r + small_r * math.cos(b)
                p = Vector((rr * math.cos(a), rr * math.sin(a), small_r * math.sin(b)))
                ring.append(bm.verts.new(rot @ p + Vector(centre)))
            loops.append(ring)
        faces = []
        for i in range(segs if full else n - 1):
            a, b = loops[i], loops[(i + 1) % n]
            for j in range(rsegs):
                k = (j + 1) % rsegs
                faces.append(bm.faces.new((a[j], b[j], b[k], a[k])))
        if not full:
            faces.append(bm.faces.new(loops[0]))
            faces.append(bm.faces.new(list(reversed(loops[-1]))))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        self._set_mat(faces, self.m(key))
        return faces

    def slab(self, outline: Sequence[tuple[float, float]], z0: float, z1: float, key: str):
        """Extruded floor-plan outline (x, y) from z0 to z1."""
        return self.prism(outline, axis="Z", start=z0, end=z1, mat=self.m(key))

    def profile_x(self, outline: Sequence[tuple[float, float]], x0: float, x1: float, key: str):
        """Side profile (y, z) extruded along X from x0 to x1."""
        return self.prism(outline, axis="X", start=x0, end=x1, mat=self.m(key))

    def profile_y(self, outline: Sequence[tuple[float, float]], y0: float, y1: float, key: str):
        """Front elevation (x, z) extruded along Y from y0 to y1."""
        return self.prism(outline, axis="Y", start=y0, end=y1, mat=self.m(key))


class Obj:
    """One exported mesh object assembled from Parts with different chamfers."""

    def __init__(self, kit: Kit, name: str, parent: bpy.types.Object | None, location: Vec3) -> None:
        self.kit = kit
        self.name = name
        self.parent = parent
        self.location = location
        self.parts: list[Part] = []

    def part(self, bevel: float = 0.004, segments: int = 1, angle: float = 30.0) -> Part:
        p = Part(self.kit, bevel, segments, angle)
        self.parts.append(p)
        return p

    def build(self, density: float = uv.DENSITY_NEAR, smooth_angle: float = 30.0) -> bpy.types.Object | None:
        mats: list[bpy.types.Material] = []
        out = bmesh.new()
        part_layer = out.faces.layers.int.new("part")
        for pi, p in enumerate(self.parts):
            if not p.bm.faces:
                p.bm.free()
                continue
            if p.bevel_w > 0:
                p.bevel(p.bevel_w, p.bevel_segments, p.bevel_angle)
            remap = []
            for m in p.materials:
                if m not in mats:
                    mats.append(m)
                remap.append(mats.index(m))
            for f in p.bm.faces:
                f.material_index = remap[f.material_index] if remap else 0
            me = bpy.data.meshes.new("_tmp")
            p.bm.to_mesh(me)
            p.bm.free()
            n_before = len(out.faces)
            out.from_mesh(me)
            bpy.data.meshes.remove(me)
            out.faces.ensure_lookup_table()
            for fi in range(n_before, len(out.faces)):
                out.faces[fi][part_layer] = pi
        if not out.faces:
            out.free()
            return None
        dezfight(out, part_layer)
        out.faces.layers.int.remove(part_layer)
        project_uvs(out, mats, density)
        mb = geo.MeshBuilder()
        mb.bm.free()
        mb.bm = out
        mb.materials = mats
        obj = mb.to_object(self.name, parent=self.parent, location=self.location)
        geo.mark_sharp(obj, smooth_angle)
        geo.add_weighted_normals(obj)
        return obj


# ------------------------------------------------------------------------------- validator rules

ZF_EPS = 0.0035     # levelcheck zfight flags planes < 2 mm apart (margin for float32 + bevels)
ZF_PUSH = 0.004     # moved faces end up this far in front of the face they covered
ZF_AREA = 0.0003    # overlap (m², bounding boxes in the plane) worth fixing (check: 4 cm²)


def _plane_box(f, u: Vector, w: Vector) -> tuple[float, float, float, float]:
    xs = [v.co.dot(u) for v in f.verts]
    ys = [v.co.dot(w) for v in f.verts]
    return min(xs), min(ys), max(xs), max(ys)


def dezfight(bm: bmesh.types.BMesh, part_layer, passes: int = 40) -> None:
    """Remove z-fighting inside one object (levelcheck `zfight`): wherever a face of a later part
    (trim, inlay, label, decal...) lies within 2 mm of a same-facing face of a different material
    and overlaps it, push it 2.5 mm out along its normal. Floor-contact bottom faces that are
    hidden anyway are deleted instead. Pure math in face order: deterministic."""
    for _ in range(passes):
        bm.normal_update()
        bm.verts.index_update()
        bm.faces.index_update()
        bm.faces.ensure_lookup_table()
        zmin = min(v.co.z for v in bm.verts)
        buckets: dict[tuple, list] = {}
        for f in bm.faces:
            n = f.normal
            if n.length < 0.5 or f.calc_area() < 1e-6:
                continue
            key = (round(n.x * 40), round(n.y * 40), round(n.z * 40))
            buckets.setdefault(key, []).append((n.dot(f.verts[0].co), f[part_layer], f.index, f))
        push: dict[int, float] = {}
        drop: list = []
        for key in sorted(buckets):
            items = sorted(buckets[key], key=lambda t: (t[0], t[1], t[2]))
            n0 = items[0][3].normal
            u = (Vector((0, 0, 1)) if abs(n0.z) < 0.9 else Vector((1, 0, 0))).cross(n0).normalized()
            w = n0.cross(u)
            boxes = {t[2]: _plane_box(t[3], u, w) for t in items}
            for a in range(len(items)):
                da, pa, ia, fa = items[a]
                for b in range(a + 1, len(items)):
                    db, pb, ib, fb = items[b]
                    if db - da >= ZF_EPS:
                        break
                    if fa.material_index == fb.material_index or fa.normal.dot(fb.normal) < 0.999:
                        continue
                    ba, bb = boxes[ia], boxes[ib]
                    ox = min(ba[2], bb[2]) - max(ba[0], bb[0])
                    oy = min(ba[3], bb[3]) - max(ba[1], bb[1])
                    if ox <= 0 or oy <= 0 or ox * oy < ZF_AREA:
                        continue
                    # move the later one (part order, then face order)
                    lo, hi = ((da, ia), (db, ib)) if (pa, ia) < (pb, ib) else ((db, ib), (da, ia))
                    f_hi = fb if hi[1] == ib else fa
                    if f_hi.normal.z < -0.99 and all(abs(v.co.z - zmin) < 0.001 for v in f_hi.verts):
                        drop.append(f_hi)
                    elif f_hi.normal.z < -0.99:
                        # never below the object's base (pivot contract): undersides move up instead
                        off = lo[0] - ZF_PUSH - hi[0]
                        push[hi[1]] = min(push.get(hi[1], 0.0), off)
                    else:
                        push[hi[1]] = max(push.get(hi[1], 0.0), lo[0] + ZF_PUSH - hi[0])
        if not push and not drop:
            return
        moved: set[int] = set()
        for fi in sorted(push):
            f = bm.faces[fi]
            off = f.normal * push[fi]
            for v in f.verts:
                if v.index not in moved:
                    v.co += off
                    moved.add(v.index)
        if drop:
            uniq = sorted({f.index: f for f in drop}.items())
            bmesh.ops.delete(bm, geom=[f for _, f in uniq], context="FACES_ONLY")
        bm.verts.index_update()


def _texture_px(mat: bpy.types.Material) -> float:
    lib = mat.name[2:] if mat.name.startswith("M_") else mat.name
    return _matlib.texture_px(lib)


def project_uvs(bm: bmesh.types.BMesh, mats: list, density: float) -> None:
    """World-scaled box UVs at the texel density the validator expects (512 px/m within reach):
    1024 px library tiles repeat every 2 m, the 512 px low-detail tiles (chrome, rubber, plastic,
    glass and their tints) every 1 m."""
    uv.box_project(bm, density=density)
    small = [i for i, m in enumerate(mats) if m is not None and _texture_px(m) < 1024]
    if small:
        faces = [f for f in bm.faces if f.material_index in small]
        uv.box_project(bm, density=density, texture_px=512.0, faces=faces)


# ----------------------------------------------------------------------------- furniture bits

def panel_door(p: Part, x0: float, x1: float, z0: float, z1: float, y: float, face_key: str,
               inlay_key: str | None = "brass", frame_w: float = 0.055, depth: float = 0.018,
               inlay: float = 0.006) -> None:
    """Raised-panel cabinet door on the front plane ``y`` (front = +Y): stile/rail frame, a raised
    field and an optional thin metal inlay line around the field (the counter-sample look)."""
    p.bx((x0, y, z0), (x1, y + depth, z1), face_key)
    f = frame_w
    p.bx((x0 + f, y + depth, z0 + f), (x1 - f, y + depth + 0.012, z1 - f), face_key)
    if inlay_key:
        g = f * 0.55
        t = inlay
        for (a0, a1, b0, b1) in ((x0 + g, x1 - g, z0 + g, z0 + g + t), (x0 + g, x1 - g, z1 - g - t, z1 - g),
                                 (x0 + g, x0 + g + t, z0 + g, z1 - g), (x1 - g - t, x1 - g, z0 + g, z1 - g)):
            p.bx((a0, y + depth, b0), (a1, y + depth + 0.002, b1), inlay_key)


def knob(p: Part, x: float, y: float, z: float, key: str = "brass", r: float = 0.012) -> None:
    p.cyl(r * 0.5, 0.02, (x, y + 0.01, z), key, axis="Y", segs=10)
    p.cyl(r, 0.01, (x, y + 0.022, z), key, axis="Y", segs=14)


def bar_handle(p: Part, x0: float, x1: float, y: float, z: float, key: str = "steel", r: float = 0.006,
               standoff: float = 0.03, vertical: bool = False) -> None:
    if vertical:
        p.rod((x0, y + standoff, z), (x0, y + standoff, x1), r, key)
        p.rod((x0, y, z + 0.01), (x0, y + standoff, z + 0.01), r * 0.8, key)
        p.rod((x0, y, x1 - 0.01), (x0, y + standoff, x1 - 0.01), r * 0.8, key)
    else:
        p.rod((x0, y + standoff, z), (x1, y + standoff, z), r, key)
        p.rod((x0 + 0.01, y, z), (x0 + 0.01, y + standoff, z), r * 0.8, key)
        p.rod((x1 - 0.01, y, z), (x1 - 0.01, y + standoff, z), r * 0.8, key)


def legs4(p: Part, w: float, d: float, h: float, inset: float, size: float, key: str,
          taper: float = 1.0, round_: bool = False) -> None:
    """Four legs under a top of w x d at height h (top underside)."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = sx * (w / 2 - inset - size / 2)
            y = sy * (d / 2 - inset - size / 2)
            if round_:
                p.lathe([(size / 2 * taper, 0.0), (size / 2, h)], key, centre=(x, y, 0), segs=10)
            else:
                p.bx((x - size / 2, y - size / 2, 0), (x + size / 2, y + size / 2, h), key)


def chair_seat_marker(kit: Kit, seat_z: float = 0.45, y: float = 0.0) -> None:
    """`Seat` marker (levelcheck scale check: chair seat at 0.45 m)."""
    kit.empty("Seat", (0.0, y, seat_z))


# ---------------------------------------------------------------------------------- lettering
# Stroke glyphs on a unit cell (x 0..w, y 0..1), used for brass letters, exit signs and neon.

def _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int = 8) -> list[tuple[float, float]]:
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def _glyph_table(k: int = 1) -> dict[str, tuple[float, list[list[tuple[float, float]]]]]:
    """Glyph table; ``k`` multiplies every arc's segment count (1 = the original polylines)."""
    return {
        "V": (0.7, [[(0.0, 1.0), (0.35, 0.0), (0.7, 1.0)]]),
        "O": (0.75, [_arc(0.375, 0.5, 0.375, 0.5, 0, 360, 16 * k)]),
        "S": (0.6, [_arc(0.3, 0.75, 0.28, 0.25, 15, 270, 8 * k) + _arc(0.3, 0.25, 0.28, 0.25, 90, -165, 8 * k)]),
        "B": (0.6, [[(0.0, 0.0), (0.0, 1.0), (0.3, 1.0)] + _arc(0.3, 0.76, 0.24, 0.24, 90, -90, 6 * k)
                    + [(0.0, 0.52), (0.33, 0.52)] + _arc(0.33, 0.26, 0.26, 0.26, 90, -90, 6 * k) + [(0.0, 0.0)]]),
        "E": (0.55, [[(0.55, 1.0), (0.0, 1.0), (0.0, 0.0), (0.55, 0.0)], [(0.0, 0.52), (0.45, 0.52)]]),
        "R": (0.62, [[(0.0, 0.0), (0.0, 1.0), (0.32, 1.0)] + _arc(0.32, 0.75, 0.25, 0.25, 90, -90, 6 * k)
                     + [(0.0, 0.5)], [(0.25, 0.5), (0.62, 0.0)]]),
        "G": (0.72, [_arc(0.38, 0.5, 0.36, 0.5, 40, 340, 12 * k) + [(0.72, 0.4), (0.72, 0.45), (0.42, 0.45)]]),
        "X": (0.62, [[(0.0, 0.0), (0.62, 1.0)], [(0.0, 1.0), (0.62, 0.0)]]),
        "I": (0.1, [[(0.05, 0.0), (0.05, 1.0)]]),
        "T": (0.6, [[(0.0, 1.0), (0.6, 1.0)], [(0.3, 1.0), (0.3, 0.0)]]),
        "J": (0.5, [[(0.5, 1.0), (0.5, 0.3)] + _arc(0.25, 0.3, 0.25, 0.3, 0, -180, 6 * k)]),
        "W": (0.95, [[(0.0, 1.0), (0.22, 0.0), (0.475, 0.7), (0.73, 0.0), (0.95, 1.0)]]),
        "L": (0.5, [[(0.0, 1.0), (0.0, 0.0), (0.5, 0.0)]]),
        "Y": (0.62, [[(0.0, 1.0), (0.31, 0.5), (0.62, 1.0)], [(0.31, 0.5), (0.31, 0.0)]]),
        "N": (0.65, [[(0.0, 0.0), (0.0, 1.0), (0.65, 0.0), (0.65, 1.0)]]),
        "A": (0.68, [[(0.0, 0.0), (0.34, 1.0), (0.68, 0.0)], [(0.13, 0.38), (0.55, 0.38)]]),
        "C": (0.65, [_arc(0.38, 0.5, 0.36, 0.5, 45, 315, 12 * k)]),
        "P": (0.58, [[(0.0, 0.0), (0.0, 1.0), (0.3, 1.0)] + _arc(0.3, 0.74, 0.26, 0.26, 90, -90, 6 * k) + [(0.0, 0.48)]]),
        "H": (0.62, [[(0.0, 0.0), (0.0, 1.0)], [(0.62, 0.0), (0.62, 1.0)], [(0.0, 0.5), (0.62, 0.5)]]),
    }


GLYPHS: dict[str, tuple[float, list[list[tuple[float, float]]]]] = _glyph_table(1)


def text_strokes(text: str, height: float, spacing: float = 0.22, slant: float = 0.0, res: int = 1
                 ) -> tuple[float, list[list[tuple[float, float]]]]:
    """Strokes (x, z) for ``text`` with letters ``height`` tall, starting at x = 0. Returns
    (total width, strokes). ``slant`` shears x by z (script look). ``res`` multiplies the arc
    segment counts (smoother curves for large or close-up lettering)."""
    glyphs = GLYPHS if res == 1 else _glyph_table(res)
    x = 0.0
    strokes: list[list[tuple[float, float]]] = []
    for ch in text:
        if ch == " ":
            x += 0.45 * height
            continue
        w, gl = glyphs[ch]
        for s in gl:
            strokes.append([(x + (gx + slant * gy) * height, gy * height) for gx, gy in s])
        x += (w + spacing) * height
    return x - spacing * height, strokes


def _ribbon(p: Part, pts: list[tuple[float, float]], hw: float, y0: float, y1: float, key: str) -> None:
    """Flat stroke of half-width ``hw`` along the (x, z) polyline ``pts``, extruded from y0 to y1.
    One quad prism per segment; neighbours share mitred edges at gentle joints (seamless curves),
    sharp joints (> 60 degrees) get butt ends plus a round disc, so no box corners poke out."""
    q: list[tuple[float, float]] = []
    for pt in pts:
        if not q or math.dist(q[-1], pt) > 1e-6:
            q.append(pt)
    closed = len(q) > 2 and math.dist(q[0], q[-1]) < 1e-4
    if closed:
        q[-1] = q[0]
    n = len(q)
    if n < 2:
        return

    def unit(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
        d = math.dist(a, b)
        return ((b[0] - a[0]) / d, (b[1] - a[1]) / d)

    dirs = [unit(q[i], q[i + 1]) for i in range(n - 1)]
    # per-vertex offset: (dx, dz) to the left side, or None for a butt end
    offs: list[tuple[float, float] | None] = []
    for i in range(n):
        din = dirs[i - 1] if i > 0 else (dirs[-1] if closed else None)
        dout = dirs[i] if i < n - 1 else (dirs[0] if closed else None)
        if din is None or dout is None:
            offs.append(None)
            continue
        cos_t = din[0] * dout[0] + din[1] * dout[1]
        if cos_t < 0.5:
            offs.append(None)
            p.cyl(hw, y1 - y0, (q[i][0], (y0 + y1) / 2, q[i][1]), key, axis="Y", segs=16)
            continue
        n0, n1 = (-din[1], din[0]), (-dout[1], dout[0])
        mx, mz = n0[0] + n1[0], n0[1] + n1[1]
        ml = math.hypot(mx, mz)
        mx, mz = mx / ml, mz / ml
        scale = hw / (mx * n0[0] + mz * n0[1])
        offs.append((mx * scale, mz * scale))
    for i in range(n - 1):
        a, b = q[i], q[i + 1]
        nrm = (-dirs[i][1] * hw, dirs[i][0] * hw)
        oa = offs[i] or nrm
        ob = offs[i + 1] or nrm
        outline = [(a[0] + oa[0], a[1] + oa[1]), (b[0] + ob[0], b[1] + ob[1]),
                   (b[0] - ob[0], b[1] - ob[1]), (a[0] - oa[0], a[1] - oa[1])]
        p.profile_y(outline, y0, y1, key)


def _sweep(p: Part, pts: list[tuple[float, float, float]], r: float, key: str, segs: int) -> None:
    """Neon tube along a polyline in a plane y = const: one connected swept mesh per smooth run
    (mitred rings, capped ends), split at sharp joints (> 25 degrees) where a sphere closes the
    seam. Connected runs survive Godot's auto-LOD, unlike a chain of tiny separate rods."""
    q: list[Vector] = []
    for pt in pts:
        v = Vector(pt)
        if not q or (v - q[-1]).length > 1e-6:
            q.append(v)
    if len(q) < 2:
        return
    closed = len(q) > 2 and (q[0] - q[-1]).length < 1e-4
    if closed:
        q.pop()
    n = len(q)
    nseg = n if closed else n - 1
    dirs = [(q[(i + 1) % n] - q[i]).normalized() for i in range(nseg)]
    up = Vector((0.0, 1.0, 0.0))
    sharp = [False] * n
    for i in range(n):
        if not closed and (i == 0 or i == n - 1):
            continue
        sharp[i] = dirs[i - 1].dot(dirs[i % nseg]) < 0.906
    # runs of segment indices split at sharp vertices
    runs: list[list[int]] = []
    cur: list[int] = []
    start = 0
    if closed and any(sharp):
        start = sharp.index(True)
    for k in range(nseg):
        i = (start + k) % nseg
        if cur and sharp[i]:
            runs.append(cur)
            cur = []
        cur.append(i)
    runs.append(cur)
    if closed and not any(sharp):
        runs = [list(range(nseg))]
    mat = p.m(key)
    bm = p.bm
    for run in runs:
        loop = closed and not any(sharp) and len(run) == nseg
        idx = [run[0]] + [(i + 1) % n for i in run]
        if loop:
            idx = idx[:-1]
        rings = []
        for j, vi in enumerate(idx):
            if loop or 0 < j < len(idx) - 1:
                si = run[j - 1] if j > 0 else run[-1]
                so = run[j] if j < len(run) else run[-1]
                t_in, t_out = dirs[si], dirs[so]
                nin, nout = t_in.cross(up), t_out.cross(up)
                nm = (nin + nout).normalized()
                scale = 1.0 / max(0.5, nm.dot(nin))
            else:
                t = dirs[run[0]] if j == 0 else dirs[run[-1]]
                nm, scale = t.cross(up), 1.0
            ring = []
            for a in range(segs):
                ang = 2.0 * math.pi * a / segs
                ring.append(bm.verts.new(q[vi] + nm * (r * math.cos(ang) * scale) + up * (r * math.sin(ang))))
            rings.append(ring)
        faces = []
        pairs = len(rings) if loop else len(rings) - 1
        for j in range(pairs):
            ra, rb = rings[j], rings[(j + 1) % len(rings)]
            for a in range(segs):
                b = (a + 1) % segs
                faces.append(bm.faces.new((ra[a], ra[b], rb[b], rb[a])))
        if not loop:
            faces.append(bm.faces.new(list(reversed(rings[0]))))
            faces.append(bm.faces.new(rings[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        p._set_mat(faces, mat)
    for i in range(n):
        if sharp[i]:
            p.sphere(r, tuple(q[i]), key, segs=segs, rings=max(3, segs // 2))


def lettering(p: Part, text: str, height: float, centre_x: float, y: float, z0: float, key: str,
              stroke: float = 0.02, depth: float = 0.015, round_tube: bool = False, slant: float = 0.0,
              spacing: float = 0.22, res: int = 1, inlay: bool = False, tube_segs: int = 6) -> float:
    """Stroke lettering centred on ``centre_x`` standing on the plane y (front +Y), baseline z0.
    Square bars (default), neon tubes (``round_tube``) or flat mitred letters ``depth`` proud of
    the plane (``inlay``: clean cut-metal letters, no overlapping blocks). Returns the text width."""
    width, strokes = text_strokes(text, height, spacing, slant, res)
    # read from the front (+Y, Godot -Z): the viewer's right is Blender -X, so text runs along -X
    ox = centre_x + width / 2
    yc = y + depth / 2
    for s in strokes:
        if inlay:
            _ribbon(p, [(ox - sx, z0 + sz) for sx, sz in s], stroke / 2, y, y + depth, key)
            continue
        pts = [(ox - sx, yc, z0 + sz) for sx, sz in s]
        if round_tube and res == 1:
            p.tube(pts, stroke / 2, key, segs=tube_segs)
        elif round_tube:
            _sweep(p, pts, stroke / 2, key, tube_segs)
        else:
            for a, b in zip(pts, pts[1:]):
                p.rod(a, b, stroke / 2, key, square=True)
            for q in pts[1:-1]:
                p.cbox(q, (stroke, stroke, stroke), key)
    return width
