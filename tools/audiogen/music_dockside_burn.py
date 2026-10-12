"""Dockside Burn music track: "cold storage on fire", E Phrygian, 150 BPM grid, 4/4.

A loud heist in a harbour cold store: driving industrial drums with metal hits (anvil-like partial
clusters), an overdriven power-chord bass, a siren-like detuned lead and the motif E5 F5 G5 F5 E5 B4
(the flat 2 is the Phrygian "burn"). Progression E5 F5 G5 F5 / E5 F5 D5 E5. Stems: stealth (32 bars,
half-time), control, anticipation, assault, fade (16 bars each); stingers win/lose. Shares the
sequencer parts in music_parts.py.
"""
from __future__ import annotations

import numpy as np

from music_parts import mixdown, part_bass, part_hits, part_kick, part_motif, part_pad
from synth import env, filters, fx, noise, osc, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "dockside_burn"
KEY = "E Phrygian"
TITLE = "Dockside Burn"
BPM = 150.0
BEATS_PER_BAR = 4
PROG8 = ["E5", "E5", "F5", "F5", "G5", "F5", "D5", "E5"]
MOTIF = [(0.0, 76, 0.5), (0.5, 77, 0.5), (1.0, 79, 1.0), (2.0, 77, 0.5), (2.5, 76, 0.5), (3.0, 71, 1.0)]
MOTIF_B = [(0.0, 76, 0.5), (0.5, 77, 0.5), (1.0, 79, 0.5), (1.5, 83, 1.0), (2.5, 81, 0.5), (3.0, 77, 1.0)]
BUS = {"drums": 1.1, "perc": 1.0, "bass": 0.7, "keys": 1.5, "lead": 1.6, "fx": 1.0}


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return seq.Song(BPM, BEATS_PER_BAR, bars, tail)


def metal(rng: np.random.Generator, f0: float = 420.0, dur: float = 0.6) -> np.ndarray:
    """Struck steel (pipe / container wall): inharmonic partials + a noise strike."""
    ratios = [1.0, 2.76, 5.4, 8.93]
    y = osc.partials([f0 * r for r in ratios], [1.0, 0.6, 0.35, 0.2], [dur, dur * 0.6, dur * 0.35, dur * 0.2], dur, rng)
    strike = filters.bp(noise.white(0.02, rng), 3000, 1.0) * env.exp_decay(0.02, 0.01)
    return fx.drive(y + np.pad(strike, (0, y.shape[0] - strike.shape[0])) * 0.6, 1.3)


def siren(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Detuned square lead with a slow pitch wobble (siren colour), filtered by `bright`."""
    f = midi_hz(note) * (1.0 + 0.004 * env.lfo(5.5, dur))
    y = osc.square(f, dur, 0.4) * 0.5 + osc.saw(f * 1.006, dur) * 0.5
    y = filters.biquad_tv(y, "lp", 1200 + 2400 * bright * env.exp_decay(dur, dur * 0.5), 1.1)
    return y * env.adsr(dur, 0.01, 0.2, 0.7, dur * 0.3) * 0.7


def power(note_root: int, dur: float, rng: np.random.Generator, cutoff: float = 1600.0) -> np.ndarray:
    """Overdriven power chord (root, fifth, octave)."""
    y = np.zeros(nsamp(dur))
    for k in (0, 7, 12):
        y += osc.supersaw(midi_hz(note_root + k), dur, 3, 10.0, rng)
    y = filters.lp(fx.drive(y * 0.5, 3.0), cutoff)
    return y * env.adsr(dur, 0.003, 0.1, 0.8, min(0.08, dur * 0.3))


def part_chug(s: seq.Song, rng: np.random.Generator, bars: range, pattern: str, gain: float = 0.3,
              cutoff: float = 1600.0) -> None:
    for b in bars:
        root = seq.root_of(PROG8[b % 8], 2)
        for t in s.steps(pattern, b):
            s.add("keys", fx.widen(power(root, s.beat_s * 0.22, rng, cutoff), 8), t, gain)


def stem_stealth() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    prog = ["Em", "F", "Em", "Dsus4"]
    for i, name in enumerate(prog):
        d = s.bar_s * 8
        n = nsamp(d + 2.0)
        t = np.arange(n) / SR
        cut = 500 + 450 * np.sin(np.pi * np.minimum(t / d, 1.0)) ** 2
        s.add("keys", seq.pad(seq.chord(name, 3), d, rng, cut, attack=2.5, release=2.0, detune=12), s.t(i * 8), 0.5)
    s.add("bass", fx.pan(seq.drone(28, s.length_s, rng, 200), 0.0), 0.0, 0.5)
    for b in range(32):
        root = seq.root_of(prog[b // 8], 1)
        s.add("bass", seq.bass(root, 0.3, rng, 220, 0.1, 0.5, 1.0), s.t(b, 0.0), 0.7)
        s.add("bass", seq.bass(root, 0.2, rng, 200, 0.1, 0.5, 1.0), s.t(b, 0.5), 0.4)
    # cold-store machinery: distant metal ticks and a compressor hum
    part_hits(s, "perc", lambda: metal(rng, 900, 0.3), range(32), "............x...", 0.05, 0.4, 0.4, rng)
    part_hits(s, "perc", lambda: seq.shaker(rng, 0.06), range(16, 32), "..x...x...x...x.", 0.05, -0.3, 0.4, rng)
    for b in range(2, 32, 4):
        frag = MOTIF[:3] if (b // 4) % 2 == 0 else MOTIF[3:]
        part_motif(s, rng, b, frag, 0.22, -12, 0.4, siren)
    return mixdown(s, [], duck=0.0, keys_verb=0.35, lead_verb=0.5, bus_gain=BUS, room="alley")


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.....x...x.....", 0.95)
    part_hits(s, "drums", lambda: seq.snare(rng, 180, 0.25, 0.8), range(16), "............x...", 0.4)
    part_hits(s, "perc", lambda: metal(rng, 520, 0.4), range(16), "....x.......x...", 0.12, 0.3, 0.3, rng)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "x.x.x.x.x.x.x.x.", 0.15, -0.2, 0.4, rng)
    part_bass(s, rng, PROG8, range(16), "x.xx.xx.x.xx.xx.", 500.0, gain=0.6, gate=0.7)
    part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.3)
    part_motif(s, rng, 4, MOTIF[:3], 0.22, 0, 0.6, siren)
    part_motif(s, rng, 12, MOTIF, 0.24, 0, 0.7, siren)
    return mixdown(s, hits, duck=0.4, bus_gain=BUS, room="alley")


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(0, 8), "x.....x...x.....", 0.95)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.05)
    part_bass(s, rng, PROG8, range(16), "xxxxxxxxxxxxxxxx", lambda b: 300 + 100 * b, gain=0.55, gate=0.65, res=0.55)
    part_hits(s, "perc", lambda: metal(rng, 520, 0.4), range(4, 16), "....x.......x...", 0.15, 0.3)
    part_chug(s, rng, range(8, 16), "x.x.x.x.x.x.x.x.", 0.12, 900.0)
    for b in range(12, 16):
        for i, t in enumerate(s.steps({12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.",
                                       15: "xxxxxxxxxxxxxxxx"}[b], b)):
            s.add("drums", seq.snare(rng, 190, 0.2, 0.6), t, 0.22 + 0.05 * (b - 12) + 0.15 * (i / 16))
    s.add("fx", seq.riser(rng, s.bar_s * 8, 200, 7000), s.t(8), 0.2)
    part_motif(s, rng, 8, MOTIF, 0.22, -12, 0.6, siren)
    return mixdown(s, hits, duck=0.5, bus_gain=BUS, room="alley")


def stem_assault() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x.x.x...x.x.x.xx" if b % 4 == 3 else "x...x.x...x.x..."

    hits = part_kick(s, rng, range(16), kpat, 1.05)
    part_hits(s, "drums", lambda: seq.snare(rng, 185, 0.3, 1.1), range(16), "....x.......x...", 0.8)
    part_hits(s, "perc", lambda: metal(rng, 440, 0.5), range(16), "..x.....x.x.....", 0.16, 0.35, 0.3, rng)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.12, 0.25, 0.5, rng)
    for b in (7, 15):
        for i, t in enumerate(s.steps("........xxxxxxxx", b)):
            s.add("drums", seq.tom(rng, 150 - 9 * i), t, 0.38)
    part_bass(s, rng, PROG8, range(16), "x-xx-xx-x-xx-xxx", 1100.0, octave_up="...o..o....o..o.", gain=0.75,
              gate=0.8, res=0.45)
    part_chug(s, rng, range(16), "x..x..x.x..x..x.", 0.2, 1800.0)
    for b in (8, 10, 12, 14):
        part_motif(s, rng, b, MOTIF if b < 14 else MOTIF_B, 0.36, 0, 1.0, siren)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.4)
    return mixdown(s, hits, duck=0.6, bus_gain=BUS, room="alley")


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.....x...x.....", 0.85)
    part_hits(s, "perc", lambda: metal(rng, 520, 0.4), range(16), "............x...", 0.1, 0.3)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "..x...x...x...x.", 0.18, 0.2, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "x-x-x-x-x-x-x-x-", 520.0, gain=0.6)
    part_pad(s, rng, PROG8, range(16), 2, 3, 1000.0, 0.4)
    for b in (4, 12):
        part_motif(s, rng, b, MOTIF, 0.24, -12, 0.5, siren)
    return mixdown(s, hits, duck=0.4, master_lp=4500, bus_gain=BUS, room="alley")


def stinger_win() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    place(out, fx.pan(power(40, 3.0, rng, 2200), 0), 0, 0.45)
    for i, note in enumerate((64, 71, 76, 83)):
        place(out, fx.pan(siren(note, 2.5, rng, 0.8), -0.3 + 0.2 * i), nsamp(i * 0.1), 0.25)
    place(out, fx.pan(metal(rng, 440, 2.5), 0.2), 0, 0.3)
    place(out, fx.pan(seq.impact(rng, 4.0), 0), 0, 0.35)
    return fx.reverb(out, "hall", 0.3, tail=False)


def stinger_lose() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((77, 76, 72, 71)):
        place(out, fx.pan(siren(note, 2.5, rng, 0.5), 0.3 - 0.2 * i), nsamp(i * 0.32), 0.3)
    place(out, fx.pan(power(41, 3.0, rng, 900), 0), nsamp(0.1), 0.35)
    place(out, fx.pan(seq.drone(28, 4.0, rng, 260) * env.adsr(4.0, 0.5, 1, 0.8, 2.0), 0), nsamp(0.5), 0.45)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), 0, 0.35)
    return fx.reverb(out, "hall", 0.4, tail=False)


STEMS = {"stealth": stem_stealth, "control": stem_control, "anticipation": stem_anticipation,
         "assault": stem_assault, "fade": stem_fade}
STINGERS = {"win": stinger_win, "lose": stinger_lose}
STEM_GAIN_DB = {"stealth": -6.0, "control": -3.0, "anticipation": -2.0, "assault": 0.0, "fade": -3.0,
                "win": -2.0, "lose": -2.0}
BARS = {"stealth": 32, "control": 16, "anticipation": 16, "assault": 16, "fade": 16}
