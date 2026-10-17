"""Ostrander Federal music track (`ostrander_federal`, "Clearing House", OF-C2): the grand-hall bank job,
D minor, 148 BPM grid.

Doc (ostrander_federal.md Audio/lighting): stealth 72 BPM (low strings and a clockwork tick that tightens
during the time lock); control; anticipation riser; assault 148 BPM (driving percussion with a brass motif);
fade; win / lose stingers.

One bar grid per track (MusicDirector keeps the phrase position across bar-line switches): 148 BPM, so
stealth is the grid at half time = 74 BPM (doc 72: +2 BPM so it shares the assault grid, which the doc
pins at 148); control runs in quarter-note triplets = 111 BPM pulse; assault is the 148 grid itself.

Identity (kept apart from Nightfall Depository's low brass / C minor and Gallery Night's harpsichord /
G minor): a low bowed string section and spiccato basses for the stealth bed, a clockwork escapement
(tick, tock and a winding ratchet) that doubles its rate in the second half of the stealth loop (the time
lock), a deep FM "clearing bell" every phrase, and in the loud stems a bright horn section (brass up an
octave, opened filter) over driving low toms, kick and snare. Progression i - VI - iv - V
(Dm Bbmaj7 Gm A) in stealth, i - III - iv - V (Dm F Gm A) in the loud stems.
Motif (brass): D A | G F E, answered D A | Bb A C#.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_hits, part_kick, part_ticks, part_triplets
from synth import env, filters, fx, noise, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "ostrander_federal"
KEY = "D minor"
PALETTE = "low bowed strings, spiccato basses, clockwork escapement tick + ratchet, FM clearing bell, horn section"
BPM = 148.0
BEATS_PER_BAR = 4
PROG_STEALTH = ["Dm", "Bbmaj7", "Gm", "A"]
PROG8 = ["Dm", "Dm", "F", "F", "Gm", "Gm", "A", "A"]
# (beat, midi note, beats) on the horn section
MOTIF = [(0.0, 62, 1.0), (1.0, 69, 1.0), (2.0, 67, 0.5), (2.5, 65, 0.5), (3.0, 64, 1.0)]
MOTIF_B = [(0.0, 62, 1.0), (1.0, 69, 1.0), (2.0, 70, 0.5), (2.5, 69, 0.5), (3.0, 73, 1.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def ratchet(rng: np.random.Generator, dur: float = 0.18, clicks: int = 7) -> np.ndarray:
    """Clock-winding ratchet (mono): a quick run of pawl clicks, band-passed, falling in level."""
    n = nsamp(dur)
    y = np.zeros(n)
    for i in range(clicks):
        c = me.tick(rng, 2400.0 + 180.0 * float(rng.random()), 0.03) * (1.0 - 0.09 * i)
        place(y, c, int(i * n / clicks), 0.5)
    return filters.bp(y, 2200, 0.9)


def clearing_bell(note: int, dur: float, rng: np.random.Generator) -> np.ndarray:
    """Deep FM bell (mono): seq.bell an octave down with a low hum partial and a slow beat."""
    y = seq.bell(note, dur, rng, 0.7)
    t = np.arange(y.shape[0]) / SR
    hum = np.sin(2 * np.pi * midi_hz(note - 12) * t) * np.exp(-t / (dur * 0.6))
    return (y + 0.3 * hum) * (1 + 0.15 * np.sin(2 * np.pi * 1.3 * t))


def horn(notes: list[int], dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Bright horn section: me.brass with the filter opened and a short swell."""
    return me.brass(notes, dur, rng, 2600.0 * bright, 0.05, 1.2)


def _escapement(s: seq.Song, rng: np.random.Generator, bars: range, pattern: str, gain: float) -> None:
    part_ticks(s, rng, bars, pattern, gain, 3400.0, 1500.0, -0.25)


def _horn_motif(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]],
                gain: float, transpose: int = 0, bright: float = 1.0) -> None:
    for beat, note, beats in motif:
        y = horn([note + transpose, note + transpose - 12], s.beat_s * beats * 0.95, rng, bright)
        s.add("lead", y, s.t(bar, beat), gain, 0.1)


def _strings_pad(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, octave: int,
                 cutoff: float, gain: float, attack: float = 0.8) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        d = s.bar_s * bars_per
        s.add("keys", me.strings(seq.chord(me.chord_at(prog, b), octave), d, rng, cutoff, attack, 1.2), s.t(b), gain)


def _spiccato(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str, gain: float,
              octave: int = 2, cutoff: float | Callable[[int], float] = 2000.0) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), octave)
        cut = cutoff(b) if callable(cutoff) else cutoff
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            note = root + (12 if ch == "o" else 7 if ch == "f" else 0)
            s.add("bass", me.spiccato(note, s.beat_s * 0.45, rng, cut), s.t(b, i / 4), gain, 0.15)


def _toms(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float) -> list[float]:
    times: list[float] = []
    for b in bars:
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            f0 = 72.0 if ch == "x" else 98.0
            t = s.t(b, i / 4)
            s.add("drums", seq.tom(rng, f0, 0.5), t, gain, -0.2 if ch == "x" else 0.2)
            times.append(t)
    return times


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @148 = 16 bars of 74 BPM. Low strings on i - VI - iv - V (8 bars per chord), a sparse
    spiccato bass, the clockwork tick (half-time tick-tock, doubling with a ratchet in bars 16-31: the
    time lock), and the clearing bell on each chord change."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    for i, name in enumerate(PROG_STEALTH):
        d = s.bar_s * 8
        s.add("keys", me.strings(seq.chord(name, 3), d, rng, 800.0, 2.2, 2.0), s.t(i * 8), 0.5)
        s.add("bass", fx.pan(me.strings([seq.root_of(name, 1)], d, rng, 280.0, 1.6, 2.0)[:, 0], 0.0), s.t(i * 8), 0.45)
        s.add("fx", clearing_bell(seq.root_of(name, 3), 5.0, rng), s.t(i * 8), 0.16, -0.2)
    st8 = [c for c in PROG_STEALTH for _ in range(8)]
    _spiccato(s, rng, st8, range(4, 32), "x.......x.....f.", 0.32, 2, 1100.0)
    _escapement(s, rng, range(0, 16), "x.......X.......", 0.14)
    _escapement(s, rng, range(16, 32), "x...X...x...X...", 0.15)
    for b in range(19, 32, 4):
        s.add("perc", ratchet(rng), s.t(b, 3.5), 0.12, 0.3)
    for b in (12, 28):
        _horn_motif(s, rng, b, MOTIF[:2], 0.12, -12, 0.45)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.5)


def stem_control() -> np.ndarray:
    """Quarter-note triplet pulse (111 BPM feel): low toms on the pulse, triplet spiccato, strings,
    the escapement at full rate, the motif on muted horns."""
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits: list[float] = []
    for b in range(16):
        for i in (0, 8) if b % 2 else (0, 4, 8):
            s.add("drums", seq.tom(rng, 70.0, 0.6), s.t(b, i / 3), 0.55 if i == 0 else 0.4)
            hits.append(s.t(b, i / 3))

    def low(b: int, i: int) -> np.ndarray:
        notes = seq.chord(me.chord_at(PROG8, b), 2)
        return me.spiccato(notes[(0, 2, 1)[i % 3]], s.beat_s * 0.4, rng, 1500.0)

    part_triplets(s, range(16), "xxxxxxxxxxxx", low, "bass", 0.32)
    part_triplets(s, range(16), "....x.......", lambda b, i: seq.rim(rng, 1500), "perc", 0.2, 0.2)
    part_ticks(s, rng, range(16), "x...X...x...X...", 0.12, 3400.0, 1500.0, -0.25)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.4)
    _horn_motif(s, rng, 4, MOTIF, 0.16, 0, 0.6)
    _horn_motif(s, rng, 12, MOTIF_B, 0.16, 0, 0.6)
    return mixdown(s, hits, duck=0.2)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = _toms(s, rng, range(0, 8), "x.......x.......", 0.5)
    hits += _toms(s, rng, range(8, 16), "x...x...x...x...", 0.55)
    _spiccato(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", 0.4, 2, lambda b: 900 + 140 * b)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 210, 0.2, 0.7), t, 0.12 + 0.04 * (b - 12) + 0.12 * (i / 16))
    part_ticks(s, rng, range(0, 8), "x...X...x...X...", 0.12, 3400.0, 1500.0)
    part_ticks(s, rng, range(8, 16), "x.X.x.X.x.X.x.X.", 0.13, 3400.0, 1500.0)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1000.0, 0.45, 1.2)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 250, 7000), s.t(8), 0.18)
    s.add("fx", clearing_bell(50, 5.0, rng), s.t(0), 0.18)
    _horn_motif(s, rng, 8, MOTIF, 0.2, -12, 0.8)
    return mixdown(s, hits, duck=0.3)


def stem_assault() -> np.ndarray:
    """Driving percussion (kick, snare, low toms, 16th hats) with the horn motif on top, spiccato
    basses in 16ths and a string bed."""
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.....x.x.......", 0.75)
    part_hits(s, "drums", lambda: seq.snare(rng, 200, 0.28), range(16), "....x.......x...", 0.6)
    _toms(s, rng, range(16), "..x.......o.x...", 0.35)
    _toms(s, rng, [7, 15], "........x.o.xoxo", 0.4)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.07, 0.25, 0.4, rng)
    _spiccato(s, rng, PROG8, range(16), "xxoxxfxxxxoxxfxx", 0.5, 2, 2400.0)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1900.0, 0.3, 0.3)
    for b in (0, 2, 4, 6):
        s.add("keys", horn(seq.chord(me.chord_at(PROG8, b), 3), s.beat_s * 0.5, rng, 1.2), s.t(b), 0.18)
    for b in (8, 10, 12, 14):
        _horn_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.36, 0, 1.3)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.3)
    return mixdown(s, hits, duck=0.45)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = _toms(s, rng, range(16), "x.......x.......", 0.4)
    part_ticks(s, rng, range(16), "x...X...x...X...", 0.12, 3400.0, 1500.0)
    _spiccato(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", 0.36, 2, 1300.0)
    _strings_pad(s, rng, PROG8, range(16), 2, 3, 1200.0, 0.45)
    for b in (4, 12):
        _horn_motif(s, rng, b, MOTIF, 0.16, -12, 0.5)
    return mixdown(s, hits, duck=0.3, master_lp=5000)


def stinger_win() -> np.ndarray:
    """Horns up a D major arpeggio, strings land on D major (Picardy), the clearing bell rings it out."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((62, 66, 69, 74)):
        place(out, fx.pan(horn([note, note - 12], 0.5 if i < 3 else 2.2, rng, 1.3), -0.3 + 0.2 * i), nsamp(i * 0.16),
              0.3)
    place(out, me.strings(seq.chord("D", 3) + [seq.chord("D", 2)[0]], 2.8, rng, 2000, 0.25, 2.5), nsamp(0.5), 0.5)
    place(out, fx.pan(clearing_bell(62, 5.0, rng), 0.0), nsamp(0.48), 0.3)
    place(out, fx.pan(seq.tom(rng, 72.0, 1.0), 0), nsamp(0.48), 0.4)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """Horns fall A G F E D, strings droop on D minor, the clock runs down (ticks slowing to a stop)."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((69, 67, 65, 64, 62)):
        place(out, fx.pan(horn([note], 0.45, rng, 0.6), 0.3 - 0.15 * i), nsamp(i * 0.28), 0.28)
    p = me.strings(seq.chord("Dm", 3) + [38], 3.2, rng, 1100, 0.3, 1.8)
    n = p.shape[0]
    idx = np.cumsum(np.linspace(1.0, 0.85, n))
    idx = idx[idx < n - 1]
    pd = np.stack([np.interp(idx, np.arange(n), p[:, c]) for c in range(2)], axis=1)
    place(out, pd, nsamp(0.4), 0.5)
    t = 0.3
    gap = 0.3
    for _ in range(9):
        place(out, fx.pan(me.tick(rng, 3000.0), -0.2), nsamp(t), 0.25)
        t += gap
        gap *= 1.22
    place(out, fx.pan(seq.drone(26, 4.0, rng, 240) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(1.0), 0.35)
    place(out, fx.pan(filters.lp(noise.brown(1.5, rng), 200) * env.exp_decay(1.5, 0.4), 0), nsamp(1.6), 0.2)
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
