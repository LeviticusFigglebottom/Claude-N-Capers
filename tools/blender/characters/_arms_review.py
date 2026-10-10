"""First-person review render for ``char_arms_fp`` (D1-03); called by ``_anim_review.py arms``.

Panels: the arms + Kestrel P9 seen from the rig root (the camera), 75 deg vertical FOV, 16:9,
for a list of ``clip:frame`` cells (default: idle, ads_idle, sprint and four reload frames).
"""

from __future__ import annotations

import math
import os
import pathlib

import bpy
import numpy as np
from mathutils import Matrix

import _anim as A
import _arms as F
from lib import scene

REPO = pathlib.Path(__file__).resolve().parents[3]
PISTOL_GLB = REPO / "game/assets/weapons/wpn_kestrel_p9/wpn_kestrel_p9.glb"
DEFAULT = ["pistol_idle:0", "pistol_ads_idle:0", "pistol_sprint:0", "pistol_reload:5", "pistol_reload:22",
           "pistol_reload:29", "pistol_reload_empty:40", "pistol_draw:5", "pistol_fire:2"]
W, H = 640, 360


def _m(R, p) -> Matrix:
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = float(R[i, j])
        m[i][3] = float(p[i])
    return m


def render(out: pathlib.Path, cells: list[str]) -> None:
    from _anim_review import _setup_render  # noqa: PLC0415

    cells = cells or DEFAULT
    scene.reset()
    sk = F.skeleton()
    solver = A.Solver(sk)
    names = sorted({c.split(":")[0] for c in cells})
    clips = F.fp_clips(sk, F.PISTOL)
    baked = {n: A.bake(solver, clips[n]) for n in names}
    arm = F.build_arms_rig()

    class _Ctx:
        def material(self, lib_id, color, roughness=0.6):
            from lib import materials  # noqa: PLC0415
            return materials.material(lib_id, color, roughness)
    F.build_arms_mesh(_Ctx(), arm, {"skin": 2})
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(PISTOL_GLB))
    gun_objs = [o for o in bpy.data.objects if o not in before]
    gun = bpy.data.objects.new("Gun", None)
    scene.link(gun)
    for o in gun_objs:
        if o.parent is None:
            o.parent = gun
    mag_root = next(o for o in gun_objs if o.name.startswith("StockMagazine"))
    mag_rest_local = mag_root.matrix_local.copy()
    cam = bpy.data.cameras.new("FP")
    cam.sensor_fit = "VERTICAL"
    cam.angle_y = math.radians(float(os.environ.get("FP_FOV", "75")))
    cam.clip_start = 0.02
    co = bpy.data.objects.new("FP", cam)
    co.rotation_euler = (math.radians(90.0 + float(os.environ.get("FP_PITCH", "0"))), 0.0,
                         math.radians(float(os.environ.get("FP_YAW", "0"))))     # look along +Y
    scene.link(co)
    bpy.context.scene.camera = co
    _setup_render(W, H, samples=16)
    bg = bpy.data.meshes.new("bg")
    bg.from_pydata([(-3, 2.5, -2), (3, 2.5, -2), (3, 2.5, 2), (-3, 2.5, 2)], [], [(0, 1, 2, 3)])
    bgo = bpy.data.objects.new("bg", bg)
    scene.link(bgo)
    panels = []
    tmp = out.with_suffix("")
    for i, cell in enumerate(cells):
        name, fs = cell.split(":")
        s = baked[name].frames[int(fs)]
        A.apply_frame(arm, s)
        Ah = s.W["hand.R"] @ sk.B["hand.R"]
        R_off, t_off = A.grip_offset(sk, "R")
        Rw, pw = Ah @ R_off, s.P["hand.R"] + Ah @ t_off
        gun.matrix_world = _m(Rw, pw)
        # magazine: bone delta relative to the weapon frame
        Wm, Pm = s.W["magazine"], s.P["magazine"]
        Rm = Wm @ sk.B["magazine"]
        Rm_w = np.column_stack([Rm[:, 0], -Rm[:, 2], Rm[:, 1]])        # back to weapon axes
        rel = _m(Rw, pw).inverted() @ _m(Rm_w, Pm)
        mag_root.matrix_local = rel @ mag_rest_local
        if os.environ.get("FP_ORBIT"):
            off = np.array([float(x) for x in os.environ["FP_ORBIT"].split(",")])
            eye = pw + Rw @ off
            d = pw - eye
            d /= np.linalg.norm(d)
            right = np.cross(d, np.array([0.0, 0.0, 1.0]))
            right /= np.linalg.norm(right)
            upv = np.cross(right, d)
            co.matrix_world = _m(np.column_stack([right, upv, -d]), eye)
        bpy.context.view_layer.update()
        path = f"{tmp}_{i}.png"
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        panels.append((cell, path))
    cols = 3
    rows = math.ceil(len(panels) / cols)
    sheet = np.zeros((rows * H, cols * W, 4), dtype=np.float32)
    for i, (_cell, path) in enumerate(panels):
        img = bpy.data.images.load(path)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
        r, c = i // cols, i % cols
        sheet[(rows - 1 - r) * H:(rows - r) * H, c * W:(c + 1) * W] = px
        bpy.data.images.remove(img)
        pathlib.Path(path).unlink()
    im = bpy.data.images.new("sheet", cols * W, rows * H, alpha=True)
    im.pixels.foreach_set(sheet.ravel())
    im.filepath_raw = str(out)
    im.file_format = "PNG"
    im.save()
    print("[review] arms panels:", ", ".join(c for c, _p in panels))
