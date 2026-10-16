# Contract: audio cues (v1.8)

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
| cue.ecm_active | ECM jam starts (ecm_system, audio_cue_requested) | dense bit-crushed digital noise burst 1.8 s (one-shot), 3D at the ECM, 20 m | 2 |
| cue.ecm_feedback | ECM feedback | phasing digital burst 1.4 s | 2 |
| cue.trip_mine_explode | trip mine detonation (deployable, audio_cue_requested [R]) | tight high-explosive crack + steel ping, World bus, ~150 m, 3 variations | 3 |
| cue.phantom_hum / phantom_charge | Phantom | see pd2_fidelity L4.3 | 3 |
| cue.stinger_windup / stinger_arc | Stinger | 1 s ramp / crackle loop | 3 |
| cue.bulwark_bang | Bulwark | metal shield bang | 3 |
| cue.wrecker_roar / wrecker_step / wrecker_plate_crack | Wrecker | — | 3 |
| cue.longshot_report | Longshot | distant heavy crack | 3 |
| cue.corpsman_heal | Corpsman | bright 2-note chime | 3 |
| cue.brandt_arrival / aegis_pulse | captain | horn sting / low pulse | 3 |
| cue.bag_lift_start / bag_lift_arrive | `bag_lift` prefab (A, CueEmitter/audio_cue_requested) | motor whine + cage rattle / bell + brake clunk | 2 |
| cue.hack_start / hack_interrupt / hack_done | `hack_terminal` (device_* kind `&"hack"`) | keyboard burst + fan / error buzz / confirm chirp | 2 |
| cue.escape_arrive (+ `_van`, `_boat`, `_heli`) | escape vehicle arrives (A via audio_cue_requested) | engine approach + horn / outboard + bump / rotor swell | 2 |
| cue.weapon_revolver_fire / _cylinder_open / _eject / _speedloader_in / _cylinder_close | revolver set (B4-12) | heavy crack + cylinder foley | 4 |
| cue.weapon_break_action_fire / _open / _eject / _shell_in / _close | break_action set (B4-18) | double-barrel boom + breech foley | 4 |
| cue.weapon_lever_fire / _cycle | lever set | rifle crack / lever cycle | 4 |
| cue.weapon_bow_fire / _draw / _impact | bow set | release thwip (silent, −8 dB, 10 m) / draw creak / thunk | 4 |
| cue.weapon_crossbow_fire / _load | crossbow set (impacts reuse bow_impact) | string snap (silent, 15 m) / cock | 4 |
| cue.weapon_launcher_fire / _reload / _explode | launcher set | 40 mm thump / breech / explosion (World bus, 180 m) | 4 |
| cue.weapon_flamethrower_ignite / _fire (loop) / _stop | flamethrower set | ignition / roar loop / cut-off | 4 |
| cue.weapon_saw_rev (loop) / _cut (loop) | saw set | motor rev / blade cutting | 4 |
| cue.weapon_minigun_spin_up / _fire (loop) / _spin_down | minigun set | whine up / 3000 rpm buzz / whine down | 4 |
| cue.door_breach | police breach a locked door (L1, A 878d35f) [R] | heavy ram impact + splintering frame, 3D at the door | 3 |
| cue.burn_warning | thermite burn_point countdown starts (QC-38) | hissing flare + rising warning tone, 5 s | 3 |
| cue.throwable_pin | grenade pin pulled (A3-12, local + 3D quiet) | pin pull + spoon ping | 3 |
| cue.throwable_frag | frag detonation | grenade blast, World bus, ~150 m | 3 |
| cue.throwable_concussion | concussion detonation | sharp bang + high ringing tail | 3 |
| cue.throwable_incendiary | incendiary impact | glass smash + fuel whoosh + short tail | 3 |
| cue.throwable_incendiary_fire (loop) | the incendiary fire pool burns (stop when it ends) | fire crackle loop, 3D at the pool | 3 |
| cue.throwable_knife_hit | throwing knife hits a body (ENV A picks by target) | flesh thunk | 3 |
| cue.throwable_knife_hit_hard | throwing knife hits world geometry | metallic ting / wood thunk | 3 |
| cue.npc_melee_swing | NPC melee windup start (A3-13) [R], source = the NPC | short cloth/arm whoosh, 3D at the NPC, ~15 m; World bus, 3 var, −8 dB, cooldown 0.25 | 3 |
| cue.radio_squelch | contact radio line start/end (ENV B ContactRadio, B7-03), local | short squelch click on / off, 2D, Voice or UI bus | 5 |
| cue.payday_tick | payday card-pick timer, each of the last 5 s (ENV B payday screen), local | 60 ms dry UI tick, 2D, UI bus (ENV C 51cfb287) | PP (D-082) |
| cue.ui_focus | any focusable control gains focus (UiBuild), local | soft paper tick ~30 ms, 2D, UI bus | PP (D-090) |
| cue.ui_confirm | button press / accept | brass "clack" ~80 ms | PP (D-090) |
| cue.ui_back | back / cancel | lower, shorter tick | PP (D-090) |
| cue.ui_primary | the screen's one primary action (Start Heist, Take, Continue) | two-tone commit | PP (D-090) |
| cue.ui_error | blocked / invalid action | muted buzz | PP (D-090) |
| cue.ui_tab | tab / page switch | paper slide | PP (D-090) |
| cue.hud_objective_done | objective completed (HUD) | short rising two-note chime | PP (D-090) |
| cue.hud_hint | contextual hint appears | very soft blip | PP (D-090) |
| cue.payday_total | payday hero total lands | register "cha-chunk" | PP (D-090) |
| cue.card_flip | payday card reveal | card flip | PP (D-090) |
| cue.hud_hit | local player's shot hits (non-zero damage), HUD | 35 ms tick, -13 dB, cooldown 0.04, jitter 0.03, UI bus 2D (B, build_ui.py) | PP (D-100) |
| cue.hud_headshot | local player's headshot/crit | 80 ms 3.5 kHz tink, -12 dB, cooldown 0.05 | PP (D-100) |
| cue.hud_kill | local player's kill | 120 ms 280 Hz thock + click, -9 dB, cooldown 0.06 | PP (D-100) |
| cue.hud_heartbeat | one pulse of the low-health vignette (< 25 % health, standing) | lub-dub 450 ms, -12 dB, cooldown 0.3, never looped | PP (D-100) |
| cue.impact_<surface> (concrete, brick, plaster, tile, wood, metal, glass, fabric, dirt, water, flesh, armor, shield) | every shot_fx / melee hit with a surface (C VfxDirector, impact_fx.md §3, D-105), local on every peer, 3D at the hit point | short material impact (≤0.4 s, 4 variations, World bus, 20–45 m, cooldown 0.03, jitter 0.06); built by tools/audiogen/cues_impact.py | PO (D-105) |

UI cues (D-090) are built by `python3 tools/audiogen/ui/build_ui.py` (ENV B). `tools/audiogen/build.py` rewrites
`cues.tres`: after it, run `python3 tools/audiogen/ui/build_ui.py --registry-only` (or have C's build call it) so the
UI-bus entries are kept.

Special-action cues have no dedicated EventBus signals: ENV A triggers them with `audio_cue_requested` or a
`CueEmitter`. Looping tells stop on the matching end fact (`crew_tase_ended` for `stinger_arc`, D-049) or locally.

Music: `world/audio/music/<track>/` stems `stealth, control, anticipation, assault, fade` (plus
`win`, `lose` stingers) driven by C's `MusicDirector` listening to the phase signals.

## v1.8 (PO6-17, D-114 §5): assault-event cues
Kinds on `EventBus.assault_event_started(kind, net_id, position)` / `assault_event_ended(kind, net_id)` are
`&"turret_van"`, `&"heli"`, `&"breach"` (never `&"helicopter"`).
| cue | type | trigger | stop owner |
|---|---|---|---|
| `cue.assault_event_warning` | 2D, UI bus ≈ −6 dB, cooldown 3 s | B HUD on `assault_event_started` (`UiSfx.ASSAULT_EVENT_WARNING`) | one-shot |
| `cue.assault_van_arrive` | 3D one-shot at `position` | turret_van start | one-shot |
| `cue.assault_van_engine` | 3D loop, follows `net_id` | turret_van start | C: `assault_event_ended`, heist end, safety cap |
| `cue.assault_turret_deploy` / `cue.assault_turret_destroyed` | 3D one-shots | A (turret) | one-shot |
| `cue.assault_heli_arrive` | 3D one-shot | heli start | one-shot |
| `cue.assault_heli_rotor` | 3D loop on `net_id`, 250 m | heli start | C: `assault_event_ended`, heist end, safety cap |
| `cue.assault_heli_leave` | 3D one-shot | heli end | one-shot |
| `cue.assault_breach_warning` | 3D at `position` | breach start | one-shot |
| `cue.c4_explode` | 3D one-shot | breach blast: A plays it on detonation (A confirms) | one-shot |
