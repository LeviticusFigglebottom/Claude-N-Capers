"""Clothing as layers on the body surface (pure numpy).

Each body face is assigned to the first outfit layer whose ``match`` accepts it. A layer has a
material (id or callable) and a thickness (m, or callable on face info). Vertices shared by faces
of different layers are duplicated, each copy pushed out along the rest normal by its layer's
thickness, and a flat-shaded step strip closes the gap (cuffs, hems, collars, shoe tops). The
result stays watertight, shares the body's skin weights (no clipping when animated) and costs
almost no extra triangles. ``shell()`` builds detached thick garments (vests, plate carriers) from
a face region; gear is added separately (``_gear.Gear``).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from _body import HEAD_AXIS_Y, BodyGen, Mesh, edge_faces, vertex_normals


@dataclass
class FaceInfo:
    part: str
    side: int
    s: float          # mean position along the part (unscaled)
    z: float          # centroid height / scale (unscaled metres)
    zh: float         # normalised head height (0 chin .. 1 crown)
    phi: float        # angle around the body axis, 0 front, +pi/2 right
    x: float          # centroid x / scale
    nz: float         # normal z
    ang: float        # mean vertex angle param (eyes: cos theta towards the front)


def face_infos(m: Mesh, gen: BodyGen) -> list[FaceInfo]:
    pos = m.positions()
    k = gen.k
    out = []
    for fi, f in enumerate(m.f):
        part = m.fpart[fi]
        pts = pos[list(f)]
        c = pts.mean(axis=0)
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        ln = np.linalg.norm(n)
        nz = float(n[2] / ln) if ln > 0 else 0.0
        same = [i for i in f if m.part[i] == part] or list(f)
        s = float(np.mean([m.s[i] for i in same]))
        ang = float(np.mean([m.ang[i] for i in same]))
        zh = (c[2] - gen.z_chin) / gen.head_h
        cy = HEAD_AXIS_Y * k if part in ("head", "eye", "ear") else -0.012 * k
        phi = math.atan2(c[0], c[1] - cy)
        side = 1 if c[0] > 0 else -1
        out.append(FaceInfo(part, side, s, float(c[2] / k), float(zh), phi, float(c[0] / k), nz, ang))
    return out


@dataclass
class Layer:
    name: str
    match: object          # callable(FaceInfo) -> bool
    mat: object            # str or callable(FaceInfo) -> str
    t: object = 0.0        # float or callable(FaceInfo) -> float (metres, before scale)


def dress(m: Mesh, gen: BodyGen, layers: list[Layer], drop_parts: tuple = ()):
    """Returns (positions, faces, face_materials, weights, flat_face_indices)."""
    infos = face_infos(m, gen)
    pos = m.positions()
    nrm = vertex_normals(pos, m.f)
    k = gen.k
    keep = [fi for fi in range(len(m.f)) if not (m.fpart[fi] in drop_parts)]
    face_layer: dict[int, int] = {}
    face_mat: dict[int, str] = {}
    face_t: dict[int, float] = {}
    for fi in keep:
        info = infos[fi]
        for li, lay in enumerate(layers):
            if lay.match(info):
                face_layer[fi] = li
                face_mat[fi] = lay.mat(info) if callable(lay.mat) else lay.mat
                face_t[fi] = (lay.t(info) if callable(lay.t) else lay.t) * k
                break
        else:
            raise ValueError(f"no layer matches face {fi} ({info.part})")
    # per (vertex, layer) average thickness
    acc: dict[tuple[int, int], list[float]] = {}
    for fi in keep:
        li = face_layer[fi]
        for vi in m.f[fi]:
            acc.setdefault((vi, li), []).append(face_t[fi])
    new_pos: list[np.ndarray] = []
    new_w: list[dict] = []
    remap: dict[tuple[int, int], int] = {}
    for key in sorted(acc):
        vi, _li = key
        t = float(np.mean(acc[key]))
        remap[key] = len(new_pos)
        new_pos.append(pos[vi] + nrm[vi] * t)
        new_w.append(m.w[vi])
    faces: list[tuple] = []
    mats: list[str] = []
    for fi in keep:
        li = face_layer[fi]
        faces.append(tuple(remap[(vi, li)] for vi in m.f[fi]))
        mats.append(face_mat[fi])
    # step strips between layers
    flat: set[int] = set()
    ef = edge_faces([m.f[fi] for fi in keep])
    kept_idx = keep
    for (a, b), fl in sorted(ef.items()):
        if len(fl) != 2:
            continue
        f1, f2 = kept_idx[fl[0]], kept_idx[fl[1]]
        l1, l2 = face_layer[f1], face_layer[f2]
        if l1 == l2:
            continue
        t1 = (np.mean(acc[(a, l1)]) + np.mean(acc[(b, l1)])) / 2
        t2 = (np.mean(acc[(a, l2)]) + np.mean(acc[(b, l2)])) / 2
        hi, lo = (f1, f2) if t1 >= t2 else (f2, f1)
        lh, ll = face_layer[hi], face_layer[lo]
        fh = m.f[hi]
        n = len(fh)
        # direction of the edge inside the higher face
        da, db = a, b
        for q in range(n):
            if fh[q] == b and fh[(q + 1) % n] == a:
                da, db = b, a
                break
        # higher face has da -> db; strip = (db_hi, da_hi, da_lo, db_lo)
        quad = (remap[(db, lh)], remap[(da, lh)], remap[(da, ll)], remap[(db, ll)])
        if quad[0] == quad[3] and quad[1] == quad[2]:
            continue
        flat.add(len(faces))
        faces.append(quad)
        mats.append(face_mat[hi])
    return np.array(new_pos), faces, mats, new_w, flat


def shell(m: Mesh, gen: BodyGen, match, mat, thickness: float, base_offset: float = 0.0,
          rim_mat=None, info_cache: list[FaceInfo] | None = None):
    """Detached thick garment over the faces accepted by ``match`` (FaceInfo -> bool).

    Returns (positions, faces, face_materials, weights, flat_faces) like ``dress``. ``mat`` may be
    callable(FaceInfo) -> material id. The rim folds back to ``base_offset`` above the skin."""
    infos = info_cache if info_cache is not None else face_infos(m, gen)
    pos = m.positions()
    nrm = vertex_normals(pos, m.f)
    k = gen.k
    sel = [fi for fi in range(len(m.f)) if match(infos[fi])]
    verts = sorted({vi for fi in sel for vi in m.f[fi]})
    outer = {vi: i for i, vi in enumerate(verts)}
    inner = {vi: i + len(verts) for i, vi in enumerate(verts)}
    P = [pos[vi] + nrm[vi] * (base_offset + thickness) * k for vi in verts]
    P += [pos[vi] + nrm[vi] * base_offset * k for vi in verts]
    W = [m.w[vi] for vi in verts] * 2
    faces: list[tuple] = []
    mats: list[str] = []
    for fi in sel:
        faces.append(tuple(outer[vi] for vi in m.f[fi]))
        mats.append(mat(infos[fi]) if callable(mat) else mat)
    ef = edge_faces([m.f[fi] for fi in sel])
    flat: set[int] = set()
    for (a, b), fl in sorted(ef.items()):
        if len(fl) != 1:
            continue
        f = m.f[sel[fl[0]]]
        n = len(f)
        da, db = a, b
        for q in range(n):
            if f[q] == b and f[(q + 1) % n] == a:
                da, db = b, a
                break
        flat.add(len(faces))
        faces.append((outer[db], outer[da], inner[da], inner[db]))
        rm = rim_mat if rim_mat is not None else (mat(infos[sel[fl[0]]]) if callable(mat) else mat)
        mats.append(rm)
    return np.array(P), faces, mats, W, flat


def merge(parts: list[tuple]):
    """Concatenate (positions, faces, mats, weights, flat) tuples."""
    P, F, M, W, FL = [], [], [], [], set()
    for pos, faces, mats, w, flat in parts:
        off = len(P)
        foff = len(F)
        P.extend(list(pos))
        F.extend(tuple(i + off for i in f) for f in faces)
        M.extend(mats)
        W.extend(w)
        FL.update(i + foff for i in flat)
    return np.array(P), F, M, W, FL
