# Contract: HUD data (v1.6)

ENV A exposes in-heist state. ENV B owns every UI scene, HUD included (one UI style, one owner).

* ENV A provides `LocalHudModel` (`game/systems/hud_model/local_hud_model.gd`, added under
  HeistRuntime on every peer) with typed properties and change signals for the **local** crew member:
  health/armor/max values, downs left, state (Enums.CrewState), bleedout timer, ammo (mag/reserve
  per slot), equipped slot, deployable/throwable counts, cable ties, body bags, carried bag
  (loot id, weight), interaction prompt (text key, progress 0..1, blocked reason), detection
  indicators (array of {observer_net_id, world_pos, value, kind}), marked targets, pager timers,
  ECM timer, camera countdown, objectives list, assault phase + wave, hostages count, Phantom/Stinger
  warnings, crew teammate panels (name, health, armor, state, downs, carried bag), casing/masked flag.
* ENV B builds `game/content/ui/hud/` scenes that bind **only** to `LocalHudModel` and EventBus.
* Text: all player-facing strings live in `game/content/data/strings/strings.csv` (D-021) (B), keys used by A for
  prompts (`ui.prompt.answer_pager`).

## v1.1: exact binding shape (D-024)

Field types (QB-20): `detection[].kind` is Enums.ObserverKind (int). `marked_targets[].kind` is a StringName
(&"guard", &"camera", &"special", &"civilian"...). `objectives[].state` is Enums.ObjectiveState.
`carried_bag.weight` is Enums.LootWeight. `ammo` keys are int (Enums.WeaponSlot). `interaction.args` formats
both `text_key` and `blocked_reason`. `world_pos` is Vector3 and timers are float seconds.

`LocalHudModel` joins group `G.LOCAL_HUD_MODEL` in `_ready`. There is exactly one per peer, for the local crew member.
The HUD reads properties with `get()` and connects signals by name, ignoring signal args. ENV A must
**assign new Arrays/Dictionaries** (never mutate them in place) and then emit the signal.

| Signal | Properties |
|---|---|
| `vitals_changed` | `health, max_health, armor, max_armor` (float), `downs_left` (int), `crew_state` (Enums.CrewState), `bleedout_s` (float, < 0 = none) |
| `ammo_changed` | `ammo` {WeaponSlot: {mag, reserve}}, `equipped_slot` |
| `inventory_changed` | `deployable_id, throwable_id` (StringName), `deployable_count, throwable_count, cable_ties, body_bags` (int) |
| `carried_bag_changed` | `carried_bag` {} or {loot_id, weight} |
| `interaction_changed` | `interaction` {} or {text_key, args, progress 0..1, blocked_reason (strings key or &"")} |
| `detection_changed` | `detection` [{observer_net_id, world_pos, value, kind}] |
| `marked_targets_changed` | `marked_targets` [{net_id, world_pos, kind}] |
| `pagers_changed` | `pagers` [{pager_id, time_left_s, answering, progress}], `pagers_answered`, `pagers_max` |
| `timers_changed` | `ecm_time_left_s`, `camera_alarm_s` (< 0 = inactive) |
| `objectives_changed` | `objectives` [{id, text_key, args, state}] |
| `assault_changed` | `assault_phase`, `assault_wave` |
| `hostages_changed` | `hostages` |
| `warnings_changed` | `warnings` Array[StringName] (&"phantom", &"stinger", ...) |
| `crew_changed` | `crew` = teammates only [{slot, name, is_ai, health_frac, armor_frac, state, downs_left, carried_loot_id}] |
| `masked_changed` | `masked`, `casing` (bool) |

**App flow ownership (D-024):** ENV B's app shell (`content/ui/menus/menu_flow.tscn`) owns the
application flow. It launches heists through `HeistLauncher`, spawns the HUD/payday CanvasLayer,
and calls `HeistRuntime.teardown()` and `Net.leave()` after the results screen. `core/boot.gd` routes to it,
and the app shell handles `--heist=<id> [--seed=] [--difficulty=]` direct-launch flags. ENV A never
instantiates UI.

## v1.2 (QA-22, D-043)
| Signal | Properties |
|---|---|
| `custody_changed` | `custody` {} or {in_custody: bool, negotiation_left_s: float, auto_release_left_s: float (< 0 = none), highlighted_hostage_net_id: int} |
* `LocalHudModel.track(crew: Node)` / `tracked_crew` lets the HUD follow a crew member without a HeistRuntime
  (firing range, spectating).

## v1.3 (QA-30, D-049)
| Signal | Properties |
|---|---|
| `captain_changed` | `captain_resistance: float` (0..1, server value replicated via Net; 0 when no captain) and `captain_present: bool`. ENV A writes; ENV B shows a widget while the captain is present. |

## v1.4 (QB-60, D-054)
| Signal | Properties |
|---|---|
| `stamina_changed` | `stamina: float` (0..1 of max), `exhausted: bool` (sprint/jump locked until recovery). ENV A writes; ENV B shows a widget. |

## v1.5 (D-057, B4-18)
| Signal | Properties |
|---|---|
| `weapon_charge_changed` | `weapon_charge: float` (0..1; bow draw / charge weapons; 0 when not charging) |
| `weapon_spin_changed` | `weapon_spin: float` (0..1; minigun spin-up; 0 when idle) |

## v1.6 (S1.3 civilian mode, D-065)
| Signal | Properties |
|---|---|
| `player_mode_changed` | `player_mode: StringName` (&"civilian" / &"casing" / &"masked") for the local player; each `crew[]` entry gains `mode`. |
