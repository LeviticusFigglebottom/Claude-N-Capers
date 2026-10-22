## VO bark director (D-117 §6 "every VO line is said", pd2_fidelity C8). Owner: ENV A. Data: bark_tweak.tres.
## Service SERVICE, a child of HeistRuntime (_create_services). Runs on the SERVER only: it maps EventBus facts to
## VoiceLineTable events, picks a line with VoiceLineTable.lines_for (filtered by BarkTweak.patterns) and plays it
## the way every mission line plays: EventBus.voice_line_requested(speaker, id, {source: &"bark", slot}) locally
## plus Net.replicate_event (the [R] fact), so every peer hears and subtitles the same line once.
##
## Facts -> bark keys (<channel>.<event>; channel mercer = the handler, crew = a heister):
##   heist_phase_changed -> CASING          mercer.heist_start_casing (waits behind the mission intro)
##   crew_masked (not loud)                 mercer.crew_masked
##   pager_started                          mercer.pager_started
##   interaction_started answer_pager       crew.pager_started (the answerer)
##   pager_answered total < cap / > cap     mercer.pager_answered / mercer.pager_limit
##   pager_answered total == cap            PagerSystem calls say_now(mercer.pager_last_answer) (D-117)
##   pager_failed (not cancelled)           mercer.pager_failed
##   body_discovered                        mercer.body_discovered
##   StealthDirector.camera_countdown_started  mercer.camera_spotted
##   device_started / _finished             mercer.device_started / _finished (BarkTweak.mercer_device_kinds)
##   device_jammed                          crew.device_jammed (nearest heister) + mercer.device_jammed
##   crew_downed                            crew.crew_downed (the downed heister) + mercer.crew_downed
##   crew_custody                           mercer.crew_custody
##   interaction_started bag_body / revive  crew.bagging_body / crew.reviving (the actor)
##   alarm_raised (not stealth-only)        crew.going_loud (nearest heister to the source)
##   assault_phase_changed (cops phases)    crew.cops_incoming (a random standing heister)
##   loot_secured (valued)                  crew.loot_secured (the bag's last carrier, else the nearest)
##   npc_killed (guard role, by the crew)   crew.guard_down (the killer)
##   civilian_killed                        crew.civilian_killed (the killer)
##   CrewWeapons.reload_started (loud)      crew.reloading (that heister)
##   heist_ended                            mercer.stealth_success / heist_success / heist_failed (at once)
## Rules (PD2 C8): per-key cooldowns (BarkTweak.key_cooldown_s, shared by the crew) + each line's own cooldown_s;
## one speaker at a time (a queue; a line holds the channel for its talk time, then global_gap_s); a key already
## waiting is not queued twice; queued barks expire after max_wait_s. Mercer barks wait mercer_settle_s and are
## dropped when a comms line from someone else (mission say(), abort, last pager, contact radio) comes within that
## window, before or after the fact:
## mission VO has priority and is never doubled. No bark while any such line (radio included) is playing.
class_name BarkDirector
extends Node

## Server: a bark played (after voice_line_requested).
signal bark_played(key: StringName, speaker: StringName, line_id: StringName, slot: int)

const SERVICE: StringName = &"barks"
const SOURCE: StringName = &"bark"
const CH_MERCER: StringName = &"mercer"
const CH_CREW: StringName = &"crew"
const KEY_CASING: StringName = &"mercer.heist_start_casing"
const KEY_LAST_ANSWER: StringName = &"mercer.pager_last_answer"
const RNG_STREAM: StringName = &"voice"

var tweak: BarkTweak = null
var table: VoiceLineTable = null
## Director clock (s). Advanced by _physics_process; tests set auto_process = false and call advance().
var now_s: float = 0.0
var auto_process: bool = true
## The [R] path: func(signal_name, args). Tests capture it.
var replicate: Callable = Callable()
## Waiting barks: {key, event, speaker, slot, due, expires, priority}.
var queue: Array[Dictionary] = []
## The channel is busy until this time (a line is being said).
var busy_until: float = -1.0
var _runtime: HeistRuntime = null
var _active: bool = false
var _key_last: Dictionary = {}
var _id_last: Dictionary = {}
var _last_pick: Dictionary = {}
var _said_once: Dictionary = {}
var _device_kinds: Dictionary = {}
var _bag_carrier: Dictionary = {}
## When the last comms line from someone else arrived (-INF = never).
var _comms_at: float = -INF
var _conns: Array[Array] = []


static func of(node: Node) -> BarkDirector:
	var rt: HeistRuntime = HeistRuntime.of(node)
	return rt.service(SERVICE) as BarkDirector if rt != null else null


func _init() -> void:
	tweak = BarkTweak.get_default()
	table = load(ContactRadio.LINES_PATH) as VoiceLineTable  # B's VoiceLineTable (lines.tres)
	replicate = Net.replicate_event


func _ready() -> void:
	_runtime = HeistRuntime.of(self)
	if not Net.is_authority() or _runtime == null or table == null:
		return
	_active = true
	_link(EventBus.heist_phase_changed, _on_heist_phase_changed)
	_link(EventBus.crew_masked, _on_crew_masked)
	_link(EventBus.pager_started, _on_pager_started)
	_link(EventBus.pager_answered, _on_pager_answered)
	_link(EventBus.pager_failed, _on_pager_failed)
	_link(EventBus.body_discovered, _on_body_discovered)
	_link(EventBus.device_started, _on_device_started)
	_link(EventBus.device_jammed, _on_device_jammed)
	_link(EventBus.device_finished, _on_device_finished)
	_link(EventBus.crew_downed, _on_crew_downed)
	_link(EventBus.crew_custody, _on_crew_custody)
	_link(EventBus.interaction_started, _on_interaction_started)
	_link(EventBus.alarm_raised, _on_alarm_raised)
	_link(EventBus.assault_phase_changed, _on_assault_phase_changed)
	_link(EventBus.loot_picked, _on_loot_carried)
	_link(EventBus.loot_dropped, _on_loot_dropped)
	_link(EventBus.loot_secured, _on_loot_secured)
	_link(EventBus.npc_killed, _on_npc_killed)
	_link(EventBus.civilian_killed, _on_civilian_killed)
	_link(EventBus.heist_ended, _on_heist_ended)
	_link(EventBus.voice_line_requested, _on_voice_line_requested)
	_link(_runtime.crew_spawned, _on_crew_spawned)
	for c: CrewController in _runtime.crew_members():
		_on_crew_spawned(c.slot, c)
	if _runtime.stealth != null:
		_link(_runtime.stealth.camera_countdown_started, _on_camera_countdown_started)


func _exit_tree() -> void:
	for c: Array in _conns:
		var sig: Signal = c[0]
		if sig.is_connected(c[1]):
			sig.disconnect(c[1])
	_conns.clear()
	_active = false


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(delta)


## Moves the director clock on and plays the next due bark when the channel is free.
func advance(dt: float) -> void:
	now_s += dt
	_pump()


## Server: queue the bark `event` on `channel` (CH_MERCER, or CH_CREW said by `slot`'s heister). False when it
## cannot play (inactive, cooldown, once per heist, already waiting, no line for that speaker).
func request(channel: StringName, event: StringName, slot: int = -1) -> bool:
	if not _active:
		return false
	var key: StringName = StringName("%s.%s" % [channel, event])
	var speaker: StringName = CH_MERCER if channel == CH_MERCER else heister_of(slot)
	if speaker == &"" or not _key_ready(key):
		return false
	if channel == CH_MERCER and key != KEY_CASING and now_s - _comms_at < tweak.mercer_settle_s:
		return false  # a mission / system line of the same moment already covered it
	for q: Dictionary in queue:
		if q["key"] == key:
			return false
	var pool: Array[Dictionary] = _pool(key, event, speaker)
	if pool.is_empty():
		return false
	var prio: int = 0
	for l: Dictionary in pool:
		prio = maxi(prio, int(l.get("priority", 0)))
	var due: float = now_s + (tweak.mercer_settle_s if channel == CH_MERCER else 0.0)
	var wait: float = tweak.max_wait_s
	if key == KEY_CASING:
		wait = maxf(wait, tweak.casing_wait_s)
	queue.append({
		"key": key, "event": event, "speaker": speaker, "slot": slot, "due": due, "expires": due + wait,
		"priority": prio,
	})
	while queue.size() > maxi(tweak.max_queue, 1):
		var low: int = 0
		for i: int in queue.size():
			if int(queue[i]["priority"]) < int(queue[low]["priority"]):
				low = i
		queue.remove_at(low)
	_pump()
	return true


## Server: say Mercer's `event` line NOW, bypassing the queue (a system line that must land with its fact, e.g.
## PagerSystem's last free answer). Returns the line id (&"" = none).
func say_now(event: StringName) -> StringName:
	if not _active:
		return &""
	var key: StringName = StringName("%s.%s" % [CH_MERCER, event])
	var pool: Array[Dictionary] = _pool(key, event, CH_MERCER)
	if pool.is_empty():
		return &""
	_drop_mercer()
	return _play({"key": key, "event": event, "speaker": CH_MERCER, "slot": -1}, pool)


## VoiceLineTable speaker of `slot`'s crew member: Loadout.heister, else BarkTweak.fallback_heisters by slot.
func heister_of(slot: int) -> StringName:
	if slot < 0 or _runtime == null:
		return &""
	var c: CrewController = _runtime.crew_controller(slot) as CrewController
	if c == null:
		return &""
	if c.heister != &"" and VoiceLineTable.HEISTERS.has(c.heister):
		return c.heister
	if tweak.fallback_heisters.is_empty():
		return &""
	return tweak.fallback_heisters[slot % tweak.fallback_heisters.size()]


## True while a line holds the channel (or the global gap after it runs).
func is_busy() -> bool:
	return now_s < busy_until + tweak.global_gap_s


# --- Queue -----------------------------------------------------------------------------------

func _pump() -> void:
	if not _active:
		return
	for i: int in range(queue.size() - 1, -1, -1):
		if now_s > float(queue[i]["expires"]) or (queue[i]["key"] == KEY_CASING and _casing_line_moot()):
			queue.remove_at(i)
	if is_busy():
		return
	var best: int = -1
	for i: int in queue.size():
		if float(queue[i]["due"]) > now_s:
			continue
		if best < 0 or int(queue[i]["priority"]) > int(queue[best]["priority"]):
			best = i
	if best < 0:
		return
	var item: Dictionary = queue[best]
	queue.remove_at(best)
	if not _key_ready(item["key"]):
		return
	_play(item, _pool(item["key"], item["event"], item["speaker"]))


func _queued(key: StringName) -> bool:
	for q: Dictionary in queue:
		if q["key"] == key:
			return true
	return false


func _key_ready(key: StringName) -> bool:
	if tweak.once_per_heist.has(key) and _said_once.has(key):
		return false
	return not _key_last.has(key) or now_s - float(_key_last[key]) >= tweak.cooldown_of(key)


## Lines `speaker` may say for `key` now: their own lines of `event` matching the key's patterns, off cooldown.
func _pool(key: StringName, event: StringName, speaker: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in table.lines_for(event, speaker):
		var id: StringName = StringName(l.get("id", &""))
		if StringName(l.get("speaker", &"")) != speaker or not tweak.allows(key, id):
			continue
		if _id_last.has(id) and now_s - float(_id_last[id]) < float(l.get("cooldown_s", 0.0)):
			continue
		out.append(l)
	return out


func _play(item: Dictionary, pool: Array[Dictionary]) -> StringName:
	if pool.is_empty():
		return &""
	var key: StringName = item["key"]
	var speaker: StringName = item["speaker"]
	var memo: String = "%s|%s" % [speaker, key]
	var picks: Array[Dictionary] = []
	for l: Dictionary in pool:
		if pool.size() == 1 or StringName(l.get("id", &"")) != StringName(_last_pick.get(memo, &"")):
			picks.append(l)
	var line: Dictionary = picks[GameRng.stream(RNG_STREAM).randi_range(0, picks.size() - 1)]
	var id: StringName = StringName(line.get("id", &""))
	var slot: int = int(item.get("slot", -1))
	_last_pick[memo] = id
	_key_last[key] = now_s
	_id_last[id] = now_s
	_said_once[key] = true
	busy_until = maxf(busy_until, now_s + tweak.talk_s(_text(line)))
	var ctx: Dictionary = {"source": SOURCE, "slot": slot}
	EventBus.voice_line_requested.emit(speaker, id, ctx)
	if replicate.is_valid():
		replicate.call(&"voice_line_requested", [speaker, id, ctx])
	bark_played.emit(key, speaker, id, slot)
	return id


func _text(line: Dictionary) -> String:
	return StringTable.text(StringName(line.get("text_key", &"")))


## A comms line from someone else: waiting Mercer barks give way (the casing line waits behind the intro).
func _drop_mercer() -> void:
	for i: int in range(queue.size() - 1, -1, -1):
		if queue[i]["speaker"] == CH_MERCER and queue[i]["key"] != KEY_CASING:
			queue.remove_at(i)


# --- Who speaks ----------------------------------------------------------------------------------

## Standing crew member nearest to `pos` (any standing one when pos is INF); -1 = none.
func _nearest_slot(pos: Vector3) -> int:
	var best: int = -1
	var best_d: float = INF
	var standing: Array[int] = []
	for c: CrewController in _runtime.crew_members():
		if c.crew_state == Enums.CrewState.CUSTODY or c.crew_state == Enums.CrewState.DOWNED:
			continue
		standing.append(c.slot)
		if pos != Vector3.INF and c.is_inside_tree():  # a device jams while the map is freed (B's RT HUD run teardown)
			var d: float = c.global_position.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = c.slot
	if best < 0 and not standing.is_empty():
		best = standing[GameRng.stream(RNG_STREAM).randi_range(0, standing.size() - 1)]
	return best


func _pos_of(net_id: int) -> Vector3:
	var n: Node3D = Ids.lookup(net_id) as Node3D if net_id != 0 else null
	return n.global_position if n != null and n.is_inside_tree() else Vector3.INF


func _slot_of_net_id(net_id: int) -> int:
	for c: CrewController in _runtime.crew_members():
		if c.net_id == net_id and net_id != 0:
			return c.slot
	return -1


# --- Facts -----------------------------------------------------------------------------------

func _on_heist_phase_changed(_old: int, new_phase: int) -> void:
	if new_phase == Enums.HeistPhase.CASING and not _casing_line_moot():
		request(CH_MERCER, &"heist_start_casing")


## B-SL audit: the generic casing line ("look like you belong") is moot once the heist said its own intro, or once
## the crew left casing (masked / loud).
func _casing_line_moot() -> bool:
	if _runtime == null:
		return true
	if _runtime.mission != null and _runtime.mission.own_intro_line:
		return true
	return _runtime.phase != Enums.HeistPhase.CASING and _runtime.phase != Enums.HeistPhase.LOADING


func _on_crew_masked(_slot: int) -> void:
	var ph: int = _runtime.phase
	if not _runtime.went_loud and (ph == Enums.HeistPhase.CASING or ph == Enums.HeistPhase.STEALTH):
		request(CH_MERCER, &"crew_masked")


func _on_pager_started(_pager_id: int, _guard_net_id: int) -> void:
	request(CH_MERCER, &"pager_started")


func _on_pager_answered(_pager_id: int, _slot: int, total: int) -> void:
	var pagers: PagerSystem = _runtime.service(G.SVC_PAGERS) as PagerSystem
	var cap: int = pagers.max_answers if pagers != null else 0
	if total < cap:
		request(CH_MERCER, &"pager_answered")
	elif total > cap:
		request(CH_MERCER, &"pager_limit")


func _on_pager_failed(_pager_id: int, reason: StringName) -> void:
	if reason != &"cancelled":
		request(CH_MERCER, &"pager_failed")


func _on_body_discovered(_body: int, _by: int) -> void:
	request(CH_MERCER, &"body_discovered")


func _on_camera_countdown_started(_camera_net_id: int, _seconds: float) -> void:
	request(CH_MERCER, &"camera_spotted")


func _on_device_started(device_net_id: int, kind: StringName, _duration: float) -> void:
	_device_kinds[device_net_id] = kind
	if tweak.mercer_device_kinds.has(kind):
		request(CH_MERCER, &"device_started")


func _on_device_jammed(device_net_id: int) -> void:
	request(CH_CREW, &"device_jammed", _nearest_slot(_pos_of(device_net_id)))
	if tweak.mercer_device_kinds.has(_device_kinds.get(device_net_id, &"")):
		request(CH_MERCER, &"device_jammed")


func _on_device_finished(device_net_id: int) -> void:
	if tweak.mercer_device_kinds.has(_device_kinds.get(device_net_id, &"")):
		request(CH_MERCER, &"device_finished")


func _on_crew_downed(slot: int, _downs_used: int) -> void:
	request(CH_CREW, &"crew_downed", slot)
	request(CH_MERCER, &"crew_downed")


func _on_crew_custody(slot: int) -> void:
	for i: int in range(queue.size() - 1, -1, -1):
		if int(queue[i]["slot"]) == slot and queue[i]["speaker"] != CH_MERCER:
			queue.remove_at(i)
	request(CH_MERCER, &"crew_custody")


func _on_interaction_started(_net_id: int, slot: int, kind: StringName) -> void:
	var ev: StringName = StringName(tweak.interaction_events.get(kind, &""))
	if ev != &"":
		request(CH_CREW, ev, slot)


func _on_alarm_raised(_reason: StringName, source_net_id: int) -> void:
	if _runtime.heist_mode != Enums.HeistMode.STEALTH_ONLY:
		request(CH_CREW, &"going_loud", _nearest_slot(_pos_of(source_net_id)))


func _on_assault_phase_changed(phase: int, _wave: int) -> void:
	if tweak.cops_incoming_phases.has(phase):
		request(CH_CREW, &"cops_incoming", _nearest_slot(Vector3.INF))


func _on_loot_carried(bag_net_id: int, slot: int) -> void:
	_bag_carrier[bag_net_id] = slot


func _on_loot_dropped(bag_net_id: int, slot: int, _thrown: bool) -> void:
	_bag_carrier[bag_net_id] = slot


func _on_loot_secured(bag_net_id: int, loot_id: StringName, value: int) -> void:
	if value <= 0 or tweak.ignored_loot.has(loot_id):
		return
	var slot: int = int(_bag_carrier.get(bag_net_id, -1))
	if slot < 0:
		slot = _nearest_slot(_pos_of(bag_net_id))
	request(CH_CREW, &"loot_secured", slot)


func _on_npc_killed(npc_net_id: int, killer_net_id: int, _info: Dictionary) -> void:
	var npc: NpcBase = Ids.lookup(npc_net_id) as NpcBase
	if npc == null or not tweak.guard_roles.has(npc.role):
		return
	var slot: int = _slot_of_net_id(killer_net_id)
	if slot >= 0:
		request(CH_CREW, &"guard_down", slot)


func _on_civilian_killed(_npc_net_id: int, slot: int) -> void:
	if slot >= 0:
		request(CH_CREW, &"civilian_killed", slot)


func _on_reload_started(_weapon_slot: int, _duration: float, slot: int) -> void:
	if tweak.reload_loud_only and not _runtime.went_loud:
		return
	request(CH_CREW, &"reloading", slot)


func _on_heist_ended(result: Dictionary) -> void:
	if not _active:
		return
	var ev: StringName = &"heist_failed"
	if bool(result.get("success", false)):
		ev = &"stealth_success" if bool(result.get("stealth", false)) else &"heist_success"
	var key: StringName = StringName("%s.%s" % [CH_MERCER, ev])
	queue.clear()
	if _key_ready(key):
		_play({"key": key, "event": ev, "speaker": CH_MERCER, "slot": -1}, _pool(key, ev, CH_MERCER))
	_active = false


func _on_voice_line_requested(speaker: StringName, line_id: StringName, ctx: Dictionary) -> void:
	if StringName(ctx.get("source", &"")) == SOURCE:
		return
	var comms: bool = tweak.comms_speakers.has(speaker)
	if not comms and not tweak.hold_speakers.has(speaker):
		return
	if comms:
		_drop_mercer()
		_comms_at = now_s
	var line: Dictionary = table.line(line_id)
	var text: String = _text(line) if not line.is_empty() else StringTable.text(StringName("voice.%s" % line_id))
	busy_until = maxf(busy_until, now_s + tweak.talk_s(text))


func _on_crew_spawned(slot: int, crew: Node) -> void:
	var c: CrewController = crew as CrewController
	if c == null or c.weapons == null:
		return
	_link(c.weapons.reload_started, _on_reload_started.bind(slot))


func _link(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)
		_conns.append([sig, cb])
