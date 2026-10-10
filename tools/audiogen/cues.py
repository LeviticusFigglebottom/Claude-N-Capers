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
from synth.core import SR, fade, fit, loop_xfade, midi_hz, nsamp, place, stereo, tvec


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
    CueSpec("lockpick", lockpick, loop=True, max_distance=8.0, volume_db=-8.0),
    CueSpec("ui_click", ui_click, bus="UI", positional=False, volume_db=-10.0, cooldown_s=0.02),
    CueSpec("amb_glasshouse_interior", amb_glasshouse_interior, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed"),
    CueSpec("amb_street_dusk", amb_street_dusk, bus="Ambience", positional=False, loop=True, volume_db=-12.0,
            norm="bed"),
]
