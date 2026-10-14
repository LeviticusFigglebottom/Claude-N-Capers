#!/usr/bin/env python3
"""Gallery Night painting canvases (GN-C2): 12 ORIGINAL abstract-figurative compositions, 1024 x 1024 albedo,
deterministic (seed = crc32 of the id), no photos and no third-party imagery. Budgets (gallery_night.md): the
4 list works + 8 studies; every other hang reuses these.

    python3 tools/texgen/paintings.py                       # write game/assets/textures/paintings/*
    python3 tools/texgen/paintings.py --check-determinism   # build twice in memory, compare sha256

Each picture is painted with a handful of soft, edge-noised shapes (grounds, bands, figures, glows) laid over
a warped colour ground, then brushwork (anisotropic fBm along the stroke direction), a fine canvas weave and a
warm varnish. Albedo rules (style guide §3) are enforced last: luminance 0.04-0.85 linear, saturation <= 0.72.
The image is square; the frame UVs crop it to the frame's aspect (cover fit), so keep the subject near the
centre third.
"""

from __future__ import annotations

import hashlib
import sys
import zlib
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))

from texgen import godot as tgodot  # noqa: E402
from texgen import io as tio  # noqa: E402
from texgen import noise, ops  # noqa: E402

SIZE = 1024
OUT = REPO / "game" / "assets" / "textures" / "paintings"
IDS = ("lantern", "orchard", "widow", "saint", "study1", "study2", "study3", "study4", "study5", "study6",
       "study7", "study8")
TITLES = {
    "lantern": "The Lantern Bearer (Ines Calloway)", "orchard": "The Salt Orchard (Teodor Wilk)",
    "widow": "Widow in Blue (Henrike Sallow)", "saint": "The Tidewater Saint (Aurel Maske)",
    "study1": "study: still life with jars", "study2": "study: head of a woman", "study3": "study: harbour boats",
    "study4": "study: interior with an open door", "study5": "study: two walkers", "study6": "study: downs at dusk",
    "study7": "study: colour fields", "study8": "study: reclining figure",
}


def seed_of(pid: str) -> int:
    return zlib.crc32(("painting_" + pid).encode("utf-8"))


class Canvas:
    """A linear-RGB float image with soft-shape painting helpers. Coordinates: x right, y DOWN, in [0, 1]."""

    def __init__(self, seed: int) -> None:
        self.seed = seed
        self.u, self.v = noise.coords(SIZE)
        self.img = np.zeros((SIZE, SIZE, 3))
        self._n = 0
        # a few shared noise fields (fBm is the cost); each use takes a different seeded roll of one of them
        self._fields: dict[int, np.ndarray] = {}
        self._rng = noise.make_rng(seed)

    def _sub(self, name: str) -> int:
        self._n += 1
        return noise.sub_seed(self.seed, f"{name}{self._n}")

    def field(self, period: int) -> np.ndarray:
        """A tileable fBm field of this period, rolled by a fresh seeded offset on every call."""
        if period not in self._fields:
            self._fields[period] = noise.fbm(self.u, self.v, period, noise.sub_seed(self.seed, f"f{period}"), octaves=4)
        dy, dx = (int(x) for x in self._rng.integers(0, SIZE, size=2))
        return np.roll(self._fields[period], (dy, dx), axis=(0, 1))

    def edge_noise(self, amount: float, period: int = 9) -> np.ndarray:
        return self.field(period) * amount

    def lay(self, mask: np.ndarray, colour: str | np.ndarray, opacity: float = 1.0, vary: float = 0.12) -> None:
        col = ops.hex_to_linear(colour) if isinstance(colour, str) else np.asarray(colour)
        tone = 1.0 + vary * self.field(6)
        paint = col[None, None, :] * tone[..., None]
        m = np.clip(mask * opacity, 0.0, 1.0)[..., None]
        self.img = self.img * (1.0 - m) + paint * m

    def gradient_ground(self, stops: list[tuple[float, str]], warp: float = 0.06) -> None:
        u, v = noise.warp(self.u, self.v, warp, 4, self._sub("gw"))
        cols = [ops.hex_to_linear(c) for _, c in stops]
        pos = [p for p, _ in stops]
        out = np.zeros_like(self.img)
        t = np.clip(v, 0.0, 1.0)
        for i in range(len(stops) - 1):
            a, b = pos[i], pos[i + 1]
            w = np.clip((t - a) / max(b - a, 1e-6), 0.0, 1.0)
            seg = (t >= a) & (t <= b) if i < len(stops) - 2 else (t >= a)
            mix = cols[i][None, None, :] * (1.0 - w[..., None]) + cols[i + 1][None, None, :] * w[..., None]
            out = np.where(seg[..., None], mix, out)
        out = np.where((t < pos[0])[..., None], cols[0][None, None, :], out)
        self.img = out * (1.0 + 0.1 * self.field(5))[..., None]

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, angle: float = 0.0, soft: float = 0.02,
                rough: float = 0.03) -> np.ndarray:
        dx, dy = self.u - cx, self.v - cy
        ca, sa = np.cos(angle), np.sin(angle)
        x, y = dx * ca + dy * sa, -dx * sa + dy * ca
        d = np.sqrt((x / rx) ** 2 + (y / ry) ** 2) - 1.0 + self.edge_noise(rough)
        return ops.smoothstep(soft / min(rx, ry), -soft / min(rx, ry), d)

    def band(self, y0: float, y1: float, soft: float = 0.015, rough: float = 0.02) -> np.ndarray:
        n = self.edge_noise(rough, 7)
        return ops.smoothstep(y0 - soft, y0 + soft, self.v + n) * ops.smoothstep(y1 + soft, y1 - soft, self.v + n)

    def rect(self, x0: float, y0: float, x1: float, y1: float, soft: float = 0.01, rough: float = 0.012) -> np.ndarray:
        n = self.edge_noise(rough, 11)
        mx = ops.smoothstep(x0 - soft, x0 + soft, self.u + n) * ops.smoothstep(x1 + soft, x1 - soft, self.u + n)
        my = ops.smoothstep(y0 - soft, y0 + soft, self.v + n) * ops.smoothstep(y1 + soft, y1 - soft, self.v + n)
        return mx * my

    def poly(self, pts: list[tuple[float, float]], soft: float = 0.012, rough: float = 0.02) -> np.ndarray:
        """Soft convex/concave polygon (even-odd fill) with an edge falloff from the distance to its edges."""
        n = self.edge_noise(rough, 9)
        x, y = self.u + n, self.v + n
        inside = np.zeros(x.shape, dtype=bool)
        dmin = np.full(x.shape, 9.0)
        k = len(pts)
        for i in range(k):
            (ax, ay), (bx, by) = pts[i], pts[(i + 1) % k]
            cond = ((ay > y) != (by > y)) & (x < (bx - ax) * (y - ay) / ((by - ay) + 1e-12) + ax)
            inside ^= cond
            ex, ey = bx - ax, by - ay
            t = np.clip(((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey + 1e-12), 0.0, 1.0)
            dmin = np.minimum(dmin, np.hypot(x - ax - t * ex, y - ay - t * ey))
        sd = np.where(inside, -dmin, dmin)
        return ops.smoothstep(soft, -soft, sd)

    def glow(self, cx: float, cy: float, r: float, colour: str, strength: float = 1.0) -> None:
        d = np.hypot(self.u - cx, self.v - cy) / r
        g = np.exp(-d * d * 2.2) * strength
        self.img = self.img + ops.hex_to_linear(colour)[None, None, :] * g[..., None]

    def figure(self, cx: float, foot: float, h: float, colour: str, head: str, lean: float = 0.0,
               robe: float = 1.0) -> None:
        """A standing figure: tapered robe, shoulders, head (abstracted, no features)."""
        top = foot - h
        sh = top + h * 0.17
        w = h * 0.16 * robe
        self.lay(self.poly([(cx - w * 0.45 + lean * 0.3, sh), (cx + w * 0.45 + lean * 0.3, sh),
                            (cx + w * 0.75, foot), (cx - w * 0.75, foot)], rough=0.012), colour)
        self.lay(self.ellipse(cx + lean * 0.3, sh + h * 0.03, w * 0.52, h * 0.06, rough=0.02), colour)
        self.lay(self.ellipse(cx + lean * 0.4, top + h * 0.075, h * 0.055, h * 0.072, rough=0.015), head)

    def finish(self, stroke_angle: float = 0.6, stroke: float = 0.07, varnish: str = "#E8D8B0") -> np.ndarray:
        # brushwork: anisotropic fBm in a rotated frame (strokes ~3 % of the width long)
        ca, sa = np.cos(stroke_angle), np.sin(stroke_angle)
        su, sv = self.u * ca + self.v * sa, -self.u * sa + self.v * ca
        br = noise.fbm(su, sv, (10, 90), self._sub("brush"), octaves=3)
        br2 = noise.fbm(self.u, self.v, (60, 60), self._sub("bristle"), octaves=2)
        img = self.img * (1.0 + stroke * br + 0.025 * br2)[..., None]
        # canvas weave (fine) and a warm varnish with a soft vignette
        weave = 0.018 * (np.sin(self.u * np.pi * 2 * 340) * np.sin(self.v * np.pi * 2 * 340))
        img = img * (1.0 + weave)[..., None]
        vig = 1.0 - 0.22 * np.clip(np.hypot(self.u - 0.5, self.v - 0.5) / 0.72, 0.0, 1.0) ** 2
        img = img * vig[..., None]
        img = ops.hue_shift_toward(img, ops.hex_to_linear(varnish), 0.12)
        img = ops.enforce_albedo_rules(img, 0.04, 0.85, 0.72)
        return np.round(ops.linear_to_srgb(img) * 255.0).astype(np.uint8)


# ------------------------------------------------------------------------------- compositions

def p_lantern(c: Canvas) -> None:
    """The Lantern Bearer: a cloaked figure walking out of a green-black night, the lantern's warm pool on the
    ground and on the figure's flank; a lit window far off; the halberd-green ground of the gallery's own walls."""
    c.gradient_ground([(0.0, "#16201C"), (0.55, "#24382F"), (0.72, "#2C2A22"), (1.0, "#1A1612")])
    c.lay(c.band(0.66, 1.2, soft=0.04, rough=0.03), "#2E261C", 0.9)
    c.lay(c.rect(0.12, 0.30, 0.19, 0.40, rough=0.008), "#C89A52", 0.8)   # far window
    c.glow(0.58, 0.62, 0.20, "#7A4A16", 0.55)
    c.lay(c.ellipse(0.56, 0.86, 0.26, 0.05, rough=0.05), "#5E4426", 0.7)  # light pool on the ground
    c.figure(0.50, 0.88, 0.62, "#2A3A34", "#7E664C", lean=0.03)
    c.lay(c.poly([(0.52, 0.42), (0.57, 0.44), (0.60, 0.86), (0.54, 0.86)], rough=0.01), "#6B5232", 0.55)  # lit flank
    c.lay(c.ellipse(0.61, 0.60, 0.025, 0.035, rough=0.01), "#E8C27A")  # lantern
    c.glow(0.61, 0.60, 0.06, "#C88A3A", 0.9)
    c.lay(c.rect(0.605, 0.50, 0.612, 0.575, rough=0.003), "#3A2E22")  # handle


def p_orchard(c: Canvas) -> None:
    """The Salt Orchard: rows of pollarded trees on a salt-white plain under a pale sky, one small figure."""
    c.gradient_ground([(0.0, "#C9CCC4"), (0.45, "#DCD8CB"), (0.55, "#CFC6AE"), (1.0, "#B8AE96")])
    rng = noise.make_rng(c.seed)
    for row in range(4):
        y = 0.52 + row * 0.11
        s = 0.5 + row * 0.35
        n = 7 - row
        for i in range(n):
            x = (i + 0.5) / n + float(rng.uniform(-0.03, 0.03))
            c.lay(c.rect(x - 0.006 * s, y - 0.09 * s, x + 0.006 * s, y, rough=0.004), "#4A3F35")
            c.lay(c.ellipse(x, y - 0.11 * s, 0.05 * s, 0.045 * s, rough=0.06), ["#5F6B4E", "#6E7652", "#55603F"][i % 3])
        c.lay(c.band(y + 0.002, y + 0.012, soft=0.004, rough=0.006), "#9C9278", 0.5)
    c.figure(0.70, 0.95, 0.22, "#5A3B2C", "#8A6A52")


def p_widow(c: Canvas) -> None:
    """Widow in Blue: a seated woman in a deep blue gown against an ochre wall, a tall window beside her."""
    c.gradient_ground([(0.0, "#8E6E3E"), (0.7, "#A07A44"), (0.72, "#5E4630"), (1.0, "#4A3826")])
    c.lay(c.rect(0.08, 0.10, 0.30, 0.62, rough=0.006), "#7E8E92", 0.9)    # window
    c.lay(c.rect(0.185, 0.10, 0.20, 0.62, rough=0.003), "#5A4A36")
    c.lay(c.rect(0.08, 0.35, 0.30, 0.365, rough=0.003), "#5A4A36")
    c.lay(c.rect(0.50, 0.50, 0.80, 0.80, rough=0.01), "#3E2A20")          # chair
    c.lay(c.poly([(0.47, 0.42), (0.71, 0.42), (0.84, 0.93), (0.36, 0.93)], rough=0.015), "#22365A")  # gown
    c.lay(c.ellipse(0.59, 0.42, 0.13, 0.05, rough=0.02), "#22365A")
    c.lay(c.poly([(0.62, 0.45), (0.70, 0.45), (0.80, 0.92), (0.70, 0.92)], rough=0.01), "#30497A", 0.7)  # lit fold
    c.lay(c.ellipse(0.585, 0.30, 0.055, 0.07, angle=0.15, rough=0.015), "#B48C6A")  # head
    c.lay(c.ellipse(0.575, 0.27, 0.065, 0.05, rough=0.02), "#2A221C")              # hair
    c.lay(c.ellipse(0.565, 0.60, 0.035, 0.018, rough=0.01), "#B48C6A", 0.9)        # hands


def p_saint(c: Canvas) -> None:
    """The Tidewater Saint: a pale standing figure with a ring halo in the shallows, grey-green sea in bands."""
    c.gradient_ground([(0.0, "#5E6E70"), (0.42, "#8C9690"), (0.46, "#3E5652"), (1.0, "#2C3E3A")])
    for i, y in enumerate((0.52, 0.60, 0.70, 0.82)):
        c.lay(c.band(y, y + 0.015 + 0.006 * i, soft=0.006, rough=0.03), "#A8B0A6", 0.55)
    c.figure(0.50, 0.86, 0.56, "#C8C0AC", "#A88A6E", robe=1.1)
    halo = c.ellipse(0.50, 0.345, 0.075, 0.075, rough=0.01) - c.ellipse(0.50, 0.345, 0.062, 0.062, rough=0.01)
    c.lay(np.clip(halo, 0.0, 1.0), "#C9A54E", 0.9)
    c.lay(c.ellipse(0.50, 0.87, 0.16, 0.025, rough=0.05), "#5C7470", 0.7)    # reflection


def p_study1(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#5A4E40"), (0.6, "#6A5A46"), (0.62, "#8A6A48"), (1.0, "#6E5236")])
    for x, w, h, col in ((0.30, 0.07, 0.25, "#3E5A4C"), (0.45, 0.09, 0.18, "#B8A27A"), (0.60, 0.06, 0.30, "#7A3A2C")):
        c.lay(c.rect(x - w / 2, 0.62 - h, x + w / 2, 0.62, rough=0.01), col)
        c.lay(c.ellipse(x, 0.62 - h, w / 2, 0.015, rough=0.01), col)
    c.lay(c.ellipse(0.70, 0.60, 0.09, 0.04, rough=0.02), "#C8B48C")


def p_study2(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#3A3C36"), (1.0, "#262622")])
    c.lay(c.poly([(0.30, 0.95), (0.70, 0.95), (0.64, 0.66), (0.36, 0.66)], rough=0.02), "#4A2E2A")
    c.lay(c.rect(0.46, 0.52, 0.54, 0.68, rough=0.01), "#A87E62")
    c.lay(c.ellipse(0.50, 0.42, 0.14, 0.18, rough=0.02), "#B48A6A")
    c.lay(c.ellipse(0.47, 0.32, 0.17, 0.12, angle=-0.2, rough=0.03), "#5A3A26")
    c.lay(c.ellipse(0.55, 0.44, 0.05, 0.12, rough=0.02), "#8E6A50", 0.6)


def p_study3(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#9AA4A6"), (0.5, "#B8B4A2"), (0.52, "#4E6266"), (1.0, "#33464A")])
    for x, s in ((0.25, 1.0), (0.55, 0.8), (0.78, 0.6)):
        c.lay(c.poly([(x - 0.12 * s, 0.56), (x + 0.12 * s, 0.56), (x + 0.08 * s, 0.62), (x - 0.09 * s, 0.62)],
                     rough=0.008), "#7A3A2A")
        c.lay(c.rect(x - 0.004, 0.56 - 0.28 * s, x + 0.004, 0.56, rough=0.003), "#3A2E26")
        c.lay(c.poly([(x + 0.006, 0.56 - 0.26 * s), (x + 0.10 * s, 0.54), (x + 0.006, 0.54)], rough=0.01), "#D2C6A6", 0.9)
    c.lay(c.band(0.66, 0.68, rough=0.03), "#7E8E8C", 0.5)


def p_study4(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#6E7A62"), (0.75, "#5E6A54"), (0.76, "#7A6046"), (1.0, "#5E4A36")])
    c.lay(c.rect(0.40, 0.18, 0.66, 0.76, rough=0.006), "#3A2C22")
    c.lay(c.rect(0.43, 0.21, 0.63, 0.76, rough=0.006), "#D0BE92")
    c.lay(c.poly([(0.43, 0.21), (0.52, 0.25), (0.52, 0.80), (0.43, 0.76)], rough=0.006), "#5A4232")
    c.lay(c.poly([(0.43, 0.76), (0.63, 0.76), (0.80, 0.98), (0.30, 0.98)], rough=0.02), "#B8A27E", 0.5)


def p_study5(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#B8A88A"), (0.55, "#A89676"), (0.57, "#6E7458"), (1.0, "#4E5640")])
    c.figure(0.40, 0.84, 0.42, "#3A3A46", "#8A6A52", lean=-0.02)
    c.figure(0.56, 0.86, 0.46, "#6A2E2A", "#9A765A", lean=0.02)
    c.lay(c.band(0.85, 0.88, rough=0.04), "#3E4232", 0.6)


def p_study6(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#4A4E6A"), (0.35, "#9E7A6A"), (0.5, "#C8A47A"), (1.0, "#3E4A36")])
    for i, (y, col) in enumerate(((0.52, "#6E6A54"), (0.60, "#5A6248"), (0.70, "#46533C"), (0.84, "#3A4430"))):
        c.lay(c.band(y, 1.2, soft=0.02, rough=0.05 - i * 0.008), col)
    c.glow(0.70, 0.46, 0.10, "#8A5A2A", 0.5)


def p_study7(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#5A2A26"), (1.0, "#4A2420")])
    c.lay(c.rect(0.12, 0.10, 0.88, 0.42, soft=0.03, rough=0.03), "#9A5A2E")
    c.lay(c.rect(0.12, 0.48, 0.88, 0.62, soft=0.03, rough=0.03), "#3E2A3A")
    c.lay(c.rect(0.12, 0.68, 0.88, 0.90, soft=0.03, rough=0.03), "#B8913E", 0.85)


def p_study8(c: Canvas) -> None:
    c.gradient_ground([(0.0, "#6A4A3E"), (0.6, "#7A5644"), (0.62, "#D2C8B4"), (1.0, "#B8AC96")])
    c.lay(c.poly([(0.18, 0.62), (0.80, 0.58), (0.86, 0.66), (0.20, 0.70)], rough=0.02), "#C49A7A")
    c.lay(c.ellipse(0.20, 0.58, 0.06, 0.05, rough=0.02), "#C49A7A")
    c.lay(c.ellipse(0.18, 0.55, 0.07, 0.04, rough=0.03), "#3A2A22")
    c.lay(c.poly([(0.40, 0.60), (0.60, 0.58), (0.62, 0.66), (0.40, 0.68)], rough=0.02), "#24463A", 0.85)  # drape


PAINTERS = {pid: globals()["p_" + pid] for pid in IDS}


def render(pid: str) -> np.ndarray:
    c = Canvas(seed_of(pid))
    PAINTERS[pid](c)
    ang = 0.35 + (seed_of(pid) % 100) / 100.0
    return c.finish(stroke_angle=ang)


def png_path(pid: str) -> Path:
    return OUT / f"tex_painting_{pid}_albedo.png"


def main() -> int:
    if "--check-determinism" in sys.argv:
        bad = 0
        for pid in IDS:
            a = hashlib.sha256(render(pid).tobytes()).hexdigest()
            b = hashlib.sha256(render(pid).tobytes()).hexdigest()
            print(f"{a[:16]}  {pid}" + ("" if a == b else "  MISMATCH"))
            bad += a != b
        return 1 if bad else 0
    for pid in IDS:
        dst = png_path(pid)
        tio.write_png(dst, render(pid))
        tgodot.ensure_import(dst, "texture", "CompressedTexture2D", tgodot.IMPORT_PARAMS["albedo"])
        print(f"{tio.sha256(dst)[:16]}  {dst.relative_to(REPO)}")
    lines = ["Gallery Night painting canvases (GN-C2): original abstract-figurative compositions, no third-party imagery.",
             "Generator: tools/texgen/paintings.py (python3 tools/texgen/paintings.py). 1024 x 1024 albedo, seed = crc32('painting_<id>').",
             ""]
    lines += [f"tex_painting_{pid}_albedo.png  seed {seed_of(pid)}  {TITLES[pid]}" for pid in IDS]
    tio.write_text(OUT / "SOURCE.txt", "\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
