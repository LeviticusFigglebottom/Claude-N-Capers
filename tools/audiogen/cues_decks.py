"""Perk-deck cues (D-163, decks batch 2). Built by tools/audiogen/build.py (it appends `CUES` to the cue table; the rows
are B's in cues.tres).

  smoke_bomb         Sicario's smoke bomb lands: a dull canister pop (a 150 Hz thud and a short mid crack) and the
                     discharge hiss swelling out over ~3.5 s (band noise 1.5-7 kHz, sputtering, slowly dulling),
                     then tailing off. 4.5 s.
  gas_dispenser_tag  Tag Team pairs two allies: a soft pressurised puff (low-passed noise burst), a valve tick and a
                     faint rising two-note chime (A5 -> E6, sine + 3rd harmonic) that marks the link. Quiet, 0.8 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, click, thud
from synth import env, filters, fx, noise, osc
from synth.core import fade, nsamp, place, tvec


def smoke_bomb(rng: np.random.Generator, v: int) -> np.ndarray:
    """The canister pop then the discharge hiss. 4.5 s."""
    dur = 4.5
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 150, 0.35, 0.8), 0)
    place(y, filters.bp(noise.white(0.06, rng), 2200, 1.2) * env.exp_decay(0.06, 0.02, 0.0) * 0.9, 0)
    place(y, click(rng, (1400.0, 2600.0), 0.08, 8, 0.012, 0.5), nsamp(0.01))
    hiss_t0 = 0.08
    hd = dur - hiss_t0
    ht = tvec(hd)
    body = filters.bp(noise.white(hd, rng), 3800, 0.6) + filters.bp(noise.white(hd, rng), 1600, 1.0) * 0.4
    sputter = 0.8 + 0.2 * np.sin(2 * np.pi * (11.0 + 3.0 * np.sin(2 * np.pi * 0.7 * ht)) * ht)
    shape = np.clip(ht / 0.35, 0, 1) * np.clip((hd - ht) / 1.6, 0, 1) ** 1.5
    hiss = filters.biquad_tv(body * sputter * shape, "lp", 8000 - 4500 * np.clip(ht / hd, 0, 1), 0.7)
    place(y, hiss * 0.55, nsamp(hiss_t0))
    return fade(fx.reverb(y, "alley", 0.18, stereo_out=False, tail=False), 0.0, 0.3)


def gas_dispenser_tag(rng: np.random.Generator, v: int) -> np.ndarray:
    """A soft puff, a valve tick and a faint rising chime. 0.8 s."""
    y = np.zeros(nsamp(0.8))
    pd = 0.25
    place(y, filters.lp(noise.white(pd, rng), 1800) * env.adsr(pd, 0.01, 0.08, 0.4, 0.12) * 0.6, 0)
    place(y, click(rng, (3100.0, 4700.0), 0.04, 10, 0.006, 0.4), nsamp(0.02))
    for i, f in enumerate((880.0, 1318.5)):
        d = 0.3
        tone = osc.sine(f, d) + osc.sine(3 * f, d) * 0.15
        place(y, tone * env.adsr(d, 0.01, 0.1, 0.5, 0.15) * 0.22, nsamp(0.18 + 0.14 * i))
    return fx.reverb(y, "small_office", 0.12, stereo_out=False, tail=False)


CUES: list[CueSpec] = [
    CueSpec("smoke_bomb", smoke_bomb, bus="World", max_distance=50.0, note="D-163"),
    CueSpec("gas_dispenser_tag", gas_dispenser_tag, bus="World", volume_db=-6.0, max_distance=15.0, note="D-163"),
]
