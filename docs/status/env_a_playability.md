# ENV A playability issue list (real input vs bot shortcuts)

Owner: ENV A. Written 2026-10-12 ~17:50 ET by **code reading only** on env/a-core fb517093
(Godot not installed on the box: nothing below has been run; every item is a hypothesis to confirm with a
real-input test per D-076). Severity: **H** breaks play, **M** feels wrong / confusing, **L** polish.
Scope: ENV A-owned paths (tools/ci/owners.json: game/systems/** minus player/, fp_viewmodel*, crew_tweak.*).

## 1. Stealth / detection / guard AI
| # | Sev | Issue | Evidence (code) | Needs |
|---|-----|-------|-----------------|-------|
| PP-A-1 | H | **S5.8 domination window is 1.5 s with no player-facing cue.** The window opens in `GuardBrain._on_crew_spotted` (the "!" moment), but nothing in hud_model/anim reads `dominate_window_left`; a human gets no prompt/telegraph and must also aim within a 20° half-cone at 15 m (`ShoutSystem.guard_target_for`, aim from `crew.aim_direction()`). Bots call the API directly; humans will almost always miss it. | guard_brain.gd:616-618, shout_system.gd:142-162, stealth_tweak.gd:179-183 | HUD hint (LocalHudModel field + B prompt string), check shout key path from PlayerInput → server uses the server-side aim; real-input test: walk into view, press shout. |
| PP-A-2 | M | S5.8 window only opens when the guard was not ALARMED/COMBAT, and `_begin_alarm` runs right after on the same call; confirm the guard's radio/pager timeline leaves the 1.5 s usable (domination must cancel the radio call, `dominate()` sets DOMINATED). Also verify `dominate_window_left` is server-only (clients' shout goes via intent RPC; no replication needed if the check is server-side). | guard_brain.gd:479-500, 616-622 | Two-process test: client shouts at a spotting guard. |
| PP-A-3 | H | **S1.1 casing pickups not implemented**: `stealth.casing_can_pickup_items` exists in modifier_keys and in B's plain_sight skill, but nothing in game/systems reads it, so a player with the skill still can't grab small loot while casing. | modifier_keys.gd:24; no consumer in game/systems | Gate in InteractionSystem/LootManager `casing_allowed` path + test. |
| PP-A-4 | M | Casing detection (S1.1/S2.8) is tuned on bot positions; real players linger, strafe and peek. The "within 3 m outside PUBLIC" and ×0.35 fill need a hand-play check at doorways/zone edges (zone boundary flicker could pulse the meter). Casing → alarm STEALTH hop is ENV P's (P1-02) but the alarm side (StealthDirector state change) is mine; coordinate. | stealth/* | Joint test with P1-02. |
| PP-A-5 | M | **S8.3 camera loop is only a hook**: `CameraStation.loop_requested` is emitted, nobody listens; `InteractionTweak.camera_loop_s = 5.0` vs spec 25 s (modifier_keys text says 20 s). A Light Fingers player sees a prompt that does nothing. | camera_station.gd:25,254-256; interaction_tweak.gd:31 | Implement per-camera loop (one at a time per crew) via `SecurityCamera.set_suppressed`, fix the 25 s value + key text (key text is LEAD's contracts file → ask). |

## 2. Combat / damage
| # | Sev | Issue | Evidence | Needs |
|---|-----|-------|----------|-------|
| PP-A-6 | M | **L3.3 pellet headshots trust the client's claimed `zone`.** `_apply_hit` checks distance/target tolerance/LOS but never re-validates HEAD vs BODY; `pellet_headshots` then upgrades every pellet on that target. Fine for honest co-op but a client with lag/misaligned hitboxes (remote NPC interpolation) will get or lose headshots inconsistently. | combat_system.gd:62,125-160 | Server-side head-zone sanity check (head bone/height tolerance) or accept & document. |
| PP-A-7 | M | `claim_target_tolerance_m` / `claim_distance_tolerance_m` were tuned with bots that stand still. Real strafing + client interpolation of NPCs may reject legit hits ("my shots don't register"). | combat_system.gd:_apply_hit | Real-input loopback test with moving NPC; log rejection reasons in PerfStats/debug HUD. |
| PP-A-8 | H | **L2.1 regen**: `defense.health_regen_per_sec` is declared but has no consumer in CrewHealth (base no-regen is tested by test_l2_1_no_health_regen). Skills/perks that grant regen silently do nothing. | modifier_keys.gd:80; no consumer | CrewHealth tick: regen fraction × max while not downed, server-side, replicated with existing health sync; test. |
| PP-A-9 | M | **S2.7 DR loud targeting range not implemented** (no `ai_target_range` anywhere). Police engage at a fixed range regardless of DR, so low-DR players get sniped across maps / high-DR cannot be engaged far. | no symbol in game/systems | `ai_target_range = lerp(80,180,(DR−3)/72)` in NpcGunner/PoliceBrain target pick; test at both ends. |
| PP-A-10 | L | Spread/recoil use shared GameRng streams (`&"spread"`, `&"recoil"`) consumed by the local client; harmless (claims carry results) but means GameRng streams diverge between peers by design. See §3. | crew_weapons.gd:524-587 | Document. |

## 3. Net / drop-in / RNG
| # | Sev | Issue | Evidence | Needs |
|---|-----|-------|----------|-------|
| PP-A-11 | M | **GameRng client seeding**: clients call `GameRng.begin_run(run_seed)` in `_start_replica`, which clears streams, so a client has the same seed but **not the same stream positions** as the host (especially drop-in). Anything a client rolls locally that should match the host (cosmetic or gameplay) will differ. | heist_runtime.gd:221, game_rng.gd:11-14 | Audit client-side `GameRng.stream()` callers; either keep all gameplay rolls server-only (assert) or ship stream positions in the bring-up. |
| PP-A-12 | H | **HeistDropIn `full` + `Net.was_kicked`** policy: the handoff lists them as lost local work; Net.was_kicked exists in core, REASON_FULL in B's DropInService, but the host-side policy needs re-verifying on this tree with a real second client (two-process). | net.gd:217; drop_in_service.gd:42 | Redo/verify + loopback test. |
| PP-A-13 | M | Not-replicated state from QA-20 notes: placed deployables, known codes, pre-plan drops and **interaction progress bars on remote clients** — a joining or remote human sees a teammate drilling with no bar. Re-check what A3-07 covered. | status 2026-10-10 notes | Audit + fix list. |

## 4. Queue items and what each needs
- **S2.7** DR targeting range: implement formula in police target acquisition; tweak keys; test DR 3 vs 75 (≈1 h).
- **S1.1** casing pickup: consumer for `stealth.casing_can_pickup_items` on small loot/items; HUD "Suspicious actions not allowed" still for the rest; test with real walk-up + interact (≈1 h).
- **L2.1** regen: CrewHealth consumer for `defense.health_regen_per_sec`, not while downed/custody; test (≈45 min).
- **S8.3** camera loop: listen to `loop_requested`, loop one camera per crew for 25 s, fix tweak 5.0 → 25.0, ask LEAD about the 20 s key text (≈1 h).
- **S9.5 / A5-03** shaped charges + C4: `interaction.shaped_charge` and trip-mine counts exist in B data, but no trip-mine-as-charge interaction or prefab `charges_required` consumer exists; Safe already has a `c4` method. Open question from the 2026-10-11 handoff (shaped charges vs C4 split) needs a LEAD ruling before coding (≈2 h after ruling).

## 5. Not verified (needs Godot)
Everything above. The local S5.8 and L3.3 tests (test_s5_8_guard_domination, test_l3_3_pellet_headshot) are present
but have not been run on fb517093.
