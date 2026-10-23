# gdlint:disable=max-public-methods
## ENV C audio: P1 cue registry completeness, stream loading, buses, CuePlayer fact mapping and
## MusicDirector stem selection (simulated EventBus facts, headless; checks state, not output).
extends TestCase

const P1_CUES: Array[StringName] = [
	&"cue.detect_tick", &"cue.detect_full", &"cue.npc_suspicious", &"cue.pager_beep", &"cue.pager_radio",
	&"cue.alarm_bell", &"cue.mask_on", &"cue.glass_break", &"cue.drill_loop", &"cue.drill_jam",
	&"cue.drill_done", &"cue.bag_pickup", &"cue.bag_throw", &"cue.bag_secure", &"cue.weapon_pistol_fire",
	&"cue.weapon_pistol_fire_suppressed", &"cue.weapon_rifle_fire", &"cue.reload_pistol", &"cue.reload_rifle",
	&"cue.dry_fire", &"cue.hitmarker", &"cue.headshot", &"cue.police_siren_far", &"cue.assault_start",
	&"cue.crew_downed", &"cue.revive",
	# D-026 pistol foley (ENV B viewmodel)
	&"cue.weapon_pistol_mag_out", &"cue.weapon_pistol_mag_in", &"cue.weapon_pistol_slide_release",
]
## D-034 weapon families (ENV B anim_sets): fire, suppressed fire and reload/action foley.
const FAMILY_CUES: Array[StringName] = [
	&"cue.weapon_smg_fire", &"cue.weapon_smg_fire_suppressed", &"cue.weapon_smg_mag_out", &"cue.weapon_smg_mag_in",
	&"cue.weapon_smg_bolt", &"cue.weapon_rifle_fire", &"cue.weapon_rifle_fire_suppressed",
	&"cue.weapon_rifle_mag_out", &"cue.weapon_rifle_mag_in", &"cue.weapon_rifle_bolt",
	&"cue.weapon_shotgun_fire", &"cue.weapon_shotgun_fire_suppressed", &"cue.weapon_shotgun_pump",
	&"cue.weapon_shotgun_shell_in", &"cue.weapon_lmg_fire", &"cue.weapon_lmg_fire_suppressed",
	&"cue.weapon_lmg_mag_out", &"cue.weapon_lmg_mag_in", &"cue.weapon_lmg_bolt", &"cue.weapon_sniper_fire",
	&"cue.weapon_sniper_fire_suppressed", &"cue.weapon_sniper_mag_out", &"cue.weapon_sniper_mag_in",
	&"cue.weapon_sniper_bolt",
]
## QA-15 device cues (ENV A): one-shots on the World bus.
const DEVICE_CUES: Array[StringName] = [
	&"cue.keypad_accept", &"cue.c4_armed", &"cue.c4_explode", &"cue.time_lock_start", &"cue.time_lock_done",
	&"cue.laser_trip", &"cue.zipline_attach",
]
## QA-28 / D-049: P3 special tells (Enemies bus) and new prefab cues (World bus).
const SPECIAL_CUES: Array[StringName] = [
	&"cue.phantom_hum", &"cue.phantom_charge", &"cue.stinger_windup", &"cue.stinger_arc", &"cue.longshot_report",
	&"cue.bulwark_bang", &"cue.wrecker_roar", &"cue.wrecker_step", &"cue.wrecker_plate_crack", &"cue.corpsman_heal",
	&"cue.brandt_arrival", &"cue.aegis_pulse",
]
const PREFAB_CUES: Array[StringName] = [
	&"cue.bag_lift_start", &"cue.bag_lift_arrive", &"cue.hack_start", &"cue.hack_interrupt", &"cue.hack_done",
	&"cue.escape_arrive",
]
## B4-18 armory batches 2 + 3 (anim_sets revolver, break_action, lever, bow, crossbow, launcher,
## flamethrower, saw, minigun).
const ARMORY_CUES: Array[StringName] = [
	&"cue.weapon_revolver_fire", &"cue.weapon_revolver_cylinder_open", &"cue.weapon_revolver_eject",
	&"cue.weapon_revolver_speedloader_in", &"cue.weapon_revolver_cylinder_close", &"cue.weapon_break_action_fire",
	&"cue.weapon_break_action_open", &"cue.weapon_break_action_eject", &"cue.weapon_break_action_shell_in",
	&"cue.weapon_break_action_close", &"cue.weapon_lever_fire", &"cue.weapon_lever_cycle", &"cue.weapon_bow_draw",
	&"cue.weapon_bow_fire", &"cue.weapon_bow_impact", &"cue.weapon_crossbow_fire", &"cue.weapon_crossbow_load",
	&"cue.weapon_launcher_fire", &"cue.weapon_launcher_reload", &"cue.weapon_launcher_explode",
	&"cue.weapon_flamethrower_ignite", &"cue.weapon_flamethrower_fire", &"cue.weapon_flamethrower_stop",
	&"cue.weapon_saw_rev", &"cue.weapon_saw_cut", &"cue.weapon_minigun_spin_up", &"cue.weapon_minigun_fire",
	&"cue.weapon_minigun_spin_down",
]
const ARMORY_LOOPS: Array[StringName] = [
	&"cue.weapon_flamethrower_fire", &"cue.weapon_saw_rev", &"cue.weapon_saw_cut", &"cue.weapon_minigun_fire",
]
## QA-36 (audio_cues v1.2: police breach, thermite burn) and throwables (audio_cues v1.3, D-073).
const HAZARD_CUES: Array[StringName] = [&"cue.door_breach", &"cue.burn_warning"]
## PO6-17 RNG assault events (ENV A runtime requests them via audio_cue_requested): 3D one-shots on Enemies.
const ASSAULT_EVENT_CUES: Array[StringName] = [
	&"cue.assault_van_arrive", &"cue.assault_van_park", &"cue.assault_turret_deploy", &"cue.assault_turret_destroyed",
	&"cue.assault_heli_arrive", &"cue.assault_heli_leave", &"cue.assault_breach_warning",
]
const ASSAULT_EVENT_LOOPS: Array[StringName] = [&"cue.assault_van_engine", &"cue.assault_heli_rotor"]
const THROWABLE_CUES: Array[StringName] = [
	&"cue.throwable_pin", &"cue.throwable_frag", &"cue.throwable_concussion", &"cue.throwable_incendiary",
	&"cue.throwable_knife_hit", &"cue.throwable_knife_hit_hard", &"cue.throwable_incendiary_fire",
]
const THROWABLE_LOOPS: Array[StringName] = [&"cue.throwable_incendiary_fire"]
## impact_fx.md 1.0 §1/§3 (D-105, PO-8): one impact cue per surface id, cue.impact_<surface>.
const IMPACT_SURFACES: Array[StringName] = [
	&"concrete", &"brick", &"plaster", &"tile", &"wood", &"metal", &"glass", &"fabric", &"dirt", &"water",
	&"flesh", &"armor", &"shield",
]
const LOOPS: Array[StringName] = [
	&"cue.pager_beep", &"cue.pager_radio", &"cue.alarm_bell", &"cue.drill_loop", &"cue.police_siren_far",
]
## D-117: per-heist ambience beds (heist docs' Audio/lighting), CueEmitter-owned map loops.
const AMBIENCE_BEDS: Array[StringName] = [
	&"cue.amb_glasshouse_interior", &"cue.amb_street_dusk",
	&"cue.amb_bank_night_interior", &"cue.amb_harbor_night",
	&"cue.amb_shadow_ledger_interior", &"cue.amb_rooftop_rain",
	&"cue.amb_cold_store", &"cue.amb_dockside_fog",
	&"cue.amb_gallery_gala", &"cue.amb_art_store", &"cue.amb_uptown_night",
	&"cue.amb_bank_hall_day", &"cue.amb_bank_boh", &"cue.amb_vault", &"cue.amb_city_afternoon",
	&"cue.amb_skyway_street", &"cue.amb_underpass", &"cue.amb_diner", &"cue.amb_site",
]
## D-117 §7: every built heist has its own music track. Shadow Ledger is stealth-only.
const HEIST_MUSIC: Array[StringName] = [&"glasshouse", &"night_deposit", &"shadow_ledger", &"dockside_burn",
		&"gallery_night", &"ostrander_federal", &"rolling_thunder"]
## Heist tracks whose map does not place its Audio node yet.
const HEIST_MUSIC_MAP_PENDING: Array[StringName] = []
## C4-03: the safehouse cues whose cues.tres rows ENV B adds (cue rows go to B); generated and committed by C
## (tools/audiogen/cues_safehouse.py). Empty: B's rows landed (env/b-content ba2fc327, round 285).
const CUE_ROWS_PENDING: Array[StringName] = []
## RT-C2 / audio_cues v1.9 (QC-85): the convoy-ambush one-shots and the freight train, 3D on the World bus.
const RT_CUES: Array[StringName] = [&"cue.convoy_approach", &"cue.convoy_brake", &"cue.mixer_ram",
		&"cue.signal_click", &"cue.truck_doors_open", &"cue.freight_train_pass"]
const ALL_STEMS: Array[StringName] = [&"stealth", &"control", &"anticipation", &"assault", &"fade"]
const BUSES: Array[StringName] = [&"Music", &"SFX", &"Weapons", &"Enemies", &"World", &"UI", &"Voice", &"Ambience"]
## PO-14 registry coverage scan (test_every_cue_referenced_in_code_is_registered).
const CODE_ROOTS: Array[String] = ["res://systems", "res://world", "res://content", "res://core"]
const CUE_LITERAL: String = "\"(cue\\.[a-z0-9_]*[a-z0-9])\""

var _reg: AudioCueRegistry = null


func before_all() -> void:
	_reg = load("res://world/audio/cues.tres") as AudioCueRegistry


func after_all() -> void:
	_reg = null
	AudioCueLib.clear_cache()
	await wait_frames(3)  # let the audio server drop stopped playbacks before exit


func test_registry_has_every_p1_cue() -> void:
	assert_true(_reg != null, "cues.tres loads as AudioCueRegistry")
	if _reg == null:
		return
	for id: StringName in P1_CUES:
		assert_true(_reg.has_cue(id), "registry has %s" % id)
	assert_true(_reg.has_cue(&"cue.alarm_bell_glasshouse"), "glasshouse alarm variant")
	assert_true(_reg.has_cue(&"cue.alarm_bell_ostrander_federal"), "ostrander_federal two-tone bank bell (OF-C2)")


func test_weapon_family_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in FAMILY_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_eq(c.bus, &"Weapons", "%s bus" % id)
		assert_false(c.loop, "%s one-shot" % id)
		assert_true(c.positional, "%s positional" % id)
		var want: int = 3 if String(id).ends_with("_fire") or String(id).ends_with("_suppressed") else 2
		assert_true(c.streams.size() >= want, "%s has >= %d variations" % [id, want])
	assert_false(_reg.has_cue(&"cue.weapon_shotgun_mag_out"), "shotgun loads shells, no mag cues")


func test_device_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in DEVICE_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_eq(c.bus, &"World", "%s bus" % id)
		assert_false(c.loop, "%s one-shot" % id)
		assert_true(c.positional, "%s positional" % id)
	var boom: AudioCueDef = _reg.get_cue(&"cue.c4_explode")
	if boom != null:
		assert_true(boom.streams.size() >= 3, "c4_explode variations")
		assert_true(boom.max_distance >= 150.0, "c4_explode carries far")
	var player: CuePlayer = _make_player()
	EventBus.laser_tripped.emit(11)
	assert_eq(player.last_cue, &"cue.laser_trip", "laser_tripped maps to laser_trip")
	EventBus.interaction_completed.emit(12, 0, &"keypad")
	assert_eq(player.last_cue, &"cue.keypad_accept", "keypad completion beeps")
	player.queue_free()


func test_special_and_prefab_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in SPECIAL_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c != null:
			assert_eq(c.bus, &"Enemies", "%s bus" % id)
	for id: StringName in PREFAB_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c != null:
			assert_eq(c.bus, &"World", "%s bus" % id)
	for id: StringName in [&"cue.phantom_hum", &"cue.stinger_arc", &"cue.aegis_pulse"]:
		assert_true(_reg.get_cue(id) != null and _reg.get_cue(id).loop, "%s loops" % id)
	assert_true(_reg.get_cue(&"cue.longshot_report").max_distance >= 200.0, "longshot carries 200+ m")
	assert_eq(_reg.get_cue(&"cue.escape_arrive").streams.size(), 3, "van / boat / heli variants (random fallback)")
	for id: StringName in [&"cue.escape_arrive_van", &"cue.escape_arrive_boat", &"cue.escape_arrive_heli"]:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null and c.streams.size() == 1, "%s is one fixed stream" % id)
		if c != null:
			assert_eq(c.bus, &"World", "%s bus" % id)
			assert_true(c.max_distance >= 150.0, "%s carries far" % id)
	var player: CuePlayer = _make_player()
	EventBus.device_started.emit(77, &"hack", 30.0)
	assert_eq(player.last_cue, &"cue.hack_start")
	assert_false(player.is_loop_active(&"device_77"), "hack has no loop")
	EventBus.device_jammed.emit(77)
	assert_eq(player.last_cue, &"cue.hack_interrupt")
	EventBus.device_finished.emit(77)
	assert_eq(player.last_cue, &"cue.hack_done")
	EventBus.captain_arrived.emit(88)
	assert_eq(player.last_cue, &"cue.aegis_pulse")
	assert_true(player.is_loop_active(&"captain_88"), "aegis loop while captain is present")
	EventBus.captain_retreated.emit(88)
	assert_false(player.is_loop_active(&"captain_88"), "aegis loop stops on retreat")
	player.queue_free()


func test_armory_batch_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in ARMORY_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_true(c.positional, "%s positional" % id)
		assert_eq(c.loop, ARMORY_LOOPS.has(id), "%s loop flag" % id)
	for id: StringName in [&"cue.weapon_bow_fire", &"cue.weapon_bow_draw", &"cue.weapon_crossbow_fire",
			&"cue.weapon_bow_fire_suppressed", &"cue.weapon_crossbow_fire_suppressed"]:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c.max_distance <= 15.0 and c.volume_db <= -6.0, "%s is quiet / short range" % id)
	assert_true(_reg.get_cue(&"cue.weapon_revolver_fire").streams.size() >= 3, "revolver variations")
	for base: StringName in [&"cue.weapon_bow_fire", &"cue.weapon_crossbow_fire"]:
		var sup: AudioCueDef = _reg.get_cue(StringName(String(base) + "_suppressed"))
		assert_true(sup != null, "%s_suppressed exists (silent-weapon fallback)" % base)
		if sup != null:
			assert_true(sup.volume_db < _reg.get_cue(base).volume_db, "%s_suppressed is softer" % base)
	# every suppressed fallback the armory can reach (anim_sets with suppressor slots) must exist
	for fam: String in ["pistol", "smg", "rifle", "shotgun", "lmg", "sniper", "lever", "bow", "crossbow"]:
		assert_true(_reg.has_cue(StringName("cue.weapon_%s_fire_suppressed" % fam)), "%s suppressed cue" % fam)
	var player: CuePlayer = _make_player()
	var akimbo: WeaponDef = WeaponDef.new()
	akimbo.anim_set = &"akimbo"
	assert_eq(player.weapon_fire_cue(&"x", false, akimbo), &"cue.weapon_pistol_fire", "akimbo reuses pistol")
	player.queue_free()


func test_assault_event_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in ASSAULT_EVENT_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_true(c.positional, "%s positional" % id)
		assert_false(c.loop, "%s is a one-shot (requested unowned, PO6-07)" % id)
		assert_eq(c.bus, &"Enemies", "%s bus" % id)
	for id: StringName in ASSAULT_EVENT_LOOPS:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null and c.loop and c.positional, "%s 3D loop" % id)
	var w: AudioCueDef = _reg.get_cue(&"cue.assault_event_warning")
	assert_true(w != null and not w.positional and w.bus == &"UI" and w.cooldown_s >= 3.0, "2D UI warning sting")


## RT-C2: the Rolling Thunder convoy cues and the freight train are 3D one-shots on the World bus, each a single stream of a sane length.
func test_rolling_thunder_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in RT_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_true(c.positional, "%s positional" % id)
		assert_false(c.loop, "%s one-shot" % id)
		assert_eq(c.bus, &"World", "%s World bus" % id)
		assert_eq(c.streams.size(), 1, "%s one stream" % id)
		var len_s: float = c.streams[0].get_length()
		assert_true(len_s >= 0.3 and len_s <= 18.5, "%s length %.2f s" % [id, len_s])
	var approach: AudioCueDef = _reg.get_cue(&"cue.convoy_approach")
	assert_true(approach != null and approach.max_distance >= 150.0, "convoy approach carries across the junction")
	# v1.9: the freight train is its own long one-shot (A holds it during a Phantom charge), not part of the bed.
	var train: AudioCueDef = _reg.get_cue(&"cue.freight_train_pass")
	if train != null:
		assert_true(train.streams[0].get_length() >= 15.0, "freight train pass is long (%.1f s)" % train.streams[0].get_length())
		assert_true(train.max_distance >= 150.0, "freight train carries 150 m")


func test_breach_burn_and_throwable_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in HAZARD_CUES + THROWABLE_CUES:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_true(c.positional, "%s positional (3D)" % id)
		assert_eq(c.loop, THROWABLE_LOOPS.has(id), "%s loop flag" % id)
	for id: StringName in [&"cue.door_breach", &"cue.burn_warning", &"cue.throwable_frag",
			&"cue.throwable_concussion", &"cue.throwable_incendiary", &"cue.throwable_incendiary_fire"]:
		var c: AudioCueDef = _reg.get_cue(id)
		if c != null:
			assert_eq(c.bus, &"World", "%s bus" % id)
	for id: StringName in [&"cue.door_breach", &"cue.throwable_frag", &"cue.throwable_knife_hit",
			&"cue.throwable_knife_hit_hard"]:
		var c: AudioCueDef = _reg.get_cue(id)
		if c != null:
			assert_true(c.streams.size() >= 2, "%s variations" % id)
	var frag: AudioCueDef = _reg.get_cue(&"cue.throwable_frag")
	if frag != null:
		assert_true(frag.max_distance >= 120.0, "frag carries far")
	for id: StringName in [&"cue.throwable_pin", &"cue.throwable_knife_hit", &"cue.throwable_knife_hit_hard"]:
		var c: AudioCueDef = _reg.get_cue(id)
		if c != null:
			assert_true(c.max_distance <= 15.0, "%s is short range" % id)
	var burn: AudioCueDef = _reg.get_cue(&"cue.burn_warning")
	if burn != null and burn.streams.size() > 0:
		var len_s: float = burn.streams[0].get_length()
		assert_true(absf(len_s - 5.0) < 0.1, "burn_warning is 5 s (got %.2f)" % len_s)
	if burn != null:
		assert_eq(burn.streams.size(), 3, "cue.burn_warning has 3 variations (audio_cues v1.2)")


## cue.impact_<surface>: 3D one-shots on the World bus, >= 3 variations, short (<= 0.4 s), shorter
## range than gunfire, never louder than a gunshot in the mix.
func test_impact_cues() -> void:
	if _reg == null:
		skip("no registry")
		return
	for surface: StringName in IMPACT_SURFACES:
		var id: StringName = StringName("cue.impact_%s" % surface)
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "registry has %s" % id)
		if c == null:
			continue
		assert_eq(c.bus, &"World", "%s bus" % id)
		assert_true(c.positional, "%s positional (3D)" % id)
		assert_false(c.loop, "%s one-shot" % id)
		assert_true(c.streams.size() >= 3, "%s has >= 3 variations" % id)
		assert_true(c.max_distance >= 15.0 and c.max_distance <= 60.0, "%s range %.0f m" % [id, c.max_distance])
		assert_true(c.volume_db <= 0.0, "%s sits under gunfire" % id)
		for s: AudioStream in c.streams:
			if s != null:
				assert_true(s.get_length() <= 0.401, "%s stream is short (%.3f s)" % [id, s.get_length()])
	var player: CuePlayer = _make_player()
	player.play_cue(&"cue.impact_concrete", Vector3(1, 0, 2))
	assert_eq(player.last_cue, &"cue.impact_concrete", "impact plays at a world position")
	player.queue_free()


func test_every_stream_loads_with_length() -> void:
	if _reg == null:
		skip("no registry")
		return
	var ids: Dictionary[StringName, bool] = {}
	for cue: AudioCueDef in _reg.cues:
		assert_false(ids.has(cue.id), "duplicate cue id %s" % cue.id)
		ids[cue.id] = true
		assert_true(String(cue.id).begins_with("cue."), "id format %s" % cue.id)
		assert_false(cue.streams.is_empty(), "%s has streams" % cue.id)
		for s: AudioStream in cue.streams:
			assert_true(s is AudioStreamOggVorbis, "%s stream is ogg" % cue.id)
			assert_true(s != null and s.get_length() > 0.02, "%s stream has audio" % cue.id)
		assert_true(BUSES.has(cue.bus), "%s bus %s is a contract bus" % [cue.id, cue.bus])
	for id: StringName in LOOPS:
		assert_true(_reg.get_cue(id).loop, "%s is a loop" % id)
	assert_true(_reg.get_cue(&"cue.glass_break").streams.size() >= 3, "glass_break variations")
	assert_true(_reg.get_cue(&"cue.weapon_pistol_fire").streams.size() >= 3, "pistol variations")
	for id: StringName in [&"cue.weapon_pistol_mag_out", &"cue.weapon_pistol_mag_in", &"cue.weapon_pistol_slide_release"]:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c.streams.size() >= 3, "%s variations" % id)
		assert_eq(c.bus, &"Weapons", "%s bus" % id)
		assert_false(c.loop, "%s one-shot" % id)


## D-117: every heist bed is registered as a 2D Ambience-bus loop with a stop owner, and lasts long
## enough not to read as a short loop.
func test_heist_ambience_beds() -> void:
	if _reg == null:
		skip("no registry")
		return
	for id: StringName in AMBIENCE_BEDS:
		var c: AudioCueDef = _reg.get_cue(id)
		assert_true(c != null, "bed %s registered" % id)
		if c == null:
			continue
		assert_true(c.loop, "%s loops" % id)
		assert_eq(c.bus, &"Ambience", "%s on the Ambience bus" % id)
		assert_false(c.positional, "%s is a 2D bed" % id)
		assert_eq(c.streams.size(), 1, "%s one stream" % id)
		assert_true(c.streams[0].get_length() >= 15.0, "%s loop length %.1f s" % [id, c.streams[0].get_length()])
		assert_true(CuePlayer.LOOP_STOP_OWNERS.get(id, "") == "CueEmitter (map bed)", "%s owned by a map CueEmitter" % id)


## D-117 §7: each heist track loads, has its own tempo grid, and answers every stem MusicDirector can ask
## for (stem_for over all phases), so no phase is silent; stems are whole bars of the track's grid.
func test_every_heist_music_track() -> void:
	var bpms: Dictionary = {}
	for tid: StringName in HEIST_MUSIC + HEIST_MUSIC_MAP_PENDING:
		var t: MusicTrack = MusicTrack.load_track(tid)
		assert_true(t != null, "track %s loads" % tid)
		if t == null:
			continue
		assert_eq(t.id, tid)
		bpms[tid] = t.bpm
		for stem: StringName in ALL_STEMS:
			var st: AudioStream = t.stem(stem)
			assert_true(st != null, "%s has stem %s" % [tid, stem])
			if st == null:
				continue
			var bars: float = st.get_length() / t.bar_seconds()
			assert_true(bars >= 3.9, "%s/%s at least 4 bars (%.2f)" % [tid, stem, bars])
			assert_true(absf(bars - roundf(bars)) < 0.02, "%s/%s whole bars (%.3f)" % [tid, stem, bars])
			assert_true(t.loop_bars.has(stem), "%s/%s loop_bars" % [tid, stem])
		for sting: StringName in [MusicTrack.STINGER_WIN, MusicTrack.STINGER_LOSE]:
			assert_true(t.stingers.get(sting) is AudioStream, "%s stinger %s" % [tid, sting])
	assert_eq(bpms.get(&"night_deposit"), 140.0, "ND 140 grid (stealth 70 half-time)")
	assert_eq(bpms.get(&"shadow_ledger"), 132.0, "SL 132 grid (stealth 66 half-time)")
	assert_eq(bpms.get(&"dockside_burn"), 150.0, "DB 150 grid")
	assert_eq(bpms.get(&"gallery_night"), 144.0, "GN 144 grid (stealth 72 half-time)")
	assert_eq(bpms.get(&"rolling_thunder"), 148.0, "RT 148 grid (stealth 74 half-time, control 111 triplets)")
	# Stealth-only Shadow Ledger: the loud stems are aliases (abort loop; escape/jukebox keep the bed).
	var sl: MusicTrack = MusicTrack.load_track(&"shadow_ledger")
	if sl != null:
		assert_eq(sl.stem(&"assault"), sl.stem(&"stealth"), "SL escape / preview keep the stealth bed")
		assert_eq(sl.stem(&"anticipation"), sl.stem(&"control"), "SL loud stems share the abort loop")
		assert_true(sl.stem(&"control") != sl.stem(&"stealth"), "SL abort loop differs from the bed")
		assert_true(sl.stem(&"control").get_length() < sl.stem(&"stealth").get_length(), "SL abort loop is short")


## D-117: every built heist map carries an Audio node with a CuePlayer, its MusicDirector and its own
## beds (checked on the generated scene text: no map load).
func test_heist_maps_place_their_audio() -> void:
	var beds: Dictionary = {
		&"glasshouse": [&"cue.amb_glasshouse_interior", &"cue.amb_street_dusk"],
		&"night_deposit": [&"cue.amb_bank_night_interior", &"cue.amb_harbor_night"],
		&"shadow_ledger": [&"cue.amb_shadow_ledger_interior", &"cue.amb_rooftop_rain"],
		&"dockside_burn": [&"cue.amb_cold_store", &"cue.amb_dockside_fog"],
		&"gallery_night": [&"cue.amb_gallery_gala", &"cue.amb_art_store", &"cue.amb_uptown_night"],
		&"ostrander_federal": [&"cue.amb_bank_hall_day", &"cue.amb_bank_boh", &"cue.amb_vault",
			&"cue.amb_city_afternoon"],
		&"rolling_thunder": [&"cue.amb_skyway_street", &"cue.amb_underpass", &"cue.amb_diner", &"cue.amb_site"],
	}
	for h: StringName in HEIST_MUSIC:
		var txt: String = FileAccess.get_file_as_string("res://world/heists/%s/%s.tscn" % [h, h])
		assert_false(txt.is_empty(), "%s scene readable" % h)
		assert_true(txt.contains('[node name="Audio" type="Node3D" parent="."'), "%s has an Audio node" % h)
		assert_true(txt.contains('[node name="CuePlayer" type="Node" parent="Audio"'), "%s CuePlayer" % h)
		assert_true(txt.contains('[node name="MusicDirector" type="Node" parent="Audio"'), "%s MusicDirector" % h)
		assert_true(txt.contains('track_id = &"%s"' % h) or h == &"glasshouse", "%s MusicDirector track" % h)
		for id: StringName in beds[h]:
			assert_true(txt.contains('cue_id = &"%s"' % id), "%s places bed %s" % [h, id])
		if h != &"glasshouse":
			assert_false(txt.contains('cue_id = &"cue.amb_glasshouse_interior"'), "%s no borrowed GH bed" % h)


func test_buses_resolve() -> void:
	AudioCueLib.ensure_buses()
	assert_true(AudioCueLib.has_contract_buses(), "contract buses exist")
	for pair: Array in AudioCueLib.CONTRACT_BUSES:
		var idx: int = AudioServer.get_bus_index(pair[0])
		assert_true(idx > 0, "bus %s" % pair[0])
		assert_eq(AudioServer.get_bus_send(idx), pair[1] as StringName, "bus %s sends to %s" % [pair[0], pair[1]])
	var layout: AudioBusLayout = load(AudioCueLib.BUS_LAYOUT_PATH) as AudioBusLayout
	assert_true(layout != null, "default_bus_layout.tres loads")


func test_missing_cue_plays_placeholder_and_warns() -> void:
	var player: CuePlayer = _make_player()
	Log.capture = true
	Log.captured.clear()
	var node: Node = player.play_cue(&"cue.does_not_exist_xyz")
	Log.capture = false
	assert_true(node is AudioStreamPlayer, "placeholder player returned")
	assert_true((node as AudioStreamPlayer).stream is AudioStreamWAV, "placeholder stream generated")
	var warned: bool = false
	for line: String in Log.captured:
		warned = warned or line.contains("cue.does_not_exist_xyz")
	assert_true(warned, "warned about missing cue")
	player.queue_free()


func test_cue_player_maps_facts() -> void:
	var player: CuePlayer = _make_player()
	player.local_slot_override = 0
	EventBus.heist_loaded.emit(&"heist.glasshouse", 1, {})
	assert_eq(player.variant_cue(&"cue.alarm_bell"), &"cue.alarm_bell_glasshouse", "heist alarm variant")
	EventBus.pager_started.emit(7, 0)
	assert_true(player.is_loop_active(&"pager_beep_7"), "pager beep loop")
	EventBus.pager_answer_started.emit(7, 0)
	assert_false(player.is_loop_active(&"pager_beep_7"), "beep stops when answering")
	assert_true(player.is_loop_active(&"pager_radio_7"), "radio loop while answering")
	EventBus.pager_answered.emit(7, 0, 1)
	assert_false(player.is_loop_active(&"pager_radio_7"), "radio stops when answered")
	EventBus.device_started.emit(42, &"drill", 60.0)
	assert_true(player.is_loop_active(&"device_42"), "drill loop")
	EventBus.device_jammed.emit(42)
	assert_false(player.is_loop_active(&"device_42"), "drill loop stops on jam")
	assert_eq(player.last_cue, &"cue.drill_jam")
	EventBus.device_restarted.emit(42, 0)
	EventBus.device_finished.emit(42)
	assert_eq(player.last_cue, &"cue.drill_done")
	EventBus.glass_broken.emit(5, Vector3(1, 0, 2))
	assert_eq(player.last_cue, &"cue.glass_break")
	EventBus.crew_masked.emit(0)
	assert_eq(player.last_cue, &"cue.mask_on")
	EventBus.loot_secured.emit(9, &"loot.jewelry", 1000)
	assert_eq(player.last_cue, &"cue.bag_secure")
	EventBus.detection_progress.emit(3, 0, 0.4, Enums.ObserverKind.GUARD)
	assert_eq(player.last_cue, &"cue.detect_tick")
	EventBus.detection_progress.emit(3, 0, 1.0, Enums.ObserverKind.GUARD)
	assert_eq(player.last_cue, &"cue.detect_full")
	EventBus.alarm_raised.emit(&"test", 0)
	assert_true(player.alarm_active, "alarm active")
	assert_true(player.is_loop_active(CuePlayer.ALARM_KEY), "alarm bell loop")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 1)
	assert_eq(player.last_cue, &"cue.assault_start")
	EventBus.heist_ended.emit({"success": true})
	assert_true(player.active_loop_keys().is_empty(), "all loops stop at heist end")
	player.queue_free()


func test_weapon_fire_cue_resolution() -> void:
	var player: CuePlayer = _make_player()
	assert_eq(player.weapon_fire_cue(&"weapon.kestrel_p9", false), &"cue.weapon_pistol_fire")
	assert_eq(player.weapon_fire_cue(&"weapon.kestrel_p9", true), &"cue.weapon_pistol_fire_suppressed")
	assert_eq(player.weapon_fire_cue(&"enemy.tac_rifle", false), &"cue.weapon_rifle_fire")
	assert_eq(player.weapon_fire_cue(&"enemy.swat_smg", false), &"cue.weapon_smg_fire")
	assert_eq(player.weapon_fire_cue(&"weapon.x_shotgun", true), &"cue.weapon_shotgun_fire_suppressed")
	var def: WeaponDef = WeaponDef.new()
	def.anim_set = &"pistol"
	def.fire_cue = &"cue.weapon_pistol_fire"
	assert_eq(player.weapon_fire_cue(&"x", false, def), &"cue.weapon_pistol_fire")
	assert_eq(player.weapon_fire_cue(&"x", true, def), &"cue.weapon_pistol_fire_suppressed")
	player.queue_free()


func test_music_stem_mapping() -> void:
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.STEALTH, Enums.AssaultPhase.NONE), &"stealth")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.CASING, Enums.AssaultPhase.NONE), &"stealth")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.NONE), &"control")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.ANTICIPATION), &"anticipation")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.BUILD), &"assault")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.SUSTAIN), &"assault")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.FADE), &"fade")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.LOUD, Enums.AssaultPhase.CONTROL), &"control")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.ESCAPE, Enums.AssaultPhase.NONE), &"assault")
	assert_eq(MusicDirector.stem_for(Enums.HeistPhase.ENDED, Enums.AssaultPhase.NONE), &"")


func test_music_director_follows_phase_signals() -> void:
	var md: MusicDirector = MusicDirector.new()
	md.track_id = &"glasshouse"
	add_child(md)
	assert_true(md.track != null, "glasshouse track loads")
	if md.track == null:
		md.queue_free()
		return
	assert_eq(md.track.bpm, 140.0)
	for stem: StringName in [&"stealth", &"control", &"anticipation", &"assault", &"fade"]:
		assert_true(md.track.stem(stem) != null, "stem %s" % stem)
		assert_true(md.track.stem(stem).get_length() > md.track.bar_seconds() * 8.0, "stem %s length" % stem)
	EventBus.heist_phase_changed.emit(Enums.HeistPhase.LOADING, Enums.HeistPhase.STEALTH)
	assert_eq(md.target_stem, &"stealth")
	assert_true(await wait_until(func() -> bool: return md.current_stem == &"stealth", 3.0), "stealth starts")
	EventBus.heist_phase_changed.emit(Enums.HeistPhase.STEALTH, Enums.HeistPhase.LOUD)
	assert_eq(md.target_stem, &"control")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.ANTICIPATION, 1)
	assert_eq(md.target_stem, &"anticipation")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.BUILD, 1)
	assert_eq(md.target_stem, &"assault")
	# switches on a bar line (<= one bar of 140 BPM 4/4 = 1.71 s). Wall-clock wait is generous
	# (2 bars + 1 s) so a loaded CI machine doesn't flake; the bar-sync itself is unit-timed in MusicDirector.
	var bar: float = md.track.bar_seconds()
	assert_true(await wait_until(func() -> bool: return md.current_stem == &"assault", bar * 2.0 + 1.0),
			"assault reached by the next bar line")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.FADE, 1)
	assert_eq(md.target_stem, &"fade")
	EventBus.heist_ended.emit({"success": false})
	assert_eq(md.target_stem, &"")
	assert_eq(md.last_stinger, &"lose")
	md.stop_all()
	await wait_frames(2)
	md.queue_free()


func _make_player() -> CuePlayer:
	var p: CuePlayer = CuePlayer.new()
	p.siren_delay_s = 0.05
	add_child(p)
	return p


## cue.payday_tick (ENV B payday timer, last seconds): a short 2D UI tick on the UI bus.
func test_payday_tick_cue() -> void:
	if _reg == null:
		skip("no registry")
		return
	var c: AudioCueDef = _reg.get_cue(&"cue.payday_tick")
	assert_true(c != null, "registry has cue.payday_tick")
	if c == null:
		return
	assert_false(c.positional, "payday_tick is 2D")
	assert_eq(c.bus, &"UI", "payday_tick on the UI bus")
	assert_false(c.loop, "payday_tick does not loop")
	assert_eq(c.streams.size(), 1, "one tick stream")
	if c.streams.size() > 0:
		assert_true(c.streams[0].get_length() < 0.2, "a short tick (%.3f s)" % c.streams[0].get_length())


## PO-14 registry coverage: every cue id written as a literal in game code (`const CUE_X := &"cue.x"`,
## `StringName("cue.x")`, plain `"cue.x"` in tables) must exist in cues.tres, so no trigger silently
## falls back to the placeholder beep. Prefix literals (`"cue.impact_" + surface`) end in `_` and are
## skipped; ids built at runtime are covered by the family tests above.
func test_every_cue_referenced_in_code_is_registered() -> void:
	if _reg == null:
		skip("no registry")
		return
	var re: RegEx = RegEx.create_from_string(CUE_LITERAL)
	var refs: Dictionary[String, String] = {}
	var files: PackedStringArray = []
	for root: String in CODE_ROOTS:
		_collect_gd(root, files)
	assert_true(files.size() > 50, "scanned %d .gd files" % files.size())
	for path: String in files:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			if not refs.has(m.get_string(1)):
				refs[m.get_string(1)] = path
	assert_true(refs.size() > 20, "found %d cue literals" % refs.size())
	var missing: PackedStringArray = []
	for id: String in refs:
		if not _reg.has_cue(StringName(id)) and not CUE_ROWS_PENDING.has(StringName(id)):
			missing.append("%s (%s)" % [id, refs[id]])
	assert_true(missing.is_empty(), "cues referenced in code but not registered: %s" % ", ".join(missing))
	assert_true(refs.has("cue.npc_melee_swing"), "the A3-13 melee windup cue is seen by the scan")


func _collect_gd(dir_path: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			_collect_gd(dir_path.path_join(sub), out)


## cue.npc_melee_swing (A3-13 NPC melee windup [R]): a short 3D whoosh on the World bus, under gunfire,
## that fits inside the 0.4 s windup.
func test_npc_melee_swing_cue() -> void:
	if _reg == null:
		skip("no registry")
		return
	var c: AudioCueDef = _reg.get_cue(&"cue.npc_melee_swing")
	assert_true(c != null, "registry has cue.npc_melee_swing")
	if c == null:
		return
	assert_eq(c.bus, &"World", "melee swing bus")
	assert_true(c.positional, "melee swing is 3D at the NPC")
	assert_false(c.loop, "melee swing is a one-shot")
	assert_eq(c.streams.size(), 3, "3 variations")
	assert_true(c.max_distance >= 10.0 and c.max_distance <= 25.0, "range %.0f m" % c.max_distance)
	assert_true(c.volume_db < _reg.get_cue(&"cue.weapon_rifle_fire").volume_db, "sits under gunfire")
	for s: AudioStream in c.streams:
		if s != null:
			assert_true(s.get_length() <= 0.351, "swing stream <= 0.35 s (%.3f s)" % s.get_length())
