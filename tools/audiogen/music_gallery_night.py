"""Gallery Night music track (`gallery_night`, D-117): uptown museum gala heist, G minor, 144 BPM grid.

Doc (gallery_night.md Audio/lighting): stealth 72 BPM (plucked FM "harpsichord" ostinato, low strings
pad, a ticking motif that tightens at last call and during the hack); control 110 BPM; anticipation
riser; assault 136 BPM (driving low strings and synthesized timpani, the harpsichord motif distorted);
fade; win / lose.

One bar grid per track (MusicDirector keeps the phrase position across bar-line switches): 144 BPM, so
stealth is the grid at half time = 72 BPM (exact); control runs in quarter-note triplets = 108 BPM pulse
(doc 110); assault is the 144 grid itself (doc 136: +8 BPM so it shares the stealth grid).

Identity: baroque pastiche: an FM harpsichord, a bowed string section with vibrato, spiccato low strings
and tuned timpani (G / D) in place of the kit's toms; the concert-hall reverb. Progression i - VII - VI - V
(Gm F Eb D, a descending lament bass) in stealth; i - VI - iv - V (Gm Eb Cm D) in the loud stems.
Motif (harpsichord): G Bb D C Bb A.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_hits, part_kick, part_ticks, part_triplets
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "gallery_night"
KEY = "G minor"
PALETTE = "FM harpsichord ostinato, bowed strings pad, spiccato low strings, synth timpani, gallery clock tick"
BPM = 144.0
BEATS_PER_BAR = 4
PROG8 = ["Gm", "Gm", "Eb", "Eb", "Cm", "Cm", "D", "D"]
LAMENT = ["Gm", "F", "Eb", "D"]
MOTIF = [(0.0, 67, 0.5), (0.5, 70, 0.5), (1.0, 74, 0.5), (1.5, 72, 1.0), (2.5, 70, 0.5), (3.0, 69, 1.0)]
MOTIF_B = [(0.0, 67, 0.5), (0.5, 70, 0.5), (1.0, 74, 0.5), (1.5, 75, 0.75), (2.25, 74, 0.75), (3.0, 78, 1.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _harp_ostinato(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, step_pattern: str,
                   gain: float, bright: float = 1.0, octave: int = 4, order: tuple[int, ...] = (0, 2, 1, 3, 2, 1, 0, 2)
                   ) -> None:
    for b in bars:
        notes = seq.chord(me.chord_at(prog, b), octave)
        notes = notes + [notes[0] + 12]
        k = 0
        for i, ch in enumerate(step_pattern):
            if ch in ".-_ ":
                continue
            note = notes[order[k % len(order)] % len(notes)]
            k += 1
            s.add("keys", me.harpsichord(note, 0.9, rng, bright), s.t(b, i / 4), gain, -0.3 if k % 2 else 0.3)


def _harp_motif(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]], gain: float,
                bright: float = 1.0, transpose: int = 0, dist: float = 0.0) -> None:
    for beat, note, _ in motif:
        y = me.harpsichord(note + transpose, 1.2, rng, bright)
        if dist > 0:
            y = fx.drive(y * dist, dist) * 0.6
        s.add("lead", y, s.t(bar, beat), gain, 0.15)


def _strings_pad(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, octave: int,
                 cutoff: float, gain: float, attack: float = 0.8) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        d = s.bar_s * bars_per
        s.add("keys", me.strings(seq.chord(me.chord_at(prog, b), octave), d, rng, cutoff, attack, 1.2), s.t(b), gain)


def _timp(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float,
          note_fn: Callable[[int], int] | None = None) -> list[float]:
    times: list[float] = []
    for b in bars:
        for t in s.steps(pattern, b):
            note = note_fn(b) if note_fn else 43
            s.add("drums", me.timpani(note, 1.4, rng), t, gain)
            times.append(t)
    return times


def _root_timp(prog: list[str]) -> Callable[[int], int]:
    """Timpani tuned to G2 / D2 (the two drums): D for the dominant bars, G otherwise."""
    return lambda b: 38 if me.chord_at(prog, b).startswith("D") else 43


def _spiccato(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str, gain: float,
              octave: int = 2, cutoff: float | Callable[[int], float] = 2200.0) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), octave)
        cut = cutoff(b) if callable(cutoff) else cutoff
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            note = root + (12 if ch == "o" else 7 if ch == "f" else 0)
            s.add("bass", me.spiccato(note, s.beat_s * 0.45, rng, cut), s.t(b, i / 4), gain, -0.15)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @144 = 16 bars of 72 BPM. Lament progression on low strings (8 bars per chord), a
    half-time harpsichord ostinato, the gallery clock tick tightening (last call / hack), motif fragments."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    for i, name in enumerate(LAMENT):
        d = s.bar_s * 8
        s.add("keys", me.strings(seq.chord(name, 2), d, rng, 900.0, 2.0, 2.0), s.t(i * 8), 0.55)
        s.add("bass", fx.pan(me.strings([seq.root_of(name, 1)], d, rng, 300.0, 1.5, 2.0)[:, 0], 0.0), s.t(i * 8), 0.45)
    lam8 = [c for c in LAMENT for _ in range(8)]
    _harp_ostinato(s, rng, lam8, range(4, 32), "x...x...x...x...", 0.18, 0.6, 4, (0, 2, 1, 3))
    part_ticks(s, rng, range(0, 16), "x.......X.......", 0.14, 2600.0, 1900.0, 0.3)
    part_ticks(s, rng, range(16, 32), "x...X...x...X...", 0.15, 2600.0, 1900.0, 0.3)
    for b in (8, 24):
        _harp_motif(s, rng, b, MOTIF[:3], 0.22, 0.7)
        _harp_motif(s, rng, b + 2, MOTIF[3:], 0.2, 0.7, -12)
    for b in (15, 31):
        s.add("drums", me.timpani(38 if b == 31 else 43, 2.0, rng), s.t(b, 2.0), 0.3)
    return mixdown(s, [], duck=0.0, keys_verb=0.4, lead_verb=0.5)


def stem_control() -> np.ndarray:
    """Quarter-note triplet pulse (108 BPM feel): timpani on the pulse, triplet harpsichord, strings."""
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    tn = _root_timp(PROG8)
    hits: list[float] = []
    for b in range(16):
        for i in (0, 8) if b % 2 else (0, 4, 8):
            s.add("drums", me.timpani(tn(b), 1.2, rng), s.t(b, i / 3), 0.55 if i == 0 else 0.4)
            hits.append(s.t(b, i / 3))

    def harp(b: int, i: int) -> np.ndarray:
        notes = seq.chord(me.chord_at(PROG8, b), 4)
        return me.harpsichord(notes[(0, 2, 1)[i % 3]] + (12 if i >= 6 else 0), 0.8, rng, 0.8)

    part_triplets(s, range(16), "xxxxxxxxxxxx", harp, "keys", 0.12)
    part_triplets(s, range(16), "....x.......", lambda b, i: seq.rim(rng, 1600), "perc", 0.2, 0.2)
    part_triplets(s, range(8, 16), "x.x.x.x.x.x.", lambda b, i: seq.shaker(rng, 0.07), "perc", 0.1, -0.3)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.4)

    def low(b: int, i: int) -> np.ndarray:
        return me.spiccato(seq.root_of(me.chord_at(PROG8, b), 2), s.beat_s * 0.6, rng, 1400.0)

    part_triplets(s, range(16), "x...x...x...", low, "bass", 0.55)
    _harp_motif(s, rng, 4, MOTIF, 0.24, 0.9)
    _harp_motif(s, rng, 12, MOTIF_B, 0.24, 0.9)
    return mixdown(s, hits, duck=0.2)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    tn = _root_timp(PROG8)
    hits = _timp(s, rng, range(0, 8), "x.......x.......", 0.5, tn)
    hits += _timp(s, rng, range(8, 16), "x...x...x...x...", 0.55, tn)
    _spiccato(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", 0.42, 2, lambda b: 900 + 140 * b)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", me.timpani(38, 0.6, rng), t, 0.15 + 0.04 * (b - 12) + 0.12 * (i / 16))
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1000.0, 0.45, 1.2)
    _harp_ostinato(s, rng, PROG8, range(8, 16), "x.x.x.x.x.x.x.x.", 0.12, 1.1)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 250, 7000), s.t(8), 0.18)
    _harp_motif(s, rng, 8, MOTIF, 0.22, 1.0, -12)
    return mixdown(s, hits, duck=0.3)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)
    tn = _root_timp(PROG8)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.7)
    hits += _timp(s, rng, range(16), "x.....x.x.......", 0.5, tn)
    _timp(s, rng, [7, 15], "........x.x.xxxx", 0.35, tn)
    part_hits(s, "drums", lambda: seq.snare(rng, 200, 0.28), range(16), "....x.......x...", 0.6)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.x.x.x.x.x.x.x.", 0.1, 0.25, 0.4, rng)
    _spiccato(s, rng, PROG8, range(16), "xxoxxfxxxxoxxfxx", 0.5, 2, 2400.0)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1900.0, 0.32, 0.3)
    _harp_ostinato(s, rng, PROG8, range(0, 8), "x.x.x.x.x.x.x.x.", 0.12, 1.2)
    for b in (8, 10, 12, 14):
        _harp_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.42, 1.6, 0, 3.0)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.3)
    return mixdown(s, hits, duck=0.45)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    tn = _root_timp(PROG8)
    hits = _timp(s, rng, range(16), "x.......x.......", 0.45, tn)
    part_ticks(s, rng, range(16), "x...X...x...X...", 0.12, 2600.0, 1900.0)
    _spiccato(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", 0.38, 2, 1300.0)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1200.0, 0.45)
    _harp_ostinato(s, rng, PROG8, range(16), "x...x...x...x...", 0.12, 0.6)
    for b in (4, 12):
        _harp_motif(s, rng, b, MOTIF, 0.26, 0.6, -12)
    return mixdown(s, hits, duck=0.3, master_lp=5000)


def stinger_win() -> np.ndarray:
    """Harpsichord flourish up a G major arpeggio, strings land on G major (Picardy), timpani roll."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((55, 59, 62, 67, 71, 74, 79)):
        place(out, fx.pan(me.harpsichord(note, 1.6, rng, 1.0), -0.45 + 0.15 * i), nsamp(i * 0.07), 0.3)
    place(out, me.strings(seq.chord("G", 3) + [seq.chord("G", 2)[0]], 2.8, rng, 2000, 0.25, 2.5), nsamp(0.5), 0.5)
    for i in range(10):
        place(out, fx.pan(me.timpani(43, 0.5, rng), 0), nsamp(i * 0.05), 0.1 + 0.02 * i)
    place(out, fx.pan(me.timpani(43, 3.0, rng), 0), nsamp(0.5), 0.5)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """Harpsichord falls D C Bb A G, strings droop on G minor, a soft timpani D -> G."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((74, 72, 70, 69, 67)):
        place(out, fx.pan(me.harpsichord(note, 1.6, rng, 0.7), 0.3 - 0.15 * i), nsamp(i * 0.26), 0.3)
    p = me.strings(seq.chord("Gm", 3) + [43], 3.2, rng, 1100, 0.3, 1.8)
    n = p.shape[0]
    idx = np.cumsum(np.linspace(1.0, 0.85, n))
    idx = idx[idx < n - 1]
    pd = np.stack([np.interp(idx, np.arange(n), p[:, c]) for c in range(2)], axis=1)
    place(out, pd, nsamp(0.4), 0.5)
    place(out, fx.pan(me.timpani(38, 2.0, rng), 0), nsamp(1.2), 0.45)
    place(out, fx.pan(me.timpani(43, 3.0, rng), 0), nsamp(1.9), 0.5)
    place(out, fx.pan(seq.drone(31, 4.0, rng, 260) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(1.0), 0.35)
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
