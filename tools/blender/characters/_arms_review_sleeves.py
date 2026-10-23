"""Review sheet of the first-person sleeve variants (D2-03 follow-up). Not an asset script; run directly:

    blender -b --factory-startup --python tools/blender/characters/_arms_review_sleeves.py -- OUT.png [clip:frame ...]

One row per arms mesh, top to bottom: the generic ``char_arms_fp`` (dark suit, skin hands), then
``char_arms_fp_rook``, ``_sable``, ``_dutch``, ``_wren`` (``_arms_sleeves``); columns = the cells (default a
pistol idle and a rifle ADS frame), rendered like ``_arms_review`` (crew camera at the rig root).
"""

from __future__ import annotations

import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import _arms_review as R  # noqa: E402
import _arms_sleeves as SL  # noqa: E402

CELLS = ["pistol_idle:0", "rifle_ads_idle:0"]
ROWS = [("generic", {"skin": 2})] + [(h, {"heister": h, "skin": {"rook": 3, "sable": 5, "dutch": 1, "wren": 2, "marten": 3, "jay": 4, "juno": 1, "hale": 6}[h]})
                                     for h in SL.VARIANTS]


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = pathlib.Path(argv[0]).resolve()
    cells = argv[1:] or CELLS
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="arms_sleeves_"))
    sheets = []
    for name, params in ROWS:
        path = tmp / f"{name}.png"
        R.render(path, cells, params, cols=len(cells))
        img = bpy.data.images.load(str(path))
        w, h = img.size
        sheets.append(np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4))
        bpy.data.images.remove(img)
        path.unlink()
    full = np.concatenate(list(reversed(sheets)), axis=0)       # Blender pixel rows are bottom-up
    im = bpy.data.images.new("sleeves", full.shape[1], full.shape[0], alpha=True)
    im.pixels.foreach_set(full.ravel())
    im.filepath_raw = str(out)
    im.file_format = "PNG"
    im.save()
    print("[review] sleeve rows:", ", ".join(n for n, _p in ROWS))


if __name__ == "__main__":
    main()
