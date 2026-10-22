# tools/audiogen: procedural audio (ENV C)

Every sound and music stem in CAPERWORKS is **synthesized** here from code (numpy + scipy). There
are no samples, recordings or third-party audio anywhere in the pipeline (style guide §9).

```
python3 tools/audiogen/build.py                      # everything + metrics + spectrogram sheets
python3 tools/audiogen/build.py --only glass_break   # one cue (name or cue.id)
python3 tools/audiogen/build.py --only impact        # a cue group (all cue.impact_<surface>)
python3 tools/audiogen/build.py --only music         # every heist track: stems + stingers
python3 tools/audiogen/build.py --only mus_gallery_night  # one track (or mus_<track>_<part>)
python3 tools/audiogen/build.py --check-determinism  # build, rebuild into a temp tree, compare sha256
```

Needs Python 3 with numpy, scipy, Pillow and `ffmpeg` with libvorbis. A full build takes about
1 min on 4 cores (`--jobs N`).

## Outputs

| Path | What |
|---|---|
| `game/assets/audio/sfx/<name>/sfx_<name>[_<n>].ogg` | cue streams (variations `_1.._n`), `SOURCE.txt` per folder |
| `game/assets/audio/sfx/impact/impact_<surface>/sfx_impact_<surface>_<n>.ogg` | bullet/melee impact cues `cue.impact_<surface>` (impact_fx.md, D-105), 4 variations each |
| `game/assets/audio/music/<track>/mus_<track>_<part>.ogg` | per heist (D-117): stems `stealth control anticipation assault fade`, stingers `win lose`; Shadow Ledger renders `stealth abort` + stingers and aliases the loud stems (see `music_shadow_ledger.py`) |
| `game/world/audio/cues.tres` | `AudioCueRegistry` generated from the `CUES` table in `cues.py` |
| `game/world/audio/music/<track>/<track>.tres` | `MusicTrack` (bpm, bar length, stems, gains) for glasshouse, night_deposit, shadow_ledger, dockside_burn, gallery_night, ostrander_federal, rolling_thunder |
| `docs/levels/_audio/cue_spectrograms.png`, `music_spectrograms.png`, `cue_metrics.tsv` | listen-check substitutes |

Never hand-edit the generated `.tres`; change `cues.py` / `music_glasshouse.py` and rebuild.

## Layout

| Module | Contents |
|---|---|
| `synth/core.py` | 48 kHz, time helpers, `seed_for(id) = zlib.crc32(id)`, `rng_for`, mixing (`place`), loop helpers `wrap_loop` (fold tails) and `loop_xfade` (equal-power seam) |
| `synth/osc.py` | polyBLEP band-limited saw/square (PWM)/triangle, sine, supersaw, 2-op FM, additive partial banks |
| `synth/noise.py` | white, pink (Kellet 3-pole), brown, crackle |
| `synth/env.py` | ADSR, exponential T60 decay, breakpoint segments, LFOs |
| `synth/filters.py` | RBJ biquads (LP/HP/BP/notch/peaking/shelves), block time-varying biquad, resonant LP, one-pole, TPT state-variable filter (per-sample), formant bank |
| `synth/fx.py` | waveshaping (tanh drive, clip, fold, asym, bitcrush), feedback delay, **generated-IR convolution reverb** (rooms `small_office`, `store`, `alley`, `hall`, `plate`: seeded early reflections + 3-band exponentially decaying noise tail), pan / Haas widen, **doppler** (propagation-delay time warp, 1/r, air absorption, bearing pan), envelope follower, look-ahead limiter, compressor, sidechain duck curve |
| `synth/granular.py` | grain clouds from a generator (glass shards, jingles) and classic buffer granulation |
| `synth/loudness.py` | ITU-R BS.1770-4 K-weighting; momentary / short-term / gated integrated LUFS; 4x-oversampled true peak; `normalize()` |
| `synth/wavio.py` | WAV 48 kHz / 24-bit writer, deterministic OGG export, decode for verification |
| `synth/seq.py` | `Song` grid (bpm, bars, step patterns, stereo buses), chord helper, drum synths (kick, snare, clap, hats, tom, rim, shaker, impact, riser) and instruments (bass, pad, FM bell, pluck, stab, drone) |
| `cues.py` | one recipe function per cue + the `CUES` registry table (bus, 3D, loop, distance, jitter, cooldown) |
| `cues_impact.py` | the 13 surface impact recipes (impact_fx.md §1 surface ids) + their `CUES` rows (`subdir="impact"`); build.py appends them to `cues.CUES` |
| `cues_ambience.py` | D-117 heist ambience beds (`amb_<heist place>`, 2D Ambience loops); build.py appends them to `cues.CUES` |
| `cues_ostrander.py`, `cues_rolling_thunder.py` | per-heist beds and one-shots (OF-C2; RT-C2: 4 beds + the convoy cues `convoy_approach`, `convoy_brake`, `mixer_ram`, `signal_click`, `truck_doors_open`); build.py appends them to `cues.CUES` |
| `music_engine.py` | shared music parts (kick/hits/bass/pad/motif/arp/stabs/ticks/triplets), the bus mixdown, extra instruments (brass, strings, spiccato, harpsichord, timpani, clang, fog horn, glass pad, rain, tick) |
| `music_glasshouse.py` | Glasshouse track (A minor, 140 BPM grid) |
| `music_night_deposit.py`, `music_shadow_ledger.py`, `music_dockside_burn.py`, `music_gallery_night.py`, `music_ostrander_federal.py`, `music_rolling_thunder.py` | D-117 heist tracks (C minor 140, B minor 132 stealth-only, E phrygian 150, G minor 144, D minor 148, F minor 148); summary in `docs/levels/_audio/d117_music.md` |
| `analysis.py` | metrics (duration, LUFS, true peak, spectral centroid) and the spectrogram contact sheet (numpy + Pillow) |
| `registry.py` | deterministic `.tres` text writers |

## Loudness and format (style guide §9)

* SFX: max short-term loudness −18 LUFS (for one-shots shorter than 3 s the window shrinks to the
  sound itself, min 400 ms), true peak ≤ −1 dBTP. Up to 12 dB of look-ahead limiting is allowed
  on sub-millisecond transients; very peaky one-shots (clicks, reloads, gunshots) end up a few dB
  under −18 rather than being crushed. Loops and beds use integrated loudness, and they're limited
  on a circularly padded copy so the limiter doesn't leave a seam.
* Music: −16 LUFS integrated, ≤ −1 dBTP. Voice (future): −20 LUFS.
* Mix balance lives in the registry (`volume_db`) and in `MusicTrack.gain_db`, so files stay
  normalized.
* WAV 48 kHz/24-bit intermediate, then OGG Vorbis `-q:a 6` (SFX) / `-q:a 5` (music).

## Determinism

Seeds are `zlib.crc32("<cue id>#<variation>")` (music: `crc32("mus_<track>_<part>")`), never
Python's `hash()`. numpy/scipy maths is deterministic on a given machine. ffmpeg is run with
`-fflags +bitexact -flags +bitexact -map_metadata -1` and a fixed `-serial_offset` (seed), so the
Ogg stream serial and the vendor/comment headers are stable. libvorbis turned out to be
deterministic under these flags; `--check-determinism` proves it on every run (all outputs,
`.tres` and `SOURCE.txt` included).

## Loops

* SFX loops are rendered past their end and either crossfaded over the start (`loop_xfade`) or
  have their tails folded back (`wrap_loop`), so the sample after the last one is the first one.
* Music stems are whole bars on one 4/4 grid per track (16 bars, stealth usually 32 bars), and reverb and
  delay tails are folded into bar 1. `MusicDirector` switches stems on bar lines and keeps the
  phrase position.
* Godot loop flags are set at runtime from `AudioCueDef.loop` (so `.import` files stay default).

## Adding a cue

1. Write `def my_cue(rng, v) -> np.ndarray` in `cues.py` (mono for positional, stereo allowed for
   flat cues). Give it its own frequency/rhythm niche and note the niche in the docstring.
2. Add a `CueSpec("my_cue", my_cue, bus=..., ...)` row to `CUES`.
3. `python3 tools/audiogen/build.py --only my_cue`, then a full build to refresh the registry and
   sheets. Look at `docs/levels/_audio/cue_spectrograms.png`.
4. Import: `/opt/godot/godot --headless --path game --import`; tests: `tools/ci/run_tests.sh c audio`.
