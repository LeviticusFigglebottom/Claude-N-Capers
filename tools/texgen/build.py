#!/usr/bin/env python3
"""Build the CAPERWORKS material library, trim sheet, LUTs and lighting environments.

usage: python3 tools/texgen/build.py [--only <lib_id>[,<lib_id>...]] [--preset gsr]
                                     [--check-determinism] [--jobs N] [--list]

Outputs (relative to the repo root, or --out-root):
  game/assets/textures/<lib_id>/tex_<lib_id>_{albedo,orm,normal}.png (+ .import, SOURCE.txt)
  game/world/materials/<lib_id>.tres
  game/assets/textures/trim_interior/trim_table.json
  game/assets/luts/lut_<name>.png (+ .import, SOURCE.txt)
  game/world/lighting/env_<name>.tres, sun_<name>.tscn
"""

from __future__ import annotations

import sys
from pathlib import Path

# Import the package as ``texgen.*`` from tools/ (never put tools/texgen itself on sys.path:
# texgen/io.py and texgen/noise.py would shadow other modules).
_TOOLS = Path(__file__).resolve().parent.parent
if sys.path and Path(sys.path[0]).resolve() == Path(__file__).resolve().parent:
    sys.path.pop(0)
sys.path.insert(0, str(_TOOLS))

import argparse  # noqa: E402
import importlib  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import time  # noqa: E402
import zlib  # noqa: E402
from concurrent.futures import ProcessPoolExecutor  # noqa: E402

from texgen import godot, io as tio, library, lut, presets, trim  # noqa: E402
from texgen.materials.base import Ctx, finalize  # noqa: E402

REPO = _TOOLS.parent
SCRIPT = "tools/texgen/build.py"


def asset_seed(lib_id: str) -> int:
    return zlib.crc32(lib_id.encode("utf-8"))


def make_ctx(lib_id: str, preset: dict, size: int | None = None) -> Ctx:
    entry = library.LIBRARY[lib_id]
    return Ctx(
        lib_id=lib_id,
        size=size or entry["size"],
        tile_m=library.tile_m(lib_id),
        seed=asset_seed(lib_id),
        params=preset["materials"][lib_id],
        rules=preset["rules"],
        scales=preset["scales"],
    )


def build_material(lib_id: str, preset_name: str, out_root: str, with_godot: bool) -> dict:
    preset = presets.load(preset_name)
    root = Path(out_root)
    entry = library.LIBRARY[lib_id]
    if entry.get("kind") == "emissive":
        if with_godot:
            godot.write_emissive_material(root / library.MAT_ROOT / f"{lib_id}.tres", lib_id,
                                          preset["materials"][lib_id])
        return {"lib_id": lib_id, "stats": None}
    ctx = make_ctx(lib_id, preset)
    extra: dict = {}
    if entry.get("trim"):
        maps, rows = trim.generate(ctx, lambda sid: make_ctx(sid, preset))
        tbl = trim.table(rows, ctx.size, ctx.tile_m)
        extra["table"] = tbl
    else:
        mod = importlib.import_module(f"texgen.materials.{lib_id}")
        maps = mod.generate(ctx)
    enc = finalize(ctx, maps)
    tex_dir = root / library.TEX_ROOT / lib_id
    files = {
        "albedo": tex_dir / f"tex_{lib_id}_albedo.png",
        "orm": tex_dir / f"tex_{lib_id}_orm.png",
        "normal": tex_dir / f"tex_{lib_id}_normal.png",
    }
    tio.write_png(files["albedo"], enc.albedo)
    tio.write_png(files["orm"], enc.orm)
    tio.write_png(files["normal"], enc.normal)
    if "table" in extra:
        tio.write_text(tex_dir / "trim_table.json", json.dumps(extra["table"], indent=2) + "\n")
    density = ctx.size / ctx.tile_m
    source = [
        f"generator: {SCRIPT} --only {lib_id} --preset {preset_name}",
        f"module: tools/texgen/{'trim.py' if entry.get('trim') else f'materials/{lib_id}.py'}",
        f"preset: tools/texgen/presets/{preset_name}.py",
        f"seed: {ctx.seed} (zlib.crc32('{lib_id}'))",
        f"size_px: {ctx.size}",
        f"tile_m: {ctx.tile_m} (1 UV unit = {ctx.tile_m} m)",
        f"texel_density_px_per_m: {density:g}",
        "albedo: sRGB; orm: linear R=AO G=roughness B=metallic; normal: tangent space OpenGL (Y+)",
        "stats: " + json.dumps(enc.stats, sort_keys=True),
        "",
    ]
    tio.write_text(tex_dir / "SOURCE.txt", "\n".join(source))
    if with_godot:
        for key, f in files.items():
            godot.ensure_import(f, "texture", "CompressedTexture2D", godot.IMPORT_PARAMS[key])
        godot.write_material(root / library.MAT_ROOT / f"{lib_id}.tres", lib_id,
                             f"res://assets/textures/{lib_id}", entry.get("kind", "opaque"), ctx.tile_m,
                             ctx.params.get("specular"))
    return {"lib_id": lib_id, "stats": enc.stats}


def build_luts_and_envs(preset_name: str, out_root: Path, with_godot: bool) -> None:
    preset = presets.load(preset_name)
    lut_dir = out_root / "game/assets/luts"
    for name, grade in preset["luts"].items():
        png = lut_dir / f"lut_{name}.png"
        tio.write_png(png, lut.build(grade))
        if with_godot:
            godot.ensure_import(png, "3d_texture", "CompressedTexture3D",
                                {**godot.LUT_IMPORT_PARAMS, "slices/horizontal": str(lut.LUT_SIZE),
                                 "slices/vertical": "1"})
    tio.write_text(lut_dir / "SOURCE.txt", "\n".join([
        f"generator: {SCRIPT} --preset {preset_name} (tools/texgen/lut.py)",
        f"grades: tools/texgen/presets/{preset_name}.py ['luts']",
        f"layout: {lut.LUT_SIZE} slices of {lut.LUT_SIZE}x{lut.LUT_SIZE}, horizontal; slice = blue, x = red, "
        "y(top=0) = green; texel i holds grade((i+0.5)/N); imported as CompressedTexture3D",
        "",
    ]))
    if with_godot:
        light_dir = out_root / "game/world/lighting"
        for name, env in preset["environments"].items():
            godot.write_environment(light_dir / f"env_{name}.tres", env, f"res://assets/luts/lut_{env['lut']}.png")
            godot.write_sun_scene(light_dir / f"sun_{name}.tscn", f"Sun{name.title().replace('_', '')}", env)


def list_outputs(out_root: Path, ids: list[str], include_luts: bool) -> list[Path]:
    paths: list[Path] = []
    for lib_id in ids:
        d = out_root / library.TEX_ROOT / lib_id
        if not d.exists():
            continue
        paths += sorted(d.glob("*.png")) + sorted(d.glob("*.json")) + sorted(d.glob("SOURCE.txt"))
    if include_luts:
        paths += sorted((out_root / "game/assets/luts").glob("*.png"))
    return paths


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", action="append", default=[], help="lib id(s), comma separated or repeated")
    ap.add_argument("--preset", default="gsr")
    ap.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument("--out-root", default=str(REPO), help="write outputs under this root (default: repo)")
    ap.add_argument("--no-godot", action="store_true", help="skip .tres/.import/.tscn output")
    ap.add_argument("--check-determinism", action="store_true",
                    help="after building, rebuild into a temp dir in a fresh process and compare sha256")
    ap.add_argument("--list", action="store_true", help="list library ids and exit")
    args = ap.parse_args()

    if args.list:
        for k, v in library.LIBRARY.items():
            if "size" not in v:
                print(f"{k:22s} {v.get('kind')}, no textures")
                continue
            print(f"{k:22s} {v['size']}px  tile {library.tile_m(k):g} m  {library.texel_density(k):g} px/m")
        return 0
    only = [x for chunk in args.only for x in chunk.split(",") if x]
    unknown = [x for x in only if x not in library.LIBRARY]
    if unknown:
        print(f"unknown lib id(s): {unknown}", file=sys.stderr)
        return 2
    ids = only or list(library.LIBRARY)
    out_root = Path(args.out_root).resolve()
    with_godot = not args.no_godot
    t0 = time.time()
    if args.jobs > 1 and len(ids) > 1:
        with ProcessPoolExecutor(max_workers=args.jobs) as ex:
            results = list(ex.map(build_material, ids, [args.preset] * len(ids), [str(out_root)] * len(ids),
                                  [with_godot] * len(ids)))
    else:
        results = [build_material(i, args.preset, str(out_root), with_godot) for i in ids]
    for r in results:
        s = r["stats"]
        if s is None:
            print(f"  {r['lib_id']:22s} (emissive, no textures)")
            continue
        print(f"  {r['lib_id']:22s} lum {s['albedo_lum_min_linear']:.3f}-{s['albedo_lum_max_linear']:.3f}"
              f" (mean {s['albedo_lum_mean_linear']:.3f})  rough {s['roughness_mean']:.2f}"
              f"  metal {s['metallic_mean']:.2f}  ao {s['ao_mean']:.2f}")
    include_luts = not only
    if include_luts:
        build_luts_and_envs(args.preset, out_root, with_godot)
    print(f"built {len(ids)} material(s){' + LUTs/environments' if include_luts else ''} in {time.time() - t0:.1f}s")

    if args.check_determinism:
        with tempfile.TemporaryDirectory(prefix="texgen_det_") as tmp:
            cmd = [sys.executable, str(Path(__file__).resolve()), "--preset", args.preset, "--out-root", tmp,
                   "--no-godot", "--jobs", str(args.jobs)]
            for i in only:
                cmd += ["--only", i]
            env = dict(os.environ, PYTHONHASHSEED="12345")
            subprocess.run(cmd, check=True, env=env, stdout=subprocess.DEVNULL)
            a = list_outputs(out_root, ids, include_luts)
            b = list_outputs(Path(tmp), ids, include_luts)
            bad = 0
            for pa in a:
                pb = Path(tmp) / pa.relative_to(out_root)
                ha = tio.sha256(pa)
                hb = tio.sha256(pb) if pb.exists() else "missing"
                if ha != hb:
                    bad += 1
                    print(f"  MISMATCH {pa.relative_to(out_root)}")
            print(f"determinism: {len(a) - bad}/{len(a)} files byte-identical (sha256) across two runs"
                  f" [{len(b)} in rerun]")
            if bad:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
