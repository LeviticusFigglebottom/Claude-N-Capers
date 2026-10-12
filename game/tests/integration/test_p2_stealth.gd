## P2 GATE: stealth complete (docs/roadmap.md P2 gate: "scripted ghost run on 3 seeds per heist; all
## S-rows of phase <= 2 tested"). Owner: LEAD.
##
## RESUME NOTES (D-077: keep current; a fresh agent resumes from here)
##   Done:  test_99_s_rows_phase_2_covered (coverage map of pd2_fidelity S-rows -> behaviour tests,
##          parsed from the doc at run time; fails listing uncovered rows; prints partial rows).
##          Harness + Night Deposit line written (test_01, seed 2001); Shadow Ledger not written yet.
##   State (2026-10-12): test_01 FAILS at the first step: "a quiet moment to take out the operator"
##          (_take_out_operator waited 240 s game time). Cause (my condition, not a game bug): it also
##          requires no NPC within 14 m straight-line of the operator, and the G7 corridor guards
##          (rover_ground, hall/basement guards using the stair) are always within 14 m of G3.
##   EXACT NEXT STEP: in _take_out_operator replace the 14 m straight-line rule with a navmesh path
##          length check (NavigationServer3D.map_get_path, > ~20 m) or drop it and rely on _watchers;
##          rerun `tools/ci/run_tests.sh integration test_p2_stealth.gd:test_01`; then fix gdlint
##          max-returns in _nd_line (split it), then pick seeds (resolver probe: sec_staffed, code as a
##          note), then write _ghost_sl (laptop -> keycard -> server reader -> cage code -> hack with
##          re-interacts on device_jammed -> 2 drives + laptop secured -> escape tag by variant).
##   Plan:  mask -> kill the camera operator from behind (pager answered, body bagged + hidden:
##          all cameras off, S8.2) -> objectives by teleport, each step only when no observer
##          (guard/civilian/live camera) can see the spot (_watchers), aborting a hold when a
##          detection meter on the bot rises -> laser grids crossed by WALKING through a gap/window
##          (never teleported across) -> bags to the secure zone -> escape -> heist_ended(success,
##          stealth) with no alarm_raised, no crew_detected, no laser_tripped.
##   Scratch: test_zz_probe.gd (untracked scouting probe; delete before the final commit).
extends TestCase

const FIDELITY_DOC: String = "docs/design/pd2_fidelity.md"

## Every S-row of phase <= P2 -> behaviour test functions ("dir/file.gd:test_name" under res://tests)
## that assert it. An empty list = uncovered (the gate fails and names the row).
const S_ROW_TESTS: Dictionary = {
	"S1.1": ["a/test_s1_casing_detection.gd:test_s1_1_unmasked_in_restricted_fills_at_casing_rate",
		"a/test_s1_casing_detection.gd:test_s1_1_unmasked_outside_restricted_stays_zero",
		"a/test_a1_02_crew_controller.gd:test_s1_1_casing_blocks_sprint_crouch_jump"],
	"S1.2": ["a/test_a1_02_crew_controller.gd:test_s1_2_mask_up_hold_is_irreversible",
		"a/test_s1_casing_detection.gd:test_s1_2_full_detection_force_masks"],
	"S1.4": ["a/test_s1_casing_detection.gd:test_s1_4_masked_in_public_is_detected",
		"a/test_a1_02_crew_controller.gd:test_s1_4_masked_can_sprint_crouch_jump"],
	"S1.5": ["a/test_s1_casing_detection.gd:test_s1_5_sprint_jump_behind_guard_stays_zero",
		"a/test_a1_02_crew_controller.gd:test_s1_5_movement_makes_no_noise"],
	"S2.1": ["a/test_s2_detection_meter.gd:test_s2_1_meter_starts_at_dr_fills_with_los_and_decays",
		"b/test_ui_hud.gd:test_detection_chevron_colors"],
	"S2.2": ["a/test_s2_detection_meter.gd:test_s2_2_fill_rate_formula_distance_and_angle",
		"a/test_s2_detection_meter.gd:test_s2_2_beyond_far_and_wall_no_fill",
		"a/test_s2_detection_meter.gd:test_s2_2_modifier_and_difficulty_scale_rate"],
	"S2.3": ["a/test_s2_detection_meter.gd:test_s2_3_dr_table_and_rates",
		"b/test_loadout_resolver.gd:test_detection_mult_table"],
	"S2.4": ["b/test_loadout_resolver.gd:test_curve_anchor_points",
		"b/test_loadout_resolver.gd:test_curve_bounds_and_monotonic",
		"b/test_concealment_bonus.gd:test_concealment_bonus_applies_after_weapon_cap"],
	"S2.5": ["a/test_s2_detection_meter.gd:test_s2_5_crouch_multiplies_rate",
		"a/test_s3_8_cameras.gd:test_s2_5_camera_ignores_crouch"],
	"S2.6": ["a/test_s8_1_cameras.gd:test_s8_1_detects_masked_crew_in_cone_not_outside",
		"a/test_s3_8_cameras.gd:test_s2_5_camera_ignores_crouch"],
	"S2.8": ["a/test_s1_casing_detection.gd:test_s1_4_masked_in_public_is_detected",
		"a/test_s1_casing_detection.gd:test_s1_1_civilians_never_fill_on_unmasked"],
	"S2.9": ["a/test_s2_9_marking.gd:test_s2_9_shout_marks_guard_for_crew_4_5_s",
		"a/test_s2_9_marking.gd:test_s2_9_camera_marked_8_s",
		"a/test_s2_9_marking.gd:test_s2_9_sixth_sense_marks_enemies_within_10_m_when_still"],
	"S3.1": ["a/test_s3_1_civilian_panic.gd:test_s3_1_spotted_civilian_runs_to_phone_and_calls",
		"a/test_s3_1_civilian_panic.gd:test_s3_1_shout_interrupts_call",
		"a/test_a1_06_civilians.gd:test_s3_1_no_phone_runs_to_guard"],
	"S3.2": ["a/test_s3_2_guard_cuffs.gd:test_s3_2_yell_pause_walk_cuff_then_radio_alarm",
		"a/test_s3_2_guard_cuffs.gd:test_s3_2_moving_beyond_1_7_m_makes_guard_open_fire",
		"a/test_s3_2_guard_cuffs.gd:test_s3_2_flag_off_keeps_p1_radio"],
	"S3.3": ["a/test_s3_3_guard_radio.gd:test_s3_3_spotted_radios_then_alarm",
		"a/test_s3_3_guard_radio.gd:test_s3_3_killing_guard_mid_call_cancels_alarm",
		"a/test_s3_3_guard_radio.gd:test_s3_3_domination_mid_call_cancels_alarm"],
	"S3.4": ["a/test_s3_4_guard_investigate.gd:test_s3_4_investigate_stimulus_curious_then_walks_to_it",
		"a/test_s3_4_guard_investigate.gd:test_s3_4_budget_expires_back_to_calm",
		"a/test_s3_4_guard_investigate.gd:test_s3_4_curious_escalates_to_alarm"],
	"S3.5": ["a/test_s8_1_cameras.gd:test_s3_5_real_camera_countdown_unstoppable_and_hud",
		"a/test_s3_8_cameras.gd:test_s3_5_camera_detection_starts_unstoppable_countdown",
		"a/test_s8_2_camera_operator.gd:test_s3_5_s8_2_running_countdown_survives_operator_death"],
	"S3.6": ["a/test_s3_6_guard_one_shot.gd:test_s3_6_calm_guard_dies_to_any_hit",
		"a/test_s3_6_guard_one_shot.gd:test_s3_6_curious_guard_dies_to_any_hit",
		"a/test_s3_6_guard_one_shot.gd:test_s3_6_alarmed_guard_survives_small_hit"],
	"S3.7": ["a/test_s3_7_misfire.gd:test_s3_7_body_shot_misfire_rate_about_10_percent",
		"a/test_s3_7_misfire.gd:test_s3_7_shotgun_kills_never_misfire",
		"a/test_s3_7_misfire.gd:test_s3_7_misfire_alerts_nearby_guard"],
	"S3.8": ["a/test_s3_8_cameras.gd:test_s3_8_camera_unmasked_only_in_restricted",
		"a/test_s1_casing_detection.gd:test_s1_4_masked_in_public_is_detected"],
	"S4.1": ["a/test_s4_stimuli_noise.gd:test_s4_1_corpse_in_view_is_noticed",
		"a/test_s4_stimuli_noise.gd:test_s4_1_preplaced_bag_ignored_until_moved",
		"a/test_s6_4_hostage_stimuli.gd:test_s6_4_guard_seeing_dominated_guard_raises_alarm"],
	"S4.2": ["a/test_s3_4_guard_investigate.gd:test_s3_4_ignored_stimulus_kind_does_nothing",
		"a/test_s9_devices_glass.gd:test_alarm_button_phone_and_suspicious_door",
		"a/test_a2_01_doors_nav.gd:test_a2_01_npc_opened_suspicious_door_is_a_stimulus"],
	"S4.3": ["a/test_s4_stimuli_noise.gd:test_s4_3_noise_radius_and_no_los_halving"],
	"S4.4": ["a/test_s3_8_cameras.gd:test_s4_4_camera_stimulus_kinds_and_deaf",
		"a/test_s8_1_cameras.gd:test_s4_4_camera_stimuli_alert_and_deaf"],
	"S5.1": ["a/test_s5_1_patrol_routes.gd:test_s5_1_routes_deterministic_per_seed_and_vary_across_seeds",
		"a/test_s5_1_patrol_routes.gd:test_s5_1_pauses_at_points_with_pause_range",
		"a/test_s5_1_patrol_routes.gd:test_s5_1_guard_walks_along_route"],
	"S5.2": ["a/test_s5_pagers.gd:test_s5_2_pager_starts_2_to_4_s_after_kill",
		"a/test_s5_pagers.gd:test_s5_2_answer_hold_10s_counts",
		"a/test_s5_pagers.gd:test_s5_2_dominated_guard_gets_a_pager"],
	"S5.3": ["a/test_s5_pagers.gd:test_s5_3_fifth_answer_raises_alarm_on_completion",
		"a/test_s5_pagers.gd:test_s5_3_fourth_answer_mercer_line"],
	"S5.4": ["a/test_s5_pagers.gd:test_s5_4_release_early_raises_alarm",
		"a/test_s5_pagers.gd:test_s5_4_juggle_two_answerers_no_alarm",
		"a/test_s5_pagers.gd:test_s5_4_first_completion_cancels_other_holder_without_alarm"],
	"S5.5": ["a/test_s5_pagers.gd:test_s5_5_timeout_raises_alarm"],
	"S5.6": ["a/test_s5_6_ecm_pager_delay.gd:test_s5_6_base_ecm_does_not_pause_pagers",
		"a/test_s5_6_ecm_pager_delay.gd:test_s5_6_pager_delay_pauses_window_during_jam"],
	"S5.7": [],
	"S6.1": ["a/test_s3_4_guard_investigate.gd:test_s3_4_corpse_stimulus_alarms",
		"a/test_s3_1_civilian_panic.gd:test_s3_1_noise_and_corpse_stimulus_panic",
		"a/test_s3_8_cameras.gd:test_s4_4_camera_stimulus_kinds_and_deaf"],
	"S6.2": ["a/test_s6_body_bags.gd:test_s6_2_bagging_requires_and_consumes_a_body_bag",
		"a/test_s6_2_body_bag_case.gd:test_s6_2_case_holds_3_and_respects_cap",
		"a/test_s6_2_body_bag_case.gd:test_s6_2_body_bags_extra_raises_cap"],
	"S6.3": ["a/test_s6_body_bags.gd:test_s6_3_carry_body_bag_is_heavy",
		"a/test_s6_body_bags.gd:test_s6_3_body_bag_in_body_hide_zone_is_never_noticed",
		"a/test_s6_body_bags.gd:test_s6_3_body_container_capacity"],
	"S6.4": ["a/test_s6_4_hostage_stimuli.gd:test_s6_4_guard_seeing_dominated_guard_raises_alarm",
		"a/test_s6_4_hostage_stimuli.gd:test_s6_4_guard_seeing_tied_civilian_raises_alarm",
		"a/test_s6_4_hostage_stimuli.gd:test_s6_4_civilian_seeing_dominated_guard_panics"],
	"S7.1": ["a/test_s7_shout_and_ties.gd:test_s7_1_shout_in_cone_at_10m_intimidates_while_casing",
		"a/test_s7_shout_and_ties.gd:test_s7_1_shout_within_6m_any_direction",
		"a/test_s7_shout_and_ties.gd:test_s7_1_timer_expiry_gets_up_and_reshout_resets"],
	"S7.2": ["a/test_s7_shout_and_ties.gd:test_s7_2_tie_intimidated_civilian",
		"a/test_s7_shout_and_ties.gd:test_s7_2_calm_civilian_cannot_be_tied",
		"a/test_s7_shout_and_ties.gd:test_s7_2_casing_crew_cannot_tie"],
	"S7.3": ["b/test_payout_calculator.gd:test_civilian_penalty_comes_out_of_spending",
		"b/test_ui_payday.gd:test_routine_totals_match_calculator"],
	"S7.4": ["a/test_s3_1_civilian_panic.gd:test_s3_1_spotted_civilian_runs_to_phone_and_calls",
		"a/test_a1_06_civilians.gd:test_s3_1_no_phone_runs_to_guard"],
	"S7.5": ["a/test_a1_06_civilians.gd:test_s7_5_idle_activity_and_wander"],
	"S8.1": ["a/test_s8_1_cameras.gd:test_s8_1_one_shot_destroy_disables_and_breaks",
		"a/test_s8_2_camera_operator.gd:test_s8_1_operator_dispatches_nearest_guard",
		"a/test_s8_1_cameras.gd:test_s8_1_titan_camera_survives"],
	"S8.2": ["a/test_s8_2_camera_operator.gd:test_s8_2_kill_operator_disables_all_cameras",
		"a/test_s8_2_camera_operator.gd:test_s8_2_dominate_operator_disables_cameras",
		"a/test_s8_2_camera_operator.gd:test_s8_2_room_staffed_variants"],
	"S8.4": ["a/test_s8_4_ecm.gd:test_s8_4_deploy_2s_and_duration_and_flashing",
		"a/test_s8_4_ecm.gd:test_s8_4_jams_cameras_but_not_started_countdown",
		"a/test_s8_4_ecm.gd:test_s8_4_ecms_chain_sequentially"],
	"S8.5": ["a/test_s8_4_ecm.gd:test_s8_5_ecm_on_keycard_reader_opens_doors"],
	"S9.1": ["a/test_a1_02_crew_controller.gd:test_s1_2_mask_up_hold_is_irreversible",
		"a/test_l2_survival.gd:test_l2_7_downed_cannot_revive_self_and_damage_interrupts"],
	"S9.2": ["a/test_s9_8_safes.gd:test_methods_gate_lockpick_code_c4_drill",
		"b/test_perk_behaviour.gd:test_prowler_shortens_interaction_hold_times"],
	"S9.3": ["a/test_s9_devices_glass.gd:test_s9_3_drill_place_jam_fix_finish_opens_safe",
		"a/test_s9_devices_glass.gd:test_s9_3_jams_deterministic_per_seed",
		"a/test_s9_devices_glass.gd:test_s9_3_auto_restart_and_silent_devices"],
	"S9.4": ["a/test_s9_4_saws.gd:test_saw_drill_point_opens_door_with_saw_noise_and_stimulus",
		"a/test_s9_4_saws.gd:test_safe_listing_saw_uses_a_saw"],
	"S9.6": ["a/test_s9_devices_glass.gd:test_s9_6_keycard_reader_opens_targets",
		"a/test_a1_03_prefab_shapes.gd:test_keycard_pickup_then_keycard_door"],
	"S9.7": ["a/test_s9_7_keypads_codes.gd:test_codes_registered_and_deterministic_per_seed",
		"a/test_s9_7_keypads_codes.gd:test_read_note_then_keypad_opens_code_door",
		"a/test_s9_7_keypads_codes.gd:test_code_note_variant_slot_places_configured_note"],
	"S9.8": ["a/test_s9_8_safes.gd:test_methods_gate_lockpick_code_c4_drill",
		"a/test_s9_8_safes.gd:test_time_lock_delays_opening",
		"a/test_s9_8_safes.gd:test_drill_finish_with_time_lock_and_size_durations"],
	"S9.9": ["a/test_s9_devices_glass.gd:test_s9_9_display_case_break_noise_and_take_loot",
		"a/test_s9_devices_glass.gd:test_s9_9_shooting_alarmed_case_raises_alarm"],
	"S9.10": ["a/test_s9_10_lasers.gd:test_static_grid_trips_alarm_even_while_casing",
		"a/test_s9_10_lasers.gd:test_timed_off_window_lets_crew_pass",
		"a/test_s9_10_lasers.gd:test_sweeping_beam_reaches_the_crew"],
	"S9.11": ["a/test_s9_devices_glass.gd:test_s9_11_windows_break_and_open",
		"a/test_s9_11_zipline_ladder.gd:test_ladder_climb_up_and_down_casing_blocked",
		"a/test_s9_11_zipline_ladder.gd:test_zipline_carries_bag_to_end_and_secures_it"],
	"S10.1": ["a/test_s10_loot_bags.gd:test_s10_1_sprint_and_jump_limits_per_weight",
		"a/test_s10_loot_bags.gd:test_s10_1_throw_distance_ordering",
		"a/test_s10_loot_bags.gd:test_s10_1_throw_distance_modifier"],
	"S10.1b": ["a/test_s10_1b_ladder_bag.gd:test_no_climb_with_bag_then_climb_after_dropping",
		"a/test_a3_09_bag_lift.gd:test_bags_ride_to_the_other_landing_and_back"],
	"S10.2": ["a/test_s10_loot_bags.gd:test_s10_2_throw_into_secure_zone_secures",
		"a/test_s10_loot_bags.gd:test_s10_2_bag_must_rest_in_zone"],
	"S10.3": ["a/test_a1_03_prefab_shapes.gd:test_small_loot_pickup",
		"a/test_s9_devices_glass.gd:test_s9_9_display_case_break_noise_and_take_loot"],
	"S10.4": ["b/test_payout_calculator.gd:test_golden_routine",
		"b/test_payout_calculator.gd:test_golden_brutal_pro_stealth",
		"b/test_content_data.gd:test_all_six_difficulties_exist_with_exact_multipliers"],
	"S11.2": ["a/test_a1_01_heist_runtime.gd:test_alarm_goes_loud_without_scene_change",
		"a/test_a1_05_security_officer.gd:test_s11_2_alarm_switches_guards_to_combat_and_approach",
		"a/test_a1_06_civilians.gd:test_s11_2_alarm_panics_civilians"],
	"S11.3": ["a/test_s11_3_stealth_only.gd:test_s11_3_stealth_only_alarm_fails_after_abort_line",
		"a/test_s11_3_stealth_only.gd:test_s11_3_loud_only_starts_loud"],
}

## Rows whose tests leave part of the "Our implementation" column unasserted (LEAD audit 2026-10-11).
## Reported, not failed: the gate's wording is "tested"; these are routed to the row owner.
const S_ROW_PARTIAL: Dictionary = {
	"S1.2": "force-mask on entering combat; 0.6 s / x0.4 local slow-mo",
	"S2.6": "camera min-time 2.0 s and DR scaling for cameras",
	"S3.8": "masked crew carrying a bag as a suspicious stimulus",
	"S4.1": "P2 kinds: saw within 10 m, sentries, hacking devices, ECM-feedback victims; per-kind ranges",
	"S4.2": "default suspicious_when_open=false door opened -> no stimulus; other ignored kinds",
	"S4.4": "cameras seeing bags, alerted NPCs, hostages, broken glass, drills outside view, open vaults",
	"S7.3": "real DifficultyDef civilian_kill_penalty values; ENV A HeistResult civilian-kill attribution",
	"S8.5": "ATM opened by ECM in 8 s",
	"S9.1": "cancel on > 0.5 m move / > 40 deg look-away; no_interrupt_on_damage",
	"S9.2": "a crew member lockpicking a door in 8 s",
	"S9.10": "ECM does not affect laser grids",
	"S9.11": "a player riding a zipline; crew using vents",
	"S10.1": "speed mults LIGHT/MEDIUM/VERY_HEAVY; thrown bag as an 18 m stimulus",
}

const ND: StringName = &"night_deposit"
const SL: StringName = &"shadow_ledger"
const DIFF: Enums.Difficulty = Enums.Difficulty.ROUTINE
const RISE_FRAMES: int = 3
## Run speed while the bot works / while it only waits (time lock, hack, heli).
const RUN_SCALE: float = 2.0
const WAIT_SCALE: float = 4.0
## A hold is abandoned (the bot steps away) once any observer's meter on the bot exceeds this.
const ABORT_METER: float = 0.3
## Attempts per step before the run gives up (each attempt waits for the spot to be unwatched).
const MAX_TRIES: int = 12
## Game seconds a step may wait for its spot to be unwatched.
const CLEAR_TIMEOUT_S: float = 240.0

var _rt: HeistRuntime = null
var _events: Array[Array] = []
var _conns: Array[Array] = []
var _t0: int = 0
var _max_meter: float = 0.0
var _detected: Array[String] = []
var _aborts: int = 0
var _crossings: int = 0


func before_each() -> void:
	Engine.time_scale = 1.0
	_events.clear()
	_detected.clear()
	_max_meter = 0.0
	_aborts = 0
	_crossings = 0
	_t0 = Time.get_ticks_msec()


func after_each() -> void:
	Engine.time_scale = 1.0
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
		print("[P2] %s: %.1f s wall" % [_current, float(Time.get_ticks_msec() - _t0) / 1000.0])
	_rt = null
	await wait_frames(2)


# --- Harness ------------------------------------------------------------------------------------------

func _launch(heist: StringName, seed_value: int) -> bool:
	_rt = await HeistLauncher.launch(heist, seed_value, DIFF, self, {"ai_teammates": 3})
	if _rt == null:
		fail("HeistLauncher.launch(%s, %d) returned null" % [heist, seed_value])
		return false
	var nav_ok: bool = await wait_until(func() -> bool: return BotUtil.nav_ready(_crew()), 10.0)
	assert_true(nav_ok, "navigation map ready")
	await wait_physics_frames(2)
	_listen_all([&"alarm_raised", &"heist_ended", &"laser_tripped", &"pager_started", &"pager_answered",
		&"pager_failed", &"body_bagged", &"body_discovered", &"loot_secured", &"item_picked_up",
		&"interaction_completed", &"cameras_loop_disabled", &"device_started", &"device_jammed",
		&"device_finished", &"civilian_fled"])
	var on_det: Callable = func(obs: Node, crew: Node) -> void:
		_detected.append("%s saw slot %d" % [obs.name, (crew as CrewController).slot])
	_rt.stealth.crew_detected.connect(on_det)
	_conns.append([_rt.stealth.crew_detected, on_det])
	var tick: Callable = func() -> void:
		if _rt != null and is_instance_valid(_rt) and _rt.stealth != null:
			_max_meter = maxf(_max_meter, _meter())
	get_tree().physics_frame.connect(tick)
	_conns.append([get_tree().physics_frame, tick])
	print("[P2] %s seed %d variants %s" % [heist, seed_value, _variant_line(_rt.variants)])
	return nav_ok


func _listen_all(tags: Array[StringName]) -> void:
	for tag: StringName in tags:
		var cb: Callable = func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			_events.append([tag, a, b, c])
		var sig: Signal = Signal(EventBus, tag)
		sig.connect(cb)
		_conns.append([sig, cb])


func _of(tag: StringName) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in _events:
		if e[0] == tag:
			out.append(e)
	return out


func _crew(slot: int = 0) -> CrewController:
	return _rt.crew_controller(slot) as CrewController


func _still() -> CrewIntent:
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = _crew().look_yaw
	i.look_pitch = _crew().look_pitch
	return i


## Highest detection meter any observer holds on the bot right now.
func _meter() -> float:
	var m: float = 0.0
	for o: Node3D in _observers():
		m = maxf(m, _rt.detection_value(o, 0))
	return m


func _observers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group(G.OBSERVER):
		if _rt.is_ancestor_of(n) and n is Node3D:
			out.append(n as Node3D)
	return out


func _failed() -> bool:
	return not _of(&"alarm_raised").is_empty() or not _detected.is_empty() or not _failures.is_empty()


## Observers that could see a crew member standing at `pos` (feet): live, within their range, inside
## their view (NPC sectors widened by 30 deg, an NPC closer than 3 m always counts) and with a clear
## vision ray to 1.0 m or 1.6 m. `ignore`: observers left out (the guard the bot stands behind).
func _watchers(pos: Vector3, ignore: Array = []) -> Array[String]:
	var out: Array[String] = []
	var presets: Dictionary = Tweak.stealth().observer_presets
	var space: PhysicsDirectSpaceState3D = _crew().get_world_3d().direct_space_state
	for o: Node3D in _observers():
		if ignore.has(o) or (o.has_method(&"can_observe") and not bool(o.call(&"can_observe"))):
			continue
		var cam: SecurityCamera = o as SecurityCamera
		var eye: Vector3 = o.call(&"eye_position")
		var fwd: Vector3 = o.call(&"look_forward")
		var far: float = 0.0
		var half: float = 0.0
		if cam != null:
			far = cam.range_m + 1.0
			half = deg_to_rad(cam.fov_deg * 0.5 + 5.0)
		else:
			var p: Dictionary = presets.get(o.get(&"detection_preset"), presets[&"guard"])
			far = float(p["far"]) + 2.0
			half = deg_to_rad(float(p["fov_deg"]) * 0.5 + 30.0)
		var target: Vector3 = pos + Vector3.UP
		var to: Vector3 = target - eye
		if to.length() > far:
			continue
		var close: bool = cam == null and _flat(o.global_position - pos) < 3.0
		if not close:
			var ang: float = fwd.angle_to(to) if cam != null else absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))
			if ang > half:
				continue
		var ex: Array[RID] = [_crew().get_rid()]
		if o is CollisionObject3D:
			ex.append((o as CollisionObject3D).get_rid())
		for h: float in [1.0, 1.6]:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, pos + Vector3.UP * h, StealthDirector.VISION_MASK, ex)
			if space.intersect_ray(q).is_empty():
				out.append(String(o.name))
				break
	return out


## Wait (time scaled) until nobody watches any of `spots`. False on timeout or a failed run.
func _await_clear(spots: Array, ignore: Array = [], timeout_s: float = CLEAR_TIMEOUT_S) -> bool:
	var ok: bool = await wait_until(func() -> bool:
		if _failed():
			return true
		for s: Variant in spots:
			if not _watchers(s as Vector3, ignore).is_empty():
				return false
		return true, timeout_s)
	if not ok:
		var who: Array[String] = []
		for s: Variant in spots:
			who.append_array(_watchers(s as Vector3, ignore))
		fail("spots %s never unwatched in %.0f s (watchers %s)" % [spots, timeout_s, who])
	return ok and not _failed()


## A safe standing spot nobody watches: the crew spawns first, then the secure / escape zones.
func _retreat() -> void:
	var cands: Array[Vector3] = []
	for n: Node in _rt.map.get_slots(G.PLAYER_SPAWN):
		cands.append((n as Node3D).global_position)
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if _rt.is_ancestor_of(n):
			var p: Variant = BotUtil.nav_point_in_zone(n as Area3D)
			if p != null:
				cands.append(p as Vector3)
	_rt.set_bot_intent(0, _still())
	for c: Vector3 in cands:
		if _watchers(c).is_empty():
			_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, c))
			await wait_physics_frames(2)
			return
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, cands[0]))
	await wait_physics_frames(2)


## Standing spot on the navmesh next to `prefab`'s UsePoint (else the prefab), within explicit reach.
func _stand_for(prefab: Node3D) -> Variant:
	var gp: GameplayPrefab = prefab as GameplayPrefab
	var at: Vector3 = gp.use_point.global_position if gp != null and gp.use_point != null else prefab.global_position
	for r: float in [0.4, 0.8, 1.2, 1.6]:
		var p: Variant = BotUtil.nav_point_near(prefab, at, r)
		if p != null:
			return p
	return null


## Hold interact on `target_id` (looking at `look_to`) until `done`; abandoned when a meter on the bot
## passes ABORT_METER. Returns 1 done, 0 abandoned / timed out.
func _hold(target_id: int, look_to: Vector3, done: Callable, timeout_s: float) -> int:
	var i: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), look_to)
	i.interact = true
	i.interact_target_net_id = target_id
	_rt.set_bot_intent(0, i)
	var aborted: Array[bool] = [false]
	await wait_until(func() -> bool:
		if done.call() or _failed():
			return true
		if _meter() > ABORT_METER:
			aborted[0] = true
			return true
		return false, timeout_s)
	_rt.set_bot_intent(0, _still())
	await wait_physics_frames(RISE_FRAMES)
	if aborted[0]:
		_aborts += 1
	return 1 if done.call() else 0


## One interaction step: wait until `stand` is unwatched, teleport there facing `look_to`, hold on
## `target_id` until `done`; step away and retry when watched. False after MAX_TRIES or a failure.
func _step(what: String, stand: Vector3, look_to: Vector3, target_id: int, done: Callable, hold_s: float,
		ignore: Array = []) -> bool:
	for t: int in range(MAX_TRIES):
		if done.call():
			return true
		if not await _await_clear([stand], ignore):
			return false
		_rt.teleport_crew(0, BotUtil.facing(stand, look_to))
		await wait_physics_frames(2)
		if await _hold(target_id, look_to, done, hold_s + 3.0) == 1:
			return true
		if _failed():
			break
		await _retreat()
	fail("%s: not done after %d tries (aborts %d)" % [what, MAX_TRIES, _aborts])
	return false


func _step_prefab(what: String, prefab: Node3D, done: Callable, hold_s: float) -> bool:
	var stand: Variant = _stand_for(prefab)
	if stand == null:
		fail("%s: no navmesh point next to %s" % [what, prefab.name])
		return false
	return await _step(what, stand as Vector3, prefab.global_position + Vector3.UP * 0.2,
		int(prefab.get(&"net_id")), done, hold_s)


func _mask_up() -> bool:
	var i: CrewIntent = _still()
	i.mask_up = true
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return _crew().masked, 5.0)
	_rt.set_bot_intent(0, _still())
	assert_true(ok, "bot masks up")
	return ok


func _press(i: CrewIntent) -> void:
	_rt.set_bot_intent(0, i)
	await wait_physics_frames(RISE_FRAMES)
	_rt.set_bot_intent(0, _still())


# --- Camera operator (S8.2, S5.2, S6.2/S6.3) ----------------------------------------------------------

## Kill the camera operator from behind with one suppressed headshot while nobody else sees him or the
## bot, answer his pager, bag the body and hide it: all cameras go off. No-op on an empty room.
func _take_out_operator() -> bool:
	var stations: Array[Node] = _rt.map.find_children("*", "CameraStation", true, false)
	if stations.is_empty() or not (stations[0] as CameraStation).staffed:
		print("[P2] security room empty: cameras stay live (avoided by _watchers)")
		return true
	var st: CameraStation = stations[0] as CameraStation
	var op: NpcBase = st.operator
	var shot: Variant = BotUtil.find_clear_point(op, 2.0, true, 1.65, true)
	if shot == null:
		fail("no clear firing point behind the operator")
		return false
	var at: Vector3 = (shot as Transform3D).origin
	# Nobody may see the bot, the body, or be near enough to reach it during the pager (12 s + 10 s).
	var quiet: bool = await wait_until(func() -> bool:
		if not _watchers(at, [op]).is_empty() or not _watchers(op.global_position, [op]).is_empty():
			return false
		for n: Node in _rt.npcs():
			if n != op and (n as Node3D).global_position.distance_to(op.global_position) < 14.0:
				return false
		return true, CLEAR_TIMEOUT_S)
	assert_true(quiet, "a quiet moment to take out the operator")
	if not quiet:
		return false
	_rt.teleport_crew(0, shot as Transform3D)
	await wait_physics_frames(2)
	var aim: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), op.head_position())
	aim.fire = true
	await _press(aim)
	var dead: bool = await wait_until(func() -> bool: return not op.alive, 1.0)
	assert_true(dead, "operator killed by a suppressed headshot (S3.6)")
	if not dead:
		return false
	var off: bool = await wait_until(func() -> bool: return st.cameras_off, 2.0)
	assert_true(off, "operator down: all cameras off (S8.2)")
	if not await _answer_pager(op):
		return false
	return await _hide_body(op)


func _answer_pager(guard: NpcBase) -> bool:
	var n0: int = _of(&"pager_answered").size()
	var started: bool = await wait_until(func() -> bool: return _of(&"pager_started").size() > n0, 6.0)
	assert_true(started, "pager_started after the kill (S5.2)")
	if not started:
		return false
	var stand: Variant = BotUtil.find_clear_point(guard, 1.0, true)
	if stand != null:
		_rt.teleport_crew(0, stand as Transform3D)
		await wait_physics_frames(2)
	var i: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), guard.global_position)
	i.interact = true
	i.interact_target_net_id = guard.net_id
	_rt.set_bot_intent(0, i)
	var ok: bool = await wait_until(func() -> bool: return _of(&"pager_answered").size() > n0 or _failed(),
		Tweak.interaction().pager_answer_s + 6.0)
	_rt.set_bot_intent(0, _still())
	await wait_physics_frames(RISE_FRAMES)
	assert_true(ok and _of(&"pager_answered").size() > n0, "pager answered (S5.2)")
	return ok and not _failed()


func _hide_body(body: NpcBase) -> bool:
	var n0: int = _of(&"body_bagged").size()
	var stand: Variant = BotUtil.find_clear_point(body, 1.0, true)
	if stand == null:
		fail("no spot next to the body")
		return false
	if not await _step("bag the body", (stand as Transform3D).origin, body.global_position, body.net_id,
			func() -> bool: return _of(&"body_bagged").size() > n0, Tweak.interaction().body_bag_s):
		return false
	var bag: LootBag = Ids.lookup(int(_of(&"body_bagged")[n0][2])) as LootBag
	assert_true(bag != null and bag.is_body_bag(), "body bag spawned (S6.2)")
	if bag == null:
		return false
	if not await _pick_up(bag):
		return false
	var zone: Area3D = _body_hide_zone()
	assert_true(zone != null, "map has a BODY_HIDE zone")
	if zone == null or not await _drop_into(zone):
		return false
	var hidden: bool = await wait_until(func() -> bool: return bag.hidden_from_stealth, 3.0)
	assert_true(hidden, "body bag hidden in %s (S6.3)" % zone.name)
	return hidden


func _body_hide_zone() -> Area3D:
	var any: Area3D = null
	for n: Node in get_tree().get_nodes_in_group(G.BODY_HIDE_ZONE):
		if _rt.is_ancestor_of(n):
			if not n.get_parent().has_method(&"store_bag"):
				return n as Area3D
			any = n as Area3D if any == null else any
	return any


# --- Bags ---------------------------------------------------------------------------------------------

func _pick_up(bag: LootBag) -> bool:
	var p: Variant = BotUtil.nav_point_near(bag, bag.global_position, 1.2)
	if p == null:
		fail("no navmesh point next to bag %s" % bag.name)
		return false
	return await _step("pick up %s" % bag.name, p as Vector3, bag.global_position, bag.net_id,
		func() -> bool: return _crew().carried_bag == bag, Tweak.interaction().bag_loot_s)


## Bag one from `spawn` (LootSpawn). Returns the carried bag or null.
func _bag_from(spawn: LootSpawn) -> LootBag:
	var n0: int = spawn.remaining
	if not await _step_prefab("bag %s" % spawn.name, spawn,
			func() -> bool: return _crew().is_carrying_bag() and spawn.remaining < n0, Tweak.interaction().bag_loot_s):
		return null
	return _crew().carried_bag as LootBag


## A stand spot from which a bag dropped forward lands inside `zone` with no geometry in between.
func _drop_spot(zone: Area3D) -> Array:
	var tw: LootTweak = LootTweak.get_default()
	var center: Vector3 = BotUtil.drop_point(zone)
	var space: PhysicsDirectSpaceState3D = zone.get_world_3d().direct_space_state
	for d: float in [0.3, 0.6, 0.9, 1.2, 1.6, 2.0, 2.5]:
		for deg: int in range(0, 360, 30):
			var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(float(deg)))
			var p: Variant = BotUtil.nav_point_near(zone, center - dir * d, 0.3)
			if p == null:
				continue
			var stand: Vector3 = p
			var drop: Vector3 = stand + dir * tw.drop_forward_m + Vector3.UP * tw.drop_height_m
			if not ZoneUtil.contains(zone, drop + Vector3.UP * tw.zone_probe_up_m):
				continue
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(stand + Vector3.UP * 0.6, drop, 1 | 2)
			if not space.intersect_ray(q).is_empty():
				continue
			return [stand, stand + dir]
	return []


## Carry the held bag into `zone` (unwatched) and drop it there.
func _drop_into(zone: Area3D) -> bool:
	var spot: Array = _drop_spot(zone)
	if spot.is_empty():
		fail("no spot to drop a bag into %s" % zone.get_path())
		return false
	if not await _await_clear([spot[0]]):
		return false
	_rt.teleport_crew(0, BotUtil.facing(spot[0], spot[1]))
	await wait_physics_frames(2)
	var d: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), (spot[1] as Vector3) + Vector3.UP * 0.3)
	d.drop_bag = true
	await _press(d)
	assert_false(_crew().is_carrying_bag(), "bag dropped into %s" % zone.name)
	return not _crew().is_carrying_bag()


func _secure_zone() -> Area3D:
	for n: Node in get_tree().get_nodes_in_group(G.LOOT_SECURE_ZONE):
		if _rt.is_ancestor_of(n):
			return n as Area3D
	return null


## Drop the held bag in the active escape's SECURE_LOOT zone and wait for loot_secured.
func _secure_held() -> bool:
	var zone: Area3D = _secure_zone()
	assert_true(zone != null, "an active SECURE_LOOT zone")
	var n0: int = _of(&"loot_secured").size()
	if zone == null or not await _drop_into(zone):
		return false
	var ok: bool = await wait_until(func() -> bool: return _of(&"loot_secured").size() > n0, 5.0)
	assert_true(ok, "bag secured (S10.2)")
	return ok


# --- Laser grids (S9.10): crossed on foot, never teleported across ----------------------------------

## Walk from one side of `grid` to the other (`to_far`: towards +local z). Picks a crossing line on
## the navmesh: beside the grid (a bypass gap), or through it crouched under static beams, or through
## it in a beam-free window (timed_off / sweeping), predicted from the grid's own pattern parameters.
## Returns the far-side standing point (null on failure).
func _cross(grid: LaserGrid, to_far: bool) -> Variant:
	var plan: Dictionary = _crossing_plan(grid, to_far)
	if plan.is_empty():
		fail("no crossing line through %s (pattern %s)" % [grid.name, grid.pattern])
		return null
	var a: Vector3 = plan["from"]
	var b: Vector3 = plan["to"]
	var crouch: bool = plan["crouch"]
	for t: int in range(MAX_TRIES):
		if not await _await_clear([a, b]):
			return null
		_rt.teleport_crew(0, BotUtil.facing(a, b))
		await wait_physics_frames(2)
		var speed: float = (Tweak.crew().crouch_speed if crouch else Tweak.crew().walk_speed) * (0.55 if _crew().is_carrying_bag() else 1.0)
		var window_s: float = a.distance_to(b) / speed * 1.5 + 0.4
		var cx: float = float(plan["x"])
		var open: bool = await wait_until(func() -> bool:
			return _failed() or _meter() > ABORT_METER or _grid_clear(grid, cx, window_s), 30.0)
		if _failed():
			return null
		if not open or _meter() > ABORT_METER:
			await _retreat()
			continue
		var walk: CrewIntent = BotUtil.look_at_intent(_crew().eye_position(), b + Vector3.UP * _crew().eye_height())
		walk.move = Vector2(0.0, 1.0)
		walk.crouch = crouch
		_rt.set_bot_intent(0, walk)
		var n: Vector3 = grid.global_basis.z * (1.0 if to_far else -1.0)
		var arrived: bool = await wait_until(func() -> bool:
			return _failed() or (_crew().global_position - b).dot(n) > -0.15, window_s * 2.0 + 2.0)
		_rt.set_bot_intent(0, _still())
		await wait_physics_frames(2)
		if _failed():
			return null
		assert_true(arrived, "walked across %s (%s)" % [grid.name, plan["how"]])
		_crossings += 1
		return _crew().global_position
	fail("could not cross %s" % grid.name)
	return null


## {from, to, x, crouch, how} for a crossing line, or {} if none.
func _crossing_plan(grid: LaserGrid, to_far: bool) -> Dictionary:
	var o: Vector3 = grid.global_position
	var bx: Vector3 = grid.global_basis.x.normalized()
	var bz: Vector3 = grid.global_basis.z.normalized() * (1.0 if to_far else -1.0)
	var half: float = grid.size_m.x * 0.5
	var crouch_top: float = 1.2 + 0.1
	var low_beam: float = INF
	if grid.pattern != LaserGrid.PATTERN_SWEEPING:
		for i: int in range(grid.beam_total()):
			low_beam = minf(low_beam, grid.beam_offset(i))
	var cands: Array[Dictionary] = []
	var x: float = -half - 1.5
	while x <= half + 1.5:
		var a: Variant = BotUtil.nav_point_near(grid, o + bx * x - bz * 1.0, 0.25)
		var b: Variant = BotUtil.nav_point_near(grid, o + bx * x + bz * 1.0, 0.25)
		x += 0.25
		if a == null or b == null:
			continue
		var space: PhysicsDirectSpaceState3D = grid.get_world_3d().direct_space_state
		var blocked: bool = false
		for h: float in [0.4, 1.0]:
			for side: float in [-0.35, 0.35]:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					(a as Vector3) + Vector3.UP * h + bx * side, (b as Vector3) + Vector3.UP * h + bx * side, 1 | 2)
				blocked = blocked or not space.intersect_ray(q).is_empty()
		if blocked:
			continue
		var cx: float = x - 0.25
		var beside: bool = absf(cx) > half + 0.45
		var how: String = ""
		var crouch: bool = false
		if beside:
			how = "bypass gap"
		elif grid.pattern == LaserGrid.PATTERN_STATIC:
			if low_beam > crouch_top:
				how = "crouched under static beams"
				crouch = true
			else:
				continue
		else:
			how = "beam-free window (%s)" % grid.pattern
		cands.append({"from": a, "to": b, "x": cx, "crouch": crouch, "how": how, "beside": beside})
	if cands.is_empty():
		return {}
	# Prefer the bypass gap, then lines nearest the grid's edge (longest sweep gaps).
	cands.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if bool(p["beside"]) != bool(q["beside"]):
			return bool(p["beside"])
		return absf(float(p["x"])) > absf(float(q["x"])))
	return cands[0]


## True when no beam of `grid` will touch a crossing line at local x `cx` (capsule +-0.5 m) during the
## next `window_s` seconds (sampled every 0.05 s from the grid's pattern parameters).
func _grid_clear(grid: LaserGrid, cx: float, window_s: float) -> bool:
	if grid.tripped:
		return true
	if absf(cx) > grid.size_m.x * 0.5 + 0.45:
		return true
	var t: float = 0.0
	while t <= window_s:
		var ts: float = grid.time_s + t
		if grid.pattern == LaserGrid.PATTERN_TIMED_OFF:
			if fposmod(ts, grid.period_s) < grid.period_s - clampf(grid.off_s, 0.0, grid.period_s):
				return false
		elif grid.pattern == LaserGrid.PATTERN_SWEEPING:
			var n: int = grid.beam_total()
			for i: int in range(n):
				var u: float = fposmod(ts / maxf(grid.period_s, 0.01) + float(i) / float(maxi(n, 1)), 1.0)
				var bxv: float = (1.0 - absf(2.0 * u - 1.0) - 0.5) * grid.size_m.x
				if absf(bxv - cx) < 0.55:
					return false
		t += 0.05
	return true


# --- Escape -------------------------------------------------------------------------------------------

func _escape(tag: StringName) -> bool:
	var tagged: Array[Node] = _rt.find_by_tag(tag)
	assert_false(tagged.is_empty(), "escape zone tagged %s" % tag)
	if tagged.is_empty():
		return false
	var esc: EscapeZone = tagged[0] as EscapeZone
	Engine.time_scale = WAIT_SCALE
	var arrived: bool = await wait_until(func() -> bool: return esc.has_arrived() or _failed(), 120.0)
	Engine.time_scale = RUN_SCALE
	assert_true(arrived and esc.has_arrived(), "escape %s active and arrived" % tag)
	if not arrived or _failed():
		return false
	var inside: Variant = BotUtil.nav_point_in_zone(esc.zone)
	if inside == null:
		fail("no navmesh point inside %s" % esc.name)
		return false
	if not await _await_clear([inside]):
		return false
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, inside as Vector3))
	var ended: bool = await wait_until(func() -> bool: return not _of(&"heist_ended").is_empty(), 10.0)
	assert_true(ended, "heist_ended after reaching the escape")
	return ended


## The gate's verdict on a finished run.
func _check_ghost(min_bags: int) -> void:
	assert_eq(_of(&"alarm_raised"), [] as Array[Array], "no alarm raised")
	assert_eq(_detected, [] as Array[String], "the bot was never fully detected")
	assert_eq(_of(&"laser_tripped"), [] as Array[Array], "no laser tripped")
	assert_eq(_of(&"body_discovered"), [] as Array[Array], "no body discovered")
	assert_ne(_rt.phase, Enums.HeistPhase.LOUD, "never went loud")
	assert_true(_of(&"pager_answered").size() <= 4, "pager answers within the cap")
	if not _of(&"heist_ended").is_empty():
		var r: Dictionary = _of(&"heist_ended")[0][1]
		assert_true(bool(r.get("success", false)), "heist_ended(success)")
		assert_true(bool(r.get("stealth", false)), "stealth success")
		assert_true((r.get("loot", []) as Array).size() >= min_bags, "HeistResult lists >= %d secured bags" % min_bags)
	print("[P2] ghost: heist time %.0f s, max meter on the bot %.2f, holds abandoned %d, laser crossings %d, pagers %d, bags %d" % [
		_rt.heist_time_s, _max_meter, _aborts, _crossings, _of(&"pager_answered").size(), _of(&"loot_secured").size()])


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _variant_line(v: Dictionary) -> String:
	var keys: Array = v.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in keys:
		parts.append("%s=%s" % [k, v[k]])
	return ", ".join(parts)


# --- Night Deposit -------------------------------------------------------------------------------------

func test_01_night_deposit_ghost_a() -> void:
	await _ghost_nd(2001)


## Night Deposit ghost (docs/design/heists/night_deposit.md Stealth): operator -> keycard -> code note
## -> vault gate (keycard) -> lasers on foot -> time-lock code -> hold -> 4 vault bags secured -> escape.
func _ghost_nd(seed_value: int) -> void:
	if not await _launch(ND, seed_value):
		return
	Engine.time_scale = RUN_SCALE
	if not await _mask_up() or not await _take_out_operator():
		_check_ghost(0)
		return
	var ok: bool = await _nd_line()
	if ok:
		await _escape(&"escape_boat" if (_rt.variants.get(&"escape", []) as Array).has(&"esc_boat_quay") else &"escape_van")
	_check_ghost(4)
	var m: HeistMission = _rt.mission
	for oid: StringName in [&"keycard", &"code", &"vault_gate", &"time_lock", &"time_lock_wait", &"secure", &"escape"]:
		assert_eq(m.objective_state(oid), Enums.ObjectiveState.COMPLETED, "objective %s completed" % oid)


func _nd_line() -> bool:
	var m: HeistMission = _rt.mission
	var card: KeycardPickup = _rt.find_by_tag(&"keycard")[0] as KeycardPickup
	if not await _step_prefab("keycard", card, func() -> bool: return card.taken, Tweak.interaction().item_pickup_s):
		return false
	var notes: Array[Node] = _rt.find_by_tag(&"code_note")
	assert_false(notes.is_empty(), "a code note to read (code_on_manager seeds are not used)")
	if notes.is_empty():
		return false
	var note: CodeNote = notes[0] as CodeNote
	var reg: CodeRegistry = CodeRegistry.of(_rt)
	if not await _step_prefab("code note", note, func() -> bool: return reg.is_known(note.code_group), Tweak.interaction().read_note_s):
		return false
	var gate: Door = _rt.find_by_tag(&"vault_gate")[0] as Door
	if not await _step_prefab("vault gate", gate, func() -> bool: return gate.is_open or not gate.locked, Tweak.interaction().keycard_s):
		return false
	assert_eq(m.objective_state(&"vault_gate"), Enums.ObjectiveState.COMPLETED, "vault_gate objective")
	var grid: LaserGrid = _rt.find_by_tag(&"antechamber_lasers")[0] as LaserGrid
	var panel: Keypad = _rt.find_by_tag(&"time_lock")[0] as Keypad
	if await _cross(grid, true) == null:
		return false
	if not await _step_prefab("time-lock panel", panel, func() -> bool: return panel.used, Tweak.interaction().keypad_s):
		return false
	assert_eq(m.objective_state(&"time_lock_wait"), Enums.ObjectiveState.ACTIVE, "time lock running")
	if await _cross(grid, false) == null:
		return false
	await _retreat()
	var door: Door = _rt.find_by_tag(&"vault_door")[0] as Door
	Engine.time_scale = WAIT_SCALE
	var open: bool = await wait_until(func() -> bool: return door.is_open or _failed(), 200.0)
	Engine.time_scale = RUN_SCALE
	assert_true(open and door.is_open, "the time lock opens the vault door")
	if not open or _failed():
		return false
	var spawns: Array[LootSpawn] = []
	for n: Node in _rt.find_by_tag(&"vault_loot"):
		spawns.append(n as LootSpawn)
	var secured: int = 0
	for ls: LootSpawn in spawns:
		while ls.remaining > 0 and secured < 4:
			if await _cross(grid, true) == null:
				return false
			if await _bag_from(ls) == null:
				return false
			if await _cross(grid, false) == null:
				return false
			if not await _secure_held():
				return false
			secured += 1
	assert_eq(secured, 4, "4 vault bags secured")
	return secured == 4 and not _failed()


# --- 99 S-row coverage --------------------------------------------------------------------------------

## "All S-rows of phase <= 2 tested": every S-row of pd2_fidelity.md whose phase column names P1 or P2
## (mixed rows like "P1 (simple) / P2 (cuffs)" count) must map to >= 1 existing behaviour test function.
## The row list is parsed from the doc, so a new S-row without a mapping fails here.
func test_99_s_rows_phase_2_covered() -> void:
	var rows: Array[String] = _doc_rows_phase_le_2()
	assert_true(rows.size() >= 50, "parsed the S-rows of %s (%d rows of phase <= 2)" % [FIDELITY_DOC, rows.size()])
	var uncovered: Array[String] = []
	var missing_fn: Array[String] = []
	var scripts: Dictionary = {}
	for row: String in rows:
		var tests: Array = S_ROW_TESTS.get(row, [])
		if tests.is_empty():
			uncovered.append(row)
			continue
		for ref: String in tests:
			var parts: PackedStringArray = ref.split(":")
			var path: String = "res://tests/" + parts[0]
			if not scripts.has(path):
				scripts[path] = _method_names(path)
			if not (scripts[path] as Array).has(parts[1]):
				missing_fn.append("%s -> %s" % [row, ref])
	for row: Variant in S_ROW_TESTS:
		assert_true(rows.has(String(row)), "mapped row %s is an S-row of phase <= 2 in the doc" % row)
	var partial: Array[String] = []
	for row: String in rows:
		if S_ROW_PARTIAL.has(row):
			partial.append("%s (%s)" % [row, S_ROW_PARTIAL[row]])
	print("[P2] S-rows phase <= 2: %d, covered %d (of which partial %d), uncovered %d" % [
		rows.size(), rows.size() - uncovered.size(), partial.size(), uncovered.size()])
	for p: String in partial:
		print("[P2]   partial: %s" % p)
	assert_eq(missing_fn, [] as Array[String], "mapped test functions exist")
	assert_eq(uncovered, [] as Array[String], "S-rows of phase <= 2 without a behaviour test")


## S-row ids whose phase column (last column) mentions P1 or P2.
func _doc_rows_phase_le_2() -> Array[String]:
	var out: Array[String] = []
	var path: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(FIDELITY_DOC)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		fail("cannot read %s" % path)
		return out
	var re: RegEx = RegEx.create_from_string("P(\\d)")
	while not f.eof_reached():
		var line: String = f.get_line()
		if not line.begins_with("| S"):
			continue
		var cols: PackedStringArray = line.split("|")
		if cols.size() < 3:
			continue
		var id: String = cols[1].strip_edges()
		var phase: String = cols[cols.size() - 2]
		var lo: int = 99
		for m: RegExMatch in re.search_all(phase):
			lo = mini(lo, int(m.get_string(1)))
		if lo <= 2:
			out.append(id)
	return out


func _method_names(path: String) -> Array[String]:
	var out: Array[String] = []
	var s: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
	if s == null:
		return out
	for m: Dictionary in s.get_script_method_list():
		out.append(String(m["name"]))
	return out
