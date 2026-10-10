# Deployables + ECM (ENV A, A2-03 / A2-06)

Services under HeistRuntime (created in `_create_services`):

| Service | Class | Rows |
|---|---|---|
| `&"deployables"` | `DeployableSystem` (deployable_system.gd) | L2.11, S6.2, S1.1 |
| `&"ecm"` | `EcmSystem` (ecm_system.gd) | S8.4, S8.5, S8.6, S5.6 |

Numbers: `game/systems/tweak/deployable_tweak.tres` (`DeployableTweak.data()`). ENV B's
`DeployableDef` wins; `fallback_defs` cover ids not shipped yet (`deployable.ecm`, `deployable.fak`).

## Deploying
`intent.deploy` rising edge, held `deploy_time_s x deploy.deploy_speed_mult` (ECM 2 s, FAK 1 s,
others 2 s). Not while casing (S1.1) or out of NORMAL. Lands `place_forward_m` in front on the floor
(ray down). Count = `count + deploy.extra.<kind>` (+ `stealth.ecm_extra` for ECMs); uses =
`uses x deploy.capacity_mult.<kind>`. HUD: `crew.weapons.deployable_id / deployable_count`
(`CrewWeapons.set_deployable`, synced to a remote owner).

## Placed prefab
`res://systems/prefabs/deployable/deployable.tscn`, class `DeployablePrefab` (common prefab shape:
`Visual`, `UsePoint`, `Interactable`; group `G.DEPLOYABLE`; `net_id`). Exports `kind`, `deployable_id`
plus the common interaction exports. Visual = `DeployableDef.model`, else a box placeholder (`Body`).

| kind | Interactable kind | Effect |
|---|---|---|
| doctor_bag | `use_doctor_bag` | full heal + downs reset, 2 uses |
| fak | `use_fak` | +150 health (params.heal), 1 use, no down reset |
| ammo_bag | `use_ammo_bag` | shared 400 % pool, takes only what is missing |
| body_bag_case | `take_body_bag` | +1 body bag up to the cap, holds 3 |
| ecm | `ecm_feedback` | S8.6 feedback (built into every ECM, D-038; `stealth.ecm_feedback` is deprecated and ignored) |

## ECM
`is_jamming()`, `time_left()`, `is_flashing()` (last 8 s), `queued_count()`, `pager_delay_active()`,
static `phones_jammed()`. While jamming every `SecurityCamera` is `set_suppressed(&"ecm", true)`;
the S3.5 countdown in StealthDirector keeps running. Civilians cannot complete phone calls and
`Phone.call_police` is a no-op; alarm buttons and pagers are untouched. A second ECM queues.
Events `ecm_started(net_id, duration)` (when the jam starts), `ecm_ended`, `ecm_feedback_triggered` [R].
Feedback: 15 m, 6 s `NpcBase.stun()` of ENEMY NPCs (Phantom immune), `alarm` noise in stealth,
4 min recharge before a retrigger (`stealth.ecm_feedback_retrigger`).
`stealth.ecm_opens_doors`: an ECM deployed while aiming at a keycard reader is consumed and calls
`KeycardReader.open_by_ecm()` after 4 s. `stealth.ecm_pager_delay`: PagerSystem pauses the window of
pagers started during such a jam.
