# Contract: HUD data (v1.22)

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
| `detection_changed` | `detection` [{observer_net_id, world_pos, value, kind, state?}] (v1.17: `state`) |
| `marked_targets_changed` | `marked_targets` [{net_id, world_pos, kind}] |
| `pagers_changed` | `pagers` [{pager_id, time_left_s, answering, progress}], `pagers_answered`, `pagers_max` (v1.13: `time_left_s` = response window, frozen while answering) |
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

## v1.7 (B6-02 scoreboard, D-071)
| Signal | Properties |
|---|---|
| `crew_stats_changed` | `crew_stats: Array[Dictionary]`, one row per crew member (humans and Crew AI, local included): `{slot, name, is_ai, is_local, kills, specials_killed, civilians_killed, downs, shots, hits, headshots}`. Server counts, replicated to every peer; `name` = `CrewController.display_name`. A counter that does not exist yet is **omitted** (not 0). |

Counting rules (ENV A): a **shot** = one firearm trigger pull (a shotgun blast is 1; melee, throwables, deployables,
sentries never count). A **hit** = a shot that struck an enemy NPC (body, shield or armour plate, even for 0 damage),
at most once per shot. A **headshot** = a shot that struck an enemy's HitZone.HEAD, at most once per shot. AI crew
are counted the same way.

## v1.8 (QA-PO5-1, D-089): objective world markers
* An objective def may carry `data.marker_tags: Array[StringName]`, map `objective_tags` that place its markers.
* `LocalHudModel.objective_markers: Array[Dictionary]`, each `{id: StringName, text_key: StringName, position: Vector3,
  state: Enums.ObjectiveState}`, **only for ACTIVE objectives** of the local crew's view; signal
  `objective_markers_changed(markers)`. Positions are world space; ENV B projects them (edge-clamped, distance label,
  hidden while casing unless the objective is a casing objective). Markers update when an objective changes (incl. the
  stealth → loud transition) and when a tagged node moves or frees.

## v1.9 (D-100): local player id
* `LocalHudModel.local_net_id: int`: the net id of the crew member this HUD belongs to (valid in normal play, not only tracked_crew), so the HUD can match `damage_applied` / `npc_killed` attacker ids for hit markers and damage-direction arcs. ENV A provides; ENV B consumes.
* v1.10: `LocalHudModel.revive_progress: float` (0..1, while the local crew member is downed and someone holds revive on them, else 0) and `reviver_slot: int` (-1 = none), for B's downed-state "<name> is reviving you" bar. ENV A provides.
* v1.11: each `crew` row also carries `bleedout_s: float` (seconds left while DOWNED, else -1) and `revive_progress: float` (0..1 while being revived, else -1), for B's teammate state badge rings (env/a-core bbdc5784).
* v1.12 (D-106): `reloading: bool` and `reload_progress: float` (0..1, -1 when not reloading) for the local crew member's equipped weapon, in the weapon group; ENV A provides, ENV B draws a reload indicator.

## v1.13 (D-114 §1/§4, PO6-03/PO6-08): device rows, objective device id, pager window freeze
ENV A provides (env/a-core c24f6c53, 99f3e8dc); ENV B consumes.
* **Devices.** `LocalHudModel.devices: Array[Dictionary]` + signal `devices_changed()`: one row per placed timed device
  while it is running, jammed or paused (the row is removed when the device is done or idle):

  | Field | Type | Meaning |
  |---|---|---|
  | `net_id` | int | the device's net id (DrillPoint / Safe runner / HackTerminal) |
  | `kind` | StringName | `&"drill"`, `&"thermal"`, `&"saw"`, `&"hack"` |
  | `world_pos` | Vector3 | panel anchor, world space (the placed device, raised `device_panel_up_m`) |
  | `progress` | float | 0..1 |
  | `time_left_s` | float | run time left (jams excluded) |
  | `duration_s` | float | full run time |
  | `state` | StringName | `&"running"`, `&"jammed"`, `&"paused"` |
  | `fix_prompt_key` | StringName | strings key to fix/restart while jammed (`ui.prompt.fix_drill`, `ui.prompt.restart_hack`), `&""` otherwise |

  Clients extrapolate a running device's progress between replicated snapshots. A Safe that shares its DrillPoint's
  runner (PO6-01) is listed once, under the drill point.
* **Objectives.** Each `objectives` row also carries `device_net_id: int`: the device serving that ACTIVE objective
  (matches a `devices[].net_id`), `-1` = none.
* **Pagers (D-114 §4, PO 2026-10-15).** `pagers[].time_left_s` is now always the **response window**: it freezes while
  anyone holds the answer. An early release with nobody else answering raises the alarm (default, S5.4); only with the
  opt-in `StealthTweak.pager_release_resumes = true` does the window resume from the frozen value (events v1.4
  `pager_answer_released`). `progress` (0..1) is the current answer hold (0 when nobody answers). It used to switch to the
  10 s answer countdown while answering; it no longer does. The service rows behind it (`PagerSystem.pager_entries()`,
  mirrored to clients by HeistNetSync) also carry `time_left` (window), `answer_left` (seconds left on the best current
  hold) and `progress`; `LocalHudModel.pagers` rows do **not** expose `answer_left` (derive it from `progress` if needed).

## v1.14 (D-114 §1/§4, PO6-03/PO6-08/PO6-20): device kinds and auto-restart, pager waypoint rows
ENV A provides (env/a-core 089d327a, 450b8ea0); ENV B consumes. Additive to v1.13.
* **Devices.** The full `LocalHudModel.devices` row (signal `devices_changed()`) is now
  `{net_id, kind, world_pos, progress, time_left_s, duration_s, state, fix_prompt_key, auto_restart_in_s}`:

  | Field | Type | Meaning |
  |---|---|---|
  | `kind` | StringName | v1.13 kinds plus `&"c4"` (an armed C4 fuse on a Safe) and `&"time_lock"` (a vault Safe's time lock); full set `drill`, `thermal`, `saw`, `hack`, `c4`, `time_lock` |
  | `world_pos` | Vector3 | panel anchor: the device raised `device_panel_up_m` 0.45 m and pushed `device_panel_out_m` 0.25 m out of the lock face, so the panel clears the safe door |
  | `state` | StringName | `&"running"`, `&"jammed"`, `&"paused"` (`c4` / `time_lock` rows are always `&"running"`) |
  | `fix_prompt_key` | StringName | as v1.13; `&""` for `c4` / `time_lock` |
  | `auto_restart_in_s` | float | seconds until a jammed device restarts itself (the `interaction.device_auto_restart_chance` roll at placement / per fix succeeded), `-1` when none is pending |

  Other fields are unchanged (`net_id`, `progress`, `time_left_s`, `duration_s`). Objective rows' `device_net_id` may now
  also point at a `c4` / `time_lock` row.
* **Pagers (PO6-20).** Each `pagers` row also carries `guard_net_id: int` (the paged guard's body) and `world_pos: Vector3`
  (where that body lies: the server's hips position from `PagerSystem.pager_entries()`, or the body root as a fallback,
  raised `pager_marker_up_m` **1.2 m**), for B's pager waypoint while the pager is live (D-114 §4). A dragged body moves
  the waypoint. Row: `{pager_id, time_left_s, answering, progress, guard_net_id, world_pos}`.

## v1.15 (PO6-17b): breach flash
`LocalHudModel.flashed_s: float` in the vitals group: seconds of breach-blast flash left on the local crew member
(from `CrewHealth.flashed_left`, replicated with the crew health props; up to 2.5 s at the blast, half at the stun-radius
edge). 0 = not flashed. B renders a white-out that fades with it; P may add a matching viewmodel/audio dull. The flash
interrupts a held interaction (A).

## v1.16: scoped ADS (P's FP scope overlay)
HUD model gains `scoped_ads: bool` and `scope_ring: Rect2` (canvas coordinates at the 1920x1080 stretch base, the space B's Controls lay out in, not window
pixels; the ring's bounding rect), written by ENV P while
the scope overlay is above its show threshold. ENV B moves text panels (device timers, the interaction prompt, hint strips,
first-time tips, assault banners) outside `scope_ring` while scoped; the ring leaves little room above or below it, so
the side margins are the place. Gameplay markers, detection chevrons, hit markers and subtitles stay where they are
(PD2 keeps them while scoped). No gadget on/off HUD hint: PD2 shows none.

## v1.17: detection rings and the investigating "?" (D-128)
`detection` rows gain an optional `state: StringName`: `&""` (meter only, as v1.16), `&"curious"` or
`&"investigating"` (guard_brain S3.4 AlertState). ENV A also emits rows at `value` 0 for observers in CURIOUS or
INVESTIGATING that are in view of, or within stealth range of, the tracked crew member, so the HUD can show "?" over a
guard checking a noise. Rows without `state` behave as v1.16. ENV B draws PD2's indicator from these rows: a ring over
each observer (2.15 m above `world_pos`, cameras 0.35 m) filling clockwise from 12 o'clock with "?" inside, turning into
a red "!" when detected, plus one crosshair arc per observer in its direction; colours white → orange (≥ 0.5) → red.
Off-screen observers get only the arc. It replaces the v1.x chevrons.

## v1.18: side objectives (B f3b6781f, P's DB-P1)
Objective data may carry `side: bool` (default false). The HUD objective caption shows the first ACTIVE main step; an
ACTIVE step with `side: true` gives way to any live main step (it still lists in the objectives panel). Not the same as
`optional` (casing and alternative steps carry that). Producer A (`add_objective` data in `*_mission.gd`: DB `cartel`;
GH `extra_bags` / `salon` / `display_cases`; any other bonus step), consumer B (caption). A also emits an objective's
state only on change (P saw `cartel -> ACTIVE` re-emitted on every data update).

## v1.19 (D-139 heist freshness, B 1622ac1f)
- Payday cash grid: line id `freshness` between `crew_alive` and `civilian_penalty`, caption "Heist freshness {pct}"
  (`ui.results.freshness`); the XP list has the same caption (`ui.results.xp.freshness`). Both hide at 0.
  A dim `FreshnessReason` label sits under the cash total.
- HeistSelect: `FreshnessNote` label under the contract pay, hidden at 0 %; static `freshness_note(heist_id, profile)`.
- Strings: `ui.freshness.badge` "{pct} %", `ui.freshness.reason_repeat` "Played {n}× in your last {memory} heists",
  `ui.freshness.reason_rotation` "Not played in {since} heists", `ui.heist_select.freshness`.
- D-140: the card's "N pagers" note shows only where the def cap is below StealthTweak's 4.

## v1.20: pocket ECM (D-161; B proposal)
- A: `LocalHudModel.pocket_ecm: Dictionary` = EcmSystem.pocket_state(local slot): `{}` when the local crew has no pocket ECM,
  else `{charges: int, max: int, recharge_left: float (s), active_left: float (s), mode: StringName &"" | &"jam" | &"feedback"}`.
  Signal `pocket_ecm_changed` on any field change (0.1 s snapping is fine).
- A: `LocalHudModel.throwable_id` reports `PerkHooks.throwable_id(crew)` (a deck's replacement throwable: Composure flask,
  Overlord injector, Hacker pocket ECM), not the raw `Loadout.throwable`.
- B: the throwable chip shows the pocket ECM glyph + charge count (dimmed at 0); caption "JAM {s} s" / "FEEDBACK {s} s" while
  active, "+1 in {s} s" while recharging, else hidden. Models without the field leave the HUD unchanged.

## v1.21: generic perk item (D-163; B proposal, A 36df6d56)
- A: `LocalHudModel.perk_item: Dictionary` = `{}` when the local deck has no perk item, else
  `{kind: StringName, charges: int, max: int, cooldown_left: float (s), active_left: float (s), partner_slot: int (-1 = none)}`
  from the replicated PerkItems service; signal `perk_item_changed`. Kinds today: &"pocket_ecm", &"smoke_bomb", &"gas_dispenser".
- `pocket_ecm` (v1.20) stays as an alias for one round, then B migrates to perk_item and the alias is removed.
- B: the throwable chip shows the item's glyph, charges and cooldown; Tag Team marks the partner's teammate panel "tagged".

## v1.22: perk item segments + mode (D-164; A 9c4622d6)
- `perk_item.segments: {count: int, size: float (fraction of max health)}`, present only while a Leech ampule window is active.
- `perk_item.mode: StringName` (&"" | &"jam" | &"feedback"), so the pocket ECM no longer needs the v1.20 `pocket_ecm` alias;
  B drops the alias in its next HUD push (v1.20's field is then removed).

