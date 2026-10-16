"""Nightfall Depository music track (`night_deposit`, D-117): harbour-night bank job, C minor, 140 BPM grid.

Doc (night_deposit.md Audio/lighting): stealth 70 BPM with low brass and sub pulses and a ticking motif
tied to the time lock; assault 140 BPM. Stealth is 32 bars of the 140 grid played half-time (= 70 BPM),
so every stem shares one bar grid and MusicDirector can switch on any bar line.

Identity: low brass section (saw + pulse, lip scoop, delayed vibrato) instead of Golden Hour's glass
bells; a clock tick-tock ("time lock") that tightens through the stealth bed; sub pulses on the half-time
downbeat. Motif (brass): C Eb G | F Eb D, answered by Ab G. Progression i - VI - iv - V
(Cm Ab Fm G). Mix room: the marble banking hall ("hall").
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_bass, part_hits, part_kick, part_ticks
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "night_deposit"
KEY = "C minor"
PALETTE = "low brass section, sub pulses, clock tick-tock (time lock), saw bass, dry kit"
BPM = 140.0
BEATS_PER_BAR = 4
PROG8 = ["Cm", "Cm", "Ab", "Ab", "Fm", "Fm", "G", "G"]
# (beat, midi note, beats) on the brass
MOTIF = [(0.0, 60, 1.0), (1.0, 63, 0.5), (1.5, 67, 1.5), (3.0, 65, 0.5), (3.5, 63, 0.5)]
MOTIF_ANSWER = [(0.0, 62, 1.5), (1.5, 68, 1.0), (2.5, 67, 1.5)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _brass_phrase(s: seq.Song, rng: np.random.Generator, bar: int, phrase: list[tuple[float, int, float]],
                  gain: float, transpose: int = 0, cutoff: float = 1500.0) -> None:
    for beat, note, beats in phrase:
        d = beats * s.beat_s * 0.95
        s.add("lead", me.brass([note + transpose], d, rng, cutoff, 0.05), s.t(bar, beat), gain, 0.1)


def _brass_chords(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int,
                  octave: int, cutoff: float, gain: float, swell: float) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        notes = seq.chord(me.chord_at(prog, b), octave)
        d = s.bar_s * bars_per * 0.98
        s.add("keys", fx.widen(me.brass(notes, d, rng, cutoff, swell, 0.6), 9), s.t(b), gain)


def _brass_stabs(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str, gain: float,
                 cutoff: float = 2200.0) -> None:
    for b in bars:
        notes = seq.chord(me.chord_at(prog, b), 3)
        st = me.brass(notes, s.beat_s * 0.4, rng, cutoff, 0.01, 0.0)
        for t in s.steps(pattern, b):
            s.add("lead", fx.widen(st, 6), t, gain)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @140 = 16 bars of 70 BPM. Low brass swells, sub pulses, the time-lock tick-tock
    (half notes, then quarters from bar 16 = the lock counting down), sparse brass motif."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["Cm", "Abmaj7", "Fm", "G7sus4"]
    for i, name in enumerate(prog):
        for half in range(2):
            notes = seq.chord(name, 2)[:3] if half == 0 else seq.chord(name, 3)[:3]
            d = s.bar_s * 4 * 0.98
            s.add("keys", fx.widen(me.brass(notes, d, rng, 520 + 140 * half, 1.6, 0.4), 11), s.t(i * 8 + half * 4),
                  0.5)
    s.add("bass", fx.pan(seq.drone(36, s.length_s, rng, 220), 0.0), 0.0, 0.45)
    for b in range(32):
        root = seq.root_of(prog[b // 8], 1)
        for beat, g in ((0.0, 1.0), (2.0, 0.45)):
            s.add("bass", seq.bass(root, 0.35, rng, 200, 0.1, 0.5, 0.9), s.t(b, beat), 0.75 * g)
    part_ticks(s, rng, range(0, 16), "x.......X.......", 0.16, 3000.0, 2100.0, 0.25)
    part_ticks(s, rng, range(16, 32), "x...X...x...X...", 0.17, 3000.0, 2100.0, 0.25)
    for b in (4, 12, 20, 28):
        _brass_phrase(s, rng, b, MOTIF if b % 8 == 4 else MOTIF_ANSWER, 0.22, -12, 900.0)
    for k in range(10):  # harbour: far-off rigging clinks
        t0 = float(rng.uniform(0, s.length_s))
        s.add("fx", me.clang(rng, float(rng.uniform(900, 1400)), 1.2, 0.6), t0, 0.025, float(rng.uniform(-0.8, 0.8)))
    return mixdown(s, [], duck=0.0, keys_verb=0.35, lead_verb=0.45)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.9)
    part_hits(s, "drums", lambda: seq.rim(rng, 1400), range(16), "............x...", 0.3)
    part_ticks(s, rng, range(16), "x.x.X.x.x.x.X.x.", 0.12, 3200.0, 2200.0, -0.2)
    part_hits(s, "drums", lambda: seq.hat(rng), range(8, 16), "..x...x...x...x.", 0.2, 0.2, 0.4, rng)
    part_bass(s, rng, PROG8, range(16), "x..x..x.x..x..x.", 380.0, gain=0.65)
    _brass_chords(s, rng, PROG8, range(16), 2, 3, 900.0, 0.32, 0.6)
    _brass_phrase(s, rng, 4, MOTIF, 0.3, 0, 1300.0)
    _brass_phrase(s, rng, 12, MOTIF_ANSWER, 0.3, 0, 1300.0)
    return mixdown(s, hits, duck=0.35)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", lambda b: 280 + 85 * b, gain=0.55, gate=0.7, res=0.5)
    part_ticks(s, rng, range(0, 8), "x...X...x...X...", 0.14, 3200.0, 2200.0)
    part_ticks(s, rng, range(8, 16), "x.x.X.x.x.x.X.x.", 0.15, 3200.0, 2200.0)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 190, 0.2, 0.6), t, 0.2 + 0.05 * (b - 12) + 0.15 * (i / 16))
    _brass_chords(s, rng, PROG8, range(16), 4, 2, 700.0, 0.4, 2.0)
    _brass_stabs(s, rng, PROG8, range(8, 16), "x.......x.....x.", 0.2)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 220, 6500), s.t(8), 0.18)
    _brass_phrase(s, rng, 8, MOTIF, 0.25, -12, 1000.0)
    return mixdown(s, hits, duck=0.45, drive=1.2)  # soft-clips the snare-roll peaks (OGG true peak)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x..x..x.x..x.x.." if b % 4 == 3 else "x..x....x..x...."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 180), range(16), "....x.......x...", 0.75)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.xxx.xxx.xxx.xx", 0.12, 0.25, 0.5, rng)
    part_hits(s, "perc", lambda: seq.tom(rng, 85), [7, 15], "........x.x.x.x.", 0.45)
    part_ticks(s, rng, range(16), "x.x.x.x.x.x.x.x.", 0.1, 3400.0)
    part_bass(s, rng, PROG8, range(16), "x-xx-xx-x-xx-xx-", 820.0, octave_up="...o..o....o..o.", gain=0.75,
              gate=0.8, res=0.4)
    _brass_chords(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.22, 0.3)
    _brass_stabs(s, rng, PROG8, range(4, 16), "x..x..x.....x...", 0.24)
    for b in (8, 10, 12, 14):
        _brass_phrase(s, rng, b, MOTIF, 0.4, 0, 2000.0)
        _brass_phrase(s, rng, b + 1, MOTIF_ANSWER, 0.36, 0, 1800.0)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 350, 8000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.35)
    return mixdown(s, hits, duck=0.6)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.18, 0.2, 0.3, rng)
    part_ticks(s, rng, range(16), "x.......X.......", 0.14, 3000.0, 2100.0)
    part_bass(s, rng, PROG8, range(16), "x-x-x-x-x-x-x-x-", 480.0, gain=0.6)
    _brass_chords(s, rng, PROG8, range(16), 2, 3, 800.0, 0.38, 0.9)
    for b in (4, 12):
        _brass_phrase(s, rng, b, MOTIF_ANSWER, 0.28, -12, 900.0)
    return mixdown(s, hits, duck=0.4, master_lp=4500)


def stinger_win() -> np.ndarray:
    """Brass fanfare that lands on C major (Picardy third), a last tick, a sub hit."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((48, 55, 60, 64, 67)):
        place(out, fx.pan(me.brass([note], 3.2 - i * 0.2, rng, 1800, 0.04), -0.3 + 0.15 * i), nsamp(i * 0.12), 0.32)
    place(out, fx.widen(me.brass(seq.chord("C", 3), 3.5, rng, 1500, 0.3), 9), nsamp(0.6), 0.45)
    place(out, fx.pan(seq.bass(36, 3.5, rng, 400, 0.2, 1.0, 1.0) * env.adsr(3.5, 0.005, 1.0, 0.8, 2.5), 0), 0, 0.5)
    place(out, fx.pan(me.tick(rng, 2400), 0.2), nsamp(0.0), 0.4)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), 0, 0.3)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """Falling brass (Eb D C B), the time lock tick stopping, a sub boom."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((63, 62, 60, 59)):
        place(out, fx.pan(me.brass([note - 12, note], 1.4, rng, 1100, 0.08), 0.25 - 0.15 * i), nsamp(i * 0.42), 0.32)
    for i in range(5):
        place(out, fx.pan(me.tick(rng, 3000 - 250 * i), 0.3), nsamp(i * (0.2 + 0.06 * i)), 0.3 * (1 - i * 0.15))
    place(out, fx.widen(me.brass(seq.chord("Fm", 2), 3.5, rng, 600, 0.6), 10), nsamp(1.6), 0.42)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), nsamp(1.6), 0.35)
    place(out, fx.pan(seq.drone(36, 4.0, rng, 260) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(1.0), 0.4)
    return fx.reverb(out, "hall", 0.4, tail=False)


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
