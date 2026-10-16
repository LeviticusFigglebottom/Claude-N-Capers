"""Shadow Ledger music track (`shadow_ledger`, D-117 §7): corporate-tower stealth, B minor, 132 BPM grid.

Doc (shadow_ledger.md Audio/lighting): a stealth bed only (66 BPM, glassy pads, sub pulses, rain-noise
texture, a ticking motif for the hack and the time lock) plus a fail sting on the abort. The heist is
STEALTH_ONLY: any alarm sets the phase LOUD for the abort window (StealthTweak.stealth_only_abort_s), then
heist_ended(failed).

Rendered parts: `stealth` (32 bars of the 132 grid half-time = 66 BPM), `abort` (a 4-bar alarm loop that
covers the abort window), stingers `win` and `lose` (= the abort / fail sting). MusicDirector picks stems
by phase with no special case, so STEM_ALIASES maps every stem name it can ask for onto those two loops:
casing/stealth -> stealth; ESCAPE (stealth extraction) and the jukebox preview (default stem `assault`)
-> stealth, so the bed carries on through the escape; LOUD (control / anticipation / fade, i.e. the abort
window) -> abort. The fail sting plays on heist_ended(failed) as the `lose` stinger.

Identity: cold glass-harmonica pads (2:1 FM) instead of saw pads, rain hiss, a dry tick on the plate
reverb that tightens (half notes -> quarters -> eighths) like a hack counter; no drums at all.
Progression Bm(add9) - Gmaj7 - Em9 - F#7sus4.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_ticks
from synth import env, filters, fx, osc, seq
from synth.core import SR, nsamp, place, rng_for

TRACK = "shadow_ledger"
KEY = "B minor"
PALETTE = "glass-harmonica FM pads, sub pulses, rain-noise texture, hack/time-lock ticks; no drums"
BPM = 132.0
BEATS_PER_BAR = 4
PROG4 = ["Bmadd9", "Gmaj7", "Em9", "F#7sus4"]
# glass motif (beats on the half-time feel are doubled)
MOTIF = [(0.0, 78, 1.0), (1.0, 81, 1.0), (2.0, 85, 2.0)]
MOTIF_B = [(0.0, 83, 1.0), (1.0, 81, 1.0), (2.0, 78, 2.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


def _glass_motif(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]],
                 gain: float) -> None:
    for beat, note, length in motif:
        d = max(1.5, length * s.beat_s * 2.5)
        s.add("lead", seq.bell(note, d, rng, 0.35), s.t(bar, beat), gain, pan_pos=0.3 * np.sin(note))


def stem_stealth() -> np.ndarray:
    """32 bars @132 = 16 bars of 66 BPM. Glass pads (8 bars per chord), sub pulse heartbeat, rain,
    a hack tick that tightens over the loop, soft glass motif."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 7.0)
    for i, name in enumerate(PROG4):
        d = s.bar_s * 8
        s.add("keys", me.glass_pad(seq.chord(name, 4), d, rng, 2.5, 2.5, 0.9), s.t(i * 8), 0.6)
        s.add("keys", me.glass_pad(seq.chord(name, 3)[:2], d, rng, 3.0, 2.5, 0.5), s.t(i * 8), 0.4)
    s.add("bass", fx.pan(seq.drone(35, s.length_s, rng, 180), 0.0), 0.0, 0.35)
    for b in range(32):
        root = seq.root_of(PROG4[b // 8], 1)
        for beat, g in ((0.0, 1.0), (0.75, 0.55)):
            s.add("bass", seq.bass(root, 0.32, rng, 170, 0.1, 0.4, 1.0), s.t(b, beat), 0.8 * g)
    part_ticks(s, rng, range(0, 12), "x.......x.......", 0.13, 4200.0)
    part_ticks(s, rng, range(12, 24), "x...x...x...x...", 0.13, 4200.0)
    part_ticks(s, rng, range(24, 32), "x.x.x.x.x.x.x.x.", 0.12, 4200.0)
    part_ticks(s, rng, range(0, 32, 2), "X...............", 0.12, 4200.0, 1400.0, -0.3)
    for b in range(2, 32, 8):
        _glass_motif(s, rng, b, MOTIF, 0.22)
        _glass_motif(s, rng, b + 4, MOTIF_B, 0.18)
    s.add("fx", me.rain(s.length_s, rng), 0.0, 0.05)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.55, room="plate")


def stem_abort() -> np.ndarray:
    """4-bar alarm loop for the abort window: sub on every beat, eighth ticks, a B/C/F glass
    cluster (minor second + tritone) swelling, a filtered riser. Loops seamlessly if the window is long."""
    rng = rng_for(f"mus_{TRACK}_abort")
    s = _song(4, 4.0)
    for b in range(4):
        for beat in range(4):
            s.add("bass", seq.bass(35, 0.3, rng, 220, 0.2, 0.6, 1.0), s.t(b, beat), 0.85 if beat == 0 else 0.6)
    part_ticks(s, rng, range(4), "x.x.x.x.x.x.x.x.", 0.16, 4800.0)
    part_ticks(s, rng, range(4), "X.......X.......", 0.18, 4800.0, 1600.0)
    s.add("keys", me.glass_pad([71, 72, 77], s.bar_s * 4, rng, 0.4, 1.5, 1.6), 0.0, 0.6)
    s.add("keys", me.glass_pad([59, 65], s.bar_s * 4, rng, 0.2, 1.5, 1.2), 0.0, 0.4)
    s.add("fx", seq.riser(rng, s.bar_s * 4, 400, 5000), 0.0, 0.12)
    s.add("fx", me.rain(s.length_s, rng), 0.0, 0.04)
    return mixdown(s, [], duck=0.0, keys_verb=0.35, room="plate")


def stinger_win() -> np.ndarray:
    """Clean extraction: rising glass bells into D major add9 (relative major), sub swell."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(6.0), 2))
    for i, note in enumerate((71, 74, 78, 81, 86)):
        place(out, fx.pan(seq.bell(note, 3.0, rng, 0.5), -0.4 + 0.2 * i), nsamp(i * 0.16), 0.32)
    place(out, me.glass_pad(seq.chord("Dadd9", 4), 2.8, rng, 0.3, 2.5), 0, 0.55)
    place(out, fx.pan(seq.bass(38, 3.5, rng, 300, 0.1, 1.0, 1.0) * env.adsr(3.5, 0.3, 1.0, 0.8, 2.5), 0), 0, 0.45)
    return fx.reverb(out, "plate", 0.4, tail=False)


def stinger_lose() -> np.ndarray:
    """Abort / fail sting: a hard glass cluster hit, the ticks stopping, the cluster bending down a
    fourth over a sub drop, rain left behind."""
    rng = rng_for(f"mus_{TRACK}_lose")
    dur = 6.0
    out = np.zeros((nsamp(dur), 2))
    hit = np.zeros(nsamp(3.0))
    for note in (71, 72, 77, 83):
        hit += seq.bell(note, 3.0, rng, 1.4)
    place(out, fx.widen(hit * 0.4, 8), 0, 0.5)
    for i in range(4):
        place(out, fx.pan(me.tick(rng, 4800), 0.3), nsamp(i * 0.12), 0.3)
    n = nsamp(4.5)
    t = np.arange(n) / SR
    bend = 2 ** (-5 * np.clip((t - 0.4) / 3.0, 0, 1) ** 1.5 / 12)
    cl = np.zeros(n)
    for note in (59, 60, 65):
        cl += osc.fm(440.0 * 2 ** ((note - 69) / 12) * bend, 2.0, 0.9, 4.5)
    cl *= env.adsr(4.5, 0.05, 0.5, 0.7, 2.0)
    place(out, fx.widen(cl * 0.25, 10), nsamp(0.3), 0.5)
    sub = osc.sine(62 * np.geomspace(1.0, 0.5, nsamp(3.0)), 3.0) * env.adsr(3.0, 0.01, 0.5, 0.8, 1.5)
    place(out, fx.pan(fx.drive(sub, 1.5), 0), nsamp(0.3), 0.6)
    place(out, me.rain(dur, rng) * np.linspace(0, 1, nsamp(dur))[:, None], 0, 0.06)
    out = filters.hp(out, 25)
    return fx.reverb(out, "plate", 0.45, tail=False)


STEMS: dict[str, Callable[[], np.ndarray]] = {"stealth": stem_stealth, "abort": stem_abort}
STINGERS: dict[str, Callable[[], np.ndarray]] = {"win": stinger_win, "lose": stinger_lose}
# MusicTrack stem name -> rendered part (see the module doc)
STEM_ALIASES: dict[str, str] = {"stealth": "stealth", "control": "abort", "anticipation": "abort",
                                "assault": "stealth", "fade": "abort"}
STEM_GAIN_DB: dict[str, float] = {"stealth": -6.0, "control": -3.0, "anticipation": -3.0, "assault": -6.0,
                                  "fade": -3.0, "win": -2.0, "lose": -1.0}
BARS: dict[str, int] = {"stealth": 32, "abort": 4}
