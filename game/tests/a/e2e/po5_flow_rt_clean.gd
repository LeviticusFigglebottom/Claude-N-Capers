## RT-A6 (D-149.4, LEAD round 274): the Rolling Thunder clean-stop loud run on the REAL menus, headless. P plays the
## windowed real-input version (RT-P1 / the P5 clean-setup gate) on this route.
## Stealth prelude (X4StealthFlow and its stated shortcuts: teleports onto the navmesh next to each UsePoint,
## crew.stealth_hidden so guards, the marshal, pedestrians and cameras never see the bot, waits at Engine.time_scale
## FAST): mask up -> the site man-gate's padlock (lockpick) -> the controller cabinet's padlock (ctrl_locked) -> the
## signal rig hack, every interruption restarted -> back to the heist start -> the convoy to its CLEAN stop. From the
## stop the auto_loud pilot (input only, po5_flow_auto_loud.gd) plays the rest: its shots spring the ambush in the
## 8 s window, then trucks, bags, the ride. Checks: [signals] done before the stop, no alarm before it, clean_stop,
## [ambush] sprung after it (any alarm then: the window's end, a shot, a guard seeing the masked crew), heist_ended(success).
## run: DIRECT=1 HEADLESS=1 game/tests/a/e2e/run_po5.sh rt_clean <seed> 2400 <out> "Rolling Thunder" Routine
extends RefCounted

const AUTO_LOUD: String = "res://tests/a/e2e/po5_flow_auto_loud.gd"
const MAN_GATE_LOCK: NodePath = ^"Gameplay/Doors/SiteManGate/Padlock"
const LOCK_PICK_S: float = 30.0
const ITEM_C4: StringName = &"item.c4"
## RT_STORES=1 (--po5-rt-stores, LEAD: a C4 breach and a thermite burn e2e): the prelude also raids the site stores
## (the magazine's C4 through its padlock, the tool store's thermite bag through its lock) and carries the thermite
## back; the loud pilot then uses the C4 on a truck (the truck takes C4 before the saw) and burns one with the
## thermite (po5_flow_auto_loud _deliver_tool: the truck's own burn point).
var raid_stores: bool = "--po5-rt-stores" in OS.get_cmdline_user_args()


func play(driver: Node) -> int:
	var rt: HeistRuntime = driver.get(&"rt") as HeistRuntime
	var m: RollingThunderMission = rt.mission as RollingThunderMission
	if m == null:
		driver.call(&"note", "FAIL rt_clean: not the Rolling Thunder mission (%s)" % rt.heist_id)
		return 1
	var flow: X4StealthFlow = X4StealthFlow.new(driver)
	flow.sink = func(line: String) -> void: driver.call(&"note", line)
	if not await flow.attach(rt, rt.run_seed):
		return _fail(driver, flow, "attach to the menu-launched runtime")
	var start: Transform3D = (rt.crew_controller(0) as Node3D).global_transform
	var vo: Callable = func(speaker: StringName, line_id: StringName, _c: Dictionary) -> void:
		driver.call(&"note", "EVENT vo %s %s t=%.0f" % [speaker, line_id, rt.heist_time_s])  # auto_loud logs its own
	EventBus.voice_line_requested.connect(vo)
	flow.hide_from_observers()
	if not await flow.mask_up():
		return _fail(driver, flow, "mask up")
	if not await _rig_the_signals(flow, rt, m) or (raid_stores and not await _raid_stores(flow, rt, m)):
		return _fail(driver, flow, "the signals / the site stores")
	var carrying_before: bool = flow.crew.is_carrying_bag()
	rt.teleport_crew(0, start)
	await flow.wait_until(func() -> bool: return false, 0.2)
	flow.note("teleported back: carrying %s -> %s" % [carrying_before, flow.crew.is_carrying_bag()])
	flow.note("back at the start (%s), waiting for the convoy (ETA %.0f s)" % [start.origin, m.timer_left(&"convoy")])
	var budget: float = m.timer_left(&"convoy") + 120.0
	var stopped: bool = await flow.fast_until(func() -> bool: return m._stop_done, budget)
	flow.check(stopped, "the convoy stopped (%s)" % m.layout_id)
	flow.check(m.clean_stop, "a CLEAN stop (layout %s)" % m.layout_id)
	flow.check(flow.alarms.is_empty(), "no alarm before the stop (%s)" % [flow.alarms])
	flow.crew.stealth_hidden = false
	# LEAD D-151: the escort's first 60 s from the clean stop (who is up, alerted, shooting, from where).
	Po5EscortLog.new().start(driver, rt, func(line: String) -> void: driver.call(&"note", line))
	flow.note("clean stop %s at %.1f s heist: observers on, the loud pilot takes over" % [m.layout_id, rt.heist_time_s])
	EventBus.voice_line_requested.disconnect(vo)
	flow.note("hand-over: carrying %s (%s)" % [flow.crew.is_carrying_bag(),
		(flow.crew.carried_bag as LootBag).loot_id if flow.crew.is_carrying_bag() else &""])
	var failures: Array[String] = flow.failures.duplicate()
	flow.detach()
	if not failures.is_empty():
		driver.call(&"note", "FAIL rt_clean prelude: %s" % [failures])
		return 1
	var ended: Array[Dictionary] = []
	var at_end: Dictionary = {}
	var on_end: Callable = func(r: Dictionary) -> void:  # the runtime is freed by the payday: read it now
		ended.append(r)
		at_end.merge({"sprung": m.objective_state(&"ambush") == Enums.ObjectiveState.COMPLETED,
			"reason": rt.stealth.alarm_reason if rt.stealth != null else &"", "clean": m.clean_stop})  # captured by ref
	EventBus.heist_ended.connect(on_end)
	var seed_v: int = rt.run_seed
	var loud: RefCounted = (load(AUTO_LOUD) as GDScript).new()
	var rc: int = await loud.call(&"play", driver)
	EventBus.heist_ended.disconnect(on_end)
	# Any alarm after the clean stop springs the ambush (the window's end, a convoy unit, or a guard who sees the
	# masked crew): no alarm before the stop is checked above.
	var ok: bool = rc == 0 and bool(at_end.get("sprung", false)) and not ended.is_empty() \
		and bool(ended[0].get("success", false))
	driver.call(&"note", "RESULT rt_clean %s seed %d: %s, auto_loud rc %d, success %s" % [
		"PASS" if ok else "FAIL", seed_v, at_end, rc, ended[0].get("success", false) if not ended.is_empty() else false])
	return 0 if ok else 1


## The site man-gate, the cabinet (ctrl_locked) and the rig's hack, until [signals] is done.
func _rig_the_signals(flow: X4StealthFlow, rt: HeistRuntime, m: RollingThunderMission) -> bool:
	var gate: Padlock = rt.map.get_node_or_null(MAN_GATE_LOCK) as Padlock
	if gate != null and not await _pick(flow, gate, "the man-gate padlock"):
		return false
	var rig: HackTerminal = null
	var cabinet: Padlock = null
	for n: Node in m.find_tagged(RollingThunderMission.TAG_SIGNALS):
		if n is HackTerminal:
			rig = n as HackTerminal
		elif n is Padlock:
			cabinet = n as Padlock
	if not flow.check(rig != null, "the signal rig"):
		return false
	if cabinet != null and m._slot_active(&"controller", &"ctrl_locked") \
			and not await _pick(flow, cabinet, "the cabinet padlock"):
		return false
	if not await flow.run_hack(rig):
		return false
	var done: bool = await flow.wait_until(func() -> bool: return m.signals_rigged, 3.0)
	return flow.check(done and flow.objective(&"signals") == Enums.ObjectiveState.COMPLETED, "[signals] done")


## The rolled site stores: every C4 box (through the magazine's padlock) and the thermite bag (through the tool store's
## lock), the bag carried back on the bot's back.
func _raid_stores(flow: X4StealthFlow, rt: HeistRuntime, m: RollingThunderMission) -> bool:
	var mag: Padlock = rt.map.get_node_or_null(^"Gameplay/Doors/MagazineDoor/Padlock") as Padlock
	for n: Node in m.find_tagged(&"charges"):
		var box: GameplayPrefab = n as GameplayPrefab
		if box == null or box is Padlock or box is Door or not box.is_visible_in_tree() or box.interactable == null \
				or not box.interactable.enabled:  # [charges] also tags the magazine's padlock / door
			continue
		if mag != null and not await _pick(flow, mag, "the magazine padlock"):
			return false
		var had: int = flow.crew.item_count(ITEM_C4)
		if not await flow.go_to(box) or not await flow.use(box, func() -> bool: return flow.crew.item_count(ITEM_C4) > had,
				15.0, "take the C4 from %s" % box.name):
			return false
	for n: Node in m.find_tagged(&"thermite"):
		var bag: LootSpawn = n as LootSpawn
		if bag == null or not bag.is_visible_in_tree() or bag.remaining <= 0:
			continue
		var store: Door = rt.map.get_node_or_null(^"Gameplay/Doors/ToolStoreDoor") as Door
		if store != null and store.locked:
			if not await flow.go_to(store) or not await flow.use(store, func() -> bool: return not store.locked,
					LOCK_PICK_S, "pick the tool store door"):
				return false
		if not await flow._bag_from(bag):
			return false
	flow.note("stores raided: C4 x%d, thermite %s" % [flow.crew.item_count(ITEM_C4), flow.crew.is_carrying_bag()])
	return true


## Lockpick `lock` (S2: masked, 8 s) unless it is already off.
func _pick(flow: X4StealthFlow, lock: Padlock, what: String) -> bool:
	if lock.opened:
		return true
	if not await flow.go_to(lock):
		return false
	return await flow.use(lock, func() -> bool: return lock.opened, LOCK_PICK_S, "pick %s" % what)


func _fail(driver: Node, flow: X4StealthFlow, what: String) -> int:
	flow.detach()
	driver.call(&"note", "FAIL rt_clean: %s; failures %s" % [what, flow.failures])
	return 1
