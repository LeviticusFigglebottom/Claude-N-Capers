"""Safehouse ("The Press") cues (C4-03; docs/design/heists/safehouse.md §Audio): the interior bed and five point
emitters. The bed is as cues_ambience.py (stereo, 2D, Ambience bus, loop, "bed" loudness, seamless via make_loop);
the emitters are mono 3D loops on the Ambience bus with a 6-10 m max distance (the G0: no more than 6 audible at
once). Built by tools/audiogen/build.py (it appends `CUES` to the cue table).

Bed:
  amb_safehouse_interior  the print works at 23:30 in steady rain: low building room tone (< 300 Hz), rain on the flat
                          roof (pink wash 400-8000 Hz) and drumming on the rooflight glass (sparse bright drops 2-6
                          kHz with a short glass ring), faint traffic through the north wall (< 400 Hz swells, one
                          tyre hiss per ~12 s), an occasional heating-pipe tick (1.2-2.4 kHz, every 5-11 s). Same
                          family as amb_glasshouse_interior. 36 s.
Emitters (each its own band so they stack in the lounge and the corridor):
  amb_fridge_hum          the lounge fridge: 50 Hz compressor hum with its 100 / 150 Hz harmonics, a soft 1.4 kHz
                          fan whir, one relay click and settle per loop. 16 s.
  amb_wall_clock          the lounge wall clock: a quiet 1 Hz tick (alternating 3.1 / 2.6 kHz, wood body 900 Hz). 8 s.
  amb_ballast_buzz        the workshop batten's ballast: 100 Hz buzz with odd harmonics, a slow flutter. 12 s.
  amb_drip                the WC basin: a slow irregular drip (water-drop pings 900-1800 Hz with a falling glide,
                          small-room reverb), about one per 1.6-3.2 s. 20 s.
  amb_range_extractor     the range vestibule's extractor: a fan (blade rate 38 Hz AM on 200-1200 Hz noise), the
                          motor's 25 Hz rumble, duct whistle at 2.2 kHz. Audible from the corridor. 16 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, click, make_loop
from synth import env, filters, fx, noise, osc
from synth.core import SR, nsamp, place

# ============================================================ helpers


def _drop(rng: np.random.Generator, f0: float, dur: float = 0.12) -> np.ndarray:
    """A water drop: a sine ping gliding down from f0 with a fast decay plus a tiny noise splash."""
    t = np.arange(nsamp(dur)) / SR
    f = f0 * (1.0 - 0.35 * np.clip(t / dur, 0, 1))
    ping = np.sin(2 * np.pi * np.cumsum(f) / SR) * env.exp_decay(dur, 0.03)
    splash = filters.bp(noise.white(dur, rng), f0 * 2.0, 2.0) * env.exp_decay(dur, 0.008) * 0.3
    return ping + splash


# ============================================================ bed


def amb_safehouse_interior(rng: np.random.Generator, v: int) -> np.ndarray:
    """The print works in steady rain (see the module docstring). 36 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        chans = []
        for c in range(2):
            tone = filters.lp(noise.brown(d, rng), 280) * 0.6 * (1 + 0.1 * env.lfo(0.06 + 0.01 * c, d, phase=c))
            rain = filters.lp(filters.hp(noise.pink(d, rng), 400), 8000) * 0.16
            traffic = filters.lp(noise.brown(d, rng), 380) * 0.25 * np.clip(env.lfo(0.05, d, phase=0.4 * c), 0, None)
            chans.append(tone + rain + traffic)
        out = np.stack(chans, axis=1)
        glass = np.zeros(n)
        for _ in range(int(d * 3.0)):
            t0 = float(rng.uniform(0, d - 0.2))
            f0 = float(rng.uniform(2000.0, 6000.0))
            place(glass, filters.bp(noise.white(0.05, rng), f0, 6.0) * env.exp_decay(0.05, 0.01), nsamp(t0),
                  float(rng.uniform(0.08, 0.2)))
        out += fx.pan(fx.reverb(glass, "store", 0.25, stereo_out=False, tail=False)[:n], 0.1)
        hiss = np.zeros(n)
        for k in range(int(d / 12.0)):
            t0 = 2.0 + 12.0 * k + float(rng.uniform(0, 4.0))
            dur = 3.0
            if t0 + dur < d:
                sw = filters.biquad_tv(noise.white(dur, rng), "bp", 900 + 700 * env.lfo(0.3, dur), 0.8)
                place(hiss, filters.lp(sw, 1600) * env.adsr(dur, 1.2, 0.2, 0.6, 1.4), nsamp(t0), 0.12)
        out += fx.pan(hiss, -0.3)
        tick = np.zeros(n)
        t0 = float(rng.uniform(1.0, 4.0))
        while t0 < d - 0.3:
            place(tick, click(rng, (1200.0, 1900.0, 2400.0), 0.06, 12, 0.01, 1.0), nsamp(t0), 0.3)
            t0 += float(rng.uniform(5.0, 11.0))
        out += fx.pan(fx.reverb(tick, "hall", 0.4, stereo_out=False, tail=False)[:n], 0.35)
        return out
    return make_loop(render, 36.0, 1.5)


# ============================================================ point emitters (mono, 3D)


def amb_fridge_hum(rng: np.random.Generator, v: int) -> np.ndarray:
    """Lounge fridge: 50 Hz compressor hum + harmonics, a soft fan whir, one relay click per loop. 16 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        hum = osc.sine(50, d) * 0.5 + osc.sine(100, d) * 0.3 + osc.sine(150, d) * 0.12
        hum *= 1 + 0.05 * env.lfo(0.3, d)
        whir = filters.bp(noise.pink(d, rng), 1400, 1.5) * 0.08
        y = hum + whir
        place(y, click(rng, (800.0, 1500.0), 0.05, 10, 0.012, 1.0), nsamp(d * 0.4), 0.3)
        return y[:n]
    return make_loop(render, 16.0, 0.8)


def amb_wall_clock(rng: np.random.Generator, v: int) -> np.ndarray:
    """Lounge wall clock: a quiet 1 Hz tick (alternating 3.1 / 2.6 kHz on a 900 Hz wood body). 8 s loop."""
    d = 8.0
    n = nsamp(d)
    y = np.zeros(n)
    for k in range(int(d)):
        f = 3100.0 if k % 2 == 0 else 2600.0
        tk = filters.bp(noise.white(0.04, rng), f, 5.0) * env.exp_decay(0.04, 0.008)
        tk += osc.sine(900.0, 0.04) * env.exp_decay(0.04, 0.012) * 0.4
        place(y, tk, nsamp(float(k)), 0.6)
    return y


def amb_ballast_buzz(rng: np.random.Generator, v: int) -> np.ndarray:
    """Workshop batten ballast: 100 Hz buzz with odd harmonics and a slow flutter. 12 s loop."""
    def render(d: float) -> np.ndarray:
        buzz = osc.square(100, d, 0.5) * 0.15 + osc.sine(300, d) * 0.05 + osc.sine(500, d) * 0.03
        buzz = filters.lp(buzz, 2600) * (1 + 0.25 * env.lfo(0.7, d) + 0.1 * env.lfo(3.1, d))
        return buzz + filters.hp(noise.pink(d, rng), 3000) * 0.01
    return make_loop(render, 12.0, 0.6)


def amb_drip(rng: np.random.Generator, v: int) -> np.ndarray:
    """WC basin drip: irregular drops (900-1800 Hz pings with a falling glide) in a small room. 20 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        y = np.zeros(n)
        t0 = float(rng.uniform(0.2, 1.0))
        while t0 < d - 0.2:
            place(y, _drop(rng, float(rng.uniform(900.0, 1800.0))), nsamp(t0), float(rng.uniform(0.5, 0.9)))
            t0 += float(rng.uniform(1.6, 3.2))
        return fx.reverb(y, "small_office", 0.35, stereo_out=False, tail=False)[:n]
    return make_loop(render, 20.0, 0.4)


def amb_range_extractor(rng: np.random.Generator, v: int) -> np.ndarray:
    """Range vestibule extractor fan: blade-rate (38 Hz) AM on 200-1200 Hz noise, 25 Hz motor rumble, a 2.2 kHz duct
    whistle. 16 s loop."""
    def render(d: float) -> np.ndarray:
        fan = filters.bp(noise.pink(d, rng), 600, 0.6) * 0.5 * (1 + 0.3 * env.lfo(38.0, d))
        motor = filters.lp(noise.brown(d, rng), 120) * 0.4 + osc.sine(25.0, d) * 0.15
        whistle = osc.sine(2200.0, d) * 0.015 * (1 + 0.4 * env.lfo(0.2, d))
        return fan + motor + whistle
    return make_loop(render, 16.0, 0.8)


# ============================================================ registry rows

CUES: list[CueSpec] = [
    CueSpec("amb_safehouse_interior", amb_safehouse_interior, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed", note="C4-03 safehouse interior bed (CueEmitter-owned map loop)"),
    CueSpec("amb_fridge_hum", amb_fridge_hum, bus="Ambience", loop=True, volume_db=-16.0, max_distance=6.0,
            note="C4-03 safehouse point emitter: lounge fridge (3D loop, CueEmitter)"),
    CueSpec("amb_wall_clock", amb_wall_clock, bus="Ambience", loop=True, volume_db=-20.0, max_distance=6.0,
            note="C4-03 safehouse point emitter: lounge wall clock (3D loop, CueEmitter)"),
    CueSpec("amb_ballast_buzz", amb_ballast_buzz, bus="Ambience", loop=True, volume_db=-20.0, max_distance=6.0,
            note="C4-03 safehouse point emitter: workshop batten ballast (3D loop, CueEmitter)"),
    CueSpec("amb_drip", amb_drip, bus="Ambience", loop=True, volume_db=-18.0, max_distance=6.0,
            note="C4-03 safehouse point emitter: WC basin drip (3D loop, CueEmitter)"),
    CueSpec("amb_range_extractor", amb_range_extractor, bus="Ambience", loop=True, volume_db=-14.0,
            max_distance=10.0, note="C4-03 safehouse point emitter: range vestibule extractor, heard from the corridor"),
]
