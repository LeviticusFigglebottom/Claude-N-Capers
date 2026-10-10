"""Asset-script framework (Blender only).

An asset script is a plain module in ``tools/blender/<folder>/`` with UPPER_CASE metadata (see
``lib/meta.py``) and a ``build(ctx)`` function::

    ASSET_ID = "prop_crate_small"
    TRI_BUDGET = 800

    def build(ctx: AssetContext) -> None:
        wood = ctx.material("wood_veneer", "#7A5A3A")
        ...

The runner (``tools/blender/run_asset.py`` -> ``run()``) resets the scene, calls ``build(ctx)``,
applies ``PIVOT``-independent checks (names, materials, triangle budget), exports
``<out_root>/<category>/<asset_id>/<asset_id>.glb`` and writes ``SOURCE.txt`` next to it.
"""

from __future__ import annotations

import importlib.util
import pathlib
import random
import sys
import zlib
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any

import bpy

from . import __version__, export, geo, materials, meta, naming, scene, source

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]


def seed_for(asset_id: str) -> int:
    """Stable per-asset seed (never Python's salted ``hash()``)."""
    return zlib.crc32(asset_id.encode("utf-8"))


@dataclass
class AssetContext:
    """Everything ``build(ctx)`` needs. Build only through this; never read the clock or OS."""

    asset_id: str
    params: dict[str, Any]
    out_dir: pathlib.Path
    script: pathlib.Path
    seed: int = 0
    rng: random.Random = field(default_factory=random.Random)
    export_options: dict[str, Any] = field(default_factory=dict)
    source_extra: dict[str, Any] = field(default_factory=dict)

    @property
    def category(self) -> str:
        return naming.category_for(self.asset_id)

    @property
    def glb_path(self) -> pathlib.Path:
        return self.out_dir / f"{self.asset_id}.glb"

    def param(self, key: str, default: Any = None) -> Any:
        return self.params.get(key, default)

    # -- convenience wrappers ---------------------------------------------------------------
    def material(self, library_id: str, color: Sequence[float] | str = (0.5, 0.5, 0.5),
                 roughness: float = 0.8, metallic: float = 0.0, alpha: float = 1.0) -> bpy.types.Material:
        return materials.material(library_id, color, roughness, metallic, alpha)

    def marker(self, name: str, location: Sequence[float] = (0, 0, 0),
               rotation_euler: Sequence[float] = (0, 0, 0),
               parent: bpy.types.Object | None = None) -> bpy.types.Object:
        """Named empty -> Godot Node3D with exactly ``name`` (e.g. ``Muzzle``, ``Handle``)."""
        return geo.empty(name, location, rotation_euler, parent)

    def builder(self) -> geo.MeshBuilder:
        return geo.MeshBuilder()

    def pivot(self, mode: str) -> None:
        """Move the whole asset to the contract pivot: ``floor``, ``wall``, ``ceiling``."""
        geo.align_pivot([o for o in scene.all_objects() if o.parent is None], mode)


def load_module(script: pathlib.Path):
    """Import an asset script by path (its folder is put on sys.path for shared ``_helpers``)."""
    folder = str(script.parent)
    if folder not in sys.path:
        sys.path.insert(0, folder)
    name = f"caper_asset_{script.parent.name}_{script.stem}"
    spec = importlib.util.spec_from_file_location(name, script)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {script}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def build_one(spec: meta.AssetSpec, module, out_root: pathlib.Path) -> pathlib.Path:
    """Reset, build, validate, export and write SOURCE.txt for one asset. Returns the .glb path."""
    scene.reset()
    seed = seed_for(spec.asset_id)
    out_dir = out_root / spec.category / spec.asset_id
    ctx = AssetContext(asset_id=spec.asset_id, params=dict(spec.params), out_dir=out_dir,
                       script=spec.script, seed=seed, rng=random.Random(seed),
                       export_options=dict(spec.export))
    module.build(ctx)
    for warning in export.validate(spec.tri_budget):
        print(f"[asset] WARN {spec.asset_id}: {warning}")
    glb_path = export.export_glb(ctx.glb_path, **ctx.export_options)
    try:
        script_rel = spec.script.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        script_rel = spec.script.name
    extra = dict(ctx.source_extra)
    if spec.tri_budget is not None:
        extra["tri_budget"] = spec.tri_budget
    text = source.render(spec.asset_id, script_rel, spec.params, seed,
                         ".".join(str(x) for x in bpy.app.version[:2]), __version__, extra)
    source.write(out_dir / "SOURCE.txt", text)
    return glb_path


def run(script: pathlib.Path, out_root: pathlib.Path, ids: Sequence[str] | None = None) -> int:
    """Build every asset of ``script`` (or only ``ids``). Returns a process exit code."""
    specs = meta.read_specs(script)
    if ids:
        wanted = set(ids)
        specs = [s for s in specs if s.asset_id in wanted]
        missing = wanted - {s.asset_id for s in specs}
        if missing:
            print(f"[asset] ERROR unknown asset ids for {script.name}: {sorted(missing)}")
            return 2
    module = load_module(script)
    if not hasattr(module, "build"):
        print(f"[asset] ERROR {script} has no build(ctx)")
        return 2
    for spec in specs:
        path = build_one(spec, module, out_root)
        print(f"[asset] OK {spec.asset_id} -> {path}")
    return 0
