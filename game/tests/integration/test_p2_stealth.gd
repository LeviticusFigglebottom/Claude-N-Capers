## P2 GATE: stealth complete (docs/roadmap.md P2 gate: "scripted ghost run on 3 seeds per heist; all
## S-rows of phase <= 2 tested"). Owner: LEAD.
##
## RESUME NOTES (D-077: keep current; a fresh agent resumes from here)
##   Done:  test_99_s_rows_phase_2_covered (coverage map of pd2_fidelity S-rows -> behaviour tests,
##          parsed from the doc at run time; fails listing uncovered rows; prints partial rows).
##   Next:  ghost runs test_01..06 (night_deposit / shadow_ledger x 3 Routine seeds, sec_staffed).
##          Plan: mask -> kill the camera operator from behind (pager answered, body bagged + hidden:
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
