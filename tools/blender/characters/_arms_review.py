"""First-person review sheets for ``char_arms_fp`` (D1-03, D-034); called by ``_anim_review.py arms``.

    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- arms OUT.png SET [clip:frame ...]

One panel per ``clip:frame`` cell (default: ``REVIEW_CELLS[SET]``): the arms + the set's weapon
model (attached through the ``weapon`` bone, the magazine node through the ``magazine`` bone; pump,
bolt and LMG feed cover moved from the clip's part curves; a shell proxy in the left hand during
shotgun loads) seen from the rig root, i.e. the crew camera: 75 deg vertical FOV
(``crew_member.tscn``), 16:9. A small red cross marks the screen centre (ADS alignment check).
Cycles CPU, low samples.
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
import _arms_clips as CL
from _arms_choreo import magazine_of, realize, weapon_of
from lib import scene

REPO = pathlib.Path(__file__).resolve().parents[3]
REVIEW_CELLS = {
    "pistol": ["pistol_idle:0", "pistol_ads_idle:0", "pistol_sprint:4", "pistol_fire:1", "pistol_reload:9",
               "pistol_reload:25", "pistol_reload_empty:29", "pistol_reload_empty:43", "pistol_draw:8"],
    "smg": ["smg_idle:0", "smg_ads_idle:0", "smg_sprint:4", "smg_fire:1", "smg_reload:13", "smg_reload:34",
            "smg_reload_empty:61", "smg_draw:10", "smg_holster:6"],
    "rifle": ["rifle_idle:0", "rifle_ads_idle:0", "rifle_sprint:4", "rifle_fire:1", "rifle_reload:14",
              "rifle_reload:37", "rifle_reload_empty:62", "rifle_draw:12", "rifle_fire_ads:1"],
    "shotgun": ["shotgun_idle:0", "shotgun_ads_idle:0", "shotgun_sprint:4", "shotgun_fire:2", "shotgun_fire:9",
                "shotgun_fire_ads:9", "shotgun_reload_loop:2", "shotgun_reload_loop:6", "shotgun_reload_end_empty:17"],
    "lmg": ["lmg_idle:0", "lmg_ads_idle:0", "lmg_sprint:4", "lmg_reload:24", "lmg_reload:60", "lmg_reload:100",
            "lmg_reload:116", "lmg_reload:132", "lmg_reload_empty:160"],
    "sniper": ["sniper_idle:0", "sniper_ads_idle:0", "sniper_sprint:4", "sniper_fire:1", "sniper_bolt:9",
               "sniper_bolt:12", "sniper_bolt_ads:12", "sniper_reload:22", "sniper_reload:47"],
}
W, H = 640, 360
SHELL_IN_HAND = (0.012, 0.100, -0.018)      # shell centre in hand.L bone space (review proxy)


def _m(R, p) -> Matrix:
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = float(R[i, j])
        m[i][3] = float(p[i])
    return m


def _rot_about(R: np.ndarray, c) -> Matrix:
    c = np.asarray(c, float)
    return _m(R, c - R @ c)


class _Ctx:
    def material(self, lib_id, color, roughness=0.6):
        from lib import materials
        return materials.material(lib_id, color, roughness)


def _import_weapon(asset: str):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(REPO / f"game/assets/weapons/{asset}/{asset}.glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    rest = {o.name: o.matrix_world.copy() for o in objs}
    gun = bpy.data.objects.new("Gun", None)
    scene.link(gun)
    for o in objs:
        if o.parent is None:
            o.parent = gun
    return gun, {o.name: o for o in objs}, rest


def _shell(mat):
    me = bpy.data.meshes.new("ShellProxy")
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.0105, radius2=0.0105, depth=0.068)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new("ShellProxy", me)
    scene.link(ob)
    return ob


def render(out: pathlib.Path, args: list[str]) -> None:
    from _anim_review import _setup_render

    set_name = args[0] if args and ":" not in args[0] else "pistol"
    cells = [a for a in args if ":" in a] or REVIEW_CELLS[set_name]
    s = F.SETS[set_name]
    scene.reset()
    sk = F.skeleton()
    solver = A.Solver(sk)
    fns = CL.state_fns(sk, s)
    arm = F.build_arms_rig()
    F.build_arms_mesh(_Ctx(), arm, {"skin": 2})
    gun, parts, rest = _import_weapon(s.weapon)
    mag_node = next((o for n, o in parts.items() if n.startswith("StockMagazine")), None)
    from lib import materials
    shell = _shell(materials.material("review_shell", "#B0322A", 0.4))
    cam = bpy.data.cameras.new("FP")
    cam.sensor_fit = "VERTICAL"
    cam.angle_y = math.radians(float(os.environ.get("FP_FOV", "75")))
    cam.clip_start = 0.03
    co = bpy.data.objects.new("FP", cam)
    co.rotation_euler = (math.radians(90.0), 0.0, 0.0)          # look along +Y
    scene.link(co)
    bpy.context.scene.camera = co
    _setup_render(W, H, samples=int(os.environ.get("FP_SAMPLES", "16")))
    bg = bpy.data.meshes.new("bg")
    bg.from_pydata([(-6, 4.0, -4), (6, 4.0, -4), (6, 4.0, 4), (-6, 4.0, 4)], [], [(0, 1, 2, 3)])
    scene.link(bpy.data.objects.new("bg", bg))
    panels = []
    import tempfile
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="arms_review_")) / out.stem      # panels never land in the project
    for i, cell in enumerate(cells):
        name, fs = cell.split(":")
        clip = name[len(s.name) + 1:]
        st = fns[clip](int(fs))
        sv = solver.solve(realize(sk, solver, st, s.sh))
        A.apply_frame(arm, sv)
        Rw, pw = weapon_of(sk, sv)
        Mg = _m(Rw, pw)
        gun.matrix_world = Mg
        bpy.context.view_layer.update()
        if mag_node is not None:
            Rm, pm = magazine_of(sk, sv)
            mag_node.matrix_world = _m(Rm, pm) @ rest[mag_node.name]
        if "Pump" in parts:
            p = st.extra.get("pump", 0.0)
            parts["Pump"].matrix_world = Mg @ Matrix.Translation((0.0, -CL.PUMP_TRAVEL * p, 0.0)) @ rest["Pump"]
        if "Bolt" in parts:
            lift, back = st.extra.get("bolt", (0.0, 0.0))
            bore = s.markers["bore"]
            rot = _rot_about(A.ryd(-CL.BOLT_LIFT_DEG * lift), bore)
            slide = Matrix.Translation((0.0, -CL.BOLT_TRAVEL * back, 0.0))
            parts["Bolt"].matrix_world = Mg @ slide @ rot @ rest["Bolt"]
        if "FeedCover" in parts:
            ang = st.extra.get("cover", 0.0)
            parts["FeedCover"].matrix_world = Mg @ _rot_about(A.rxd(-CL.COVER_OPEN_DEG * ang),
                                                              s.markers["cover_hinge"]) @ rest["FeedCover"]
        shell.hide_render = not st.extra.get("shell", False)
        if not shell.hide_render:
            Rh = sv.W["hand.L"] @ sk.B["hand.L"]
            ph = sv.P["hand.L"] + Rh @ np.array(SHELL_IN_HAND)
            shell.matrix_world = _m(np.column_stack([Rw[:, 0], -Rw[:, 2], Rw[:, 1]]), ph)
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
        cy, cx = H // 2, W // 2
        px[cy, cx - 5:cx + 6, :3] = (0.9, 0.05, 0.05)
        px[cy - 5:cy + 6, cx, :3] = (0.9, 0.05, 0.05)
        px[0, :, :3] = px[-1, :, :3] = 0.2
        px[:, 0, :3] = px[:, -1, :3] = 0.2
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

