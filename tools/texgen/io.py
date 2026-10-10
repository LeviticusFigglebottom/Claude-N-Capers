"""Deterministic file output. PNGs carry no metadata and use a fixed zlib level.

NOTE: this module shadows the stdlib name only inside the ``texgen`` package; always import it
as ``from texgen import io as tio`` (build.py puts ``tools/`` on sys.path, not ``tools/texgen``).
"""

from __future__ import annotations

import hashlib
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image

PNG_COMPRESS_LEVEL = 9


def write_png(path: Path, img: np.ndarray) -> None:
    """Write an (H, W), (H, W, 3) or (H, W, 4) uint8 array as PNG, byte-reproducibly."""
    if img.dtype != np.uint8:
        raise TypeError(f"{path}: expected uint8, got {img.dtype}")
    if img.ndim == 3 and img.shape[2] not in (3, 4):
        raise ValueError(f"{path}: unsupported channel count {img.shape[2]}")
    im = Image.fromarray(np.ascontiguousarray(img))
    # No pnginfo, no ICC profile, no gamma chunk, no optimize pass (its search is not
    # guaranteed stable across Pillow versions).
    buf = BytesIO()
    im.save(buf, format="PNG", optimize=False, compress_level=PNG_COMPRESS_LEVEL)
    data = buf.getvalue()
    # Leave byte-identical files untouched: a new mtime makes Godot re-import them, and
    # concurrent imports by other sessions can then leave .import files valid=false.
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode("utf-8")
    if path.exists() and path.read_bytes() == data:
        return
    path.write_bytes(data)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()
