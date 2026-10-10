"""Display-referred colour grade + lens finish for the style samples (system Python: Pillow, numpy).

Reads the style's "grade" block from styles.py so the grade is a preset parameter, not a hand edit.
Deterministic: grain uses numpy's PCG64 seeded with zlib.crc32(style + asset); PNG written without
metadata.

usage: python3 post.py --style a_gsr --in raw.png --out final.png --seed 123
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import styles  # noqa: E402

LUM = np.array([0.2126, 0.7152, 0.0722], np.float32)


def grade(img: np.ndarray, g: dict, rng: np.random.Generator) -> np.ndarray:
    c = img.astype(np.float32) / 255.0
    h, w, _ = c.shape
    # chromatic aberration: radially scale R out / B in by a few tenths of a pixel at the corners
    if g["chroma_ab"] > 0:
        k = g["chroma_ab"] / (0.5 * np.hypot(w, h))
        out = c.copy()
        # scale R (and G by half) outward about the centre; sampling stays inside the frame
        for ch, s in ((0, 1.0 + 2 * k), (1, 1.0 + k)):
            im = Image.fromarray((c[..., ch] * 65535).astype(np.int32), "I")
            im = im.transform((w, h), Image.AFFINE, (1 / s, 0, w / 2 * (1 - 1 / s), 0, 1 / s, h / 2 * (1 - 1 / s)),
                              resample=Image.BICUBIC)
            out[..., ch] = np.asarray(im, np.float32) / 65535.0
        c = np.clip(out, 0, 1)
    # lift / gain
    lift = np.array(g["lift"], np.float32)
    gain = np.array(g["gain"], np.float32)
    c = c * gain + lift * (1.0 - c)
    # toe (crushed blacks)
    if g["curve_toe"] > 0:
        t = g["curve_toe"]
        c = 0.7 * np.clip((c - t) / (1 - t), 0, 1) + 0.3 * c
    # contrast as a smooth S around mid grey
    k = g["contrast"]
    if k != 1.0:
        x = np.clip(c, 0, 1)
        s = x * x * (3 - 2 * x)
        c = x + (s - x) * (k - 1.0) * 2.0
    # saturation
    lum = (c @ LUM)[..., None]
    c = lum + (c - lum) * g["saturation"]
    # vignette
    if g["vignette"] > 0:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / np.sqrt(2)
        c = c * (1.0 - g["vignette"] * np.clip(r, 0, 1) ** 2.2)[..., None]
    # film grain (luma, strongest in the mids)
    if g["grain"] > 0:
        n = rng.standard_normal((h, w), dtype=np.float32)
        lum = c @ LUM
        amp = g["grain"] * (0.35 + 1.3 * lum * (1 - lum))
        c = c + (n * amp)[..., None]
    return (np.clip(c, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", required=True)
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()
    st = styles.get(a.style)
    img = np.asarray(Image.open(a.src).convert("RGB"))
    rng = np.random.Generator(np.random.PCG64(a.seed))
    res = grade(img, st["grade"], rng)
    im = Image.fromarray(res, "RGB")
    im.save(a.out, format="PNG", optimize=True)
    if pathlib.Path(a.out).stat().st_size > 2_000_000:
        # grain defeats PNG compression: fall back to a 256-colour dithered palette (<= ~2 MB budget)
        im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(
            a.out, format="PNG", optimize=True)
    print(f"[post] {a.out} {pathlib.Path(a.out).stat().st_size / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
