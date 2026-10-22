# D-117 §7: heist music tracks and ambience beds

Every built heist has its own procedural music track and its own ambience beds (tools/audiogen; no samples, no
third-party audio). Built by `python3 tools/audiogen/build.py` (one track: `--only mus_<track>`); the
determinism check (`--check-determinism`) covers all of it. Metrics: `cue_metrics.tsv`, spectrograms:
`music_spectrograms.png` / `cue_spectrograms.png` (both from the full build).

## Engine

`tools/audiogen/music_engine.py` holds the step-sequenced parts and the bus mixdown lifted from
`music_glasshouse.py` (Golden Hour output is byte-identical: sha256 checked before/after) plus the new
instruments. Each track module only carries its parameters and stem recipes. All stems of a track sit on
**one bar grid**, because MusicDirector switches on the playing stem's bar line and keeps the phrase position;
where a doc asks for a different tempo in one stem, it is written on the shared grid (half time, or a
quarter-note-triplet pulse = 3/4 of the grid) and the difference is noted below.

All files: OGG Vorbis q5, 48 kHz stereo, −16 LUFS integrated (±0.3), true peak ≤ −1 dBTP after decode.
Mix trims live in the track `.tres` (`gain_db`: stealth −6, control −3, anticipation −2, assault 0, fade −3,
stingers −2, unless listed).

## Tracks

| Track | Key / grid | Palette | Doc tempo vs grid |
|---|---|---|---|
| `glasshouse` (Golden Hour, reference) | A minor, 140 | glassy FM bells (3.5 ratio), saw pads, saw/sub bass, kit | stealth 70 = half time |
| `night_deposit` | C minor, 140 (Cm Ab Fm G) | low brass section (saw + pulse, lip scoop, delayed vibrato), sub pulses, clock tick-tock (time lock: half notes, then quarters), brass motif C Eb G / F Eb D; hall reverb | stealth 70 = half time, assault 140: exact |
| `shadow_ledger` | B minor, 132 (Bm(add9) Gmaj7 Em9 F#7sus4) | glass-harmonica FM pads (2:1), sub pulses, rain-noise texture, hack ticks that tighten (half -> quarter -> eighth notes), no drums; plate reverb | stealth 66 = half time: exact |
| `dockside_burn` | E minor / phrygian bII, 150 (Em C F B) | container clangs (inharmonic plate modes), diaphone fog-horn motif (E2 -> B1), driven toms, saw ostinato, saturated master; alley reverb | assault 150 exact; control on quarter-note triplets = 112.5 pulse (doc 110) |
| `gallery_night` | G minor, 144 (stealth lament Gm F Eb D; loud Gm Eb Cm D) | FM harpsichord ostinato and motif G Bb D C Bb A (distorted in assault), bowed strings pad with vibrato, spiccato low strings, synth timpani (G2 / D2), gallery clock tick; hall reverb | stealth 72 = half time exact; control triplet pulse = 108 (doc 110); assault 144 (doc 136, +8 to share the grid) |
| `rolling_thunder` (RT-C2) | F minor, 148 (stealth Fm Eb Db C; loud Fm Db Eb C) | ticking closed hi-hat clock (tick / tock / open-hat chime per bar, doubling to sixteenths in stealth bars 16-31 = the ETA - 30 s rise), dark detuned-saw pad, sub pulses, diesel-drone bass (detuned saws + square sub chugging at the sixteenth firing rate, growling LP), two-note signal chime (inharmonic crossing bell, C6 -> Ab5), kick / snare / low toms; hall reverb, light master drive | stealth 74 = half time (doc 78, -4 to share the grid); control triplet pulse = 111 (doc 112); assault 148 exact |

### Stems and durations

| Track | stealth | control | anticipation | assault | fade | win / lose |
|---|---|---|---|---|---|---|
| night_deposit | 32 bars, 54.86 s | 16 bars, 27.43 s | 27.43 s | 27.43 s | 27.43 s | 6.0 s / 6.0 s |
| shadow_ledger | 32 bars, 58.18 s | = `abort` 4 bars, 7.27 s | = abort | = stealth | = abort | 6.0 s / 6.0 s (fail sting) |
| dockside_burn | 16 bars, 25.60 s | 16 bars, 25.60 s | 25.60 s | 25.60 s | 25.60 s | 6.0 s / 6.0 s |
| gallery_night | 32 bars, 53.33 s | 16 bars, 26.67 s | 26.67 s | 26.67 s | 26.67 s | 6.0 s / 6.0 s |
| rolling_thunder | 32 bars, 51.89 s | 16 bars, 25.95 s | 25.95 s | 25.95 s | 25.95 s | 6.0 s / 6.0 s |

### Loudness (decoded OGG: integrated LUFS / true peak dBTP)

| Part | night_deposit | shadow_ledger | dockside_burn | gallery_night | rolling_thunder |
|---|---|---|---|---|---|
| stealth | −15.99 / −4.7 | −15.99 / −5.1 | −16.12 / −3.7 | −16.05 / −4.7 | −16.00 / −3.7 |
| control (SL: abort) | −16.07 / −1.2 | −16.17 / −2.8 | −16.15 / −1.7 | −16.11 / −2.9 | −16.07 / −3.2 |
| anticipation | −16.13 / −2.4 | (abort) | −16.13 / −2.7 | −16.08 / −4.2 | −16.05 / −2.9 |
| assault | −16.13 / −1.3 | (stealth) | −16.25 / −1.7 | −16.17 / −1.3 | −16.19 / −3.4 |
| fade | −16.06 / −1.9 | (abort) | −16.15 / −3.0 | −16.11 / −5.1 | −16.05 / −3.0 |
| win | −16.03 / −5.6 | −15.99 / −3.8 | −16.06 / −3.8 | −16.02 / −3.7 | −16.02 / −4.9 |
| lose | −16.05 / −2.0 | −15.97 / −3.7 | −16.06 / −3.1 | −16.12 / −3.9 | −15.94 / −4.0 |

### Shadow Ledger (stealth-only)

MusicDirector has no stealth-only branch: an alarm sets the phase LOUD (stem `control`) for
`StealthTweak.stealth_only_abort_s`, then `heist_ended(failed)` plays the `lose` stinger; a stealth escape is
phase ESCAPE (stem `assault`), and the jukebox previews the `assault` stem. So the track renders two loops and
aliases every stem name in `shadow_ledger.tres` (one ext_resource per file):
`stealth`, `assault` -> the stealth bed (escape and the jukebox keep the bed); `control`, `anticipation`,
`fade` -> `abort` (4-bar alarm loop: sub on every beat, eighth ticks, B/C/F glass cluster, riser). `lose` = the
abort / fail sting (glass cluster hit, ticks stopping, cluster bending down a fourth over a sub drop); `win` =
rising glass bells into D major. No assault stems were composed.

Dockside Burn is loud-only; its `stealth` stem (fog drone, distant horn, far clangs) only covers the short
CASING walk-in so that phase is never silent.

## Ambience beds (`cues_ambience.py`)

2D (positional = false), Ambience bus, loop, −18 LUFS integrated, seamless crossfaded loops; each is a
`CueEmitter (map bed)` loop owner (CuePlayer.LOOP_STOP_OWNERS) placed in the map's `Audio` node.

| Cue | Heist | Content | Length | vol dB |
|---|---|---|---|---|
| `cue.amb_bank_night_interior` | ND | HVAC, hall clock tick-tock (1 Hz), 120 Hz fluorescent buzz | 24 s | −14 |
| `cue.amb_harbor_night` | ND | lapping water, rigging clinks, one far fog horn / loop, no gulls | 48 s | −12 |
| `cue.amb_shadow_ledger_interior` | SL | low HVAC, rain on glass, wind pressure, server fan | 30 s | −14 |
| `cue.amb_rooftop_rain` | SL | heavy rain + splashes, gusts, traffic far below | 30 s | −12 |
| `cue.amb_cold_store` | DB | evaporator fans (23 Hz blade AM), compressor thump / 1.6 s, ice ticks, strip-curtain flutter | 24 s | −14 |
| `cue.amb_dockside_fog` | DB | water slap, fog horn / 56 s, two far gulls, rigging, condenser drone, crane hum | 56 s | −12 |
| `cue.amb_gallery_gala` | GN | string-trio pad (G minor), crowd murmur (formant babble), glass clinks | 32 s | −14 |
| `cue.amb_art_store` | GN | climate-plant drone, humidifier ticks, mist hiss | 24 s | −15 |
| `cue.amb_uptown_night` | GN | light traffic with wet-tyre hiss, wind in trees, one far taxi horn | 36 s | −12 |
| `cue.amb_skyway_street` | RT | Skyway traffic rumble overhead, expansion-joint thumps every 3-6 s, gusts with leaves and grit, far traffic, a bus idling, pigeons | 48 s | −12 |
| `cue.amb_underpass` | RT | tunnel drips, fluorescent buzz, low rumble, one freight train over the bridge per loop (rumble, bogie clacks, wheel squeal; period 96 s, inside the doc's 90-150 s) | 96 s | −12 |
| `cue.amb_diner` | RT | griddle sizzle + spits, counter radio (tinny plucks + DJ), cutlery / crockery, soft murmur, fridge hum | 32 s | −14 |
| `cue.amb_site` | RT | diesel generator (25 Hz firing, 50 Hz hum), scaffold clanks on the gusts, wind on the hoarding, far traffic | 40 s | −13 |

RT beds and the convoy cues live in `cues_rolling_thunder.py` (like `cues_ostrander.py`). RT freight trains are part of
the underpass bed, so they cannot be suppressed during a Phantom charge (the doc's readability note): a separate
train cue would be needed for that (ENV A schedules it).

Not done: the doc's post-last-call change of the GN hall bed (gala -> room tone) would need a second bed
switched by the mission (ENV A); the gala bed plays all night for now.

## Maps

`game/world/audio/map_audio_builder.gd` builds the `Audio` node (CuePlayer, MusicDirector with the heist's
track id, autoplaying bed CueEmitters) for the Night Deposit, Shadow Ledger, Dockside Burn and Gallery Night
generators. Night Deposit no longer borrows the Golden Hour beds. Golden Hour keeps its own `gh_art.gd` setup.
