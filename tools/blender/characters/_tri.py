"""Deterministic quad triangulation for every character mesh, run before export. Blender only (``bmesh``).

Why: left as quads, the glTF exporter (``loop_triangles``) and mikktspace (tangents) each choose a
quad diagonal themselves. A non-planar quad then gets a fixed index-order split, which shades
asymmetrically on mirrored faces (dark creases on one side of a face), and the tangents of quads
whose two diagonals tie were not reproducible from build to build. Triangles leave nothing to
decide downstream.

The rule (mirror-symmetric, so mirrored quads get mirrored splits): each diagonal (i, j) predicts
the smooth surface above its chord midpoint from the vertex normals, sagitta ~ (n_j - n_i).(p_j - p_i)/8
(exact for a circular arc). The diagonal whose own midpoint lies closest to the mean predicted
surface point is used, i.e. the split that best follows the curvature (convex on the cranium,
concave in the creases). Ties (planar quads): the shorter diagonal, then 0-2.
"""

from __future__ import annotations


def quad_split(p, n) -> bool:
    """``True``: split quad (p0, p1, p2, p3) along 0-2, ``False``: along 1-3. ``p``/``n`` are 4
    positions and unit vertex normals (anything with x, y, z and vector maths, e.g. mathutils)."""
    nsum = n[0] + n[1] + n[2] + n[3]
    if nsum.length < 1e-12:
        nsum = (p[1] - p[0]).cross(p[3] - p[0])
    if nsum.length < 1e-12:
        return True
    nn = nsum.normalized()
    pred = []
    mids = []
    for i, j in ((0, 2), (1, 3)):
        mid = (p[i] + p[j]) * 0.5
        sag = (n[j] - n[i]).dot(p[j] - p[i]) / 8.0
        mids.append(mid)
        pred.append(mid + nn * sag)
    target = (pred[0] + pred[1]) * 0.5
    e02 = abs((mids[0] - target).dot(nn))
    e13 = abs((mids[1] - target).dot(nn))
    if abs(e02 - e13) > 1e-7:
        return e02 < e13
    d02 = (p[2] - p[0]).length
    d13 = (p[3] - p[1]).length
    if abs(d02 - d13) > 1e-7:
        return d02 < d13
    return True


def triangulate(obj) -> int:
    """Split every quad of ``obj`` (mesh object, shape keys and all custom data kept) into two
    triangles with ``quad_split``. N-gons are not expected (the outfit/body builders never make
    them). Returns the number of quads split. Face order: original faces keep their index, the
    second triangle of each quad is appended in face order (deterministic)."""
    import bmesh

    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    quads = [f for f in bm.faces if len(f.verts) == 4]
    if any(len(f.verts) > 4 for f in bm.faces):
        bm.free()
        raise ValueError(f"{obj.name}: n-gons left for the exporter to triangulate")
    # decide on the rest positions before any split changes the normals
    plan = []
    for f in quads:
        vs = [lp.vert for lp in f.loops]
        plan.append((f, vs, quad_split([v.co for v in vs], [v.normal for v in vs])))
    for f, vs, d02 in plan:
        a, b = (vs[0], vs[2]) if d02 else (vs[1], vs[3])
        bmesh.utils.face_split(f, a, b)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(plan)
