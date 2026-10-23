"""Crew face envelope for the mask fit (not an asset script).

    blender -b --factory-startup --python tools/blender/masks/_face_envelope.py [-- --check]

Reads the crew heister glbs (``CREW``), puts each head in mask space (origin = the character's
``attach_Head`` socket from its SOURCE.txt, Blender axes: +Y forward, +Z up) and records the outer
envelope of all faces as a cylindrical height map: ``r[z][theta]`` = the largest distance from the
vertical axis ``x = 0, y = AXIS_Y`` at which any crew head's skin or hair (Body and Hair meshes,
plus the hair-material faces of any other mesh, e.g. Dutch's beard on ``Headwear``; rest pose)
lies, per height z and azimuth theta (0 = straight ahead, + = towards Blender +X). Written to
``_crew_face_envelope.json`` next to this script; ``_mask_base.FaceSurface`` pushes every mask's
shell out of it by ``fit_clearance`` (the mask fit). The map stores each crew glb's sha256
(``crew_sha256``); ``game/tests/d/test_masks.gd`` fails when a crew glb changes without a rerun.
Rerun whenever a crew head changes, then rebuild the masks; ``--check`` exits 1 if the committed
map is stale.
"""
import hashlib
import json
import math
import pathlib
import re
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
OUT = HERE / "_crew_face_envelope.json"
CREW = ["char_crew_rook", "char_crew_sable", "char_crew_dutch", "char_crew_wren", "char_crew_marten", "char_crew_jay",
        "char_crew_juno", "char_crew_hale", "char_crew_body",
        "char_crew_body_b"]
MESHES = ("Body", "Hair")   # skin and hair: the mask goes over the hairline, not under it
HAIR_MAT = "M_char_hair_"   # + hair-material faces of any other mesh (Dutch's beard on Headwear)
AXIS_Y = -0.075
TH0, TH1, DTH = -110.0, 110.0, 2.0       # degrees
Z0, Z1, DZ = -0.170, 0.170, 0.004         # metres
R_FAR = 0.30
SRC_RE = re.compile(r"model \[([-\d.]+), ([-\d.]+), ([-\d.]+)\]")


def _head_bvh(cid: str) -> BVHTree:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    src = (REPO / "game/assets/characters" / cid / "SOURCE.txt").read_text()
    line = next(ln for ln in src.splitlines() if ln.startswith("attach_Head"))
    gx, gy, gz = map(float, SRC_RE.search(line).groups())
    sock = Vector((gx, -gz, gy))
    bpy.ops.import_scene.gltf(filepath=str(REPO / "game/assets/characters" / cid / f"{cid}.glb"))
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    verts: list = []
    polys: list = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        whole = o.name.split(".")[0] in MESHES
        me = o.evaluated_get(dg).to_mesh()
        hair = {i for i, m in enumerate(me.materials) if m is not None and m.name.startswith(HAIR_MAT)}
        if not whole and not hair:
            continue
        base = len(verts)
        verts += [o.matrix_world @ v.co - sock for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons if whole or p.material_index in hair]
    return BVHTree.FromPolygons(verts, polys)


def build() -> dict:
    nth = round((TH1 - TH0) / DTH) + 1
    nz = round((Z1 - Z0) / DZ) + 1
    r = [[0.0] * nth for _ in range(nz)]
    for cid in CREW:
        bvh = _head_bvh(cid)
        for iz in range(nz):
            z = Z0 + iz * DZ
            for it in range(nth):
                a = math.radians(TH0 + it * DTH)
                d = Vector((math.sin(a), math.cos(a), 0.0))
                o = Vector((0.0, AXIS_Y, z)) + d * R_FAR
                hit, _n, _i, dist = bvh.ray_cast(o, -d, R_FAR)
                if hit is not None:
                    r[iz][it] = max(r[iz][it], round(R_FAR - dist, 4))
    sha = {cid: hashlib.sha256((REPO / "game/assets/characters" / cid / f"{cid}.glb").read_bytes()).hexdigest()
           for cid in CREW}
    return {"doc": "crew face envelope, see tools/blender/masks/_face_envelope.py", "crew": CREW,
            "crew_sha256": sha,
            "axis_y": AXIS_Y, "theta_deg": [TH0, TH1, DTH], "z": [Z0, Z1, DZ], "r": r}


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    env = build()
    text = json.dumps(env, separators=(",", ":"))
    if "--check" in argv:
        same = OUT.exists() and OUT.read_text() == text
        print("face envelope", "current" if same else "STALE: rerun tools/blender/masks/_face_envelope.py")
        sys.exit(0 if same else 1)
    OUT.write_text(text)
    print("WROTE", OUT)


main()
