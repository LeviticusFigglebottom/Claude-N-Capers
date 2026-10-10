"""Review renders for D1-03 animations (contact sheets). Not an asset script; run directly:

    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- humanoid OUT.png [clip:frame ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- arms OUT.png

``humanoid``: one posed ``char_body_base`` body per cell (Cycles CPU, low samples; EEVEE needs EGL),
3/4 front view with a side-view row for locomotion, the weapon models attached through the HandR
grip convention, a floor at z = 0, labels. Also prints the lowest skinned-mesh vertex per cell
(floor penetration check). ``arms``: the first-person arms with the Kestrel P9 from the camera at
the rig root (idle and reload mid), 75 deg vertical FOV like the crew camera.
"""

from __future__ import annotations

import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix  # noqa: E402

import _anim as A  # noqa: E402
import _body as body  # noqa: E402
import _rig as rig  # noqa: E402
from lib import meta, scene  # noqa: E402

WEAPONS = {"pistol": REPO / "game/assets/weapons/wpn_kestrel_p9/wpn_kestrel_p9.glb",
           "rifle": REPO / "game/assets/weapons/wpn_corsair_ar/wpn_corsair_ar.glb"}
GUN_CLIPS = {"aim_pistol": "pistol", "fire_pistol": "pistol", "reload_pistol": "pistol", "downed": "pistol",
             "aim_rifle": "rifle", "fire_rifle": "rifle", "reload_rifle": "rifle", "melee": "rifle"}

DEFAULT_CELLS = ["walk:0", "walk:7", "walk:15", "walk:22", "run:0", "run:6", "crouch_walk:0", "crouch_walk:9",
                 "aim_pistol:0", "aim_rifle:0", "cower:0", "hands_up:0", "death_front:-1", "death_back:-1", "downed:0",
                 "carry_bag_walk:0", "interact_mid:0", "interact_low:0", "lie_down:0", "tied:0", "reload_pistol:22",
                 "reload_rifle:30", "throw_bag:15", "phone_call:0"]


def _mat(name: str, rgb, rough: float = 0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def _import_weapon(kind: str):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(WEAPONS[kind]))
    objs = [o for o in bpy.data.objects if o not in before]
    holder = bpy.data.objects.new(f"W_{kind}", None)
    scene.link(holder)
    for o in objs:
        if o.parent is None:
            o.parent = holder
    return holder


def _weapon_matrix(sk, s) -> Matrix:
    R_off, t_off = A.grip_offset(sk, "R")
    Ah = s.W["hand.R"] @ sk.B["hand.R"]
    Rw = Ah @ R_off
    pw = s.P["hand.R"] + Ah @ t_off
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = float(Rw[i, j])
        m[i][3] = float(pw[i])
    return m


def _label(text: str, loc, size: float = 0.09):
    cu = bpy.data.curves.new(f"lbl_{text}", "FONT")
    cu.body = text
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new(f"lbl_{text}", cu)
    ob.location = loc
    ob.data.materials.append(_mat("label", (0.02, 0.02, 0.02)))
    scene.link(ob)
    return ob


def _setup_render(res_x: int, res_y: int, samples: int = 24) -> None:
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.64, 0.68, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    sc.world = world
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.0
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.link(so)
    sc.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in
                                                          type(sc.view_settings).bl_rna.properties["view_transform"].enum_items] else "Filmic"


def humanoid(out: pathlib.Path, cells: list[str]) -> None:
    scene.reset()
    consts = meta.read_constants(HERE / "anim_humanoid.py")
    table = consts["CLIPS"]
    import _anim_humanoid as lib  # noqa: PLC0415

    sk = A.Skeleton.humanoid()
    solver = A.Solver(sk)
    names = sorted({c.split(":")[0] for c in cells})
    cols = int(__import__("os").environ.get("REVIEW_COLS", "6"))
    clips = lib.clips(sk, {n: table[n] for n in names})
    baked = {n: A.bake(solver, clips[n]) for n in names}
    rows = math.ceil(len(cells) / cols)
    cam_obj, right, up = _camera((0.55, 1.0, 0.42))
    dx, dy = 2.0, 2.35
    floor_mat = _mat("floor", (0.30, 0.30, 0.32), 0.9)
    weapons_src = {k: _import_weapon(k) for k in WEAPONS}
    for w in weapons_src.values():
        w.location = (0.0, 0.0, -50.0)
    lows = []
    for i, cell in enumerate(cells):
        parts = cell.split(":")
        name, fs = parts[0], parts[1]
        b = baked[name]
        f = int(fs) if int(fs) >= 0 else len(b.frames) - 1
        s = b.frames[f]
        col, row = i % cols, i // cols
        base = right * (col * dx) - up * (row * dy)
        arm = rig.build_rig(None)
        arm.name = f"rig_{i}"
        out_b = body.build_body(None, arm, body.body_params())
        A.apply_frame(arm, s)
        side = name in ("walk", "run", "crouch_walk", "sprint", "carry_bag_walk", "flee", "strafe_l", "strafe_r", "walk_back")
        yaw = -math.radians(58.0) if side else 0.0
        if len(parts) > 2:
            yaw = math.radians(float(parts[2]))
        arm.matrix_world = Matrix.Translation(tuple(base)) @ Matrix.Rotation(yaw, 4, "Z")
        bpy.context.view_layer.update()
        if name in GUN_CLIPS:
            src = weapons_src[GUN_CLIPS[name]]
            bpy.context.view_layer.update()
            W_gun = arm.matrix_world @ _weapon_matrix(sk, s)
            inv_src = src.matrix_world.inverted()
            for o in src.children_recursive:
                if o.type == "MESH":
                    c = o.copy()
                    scene.link(c)
                    c.parent = None
                    c.matrix_world = W_gun @ inv_src @ o.matrix_world
        dg = bpy.context.evaluated_depsgraph_get()
        ev = out_b["Body"].evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        zmin = min((mw @ v.co).z for v in me.vertices)
        ev.to_mesh_clear()
        lows.append((cell, zmin - base[2]))
        floor = bpy.data.meshes.new(f"floor_{i}")
        fx, fy = 0.75, 1.1
        floor.from_pydata([(-fx, -fy, 0), (fx, -fy, 0), (fx, fy, 0), (-fx, fy, 0)], [], [(0, 1, 2, 3)])
        floor.materials.append(floor_mat)
        fo = bpy.data.objects.new(f"floor_{i}", floor)
        fo.matrix_world = Matrix.Translation(tuple(base))
        scene.link(fo)
        lb = _label(f"{name} f{f}", tuple(base - up * 0.15 + np.array(cam_obj.matrix_world.col[2][:3]) * 2.0), 0.12)
        lb.rotation_euler = cam_obj.rotation_euler
    for w in weapons_src.values():
        for o in [w, *w.children_recursive]:
            bpy.data.objects.remove(o)
    _setup_render(1800, 1200)
    _frame_all(cam_obj)
    bpy.context.scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    for cell, z in lows:
        print(f"[review] {cell}: lowest body vertex z = {z * 1000:.1f} mm")


def _camera(view_from):
    """Orthographic camera looking along -view_from; returns (object, right, up) unit vectors."""
    c = np.array(view_from, dtype=float)
    c /= np.linalg.norm(c)
    fwd = -c
    right = np.cross(fwd, np.array([0.0, 0.0, 1.0]))
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("Cam", cam)
    scene.link(co)
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2] = float(right[i]), float(up[i]), float(-fwd[i])
        m[i][3] = float(c[i] * 30.0)
    co.matrix_world = m
    bpy.context.scene.camera = co
    return co, right, up


def _frame_all(cam_obj) -> None:
    """Fit the ortho camera to every mesh (project bounds on the camera axes)."""
    bpy.context.view_layer.update()
    inv = cam_obj.matrix_world.inverted()
    xs, ys = [], []
    for o in bpy.context.scene.objects:
        if o.type not in ("MESH", "FONT") or o.hide_render:
            continue
        for c in o.bound_box:
            p = inv @ (o.matrix_world @ __import__("mathutils").Vector(c))
            xs.append(p.x)
            ys.append(p.y)
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    print(f"[review] frame bounds w={w:.2f} h={h:.2f} x={min(xs):.2f}..{max(xs):.2f} y={min(ys):.2f}..{max(ys):.2f}")
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    cam_obj.matrix_world = cam_obj.matrix_world @ Matrix.Translation((cx, cy, 0.0))
    sc = bpy.context.scene
    aspect = sc.render.resolution_x / sc.render.resolution_y
    cam_obj.data.ortho_scale = max(w, h * aspect) * 1.04
    sc.render.resolution_y = int(sc.render.resolution_x * h / w)
    cam_obj.data.ortho_scale = w * 1.04


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kind, out = argv[0], pathlib.Path(argv[1]).resolve()
    if kind == "humanoid":
        humanoid(out, argv[2:] or DEFAULT_CELLS)
    elif kind == "arms":
        import _arms_review  # noqa: PLC0415

        _arms_review.render(out, argv[2:])
    else:
        raise SystemExit(f"unknown review kind {kind}")


if __name__ == "__main__":
    main()
