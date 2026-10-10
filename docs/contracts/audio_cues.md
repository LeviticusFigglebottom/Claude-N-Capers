# Contract: audio cues (v1.0)

ENV C produces every sound (synthesized/procedural; see style guide §Audio) and the cue registry
`game/world/audio/cues.tres` (`AudioCueDef` resources: streams[], volume_db, bus, 3D, max_distance,
pitch jitter, cooldown). Anyone triggers a cue through `EventBus.audio_cue_requested(cue_id, pos, net_id)`
or through the C-provided `CueEmitter` node (local playback of replicated state).
Missing cues fall back to a generated placeholder beep and log a warning (never crash).

Buses: `Master > Music, SFX (> Weapons, Enemies, World, UI), Voice, Ambience`.

## Required cue ids (phase)
| Cue | Trigger | Design brief | P |
|---|---|---|---|
| cue.detect_tick | detection rising (local) | soft rising tick, pitch ∝ meter | 1 |
| cue.detect_full | "!" | sharp alarm sting | 1 |
| cue.npc_suspicious | NPC → CURIOUS | short "huh?" vocal-ish synth | 1 |
| cue.pager_beep | pager active (3D at body) | insistent 2-tone beeper loop | 1 |
| cue.pager_radio | answering | radio squelch + static bed | 1 |
| cue.alarm_bell | alarm raised | building alarm bell, looping, per-heist variant | 1 |
| cue.mask_on | mask up | cloth/plastic snap + low whoosh | 1 |
| cue.glass_break | glass broken | glass shatter (procedural granular) | 1 |
| cue.drill_loop / drill_jam / drill_done | drill | motor whine loop / grinding stop + clunk / ding | 1 |
| cue.bag_pickup / bag_throw / bag_secure | loot | duffel rustle / whoosh / thud+cha-ching | 1 |
| cue.weapon_<anim_set>_fire(_suppressed) | fire | per weapon family; suppressed versions | 1 |
| cue.reload_*, cue.dry_fire, cue.hitmarker, cue.headshot | combat | — | 1 |
| cue.police_siren_far | loud start | dopplered sirens bed | 1 |
| cue.assault_start | ANTICIPATION→BUILD | stinger + radio chatter | 1 |
| cue.crew_downed / revive | — | — | 1 |
| cue.camera_alert_tone | camera "!" | continuous high tone 7 s | 2 |
| cue.ecm_active / ecm_feedback | ECM | dense digital noise bed / phasing burst | 2 |
| cue.phantom_hum / phantom_charge | Phantom | see pd2_fidelity L4.3 | 3 |
| cue.stinger_windup / stinger_arc | Stinger | 1 s ramp / crackle loop | 3 |
| cue.bulwark_bang | Bulwark | metal shield bang | 3 |
| cue.wrecker_roar / wrecker_step / wrecker_plate_crack | Wrecker | — | 3 |
| cue.longshot_report | Longshot | distant heavy crack | 3 |
| cue.corpsman_heal | Corpsman | bright 2-note chime | 3 |
| cue.brandt_arrival / aegis_pulse | captain | horn sting / low pulse | 3 |

Music: `world/audio/music/<track>/` stems `stealth, control, anticipation, assault, fade` (plus
`win`, `lose` stingers) driven by C's `MusicDirector` listening to the phase signals.
