"""CAPERWORKS Blender asset library (C1-01). Owner: ENV C.

Import inside Blender 4.5 after putting ``<repo>/tools/blender`` on ``sys.path``::

    from lib import scene, naming, materials, geo, uv, lod, export, asset

Modules that touch Blender (``scene``, ``materials``, ``geo``, ``uv``, ``export``, ``asset``)
import ``bpy`` and only work inside Blender. ``naming``, ``lod``, ``meta``, ``source``,
``godot_import`` and ``glb`` are pure Python and are also used by ``build.py`` (system python3).

This package deliberately imports nothing on load so the pure-Python modules stay importable
outside Blender. See tools/blender/PIPELINE.md for the full how-to.
"""

# Bump the minor version for additive API changes and the major version for breaking changes.
# ENV B builds weapons against this API, so breaking changes need a lead-approved migration note.
__version__ = "1.0.0"

# Pinned tool versions. Output bytes are only guaranteed identical with these.
BLENDER_VERSION = "4.5"
