## Heist-scene audio service: plays cues requested through EventBus.audio_cue_requested and maps
## gameplay facts (pagers, alarm, drills, loot, crew, detection...) to cues. Pooled players,
## per-source cooldowns, presentation-only pitch jitter from a local seeded RNG (never global randf).
## Missing cues play a generated placeholder beep and warn once (never crash).
## Runs on every peer: facts marked [R] in events.md are re-emitted on clients by Net.
## PO6-07 / D-114 §3: only keyed loops (start_loop) loop, and every one has a stop owner
## (LOOP_STOP_OWNERS) plus a safety cap (loop_max_s). A loop cue played any other way
## (audio_cue_requested, weapon_fired) plays its clip once.
class_name CuePlayer
extends Node

const POOL_3D: int = 32
const POOL_2D: int = 16
const NO_POSITION: Vector3 = AudioCueLib.NO_POSITION
const ALARM_KEY: StringName = &"alarm"
const SIREN_KEY: StringName = &"siren"
## anim_sets that reuse another family's fire cue when WeaponDef.fire_cue is empty.
const ANIM_SET_FIRE_FAMILY: Dictionary[StringName, StringName] = {&"akimbo": &"pistol"}
## Every cue with loop = true -> the fact(s) that stop it (tests assert full coverage). "CueEmitter"
## loops are owned by a node: they stop when it leaves the tree (map unload, pool freed) or on heist end.
const LOOP_STOP_OWNERS: Dictionary[StringName, String] = {
	&"cue.pager_beep": "pager_answer_started / pager_answered / pager_failed (A: PagerSystem); cap",
	&"cue.pager_radio": "pager_answer_released / pager_answered / pager_failed (A: PagerSystem); cap",
	&"cue.alarm_bell": "alarm_bell_duration_s timer / heist_ended / heist_loaded",
	&"cue.alarm_bell_glasshouse": "alarm_bell_duration_s timer / heist_ended / heist_loaded",
	&"cue.alarm_bell_ostrander_federal": "alarm_bell_duration_s timer / heist_ended / heist_loaded",
	&"cue.police_siren_far": "assault_phase_changed FADE/CONTROL/NONE (A: assault director) / heist_ended",
	&"cue.drill_loop": "device_jammed / device_finished (A: Device); cap",
	&"cue.lockpick": "interaction_cancelled / interaction_completed (A: Interactable) / crew_downed; cap",
	&"cue.aegis_pulse": "captain_retreated / npc_killed (A: AegisCaptain)",
	&"cue.weapon_flamethrower_fire": "weapon_fired gap > weapon_loop_tail_s (held trigger)",
	&"cue.weapon_saw_rev": "weapon_fired gap > weapon_loop_tail_s (held trigger)",
	&"cue.weapon_saw_cut": "weapon_fired gap > weapon_loop_tail_s (held trigger)",
	&"cue.weapon_minigun_fire": "weapon_fired gap > weapon_loop_tail_s (held trigger)",
	&"cue.phantom_hum": "never keyed: re-requested per interval, plays once (A: PhantomBrain)",
	&"cue.stinger_arc": "never keyed: re-requested per interval, plays once (A: StingerBrain)",
	&"cue.amb_glasshouse_interior": "CueEmitter (map bed)",
	&"cue.amb_street_dusk": "CueEmitter (map bed)",
	&"cue.amb_bank_night_interior": "CueEmitter (map bed)",
	&"cue.amb_harbor_night": "CueEmitter (map bed)",
	&"cue.amb_shadow_ledger_interior": "CueEmitter (map bed)",
	&"cue.amb_rooftop_rain": "CueEmitter (map bed)",
	&"cue.amb_cold_store": "CueEmitter (map bed)",
	&"cue.amb_dockside_fog": "CueEmitter (map bed)",
	&"cue.amb_gallery_gala": "CueEmitter (map bed)",
	&"cue.amb_art_store": "CueEmitter (map bed)",
	&"cue.amb_uptown_night": "CueEmitter (map bed)",
	&"cue.amb_bank_hall_day": "CueEmitter (map bed)",
	&"cue.amb_bank_boh": "CueEmitter (map bed)",
	&"cue.amb_vault": "CueEmitter (map bed)",
	&"cue.amb_city_afternoon": "CueEmitter (map bed)",
	&"cue.amb_skyway_street": "CueEmitter (map bed)",
	&"cue.amb_underpass": "CueEmitter (map bed)",
	&"cue.amb_diner": "CueEmitter (map bed)",
	&"cue.amb_site": "CueEmitter (map bed)",
	# C4-03 safehouse: the interior bed and the point emitters (CueEmitters SafehouseMap starts; freed with the hub)
	&"cue.amb_safehouse_interior": "CueEmitter (map bed)",
	&"cue.amb_fridge_hum": "CueEmitter (map bed)",
	&"cue.amb_wall_clock": "CueEmitter (map bed)",
	&"cue.amb_ballast_buzz": "CueEmitter (map bed)",
	&"cue.amb_drip": "CueEmitter (map bed)",
	&"cue.amb_range_extractor": "CueEmitter (map bed)",
	# AH-C1 Afterhours: the map beds (ClubSound owns the club loop + crowd bed: cut() stops them on the alarm)
	&"cue.amb_afterhours_club_music": "CueEmitter (map bed)",
	&"cue.amb_afterhours_club": "CueEmitter (map bed)",
	&"cue.amb_afterhours_boh": "CueEmitter (map bed)",
	&"cue.amb_street_wet_night": "CueEmitter (map bed)",
	&"cue.crowd_stampede": "CueEmitter (Audio/ClubSound, started by cut(); freed with the map); cap",
	&"cue.throwable_incendiary_fire": "CueEmitter (fire pool, freed with the pool)",
	&"cue.assault_van_engine": "assault_event_ended (A: assault events) / heist_ended; cap",
	&"cue.assault_heli_rotor": "assault_event_ended (A: assault events) / heist_ended; cap",
}
## PO6-17 / audio_cues v1.8: assault-event kind -> [start one-shot, keyed loop, end one-shot]; "" = none.
const ASSAULT_EVENT_CUES: Dictionary = {
	&"turret_van": [&"cue.assault_van_arrive", &"cue.assault_van_engine", &""],
	&"heli": [&"cue.assault_heli_arrive", &"cue.assault_heli_rotor", &"cue.assault_heli_leave"],
	&"breach": [&"cue.assault_breach_warning", &"", &""],
}
## Held-trigger weapon loop -> one-shot tail played when the trigger is released.
const WEAPON_LOOP_TAILS: Dictionary[StringName, StringName] = {
	&"cue.weapon_flamethrower_fire": &"cue.weapon_flamethrower_stop",
	&"cue.weapon_minigun_fire": &"cue.weapon_minigun_spin_down",
}

@export var registry: AudioCueRegistry
@export var listen_to_event_bus: bool = true
## Play the alarm bell as a flat bed when the alarm goes off. Set false when the map places
## CueEmitter bells (trigger_on_alarm) instead.
@export var play_flat_alarm: bool = true
@export var alarm_bell_duration_s: float = 120.0
@export var siren_delay_s: float = 6.0
## Play weapon_fired facts (server-local only; clients play fire from synced state via CueEmitter).
@export var play_weapon_fired: bool = true
## A held-trigger weapon loop stops this long after its shooter's last weapon_fired.
@export var weapon_loop_tail_s: float = 0.25
## Safety cap per loop cue (seconds; a keyed loop older than this is stopped even if its owner never
## sent the end fact). Missing = no cap.
@export var loop_max_s: Dictionary[StringName, float] = {
	&"cue.pager_beep": 30.0, &"cue.pager_radio": 30.0, &"cue.lockpick": 120.0, &"cue.drill_loop": 600.0,
	&"cue.police_siren_far": 240.0, &"cue.assault_van_engine": 600.0, &"cue.assault_heli_rotor": 600.0,
}
## Interaction kind -> loop cue while the interaction is held.
@export var interaction_loop_cues: Dictionary[StringName, StringName] = {&"lockpick": &"cue.lockpick"}
## Interaction kind -> one-shot cue on completion.
@export var interaction_done_cues: Dictionary[StringName, StringName] = {
	&"keycard": &"cue.keycard_beep", &"door_open": &"cue.door_open", &"door_close": &"cue.door_close",
	&"lockpick": &"cue.door_open", &"keypad": &"cue.keypad_accept",
}
## Device kind (device_started) -> [loop, jam, done] or [loop, jam, done, start] cues; "" = none.
## `start` is a one-shot on device_started / device_restarted (e.g. the hack's terminal chirps).
@export var device_cues: Dictionary[StringName, PackedStringArray] = {
	&"drill": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
	&"saw": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
	&"thermal": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
	&"hack": PackedStringArray(["", "cue.hack_interrupt", "cue.hack_done", "cue.hack_start"]),
}

## Heist variant used to resolve per-heist cues (cue.alarm_bell_<variant>); set from heist_loaded.
var heist_variant: StringName = &""
## Tests/tools: force the local crew slot / crew net id (otherwise Net + crew group lookup).
var local_slot_override: int = -1
var local_crew_net_id_override: int = -1
## Last cue id actually started (after resolution) and a running count; handy for tests/tools.
var last_cue: StringName = &""
var play_count: int = 0
## True from alarm_raised (or LOUD) until the heist ends; the bell itself stops after its duration.
var alarm_active: bool = false

var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _started_ms: Dictionary[Node, int] = {}
var _loops: Dictionary[StringName, Node] = {}
var _loop_cue: Dictionary[StringName, StringName] = {}
var _loop_started_ms: Dictionary[StringName, int] = {}
var _weapon_last_ms: Dictionary[StringName, int] = {}
var _interact_crew: Dictionary[int, int] = {}
var _follow: Dictionary[Node, int] = {}
var _last_play_ms: Dictionary[String, int] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _detect_last: Dictionary[int, float] = {}
var _pager_guard: Dictionary[int, int] = {}
var _device_kind: Dictionary[int, StringName] = {}
var _alarm_gen: int = 0
## True between an assault's FADE/CONTROL and the next wave: sirens stay off.
var _siren_held: bool = false


func _ready() -> void:
	_rng.seed = 0xC0E5_A0D1  # presentation-only variation; deterministic, not gameplay
	AudioCueLib.ensure_buses()
	if registry == null:
		registry = AudioCueLib.registry()
	for i: int in range(POOL_3D):
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.name = "P3D_%d" % i
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = 6.0
		add_child(p3)
		_players_3d.append(p3)
	for i: int in range(POOL_2D):
		var p2: AudioStreamPlayer = AudioStreamPlayer.new()
		p2.name = "P2D_%d" % i
		add_child(p2)
		_players_2d.append(p2)
	if listen_to_event_bus:
		_connect_event_bus()


func _exit_tree() -> void:
	stop_everything()


## Stop every pooled player (teardown, tests).
func stop_everything() -> void:
	_loops.clear()
	_loop_cue.clear()
	_loop_started_ms.clear()
	_weapon_last_ms.clear()
	_follow.clear()
	for p3: AudioStreamPlayer3D in _players_3d:
		p3.stop()
	for p2: AudioStreamPlayer in _players_2d:
		p2.stop()


func _process(_delta: float) -> void:
	for p: Node in _follow.keys():
		var target: Node3D = Ids.lookup(_follow[p]) as Node3D
		var p3: AudioStreamPlayer3D = p as AudioStreamPlayer3D
		if target != null and p3 != null and p3.playing:
			p3.global_position = target.global_position
	if not _loops.is_empty():
		_enforce_loop_ends()


## Stops held-trigger weapon loops whose trigger was released and any loop past its safety cap.
func _enforce_loop_ends() -> void:
	var now: int = Time.get_ticks_msec()
	for key: StringName in _weapon_last_ms.keys():
		if now - _weapon_last_ms[key] > int(weapon_loop_tail_s * 1000.0):
			_end_weapon_loop(key)
	for key: StringName in _loop_started_ms.keys():
		var cap: float = loop_max_s.get(_loop_cue.get(key, &""), 0.0)
		if cap > 0.0 and now - _loop_started_ms[key] > int(cap * 1000.0):
			stop_loop(key)


# --- public API ------------------------------------------------------------------------------


## Play a cue once (or start it, if it is a loop and you keep the returned player). `position`
## NO_POSITION = flat; a positional cue with a resolvable `source_net_id` plays at that node.
## Returns the player node, or null when suppressed by cooldown.
## Only start_loop passes `looped` = true; any other play of a loop cue plays its clip once.
func play_cue(cue_id: StringName, position: Vector3 = NO_POSITION, source_net_id: int = 0,
		pitch: float = 1.0, looped: bool = false) -> Node:
	var cue: AudioCueDef = AudioCueLib.resolve(registry, cue_id)
	if cue == null:
		return _play_placeholder(cue_id)
	if cue.cooldown_s > 0.0:
		var key: String = "%s|%d" % [cue_id, source_net_id]
		var now: int = Time.get_ticks_msec()
		if _last_play_ms.has(key) and now - _last_play_ms[key] < int(cue.cooldown_s * 1000.0):
			return null
		_last_play_ms[key] = now
	var pos: Vector3 = _resolve_position(position, source_net_id)
	var stream: AudioStream = AudioCueLib.pick_stream(cue, _rng, 1 if looped else 0)
	var pitch_scale: float = AudioCueLib.pitch_for(cue, _rng, pitch)
	var player: Node = null
	if cue.positional and pos != NO_POSITION:
		var p3: AudioStreamPlayer3D = _take_3d()
		p3.stream = stream
		p3.volume_db = cue.volume_db
		p3.max_distance = cue.max_distance
		p3.pitch_scale = pitch_scale
		p3.bus = AudioCueLib.bus_or_master(cue.bus)
		p3.global_position = pos
		p3.play()
		player = p3
		if looped and cue.loop and source_net_id != 0 and Ids.lookup(source_net_id) is Node3D:
			_follow[p3] = source_net_id
	else:
		var p2: AudioStreamPlayer = _take_2d()
		p2.stream = stream
		p2.volume_db = cue.volume_db
		p2.pitch_scale = pitch_scale
		p2.bus = AudioCueLib.bus_or_master(cue.bus)
		p2.play()
		player = p2
	_started_ms[player] = Time.get_ticks_msec()
	last_cue = cue_id
	play_count += 1
	return player


## Start a keyed loop (replacing an existing loop with the same key).
func start_loop(key: StringName, cue_id: StringName, position: Vector3 = NO_POSITION, source_net_id: int = 0) -> void:
	stop_loop(key)
	var p: Node = play_cue(cue_id, position, source_net_id, 1.0, true)
	if p != null:
		_loops[key] = p
		_loop_cue[key] = cue_id
		_loop_started_ms[key] = Time.get_ticks_msec()


func stop_loop(key: StringName) -> void:
	if not _loops.has(key):
		return
	var p: Node = _loops[key]
	_loops.erase(key)
	_loop_cue.erase(key)
	_loop_started_ms.erase(key)
	_weapon_last_ms.erase(key)
	_follow.erase(p)
	if p is AudioStreamPlayer:
		(p as AudioStreamPlayer).stop()
	elif p is AudioStreamPlayer3D:
		(p as AudioStreamPlayer3D).stop()


func stop_all_loops() -> void:
	for key: StringName in _loops.keys():
		stop_loop(key)


func is_loop_active(key: StringName) -> bool:
	return _loops.has(key)


func active_loop_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_loops.keys())
	out.sort()
	return out


## Resolve a per-heist variant: cue.<base>_<heist_variant> if registered, else cue.<base>.
func variant_cue(base: StringName) -> StringName:
	if heist_variant != &"":
		var v: StringName = StringName("%s_%s" % [base, heist_variant])
		if registry != null and registry.has_cue(v):
			return v
	return base


## Fire cue for a weapon: WeaponDef.fire_cue(_suppressed) when given, else by id heuristics.
func weapon_fire_cue(weapon_id: StringName, suppressed: bool, def: WeaponDef = null) -> StringName:
	if def != null:
		var c: StringName = def.fire_cue_suppressed if suppressed else def.fire_cue
		if c != &"":
			return c
		var fam: StringName = ANIM_SET_FIRE_FAMILY.get(def.anim_set, def.anim_set)
		return StringName("cue.weapon_%s_fire%s" % [fam, "_suppressed" if suppressed else ""])
	var w: String = String(weapon_id).to_lower()
	var family: String = "pistol"
	for pair: Array in [["smg", "smg"], ["lmg", "lmg"], ["shotgun", "shotgun"], ["sniper", "sniper"],
			["rifle", "rifle"], ["carbine", "rifle"], ["_ar", "rifle"]]:
		if w.contains(pair[0]):
			family = pair[1]
			break
	return StringName("cue.weapon_%s_fire%s" % [family, "_suppressed" if suppressed else ""])


# --- EventBus mapping ------------------------------------------------------------------------


func _connect_event_bus() -> void:
	EventBus.audio_cue_requested.connect(_on_audio_cue_requested)
	EventBus.heist_loaded.connect(_on_heist_loaded)
	EventBus.heist_phase_changed.connect(_on_heist_phase_changed)
	EventBus.heist_ended.connect(_on_heist_ended)
	EventBus.alarm_raised.connect(_on_alarm_raised)
	EventBus.crew_masked.connect(_on_crew_masked)
	EventBus.crew_downed.connect(_on_crew_downed)
	EventBus.crew_revived.connect(_on_crew_revived)
	EventBus.detection_progress.connect(_on_detection_progress)
	EventBus.npc_alert_state_changed.connect(_on_npc_alert_state_changed)
	EventBus.pager_started.connect(_on_pager_started)
	EventBus.pager_answer_started.connect(_on_pager_answer_started)
	EventBus.pager_answer_released.connect(_on_pager_answer_released)
	EventBus.pager_answered.connect(_on_pager_answered)
	EventBus.pager_failed.connect(_on_pager_failed)
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_cancelled.connect(_on_interaction_cancelled)
	EventBus.interaction_completed.connect(_on_interaction_completed)
	EventBus.device_started.connect(_on_device_started)
	EventBus.device_jammed.connect(_on_device_jammed)
	EventBus.device_restarted.connect(_on_device_restarted)
	EventBus.device_finished.connect(_on_device_finished)
	EventBus.glass_broken.connect(_on_glass_broken)
	EventBus.laser_tripped.connect(_on_laser_tripped)
	EventBus.loot_picked.connect(_on_loot_picked)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.loot_secured.connect(_on_loot_secured)
	EventBus.small_loot_taken.connect(_on_small_loot_taken)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.assault_phase_changed.connect(_on_assault_phase_changed)
	EventBus.captain_arrived.connect(_on_captain_arrived)
	EventBus.captain_retreated.connect(_on_captain_retreated)
	EventBus.npc_killed.connect(_on_npc_killed)
	EventBus.assault_event_started.connect(_on_assault_event_started)
	EventBus.assault_event_ended.connect(_on_assault_event_ended)


func _on_audio_cue_requested(cue_id: StringName, position: Vector3, source_net_id: int) -> void:
	play_cue(cue_id, position, source_net_id)


func _on_heist_loaded(heist_id: StringName, _run_seed: int, _variants: Dictionary) -> void:
	_stop_alarm()
	stop_all_loops()
	_interact_crew.clear()
	var s: String = String(heist_id)
	heist_variant = StringName(s.get_slice(".", s.get_slice_count(".") - 1))


func _on_heist_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == Enums.HeistPhase.LOUD and not alarm_active:
		_start_alarm()
	elif new_phase == Enums.HeistPhase.ENDED:
		_stop_alarm()
		stop_all_loops()


func _on_heist_ended(_result: Dictionary) -> void:
	_stop_alarm()
	stop_all_loops()


func _on_alarm_raised(_reason: StringName, _source_net_id: int) -> void:
	if not alarm_active:
		_start_alarm()


func _start_alarm() -> void:
	alarm_active = true
	_siren_held = false
	_alarm_gen += 1
	if play_flat_alarm:
		start_loop(ALARM_KEY, variant_cue(&"cue.alarm_bell"))
	if is_inside_tree():
		get_tree().create_timer(siren_delay_s).timeout.connect(_on_siren_timer.bind(_alarm_gen))
		get_tree().create_timer(alarm_bell_duration_s).timeout.connect(_on_bell_timer.bind(_alarm_gen))


func _stop_alarm() -> void:
	alarm_active = false
	_alarm_gen += 1
	stop_loop(ALARM_KEY)
	stop_loop(SIREN_KEY)


func _on_siren_timer(gen: int) -> void:
	if gen == _alarm_gen and alarm_active and not _siren_held and not is_loop_active(SIREN_KEY):
		start_loop(SIREN_KEY, &"cue.police_siren_far")


func _on_bell_timer(gen: int) -> void:
	if gen == _alarm_gen:
		stop_loop(ALARM_KEY)


func _on_crew_masked(crew_slot: int) -> void:
	_play_at_crew(&"cue.mask_on", crew_slot)


func _on_crew_downed(crew_slot: int, _downs_used: int) -> void:
	_play_at_crew(&"cue.crew_downed", crew_slot)
	for iid: int in _interact_crew.keys():
		if _interact_crew[iid] == crew_slot:
			stop_loop(StringName("interact_%d" % iid))
			_interact_crew.erase(iid)


func _on_crew_revived(crew_slot: int, _by_crew_slot: int) -> void:
	_play_at_crew(&"cue.revive", crew_slot)


func _on_detection_progress(observer_net_id: int, crew_slot: int, value: float, _kind: int) -> void:
	if crew_slot != _local_slot():
		return
	var prev: float = _detect_last.get(observer_net_id, 0.0)
	_detect_last[observer_net_id] = value
	if value >= 1.0 and prev < 1.0:
		play_cue(&"cue.detect_full")
	elif value > prev + 0.001 and value < 1.0:
		play_cue(&"cue.detect_tick", NO_POSITION, 0, 0.8 + 0.7 * clampf(value, 0.0, 1.0))


func _on_npc_alert_state_changed(npc_net_id: int, old_state: int, new_state: int) -> void:
	if new_state == Enums.AlertState.CURIOUS and old_state == Enums.AlertState.CALM:
		play_cue(&"cue.npc_suspicious", NO_POSITION, npc_net_id)


func _on_pager_started(pager_id: int, guard_net_id: int) -> void:
	_pager_guard[pager_id] = guard_net_id
	start_loop(_pager_key(pager_id, false), &"cue.pager_beep", NO_POSITION, guard_net_id)


func _on_pager_answer_started(pager_id: int, _crew_slot: int) -> void:
	stop_loop(_pager_key(pager_id, false))
	start_loop(_pager_key(pager_id, true), &"cue.pager_radio", NO_POSITION, _pager_guard.get(pager_id, 0))


## Released early (D-114 §4 as amended): the radio stops and the beep resumes until the pager is answered or fails.
func _on_pager_answer_released(pager_id: int, _crew_slot: int) -> void:
	if not _pager_guard.has(pager_id):
		return
	stop_loop(_pager_key(pager_id, true))
	start_loop(_pager_key(pager_id, false), &"cue.pager_beep", NO_POSITION, _pager_guard[pager_id])


func _on_pager_answered(pager_id: int, _crew_slot: int, _answered_total: int) -> void:
	_end_pager(pager_id)


func _on_pager_failed(pager_id: int, _reason: StringName) -> void:
	_end_pager(pager_id)


func _end_pager(pager_id: int) -> void:
	stop_loop(_pager_key(pager_id, false))
	stop_loop(_pager_key(pager_id, true))
	_pager_guard.erase(pager_id)


func _pager_key(pager_id: int, radio: bool) -> StringName:
	return StringName("pager_%s_%d" % ["radio" if radio else "beep", pager_id])


func _on_interaction_started(interactable_net_id: int, crew_slot: int, kind: StringName) -> void:
	if interaction_loop_cues.has(kind):
		_interact_crew[interactable_net_id] = crew_slot
		start_loop(StringName("interact_%d" % interactable_net_id), interaction_loop_cues[kind], NO_POSITION,
				interactable_net_id)


func _on_interaction_cancelled(interactable_net_id: int, _crew_slot: int) -> void:
	stop_loop(StringName("interact_%d" % interactable_net_id))
	_interact_crew.erase(interactable_net_id)


func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, kind: StringName) -> void:
	stop_loop(StringName("interact_%d" % interactable_net_id))
	_interact_crew.erase(interactable_net_id)
	if interaction_done_cues.has(kind):
		play_cue(interaction_done_cues[kind], NO_POSITION, interactable_net_id)


func _on_device_started(device_net_id: int, kind: StringName, _duration: float) -> void:
	_device_kind[device_net_id] = kind
	_device_begin(device_net_id)


func _on_device_jammed(device_net_id: int) -> void:
	stop_loop(_device_key(device_net_id))
	_device_one_shot(device_net_id, 1)


func _on_device_restarted(device_net_id: int, _crew_slot: int) -> void:
	_device_begin(device_net_id)


func _on_device_finished(device_net_id: int) -> void:
	stop_loop(_device_key(device_net_id))
	_device_one_shot(device_net_id, 2)
	_device_kind.erase(device_net_id)


func _device_cue(device_net_id: int, idx: int) -> StringName:
	var cues: PackedStringArray = device_cues.get(_device_kind.get(device_net_id, &"drill"), PackedStringArray())
	return StringName(cues[idx]) if idx < cues.size() else &""


func _device_begin(device_net_id: int) -> void:
	var loop_cue: StringName = _device_cue(device_net_id, 0)
	if loop_cue != &"":
		start_loop(_device_key(device_net_id), loop_cue, NO_POSITION, device_net_id)
	_device_one_shot(device_net_id, 3)


func _device_one_shot(device_net_id: int, idx: int) -> void:
	var cue: StringName = _device_cue(device_net_id, idx)
	if cue != &"":
		play_cue(cue, NO_POSITION, device_net_id)


func _device_key(device_net_id: int) -> StringName:
	return StringName("device_%d" % device_net_id)


func _on_glass_broken(net_id: int, position: Vector3) -> void:
	play_cue(&"cue.glass_break", position, net_id)


func _on_laser_tripped(net_id: int) -> void:
	play_cue(&"cue.laser_trip", NO_POSITION, net_id)


func _on_loot_picked(bag_net_id: int, crew_slot: int) -> void:
	if crew_slot == _local_slot():
		play_cue(&"cue.bag_pickup")
	else:
		play_cue(&"cue.bag_pickup", NO_POSITION, bag_net_id)


func _on_loot_dropped(bag_net_id: int, _crew_slot: int, thrown: bool) -> void:
	if thrown:
		play_cue(&"cue.bag_throw", NO_POSITION, bag_net_id)


func _on_loot_secured(bag_net_id: int, _loot_id: StringName, _value: int) -> void:
	play_cue(&"cue.bag_secure", NO_POSITION, bag_net_id)


func _on_small_loot_taken(_value: int, crew_slot: int) -> void:
	_play_at_crew(&"cue.small_loot_pickup", crew_slot)


func _on_damage_applied(_victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	var me: int = _local_crew_net_id()
	if me <= 0 or attacker_net_id != me:
		return
	if int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD:
		play_cue(&"cue.headshot")
	else:
		play_cue(&"cue.hitmarker")


func _on_weapon_fired(shooter_net_id: int, weapon_id: StringName, suppressed: bool, position: Vector3) -> void:
	if not play_weapon_fired:
		return
	var cue_id: StringName = weapon_fire_cue(weapon_id, suppressed)
	var cue: AudioCueDef = AudioCueLib.resolve(registry, cue_id)
	if cue == null or not cue.loop:
		play_cue(cue_id, position, shooter_net_id)
		return
	# Held-trigger loop (minigun, flamethrower, saw): one loop per shooter, refreshed by every shot.
	var key: StringName = _weapon_key(shooter_net_id)
	if _loop_cue.get(key, &"") != cue_id:
		start_loop(key, cue_id, position, shooter_net_id)
	if is_loop_active(key):
		_weapon_last_ms[key] = Time.get_ticks_msec()


func _end_weapon_loop(key: StringName) -> void:
	var cue_id: StringName = _loop_cue.get(key, &"")
	var src: int = String(key).get_slice("_", 1).to_int()
	stop_loop(key)
	if WEAPON_LOOP_TAILS.has(cue_id):
		play_cue(WEAPON_LOOP_TAILS[cue_id], NO_POSITION, src)


func _weapon_key(shooter_net_id: int) -> StringName:
	return StringName("weapon_%d" % shooter_net_id)


func _on_captain_arrived(npc_net_id: int) -> void:
	play_cue(&"cue.brandt_arrival")
	start_loop(_captain_key(npc_net_id), &"cue.aegis_pulse", NO_POSITION, npc_net_id)


func _on_captain_retreated(npc_net_id: int) -> void:
	stop_loop(_captain_key(npc_net_id))


func _on_npc_killed(npc_net_id: int, _killer_net_id: int, _info: Dictionary) -> void:
	stop_loop(_captain_key(npc_net_id))
	stop_loop(_weapon_key(npc_net_id))


## PO6-17: arrival one-shot at `position`, then the event's keyed loop following `net_id` until it ends.
func _on_assault_event_started(kind: StringName, net_id: int, position: Vector3) -> void:
	var cues: Array = ASSAULT_EVENT_CUES.get(kind, [])
	if cues.is_empty():
		return
	if cues[0] != &"":
		play_cue(cues[0], position, net_id)
	if cues[1] != &"":
		start_loop(_assault_key(net_id), cues[1], position, net_id)


func _on_assault_event_ended(kind: StringName, net_id: int) -> void:
	stop_loop(_assault_key(net_id))
	var cues: Array = ASSAULT_EVENT_CUES.get(kind, [])
	if cues.size() > 2 and cues[2] != &"":
		play_cue(cues[2], NO_POSITION, net_id)


func _assault_key(net_id: int) -> StringName:
	return StringName("assault_event_%d" % net_id)


func _captain_key(npc_net_id: int) -> StringName:
	return StringName("captain_%d" % npc_net_id)


## Sirens run while police are inbound or assaulting and stop when the assault ends (D-114 §3).
func _on_assault_phase_changed(phase: int, _wave_index: int) -> void:
	_siren_held = phase in [Enums.AssaultPhase.FADE, Enums.AssaultPhase.CONTROL, Enums.AssaultPhase.NONE]
	if _siren_held:
		stop_loop(SIREN_KEY)
	elif alarm_active and not is_loop_active(SIREN_KEY):
		start_loop(SIREN_KEY, &"cue.police_siren_far")
	if phase == Enums.AssaultPhase.BUILD:
		play_cue(&"cue.assault_start")


# --- internals ------------------------------------------------------------------------------


func _play_at_crew(cue_id: StringName, crew_slot: int) -> void:
	if crew_slot == _local_slot():
		play_cue(cue_id)
		return
	var node: Node3D = _crew_node(crew_slot)
	play_cue(cue_id, node.global_position if node != null else NO_POSITION)


func _resolve_position(position: Vector3, source_net_id: int) -> Vector3:
	if source_net_id != 0:
		var n: Node3D = Ids.lookup(source_net_id) as Node3D
		if n != null and n.is_inside_tree():
			return n.global_position
	return position


func _local_slot() -> int:
	return local_slot_override if local_slot_override >= 0 else Net.local_slot()


func _local_crew_net_id() -> int:
	if local_crew_net_id_override >= 0:
		return local_crew_net_id_override
	var node: Node3D = _crew_node(_local_slot())
	return int(node.get(&"net_id")) if node != null and node.get(&"net_id") != null else -1


func _crew_node(crew_slot: int) -> Node3D:
	if crew_slot < 0 or not is_inside_tree():
		return null
	for n: Node in get_tree().get_nodes_in_group(G.CREW):
		if n is Node3D and n.get(&"crew_slot") != null and int(n.get(&"crew_slot")) == crew_slot:
			return n as Node3D
	return null


func _take_3d() -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = null
	for p: AudioStreamPlayer3D in _players_3d:
		if not p.playing and not _is_loop_player(p):
			_follow.erase(p)
			return p
		if not _is_loop_player(p) and (oldest == null or _started_ms.get(p, 0) < _started_ms.get(oldest, 0)):
			oldest = p
	var victim: AudioStreamPlayer3D = oldest if oldest != null else _players_3d[0]
	victim.stop()
	_follow.erase(victim)
	return victim


func _take_2d() -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for p: AudioStreamPlayer in _players_2d:
		if not p.playing and not _is_loop_player(p):
			return p
		if not _is_loop_player(p) and (oldest == null or _started_ms.get(p, 0) < _started_ms.get(oldest, 0)):
			oldest = p
	var victim: AudioStreamPlayer = oldest if oldest != null else _players_2d[0]
	victim.stop()
	return victim


func _is_loop_player(p: Node) -> bool:
	return _loops.values().has(p)


func _play_placeholder(cue_id: StringName) -> Node:
	var p2: AudioStreamPlayer = _take_2d()
	p2.stream = AudioCueLib.placeholder_stream()
	p2.volume_db = -6.0
	p2.pitch_scale = 1.0
	p2.bus = AudioCueLib.bus_or_master(&"SFX")
	p2.play()
	_started_ms[p2] = Time.get_ticks_msec()
	last_cue = cue_id
	play_count += 1
	return p2
