"""Review renders for D1-03 animations (contact sheets). Not an asset script; run directly:

    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- humanoid OUT.png [clip:frame ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- arms OUT.png
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- specials OUT.png [clip:frame[:yaw] ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- npc OUT.png [clip:frame[:yaw] ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- rappel OUT.png [clip:frame[:yaw] ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- p5 OUT.png [clip:frame[:yaw] ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- d304 OUT.png [clip:frame[:yaw] ...]
    blender -b --factory-startup --python tools/blender/characters/_anim_review.py -- assault OUT.png [clip:frame[:yaw] ...]

``humanoid``: one posed ``char_body_base`` body per cell (Cycles CPU, low samples; EEVEE needs EGL),
3/4 front view with a side-view row for locomotion, the weapon models attached through the HandR
grip convention (``specials``: the Bulwark shield as a plate proxy on the HandL socket frame), a floor at
z = 0, labels (``npc``: review-only proxies of the hand props from ``_anim_humanoid.GRIPS`` (phone, mug, mop,
book) read off the solved hand, plus the chair/desk of the seated clips and the bed of sit_bed_read). Also prints the lowest skinned-mesh vertex per cell
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
GUN_CLIPS = {"dozer_walk_heavy": "rifle", "aim_pistol": "pistol", "fire_pistol": "pistol", "reload_pistol": "pistol", "downed": "pistol",
             "aim_rifle": "rifle", "fire_rifle": "rifle", "reload_rifle": "rifle", "melee": "rifle",
             "shield_idle": "pistol", "shield_walk": "pistol", "shield_bang": "pistol", "heal_ally": "rifle",
             "dozer_walk": "rifle", "idle_thug": "rifle", "heli_door_idle": "rifle", "heli_door_aim": "rifle",
             "heli_door_fire": "rifle"}
#: Clips that also show the Bulwark shield proxy (a plate on the HandL/Socket frame, _anim_humanoid.SHIELD).
SHIELD_CLIPS = ("shield_idle", "shield_walk", "shield_bang")
SPECIAL_CELLS = ["kick_charge:0", "kick_charge:4", "kick_charge:10", "kick_charge:15", "kick_hit:3", "kick_hit:6",
                 "kick_hit:6:0", "kick_hit:12", "kick_hit:21", "heal_ally:7:90", "heal_ally:12:90", "heal_ally:12:30",
                 "shield_walk:0:-58", "shield_walk:14:-58", "shield_walk:0:-90", "shield_walk:0:150",
                 "shield_bang:3:-50", "shield_bang:6:-50", "shield_bang:6:150", "heal_ally:22:90",
                 "dozer_walk:0", "dozer_walk:8", "dozer_walk:16", "dozer_walk:8:0"]

NPC_CELLS = ["desk_work:0", "desk_work:165", "desk_work:280", "desk_work:280:70", "phone_seated:30", "phone_seated:170",
             "sit_chair_watch:30", "sit_chair_watch:100", "sit_chair_watch:220", "phone_call:0", "phone_call:0:110",
             "phone_seated:30:110", "mug_idle:0", "mug_idle:120", "mug_idle:120:80", "mug_carry_walk:0", "mug_carry_walk:9",
             "mop:0", "mop:15", "mop:45", "sit_bed_read:0", "sit_bed_read:0:-80", "sit_bed_read:208", "sit_bed_read:221",
             "idle_thug:0", "idle_thug:0:80", "idle_thug:30", "idle_thug:70"]
#: Police rappel (QC-41): a rope proxy on the documented rope line and a wall slab at RAPPEL_WALL (review only).
RAPPEL_CELLS = ["rappel:0:-90", "rappel:2:-90", "rappel:4:-90", "rappel:10:-90", "rappel:18:-90", "rappel:26:-90",
                "rappel:0:180", "rappel:4:180", "rappel:10:200", "rappel:18:160", "rappel:0:-130", "rappel:10:-60"]
#: P5 NPC set (D3-02): bar / counter / painting wall / chair / wall proxies at the documented placement (review only).
P5_CELLS = ["dance_a:0", "dance_a:15", "dance_a:26", "dance_a:45", "dance_b:7", "dance_b:15", "dance_b:97",
            "dance_b:105", "dance_c:0", "dance_c:8", "dance_c:30:60", "bartender_wipe:0", "bartender_wipe:20:70",
            "bartender_wipe:115", "bartender_pour:0:40", "bartender_pour:24:40", "bartender_pour:55:40",
            "bartender_pour:55:-60", "bouncer_idle:0", "bouncer_idle:60:40", "bouncer_idle:222", "teller_count:30:40",
            "teller_count:144:40", "teller_count:177:70", "curator_inspect:30:70", "curator_inspect:85:70",
            "curator_inspect:150:70", "curator_inspect:180:20", "walk_text:0", "walk_text:12:30", "cower_seated:0",
            "cower_seated:0:70", "cower_stand:0", "cower_stand:42:60", "cower_stand:42"]
#: D3-04 polish: 8-way walk / run, start / stop, directional hit reacts, death variety, downed crawl, heavy Wrecker gait.
D304_CELLS = ["walk_l:0:-58", "walk_l:8:-58", "walk_r:0:-58", "walk_r:8:-58", "walk_fr:8:-58", "walk_bl:8:-58",
              "walk_b:8:-58", "walk_br:22:-58",
              "run_l:0:-58", "run_l:5:-58", "run_r:5:-58", "run_fr:5:-58", "run_bl:5:-58", "run_b:5:-58",
              "walk_start:0:-58", "walk_start:8:-58",
              "walk_start:12:-58", "walk_start:18:-58", "walk_stop:5:-58", "walk_stop:10:-58", "walk_stop:18:-58",
              "run_start:6:-58", "run_start:11:-58", "run_start:18:-58",
              "run_stop:3:-58", "run_stop:8:-58", "run_stop:13:-58", "run_stop:20:-58", "hit_react_back:3:-58",
              "hit_react_left:3", "hit_react_left:7", "hit_react_right:3",
              "death_front_b:10:-58", "death_front_b:16:-58", "death_front_b:28:-58", "death_front_b:60:-58",
              "death_back_b:12:-58", "death_back_b:31:-58", "death_back_b:44:-58", "death_back_b:60:-58",
              "death_side:4", "death_side:12", "death_side:21", "death_side:36", "death_side:60:90",
              "downed_crawl:0:-58", "downed_crawl:15:-58", "downed_crawl:30:-58",
              "dozer_walk_heavy:0:-58", "dozer_walk_heavy:8:-58", "dozer_walk_heavy:16:-58", "dozer_walk_heavy:8"]
#: PO6-17 assault events: rope line, heli cabin (floor, bench, roof, door edge), van step and breach wall proxies at
#: the placement documented in SOURCE.txt (_anim_assault constants; review only).
ASSAULT_CELLS = ["rappel_hang:0", "rappel_hang:20:-90", "rappel_descend:0", "rappel_descend:10:-90",
                 "rappel_land:0:-90", "rappel_land:6:-90", "rappel_land:11:-90", "rappel_land:30",
                 "heli_door_idle:0:-50", "heli_door_aim:0:-50", "heli_door_aim:0:-90", "heli_door_fire:1:-50",
                 "van_exit:0:-90", "van_exit:13:-90", "van_exit:16:-90", "van_exit:24:-90", "van_exit:36:-90",
                 "breach_place:0:-90", "breach_place:16:-90", "breach_place:28:-90", "breach_place:28:-150",
                 "breach_standback:10:-150", "breach_standback:21:-150", "breach_standback:30:-150",
                 "breach_standback:21:-90"]
#: Clips that show hand-prop proxies (review only), and their furniture.
PROP_CLIPS = {"phone_call": "phone", "phone_seated": "phone", "mug_idle": "mug", "mug_carry_walk": "mug", "mop": "mop",
              "sit_bed_read": "book", "walk_text": "phone", "bartender_wipe": "rag", "bartender_pour": ("bottle", "glass"),
              "teller_count": "cash", "smoke": "cigarette"}
DESK_CLIPS = ("desk_work", "phone_seated", "sit_chair_watch", "desk_type", "death_seated_slump", "death_seated_fall")
CHAIR_CLIPS = DESK_CLIPS + ("sit_chair", "cower_seated")
P5_FURNITURE = ("bartender_wipe", "bartender_pour", "teller_count", "curator_inspect", "cower_stand")

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


def _weapon_matrix(sk, s, sfx: str = "R") -> Matrix:
    """The HandR/HandL socket frame (grip convention) as a Blender matrix."""
    R_off, t_off = A.grip_offset(sk, sfx)
    Ah = s.W[f"hand.{sfx}"] @ sk.B[f"hand.{sfx}"]
    Rw = Ah @ R_off
    pw = s.P[f"hand.{sfx}"] + Ah @ t_off
    m = Matrix.Identity(4)
    for i in range(3):
        for j in range(3):
            m[i][j] = float(Rw[i, j])
        m[i][3] = float(pw[i])
    return m


def _shield_proxy(m_socket: Matrix, mat) -> None:
    """Review-only Bulwark shield (_anim_humanoid.SHIELD, the char_bulwark_shield proportions): a centre
    panel and two wings angled back, in front of the grip (shield space X right, Y face normal, Z up),
    plus the vertical grip bar in the fist."""
    import _anim_humanoid as lib  # noqa: PLC0415

    d = lib.SHIELD
    face, cz, w, ww = d["face"], d["up"], d["w"], d["wing"]
    boxes = [("panel", Matrix.Translation((0.0, face, cz)), (w, d["t"], d["h"])),
             ("grip", Matrix.Identity(4), (0.03, 0.03, 0.13)),
             ("bracket", Matrix.Translation((0.0, face / 2.0, 0.0)), (0.025, face, 0.15))]
    for sx in (-1.0, 1.0):
        hinge = Matrix.Translation((sx * w / 2.0, face, cz)) @ Matrix.Rotation(math.radians(sx * d["wing_deg"]), 4, "Z")
        boxes.append((f"wing{int(sx)}", hinge @ Matrix.Translation((sx * ww / 2.0, 0.0, 0.0)), (ww, d["t"], d["h"])))
    for nm, local, (sx_, sy_, sz_) in boxes:
        me = bpy.data.meshes.new(f"shield_{nm}")
        vs = [((i - 0.5) * sx_, (j - 0.5) * sy_, (kk - 0.5) * sz_) for i in (0, 1) for j in (0, 1) for kk in (0, 1)]
        me.from_pydata(vs, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
        me.materials.append(mat)
        ob = bpy.data.objects.new(f"shield_{nm}", me)
        ob.matrix_world = m_socket @ local
        scene.link(ob)


def _box(name: str, M: Matrix, size, mat, centre=(0.0, 0.0, 0.0)) -> None:
    sx_, sy_, sz_ = size
    cx, cy, cz = centre
    me = bpy.data.meshes.new(name)
    vs = [(cx + (i - 0.5) * sx_, cy + (j - 0.5) * sy_, cz + (kk - 0.5) * sz_) for i in (0, 1) for j in (0, 1) for kk in (0, 1)]
    me.from_pydata(vs, [], [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = M
    scene.link(ob)


def _cyl(name: str, M: Matrix, r: float, z0: float, z1: float, mat, seg: int = 16) -> None:
    me = bpy.data.meshes.new(name)
    vs = [(r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z) for z in (z0, z1) for i in range(seg)]
    faces = [(i, (i + 1) % seg, seg + (i + 1) % seg, seg + i) for i in range(seg)]
    faces += [tuple(range(seg))[::-1], tuple(range(seg, 2 * seg))]
    me.from_pydata(vs, [], faces)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.matrix_world = M
    scene.link(ob)


def _npc_props(name: str, sk, s, base_m: Matrix, i: int, mats: dict) -> None:
    """Review-only proxies: the clip's hand prop at its GRIPS frame and its furniture."""
    import _anim_humanoid as lib  # noqa: PLC0415

    props = PROP_CLIPS.get(name, ())
    for prop in (props,) if isinstance(props, str) else props:
        R, o = lib.prop_frame(sk, s, prop)
        m = Matrix.Identity(4)
        for a in range(3):
            for b in range(3):
                m[a][b] = float(R[a, b])
            m[a][3] = float(o[a])
        M = base_m @ m
        if prop == "phone":
            _box(f"phone_{i}", M, lib.PROPS["phone"], mats["prop"])
        elif prop == "book":
            w, t, h = lib.PROPS["book"]
            _box(f"book_{i}", M, (w, t * 0.6, h), mats["book"], (0.0, t * 0.2, 0.0))
            _box(f"pages_{i}", M, (w * 0.96, t * 0.4, h * 0.96), mats["paper"], (0.0, -t * 0.25, 0.0))
        elif prop == "mug":
            _cyl(f"mug_{i}", M, 0.041, 0.0, 0.095, mats["mug"])
            _box(f"mughandle_{i}", M, (0.03, 0.012, 0.06), mats["mug"], (-0.055, 0.0, 0.05))
        elif prop == "mop":
            _cyl(f"shaft_{i}", M, 0.013, 0.05, lib.MOP_LENGTH, mats["prop"], 10)
            _cyl(f"mophead_{i}", M, 0.13, 0.0, 0.07, mats["paper"], 14)
        elif prop == "rag":
            _box(f"rag_{i}", M, lib.PROPS["rag"], mats["paper"], (0.0, 0.0, lib.PROPS["rag"][2] / 2))
        elif prop == "bottle":
            _cyl(f"bottle_{i}", M, 0.04, 0.0, 0.20, mats["mug"])
            _cyl(f"neck_{i}", M, 0.014, 0.20, 0.30, mats["mug"], 10)
        elif prop == "glass":
            _cyl(f"glass_{i}", M, 0.04, 0.0, 0.10, mats["paper"])
        elif prop == "cash":
            _box(f"cash_{i}", M, lib.PROPS["cash"], mats["cash"])
        elif prop == "cigarette":
            _cyl(f"cig_{i}", M, lib.CIG_R, 0.0, lib.CIG_LEN, mats["paper"], 8)
    if name in P5_FURNITURE:
        _p5_furniture(name, base_m, i, mats)
    if name in CHAIR_CLIPS:
        _box(f"seat_{i}", base_m, (0.46, 0.46, 0.05), mats["furn"], (0.0, -0.06, lib.SEAT_H - 0.025))
        _box(f"back_{i}", base_m, (0.44, 0.05, 0.45), mats["furn"], (0.0, -0.33, lib.SEAT_H + 0.30))
    if name in DESK_CLIPS:
        _box(f"desk_{i}", base_m, (1.2, 0.55, 0.03), mats["furn"], (0.0, 0.50, lib.DESK_Z - 0.015))
    if name == "sit_bed_read":
        _box(f"mattress_{i}", base_m, (1.0, 2.0, 0.22), mats["paper"], (0.0, 0.45, -0.112))
        wedge = base_m @ Matrix.Translation((0.0, -0.36, 0.0)) @ Matrix.Rotation(math.radians(lib.BED_RECLINE), 4, "X")
        _box(f"pillow_{i}", wedge, (0.7, 0.16, 0.62), mats["furn"], (0.0, -0.08, 0.31))


def _p5_furniture(name: str, base_m: Matrix, i: int, mats: dict) -> None:
    """Review-only P5 furniture at the placement documented in SOURCE.txt (_anim_p5 constants)."""
    import _anim_p5 as p5  # noqa: PLC0415

    if name.startswith("bartender_"):
        d = 0.55
        _box(f"bar_{i}", base_m, (1.4, d, 0.05), mats["furn"], (0.0, p5.BAR_EDGE + d / 2, p5.BAR_Z - 0.025))
        _box(f"barfront_{i}", base_m, (1.4, 0.05, p5.BAR_Z - 0.05), mats["furn"],
             (0.0, p5.BAR_EDGE + 0.12, (p5.BAR_Z - 0.05) / 2))
    elif name == "teller_count":
        d = 0.5
        _box(f"counter_{i}", base_m, (1.4, d, 0.04), mats["furn"], (0.0, p5.COUNTER_EDGE + d / 2, p5.COUNTER_Z - 0.02))
        _box(f"counterfront_{i}", base_m, (1.4, 0.05, p5.COUNTER_Z - 0.04), mats["furn"],
             (0.0, p5.COUNTER_EDGE + 0.12, (p5.COUNTER_Z - 0.04) / 2))
        _box(f"pile_{i}", base_m, (0.156, 0.066, 0.006), mats["cash"], (p5.TELLER_PILE[0], p5.TELLER_PILE[1], p5.COUNTER_Z + 0.003))
    elif name == "curator_inspect":
        _box(f"wall_{i}", base_m, (1.4, 0.05, 2.4), mats["paper"], (0.0, p5.PAINT_WALL + 0.025, 1.2))
        _box(f"frame_{i}", base_m, (0.80, 0.04, 0.62), mats["furn"], (0.0, p5.PAINT_WALL - 0.02, p5.PAINT_Z))
        _box(f"canvas_{i}", base_m, (0.68, 0.01, 0.50), mats["mug"], (0.0, p5.PAINT_WALL - 0.045, p5.PAINT_Z))
    elif name == "cower_stand":
        _box(f"wall_{i}", base_m, (1.4, 0.05, 2.2), mats["paper"], (0.0, -p5.COWER_WALL - 0.025, 1.1))


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
    env0 = __import__("os").environ
    dx, dy = float(env0.get("REVIEW_DX", "2.0")), float(env0.get("REVIEW_DY", "2.35"))
    floor_mat = _mat("floor", (0.30, 0.30, 0.32), 0.9)
    shield_mat = _mat("shield", (0.10, 0.12, 0.16), 0.4)
    npc_mats = {"prop": _mat("prop", (0.08, 0.08, 0.09), 0.4), "book": _mat("book", (0.35, 0.08, 0.06), 0.6),
                "paper": _mat("paper", (0.85, 0.83, 0.78), 0.8), "mug": _mat("mug", (0.15, 0.35, 0.60), 0.3),
                "furn": _mat("furn", (0.42, 0.30, 0.20), 0.7), "cash": _mat("cash", (0.32, 0.45, 0.30), 0.7)}
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
        side = name in ("walk", "run", "crouch_walk", "sprint", "carry_bag_walk", "flee", "strafe_l", "strafe_r", "walk_back",
                        "dozer_walk", "kick_charge", "kick_hit", "heal_ally", "mug_carry_walk", "walk_text")
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
        if name in SHIELD_CLIPS:
            _shield_proxy(arm.matrix_world @ _weapon_matrix(sk, s, "L"), shield_mat)
        if name == "rappel":
            _rappel_props(arm.matrix_world.copy(), npc_mats)
        if name in ASSAULT_PROPS:
            _assault_props(name, f, arm.matrix_world.copy(), npc_mats)
        if name in PROP_CLIPS or name in CHAIR_CLIPS or name in P5_FURNITURE:
            _npc_props(name, sk, s, arm.matrix_world.copy(), i, npc_mats)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = out_b["Body"].evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        zmin = min((mw @ v.co).z for v in me.vertices)
        ev.to_mesh_clear()
        lows.append((cell, zmin - base[2]))
        floor = bpy.data.meshes.new(f"floor_{i}")
        fx, fy = (float(x) for x in env0.get("REVIEW_FLOOR", "0.75,1.1").split(","))
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
    env = __import__("os").environ
    _setup_render(int(env.get("REVIEW_RES", "1800")), 1200, int(env.get("REVIEW_SAMPLES", "24")))
    _frame_all(cam_obj)
    bpy.context.scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    for cell, z in lows:
        print(f"[review] {cell}: lowest body vertex z = {z * 1000:.1f} mm")


def _rappel_props(M: Matrix, mats: dict) -> None:
    """The rope (vertical line x 0 at RAPPEL_ROPE_D) and the wall face at RAPPEL_WALL, in the cell's frame."""
    import _anim_humanoid as lib  # noqa: PLC0415

    _cyl("rope", M @ Matrix.Translation((0.0, lib.RAPPEL_ROPE_D, 0.0)), 0.006, -0.3, 2.6, mats["prop"], 10)
    _box("wall", M, (0.9, 0.05, 2.6), mats["paper"], (0.0, lib.RAPPEL_WALL + 0.025, 1.0))


ASSAULT_PROPS = ("rappel_hang", "rappel_descend", "rappel_land", "heli_door_idle", "heli_door_aim", "heli_door_fire",
                 "van_exit", "breach_place", "breach_standback")


def _assault_props(name: str, f: int, M: Matrix, mats: dict) -> None:
    """PO6-17 review proxies in the cell's frame (Blender clip space: x right, y forward, z up)."""
    import _anim_assault as S  # noqa: PLC0415
    from anim_humanoid import CLIPS  # noqa: PLC0415

    if name.startswith("rappel"):
        top = 2.6 if name != "rappel_land" else 2.2
        _cyl("rope", M @ Matrix.Translation((0.0, S.ROPE_Y, 0.0)), 0.007, 0.0 if name == "rappel_land" else -0.2, top,
             mats["mug"], 10)
    elif name.startswith("heli_door"):
        rx, _ry, rz = S.HELI_ROOT_IN_SNIPER_SEAT
        # cabin floor up to the door edge, the rear bench (SniperSeat on its top), the roof liner over the cabin
        _box("hfloor", M, (1.6, 1.6, 0.04), mats["furn"], (0.0, S.HELI_SILL_AHEAD - 0.8, -0.02))
        _box("bench", M, (0.44, 1.44, -S.HELI_ROOT_IN_SNIPER_SEAT[1]), mats["prop"],
             (-rx - 0.05, -(0.53 - rz), -S.HELI_ROOT_IN_SNIPER_SEAT[1] / 2))
        _box("roof", M, (1.6, 1.6, 0.03), mats["paper"], (0.0, S.HELI_SILL_AHEAD - 0.8, S.HELI_HEADROOM + 0.015))
    elif name == "van_exit":
        N = int(CLIPS[name]["frames"])
        edge = -S.VAN_STEP_EDGE + S.VAN_STEP_BACK - S.root_s(name, float(f), N)
        _box("step", M, (1.4, 0.8, S.VAN_STEP_Z), mats["furn"], (0.0, edge - 0.4, S.VAN_STEP_Z / 2))
        _box("doortop", M, (1.4, 0.8, 0.05), mats["prop"], (0.0, edge - 0.4, S.VAN_STEP_Z + 1.30))
    elif name.startswith("breach"):
        N = int(CLIPS[name]["frames"])
        dx = S.root_s(name, float(f), N) if name == "breach_standback" else 0.0   # the charge stays at the start root
        _box("wall", M, (1.4, 0.05, 2.0), mats["paper"], (dx, S.BREACH_WALL + 0.025, 1.0))
        cx, cy, cz = S.BREACH_CHARGE
        if name == "breach_standback" or f >= int(CLIPS["breach_place"]["events"]["place"]):
            _box("charge", M, (0.16, S.BREACH_WALL - cy, 0.12), mats["cash"], (cx + dx, (S.BREACH_WALL + cy) / 2, cz))


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
    elif kind == "specials":
        humanoid(out, argv[2:] or SPECIAL_CELLS)
    elif kind == "npc":
        humanoid(out, argv[2:] or NPC_CELLS)
    elif kind == "rappel":
        humanoid(out, argv[2:] or RAPPEL_CELLS)
    elif kind == "p5":
        humanoid(out, argv[2:] or P5_CELLS)
    elif kind == "d304":
        humanoid(out, argv[2:] or D304_CELLS)
    elif kind == "assault":
        humanoid(out, argv[2:] or ASSAULT_CELLS)
    elif kind == "arms":
        import _arms_review  # noqa: PLC0415

        _arms_review.render(out, argv[2:])
    else:
        raise SystemExit(f"unknown review kind {kind}")


if __name__ == "__main__":
    main()
