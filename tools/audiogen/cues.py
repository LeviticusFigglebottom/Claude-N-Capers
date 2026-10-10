"""P1 sound-effect recipes + their registry metadata.

Every recipe is `fn(rng, variant_index) -> np.ndarray` (mono (n,) or stereo (n, 2), float, any
level: build.py normalises loudness). Readability rule (style guide §9): each cue sits in its own
frequency/rhythm niche; the niche is noted in each docstring and checked on the spectrogram sheet.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np

from synth import env, filters, fx, granular, noise, osc, seq
from synth.core import SR, fade, fit, loop_xfade, midi_hz, nsamp, place, rng_for, stereo, tvec


@dataclass(frozen=True)
class CueSpec:
    name: str                       # folder + file stem: sfx_<name>[_<n>].ogg ; cue id = cue.<name>
    fn: Callable[[np.random.Generator, int], np.ndarray]
    bus: str = "World"
    positional: bool = True
    variations: int = 1
    loop: bool = False
    volume_db: float = 0.0
    max_distance: float = 40.0
    pitch_jitter: float = 0.0       # +- fraction of pitch_scale (0.04 = +-4 %)
    cooldown_s: float = 0.0
    norm: str = "sfx"               # loudness class (see build.py TARGETS)
    note: str = ""

    @property
    def cue_id(self) -> str:
        return "cue." + self.name


# ============================================================ helpers


def click(rng: np.random.Generator, freqs: tuple[float, ...], dur: float = 0.04, q: float = 10.0,
          decay: float = 0.012, level: float = 1.0) -> np.ndarray:
    """Metallic click (latches, pins, slides, hammers): a 1 ms noise tick plus a bank of damped
    resonant modes. `q` scales the ring time (q/10 x decay)."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        d = decay * (q / 10.0) * rng.uniform(0.7, 1.3)
        out += np.sin(2 * np.pi * f * rng.uniform(0.97, 1.03) * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
    k = min(n, nsamp(0.001))
    out[:k] += filters.hp(rng.standard_normal(k), 2000) * np.linspace(0.6, 0.0, k)
    return out * np.minimum(t / 0.0003, 1.0) * level * 0.6


def thud(rng: np.random.Generator, f0: float = 90.0, dur: float = 0.35, noise_amt: float = 0.6) -> np.ndarray:
    t = tvec(dur)
    body = osc.sine(f0 * (1 + 0.8 * np.exp(-t / 0.02)), dur) * env.exp_decay(dur, dur * 0.6, 0.001)
    nz = filters.lp(noise.brown(dur, rng), 600) * env.exp_decay(dur, 0.08)
    return body + nz * noise_amt


def whoosh(rng: np.random.Generator, dur: float, f0: float, f1: float, f2: float, q: float = 1.5) -> np.ndarray:
    n = nsamp(dur)
    f = np.concatenate([np.geomspace(f0, f1, n // 2), np.geomspace(f1, f2, n - n // 2)])
    y = filters.biquad_tv(noise.pink(dur, rng), "bp", f, q)
    e = np.sin(np.linspace(0, np.pi, n)) ** 2
    return y * e


def radio_chatter(rng: np.random.Generator, dur: float, syllable_rate: float = 7.0) -> np.ndarray:
    """Unintelligible procedural 'speech': formant-filtered glottal pulses with a random prosody,
    band-limited to a radio (300 Hz - 3 kHz), with squelch bursts at both ends."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    pitch = 125 + 30 * np.sin(2 * np.pi * 0.7 * t + rng.uniform(0, 6)) + 12 * np.sin(2 * np.pi * 3.1 * t)
    voice = osc.saw(pitch, dur) + 0.3 * noise.white(dur, rng)
    vowels = ["a", "e", "o", "uh", "i", "u"]
    out = np.zeros(n)
    pos = 0.12
    while pos < dur - 0.2:
        sl = rng.uniform(0.5, 1.3) / syllable_rate
        v0, v1 = rng.choice(vowels), rng.choice(vowels)
        a = int(pos * SR)
        b = min(n, a + nsamp(sl))
        seg = filters.formant(voice[a:b], str(v0), str(v1), 6.0)
        seg *= np.sin(np.linspace(0, np.pi, b - a)) ** 0.6
        out[a:b] += seg
        pos += sl + (rng.uniform(0.02, 0.06) if rng.random() < 0.8 else rng.uniform(0.15, 0.3))
    out = filters.hp(filters.lp(out, 2800), 350)
    out = fx.drive(out * 3.0, 2.5)
    static = filters.bp(noise.white(dur, rng), 1800, 0.4) * 0.12
    sq = np.zeros(n)
    for s0 in (0.0, dur - 0.1):
        k0 = nsamp(s0)
        burst = filters.bp(noise.white(0.1, rng), 2500, 0.8) * env.exp_decay(0.1, 0.09)
        place(sq, burst, k0, 0.8)
    return out + static + sq


def make_loop(render: Callable[[float], np.ndarray], loop_s: float, xfade_s: float = 0.25) -> np.ndarray:
    return loop_xfade(render(loop_s + xfade_s + 0.01), nsamp(loop_s), nsamp(xfade_s))


# ============================================================ stealth / detection


def detect_tick(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: 2-3 kHz, 60 ms, soft. Runtime pitch_scale follows the detection meter."""
    dur = 0.07
    t = tvec(dur)
    y = osc.sine(2100 * (1 + 0.12 * t / dur), dur) * env.exp_decay(dur, 0.05, 0.002)
    y += osc.sine(4200, dur) * env.exp_decay(dur, 0.02, 0.001) * 0.2
    return fade(y, 0, 0.01)


def detect_full(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: broadband sting, dissonant tritone stab 0.9 s, sharp attack (the "!")."""
    dur = 1.0
    t = tvec(dur)
    stab = np.zeros(nsamp(dur))
    for f in (740.0, 1046.5, 1480.0):
        stab += osc.saw(f * (1 + 0.02 * np.exp(-t / 0.05)), dur, float(rng.random()))
    stab = filters.biquad_tv(stab, "lp", 1500 + 7000 * env.exp_decay(dur, 0.4), 1.4)
    stab *= env.adsr(dur, 0.002, 0.25, 0.35, 0.5)
    hit = osc.fm(1760, 1.41, 4 * env.exp_decay(dur, 0.2), dur) * env.exp_decay(dur, 0.6, 0.001)
    low = thud(rng, 70, dur, 0.4)
    y = stab * 0.5 + hit * 0.35 + low * 0.6
    return fx.reverb(fx.drive(y, 1.4), "plate", 0.18, stereo_out=True, tail=False)


def npc_suspicious(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: voice band 150 Hz-2.5 kHz, rising-pitch "huh?" (vocal-ish formant synth)."""
    dur = 0.5
    n = nsamp(dur)
    t = tvec(dur)
    f0 = 135 + 70 * (t / dur) ** 1.6 + 3 * np.sin(2 * np.pi * 6 * t)
    glottal = osc.saw(f0, dur) * 0.8 + osc.triangle(f0, dur) * 0.4
    breath = filters.bp(noise.white(dur, rng), 1500, 0.7)
    h_env = env.segments([(0, 0), (0.02, 1), (0.08, 0.3), (0.12, 0.0), (dur, 0)], dur)
    v_env = env.segments([(0, 0), (0.07, 0), (0.12, 1), (0.36, 0.9), (dur, 0)], dur)
    src = glottal * v_env + breath * (h_env * 0.6 + v_env * 0.05)
    y = filters.formant(src, "uh", "a", 7.0) + filters.formant(src, "uh", "e", 9.0) * 0.4
    return fit(fade(y, 0.005, 0.06), n)


def pager_beep(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: 2.1/2.8 kHz square two-tone, 6 Hz rhythm (hi-lo-hi-lo, gap). Seamless 1.0 s loop."""
    loop = 1.0
    y = np.zeros(nsamp(loop))
    for i, (start, f) in enumerate(((0.0, 2800.0), (0.11, 2100.0), (0.22, 2800.0), (0.33, 2100.0))):
        b = osc.square(f, 0.09, 0.5) * env.adsr(0.09, 0.002, 0.05, 0.9, 0.01)
        place(y, b, nsamp(start))
    y = filters.bp(y, 2400, 0.9) + y * 0.15  # tiny piezo speaker
    return y


def pager_radio(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: 300 Hz-3 kHz band-limited static + squelch + garbled dispatcher. 6 s loop."""
    loop = 6.0

    def render(d: float) -> np.ndarray:
        static = filters.hp(filters.lp(noise.white(d, rng), 3200), 300) * 0.25
        static *= 1 + 0.3 * env.lfo(0.37, d) + 0.15 * env.lfo(2.3, d, phase=0.2)
        cr = filters.bp(noise.crackle(d, rng, 60), 2200, 1.0) * 1.5
        chat = np.zeros(nsamp(d))
        place(chat, radio_chatter(rng, 2.2), nsamp(0.6), 0.6)
        place(chat, radio_chatter(rng, 1.6), nsamp(3.6), 0.5)
        return static + cr + chat
    return make_loop(render, loop, 0.3)


# ============================================================ alarms


def alarm_bell(rng: np.random.Generator, v: int) -> np.ndarray:
    """Generic building alarm (temporal-3 fire-alarm horn). Niche: buzzy 520 Hz + harmonics,
    0.5 s on/off pattern. Seamless 4 s loop."""
    loop = 4.0
    y = np.zeros(nsamp(loop))
    for k in range(3):
        d = 0.5
        b = osc.square(520, d, 0.35) + osc.square(1040, d, 0.4) * 0.3
        b = filters.peak(filters.bp(b, 1600, 0.6), 3100, 6, 2.0) * env.adsr(d, 0.005, 0.1, 0.95, 0.01)
        place(y, b, nsamp(k * 1.0))
    return fx.reverb(y, "small_office", 0.15, stereo_out=False, tail=False)


def alarm_bell_glasshouse(rng: np.random.Generator, v: int) -> np.ndarray:
    """Classic shop alarm bell: an 18 Hz striker hammering a steel gong. Niche: inharmonic bell
    partials 1.3-6 kHz with an 18 Hz rattle rhythm. Seamless 2 s loop (36 strikes)."""
    loop = 2.0
    rate = 18.0
    ring = 0.9
    ratios = (1.0, 1.53, 2.0, 2.74, 3.1, 4.3)
    f0 = 1320.0
    amps = (1.0, 0.7, 0.45, 0.5, 0.3, 0.2)
    decays = (0.6, 0.35, 0.3, 0.22, 0.15, 0.1)
    strike = osc.partials([f0 * r for r in ratios], list(amps), list(decays), ring, rng)
    strike += click(rng, (5200.0, 7400.0), ring, 6, 0.004, 0.25)
    total = loop + ring
    y = np.zeros(nsamp(total))
    for i in range(int(rate * total)):
        jitter = rng.normal(0, 0.0012)
        place(y, strike * rng.uniform(0.85, 1.0), nsamp(i / rate + max(jitter, -0.001)))
    y = loop_xfade(y, nsamp(loop), nsamp(0.5))
    y *= 1 + 0.05 * np.sin(2 * np.pi * 0.5 * np.arange(y.shape[0]) / SR)
    return fx.drive(y * 0.2, 1.3)


def police_siren_far(rng: np.random.Generator, v: int) -> np.ndarray:
    """Distant dopplered siren bed: two cars (wail + yelp) driving back and forth ~150-260 m
    away. Niche: 600-1500 Hz slow sweeps, distant/dark. Stereo 24 s loop."""
    loop = 24.0
    xf = 1.0
    out_len = loop + xf
    pre = 2.0
    src_d = out_len + 2 * pre
    ts = np.arange(nsamp(src_d)) / SR - pre
    # car A: wail 4 s period (6 cycles / loop) ; car B: yelp 0.4 s period, offset
    wail_f = 1050 + 420 * np.sin(2 * np.pi * ts / 4.0 - np.pi / 2)
    yelp_f = 1000 + 380 * np.sin(2 * np.pi * ts / 0.4)
    a = osc.square(wail_f, src_d, 0.5) * 0.4 + osc.saw(wail_f, src_d) * 0.4
    b = osc.square(yelp_f, src_d, 0.45) * 0.4 + osc.saw(yelp_f * 1.003, src_d) * 0.4
    a = filters.bp(a, 1200, 0.5)
    b = filters.bp(b, 1150, 0.5)
    tout = np.arange(nsamp(out_len)) / SR
    path_a = np.stack([140 * np.sin(2 * np.pi * tout / loop), np.full(tout.shape, 170.0)], axis=1)
    path_b = np.stack([-170 * np.sin(2 * np.pi * tout / loop + 1.3), -240 + 30 * np.cos(2 * np.pi * tout / loop)], axis=1)

    y = fx.doppler(a, path_a, ref_dist=60.0, src_t0=-pre) + fx.doppler(b, path_b, ref_dist=60.0, src_t0=-pre) * 0.8
    y = filters.lp(y, 3500)
    y = fx.reverb(y, "alley", 0.45, stereo_out=True, tail=False, lowcut=300)
    bed = np.stack([filters.lp(noise.brown(out_len, rng), 250) for _ in range(2)], axis=1) * 0.05
    return loop_xfade(y + bed, nsamp(loop), nsamp(xf))


# ============================================================ crew / heist events


def mask_on(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: cloth rustle (2-6 kHz grains) + plastic snap at 0.32 s + low whoosh 150-500 Hz."""
    dur = 0.9
    rustle_src = filters.bp(noise.white(dur, rng), 3800, 0.8)
    times = np.sort(rng.uniform(0.0, 0.35, 40))
    rustle = granular.cloud(dur, times, lambda i, r: _grain_from(rustle_src, r, 0.01, 0.04), rng)
    snap = click(rng, (2300.0, 3400.0, 5600.0), 0.12, 8, 0.012, 0.35)
    snap += osc.sine(380, 0.12) * env.exp_decay(0.12, 0.05) * 0.4
    whoo = whoosh(rng, 0.55, 150, 500, 180, 0.8)
    y = np.zeros(nsamp(dur))
    place(y, rustle * 1.2, 0)
    place(y, whoo * 2.0, nsamp(0.05))
    place(y, snap, nsamp(0.32))
    return fade(y, 0, 0.1)


def _grain_from(src: np.ndarray, rng: np.random.Generator, lo: float, hi: float) -> np.ndarray:
    gl = nsamp(rng.uniform(lo, hi))
    k = int(rng.integers(0, src.shape[0] - gl))
    return src[k:k + gl] * granular.grain_window(gl, "perc")


def crew_downed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: sub-heavy muffled thud + slow descending tone 600->180 Hz, LP'd (dazed)."""
    dur = 1.6
    t = tvec(dur)
    body = thud(rng, 55, dur, 1.0) * 1.2
    tone = osc.triangle(600 * np.exp(-t * 0.8), dur) * env.adsr(dur, 0.02, 0.5, 0.6, 0.8) * 0.5
    beat = np.zeros(nsamp(dur))
    for s0 in (0.35, 0.62, 1.1, 1.37):
        place(beat, thud(rng, 48, 0.25, 0.2), nsamp(s0), 0.6)
    y = filters.lp(body + tone + beat, 900)
    return fx.reverb(y, "small_office", 0.2, stereo_out=False, tail=False)


def revive(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: rising major arpeggio chime (A5 C#6 E6) + breath swell. Bright, 1.1 s."""
    dur = 1.2
    y = np.zeros(nsamp(dur))
    for i, note in enumerate((81, 85, 88)):
        place(y, seq.bell(note, 0.9, rng, 0.5), nsamp(i * 0.08), 0.5)
    breath = filters.bp(noise.pink(dur, rng), 900, 0.6) * env.segments([(0, 0), (0.25, 1), (0.6, 0)], dur) * 0.5
    return fx.reverb(y + breath, "plate", 0.2, stereo_out=False, tail=False)


def assault_start(rng: np.random.Generator, v: int) -> np.ndarray:
    """Stinger + radio chatter. Niche: sub impact + minor brass stab (Am) + dispatcher radio."""
    dur = 3.4
    y = np.zeros((nsamp(dur), 2))
    boom = seq.impact(rng, 2.6)
    place(y, stereo(boom), 0, 0.9)
    stab_notes = seq.chord("Am", 3) + seq.chord("Am", 4)[1:]
    st = np.zeros(nsamp(1.4))
    for note in stab_notes:
        st += osc.supersaw(midi_hz(note), 1.4, 5, 16, rng)
    st = filters.biquad_tv(st, "lp", 600 + 5000 * env.exp_decay(1.4, 0.7), 1.0)
    st *= env.adsr(1.4, 0.01, 0.4, 0.4, 0.6)
    place(y, fx.widen(st * 0.35, 9), 0)
    chat = radio_chatter(rng, 1.8, 8.0)
    place(y, fx.pan(chat * 0.5, 0.25), nsamp(1.2))
    return fx.reverb(y, "hall", 0.15, stereo_out=True, tail=False)


# ============================================================ glass, drill, loot


def glass_break(rng: np.random.Generator, v: int) -> np.ndarray:
    """Procedural granular shatter: crack impulse + low thump, then a dense cloud of shard grains
    (inharmonic 3-11 kHz resonators) decaying over 0.4 s, then sparse bouncing tinkles.
    Niche: 3-11 kHz shimmer, irregular density. Each variant reseeds the grain field."""
    dur = 1.7
    n = nsamp(dur)
    crack = filters.hp(noise.white(0.03, rng), 1500) * env.exp_decay(0.03, 0.02, 0.0)
    thump = thud(rng, 140 + 20 * v, 0.2, 0.8) * 0.5

    def shard(i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(0.02, 0.12)
        base = r.uniform(2800, 9000)
        fr = [base * k for k in (1.0, r.uniform(1.4, 1.9), r.uniform(2.3, 3.1))]
        g = osc.partials(fr, [1.0, 0.6, 0.35], [d * 0.5, d * 0.3, d * 0.2], d, r)
        return g * r.uniform(0.3, 1.0)

    burst_n = 260 + 20 * v
    times = np.concatenate([
        rng.exponential(0.09 + 0.02 * v, burst_n),
        0.25 + rng.uniform(0.0, 1.0, 26 + 4 * v) ** 1.5 * 1.1,
    ])
    gains = np.concatenate([np.ones(burst_n), rng.uniform(0.2, 0.6, times.shape[0] - burst_n)])
    shards = granular.cloud(dur, np.clip(times, 0, dur - 0.15), shard, rng, gains) * 0.25
    y = np.zeros(n)
    place(y, crack * 2.0, 0)
    place(y, thump, 0)
    y += shards
    y = fx.reverb(y, "store", 0.18, stereo_out=False, tail=False)
    return fade(y, 0, 0.15)


def _motor(rng: np.random.Generator, dur: float, f: np.ndarray | float) -> np.ndarray:
    n = nsamp(dur)
    fa = np.full(n, float(f)) if np.isscalar(f) else f
    m = osc.saw(fa, dur) * 0.5 + osc.square(fa * 2, dur, 0.3) * 0.2
    m = filters.bp(m, 900, 0.5) + filters.bp(m, 2400, 2.0) * 0.4
    gear = osc.sine(fa * 7.0, dur) * 0.12
    grind = filters.bp(noise.white(dur, rng), 1700, 1.2) * (0.5 + 0.5 * np.abs(osc.sine(fa / 8, dur)))
    return (m + gear + grind * 0.35) * (1 + 0.15 * osc.sine(fa / 4, dur))


def drill_loop(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: steady motor whine 180 Hz + 1.26 kHz gear whine + 1.7 kHz grind, 45 Hz chatter.
    Seamless 3 s loop."""
    return make_loop(lambda d: fx.drive(_motor(rng, d, 180.0 * (1 + 0.01 * env.lfo(0.5, d))), 1.5), 3.0, 0.4)


def drill_jam(rng: np.random.Generator, v: int) -> np.ndarray:
    """Grinding stop + clunk. Niche: falling motor pitch with heavy grind, low metal clunk at end."""
    dur = 1.4
    t = tvec(dur)
    f = 180.0 * np.maximum(1.0 - (t / 0.7) ** 1.3, 0.12)
    m = _motor(rng, dur, f) * env.segments([(0, 1), (0.65, 0.9), (0.8, 0.0), (dur, 0)], dur)
    grind = filters.bp(noise.white(dur, rng), 900, 1.5) * env.segments([(0, 0.4), (0.6, 1.0), (0.8, 0)], dur) * 1.5
    clunk = thud(rng, 75, 0.5, 0.6) + osc.partials([410, 980, 1530], [0.5, 0.3, 0.2], [0.2, 0.12, 0.08], 0.5, rng)
    y = fx.drive(m + grind, 2.0)
    place(y, clunk * 1.2, nsamp(0.74))
    return fade(y, 0, 0.1)


def drill_done(rng: np.random.Generator, v: int) -> np.ndarray:
    """Spin-down whirr then a clear 'ding'. Niche: single pure bell at 1.97 kHz with long decay."""
    dur = 1.8
    t = tvec(0.5)
    spin = _motor(rng, 0.5, 180 * np.exp(-t * 3)) * env.exp_decay(0.5, 0.5) * 0.4
    ding = osc.partials([1975.0, 1975.0 * 2.76, 1975 * 5.4], [1.0, 0.25, 0.08], [0.5, 0.15, 0.06], 1.3, rng)
    y = np.zeros(nsamp(dur))
    place(y, spin, 0)
    place(y, ding, nsamp(0.42))
    return fx.reverb(y, "small_office", 0.15, stereo_out=False, tail=False)


def bag_pickup(rng: np.random.Generator, v: int) -> np.ndarray:
    """Duffel rustle + strap tug. Niche: 600 Hz-3 kHz dense nylon rustle 0.4 s, soft low thump."""
    dur = 0.55
    src = filters.bp(noise.white(dur, rng), 1600, 0.6)
    times = np.sort(rng.uniform(0, 0.32, 55))
    rus = granular.cloud(dur, times, lambda i, r: _grain_from(src, r, 0.008, 0.035), rng)
    y = rus * 0.8 + thud(rng, 110, dur, 0.5) * 0.4
    place(y, click(rng, (2900.0, 4300.0), 0.05, 10, 0.008, 0.4), nsamp(0.28))
    return fade(y, 0, 0.08)


def bag_throw(rng: np.random.Generator, v: int) -> np.ndarray:
    """Effort whoosh. Niche: band-pass noise sweep 300->1400->400 Hz, 0.55 s swell."""
    y = whoosh(rng, 0.55, 300, 1400, 400, 1.6) * 1.4
    y += filters.bp(noise.white(0.55, rng), 2500, 0.7) * np.sin(np.linspace(0, np.pi, nsamp(0.55))) ** 4 * 0.2
    return y


def bag_secure(rng: np.random.Generator, v: int) -> np.ndarray:
    """Thud + cha-ching. Niche: 70 Hz body thump then two bright register bells (2.6/3.5 kHz)."""
    dur = 1.3
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 70, 0.45, 1.0) * 1.3, 0)
    place(y, click(rng, (3100.0, 4700.0), 0.06, 8, 0.01, 0.5), nsamp(0.22))
    for k, (st, f) in enumerate(((0.26, 2637.0), (0.36, 3520.0))):
        b = osc.partials([f, f * 2.4, f * 3.9], [1.0, 0.35, 0.15], [0.35, 0.12, 0.06], 0.8, rng)
        place(y, b * 0.55, nsamp(st))
    coins = granular.cloud(0.5, np.sort(rng.uniform(0, 0.25, 16)),
                           lambda i, r: osc.partials([r.uniform(5000, 8000)], [1.0], [0.02], 0.05, r), rng)
    place(y, coins * 0.25, nsamp(0.3))
    return fx.reverb(y, "small_office", 0.12, stereo_out=False, tail=False)


def small_loot_pickup(rng: np.random.Generator, v: int) -> np.ndarray:
    """Jewelry jingle. Niche: 4-8 kHz tiny bell grains, 0.4 s, plus a soft pocket rustle."""
    dur = 0.6
    jingle = granular.cloud(dur, np.sort(rng.uniform(0, 0.28, 14)),
                            lambda i, r: osc.partials([r.uniform(4200, 7800), r.uniform(9000, 11000)], [1.0, 0.3],
                                                      [0.06, 0.02], 0.15, r), rng)
    rus = filters.bp(noise.white(dur, rng), 2200, 0.8) * env.segments([(0, 0), (0.05, 0.6), (0.25, 0)], dur)
    return jingle * 0.4 + rus * 0.25


# ============================================================ weapons


def _gunshot(rng: np.random.Generator, v: int, *, body_hz: float, sub: float, crack: float, dur: float,
             room: str, wet: float, bark_hz: float) -> np.ndarray:
    t = tvec(dur)
    vr = 1 + rng.uniform(-0.05, 0.05)
    cr = filters.hp(noise.white(dur, rng), 2500) * env.exp_decay(dur, 0.012, 0.0) * crack
    body = osc.sine(body_hz * vr * (1 + 1.5 * np.exp(-t / 0.006)), dur) * env.exp_decay(dur, 0.18, 0.0003)
    subw = osc.sine(55 * vr * (1 + 0.5 * np.exp(-t / 0.02)), dur) * env.exp_decay(dur, 0.25, 0.001) * sub
    bark = filters.bp(noise.white(dur, rng), bark_hz * vr, 1.2) * env.exp_decay(dur, 0.09, 0.0002) * 1.8
    mech = click(rng, (3300.0, 5100.0), 0.05, 10, 0.006, 0.25)
    y = fx.drive((cr + body + subw + bark) * 1.6, 3.0)
    place(y, mech, nsamp(0.035 + rng.uniform(0, 0.01)))
    y = fx.reverb(y, room, wet, stereo_out=False, tail=False, lowcut=200)
    return fade(y, 0, 0.2)


def weapon_pistol_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: sharp 9 mm crack, 1 kHz bark, 150 Hz punch, short slap tail (alley IR)."""
    return _gunshot(rng, v, body_hz=150, sub=0.4, crack=1.4, dur=1.0, room="alley", wet=0.22, bark_hz=1000)


def weapon_rifle_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: heavier 5.56 report: 55 Hz sub, 700 Hz bark, harsher crack, longer tail."""
    return _gunshot(rng, v, body_hz=110, sub=1.1, crack=1.8, dur=1.4, room="alley", wet=0.3, bark_hz=700)


def _suppressed(rng: np.random.Generator, v: int, *, puff_hz: float, dur: float, action: float) -> np.ndarray:
    t = tvec(dur)
    puff = filters.lp(noise.white(dur, rng), puff_hz) * env.exp_decay(dur, 0.06, 0.0005) * 2.5
    thmp = osc.sine(180 * (1 + np.exp(-t / 0.01)), dur) * env.exp_decay(dur, 0.07) * 0.8
    y = puff + thmp
    place(y, click(rng, (2600.0, 4100.0, 6200.0), 0.07, 9, 0.01, action * 0.3), nsamp(0.018))
    place(y, click(rng, (1900.0, 3500.0), 0.06, 8, 0.012, action * 0.2), nsamp(0.06 + rng.uniform(0, 0.01)))
    return fade(fx.reverb(y, "small_office", 0.1, stereo_out=False, tail=False), 0, 0.05)


def weapon_pistol_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: muffled 1.4 kHz puff + slide clack (2.6-6 kHz). Short, quiet character."""
    return _suppressed(rng, v, puff_hz=1400, dur=0.35, action=0.9)


def weapon_rifle_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: bigger 1 kHz puff + bolt clack."""
    return _suppressed(rng, v, puff_hz=1000, dur=0.4, action=1.2)


# ------------------------------------------------------------ D-034 weapon families (smg/rifle/shotgun/lmg/sniper)


def _shot(rng: np.random.Generator, *, body_hz: float, sub: float, crack: float, dur: float, room: str, wet: float,
          bark_hz: float, sub_hz: float = 55.0, crack_hp: float = 2500.0, crack_t: float = 0.012, bark_q: float = 1.2,
          bark_t: float = 0.09, body_t: float = 0.18, sub_t: float = 0.25, boom: float = 0.0, echo: float = 0.0,
          drive_amt: float = 3.0, mech: float = 0.25) -> np.ndarray:
    """Family gunshot: crack (supersonic/muzzle) + body punch + sub + mid bark + mechanism, optional
    low-end boom (shotgun) and distant slap-back echoes (sniper), room IR tail."""
    t = tvec(dur)
    vr = 1 + rng.uniform(-0.05, 0.05)
    cr = filters.hp(noise.white(dur, rng), crack_hp) * env.exp_decay(dur, crack_t, 0.0) * crack
    body = osc.sine(body_hz * vr * (1 + 1.5 * np.exp(-t / 0.006)), dur) * env.exp_decay(dur, body_t, 0.0003)
    subw = osc.sine(sub_hz * vr * (1 + 0.5 * np.exp(-t / 0.02)), dur) * env.exp_decay(dur, sub_t, 0.001) * sub
    bark = filters.bp(noise.white(dur, rng), bark_hz * vr, bark_q) * env.exp_decay(dur, bark_t, 0.0002) * 1.8
    y = fx.drive((cr + body + subw + bark) * 1.6, drive_amt)
    if boom > 0:
        y += (filters.lp(noise.brown(dur, rng), 180) * env.exp_decay(dur, 0.6, 0.002)
              + osc.sine(38 * vr * (1 + np.exp(-t / 0.05)), dur) * env.exp_decay(dur, 0.7, 0.002)) * boom
    place(y, click(rng, (3300.0, 5100.0), 0.05, 10, 0.006, mech), nsamp(0.035 + rng.uniform(0, 0.01)))
    y = fx.reverb(y, room, wet, stereo_out=False, tail=False, lowcut=200)
    if echo > 0:
        head = filters.lp(y[: nsamp(0.35)], 2200)
        for dt, g in ((0.23 + rng.uniform(0, 0.03), 0.32), (0.52 + rng.uniform(0, 0.05), 0.18), (0.95, 0.09)):
            place(y, head * g * echo, nsamp(dt))
    return fade(y, 0, min(0.4, dur * 0.25))


def _sup(rng: np.random.Generator, *, puff_hz: float, dur: float, action: float, thump_hz: float, puff_t: float,
         crack: float = 0.0) -> np.ndarray:
    """Family suppressed shot: low-passed gas puff + thump + action clacks (+ residual supersonic crack)."""
    t = tvec(dur)
    puff = filters.lp(noise.white(dur, rng), puff_hz) * env.exp_decay(dur, puff_t, 0.0005) * 2.5
    thmp = osc.sine(thump_hz * (1 + np.exp(-t / 0.01)), dur) * env.exp_decay(dur, puff_t * 1.2) * 0.8
    y = puff + thmp
    if crack > 0:
        y += filters.hp(noise.white(dur, rng), 3500) * env.exp_decay(dur, 0.006, 0.0) * crack
    place(y, click(rng, (2600.0, 4100.0, 6200.0), 0.07, 9, 0.01, action * 0.3), nsamp(0.018))
    place(y, click(rng, (1900.0, 3500.0), 0.06, 8, 0.012, action * 0.2), nsamp(0.06 + rng.uniform(0, 0.01)))
    room = "alley" if crack > 0 else "small_office"
    return fade(fx.reverb(y, room, 0.12, stereo_out=False, tail=False), 0, 0.05)


def weapon_smg_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: fast & light: 200 Hz punch, 1.4 kHz bark, very short tail (built for 900 rpm)."""
    return _shot(rng, body_hz=200, sub=0.25, crack=1.2, dur=0.7, room="alley", wet=0.15, bark_hz=1400,
                 bark_t=0.06, body_t=0.1, sub_t=0.12, mech=0.35)


def weapon_smg_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: tight 1.6 kHz puff + busy bolt clatter."""
    return _sup(rng, puff_hz=1600, dur=0.3, action=1.0, thump_hz=220, puff_t=0.045)


def weapon_shotgun_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: big boom: 38-48 Hz low end, wide 450 Hz bark, long body."""
    return _shot(rng, body_hz=85, sub=1.4, sub_hz=48, crack=1.5, crack_t=0.02, dur=1.6, room="alley", wet=0.3,
                 bark_hz=450, bark_q=0.8, bark_t=0.15, body_t=0.3, sub_t=0.45, boom=1.2, mech=0.2)


def weapon_shotgun_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: deep 700 Hz whump."""
    return _sup(rng, puff_hz=700, dur=0.55, action=0.6, thump_hz=110, puff_t=0.1)


def weapon_lmg_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: heavier than the rifle: 50 Hz sub, 620 Hz bark, more drive and mechanism."""
    return _shot(rng, body_hz=95, sub=1.3, sub_hz=50, crack=2.0, dur=1.5, room="alley", wet=0.32, bark_hz=620,
                 bark_t=0.11, body_t=0.22, sub_t=0.3, drive_amt=3.5, mech=0.4)


def weapon_lmg_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: 900 Hz puff with a heavy action."""
    return _sup(rng, puff_hz=900, dur=0.45, action=1.3, thump_hz=140, puff_t=0.08)


def weapon_sniper_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: heavy supersonic crack (3.5 kHz+) and a long tail with distant slap-back echoes."""
    return _shot(rng, body_hz=90, sub=1.2, crack=2.6, crack_hp=3500, crack_t=0.008, dur=3.0, room="alley",
                 wet=0.4, bark_hz=800, body_t=0.25, sub_t=0.4, echo=1.0, mech=0.15)


def weapon_sniper_fire_suppressed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Niche: suppressed but still supersonic: 800 Hz puff + residual crack."""
    return _sup(rng, puff_hz=800, dur=0.7, action=0.5, thump_hz=120, puff_t=0.09, crack=0.6)


def _mag_out(rng: np.random.Generator, k: float, mass: float) -> np.ndarray:
    """Generic mag release: catch click, rasp slide-out, palm catch. k = pitch scale, mass = weight."""
    dur = 0.3 + 0.1 * mass
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (2600.0 * k, 4300.0 * k), 0.05, 10, 0.008, 0.9), 0)
    rd = 0.08 * mass + 0.02 * rng.random()
    rasp = filters.bp(noise.white(rd, rng), 1900 * k, 1.3) * env.segments([(0, 0), (rd * 0.3, 1), (rd, 0)], rd) * 0.5
    place(y, rasp, nsamp(0.025))
    place(y, thud(rng, 220 * k, 0.1, 0.5) * 0.3 * mass, nsamp(0.11 * mass + 0.02 * rng.random()))
    return fade(y, 0, 0.03)


def _mag_in(rng: np.random.Generator, k: float, mass: float) -> np.ndarray:
    """Generic mag insert: scrape, seating clack with body, latch catch."""
    dur = 0.28 + 0.08 * mass
    y = np.zeros(nsamp(dur))
    sd = 0.04 + 0.03 * mass
    place(y, filters.bp(noise.white(sd, rng), 2800 * k, 1.5) * env.segments([(0, 0), (sd, 1)], sd) * 0.35, 0)
    t0 = nsamp(sd)
    place(y, click(rng, (1400.0 * k, 2300.0 * k, 3200.0 * k), 0.12, 14, 0.014, 1.3), t0)
    place(y, thud(rng, 160 * k, 0.14, 0.6) * 0.6 * mass, t0)
    place(y, click(rng, (4000.0 * k, 5600.0 * k), 0.03, 8, 0.004, 0.35), t0 + nsamp(0.012))
    return fade(y, 0, 0.03)


def _charging_handle(rng: np.random.Generator, k: float, mass: float) -> np.ndarray:
    """Charging handle: pull back (scrape + stop click), release: spring slam with ring + thump."""
    dur = 0.5 + 0.1 * mass
    y = np.zeros(nsamp(dur))
    pd = 0.07 * mass
    place(y, filters.bp(noise.white(pd, rng), 3800 * k, 2.0) * env.segments([(0, 0), (pd * 0.5, 1), (pd, 0.3)], pd) * 0.5, 0)
    place(y, click(rng, (2400.0 * k, 4400.0 * k), 0.05, 10, 0.008, 0.7), nsamp(pd))
    t1 = nsamp(pd + 0.12 + 0.03 * rng.random())
    place(y, click(rng, (1800.0 * k, 3300.0 * k, 5600.0 * k), 0.2, 18, 0.02, 1.6), t1)
    place(y, thud(rng, 130 * k, 0.12, 0.4) * 0.5 * mass, t1)
    return fade(y, 0, 0.04)


def _bolt_action(rng: np.random.Generator, k: float) -> np.ndarray:
    """Bolt-action cycle: lift (click), pull back (scrape + stop), push forward (scrape), lock down."""
    dur = 0.95
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (2100.0 * k, 3700.0 * k), 0.06, 10, 0.01, 0.8), 0)
    for start, f0, f1 in ((0.08, 2600.0, 3600.0), (0.42, 3400.0, 2400.0)):
        sd = 0.11
        n = nsamp(sd)
        sc = filters.biquad_tv(noise.white(sd, rng), "bp", np.geomspace(f0 * k, f1 * k, n), 2.5)
        place(y, sc * np.sin(np.linspace(0, np.pi, n)) * 0.6, nsamp(start))
    place(y, click(rng, (1700.0 * k, 3000.0 * k, 4900.0 * k), 0.12, 14, 0.014, 1.2), nsamp(0.2))  # rear stop
    place(y, click(rng, (1500.0 * k, 2800.0 * k), 0.1, 12, 0.012, 1.0), nsamp(0.54))  # chambered
    place(y, click(rng, (2000.0 * k, 3500.0 * k, 5200.0 * k), 0.15, 16, 0.016, 1.4), nsamp(0.68))  # lock down
    place(y, thud(rng, 150 * k, 0.12, 0.4) * 0.4, nsamp(0.68))
    return fade(y, 0, 0.05)


def weapon_shotgun_pump(rng: np.random.Generator, v: int) -> np.ndarray:
    """Pump "ka-chunk": back stroke (scrape + clack + wood thud) then a heavier forward lock. Niche:
    low 1.1-2.4 kHz clacks with 90-120 Hz body, two hits 0.17 s apart."""
    dur = 0.5
    y = np.zeros(nsamp(dur))
    k = rng.uniform(0.96, 1.04)
    for start, lvl, f in ((0.0, 1.0, 120.0), (0.17 + 0.02 * rng.random(), 1.4, 95.0)):
        sd = 0.05
        place(y, filters.bp(noise.white(sd, rng), 2200 * k, 1.2) * np.linspace(0.2, 1, nsamp(sd)) * 0.4, nsamp(start))
        t0 = nsamp(start + sd)
        place(y, click(rng, (1100.0 * k, 2400.0 * k, 3600.0 * k), 0.1, 12, 0.012, lvl), t0)
        place(y, thud(rng, f, 0.15, 0.6) * 0.7 * lvl, t0)
    return fade(y, 0, 0.04)


def weapon_shotgun_shell_in(rng: np.random.Generator, v: int) -> np.ndarray:
    """Shell thumbed into the tube: brass/plastic click (3.5 kHz ring), short slide, follower click."""
    dur = 0.22
    y = np.zeros(nsamp(dur))
    k = rng.uniform(0.95, 1.05)
    place(y, click(rng, (3500.0 * k, 5200.0 * k), 0.06, 10, 0.01, 0.8), 0)
    sd = 0.05
    place(y, filters.bp(noise.white(sd, rng), 2600 * k, 1.2) * np.sin(np.linspace(0, np.pi, nsamp(sd))) * 0.4, nsamp(0.02))
    place(y, click(rng, (1900.0 * k, 3100.0 * k), 0.05, 8, 0.008, 0.6), nsamp(0.08 + 0.02 * rng.random()))
    return fade(y, 0, 0.03)


def _family(k: float, mass: float) -> tuple[Callable, Callable, Callable]:
    def mag_out(rng: np.random.Generator, v: int) -> np.ndarray:
        return _mag_out(rng, k * rng.uniform(0.97, 1.03), mass)

    def mag_in(rng: np.random.Generator, v: int) -> np.ndarray:
        return _mag_in(rng, k * rng.uniform(0.97, 1.03), mass)

    def bolt(rng: np.random.Generator, v: int) -> np.ndarray:
        return _charging_handle(rng, k * rng.uniform(0.97, 1.03), mass)

    for fn, base in ((mag_out, "_mag_out"), (mag_in, "_mag_in"), (bolt, "_charging_handle")):
        fn.__name__ = fn.__qualname__ = f"{base}(k={k}, mass={mass})"  # shown in SOURCE.txt
    return mag_out, mag_in, bolt


weapon_smg_mag_out, weapon_smg_mag_in, weapon_smg_bolt = _family(1.1, 0.8)
weapon_rifle_mag_out, weapon_rifle_mag_in, weapon_rifle_bolt = _family(0.85, 1.0)
weapon_lmg_mag_out, weapon_lmg_mag_in, weapon_lmg_bolt = _family(0.7, 1.4)
weapon_sniper_mag_out, weapon_sniper_mag_in = _family(0.9, 1.1)[:2]


def weapon_sniper_bolt(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bolt-action cycle (lift, back, forward, lock), 0.95 s."""
    return _bolt_action(rng, 0.95 * rng.uniform(0.97, 1.03))


def weapon_pistol_mag_out(rng: np.random.Generator, v: int) -> np.ndarray:
    """Mag release: thumb-button click (2.8-4.6 kHz), short polymer slide-out rasp (2.2 kHz band),
    soft palm catch. Niche: single 0.3 s event, brighter/lighter than mag_in."""
    dur = 0.32
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (2800.0 * rng.uniform(0.95, 1.05), 4600.0), 0.05, 10, 0.008, 0.9), 0)
    rd = 0.09 + 0.02 * rng.random()
    rasp = filters.bp(noise.white(rd, rng), 2200 * rng.uniform(0.9, 1.1), 1.4)
    rasp *= env.segments([(0, 0), (rd * 0.3, 1), (rd, 0)], rd) * 0.5
    place(y, rasp, nsamp(0.025))
    catch = thud(rng, 260 * rng.uniform(0.9, 1.1), 0.08, 0.5) * 0.35
    place(y, catch, nsamp(0.12 + 0.02 * rng.random()))
    return fade(y, 0, 0.03)


def weapon_pistol_mag_in(rng: np.random.Generator, v: int) -> np.ndarray:
    """Mag seated: slide-in scrape then a firm clack (1.6-3.4 kHz modes, longer ring) with a
    180 Hz palm-slap body. Niche: lower, heavier than mag_out."""
    dur = 0.3
    y = np.zeros(nsamp(dur))
    sd = 0.05
    scrape = filters.bp(noise.white(sd, rng), 3200, 1.5) * env.segments([(0, 0), (sd, 1)], sd) * 0.35
    place(y, scrape, 0)
    t0 = nsamp(sd)
    place(y, click(rng, (1600.0 * rng.uniform(0.95, 1.05), 2500.0, 3400.0), 0.12, 14, 0.014, 1.3), t0)
    place(y, thud(rng, 180 * rng.uniform(0.92, 1.08), 0.12, 0.6) * 0.7, t0)
    place(y, click(rng, (4200.0, 5900.0), 0.03, 8, 0.004, 0.35), t0 + nsamp(0.012))  # latch catch
    return fade(y, 0, 0.03)


def weapon_pistol_slide_release(rng: np.random.Generator, v: int) -> np.ndarray:
    """Slide slams home: spring-driven steel-on-steel snap with a bright metallic ring
    (2.1/3.9/6.3 kHz, ~60 ms) and a small frame thump. Niche: sharpest, most metallic of the three."""
    dur = 0.28
    y = np.zeros(nsamp(dur))
    pre = filters.bp(noise.white(0.018, rng), 5000, 2.0) * np.linspace(0.0, 0.4, nsamp(0.018))  # spring travel
    place(y, pre, 0)
    t0 = nsamp(0.018)
    k = rng.uniform(0.96, 1.04)
    place(y, click(rng, (2100.0 * k, 3900.0 * k, 6300.0 * k), 0.2, 18, 0.02, 1.6), t0)
    place(y, thud(rng, 140, 0.1, 0.4) * 0.5, t0)
    return fade(y, 0, 0.04)


def reload_pistol(rng: np.random.Generator, v: int) -> np.ndarray:
    """Mag out, mag in, slide rack. Niche: sparse metallic clicks 2-6 kHz in a 1.3 s rhythm."""
    dur = 1.35
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (2400.0, 4100.0), 0.06, 10, 0.01, 0.7), nsamp(0.05))           # release
    place(y, filters.bp(noise.white(0.12, rng), 3000, 1.0) * env.exp_decay(0.12, 0.08) * 0.3, nsamp(0.08))
    place(y, click(rng, (1800.0, 3200.0, 5200.0), 0.07, 9, 0.012, 1.2), nsamp(0.62))   # mag in
    place(y, thud(rng, 220, 0.08, 0.2) * 0.3, nsamp(0.62))
    scrape = filters.bp(noise.white(0.1, rng), 4500, 2.0) * env.segments([(0, 0), (0.05, 1), (0.1, 0)], 0.1) * 0.6
    place(y, scrape, nsamp(0.95))                                                     # slide pull
    place(y, click(rng, (2000.0, 3700.0, 6100.0), 0.08, 8, 0.014, 1.5), nsamp(1.07))   # slide release
    return y


def reload_rifle(rng: np.random.Generator, v: int) -> np.ndarray:
    """Mag release, drop rattle, insert, charging handle. Niche: lower 1.2-4 kHz clacks, 2.2 s."""
    dur = 2.3
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (1500.0, 3300.0), 0.06, 10, 0.012, 0.8), nsamp(0.05))
    rattle = granular.cloud(0.3, np.sort(rng.uniform(0, 0.2, 6)),
                            lambda i, r: click(r, (r.uniform(1200, 2400), r.uniform(3000, 4500)), 0.04, 6, 0.006, 0.4), rng)
    place(y, rattle, nsamp(0.25))
    place(y, click(rng, (1200.0, 2600.0, 4000.0), 0.08, 8, 0.016, 1.4), nsamp(1.05))
    place(y, thud(rng, 160, 0.1, 0.3) * 0.4, nsamp(1.05))
    scrape = filters.bp(noise.white(0.15, rng), 3600, 2.0) * env.segments([(0, 0), (0.08, 1), (0.15, 0)], 0.15) * 0.6
    place(y, scrape, nsamp(1.55))
    place(y, click(rng, (1700.0, 2900.0, 5000.0), 0.09, 8, 0.016, 1.6), nsamp(1.75))
    return y


def dry_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """Hammer on empty chamber. Niche: single 3.2 kHz metallic tick, 80 ms, no tail."""
    return click(rng, (3200.0, 5800.0), 0.09, 14, 0.01, 1.0)


def hitmarker(rng: np.random.Generator, v: int) -> np.ndarray:
    """UI confirm of a hit. Niche: 3.5 kHz 'tok', 50 ms, dry."""
    dur = 0.06
    y = osc.sine(3500, dur) * env.exp_decay(dur, 0.03, 0.0005) + click(rng, (5000.0,), dur, 6, 0.004, 0.3)
    return y


def headshot(rng: np.random.Generator, v: int) -> np.ndarray:
    """Distinct from hitmarker: metallic 'dink' (1.5 + 4.2 kHz inharmonic ping) with 250 ms ring
    and a crunch transient."""
    dur = 0.32
    ping = osc.partials([1530.0, 4190.0, 6020.0], [0.8, 1.0, 0.4], [0.12, 0.07, 0.03], dur, rng)
    crunch = filters.bp(noise.white(dur, rng), 2200, 1.0) * env.exp_decay(dur, 0.02, 0.0) * 1.5
    return ping + crunch


# ============================================================ world interactions / UI


def door_open(rng: np.random.Generator, v: int) -> np.ndarray:
    """Latch click + hinge creak. Niche: creak = stick-slip pulse train 30-60 Hz exciting
    wood formants (400 Hz / 1.1 kHz)."""
    dur = 1.0
    n = nsamp(dur)
    y = np.zeros(n)
    place(y, click(rng, (1600.0, 2900.0), 0.06, 8, 0.01, 0.2), 0)
    cd = 0.6
    t = tvec(cd)
    rate = 35 + 25 * np.sin(np.pi * t / cd) + 4 * noise.brown(cd, rng)
    ph = np.cumsum(rate / SR) % 1.0
    pulses = (np.diff(np.concatenate([[0.0], ph])) < 0).astype(float)
    creak = filters.bp(pulses, 420, 6) * 2 + filters.bp(pulses, 1150, 8) * 1.3 + filters.bp(pulses, 2400, 10) * 0.5
    creak *= np.sin(np.linspace(0, np.pi, nsamp(cd))) ** 0.7
    place(y, creak * 6.0, nsamp(0.12))
    return fx.reverb(y, "small_office", 0.15, stereo_out=False, tail=False)


def door_close(rng: np.random.Generator, v: int) -> np.ndarray:
    """Short swing air + wooden thunk 110 Hz + latch click."""
    dur = 0.7
    y = np.zeros(nsamp(dur))
    place(y, whoosh(rng, 0.2, 200, 600, 300, 0.8) * 0.4, 0)
    place(y, thud(rng, 110, 0.4, 0.9) * 1.2, nsamp(0.18))
    place(y, click(rng, (1400.0, 2600.0), 0.05, 8, 0.008, 0.8), nsamp(0.19))
    return fx.reverb(y, "small_office", 0.18, stereo_out=False, tail=False)


def keycard_beep(rng: np.random.Generator, v: int) -> np.ndarray:
    """Reader accept: rising 1.6 -> 2.4 kHz sine pair + relay click. Niche: clean pure tones."""
    dur = 0.4
    y = np.zeros(nsamp(dur))
    for st, f in ((0.0, 1600.0), (0.1, 2400.0)):
        place(y, osc.sine(f, 0.08) * env.adsr(0.08, 0.003, 0.03, 0.8, 0.01), nsamp(st))
    place(y, click(rng, (900.0, 2100.0), 0.05, 6, 0.008, 0.5), nsamp(0.22))
    return y


# ------------------------------------------------------------ QA-15 devices


def keypad_accept(rng: np.random.Generator, v: int) -> np.ndarray:
    """Code accepted: soft triangle two-tone D6 -> G6 (1175/1568 Hz), quick 60 ms pips, no relay.
    Niche: rounder and lower than keycard_beep (pure sines 1.6/2.4 kHz + relay click)."""
    dur = 0.25
    y = np.zeros(nsamp(dur))
    for st, f in ((0.0, 1175.0), (0.075, 1568.0)):
        place(y, osc.triangle(f, 0.06) * env.adsr(0.06, 0.002, 0.03, 0.7, 0.015), nsamp(st))
    return fade(y, 0, 0.02)


def c4_armed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Arming chirp: three rising FM blips 2.5 -> 3.5 kHz then an LED 'pip'. One-shot (a ticking
    loop can be added as cue.c4_tick if design wants a countdown)."""
    dur = 0.45
    y = np.zeros(nsamp(dur))
    for i, f in enumerate((2500.0, 3000.0, 3500.0)):
        b = osc.fm(f, 1.5, 1.2 * env.exp_decay(0.04, 0.03), 0.04) * env.adsr(0.04, 0.001, 0.02, 0.6, 0.01)
        place(y, b, nsamp(i * 0.055))
    place(y, osc.sine(4200.0, 0.08) * env.adsr(0.08, 0.002, 0.05, 0.8, 0.02) * 0.8, nsamp(0.22))
    return fade(y, 0, 0.03)


def c4_explode(rng: np.random.Generator, v: int) -> np.ndarray:
    """Large explosion: broadband crack, 30-60 Hz sub boom, 300-800 Hz roar, granular debris rain
    (0.3-2.6 s) and a long alley tail. Niche: the only cue with sustained sub + debris texture."""
    dur = 4.0
    t = tvec(dur)
    vr = 1 + 0.06 * (v - 1) + rng.uniform(-0.03, 0.03)
    crack = filters.hp(noise.white(dur, rng), 1200) * env.exp_decay(dur, 0.05, 0.0) * 2.0
    sub = osc.sine(30 * vr * (1 + 1.2 * np.exp(-t / 0.12)), dur) * env.exp_decay(dur, 1.8, 0.002) * 1.6
    roar = filters.bp(noise.brown(dur, rng), 450 * vr, 0.6) * env.exp_decay(dur, 1.4, 0.004) * 2.2
    rumble = filters.lp(noise.brown(dur, rng), 120) * env.exp_decay(dur, 2.8, 0.01) * 1.5
    y = fx.drive(crack + sub + roar + rumble, 2.5)

    def debris(i: int, r: np.random.Generator) -> np.ndarray:
        if r.random() < 0.6:
            return click(r, (r.uniform(900, 2500), r.uniform(2800, 6000)), 0.06, 8, 0.008, r.uniform(0.2, 0.8))
        return thud(r, r.uniform(90, 260), 0.15, 0.7) * r.uniform(0.2, 0.6)

    times = 0.3 + rng.uniform(0, 1, 90 + 10 * v) ** 1.7 * 2.3
    y += granular.cloud(dur, np.sort(times), debris, rng) * 0.5
    y = fx.reverb(y, "alley", 0.35, stereo_out=False, tail=False, lowcut=60)
    return fade(y, 0, 0.6)


def time_lock_start(rng: np.random.Generator, v: int) -> np.ndarray:
    """Vault time-lock engages: heavy bolt clunk (70 Hz + 0.9/1.8 kHz) then a 2 s geared motor
    whir (90 Hz harmonics + gear ticks) that spins up and stops with a click."""
    dur = 2.8
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 70, 0.5, 0.9) * 1.3, 0)
    place(y, click(rng, (900.0, 1800.0, 2700.0), 0.3, 20, 0.03, 1.0), 0)
    md = 2.0
    mt = tvec(md)
    f = 90 * np.minimum(1.0, 0.4 + mt / 0.4)
    motor = filters.bp(osc.saw(f, md), 700, 0.6) + osc.sine(f * 6, md) * 0.15
    motor *= env.segments([(0, 0), (0.3, 1), (md - 0.15, 1), (md, 0)], md) * 0.5
    ph = np.cumsum(f / 6 / 48000) % 1.0
    ticks = (np.diff(np.concatenate([[0.0], ph])) < 0).astype(float)
    motor += filters.bp(ticks, 3200, 6) * 3.0 * env.segments([(0, 0), (0.3, 1), (md, 1)], md)
    place(y, motor, nsamp(0.45))
    place(y, click(rng, (1500.0, 2600.0), 0.08, 10, 0.01, 0.8), nsamp(0.45 + md))
    return fx.reverb(y, "store", 0.15, stereo_out=False, tail=False)


def time_lock_done(rng: np.random.Generator, v: int) -> np.ndarray:
    """Time-lock releases: retracting bolt clunk with a low metal ring, then a two-note chime
    (A5, E6 bell). Niche: low clunk + bright consonant chime."""
    dur = 2.2
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 85, 0.4, 0.8), 0)
    place(y, osc.partials([310.0, 742.0, 1290.0], [0.6, 0.35, 0.2], [0.35, 0.2, 0.1], 0.6, rng), 0)
    place(y, click(rng, (1100.0, 2200.0), 0.1, 12, 0.012, 0.9), nsamp(0.01))
    for i, note in enumerate((81, 88)):
        place(y, seq.bell(note, 1.4, rng, 0.4), nsamp(0.45 + i * 0.18), 0.45)
    return fx.reverb(y, "store", 0.2, stereo_out=False, tail=False)


def laser_trip(rng: np.random.Generator, v: int) -> np.ndarray:
    """Laser grid tripped: two fast down-swept square blips 4.5 -> 2 kHz with a buzzy 120 Hz edge.
    Niche: sweeping (unlike the steady pager/alarm tones), 0.3 s."""
    dur = 0.32
    y = np.zeros(nsamp(dur))
    bd = 0.11
    sweep = np.geomspace(4500, 2000, nsamp(bd))
    blip = osc.square(sweep, bd, 0.5) * env.adsr(bd, 0.002, 0.05, 0.8, 0.02)
    blip *= 0.8 + 0.2 * osc.square(120, bd, 0.5)
    for st in (0.0, 0.14):
        place(y, filters.bp(blip, 3000, 0.7) + blip * 0.2, nsamp(st))
    return fade(y, 0, 0.02)


def zipline_attach(rng: np.random.Generator, v: int) -> np.ndarray:
    """Carabiner snaps onto the cable: bright clack (2.4/4.1/6.8 kHz) plus a taut-cable 'zing':
    a stretched-harmonic string at 160 Hz with a falling pitch bend and friction hiss."""
    dur = 1.1
    y = np.zeros(nsamp(dur))
    place(y, click(rng, (2400.0, 4100.0, 6800.0), 0.15, 16, 0.016, 1.3), 0)
    zd = 0.9
    t = tvec(zd)
    f0 = 160 * (1 + 0.04 * np.exp(-t / 0.15))
    zing = np.zeros(nsamp(zd))
    for h in range(1, 14):
        stretch = h * (1 + 0.0009 * h * h)
        zing += osc.sine(f0 * stretch, zd) * np.exp(-t / (0.5 / (1 + 0.15 * h))) / h ** 0.6
    hiss = filters.bp(noise.white(zd, rng), 5000, 1.5) * env.exp_decay(zd, 0.2) * 0.4
    place(y, (zing * 0.4 + hiss), nsamp(0.015))
    return fade(y, 0, 0.1)


def lockpick(rng: np.random.Generator, v: int) -> np.ndarray:
    """Pin picking loop: irregular tiny ticks 5-8 kHz over a faint tension-wrench scrape.
    Niche: very high, sparse, quiet. Seamless 3 s loop."""
    def render(d: float) -> np.ndarray:
        times = np.sort(rng.uniform(0, d - 0.05, int(d * 7)))
        ticks = granular.cloud(d, times, lambda i, r: click(r, (r.uniform(4500, 6500), r.uniform(7000, 9000)),
                                                             0.03, 12, 0.004, r.uniform(0.3, 1.0)), rng)
        scrape = filters.bp(noise.white(d, rng), 6000, 3) * (0.3 + 0.3 * env.lfo(1.3, d)) * 0.15
        return ticks + scrape
    return make_loop(render, 3.0, 0.2)


def ui_click(rng: np.random.Generator, v: int) -> np.ndarray:
    """Menu click: 1.2 kHz damped sine + soft transient, 40 ms."""
    dur = 0.045
    return osc.sine(1200, dur) * env.exp_decay(dur, 0.025, 0.0004) + click(rng, (2600.0,), dur, 4, 0.003, 0.2)


# ============================================================ QA-28 / D-049: P3 specials + new prefabs
# Readability (PD2 rule): every special tell is short, rhythmic or tonal, and centred in the
# 600 Hz - 4 kHz region where the assault stem and gunfire leave the most room (checked against
# mus_glasshouse_assault and weapon_rifle_fire spectra; see the build report).


def phantom_hum(rng: np.random.Generator, v: int) -> np.ndarray:
    """Phantom tell: eerie hum loop: 70 Hz drone whose 600-1300 Hz harmonics beat against a
    detuned copy, with a 6 Hz tremolo and a thin 2.2 kHz whistle on a slow vibrato.
    Niche: pulsing mid-band hum (6 Hz rhythm); nothing else in the game trembles at that rate."""
    def render(d: float) -> np.ndarray:
        t = tvec(d)
        drone = osc.saw(70.0, d) + osc.saw(70.7, d, 0.3)
        mid = filters.bp(drone, 900, 1.4) * 2.0 + filters.lp(drone, 200) * 0.3
        whistle = osc.sine(2200 * (1 + 0.01 * np.sin(2 * np.pi * 0.5 * t)), d) * 0.12
        trem = 0.55 + 0.45 * np.sin(2 * np.pi * 6.0 * t) ** 2
        return (mid + whistle) * trem
    return make_loop(render, 4.0, 0.3)


def phantom_charge(rng: np.random.Generator, v: int) -> np.ndarray:
    """Phantom charge: rushing whoosh plus a distorted formant shriek gliding 520 -> 900 Hz
    ("a" -> "i"). Niche: 1-3.5 kHz vocal scream with a rising glide, 1.2 s."""
    dur = 1.2
    t = tvec(dur)
    f0 = 520 + 380 * np.clip(t / 0.5, 0, 1) ** 0.7 + 25 * np.sin(2 * np.pi * 9 * t)
    src = osc.saw(f0, dur) + 0.25 * noise.white(dur, rng)
    shriek = filters.formant(src, "a", "i", 6.0) * env.segments([(0, 0), (0.12, 0.3), (0.3, 1), (0.95, 0.8), (dur, 0)], dur)
    shriek = fx.drive(shriek * 3.0, 3.0)
    rush = whoosh(rng, 0.7, 200, 1800, 600, 1.0) * 1.2
    y = shriek * 0.8
    place(y, rush, 0)
    return fx.reverb(fade(y, 0.005, 0.1), "store", 0.15, stereo_out=False, tail=False)


def stinger_windup(rng: np.random.Generator, v: int) -> np.ndarray:
    """Taser windup: 1 s electric ramp: buzzing square rising 180 -> 1800 Hz with a 120 Hz AM
    buzz and growing spark crackle. Niche: the only rising 1 s electric ramp."""
    dur = 1.0
    t = tvec(dur)
    f = np.geomspace(180, 1800, nsamp(dur))
    ramp = filters.bp(osc.square(f, dur, 0.3), 1500, 0.6) * (0.75 + 0.25 * osc.square(120, dur, 0.5))
    sparks = filters.hp(noise.crackle(dur, rng, 40), 2500) * (t / dur) ** 2 * 6
    y = (ramp * (0.2 + 0.8 * t / dur) + sparks)
    return fade(y, 0.01, 0.02)


def stinger_arc(rng: np.random.Generator, v: int) -> np.ndarray:
    """Taser arc loop: 120 Hz buzz (harmonics emphasised around 2.4 kHz, the "zzzt") with irregular
    spark bursts (high-passed noise spikes) at ~14 per second. Niche: 2-3 kHz buzz + crackle. 2 s seamless loop."""
    def render(d: float) -> np.ndarray:
        sq = osc.square(120.0, d, 0.2)
        buzz = filters.bp(sq, 2400, 1.2) * 1.6 + filters.bp(sq, 1100, 0.7) * 0.4
        n = nsamp(d)
        sparks = np.zeros(n)
        for t0 in np.sort(rng.uniform(0, d, int(d * 14))):
            bd = rng.uniform(0.005, 0.03)
            burst = filters.hp(noise.white(bd, rng), 2500) * env.exp_decay(bd, bd, 0.0) * rng.uniform(0.5, 1.5)
            place(sparks, burst, nsamp(t0))
        return buzz * (0.8 + 0.2 * env.lfo(3.0, d)) + sparks * 1.5
    return make_loop(render, 2.0, 0.1)


def longshot_report(rng: np.random.Generator, v: int) -> np.ndarray:
    """Longshot (sniper special) from 200+ m: sharp supersonic crack arriving first, then a
    darker, low-passed muzzle boom and long slap-back echoes. Niche: crack-then-boom double hit."""
    dur = 3.5
    y = np.zeros(nsamp(dur))
    cn = noise.white(0.06, rng)
    crack = (filters.hp(cn, 3000) * 4.0 + filters.bp(cn, 2200, 1.2) * 5.0) * env.exp_decay(0.06, 0.02, 0.0)
    place(y, crack, 0)
    boom = _shot(rng, body_hz=80, sub=1.0, crack=0.4, dur=3.2, room="alley", wet=0.5, bark_hz=500, body_t=0.3,
                 sub_t=0.5, echo=1.4, mech=0.0)
    place(y, filters.lp(boom, 2500), nsamp(0.09))
    return fade(y, 0, 0.5)


def bulwark_bang(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bulwark shield struck/slammed: large steel plate: inharmonic partials 180-2000 Hz ringing
    0.6 s, a flat thud and a bright clank. Niche: gong-like metallic ring."""
    dur = 1.0
    k = rng.uniform(0.95, 1.05)
    ring = osc.partials([182 * k, 421 * k, 763 * k, 1238 * k, 1975 * k, 2890 * k], [0.8, 1.0, 0.8, 0.6, 0.4, 0.25],
                        [0.5, 0.45, 0.35, 0.25, 0.15, 0.08], dur, rng)
    y = ring * 0.7 + thud(rng, 95, dur, 0.8) * 0.8
    place(y, click(rng, (2600.0, 4400.0), 0.08, 10, 0.01, 1.0), 0)
    return fx.reverb(fx.drive(y, 1.5), "store", 0.12, stereo_out=False, tail=False)


def wrecker_roar(rng: np.random.Generator, v: int) -> np.ndarray:
    """Wrecker (dozer) roar: heavily processed growl: jittered 75 Hz glottal saw through 'o'->'a'
    formants, ring-modulated at 33 Hz, tanh-crushed, with a sub-octave layer. Niche: gritty
    400-1500 Hz formant growl, 1.8 s."""
    dur = 1.8
    t = tvec(dur)
    f0 = 75 * (1 + 0.15 * env.segments([(0, 0), (0.4, 1), (1.3, 0.8), (dur, -0.3)], dur)) * \
        (1 + 0.03 * filters.lp(noise.white(dur, rng), 30) * 8)
    src = osc.saw(f0, dur) + 0.4 * filters.lp(noise.white(dur, rng), 3000)
    growl = filters.formant(src, "o", "a", 5.0) * (0.6 + 0.4 * osc.sine(33, dur))
    growl = fx.drive(growl * 4.0, 4.0)
    sub = osc.sine(f0 / 2, dur) * 0.4
    e = env.segments([(0, 0), (0.15, 1), (1.4, 0.85), (dur, 0)], dur)
    return fx.reverb((growl + sub) * e, "store", 0.15, stereo_out=False, tail=False)


def wrecker_step(rng: np.random.Generator, v: int) -> np.ndarray:
    """Heavy armoured footfall: 50 Hz floor thud, armour-plate clank (310/720 Hz), gear rattle.
    Niche: slow, heavy, metallic stomp (rhythm comes from the walk)."""
    dur = 0.6
    y = thud(rng, 50 * rng.uniform(0.95, 1.05), dur, 1.2) * 1.3
    plate = osc.partials([310 * rng.uniform(0.97, 1.03), 720, 1340], [0.6, 0.45, 0.25], [0.18, 0.12, 0.06], dur, rng)
    place(y, plate, nsamp(0.01))
    rattle = granular.cloud(0.3, np.sort(rng.uniform(0, 0.15, 6)),
                            lambda i, r: click(r, (r.uniform(1500, 3000),), 0.03, 6, 0.004, 0.3), rng)
    place(y, rattle, nsamp(0.03))
    return fade(y, 0, 0.1)


def wrecker_plate_crack(rng: np.random.Generator, v: int) -> np.ndarray:
    """Faceplate shatter: sharp crack, composite shards (1.5-5 kHz grains, drier and lower than
    glass) and a steel ping at 1.9 kHz. Niche: crunchy mid-high burst + ping, 1 s."""
    dur = 1.0
    crack = filters.hp(noise.white(0.04, rng), 1200) * env.exp_decay(0.04, 0.02, 0.0) * 2.0

    def shard(i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(0.015, 0.05)
        return osc.partials([r.uniform(1500, 5000), r.uniform(5000, 7000)], [1.0, 0.3], [d * 0.4, d * 0.2], d, r) * \
            r.uniform(0.3, 1.0)

    shards = granular.cloud(dur, np.clip(rng.exponential(0.07, 120), 0, 0.8), shard, rng) * 0.35
    ping = osc.partials([1910.0, 5150.0], [0.6, 0.3], [0.3, 0.1], dur, rng)
    y = shards + ping * 0.5 + thud(rng, 120, dur, 0.5) * 0.4
    place(y, crack, 0)
    return fx.reverb(fade(y, 0, 0.15), "store", 0.12, stereo_out=False, tail=False)


def corpsman_heal(rng: np.random.Generator, v: int) -> np.ndarray:
    """Corpsman heal: bright 2-note chime E6 -> B6 (pure bell). Niche: the only rising
    perfect-fifth sparkle above 1.3 kHz."""
    dur = 1.0
    y = np.zeros(nsamp(dur))
    for i, note in enumerate((88, 95)):
        place(y, seq.bell(note, 0.8, rng, 0.35), nsamp(i * 0.13), 0.6)
    return fx.reverb(y, "plate", 0.15, stereo_out=False, tail=False)


def brandt_arrival(rng: np.random.Generator, v: int) -> np.ndarray:
    """Captain Brandt arrives: brass-like horn sting (stacked detuned saws, D2-A2-D3-F3) with a
    filter swell and a sub hit. Niche: big minor brass chord, 2.6 s."""
    dur = 2.6
    t = tvec(dur)
    y = np.zeros(nsamp(dur))
    for note in (38, 45, 50, 53, 57):
        y += osc.supersaw(midi_hz(note), dur, 3, 10, rng)
    for note in (62, 65, 69):  # bright upper brass voicing
        y += osc.supersaw(midi_hz(note), dur, 3, 12, rng) * 0.8
    cut = 300 + 4800 * env.segments([(0, 0), (0.35, 1), (1.6, 0.6), (dur, 0.2)], dur)
    y = filters.biquad_tv(y, "lp", cut, 2.2) * env.adsr(dur, 0.08, 0.6, 0.7, 0.8)
    y = filters.peak(y, 2000, 6.0, 1.0)
    y = fx.drive(y * 0.5, 1.8) + osc.sine(36 * (1 + np.exp(-t / 0.1)), dur) * env.exp_decay(dur, 0.8) * 0.6
    return fx.reverb(y, "hall", 0.2, stereo_out=True, tail=False)


def aegis_pulse(rng: np.random.Generator, v: int) -> np.ndarray:
    """Captain's Aegis aura loop: low 55 Hz pulse at 1.5 Hz with an 880 Hz harmonic and a
    1.3/2 kHz glassy ring on each throb so it reads over music. Niche: slow throb (1.5 Hz), 2 s seamless loop (3 pulses)."""
    loop = 2.0
    y = np.zeros(nsamp(loop + 0.6))
    for k in range(4):
        p = osc.sine(55.0, 0.6) * env.exp_decay(0.6, 0.5, 0.02)
        p += filters.bp(osc.saw(110.0, 0.6), 880, 3.0) * env.exp_decay(0.6, 0.35, 0.03) * 2.5
        p += osc.partials([1320.0, 1980.0], [0.5, 0.3], [0.25, 0.15], 0.6, rng) * np.minimum(tvec(0.6) / 0.03, 1)
        place(y, p, nsamp(k * loop / 3))
    return wrap_loop_mono(y, nsamp(loop))


def wrap_loop_mono(x: np.ndarray, loop_len: int) -> np.ndarray:
    out = x[:loop_len].copy()
    tail = x[loop_len:]
    out[: tail.shape[0]] += tail
    return out


def bag_lift_start(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bag lift starts: start clunk, a low geared motor (60 Hz) and a periodic chain rattle
    (link clicks at ~11 Hz). Niche: low motor + metallic 11 Hz ratchet, 2.5 s."""
    dur = 2.5
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 80, 0.4, 0.8), 0)
    md = 2.3
    m = _motor(rng, md, 60.0 * np.minimum(1.0, 0.5 + tvec(md) / 0.5)) * env.segments([(0, 0), (0.3, 1), (md, 0.9)], md) * 0.6
    chain = granular.cloud(md, np.arange(0.2, md - 0.05, 1 / 11.0) + rng.uniform(0, 0.004, len(np.arange(0.2, md - 0.05, 1 / 11.0))),
                           lambda i, r: click(r, (r.uniform(1800, 2600), r.uniform(3800, 5000)), 0.04, 8, 0.005, 0.5), rng)
    place(y, m + chain, nsamp(0.15))
    return fade(y, 0, 0.2)


def bag_lift_arrive(rng: np.random.Generator, v: int) -> np.ndarray:
    """Bag lift arrives: heavy stop clunk + single bright bell ding (2.35 kHz)."""
    dur = 1.6
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 75, 0.4, 0.9) * 1.2, 0)
    place(y, click(rng, (1200.0, 2300.0), 0.1, 12, 0.012, 0.9), 0)
    place(y, osc.partials([2350.0, 2350 * 2.76, 2350 * 5.4], [1.0, 0.25, 0.08], [0.45, 0.14, 0.05], 1.2, rng), nsamp(0.3))
    return fx.reverb(y, "store", 0.15, stereo_out=False, tail=False)


def hack_start(rng: np.random.Generator, v: int) -> np.ndarray:
    """Hack starts: terminal chirps (random square pips 1-3 kHz) then a data whirr (band-passed
    noise AM at 23 Hz) with HDD seek ticks. Niche: busy digital chatter, 1.5 s."""
    dur = 1.5
    y = np.zeros(nsamp(dur))
    for i in range(7):
        f = float(rng.choice([1047.0, 1319.0, 1568.0, 2093.0, 2637.0]))
        place(y, osc.square(f, 0.035, 0.5) * env.adsr(0.035, 0.001, 0.02, 0.7, 0.005) * 0.4, nsamp(i * 0.045))
    wd = 1.1
    whirr = filters.bp(noise.white(wd, rng), 1800, 1.0) * (0.6 + 0.4 * osc.sine(23, wd)) * 0.5
    whirr *= env.segments([(0, 0), (0.2, 1), (wd - 0.2, 1), (wd, 0)], wd)
    ticks = granular.cloud(wd, np.sort(rng.uniform(0, wd, 18)),
                           lambda i, r: click(r, (r.uniform(3000, 4500),), 0.02, 6, 0.003, 0.4), rng)
    place(y, whirr + ticks, nsamp(0.35))
    return fade(y, 0, 0.1)


def hack_interrupt(rng: np.random.Generator, v: int) -> np.ndarray:
    """Hack interrupted: two harsh 150 Hz error buzzes, then a reboot whine (sine 300 -> 80 ->
    1200 Hz). Niche: buzzy low-mid error + swooping whine, 1.6 s."""
    dur = 1.6
    y = np.zeros(nsamp(dur))
    for st in (0.0, 0.25):
        b = filters.bp(osc.square(150, 0.18, 0.5), 900, 0.5) * env.adsr(0.18, 0.003, 0.05, 0.9, 0.02)
        place(y, fx.drive(b * 2, 2.0), nsamp(st))
    wd = 1.0
    f = env.segments([(0, 300), (0.35, 80), (wd, 1200)], wd, "exp")
    whine = osc.sine(f, wd) * env.segments([(0, 0), (0.1, 0.6), (0.35, 0.2), (wd - 0.1, 0.6), (wd, 0)], wd)
    place(y, whine, nsamp(0.55))
    return y


def hack_done(rng: np.random.Generator, v: int) -> np.ndarray:
    """Hack complete: three ascending confirmation pips C6-E6-G6 (soft square). Niche: major
    arpeggio, digital timbre (vs corpsman's bells)."""
    dur = 0.6
    y = np.zeros(nsamp(dur))
    for i, f in enumerate((1047.0, 1319.0, 1568.0)):
        pip = filters.lp(osc.square(f, 0.09, 0.5), 4000) * env.adsr(0.09, 0.002, 0.04, 0.7, 0.02)
        place(y, pip * 0.5, nsamp(i * 0.1))
    return fade(y, 0, 0.05)


def escape_arrive(rng: np.random.Generator, v: int) -> np.ndarray:
    """Escape vehicle arrives. v0 van horn (two 350/440 Hz honks), v1 boat horn (long 110 Hz
    blast), v2 helicopter rotor swell (18 Hz blade slap over turbine whine). Positional, far."""
    if v == 0:
        dur = 1.4
        y = np.zeros(nsamp(dur))
        for st, ln in ((0.0, 0.25), (0.4, 0.55)):
            h = (osc.saw(350, ln) + osc.saw(440, ln)) * env.adsr(ln, 0.01, 0.05, 0.9, 0.03)
            place(y, filters.bp(fx.drive(h, 2.0), 900, 0.6), nsamp(st))
        return fx.reverb(y, "alley", 0.25, stereo_out=False, tail=False)
    if v == 1:
        dur = 3.0
        ln = 2.0
        h = osc.saw(110, ln) + osc.saw(110.6, ln, 0.4) + osc.square(55, ln, 0.5) * 0.4
        h = filters.lp(h, 900) * env.adsr(ln, 0.12, 0.3, 0.9, 0.3)
        y = np.zeros(nsamp(dur))
        place(y, h, 0)
        return fx.reverb(y, "alley", 0.35, stereo_out=False, tail=False)
    dur = 4.0
    t = tvec(dur)
    slap = (0.5 + 0.5 * np.cos(2 * np.pi * 18.0 * t)) ** 6
    body = filters.lp(noise.brown(dur, rng), 400) * slap * 2.0 + filters.bp(noise.white(dur, rng), 1200, 0.8) * slap * 0.4
    turbine = osc.sine(2900 * (1 + 0.02 * t / dur), dur) * 0.05
    swell = np.clip(t / 3.0, 0, 1) ** 1.5
    return fade((body + turbine) * swell, 0, 0.3)


def _escape_variant(k: int, label: str) -> Callable[[np.random.Generator, int], np.ndarray]:
    """Fixed escape_arrive variant: renders exactly cue.escape_arrive's variation k (same seed)."""
    def fn(rng: np.random.Generator, v: int) -> np.ndarray:
        return escape_arrive(rng_for("cue.escape_arrive", str(k)), k)
    fn.__name__ = fn.__qualname__ = f"escape_arrive(variant {k}: {label}, seed of cue.escape_arrive#{k})"
    return fn


escape_arrive_van = _escape_variant(0, "van horn")
escape_arrive_boat = _escape_variant(1, "boat horn")
escape_arrive_heli = _escape_variant(2, "heli rotor swell")


# ============================================================ ambience beds


def amb_glasshouse_interior(rng: np.random.Generator, v: int) -> np.ndarray:
    """Room tone: HVAC (pink/brown below 400 Hz), 60 Hz mains hum + harmonics, faint fridge/
    display-case compressor whine at 1.1 kHz, slow fluctuation. Stereo 20 s loop."""
    def render(d: float) -> np.ndarray:
        chans = []
        for ch in range(2):
            hvac = filters.lp(noise.brown(d, rng), 380) * 0.8 + filters.lp(noise.pink(d, rng), 1500) * 0.08
            hvac *= 1 + 0.12 * env.lfo(0.07 + ch * 0.01, d, phase=ch * 0.3)
            hum = (osc.sine(60, d) * 0.08 + osc.sine(120, d) * 0.05 + osc.sine(180, d) * 0.02)
            whine = osc.sine(1102, d) * 0.004 * (1 + 0.5 * env.lfo(0.23, d))
            chans.append(hvac + hum + whine)
        return np.stack(chans, axis=1)
    return make_loop(render, 20.0, 1.5)


def amb_street_dusk(rng: np.random.Generator, v: int) -> np.ndarray:
    """Distant traffic: brown-noise city rumble + passing cars (filtered noise swells panning
    across) + light wind. Stereo 30 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        rumble = np.stack([filters.lp(noise.brown(d, rng), 450) for _ in range(2)], axis=1) * 0.6
        cars = np.zeros((n, 2))
        for k in range(int(d / 3.2)):
            cd = rng.uniform(4.0, 7.0)
            t0 = rng.uniform(-2.0, d - 1.0)
            car = filters.bp(noise.pink(cd, rng), rng.uniform(350, 700), 0.7)
            car *= np.exp(-((np.linspace(-1, 1, nsamp(cd))) ** 2) * 6) * rng.uniform(0.3, 0.8)
            side = rng.choice([-1.0, 1.0])
            pan_curve = np.linspace(-0.8 * side, 0.8 * side, nsamp(cd))
            place(cars, fx.pan(car, pan_curve), nsamp(t0))
        wind = np.stack([filters.biquad_tv(noise.white(d, rng), "bp",
                                           900 + 400 * env.lfo(0.05 + 0.02 * c, d), 0.6) for c in range(2)], axis=1) * 0.04
        return rumble + cars + wind
    return make_loop(render, 30.0, 2.0)


# ============================================================ table

CUES: list[CueSpec] = [
    CueSpec("detect_tick", detect_tick, bus="UI", positional=False, volume_db=-8.0, cooldown_s=0.12),
    CueSpec("detect_full", detect_full, bus="UI", positional=False, volume_db=-2.0, cooldown_s=1.0),
    CueSpec("npc_suspicious", npc_suspicious, bus="Enemies", max_distance=25.0, pitch_jitter=0.08, cooldown_s=1.5),
    CueSpec("pager_beep", pager_beep, bus="Enemies", loop=True, max_distance=30.0, volume_db=-2.0),
    CueSpec("pager_radio", pager_radio, bus="Enemies", loop=True, max_distance=20.0, volume_db=-4.0),
    CueSpec("alarm_bell", alarm_bell, loop=True, max_distance=70.0, volume_db=-3.0),
    CueSpec("alarm_bell_glasshouse", alarm_bell_glasshouse, loop=True, max_distance=70.0, volume_db=-3.0,
            note="per-heist variant of cue.alarm_bell (CuePlayer resolves cue.alarm_bell_<heist>)"),
    CueSpec("police_siren_far", police_siren_far, bus="Ambience", positional=False, loop=True, volume_db=-8.0,
            norm="bed"),
    CueSpec("mask_on", mask_on, max_distance=12.0, pitch_jitter=0.04),
    CueSpec("glass_break", glass_break, variations=4, max_distance=45.0, pitch_jitter=0.05, cooldown_s=0.05),
    CueSpec("drill_loop", drill_loop, loop=True, max_distance=35.0, volume_db=-3.0),
    CueSpec("drill_jam", drill_jam, max_distance=35.0),
    CueSpec("drill_done", drill_done, max_distance=35.0),
    CueSpec("bag_pickup", bag_pickup, max_distance=15.0, pitch_jitter=0.06),
    CueSpec("bag_throw", bag_throw, max_distance=15.0, pitch_jitter=0.06),
    CueSpec("bag_secure", bag_secure, max_distance=20.0),
    CueSpec("small_loot_pickup", small_loot_pickup, max_distance=10.0, pitch_jitter=0.06, volume_db=-3.0),
    CueSpec("weapon_pistol_fire", weapon_pistol_fire, bus="Weapons", variations=4, max_distance=90.0, pitch_jitter=0.03),
    CueSpec("weapon_pistol_fire_suppressed", weapon_pistol_fire_suppressed, bus="Weapons", variations=4,
            max_distance=25.0, pitch_jitter=0.04, volume_db=-4.0),
    CueSpec("weapon_rifle_fire", weapon_rifle_fire, bus="Weapons", variations=4, max_distance=110.0, pitch_jitter=0.03),
    CueSpec("weapon_rifle_fire_suppressed", weapon_rifle_fire_suppressed, bus="Weapons", variations=3,
            max_distance=30.0, pitch_jitter=0.04, volume_db=-4.0),
    CueSpec("weapon_pistol_mag_out", weapon_pistol_mag_out, bus="Weapons", variations=3, max_distance=10.0,
            pitch_jitter=0.03, volume_db=-6.0, note="D-026 viewmodel foley"),
    CueSpec("weapon_pistol_mag_in", weapon_pistol_mag_in, bus="Weapons", variations=3, max_distance=10.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-026 viewmodel foley"),
    CueSpec("weapon_pistol_slide_release", weapon_pistol_slide_release, bus="Weapons", variations=3,
            max_distance=12.0, pitch_jitter=0.03, volume_db=-5.0, note="D-026 viewmodel foley"),
    CueSpec("weapon_smg_fire", weapon_smg_fire, bus="Weapons", variations=4, max_distance=80.0, pitch_jitter=0.03,
            note="D-034"),
    CueSpec("weapon_smg_fire_suppressed", weapon_smg_fire_suppressed, bus="Weapons", variations=3,
            max_distance=30.0, pitch_jitter=0.04, volume_db=-4.0, note="D-034"),
    CueSpec("weapon_shotgun_fire", weapon_shotgun_fire, bus="Weapons", variations=4, max_distance=100.0, pitch_jitter=0.03,
            note="D-034"),
    CueSpec("weapon_shotgun_fire_suppressed", weapon_shotgun_fire_suppressed, bus="Weapons", variations=3,
            max_distance=30.0, pitch_jitter=0.04, volume_db=-4.0, note="D-034"),
    CueSpec("weapon_lmg_fire", weapon_lmg_fire, bus="Weapons", variations=4, max_distance=120.0, pitch_jitter=0.03,
            note="D-034"),
    CueSpec("weapon_lmg_fire_suppressed", weapon_lmg_fire_suppressed, bus="Weapons", variations=3,
            max_distance=30.0, pitch_jitter=0.04, volume_db=-4.0, note="D-034"),
    CueSpec("weapon_sniper_fire", weapon_sniper_fire, bus="Weapons", variations=4, max_distance=160.0, pitch_jitter=0.03,
            note="D-034"),
    CueSpec("weapon_sniper_fire_suppressed", weapon_sniper_fire_suppressed, bus="Weapons", variations=3,
            max_distance=30.0, pitch_jitter=0.04, volume_db=-4.0, note="D-034"),
    CueSpec("weapon_smg_mag_out", weapon_smg_mag_out, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_smg_mag_in", weapon_smg_mag_in, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_smg_bolt", weapon_smg_bolt, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_rifle_mag_out", weapon_rifle_mag_out, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_rifle_mag_in", weapon_rifle_mag_in, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_rifle_bolt", weapon_rifle_bolt, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_shotgun_pump", weapon_shotgun_pump, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_shotgun_shell_in", weapon_shotgun_shell_in, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_lmg_mag_out", weapon_lmg_mag_out, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_lmg_mag_in", weapon_lmg_mag_in, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_lmg_bolt", weapon_lmg_bolt, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_sniper_mag_out", weapon_sniper_mag_out, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_sniper_mag_in", weapon_sniper_mag_in, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("weapon_sniper_bolt", weapon_sniper_bolt, bus="Weapons", variations=2, max_distance=12.0,
            pitch_jitter=0.03, volume_db=-5.0, note="D-034 viewmodel foley"),
    CueSpec("reload_pistol", reload_pistol, bus="Weapons", max_distance=12.0, volume_db=-4.0),
    CueSpec("reload_rifle", reload_rifle, bus="Weapons", max_distance=12.0, volume_db=-4.0),
    CueSpec("dry_fire", dry_fire, bus="Weapons", max_distance=8.0, pitch_jitter=0.03, volume_db=-6.0),
    CueSpec("hitmarker", hitmarker, bus="UI", positional=False, volume_db=-8.0, pitch_jitter=0.02, cooldown_s=0.03),
    CueSpec("headshot", headshot, bus="UI", positional=False, volume_db=-5.0, pitch_jitter=0.02, cooldown_s=0.03),
    CueSpec("assault_start", assault_start, positional=False, volume_db=-1.0, cooldown_s=5.0),
    CueSpec("crew_downed", crew_downed, max_distance=25.0),
    CueSpec("revive", revive, max_distance=20.0),
    CueSpec("door_open", door_open, max_distance=20.0, pitch_jitter=0.05),
    CueSpec("door_close", door_close, max_distance=20.0, pitch_jitter=0.05),
    CueSpec("keycard_beep", keycard_beep, max_distance=12.0, volume_db=-4.0),
    CueSpec("keypad_accept", keypad_accept, max_distance=12.0, volume_db=-4.0, note="QA-15"),
    CueSpec("c4_armed", c4_armed, max_distance=15.0, volume_db=-4.0, note="QA-15 one-shot chirp"),
    CueSpec("c4_explode", c4_explode, variations=3, max_distance=250.0, pitch_jitter=0.03, note="QA-15"),
    CueSpec("time_lock_start", time_lock_start, max_distance=30.0, note="QA-15"),
    CueSpec("time_lock_done", time_lock_done, max_distance=30.0, note="QA-15"),
    CueSpec("laser_trip", laser_trip, max_distance=30.0, volume_db=-2.0, cooldown_s=0.5, note="QA-15"),
    CueSpec("zipline_attach", zipline_attach, max_distance=20.0, pitch_jitter=0.04, note="QA-15"),
    CueSpec("lockpick", lockpick, loop=True, max_distance=8.0, volume_db=-8.0),
    CueSpec("ui_click", ui_click, bus="UI", positional=False, volume_db=-10.0, cooldown_s=0.02),
    CueSpec("phantom_hum", phantom_hum, bus="Enemies", loop=True, max_distance=15.0, volume_db=-2.0, note="QA-28"),
    CueSpec("phantom_charge", phantom_charge, bus="Enemies", max_distance=30.0, cooldown_s=1.0, note="QA-28"),
    CueSpec("stinger_windup", stinger_windup, bus="Enemies", max_distance=30.0, cooldown_s=0.5, note="QA-28"),
    CueSpec("stinger_arc", stinger_arc, bus="Enemies", loop=True, max_distance=25.0, note="QA-28"),
    CueSpec("longshot_report", longshot_report, bus="Enemies", max_distance=300.0, pitch_jitter=0.03, volume_db=2.0,
            note="QA-28"),
    CueSpec("bulwark_bang", bulwark_bang, bus="Enemies", variations=3, max_distance=40.0, pitch_jitter=0.03,
            cooldown_s=0.15, note="QA-28"),
    CueSpec("wrecker_roar", wrecker_roar, bus="Enemies", variations=2, max_distance=60.0, cooldown_s=2.0, note="QA-28"),
    CueSpec("wrecker_step", wrecker_step, bus="Enemies", variations=3, max_distance=30.0, pitch_jitter=0.04,
            note="QA-28"),
    CueSpec("wrecker_plate_crack", wrecker_plate_crack, bus="Enemies", variations=2, max_distance=40.0, note="QA-28"),
    CueSpec("corpsman_heal", corpsman_heal, bus="Enemies", max_distance=30.0, cooldown_s=0.5, note="QA-28"),
    CueSpec("brandt_arrival", brandt_arrival, bus="Enemies", positional=False, volume_db=-2.0, cooldown_s=5.0,
            note="QA-28"),
    CueSpec("aegis_pulse", aegis_pulse, bus="Enemies", loop=True, max_distance=30.0, volume_db=-3.0, note="QA-28"),
    CueSpec("bag_lift_start", bag_lift_start, max_distance=40.0, note="QA-28"),
    CueSpec("bag_lift_arrive", bag_lift_arrive, max_distance=40.0, note="QA-28"),
    CueSpec("hack_start", hack_start, max_distance=15.0, volume_db=-3.0, note="QA-28"),
    CueSpec("hack_interrupt", hack_interrupt, max_distance=20.0, volume_db=-2.0, note="QA-28"),
    CueSpec("hack_done", hack_done, max_distance=15.0, volume_db=-3.0, note="QA-28"),
    CueSpec("escape_arrive", escape_arrive, variations=3, max_distance=200.0,
            note="QA-28: _1 van horn, _2 boat horn, _3 heli rotor swell (variant index chosen by caller or random)"),
    CueSpec("escape_arrive_van", escape_arrive_van, max_distance=200.0, note="QA-28 fixed variant"),
    CueSpec("escape_arrive_boat", escape_arrive_boat, max_distance=200.0, note="QA-28 fixed variant"),
    CueSpec("escape_arrive_heli", escape_arrive_heli, max_distance=200.0, note="QA-28 fixed variant"),
    CueSpec("amb_glasshouse_interior", amb_glasshouse_interior, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed"),
    CueSpec("amb_street_dusk", amb_street_dusk, bus="Ambience", positional=False, loop=True, volume_db=-12.0,
            norm="bed"),
]
