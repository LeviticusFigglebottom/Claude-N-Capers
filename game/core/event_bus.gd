## Global bus for cross-system gameplay FACTS (already happened). Owner: LEAD.
## Contract: docs/contracts/events.md (v1). Signal signatures change only via contract update.
##
## Rules:
## - Emitted on the SERVER by the owning system (see "emitter" column in events.md).
## - Entities are referenced by net_id (int, see Ids), peers by peer_id (int), crew slots by
##   crew_slot (int 0..3; AI teammates have crew slots but no peer).
## - Facts marked [R] in events.md are relayed to clients by the emitter via Net.replicate_event().
## - Never use these signals as commands.
extends Node

# --- Heist lifecycle ---------------------------------------------------------
signal heist_loaded(heist_id: StringName, run_seed: int, variants: Dictionary)
signal heist_phase_changed(old_phase: int, new_phase: int)  # Enums.HeistPhase
signal alarm_raised(reason: StringName, source_net_id: int)
signal objective_updated(objective_id: StringName, state: int, data: Dictionary)  # Enums.ObjectiveState
signal heist_ended(result: Dictionary)  # see events.md "HeistResult"

# --- Crew --------------------------------------------------------------------
signal crew_member_joined(crew_slot: int, peer_id: int, is_ai: bool)
signal crew_member_left(crew_slot: int)
signal crew_masked(crew_slot: int)
signal crew_downed(crew_slot: int, downs_used: int)
signal crew_revived(crew_slot: int, by_crew_slot: int)
signal crew_custody(crew_slot: int)
signal crew_traded(crew_slot: int, hostage_net_id: int)
signal crew_tased(crew_slot: int, by_net_id: int)
signal crew_tase_ended(crew_slot: int)
signal crew_cloaker_downed(crew_slot: int, by_net_id: int)
signal crew_cuffed(crew_slot: int, by_net_id: int)
signal crew_uncuffed(crew_slot: int, by_crew_slot: int)  # -1 = freed themselves

# --- Detection / stealth -----------------------------------------------------
signal detection_progress(observer_net_id: int, crew_slot: int, value: float, kind: int)  # Enums.ObserverKind
signal npc_alert_state_changed(npc_net_id: int, old_state: int, new_state: int)  # Enums.AlertState
signal camera_disabled(camera_net_id: int, reason: StringName)
signal cameras_loop_disabled(by_net_id: int)  # camera operator neutralised: all cameras off
signal pager_started(pager_id: int, guard_net_id: int)
signal pager_answer_started(pager_id: int, crew_slot: int)
signal pager_answered(pager_id: int, crew_slot: int, answered_total: int)
## events v1.4 (D-114 §4): opt-in StealthTweak.pager_release_resumes only: the last answerer let go early and the
## response window resumes, no alarm (default: early release = pager_failed(released) + alarm).
signal pager_answer_released(pager_id: int, crew_slot: int)
signal pager_failed(pager_id: int, reason: StringName)
signal body_bagged(body_net_id: int, bag_net_id: int, crew_slot: int)
signal body_discovered(body_net_id: int, by_npc_net_id: int)
signal ecm_started(ecm_net_id: int, duration: float)
signal ecm_ended(ecm_net_id: int)
signal ecm_feedback_triggered(ecm_net_id: int)

# --- NPCs / civilians --------------------------------------------------------
signal civilian_intimidated(npc_net_id: int, crew_slot: int)
signal civilian_tied(npc_net_id: int, crew_slot: int)
signal civilian_fled(npc_net_id: int)
signal civilian_killed(npc_net_id: int, crew_slot: int)
signal guard_dominated(npc_net_id: int, crew_slot: int)
signal hostage_count_changed(count: int)

# --- Interaction -------------------------------------------------------------
signal interaction_started(interactable_net_id: int, crew_slot: int, kind: StringName)
signal interaction_cancelled(interactable_net_id: int, crew_slot: int)
signal interaction_completed(interactable_net_id: int, crew_slot: int, kind: StringName)
signal device_started(device_net_id: int, kind: StringName, duration: float)  # drill/saw/hack
signal device_jammed(device_net_id: int)
signal device_restarted(device_net_id: int, crew_slot: int)
signal device_finished(device_net_id: int)
signal item_picked_up(item_id: StringName, crew_slot: int)  # keycard, crowbar, code note...
signal glass_broken(net_id: int, position: Vector3)
signal laser_tripped(net_id: int)

# --- Loot ----------------------------------------------------------------------
signal loot_spawned(bag_net_id: int, loot_id: StringName)
signal loot_picked(bag_net_id: int, crew_slot: int)
signal loot_dropped(bag_net_id: int, crew_slot: int, thrown: bool)
signal loot_secured(bag_net_id: int, loot_id: StringName, value: int)
signal small_loot_taken(value: int, crew_slot: int)

# --- Combat --------------------------------------------------------------------
signal damage_applied(victim_net_id: int, attacker_net_id: int, info: Dictionary)  # DamageInfo dict
signal npc_killed(npc_net_id: int, killer_net_id: int, info: Dictionary)
signal special_spawned(npc_net_id: int, special_type: StringName)
signal weapon_fired(shooter_net_id: int, weapon_id: StringName, suppressed: bool, position: Vector3)

# --- Loud director -------------------------------------------------------------
signal assault_phase_changed(phase: int, wave_index: int)  # Enums.AssaultPhase
signal captain_arrived(npc_net_id: int)
signal captain_retreated(npc_net_id: int)
## PO6-17 (D-114 §5) RNG assault events [R]: AssaultEventRunner (A), host. `kind` = AssaultEventsTweak.KINDS
## (&"turret_van", &"heli", &"breach"); `net_id` = the event's dynamic entity (van / heli / breach).
signal assault_event_started(kind: StringName, net_id: int, position: Vector3)
signal assault_event_ended(kind: StringName, net_id: int)

# --- Presentation hooks (consumed by audio/UI/voice) ---------------------------
signal voice_line_requested(speaker: StringName, line_id: StringName, context: Dictionary)
signal audio_cue_requested(cue_id: StringName, position: Vector3, source_net_id: int)
# --- Presentation-only, emitted locally on EVERY peer (impact_fx.md 1.0, D-105); never replicated themselves.
## One per hitscan ray/pellet/melee hit. `end` = impact or max range (normal ZERO, surface &"" on a miss).
## flags: bit0 suppressed, bit1 first-person shooter on this peer, bit2 headshot, bit3 penetrated.
signal shot_fx(origin: Vector3, end: Vector3, normal: Vector3, surface: StringName, weapon_class: StringName,
		shooter_net_id: int, flags: int)
signal explosion_fx(position: Vector3, radius: float, kind: StringName)
## D-163: a Sicario smoke cloud started (every peer; presentation only, C's VfxDirector).
signal smoke_cloud_fx(position: Vector3, radius: float, duration_s: float)
## D-163: a Tag Team pair formed (active = true) or ended (every peer; presentation only).
signal crew_tether_fx(a_slot: int, b_slot: int, active: bool)
## D-113 blood FX (FX-only, [R]): flesh hit after damage_applied (crew: health hits only, not armour).
signal blood_hit(victim_net_id: int, point: Vector3, direction: Vector3, normal: Vector3, strength: float, headshot: bool,
		exit_point: Vector3, victim_kind: StringName)
## D-113 (FX-only, [R]): NPC death starts it (stops when bagged); crew down starts it (stops on revive / custody).
signal bleed_changed(body_net_id: int, bleeding: bool, position: Vector3, rate: float)
## shot_fx flag bits (impact_fx.md §2).
const SHOT_FX_SUPPRESSED: int = 1
const SHOT_FX_FIRST_PERSON: int = 2
const SHOT_FX_HEADSHOT: int = 4
const SHOT_FX_PENETRATED: int = 8
const SHOT_FX_STRONG: int = 16  ## flesh hit above the strong-hit rule (class or damage); VFX scales blood (D-113)
