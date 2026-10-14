"""Bullet / melee impact cues `cue.impact_<surface>` (contracts/impact_fx.md 1.0 §3, D-105, PO-8).

One recipe per surface id of impact_fx.md §1 (`concrete brick plaster tile wood metal glass fabric
dirt water flesh armor shield`), 4 variations each, mono, <= 0.4 s, World bus, 3D. Played by C's
VfxDirector/ImpactFx on every `EventBus.shot_fx` hit (local presentation, every peer), so they
fire a lot: short, dry (a hint of the "store" room at most), and mixed under the gunshots in the
registry (`volume_db`), with a small per-source cooldown so a shotgun's pellets don't stack.

Built by tools/audiogen/build.py like every other cue (`--only impact` builds this group); files
land in game/assets/audio/sfx/impact/impact_<surface>/sfx_impact_<surface>_<n>.ogg.

Niches (all start with a sub-millisecond transient; what follows tells the material apart):
  concrete  sharp 1.8-6 kHz crack + bright grit scatter (2-7 kHz grains), small 120 Hz body
  brick     duller crack (low-passed at 3.4 kHz) + 1.1 kHz body + coarser, lower crumble
  plaster   soft broadband "puff" (pink < 1.6 kHz, 3 ms attack) + 170 Hz thud + faint dust hiss
  tile      bright ceramic click (3.1/4.7/6.9 kHz modes) + short 2.2/3.9 kHz ring + chip tinkles
  wood      woody "thock" (210 Hz + 430/980/1750 Hz modes) + 1.5-4 kHz splinter crackle
  metal     ping: inharmonic 2.3-9 kHz ring 0.1-0.2 s; _2/_4 add a ricochet whine (3.4 -> 1.5 kHz)
  glass     crack + 300 Hz knock + a short cloud of 3-10 kHz shard tinkles (much smaller than glass_break)
  fabric    muffled "thup": pink < 650 Hz, 140 Hz body, nearly no highs
  dirt      soft 90 Hz thud + low-passed scatter of grit grains (0.6-2.5 kHz) over 0.2 s
  water     splash: 2-6 kHz hiss burst + rising droplet chirps; plop: a rising 380 -> 900 Hz bubble
  flesh     wet thud: 115 Hz body + 500 Hz/1.4 kHz damp "slap" noise; no squelch, not gory
  armor     hard, dull clank: heavily damped plate modes 380-2300 Hz (40-90 ms) + 130 Hz knock
  shield    heavy metal clang: steel plate modes 240-3700 Hz ringing 0.15-0.3 s + 90 Hz knock, driven
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, click, thud
from synth import env, filters, fx, granular, noise, osc
from synth.core import SR, fade, nsamp, place, tvec

MAX_S = 0.4
SURFACES: tuple[str, ...] = ("concrete", "brick", "plaster", "tile", "wood", "metal", "glass", "fabric",
                             "dirt", "water", "flesh", "armor", "shield")


# ============================================================ helpers


def _burst(rng: np.random.Generator, dur: float, kind: str, f: float, q: float, t60: float,
           attack: float = 0.0002, pink: bool = False) -> np.ndarray:
    """Filtered noise burst with an exponential decay (`kind` = lp / hp / bp)."""
    src = noise.pink(dur, rng) if pink else noise.white(dur, rng)
    if kind == "bp":
        y = filters.bp(src, f, q)
    elif kind == "lp":
        y = filters.lp(src, f, q)
    else:
        y = filters.hp(src, f, q)
    return y * env.exp_decay(dur, t60, attack)


def _scatter(rng: np.random.Generator, dur: float, count: int, start: float, spread: float,
             lo: float, hi: float, grain: tuple[float, float] = (0.001, 0.004)) -> np.ndarray:
    """Grit / debris scatter: `count` tiny band-passed noise ticks at start + exponential(spread)."""
    def make(_i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(*grain)
        g = filters.bp(r.standard_normal(nsamp(d)), r.uniform(lo, hi), 1.5)
        return g * np.hanning(g.shape[0]) * r.uniform(0.3, 1.0)

    times = np.clip(start + rng.exponential(spread, count), 0, dur - grain[1] - 0.001)
    return granular.cloud(dur, times, make, rng)


def _modes(rng: np.random.Generator, freqs: list[float], amps: list[float], t60s: list[float],
           dur: float) -> np.ndarray:
    """Resonant modes given as T60 decay times (osc.partials takes time constants)."""
    return osc.partials(freqs, amps, [t / 6.907755 for t in t60s], dur, rng)


def _finish(y: np.ndarray, out_s: float = 0.04, room: float = 0.0) -> np.ndarray:
    """Optional touch of the generated 'store' room (no tail), hard length cap, fade-out."""
    if room > 0:
        y = fx.reverb(y, "store", room, stereo_out=False, tail=False)
    return fade(y[: nsamp(MAX_S)], 0, out_s)


def _k(rng: np.random.Generator, v: int, step: float = 0.04) -> float:
    """Per-variation pitch scale: seeded spread plus a small deterministic step per variation."""
    return float(rng.uniform(0.95, 1.05)) * (1 + step * (v - 1.5))


# ============================================================ recipes


def impact_concrete(rng: np.random.Generator, v: int) -> np.ndarray:
    """Sharp crack + grit: 1.8 kHz-high-passed crack (4 ms), a 2.6 kHz snap, a small 120 Hz body
    and 30-45 bright grit grains (2-7 kHz) spilling over ~0.12 s. 0.32 s."""
    dur = 0.32
    k = _k(rng, v)
    y = _burst(rng, dur, "hp", 1800 * k, 0.7, 0.03) * 1.2
    y += _burst(rng, dur, "bp", 2600 * k, 1.2, 0.05) * 0.8
    y += thud(rng, 120 * k, dur, 0.4) * 0.35 * env.exp_decay(dur, 0.12)
    y += _scatter(rng, dur, int(rng.integers(30, 46)), 0.006, 0.045, 2000, 7000) * 0.5
    place(y, click(rng, (3400.0 * k, 5200.0 * k), 0.02, 5, 0.002, 0.8), 0)
    return _finish(y, 0.05, 0.06)


def impact_brick(rng: np.random.Generator, v: int) -> np.ndarray:
    """Duller crack: the crack low-passed at 3.4 kHz, a 1.1 kHz fired-clay body, a 150 Hz knock and
    a coarser, lower crumble (1-3.5 kHz grains, a little longer). 0.34 s."""
    dur = 0.34
    k = _k(rng, v)
    crack = filters.lp(_burst(rng, dur, "hp", 900 * k, 0.7, 0.035), 3400 * k)
    y = crack * 1.3
    y += _burst(rng, dur, "bp", 1100 * k, 1.6, 0.06) * 0.9
    y += thud(rng, 150 * k, dur, 0.6) * 0.5 * env.exp_decay(dur, 0.14)
    y += _scatter(rng, dur, int(rng.integers(18, 28)), 0.01, 0.06, 1000, 3500, (0.002, 0.006)) * 0.55
    return _finish(y, 0.05, 0.06)


def impact_plaster(rng: np.random.Generator, v: int) -> np.ndarray:
    """Soft puff thud: pink noise below 1.6 kHz with a 3 ms attack (the drywall/plaster "puff"),
    a 170 Hz thud and a faint high dust hiss trailing off. 0.3 s."""
    dur = 0.3
    k = _k(rng, v)
    puff = _burst(rng, dur, "lp", 1600 * k, 0.7, 0.09, attack=0.003, pink=True)
    y = puff * 1.4
    y += thud(rng, 170 * k, dur, 0.5) * 0.6 * env.exp_decay(dur, 0.12)
    dust = _burst(rng, dur, "hp", 4500, 0.7, 0.2, attack=0.02) * 0.08
    y += dust
    place(y, click(rng, (1400.0 * k,), 0.015, 4, 0.002, 0.25), 0)
    return _finish(y, 0.06)


def impact_tile(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bright click-crack: ceramic click modes (3.1/4.7/6.9 kHz), a 3 kHz high-passed crack, a short
    2.2/3.9 kHz glaze ring and a few chip tinkles (5-9 kHz). 0.28 s."""
    dur = 0.28
    k = _k(rng, v, 0.05)
    y = _burst(rng, dur, "hp", 3000 * k, 0.7, 0.02) * 1.0
    y += _modes(rng, [2200 * k, 3900 * k, 5600 * k], [0.7, 0.5, 0.25], [0.06, 0.04, 0.025], dur) * 0.5
    y += thud(rng, 260 * k, dur, 0.3) * 0.2 * env.exp_decay(dur, 0.06)
    y += _scatter(rng, dur, int(rng.integers(8, 15)), 0.015, 0.05, 5000, 9000, (0.002, 0.005)) * 0.5
    place(y, click(rng, (3100.0 * k, 4700.0 * k, 6900.0 * k), 0.03, 8, 0.004, 1.2), 0)
    return _finish(y, 0.04, 0.05)


def impact_wood(rng: np.random.Generator, v: int) -> np.ndarray:
    """Woody thock + splinter: a 210 Hz knock with 430/980/1750 Hz grain modes and a 800 Hz noise
    body, then 6-14 splinter crackles (1.5-4 kHz) over ~80 ms. 0.32 s."""
    dur = 0.32
    k = _k(rng, v)
    y = thud(rng, 210 * k, dur, 0.5) * 0.7 * env.exp_decay(dur, 0.15)
    y += _modes(rng, [430 * k, 980 * k, 1750 * k], [0.9, 0.55, 0.3], [0.09, 0.05, 0.03], dur) * 0.7
    y += _burst(rng, dur, "bp", 800 * k, 1.8, 0.04) * 0.8
    y += _scatter(rng, dur, int(rng.integers(6, 15)), 0.004, 0.03, 1500, 4000, (0.001, 0.003)) * 0.9
    place(y, click(rng, (2300.0 * k,), 0.02, 5, 0.002, 0.6), 0)
    return _finish(y, 0.05, 0.05)


def impact_metal(rng: np.random.Generator, v: int) -> np.ndarray:
    """Ping / ricochet: a hard tick and an inharmonic ring (2.3-9 kHz, 0.1-0.2 s) over a small
    knock. Variations _2 and _4 (v odd) add a ricochet whine: a sine gliding 3.4 -> 1.5 kHz with
    a slight wobble that swells then fades (the deflected round flying past). 0.4 s."""
    dur = MAX_S
    k = _k(rng, v, 0.06)
    ring = _modes(rng, [2310 * k, 3570 * k, 5240 * k, 7020 * k, 8900 * k], [1.0, 0.75, 0.5, 0.3, 0.18],
                  [0.22, 0.17, 0.12, 0.08, 0.05], dur)
    y = ring * 0.6
    y += thud(rng, 330 * k, dur, 0.3) * 0.25 * env.exp_decay(dur, 0.08)
    y += _burst(rng, dur, "hp", 3500, 0.7, 0.012) * 0.6
    place(y, click(rng, (4100.0 * k, 6800.0 * k), 0.03, 6, 0.003, 1.0), 0)
    if v % 2 == 1:
        t = tvec(dur)
        f0, f1 = 3400 * k * rng.uniform(0.95, 1.05), 1500 * k * rng.uniform(0.9, 1.1)
        f = f0 * (f1 / f0) ** np.clip(t / (dur * 0.9), 0, 1) * (1 + 0.012 * np.sin(2 * np.pi * 34 * t))
        swell = env.segments([(0, 0), (0.02, 0.0), (0.07, 1.0), (0.22, 0.55), (dur, 0.0)], dur)
        whine = osc.sine(f, dur) + 0.25 * osc.sine(f * 2.01, dur)
        whine += filters.bp(noise.white(dur, rng), 3000, 2.0) * 0.15
        y += whine * swell * 0.35
    return _finish(y, 0.06, 0.04)


def impact_glass(rng: np.random.Generator, v: int) -> np.ndarray:
    """Crack + tinkle: a 2 kHz-high-passed crack and 4.5/6.2 kHz click, a small 300 Hz knock, then
    a short cloud of 14-24 shard tinkles (3-10 kHz partials). Much smaller than glass_break
    (a pane hit, not a pane shattering). 0.38 s."""
    dur = 0.38
    k = _k(rng, v)
    y = _burst(rng, dur, "hp", 2000 * k, 0.7, 0.025) * 1.1
    y += thud(rng, 300 * k, dur, 0.4) * 0.3 * env.exp_decay(dur, 0.07)
    place(y, click(rng, (4500.0 * k, 6200.0 * k), 0.03, 7, 0.003, 1.0), 0)

    def shard(_i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(0.015, 0.07)
        base = r.uniform(3000, 9500)
        fr = [base, base * r.uniform(1.4, 1.9), base * r.uniform(2.3, 3.1)]
        return osc.partials(fr, [1.0, 0.55, 0.3], [d * 0.5, d * 0.3, d * 0.2], d, r) * r.uniform(0.3, 1.0)

    times = np.clip(0.008 + rng.exponential(0.06, int(rng.integers(14, 25))), 0, dur - 0.08)
    y += granular.cloud(dur, times, shard, rng) * 0.35
    return _finish(y, 0.05, 0.06)


def impact_fabric(rng: np.random.Generator, v: int) -> np.ndarray:
    """Muffled thup: pink noise low-passed at 650 Hz with a 2 ms attack, a 140 Hz body and a barely
    audible 2 kHz cloth brush. Nearly no highs. 0.22 s."""
    dur = 0.22
    k = _k(rng, v)
    y = _burst(rng, dur, "lp", 650 * k, 0.8, 0.07, attack=0.002, pink=True) * 1.5
    y += thud(rng, 140 * k, dur, 0.3) * 0.6 * env.exp_decay(dur, 0.09)
    y += _burst(rng, dur, "bp", 2000 * k, 1.0, 0.04, attack=0.003) * 0.05
    return _finish(y, 0.05)


def impact_dirt(rng: np.random.Generator, v: int) -> np.ndarray:
    """Soft thud + scatter: a 90 Hz thud with low brown-noise body, then 25-40 low-passed grit grains
    (0.6-2.5 kHz) falling back over ~0.2 s. 0.36 s."""
    dur = 0.36
    k = _k(rng, v)
    y = thud(rng, 90 * k, dur, 0.9) * 0.8 * env.exp_decay(dur, 0.18)
    y += _burst(rng, dur, "lp", 900 * k, 0.7, 0.06, attack=0.001, pink=True) * 0.9
    grit = _scatter(rng, dur, int(rng.integers(25, 41)), 0.02, 0.09, 600, 2500, (0.002, 0.006))
    y += filters.lp(grit, 3000) * 0.7
    return _finish(y, 0.06)


def impact_water(rng: np.random.Generator, v: int) -> np.ndarray:
    """Splash plop: a 2-6 kHz hiss burst (the spray), 6-12 droplet chirps (short sines rising
    ~40 %, 1.4-4 kHz) and the plop: a bubble resonance rising 380 -> 900 Hz over ~40 ms. 0.36 s."""
    dur = 0.36
    k = _k(rng, v)
    t = tvec(dur)
    y = filters.bp(_burst(rng, dur, "hp", 2000 * k, 0.7, 0.12, attack=0.002), 4000 * k, 0.6) * 0.9
    p0 = 0.006 + 0.004 * (v % 2)
    tp = np.maximum(t - p0, 0)
    fp = 380 * k * (1 + 1.4 * (1 - np.exp(-tp / 0.025)))
    plop = osc.sine(fp, dur) * np.exp(-tp / 0.035) * (t >= p0)
    y += plop * 0.9
    y += filters.lp(noise.brown(dur, rng), 400) * env.exp_decay(dur, 0.1) * 0.4

    def drop(_i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(0.01, 0.03)
        tt = np.arange(nsamp(d)) / SR
        f = r.uniform(1400, 4000) * (1 + 0.4 * tt / d)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (d * 0.35)) * r.uniform(0.3, 1.0)

    times = np.clip(0.03 + rng.exponential(0.07, int(rng.integers(6, 13))), 0, dur - 0.04)
    y += granular.cloud(dur, times, drop, rng) * 0.3
    return _finish(y, 0.06)


def impact_flesh(rng: np.random.Generator, v: int) -> np.ndarray:
    """Wet thud (not gory): a 115 Hz body thump, a damp 500 Hz noise slap and a softer 1.4 kHz
    "wet" layer with a 1 ms attack; no squelch, no crunch. Niche: lower and shorter than
    throwable_knife_hit (160 Hz, 0.45 s, blade twang). 0.26 s."""
    dur = 0.26
    k = _k(rng, v)
    y = thud(rng, 115 * k, dur, 0.6) * 0.9 * env.exp_decay(dur, 0.14)
    y += _burst(rng, dur, "bp", 500 * k, 1.4, 0.05, attack=0.0008) * 1.1
    y += _burst(rng, dur, "bp", 1400 * k, 2.0, 0.03, attack=0.001) * 0.35
    return _finish(y, 0.05)


def impact_armor(rng: np.random.Generator, v: int) -> np.ndarray:
    """Hard, dull clank (body armour plate): heavily damped plate modes 380/870/1450/2300 Hz
    (40-90 ms), a 130 Hz knock, a 1.8/2.9 kHz tick and light drive. Duller and shorter than metal
    and shield. 0.26 s."""
    dur = 0.26
    k = _k(rng, v)
    y = _modes(rng, [380 * k, 870 * k, 1450 * k, 2300 * k], [1.0, 0.8, 0.5, 0.3], [0.09, 0.07, 0.05, 0.04], dur)
    y += thud(rng, 130 * k, dur, 0.5) * 0.7 * env.exp_decay(dur, 0.1)
    y += _burst(rng, dur, "bp", 1200 * k, 1.2, 0.03) * 0.5
    place(y, click(rng, (1800.0 * k, 2900.0 * k), 0.02, 5, 0.002, 0.8), 0)
    return _finish(fx.drive(y, 1.4), 0.05)


def impact_shield(rng: np.random.Generator, v: int) -> np.ndarray:
    """Heavy metal clang (ballistic shield): thick steel plate modes 240-3700 Hz ringing 0.15-0.3 s,
    a 90 Hz knock and a bright 2.6/4.4 kHz clank, driven. Niche: a short clang, not bulwark_bang's
    1 s gong. 0.4 s."""
    dur = MAX_S
    k = _k(rng, v, 0.03)
    y = _modes(rng, [243 * k, 562 * k, 1018 * k, 1634 * k, 2481 * k, 3712 * k], [0.8, 1.0, 0.85, 0.6, 0.4, 0.25],
               [0.3, 0.28, 0.24, 0.2, 0.15, 0.1], dur) * 0.7
    y += thud(rng, 90 * k, dur, 0.8) * 0.8 * env.exp_decay(dur, 0.2)
    place(y, click(rng, (2600.0 * k, 4400.0 * k), 0.05, 8, 0.006, 1.0), 0)
    return _finish(fx.drive(y, 1.6), 0.08, 0.06)


# ============================================================ registry rows

# (surface, max_distance m, volume_db). Files are normalised to -18 LUFS like every SFX (the peakiest,
# concrete and tile, land 2-5 dB under it after limiting and get +1-2 dB back here); the mix
# lives here: impacts sit 3-9 dB under gunfire (0 dB), soft surfaces quieter and shorter-range,
# ringing metal carries furthest. Range is well under the 80-160 m gunshots (cf. glass_break 45 m).
_MIX: tuple[tuple[str, float, float], ...] = (
    ("concrete", 35.0, -4.0), ("brick", 35.0, -5.0), ("plaster", 25.0, -7.0), ("tile", 35.0, -3.0),
    ("wood", 35.0, -5.0), ("metal", 45.0, -4.0), ("glass", 40.0, -5.0), ("fabric", 20.0, -9.0),
    ("dirt", 25.0, -7.0), ("water", 30.0, -6.0), ("flesh", 25.0, -6.0), ("armor", 35.0, -4.0),
    ("shield", 45.0, -3.0),
)
_FN = {s: globals()[f"impact_{s}"] for s in SURFACES}

CUES: list[CueSpec] = [
    CueSpec(f"impact_{s}", _FN[s], bus="World", variations=4, max_distance=dist, volume_db=vol,
            pitch_jitter=0.06, cooldown_s=0.03, subdir="impact",
            note="impact_fx.md 1.0 (D-105, PO-8): bullet/melee impact, 3D at the hit point")
    for s, dist, vol in _MIX
]
assert [c.name for c in CUES] == [f"impact_{s}" for s in SURFACES]
