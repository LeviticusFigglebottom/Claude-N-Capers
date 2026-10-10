"""Blender-side entry point. Run by build.py; you rarely call it yourself.

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/run_asset.py -- \\
        <asset_script.py> <out_root> [asset_id ...]

Builds the listed assets of one script (all of them if none are listed) into
``<out_root>/<category>/<asset_id>/``.
"""

import pathlib
import sys
import traceback

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from lib import asset  # noqa: E402


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        print(__doc__)
        return 2
    script = pathlib.Path(argv[0]).resolve()
    out_root = pathlib.Path(argv[1]).resolve()
    try:
        return asset.run(script, out_root, argv[2:])
    except Exception:  # noqa: BLE001 - report and fail the Blender process
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    code = main()
    if code:
        sys.exit(code)
