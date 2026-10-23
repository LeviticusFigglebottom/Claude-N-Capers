"""Crew sentry gun cues (D-157; B's rows cue.sentry_*, b-content ba2fc327). Built by tools/audiogen/build.py (it
appends `CUES` to the cue table; the rows themselves are B's in cues.tres).

A small tripod autogun on a brushless motor and a solenoid trigger: light, electric and quick, so it never reads as
the police roof turret (assault_turret_*: a heavy hatch clank, a saw servo rising 220-600 Hz, 2.4 kHz chirps, a big
pop with a pitch-down servo).
  sentry_fire       one shot of the burst (4 variations): a carbine-weight report (170 Hz punch, 1.25 kHz bark, short
                    alley tail) with the solenoid tick (6-8 kHz) and a 30 ms brushless whine blip (3.1 kHz). 0.5 s.
  sentry_empty      out of ammo: the solenoid clicking on nothing (3 ticks) and a falling two-tone bleep
                    (1.6 -> 1.1 kHz, square-ish). 0.7 s.
  sentry_mode       ammo mode toggle (standard / armour-piercing): a short brushless whir, a latch clack and a
                    rising two-note bleep (880 -> 1320 Hz). 0.55 s.
  sentry_destroyed  shot to pieces: a stuttering 120 Hz electrical buzz cut off by a capacitor pop, a fizz, the legs
                    folding (three light metal clatters). No pitch-down servo (that is the turret's). 1.6 s.
  sentry_deploy     placed: the three legs snap open (clicks at three pitches), the brushless motor spins up with its
                    3-phase flutter (700 -> 2600 Hz), then a ready double-beep (1.8 kHz). 1.3 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, _shot, click, thud
from synth import env, filters, fx, noise, osc
from synth.core import SR, fade, nsamp, place, tvec


def _bleep(f: float, dur: float, level: float) -> np.ndarray:
    """A small square-ish electronic bleep (odd harmonics, soft edges)."""
    y = osc.sine(f, dur) + osc.sine(3 * f, dur) * 0.25 + osc.sine(5 * f, dur) * 0.08
    return y * env.adsr(dur, 0.004, 0.02, 0.8, 0.02) * level


def _brushless(f0: float, f1: float, dur: float) -> np.ndarray:
    """A brushless motor whine gliding f0 -> f1, with the 3-phase flutter (AM at a sixth of the pitch)."""
    t = tvec(dur)
    f = f0 + (f1 - f0) * np.clip(t / dur, 0, 1) ** 0.7
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * (0.75 + 0.25 * np.sin(ph / 6.0)) + np.sin(2 * ph) * 0.2


def sentry_fire(rng: np.random.Generator, v: int) -> np.ndarray:
    """One shot of the sentry's burst (see the module docstring). 0.5 s."""
    y = _shot(rng, body_hz=170, sub=0.5, crack=1.5, dur=0.5, room="alley", wet=0.16, bark_hz=1250,
              bark_t=0.06, body_t=0.12, sub_t=0.15, mech=0.0)
    place(y, click(rng, (6200.0, 7900.0), 0.03, 12, 0.004, 0.45), nsamp(0.004))
    place(y, _brushless(3100, 3000, 0.03) * env.adsr(0.03, 0.003, 0.01, 0.7, 0.01) * 0.12,
          nsamp(0.03 + rng.uniform(0, 0.006)))
    return fade(y, 0, 0.12)


def sentry_empty(rng: np.random.Generator, v: int) -> np.ndarray:
    """Out of ammo: three dry solenoid ticks and a falling two-tone bleep. 0.7 s."""
    y = np.zeros(nsamp(0.7))
    for i in range(3):
        place(y, click(rng, (5600.0, 7400.0), 0.03, 12, 0.004, 0.7), nsamp(0.0 + 0.075 * i))
    place(y, _bleep(1600, 0.12, 0.35), nsamp(0.28))
    place(y, _bleep(1100, 0.2, 0.35), nsamp(0.42))
    return fx.reverb(y, "small_office", 0.08, stereo_out=False, tail=False)


def sentry_mode(rng: np.random.Generator, v: int) -> np.ndarray:
    """Ammo mode toggle: a short whir, a latch clack, a rising two-note bleep. 0.55 s."""
    y = np.zeros(nsamp(0.55))
    place(y, _brushless(900, 1500, 0.16) * env.adsr(0.16, 0.02, 0.05, 0.7, 0.05) * 0.18, 0)
    place(y, click(rng, (2100.0, 3900.0), 0.05, 9, 0.008, 0.7), nsamp(0.17))
    place(y, _bleep(880, 0.09, 0.3), nsamp(0.25))
    place(y, _bleep(1320, 0.13, 0.3), nsamp(0.36))
    return fx.reverb(y, "small_office", 0.08, stereo_out=False, tail=False)


def sentry_destroyed(rng: np.random.Generator, v: int) -> np.ndarray:
    """Shot to pieces: stuttering buzz, capacitor pop, fizz, the legs folding. 1.6 s."""
    dur = 1.6
    y = np.zeros(nsamp(dur))
    bd = 0.35
    bt = tvec(bd)
    gate = (np.sin(2 * np.pi * 23.0 * bt) > -0.2).astype(float)
    buzz = filters.bp(osc.saw(120, bd) + osc.square(240, bd, 0.5) * 0.4, 700, 0.8) * gate * 0.35
    place(y, buzz, 0)
    pd = 0.4
    place(y, (filters.hp(noise.white(pd, rng), 1500) * env.exp_decay(pd, 0.02, 0.0) * 1.4
              + thud(rng, 160, pd, 0.5) * 0.6), nsamp(bd))
    fd = 0.8
    fizz = filters.bp(noise.white(fd, rng), 5200, 1.5) * env.exp_decay(fd, 0.35, 0.0) * 0.18
    place(y, fizz, nsamp(bd + 0.02))
    for i, f in enumerate((1500.0, 1150.0, 1900.0)):
        place(y, click(rng, (f, f * 1.9), 0.12, 8, 0.02, 0.5), nsamp(0.62 + 0.13 * i + rng.uniform(0, 0.03)))
    place(y, thud(rng, 110, 0.3, 0.6) * 0.5, nsamp(1.0))
    return fade(fx.reverb(fx.drive(y, 1.5), "alley", 0.15, stereo_out=False, tail=False), 0.0, 0.15)


def sentry_deploy(rng: np.random.Generator, v: int) -> np.ndarray:
    """Placed: three leg snaps, the motor spinning up, a ready double-beep. 1.3 s."""
    dur = 1.3
    y = np.zeros(nsamp(dur))
    for i, f in enumerate((2400.0, 2900.0, 2100.0)):
        place(y, click(rng, (f, f * 1.7), 0.05, 10, 0.006, 0.8), nsamp(0.0 + 0.09 * i))
    place(y, thud(rng, 150, 0.15, 0.4) * 0.4, nsamp(0.2))
    sd = 0.6
    place(y, _brushless(700, 2600, sd) * env.adsr(sd, 0.05, 0.1, 0.8, 0.12) * 0.22, nsamp(0.32))
    for i in range(2):
        place(y, _bleep(1800, 0.07, 0.3), nsamp(1.0 + 0.12 * i))
    return fx.reverb(y, "alley", 0.12, stereo_out=False, tail=False)


# Row values match B's rows (cues.tres cue_182..186) so a rebuilt registry agrees with them.
CUES: list[CueSpec] = [
    CueSpec("sentry_fire", sentry_fire, bus="Weapons", variations=4, max_distance=80.0, pitch_jitter=0.03,
            note="D-157"),
    CueSpec("sentry_empty", sentry_empty, bus="Weapons", volume_db=-6.0, max_distance=8.0, pitch_jitter=0.03,
            note="D-157"),
    CueSpec("sentry_mode", sentry_mode, bus="World", volume_db=-4.0, max_distance=12.0, note="D-157"),
    CueSpec("sentry_destroyed", sentry_destroyed, bus="Enemies", max_distance=100.0, note="D-157"),
    CueSpec("sentry_deploy", sentry_deploy, bus="Enemies", max_distance=80.0, note="D-157"),
]
