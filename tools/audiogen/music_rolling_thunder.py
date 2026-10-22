"""Rolling Thunder music track (`rolling_thunder`, RT-C2): the Vaultline convoy ambush under the Southfield Skyway,
F minor, 148 BPM grid.

Doc (rolling_thunder.md Audio/lighting): stealth 78 BPM (a ticking hi-hat clock motif over a low synth pad, used for
the setup countdown and rising at ETA - 30 s); control 112 BPM; anticipation riser; assault 148 BPM (driving
percussion, diesel-drone bass and a two-note signal-chime motif); fade; win / lose stingers.

One bar grid per track (MusicDirector keeps the phrase position across bar-line switches): 148 BPM, so stealth is
the grid at half time = 74 BPM (doc 78: -4 BPM so it shares the assault grid, which the doc pins at 148); control
runs in quarter-note triplets = 111 BPM pulse (doc 112); assault is the 148 grid itself.

Identity (kept apart from Ostrander Federal's horns / strings in D minor at the same grid, Dockside Burn's clangs /
fog horn in E phrygian and Night Deposit's brass in C minor): a closed hi-hat "clock" (tick on the off-beats, a
heavier tock on the beat, an open-hat chime every bar) over a dark detuned-saw pad, sub pulses; the clock doubles
to sixteenths in the second half of the stealth loop (ETA - 30 s); in the loud stems a **diesel-drone bass** (two
detuned saws + a square sub chugging at the sixteenth-note firing rate through a growling low-pass) and a
**two-note signal chime** (a bright inharmonic crossing-bell partial bank, C6 -> Ab5, the falling major third of a
level-crossing signal) over kick, snare, low toms and sixteenth hats.
Progression i - bVII - bVI - V (Fm Eb Db C) in stealth, Fm Fm Db Db Eb Eb C C in the loud stems.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_hits, part_kick, part_triplets
from synth import env, filters, fx, noise, osc, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "rolling_thunder"
KEY = "F minor"
PALETTE = "hi-hat clock motif, dark detuned-saw pad, sub pulses, diesel-drone bass, two-note signal chime, kit + toms"
BPM = 148.0
BEATS_PER_BAR = 4
PROG_STEALTH = ["Fm", "Eb", "Db", "C"]
PROG8 = ["Fm", "Fm", "Db", "Db", "Eb", "Eb", "C", "C"]
# the signal chime: (beat, midi note, beats). C6 -> Ab5 (falling major third), answered C6 -> Db6 (the b6 tension)
CHIME = [(0.0, 84, 1.0), (1.0, 80, 1.0), (2.0, 84, 1.0), (3.0, 80, 1.0)]
CHIME_B = [(0.0, 84, 1.0), (1.0, 80, 1.0), (2.0, 84, 0.5), (2.5, 85, 1.5)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


# ------------------------------------------------------------------ instruments


def chime(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Signal chime (mono): a struck crossing bell, inharmonic partials 1 / 2.76 / 4.07 / 5.4 / 6.75 with a bright
    strike and a slight beating pair on the fundamental. Brighter and shorter than seq.bell (Golden Hour's FM)."""
    f = midi_hz(note)
    ratios = [1.0, 1.003, 2.76, 4.07, 5.4, 6.75]
    amps = [0.8, 0.5, 0.55 * bright, 0.35 * bright, 0.22 * bright, 0.12 * bright]
    decays = [dur * 0.55, dur * 0.5, dur * 0.25, dur * 0.15, dur * 0.1, dur * 0.07]
    y = osc.partials([f * r for r in ratios], amps, decays, dur, rng)
    y += filters.bp(noise.white(dur, rng), 5200, 2.0) * env.exp_decay(dur, 0.01, 0.0002) * 0.3 * bright
    return y * 0.7


def diesel_bass(note: int, dur: float, rng: np.random.Generator, rate_hz: float, cutoff: float = 520.0,
                chug: float = 0.55) -> np.ndarray:
    """Diesel-drone bass (mono): two detuned saws + a square sub, amplitude-chugged at `rate_hz` (the engine's
    firing rate, locked to the grid) through a growling resonant low-pass, then driven."""
    f = midi_hz(note)
    n = nsamp(dur)
    t = np.arange(n) / SR
    y = osc.saw(f, dur, float(rng.random())) + osc.saw(f * 1.006, dur, float(rng.random())) * 0.8
    y += osc.square(f * 0.5, dur, 0.5) * 0.6
    fire = (0.5 + 0.5 * np.cos(2 * np.pi * rate_hz * t)) ** 3
    y *= (1.0 - chug) + chug * fire
    cut = cutoff * (1.0 + 0.6 * fire) * (1.0 + 0.3 * np.sin(2 * np.pi * 0.21 * t))
    y = filters.biquad_tv(y, "lp", cut, 1.6)
    y += filters.lp(noise.brown(dur, rng), 160) * fire * 0.4
    return fx.drive(y * env.adsr(dur, 0.02, 0.2, 0.9, min(0.12, dur * 0.2)), 2.2) * 0.6


def _hat_clock(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float,
               pan_pos: float = -0.2) -> None:
    """The ticking hi-hat clock: 'x' closed tick, 'X' heavier tock (longer, lower-cut hat), 'o' open-hat chime."""
    for b in bars:
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            if ch == "o":
                y, g = seq.hat(rng, True, 0.28), 0.6
            elif ch == "X":
                y, g = filters.lp(seq.hat(rng, False, 0.1), 9000), 1.25
            else:
                y, g = seq.hat(rng, False, 0.045), float(rng.uniform(0.8, 1.0))
            s.add("perc", y, s.t(b, i / 4), gain * g, pan_pos)


def _chime_motif(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]],
                 gain: float, transpose: int = 0, bright: float = 1.0) -> None:
    for beat, note, beats in motif:
        y = chime(note + transpose, max(1.0, s.beat_s * beats * 2.5), rng, bright)
        s.add("lead", y, s.t(bar, beat), gain, 0.2 if note % 2 else -0.2)


def _diesel_line(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, gain: float,
                 cutoff: float | Callable[[int], float] = 520.0, chug: float = 0.55, octave: int = 1) -> None:
    rate = 4.0 / s.beat_s  # sixteenth-note firing
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        cut = cutoff(b) if callable(cutoff) else cutoff
        note = seq.root_of(me.chord_at(prog, b), octave)
        s.add("bass", diesel_bass(note, s.bar_s * bars_per * 0.98, rng, rate, cut, chug), s.t(b), gain)


def _toms(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float) -> list[float]:
    times: list[float] = []
    for b in bars:
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            t = s.t(b, i / 4)
            s.add("drums", seq.tom(rng, 66.0 if ch == "x" else 92.0, 0.5), t, gain, -0.2 if ch == "x" else 0.2)
            times.append(t)
    return times


def _sub_pulse(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range | list[int], pattern: str,
               gain: float) -> None:
    for b in bars:
        root = seq.root_of(me.chord_at(prog, b), 1)
        for t in s.steps(pattern, b):
            s.add("bass", seq.bass(root, s.beat_s * 0.9, rng, 180.0, 0.2, 1.0, 1.0), t, gain)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @148 = 16 bars of 74 BPM. Low dark pad on i - bVII - bVI - V (8 bars per chord), sub pulses on the
    half-time beat, the hi-hat clock ticking eighths of the half-time (tock on the beat) and doubling to sixteenths
    with the pad opening in bars 16-31 (the ETA - 30 s rise), a quiet chime pair on each chord change."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    st8 = [c for c in PROG_STEALTH for _ in range(8)]
    for i, name in enumerate(PROG_STEALTH):
        d = s.bar_s * 8
        cut = 520.0 if i < 2 else 900.0
        s.add("keys", seq.pad(seq.chord(name, 3), d, rng, cut, attack=2.5, release=2.0, detune=12.0), s.t(i * 8), 0.55)
        s.add("bass", fx.pan(seq.drone(seq.root_of(name, 1), d + 1.0, rng, 220.0), 0.0), s.t(i * 8), 0.35)
        s.add("fx", chime(seq.root_of(name, 5), 4.0, rng, 0.5), s.t(i * 8), 0.07, 0.3)
    _sub_pulse(s, rng, st8, range(2, 32), "x.......x.......", 0.3)
    _hat_clock(s, rng, range(0, 16), "X...x...X...x...", 0.16)
    _hat_clock(s, rng, range(16, 32), "X.x.x.x.X.x.x.x.", 0.15)
    for b in range(3, 32, 4):
        _hat_clock(s, rng, [b], "............o...", 0.12, 0.3)
    for b in (12, 28):
        _chime_motif(s, rng, b, CHIME[:2], 0.08, -12, 0.5)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.55)


def stem_control() -> np.ndarray:
    """Quarter-note triplet pulse (111 BPM feel): kick and low tom on the pulse, a muted diesel drone, triplet hat
    clock, the pad, the chime motif muted (lower, darker)."""
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits: list[float] = []
    k = seq.kick(rng, 0.8)
    for b in range(16):
        for i in (0, 4, 8):
            t = s.t(b, i / 3)
            if i == 0 or b % 2 == 0:
                s.add("drums", k, t, 0.55 if i == 0 else 0.4)
                hits.append(t)
            else:
                s.add("drums", seq.tom(rng, 70.0, 0.5), t, 0.4)
    part_triplets(s, range(16), "x.xx.xx.xx.x", lambda b, i: seq.hat(rng, False, 0.045), "perc", 0.09, -0.2)
    part_triplets(s, range(16), "....x.......", lambda b, i: seq.rim(rng, 1500), "perc", 0.18, 0.2)
    _diesel_line(s, rng, PROG8, range(16), 2, 0.38, 380.0, 0.4)
    me.part_pad(s, rng, PROG8, range(16), 2, 3, 1100.0, 0.4)
    _chime_motif(s, rng, 4, CHIME, 0.12, -12, 0.6)
    _chime_motif(s, rng, 12, CHIME_B, 0.12, -12, 0.6)
    return mixdown(s, hits, duck=0.25)


def stem_anticipation() -> np.ndarray:
    """The build: toms doubling, the diesel bass opening up bar by bar, the hat clock accelerating, a snare roll in
    bars 12-15 and a noise riser over the second half."""
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = _toms(s, rng, range(0, 8), "x.......x.......", 0.5)
    hits += _toms(s, rng, range(8, 16), "x...x...x...x...", 0.55)
    _diesel_line(s, rng, PROG8, range(16), 1, 0.4, lambda b: 300.0 + 40.0 * b, 0.6)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 210, 0.2, 0.7), t, 0.12 + 0.04 * (b - 12) + 0.12 * (i / 16))
    _hat_clock(s, rng, range(0, 8), "X.x.x.x.X.x.x.x.", 0.13)
    _hat_clock(s, rng, range(8, 16), "Xxxxxxxxxxxxxxxx", 0.12)
    me.part_pad(s, rng, PROG8, range(16), 2, 3, 900.0, 0.45)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 250, 7000), s.t(8), 0.18)
    _chime_motif(s, rng, 8, CHIME, 0.16, 0, 0.8)
    return mixdown(s, hits, duck=0.3)


def stem_assault() -> np.ndarray:
    """Driving percussion (kick, snare, low toms, sixteenth hats) on the 148 grid, the diesel-drone bass chugging
    in sixteenths, a pad bed and the two-note signal chime on top."""
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.....x...x.....", 0.75)
    part_hits(s, "drums", lambda: seq.snare(rng, 200, 0.28), range(16), "....x.......x...", 0.6)
    _toms(s, rng, range(16), "..x.......o.....", 0.32)
    _toms(s, rng, [7, 15], "........x.o.xoxo", 0.4)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.07, 0.25, 0.4, rng)
    _hat_clock(s, rng, range(16), "..o.......o.....", 0.06, 0.35)
    _diesel_line(s, rng, PROG8, range(16), 1, 0.55, 700.0, 0.7)
    me.part_pad(s, rng, PROG8, range(16), 2, 3, 1600.0, 0.32)
    for b in range(0, 16, 2):
        _chime_motif(s, rng, b, CHIME if b % 8 < 6 else CHIME_B, 0.24 if b < 8 else 0.3, 0, 1.1)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(6), 0.15)
    s.add("fx", seq.impact(rng, 2.5), s.t(8), 0.3)
    return mixdown(s, hits, duck=0.45, drive=1.1)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = _toms(s, rng, range(16), "x.......x.......", 0.4)
    _hat_clock(s, rng, range(16), "X...x...X...x...", 0.12)
    _diesel_line(s, rng, PROG8, range(16), 2, 0.4, 340.0, 0.35)
    me.part_pad(s, rng, PROG8, range(16), 2, 3, 1000.0, 0.45)
    for b in (4, 12):
        _chime_motif(s, rng, b, CHIME[:2], 0.12, -12, 0.5)
    return mixdown(s, hits, duck=0.3, master_lp=5000)


def stinger_win() -> np.ndarray:
    """The signal chime rings up an F major arpeggio, the pad lands on F major (Picardy), a tom hit and a last
    chime ring out."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((77, 81, 84, 89)):
        place(out, fx.pan(chime(note, 1.2 if i < 3 else 3.5, rng, 1.1), -0.3 + 0.2 * i), nsamp(i * 0.16), 0.3)
    place(out, seq.pad(seq.chord("F", 3) + [seq.root_of("F", 2)], 2.8, rng, 2200, 0.25, 2.5), nsamp(0.5), 0.5)
    place(out, fx.pan(seq.tom(rng, 66.0, 1.0), 0), nsamp(0.48), 0.4)
    place(out, fx.pan(seq.hat(rng, True, 0.6), 0.3), nsamp(0.48), 0.15)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """The chime falls C Ab F E, the pad droops on F minor, the diesel winds down (firing slowing to a stall) and the
    clock stops."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((84, 80, 77, 76)):
        place(out, fx.pan(chime(note, 1.4, rng, 0.6), 0.3 - 0.15 * i), nsamp(i * 0.3), 0.26)
    p = seq.pad(seq.chord("Fm", 3) + [41], 3.2, rng, 1100, 0.3, 1.8)
    n = p.shape[0]
    idx = np.cumsum(np.linspace(1.0, 0.85, n))
    idx = idx[idx < n - 1]
    pd = np.stack([np.interp(idx, np.arange(n), p[:, c]) for c in range(2)], axis=1)
    place(out, pd, nsamp(0.4), 0.5)
    d = 4.0
    t = np.arange(nsamp(d)) / SR
    rate = 9.9 * np.exp(-t / 1.4)
    fire = (0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / SR)) ** 4
    f = midi_hz(29) * (1 - 0.25 * t / d)
    eng = filters.lp(osc.saw(f, d) + osc.square(f * 0.5, d, 0.5) * 0.6, 400) * fire * env.adsr(d, 0.05, 0.2, 0.9, 1.5)
    place(out, fx.pan(fx.drive(eng, 1.8), 0.0), nsamp(0.9), 0.35)
    tk = 0.3
    gap = 0.3
    for _ in range(8):
        place(out, fx.pan(seq.hat(rng, False, 0.045), -0.2), nsamp(tk), 0.3)
        tk += gap
        gap *= 1.22
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
