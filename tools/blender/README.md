# tools/blender

Scripted, deterministic Blender 4.5 models for CAPERWORKS. Full how-to: **[docs/art/pipeline.md](../../docs/art/pipeline.md)**.

* `lib/` – shared library (scene reset, naming, materials, geometry, UVs, LOD policy, glTF export). Owner: ENV C.
* `build.py` – `python3 tools/blender/build.py --category <folder> [--asset <id>] [--check-determinism] [--list]`.
* `run_asset.py` – Blender-side runner used by build.py.
* `greybox/` – greybox modular kit (`arch_*`) and `make_materials.py` (greybox material library).
* `weapons/` – ENV B weapon scripts (same lib).
