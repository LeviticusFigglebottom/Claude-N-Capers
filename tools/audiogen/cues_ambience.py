"""Heist ambience beds (D-117): one interior and one exterior bed per heist, named as in each heist doc's
Audio/lighting section. Like `amb_glasshouse_interior` / `amb_street_dusk`: stereo, 2D (positional = false),
Ambience bus, loop = true, "bed" loudness class (-18 LUFS integrated), seamless via `make_loop`
(rendered past the end and crossfaded over the start). Owned by map-placed CueEmitters (CuePlayer
LOOP_STOP_OWNERS "CueEmitter (map bed)"); levels sit in the registry (`volume_db`) and per emitter.

Built by tools/audiogen/build.py like every other cue (build.py appends `CUES` to cues.CUES).

Niches (each bed has its own band / rhythm so two of them can overlap at a doorway):
  amb_bank_night_interior     Nightfall Depository hall: HVAC < 400 Hz, 1 Hz hall-clock tick-tock (2.3 / 1.6 kHz),
                              120 Hz fluorescent buzz with odd harmonics. 24 s.
  amb_harbor_night            ND quay: water lapping (low-passed swells 0.2-0.6 Hz), rigging clinks (1-3 kHz pings),
                              one distant fog horn per loop (~ every 48 s), no gulls (night). 48 s.
  amb_shadow_ledger_interior  Shadow Ledger L41/L42: low HVAC, rain on the curtain wall (hiss 2-8 kHz + droplets),
                              wind pressure (40-120 Hz swells), server-fan whine near K11. 30 s.
  amb_rooftop_rain            SL roof: heavy rain (broadband + dense splashes), gusts (band-passed swells),
                              traffic far below (< 300 Hz). 30 s.
  amb_cold_store              Dockside Burn chambers: evaporator fans (blade-rate AM at 23 Hz, 400-1500 Hz),
                              compressor thump every 1.6 s (55 Hz), ice ticks, strip-curtain flutter. 24 s.
  amb_dockside_fog            DB yard / quay: water slap, one fog horn per loop (~ every 56 s), two far gulls,
                              rigging, the condenser drone (50 Hz + hiss), the crane's 100 Hz hum. 56 s.
  amb_gallery_gala            Gallery Night Great Hall (gala): string-trio pad (G minor, soft), crowd murmur
                              (formant-filtered babble 300-3000 Hz), glass clinks (3-7 kHz). 32 s.
  amb_art_store               GN Art Store: climate-plant drone (low hum + filtered air), humidifier ticks. 24 s.
  amb_uptown_night            GN exterior: light traffic on the Parade, wet-tyre hiss, wind in the median trees,
                              one far taxi horn. 36 s.
"""
from __future__ import annotations

import numpy as np

from cues import CueSpec, make_loop
from synth import env, filters, fx, noise, osc
from synth.core import SR, midi_hz, nsamp, place


# ============================================================ helpers


def _hvac(d: float, rng: np.random.Generator, cut: float = 380.0, level: float = 0.8, ch: int = 0) -> np.ndarray:
    y = filters.lp(noise.brown(d, rng), cut) * level + filters.lp(noise.pink(d, rng), 1500) * 0.08 * level
    return y * (1 + 0.12 * env.lfo(0.07 + ch * 0.01, d, phase=ch * 0.3))


def _clink(rng: np.random.Generator, f0: float, dur: float = 0.6) -> np.ndarray:
    """Small metal / glass ping: a few inharmonic partials with short decays."""
    ratios = (1.0, 2.32, 4.25, 6.63)
    return osc.partials([f0 * r for r in ratios], [1.0, 0.6, 0.35, 0.2], [0.25, 0.12, 0.07, 0.04], dur, rng)


def _horn(dur: float, f: float, rng: np.random.Generator) -> np.ndarray:
    """Distant diaphone fog horn: beating saws + sub square, low-passed, slow swell, end drop."""
    n = nsamp(dur)
    t = np.arange(n) / SR
    bend = 2 ** ((-1.0 * np.exp(-t / 0.25) - 1.0 * np.clip((t - (dur - 0.6)) / 0.6, 0, 1)) / 12)
    y = osc.saw(f * bend, dur) + osc.saw(f * 1.004 * bend, dur, 0.3) + osc.square(f * 0.5 * bend, dur) * 0.6
    y = filters.lp(filters.lp(y, 500), 700)
    return y * env.adsr(dur, 0.4, 0.4, 0.85, 0.8)


def _water(d: float, rng: np.random.Generator, ch: int, rate: float = 0.35, level: float = 0.6) -> np.ndarray:
    """Lapping water: low-passed noise under an irregular slow swell envelope plus a slap band."""
    swell = np.clip(0.5 + 0.5 * env.lfo(rate * (1 + 0.13 * ch), d, phase=0.37 * ch)
                    + 0.3 * env.lfo(rate * 2.71, d, phase=0.11 + ch * 0.2), 0, None) ** 2
    body = filters.lp(noise.brown(d, rng), 600) * 0.8
    slap = filters.bp(noise.pink(d, rng), 900, 0.7) * 0.35
    return (body + slap) * swell * level


def _gull(rng: np.random.Generator) -> np.ndarray:
    """A far gull cry: falling FM chirp ~1.6 -> 0.9 kHz, three short calls."""
    out = np.zeros(nsamp(1.6))
    for k in range(3):
        d = 0.32 - 0.04 * k
        n = nsamp(d)
        t = np.arange(n) / SR
        f = np.geomspace(1700 - 100 * k, 950, n)
        y = osc.fm(f, 2.0, 1.2 * np.exp(-t / 0.15), d) * env.adsr(d, 0.02, 0.1, 0.7, 0.1)
        place(out, filters.bp(y, 1300, 0.8), nsamp(k * 0.42))
    return out


def _car_pass(rng: np.random.Generator, n: int, d: float, wet: float = 0.0) -> np.ndarray:
    cars = np.zeros((n, 2))
    for _ in range(int(d / 4.0)):
        cd = float(rng.uniform(4.0, 7.0))
        t0 = float(rng.uniform(-2.0, d - 1.0))
        car = filters.bp(noise.pink(cd, rng), float(rng.uniform(300, 650)), 0.7)
        if wet:
            car += filters.lp(filters.hp(noise.white(cd, rng), 1800), 5000) * wet
        car *= np.exp(-((np.linspace(-1, 1, nsamp(cd))) ** 2) * 6) * float(rng.uniform(0.25, 0.7))
        side = float(rng.choice([-1.0, 1.0]))
        place(cars, fx.pan(car, np.linspace(-0.8 * side, 0.8 * side, nsamp(cd))), nsamp(t0))
    return cars


# ============================================================ Nightfall Depository


def amb_bank_night_interior(rng: np.random.Generator, v: int) -> np.ndarray:
    """Banking hall at night: HVAC, the hall clock (tick-tock every second, alternating 2.3 / 1.6 kHz,
    marble-hall reverb), fluorescent 120 Hz buzz drifting in from the basement. 24 s loop (the
    clock period divides it, so the seam keeps the beat)."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_hvac(d, rng, 360, 0.7, c) for c in range(2)], axis=1)
        buzz = osc.square(120, d, 0.5) * 0.02 + osc.sine(240, d) * 0.01 + osc.sine(360, d) * 0.008
        buzz = filters.lp(buzz, 2200) * (1 + 0.2 * env.lfo(0.9, d))
        out += fx.pan(buzz, -0.2)
        clock = np.zeros(n)
        for k in range(int(d) + 1):
            f = 2300.0 if k % 2 == 0 else 1600.0
            dur = 0.05
            tk = filters.bp(noise.white(dur, rng), f, 4.0) * env.exp_decay(dur, 0.015, 0.0003)
            tk += osc.sine(f * 0.5, dur) * env.exp_decay(dur, 0.02) * 0.3
            place(clock, tk, nsamp(float(k)), 0.35)
        out += fx.reverb(fx.pan(clock, 0.25), "hall", 0.5, tail=False)[:n]
        return out
    return make_loop(render, 24.0, 1.0)


def amb_harbor_night(rng: np.random.Generator, v: int) -> np.ndarray:
    """Harbour quay at night: lapping water, rigging clinks, one distant fog horn (two-tone diaphone,
    far: heavy low-pass + hall reverb), a faint far-city rumble. No gulls at night. 48 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_water(d, rng, c) for c in range(2)], axis=1)
        out += np.stack([filters.lp(noise.brown(d, rng), 250) for _ in range(2)], axis=1) * 0.25
        for _ in range(int(d / 2.5)):
            t0 = float(rng.uniform(0, d - 0.8))
            place(out, fx.pan(_clink(rng, float(rng.uniform(1100, 2600))), float(rng.uniform(-0.9, 0.9))),
                  nsamp(t0), float(rng.uniform(0.02, 0.06)))
        horn = np.zeros(n)
        place(horn, _horn(3.2, 98.0, rng), nsamp(14.0), 0.16)
        out += fx.reverb(fx.pan(horn, -0.4), "hall", 0.6, tail=False)[:n]
        return out
    return make_loop(render, 48.0, 2.0)


# ============================================================ Shadow Ledger


def amb_shadow_ledger_interior(rng: np.random.Generator, v: int) -> np.ndarray:
    """Tower office at night: low HVAC, rain on the curtain wall (high hiss + droplet ticks), wind
    pressure on the glass (40-120 Hz swells), server-fan whine with its 4.3 kHz tone (near K11). 30 s."""
    def render(d: float) -> np.ndarray:
        chans = []
        for c in range(2):
            hv = _hvac(d, rng, 300, 0.6, c)
            rain = filters.lp(filters.hp(noise.pink(d, rng), 2000), 8000) * 0.08
            drops = filters.bp(noise.crackle(d, rng, 60), 3000, 0.8) * 0.4
            wind = filters.biquad_tv(noise.brown(d, rng), "bp", 70 + 40 * env.lfo(0.045 + 0.01 * c, d), 0.9)
            wind *= 0.7 * (0.6 + 0.4 * env.lfo(0.06, d, phase=0.2 * c))
            chans.append(hv + rain + drops + wind)
        out = np.stack(chans, axis=1)
        fan = filters.bp(noise.white(d, rng), 900, 0.6) * 0.03 + osc.sine(4300, d) * 0.002
        out += fx.pan(fan * (1 + 0.1 * env.lfo(0.3, d)), 0.4)
        return out
    return make_loop(render, 30.0, 1.5)


def amb_rooftop_rain(rng: np.random.Generator, v: int) -> np.ndarray:
    """Roof in heavy rain: broadband rain wash + dense splashes on the membrane, gusts (band-passed
    noise swells sweeping 400-1400 Hz), traffic rumble far below. 30 s loop."""
    def render(d: float) -> np.ndarray:
        chans = []
        for c in range(2):
            wash = filters.lp(filters.hp(noise.pink(d, rng), 400), 10000) * 0.35
            splash = filters.lp(filters.hp(noise.crackle(d, rng, 1800), 1200), 6000) * 0.7
            gust_env = np.clip(env.lfo(0.08 + 0.015 * c, d, phase=0.3 * c) + 0.3 * env.lfo(0.21, d), 0, None) ** 1.5
            gust = filters.biquad_tv(noise.white(d, rng), "bp", 800 + 500 * env.lfo(0.08, d, phase=0.3 * c), 0.7)
            low = filters.lp(noise.brown(d, rng), 280) * 0.3
            chans.append(wash + splash + gust * gust_env * 0.25 + low)
        return np.stack(chans, axis=1)
    return make_loop(render, 30.0, 1.5)


# ============================================================ Dockside Burn


def amb_cold_store(rng: np.random.Generator, v: int) -> np.ndarray:
    """Cold-store chambers: evaporator fans (band noise amplitude-modulated at the 23 Hz blade rate),
    the plant-room compressor thump every 1.6 s (55 Hz knock through the wall), ice ticks, and a
    strip-curtain flutter now and then. 24 s loop (15 thump periods)."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        chans = []
        for c in range(2):
            fan = filters.bp(noise.pink(d, rng), 650 + 80 * c, 0.5) * 0.45
            fan *= 1 + 0.25 * env.lfo(23.0 + 0.4 * c, d)
            hum = osc.sine(46.0, d) * 0.06 + osc.sine(92.0, d) * 0.03
            chans.append(fan + hum + filters.lp(noise.brown(d, rng), 200) * 0.3)
        out = np.stack(chans, axis=1)
        thump = np.zeros(n)
        for k in range(int(d / 1.6) + 1):
            dur = 0.35
            th = osc.sine(55 * (1 + 0.3 * np.exp(-np.arange(nsamp(dur)) / SR / 0.03)), dur)
            th = th * env.exp_decay(dur, 0.25, 0.004) + filters.lp(noise.brown(dur, rng), 300) * env.exp_decay(dur, 0.1)
            place(thump, th, nsamp(k * 1.6), 0.35)
        out += fx.pan(thump, -0.3)
        for _ in range(int(d * 1.2)):
            t0 = float(rng.uniform(0, d - 0.1))
            tk = filters.bp(noise.white(0.03, rng), float(rng.uniform(3000, 7000)), 5.0) * env.exp_decay(0.03, 0.01)
            place(out, fx.pan(tk, float(rng.uniform(-0.9, 0.9))), nsamp(t0), float(rng.uniform(0.05, 0.15)))
        for _ in range(2):
            t0 = float(rng.uniform(1.0, d - 2.0))
            fl = filters.bp(noise.white(1.2, rng), 1400, 0.6) * (0.5 + 0.5 * env.lfo(14.0, 1.2, shape="tri"))
            fl *= env.adsr(1.2, 0.1, 0.3, 0.6, 0.5)
            place(out, fx.pan(fl, float(rng.uniform(-0.6, 0.6))), nsamp(t0), 0.12)
        return out
    return make_loop(render, 24.0, 1.0)


def amb_dockside_fog(rng: np.random.Generator, v: int) -> np.ndarray:
    """Docks in pre-dawn fog: water slapping the quay, one fog horn per loop (far, 2-tone), two far
    gulls, rigging clinks, the cold-store condenser drone (50 Hz + fan hiss) and the crane's 100 Hz
    hum. 56 s loop (the horn lands every 56 s: the doc's 40-70 s)."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([_water(d, rng, c, 0.45, 0.7) for c in range(2)], axis=1)
        cond = osc.sine(50, d) * 0.05 + osc.sine(100, d) * 0.03 + filters.bp(noise.pink(d, rng), 500, 0.5) * 0.12
        out += fx.pan(cond, 0.35)
        crane = (osc.sine(100, d) * 0.02 + osc.sine(300, d) * 0.006) * (1 + 0.3 * env.lfo(0.13, d))
        out += fx.pan(crane, -0.5)
        for _ in range(int(d / 3.5)):
            t0 = float(rng.uniform(0, d - 0.8))
            place(out, fx.pan(_clink(rng, float(rng.uniform(900, 2200))), float(rng.uniform(-0.9, 0.9))),
                  nsamp(t0), float(rng.uniform(0.02, 0.05)))
        far = np.zeros(n)
        place(far, _horn(3.6, 87.0, rng), nsamp(9.0), 0.18)
        place(far, _horn(2.4, 73.0, rng), nsamp(12.8), 0.13)
        for t0 in (25.0, 41.5):
            place(far, _gull(rng), nsamp(t0), 0.05)
        out += fx.reverb(fx.pan(filters.lp(far, 1800), 0.3), "hall", 0.65, tail=False)[:n]
        return out
    return make_loop(render, 56.0, 2.0)


# ============================================================ Gallery Night


def amb_gallery_gala(rng: np.random.Generator, v: int) -> np.ndarray:
    """Great Hall gala: a soft string-trio pad (violin / viola / cello sines with vibrato, G minor
    progression, 8 s per chord) from the dais, crowd murmur (pulse-train "voices" through gliding vowel
    formants, syllable-rate AM), glass clinks. Hall reverb. 32 s loop."""
    chords = [(43, 58, 62, 67), (39, 55, 63, 67), (36, 55, 60, 63), (38, 54, 57, 62)]

    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        trio = np.zeros(n)
        for i in range(int(np.ceil(d / 8.0))):
            seg = min(9.5, d - i * 8.0 + 1.5)
            if seg <= 0.5:
                continue
            tt = np.arange(nsamp(seg)) / SR
            y = np.zeros(nsamp(seg))
            for k, note in enumerate(chords[i % 4]):
                f = midi_hz(note) * (1 + 0.004 * np.sin(2 * np.pi * (5.2 + 0.3 * k) * tt))
                y += (osc.saw(f, seg, float(rng.random())) * 0.3 + osc.sine(f, seg) * 0.7) / (1 + 0.3 * k)
            y = filters.lp(y, 2400) * env.adsr(seg, 1.2, 0.5, 0.9, 1.5)
            place(trio, y, nsamp(i * 8.0), 0.12)
        out = fx.reverb(fx.pan(trio, -0.2), "hall", 0.45, tail=False)[:n]
        vowels = ("a", "e", "o", "uh", "i", "u")
        for c in range(6):
            dur = d
            f0 = float(rng.uniform(95, 220))
            pulses = osc.saw(f0 * (1 + 0.03 * env.lfo(float(rng.uniform(0.3, 0.8)), dur)), dur) * 0.5
            pulses += noise.white(dur, rng) * 0.2
            v0, v1 = vowels[c % 6], vowels[(c + 2) % 6]
            voice = filters.formant(pulses, v0, v1, 6.0)
            syl = np.clip(env.lfo(float(rng.uniform(3.5, 5.5)), dur, phase=float(rng.random())), 0, None)
            talk = np.clip(env.lfo(float(rng.uniform(0.08, 0.2)), dur, phase=float(rng.random())) + 0.3, 0, None)
            place(out, fx.pan(voice * syl * talk * 0.05, float(rng.uniform(-0.9, 0.9))), 0)
        out = fx.reverb(out, "hall", 0.3, tail=False)[:n]
        for _ in range(int(d / 2.2)):
            t0 = float(rng.uniform(0, d - 0.6))
            place(out, fx.pan(_clink(rng, float(rng.uniform(2800, 4200)), 0.5), float(rng.uniform(-0.8, 0.8))),
                  nsamp(t0), float(rng.uniform(0.015, 0.04)))
        return out
    return make_loop(render, 32.0, 1.5)


def amb_art_store(rng: np.random.Generator, v: int) -> np.ndarray:
    """Art store (climate-controlled racks): climate-plant drone (60 Hz + harmonics, filtered air
    rush), humidifier ticks every ~0.7 s with a faint mist hiss. 24 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        chans = []
        for c in range(2):
            air = filters.lp(filters.hp(noise.pink(d, rng), 150), 1200) * 0.2
            drone = osc.sine(60, d) * 0.05 + osc.sine(120, d) * 0.035 + osc.sine(180, d) * 0.015
            chans.append(air * (1 + 0.08 * env.lfo(0.05 + 0.02 * c, d)) + drone + _hvac(d, rng, 250, 0.4, c))
        out = np.stack(chans, axis=1)
        ticks = np.zeros(n)
        k = 0.0
        while k < d - 0.1:
            tk = filters.bp(noise.white(0.025, rng), 2600, 6.0) * env.exp_decay(0.025, 0.008)
            place(ticks, tk, nsamp(k), float(rng.uniform(0.12, 0.2)))
            k += float(rng.uniform(0.6, 0.85))
        mist = filters.hp(noise.white(d, rng), 5000) * 0.015 * (0.6 + 0.4 * env.lfo(0.2, d))
        out += fx.pan(ticks + mist, 0.3)
        return out
    return make_loop(render, 24.0, 1.0)


def amb_uptown_night(rng: np.random.Generator, v: int) -> np.ndarray:
    """Uptown street after rain: light traffic on the Parade with wet-tyre hiss, wind in the median
    trees (leafy rustle: band-passed noise with gust envelope), one far taxi horn. 36 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        out = np.stack([filters.lp(noise.brown(d, rng), 400) for _ in range(2)], axis=1) * 0.45
        out += _car_pass(rng, n, d, 0.25)
        for c in range(2):
            g = np.clip(env.lfo(0.06 + 0.01 * c, d, phase=0.4 * c) + 0.4 * env.lfo(0.17, d), 0, None) ** 1.6
            leaves = filters.lp(filters.bp(noise.white(d, rng), 2600, 0.5), 5000) * (0.4 + 0.6 * g) * 0.03
            out[:, c] += leaves + filters.biquad_tv(noise.white(d, rng), "bp", 700 + 300 * g, 0.6) * g * 0.04
        horn = np.zeros(n)
        hd = 0.5
        h = (osc.saw(415, hd) + osc.saw(520, hd)) * env.adsr(hd, 0.01, 0.05, 0.9, 0.05)
        place(horn, filters.lp(filters.bp(fx.drive(h, 2.0), 900, 0.6), 2500), nsamp(21.0), 0.15)
        place(horn, filters.lp(filters.bp(fx.drive(h, 2.0), 900, 0.6), 2500), nsamp(21.65), 0.12)
        out += fx.reverb(fx.pan(horn, 0.6), "alley", 0.6, tail=False)[:n]
        return out
    return make_loop(render, 36.0, 2.0)


# ============================================================ registry rows

# (name, fn, volume_db, heist, doc role)
_BEDS = (
    ("amb_bank_night_interior", amb_bank_night_interior, -14.0, "night_deposit", "interior"),
    ("amb_harbor_night", amb_harbor_night, -12.0, "night_deposit", "exterior"),
    ("amb_shadow_ledger_interior", amb_shadow_ledger_interior, -14.0, "shadow_ledger", "interior"),
    ("amb_rooftop_rain", amb_rooftop_rain, -12.0, "shadow_ledger", "roof"),
    ("amb_cold_store", amb_cold_store, -14.0, "dockside_burn", "interior"),
    ("amb_dockside_fog", amb_dockside_fog, -12.0, "dockside_burn", "exterior"),
    ("amb_gallery_gala", amb_gallery_gala, -14.0, "gallery_night", "interior (gala)"),
    ("amb_art_store", amb_art_store, -15.0, "gallery_night", "interior (BOH art store)"),
    ("amb_uptown_night", amb_uptown_night, -12.0, "gallery_night", "exterior"),
)

CUES: list[CueSpec] = [
    CueSpec(name, fn, bus="Ambience", positional=False, loop=True, volume_db=vol, norm="bed",
            note=f"D-117 {heist} {role} bed (CueEmitter-owned map loop)")
    for name, fn, vol, heist, role in _BEDS
]
