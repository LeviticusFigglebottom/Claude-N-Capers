#!/usr/bin/env python3
"""Build Blender asset scripts into .glb files. Run with the system python3 (not inside Blender).

    python3 tools/blender/build.py --category greybox                   # build every asset
    python3 tools/blender/build.py --category weapons --asset wpn_kestrel_p9
    python3 tools/blender/build.py --category greybox --check-determinism
    python3 tools/blender/build.py --category greybox --list

``--category`` names the script folder ``tools/blender/<category>/``. Each asset lands in
``game/assets/<asset category>/<asset_id>/`` where the asset category comes from the asset-id
prefix (``arch_`` -> arch, ``prop_`` -> props, ``wpn_``/``mod_`` -> weapons; see lib/naming.py).
Next to each .glb, build.py writes or patches ``<asset_id>.glb.import`` so Godot runs the
material-library post-import script. See tools/blender/PIPELINE.md.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import functools
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))

from lib import glb, godot_import, meta  # noqa: E402

RUNNER = HERE / "run_asset.py"
DEFAULT_OUT = REPO / "game" / "assets"


def find_blender(explicit: str | None) -> str:
    cand = explicit or os.environ.get("BLENDER") or shutil.which("blender") or "/opt/blender/blender"
    if not cand or not pathlib.Path(cand).exists() and shutil.which(cand) is None:
        sys.exit("build.py: Blender not found; pass --blender or set $BLENDER (tools/setup/install_blender.sh)")
    return cand


def discover(category: str) -> list[meta.AssetSpec]:
    folder = HERE / category
    if not folder.is_dir():
        sys.exit(f"build.py: no script folder {folder.relative_to(REPO)}")
    specs: list[meta.AssetSpec] = []
    for script in sorted(folder.glob("*.py")):
        if script.name.startswith("_"):
            continue
        specs.extend(meta.read_specs(script))
    ids = [s.asset_id for s in specs]
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    if dupes:
        sys.exit(f"build.py: duplicate asset ids {dupes}")
    return specs


@functools.cache
def _no_aslr() -> tuple[str, ...]:
    """Run Blender with address-space randomisation off where possible (Linux ``setarch -R``).

    Some Blender operators (e.g. bevel UV interpolation) produce last-bit float differences that
    depend on heap addresses. Asset scripts avoid those paths (see PIPELINE rules); this is the
    second line of defence."""
    setarch = shutil.which("setarch")
    if setarch is None or sys.platform != "linux":
        return ()
    probe = subprocess.run([setarch, os.uname().machine, "-R", "true"], capture_output=True, check=False)
    return (setarch, os.uname().machine, "-R") if probe.returncode == 0 else ()


def run_blender(blender: str, script: pathlib.Path, out_root: pathlib.Path, ids: list[str],
                verbose: bool) -> tuple[pathlib.Path, int, str]:
    # --threads 1: multithreaded tangent calculation adds ~1e-7 float noise that flips the glTF
    # exporter's 4-decimal rounding of normals/tangents in ~1 of 4 builds (ENV D root cause).
    cmd = [*_no_aslr(), blender, "--threads", "1", "-b", "--factory-startup", "--python-exit-code", "1",
           "--python", str(RUNNER), "--", str(script), str(out_root), *ids]
    env = dict(os.environ, PYTHONHASHSEED="0", TZ="UTC", LC_ALL="C")
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env, check=False)
    log = proc.stdout + proc.stderr
    if verbose or proc.returncode != 0:
        print(log)
    return script, proc.returncode, log


def build(specs: list[meta.AssetSpec], out_root: pathlib.Path, blender: str, jobs: int, verbose: bool) -> bool:
    by_script: dict[pathlib.Path, list[str]] = {}
    for s in specs:
        by_script.setdefault(s.script, []).append(s.asset_id)
    ok = True
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
        futures = [pool.submit(run_blender, blender, script, out_root, ids, verbose)
                   for script, ids in sorted(by_script.items())]
        for fut in futures:
            script, code, log = fut.result()
            built = sum(1 for line in log.splitlines() if line.startswith("[asset] OK"))
            status = "ok" if code == 0 else f"FAILED (exit {code})"
            print(f"  {script.relative_to(REPO)}: {built} asset(s) {status}")
            ok = ok and code == 0
    return ok


def outputs(spec: meta.AssetSpec, out_root: pathlib.Path) -> list[pathlib.Path]:
    d = out_root / spec.category / spec.asset_id
    return [d / f"{spec.asset_id}.glb", d / "SOURCE.txt"]


def check_determinism(specs: list[meta.AssetSpec], blender: str, jobs: int, verbose: bool) -> bool:
    with tempfile.TemporaryDirectory(prefix="caper_det_") as tmp:
        roots = [pathlib.Path(tmp) / "run1", pathlib.Path(tmp) / "run2"]
        for i, root in enumerate(roots, 1):
            print(f"determinism: build {i}/2")
            if not build(specs, root, blender, jobs, verbose):
                return False
        bad = 0
        for spec in specs:
            for a, b in zip(outputs(spec, roots[0]), outputs(spec, roots[1])):
                ha, hb = glb.sha256(a), glb.sha256(b)
                rel = a.relative_to(roots[0]).as_posix()
                committed = DEFAULT_OUT / rel
                note = ""
                if committed.exists() and glb.sha256(committed) != ha:
                    note = "  (differs from committed game/assets copy: rebuild)"
                if ha == hb:
                    print(f"{ha}  {rel}{note}")
                else:
                    bad += 1
                    print(f"MISMATCH {rel}\n  run1 {ha}\n  run2 {hb}")
        total = 2 * len(specs)
        print(f"determinism: {total - bad}/{total} files identical across two clean builds")
        return bad == 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--category", required=True, help="script folder under tools/blender/")
    ap.add_argument("--asset", action="append", default=[], help="asset id to build (repeatable)")
    ap.add_argument("--check-determinism", action="store_true", help="build twice in temp dirs, compare sha256")
    ap.add_argument("--list", action="store_true", help="list asset ids and exit")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="output root (default game/assets)")
    ap.add_argument("--blender", default=None, help="Blender executable (default $BLENDER or PATH)")
    ap.add_argument("-j", "--jobs", type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    specs = discover(args.category)
    if args.asset:
        known = {s.asset_id for s in specs}
        unknown = sorted(set(args.asset) - known)
        if unknown:
            sys.exit(f"build.py: unknown asset ids {unknown}")
        specs = [s for s in specs if s.asset_id in set(args.asset)]
    if args.list:
        for s in specs:
            print(f"{s.asset_id}\t{s.script.relative_to(REPO)}\t{s.params}")
        return 0
    if not specs:
        print(f"build.py: no asset scripts in tools/blender/{args.category}/")
        return 0
    blender = find_blender(args.blender)
    if args.check_determinism:
        return 0 if check_determinism(specs, blender, args.jobs, args.verbose) else 1

    out_root = pathlib.Path(args.out).resolve()
    print(f"building {len(specs)} asset(s) from tools/blender/{args.category}/ -> {out_root}")
    if not build(specs, out_root, blender, args.jobs, args.verbose):
        return 1
    changed = 0
    for spec in specs:
        glb_path = outputs(spec, out_root)[0]
        if not glb_path.exists():
            print(f"missing output {glb_path}")
            return 1
        changed += godot_import.ensure(glb_path)
    print(f"done: {len(specs)} asset(s); {changed} .glb.import file(s) written/updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
