"""Tiny music sequencer: tempo grid, chord helpers, drum synths and tonal instruments.

Everything renders into numpy buffers; a `Song` owns named stereo buses that are mixed at the end.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from . import env, filters, fx, noise, osc
from .core import SR, as_array, midi_hz, nsamp, place

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
QUALITY = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11),
    "m9": (0, 3, 7, 10, 14), "madd9": (0, 3, 7, 14), "sus4": (0, 5, 7), "7sus4": (0, 5, 7, 10),
    "maj7#11": (0, 4, 7, 11, 18), "dim": (0, 3, 6), "5": (0, 7, 12), "add9": (0, 4, 7, 14),
}


def chord(name: str, octave: int = 4) -> list[int]:
    """'Am7' -> MIDI notes rooted in the given octave (C4 = 60)."""
    root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    q = name[len(root):]
    base = 12 * (octave + 1) + NOTE[root]
    return [base + i for i in QUALITY[q]]


def root_of(name: str, octave: int = 2) -> int:
    return chord(name, octave)[0]


@dataclass
class Song:
    bpm: float
    beats_per_bar: int = 4
    bars: int = 16
    tail_s: float = 4.0
    buses: dict[str, np.ndarray] = field(default_factory=dict)

    @property
    def beat_s(self) -> float:
        return 60.0 / self.bpm

    @property
    def bar_s(self) -> float:
        return self.beat_s * self.beats_per_bar

    @property
    def length_s(self) -> float:
        return self.bar_s * self.bars

    @property
    def loop_samples(self) -> int:
        return int(round(self.length_s * SR))

    def t(self, bar: float, beat: float = 0.0) -> float:
        return bar * self.bar_s + beat * self.beat_s

    def bus(self, name: str) -> np.ndarray:
        if name not in self.buses:
            self.buses[name] = np.zeros((self.loop_samples + nsamp(self.tail_s), 2))
        return self.buses[name]

    def add(self, bus: str, sound: np.ndarray, time_s: float, gain: float = 1.0, pan_pos: float = 0.0) -> None:
        s = fx.pan(sound, pan_pos) if sound.ndim == 1 else sound
        place(self.bus(bus), s, int(round(time_s * SR)), gain)

    def steps(self, pattern: str, bar: int, step_div: int = 4) -> list[float]:
        """Times for an 'x...x...' step pattern (one char per 1/step_div beat) starting at bar."""
        out = []
        for i, ch in enumerate(pattern):
            if ch not in ".-_ ":
                out.append(self.t(bar, i / step_div))
        return out


# ------------------------------------------------------------------ drums


def kick(rng: np.random.Generator, punch: float = 1.0, f_end: float = 46.0, dur: float = 0.45) -> np.ndarray:
    t = np.arange(nsamp(dur)) / SR
    f = f_end + (160 * punch) * np.exp(-t / 0.028) + 40 * np.exp(-t / 0.005)
    body = osc.sine(f, dur) * env.exp_decay(dur, dur * 0.9, 0.0008)
    click = filters.hp(noise.white(0.006, rng), 2500) * np.linspace(1, 0, nsamp(0.006))
    out = fx.drive(body, 1.6) + np.pad(click, (0, body.shape[0] - click.shape[0])) * 0.35
    return out


def snare(rng: np.random.Generator, tone_hz: float = 190.0, dur: float = 0.32, snap: float = 1.0) -> np.ndarray:
    t = np.arange(nsamp(dur)) / SR
    tone = (osc.sine(tone_hz * (1 + 0.5 * np.exp(-t / 0.01)), dur) * 0.6
            + osc.sine(tone_hz * 1.6, dur) * 0.25) * env.exp_decay(dur, 0.12)
    nz = filters.bp(noise.white(dur, rng), 4200, 0.6) * 2.2 + filters.hp(noise.white(dur, rng), 7000) * 0.6
    rattle = nz * env.exp_decay(dur, 0.22 * snap)
    return fx.drive(tone + rattle, 1.4)


def clap(rng: np.random.Generator, dur: float = 0.35) -> np.ndarray:
    n = nsamp(dur)
    e = np.zeros(n)
    for k, off in enumerate((0.0, 0.009, 0.017, 0.026)):
        seg = env.exp_decay(dur - off, 0.012 if k < 3 else 0.2)
        place(e, seg, nsamp(off))
    return filters.bp(noise.white(dur, rng), 1300, 1.2) * e * 2.5


def hat(rng: np.random.Generator, open_: bool = False, dur: float | None = None) -> np.ndarray:
    d = dur or (0.38 if open_ else 0.06)
    metal = sum(osc.square(f, d) for f in (205.3, 369.6, 304.4, 522.7, 540.0, 800.0)) / 6
    src = metal * 0.7 + noise.white(d, rng) * 0.6
    src = filters.hp(filters.bp(src, 9500, 0.7), 6500)
    return src * env.exp_decay(d, 0.32 if open_ else 0.045, 0.0003) * 2.0


def tom(rng: np.random.Generator, f0: float = 110.0, dur: float = 0.5) -> np.ndarray:
    t = np.arange(nsamp(dur)) / SR
    body = osc.sine(f0 * (1 + 0.6 * np.exp(-t / 0.03)), dur) * env.exp_decay(dur, 0.35)
    return body + filters.lp(noise.white(dur, rng), 2500) * env.exp_decay(dur, 0.03) * 0.3


def rim(rng: np.random.Generator, f0: float = 1700.0) -> np.ndarray:
    d = 0.05
    return (osc.sine(f0, d) * 0.6 + filters.bp(noise.white(d, rng), 3500, 3) * 1.5) * env.exp_decay(d, 0.025, 0.0002)


def shaker(rng: np.random.Generator, dur: float = 0.09) -> np.ndarray:
    nz = filters.hp(noise.white(dur, rng), 5500)
    e = env.segments([(0, 0), (dur * 0.35, 1), (dur, 0)], dur)
    return nz * e


def impact(rng: np.random.Generator, dur: float = 2.5) -> np.ndarray:
    """Cinematic boom: sub drop + noise burst."""
    t = np.arange(nsamp(dur)) / SR
    sub = osc.sine(32 + 60 * np.exp(-t / 0.15), dur) * env.exp_decay(dur, 2.0, 0.002)
    nz = filters.lp(noise.brown(dur, rng), 900) * env.exp_decay(dur, 0.9)
    return fx.drive(sub * 1.2 + nz * 0.8, 1.5)


def riser(rng: np.random.Generator, dur: float, f0: float = 300.0, f1: float = 6000.0) -> np.ndarray:
    nz = noise.white(dur, rng)
    f = np.geomspace(f0, f1, nsamp(dur))
    sweep = filters.biquad_tv(nz, "bp", f, 2.5)
    e = np.linspace(0, 1, nsamp(dur)) ** 2
    return sweep * e * 1.5


# ------------------------------------------------------------------ tonal instruments


def bass(note: int, dur: float, rng: np.random.Generator, cutoff: float = 900.0, res: float = 0.35,
         env_amt: float = 2.0, sub: float = 0.6) -> np.ndarray:
    f = midi_hz(note)
    tone = osc.saw(f, dur, float(rng.random())) * 0.6 + osc.square(f * 0.5, dur, 0.5) * 0.25 * sub
    tone += osc.sine(f * 0.5, dur) * sub
    fenv = cutoff * (1 + env_amt * env.exp_decay(dur, 0.18))
    y = filters.resonant_lp(tone, fenv, res)
    return fx.drive(y * env.adsr(dur, 0.003, 0.15, 0.7, min(0.05, dur * 0.3)), 1.3)


def pad(notes: list[int], dur: float, rng: np.random.Generator, cutoff: float | np.ndarray = 1800.0,
        attack: float = 0.8, release: float = 1.2, detune: float = 9.0) -> np.ndarray:
    """Detuned-saw pad, stereo (left/right voices detuned differently)."""
    n = nsamp(dur + release)
    lr = np.zeros((n, 2))
    for note in notes:
        f = midi_hz(note)
        for ch in range(2):
            v = osc.supersaw(f, dur + release, 3, detune * (1.0 + 0.3 * ch), rng)
            lr[:, ch] += v
    lr /= max(1, len(notes)) ** 0.7
    lr = filters.biquad_tv(lr, "lp", cutoff if np.isscalar(cutoff) else as_array(cutoff, n), 0.8)
    e = env.adsr(dur + release, attack, 1.0, 0.85, release, curve=2.5)
    return lr * e[:, None]


def bell(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Glassy FM bell (inharmonic ratio 3.5) + a pure sine body: the Glasshouse motif timbre."""
    f = midi_hz(note)
    idx = 2.6 * bright * env.exp_decay(dur, dur * 0.35)
    y = osc.fm(f, 3.5, idx, dur) * env.exp_decay(dur, dur, 0.001) * 0.6
    y += osc.sine(f * 2.0, dur) * env.exp_decay(dur, dur * 0.4, 0.001) * 0.2
    y += osc.sine(f, dur) * env.exp_decay(dur, dur * 1.2, 0.002) * 0.35
    return y


def pluck(note: int, dur: float, rng: np.random.Generator, cutoff: float = 2500.0) -> np.ndarray:
    f = midi_hz(note)
    y = osc.square(f, dur, 0.3) * 0.5 + osc.saw(f * 1.005, dur) * 0.5
    y = filters.biquad_tv(y, "lp", cutoff * (0.3 + 2.0 * env.exp_decay(dur, 0.12)), 1.5)
    return y * env.exp_decay(dur, dur * 0.6, 0.001)


def stab(notes: list[int], dur: float, rng: np.random.Generator, cutoff: float = 3000.0) -> np.ndarray:
    y = np.zeros(nsamp(dur))
    for note in notes:
        y += osc.supersaw(midi_hz(note), dur, 3, 12.0, rng)
    y /= len(notes) ** 0.7
    y = filters.biquad_tv(y, "lp", cutoff * (0.4 + 1.6 * env.exp_decay(dur, 0.08)), 1.2)
    return fx.drive(y * env.adsr(dur, 0.002, 0.08, 0.3, dur * 0.4), 1.5)


def drone(note: int, dur: float, rng: np.random.Generator, cutoff: float = 400.0) -> np.ndarray:
    f = midi_hz(note)
    y = osc.saw(f, dur) + osc.saw(f * 1.004, dur, 0.37) + osc.triangle(f * 0.5, dur) * 0.8
    lfo = 1 + 0.4 * env.lfo(0.11, dur)
    return filters.biquad_tv(y, "lp", cutoff * lfo, 1.1) * 0.4
