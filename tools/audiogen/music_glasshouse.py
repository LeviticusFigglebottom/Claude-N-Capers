"""Glasshouse music track: "clean modern heist thriller", A minor, 140 BPM grid, 4/4.

Stems (all bar-aligned seamless loops on the same 140 BPM grid so MusicDirector can switch on any
bar line): stealth (32 bars, half-time feel = 70 BPM tension bed), control, anticipation, assault,
fade (16 bars each); stingers win/lose (one-shots). Motif: a glassy FM-bell figure
E5 A5 B5 C6 B5 A5 (the jewelry-store "glass" timbre), heard sparse in stealth and as the lead in
assault. Progression i - VI - iv - V (Am F Dm E, harmonic-minor V for tension).
"""
from __future__ import annotations

from typing import Callable

import numpy as np

from music_parts import mixdown, part_arp, part_bass, part_hits, part_kick, part_motif, part_pad, part_stabs
from synth import env, fx, osc, seq
from synth.core import SR, nsamp, place, rng_for

TRACK = "glasshouse"
BPM = 140.0
BEATS_PER_BAR = 4
PROG8 = ["Am", "Am", "F", "F", "Dm", "Dm", "E", "E"]
MOTIF = [(0.0, 76, 0.5), (0.5, 81, 0.5), (1.0, 83, 0.5), (1.5, 84, 1.0), (2.5, 83, 0.5), (3.0, 81, 1.0)]
MOTIF_B = [(0.0, 76, 0.5), (0.5, 81, 0.5), (1.0, 83, 0.5), (1.5, 84, 0.75), (2.25, 88, 0.75), (3.0, 86, 1.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return seq.Song(BPM, BEATS_PER_BAR, bars, tail)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @140 (= 16 bars of 70 BPM half-time). Sparse pulses, filtered pad, glass motif."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["Amadd9", "Fmaj7", "Dm9", "E7sus4"]
    for i, name in enumerate(prog):
        d = s.bar_s * 8
        n = nsamp(d + 2.0)
        t = np.arange(n) / SR
        cut = 700 + 500 * np.sin(np.pi * np.minimum(t / d, 1.0)) ** 2
        s.add("keys", seq.pad(seq.chord(name, 3), d, rng, cut, attack=2.5, release=2.0, detune=7), s.t(i * 8), 0.55)
    s.add("bass", fx.pan(seq.drone(33, s.length_s, rng, 260), 0.0), 0.0, 0.5)
    # heartbeat-like sub pulse every bar (beat 1 and the "and" of 1): 70 BPM feel
    for b in range(32):
        root = seq.root_of(prog[b // 8], 1)
        for beat, g in ((0.0, 1.0), (0.75, 0.6)):
            p = seq.bass(root, 0.3, rng, 220, 0.1, 0.5, 0.9)
            s.add("bass", p, s.t(b, beat), 0.7 * g)
    # clock: soft rims on beats 2 and 4 (half-time "tick ... tock"), shaker ghosts
    part_hits(s, "perc", lambda: seq.rim(rng, 1500), range(32), "....x.......x...", 0.12, 0.3, 0.3, rng)
    part_hits(s, "perc", lambda: seq.shaker(rng, 0.07), range(8, 32), "..x...x...x...x.", 0.06, -0.3, 0.4, rng)
    # glass motif fragments every 4 bars, alternating register
    for b in range(2, 32, 4):
        frag = MOTIF[:3] if (b // 4) % 2 == 0 else MOTIF[3:]
        part_motif(s, rng, b, frag, 0.32, 0 if b < 16 else -12 + 12 * ((b // 4) % 2), 0.7)
    # glass sparkles
    for k in range(18):
        t0 = float(rng.uniform(0, s.length_s))
        sp = osc.partials([float(rng.uniform(5000, 9000))], [1.0], [0.25], 0.6, rng)
        s.add("fx", sp, t0, 0.05, float(rng.uniform(-0.8, 0.8)))
    return mixdown(s, [], duck=0.0, keys_verb=0.4, lead_verb=0.5)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.9)
    part_hits(s, "drums", lambda: seq.rim(rng), range(16), "............x...", 0.3)
    part_hits(s, "perc", lambda: seq.shaker(rng), range(16), "..x...x...x...x.", 0.25, 0.2, 0.3, rng)
    part_hits(s, "drums", lambda: seq.hat(rng), range(8, 16), "x.x.x.x.x.x.x.x.", 0.25, -0.2, 0.4, rng)
    part_bass(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", 420.0, gain=0.6)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1200.0, 0.4)
    part_arp(s, rng, PROG8, range(8, 16), 0.12, 1500.0)
    part_motif(s, rng, 4, MOTIF[:3], 0.25, 0, 0.6)
    part_motif(s, rng, 12, MOTIF, 0.28, 0, 0.7)
    return mixdown(s, hits, duck=0.35)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", lambda b: 300 + 90 * b, gain=0.55, gate=0.7, res=0.5)
    part_hits(s, "drums", lambda: seq.hat(rng), range(4, 16), "..x...x...x...x.", 0.3, 0.25, 0.3, rng)
    part_hits(s, "drums", lambda: seq.hat(rng), range(12, 16), "x.x.x.x.x.x.x.x.", 0.2, -0.25, 0.3, rng)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 200, 0.2, 0.6), t, 0.2 + 0.05 * (b - 12) + 0.15 * (i / 16))
    part_hits(s, "perc", lambda: seq.tom(rng, 95), [11, 15], "............x.x.", 0.5)
    part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.45, 16)
    part_stabs(s, rng, PROG8, range(8, 16), "x.......x.......", 0.18)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 250, 7000), s.t(8), 0.18)
    part_motif(s, rng, 8, MOTIF, 0.25, -12, 0.6)
    return mixdown(s, hits, duck=0.45)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x...x...x..x.x.." if b % 4 == 3 else "x...x...x...x..."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng), range(16), "....x.......x...", 0.75)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "....x.......x...", 0.35, 0.1)
    for b in (7, 15):
        for i, t in enumerate(s.steps("............xxxx", b)):
            s.add("drums", seq.snare(rng, 210, 0.18), t, 0.35 + 0.1 * i)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.12, 0.25, 0.5, rng)
    part_hits(s, "drums", lambda: seq.hat(rng, True), range(16), "..x...x...x...x.", 0.1, -0.25)
    part_hits(s, "perc", lambda: seq.tom(rng, 120), [15], "........x.x.x...", 0.45)
    part_bass(s, rng, PROG8, range(16), "x-xxx-xxx-xxx-xx", 900.0, octave_up="..o...o...o...o.", gain=0.75,
              gate=0.8, res=0.4)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1600.0, 0.3)
    part_stabs(s, rng, PROG8, range(4, 16), "..x...x...x...x.", 0.22)
    part_arp(s, rng, PROG8, range(0, 8), 0.14, 2600.0)
    for b in (8, 10, 12, 14):
        part_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.42, 0, 1.0)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.35)
    return mixdown(s, hits, duck=0.6)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.2, 0.2, 0.3, rng)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "............x...", 0.25)
    part_bass(s, rng, PROG8, range(16), "x-x-x-x-x-x-x-x-", 520.0, gain=0.6)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.45)
    part_arp(s, rng, PROG8, range(16), 0.1, 1200.0, (0, 2, 1, 3))
    for b in (4, 12):
        part_motif(s, rng, b, MOTIF, 0.3, -12, 0.5)
    return mixdown(s, hits, duck=0.4, master_lp=5000)


def stinger_win() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_win")
    dur = 6.0
    out = np.zeros((nsamp(dur), 2))
    for i, note in enumerate((69, 73, 76, 81, 85, 88)):
        place(out, fx.pan(seq.bell(note, 3.0, rng, 0.8), -0.4 + 0.16 * i), nsamp(i * 0.11), 0.35)
    place(out, seq.pad(seq.chord("Aadd9", 3), 3.0, rng, 2200, 0.3, 2.5), 0, 0.5)
    place(out, fx.pan(seq.bass(45, 3.5, rng, 500, 0.2, 1.0, 1.0) * env.adsr(3.5, 0.005, 1.0, 0.8, 2.5), 0), 0, 0.5)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), 0, 0.3)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_lose")
    dur = 6.0
    out = np.zeros((nsamp(dur), 2))
    for i, note in enumerate((76, 72, 69, 64)):
        place(out, fx.pan(seq.bell(note, 3.0, rng, 0.5), 0.3 - 0.2 * i), nsamp(i * 0.32), 0.35)
    pad_notes = seq.chord("Dm", 3) + [seq.chord("Am", 2)[0]]
    p = seq.pad(pad_notes, 3.5, rng, 1200, 0.2, 2.0)
    # tape-stop style droop: progressively slower read
    n = p.shape[0]
    rate = np.linspace(1.0, 0.82, n)
    idx = np.cumsum(rate)
    idx = idx[idx < n - 1]
    pd = np.stack([np.interp(idx, np.arange(n), p[:, c]) for c in range(2)], axis=1)
    place(out, pd, 0, 0.5)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), 0, 0.35)
    place(out, fx.pan(seq.drone(33, 4.0, rng, 300) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(0.5), 0.4)
    return fx.reverb(out, "hall", 0.4, tail=False)


STEMS: dict[str, Callable[[], np.ndarray]] = {
    "stealth": stem_stealth,
    "control": stem_control,
    "anticipation": stem_anticipation,
    "assault": stem_assault,
    "fade": stem_fade,
}
STINGERS: dict[str, Callable[[], np.ndarray]] = {"win": stinger_win, "lose": stinger_lose}
# Mix trims applied by MusicDirector (files are all -16 LUFS integrated)
STEM_GAIN_DB: dict[str, float] = {"stealth": -6.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0,
                                  "fade": -3.0, "win": -2.0, "lose": -2.0}
BARS: dict[str, int] = {"stealth": 32, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
