"""Art-direction presets. A preset is a plain dict; see gsr.py for the schema."""

from __future__ import annotations

import importlib


def load(name: str) -> dict:
    mod = importlib.import_module(f"texgen.presets.{name}")
    return mod.PRESET
