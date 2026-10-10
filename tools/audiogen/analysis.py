"""Listen-check substitutes: per-file metrics and a spectrogram contact sheet (numpy + Pillow only)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from synth import loudness
from synth.core import SR

F_LO, F_HI = 40.0, 20000.0
_STOPS = np.array([  # perceptual dark->bright ramp (black, indigo, magenta, orange, pale yellow)
    [0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66], [245, 125, 21], [250, 193, 39],
    [252, 255, 164]], dtype=np.float64)


def metrics(x: np.ndarray) -> dict:
    m = x if x.ndim == 1 else x.mean(axis=1)
    spec = np.abs(np.fft.rfft(m * np.hanning(m.shape[0])))
    freqs = np.fft.rfftfreq(m.shape[0], 1 / SR)
    centroid = float(np.sum(freqs * spec) / (np.sum(spec) + 1e-12))
    return {
        "duration_s": round(x.shape[0] / SR, 3),
        "channels": 1 if x.ndim == 1 else x.shape[1],
        "lufs_short_max": round(loudness.short_term_max(x), 2),
        "lufs_integrated": round(loudness.integrated(x), 2),
        "true_peak_dbtp": round(loudness.true_peak_db(x), 2),
        "centroid_hz": round(centroid, 0),
        "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(m ** 2)) + 1e-12), 2),
    }


def _colorize(v: np.ndarray) -> np.ndarray:
    v = np.clip(v, 0, 1) * (len(_STOPS) - 1)
    i = np.minimum(v.astype(int), len(_STOPS) - 2)
    f = (v - i)[..., None]
    return (_STOPS[i] * (1 - f) + _STOPS[i + 1] * f).astype(np.uint8)


def spectrogram_tile(x: np.ndarray, w: int, h: int, max_s: float | None = None) -> Image.Image:
    m = x if x.ndim == 1 else x.mean(axis=1)
    if max_s:
        m = m[: int(max_s * SR)]
    nfft = 2048 if m.shape[0] > SR // 2 else 512
    hop = max(8, (m.shape[0] - nfft) // w) if m.shape[0] > nfft else 8
    m = np.pad(m, (0, max(0, nfft + hop * w - m.shape[0])))
    win = np.hanning(nfft)
    frames = np.stack([m[i * hop:i * hop + nfft] * win for i in range(w)])
    mag = np.abs(np.fft.rfft(frames, axis=1))
    db = 20 * np.log10(mag + 1e-9)
    db -= db.max()
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    rows = np.geomspace(F_HI, F_LO, h)
    img = np.stack([np.interp(rows, freqs, col) for col in db], axis=1)
    return Image.fromarray(_colorize((img + 80) / 80), "RGB")


def contact_sheet(items: list[tuple[str, np.ndarray, dict]], out: Path, cols: int = 4, tile_w: int = 300,
                  tile_h: int = 120, max_s: float | None = 3.0, title: str = "") -> None:
    """Grid of spectrograms (log freq 40 Hz-20 kHz, 80 dB range) with a waveform strip and metrics."""
    font = ImageFont.load_default()
    label_h, wave_h, pad = 30, 24, 8
    cell_w, cell_h = tile_w + pad, tile_h + wave_h + label_h + pad
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w + pad, rows * cell_h + pad + 24), (18, 18, 22))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 6), title + "   (each tile spans its own length; log f 40 Hz-20 kHz, 80 dB; strip: |peak| per column, red = >-1 dBFS)",
           fill=(220, 220, 220), font=font)
    for k, (name, x, met) in enumerate(items):
        cx = pad + (k % cols) * cell_w
        cy = 24 + pad + (k // cols) * cell_h
        span = min(max_s, x.shape[0] / SR) if max_s else None  # each tile spans its own length (<= max_s)
        sheet.paste(spectrogram_tile(x, tile_w, tile_h, span), (cx, cy))
        for f in (100, 1000, 10000):  # frequency guides
            yy = cy + int((np.log(F_HI) - np.log(f)) / (np.log(F_HI) - np.log(F_LO)) * tile_h)
            d.line([(cx, yy), (cx + 6, yy)], fill=(200, 200, 200))
        m = np.abs(x if x.ndim == 1 else x.max(axis=1))
        if span:
            m = m[: int(span * SR)]
        seg = np.array_split(m, tile_w)
        wy = cy + tile_h + 2
        for i, s in enumerate(seg):
            pk = float(s.max()) if s.size else 0.0
            hh = int(min(pk, 1.0) * (wave_h - 2))
            col = (230, 60, 60) if pk > 0.891 else (120, 200, 160)
            d.line([(cx + i, wy + wave_h - 2), (cx + i, wy + wave_h - 2 - hh)], fill=col)
        d.text((cx, wy + wave_h), name, fill=(240, 240, 240), font=font)
        d.text((cx, wy + wave_h + 12),
               f"{met['duration_s']:.2f}s  ST {met['lufs_short_max']:.1f}  I {met['lufs_integrated']:.1f}  "
               f"TP {met['true_peak_dbtp']:.1f}  c {met['centroid_hz']:.0f}Hz", fill=(170, 170, 180), font=font)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, format="PNG", optimize=False)
