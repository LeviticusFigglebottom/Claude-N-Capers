"""Shared music engine (D-117): the step-sequenced parts, the bus mixdown and the extra instruments every
heist track is built from. Each track module (music_<track>.py) holds only its parameters and stem
recipes and exposes TRACK, BPM, BEATS_PER_BAR, KEY, STEMS, STINGERS, STEM_GAIN_DB, BARS (and optionally
STEM_ALIASES: stem name -> rendered part, for a stealth-only track whose loud stems reuse a part).

The parts and mixdown were lifted verbatim from music_glasshouse.py (Golden Hour output is byte-identical).
All stems of one track share one tempo grid so MusicDirector can switch on any bar line.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

from synth import env, filters, fx, noise, osc, seq
from synth.core import SR, midi_hz, nsamp, wrap_loop


def song(bpm: float, bars: int, tail: float = 5.0, beats_per_bar: int = 4) -> seq.Song:
    return seq.Song(bpm, beats_per_bar, bars, tail)


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
               gain: float = 0.5, transpose: int = 0, bright: float = 1.0) -> None:
    for beat, note, length in motif:
        dur = max(1.2, length * s.beat_s * 3)
        s.add("lead", seq.bell(note + transpose, dur, rng, bright), s.t(bar, beat), gain,
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
            bus_gain: dict[str, float] | None = None, room: str = "hall", drum_room: str = "store",
            drive: float = 0.0) -> np.ndarray:
    """Bus processing + sidechain duck from the kick + glue compression, folded into a seamless loop.
    `room` is the keys/lead/fx reverb, `drum_room` the drums/perc one; `drive` (> 0) adds a tanh
    saturation stage on the master before the glue compressor (Golden Hour: none)."""
    g = BUS_GAIN if bus_gain is None else bus_gain
    n = s.loop_samples + nsamp(s.tail_s)
    duck_g = fx.duck_curve(n, kick_hits, duck, 0.16)[:, None] if kick_hits else np.ones((n, 1))
    out = np.zeros((n, 2))
    if "drums" in s.buses:
        d = s.buses["drums"]
        d = fx.compress(d, -14, 3.0, 0.004, 0.09, 2.0)
        out += fx.reverb(d, drum_room, 0.08, tail=False)[:n] * g["drums"]
    if "perc" in s.buses:
        out += fx.reverb(s.buses["perc"], drum_room, 0.15, tail=False)[:n] * g["perc"]
    if "bass" in s.buses:
        b = filters.hp(s.buses["bass"], 30)
        out += b * duck_g * g["bass"]
    if "keys" in s.buses:
        k = filters.hp(s.buses["keys"], 180)
        k = filters.peak(k, 900, 2.0, 0.8)
        out += fx.reverb(k, room, keys_verb, tail=False)[:n] * duck_g * g["keys"]
    if "lead" in s.buses:
        ld = filters.hp(s.buses["lead"], 300)
        if lead_delay:
            dl = fx.delay(ld, s.beat_s * 0.75, 0.38, 0.28, 4500)[:n]
            ld = np.stack([dl[:, 0], fx.delay(ld[:, 1], s.beat_s * 0.5, 0.3, 0.22, 4500)[:n]], axis=1)
        out += fx.reverb(ld, room, lead_verb, tail=False)[:n] * (0.5 + 0.5 * duck_g) * g["lead"]
    if "fx" in s.buses:
        out += fx.reverb(s.buses["fx"], room, 0.35, tail=False)[:n] * g["fx"]
    if master_lp:
        out = filters.lp(out, master_lp, 0.6)
    if drive > 0.0:
        out = fx.drive(out, drive)
    out = fx.compress(out, -12, 2.0, 0.01, 0.2)
    return wrap_loop(out, s.loop_samples)




# ------------------------------------------------------------------ D-117 instruments
# Timbres the heist tracks add on top of seq.py's kit: low brass (Nightfall Depository), glass pads and
# rain texture (Shadow Ledger), metal clangs and a fog horn (Dockside Burn), FM harpsichord, strings and
# timpani (Gallery Night), and a clock tick shared by the "ticking" motifs.


def brass(notes: list[int], dur: float, rng: np.random.Generator, cutoff: float = 1400.0, swell: float = 0.12,
          vib: float = 1.0) -> np.ndarray:
    """Low brass section (mono): saw + narrow pulse per note with a lip "scoop" into pitch, a filter
    that opens with the swell and a delayed vibrato; driven a little for the brassy edge."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for note in notes:
        f = midi_hz(note) * (1 - 0.012 * np.exp(-t / 0.05))
        f = f * (1 + 0.004 * vib * np.sin(2 * np.pi * 5.1 * t + float(rng.random()) * 6.28) * np.clip(t / 0.5, 0, 1))
        y += osc.saw(f, dur, float(rng.random())) * 0.7 + osc.square(f, dur, 0.42, float(rng.random())) * 0.25
    y /= max(1, len(notes)) ** 0.7
    fenv = cutoff * (0.3 + 0.7 * np.clip(t / max(swell, 1e-3), 0, 1)) * (1 + 0.35 * env.exp_decay(dur, 0.3))
    y = filters.biquad_tv(y, "lp", fenv, 1.1)
    return fx.drive(y * env.adsr(dur, swell, 0.25, 0.8, min(0.25, dur * 0.3)), 1.6)


def strings(notes: list[int], dur: float, rng: np.random.Generator, cutoff: float = 1600.0, attack: float = 0.6,
            release: float = 0.9, vib_hz: float = 5.3) -> np.ndarray:
    """Bowed string section (stereo): 3-voice supersaw per note with per-channel vibrato, a high-pass
    to thin the low end and a slow attack. Returns dur + release seconds."""
    total = dur + release
    n = nsamp(total)
    t = np.arange(n) / SR
    lr = np.zeros((n, 2))
    for note in notes:
        for ch in range(2):
            ph = float(rng.random()) * 6.28
            f = midi_hz(note) * (1 + 0.0035 * np.sin(2 * np.pi * (vib_hz + 0.23 * ch) * t + ph))
            lr[:, ch] += osc.supersaw(f, total, 3, 8.0 + 3.0 * ch, rng)
    lr /= max(1, len(notes)) ** 0.7
    lr = filters.hp(filters.lp(lr, cutoff, 0.7), 110)
    return lr * env.adsr(total, attack, 1.0, 0.9, release, curve=2.5)[:, None]


def spiccato(note: int, dur: float, rng: np.random.Generator, cutoff: float = 2200.0) -> np.ndarray:
    """Short bowed note (mono): two detuned saws through a fast-closing low-pass, bow-noise onset."""
    f = midi_hz(note)
    y = osc.saw(f, dur, float(rng.random())) + osc.saw(f * 1.006, dur, float(rng.random()))
    y = filters.biquad_tv(y, "lp", cutoff * (0.35 + 1.4 * env.exp_decay(dur, 0.09)), 0.9)
    y += filters.bp(noise.white(dur, rng), 2500, 1.2) * env.exp_decay(dur, 0.03) * 0.3
    return y * env.adsr(dur, 0.006, 0.08, 0.4, dur * 0.4) * 0.6


def harpsichord(note: int, dur: float, rng: np.random.Generator, bright: float = 1.0) -> np.ndarray:
    """Plucked FM "harpsichord" (mono): 1:1 and 2:3 FM pairs whose index collapses fast (the quill
    pluck), a bright saw transient and a jack click. `bright` scales the pluck (>1 = harsher)."""
    f = midi_hz(note)
    idx = 3.2 * bright * env.exp_decay(dur, 0.09)
    y = osc.fm(f, 1.0, idx, dur) * 0.5 + osc.fm(f * 2.0, 1.5, idx * 0.6, dur) * 0.22
    y += filters.hp(osc.saw(f, dur, float(rng.random())), 600) * env.exp_decay(dur, 0.05) * 0.3 * bright
    y += filters.bp(noise.white(dur, rng), 3800, 2.0) * env.exp_decay(dur, 0.006) * 0.25
    return y * env.exp_decay(dur, min(dur, 1.6), 0.0005)


def timpani(note: int, dur: float, rng: np.random.Generator) -> np.ndarray:
    """Synth kettle drum (mono): membrane modes 1 / 1.5 / 1.99 / 2.44 / 2.98 with a small pitch drop
    after the strike and a felt-mallet thump."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 + 0.035 * np.exp(-t / 0.07))
    y = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 0.45), (1.5, 0.5, 0.22), (1.99, 0.32, 0.16), (2.44, 0.2, 0.11), (2.98, 0.12, 0.08)):
        y += osc.sine(f * r, dur, float(rng.random())) * a * np.exp(-t / max(d * dur, 0.05))
    y += filters.lp(noise.brown(dur, rng), 700) * env.exp_decay(dur, 0.08) * 0.8
    return fx.drive(y * 0.6, 1.4)


def clang(rng: np.random.Generator, f0: float = 95.0, dur: float = 2.2, bright: float = 1.0) -> np.ndarray:
    """Struck shipping container / steel plate (mono): inharmonic plate modes with long low decays,
    a noisy strike and a little drive."""
    ratios = (1.0, 1.47, 2.09, 2.56, 3.37, 4.13, 5.42, 6.8)
    amps = [1.0, 0.8, 0.6, 0.5, 0.35 * bright, 0.3 * bright, 0.2 * bright, 0.12 * bright]
    decays = [dur * 0.45, dur * 0.35, dur * 0.28, dur * 0.2, dur * 0.12, 0.25, 0.15, 0.1]
    jit = [float(rng.uniform(0.985, 1.015)) for _ in ratios]
    y = osc.partials([f0 * r * j for r, j in zip(ratios, jit)], amps, decays, dur, rng)
    y += filters.bp(noise.white(dur, rng), 1800 * bright, 0.8) * env.exp_decay(dur, 0.05) * 0.8
    return fx.drive(y * 0.5, 1.8)


def foghorn(note: int, dur: float, rng: np.random.Generator, cutoff: float = 650.0) -> np.ndarray:
    """Diaphone fog horn (mono): two beating saws and a square sub that bend up into pitch, a
    resonant low-pass and a slow swell; the classic "beee-oh" drop at the end."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    bend = 2 ** ((-1.2 * np.exp(-t / 0.18) - 0.8 * np.clip((t - (dur - 0.45)) / 0.45, 0, 1)) / 12)
    f = midi_hz(note) * bend
    y = osc.saw(f, dur) + osc.saw(f * 1.0035, dur, 0.31) + osc.square(f * 0.5, dur, 0.5) * 0.6
    y = filters.resonant_lp(y, cutoff * (0.6 + 0.4 * np.clip(t / 0.4, 0, 1)), 0.3)
    return fx.drive(y * env.adsr(dur, 0.25, 0.3, 0.85, min(0.5, dur * 0.3)) * 0.5, 1.5)


def tick(rng: np.random.Generator, f0: float = 3200.0, dur: float = 0.06) -> np.ndarray:
    """Clock / timer tick (mono): a band-passed click plus a short high sine blip."""
    y = filters.bp(noise.white(dur, rng), f0, 3.0) * env.exp_decay(dur, 0.012, 0.0003)
    y += osc.sine(f0 * 0.75, dur) * env.exp_decay(dur, 0.02, 0.0005) * 0.4
    return y


def glass_pad(notes: list[int], dur: float, rng: np.random.Generator, attack: float = 1.5,
              release: float = 2.0, shimmer: float = 1.0) -> np.ndarray:
    """Cold glass-harmonica pad (stereo): soft 2:1 FM sines per note, a hair detuned between the
    channels, with a slow tremolo shimmer. Returns dur + release seconds."""
    total = dur + release
    n = nsamp(total)
    lr = np.zeros((n, 2))
    for note in notes:
        for ch in range(2):
            f = midi_hz(note) * (1 + (0.0012 if ch else -0.0012))
            v = osc.fm(f, 2.0, 0.7 * shimmer, total) * 0.6 + osc.sine(f * 3.0, total) * 0.08
            v *= 1 + 0.15 * env.lfo(0.31 + 0.07 * ch + 0.05 * float(rng.random()), total)
            lr[:, ch] += v
    lr /= max(1, len(notes)) ** 0.7
    return lr * env.adsr(total, attack, 1.0, 0.9, release, curve=2.2)[:, None]


def rain(dur: float, rng: np.random.Generator, density: float = 900.0) -> np.ndarray:
    """Rain-noise texture (stereo): high-passed pink hiss plus dense droplet crackle per channel."""
    chans = []
    for _ in range(2):
        hiss = filters.lp(filters.hp(noise.pink(dur, rng), 1500), 9000) * 0.25
        drops = filters.lp(filters.hp(noise.crackle(dur, rng, density), 2000), 7000) * 0.6
        chans.append(hiss + drops)
    return np.stack(chans, axis=1)


def part_ticks(s: seq.Song, rng: np.random.Generator, bars: range | list[int], pattern: str, gain: float = 0.2,
               f0: float = 3200.0, accent_f0: float | None = None, pan_pos: float = 0.0) -> None:
    """Clock ticks on a step pattern ('x' tick, 'X' accented tock at accent_f0)."""
    for b in bars:
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            f = (accent_f0 or f0 * 0.7) if ch == "X" else f0
            s.add("perc", tick(rng, f), s.t(b, i / 4), gain * (1.3 if ch == "X" else 1.0), pan_pos)


def part_triplets(s: seq.Song, bars: range | list[int], pattern: str, fn: Callable[[int, int], np.ndarray | None],
                  bus: str, gain: float = 1.0, pan_pos: float = 0.0) -> None:
    """A 12-per-bar (eighth-note triplet) step pattern; fn(bar, step) renders the sound (or None).
    Hits on steps 0/4/8 are a quarter-note-triplet pulse = 3/4 of the grid tempo (the slower "control"
    feel the heist docs ask for, kept on the track's single bar grid)."""
    for b in bars:
        for i, ch in enumerate(pattern):
            if ch in ".-_ ":
                continue
            snd = fn(b, i)
            if snd is not None:
                s.add(bus, snd, s.t(b, i / 3), gain, pan_pos)
