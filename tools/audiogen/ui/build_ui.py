#!/usr/bin/env python3
"""CAPERWORKS UI sound cues (D-090, contracts/audio_cues.md v1.5). Owner: ENV B.

Renders the menu / HUD / payday UI cues with ENV C's procedural synth core (tools/audiogen/synth,
imported read-only), normalises them like every other SFX (style guide §9: -18 LUFS short-term,
true peak <= -1 dBTP), encodes OGG Vorbis byte-deterministically and merges their AudioCueDef
entries (UI bus, 2D) into game/world/audio/cues.tres without touching any other entry.

usage: python3 tools/audiogen/ui/build_ui.py [--only <name|cue.id>] [--registry-only] [--check-determinism]

* Outputs: game/assets/audio/sfx/ui/<name>/sfx_<name>.ogg + SOURCE.txt per folder.
* Seeds: zlib.crc32("cue.<name>#0") (same rule as tools/audiogen/build.py).
* ENV C's `build.py` rewrites cues.tres from its own CUES table; run this script afterwards
  (`--registry-only` is enough) to merge the UI entries back. The merge is idempotent.
* No samples, no recordings, no third-party audio: every sound below is oscillators + noise.

Niches (all dry, all short, all 2D on the UI bus):
  ui_focus            3-6 kHz paper tick, 30 ms (the quietest, most frequent sound)
  ui_confirm          brass "clack": inharmonic metal modes 1.9-5.1 kHz over a 190 Hz knock, 80 ms
  ui_back             the confirm's lower, shorter sibling: 900 Hz wood tick, 45 ms
  ui_primary          clack + two rising brass tones (A5 -> E6, a fifth), 260 ms
  ui_error            muted buzz: detuned 110 Hz square pair through an 800 Hz low-pass, 170 ms
  ui_tab              paper slide: pink noise band sweeping 1.8 -> 5 kHz, then a soft tick, 110 ms
  hud_objective_done  soft marimba-ish rising major third G5 -> B5, 600 ms (corpsman_heal owns the
                      bright fifth above 1.3 kHz; this one is lower and woodier)
  hud_hint            very soft sine blip 1.1 -> 1.25 kHz, 70 ms
  payday_total        register "cha-chunk": drawer-bell ding + metal rattle, then a 95 Hz drawer thud
                      with a latch click, 650 ms
  card_flip           card flip: a snap of 3 kHz noise then a papery slap with a 320 Hz body, 120 ms
  hud_hit             hit marker: dry 2.5-6 kHz "tk" with a 4.4 kHz click mode and a tiny 700 Hz body,
                      35 ms (fires many times a second, so it is the quietest gameplay cue)
  hud_headshot        the hit tick plus a bright pitched "tink": 3.5 / 7.8 kHz ring, 80 ms
  hud_kill            kill confirm "thock": 280 Hz knock with a downward pitch drop, a 1.4 kHz wood
                      click and a short 560 Hz tonal tail, 120 ms
  hud_heartbeat       one low-health beat "lub-dub": two felt thumps (58 / 52 Hz with 120 Hz body),
                      the second softer, 210 ms apart, 450 ms (played once per pulse, never looped)
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from collections.abc import Callable

import numpy as np

HERE = Path(__file__).resolve().parent
AUDIOGEN = HERE.parent
REPO = AUDIOGEN.parent.parent
sys.path.insert(0, str(AUDIOGEN))

from synth import env, filters, loudness, noise, osc, wavio  # noqa: E402
from synth.core import SR, nsamp, place, rng_for, seed_for, tvec  # noqa: E402

SFX_DIR = Path("game/assets/audio/sfx/ui")
CUE_TRES = Path("game/world/audio/cues.tres")
RES_PREFIX = "res://assets/audio/sfx/ui"
LUFS = -18.0
CEILING = -1.0
LIMIT_DB = 12.0
QUALITY = wavio.OGG_QUALITY["sfx"]


@dataclass(frozen=True)
class UiCue:
    name: str
    fn: Callable[[np.random.Generator], np.ndarray]
    volume_db: float
    cooldown_s: float = 0.03
    pitch_jitter: float = 0.0

    @property
    def cue_id(self) -> str:
        return "cue." + self.name

    @property
    def seed_key(self) -> str:
        return f"{self.cue_id}#0"

    @property
    def file(self) -> str:
        return f"sfx_{self.name}.ogg"


# ============================================================ helpers


def _modes(rng: np.random.Generator, freqs: tuple[float, ...], amps: tuple[float, ...], t60: float,
           dur: float) -> np.ndarray:
    """Bank of damped sines with a seeded +-1.5 % detune and random phase (metal / wood modes)."""
    t = tvec(dur)
    out = np.zeros_like(t)
    for f, a in zip(freqs, amps):
        ff = f * rng.uniform(0.985, 1.015)
        ph = rng.uniform(0, 2 * np.pi)
        ring = t60 * rng.uniform(0.8, 1.2)
        out += a * np.sin(2 * np.pi * ff * t + ph) * np.exp(-6.9 * t / ring)
    return out * np.minimum(t / 0.0004, 1.0)


def _tick(rng: np.random.Generator, dur: float, lo: float, hi: float, t60: float) -> np.ndarray:
    """Band-limited noise transient (paper / wood tick)."""
    x = filters.hp(filters.lp(noise.white(dur, rng), hi), lo)
    return x * env.exp_decay(dur, t60, 0.0003)


def _tone(freq: float, dur: float, t60: float, attack: float = 0.002, bright: float = 0.25) -> np.ndarray:
    """Soft brass-ish tone: sine + a little 2nd/3rd harmonic, exponential decay."""
    y = osc.sine(freq, dur) + bright * osc.sine(2 * freq, dur, 0.3) + bright * 0.4 * osc.sine(3 * freq, dur, 0.7)
    return y * env.exp_decay(dur, t60, attack)


def _fade_tail(x: np.ndarray, ms: float = 4.0) -> np.ndarray:
    k = min(x.shape[0], nsamp(ms / 1000.0))
    x = x.copy()
    x[-k:] *= np.linspace(1.0, 0.0, k)
    return x


# ============================================================ recipes


def ui_focus(rng: np.random.Generator) -> np.ndarray:
    """Soft paper tick, 30 ms: 3-6 kHz noise flick plus a faint 2.4 kHz damped sine."""
    dur = 0.03
    y = _tick(rng, dur, 3000.0, 6500.0, 0.012) * 0.7
    y += osc.sine(2400.0, dur) * env.exp_decay(dur, 0.014, 0.0003) * 0.18
    return _fade_tail(y)


def ui_confirm(rng: np.random.Generator) -> np.ndarray:
    """Brass "clack", 80 ms: inharmonic metal modes (1.9 / 2.95 / 4.1 / 5.1 kHz) over a short 190 Hz
    knock and a 1 ms bright transient."""
    dur = 0.08
    metal = _modes(rng, (1880.0, 2950.0, 4120.0, 5080.0), (0.55, 0.4, 0.25, 0.15), 0.05, dur)
    t = tvec(dur)
    knock = osc.sine(190.0 * (1 + 0.5 * np.exp(-t / 0.006)), dur) * env.exp_decay(dur, 0.035, 0.0005) * 0.6
    y = metal + knock + _tick(rng, dur, 2500.0, 9000.0, 0.006) * 0.5
    return _fade_tail(y)


def ui_back(rng: np.random.Generator) -> np.ndarray:
    """Lower, shorter tick, 45 ms: a 900 Hz wood mode plus a dull 1-3 kHz transient."""
    dur = 0.045
    wood = _modes(rng, (900.0, 1530.0), (0.6, 0.2), 0.03, dur)
    y = wood + _tick(rng, dur, 1000.0, 3200.0, 0.008) * 0.45
    return _fade_tail(y)


def ui_primary(rng: np.random.Generator) -> np.ndarray:
    """Two-tone commit, 260 ms: the confirm clack, then two rising brass tones A5 -> E6 (60 ms apart)."""
    dur = 0.26
    y = np.zeros(nsamp(dur))
    place(y, ui_confirm(rng), 0, 0.7)
    place(y, _tone(880.0, 0.2, 0.16, 0.002, 0.3), nsamp(0.012), 0.45)
    place(y, _tone(1318.5, 0.19, 0.17, 0.002, 0.3), nsamp(0.07), 0.5)
    return _fade_tail(y, 10.0)


def ui_error(rng: np.random.Generator) -> np.ndarray:
    """Muted buzz, 170 ms: detuned 110 / 116.5 Hz squares through an 800 Hz low-pass, flat-topped
    envelope (no ring), so it reads as "no" without being an alarm."""
    dur = 0.17
    y = osc.square(110.0, dur) + osc.square(116.5, dur, 0.5, 0.25)
    y = filters.lp(filters.lp(y, 800.0), 1400.0)
    e = env.segments([(0.0, 0.0), (0.006, 1.0), (0.12, 0.85), (0.17, 0.0)], dur)
    return y * e * 0.5 + _tick(rng, dur, 400.0, 1500.0, 0.01) * 0.15


def ui_tab(rng: np.random.Generator) -> np.ndarray:
    """Paper slide, 110 ms: pink noise through a band-pass sweeping 1.8 -> 5 kHz, sin^2 swell, then
    a soft tick as the page lands."""
    dur = 0.11
    n = nsamp(dur)
    f = np.geomspace(1800.0, 5000.0, n)
    slide = filters.biquad_tv(noise.pink(dur, rng), "bp", f, 1.6)
    slide *= np.sin(np.linspace(0.0, np.pi, n)) ** 2
    y = slide * 0.9
    place(y, _tick(rng, 0.03, 2500.0, 6000.0, 0.01), nsamp(0.075), 0.35)
    return _fade_tail(y)


def hud_objective_done(rng: np.random.Generator) -> np.ndarray:
    """Short rising two-note chime, 600 ms: G5 -> B5 (major third), soft mallet tone (fundamental +
    4x partial, marimba-like), 110 ms apart."""
    dur = 0.6
    y = np.zeros(nsamp(dur))
    for i, f0 in enumerate((783.99, 987.77)):
        note = osc.partials([f0, f0 * 4.0, f0 * 10.0], [1.0, 0.22, 0.05], [0.16, 0.035, 0.01], 0.45, rng)
        note *= np.minimum(tvec(0.45) / 0.002, 1.0)
        place(y, note, nsamp(i * 0.11), 0.55 if i == 0 else 0.65)
    return _fade_tail(y, 20.0)


def hud_hint(rng: np.random.Generator) -> np.ndarray:
    """Very soft blip, 70 ms: sine gliding 1.1 -> 1.25 kHz with a rounded 6 ms attack."""
    dur = 0.07
    t = tvec(dur)
    f = 1100.0 + 150.0 * (1.0 - np.exp(-t / 0.015))
    y = osc.sine(f, dur) * env.exp_decay(dur, 0.06, 0.006)
    return _fade_tail(y + _tick(rng, dur, 2000.0, 4000.0, 0.005) * 0.03)


def payday_total(rng: np.random.Generator) -> np.ndarray:
    """Register "cha-chunk", 650 ms. "cha": a drawer-bell ding (2.1 kHz inharmonic bell) with a
    3-7 kHz metal rattle; "chunk" 90 ms later: a 95 Hz drawer thud, a low noise body and a latch click."""
    dur = 0.65
    y = np.zeros(nsamp(dur))
    bell = _modes(rng, (2093.0, 2093.0 * 2.76, 2093.0 * 5.40), (0.7, 0.3, 0.12), 0.45, 0.55)
    place(y, bell, 0, 0.45)
    rattle = np.zeros(nsamp(0.06))
    for k in range(4):
        place(rattle, _tick(rng, 0.012, 3000.0, 7000.0, 0.006), nsamp(k * 0.011 + rng.uniform(0, 0.003)),
              0.5 - 0.08 * k)
    place(y, rattle, 0, 0.8)
    td = 0.25
    t = tvec(td)
    thud = osc.sine(95.0 * (1 + 0.6 * np.exp(-t / 0.012)), td) * env.exp_decay(td, 0.16, 0.001)
    body = filters.lp(noise.brown(td, rng), 500.0) * env.exp_decay(td, 0.07, 0.001)
    chunk = thud + body * 0.5
    place(chunk, _modes(rng, (1650.0, 2700.0), (0.4, 0.25), 0.03, 0.04), 0, 0.6)
    place(y, chunk, nsamp(0.09), 0.9)
    return _fade_tail(y, 20.0)


def card_flip(rng: np.random.Generator) -> np.ndarray:
    """Card flip, 120 ms: a 3 kHz band-noise snap, then 35 ms later a papery slap (low-passed noise)
    with a short 320 Hz body."""
    dur = 0.12
    y = np.zeros(nsamp(dur))
    snap = filters.bp(noise.white(0.02, rng), 3000.0, 1.2) * env.exp_decay(0.02, 0.012, 0.0003)
    place(y, snap, 0, 0.6)
    sd = 0.07
    t = tvec(sd)
    slap = filters.lp(filters.hp(noise.white(sd, rng), 500.0), 4500.0) * env.exp_decay(sd, 0.03, 0.0008)
    slap += osc.sine(320.0 * (1 + 0.3 * np.exp(-t / 0.005)), sd) * env.exp_decay(sd, 0.04, 0.0008) * 0.5
    place(y, slap, nsamp(0.035), 0.9)
    return _fade_tail(y)


def hud_hit(rng: np.random.Generator) -> np.ndarray:
    """Hit-marker tick, 35 ms: a dry 2.5-6 kHz noise flick, a short 4.4 kHz click mode and a tiny
    700 Hz body so it is a "tk", not a hiss. Quiet and non-fatiguing (automatic fire)."""
    dur = 0.035
    y = _tick(rng, dur, 2500.0, 6000.0, 0.008) * 0.6
    y += _modes(rng, (4400.0, 6100.0), (0.35, 0.12), 0.012, dur)
    t = tvec(dur)
    y += osc.sine(700.0 * (1 + 0.3 * np.exp(-t / 0.003)), dur) * env.exp_decay(dur, 0.01, 0.0004) * 0.18
    return _fade_tail(y, 3.0)


def hud_headshot(rng: np.random.Generator) -> np.ndarray:
    """Headshot "tink", 80 ms: the hit tick plus a pitched metallic ring (3.5 kHz with inharmonic
    7.8 / 10.6 kHz partials, fast decay), so it reads brighter and more final than a body hit."""
    dur = 0.08
    y = np.zeros(nsamp(dur))
    place(y, _tick(rng, 0.02, 2500.0, 7000.0, 0.006), 0, 0.5)
    ring = _modes(rng, (3520.0, 7790.0, 10600.0), (0.7, 0.22, 0.08), 0.06, dur)
    place(y, ring, nsamp(0.001), 0.8)
    return _fade_tail(y, 6.0)


def hud_kill(rng: np.random.Generator) -> np.ndarray:
    """Kill confirm "thock", 120 ms: a muted 280 Hz knock with a quick downward pitch drop, a 1.4 kHz
    wood click on top and a short 560 Hz tonal tail, all low-passed so it cuts through gunfire by
    shape rather than by brightness."""
    dur = 0.12
    t = tvec(dur)
    knock = osc.sine(280.0 * (1 + 0.45 * np.exp(-t / 0.008)), dur) * env.exp_decay(dur, 0.07, 0.0006)
    body = filters.lp(noise.brown(dur, rng), 600.0) * env.exp_decay(dur, 0.025, 0.0005) * 0.6
    tail = osc.sine(560.0, dur, 0.4) * env.exp_decay(dur, 0.1, 0.004) * 0.18
    click = _modes(rng, (1400.0, 2350.0), (0.35, 0.15), 0.02, dur) + _tick(rng, dur, 1500.0, 5000.0, 0.004) * 0.3
    y = filters.lp(knock + body + tail, 2500.0) + click
    return _fade_tail(y, 8.0)


def _thump(rng: np.random.Generator, f0: float, dur: float, t60: float) -> np.ndarray:
    """Soft heart thump: a sine dropping onto f0 with a 2x-ish body partial and a low-passed brown
    noise "felt" layer; rounded 8 ms attack, nothing above ~250 Hz."""
    t = tvec(dur)
    f = f0 * (1 + 0.35 * np.exp(-t / 0.02))
    y = osc.sine(f, dur) + 0.35 * osc.sine(f * 2.1, dur, 0.5) * np.exp(-t / 0.03)
    y += filters.lp(noise.brown(dur, rng), 180.0) * 0.4
    return filters.lp(y * env.exp_decay(dur, t60, 0.008), 260.0)


def hud_heartbeat(rng: np.random.Generator) -> np.ndarray:
    """One low-health heartbeat "lub-dub", 450 ms: a 58 Hz thump, then 210 ms later a softer 52 Hz
    one. Felt more than heard; the HUD plays it once per pulse (not a loop)."""
    dur = 0.45
    y = np.zeros(nsamp(dur))
    place(y, _thump(rng, 58.0, 0.22, 0.16), 0, 1.0)
    place(y, _thump(rng, 52.0, 0.22, 0.15), nsamp(0.21), 0.65)
    return _fade_tail(y, 20.0)


# volume_db = mix level in the registry. Files are normalised to -18 LUFS, but peak limiting leaves the
# shortest clicks well under it (see the build printout), so the levels below aim at the *played*
# loudness: focus / hint / tab ~ -36..-40 LUFS, confirm / error / flip ~ -32, primary / chime ~ -29,
# payday total ~ -26 (ENV C's ui_click sits at -10 dB, payday_tick at -8 dB). Gameplay feedback:
# hit ~ -40 (ui_focus level: it repeats with automatic fire), headshot ~ -32, kill ~ -31, heartbeat
# ~ -30 (K-weighting under-reads its 50-70 Hz energy; it peaks ~ -13 dBFS in the mix).
UI_CUES: list[UiCue] = [
    UiCue("ui_focus", ui_focus, -11.0, 0.04, 0.04),
    UiCue("ui_confirm", ui_confirm, -9.0, 0.05),
    UiCue("ui_back", ui_back, -10.0, 0.05),
    UiCue("ui_primary", ui_primary, -11.0, 0.1),
    UiCue("ui_error", ui_error, -14.0, 0.15),
    UiCue("ui_tab", ui_tab, -17.0, 0.05, 0.03),
    UiCue("hud_objective_done", hud_objective_done, -10.0, 0.3),
    UiCue("hud_hint", hud_hint, -16.0, 0.5),
    UiCue("payday_total", payday_total, -7.0, 0.5),
    UiCue("card_flip", card_flip, -7.0, 0.06, 0.04),
    UiCue("hud_hit", hud_hit, -13.0, 0.04, 0.03),
    UiCue("hud_headshot", hud_headshot, -12.0, 0.05, 0.02),
    UiCue("hud_kill", hud_kill, -9.0, 0.06, 0.02),
    UiCue("hud_heartbeat", hud_heartbeat, -12.0, 0.3),
]


# ============================================================ build


def render(cue: UiCue) -> np.ndarray:
    x = cue.fn(rng_for(cue.cue_id, "0"))
    return loudness.normalize(x, LUFS, "short", CEILING, LIMIT_DB)


def encode(cue: UiCue, root: Path) -> Path:
    out = root / SFX_DIR / cue.name / cue.file
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="audiogen_ui_") as td:
        wav = Path(td) / "render.wav"
        wavio.write_wav24(wav, np.clip(render(cue), -1.0, 1.0))
        wavio.export_ogg(wav, out, QUALITY, seed_for(cue.seed_key))
    return out


def write_source(cue: UiCue, root: Path) -> None:
    lines = [
        "Generated by tools/audiogen/ui/build_ui.py: CAPERWORKS procedural synthesis (numpy/scipy,",
        "ENV C's tools/audiogen/synth core). No samples, no recordings, no third-party audio.",
        f"cue id: {cue.cue_id}",
        f"recipe: tools/audiogen/ui/build_ui.py::{cue.fn.__name__}",
        f"command: python3 tools/audiogen/ui/build_ui.py --only {cue.name}",
        f"loudness: {LUFS} LUFS (short), true peak <= {CEILING} dBTP",
        (f"encode: ffmpeg libvorbis -q:a {QUALITY} 48 kHz, -fflags +bitexact -flags +bitexact "
         "-map_metadata -1, -serial_offset = seed & 0x7fffffff"),
        "loop: false",
        "files:",
        f"  {cue.file}  seed=zlib.crc32('{cue.seed_key}')={seed_for(cue.seed_key)}",
    ]
    (root / SFX_DIR / cue.name / "SOURCE.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


_EXT_UI = re.compile(r'^\[ext_resource type="AudioStream" path="[^"]*" id="ui_[^"]*"\]$')
_SUB_UI = re.compile(r'^\[sub_resource type="Resource" id="cue_ui_[^"]*"\]$')


def merge_registry(path: Path) -> list[str]:
    """Idempotently (re)insert the UI cue entries into ENV C's generated cues.tres. Entries are
    marked by their ids (ext `ui_<name>`, sub `cue_ui_<name>`) so a re-run replaces them and every
    other line stays byte-identical. A cue id ENV C already defines itself is left alone."""
    lines = path.read_text(encoding="utf-8").split("\n")
    kept: list[str] = []
    skip = False
    for ln in lines:
        if _SUB_UI.match(ln):
            skip = True
            continue
        if skip:
            if ln == "":
                skip = False
            continue
        if _EXT_UI.match(ln):
            continue
        kept.append(ln)
    existing = set(re.findall(r'^id = &"([^"]+)"$', "\n".join(kept), re.MULTILINE))
    cues = [c for c in UI_CUES if c.cue_id not in existing]
    skipped = [c.cue_id for c in UI_CUES if c.cue_id in existing]
    last_ext = max(i for i, ln in enumerate(kept) if ln.startswith("[ext_resource"))
    ext = [f'[ext_resource type="AudioStream" path="{RES_PREFIX}/{c.name}/{c.file}" id="ui_{c.name}"]' for c in cues]
    kept[last_ext + 1:last_ext + 1] = ext
    res_idx = kept.index("[resource]")
    subs: list[str] = []
    for c in cues:
        subs += [
            f'[sub_resource type="Resource" id="cue_ui_{c.name}"]',
            'script = ExtResource("2_def")',
            f'id = &"{c.cue_id}"',
            f'streams = Array[AudioStream]([ExtResource("ui_{c.name}")])',
            f"volume_db = {float(c.volume_db)!r}",
            'bus = &"UI"',
            "positional = false",
            "max_distance = 40.0",
            f"pitch_jitter = {float(c.pitch_jitter)!r}",
            f"cooldown_s = {float(c.cooldown_s)!r}",
            "loop = false",
            "",
        ]
    kept[res_idx:res_idx] = subs
    arr_idx = next(i for i, ln in enumerate(kept) if ln.startswith("cues = Array["))
    arr = re.sub(r', SubResource\("cue_ui_[^"]*"\)', "", kept[arr_idx])
    arr = re.sub(r'\[SubResource\("cue_ui_[^"]*"\)(, )?', "[", arr)
    add = "".join(f', SubResource("cue_ui_{c.name}")' for c in cues)
    kept[arr_idx] = arr.removesuffix("])") + add + "])"
    path.write_text("\n".join(kept), encoding="utf-8")
    return skipped


def build(root: Path, only: str | None, registry_only: bool) -> list[UiCue]:
    sel = UI_CUES
    if only:
        key = only.removeprefix("cue.")
        sel = [c for c in UI_CUES if c.name == key]
        if not sel:
            raise SystemExit(f"unknown --only target {only!r}")
    if not registry_only:
        for c in sel:
            encode(c, root)
            write_source(c, root)
    for cid in merge_registry(root / CUE_TRES):
        print(f"note: {cid} is already defined by ENV C's registry; left as is")
    return sel


def _hashes(root: Path) -> dict[str, str]:
    out = {}
    for c in UI_CUES:
        for f in (root / SFX_DIR / c.name).glob("*"):
            if f.suffix != ".import":
                out[str(f.relative_to(root))] = hashlib.sha256(f.read_bytes()).hexdigest()
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only")
    ap.add_argument("--registry-only", action="store_true", help="only merge the entries into cues.tres")
    ap.add_argument("--check-determinism", action="store_true")
    a = ap.parse_args()
    built = build(REPO, a.only, a.registry_only)
    for c in built:
        x = wavio.decode(REPO / SFX_DIR / c.name / c.file)
        print(f"{c.cue_id:24s} {x.shape[0] / SR * 1000:6.0f} ms  {loudness.short_term_max(x):6.1f} LUFS  "
              f"{loudness.true_peak_db(x):5.1f} dBTP  vol {c.volume_db:+.0f} dB")
    if a.check_determinism:
        with tempfile.TemporaryDirectory(prefix="audiogen_ui_det_") as td:
            tmp = Path(td)
            (tmp / CUE_TRES).parent.mkdir(parents=True)
            (tmp / CUE_TRES).write_text((REPO / CUE_TRES).read_text(encoding="utf-8"), encoding="utf-8")
            build(tmp, None, False)
            a_h, b_h = _hashes(REPO), _hashes(tmp)
            same = (REPO / CUE_TRES).read_bytes() == (tmp / CUE_TRES).read_bytes()
            if a_h != b_h or not same:
                print("determinism check FAILED")
                return 1
            print(f"determinism check ok ({len(a_h)} files + cues.tres)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
