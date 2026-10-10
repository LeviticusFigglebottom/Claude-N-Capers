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
    "akimbo": ["akimbo_idle:0", "akimbo_ads_idle:0", "akimbo_sprint:4", "akimbo_fire:1", "akimbo_fire_l:1",
               "akimbo_reload:4", "akimbo_reload:11", "akimbo_reload_empty:50", "akimbo_draw:9"],
    "revolver": ["revolver_idle:0", "revolver_ads_idle:0", "revolver_fire:1", "revolver_reload:12",
                 "revolver_reload:22", "revolver_reload:40", "revolver_reload:46", "revolver_reload:56",
                 "revolver_sprint:4"],
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


def _box(name, lo, hi, mat, bev: float = 0.0):
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    lo, hi = np.array(lo, float), np.array(hi, float)
    for v in bm.verts:
        v.co = tuple(lo + (np.array(v.co) + 0.5) * (hi - lo))
    if bev > 0.0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=2, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    scene.link(ob)
    return ob


def _tube(name, c, r, y0, y1, mat, seg: int = 24, flutes: int = 0):
    """A cylinder along weapon +Y (Blender weapon axes) centred on ``c`` (x, z)."""
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=y1 - y0)
    for v in bm.verts:
        x, y, z = v.co
        if flutes:
            a = math.atan2(y, x)
            k = 1.0 - 0.10 * max(0.0, math.cos(flutes * a)) ** 8
            x, y = x * k, y * k
        v.co = (c[0] + x, (y0 + y1) * 0.5 + z, c[1] + y)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    scene.link(ob)
    return ob


def _revolver_proxy(s):
    """Scratch-only Marshal .357 stand-in (never exported): frame + barrel (static), Crane group
    (crane arm, fluted cylinder, ejector rod) and a Speedloader with six rounds."""
    from lib import materials
    steel = materials.material("review_rev_steel", "#2E3034", 0.35)
    wood = materials.material("review_rev_wood", "#5B3B27", 0.6)
    brass = materials.material("review_rev_brass", "#B48A3E", 0.3)
    loader_m = materials.material("review_rev_loader", "#1E1F22", 0.5)
    m = s.markers
    cyl, cr, cl = m["cyl"], m["cyl_r"], m["cyl_len"]
    y0, y1 = cyl[1] - cl / 2, cyl[1] + cl / 2
    static = [
        _box("RevFrameTop", (-0.011, y0 - 0.055, 0.050), (0.011, y1 + 0.004, 0.060), steel, 0.002),
        _box("RevFrameRear", (-0.012, y0 - 0.050, 0.004), (0.012, y0 - 0.001, 0.058), steel, 0.002),
        _box("RevFrameLow", (-0.011, y0 - 0.020, 0.000), (0.011, y1 + 0.010, 0.012), steel, 0.002),
        _box("RevFrameFront", (-0.010, y1 + 0.001, 0.004), (0.010, y1 + 0.012, 0.060), steel, 0.002),
        _box("RevHammer", (-0.003, y0 - 0.062, 0.046), (0.003, y0 - 0.044, 0.068), steel),
        _box("RevGuard", (-0.003, 0.0, -0.022), (0.003, 0.050, -0.016), steel),
        _box("RevTrigger", (-0.003, 0.020, -0.015), (0.003, 0.028, 0.002), steel),
        _box("RevSightRear", (-0.006, -0.030, 0.058), (0.006, -0.022, 0.066), steel),
        _box("RevSightFront", (-0.0015, 0.150, 0.058), (0.0015, 0.158, 0.068), steel),
        _tube("RevBarrel", (0.0, 0.047), 0.0085, y1, 0.160, steel),
        _tube("RevShroud", (0.0, cyl[2]), 0.0065, y1, 0.112, steel),
    ]
    grip = _box("RevGrip", (-0.0145, -0.050, -0.080), (0.0145, -0.012, 0.010), wood, 0.004)
    grip.matrix_world = Matrix.Rotation(math.radians(-18.0), 4, "X") @ grip.matrix_world
    bpy.context.view_layer.update()
    grip.data.transform(grip.matrix_world)
    grip.matrix_world = Matrix.Identity(4)
    static.append(grip)
    h = m["hinge"]
    crane = [_tube("RevCylinder", (cyl[0], cyl[2]), cr, y0, y1, steel, 36, flutes=6),
             _box("RevCraneArm", (h[0] - 0.003, y1 + 0.0005, h[2] - 0.003), (cyl[0] + 0.003, y1 + 0.005, cyl[2] + 0.003),
                  steel),
             _tube("RevRod", (cyl[0], cyl[2]), 0.0028, y1, m["rod_tip"][1], steel, 12)]
    for i in range(6):
        a = math.radians(60.0 * i)
        crane.append(_tube(f"RevCase{i}", (cyl[0] + 0.0115 * math.cos(a), cyl[2] + 0.0115 * math.sin(a)), 0.0048,
                           y0 - 0.0012, y0, brass, 12))
    ld = m["loader"]
    loader = [_tube("RevLoader", (ld[0], ld[2]), 0.020, y0 - 0.020, y0 - 0.006, loader_m, 32),
              _tube("RevLoaderKnob", (ld[0], ld[2]), 0.007, y0 - 0.030, y0 - 0.020, loader_m, 16)]
    for i in range(6):
        a = math.radians(60.0 * i)
        loader.append(_tube(f"RevRound{i}", (ld[0] + 0.0115 * math.cos(a), ld[2] + 0.0115 * math.sin(a)), 0.0045,
                            y0 - 0.006, y0 + 0.026, brass, 12))
    return static, crane, loader


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
    rev = None
    if (REPO / f"game/assets/weapons/{s.weapon}/{s.weapon}.glb").exists():
        gun, parts, rest = _import_weapon(s.weapon)
    else:                                         # no marshal model yet: scratch proxy (never exported)
        rev = _revolver_proxy(s)
        gun, parts, rest = None, {}, {}
    mag_node = next((o for n, o in parts.items() if n.startswith("StockMagazine")), None)
    gun_l, mag_l = None, None
    if s.support == "akimbo":                     # the second gun (WeaponVisual on hand.L in game)
        gun_l, parts_l, rest_l = _import_weapon(s.weapon)
        mag_l = next((o for n, o in parts_l.items() if n.startswith("StockMagazine")), None)
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
        if gun is not None:
            gun.matrix_world = Mg
        if gun_l is not None:
            gun_l.matrix_world = _m(*st.extra["wf_l"])
            bpy.context.view_layer.update()
            if mag_l is not None:
                mag_l.matrix_world = _m(*st.extra["mag_l"]) @ rest_l[mag_l.name]
        if rev is not None:
            import _arms_revolver as RV
            static, crane, loader = rev
            for o in static:
                o.matrix_world = Mg
            Rc, tc = RV.crane_frame(s, st.extra.get("crane", 0.0))
            for o in crane:
                o.matrix_world = Mg @ _m(Rc, tc)
            Rm, pm = magazine_of(sk, sv)
            for o in loader:
                o.matrix_world = _m(Rm, pm)
                o.hide_render = not st.extra.get("loader", False)
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

