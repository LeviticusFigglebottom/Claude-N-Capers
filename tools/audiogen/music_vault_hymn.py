"""Vault Hymn (`vault_hymn`, C5-01): an unlockable jukebox / heist track. D minor, 128 BPM grid, 4/4.

Identity: a cathedral of steel. An organ-like string choir (slow bowed chords, no kit in stealth), tolling
bells on the half-bar, timpani that grow into the assault, and a hymn motif in long notes:
D F E D | C D A (answered A Bb A G F E). Progression i - VI - III - VII (Dm Bb F C), with a v (Am) turn.
Stealth is 32 bars of the grid played half-time (64 BPM feel); control / anticipation / assault / fade are
16 bars each, all on the one bar grid so MusicDirector can switch on any bar line. Mix room: "hall".
Original material, synthesized from the shared engine (music_engine.py).
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_bass, part_hits, part_kick
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "vault_hymn"
KEY = "D minor"
PALETTE = "string choir (supersaw, slow bow), tolling bells, timpani, sub bass, sparse kit"
BPM = 128.0
BEATS_PER_BAR = 4
PROG8 = ["Dm", "Dm", "Bb", "Bb", "F", "F", "C", "Am"]
HYMN = [(0.0, 62, 1.0), (1.0, 65, 1.0), (2.0, 64, 1.0), (3.0, 62, 1.0)]
HYMN_B = [(0.0, 60, 1.0), (1.0, 62, 1.0), (2.0, 69, 2.0)]
ANSWER = [(0.0, 69, 0.5), (0.5, 70, 0.5), (1.0, 69, 1.0), (2.0, 67, 0.5), (2.5, 65, 0.5), (3.0, 64, 1.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _choir(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, octave: int,
           cutoff: float, gain: float, attack: float = 0.8) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        notes = seq.chord(me.chord_at(prog, b), octave)
        s.add("keys", me.strings(notes, s.bar_s * bars_per * 0.97, rng, cutoff, attack, 1.2), s.t(b), gain)


def _hymn(s: seq.Song, rng: np.random.Generator, bar: int, phrase: list[tuple[float, int, float]], gain: float,
          transpose: int = 0) -> None:
    for beat, note, beats in phrase:
        d = beats * s.beat_s * 0.96
        s.add("lead", me.strings([note + transpose], d, rng, 2400.0, 0.12, 0.5, 4.6), s.t(bar, beat), gain)


def _bells(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, beats: tuple[float, ...],
           gain: float) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), 4)
        for beat in beats:
            s.add("lead", seq.bell(root + 12, 2.8, rng, 0.8), s.t(b, beat), gain, 0.2 * np.sin(b))


def _timps(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str, gain: float) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), 2)
        for t in s.steps(pattern, b):
            s.add("perc", me.timpani(root, 1.4, rng), t, gain)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @128 = 16 bars of 64 BPM: the string choir alone, a tolling bell every bar, a sub drone and the hymn
    in the low strings twice. No kit."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["Dm", "Bb", "F", "C"]
    for i, name in enumerate(prog):
        for half in range(2):
            notes = seq.chord(name, 3)
            s.add("keys", me.strings(notes, s.bar_s * 4 * 0.98, rng, 900.0 + 300.0 * half, 2.0, 1.6), s.t(i * 8 + half * 4),
                  0.42)
    s.add("bass", fx.pan(seq.drone(38, s.length_s, rng, 200), 0.0), 0.0, 0.42)
    for b in range(32):
        root = seq.root_of(prog[b // 8], 4)
        s.add("lead", seq.bell(root + 12, 3.5, rng, 0.6), s.t(b), 0.09 if b % 2 else 0.14, 0.3 * np.sin(b * 0.7))
    _hymn(s, rng, 8, HYMN, 0.2, -12)
    _hymn(s, rng, 24, HYMN_B, 0.2, -12)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.5)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.8)
    part_hits(s, "drums", lambda: seq.rim(rng, 1300), range(16), "....x.......x...", 0.25)
    _timps(s, rng, PROG8, range(0, 16, 4), "x...............", 0.35)
    part_bass(s, rng, PROG8, range(16), "x.......x...x...", 420.0, gain=0.6)
    _choir(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.34)
    _bells(s, rng, PROG8, range(16), (0.0,), 0.1)
    _hymn(s, rng, 4, HYMN, 0.28)
    _hymn(s, rng, 12, HYMN_B, 0.28)
    return mixdown(s, hits, duck=0.35)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", lambda b: 300 + 70 * b, gain=0.55, gate=0.7, res=0.45)
    _timps(s, rng, PROG8, range(0, 8), "x.......x.......", 0.38)
    _timps(s, rng, PROG8, range(8, 16), "x...x...x...x...", 0.42)

    def roll(b: int) -> str:
        return {12: "........x.......", 13: "....x.......x...", 14: "x...x...x...x.x.", 15: "x.x.x.x.xxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("perc", me.timpani(seq.root_of("A", 2), 0.6, rng), t, 0.2 + 0.05 * (b - 12) + 0.1 * (i / 16))
    _choir(s, rng, PROG8, range(16), 4, 3, 1000.0, 0.4, 1.6)
    _bells(s, rng, PROG8, range(8, 16), (0.0, 2.0), 0.11)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 200, 6000), s.t(8), 0.17)
    _hymn(s, rng, 8, ANSWER, 0.26, -12)
    return mixdown(s, hits, duck=0.45, drive=1.2)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x..x..x.x.x.x..." if b % 4 == 3 else "x.....x.x......."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 200), range(16), "....x.......x...", 0.72)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.x.x.x.x.x.x.x.", 0.12, 0.2, 0.4, rng)
    _timps(s, rng, PROG8, range(16), "x.....x.x.......", 0.4)
    part_bass(s, rng, PROG8, range(16), "x-x-x-xxx-x-x-xx", 900.0, octave_up="......o.......o.", gain=0.72,
              gate=0.8, res=0.4)
    _choir(s, rng, PROG8, range(16), 2, 3, 2000.0, 0.26, 0.3)
    _bells(s, rng, PROG8, range(16), (0.0, 2.0), 0.1)
    for b in (4, 8, 12):
        _hymn(s, rng, b, HYMN, 0.38)
        _hymn(s, rng, b + 2, ANSWER, 0.34)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 350, 8000), s.t(2), 0.14)
    s.add("fx", seq.impact(rng, 2.5), s.t(4), 0.34)
    return mixdown(s, hits, duck=0.6)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.8)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.16, 0.2, 0.3, rng)
    _timps(s, rng, PROG8, range(0, 16, 4), "x...............", 0.3)
    part_bass(s, rng, PROG8, range(16), "x---x---x---x---", 460.0, gain=0.55)
    _choir(s, rng, PROG8, range(16), 2, 3, 1100.0, 0.36, 1.0)
    _bells(s, rng, PROG8, range(16), (0.0,), 0.08)
    _hymn(s, rng, 6, HYMN_B, 0.24, -12)
    return mixdown(s, hits, duck=0.4, master_lp=4500)


def stinger_win() -> np.ndarray:
    """The hymn resolving to D major (Picardy third) under a peal of bells and a timpani roll."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((74, 78, 81, 86)):
        place(out, fx.pan(seq.bell(note, 3.5, rng, 1.0), -0.3 + 0.2 * i), nsamp(i * 0.16), 0.22)
    place(out, me.strings(seq.chord("D", 3), 3.0, rng, 1800.0, 0.3, 1.5), nsamp(0.5), 0.42)
    for i in range(8):
        place(out, fx.pan(me.timpani(38, 0.8, rng), 0.0), nsamp(i * 0.06), 0.12 + 0.03 * i)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), nsamp(0.5), 0.28)
    return fx.reverb(out, "hall", 0.4, tail=False)


def stinger_lose() -> np.ndarray:
    """The hymn falling (F E D C#) to a low bell toll and a dark choir chord."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((65, 64, 62, 61)):
        place(out, fx.pan(me.strings([note - 12], 0.9, rng, 1600.0, 0.08, 0.6), 0.2 - 0.12 * i), nsamp(i * 0.42),
              0.34)
    place(out, me.strings(seq.chord("Dm", 2), 3.0, rng, 700.0, 0.6, 1.8), nsamp(1.7), 0.42)
    place(out, fx.pan(seq.bell(50, 4.0, rng, 0.5), 0.0), nsamp(1.7), 0.3)
    place(out, fx.pan(me.timpani(38, 2.0, rng), 0.0), nsamp(1.7), 0.4)
    place(out, fx.pan(seq.drone(38, 4.0, rng, 240) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(1.0), 0.36)
    return fx.reverb(out, "hall", 0.45, tail=False)


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
