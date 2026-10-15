# PO6-07 audio loop audit (ENV C, 2026-10-15)

## Root cause
`CuePlayer.play_cue` started any `loop = true` cue as a looping stream, keyed or not. Several systems request loop
cues through `EventBus.audio_cue_requested` (unowned, nobody can stop them):

| requester (A/B code) | cue | effect before the fix |
|---|---|---|
| `systems/stealth/pager_system.gd:174` (pager start) | `cue.pager_beep` | a second, unowned beep loop that kept beeping after the answer |
| `systems/stealth/pager_system.gd:184` (answer start) | `cue.pager_radio` | an unowned radio loop that never stopped |
| `systems/director/aegis_captain.gd` every resist step | `cue.aegis_pulse` | a new endless loop every 5 s |
| `systems/ai/specials/phantom_brain.gd`, `stinger_brain.gd` per interval | `cue.phantom_hum`, `cue.stinger_arc` | stacked endless loops |
| `weapon_fired` for minigun / flamethrower / saw | `cue.weapon_*_fire`, `cue.weapon_saw_cut` | one endless loop per shot |

Also: the police siren ran from alarm + 6 s until the heist ended (never stopped after an assault); a WAV stream
could never lose a loop flag once set; map-placed alarm bells (CueEmitter) never stopped before heist end.
All `.import` files have `loop=false` (326/326); loop flags are runtime-only (`AudioCueDef.loop`).

## Fix (C files only: world/audio/*)
- Only keyed loops (`CuePlayer.start_loop`) and owner nodes (`CueEmitter`) loop. Any other play of a loop cue plays
  its clip once. Loop playback uses a cached looping copy of the stream, so the shared resource stays one-shot.
- Siren: plays while police are inbound or assaulting; stops at `assault_phase_changed` FADE/CONTROL/NONE; restarts
  on the next ANTICIPATION/BUILD/SUSTAIN; stops at heist end.
- Held-trigger weapon loops: one loop per shooter, stopped `weapon_loop_tail_s` (0.25 s) after the last
  `weapon_fired`, with the spin-down / flame-stop tail.
- Safety caps (`CuePlayer.loop_max_s`): pager beep/radio 30 s, lockpick 120 s, drill 600 s, siren 240 s.
- Lockpick loop stops if the picker goes down; aegis loop stops on `npc_killed`; map bells stop after
  `alarm_bell_duration_s`.

## Every looping cue and its stopper (`CuePlayer.LOOP_STOP_OWNERS`, test-enforced)
| cue | stopped by |
|---|---|
| cue.pager_beep | pager_answer_started / pager_answered / pager_failed (A PagerSystem); 30 s cap |
| cue.pager_radio | pager_answered / pager_failed (A PagerSystem); 30 s cap |
| cue.alarm_bell, cue.alarm_bell_glasshouse | alarm_bell_duration_s / heist_ended / heist_loaded |
| cue.police_siren_far | assault_phase_changed FADE/CONTROL/NONE (A assault director) / heist_ended |
| cue.drill_loop | device_jammed / device_finished (A Device); 600 s cap |
| cue.lockpick | interaction_cancelled / interaction_completed (A Interactable) / crew_downed; 120 s cap |
| cue.aegis_pulse | captain_retreated / npc_killed (A AegisCaptain) |
| cue.weapon_flamethrower_fire, cue.weapon_saw_rev, cue.weapon_saw_cut, cue.weapon_minigun_fire | trigger released (no weapon_fired for 0.25 s) |
| cue.phantom_hum, cue.stinger_arc | never keyed: each request plays once |
| cue.amb_glasshouse_interior, cue.amb_street_dusk | CueEmitter map bed (map unload / heist end) |
| cue.throwable_incendiary_fire | CueEmitter on the fire pool (freed with the pool) |

## What A's systems must emit (stop facts)
- PagerSystem: `pager_answered` on answer and `pager_failed` on expiry/guard-killed-mid-pager. (Already present;
  the `audio_cue_requested` beep/radio calls in pager_system.gd are now harmless one-shots and can be removed.)
- Assault director: `assault_phase_changed` with FADE (or CONTROL) at the end of every wave.
- Device: `device_jammed` / `device_finished` (also when a device is destroyed/removed mid-run).
- Interactable: `interaction_cancelled` whenever a held interaction ends without completing (released, tased,
  downed, moved away).
- AegisCaptain: `captain_retreated`, or `npc_killed` on death.

## Evidence
`game/tests/c/test_audio_loops.gd` (6 tests, headless): every loop cue has an owner; requested loop cues produce
zero looping players; pager beep/radio leave nothing looping after answer or failure; siren stops at FADE and does
not get restarted by the delayed timer; held-trigger loop stops on release; caps, downed picker and captain death stop
their loops.
