"""Afterhours ("the Velvet") cues (docs/design/heists/afterhours.md §Audio/lighting): the diegetic club loop, three
ambience beds and three one-shot / event cues. Built by tools/audiogen/build.py (it appends `CUES` to the cue table).

The club loop is WORLD audio (D-075): ClubSound's six AudioStreamPlayer3Ds play it on the Ambience bus, so it is a
mono 3D loop, not a music stem. It shares the score's instruments and bassline (music_afterhours.CLUB_BASS) so the
alarm cut (124 BPM club -> 128 BPM assault) reads as the same record driven harder.

Club music (mono, 3D, Ambience):
  amb_afterhours_club_music  124 BPM four-on-the-floor deep house in F# minor, 16 bars (30.97 s, bar-aligned seamless
                             loop): kick on every beat, offbeat open hats, claps on 2 and 4, 16th closed hats from bar
                             4, the rolling offbeat bassline, organ chord stabs, a breathy "ooh" pad and chops from
                             bar 8. Progression F#m9 F#m9 Dmaj7 Dmaj7 F#m9 F#m9 Bm7 C#7sus4.
Beds (stereo, 2D, Ambience, loop, "bed" loudness, seamless via make_loop; 124 BPM-aligned lengths so the bleed thumps
keep the beat across the seam):
  amb_afterhours_club     the hall around the speakers: crowd walla (formant babble 250-3000 Hz, 10 voices a side),
                          glass clinks (3-7 kHz pings), bass bleed (kick + bass below 110 Hz at 124 BPM), HVAC. 31 s.
  amb_afterhours_boh      back of house: cold-room fridge hum (50 Hz + harmonics), the keg compressor cycling (a
                          29 Hz motor rattle, on ~60 % of the loop, start / stop clunks), the kick drum muffled
                          through walls (< 90 Hz at 124 BPM), fluorescent buzz. 31 s.
  amb_street_wet_night    Tolley St at 00:40 after rain: tyres hissing on wet asphalt (car passes, 1.8-6 kHz spray),
                          two distant sirens (wail, low-passed, far), the queue's chatter (near walla, a laugh), a
                          faint club thump from the doors. 31 s.
Event cues (mono, 3D):
  club_power_down         ClubSound.cut(): a needle drag, the record dragging to a stop (the club groove time-warped
                          to zero), the amp's power-down whine (900 -> 50 Hz) with a relay clunk, then the crowd's gasp
                          and a falling "ohh". 4.2 s one-shot.
  crowd_stampede          the crowd fleeing at the hall doors: shouting walla, scattered screams (formant shrieks
                          1-3.5 kHz), dense running footfalls and body bumps. 12 s seamless loop (stopped by the mission
                          when the last fleeing civilian despawns).
  dj_mic_feedback         the DJ mic squeal under vo.dj.afterhours_alarm: a mic pop, then a howl at 2.6 kHz that
                          swells, jumps to 3.45 kHz and is cut by the fader. 2.2 s one-shot.
"""
from __future__ import annotations

import numpy as np

import music_afterhours as mah
import music_engine as me
from cues import CueSpec, click, make_loop
from synth import env, filters, fx, noise, osc, seq
from synth.core import SR, midi_hz, nsamp, place

CLUB_BPM = 124.0
CLUB_BARS = 16
CLUB_PROG = ["F#m9", "F#m9", "Dmaj7", "Dmaj7", "F#m9", "F#m9", "Bm7", "C#7sus4"]
BEAT_S = 60.0 / CLUB_BPM
LOOP_S = BEAT_S * 4 * CLUB_BARS   # 30.97 s: every 124 BPM bed is this long, so beat-locked layers loop cleanly

# vowel formant banks (F1, F2, F3) for the babble
_VOWELS = ((800, 1150, 2900), (400, 1700, 2600), (300, 2200, 3000), (450, 800, 2830), (325, 700, 2530),
           (600, 1040, 2250))


# ============================================================ helpers


def _voice(d: float, rng: np.random.Generator, pitch: float, rate: float, excite: float = 1.0,
           pause: float = 0.25) -> np.ndarray:
    """One unintelligible talker (mono): a glottal saw with drifting prosody, filtered through every vowel bank
    statically, then crossfaded between vowels per syllable and gated at the syllable rate with phrase pauses."""
    n = nsamp(d)
    t = np.arange(n) / SR
    f0 = pitch * (1 + 0.12 * excite * np.sin(2 * np.pi * float(rng.uniform(0.3, 0.8)) * t + float(rng.uniform(0, 6)))
                  + 0.05 * np.sin(2 * np.pi * float(rng.uniform(2.5, 4.0)) * t))
    src = osc.saw(f0, d, float(rng.random())) + 0.2 * noise.white(d, rng)
    banks = [sum(g * filters.bp(src, f, 7.0) for g, f in zip((1.0, 0.55, 0.25), v)) for v in _VOWELS]
    # syllables: random vowel per syllable, a smooth amplitude bump each, silences between phrases
    gate = np.zeros(n)
    weights = np.zeros((len(_VOWELS), n))
    pos = float(rng.uniform(0, 0.5))
    while pos < d:
        sl = float(rng.uniform(0.6, 1.4)) / rate
        a, b = nsamp(pos), min(n, nsamp(pos + sl))
        if b > a:
            gate[a:b] = np.sin(np.linspace(0, np.pi, b - a)) ** 0.7
            weights[int(rng.integers(len(_VOWELS))), a:b] = 1.0
        pos += sl + (float(rng.uniform(0.3, 1.2)) if rng.random() < pause else float(rng.uniform(0.0, 0.04)))
    weights = filters.lp(weights.T, 18.0).T
    y = sum(w * bank for w, bank in zip(weights, banks))
    return y * filters.lp(gate, 25.0)


def _walla(d: float, rng: np.random.Generator, voices: int, excite: float = 1.0, rate: float = 5.0,
           pitch: tuple[float, float] = (95.0, 230.0)) -> np.ndarray:
    """A crowd of talkers (mono), each at its own level; band-limited 250-3000 Hz like voices through a room."""
    y = np.zeros(nsamp(d))
    for _ in range(voices):
        y += _voice(d, rng, float(rng.uniform(*pitch)), rate * float(rng.uniform(0.8, 1.2)), excite) \
            * float(rng.uniform(0.4, 1.0))
    return filters.lp(filters.hp(y, 250), 3000) / max(1.0, voices ** 0.5)


def _clink(rng: np.random.Generator, f0: float, dur: float = 0.5) -> np.ndarray:
    """Glass on glass: inharmonic partials with short decays."""
    ratios = (1.0, 2.41, 3.93, 5.6)
    return osc.partials([f0 * r for r in ratios], [1.0, 0.5, 0.3, 0.15], [0.18, 0.09, 0.05, 0.03], dur, rng)


def _beat_layer(d: float, rng: np.random.Generator, cut: float, bass: bool) -> np.ndarray:
    """The club's low end heard through a wall (mono): the kick on every 124 BPM beat (and the bass root on the
    offbeats when `bass`), low-passed hard. Beat-locked so a LOOP_S-long bed keeps the pulse across its seam."""
    n = nsamp(d)
    y = np.zeros(n)
    k = seq.kick(rng, 0.8, 48.0, 0.4)
    k_beats = int(d / BEAT_S) + 1
    for i in range(k_beats):
        place(y, k, nsamp(i * BEAT_S), 1.0)
        if bass:
            name = CLUB_PROG[(i // 4) % len(CLUB_PROG)]
            place(y, osc.sine(midi_hz(seq.root_of(name, 1)), BEAT_S * 0.4)
                  * env.adsr(BEAT_S * 0.4, 0.005, 0.1, 0.7, 0.05), nsamp((i + 0.5) * BEAT_S), 0.5)
    return filters.lp(filters.lp(y, cut), cut)


def _tyre_pass(rng: np.random.Generator, n: int, d: float, every: float) -> np.ndarray:
    """Cars on wet asphalt (stereo): a low tyre roar plus a bright spray hiss (1.8-6 kHz) swelling past."""
    out = np.zeros((n, 2))
    for _ in range(int(d / every)):
        cd = float(rng.uniform(4.5, 8.0))
        t0 = float(rng.uniform(-2.0, d - 1.0))
        roar = filters.bp(noise.pink(cd, rng), float(rng.uniform(250, 500)), 0.7) * 0.6
        spray = filters.lp(filters.hp(noise.white(cd, rng), 1800), 6000) * float(rng.uniform(0.25, 0.4))
        swell = np.exp(-(np.linspace(-1, 1, nsamp(cd)) ** 2) * 5)
        car = (roar + spray * (0.6 + 0.4 * swell)) * swell * float(rng.uniform(0.3, 0.8))
        side = float(rng.choice([-1.0, 1.0]))
        place(out, fx.pan(car, np.linspace(-0.85 * side, 0.85 * side, nsamp(cd))), nsamp(t0))
    return out


def _siren(dur: float, rng: np.random.Generator, period: float) -> np.ndarray:
    """A far wail siren (mono): a square/saw pair sweeping 700-1500 Hz, band-limited and dark."""
    t = np.arange(nsamp(dur)) / SR
    f = 1100 + 400 * np.sin(2 * np.pi * t / period - np.pi / 2 + float(rng.uniform(0, 1)))
    y = osc.square(f, dur, 0.5) * 0.5 + osc.saw(f * 1.002, dur) * 0.4
    return filters.lp(filters.bp(y, 1100, 0.6), 2200) * env.adsr(dur, dur * 0.35, 0.1, 1.0, dur * 0.45)


def _heel(rng: np.random.Generator, run: bool = False) -> np.ndarray:
    """A shoe on a sticky club floor: band-passed click + body thump (heavier when running)."""
    d = 0.11
    y = filters.bp(noise.white(d, rng), float(rng.uniform(1500, 3500)), 2.5) * env.exp_decay(d, 0.015, 0.0005)
    y += filters.lp(noise.white(d, rng), 400) * env.exp_decay(d, 0.03) * (0.9 if run else 0.4)
    return y


def _scream(rng: np.random.Generator) -> np.ndarray:
    """A short scream (mono): a saw voice gliding up then falling, through an "a" -> "e"/"i" formant, driven."""
    dur = float(rng.uniform(0.6, 1.3))
    t = np.arange(nsamp(dur)) / SR
    base = float(rng.uniform(420, 820))
    f0 = base * (1 + 0.35 * np.clip(t / 0.18, 0, 1) - 0.25 * np.clip((t - dur * 0.6) / (dur * 0.4), 0, 1)) \
        * (1 + 0.02 * np.sin(2 * np.pi * float(rng.uniform(5, 8)) * t))
    src = osc.saw(f0, dur, float(rng.random())) + 0.3 * noise.white(dur, rng)
    y = filters.formant(src, "a", str(rng.choice(["e", "i"])), 6.0)
    y *= env.segments([(0, 0), (0.06, 1.0), (dur * 0.7, 0.8), (dur, 0)], dur)
    return fx.drive(y * 3.0, 2.2)


# ============================================================ club music (world audio)


def amb_afterhours_club_music(rng: np.random.Generator, v: int) -> np.ndarray:
    """The Velvet's house loop (see the module docstring). Mono, 16 bars at 124 BPM, seamless (the sequencer
    folds every tail past bar 16 back onto bar 1)."""
    s = me.song(CLUB_BPM, CLUB_BARS, 4.0)
    hits = me.part_kick(s, rng, range(CLUB_BARS), "x...x...x...x...", 1.0)
    me.part_hits(s, "drums", lambda: seq.hat(rng, True, 0.2), range(CLUB_BARS), "..x...x...x...x.", 0.14)
    me.part_hits(s, "drums", lambda: seq.clap(rng), range(CLUB_BARS), "....x.......x...", 0.45)
    me.part_hits(s, "drums", lambda: seq.hat(rng), range(4, CLUB_BARS), "x.xxx.xxx.xxx.xx", 0.07, 0.0, 0.5, rng)
    me.part_hits(s, "perc", lambda: seq.shaker(rng), range(8, CLUB_BARS), ".x.x.x.x.x.x.x.x", 0.06, 0.0, 0.4, rng)
    me.part_bass(s, rng, CLUB_PROG, range(CLUB_BARS), mah.CLUB_BASS, 750.0, octave_up=mah.CLUB_OCT, gain=0.8,
                 gate=0.8, res=0.45)
    for b in range(CLUB_BARS):
        stab = filters.lp(mah.organ(seq.chord(me.chord_at(CLUB_PROG, b), 4), s.beat_s * 0.4, rng), 3200)
        for t in s.steps("...x..x.....x..." if b % 2 else "...x..x...x.....", b):
            s.add("keys", stab, t, 0.22)
    for b in range(8, CLUB_BARS, 2):
        notes = seq.chord(me.chord_at(CLUB_PROG, b), 3)
        s.add("keys", mah.velvet_pad(notes, s.bar_s * 2 * 0.95, rng, "u", "o", 0.6, 1.0), s.t(b), 0.18)
        for beat in (1.5, 5.5):   # "ooh" chops on the offbeat
            s.add("lead", mah.velvet_pad([notes[0] + 12, notes[2] + 12], s.beat_s * 0.35, rng, "o", "a", 0.01, 0.2),
                  s.t(b, beat), 0.16)
    out = me.mixdown(s, hits, duck=0.45, keys_verb=0.12, lead_verb=0.15, lead_delay=False, room="store")
    y = out.mean(axis=1)
    y = filters.peak(y, 70.0, 3.0, 0.9)   # the PA's bass bump
    return filters.lp(y, 12000.0)


# ============================================================ beds


def amb_afterhours_club(rng: np.random.Generator, v: int) -> np.ndarray:
    """The hall: crowd walla, glass clinks, bass bleed and HVAC (see the module docstring). LOOP_S loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        chans = []
        for c in range(2):
            hvac = filters.lp(noise.brown(d, rng), 320) * 0.35 * (1 + 0.1 * env.lfo(0.07 + 0.01 * c, d, phase=c))
            chans.append(_walla(d, rng, 10, 1.1, 4.8) * 1.4 + hvac)
        out = np.stack(chans, axis=1)
        clinks = np.zeros((n, 2))
        for _ in range(int(d * 0.9)):
            t0 = float(rng.uniform(0, d - 0.6))
            g = _clink(rng, float(rng.uniform(3000, 5500))) * float(rng.uniform(0.04, 0.12))
            if rng.random() < 0.4:   # a toast: two glasses
                g2 = np.zeros(g.size + nsamp(0.06))
                place(g2, g, 0)
                place(g2, _clink(rng, float(rng.uniform(3000, 5500))) * 0.08, nsamp(0.05))
                g = g2
            place(clinks, fx.pan(g, float(rng.uniform(-0.9, 0.9))), nsamp(t0))
        out += fx.reverb(clinks, "hall", 0.35, tail=False)[:n]
        out += fx.pan(_beat_layer(d, rng, 110.0, True), 0.0) * 0.5
        return out
    return make_loop(render, LOOP_S, 1.2)


def amb_afterhours_boh(rng: np.random.Generator, v: int) -> np.ndarray:
    """Back of house: fridge hum, keg compressor, the kick through the walls, ballast buzz. LOOP_S loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        t = np.arange(n) / SR
        hum = osc.sine(50, d) * 0.4 + osc.sine(100, d) * 0.25 + osc.sine(150, d) * 0.1
        hum = hum * (1 + 0.04 * env.lfo(0.3, d)) + filters.bp(noise.pink(d, rng), 1300, 1.5) * 0.05
        # keg compressor: on from 4 s to 4 + 0.6 * LOOP_S, motor rattle + clunks at start / stop
        on0, on1 = 4.0, 4.0 + 0.6 * LOOP_S
        gate = np.clip((t - on0) / 0.4, 0, 1) * np.clip((on1 - t) / 0.6, 0, 1)
        motor = (osc.square(29.0, d, 0.4) * 0.25 + filters.bp(noise.pink(d, rng), 180, 1.2) * 0.5) \
            * (1 + 0.3 * env.lfo(29.0, d))
        keg = filters.lp(motor, 600) * gate * 0.6
        for tc in (on0, on1):
            place(keg, click(rng, (180.0, 420.0, 900.0), 0.12, 14, 0.03, 1.0), nsamp(tc), 0.8)
        buzz = filters.lp(osc.square(100, d, 0.5), 2400) * 0.02 * (1 + 0.2 * env.lfo(0.8, d))
        thump = _beat_layer(d, rng, 90.0, False) * 0.9
        left = hum * 0.9 + keg * 0.4 + buzz + thump
        right = hum * 0.6 + keg * 0.8 + buzz * 0.6 + thump
        out = np.stack([left, right], axis=1)
        return fx.reverb(out, "small_office", 0.15, tail=False)[:n]
    return make_loop(render, LOOP_S, 1.0)


def amb_street_wet_night(rng: np.random.Generator, v: int) -> np.ndarray:
    """Tolley St after rain: wet tyres, far sirens, the queue's chatter, the club through the doors. LOOP_S loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        city = np.stack([filters.lp(noise.brown(d, rng), 260) * 0.3 for _ in range(2)], axis=1)
        drips = np.zeros(n)
        for _ in range(int(d * 1.5)):
            place(drips, filters.bp(noise.white(0.03, rng), float(rng.uniform(1500, 4000)), 5.0)
                  * env.exp_decay(0.03, 0.01), nsamp(float(rng.uniform(0, d - 0.1))), float(rng.uniform(0.02, 0.06)))
        out = city + fx.pan(drips, 0.4) + _tyre_pass(rng, n, d, 5.0)
        for t0, per, p in ((3.0, 4.5, -0.6), (d * 0.55, 5.2, 0.7)):
            sd = 11.0
            if t0 + sd <= d:
                place(out, fx.reverb(fx.pan(_siren(sd, rng, per), p), "alley", 0.5, tail=False), nsamp(t0), 0.06)
        queue = np.stack([_walla(d, rng, 5, 1.0, 5.2, (100.0, 240.0)) for _ in range(2)], axis=1) * 0.9
        laugh = np.zeros(n)
        for _ in range(3):
            t0 = float(rng.uniform(1.0, d - 2.0))
            for k in range(4):
                place(laugh, _voice(0.16, rng, float(rng.uniform(230, 300)), 9.0, 1.4, 0.0), nsamp(t0 + k * 0.17),
                      0.5 - 0.08 * k)
        out += queue + fx.pan(filters.hp(laugh, 250), float(rng.uniform(-0.4, 0.4)))
        out += fx.pan(_beat_layer(d, rng, 140.0, True), 0.3) * 0.25
        return fx.reverb(out, "alley", 0.15, tail=False)[:n]
    return make_loop(render, LOOP_S, 1.2)


# ============================================================ event cues


def club_power_down(rng: np.random.Generator, v: int) -> np.ndarray:
    """The cut: needle drag, the record dragging to a stop, the amp's power-down whine and a relay clunk, then
    the crowd's gasp. Mono, 4.2 s."""
    dur = 4.2
    n = nsamp(dur)
    y = np.zeros(n)
    # one bar of the club groove, then time-warped: playback rate 1 -> 0 over 1.3 s (the platter stopping)
    s = me.song(CLUB_BPM, 1, 0.5)
    me.part_kick(s, rng, range(1), "x...x...x...x...", 1.0)
    me.part_hits(s, "drums", lambda: seq.hat(rng, True, 0.2), range(1), "..x...x...x...x.", 0.14)
    me.part_bass(s, rng, CLUB_PROG, range(1), mah.CLUB_BASS, 750.0, octave_up=mah.CLUB_OCT, gain=0.8)
    s.add("keys", mah.organ(seq.chord("F#m9", 4), s.beat_s * 0.4, rng), s.t(0, 0.75), 0.25)
    groove = s.bus("drums").mean(axis=1) + s.bus("bass").mean(axis=1) * 0.6 + s.bus("keys").mean(axis=1)
    stop = 1.3
    ts = np.arange(nsamp(stop)) / SR
    rate = (1 - ts / stop) ** 1.6
    pos = np.cumsum(rate) + nsamp(BEAT_S * 0.5)   # pick up mid-groove
    drag = np.interp(pos, np.arange(groove.size), groove) * np.linspace(1, 0.2, ts.size)
    place(y, filters.lp(drag, 6000), 0, 0.9)
    # needle drag: a scratchy band of noise + crackle sweeping down, 0.45 s
    nd = 0.45
    sweep = filters.biquad_tv(noise.white(nd, rng) + noise.crackle(nd, rng, 900) * 0.8, "bp",
                              np.geomspace(3200, 500, nsamp(nd)), 2.0)
    place(y, sweep * env.segments([(0, 0), (0.01, 1.0), (0.25, 0.6), (nd, 0)], nd), 0, 0.9)
    # amp power-down whine (transformer + tweeter), 900 -> 50 Hz over 2.2 s, and the relay clunk
    wd = 2.4
    tw = np.arange(nsamp(wd)) / SR
    fw = 50 + 850 * np.exp(-tw / 0.6)
    whine = osc.sine(fw, wd) + 0.3 * osc.sine(fw * 2.01, wd) + 0.15 * osc.square(fw * 0.5, wd, 0.5)
    place(y, whine * env.segments([(0, 0), (0.03, 0.5), (0.6, 0.35), (wd, 0)], wd), nsamp(0.08), 0.35)
    place(y, click(rng, (140.0, 380.0, 1100.0), 0.15, 16, 0.03, 1.0), nsamp(0.06), 0.9)
    place(y, filters.lp(noise.brown(0.3, rng), 200) * env.exp_decay(0.3, 0.12), nsamp(0.06), 0.6)
    # the crowd's gasp: many voices on a sharp inhaled "ah" swell, falling into an "ohh"
    gd = 2.6
    gasp = np.zeros(nsamp(gd))
    tg = np.arange(gasp.size) / SR
    for _ in range(14):
        p = float(rng.uniform(150, 360)) * (1 + 0.15 * np.exp(-tg / 0.4)) * (1 - 0.18 * np.clip(tg / gd, 0, 1))
        src = osc.saw(p, gd, float(rng.random())) * 0.5 + noise.pink(gd, rng) * 0.8   # breathy
        place(gasp, filters.formant(src, "a", "o", 5.0) * float(rng.uniform(0.5, 1.0)), nsamp(float(rng.uniform(0, 0.12))))
    gasp *= env.segments([(0, 0), (0.12, 1.0), (0.5, 0.55), (1.4, 0.4), (gd, 0)], gd)
    place(y, filters.hp(gasp, 200) / 14 ** 0.5, nsamp(0.55), 0.8)
    return fx.reverb(y, "hall", 0.28, stereo_out=False, tail=False)


def crowd_stampede(rng: np.random.Generator, v: int) -> np.ndarray:
    """The crowd fleeing at the hall doors: shouting walla, screams, running feet, bumps. Mono 12 s loop."""
    def render(d: float) -> np.ndarray:
        n = nsamp(d)
        y = _walla(d, rng, 12, 2.2, 7.0, (150.0, 330.0)) * 1.6
        for _ in range(int(d * 0.8)):
            place(y, _scream(rng) * float(rng.uniform(0.15, 0.4)), nsamp(float(rng.uniform(0, d - 1.4))))
        feet = np.zeros(n)
        for _ in range(int(d * 7.0)):
            place(feet, _heel(rng, True) * float(rng.uniform(0.3, 0.8)), nsamp(float(rng.uniform(0, d - 0.15))))
        for _ in range(int(d * 0.5)):
            place(feet, filters.lp(noise.brown(0.25, rng), 300) * env.exp_decay(0.25, 0.08), nsamp(float(rng.uniform(0, d - 0.3))),
                  float(rng.uniform(0.3, 0.6)))
        y += feet * 0.8
        return fx.reverb(y, "hall", 0.3, stereo_out=False, tail=False)[:n]
    return make_loop(render, 12.0, 0.8)


def dj_mic_feedback(rng: np.random.Generator, v: int) -> np.ndarray:
    """DJ mic squeal: a mic pop, a howl at 2.6 kHz swelling with a warble, a jump to 3.45 kHz, the fader cut.
    Mono 2.2 s."""
    dur = 2.2
    n = nsamp(dur)
    t = np.arange(n) / SR
    y = np.zeros(n)
    place(y, filters.lp(noise.brown(0.15, rng), 250) * env.exp_decay(0.15, 0.05) * 1.5, 0)
    hd = 1.55
    th = np.arange(nsamp(hd)) / SR
    f = np.where(th < 0.95, 2600.0, 3450.0) * (1 + 0.004 * np.sin(2 * np.pi * 6.5 * th))
    f = filters.lp(f, 30.0)   # a quick glide, not a step
    howl = osc.sine(f, hd) + 0.25 * osc.sine(f * 2, hd) + 0.1 * osc.sine(f * 0.5, hd)
    swell = np.clip(np.exp((th - 0.9) * 4.0), 0, 1) * (1 + 0.15 * np.sin(2 * np.pi * 3.1 * th))
    howl = fx.drive(howl * swell, 1.8) * env.segments([(0, 1), (hd - 0.03, 1), (hd, 0)], hd)
    place(y, howl, nsamp(0.12), 0.7)
    place(y, filters.bp(noise.white(dur, rng), 1500, 0.8) * 0.02 * np.clip(t / 0.2, 0, 1) * (t < 1.67), 0)
    return fx.reverb(y, "hall", 0.3, stereo_out=False, tail=False)


# ============================================================ registry rows

CUES: list[CueSpec] = [
    CueSpec("amb_afterhours_club_music", amb_afterhours_club_music, bus="Ambience", positional=True, loop=True,
            volume_db=-4.0, max_distance=30.0, norm="bed",
            note="Afterhours ClubSound loop: 124 BPM house, 16 bars, played by the hall speakers (world audio, D-075)"),
    CueSpec("amb_afterhours_club", amb_afterhours_club, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed", note="Afterhours hall bed: walla, glass, bass bleed, HVAC (CueEmitter map loop)"),
    CueSpec("amb_afterhours_boh", amb_afterhours_boh, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed", note="Afterhours back-of-house bed: fridge, keg compressor, muffled kick"),
    CueSpec("amb_street_wet_night", amb_street_wet_night, bus="Ambience", positional=False, loop=True,
            volume_db=-14.0, norm="bed", note="Afterhours exterior bed: wet tyres, far sirens, queue chatter"),
    CueSpec("club_power_down", club_power_down, bus="World", positional=True, max_distance=45.0, volume_db=-2.0,
            note="Afterhours ClubSound.cut(): needle drag, record stop, power-down whine, crowd gasp"),
    CueSpec("crowd_stampede", crowd_stampede, bus="World", positional=True, loop=True, max_distance=35.0,
            volume_db=-4.0, note="Afterhours fleeing crowd at the hall doors (loop; stops on the last despawn)"),
    CueSpec("dj_mic_feedback", dj_mic_feedback, bus="World", positional=True, max_distance=35.0, volume_db=-6.0,
            note="Afterhours DJ mic squeal under vo.dj.afterhours_alarm"),
]
