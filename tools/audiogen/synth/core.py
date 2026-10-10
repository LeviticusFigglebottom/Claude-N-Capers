"""Sample rate, time helpers and deterministic seeding."""
from __future__ import annotations

import zlib

import numpy as np

SR: int = 48000


def seed_for(sound_id: str) -> int:
    """Seed rule (conventions): zlib.crc32 of the asset id, never Python's salted hash()."""
    return zlib.crc32(sound_id.encode("utf-8"))


def rng_for(sound_id: str, salt: str = "") -> np.random.Generator:
    return np.random.default_rng(seed_for(sound_id + ("#" + salt if salt else "")))


def nsamp(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def tvec(dur: float) -> np.ndarray:
    return np.arange(nsamp(dur), dtype=np.float64) / SR


def silence(dur: float, channels: int = 1) -> np.ndarray:
    n = nsamp(dur)
    return np.zeros(n) if channels == 1 else np.zeros((n, channels))


def midi_hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-12))


def undb(d: float) -> float:
    return 10.0 ** (d / 20.0)


def as_array(v: float | np.ndarray, n: int) -> np.ndarray:
    if np.isscalar(v):
        return np.full(n, float(v))
    a = np.asarray(v, dtype=np.float64)
    if a.shape[0] != n:
        a = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, a.shape[0]), a)
    return a


def place(dst: np.ndarray, src: np.ndarray, start: int, gain: float = 1.0) -> None:
    """Mix src into dst at sample offset `start` (clipped to dst length). Mono or stereo."""
    if start >= dst.shape[0] or start + src.shape[0] <= 0:
        return
    s0 = max(0, -start)
    a = max(0, start)
    b = min(dst.shape[0], start + src.shape[0])
    seg = src[s0:s0 + (b - a)]
    if dst.ndim == 2 and seg.ndim == 1:
        seg = seg[:, None]
    dst[a:b] += seg * gain


def fit(x: np.ndarray, n: int) -> np.ndarray:
    """Pad with zeros or truncate to n samples."""
    if x.shape[0] >= n:
        return x[:n]
    pad = [(0, n - x.shape[0])] + [(0, 0)] * (x.ndim - 1)
    return np.pad(x, pad)


def fade(x: np.ndarray, fin: float = 0.0, fout: float = 0.0) -> np.ndarray:
    y = x.copy()
    if fin > 0:
        k = min(nsamp(fin), y.shape[0])
        r = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
        y[:k] *= r if y.ndim == 1 else r[:, None]
    if fout > 0:
        k = min(nsamp(fout), y.shape[0])
        r = np.cos(np.linspace(0, np.pi / 2, k)) ** 2
        y[-k:] *= r if y.ndim == 1 else r[:, None]
    return y


def wrap_loop(x: np.ndarray, loop_len: int) -> np.ndarray:
    """Make a seamless loop: fold everything rendered past loop_len (tails) back onto the start."""
    out = x[:loop_len].copy()
    rest = x[loop_len:]
    while rest.shape[0] > 0:
        k = min(loop_len, rest.shape[0])
        out[:k] += rest[:k]
        rest = rest[k:]
    return out


def mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def stereo(x: np.ndarray) -> np.ndarray:
    return np.stack([x, x], axis=1) if x.ndim == 1 else x


def loop_xfade(x: np.ndarray, loop_len: int, xfade: int) -> np.ndarray:
    """Seamless loop from a render of at least loop_len + xfade samples: the material rendered
    past the loop end is equal-power crossfaded over the loop start, so sample L-1 -> 0 is
    continuous (out[0] == x[L])."""
    assert x.shape[0] >= loop_len + xfade, "render loop_len + xfade samples"
    out = x[:loop_len].copy()
    w = np.linspace(0.0, 1.0, xfade)
    fin = np.sin(w * np.pi / 2)
    fout = np.cos(w * np.pi / 2)
    if x.ndim == 2:
        fin = fin[:, None]
        fout = fout[:, None]
    out[:xfade] = x[:xfade] * fin + x[loop_len:loop_len + xfade] * fout
    return out
