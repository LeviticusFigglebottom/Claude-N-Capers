"""Labelled 2 x 3 contact sheet of the C1-00 style samples (system Python + Pillow).

Rows: counter, officer. Columns: a_gsr, b_noir, c_photo. Uses Pillow's built-in default font
(no third-party font files).
"""

from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import styles  # noqa: E402

ASSETS = (("counter", "Hero prop: Glasshouse jewelry counter"), ("officer", "Character: Halden Security officer"))


def font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cell", type=int, default=800, help="cell width in px")
    a = ap.parse_args()
    root = pathlib.Path(a.root)
    cw = a.cell
    ch = cw * 1000 // 1600
    pad, head, rowlab = 12, 64, 34
    W = pad + 3 * (cw + pad)
    H = head + 2 * (rowlab + ch + pad) + pad
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 14), "CAPERWORKS  C1-00 art-direction samples (D-012)  -  same geometry & camera, style preset only",
           fill=(235, 230, 220), font=font(24))
    for r, (asset, title) in enumerate(ASSETS):
        y0 = head + r * (rowlab + ch + pad)
        for c, sid in enumerate(styles.STYLE_IDS):
            x = pad + c * (cw + pad)
            d.text((x, y0 + 6), f"{styles.STYLES[sid]['label']}  |  {title}", fill=(225, 215, 195), font=font(18))
            p = root / sid / f"{asset}.png"
            if p.exists():
                im = Image.open(p).convert("RGB").resize((cw, ch), Image.LANCZOS)
                sheet.paste(im, (x, y0 + rowlab))
            else:
                d.rectangle((x, y0 + rowlab, x + cw, y0 + rowlab + ch), fill=(36, 36, 42), outline=(90, 90, 100), width=2)
                msg = "officer pending (ENV D)" if asset == "officer" else f"missing {sid}/{asset}.png"
                d.text((x + cw // 2, y0 + rowlab + ch // 2), msg, fill=(200, 195, 185), font=font(26), anchor="mm")
    sheet.save(a.out, format="PNG", optimize=True)
    print(f"[sheet] {a.out} {pathlib.Path(a.out).stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
