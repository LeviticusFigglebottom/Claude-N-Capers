"""Rolling Thunder cues (RT-C2): the four ambience beds of the heist doc (Audio/lighting) and the five convoy-ambush
one-shots (audio_cues v1.4 additions, QC-85). Beds are as cues_ambience.py (stereo, 2D, Ambience bus, loop, "bed"
loudness, seamless via make_loop); one-shots are mono, 3D, World bus. Built by tools/audiogen/build.py (it appends
`CUES` to the cue table).

Beds (each keeps its own band / rhythm so two can overlap at a doorway or a ramp):
  amb_skyway_street   the junction under the Skyway, 16:50: the expressway's traffic rumble overhead (deck-filtered
                      brown noise < 250 Hz with a 70-110 Hz deck resonance), expansion-joint "ba-dum" thumps every
                      3-6 s (paired 45-70 Hz thuds), wind gusts (band-passed swells 400-1400 Hz) carrying leaves and
                      grit (crackle 2.5-7 kHz gated by the gusts), distant city traffic, a bus idling at the
                      interchange (diesel firing 22 Hz, 60-300 Hz, panned left), pigeons cooing under the girder. 48 s.
  amb_underpass       the Tannery underpass at -5.0: echoing drips (1.4-3.2 kHz pings in a long tunnel reverb),
                      the fluorescent battens (100 Hz buzz with odd harmonics), low cut rumble, and one freight train
                      over the rail bridge per loop (96 s: inside the doc's 90-150 s): an 18 s pass with a < 200 Hz
                      rumble swell, bogie wheel-joint clacks (paired, rate following the speed) and intermittent
                      wheel squeal (2.6-4.2 kHz narrow tones), panned N -> S. 96 s.
  amb_diner           the Halfway Diner: the griddle (hiss 3-9 kHz + fat spits), a counter radio (tinny 350-2800 Hz
                      plucked progression + a DJ voice), cutlery and crockery clinks (2-6 kHz), soft murmur, the
                      fridge compressor hum (50 Hz). 32 s.
  amb_site            Tanner's Reach: a diesel generator (25 Hz firing on a 50 Hz hum with a rattle at 1.1 kHz),
                      scaffold clanks in the wind (tube rings 300-1800 Hz, a few per gust), wind on the hoarding,
                      distant traffic. 40 s.

One-shots (niches):
  convoy_approach     three diesel trucks closing (firing 18-30 Hz, rasp 700 Hz, swelling 0 -> full over 6 s) and the
                      two-tone Vaultline horn (driven saws on 311 Hz then 392 Hz, 0.45 s each). 3D, 200 m. 8 s.
  convoy_brake        air brakes: a short brake squeal (1.9 kHz) then the "pssshh" of the valve (broadband hiss
                      3-10 kHz, fast attack, 1.2 s decay) and a relief chuff. 3D, 80 m. 2.5 s.
  mixer_ram           the cement mixer ramming the lead truck: a 40-60 Hz body slam, crumpling sheet metal (dense
                      1-4 kHz crunch grains + plate modes), a windscreen bursting (cue.glass_break's recipe, its own
                      seed), debris tinkle. 3D, 150 m. 3 s.
  signal_click        the rigged junction controller's relay clunk: a solenoid thump (130 Hz), a hard contact
                      click (1.6-3.4 kHz), a brief 50 Hz hum swell. 3D, 25 m. 0.5 s.
  truck_doors_open    the armoured truck's rear doors: a heavy bolt drawn (steel scrape sweep + two clunks), then
                      both hinges creaking (stick-slip FM squeal 300-900 Hz) and the doors banging on their stops.
                      3D, 40 m. 2.8 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, _diesel, click, glass_break, make_loop, radio_chatter, thud
from cues_ambience import _car_pass, _clink
from cues_ostrander import _murmur, _pigeon
from synth import env, filters, fx, granular, noise, osc
from synth.core import SR, midi_hz, nsamp, place, rng_for, tvec
from synth.core import fade as _fade

# ============================================================ helpers


def _diesel_idle(d: float, rng: np.random.Generator, fire_hz: float = 22.0, level: float = 1.0) -> np.ndarray:
    """An idling diesel (mono): firing pulses at fire_hz with a slow wobble through a low body and a 700 Hz rasp."""
    t = np.arange(nsamp(d)) / SR
    f = fire_hz * (1 + 0.02 * np.sin(2 * np.pi * 0.37 * t))
    pulse = (0.5 + 0.5 * np.cos(2 * np.pi * np.cumsum(f) / SR)) ** 6
    body = filters.lp(noise.brown(d, rng), 260) * pulse * 2.0 + osc.saw(f * 2.0, d) * 0.08
    rasp = filters.bp(noise.white(d, rng), 700, 0.9) * pulse * 0.25
    return filters.lp(fx.drive(body + rasp, 1.6), 1500) * level


def _gusts(d: float, rng: np.random.Generator, rate: float = 0.06) -> np.ndarray:
    """A gust envelope (0..1), irregular, a few swells per minute."""
    g = 0.5 + 0.5 * env.lfo(rate, d, phase=float(rng.random())) * env.lfo(rate * 2.37, d, phase=float(rng.random()))
    return np.clip(g, 0, None) ** 2


def _wind(d: float, rng: np.random.Generator, gust: np.ndarray, ch: int) -> np.ndarray:
    f = 600 + 700 * gust + 120 * env.lfo(0.13 + 0.03 * ch, d)
    return filters.biquad_tv(noise.white(d, rng), "bp", f, 0.7) * (0.02 + 0.09 * gust)


def _joint_thump(rng: np.random.Generator) -> np.ndarray:
    """Tyres over an expansion joint: two low thuds 0.08-0.16 s apart (front and rear axle), deck-filtered."""
    gap = float(rng.uniform(0.08, 0.16))
    y = np.zeros(nsamp(0.9))
    for k in range(2):
        place(y, thud(rng, float(rng.uniform(45, 70)), 0.5, 0.9), nsamp(k * gap), 1.0 - 0.25 * k)
    return filters.lp(y, 300)


def _drip(rng: np.random.Generator) -> np.ndarray:
    d = 0.12
    t = np.arange(nsamp(d)) / SR
    f = float(rng.uniform(1400, 3200)) * (1 + 0.6 * np.exp(-t / 0.01))
    return osc.sine(f, d) * env.exp_decay(d, 0.04, 0.0003)


def _train_pass(rng: np.random.Generator, d: float = 18.0) -> np.ndarray:
    """A freight train over the bridge (stereo): a low rumble swell, bogie wheel-joint clacks (pairs, the rate
    following the speed curve), intermittent wheel squeal, panned north -> south."""
    n = nsamp(d)
    t = np.arange(n) / SR
    swell = np.clip(np.sin(np.pi * t / d), 0, None) ** 1.5
    rumble = filters.lp(noise.brown(d, rng), 180) * 1.6 + filters.bp(noise.pink(d, rng), 420, 0.8) * 0.25
    rumble *= swell * (1 + 0.25 * env.lfo(3.1, d))
    y = rumble.copy()
    pos = 0.6
    while pos < d - 0.6:  # one wagon every ~1.15 s (13 m wagons at ~40 km/h), two bogies each
        for off in (0.0, 0.11, 0.78, 0.89):
            k = nsamp(pos + off)
            if k < n:
                c = filters.bp(noise.white(0.06, rng), float(rng.uniform(900, 1500)), 1.5) * env.exp_decay(0.06, 0.03)
                c += thud(rng, 70.0, 0.06, 0.4) * 0.6
                place(y, c, k, 0.5 * float(swell[k]) * float(rng.uniform(0.7, 1.0)))
        pos += float(rng.uniform(1.1, 1.2))
    for _ in range(3):
        sd = float(rng.uniform(1.2, 2.6))
        st = float(rng.uniform(3.0, d - 5.0))
        tt = np.arange(nsamp(sd)) / SR
        f = float(rng.uniform(2600, 4200)) * (1 + 0.01 * np.sin(2 * np.pi * float(rng.uniform(4, 9)) * tt))
        sq = (osc.sine(f, sd) + osc.sine(f * 1.5, sd) * 0.3) * env.adsr(sd, 0.2, 0.3, 0.8, 0.4)
        sq *= 0.6 + 0.4 * np.clip(filters.lp(noise.white(sd, rng), 6.0) * 20, -1, 1)
        place(y, sq, nsamp(st), 0.05 * float(swell[nsamp(st)]))
    return fx.pan(filters.lp(y, 6000), np.linspace(-0.85, 0.85, n))


def _sizzle(d: float, rng: np.random.Generator) -> np.ndarray:
    hiss = filters.lp(filters.hp(noise.white(d, rng), 3000), 9000) * 0.08
    hiss *= 1 + 0.2 * env.lfo(0.17, d)
    spits = filters.hp(noise.crackle(d, rng, 60), 1500) * 0.5
    return hiss + spits


def _radio(d: float, rng: np.random.Generator) -> np.ndarray:
    """A small counter radio: a plucked i-VI-III-VII progression and a DJ voice, band-limited like a tiny speaker."""
    n = nsamp(d)
    y = np.zeros(n)
    beat = 60.0 / 104.0
    prog = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]
    k = 0
    while k * beat < d - 1.0:
        notes = prog[(k // 8) % len(prog)]
        note = notes[(0, 1, 2, 1)[k % 4]] + 12
        f = midi_hz(note)
        p = (osc.square(f, 0.4, 0.3) + osc.saw(f * 1.004, 0.4) * 0.5) * env.exp_decay(0.4, 0.25)
        place(y, p, nsamp(k * beat), 0.25)
        if k % 2 == 0:
            place(y, osc.sine(midi_hz(notes[0] - 12), 0.5) * env.exp_decay(0.5, 0.3), nsamp(k * beat), 0.35)
        if k % 4 == 2:
            place(y, filters.hp(noise.white(0.08, rng), 2000) * env.exp_decay(0.08, 0.05), nsamp(k * beat), 0.15)
        k += 1
    vt = float(rng.uniform(4.0, d - 8.0))
    place(y, radio_chatter(rng, 4.0, 5.5) * 0.25, nsamp(vt))
    y = filters.hp(filters.lp(y, 2800), 350)
    return fx.drive(y * 1.5, 1.4)


def _scaffold_clank(rng: np.random.Generator) -> np.ndarray:
    """A loose scaffold tube / clip knocking: low-ish pipe partials with a hard knock."""
    f0 = float(rng.uniform(300, 650))
    y = osc.partials([f0, f0 * 2.76, f0 * 5.4], [1.0, 0.55, 0.25], [0.5, 0.2, 0.08], 0.9, rng)
    y += click(rng, (1200.0, 1800.0), 0.9, 6, 0.006, 0.6)
    return y


# ============================================================ beds


def amb_skyway_street(rng: np.random.Generator, v: int) -> np.ndarray:
    """The junction under the Skyway (doc: traffic rumble overhead with expansion-joint thumps every 3-6 s, wind
    gusts with leaves and grit, distant city traffic, a bus idling, pigeons under the girder). 48 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        over = []
        for c in range(2):
            r = filters.lp(noise.brown(d, rng), 250) * 0.9
            r = filters.peak(r, 90, 6.0, 1.2)
            over.append(r * (1 + 0.2 * env.lfo(0.11 + 0.02 * c, d, phase=0.3 * c)))
        out = np.stack(over, axis=1)
        joints = np.zeros(n)
        t = float(rng.uniform(0.5, 2.0))
        while t < d - 1.0:
            place(joints, _joint_thump(rng), nsamp(t), float(rng.uniform(0.35, 0.6)))
            t += float(rng.uniform(3.0, 6.0))
        out += fx.reverb(fx.pan(joints, 0.0), "alley", 0.35, tail=False)[:n]
        out += _car_pass(rng, n, d) * 0.35
        gust = _gusts(d, rng)
        out += np.stack([_wind(d, rng, gust, c) for c in range(2)], axis=1)
        grit = np.stack([filters.lp(filters.hp(noise.crackle(d, rng, 260), 2500), 7000) for _ in range(2)], axis=1)
        out += grit * (0.05 + 0.35 * gust)[:, None]
        out += fx.pan(_diesel_idle(d, rng, 21.0, 0.12), -0.6)
        birds = np.zeros((n, 2))
        for t0 in rng.uniform(0.5, d - 2.0, 8):
            place(birds, fx.pan(_pigeon(rng), float(rng.uniform(-0.4, 0.4))), nsamp(float(t0)),
                  float(rng.uniform(0.04, 0.09)))
        out += fx.reverb(birds, "alley", 0.4, tail=False)[:n]
        return out
    return make_loop(render, 48.0, 2.0)


def amb_underpass(rng: np.random.Generator, v: int) -> np.ndarray:
    """The Tannery underpass (doc: echoing drips, the fluorescent buzz, a freight train passing over every 90-150 s:
    rumble plus wheel squeal). 96 s loop with one 18 s train pass."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([filters.lp(noise.brown(d, rng), 160) * 0.35 for _ in range(2)], axis=1)
        buzz = osc.square(100, d, 0.5) * 0.014 + osc.sine(300, d) * 0.007 + osc.sine(500, d) * 0.004
        out += fx.pan(filters.lp(buzz, 2200) * (1 + 0.12 * env.lfo(0.9, d)), -0.1)
        drips = np.zeros((n, 2))
        for t0 in rng.uniform(0.3, d - 1.0, int(d / 2.2)):
            place(drips, fx.pan(_drip(rng), float(rng.uniform(-0.7, 0.7))), nsamp(float(t0)),
                  float(rng.uniform(0.04, 0.1)))
        out += fx.reverb(drips, "hall", 0.7, tail=False)[:n]
        out += _car_pass(rng, n, d) * 0.15
        tr = fx.reverb(_train_pass(rng), "hall", 0.3, tail=False)
        place(out, tr, nsamp(float(rng.uniform(30.0, 60.0))), 0.55)
        return out
    return make_loop(render, 96.0, 2.0)


def amb_diner(rng: np.random.Generator, v: int) -> np.ndarray:
    """The Halfway Diner (doc: griddle, radio, cutlery), plus a soft murmur and the fridge hum. 32 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        hum = osc.sine(50, d) * 0.03 + osc.sine(100, d) * 0.015 + filters.lp(noise.brown(d, rng), 300) * 0.3
        out = fx.pan(hum, 0.1)
        out += fx.pan(_sizzle(d, rng), 0.45)
        out += np.stack([_murmur(d, rng, 0.08), _murmur(d, rng, 0.08)], axis=1)
        dry = fx.pan(_radio(d, rng), -0.5) * 0.35
        for t0 in rng.uniform(0.5, d - 1.0, 22):
            f0 = float(rng.uniform(2000, 4800))
            place(dry, fx.pan(_clink(rng, f0, 0.5), float(rng.uniform(-0.7, 0.7))), nsamp(float(t0)),
                  float(rng.uniform(0.05, 0.14)))
        for t0 in rng.uniform(1.0, d - 2.0, 4):  # a plate set down
            place(dry, fx.pan(thud(rng, 220, 0.15, 0.3), float(rng.uniform(-0.5, 0.5))), nsamp(float(t0)), 0.15)
        out += fx.reverb(dry, "small_office", 0.35, tail=False)[:n]
        return out
    return make_loop(render, 32.0, 1.5)


def amb_site(rng: np.random.Generator, v: int) -> np.ndarray:
    """Tanner's Reach construction site (doc: a generator, scaffold clanks in the wind). 40 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        gen = _diesel_idle(d, rng, 25.0, 0.3) + osc.sine(50, d) * 0.03 + osc.sine(150, d) * 0.01
        gen += filters.bp(noise.white(d, rng), 1100, 3.0) * 0.015 * (1 + env.lfo(25.0, d))
        out = fx.pan(gen, 0.35)
        out += np.stack([filters.lp(noise.brown(d, rng), 220) * 0.25 for _ in range(2)], axis=1)
        gust = _gusts(d, rng, 0.07)
        out += np.stack([_wind(d, rng, gust, c) for c in range(2)], axis=1) * 1.2
        clanks = np.zeros((n, 2))
        for t0 in rng.uniform(0.5, d - 1.5, 26):
            g = float(gust[nsamp(float(t0))])
            if g < 0.15 and rng.random() < 0.7:
                continue
            place(clanks, fx.pan(_scaffold_clank(rng), float(rng.uniform(-0.8, 0.0))), nsamp(float(t0)),
                  0.05 + 0.12 * g)
        out += fx.reverb(clanks, "alley", 0.35, tail=False)[:n]
        out += _car_pass(rng, n, d) * 0.2
        return out
    return make_loop(render, 40.0, 2.0)


# ============================================================ one-shots


def _air_horn(f: float, ln: float) -> np.ndarray:
    """One truck air-horn tone: three beating saws, band-limited and driven."""
    h = osc.saw(f, ln) + osc.saw(f * 1.006, ln, 0.3) + osc.saw(f * 2.0, ln, 0.6) * 0.3
    h = filters.bp(fx.drive(h * env.adsr(ln, 0.03, 0.05, 0.9, 0.06), 2.2), f * 2.2, 0.5)
    return h


def convoy_approach(rng: np.random.Generator, v: int) -> np.ndarray:
    """The Vaultline convoy closing on the junction: three diesel trucks (firing 18 -> 30 Hz, staggered) swelling up
    over 6 s with the air-blown rasp opening, then the two-tone Vaultline horn (311 Hz then 392 Hz). Niche: the only
    cue with a stacked engine swell + a two-tone horn; the escape van's honks are a single 350/440 Hz chord. 8 s."""
    dur = 8.0
    t = tvec(dur)
    y = np.zeros(nsamp(dur))
    for k, (lag, lvl) in enumerate(((0.0, 1.0), (0.7, 0.75), (1.4, 0.6))):
        rpm = (1100 + 700 * np.clip((t - lag) / 6.0, 0, 1)) * (1 + 0.03 * k)
        e = _diesel(rng, dur, rpm) * np.clip((t - lag) / 6.0, 0.03, 1.0) ** 1.8
        y += e * lvl
    y = filters.lp(y, 900) + filters.biquad_tv(y, "lp", 900 + 2200 * np.clip(t / 6.0, 0, 1), 0.7) * 0.4
    horn = np.zeros(nsamp(1.2))
    place(horn, _air_horn(311.0, 0.45), 0)
    place(horn, _air_horn(392.0, 0.5), nsamp(0.5))
    place(y, horn, nsamp(5.6), 0.45)
    y = fx.reverb(y, "alley", 0.25, stereo_out=False, tail=False)
    return _fade(y * 0.7, 0.05, 0.6)


def convoy_brake(rng: np.random.Generator, v: int) -> np.ndarray:
    """Air brakes: a short brake squeal (1.9 kHz with a 7 Hz wobble), the valve "pssshh" (3-10 kHz hiss, 1.2 s) and
    a relief chuff. Niche: broadband top-end hiss burst; the van's hiss in assault_van_arrive is buried in its
    engine. 2.5 s."""
    dur = 2.5
    y = np.zeros(nsamp(dur))
    sd = 0.6
    st = tvec(sd)
    f = 1900 * (1 + 0.012 * np.sin(2 * np.pi * 7 * st)) * (1 - 0.04 * st / sd)
    squeal = (osc.sine(f, sd) + osc.sine(f * 2.01, sd) * 0.25) * env.adsr(sd, 0.05, 0.1, 0.8, 0.15)
    place(y, squeal, 0, 0.35)
    hd = 1.6
    ht = tvec(hd)
    hiss = filters.lp(filters.hp(noise.white(hd, rng), 2800), 10000)
    hiss = filters.biquad_tv(hiss, "lp", 10000 - 5000 * np.clip(ht / hd, 0, 1), 0.7)
    hiss *= env.segments([(0, 0), (0.02, 1.0), (0.25, 0.8), (hd, 0.0)], hd)
    place(y, hiss, nsamp(0.55), 0.9)
    chuff = filters.bp(noise.pink(0.25, rng), 900, 0.8) * env.exp_decay(0.25, 0.12)
    place(y, chuff, nsamp(0.55), 0.7)
    place(y, click(rng, (1300.0, 2600.0), 0.08, 6, 0.008, 0.6), nsamp(0.5))
    y = fx.reverb(y, "alley", 0.2, stereo_out=False, tail=False)
    return _fade(y, 0.0, 0.3)


def mixer_ram(rng: np.random.Generator, v: int) -> np.ndarray:
    """The stolen cement mixer rams the lead truck: a 40-60 Hz body slam, crumpling sheet metal (dense crunch grains
    1-4 kHz over plate modes), the windscreen bursting (cue.glass_break's recipe on its own seed) and debris
    tinkling down. Niche: the heaviest compound impact (slam + crunch + glass); c4 has a sustained sub and no glass,
    door_breach is woody. 3 s."""
    dur = 3.0
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 48, 0.9, 1.4) * 1.5, 0)
    place(y, thud(rng, 72, 0.5, 0.8) * 0.8, nsamp(0.09))
    ratios = (1.0, 1.47, 2.09, 2.56, 3.37, 4.13, 5.42)
    f0 = 140.0
    plate = osc.partials([f0 * r * float(rng.uniform(0.98, 1.02)) for r in ratios],
                         [1.0, 0.8, 0.6, 0.5, 0.35, 0.3, 0.2], [0.7, 0.5, 0.4, 0.3, 0.2, 0.15, 0.1], 1.4, rng)
    place(y, plate, 0, 0.5)

    def crunch(i: int, r: np.random.Generator) -> np.ndarray:
        d = r.uniform(0.006, 0.03)
        return filters.bp(noise.white(d, r), r.uniform(900, 4200), r.uniform(1.0, 3.0)) * env.exp_decay(d, d * 0.8, 0.0)

    times = np.sort(rng.exponential(0.16, 260))
    y += granular.cloud(dur, np.clip(times, 0, dur - 0.1), crunch, rng) * 0.8
    glass = glass_break(rng_for("cue.mixer_ram", "glass"), 0)
    if glass.ndim == 2:
        glass = glass.mean(axis=1)
    place(y, glass[: nsamp(dur - 0.05)], nsamp(0.04), 0.45)
    for _ in range(9):
        place(y, _clink(rng, float(rng.uniform(1500, 3800)), 0.4), nsamp(float(rng.uniform(0.6, 2.3))),
              float(rng.uniform(0.04, 0.12)))
    y = fx.drive(y, 1.5)
    y = fx.reverb(y, "alley", 0.22, stereo_out=False, tail=False)
    return _fade(y, 0.0, 0.4)


def signal_click(rng: np.random.Generator, v: int) -> np.ndarray:
    """The junction controller's relay clunk as the rigged lights switch: a solenoid thump (130 Hz), a hard contact
    click (1.6-3.4 kHz) and the release clack, with a brief 50 Hz hum swell. Niche: a dry mid-low clunk; keycard /
    keypad cues are beeps, lockpick is high and fine. 0.5 s."""
    dur = 0.5
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 130, 0.18, 0.5) * 0.9, 0)
    place(y, click(rng, (1650.0, 2450.0, 3400.0), 0.12, 10, 0.012, 1.0), 0)
    place(y, click(rng, (1900.0, 3000.0), 0.08, 8, 0.008, 0.5), nsamp(0.045))
    hd = 0.35
    hum = (osc.sine(50, hd) + osc.sine(100, hd) * 0.5 + osc.sine(150, hd) * 0.25) * env.adsr(hd, 0.02, 0.1, 0.6, 0.15)
    place(y, hum, nsamp(0.02), 0.12)
    y = fx.reverb(y, "small_office", 0.12, stereo_out=False, tail=False)
    return _fade(y, 0.0, 0.08)


def truck_doors_open(rng: np.random.Generator, v: int) -> np.ndarray:
    """The armoured truck's rear doors: a heavy bolt drawn (a steel scrape sweeping 1.2 -> 2.4 kHz between two
    clunks), both hinges creaking (stick-slip FM squeal 300-900 Hz) and the doors banging on their stops. Niche: the
    only long creak; door_open is a light latch + swing. 2.8 s."""
    dur = 2.8
    y = np.zeros(nsamp(dur))
    place(y, thud(rng, 110, 0.25, 0.7) * 0.7, 0)
    place(y, click(rng, (900.0, 1700.0, 2600.0), 0.15, 10, 0.012, 0.9), 0)
    sd = 0.35
    st = tvec(sd)
    scrape = filters.biquad_tv(noise.white(sd, rng), "bp", 1200 + 1200 * st / sd, 3.0)
    scrape *= env.adsr(sd, 0.03, 0.1, 0.8, 0.05) * (0.7 + 0.3 * np.sin(2 * np.pi * 37 * st))
    place(y, scrape, nsamp(0.05), 0.5)
    place(y, thud(rng, 95, 0.3, 0.8) * 0.8, nsamp(0.42))
    place(y, click(rng, (1100.0, 2200.0, 3300.0), 0.15, 12, 0.014, 1.0), nsamp(0.42))
    for k, (t0, f0) in enumerate(((0.65, 420.0), (0.8, 560.0))):
        cd = 1.3
        ct = tvec(cd)
        f = f0 * (1 + 0.6 * np.clip(ct / cd, 0, 1)) * (1 + 0.05 * np.sin(2 * np.pi * 3.0 * ct))
        stick = (0.5 + 0.5 * np.cos(2 * np.pi * (22 + 10 * ct / cd) * ct)) ** 4
        creak = osc.fm(f, 1.5, 1.4 * stick, cd) * stick * env.adsr(cd, 0.08, 0.2, 0.8, 0.25)
        place(y, filters.bp(creak, 700, 0.7), nsamp(t0), 0.35 - 0.08 * k)
    for t0 in (2.05, 2.2):
        place(y, thud(rng, 85, 0.45, 0.9) * 0.9, nsamp(t0))
        place(y, click(rng, (750.0, 1350.0, 2100.0), 0.3, 12, 0.03, 0.6), nsamp(t0))
    y = fx.drive(y, 1.3)
    y = fx.reverb(y, "alley", 0.2, stereo_out=False, tail=False)
    return _fade(y, 0.0, 0.3)


# ============================================================ registry rows

_BEDS = (
    ("amb_skyway_street", amb_skyway_street, -12.0, "exterior (junction, plaza, streets under the Skyway)"),
    ("amb_underpass", amb_underpass, -12.0, "exterior (Tannery underpass and east cut, -5.0)"),
    ("amb_diner", amb_diner, -14.0, "interior (Halfway Diner)"),
    ("amb_site", amb_site, -13.0, "exterior (Tanner's Reach construction site)"),
)

CUES: list[CueSpec] = [
    CueSpec(name, fn, bus="Ambience", positional=False, loop=True, volume_db=vol, norm="bed",
            note=f"RT-C2 rolling_thunder {role} bed (CueEmitter-owned map loop)")
    for name, fn, vol, role in _BEDS
] + [
    CueSpec("convoy_approach", convoy_approach, max_distance=200.0, cooldown_s=5.0,
            note="RT-C2 audio_cues v1.4 (QC-85): convoy engines + two-tone Vaultline horn, 3D on the lead truck"),
    CueSpec("convoy_brake", convoy_brake, max_distance=80.0, pitch_jitter=0.03, cooldown_s=1.0,
            note="RT-C2 audio_cues v1.4 (QC-85): air-brake hiss, 3D on each truck as it stops"),
    CueSpec("mixer_ram", mixer_ram, max_distance=150.0,
            note="RT-C2 audio_cues v1.4 (QC-85): mixer rams the lead truck (impact, glass, metal), 3D at the hit"),
    CueSpec("signal_click", signal_click, max_distance=25.0, volume_db=-3.0, pitch_jitter=0.04, cooldown_s=0.2,
            note="RT-C2 audio_cues v1.4 (QC-85): relay clunk when the rigged signals switch, 3D at the controller"),
    CueSpec("truck_doors_open", truck_doors_open, max_distance=40.0, pitch_jitter=0.02,
            note="RT-C2 audio_cues v1.4 (QC-85): heavy bolt + hinges, 3D at the truck's rear doors"),
]
