"""Night Deposit music track: "harbour noir", D minor, 124 BPM grid, 4/4.

A 1931 savings bank on a foggy quay at night: brushed ride and rim clicks, a walking upright-style
bass, low muted-horn chords and a slow vibraphone-like motif A4 D5 F5 E5 C5 D5. Progression
i - VI - iv - V7 (Dm Bb Gm A7). Stems: stealth (32 bars, half-time), control, anticipation, assault,
fade (16 bars each); stingers win/lose. Shares the sequencer parts in music_parts.py.
"""
from __future__ import annotations

import numpy as np

from music_parts import mixdown, part_bass, part_hits, part_kick, part_motif, part_pad, part_stabs
from synth import env, filters, fx, osc, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "night_deposit"
KEY = "D minor"
TITLE = "Night Deposit"
BPM = 124.0
BEATS_PER_BAR = 4
PROG8 = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A7", "A7"]
MOTIF = [(0.0, 69, 0.5), (0.5, 74, 0.5), (1.0, 77, 1.0), (2.0, 76, 0.5), (2.5, 72, 0.5), (3.0, 74, 1.0)]
MOTIF_B = [(0.0, 69, 0.5), (0.5, 74, 0.5), (1.0, 77, 0.5), (1.5, 81, 1.0), (2.5, 79, 0.5), (3.0, 76, 1.0)]
WALK = (0, 3, 5, 7)


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return seq.Song(BPM, BEATS_PER_BAR, bars, tail)


def vibe(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Vibraphone-ish: sine + 4th partial with a slow tremolo, soft mallet click."""
    f = midi_hz(note)
    trem = 1.0 + 0.25 * env.lfo(5.2, dur)
    y = osc.sine(f, dur) * env.exp_decay(dur, dur * 1.1, 0.002) * 0.7
    y += osc.sine(f * 4.0, dur) * env.exp_decay(dur, dur * 0.25, 0.001) * 0.18 * bright
    y += osc.sine(f * 10.0, dur) * env.exp_decay(dur, 0.04, 0.0005) * 0.06 * bright
    return y * trem


def horn(notes: list[int], dur: float, rng: np.random.Generator, cutoff: float = 900.0) -> np.ndarray:
    """Muted brass section chord: detuned saws through a slow-opening low-pass."""
    y = np.zeros(nsamp(dur))
    for note in notes:
        y += osc.supersaw(midi_hz(note), dur, 3, 6.0, rng)
    y /= len(notes) ** 0.7
    sweep = cutoff * (0.6 + 0.8 * env.adsr(dur, dur * 0.3, dur * 0.3, 0.6, dur * 0.3))
    y = filters.biquad_tv(y, "lp", sweep, 0.9)
    return fx.drive(y * env.adsr(dur, 0.04, 0.2, 0.8, dur * 0.35), 1.2)


def ride(rng: np.random.Generator) -> np.ndarray:
    return seq.hat(rng, True, 0.5) * 0.6


def part_walk(s: seq.Song, rng: np.random.Generator, bars: range, gain: float = 0.6, cutoff: float = 520.0) -> None:
    """Walking bass: four quarter notes per bar climbing the chord, approach note into the next."""
    for b in bars:
        root = seq.root_of(PROG8[b % len(PROG8)], 1)
        nxt = seq.root_of(PROG8[(b + 1) % len(PROG8)], 1)
        notes = [root + WALK[0], root + WALK[1] + (1 if "m" not in PROG8[b % 8] else 0), root + WALK[3], nxt - 1]
        for i, note in enumerate(notes):
            s.add("bass", seq.bass(note, s.beat_s * 0.9, rng, cutoff, 0.15, 0.8, 0.8), s.t(b, i), gain)


def stem_stealth() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["Dm9", "Bbmaj7", "Gm7", "A7sus4"]
    for i, name in enumerate(prog):
        d = s.bar_s * 8
        n = nsamp(d + 2.0)
        t = np.arange(n) / SR
        cut = 600 + 400 * np.sin(np.pi * np.minimum(t / d, 1.0)) ** 2
        s.add("keys", seq.pad(seq.chord(name, 3), d, rng, cut, attack=2.5, release=2.0, detune=5), s.t(i * 8), 0.5)
    s.add("bass", fx.pan(seq.drone(26, s.length_s, rng, 220), 0.0), 0.0, 0.45)
    for b in range(32):
        root = seq.root_of(prog[b // 8], 1)
        s.add("bass", seq.bass(root, 0.5, rng, 260, 0.1, 0.4, 0.9), s.t(b, 0.0), 0.6)
        if b % 2:
            s.add("bass", seq.bass(root + 7, 0.35, rng, 240, 0.1, 0.4, 0.9), s.t(b, 2.5), 0.4)
    part_hits(s, "perc", lambda: ride(rng), range(32), "x.....x.x.....x.", 0.07, 0.35, 0.3, rng)
    part_hits(s, "perc", lambda: seq.rim(rng, 1200), range(8, 32), "........x.......", 0.1, -0.2, 0.3, rng)
    for b in range(2, 32, 4):
        frag = MOTIF[:3] if (b // 4) % 2 == 0 else MOTIF[3:]
        part_motif(s, rng, b, frag, 0.34, -12 if b >= 16 else 0, 0.8, vibe)
    # harbour: distant foghorn-like low swells every 8 bars
    for b in (5, 13, 21, 29):
        d = s.bar_s * 1.5
        fh = osc.saw(midi_hz(38), d) + osc.saw(midi_hz(38) * 1.006, d)
        fh = filters.lp(fh, 300) * env.adsr(d, d * 0.3, 0.2, 0.8, d * 0.4)
        s.add("fx", fh, s.t(b), 0.07, -0.5)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.5, room="alley")


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.........x.....", 0.85)
    part_hits(s, "drums", lambda: seq.rim(rng, 1300), range(16), "....x.......x...", 0.28)
    part_hits(s, "perc", lambda: ride(rng), range(16), "x...x.x.x...x.x.", 0.12, 0.3, 0.3, rng)
    part_walk(s, rng, range(16), 0.55)
    part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.3)
    for b in range(0, 16, 2):
        s.add("keys", horn(seq.chord(PROG8[b % 8], 3), s.bar_s * 0.9, rng, 800), s.t(b, 0.5), 0.25)
    part_motif(s, rng, 4, MOTIF[:3], 0.3, 0, 0.7, vibe)
    part_motif(s, rng, 12, MOTIF, 0.32, 0, 0.8, vibe)
    return mixdown(s, hits, duck=0.3, room="alley")


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.........x.....", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "x.x.x.x.x.x.x.x.", lambda b: 280 + 70 * b, gain=0.55, gate=0.6, res=0.45)
    part_hits(s, "perc", lambda: ride(rng), range(4, 16), "x.x.x.x.x.x.x.x.", 0.12, 0.3, 0.3, rng)
    for b in range(12, 16):
        for i, t in enumerate(s.steps("..x...x...x.xxxx" if b == 15 else "....x.......x...", b)):
            s.add("drums", seq.snare(rng, 180, 0.22, 0.7), t, 0.22 + 0.06 * (b - 12) + 0.1 * (i / 8))
    for b in range(0, 16, 2):
        s.add("keys", horn(seq.chord(PROG8[b % 8], 3), s.bar_s * 1.8, rng, 600 + 60 * b), s.t(b), 0.3)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 200, 6000), s.t(8), 0.17)
    part_motif(s, rng, 8, MOTIF, 0.28, -12, 0.6, vibe)
    return mixdown(s, hits, duck=0.4, room="alley")


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x..x..x...x..x.." if b % 4 == 3 else "x.....x...x....."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 175), range(16), "....x.......x...", 0.75)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.xxx.xxx.xxx.xx", 0.12, 0.25, 0.5, rng)
    part_hits(s, "perc", lambda: ride(rng), range(16), "x...x...x...x...", 0.12, -0.3)
    for b in (7, 15):
        for i, t in enumerate(s.steps("........x.x.xxxx", b)):
            s.add("drums", seq.tom(rng, 140 - 8 * i), t, 0.4)
    part_bass(s, rng, PROG8, range(16), "x..x..x.x..x..x.", 850.0, octave_up="......o.......o.", gain=0.75,
              gate=0.75, res=0.4)
    for b in range(16):
        st = "x.....x...x....." if b % 2 == 0 else "..x.....x...x..."
        for t in s.steps(st, b):
            s.add("lead", fx.widen(horn(seq.chord(PROG8[b % 8], 4), s.beat_s * 0.6, rng, 2200), 6), t, 0.2)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1400.0, 0.25)
    for b in (8, 10, 12, 14):
        part_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.42, 0, 1.0, vibe)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.35)
    return mixdown(s, hits, duck=0.55, room="alley")


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.........x.....", 0.8)
    part_hits(s, "perc", lambda: ride(rng), range(16), "x...x.x.x...x.x.", 0.1, 0.3, 0.3, rng)
    part_hits(s, "drums", lambda: seq.rim(rng, 1300), range(16), "............x...", 0.22)
    part_walk(s, rng, range(16), 0.5, 440.0)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1000.0, 0.4)
    for b in (4, 12):
        part_motif(s, rng, b, MOTIF, 0.3, -12, 0.5, vibe)
    return mixdown(s, hits, duck=0.35, master_lp=4500, room="alley")


def stinger_win() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((62, 65, 69, 74, 77, 81)):
        place(out, fx.pan(vibe(note, 3.0, rng, 0.9), -0.4 + 0.16 * i), nsamp(i * 0.12), 0.38)
    place(out, fx.pan(horn(seq.chord("D", 3), 3.0, rng, 1400), 0), 0, 0.4)
    place(out, fx.pan(seq.bass(38, 3.0, rng, 400, 0.2, 1.0, 1.0) * env.adsr(3.0, 0.005, 1.0, 0.8, 2.0), 0), 0, 0.45)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((74, 70, 67, 61)):
        place(out, fx.pan(vibe(note, 3.0, rng, 0.6), 0.3 - 0.2 * i), nsamp(i * 0.34), 0.38)
    place(out, fx.pan(horn(seq.chord("Gm", 3), 3.5, rng, 700), 0), nsamp(0.2), 0.4)
    place(out, fx.pan(seq.drone(26, 4.0, rng, 260) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(0.5), 0.45)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), 0, 0.3)
    return fx.reverb(out, "hall", 0.4, tail=False)


STEMS = {"stealth": stem_stealth, "control": stem_control, "anticipation": stem_anticipation,
         "assault": stem_assault, "fade": stem_fade}
STINGERS = {"win": stinger_win, "lose": stinger_lose}
STEM_GAIN_DB = {"stealth": -6.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0, "fade": -3.0,
                "win": -2.0, "lose": -2.0}
BARS = {"stealth": 32, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
