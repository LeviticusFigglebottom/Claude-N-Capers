"""Afterhours (`afterhours`, "Velvet Rope"): the Velvet nightclub heist track. F# minor, 128 BPM grid, 4/4.

Identity: a 1928 picture house turned nightclub at 00:40. Dark violet deep house: a drawbar "house organ"
stab (sines on harmonics 1-2-3-4-6 with a key click), a breathy formant "ooh" velvet pad, a rolling offbeat
bassline (the same pattern the club's own speakers play, cues_afterhours.amb_afterhours_club_music) and a
syncopated organ hook F#5 A5 G#5 E5 | C#5 E5 (answered D5 E5 F#5 A5 G#5). Progression i - VI - iv - V
(F#m9 Dmaj7 Bm7 C#7sus4 -> C#7). No bells, no arpeggios: the organ and the pad carry the harmony.

Stealth is 32 bars of the grid (60 s) under which the sub-bass pulses run at 72 BPM (72 pulses per loop, so
the loop stays seamless): it sits under the diegetic 120 BPM club loop, ducked by the MusicDirector in the
hall. control / anticipation / assault / fade are 16 bars each on the 128 BPM bar grid; assault drives the
club bassline (CLUB_BASS) into a full four-on-the-floor assault. Mix room: "hall". Original material,
synthesized from the shared engine.
"""
from __future__ import annotations

from typing import Callable

import numpy as np

import music_engine as me
from music_engine import mixdown, part_bass, part_hits, part_kick
from synth import env, filters, fx, noise, osc, seq
from synth.core import SR, midi_hz, nsamp, place, rng_for

TRACK = "afterhours"
KEY = "F# minor"
PALETTE = "house organ stabs, formant velvet pad, rolling offbeat bass, 72 BPM sub pulses, four-on-the-floor kit"
BPM = 128.0
BEATS_PER_BAR = 4
PROG8 = ["F#m9", "F#m9", "Dmaj7", "Dmaj7", "Bm7", "Bm7", "C#7sus4", "C#7"]
# the club's own bassline (shared with the diegetic loop at 120 BPM): rolling offbeats with octave kicks
CLUB_BASS = "..x-.xx-..x-.x.x"
CLUB_OCT = "......o.......o."
HOOK = [(0.0, 78, 0.5), (0.75, 81, 0.25), (1.0, 80, 0.5), (1.5, 76, 0.75), (2.5, 73, 0.5), (3.25, 76, 0.5)]
ANSWER = [(0.0, 74, 0.5), (0.5, 76, 0.5), (1.0, 78, 0.75), (2.0, 81, 0.5), (2.75, 80, 1.0)]


def _song(bars: int, tail: float = 5.0) -> seq.Song:
    return me.song(BPM, bars, tail, BEATS_PER_BAR)


# ------------------------------------------------------------------ instruments (shared with cues_afterhours)


def organ(notes: list[int], dur: float, rng: np.random.Generator, decay: float = 0.28,
          bright: float = 1.0) -> np.ndarray:
    """Drawbar house-organ stab (mono): per note, sines on harmonics 1/2/3/4/6 (the upper ones decay
    faster), a percussive 2nd-harmonic "perc" and a key click; a hair of drive."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for note in notes:
        f = midi_hz(note)
        for h, a, d in ((1, 1.0, 1.0), (2, 0.7, 0.8), (3, 0.45 * bright, 0.55), (4, 0.3 * bright, 0.4),
                        (6, 0.15 * bright, 0.25)):
            if f * h < SR * 0.45:
                y += a * np.sin(2 * np.pi * f * h * t + float(rng.random()) * 6.28) * np.exp(-t / (decay * d))
        y += 0.35 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / 0.06)
    y /= max(1, len(notes)) ** 0.7
    k = min(n, nsamp(0.004))
    y[:k] += filters.bp(rng.standard_normal(k), 2500, 1.0) * np.linspace(0.5, 0.0, k)
    return fx.drive(y * env.adsr(dur, 0.002, 0.05, 0.9, min(0.04, dur * 0.3)) * 0.6, 1.3)


def velvet_pad(notes: list[int], dur: float, rng: np.random.Generator, vowel: str = "o", to: str = "u",
               attack: float = 1.0, release: float = 1.6) -> np.ndarray:
    """Breathy "ooh" pad (stereo): a detuned supersaw per note plus breath noise through a gliding vowel
    formant bank, a slow tremolo; returns dur + release seconds."""
    total = dur + release
    n = nsamp(total)
    lr = np.zeros((n, 2))
    for ch in range(2):
        src = np.zeros(n)
        for note in notes:
            src += osc.supersaw(midi_hz(note) * (1.0015 if ch else 0.9985), total, 3, 9.0, rng)
        src = src / max(1, len(notes)) ** 0.7 + noise.pink(total, rng) * 0.08
        v = filters.formant(src, vowel, to, 5.0) * 1.6 + filters.lp(src, 700) * 0.25
        lr[:, ch] = v * (1 + 0.12 * env.lfo(0.23 + 0.05 * ch, total))
    return lr * env.adsr(total, attack, 1.0, 0.9, release, curve=2.4)[:, None]


def sub_pulse(note: int, dur: float, rng: np.random.Generator, punch: float = 1.0) -> np.ndarray:
    """Sub-bass pulse (mono): a sine with a short pitch scoop down into the note and a soft 2nd harmonic."""
    t = np.arange(nsamp(dur)) / SR
    f = midi_hz(note) * (1 + 0.25 * punch * np.exp(-t / 0.03))
    y = osc.sine(f, dur, float(rng.random())) + 0.18 * osc.sine(f * 2, dur)
    return fx.drive(y * env.adsr(dur, 0.006, 0.12, 0.6, dur * 0.5), 1.2)


def part_organ(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, pattern: str,
               gain: float = 0.3, octave: int = 4, cutoff: float = 0.0) -> None:
    """Organ chord stabs on a 16-step pattern (the chord of each bar)."""
    for b in bars:
        st = organ(seq.chord(me.chord_at(prog, b), octave), s.beat_s * 0.42, rng)
        if cutoff:
            st = filters.lp(st, cutoff)
        for t in s.steps(pattern, b):
            s.add("keys", fx.widen(st, 9), t, gain)


def part_hook(s: seq.Song, rng: np.random.Generator, bar: int, motif: list[tuple[float, int, float]],
              gain: float = 0.3, transpose: int = 0, cutoff: float = 0.0) -> None:
    """The organ hook: each note an octave-doubled organ voice (pan drifts with the pitch)."""
    for beat, note, length in motif:
        v = organ([note + transpose, note + transpose - 12], max(0.25, length * s.beat_s), rng, 0.35, 1.2)
        if cutoff:
            v = filters.lp(v, cutoff)
        s.add("lead", v, s.t(bar, beat), gain, pan_pos=0.2 * np.cos(note))


def _pad(s: seq.Song, rng: np.random.Generator, prog: list[str], bars: range, bars_per: int, octave: int,
         gain: float, attack: float = 1.0) -> None:
    for b in bars:
        if (b - bars.start) % bars_per:
            continue
        notes = seq.chord(me.chord_at(prog, b), octave)
        s.add("keys", velvet_pad(notes, s.bar_s * bars_per * 0.97, rng, attack=attack), s.t(b), gain)


# ------------------------------------------------------------------ stems


def stem_stealth() -> np.ndarray:
    """32 bars @128 (60 s) carrying 72 sub-bass pulses at 72 BPM (every 4th accented, roots F# D B C#,
    18 pulses each), the velvet pad very soft, a dull rim on every 4th pulse and the hook's first notes as a
    muffled organ twice. Sparse: it sits under the club's own loop."""
    rng = rng_for(f"mus_{TRACK}_stealth")
    s = _song(32, 6.0)
    pulse_s = 60.0 / 72.0
    roots = [30, 26, 23, 25]   # F#1 D1 B0 C#1 (played an octave up)
    for k in range(72):
        root = roots[k // 18]
        accent = k % 4 == 0
        s.add("bass", sub_pulse(root + 12, pulse_s * (0.9 if accent else 0.55), rng, 1.0 if accent else 0.5),
              k * pulse_s, 0.75 if accent else 0.4)
        if k % 4 == 2:
            s.add("perc", filters.lp(seq.rim(rng, 1400), 2200), k * pulse_s, 0.09, 0.3)
    for i, name in enumerate(("F#m9", "Dmaj7", "Bm7", "C#7sus4")):
        s.add("keys", velvet_pad(seq.chord(name, 3), s.bar_s * 8 * 0.97, rng, "u", "o", 3.0, 2.5), s.t(i * 8), 0.3)
    for b in (6, 22):
        part_hook(s, rng, b, HOOK[:3], 0.14, -12, 1400.0)
    return mixdown(s, [], duck=0.0, keys_verb=0.45, lead_verb=0.55)


def stem_control() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_control")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.85)
    part_hits(s, "drums", lambda: seq.shaker(rng), range(16), "..x...x...x...x.", 0.12, 0.3, 0.3, rng)
    part_hits(s, "drums", lambda: seq.rim(rng, 1500), range(16), "....x.......x..x", 0.12, -0.2)
    part_bass(s, rng, PROG8, range(16), "..x...x...x...x.", 520.0, gain=0.6)
    part_organ(s, rng, PROG8, range(16), "...x..x.........", 0.18, 4, 2600.0)
    _pad(s, rng, PROG8, range(16), 2, 3, 0.26)
    part_hook(s, rng, 4, HOOK, 0.22)
    part_hook(s, rng, 12, ANSWER, 0.22)
    return mixdown(s, hits, duck=0.4)


def stem_anticipation() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_anticipation")
    s = _song(16)
    hits = part_kick(s, rng, range(8), "x.......x.......", 0.9)
    hits += part_kick(s, rng, range(8, 16), "x...x...x...x...", 1.0)
    part_hits(s, "drums", lambda: seq.clap(rng), range(8, 16), "....x.......x...", 0.28)
    part_hits(s, "drums", lambda: seq.hat(rng, True, 0.2), range(16), "..x...x...x...x.", 0.08, 0.2)
    part_bass(s, rng, PROG8, range(16), CLUB_BASS, lambda b: 300 + 70 * b, octave_up=CLUB_OCT, gain=0.58,
              gate=0.8, res=0.5)
    part_organ(s, rng, PROG8, range(4, 16), "...x..x...x.....", 0.16, 4, 1800.0)

    def roll(b: int) -> str:
        return {12: "....x.......x...", 13: "..x...x...x...x.", 14: "x.x.x.x.x.x.x.x.", 15: "xxxxxxxxxxxxxxxx"}[b]

    for b in range(12, 16):
        for i, t in enumerate(s.steps(roll(b), b)):
            s.add("drums", seq.snare(rng, 210, 0.2, 0.5), t, 0.16 + 0.05 * (b - 12) + 0.1 * (i / 16))
    _pad(s, rng, PROG8, range(16), 4, 3, 0.3, 2.0)
    s.add("fx", seq.riser(rng, s.bar_s * 8, 220, 6500), s.t(8), 0.16)
    part_hook(s, rng, 8, HOOK, 0.2, -12, 3000.0)
    return mixdown(s, hits, duck=0.45, drive=1.2)


def stem_assault() -> np.ndarray:
    """The club bassline (CLUB_BASS) driven: four-on-the-floor with a fill every 4th bar, claps, open
    offbeat hats over 16th closed hats, organ stabs, the hook three times, an impact on bar 4."""
    rng = rng_for(f"mus_{TRACK}_assault")
    s = _song(16)

    def kpat(b: int) -> str:
        return "x...x...x...x.xx" if b % 4 == 3 else "x...x...x...x..."

    hits = part_kick(s, rng, range(16), kpat, 1.0)
    part_hits(s, "drums", lambda: seq.clap(rng), range(16), "....x.......x...", 0.6)
    part_hits(s, "drums", lambda: seq.hat(rng), range(16), "xxxxxxxxxxxxxxxx", 0.09, -0.25, 0.5, rng)
    part_hits(s, "drums", lambda: seq.hat(rng, True, 0.22), range(16), "..x...x...x...x.", 0.13, 0.25)
    part_hits(s, "perc", lambda: seq.tom(rng, 140), [3, 7, 11, 15], "........x.x.x.x.", 0.22, 0.1)
    part_bass(s, rng, PROG8, range(16), CLUB_BASS, 1300.0, octave_up=CLUB_OCT, gain=0.75, gate=0.8, res=0.55)
    part_bass(s, rng, PROG8, range(8, 16), "x...x...x...x...", 220.0, gain=0.35, gate=0.5)
    part_organ(s, rng, PROG8, range(16), "...x..x...x..x..", 0.2, 4)
    _pad(s, rng, PROG8, range(16), 2, 4, 0.16, 0.4)
    for b in (4, 8, 12):
        part_hook(s, rng, b, HOOK, 0.32)
        part_hook(s, rng, b + 2, ANSWER, 0.28)
    s.add("fx", seq.riser(rng, s.bar_s * 2, 400, 9000), s.t(2), 0.13)
    s.add("fx", seq.impact(rng, 2.5), s.t(4), 0.3)
    return mixdown(s, hits, duck=0.6, drive=1.3)


def stem_fade() -> np.ndarray:
    rng = rng_for(f"mus_{TRACK}_fade")
    s = _song(16)
    hits = part_kick(s, rng, range(16), "x.......x.......", 0.75)
    part_hits(s, "drums", lambda: seq.shaker(rng), range(16), "..x...x...x...x.", 0.1, 0.2, 0.3, rng)
    part_bass(s, rng, PROG8, range(16), "..x-......x-....", 450.0, gain=0.55)
    part_organ(s, rng, PROG8, range(16), "......x.........", 0.14, 4, 1500.0)
    _pad(s, rng, PROG8, range(16), 2, 3, 0.3)
    part_hook(s, rng, 8, ANSWER, 0.16, -12, 2000.0)
    return mixdown(s, hits, duck=0.4, master_lp=4500)


def stinger_win() -> np.ndarray:
    """Out the side door: the answer on the organ climbing to a bright F# major stab over a velvet swell."""
    rng = rng_for(f"mus_{TRACK}_win")
    out = np.zeros((nsamp(5.5), 2))
    for i, note in enumerate((74, 76, 78, 81)):
        place(out, fx.pan(organ([note, note - 12], 0.4, rng, 0.3, 1.2), -0.3 + 0.2 * i), nsamp(i * 0.12), 0.3)
    place(out, fx.widen(organ(seq.chord("F#", 4) + [78 + 12], 2.6, rng, 0.9, 1.3), 9), nsamp(0.52), 0.42)
    place(out, velvet_pad(seq.chord("F#add9", 3), 2.4, rng, "o", "a", 0.3, 1.8), nsamp(0.45), 0.4)
    place(out, fx.pan(sub_pulse(30, 2.0, rng), 0), nsamp(0.52), 0.4)
    place(out, fx.pan(seq.impact(rng, 3.0), 0), nsamp(0.52), 0.22)
    return fx.reverb(out, "hall", 0.35, tail=False)


def stinger_lose() -> np.ndarray:
    """House lights up: the hook dragged down like a stopping turntable, into a low F# minor pad and a thud."""
    rng = rng_for(f"mus_{TRACK}_lose")
    out = np.zeros((nsamp(5.5), 2))
    t = 0.0
    for i, (_, note, _) in enumerate(HOOK):
        place(out, fx.pan(organ([note - i, note - 12 - i], 0.45, rng, 0.3, 1.0 - 0.1 * i), 0.3 - 0.12 * i),
              nsamp(t), 0.3)
        t += 0.13 + 0.06 * i
    place(out, velvet_pad(seq.chord("F#m", 2), 2.6, rng, "u", "u", 0.6, 1.6), nsamp(1.5), 0.42)
    place(out, fx.pan(seq.impact(rng, 2.5), 0), nsamp(1.5), 0.3)
    place(out, fx.pan(sub_pulse(30, 3.2, rng, 1.6), 0), nsamp(1.5), 0.45)
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
