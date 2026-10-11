#!/usr/bin/env python3
"""Stitch the D3-01 review renders of ``_p5_review.py`` (system python + Pillow; not an asset script).

    python3 tools/blender/characters/_p5_stitch.py lineup <out.png> <label>=<row.png> ...
    python3 tools/blender/characters/_p5_stitch.py faces <out.png> <tile_prefix> <id> ...
    python3 tools/blender/characters/_p5_stitch.py upscale <out.png> <in.png> [factor]

``lineup`` stacks the heist rows (centred, labelled), ``faces`` lays the head tiles out 6 per row
with the character id under each, ``upscale`` enlarges the 30 m silhouette render nearest-neighbour.
"""

from __future__ import annotations

import sys

from PIL import Image, ImageDraw, ImageFont

BG = (38, 38, 41)
FG = (225, 225, 220)


def _font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def lineup(out: str, rows: list[str]) -> None:
    imgs = [(lab, Image.open(p).convert("RGB")) for lab, p in (r.split("=", 1) for r in rows)]
    w = max(im.width for _, im in imgs)
    bar = 44
    h = sum(im.height + bar for _, im in imgs)
    sheet = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(sheet)
    f = _font(30)
    y = 0
    for lab, im in imgs:
        d.text((16, y + 6), lab, fill=FG, font=f)
        sheet.paste(im, ((w - im.width) // 2, y + bar))
        y += im.height + bar
    sheet.save(out)


def faces(out: str, prefix: str, ids: list[str], cols: int = 6) -> None:
    tiles = [Image.open(f"{prefix}.{i}.png").convert("RGB") for i in ids]
    t = tiles[0].width
    lab = 28
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * t, rows * (t + lab)), BG)
    d = ImageDraw.Draw(sheet)
    f = _font(20)
    for n, (cid, im) in enumerate(zip(ids, tiles)):
        x, y = (n % cols) * t, (n // cols) * (t + lab)
        sheet.paste(im, (x, y))
        d.text((x + 8, y + t + 3), cid.removeprefix("char_"), fill=FG, font=f)
    sheet.save(out)


def upscale(out: str, src: str, factor: int = 3) -> None:
    im = Image.open(src).convert("RGB")
    im.resize((im.width * factor, im.height * factor), Image.NEAREST).save(out)


if __name__ == "__main__":
    mode, dst = sys.argv[1], sys.argv[2]
    if mode == "lineup":
        lineup(dst, sys.argv[3:])
    elif mode == "faces":
        faces(dst, sys.argv[3], sys.argv[4:])
    else:
        upscale(dst, sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 3)
