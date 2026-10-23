## Rolling Thunder mission flow (RT-A6, D-151). Owner: ENV A. Design: docs/design/heists/rolling_thunder.md §Objectives /
## Mission script notes / Convoy / Truck targets / Escape; docs/process/next_heist_rolling_thunder.md §6. Contract
## heist_map.md §6: only the HeistMission API, EventBus and nodes of this map (found by objective_tag / names).
## STAGE 1 (G1): setup clock (marshal, ETA lines, sighted), signals -> clean stop / no signals or an early alarm -> crash
## stop, the stop (ConvoyLayouts: movers drive onto the layout's stop markers when the map has them, else the layout
## pops in), convoy units (seated in movers, else beside the G1 bodies), the 8 s window and the ambush alarm, the early-
## alarm lockdown (police at once, trucks locked down, crash stop), trucks (opened n/N, cargo spawned at the truck when
## it carries none), escort down, [secure] 4 bags -> the ride after escape_eta_s, every RT VO line. Rare events: stage 2.
## Not offered in menus until G1 plays end to end (B's readiness gate).
## The map's tags: casing, signals, charges, thermite, thermite_bag, marshal, convoy, ambush, escort, trucks, cargo,
## secure, escape, escape_wait, goods_lift, lift_breaker, player_perch, pay_station, diner_till, diner_safe, petty_cash,
## frame_ladder, site_gate, bonds_courier, holdout_h1..h4.
class_name RollingThunderMission
extends HeistMission

## Bags to secure (doc Loot path, D-075): cash bricks and / or gold.
const REQUIRED_BAGS: int = 4
const REQUIRED_LOOT: Array[StringName] = [&"loot.cash_bricks", &"loot.gold"]
const LOOT_CASH: StringName = &"loot.cash_bricks"
const LOOT_GOLD: StringName = &"loot.gold"
const ITEM_C4: StringName = &"item.c4"
const LOOT_THERMITE: StringName = &"loot.thermite"

const TAG_SIGNALS: StringName = &"signals"
const TAG_SECURE: StringName = &"secure"
const TAG_ESCAPE: StringName = &"escape"
const TAG_ESCAPE_WAIT: StringName = &"escape_wait"
const TAG_MARSHAL_SPAWN: StringName = &"vl_marshal"
const TAG_CIV_FLEE: StringName = &"civ_flee"

## Setup clock (doc Mission script notes): the marshal at ETA - 75 s (- 90 with marshal_early), sighted at ETA - 20 s.
const MARSHAL_LEAD_S: float = 75.0
const MARSHAL_EARLY_LEAD_S: float = 90.0
const SIGHTED_LEAD_S: float = 20.0
const CONVOY_EARLY_S: float = 45.0
## Clean stop: the mixer moves at stop + 3 s, the window ends at stop + 8 s; units dismount 4 s after the alarm.
const MIXER_MOVE_S: float = 3.0
const WINDOW_S: float = 8.0
const DISMOUNT_DELAY_S: float = 4.0
## D-158 truck window ◇: the first assault's BUILD begins no sooner than this many seconds after the stop (crash or
## clean, any difficulty), so the crew gets at the trucks before wave 1 lands (later alarm-based anticipation still rules).
## The live value and its start point are RtTweak (truck_window_s / truck_window_from); this is its default.
const TRUCK_WINDOW_S: float = 30.0
const POLL_S: float = 1.0
## Convoy layout node and its pieces (C's G1 / RT-C2): `<route slot>/Convoy/<Clean|Crash>` (meta convoy_layout
## "<route>_<clean|crash>"), movers at `<route slot>/Convoy/Movers/<Veh>` with `<Veh>Stop` markers in each layout.
const MOVERS_PATH: String = "Convoy/Movers"
const STOP_SUFFIX: String = "Stop"
const VEHICLES: Array[String] = ["Lead", "T1", "T2", "T3", "Rear"]
## Runtime marker tags: the trucks in play / an opened truck (C's fixed Trucks / Cargo markers sit on one route only).
const TAG_TRUCK_IN_PLAY: StringName = &"rt_truck"
const TAG_TRUCK_OPEN: StringName = &"rt_cargo"
## Setup steps closed when the convoy arrives (B's HUD capture: an unrigged [signals] led the HUD through the fight).
const SETUP_STEPS: Array[StringName] = [&"casing", &"signals", &"charges", &"thermite", &"marshal"]

const RARE_MARSHAL_EARLY: StringName = &"marshal_early"
const RARE_CONVOY_EARLY: StringName = &"convoy_early"
const RARE_INFORMANT: StringName = &"informant_tip"
const RARE_CRANE: StringName = &"crane_sniper"
const RARE_ARMORED_ESCORT: StringName = &"armored_escort"
const RARE_RUSH_HOUR: StringName = &"rush_hour"
## Perch tags (the map): S3 in the crane cab only on crane_sniper; S4 (Ashby) from Hazardous (doc Perches active).
const PERCH_CRANE: StringName = &"crane_sniper"
const PERCH_ASHBY: StringName = &"ashby"
const WRECKER: StringName = &"enemy.wrecker"
## Street pedestrians (`civilians` scalar 6 / 9 / 12; rush_hour 12).
const TAG_CIV_STREET: StringName = &"civ_street"
const TAG_CIV_DINER: StringName = &"civ_diner"
const TAG_LIFT_BREAKER: StringName = &"lift_breaker"
const PAUSE_CABINET: StringName = &"cabinet_locked"
## D-154.2 revised (B fd41028a): an early alarm brings the convoy at most this many seconds later (it stops at about
## +35 s, inside wave 1's quiet ANTICIPATION, not on SUSTAIN as +75 did).
const EARLY_PUSH_S: float = 25.0
## D-154 amended: the crash stop's crews / TAC Heavy get out over this many seconds after the escorts.
const CRASH_DISMOUNT_S: float = 6.0
## RT phase 2 (C): the Mixer ConvoyVehicle, each convoy layout's MixerPath / MixerStop, the Tannery gates' tag.
const MIXER_NAME: String = "Mixer"
const MIXER_PATH: NodePath = ^"MixerPath"
const MIXER_STOP: NodePath = ^"MixerStop"
## C: the gate Door(s) the mixer's move opens carry this meta `opens_with`; the mixer's own COVER carries this tag.
const OPENS_WITH_MIXER: StringName = &"mixer_move"
const TAG_MIXER_COVER: StringName = &"mixer"
const TAG_REYES: StringName = &"driver_mixer"
## QC-85 (audio_cues v1.9): C's RT one-shots.
const CUE_APPROACH: StringName = &"cue.convoy_approach"
const CUE_BRAKE: StringName = &"cue.convoy_brake"
const CUE_MIXER_RAM: StringName = &"cue.mixer_ram"
const CUE_SIGNAL_CLICK: StringName = &"cue.signal_click"
const CUE_TRAIN: StringName = &"cue.freight_train_pass"
## The junction's signal heads (C's dress props, metadata kind).
const SIGNAL_KIND: StringName = &"traffic_signal"
## doc Ambience: a freight train over the underpass rail bridge every 90-150 s (tracks x 70 / 80, rail level +1.2, the
## underpass road at z 0). Held back while a Phantom charge is live (re-checked every TRAIN_HOLD_S).
const TRAIN_POS: Vector3 = Vector3(75.0, 1.2, 0.0)
const TRAIN_GAP_S: Vector2 = Vector2(90.0, 150.0)
const TRAIN_HOLD_S: float = 2.0
## Diner customers (doc Cast: 2-5 in the booths): 3, rush_hour adds its extra_diner_customers (+2).
const DINER_CUSTOMERS: int = 3
const RNG_STREAM: StringName = &"rt_mission"

## Convoy units per vehicle (doc "Convoy units per difficulty"): escorts by difficulty (Routine/Tense patrol cars,
## Hazardous+ SUVs), two Vaultline crew per truck.
const ESCORT_LOW: Array[StringName] = [&"enemy.patrol_officer", &"enemy.patrol_officer"]
const ESCORT_LEAD_HIGH: Array[StringName] = [&"enemy.tac_light", &"enemy.tac_light"]
const ESCORT_REAR_HIGH: Array[StringName] = [&"enemy.tac_light", &"enemy.tac_light", &"enemy.tac_heavy"]
const VAULTLINE_CREW: Array[StringName] = [&"enemy.security_officer", &"enemy.security_officer"]
## D-149.12: the escorts' own EnemyDefs (looks by difficulty) once B / D land them; the rows above until then.
const ESCORT_DEFS: Dictionary = {"Lead": &"enemy.convoy_lead", "Rear": &"enemy.convoy_rear"}
const ESCORT_SWAPPED: Array[StringName] = [&"enemy.patrol_officer", &"enemy.tac_light"]

const SPEAKER_REYES: StringName = &"reyes"
const VO_INTRO: StringName = &"vo.mercer.rolling_thunder_intro"
const VO_ETA_60: StringName = &"vo.mercer.rolling_thunder_eta_60"
const VO_ETA_30: StringName = &"vo.mercer.rolling_thunder_eta_30"
const VO_MARSHAL: StringName = &"vo.mercer.rolling_thunder_marshal"
const VO_SIGNALS_DONE: StringName = &"vo.mercer.rolling_thunder_signals_done"
const VO_SIGNALS_REMIND: StringName = &"vo.mercer.rolling_thunder_signals_remind"
const VO_C4_FOUND: StringName = &"vo.mercer.rolling_thunder_c4_found"
const VO_THERMITE_FOUND: StringName = &"vo.mercer.rolling_thunder_thermite_found"
const VO_SIGHTED: StringName = &"vo.mercer.rolling_thunder_sighted"
const VO_STOPPED: StringName = &"vo.mercer.rolling_thunder_stopped"
const VO_GO: StringName = &"vo.mercer.rolling_thunder_go"
const VO_ALERTED: StringName = &"vo.mercer.rolling_thunder_alerted"
const VO_ESCORT_DOWN: StringName = &"vo.mercer.rolling_thunder_escort_down"
const VO_POLICE: StringName = &"vo.mercer.rolling_thunder_police"
const VO_SAW_ON: StringName = &"vo.mercer.rolling_thunder_saw_on"
const VO_SAW_JAM: StringName = &"vo.mercer.rolling_thunder_saw_jam"
const VO_DEADBOLTS: StringName = &"vo.mercer.rolling_thunder_deadbolts"
const VO_TRUCK_OPEN: StringName = &"vo.mercer.rolling_thunder_truck_open"
const VO_C4_ARMED: StringName = &"vo.mercer.rolling_thunder_c4_armed"
const VO_THERMITE_BURN: StringName = &"vo.mercer.rolling_thunder_thermite_burn"
const VO_GOLD: StringName = &"vo.mercer.rolling_thunder_gold"
const VO_BONDS: StringName = &"vo.mercer.rolling_thunder_bonds"
const VO_LIFT_DEAD: StringName = &"vo.mercer.rolling_thunder_lift_dead"
const VO_SNIPER_SKYWAY: StringName = &"vo.mercer.rolling_thunder_sniper_skyway"
const VO_SNIPER_RAIL: StringName = &"vo.mercer.rolling_thunder_sniper_rail"
const VO_SNIPER_CRANE: StringName = &"vo.mercer.rolling_thunder_sniper_crane"
const VO_SECURED: StringName = &"vo.mercer.rolling_thunder_secured"
const VO_VAN_ETA: StringName = &"vo.mercer.rolling_thunder_van_eta"
const VO_HELI_ETA: StringName = &"vo.mercer.rolling_thunder_heli_eta"
const VO_ESCAPE: StringName = &"vo.mercer.rolling_thunder_escape"
const VO_REYES_READY: StringName = &"vo.reyes.rolling_thunder_ready"
const VO_REYES_BOXED: StringName = &"vo.reyes.rolling_thunder_boxed"
const VO_REYES_CRASH: StringName = &"vo.reyes.rolling_thunder_crash"
const VO_REYES_PAYDAY: StringName = &"vo.reyes.rolling_thunder_payday"
## Longshot perches (the map's TacticalPoint tags) -> line, once per perch (L4.7; S4 Ashby has none of its own).
const SNIPER_LINES: Dictionary = {&"s1": VO_SNIPER_SKYWAY, &"s2": VO_SNIPER_RAIL, &"s3": VO_SNIPER_CRANE}
const SPECIAL_LONGSHOT: String = "longshot"
## Rare bonds_courier (doc Rare events): T1's courier case, 2 LIGHT bags of bonds at the map's `bonds_courier` marker
## (G1; the cab safe comes with the truck art).
const RARE_BONDS: StringName = &"bonds_courier"
const LOOT_BONDS: StringName = &"loot.bearer_bonds"
const BONDS_BAGS: int = 2

## &"en_route" -> &"stopped".
var convoy_state: StringName = &"en_route"
## The setup was blown before the convoy came (police at once, crash stop, trucks locked down).
var alerted: bool = false
var signals_rigged: bool = false
## "<route>_<clean|crash>" once stopped.
var layout_id: String = ""
var clean_stop: bool = false
var required_secured: int = 0
var escape_open: bool = false

var _eta_s: float = 0.0
var _units: Array[NpcBase] = []
var _seated: Array[NpcBase] = []
var _units_total: int = 0
var _trucks: Array[ArmoredTruck] = []
var _opened: Dictionary = {}
var _said: Dictionary = {}
var _escape_called: bool = false
var _movers_left: int = 0
## Every mover is on its stop (the layout is in and the stop's objectives are up).
var _stop_done: bool = false
## Last published [trucks opened, escort down] (the poll publishes only changes).
var _last_counts: Vector2i = Vector2i(-1, -1)


func _on_mission_start() -> void:
	_eta_s = float(_scalar(&"convoy_eta_s", 180.0))
	if _rare(RARE_CONVOY_EARLY):
		_eta_s += float(_fx(RARE_CONVOY_EARLY, &"convoy_eta_add_s", -CONVOY_EARLY_S))
	police_delay_s = float(_scalar(&"police_delay_s", 60.0))
	_apply_rare_setup()
	_add(&"casing", Enums.ObjectiveState.ACTIVE, [&"casing"])
	_add(&"signals", Enums.ObjectiveState.ACTIVE, [TAG_SIGNALS])
	if not find_tagged(&"charges").is_empty():
		_add(&"charges", Enums.ObjectiveState.ACTIVE, [&"charges"])
	if not find_tagged(&"thermite").is_empty():
		_add(&"thermite", Enums.ObjectiveState.ACTIVE, [&"thermite"])
	_add(&"marshal", Enums.ObjectiveState.HIDDEN, [&"marshal"])
	_add(&"convoy", Enums.ObjectiveState.ACTIVE, [&"convoy"], {"seconds": _eta_s})
	for id: StringName in [&"ambush", &"escort", &"trucks", &"cargo"]:
		_add(id, Enums.ObjectiveState.HIDDEN, [id])
	_add(&"secure", Enums.ObjectiveState.HIDDEN, [TAG_SECURE], {"count": 0, "total": REQUIRED_BAGS, "optional_more": true})
	_add(&"escape_wait", Enums.ObjectiveState.HIDDEN, [TAG_ESCAPE_WAIT])
	_add(&"escape", Enums.ObjectiveState.HIDDEN, [TAG_ESCAPE])
	var marshal_lead: float = float(_fx(RARE_MARSHAL_EARLY, &"marshal_lead_s", MARSHAL_EARLY_LEAD_S)) \
		if _rare(RARE_MARSHAL_EARLY) else MARSHAL_LEAD_S
	schedule_at(maxf(_eta_s - marshal_lead, 1.0), &"marshal", _spawn_marshal)
	schedule_at(maxf(_eta_s - 60.0, 1.0), &"eta_60", _eta_60)
	schedule_at(maxf(_eta_s - 30.0, 1.0), &"eta_30", func() -> void: _say_once(VO_ETA_30))
	schedule_at(maxf(_eta_s - SIGHTED_LEAD_S, 1.0), &"sighted", _sighted)
	schedule_at(_eta_s, &"convoy", _convoy_arrives)
	on_event(&"device_finished", _on_device_finished)
	on_event(&"device_started", _on_device_started)
	on_event(&"device_jammed", func(_id: int) -> void: _say_once(VO_SAW_JAM))
	on_event(&"item_picked_up", _on_rt_item_picked)
	on_event(&"loot_picked", _on_loot_picked)
	on_event(&"loot_secured", _on_bag_secured)
	on_event(&"special_spawned", _on_special_spawned)
	say(VO_INTRO)
	say(VO_REYES_READY, {}, SPEAKER_REYES)
	_schedule_train()
	_seat_reyes()


## Rare events and difficulty rows at the start (doc Rare events / Convoy units per difficulty): the street's
## pedestrian count, the informant's reveals, the perches.
func _apply_rare_setup() -> void:
	var civs: int = int(_fx(RARE_RUSH_HOUR, &"civilians", int(_scalar(&"civilians", 9)))) if _rare(RARE_RUSH_HOUR) \
		else int(_scalar(&"civilians", 9))
	thin_civilians(TAG_CIV_STREET, civs)
	if _rare(RARE_INFORMANT):
		for g: Variant in _fx(RARE_INFORMANT, &"reveal", []) as Array:
			reveal_variant_group(StringName(g))
	var diner: int = DINER_CUSTOMERS + (int(_fx(RARE_RUSH_HOUR, &"extra_diner_customers", 2)) if _rare(RARE_RUSH_HOUR) else 0)
	thin_civilians(TAG_CIV_DINER, diner)
	if _slot_active(&"goods_lift", &"lift_dead"):
		_power_lift(false)
	if _slot_active(&"controller", &"ctrl_locked"):
		_lock_cabinet()
	set_sniper_perches_open(PERCH_CRANE, _rare(RARE_CRANE))
	if _runtime != null and _runtime.difficulty < Enums.Difficulty.HAZARDOUS:
		set_sniper_perches_open(PERCH_ASHBY, false)


## doc Variants controller: ctrl_locked = the cabinet's padlock (8 s pick, or cut) before the rig can be worked; the
## rig is paused (blocked) until the padlock is off.
func _lock_cabinet() -> void:
	var rig: HackTerminal = null
	var lock: Padlock = null
	for n: Node in find_tagged(TAG_SIGNALS):
		if n is HackTerminal:
			rig = n as HackTerminal
		elif n is Padlock:
			lock = n as Padlock
	if rig == null or lock == null or lock.opened:
		return
	rig.pause(PAUSE_CABINET)
	lock.lock_opened.connect(func(_how: StringName) -> void: rig.resume(PAUSE_CABINET), CONNECT_ONE_SHOT)


## Server: a cue for every peer (audio_cues: EventBus.audio_cue_requested, relayed).
func _cue(cue_id: StringName, pos: Vector3, net_id: int) -> void:
	if not Net.is_authority():
		return
	EventBus.audio_cue_requested.emit(cue_id, pos, net_id)
	Net.replicate_event(&"audio_cue_requested", [cue_id, pos, net_id])


func _schedule_train() -> void:
	start_timer(&"freight_train", GameRng.stream(RNG_STREAM).randf_range(TRAIN_GAP_S.x, TRAIN_GAP_S.y), _train)


## The freight train passes, unless a Phantom charge is live (doc: the train never overlaps cue.phantom_charge).
func _train() -> void:
	if phantom_charge_live():
		start_timer(&"freight_train", TRAIN_HOLD_S, _train)
		return
	_cue(CUE_TRAIN, TRAIN_POS, 0)
	_schedule_train()


func phantom_charge_live() -> bool:
	for n: Node in _runtime.npcs():  # a director spawn may carry any role: the brain says it is a Phantom
		var b: PhantomBrain = n.get_node_or_null(^"Brain") as PhantomBrain
		if b != null and b.goggles_glowing:
			return true
	return false


## C's phase-2 `Mixer`: the rolled route's `<slot>/Convoy/Movers/Mixer` ConvoyVehicle, null on a map without one.
func _mixer() -> ConvoyVehicle:
	var slot: Node = _route_slot()
	return slot.get_node_or_null(NodePath(MOVERS_PATH + "/" + MIXER_NAME)) as ConvoyVehicle if slot != null else null


## C (phase 2): Reyes (the driver_mixer civilian) sits at the Mixer's wheel (Seat0) from the start.
func _seat_reyes() -> void:
	var mixer: ConvoyVehicle = _mixer()
	if mixer == null:
		return
	var seats: Array[Node3D] = mixer.seats()
	if seats.is_empty():
		return
	for n: Node in _runtime.npcs(&"civilian"):
		var npc: NpcBase = n as NpcBase
		if _has_spawn_tag(npc, [TAG_REYES]):
			npc.global_transform = seats[0].global_transform
			_seat(npc, mixer, true, true)  # D r280: seen at the wheel, though the Mixer's kind is "truck"
			return


func _power_lift(on: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"goods_lift"):
		if n is BagLift and _runtime.is_ancestor_of(n):
			(n as BagLift).set_powered(on)


func _add(id: StringName, state: Enums.ObjectiveState, tags: Array, data: Dictionary = {}) -> void:
	var d: Dictionary = data.duplicate()
	d["marker_tags"] = tags
	add_objective(id, StringName("objective.rolling_thunder.%s" % id), state, d)


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if old_phase == Enums.HeistPhase.CASING and new_phase != Enums.HeistPhase.CASING:
		_complete_once(&"casing")


# --- Setup ---------------------------------------------------------------------------------------

func _eta_60() -> void:
	_say_once(VO_ETA_60)
	if not signals_rigged:
		_say_once(VO_SIGNALS_REMIND)


func _spawn_marshal() -> void:
	if went_loud or convoy_state != &"en_route":
		return
	var m: Array[Node] = spawn_guards(1, TAG_MARSHAL_SPAWN)
	if m.is_empty():
		return
	if _rare(RARE_MARSHAL_EARLY):
		_second_check(m[0] as NpcBase)
	activate(&"marshal")
	_say_once(VO_MARSHAL)


## marshal_early: the marshal walks a second check after his own (another `marshal_walk` graph, by the mission stream).
func _second_check(npc: NpcBase) -> void:
	var brain: GuardBrain = npc.get_node_or_null(^"Brain") as GuardBrain if npc != null else null
	if brain == null:
		return
	var others: Array[PatrolGraph] = []
	for n: Node in _runtime.map.find_children("*", "PatrolGraph", true, false):
		var g: PatrolGraph = n as PatrolGraph
		if String(g.graph_id).begins_with("marshal_") and not _slot_active(&"marshal_walk", g.graph_id):
			others.append(g)
	if others.is_empty():
		return
	others.sort_custom(func(a: PatrolGraph, b: PatrolGraph) -> bool: return String(a.graph_id) < String(b.graph_id))
	brain.extend_route(others[GameRng.stream(RNG_STREAM).randi_range(0, others.size() - 1)])


func _sighted() -> void:
	_say_once(VO_SIGHTED)
	var lead: Node3D = _vehicle("Lead", null)
	if lead != null:
		_cue(CUE_APPROACH, lead.global_position, NetIds.of(lead))


## [signals]: the junction rig's hack finished (doc: without it the stop is a crash).
func _on_device_finished(device_net_id: int) -> void:
	var dev: Node = Ids.lookup(device_net_id)
	if dev != null and _tagged(dev, TAG_LIFT_BREAKER):
		_power_lift(true)  # doc Variants goods_lift: the plant-room breaker restores a dead lift
	if dev != null and _tagged(dev, TAG_SIGNALS) and dev is HackTerminal and not signals_rigged:
		signals_rigged = true
		_complete_once(&"signals")
		for n: Node in _runtime.map.find_children("Signal*", "Node3D", true, false):
			if StringName(n.get_meta(&"kind", &"")) == SIGNAL_KIND:
				_cue(CUE_SIGNAL_CLICK, (n as Node3D).global_position + Vector3(0.0, 3.0, 0.0), 0)
		_say_once(VO_SIGNALS_DONE)


func _on_device_started(device_net_id: int, kind: StringName, _duration: float) -> void:
	var dev: Node = Ids.lookup(device_net_id)
	if dev == null or not _on_a_truck(dev):
		return
	match kind:
		&"saw":
			_say_once(VO_SAW_ON)
		&"c4":
			_say_once(VO_C4_ARMED)
		&"thermite":
			_say_once(VO_THERMITE_BURN)


func _on_rt_item_picked(item_id: StringName, _slot: int) -> void:
	if item_id == ITEM_C4:
		_complete_once(&"charges")
		_say_once(VO_C4_FOUND)


func _on_loot_picked(bag_net_id: int, _slot: int) -> void:
	var bag: LootBag = Ids.lookup(bag_net_id) as LootBag
	if bag == null:
		return
	if bag.loot_id == LOOT_BONDS:
		_say_once(VO_BONDS)
	elif bag.loot_id == LOOT_THERMITE:
		_complete_once(&"thermite")
		_say_once(VO_THERMITE_FOUND)
	elif REQUIRED_LOOT.has(bag.loot_id) and convoy_state == &"stopped":
		_complete_once(&"cargo")


# --- Alarm / the stop ---------------------------------------------------------------------------

func _on_alarm(_reason: StringName) -> void:
	civilians_flee(TAG_CIV_FLEE)
	if convoy_state == &"en_route":
		# Early alarm (doc): police at once, the convoy alerted (crash stop, immediate dismount, lockdown).
		alerted = true
		police_delay_s = 0.0
		_say_once(VO_ALERTED)
		_say_once(VO_POLICE)
		_push_through()
		return
	if not _stop_done:
		return  # the drive-in: _stopped() springs it with [trucks] / [escort] up (B's HUD run: no empty objective line)
	_spring_ambush()


## B's approved early-alarm balance (rt_early_alarm_balance.md item 1; doc "Vaultline pushes through to the depot"):
## after an early alarm the convoy arrives at min(its ETA, alarm + EARLY_PUSH_S), so wave 1's BUILD is a fight over the
## trucks, not dead time. The setup's clock lines that would come after the new arrival are dropped.
func _push_through() -> void:
	var left: float = timer_left(&"convoy")
	if left <= EARLY_PUSH_S:
		return
	start_timer(&"convoy", EARLY_PUSH_S, _convoy_arrives)
	update_objective_data(&"convoy", {"seconds": EARLY_PUSH_S})
	for id: StringName in [&"eta_60", &"eta_30", &"marshal"]:
		if timer_left(id) > EARLY_PUSH_S:
			cancel_timer(id)
	start_timer(&"sighted", maxf(EARLY_PUSH_S - SIGHTED_LEAD_S, 0.1), _sighted)


## The ambush is on: [ambush] done, Mercer's go, the police line, the dismount (the stop's objectives are already up).
func _spring_ambush() -> void:
	_complete_once(&"ambush")
	_say_once(VO_GO)
	start_timer(&"police_line", maxf(police_delay_s, 0.1), func() -> void: _say_once(VO_POLICE))
	start_timer(&"dismount", 0.1 if not clean_stop else DISMOUNT_DELAY_S, _dismount_all)
	if _slot_active(&"goods_lift", &"lift_dead"):
		_say_once(VO_LIFT_DEAD)


## ETA: the convoy arrives. Clean with the signals rigged and nobody alerted; else the crash.
func _convoy_arrives() -> void:
	if convoy_state != &"en_route":
		return
	convoy_state = &"stopped"
	clean_stop = signals_rigged and not alerted
	layout_id = "%s_%s" % [_route(), "clean" if clean_stop else "crash"]
	_complete_once(&"convoy")
	_close_setup()
	activate(&"ambush")
	var movers: Array[ConvoyVehicle] = _movers()
	var layout: Node3D = ConvoyLayouts.find(_runtime.map, layout_id)
	var legs: Array[Array] = []  # [mover, its stop marker]: counted before any drives (park() stops at once)
	for v: ConvoyVehicle in movers:
		var stop: Node3D = _stop_marker(layout, String(v.name))
		if stop != null:
			legs.append([v, stop])
	_movers_left = legs.size()
	if legs.is_empty():
		_stopped()
		return
	for leg: Array in legs:
		var v: ConvoyVehicle = leg[0]
		v.vehicle_stopped.connect(func(id: int) -> void:
			_cue(CUE_BRAKE, v.global_position, id)
			_mover_stopped(), CONNECT_ONE_SHOT)
		var path: Path3D = _drive_path(v)
		if path != null:
			v.drive(path, leg[1] as Node3D)
		else:
			v.park(leg[1] as Node3D)


## `<Veh>Stop` in `layout`; on trucks_2 the rear car closes up behind T2 at `RearStop2` when the layout has one (C),
## at a clean stop only with RtTweak.rear_close_up_clean (D-158 amendment 9).
func _stop_marker(layout: Node3D, veh: String) -> Node3D:
	if layout == null:
		return null
	var clean: bool = String(layout.get_meta(&"convoy_layout", "")).ends_with("_clean")
	if veh == "Rear" and _slot_active(&"truck_count", &"trucks_2") and (not clean or RtTweak.data().rear_close_up_clean):
		var short: Node3D = layout.get_node_or_null(NodePath(veh + STOP_SUFFIX + "2")) as Node3D
		if short != null:
			return short
	return layout.get_node_or_null(NodePath(veh + STOP_SUFFIX)) as Node3D


## The setup is over: every setup step still open is skipped (OF's [code_pc] pattern: data skipped, then COMPLETED, so
## the HUD leads with the stop's steps).
func _close_setup() -> void:
	for id: StringName in SETUP_STEPS:
		if objective_state(id) == Enums.ObjectiveState.ACTIVE:
			update_objective_data(id, {"skipped": true, "reason": &"convoy"})
			complete(id)


func _mover_stopped() -> void:
	_movers_left -= 1
	if _movers_left == 0:
		_stopped()


## Every vehicle is on its stop marker: swap the layout in, units, trucks, then the window (clean) or the impact (crash).
func _stopped() -> void:
	_stop_done = true
	var dir: AssaultDirector = _director()
	var rtw: RtTweak = RtTweak.data()
	if dir != null:
		# D-158 / LEAD r286 levers (RtTweak; defaults = the shipped behaviour)
		dir.first_build_hold_s = rtw.escort_down_max_s if rtw.truck_window_from == RtTweak.FROM_ESCORT_DOWN \
			else rtw.truck_window_s
		if not rtw.wave1_exclude.is_empty() and _runtime.difficulty >= rtw.wave1_exclude_min_difficulty:
			dir.wave1_exclude = rtw.wave1_exclude.duplicate()
	set_layout(layout_id)
	if _slot_active(&"truck_count", &"trucks_2"):
		_drop_vehicle("T3")
	_trucks = _find_trucks()
	for t: ArmoredTruck in _trucks:
		t.objective_tag = TAG_TRUCK_IN_PLAY  # [trucks] marks the stopped trucks themselves, not one fixed marker
	if alerted:
		for t: ArmoredTruck in _trucks:
			t.lockdown()
		_say_once(VO_DEADBOLTS)
	_spawn_convoy_units()
	_apply_escort_accuracy()
	if _rare(RARE_BONDS):
		spawn_loot(LOOT_BONDS, RARE_BONDS, BONDS_BAGS)
	update_objective_data(&"trucks", {"opened": 0, "total": _trucks.size(), "marker_tags": [TAG_TRUCK_IN_PLAY]})
	activate(&"trucks")
	activate(&"escort")
	update_objective_data(&"escort", {"down": 0, "total": _units_total, "marker_tags": []})  # the units are the marks
	activate(&"secure")
	start_timer(&"poll", POLL_S, _poll)
	if clean_stop:
		_say_once(VO_STOPPED)
		start_timer(&"mixer_move", MIXER_MOVE_S, _mixer_move)
		start_timer(&"window", WINDOW_S, func() -> void: raise_alarm(&"ambush"))
		return
	_say_once(VO_REYES_CRASH, {}, SPEAKER_REYES)
	_mixer_move()
	if alerted:
		_complete_once(&"ambush")  # an early alarm: the crash is the ambush (no second alarm comes)
		_dismount_all()
	elif went_loud:
		_spring_ambush()  # the alarm came during the drive-in
	else:
		raise_alarm(&"ambush")


## The mixer boxes the convoy in (clean: stop + 3 s; crash: the impact): Reyes's line, the Tannery gates open.
func _mixer_move() -> void:
	var layout: Node3D = ConvoyLayouts.find(_runtime.map, layout_id)
	var mixer: ConvoyVehicle = _mixer()
	var stop: Node3D = layout.get_node_or_null(MIXER_STOP) as Node3D if layout != null else null
	if mixer != null and stop != null:
		# RT phase 2 (C f2c05253): the gate(s) with meta opens_with = "mixer_move" swing open and the Mixer (Reyes at
		# the wheel) drives the layout's MixerPath onto its MixerStop (the layout's nav is baked with it there); the
		# cover it gave at its start goes with it.
		for n: Node in _runtime.map.find_children("*", "Door", true, false):
			var d: Door = n as Door
			if StringName(d.get_meta(&"opens_with", &"")) == OPENS_WITH_MIXER:
				d.unlock()
				d.set_open(true, false, true)
		for n: Node in _runtime.map.find_children("*", "TacticalPoint", true, false):
			var tp: TacticalPoint = n as TacticalPoint
			if tp.kind == TacticalPoint.Kind.COVER and tp.tags.has(TAG_MIXER_COVER):
				tp.set_enabled(false)
		var path: Path3D = layout.get_node_or_null(MIXER_PATH) as Path3D
		if path != null:
			mixer.drive(path, stop)
		else:
			mixer.park(stop)
	var lead: Node3D = _vehicle("Lead", ConvoyLayouts.find(_runtime.map, layout_id))
	if lead != null:
		_cue(CUE_MIXER_RAM, lead.global_position, 0)  # the mixer hits the lead escort (crash) / boxes it in (clean)
	_say_once(VO_REYES_BOXED, {}, SPEAKER_REYES)


func _spawn_convoy_units() -> void:
	var high: bool = _runtime != null and _runtime.difficulty >= Enums.Difficulty.HAZARDOUS
	var layout: Node3D = ConvoyLayouts.find(_runtime.map, layout_id)
	for veh: String in VEHICLES:
		var body: Node3D = _vehicle(veh, layout)
		if body == null:
			continue
		var ids: Array[StringName] = VAULTLINE_CREW
		if veh == "Lead":
			ids = ESCORT_LEAD_HIGH if high else ESCORT_LOW
		elif veh == "Rear":
			ids = (ESCORT_REAR_HIGH if high else ESCORT_LOW).duplicate()
			if _rare(RARE_ARMORED_ESCORT):
				ids.append(WRECKER)  # Lethal+: a Wrecker rides in the rear escort
		if ESCORT_DEFS.has(veh) and has_enemy(ESCORT_DEFS[veh]):
			# D-149.12: the escort officers wear the car's EnemyDef; the TAC Heavy and the Wrecker keep theirs
			var own: Array[StringName] = []
			for id: StringName in ids:
				own.append(ESCORT_DEFS[veh] if ESCORT_SWAPPED.has(id) else id)
			ids = own
		# D-154 amended (LEAD): a crash stop seats them too, so the dismount can be staggered (_dismount_crash)
		var seat: bool = body is ConvoyVehicle
		var look_tag: StringName = StringName("convoy_" + veh.to_lower())  # convoy_lead / convoy_t1.. / convoy_rear
		for i: int in ids.size():
			# D: the Wrecker's helmet clears no car door frame: it rides along but starts beside the car
			var got: Array[NpcBase] = spawn_units(ids[i], 1, look_tag, seat and ids[i] != WRECKER, body)
			for u: NpcBase in got:
				u.set_meta(StealthDirector.META_ALARM_REASON, &"ambush")  # QC-83 (d): their alarm is the ambush
				_units.append(u)
				if seat:
					_seated.append(u)
				elif went_loud:
					u.set_alert_state(Enums.AlertState.COMBAT)
	_units_total = _units.size()


func _dismount_all() -> void:
	if not clean_stop:
		_dismount_crash()
		return
	dismount_units(_seated)
	_seated.clear()


## D-154 amended (LEAD, lever (a)): on the crash stop the escort officers get out at once, the Vaultline crews and the
## rear TAC Heavy over the next CRASH_DISMOUNT_S (seeded per unit), so the crew does not meet all eleven at once.
func _dismount_crash() -> void:
	var rng: RandomNumberGenerator = GameRng.stream(RNG_STREAM)
	var first: Array[NpcBase] = []
	for v: Variant in _seated:
		if not is_instance_valid(v):
			continue
		var u: NpcBase = v as NpcBase
		var tags: Array = u.spawn_info.get("tags", []) as Array
		var def_id: StringName = u.enemy_def.id if u.enemy_def != null else &""
		if (tags.has(&"convoy_lead") or tags.has(&"convoy_rear")) and def_id != &"enemy.tac_heavy":
			first.append(u)
			continue
		var unit: NpcBase = u
		start_timer(StringName("dismount_%d" % u.get_instance_id()), rng.randf_range(1.0, CRASH_DISMOUNT_S),
			func() -> void: dismount_units([unit]))
	dismount_units(first)
	_seated.clear()


## Longshots (L4.7): the line names the perch he holds, once per perch.
func _on_special_spawned(npc_net_id: int, special_type: StringName) -> void:
	if not String(special_type).contains(SPECIAL_LONGSHOT):
		return
	var perch: TacticalPoint = sniper_perch_of(npc_net_id)
	if perch == null:
		return
	for tag: StringName in SNIPER_LINES:
		if perch.tags.has(tag):
			_say_once(SNIPER_LINES[tag])


# --- Trucks / escort / loot ----------------------------------------------------------------------

func _poll() -> void:
	var opened: int = 0
	for t: ArmoredTruck in _trucks:
		if not is_instance_valid(t) or not t.opened:
			continue
		opened += 1
		if not _opened.has(t.get_instance_id()):
			_opened[t.get_instance_id()] = true
			_truck_opened(t)
	var down: int = 0
	for u: NpcBase in _units:
		if not is_instance_valid(u) or not u.alive:
			down += 1
	if opened != _last_counts.x:
		update_objective_data(&"trucks", {"opened": opened, "total": _trucks.size()})
		if not _trucks.is_empty() and opened >= _trucks.size():
			_complete_once(&"trucks")
	if down != _last_counts.y:
		update_objective_data(&"escort", {"down": down, "total": _units_total})
		if _units_total > 0 and down >= _units_total:
			_complete_once(&"escort")
			_say_once(VO_ESCORT_DOWN)
			_escort_down_window()
	_last_counts = Vector2i(opened, down)
	if not escape_open:
		start_timer(&"poll", POLL_S, _poll)


## RtTweak escort_accuracy_mult: every convoy unit hits at that multiple for escort_accuracy_window_s from the stop.
func _apply_escort_accuracy() -> void:
	var rtw: RtTweak = RtTweak.data()
	if is_equal_approx(rtw.escort_accuracy_mult, 1.0):
		return
	for u: NpcBase in _units:
		var g: NpcGunner = u.get_node_or_null(^"Gunner") as NpcGunner if is_instance_valid(u) else null
		if g != null:
			g.hit_chance_mult = rtw.escort_accuracy_mult
			g.hit_chance_mult_left = rtw.escort_accuracy_window_s


## RtTweak escort_engage_delay_s: a convoy unit that just got out holds fire that long.
func _on_dismounted(npc: NpcBase) -> void:
	var delay: float = RtTweak.data().escort_engage_delay_s
	var g: NpcGunner = npc.get_node_or_null(^"Gunner") as NpcGunner
	if delay > 0.0 and g != null and _units.has(npc):
		g.engage_hold_left = delay


## RtTweak.FROM_ESCORT_DOWN: the last convoy unit is down, so the BUILD hold now ends truck_window_s from here (or at
## stop + escort_down_max_s, whichever comes first).
func _escort_down_window() -> void:
	var dir: AssaultDirector = _director()
	var rtw: RtTweak = RtTweak.data()
	if dir != null and rtw.truck_window_from == RtTweak.FROM_ESCORT_DOWN and dir.first_build_hold_s > 0.0:
		dir.first_build_hold_s = minf(dir.first_build_hold_s, rtw.truck_window_s)


## A truck's rear doors opened: its line, and its cargo when the map gave it none (G1: bags at its rear doors).
func _truck_opened(t: ArmoredTruck) -> void:
	say(VO_TRUCK_OPEN)
	t.objective_tag = TAG_TRUCK_OPEN  # the marker moves on to what is inside
	if objective_state(&"cargo") == Enums.ObjectiveState.HIDDEN:
		update_objective_data(&"cargo", {"marker_tags": [TAG_TRUCK_OPEN]})
		activate(&"cargo")
	var bullion: bool = String(t.get_meta(&"truck_kind", "cash")) == "bullion" or t.saw_duration_s >= 150.0
	if bullion:
		_say_once(VO_GOLD)
	if t.find_children("*", "LootSpawn", true, false).is_empty():
		var n: int = int(_scalar(&"gold_bags" if bullion else &"cash_bags", 4))
		spawn_loot_at(LOOT_GOLD if bullion else LOOT_CASH, _cargo_spot(t), n)


## Where spawned cargo lands: the rear step (the truck's UsePoint), outside the hold's collision box. G1 pilot: bags at
## the LootAnchor sat inside the body, and the hold blocked the pick-up's line of sight (doc: bagged from the rear step).
func _cargo_spot(t: ArmoredTruck) -> Node3D:
	return t.use_point if t.use_point != null else t


func _on_bag_secured(_bag_net_id: int, loot_id: StringName, _value: int) -> void:
	if not REQUIRED_LOOT.has(loot_id):
		return
	required_secured += 1
	update_objective_data(&"secure", {"count": required_secured, "total": REQUIRED_BAGS})
	if required_secured >= REQUIRED_BAGS and objective_state(&"secure") != Enums.ObjectiveState.COMPLETED:
		complete(&"secure")
		_complete_once(&"cargo")
		say(VO_SECURED)
		_call_escape()


func _call_escape() -> void:
	if _escape_called:
		return
	_escape_called = true
	var eta: float = float(_scalar(&"escape_eta_s", 120.0)) + (20.0 if _heli() else 0.0)
	update_objective_data(&"escape_wait", {"seconds": eta})
	activate(&"escape_wait")
	say(VO_HELI_ETA if _heli() else VO_VAN_ETA, {"seconds": int(eta)})
	start_timer(&"escape_eta", eta, open_escape)


func open_escape() -> void:
	if escape_open:
		return
	escape_open = true
	_complete_once(&"escape_wait")
	for n: Node in find_tagged(TAG_ESCAPE):
		if n is EscapeZone:
			(n as EscapeZone).arrival_delay_s = 0.0  # the wait already ran: the ride is here
	activate(&"escape")
	say(VO_ESCAPE)
	_say_once(VO_REYES_PAYDAY, {}, SPEAKER_REYES)
	activate_escape(TAG_ESCAPE)


# --- Map helpers ---------------------------------------------------------------------------------

func _route() -> String:
	return "east" if _slot_active(&"convoy_route", &"route_east") else "north"


func _route_slot() -> Node:
	if _runtime == null or _runtime.map == null:
		return null
	for n: Node in _runtime.map.find_children("Slot_route_" + _route(), "", true, false):
		return n
	return null


func _movers() -> Array[ConvoyVehicle]:
	var out: Array[ConvoyVehicle] = []
	var slot: Node = _route_slot()
	var holder: Node = slot.get_node_or_null(MOVERS_PATH) if slot != null else null
	if holder != null:
		for c: Node in holder.get_children():
			if c is ConvoyVehicle and String(c.name) != MIXER_NAME:  # the Mixer moves at _mixer_move, not at the stop
				out.append(c as ConvoyVehicle)
	return out


## The mover's drive-in path `<Veh>Path`: beside it under Movers, under `Convoy/Paths` (C's G1), or its own Path3D child.
func _drive_path(v: ConvoyVehicle) -> Path3D:
	var name_path: NodePath = NodePath(String(v.name) + "Path")
	var p: Path3D = v.get_parent().get_node_or_null(name_path) as Path3D
	if p == null and v.get_parent().get_parent() != null:
		p = v.get_parent().get_parent().get_node_or_null(NodePath("Paths/" + String(name_path))) as Path3D
	if p == null:
		for c: Node in v.get_children():
			if c is Path3D:
				return c as Path3D
	return p


## Vehicle `veh` ("Lead", "T1".. "Rear") of the stopped convoy: its mover, else the layout's G1 body (`<Mode><Veh>`).
func _vehicle(veh: String, layout: Node3D) -> Node3D:
	var slot: Node = _route_slot()
	var mover: Node3D = slot.get_node_or_null(NodePath(MOVERS_PATH + "/" + veh)) as Node3D if slot != null else null
	if mover != null and mover.visible:
		return mover
	if layout == null:
		return null
	var mode: String = "Clean" if clean_stop else "Crash"
	var body: Node3D = layout.get_node_or_null(NodePath(mode + veh)) as Node3D
	return body if body != null and body.visible else null


## trucks_2: the third truck is not in the convoy (its mover or body hidden and out of play).
func _drop_vehicle(veh: String) -> void:
	var layout: Node3D = ConvoyLayouts.find(_runtime.map, layout_id)
	var v: Node3D = _vehicle(veh, layout)
	if v == null:
		return
	if v is GameplayPrefab:
		(v as GameplayPrefab).set_enabled(false)
	else:
		v.visible = false
		v.process_mode = Node.PROCESS_MODE_DISABLED
	for t: Node in v.find_children("*", "ArmoredTruck", true, false):
		(t as GameplayPrefab).set_enabled(false)


## The convoy's armored_trucks in play: under the active layout and the route's movers.
func _find_trucks() -> Array[ArmoredTruck]:
	var out: Array[ArmoredTruck] = []
	var roots: Array[Node] = []
	var layout: Node3D = ConvoyLayouts.find(_runtime.map, layout_id)
	if layout != null:
		roots.append(layout)
	var slot: Node = _route_slot()
	if slot != null and slot.get_node_or_null(MOVERS_PATH) != null:
		roots.append(slot.get_node(MOVERS_PATH))
	for r: Node in roots:
		for n: Node in r.find_children("*", "ArmoredTruck", true, false):
			var t: ArmoredTruck = n as ArmoredTruck
			if t.is_enabled() and not out.has(t):
				out.append(t)
	return out


func _on_a_truck(dev: Node) -> bool:
	var n: Node = dev
	while n != null:
		if n is ArmoredTruck:
			return true
		n = n.get_parent()
	return dev.get(&"target") is NodePath and _target_is_truck(dev)


func _target_is_truck(dev: Node) -> bool:
	var tp: NodePath = dev.get(&"target") as NodePath
	return not tp.is_empty() and dev.get_node_or_null(tp) is ArmoredTruck


func _heli() -> bool:
	return _slot_active(&"escape", &"esc_heli_roof")


func _tagged(n: Node, tag: StringName) -> bool:
	var t: Variant = n.get(&"objective_tag")
	return t != null and StringName(t) == tag


func _rare(id: StringName) -> bool:
	return rare_effects().has(id)


## A rolled rare event's effect value (`fallback` when the event did not roll or has no such key).
func _fx(event_id: StringName, key: StringName, fallback: Variant) -> Variant:
	var fx: Variant = rare_effects().get(event_id)
	return (fx as Dictionary).get(key, fallback) if fx is Dictionary else fallback


func _scalar(id: StringName, fallback: Variant) -> Variant:
	var v: Variant = variant(id)
	return fallback if v == null else v


func _slot_active(group: StringName, slot_id: StringName) -> bool:
	var v: Variant = variant(group)
	return v is Array and (v as Array).has(slot_id)


func _complete_once(id: StringName) -> void:
	var st: int = objective_state(id)
	if st == Enums.ObjectiveState.ACTIVE or st == Enums.ObjectiveState.HIDDEN:
		complete(id)


func _say_once(line: StringName, context: Dictionary = {}, speaker: StringName = SPEAKER_MERCER) -> void:
	if _said.has(line):
		return
	_said[line] = true
	say(line, context, speaker)
