"""Shared music parts for the procedural heist tracks (tools/audiogen/music_<track>.py).

Moved verbatim from music_glasshouse.py (C5-01) so every track uses the same sequencer parts and bus
mix; Glasshouse output is byte-identical. `part_motif` takes the motif instrument, `mixdown` an optional
bus-gain table.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

from synth import fx, filters, seq
from synth.core import SR, nsamp, wrap_loop


def chord_at(prog: list[str], bar: int) -> str:
    return prog[bar % len(prog)]


# ------------------------------------------------------------------ parts


def part_kick(s: seq.Song, rng: np.random.Generator, bars: range, pattern: str | Callable[[int], str],
              gain: float = 1.0) -> list[float]:
    k = seq.kick(rng)
    hits: list[float] = []
    for b in bars:
        pat = pattern(b) if callable(pattern) else pattern
        for t in s.steps(pat, b):
            s.add("drums", k, t, gain)
            hits.append(t)
    return hits


def part_hits(s: seq.Song, bus: str, sound_fn: Callable[[], np.ndarray], bars: range | list[int],
              pattern: str | Callable[[int], str], gain: float = 1.0, pan_pos: float = 0.0,
              human: float = 0.0, rng: np.random.Generator | None = None) -> None:
    for b in bars:
        pat = pattern(b) if callable(pattern) else pattern
        for t in s.steps(pat, b):
            g = gain * (1.0 if rng is None else rng.uniform(1 - human, 1.0))
            s.add(bus, sound_fn(), t, g, pan_pos)


def part_bass(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str,
              cutoff: float | Callable[[int], float] = 700.0, octave_up: str = "", gain: float = 1.0,
              gate: float = 0.85, res: float = 0.35) -> None:
    step = s.beat_s / 4
    for b in bars:
        root = seq.root_of(chord_at(prog, b), 1)
        cut = cutoff(b) if callable(cutoff) else cutoff
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            run = 1
            while i + run < len(pattern) and pattern[i + run] == "-":
                run += 1
            note = root + (12 if (octave_up and i < len(octave_up) and octave_up[i] == "o") else 0)
            d = step * run * gate
            s.add("bass", seq.bass(note, d, rng, cut, res), s.t(b, i / 4), gain)


def part_pad(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per_chord: int,
             octave: int = 3, cutoff: float = 1400.0, gain: float = 0.5, lfo_bars: float = 8.0) -> None:
    for b in bars:
        if (b - bars.start) % bars_per_chord:
            continue
        name = chord_at(prog, b)
        d = s.bar_s * bars_per_chord
        rel = 1.5
        n = nsamp(d + rel)
        t = np.arange(n) / SR + s.t(b)
        cut = cutoff * (1 + 0.45 * np.sin(2 * np.pi * t / (lfo_bars * s.bar_s)))
        notes = seq.chord(name, octave)
        s.add("keys", seq.pad(notes, d, rng, cut, attack=min(1.2, d * 0.3), release=rel), s.t(b), gain)


def part_motif(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]],
               gain: float = 0.5, transpose: int = 0, bright: float = 1.0,
               inst: Callable[[int, float, np.random.Generator, float], np.ndarray] = seq.bell) -> None:
    for beat, note, length in motif:
        dur = max(1.2, length * s.beat_s * 3)
        s.add("lead", inst(note + transpose, dur, rng, bright), s.t(bar, beat), gain,
              pan_pos=0.25 * np.sin(note))


def part_arp(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, gain: float = 0.25,
             cutoff: float = 2200.0, pattern: tuple[int, ...] = (0, 1, 2, 1, 2, 3, 2, 1)) -> None:
    step = s.beat_s / 4
    for b in bars:
        notes = seq.chord(chord_at(prog, b), 4)
        notes = notes + [notes[0] + 12]
        for i in range(16):
            note = notes[pattern[i % len(pattern)] % len(notes)]
            s.add("keys", seq.pluck(note, step * 1.6, rng, cutoff), s.t(b, i / 4), gain,
                  pan_pos=0.35 if i % 2 else -0.35)


def part_stabs(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str,
               gain: float = 0.35) -> None:
    for b in bars:
        notes = seq.chord(chord_at(prog, b), 4)
        st = seq.stab(notes, s.beat_s * 0.45, rng)
        for t in s.steps(pattern, b):
            s.add("lead", fx.widen(st, 7), t, gain)


# ------------------------------------------------------------------ mix


BUS_GAIN: dict[str, float] = {"drums": 1.0, "perc": 1.0, "bass": 0.6, "keys": 1.7, "lead": 1.8, "fx": 1.0}


def mixdown(s: seq.Song, kick_hits: list[float], *, duck: float = 0.55, keys_verb: float = 0.3,
            lead_verb: float = 0.4, lead_delay: bool = True, master_lp: float | None = None,
            bus_gain: dict[str, float] | None = None, room: str = "store") -> np.ndarray:
    """Bus processing + sidechain duck from the kick + glue compression, folded into a seamless loop."""
    g = BUS_GAIN if bus_gain is None else bus_gain
    n = s.loop_samples + nsamp(s.tail_s)
    duck_g = fx.duck_curve(n, kick_hits, duck, 0.16)[:, None] if kick_hits else np.ones((n, 1))
    out = np.zeros((n, 2))
    if "drums" in s.buses:
        d = s.buses["drums"]
        d = fx.compress(d, -14, 3.0, 0.004, 0.09, 2.0)
        out += fx.reverb(d, room, 0.08, tail=False)[:n] * g["drums"]
    if "perc" in s.buses:
        out += fx.reverb(s.buses["perc"], room, 0.15, tail=False)[:n] * g["perc"]
    if "bass" in s.buses:
        b = filters.hp(s.buses["bass"], 30)
        out += b * duck_g * g["bass"]
    if "keys" in s.buses:
        k = filters.hp(s.buses["keys"], 180)
        k = filters.peak(k, 900, 2.0, 0.8)
        out += fx.reverb(k, "hall", keys_verb, tail=False)[:n] * duck_g * g["keys"]
    if "lead" in s.buses:
        ld = filters.hp(s.buses["lead"], 300)
        if lead_delay:
            dl = fx.delay(ld, s.beat_s * 0.75, 0.38, 0.28, 4500)[:n]
            ld = np.stack([dl[:, 0], fx.delay(ld[:, 1], s.beat_s * 0.5, 0.3, 0.22, 4500)[:n]], axis=1)
        out += fx.reverb(ld, "hall", lead_verb, tail=False)[:n] * (0.5 + 0.5 * duck_g) * g["lead"]
    if "fx" in s.buses:
        out += fx.reverb(s.buses["fx"], "hall", 0.35, tail=False)[:n] * g["fx"]
    if master_lp:
        out = filters.lp(out, master_lp, 0.6)
    out = fx.compress(out, -12, 2.0, 0.01, 0.2)
    return wrap_loop(out, s.loop_samples)
