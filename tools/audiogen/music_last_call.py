"""Last Call (`last_call`, C5-01): an unlockable jukebox / heist track. B minor, 150 BPM grid, 4/4.

Identity: closing time on the getaway. A driving synth track: sixteenth saw arpeggios, a cold glass pad,
claps on the backbeat, an octave-jumping bass and a bright bell lead whose motif climbs like a clock running
out: B D F# | A G F# E D (answered E F# G A B). Progression i - VI - III - VII (Bm G D A), with F#7 on the turn.
Stealth is 32 bars of the grid played half-time (75 BPM feel); control / anticipation / assault / fade are 16
bars each on the one bar grid. Mix room: "hall". Original material, synthesized from the shared engine.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_arp, part_bass, part_hits, part_kick, part_motif, part_stabs
from synth import env, fx, seq
from synth.core import nsamp, place, rng_for

TRACK = "last_call"
KEY = "B minor"
PALETTE = "saw arpeggios, glass pad, bell lead, octave bass, clap kit"
BPM = 150.0
BEATS_PER_BAR = 4
PROG8 = ["Bm", "Bm", "G", "G", "D", "D", "A", "F#7"]
MOTIF = [(0.0, 71, 0.5), (0.5, 74, 0.5), (1.0, 78, 1.0), (2.0, 81, 0.5), (2.5, 79, 0.5), (3.0, 78, 0.5),
         (3.5, 76, 0.5)]
ANSWER = [(0.0, 76, 0.5), (0.5, 78, 0.5), (1.0, 79, 0.5), (1.5, 81, 0.5), (2.0, 83, 2.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _glass(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, octave: int,
           gain: float, attack: float = 1.2) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        notes = seq.chord(me.chord_at(prog, b), octave)
        s.add("keys", me.glass_pad(notes, s.bar_s * bars_per * 0.97, rng, attack, 1.6), s.t(b), gain)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @150 = 16 bars of 75 BPM: the glass pad, a muted eighth arpeggio (low-passed) from bar 8, a soft
    clock-like rim on the half-time backbeat and the motif's first notes as distant bells."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 6.0)
    prog = ["Bm", "G", "D", "A"]
    for i, name in enumerate(prog):
        s.add("keys", me.glass_pad(seq.chord(name, 3), s.bar_s * 8 * 0.97, rng, 2.5, 2.0), s.t(i * 8), 0.38)
    s.add("bass", fx.pan(seq.drone(35, s.length_s, rng, 210), 0.0), 0.0, 0.4)
    per_bar = [name for name in prog for _ in range(8)]   # the pad's chord, bar by bar
    part_arp(s, rng, per_bar, range(8, 32), 0.07, 900.0, (0, 2, 1, 2, 0, 2, 1, 3))
    part_hits(s, "perc", lambda: seq.rim(rng, 1800), range(32), "........x.......", 0.12, 0.25)
    for b in (4, 20):
        part_motif(s, rng, b, MOTIF[:3], 0.12, -12, 0.7)
    return mixdown(s, [], duck=0.0, keys_verb=0.4, lead_verb=0.5)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "....x.......x...", 0.3)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.14, 0.25, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", 600.0, octave_up="..o...o...o...o.", gain=0.6)
    part_arp(s, rng, PROG8, range(16), 0.1, 1600.0)
    _glass(s, rng, PROG8, range(16), 2, 3, 0.3)
    part_motif(s, rng, 4, MOTIF, 0.24)
    part_motif(s, rng, 12, ANSWER, 0.24)
    return mixdown(s, hits, duck=0.4)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_hits(s, "drums", lambda: seq.clap(rng), range(8, 16), "....x.......x...", 0.3)
    part_bass(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", lambda b: 320 + 90 * b, gain=0.55, gate=0.7, res=0.5)
    part_arp(s, rng, PROG8, range(16), 0.11, 2200.0, (0, 1, 2, 3, 2, 1, 2, 3))

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 200, 0.2, 0.6), t, 0.18 + 0.05 * (b - 12) + 0.12 * (i / 16))
    _glass(s, rng, PROG8, range(16), 4, 3, 0.36, 2.0)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 260, 7000), s.t(8), 0.17)
    part_motif(s, rng, 8, MOTIF, 0.22, -12)
    return mixdown(s, hits, duck=0.45, drive=1.2)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x..x..x.x..x.x.x" if b % 4 == 3 else "x...x...x...x..."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "....x.......x...", 0.6)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.1, 0.25, 0.5, rng)
    part_hits(s, "drums", lambda: seq.hat(rng, True), range(16), "..x...x...x...x.", 0.12, -0.25)
    part_bass(s, rng, PROG8, range(16), "x-xxx-xxx-xxx-xx", 1000.0,
              octave_up="...o...o...o...o", gain=0.72, gate=0.75, res=0.45)
    part_arp(s, rng, PROG8, range(16), 0.12, 3000.0, (0, 1, 2, 3, 2, 3, 1, 2))
    part_stabs(s, rng, PROG8, range(8, 16), "x.....x.....x...", 0.18)
    _glass(s, rng, PROG8, range(16), 2, 4, 0.2, 0.4)
    for b in (4, 8, 12):
        part_motif(s, rng, b, MOTIF, 0.36, 0, 1.3)
        part_motif(s, rng, b + 2, ANSWER, 0.32, 0, 1.3)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(2), 0.14)
    s.add("fx", seq.impact(rng, 2.5), s.t(4), 0.32)
    return mixdown(s, hits, duck=0.6)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.8)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.13, 0.2, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "x---x---x---x---", 500.0, gain=0.55)
    part_arp(s, rng, PROG8, range(16), 0.07, 1100.0)
    _glass(s, rng, PROG8, range(16), 2, 3, 0.34)
    part_motif(s, rng, 8, ANSWER, 0.18, -12, 0.8)
    return mixdown(s, hits, duck=0.4, master_lp=4800)


def stinger_win() -> np.ndarray:
    """Out before closing: the answer climbing to a bright B major bell chord over a glass swell."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(5.5), 2))
    for i, note in enumerate((76, 78, 79, 81, 83)):
        place(out, fx.pan(seq.bell(note, 2.0, rng, 1.2), -0.3 + 0.15 * i), nsamp(i * 0.1), 0.24)
    for k, note in enumerate(seq.chord("B", 5)):
        place(out, fx.pan(seq.bell(note, 3.5, rng, 1.0), -0.2 + 0.2 * k), nsamp(0.55), 0.22)
    place(out, me.glass_pad(seq.chord("B", 3), 2.5, rng, 0.4, 1.5), nsamp(0.4), 0.4)
    place(out, fx.pan(seq.impact(rng, 3.5), 0), nsamp(0.55), 0.26)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """Lights up, doors locked: the arpeggio slowing and detuning down to a low B minor drone and a thud."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(5.5), 2))
    t = 0.0
    for i, note in enumerate((83, 78, 74, 71, 66, 62)):
        place(out, fx.pan(seq.pluck(note - i // 3, 0.5, rng, 2400.0 - 300.0 * i), 0.3 - 0.12 * i), nsamp(t), 0.3)
        t += 0.12 + 0.07 * i
    place(out, me.glass_pad(seq.chord("Bm", 2), 2.5, rng, 0.6, 1.5), nsamp(1.6), 0.4)
    place(out, fx.pan(seq.impact(rng, 2.5), 0), nsamp(1.6), 0.3)
    place(out, fx.pan(seq.drone(35, 3.5, rng, 240) * env.adsr(3.5, 0.4, 1, 0.8, 1.6), 0), nsamp(1.4), 0.34)
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
