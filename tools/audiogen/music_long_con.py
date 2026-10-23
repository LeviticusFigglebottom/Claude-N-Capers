"""The Long Con (`long_con`, C5-01): an unlockable jukebox / heist track. G dorian, 120 BPM grid, 4/4.

Identity: noir swagger. A plucked walking bass, brushed rim and shaker, harpsichord comping (the con man's
patter) and a sly two-bar motif: G Bb C D | F E D Bb (answered by C D Bb G). Progression i - IV - i - v in dorian
(Gm7 C7 Gm7 Dm7), Ebmaj7 on the turn. Stealth is 32 bars of the grid played half-time (60 BPM feel); control /
anticipation / assault / fade are 16 bars each on the one bar grid. Mix room: "store" (a small club).
Original material, synthesized from the shared engine (music_engine.py).
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_bass, part_hits, part_kick, part_stabs
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "long_con"
KEY = "G dorian"
PALETTE = "plucked walking bass, harpsichord comping, rim + shaker, warm pads, finger snaps"
BPM = 120.0
BEATS_PER_BAR = 4
PROG8 = ["Gm7", "Gm7", "C7", "C7", "Gm7", "Ebmaj7", "Dm7", "Dm7"]
MOTIF = [(0.0, 67, 0.5), (0.5, 70, 0.5), (1.0, 72, 0.5), (1.5, 74, 1.0), (2.5, 77, 0.5), (3.0, 76, 0.5),
         (3.5, 74, 0.5)]
ANSWER = [(0.0, 72, 0.5), (0.5, 74, 0.5), (1.0, 70, 1.0), (2.0, 67, 2.0)]
# walking-bass degrees (semitones over the bar's root) on the four beats
WALK = [(0, 3, 5, 7), (0, 7, 5, 3), (0, 2, 3, 5), (0, -2, -3, -5)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _walk(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, gain: float, cutoff: float,
          eighths: bool = False) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), 2)
        steps = WALK[b % len(WALK)]
        for i, deg in enumerate(steps):
            s.add("bass", seq.pluck(root + deg, s.beat_s * 0.9, rng, cutoff), s.t(b, float(i)), gain)
            if eighths and i % 2 == 1:
                s.add("bass", seq.pluck(root + deg + 12, s.beat_s * 0.4, rng, cutoff), s.t(b, i + 0.5), gain * 0.5)


def _comp(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str, gain: float,
          bright: float = 1.0) -> None:
    for b in bars:
        notes = seq.chord(me.chord_at(prog, b), 4)[1:]
        for t in s.steps(pattern, b):
            for k, note in enumerate(notes):
                s.add("keys", me.harpsichord(note, s.beat_s * 0.7, rng, bright), t + 0.008 * k, gain,
                      -0.2 + 0.2 * k)


def _lead(s: seq.Song, rng: np.random.Generator, bar: int, phrase: list[tuple[float, int, float]], gain: float,
          transpose: int = 0) -> None:
    for beat, note, beats in phrase:
        s.add("lead", me.harpsichord(note + transpose, max(0.4, beats * s.beat_s * 1.4), rng, 1.3),
              s.t(bar, beat), gain, 0.15)


def _snap(rng: np.random.Generator) -> np.ndarray:
    return seq.clap(rng, 0.18)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @120 = 16 bars of 60 BPM: the walking bass on half-time quarters, finger snaps on the backbeat, soft
    pads and the motif as quiet harpsichord once per 8 bars."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 6.0)
    prog = ["Gm7", "C7", "Gm7", "Dm7"]
    for i, name in enumerate(prog):
        s.add("keys", seq.pad(seq.chord(name, 3), s.bar_s * 8 * 0.97, rng, 900.0, attack=1.6, release=1.5),
              s.t(i * 8), 0.32)
    for b in range(0, 32, 2):
        root = seq.root_of(prog[b // 8], 2)
        for i, deg in enumerate(WALK[(b // 2) % len(WALK)]):
            s.add("bass", seq.pluck(root + deg, s.beat_s * 1.6, rng, 900.0), s.t(b + i // 2, 2.0 * (i % 2)), 0.55)
    part_hits(s, "perc", lambda: _snap(rng), range(32), "........x.......", 0.16, 0.2)
    part_hits(s, "perc", lambda: seq.shaker(rng), range(16, 32), "x.......x.......", 0.08, -0.3)
    for b in (6, 22):
        _lead(s, rng, b, MOTIF, 0.12, -12)
    return mixdown(s, [], duck=0.0, keys_verb=0.3, lead_verb=0.35, room="store")


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.........x.....", 0.75)
    part_hits(s, "drums", lambda: seq.rim(rng, 1500), range(16), "....x.......x...", 0.3)
    part_hits(s, "perc", lambda: seq.shaker(rng), range(16), "x.x.x.x.x.x.x.x.", 0.09, -0.3, 0.3, rng)
    _walk(s, rng, PROG8, range(16), 0.6, 1100.0)
    _comp(s, rng, PROG8, range(16), "..x.....x.x.....", 0.11)
    _lead(s, rng, 4, MOTIF, 0.2)
    _lead(s, rng, 12, ANSWER, 0.2)
    return mixdown(s, hits, duck=0.3, room="store")


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.........x.....", 0.85)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 0.95)
    part_hits(s, "drums", lambda: seq.rim(rng, 1500), range(16), "....x..x....x...", 0.3)
    part_hits(s, "perc", lambda: seq.shaker(rng), range(16), "xxxxxxxxxxxxxxxx", 0.07, -0.3, 0.4, rng)
    _walk(s, rng, PROG8, range(16), 0.6, 1300.0, eighths=True)
    _comp(s, rng, PROG8, range(8, 16), "x..x..x...x..x..", 0.12, 1.2)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 260, 5000), s.t(8), 0.15)

    def roll(b: int) -> str:
        return {14: "....x.......x.x.", 15: "x.x.x.x.xxxxxxxx"}.get(b, "")

    for b in (14, 15):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 220, 0.18, 0.5), t, 0.18 + 0.12 * (i / 16))
    _lead(s, rng, 8, MOTIF, 0.22)
    return mixdown(s, hits, duck=0.4, drive=1.15, room="store")


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x..x..x...x.x..." if b % 4 == 3 else "x..x......x....."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 210), range(16), "....x.......x...", 0.7)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.xxx.xxx.xxx.xx", 0.11, 0.25, 0.5, rng)
    part_hits(s, "perc", lambda: _snap(rng), range(16), "....x.......x...", 0.14, 0.3)
    part_bass(s, rng, PROG8, range(16), "x..x.x.xx..x.x.x", 900.0, octave_up="...o.......o....", gain=0.7, gate=0.7,
              res=0.45)
    _comp(s, rng, PROG8, range(16), "..x..x..x..x..x.", 0.13, 1.4)
    part_stabs(s, rng, PROG8, range(4, 16), "x.......x..x....", 0.2)
    for b in (4, 8, 12):
        _lead(s, rng, b, MOTIF, 0.3)
        _lead(s, rng, b + 2, ANSWER, 0.28)
    s.add("fx", seq.impact(rng, 2.5), s.t(4), 0.3)
    return mixdown(s, hits, duck=0.55, room="store")


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.........x.....", 0.7)
    part_hits(s, "drums", lambda: seq.rim(rng, 1500), range(16), "............x...", 0.24)
    part_hits(s, "perc", lambda: seq.shaker(rng), range(16), "x...x...x...x...", 0.07, -0.3)
    _walk(s, rng, PROG8, range(16), 0.55, 900.0)
    for b in range(0, 16, 4):
        s.add("keys", seq.pad(seq.chord(me.chord_at(PROG8, b), 3), s.bar_s * 4 * 0.97, rng, 1000.0, attack=1.0,
                              release=1.2), s.t(b), 0.3)
    _lead(s, rng, 8, ANSWER, 0.18, -12)
    return mixdown(s, hits, duck=0.35, master_lp=5000, room="store")


def stinger_win() -> np.ndarray:
    """The con closes: a harpsichord run up G dorian, a G6/9 chord, a snap and a cymbal-like impact."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(5.0), 2))
    for i, note in enumerate((67, 69, 70, 72, 74, 76, 77, 79)):
        place(out, fx.pan(me.harpsichord(note, 0.8, rng, 1.2), -0.4 + 0.1 * i), nsamp(i * 0.07), 0.3)
    for k, note in enumerate((55, 59, 64, 69, 74)):
        place(out, fx.pan(me.harpsichord(note, 2.5, rng), -0.3 + 0.15 * k), nsamp(0.62 + 0.01 * k), 0.3)
    place(out, fx.pan(seq.pluck(43, 2.0, rng, 900.0), 0.0), nsamp(0.62), 0.5)
    place(out, fx.pan(_snap(rng), 0.2), nsamp(0.62), 0.3)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), nsamp(0.62), 0.2)
    return fx.reverb(out, "store", 0.3, tail=False)


def stinger_lose() -> np.ndarray:
    """Busted: the walking bass slows and falls (G F Eb D Db), a dissonant harpsichord cluster, a low thud."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(5.0), 2))
    for i, note in enumerate((43, 41, 39, 38, 37)):
        place(out, fx.pan(seq.pluck(note, 1.0, rng, 800.0), 0.0), nsamp(i * (0.3 + 0.08 * i)), 0.55)
    for k, note in enumerate((61, 62, 67, 68)):
        place(out, fx.pan(me.harpsichord(note, 2.5, rng, 0.8), -0.3 + 0.2 * k), nsamp(2.2), 0.24)
    place(out, fx.pan(seq.impact(rng, 2.5), 0), nsamp(2.2), 0.3)
    place(out, fx.pan(seq.drone(31, 3.0, rng, 220) * env.adsr(3.0, 0.3, 1, 0.8, 1.5), 0), nsamp(2.0), 0.3)
    return fx.reverb(out, "store", 0.35, tail=False)


STEMS: dict[str, Callable[[], np.ndarray]] = {
    "stealth": stem_stealth,
    "control": stem_control,
    "anticipation": stem_anticipation,
    "assault": stem_assault,
    "fade": stem_fade,
}
STINGERS: dict[str, Callable[[], np.ndarray]] = {"win": stinger_win, "lose": stinger_lose}
STEM_GAIN_DB: dict[str, float] = {"stealth": -6.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0,
                                  "fade": -3.0, "win": -2.0, "lose": -2.0}
BARS: dict[str, int] = {"stealth": 32, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
