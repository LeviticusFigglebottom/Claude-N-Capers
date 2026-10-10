## Heist-scene audio service: plays cues requested through EventBus.audio_cue_requested and maps
## gameplay facts (pagers, alarm, drills, loot, crew, detection...) to cues. Pooled players,
## per-source cooldowns, presentation-only pitch jitter from a local seeded RNG (never global randf).
## Missing cues play a generated placeholder beep and warn once (never crash).
## Runs on every peer: facts marked [R] in events.md are re-emitted on clients by Net.
class_name CuePlayer
extends Node

const POOL_3D: int = 32
const POOL_2D: int = 16
const NO_POSITION: Vector3 = AudioCueLib.NO_POSITION
const ALARM_KEY: StringName = &"alarm"
const SIREN_KEY: StringName = &"siren"

@export var registry: AudioCueRegistry
@export var listen_to_event_bus: bool = true
## Play the alarm bell as a flat bed when the alarm goes off. Set false when the map places
## CueEmitter bells (trigger_on_alarm) instead.
@export var play_flat_alarm: bool = true
@export var alarm_bell_duration_s: float = 120.0
@export var siren_delay_s: float = 6.0
## Play weapon_fired facts (server-local only; clients play fire from synced state via CueEmitter).
@export var play_weapon_fired: bool = true
## Interaction kind -> loop cue while the interaction is held.
@export var interaction_loop_cues: Dictionary[StringName, StringName] = {&"lockpick": &"cue.lockpick"}
## Interaction kind -> one-shot cue on completion.
@export var interaction_done_cues: Dictionary[StringName, StringName] = {
	&"keycard": &"cue.keycard_beep", &"door_open": &"cue.door_open", &"door_close": &"cue.door_close",
	&"lockpick": &"cue.door_open",
}
## Device kind (device_started) -> [loop, jam, done] cues.
@export var device_cues: Dictionary[StringName, PackedStringArray] = {
	&"drill": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
	&"saw": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
	&"thermal": PackedStringArray(["cue.drill_loop", "cue.drill_jam", "cue.drill_done"]),
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
var _follow: Dictionary[Node, int] = {}
var _last_play_ms: Dictionary[String, int] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _detect_last: Dictionary[int, float] = {}
var _pager_guard: Dictionary[int, int] = {}
var _device_kind: Dictionary[int, StringName] = {}
var _alarm_gen: int = 0


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


# --- public API ------------------------------------------------------------------------------


## Play a cue once (or start it, if it is a loop and you keep the returned player). `position`
## NO_POSITION = flat; a positional cue with a resolvable `source_net_id` plays at that node.
## Returns the player node, or null when suppressed by cooldown.
func play_cue(cue_id: StringName, position: Vector3 = NO_POSITION, source_net_id: int = 0,
		pitch: float = 1.0) -> Node:
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
	var stream: AudioStream = AudioCueLib.pick_stream(cue, _rng)
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
		if cue.loop and source_net_id != 0 and Ids.lookup(source_net_id) is Node3D:
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
	var p: Node = play_cue(cue_id, position, source_net_id)
	if p != null:
		_loops[key] = p


func stop_loop(key: StringName) -> void:
	if not _loops.has(key):
		return
	var p: Node = _loops[key]
	_loops.erase(key)
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
		return StringName("cue.weapon_%s_fire%s" % [def.anim_set, "_suppressed" if suppressed else ""])
	var w: String = String(weapon_id).to_lower()
	var family: String = "pistol"
	for token: String in ["rifle", "carbine", "_ar", "smg", "lmg"]:
		if w.contains(token):
			family = "rifle"
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
	EventBus.loot_picked.connect(_on_loot_picked)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.loot_secured.connect(_on_loot_secured)
	EventBus.small_loot_taken.connect(_on_small_loot_taken)
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.assault_phase_changed.connect(_on_assault_phase_changed)


func _on_audio_cue_requested(cue_id: StringName, position: Vector3, source_net_id: int) -> void:
	play_cue(cue_id, position, source_net_id)


func _on_heist_loaded(heist_id: StringName, _run_seed: int, _variants: Dictionary) -> void:
	_stop_alarm()
	stop_all_loops()
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
	if gen == _alarm_gen and alarm_active:
		start_loop(SIREN_KEY, &"cue.police_siren_far")


func _on_bell_timer(gen: int) -> void:
	if gen == _alarm_gen:
		stop_loop(ALARM_KEY)


func _on_crew_masked(crew_slot: int) -> void:
	_play_at_crew(&"cue.mask_on", crew_slot)


func _on_crew_downed(crew_slot: int, _downs_used: int) -> void:
	_play_at_crew(&"cue.crew_downed", crew_slot)


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


func _on_interaction_started(interactable_net_id: int, _crew_slot: int, kind: StringName) -> void:
	if interaction_loop_cues.has(kind):
		start_loop(StringName("interact_%d" % interactable_net_id), interaction_loop_cues[kind], NO_POSITION,
				interactable_net_id)


func _on_interaction_cancelled(interactable_net_id: int, _crew_slot: int) -> void:
	stop_loop(StringName("interact_%d" % interactable_net_id))


func _on_interaction_completed(interactable_net_id: int, _crew_slot: int, kind: StringName) -> void:
	stop_loop(StringName("interact_%d" % interactable_net_id))
	if interaction_done_cues.has(kind):
		play_cue(interaction_done_cues[kind], NO_POSITION, interactable_net_id)


func _on_device_started(device_net_id: int, kind: StringName, _duration: float) -> void:
	_device_kind[device_net_id] = kind
	var cues: PackedStringArray = device_cues.get(kind, PackedStringArray())
	if cues.size() == 3:
		start_loop(_device_key(device_net_id), StringName(cues[0]), NO_POSITION, device_net_id)


func _on_device_jammed(device_net_id: int) -> void:
	stop_loop(_device_key(device_net_id))
	var cues: PackedStringArray = device_cues.get(_device_kind.get(device_net_id, &"drill"), PackedStringArray())
	if cues.size() == 3:
		play_cue(StringName(cues[1]), NO_POSITION, device_net_id)


func _on_device_restarted(device_net_id: int, _crew_slot: int) -> void:
	var cues: PackedStringArray = device_cues.get(_device_kind.get(device_net_id, &"drill"), PackedStringArray())
	if cues.size() == 3:
		start_loop(_device_key(device_net_id), StringName(cues[0]), NO_POSITION, device_net_id)


func _on_device_finished(device_net_id: int) -> void:
	stop_loop(_device_key(device_net_id))
	var cues: PackedStringArray = device_cues.get(_device_kind.get(device_net_id, &"drill"), PackedStringArray())
	if cues.size() == 3:
		play_cue(StringName(cues[2]), NO_POSITION, device_net_id)
	_device_kind.erase(device_net_id)


func _device_key(device_net_id: int) -> StringName:
	return StringName("device_%d" % device_net_id)


func _on_glass_broken(net_id: int, position: Vector3) -> void:
	play_cue(&"cue.glass_break", position, net_id)


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
	if play_weapon_fired:
		play_cue(weapon_fire_cue(weapon_id, suppressed), position, shooter_net_id)


func _on_assault_phase_changed(phase: int, _wave_index: int) -> void:
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
