"""Shadow Ledger music track: "glass tower, after hours", F# minor, 118 BPM grid, 4/4.

Two executive floors forty storeys up: cold sequenced plucks in 16ths (the ledger "ticker"), a soft
sub pulse, airy pads and a sparse electric-piano-like motif C#5 F#5 A5 G#5 E5 F#5. Progression
i - VI - III - VII (F#m7 Dmaj7 A E). Stealth is the heist's main bed (stealth-only map); the loud stems
exist for the jukebox and other heists. Stems: stealth (32 bars, half-time), control, anticipation,
assault, fade (16 bars each); stingers win/lose. Shares the sequencer parts in music_parts.py.
"""
from __future__ import annotations

import numpy as np

from music_parts import mixdown, part_arp, part_bass, part_hits, part_kick, part_motif, part_pad, part_stabs
from synth import env, filters, fx, osc, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "shadow_ledger"
KEY = "F# minor"
TITLE = "Shadow Ledger"
BPM = 118.0
BEATS_PER_BAR = 4
PROG8 = ["F#m7", "F#m7", "Dmaj7", "Dmaj7", "A", "A", "E", "E"]
MOTIF = [(0.0, 73, 0.5), (0.5, 78, 0.5), (1.0, 81, 1.0), (2.0, 80, 0.5), (2.5, 76, 0.5), (3.0, 78, 1.0)]
MOTIF_B = [(0.0, 73, 0.5), (0.5, 78, 0.5), (1.0, 81, 0.5), (1.5, 85, 1.0), (2.5, 83, 0.5), (3.0, 80, 1.0)]
TICKER = (0, 2, 1, 3, 2, 1, 3, 4)


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return seq.Song(BPM, BEATS_PER_BAR, bars, tail)


def epiano(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Tine electric piano: FM ratio 1 (warm) + a ratio-14 tine click."""
    f = midi_hz(note)
    idx = 1.4 * bright * env.exp_decay(dur, dur * 0.3)
    y = osc.fm(f, 1.0, idx, dur) * env.exp_decay(dur, dur * 0.9, 0.002) * 0.6
    y += osc.fm(f, 14.0, 0.6 * bright, dur) * env.exp_decay(dur, 0.06, 0.0005) * 0.12
    return y * (1.0 + 0.12 * env.lfo(4.5, dur))


def part_ticker(s: seq.Song, rng: np.random.Generator, bars: range, gain: float = 0.18, cutoff: float = 1800.0,
                every: int = 1) -> None:
    """The ledger ticker: 16th-note plucks through the chord tones, alternate steps panned."""
    step = s.beat_s / 4
    for b in bars:
        notes = seq.chord(PROG8[b % 8], 4)
        notes = notes + [notes[0] + 12]
        for i in range(0, 16, every):
            note = notes[TICKER[i % len(TICKER)] % len(notes)]
            s.add("keys", seq.pluck(note, step * 1.3, rng, cutoff), s.t(b, i / 4), gain * (1.0 if i % 4 else 1.3),
                  pan_pos=0.45 if i % 2 else -0.45)


def stem_stealth() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["F#m9", "Dmaj7#11", "Amaj7", "E7sus4"]
    for i, name in enumerate(prog):
        d = s.bar_s * 8
        n = nsamp(d + 2.0)
        t = np.arange(n) / SR
        cut = 900 + 700 * np.sin(np.pi * np.minimum(t / d, 1.0)) ** 2
        s.add("keys", seq.pad(seq.chord(name, 3), d, rng, cut, attack=3.0, release=2.0, detune=11), s.t(i * 8), 0.5)
    s.add("bass", fx.pan(seq.drone(30, s.length_s, rng, 240), 0.0), 0.0, 0.4)
    for b in range(32):
        root = seq.root_of(prog[b // 8], 1)
        for beat in (0.0, 2.0):
            s.add("bass", seq.bass(root, 0.25, rng, 200, 0.1, 0.5, 1.0), s.t(b, beat), 0.55)
    # muted ticker, every other 16th, only in the second half: the floor "wakes up"
    for b in range(16, 32):
        notes = seq.chord(prog[b // 8], 4)
        for i in range(0, 16, 2):
            s.add("keys", seq.pluck(notes[(i // 2) % len(notes)], 0.12, rng, 900), s.t(b, i / 4), 0.08,
                  pan_pos=0.5 if (i // 2) % 2 else -0.5)
    part_hits(s, "perc", lambda: seq.rim(rng, 2100), range(32), "........x.......", 0.08, 0.2, 0.3, rng)
    for b in range(2, 32, 4):
        frag = MOTIF[:3] if (b // 4) % 2 == 0 else MOTIF[3:]
        part_motif(s, rng, b, frag, 0.3, 0, 0.6, epiano)
    # tower hum: high air shimmer
    for k in range(14):
        t0 = float(rng.uniform(0, s.length_s))
        sp = osc.partials([float(rng.uniform(3000, 6000))], [1.0], [0.6], 1.2, rng)
        s.add("fx", sp, t0, 0.03, float(rng.uniform(-0.8, 0.8)))
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.55)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "............x...", 0.22)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.2, 0.25, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "x..x..x.x..x..x.", 380.0, gain=0.55)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1300.0, 0.35)
    part_ticker(s, rng, range(16), 0.12, 1500.0, 2)
    part_motif(s, rng, 4, MOTIF[:3], 0.28, 0, 0.6, epiano)
    part_motif(s, rng, 12, MOTIF, 0.3, 0, 0.7, epiano)
    return mixdown(s, hits, duck=0.35)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_bass(s, rng, PROG8, range(16), "x.xxx.xxx.xxx.xx", lambda b: 320 + 80 * b, gain=0.5, gate=0.6, res=0.5)
    part_ticker(s, rng, range(16), 0.13, 1200.0)
    part_hits(s, "drums", lambda: seq.hat(rng), range(8, 16), "x.x.x.x.x.x.x.x.", 0.2, -0.25, 0.3, rng)
    for b in range(12, 16):
        for i, t in enumerate(s.steps("....x.......x..." if b < 14 else "x.x.x.x.x.x.xxxx", b)):
            s.add("drums", seq.snare(rng, 210, 0.2, 0.6), t, 0.2 + 0.05 * (b - 12) + 0.12 * (i / 16))
    part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.4, 16)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 300, 8000), s.t(8), 0.17)
    part_motif(s, rng, 8, MOTIF, 0.26, -12, 0.6, epiano)
    return mixdown(s, hits, duck=0.45)


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x...x...x...x.x." if b % 4 == 3 else "x...x...x...x..."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.snare(rng, 200), range(16), "....x.......x...", 0.7)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "....x.......x...", 0.3, -0.1)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.11, 0.25, 0.5, rng)
    part_hits(s, "drums", lambda: seq.hat(rng, True), range(16), "..x...x...x...x.", 0.09, -0.25)
    part_bass(s, rng, PROG8, range(16), "x-x.x-x.x-x.x-xx", 950.0, octave_up="..o...o...o...o.", gain=0.72,
              gate=0.8, res=0.45)
    part_ticker(s, rng, range(16), 0.13, 2600.0)
    part_stabs(s, rng, PROG8, range(8, 16), "x.....x.....x...", 0.18)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1700.0, 0.25)
    for b in (8, 10, 12, 14):
        part_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.4, 0, 1.0, epiano)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.33)
    return mixdown(s, hits, duck=0.6)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.8)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.18, 0.2, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "x-x-x-x-x-x-x-x-", 480.0, gain=0.55)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1200.0, 0.45)
    part_arp(s, rng, PROG8, range(16), 0.1, 1100.0, (0, 2, 1, 3))
    for b in (4, 12):
        part_motif(s, rng, b, MOTIF, 0.3, -12, 0.5, epiano)
    return mixdown(s, hits, duck=0.4, master_lp=5000)


def stinger_win() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((66, 69, 73, 78, 81, 85)):
        place(out, fx.pan(epiano(note, 3.0, rng, 0.9), -0.4 + 0.16 * i), nsamp(i * 0.1), 0.38)
    place(out, seq.pad(seq.chord("Aadd9", 3), 3.0, rng, 2200, 0.3, 2.5), 0, 0.5)
    place(out, fx.pan(seq.bass(42, 3.0, rng, 450, 0.2, 1.0, 1.0) * env.adsr(3.0, 0.005, 1.0, 0.8, 2.0), 0), 0, 0.45)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), 0, 0.25)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((78, 73, 69, 66)):
        place(out, fx.pan(epiano(note, 3.0, rng, 0.5), 0.3 - 0.2 * i), nsamp(i * 0.3), 0.38)
    p = seq.pad(seq.chord("Dmaj7", 3), 3.5, rng, 1100, 0.2, 2.0)
    place(out, filters.lp(p, 1500), 0, 0.5)
    place(out, fx.pan(seq.drone(30, 4.0, rng, 280) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(0.5), 0.4)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), 0, 0.3)
    return fx.reverb(out, "hall", 0.4, tail=False)


STEMS = {"stealth": stem_stealth, "control": stem_control, "anticipation": stem_anticipation,
         "assault": stem_assault, "fade": stem_fade}
STINGERS = {"win": stinger_win, "lose": stinger_lose}
STEM_GAIN_DB = {"stealth": -6.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0, "fade": -3.0,
                "win": -2.0, "lose": -2.0}
BARS = {"stealth": 32, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
