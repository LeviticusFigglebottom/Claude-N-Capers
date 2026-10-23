"""Asset, material and node naming rules (style guide §6). Pure Python.

* Asset ids: ``<category>_<name>[_<variant>]``, lowercase snake_case, e.g. ``arch_wall_int_w200_h300``,
  ``prop_desk_office_a``, ``wpn_kestrel_p9``, ``mod_suppressor_short``.
* Material slots: ``M_<library_id>`` where ``library_id`` is lowercase snake_case and names
  ``game/world/materials/<library_id>.tres``.
* Node names that gameplay looks up (``Muzzle``, ``Leaf``, ``Frame``...) are PascalCase and must be
  unique inside one asset.
"""

from __future__ import annotations

import re

# Asset-id prefixes and the game/assets/<category>/ folder each one lives in.
PREFIX_CATEGORY: dict[str, str] = {
    "arch": "arch",
    "prop": "props",
    "char": "characters",
    "wpn": "weapons",
    "mod": "weapons",
    "fx": "fx",
    "veh": "props",
    "mask": "masks",
    "eqp": "equipment",  # D-157: ENV D's equipment (tools/blender/equipment, the crew sentry eqp_sentry)
}

MATERIAL_PREFIX = "M_"
COLLISION_SUFFIXES = ("-colonly", "-convcolonly", "-col", "-convcol")

_SNAKE = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
_PASCAL = re.compile(r"^[A-Z][A-Za-z0-9]*$")


class NamingError(ValueError):
    """Raised when a name breaks the conventions."""


def is_snake(name: str) -> bool:
    return bool(_SNAKE.match(name))


def check_asset_id(asset_id: str) -> str:
    """Validate ``<category>_<name>[_<variant>]``. Returns the asset id or raises NamingError."""
    if not is_snake(asset_id):
        raise NamingError(f"asset id {asset_id!r} must be lowercase snake_case")
    parts = asset_id.split("_")
    if len(parts) < 2:
        raise NamingError(f"asset id {asset_id!r} needs <category>_<name>")
    if parts[0] not in PREFIX_CATEGORY:
        raise NamingError(f"asset id {asset_id!r}: unknown prefix {parts[0]!r}, expected one of {sorted(PREFIX_CATEGORY)}")
    return asset_id


def category_for(asset_id: str) -> str:
    """Output folder (``game/assets/<category>``) for an asset id."""
    return PREFIX_CATEGORY[check_asset_id(asset_id).split("_")[0]]


def check_library_id(library_id: str) -> str:
    if not is_snake(library_id):
        raise NamingError(f"material library id {library_id!r} must be lowercase snake_case")
    return library_id


def material_name(library_id: str) -> str:
    """``grey_wall`` -> ``M_grey_wall``."""
    return MATERIAL_PREFIX + check_library_id(library_id)


def library_id_from_material(name: str) -> str | None:
    """``M_grey_wall`` -> ``grey_wall``; ``None`` if the name is not a library slot."""
    if not name.startswith(MATERIAL_PREFIX):
        return None
    lib_id = name[len(MATERIAL_PREFIX):]
    return lib_id if is_snake(lib_id) else None


def check_node_name(name: str) -> str:
    """Gameplay-visible node names: PascalCase, optionally with a Godot collision suffix."""
    base = strip_collision_suffix(name)
    if not _PASCAL.match(base):
        raise NamingError(f"node name {name!r} must be PascalCase (e.g. Muzzle, Leaf, Frame)")
    return name


def strip_collision_suffix(name: str) -> str:
    for suffix in COLLISION_SUFFIXES:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def is_collision_name(name: str) -> bool:
    return any(name.endswith(s) for s in COLLISION_SUFFIXES)
