"""Dockside Burn music track (`dockside_burn`, D-117): pre-dawn cartel cold store, E minor / phrygian, 150 BPM grid.

Doc (dockside_burn.md Audio/lighting): loud-only. `stealth` unused (the casing walk-in still gets a low fog
bed so the CASING phase is never silent); `control` 110 BPM, low synth ostinato and metallic hits (also
through the cartel phase); `anticipation` riser; `assault` 150 BPM, driving percussion with synthesized
container clangs and a fog-horn motif; `fade`; `win` / `lose`.

One bar grid per track (MusicDirector keeps the phrase position across bar-line switches), so control is
written on the 150 grid in quarter-note triplets: its pulse is 3 per bar = 112.5 BPM (doc: 110). Stealth is
16 bars at a half-time feel.

Identity: struck steel (container clangs, inharmonic plate modes), a diaphone fog horn as the motif
(E2 ... B1, the "beee-oh"), driven toms and a saturated master; the alley reverb (hard yard walls).
Progression i - VI - bII - V (Em C F B, phrygian bII for the cartel menace).
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_bass, part_hits, part_kick, part_pad, part_triplets
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "dockside_burn"
KEY = "E minor (phrygian bII)"
PALETTE = "container clangs, fog-horn motif, driven toms, saw bass ostinato, dark pads, saturated master"
BPM = 150.0
BEATS_PER_BAR = 4
PROG8 = ["Em", "Em", "C", "C", "F", "F", "B", "B"]
DRUM_ROOM = "alley"


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _horn_call(s: seq.Song, rng: np.random.Generator, bar: int, gain: float, transpose: int = 0) -> None:
    """The fog-horn motif: E2 (1.5 beats), B1 (2 beats)."""
    s.add("lead", me.foghorn(40 + transpose, s.beat_s * 1.5, rng), s.t(bar, 0.0), gain, -0.1)
    s.add("lead", me.foghorn(35 + transpose, s.beat_s * 2.2, rng), s.t(bar, 1.75), gain, 0.1)


def _clangs(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float,
            f0: float = 95.0, bright: float = 1.0, dur: float = 1.6) -> None:
    for b in bars:
        for t in s.steps(pattern, b):
            s.add("perc", me.clang(rng, f0 * float(rng.uniform(0.97, 1.03)), dur, bright), t, gain,
                  float(rng.uniform(-0.4, 0.4)))


def stem_stealth() -> np.ndarray:
    """16 bars, half-time feel: fog drone, a distant horn every 8 bars, sparse far clangs, sub pulse."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(16, 7.0)
    s.add("bass", fx.pan(seq.drone(28, s.length_s, rng, 200), 0.0), 0.0, 0.5)
    part_pad(s, rng, ["Em"] * 4 + ["C"] * 4 + ["F"] * 4 + ["B"] * 4, range(16), 4, 2, 500.0, 0.35, 16)
    for b in range(16):
        s.add("bass", seq.bass(28, 0.35, rng, 160, 0.1, 0.4, 1.0), s.t(b), 0.75)
    for b in (2, 10):
        _horn_call(s, rng, b, 0.22)
    _clangs(s, rng, [1, 5, 9, 13], "........x.......", 0.12, 140.0, 0.5, 2.0)
    return mixdown(s, [], duck=0.0, keys_verb=0.4, lead_verb=0.5, room="alley", drum_room=DRUM_ROOM)


def stem_control() -> np.ndarray:
    """Quarter-note-triplet pulse (112.5 BPM feel): saw ostinato, kick on the pulse, metal hits."""
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    kick = seq.kick(rng, 1.1, 42.0)
    hits: list[float] = []
    for b in range(16):
        for i in (0, 8) if b % 2 else (0, 4, 8):
            s.add("drums", kick, s.t(b, i / 3), 0.9)
            hits.append(s.t(b, i / 3))

    def ost(b: int, i: int) -> np.ndarray:
        root = seq.root_of(me.chord_at(PROG8, b), 1)
        note = root + (12 if i in (3, 9) else 7 if i == 6 else 0)
        return seq.bass(note, s.beat_s * 0.55, rng, 520.0, 0.45, 2.5, 0.5)

    part_triplets(s, range(16), "x..x..x..x..", ost, "bass", 0.65)
    part_triplets(s, range(16), "....x.......", lambda b, i: me.clang(rng, 310.0, 0.9, 1.4), "perc", 0.18, 0.25)
    part_triplets(s, range(8, 16), "..x..x..x..x", lambda b, i: seq.hat(rng), "drums", 0.16, -0.2)
    part_triplets(s, [3, 7, 11, 15], "........x...", lambda b, i: me.clang(rng, 90.0, 1.8, 0.8), "perc", 0.3)
    part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.32)
    _horn_call(s, rng, 4, 0.2)
    _horn_call(s, rng, 12, 0.22)
    return mixdown(s, hits, duck=0.35, room="alley", drum_room=DRUM_ROOM, drive=1.3)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", lambda b: 260 + 95 * b, gain=0.55, gate=0.7, res=0.55)
    _clangs(s, rng, range(0, 16, 2), "x...............", 0.22, 90.0, 0.8, 2.0)
    _clangs(s, rng, range(8, 16), "....x.......x...", 0.12, 300.0, 1.4, 0.9)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.tom(rng, 90 + 6 * (b - 12)), t, 0.18 + 0.05 * (b - 12) + 0.15 * (i / 16))
    part_pad(s, rng, PROG8, range(16), 2, 3, 800.0, 0.4, 16)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 200, 7000), s.t(8), 0.2)
    _horn_call(s, rng, 8, 0.22)
    return mixdown(s, hits, duck=0.45, room="alley", drum_room=DRUM_ROOM, drive=1.3)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x...x...x...x.xx" if b % 4 == 3 else "x...x...x...x..."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 230, 0.25, 1.2), range(16), "....x.......x...", 0.7)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.xxx.xxx.xxx.xx", 0.12, 0.25, 0.5, rng)
    part_hits(s, "perc", lambda: seq.tom(rng, 110), range(16), "..x.....x.x.....", 0.3, -0.3, 0.3, rng)
    part_hits(s, "perc", lambda: seq.tom(rng, 75), [3, 7, 11, 15], "........x.x.x.x.", 0.45)
    _clangs(s, rng, range(16), "......x.......x.", 0.2, 120.0, 1.2, 1.2)
    _clangs(s, rng, range(0, 16, 4), "x...............", 0.3, 70.0, 0.8, 2.4)
    part_bass(s, rng, PROG8, range(16), "x-xxx-xxx-xxx-xx", 950.0, octave_up="..o...o...o...o.", gain=0.75,
              gate=0.8, res=0.45)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1400.0, 0.26)
    for b in (8, 10, 12, 14):
        _horn_call(s, rng, b, 0.38, 12)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.35)
    return mixdown(s, hits, duck=0.6, room="alley", drum_room=DRUM_ROOM, drive=1.5)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.18, 0.2, 0.3, rng)
    _clangs(s, rng, range(1, 16, 2), "............x...", 0.14, 160.0, 0.7, 1.8)
    part_bass(s, rng, PROG8, range(16), "x-x-x-x-x-x-x-x-", 500.0, gain=0.6)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1100.0, 0.42)
    _horn_call(s, rng, 4, 0.2)
    _horn_call(s, rng, 12, 0.2)
    return mixdown(s, hits, duck=0.4, master_lp=4200, room="alley", drum_room=DRUM_ROOM, drive=1.2)


def stinger_win() -> np.ndarray:
    """Horn up to E major, a big clang and impact (the burn behind you)."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    place(out, fx.pan(me.foghorn(35, 0.8, rng), -0.1), 0, 0.35)
    place(out, fx.pan(me.foghorn(40, 2.6, rng, 900), 0.1), nsamp(0.7), 0.35)
    place(out, seq.pad(seq.chord("E", 3) + [68], 3.0, rng, 1800, 0.4, 2.5), nsamp(0.7), 0.45)
    place(out, fx.pan(me.clang(rng, 85.0, 3.5, 1.2), 0), nsamp(0.7), 0.4)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), nsamp(0.7), 0.3)
    return fx.reverb(out, "alley", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """The horn falls E -> C -> B (half step down), clangs ring out, sub boom."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((40, 36, 35)):
        place(out, fx.pan(me.foghorn(note, 1.4 + 0.6 * i, rng, 520 - 80 * i), 0.15 * (i - 1)), nsamp(i * 0.9), 0.32)
    for i in range(3):
        place(out, fx.pan(me.clang(rng, 110.0 - 12 * i, 2.5, 0.8), -0.4 + 0.4 * i), nsamp(0.2 + i * 0.9), 0.22)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), nsamp(1.8), 0.35)
    place(out, fx.pan(seq.drone(28, 4.0, rng, 240) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(1.0), 0.4)
    return fx.reverb(out, "alley", 0.4, tail=False)


STEMS: dict[str, Callable[[], np.ndarray]] = {
    "stealth": stem_stealth,
    "control": stem_control,
    "anticipation": stem_anticipation,
    "assault": stem_assault,
    "fade": stem_fade,
}
STINGERS: dict[str, Callable[[], np.ndarray]] = {"win": stinger_win, "lose": stinger_lose}
STEM_GAIN_DB: dict[str, float] = {"stealth": -7.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0,
                                  "fade": -3.0, "win": -2.0, "lose": -2.0}
BARS: dict[str, int] = {"stealth": 16, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
