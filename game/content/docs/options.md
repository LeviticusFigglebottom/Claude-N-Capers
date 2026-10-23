# Options / settings (B5-01)

Owner: ENV B. API brief for every environment that must read a player option. Code:
`game/content/settings/` (model, persistence, input), `game/content/ui/menus/options_screen.gd`
(+ `ui/menus/options/`), palettes in `game/content/ui/data/hud_palette*.gd`.

## Reading a setting

```gdscript
var s: GameSettings = GameSettings.current()   # game-wide instance, loaded from user://settings.cfg on first use
s.fov()                                         # float, degrees, 60..100, default 75
s.effects_quality()                             # int: video/effects_quality low 0 / medium 1 / high 2, one lower with reduce_motion
s.head_bob()                                    # bool: accessibility/head_bob (default true) AND NOT reduce_motion
s.changed.connect(_on_settings_changed)         # changed(section: StringName, key: StringName)
```

`GameSettings.current()` is a plain `RefCounted` (no autoload): call it whenever you need it; it is
loaded once and the same object is kept for the session. `changed` fires once per value that actually
changes, after the player presses **Apply** in the options screen (the screen edits a copy and copies
it into `current()` on Apply). Generic access: `get_value(section, key)`; sections are the constants
`GameSettings.AUDIO`, `VIDEO`, `CONTROLS`, `ACCESSIBILITY`, `BINDINGS`.

### What ENV A must read (B does not touch A's camera or controller)

| What | API | Type / range | Default | Notes |
|---|---|---|---|---|
| Head bob | `head_bob()` / `accessibility/head_bob` | bool | true | ENV P's camera walk bob. Always false while `accessibility/reduce_motion` is on. Listen to `changed` for either key. |
| Effects quality (D-105) | `effects_quality()` / `video/effects_quality` | int `EFFECTS_LOW` 0 / `EFFECTS_MEDIUM` 1 / `EFFECTS_HIGH` 2 (choice "low" / "medium" / "high") | high | ENV C's VfxDirector (impact_fx.md §3) scales pooled effect counts, e.g. `GameSettings.EFFECTS_SCALE[q]` (0.3 / 0.6 / 1.0). One step lower while `accessibility/reduce_motion` is on. Listen to `changed` for either key. |
| Camera FOV | `fov()` / `video/fov` | float deg 60..100 | 75 | Vertical FOV of the local player's `Head/Camera` (CrewView). ADS zoom should scale from it. The Options row shows it as horizontal degrees at the current aspect (75 ≈ 108° at 16:9, lead ruling). |
| Mouse sensitivity | `mouse_sensitivity()` | Vector2 multipliers 0.1..5 | (1, 1) | Multiply `PlayerInput.mouse_sensitivity` (x for yaw, y for pitch). |
| Aiming sensitivity (options parity) | `ads_sensitivity()` / `controls/ads_sensitivity` | float multiplier 0.1..2 | 1 | ENV P: while aiming / scoped, multiply mouse and stick look by it, on top of the D-091 zoom slow-down. |
| Screen shake (options parity) | `screen_shake()` / `accessibility/screen_shake` | float 0..1 | 1 | ENV P: scale every camera shaker (melee punch, tase jitter, later ones) by it; Reduce Motion keeps its own cut on top. |
| Invert Y | `invert_y()` | bool | false | Applies to mouse and pad (`PlayerInput.gamepad_invert_y`). |
| Pad look speed | `pad_sensitivity()` | float multiplier 0.1..5 | 1 | Multiply `PlayerInput.gamepad_look_speed`. |
| Pad deadzone | `pad_deadzone()` | float 0.05..0.5 | 0.2 | `PlayerInput.gamepad_deadzone` (right stick). |
| Hold / toggle | `is_toggle(&"aim")`, `&"crouch"`, `&"sprint"` | bool | false (hold) | Toggle = a press flips the state; release does nothing. Clearing the toggle on down / custody is A's call. |
| Scoreboard hold / toggle (B6-02) | `is_toggle(&"scoreboard")` / `controls/scoreboard_mode` | bool | false (hold) | B's own: the HUD's `ScoreboardOverlay` reads it; nothing for ENV A. |
| Interact hold / toggle (options gap, LEAD r280 (5)) | `is_toggle(&"interact")` / `controls/interact_mode` | bool | false (hold) | ENV P: toggle = PD2's "toggle interaction". A press starts a timed interaction and it runs on without holding; another press, moving out of range, or looking away cancels it. Instant interactions are unchanged. |
| Quality preset / shadows / resolution (options gap) | `video/quality_preset`, `video/shadow_quality`, `video/resolution` / `resolution()` | choice / Vector2i | high / high / auto (ZERO) | B's own (SettingsApplier). A preset writes render_scale / msaa / fxaa / effects_quality / shadow_quality (GameSettings.QUALITY_PRESETS); a hand edit re-derives it ("custom"). Shadows = shadow atlas size (1024 / 2048 / 4096; high = Godot's default). Resolution sizes the window in windowed mode only. |

Suggested hook (ENV A, `systems/player/player_input.gd`): in `_ready()` read the values above, connect
`GameSettings.current().changed` and re-read on `section == &"controls"`; `crew_view.gd` sets
`camera.fov = GameSettings.current().fov()` and follows `changed` for `&"video"/&"fov"`.

### What ENV C (or A) may read

| What | API | Notes |
|---|---|---|
| Brightness | `video/brightness` (0.5..1.5, default 1.0) | `SettingsApplier.apply_environment(env)` sets `adjustment_enabled` + `adjustment_brightness` on a map's `Environment`. Call it when a heist map's WorldEnvironment is ready (and on `changed` for `&"video"/&"brightness"`). |
| Subtitles on / off (options parity) | `subtitles()` / `accessibility/subtitles` (bool, default true) | ENV B's `SubtitleOverlay` shows no in-heist line while off. The briefing screen's own subtitle panel is the briefing text and stays. |
| Subtitle size | `accessibility/subtitle_size` (`small`/`medium`/`large`) | ENV B's in-heist `SubtitleOverlay` (B7-03, `content/docs/radio.md`) follows it live: font sizes in `data/tweak/radio.tres` `font_sizes` (22 / 28 / 36 px at 1080p). |
| Drop-in (host) | `gameplay/dropin_policy` (`ask`/`auto`/`off`, default `ask`) | ENV B: copied into each hosted lobby session (`LobbySession.host`); the host's in-lobby change is remembered here. Shown on the Controls tab. |
| Blood & gore (D-113) | `gameplay/gore` (`full`/`reduced`/`off`, default `full`) | ENV C's VFX: `GameSettings.current().gore()` (StringName, `GameSettings.GORE_*`), looked up by class name; follow `changed(&"gameplay", &"gore")`. Shown on the Controls tab with the other gameplay rows. |

### What ENV B applies itself (`GameSettings.apply()` -> `SettingsApplier`)

* **Audio**: buses `Master, Music, SFX, Weapons, Enemies, World, UI, Voice, Ambience` (contract
  audio_cues.md). A 0..1 linear volume per bus; the bus gets `base_db + linear_to_db(v)` where
  `base_db` is the bus layout's own mix level (so ENV C's `-3 dB` on a bus survives), and is muted at
  0. Calls `AudioCueLib.ensure_buses()` first so a later `ensure_buses()` never wipes the volumes.
* **Video**: window mode (`windowed`, `fullscreen` = borderless full-screen window,
  `exclusive_fullscreen`), vsync, `Engine.max_fps` (0 = unlimited), and on the root viewport
  `scaling_3d_scale` (render scale 0.5..1), `msaa_3d` (`off/2x/4x/8x`) and `screen_space_aa` (FXAA).
  Window / vsync are skipped on the headless display server.
* **Input**: the InputMap (below).
* **HUD**: palette + HUD scale (the HUD follows `changed`).

`MenuFlow._ready()` calls `GameSettings.current().apply()` at start (menus and direct launch).

## Input bindings

Every project InputMap action except Godot's `ui_*` actions is rebindable (order:
`data/settings/settings_defaults.tres` `action_order`; an action missing there is appended). Each action
has two columns: **KBM** (keys, mouse buttons) and **PAD** (pad buttons, stick / trigger directions).
Display names: strings `ui.action.<action>`.

* `InputBindings.column(s, action, col) -> Array[Dictionary]`, `rebind(s, action, binding, swap)`,
  `conflicts(s, action, binding)`, `reset_action(s, action)`, `reset_all(s)`, `apply(s)`.
* Applying = `InputMap.action_erase_events(action)` + `action_add_event` per binding (deadzones kept).
* A conflict is the same input on another action in the same column, unless the two actions already
  share an input in project.godot (designed contextual keys: F = interact / shout, G = mask up / throw /
  drop bag, pad Y = mask up / swap weapon). The options screen offers **Swap** (the other action takes
  this action's previous input), **Keep both** or **Cancel**.
* Code that shows key names should read the InputMap (it is always current), e.g.
  `InputEventCodec.text(InputEventCodec.to_dict(event))`.

## Settings file (`user://settings.cfg`, ConfigFile, version 1)

```ini
[meta]
version=1

[audio]
Master=1.0
Music=0.8
; ... one float 0..1 per bus

[video]
window_mode="windowed"
vsync=true
max_fps=0
render_scale=1.0
msaa="4x"
fxaa=false
brightness=1.0
fov=75.0
effects_quality="high"

[controls]
mouse_sensitivity_x=1.0
mouse_sensitivity_y=1.0
invert_y=false
pad_sensitivity=1.0
pad_deadzone=0.2
aim_mode="hold"
crouch_mode="hold"
sprint_mode="hold"
scoreboard_mode="hold"

[accessibility]
palette="default"
hud_scale=1.0
subtitle_size="medium"

[bindings]
; only overridden actions; a missing column means "project default"
reload={"kbm": [{"type": "key", "keycode": 75, "physical": true}]}
```

Binding dicts (never serialized objects): `{"type": "key", "keycode": int, "physical": bool}`,
`{"type": "mouse_button", "button": int}`, `{"type": "joy_button", "button": int}`,
`{"type": "joy_motion", "axis": int, "dir": 1 | -1}`.

Loading: missing file -> defaults; unreadable / corrupt -> defaults + `Log.warn`; every value is
validated against `data/settings/settings_defaults.tres` (wrong type -> that key's default, numbers
clamped, unknown choices -> default; invalid bindings and unknown actions dropped); a newer `version`
reads the known keys. Defaults, ranges and choices all live in that tweak (`SettingsDefaults.sections`,
spec types `float/int/bool/choice`). Tests point `GameSettings.root_dir` at
`BTestUtil.settings_root()`.

## HUD palettes (`data/ui/hud_palettes.tres`)

`HudPaletteSet.palettes: Array[HudPalette]`, one per `accessibility/palette` option:
`default` (the PD2 colours of `hud_tweak.tres`), `deuteranopia`, `protanopia`, `tritanopia`,
`high_contrast`. Each `HudPalette`:

| Field | Used for |
|---|---|
| `id`, `name_key` | setting value, `ui.options.palette.<id>` |
| `detection_suspicious`, `detection_alert`, `detection_detected` | detection rings and crosshair arcs (D-128) below 0.5, from 0.5, at 1.0 ("!") |
| `health`, `armor`, `low_health` | vitals / teammate bars; low-health tint and warning text |
| `ally_marker`, `enemy_marker` | teammate names; marked-target diamonds |
| `objective` | active objective rows |
| `loot_highlight`, `interaction_highlight` | carried-bag line; interaction hold bar |
| `device_jam` | a jammed drill / saw / hack in the device timers (bar, frame, status word); PD2 red in every palette, paired with `objective` in the CVD check (r266) |

`HudPalette.apply_to(tweak)` returns a recoloured `HudTweak` copy; `HudPaletteSet.active_tweak()` is
what the HUD reads. Outline / world highlights drawn by other environments can read
`HudPaletteSet.active().loot_highlight` etc. and follow `changed` for `&"accessibility"`.
Test guarantees (`tests/b/test_options_palettes.gd`): every colour >= 3:1 against the HUD panel
(`low_health` >= 4.5:1, it is text); paired states (suspicious/alert/detected, health/armor,
health/low health, ally/enemy, objective/loot, loot/interaction) >= 20 CIE76 apart in normal vision and
under the simulation each palette targets (Machado 2009, severity 1; `high_contrast` under all three).
`ColorVision.simulate(color, kind)` / `delta_e76()` check new colours.

## Options screen

`OptionsScreen` (`ui/menus/options_screen.tscn`): tabs Controls (look / hold-toggle rows + rebind list),
Audio, Video, Accessibility (with a palette swatch preview); footer Apply / Revert / Reset Tab / Back.
Opened by `MenuFlow.options_menu` (`MenuOptions`): main menu **Options**, hub profile panel **Options**,
and in a heist the `pause` action (Esc / Start) opens it over the HUD while the game keeps running; the
local `CrewController.set_input_paused(true)` holds the crew still and the mouse is released until Back.
There is no other pause menu. Code that needs to open the overlay itself calls
`options_menu.open_in_heist()` on the `MenuFlow` node.
