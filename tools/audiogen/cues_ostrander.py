"""Ostrander Federal cues (OF-C2): the four ambience beds of the heist doc (Audio/lighting) and the per-heist alarm
bell `cue.alarm_bell_ostrander_federal` (CuePlayer resolves cue.alarm_bell_<heist>). Beds are as cues_ambience.py
(stereo, 2D, Ambience bus, loop, "bed" loudness, seamless via make_loop). Built by tools/audiogen/build.py (it appends
`CUES` to the cue table).

Niches (each bed keeps its own band / rhythm so two can overlap at a doorway):
  amb_bank_hall_day      the banking hall in business hours: a large stone room. Footsteps on marble (heel clicks
                         2-5 kHz in the hall reverb), soft murmurs (formant babble 300-2500 Hz), note counters
                         (35 Hz flutter bursts) and a receipt printer at the counter, a pneumatic-tube thunk every
                         40-90 s (one per loop), the hall clock (tick every 2 s, 1.9 kHz). 64 s.
  amb_bank_boh           back of house: HVAC < 350 Hz, fluorescent 100 Hz buzz with odd harmonics, two distant
                         phone trills (dual-tone 440 / 480 Hz, damped by a wall). 30 s.
  amb_vault              the vault: low ventilation (< 200 Hz, a slow 0.05 Hz breath), the time lock's clockwork
                         escapement (a 4 Hz movement tick, 3.1 kHz, in a dead small room). 24 s.
  amb_city_afternoon     the plaza / avenue / lane: traffic with wet tyres (hiss 1.8-5 kHz), a bus pulling away
                         (diesel 70-140 Hz swell), pigeons cooing on the plaza (300-700 Hz warbles) and wing claps.
                         40 s.
  alarm_bell_ostrander_federal  a deep two-tone bank bell: a 15 Hz striker alternating between two large gongs a
                         minor third apart (f0 380 / 452 Hz, inharmonic partials to 2.6 kHz), 1 s per tone. 2 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, click, make_loop
from cues_ambience import _car_pass, _hvac
from synth import env, filters, fx, noise, osc
from synth.core import SR, loop_xfade, nsamp, place

# ============================================================ helpers


def _heel(rng: np.random.Generator) -> np.ndarray:
    """One heel strike on marble: a short band-passed click with a little body."""
    d = 0.09
    y = filters.bp(noise.white(d, rng), float(rng.uniform(2400, 4200)), 3.0) * env.exp_decay(d, 0.012, 0.0005)
    y += filters.lp(noise.white(d, rng), 600) * env.exp_decay(d, 0.02) * 0.4
    return y


def _footsteps(rng: np.random.Generator, n: int, d: float, walkers: int) -> np.ndarray:
    out = np.zeros((n, 2))
    for _ in range(walkers):
        t = float(rng.uniform(0.0, d * 0.5))
        dur = float(rng.uniform(5.0, 12.0))
        rate = float(rng.uniform(1.6, 2.0))
        lvl = float(rng.uniform(0.08, 0.18))
        p0 = float(rng.uniform(-0.8, 0.8))
        p1 = float(np.clip(p0 + rng.uniform(-0.8, 0.8), -0.9, 0.9))
        k = 0
        while k / rate < dur and t + k / rate < d - 0.2:
            pp = p0 + (p1 - p0) * (k / rate) / dur
            place(out, fx.pan(_heel(rng) * lvl, pp), nsamp(t + k / rate))
            k += 1
    return out


def _murmur(d: float, rng: np.random.Generator, level: float = 0.15) -> np.ndarray:
    """Distant voices: pink noise through two drifting formants, syllable-rate (4-6 Hz) gating."""
    n = nsamp(d)
    src = noise.pink(d, rng)
    y = filters.bp(src, 520, 2.0) * 0.6 + filters.bp(src, 1450, 2.5) * 0.35 + filters.bp(src, 2400, 3.0) * 0.15
    gate = np.clip(0.4 + 0.6 * env.lfo(4.7, d) * env.lfo(0.31, d, phase=0.4), 0, None)
    gate = filters.lp(gate, 12.0)
    return y[:n] * gate[:n] * level


def _note_counter(rng: np.random.Generator) -> np.ndarray:
    """A note counter riffling a strap: 35 Hz flutter of paper ticks over a motor whirr, ~1.2 s."""
    d = 1.3
    n = nsamp(d)
    y = np.zeros(n)
    for i in range(int(1.1 * 35)):
        place(y, filters.bp(noise.white(0.01, rng), 3200, 2.0) * env.exp_decay(0.01, 0.003), nsamp(0.05 + i / 35.0),
              float(rng.uniform(0.5, 1.0)))
    t = np.arange(n) / SR
    y += osc.saw(180 + 40 * np.clip(t / 0.15, 0, 1), d) * 0.04 * env.adsr(d, 0.08, 0.1, 0.8, 0.15)
    return filters.lp(y, 6000)


def _printer(rng: np.random.Generator) -> np.ndarray:
    """Receipt printer: a buzzy 1.1 kHz line-feed rasp in four strokes, then a cutter snip."""
    out = np.zeros(nsamp(1.2))
    for k in range(4):
        d = 0.16
        y = filters.bp(osc.square(55, d, 0.5) + noise.white(d, rng) * 0.5, 1100, 1.5) * env.adsr(d, 0.005, 0.02, 0.8,
                                                                                                0.03)
        place(out, y, nsamp(k * 0.2), 0.35)
    place(out, click(rng, (4800.0, 6900.0), 0.05, 8, 0.01, 0.5), nsamp(0.9))
    return out


def _tube_thunk(rng: np.random.Generator) -> np.ndarray:
    """Pneumatic tube carrier arriving: an air whoosh rising, a hollow thunk (110 Hz body), a latch."""
    d = 1.8
    n = nsamp(d)
    t = np.arange(n) / SR
    whoosh = filters.biquad_tv(noise.pink(d, rng), "bp", 300 + 1800 * np.clip(t / 1.0, 0, 1), 1.2)
    whoosh *= np.clip(t / 1.0, 0, 1) ** 2 * (t < 1.05)
    thunk = osc.sine(110 * (1 + 0.3 * np.exp(-(t - 1.05).clip(0) / 0.02)), d) * np.exp(-(t - 1.05).clip(0) / 0.09)
    thunk *= t >= 1.05
    y = whoosh * 0.4 + thunk * 0.9
    place(y, click(rng, (2100.0, 3300.0), 0.06, 8, 0.015, 0.5), nsamp(1.35))
    return y


def _phone_trill(rng: np.random.Generator) -> np.ndarray:
    """Office phone two-burst ring (440 + 480 Hz dual tone, 0.4 s on / 0.2 s off / 0.4 s on), wall-damped."""
    out = np.zeros(nsamp(1.2))
    for k in range(2):
        d = 0.4
        y = (osc.sine(440, d) + osc.sine(480, d)) * env.adsr(d, 0.01, 0.05, 0.9, 0.03)
        y *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 20 * np.arange(nsamp(d)) / SR))
        place(out, y, nsamp(k * 0.6), 0.5)
    return filters.lp(out, 1600)


def _pigeon(rng: np.random.Generator) -> np.ndarray:
    """A pigeon coo: a warbling 350-650 Hz tone with a throaty roll, ~0.9 s."""
    d = 0.9
    n = nsamp(d)
    t = np.arange(n) / SR
    f = 420 + 160 * np.sin(np.pi * t / d) + 25 * np.sin(2 * np.pi * 14 * t)
    y = osc.sine(f, d) * env.adsr(d, 0.08, 0.2, 0.6, 0.3) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * t) ** 2)
    return filters.lp(y + filters.bp(noise.pink(d, rng), 500, 2.0) * 0.1, 1400)


def _wing_claps(rng: np.random.Generator) -> np.ndarray:
    out = np.zeros(nsamp(1.0))
    for k in range(6):
        d = 0.05
        place(out, filters.bp(noise.white(d, rng), 1800, 1.0) * env.exp_decay(d, 0.012), nsamp(k * 0.11),
              0.6 - 0.07 * k)
    return out


# ============================================================ beds


def amb_bank_hall_day(rng: np.random.Generator, v: int) -> np.ndarray:
    """The banking hall in business hours (doc: footsteps on marble, murmurs, note counters and printers, a
    pneumatic-tube thunk every 40-90 s, the hall clock). 64 s loop: one tube arrival, the clock every 2 s."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_hvac(d, rng, 260, 0.35, c) for c in range(2)], axis=1)
        out += np.stack([_murmur(d, rng, 0.14), _murmur(d, rng, 0.14)], axis=1)
        dry = _footsteps(rng, n, d, 9)
        for t0 in rng.uniform(1.0, d - 2.0, 7):
            place(dry, fx.pan(_note_counter(rng), float(rng.uniform(-0.6, 0.6))), nsamp(float(t0)), 0.22)
        for t0 in rng.uniform(1.0, d - 2.0, 3):
            place(dry, fx.pan(_printer(rng), float(rng.uniform(-0.5, 0.5))), nsamp(float(t0)), 0.25)
        place(dry, fx.pan(_tube_thunk(rng), 0.45), nsamp(float(rng.uniform(18.0, 40.0))), 0.4)
        clock = np.zeros(n)
        for k in range(int(d / 2.0) + 1):
            dur = 0.05
            tk = filters.bp(noise.white(dur, rng), 1900.0, 4.0) * env.exp_decay(dur, 0.015, 0.0003)
            place(clock, tk, nsamp(2.0 * k), 0.25)
        place(dry, fx.pan(clock, -0.35), 0)
        out += fx.reverb(dry, "hall", 0.6, tail=False)[:n]
        return out
    return make_loop(render, 64.0, 2.0)


def amb_bank_boh(rng: np.random.Generator, v: int) -> np.ndarray:
    """Back of house: HVAC, fluorescents (100 Hz buzz, odd harmonics), two distant phone trills. 30 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_hvac(d, rng, 340, 0.75, c) for c in range(2)], axis=1)
        buzz = osc.square(100, d, 0.5) * 0.018 + osc.sine(300, d) * 0.008 + osc.sine(500, d) * 0.005
        out += fx.pan(filters.lp(buzz, 2000) * (1 + 0.15 * env.lfo(0.7, d)), 0.15)
        far = np.zeros((n, 2))
        for t0, p in ((float(rng.uniform(3.0, 10.0)), -0.6), (float(rng.uniform(16.0, 24.0)), 0.5)):
            ph = np.zeros(nsamp(3.2))
            for k in range(2):
                place(ph, _phone_trill(rng), nsamp(k * 2.0))
            place(far, fx.pan(ph, p), nsamp(t0), 0.12)
        out += fx.reverb(far, "small_office", 0.6, tail=False)[:n]
        return out
    return make_loop(render, 30.0, 1.0)


def amb_vault(rng: np.random.Generator, v: int) -> np.ndarray:
    """The vault: low ventilation with a slow breath and the time lock's clockwork escapement (4 Hz tick in a
    dead room; the stem's tightening clock lives in the music). 24 s loop (the tick period divides it)."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_hvac(d, rng, 200, 0.9, c) for c in range(2)], axis=1)
        out *= (1 + 0.25 * env.lfo(0.05, d))[:, None]
        tick = np.zeros(n)
        for k in range(int(d * 4) + 1):
            dur = 0.03
            f = 3100.0 if k % 2 == 0 else 2600.0
            tk = filters.bp(noise.white(dur, rng), f, 6.0) * env.exp_decay(dur, 0.006, 0.0002)
            place(tick, tk, nsamp(k * 0.25), 0.18 if k % 4 else 0.26)
        out += fx.reverb(fx.pan(tick, 0.2), "small_office", 0.3, tail=False)[:n]
        return out
    return make_loop(render, 24.0, 1.0)


def amb_city_afternoon(rng: np.random.Generator, v: int) -> np.ndarray:
    """Daytime city on wet streets: traffic with tyre hiss, a bus pulling away, pigeons on the plaza. 40 s."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([filters.lp(noise.brown(d, rng), 220) * 0.5 for _ in range(2)], axis=1)
        out += _car_pass(rng, n, d, wet=0.5) * 0.9
        out += _car_pass(rng, n, d, wet=0.4) * 0.5
        bd = 9.0
        t = np.arange(nsamp(bd)) / SR
        f = 70 + 70 * np.clip(t / 5.0, 0, 1)
        bus = filters.lp(osc.saw(f, bd) + osc.square(f * 0.5, bd) * 0.5, 400) * env.adsr(bd, 1.5, 1.0, 0.8, 3.0)
        bus += filters.bp(noise.pink(bd, rng), 2500, 0.8) * 0.15 * env.adsr(bd, 0.05, 0.6, 0.0, 0.1)  # air brakes off
        place(out, fx.pan(bus * 0.25, np.linspace(-0.3, 0.7, nsamp(bd))), nsamp(float(rng.uniform(5.0, 22.0))))
        birds = np.zeros((n, 2))
        for t0 in rng.uniform(0.5, d - 2.0, 11):
            place(birds, fx.pan(_pigeon(rng), float(rng.uniform(-0.7, 0.7))), nsamp(float(t0)),
                  float(rng.uniform(0.05, 0.12)))
        for t0 in rng.uniform(1.0, d - 2.0, 2):
            place(birds, fx.pan(_wing_claps(rng), float(rng.uniform(-0.5, 0.5))), nsamp(float(t0)), 0.12)
        out += fx.reverb(birds, "alley", 0.3, tail=False)[:n]
        return out
    return make_loop(render, 40.0, 2.0)


# ============================================================ alarm


def alarm_bell_ostrander_federal(rng: np.random.Generator, v: int) -> np.ndarray:
    """Deep two-tone bank bell: a 15 Hz striker on two large gongs a minor third apart (380 / 452 Hz), one second
    each. Niche: lower and slower than Golden Hour's 18 Hz shop bell (1.3 kHz) and the generic 520 Hz horn.
    Seamless 2 s loop."""
    loop = 2.0
    rate = 15.0
    ring = 1.4
    ratios = (1.0, 1.59, 2.14, 2.76, 3.52, 4.9, 6.3)
    amps = (1.0, 0.75, 0.55, 0.45, 0.3, 0.2, 0.12)
    decays = (1.2, 0.7, 0.5, 0.35, 0.22, 0.14, 0.09)
    strikes = []
    for f0 in (380.0, 452.0):
        s = osc.partials([f0 * r for r in ratios], list(amps), list(decays), ring, rng)
        s += click(rng, (2600.0, 4100.0), ring, 6, 0.004, 0.18)
        strikes.append(s)
    total = loop + ring
    y = np.zeros(nsamp(total))
    for i in range(int(rate * total)):
        tone = int((i / rate) % 2.0 >= 1.0)
        jitter = rng.normal(0, 0.0012)
        place(y, strikes[tone] * rng.uniform(0.85, 1.0), nsamp(i / rate + max(jitter, -0.001)))
    y = loop_xfade(y, nsamp(loop), nsamp(0.5))
    y = filters.lp(y, 5200)
    return fx.drive(y * 0.18, 1.3)


# ============================================================ registry rows

_BEDS = (
    ("amb_bank_hall_day", amb_bank_hall_day, -14.0, "interior (hall, business hours)"),
    ("amb_bank_boh", amb_bank_boh, -15.0, "interior (back of house)"),
    ("amb_vault", amb_vault, -15.0, "interior (vault, VC / VT)"),
    ("amb_city_afternoon", amb_city_afternoon, -12.0, "exterior"),
)

CUES: list[CueSpec] = [
    CueSpec(name, fn, bus="Ambience", positional=False, loop=True, volume_db=vol, norm="bed",
            note=f"OF-C2 ostrander_federal {role} bed (CueEmitter-owned map loop)")
    for name, fn, vol, role in _BEDS
] + [
    CueSpec("alarm_bell_ostrander_federal", alarm_bell_ostrander_federal, loop=True, max_distance=70.0, volume_db=-3.0,
            note="per-heist variant of cue.alarm_bell (CuePlayer resolves cue.alarm_bell_<heist>)"),
]
