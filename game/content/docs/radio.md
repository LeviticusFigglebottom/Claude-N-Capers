# Contact radio + subtitles (B7-03)

Owner: ENV B. The PD2 "handler on comms" analog (pd2_fidelity C8): the heist's contact comments on what just
happened, in text (no speech synthesis). Code: `content/radio/` (`ContactRadio`, `RadioLinePicker`,
`RadioTweak`) and `content/ui/hud/subtitle_overlay.gd` (`SubtitleOverlay`). Tests: `tests/b/test_contact_radio.gd`.

## Who is on the radio

`HeistDef.contact` -> `ContactDef.voice_speaker`:

| Heist | Contact | Speaker |
|---|---|---|
| Glasshouse | `contact.vance` (Odile Vance) | `vance` |
| Night Deposit | `contact.accountant` | `accountant` |
| Shadow Ledger | `contact.accountant` | `accountant` |
| Dockside Burn | `contact.reyes` (Hollis "Hammer" Reyes) | `reyes` |

`RadioTweak.speaker_overrides` (`heist id -> contact id`) replaces it per heist (e.g. put Mercer on a heist) and
`fallback_contact` (`contact.mercer`) covers a heist without a known contact. Generic radio lines exist for all four
speakers (`vance`, `reyes`, `accountant`, `mercer`), so either change is data only.

## Fact -> radio event

Every fact below is `[R]` in `docs/contracts/events.md`, so the radio runs **locally on every peer** (host and
clients) and never replicates anything itself.

| EventBus fact | Condition | Radio event | ctx for line matching |
|---|---|---|---|
| `objective_updated(id, state, data)` | state -> COMPLETED (id seen before) | `radio.objective_done` | `objective` = id |
| `objective_updated` | HIDDEN -> ACTIVE | `radio.objective_new` | `objective` = id |
| `objective_updated` | -> FAILED | `radio.objective_failed` | `objective` = id |
| `alarm_raised(reason, _)` | once per heist | `radio.alarm` | `reason` |
| `assault_phase_changed(phase, wave)` | `RadioTweak.assault_tags[phase]`: BUILD / SUSTAIN / FADE | `radio.assault_build` / `_sustain` / `_fade` | `wave` |
| `heist_phase_changed(_, ESCAPE)` | escape activated (`HeistMission.activate_escape`), once | `radio.escape_available` | |
| `audio_cue_requested(cue, ...)` | `cue` starts with `cue.escape_arrive` (EscapeZone arrival after `arrival_delay_s`), once | `radio.escape` | |
| `loot_secured(bag, loot_id, value)` | `loot_id` not in `ignored_loot` (body bags, thermite) | `radio.loot_secured` | `loot_id`, `value` |
| `heist_loaded(heist_id, ...)` | | (re)setup for that heist | |
| `heist_ended` | | radio goes silent | |

The **first sight** of an objective id (its `add_objective`, or the state a drop-in client receives) is silent: only
transitions speak, so the mission's opening burst of objectives never floods the radio.

There is no dedicated "escape vehicle arrived" EventBus fact. The radio uses ENV A's replicated
`audio_cue_requested(&"cue.escape_arrive*")` from `EscapeZone`. An escape with `arrival_delay_s = 0` is present at
once and only gets `radio.escape_available`.

## Line data

Lines live in `data/voice/lines.tres` (`VoiceLineTable`), next to the briefing / mission / bark lines, so ENV C's
voice player finds radio ids in the same table. Text is `voice.<id>` in `strings.csv` (append-only).

```
{ "id": &"vo.<speaker>.radio_<event>_<n>"            generic per contact, e.g. vo.reyes.radio_alarm_2
        | &"vo.<speaker>.<heist>_radio_<suffix>"      heist line, e.g. vo.vance.glasshouse_radio_safe
  "speaker": &"<contact voice_speaker>",
  "event": &"radio.<event>",
  "text_key": &"voice.<id>",
  "cooldown_s": float,    # this line again only after this long (loot lines 30 s)
  "priority": int,        # = RadioTweak.event_priority[event] (informational; the queue reads the tweak)
  "heist": &"<heist id>", # optional: heist line
  "objective": &"<tag>",  # radio.objective_* heist lines: the design doc's Objectives `[tag]` (D-039)
  "loot": &"loot.<id>" }  # optional on radio.loot_secured heist lines
```

Coverage: every speaker has >= 3 generic lines for each of the 10 radio events. Each of the four heists has a
contact line for every objective `[tag]` in its design doc, plus escape-available, escape-arrived and loot lines
(Dockside and Shadow Ledger also by loot id).

## Selection (RadioLinePicker)

1. **Heist lines**: same event and speaker, `heist` = the running heist, `objective` = ctx.objective when the line
   has one, `loot` = ctx.loot_id when the line has one.
2. **Generic lines**: same event and speaker, no `heist` / `objective` / `loot`.

Set 1 wins while any of its lines is off its `cooldown_s`, else set 2 is used. Within the set the last
`no_repeat_depth` (2) picks of that event are avoided while other lines remain. The pick uses
`GameRng.stream(&"radio")`, so it is deterministic per run seed. The same facts in the same order give the same lines
on every peer.

## Timing and priority (RadioTweak, `data/tweak/radio.tres`)

* One fact **waits** at a time: `request(event)` keeps the higher `event_priority` and drops the lower one (on a tie,
  the first one stays). Priorities: alarm 80, escape 75, escape_available 70, assault_build 60, objective_failed 55,
  objective_done 50, objective_new 45, assault_fade 40, assault_sustain 30, loot 20.
* A waiting fact speaks after `settle_s` (0.75 s) and once the previous radio line is off air (its subtitle time). It
  is dropped after `max_wait_s` (4 s).
* `event_cooldown_s` per event (loot 12 s, assault_sustain 45 s, objectives 2 s) and `once_per_heist` (alarm,
  escape_available, escape).
* **Mission lines win.** A `voice_line_requested` from a `comms_speakers` speaker (mercer, vance, reyes,
  accountant) that the radio did not send (ENV C's `say()`, A's abort / last pager) drops the waiting fact and keeps
  the radio quiet for `max(mission_suppress_s, that line's subtitle time)`. Because of `settle_s`, a `say()` sent in
  the same frame as the fact, or just after it, still wins. This is how the radio fills the generic facts without
  doubling the scripted lines (e.g. Glasshouse's `glasshouse_escape` vs `radio.escape_available`).

## Output and the squelch hook (ENV C)

The radio emits **locally** (never replicated):
`EventBus.voice_line_requested(speaker, line_id, {source: &"radio", radio: true, local: true, heist_id, event,
priority, ...fact ctx})`.
* ENV C's voice player can treat `ctx.radio == true` as "play through the radio filter / squelch".
* Or ENV C ships a squelch cue and the lead sets `RadioTweak.squelch_cue` (e.g. `&"cue.radio_squelch"`). The radio
  then also emits `audio_cue_requested(squelch_cue, Vector3.ZERO, 0)` locally with every line. It is empty until the
  cue exists (a missing cue would beep).

## SubtitleOverlay

* MenuFlow's `_spawn_in_heist_ui` calls `ContactRadio.spawn(layer, heist_id)`. That puts the radio and a
  `SubtitleOverlay` on the in-heist CanvasLayer (after the HUD, before payday), and sets `MenuFlow.heist_radio`. Solo,
  host, co-op client and drop-in all use this path.
* It shows every radio line, plus `voice_line_requested` lines from `subtitle_speakers` (the four contacts / handler;
  mission `say()` lines reach every peer as `[R]`). Briefing playback (`source == &"briefing"`) is never shown.
* Row: `ui.subtitle.speaker` ("{name}:") in the speaker's accent (`ContactDef.accent_color`, a heister's roster
  accent), lifted to `min_contrast` (4.5:1) on `panel_color`; then the text, in the active HUD palette's
  `interaction_color`. Each text is formatted with the ctx args: string-key values such as `ui.escape.heli` are
  translated.
* Time on screen = `clamp(base_s + per_char_s * chars, min_s, max_s)` (1.2 + 0.055/char, 2.5..9 s), with a fade over
  the last `fade_s`. At most `max_lines` (2) rows; the oldest is dropped.
* Size: `font_sizes[accessibility/subtitle_size]` (small 22, medium 28, large 36 px at 1080p), live through
  `GameSettings.changed`.
* Placement: bottom centre, `width_px` 800 wide, `bottom_margin_px` 40, and it grows upwards. It stays clear of the
  vitals (bottom-left) and ammo (bottom-right) panels up to `hud_scale` 1.5. Hidden on `heist_ended`.
