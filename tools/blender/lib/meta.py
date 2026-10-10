"""Read asset-script metadata without Blender. Pure Python.

An asset script (``tools/blender/<folder>/<name>.py``) declares its metadata as UPPER_CASE top-level
assignments that use only plain Python (no ``bpy``, no imports, no helper functions)::

    ASSET_ID = "wpn_kestrel_p9"          # single asset, or ...
    VARIANTS = {                         # ... several assets from one script
        f"arch_wall_int_w{w}_h{h}": {"width": w / 100, "height": h / 100}
        for w in (50, 100, 200, 400) for h in (300, 350, 400)
    }
    TRI_BUDGET = 500                     # optional: fail the build above this many LOD0 triangles
    EXPORT = {"animations": False}       # optional: extra export_glb() keyword arguments

Only those UPPER_CASE assignments are evaluated (in file order, with a small set of safe builtins),
so ``build.py`` can list assets with the system python and Blender is only started to build them.
Files without ``ASSET_ID`` or ``VARIANTS`` (helpers, material generators) are not asset scripts.
"""

from __future__ import annotations

import ast
import pathlib
from dataclasses import dataclass, field
from typing import Any

from . import naming

_SAFE_BUILTINS: dict[str, Any] = {
    name: __builtins__[name] if isinstance(__builtins__, dict) else getattr(__builtins__, name)
    for name in (
        "abs", "bool", "dict", "enumerate", "float", "int", "len", "list", "max", "min", "range",
        "round", "sorted", "str", "sum", "tuple", "zip", "True", "False", "None",
    )
}


@dataclass(frozen=True)
class AssetSpec:
    """One buildable asset."""

    asset_id: str
    script: pathlib.Path
    params: dict[str, Any] = field(default_factory=dict)
    tri_budget: int | None = None
    export: dict[str, Any] = field(default_factory=dict)

    @property
    def category(self) -> str:
        return naming.category_for(self.asset_id)


def _is_upper_assign(node: ast.stmt) -> bool:
    targets: list[ast.expr] = []
    if isinstance(node, ast.Assign):
        targets = node.targets
    elif isinstance(node, ast.AnnAssign) and node.value is not None:
        targets = [node.target]
    return bool(targets) and all(isinstance(t, ast.Name) and t.id.isupper() for t in targets)


def read_constants(script: pathlib.Path) -> dict[str, Any]:
    """Evaluate the UPPER_CASE top-level assignments of ``script``."""
    tree = ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
    body = [n for n in tree.body if _is_upper_assign(n)]
    module = ast.Module(body=body, type_ignores=[])
    namespace: dict[str, Any] = {"__builtins__": _SAFE_BUILTINS}
    exec(compile(module, str(script), "exec"), namespace)  # noqa: S102 - our own checked-in scripts
    return {k: v for k, v in namespace.items() if k.isupper()}


def is_asset_script(script: pathlib.Path) -> bool:
    """True if ``script`` assigns ``ASSET_ID`` or ``VARIANTS`` at top level (checked without running it)."""
    tree = ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
    for node in tree.body:
        if _is_upper_assign(node):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            if any(isinstance(t, ast.Name) and t.id in ("ASSET_ID", "VARIANTS") for t in targets):
                return True
    return False


def read_specs(script: pathlib.Path) -> list[AssetSpec]:
    """All assets declared by ``script`` (empty list if it is not an asset script), sorted by id."""
    if not is_asset_script(script):
        return []
    consts = read_constants(script)
    budget = consts.get("TRI_BUDGET")
    export = dict(consts.get("EXPORT", {}))
    specs: list[AssetSpec] = []
    if "VARIANTS" in consts:
        for asset_id, params in sorted(consts["VARIANTS"].items()):
            specs.append(AssetSpec(naming.check_asset_id(asset_id), script, dict(params), budget, export))
    elif "ASSET_ID" in consts:
        params = dict(consts.get("PARAMS", {}))
        specs.append(AssetSpec(naming.check_asset_id(consts["ASSET_ID"]), script, params, budget, export))
    return specs
