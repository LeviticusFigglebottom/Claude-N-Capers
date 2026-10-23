## AH-A1 (D-165): AfterhoursMission on a synthetic map (ATestMaps.basic + the agreed objective tags + its Mission node),
## so the mission logic is proven before ENV C's G1 map lands. Facts are driven through EventBus as the prefabs emit
## them. The stealth line (gear -> keycard -> office -> code -> safe -> loot -> 3 bags -> escape), the loud lockdown
## (keypad off, office door breachable, stampede, escape_wait: 2nd FADE and 300 s), the drill path, Mercer's gear line
## per gear_drop slot, the loot counts and the rare events (count_left_open, extra_product, co_op_pickup).
extends TestCase

const MISSION: String = "res://world/heists/afterhours/afterhours_mission.gd"

var _rt: HeistRuntime = null
var _lines: Array[StringName] = []
var _line_cb: Callable = func(_s: StringName, id: StringName, _c: Dictionary) -> void: _lines.append(id)
var _nodes: Dictionary = {}


func before_each() -> void:
	_lines.clear()
	EventBus.voice_line_requested.connect(_line_cb)


func after_each() -> void:
	if EventBus.voice_line_requested.is_connected(_line_cb):
		EventBus.voice_line_requested.disconnect(_line_cb)
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


## The synthetic Velvet: one slot per pinned group, the tagged prefabs / loot markers, AfterhoursMission.
func _map(pins: Dictionary, rares: Array[StringName] = [], scalars: Dictionary = {}) -> PackedScene:
	var groups: Dictionary = {}
	var rules: Array[Dictionary] = []
	for g: StringName in pins:
		groups[g] = [pins[g]]
		rules.append({"group": g, "pick": Vector2i(1, 1)})
	var vt: HeistVariantTable = HeistVariantTable.new()
	vt.rules = rules
	var rare_rows: Array[Dictionary] = []
	for id: StringName in [&"count_left_open", &"extra_product", &"co_op_pickup", &"off_duty_cop", &"rooftop_watch"]:
		rare_rows.append({"id": id, "chance": 1.0 if rares.has(id) else 0.0, "effects": {}})
	vt.rare_events = rare_rows
	var sc: Array[Dictionary] = []
	for id: StringName in scalars:
		sc.append({"id": id, "values": [scalars[id]], "weights": PackedFloat32Array([1.0])})
	vt.scalars = sc
	var root: HeistMap = ATestMaps.basic(0, 0, groups, vt).instantiate() as HeistMap
	root.get_node("Mission").set_script(load(MISSION))
	var gp: Node = root.get_node("Gameplay")
	var add: Callable = func(prefab: String, nm: String, tag: StringName, pos: Vector3) -> Node:
		var p: GameplayPrefab = (load("res://systems/prefabs/%s/%s.tscn" % [prefab, prefab]) as PackedScene).instantiate()
		p.name = nm
		p.position = pos
		p.objective_tag = tag
		gp.add_child(p)
		return p
	add.call("door", "OfficeDoor", &"office_door", Vector3(4, 0, -8)).set(&"lock", Door.Lock.KEYCARD)
	add.call("keycard_reader", "OfficeReader", &"office_reader", Vector3(3, 1.2, -7.8))
	add.call("safe", "Safe", &"safe", Vector3(8, 0, -12)).set(&"methods", [&"code", &"drill"] as Array[StringName])
	add.call("drill_point", "SafeDrill", &"safe_drill", Vector3(8, 0.6, -11.5))
	add.call("secure_zone", "VanSecure", &"loot_secure", Vector3(-8, 0, 8))
	add.call("escape_zone", "VanEscape", &"escape_van", Vector3(20, 0, 20))
	for pair: Array in [[&"safe_loot", Vector3(8, 0.2, -13)], [&"product", Vector3(-4, 0.2, -12)],
			[&"count_cash", Vector3(0, 0.2, -14)]]:
		var m: Marker3D = Marker3D.new()
		m.name = "Loot_%s" % pair[0]
		m.position = pair[1]
		m.set_meta(&"objective_tag", pair[0])
		gp.add_child(m)
	var courier: SpawnPoint = SpawnPoint.new()  # co_op_pickup (scripted: not spawned at load)
	courier.name = "Courier0"
	courier.kind = SpawnPoint.Kind.GUARD
	courier.position = Vector3(-4, 0.05, -10)
	courier.tags = [&"cartel_courier", HeistRuntime.SCRIPTED_SPAWN_TAG] as Array[StringName]
	root.get_node("Spawns").add_child(courier)
	var cop: SpawnPoint = SpawnPoint.new()  # off_duty_cop (a mission unit point)
	cop.name = "OffDuty0"
	cop.kind = SpawnPoint.Kind.POLICE
	cop.position = Vector3(10, 0.05, 6)
	cop.tags = [&"civ_offduty", HeistRuntime.SCRIPTED_SPAWN_TAG] as Array[StringName]
	root.get_node("Spawns").add_child(cop)
	var flee: PatrolPoint = PatrolPoint.new()  # the stampede's exit (civilians_flee)
	flee.name = "CivFlee"
	flee.position = Vector3(-20, 0.05, -20)
	flee.tags = [&"civ_flee"] as Array[StringName]
	root.get_node("Patrols").add_child(flee)
	ATestMaps._own_children(root)
	var ps: PackedScene = PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _launch(pins: Dictionary = {}, rares: Array[StringName] = [], scalars: Dictionary = {},
		difficulty: int = Enums.Difficulty.ROUTINE) -> AfterhoursMissionProbe:
	var all: Dictionary = {&"gear_drop": &"gear_cloak", &"count_room": &"count_running", &"dj_set": &"dj_on",
		&"product_location": &"prod_stock"}
	all.merge(pins, true)
	_rt = await HeistLauncher.launch(&"unit_afterhours", 1650, difficulty, self,
		{"map_packed": _map(all, rares, scalars), "crew_ai": false, "ai_teammates": 0, "skip_casing": true})
	await wait_physics_frames(3)
	return AfterhoursMissionProbe.new(_rt.mission)


func _id(tag: StringName) -> int:
	var n: Array[Node] = _rt.mission.find_tagged(tag)
	return int(n[0].get(&"net_id")) if not n.is_empty() else 0


func _bags(loot_id: StringName) -> int:
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	return lm.bags().filter(func(b: LootBag) -> bool: return b.loot_id == loot_id).size()


func _secure(n: int) -> void:
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	for _i: int in n:
		for b: LootBag in lm.bags():
			if b.loot_id == &"loot.cash_bricks" and not b.secured:
				lm._secure(b)
				break
	await wait_physics_frames(1)


func test_stealth_line_gear_to_escape() -> void:
	var m: AfterhoursMissionProbe = await _launch({&"gear_drop": &"gear_booth"}, [], {&"safe_bags": 5, &"product_bags": 4})
	assert_eq(m.gear_line(), &"vo.mercer.afterhours_gear_booth", "Mercer names the rolled gear slot")
	assert_true(_lines.has(&"vo.mercer.afterhours_gear_booth"), "and says it at the start (B's run coverage: never said)")
	for other: StringName in [&"wc", &"cloak", &"van"]:
		assert_false(_lines.has(StringName("vo.mercer.afterhours_gear_%s" % other)), "not the %s line" % other)
	assert_true(_lines.has(&"vo.mercer.afterhours_intro"), "intro")
	assert_true(_lines.has(&"vo.accountant.afterhours_contact_intro"), "the Accountant's contact intro (B: vo coverage)")
	assert_eq(_bags(&"loot.cash_bricks"), 0, "the safe's cash spawns when it opens, not before")
	assert_eq(_bags(&"loot.parcels"), 4, "product_bags 4")
	assert_eq(_bags(&"loot.cash"), 2, "count_running: 2 count bags")
	EventBus.item_picked_up.emit(&"item.gear", 0)
	assert_eq(m.state(&"gear"), m.DONE, "gear on the first pickup")
	assert_true(_lines.has(&"vo.mercer.afterhours_gear_picked"), &"vo.mercer.afterhours_gear_picked")
	EventBus.item_picked_up.emit(&"item.keycard", 0)
	assert_true(_lines.has(&"vo.mercer.afterhours_keycard_found"), &"vo.mercer.afterhours_keycard_found")
	EventBus.interaction_completed.emit(_id(&"office_reader"), 0, &"keycard_reader")
	assert_eq(m.state(&"office"), m.DONE, "the reader opens the office")
	assert_true(_lines.has(&"vo.mercer.afterhours_office_open"), &"vo.mercer.afterhours_office_open")
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	for b: LootBag in lm.bags().filter(func(x: LootBag) -> bool: return x.loot_id == &"loot.parcels").slice(0, 3):
		lm._secure(b)
	await wait_physics_frames(1)
	assert_eq(m.state(&"secure"), m.ACTIVE, "3 parcels secured: [secure] wants the safe's cash (doc §Required loot)")
	assert_eq(m.state(&"escape"), m.HIDDEN, "no escape on the product alone")
	EventBus.item_picked_up.emit(&"item.code_note", 0)
	assert_eq(m.state(&"safe_code"), m.DONE, "the code note")
	m.mission.open_safe(&"code")
	assert_eq(m.state(&"safe"), m.DONE, "keypad opens the safe")
	assert_eq(_bags(&"loot.cash_bricks"), 5, "the open safe holds safe_bags 5")
	assert_eq(StringName(m.data(&"safe").get("open_method", &"")), &"code", "open_method code (achievement)")
	assert_eq(m.state(&"safe_loot"), m.ACTIVE)
	await _secure(2)
	assert_eq(m.state(&"escape"), m.HIDDEN, "2 bags: no escape yet")
	await _secure(1)
	assert_eq(m.state(&"secure"), m.DONE, "3 bags secured")
	assert_true(_lines.has(&"vo.mercer.afterhours_required_secured"), &"vo.mercer.afterhours_required_secured")
	assert_true(_lines.has(&"vo.accountant.afterhours_payday"), "the Accountant's payday as the van opens")
	assert_eq(m.state(&"escape"), m.ACTIVE, "stealth: the van is there")
	assert_true(m.mission.escape_open, "escape open")


func test_loud_lockdown_and_escape_wait() -> void:
	var m: AfterhoursMissionProbe = await _launch()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	assert_true(m.mission.lockdown, "lockdown")
	assert_false((m.mission.find_tagged(&"safe")[0].get(&"methods") as Array).has(&"code"), "the keypad is dead")
	var door: Door = m.mission.find_tagged(&"office_door")[0] as Door
	assert_true(door.charges_required >= 1 and door.lock == Door.Lock.ELECTRONIC, "the office door takes C4 now")
	assert_true(_lines.has(&"vo.mercer.afterhours_music_cut") and _lines.has(&"vo.dj.afterhours_alarm"), "music cut + DJ")
	assert_eq(m.state(&"safe_code"), m.DONE, "the code step is skipped loud")
	EventBus.device_started.emit(_id(&"safe_drill"), &"drill", 120.0)
	EventBus.device_jammed.emit(_id(&"safe_drill"))
	EventBus.device_finished.emit(_id(&"safe_drill"))
	assert_true(_lines.has(&"vo.mercer.afterhours_drill_started") and _lines.has(&"vo.mercer.afterhours_drill_jam")
		and _lines.has(&"vo.mercer.afterhours_drill_done"), "drill lines")
	assert_eq(StringName(m.data(&"safe").get("open_method", &"")), &"drill", "drilled (safe_code not completed by it)")
	assert_eq(m.state(&"escape_wait"), m.ACTIVE, "escape_wait")
	await _secure(3)
	assert_eq(m.state(&"escape"), m.HIDDEN, "loud: the van is not back yet")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.FADE, 1)
	m.mission._on_secure_wait()
	assert_eq(m.state(&"escape"), m.HIDDEN, "one FADE is not enough (the second assault's)")
	EventBus.assault_phase_changed.emit(Enums.AssaultPhase.FADE, 2)
	assert_eq(m.state(&"escape_wait"), m.DONE, "second FADE + 300 s: the van is back")
	assert_eq(m.state(&"escape"), m.ACTIVE)


func test_rare_count_left_open_and_extra_product() -> void:
	var m: AfterhoursMissionProbe = await _launch({&"count_room": &"count_done"}, [&"count_left_open", &"extra_product"],
		{&"safe_bags": 4, &"product_bags": 3})
	assert_true(m.mission.safe_open, "count_left_open: the safe starts open")
	assert_eq(StringName(m.data(&"safe").get("open_method", &"")), &"left_open")
	assert_eq(m.state(&"safe_code"), m.DONE, "skipped")
	assert_eq(_bags(&"loot.cash_bricks"), 5, "count_done: +1 safe bag")
	assert_eq(_bags(&"loot.parcels"), 5, "extra_product: +2 parcels")
	assert_eq(_bags(&"loot.cash"), 0, "no count running")
	assert_eq(m.state(&"count_room"), m.HIDDEN, "count_room hidden when done")


func test_co_op_pickup_is_scheduled_at_14_00() -> void:
	var m: AfterhoursMissionProbe = await _launch({}, [&"co_op_pickup"], {}, Enums.Difficulty.BRUTAL)
	assert_true(m.mission.timer_left(&"couriers") > 800.0, "the couriers come at 14:00 (%.0f s)" % m.mission.timer_left(&"couriers"))
	assert_true(m.mission.timer_left(&"dj_shoutout") > 170.0, "DJ shout-outs while the club plays")


func test_couriers_alarm_only_when_the_product_is_gone() -> void:
	var m: AfterhoursMissionProbe = await _launch({}, [&"co_op_pickup"], {&"product_bags": 3}, Enums.Difficulty.BRUTAL)
	m.mission._couriers_arrive()
	await wait_physics_frames(2)
	assert_eq(m.mission.couriers.size(), 2, "two couriers, calm guards")
	assert_true(_lines.has(&"vo.mercer.afterhours_couriers"), "Mercer warns")
	assert_false(m.mission.couriers[0].alert_state == Enums.AlertState.COMBAT, "they walk in calm")
	m.mission._check_couriers()
	assert_false(m.mission.went_loud, "the product is there: no alarm")
	var lm: LootManager = _rt.service(G.SVC_LOOT) as LootManager
	for b: LootBag in lm.bags():
		if b.loot_id == &"loot.parcels":
			b.queue_free()
	await wait_physics_frames(1)
	m.mission._check_couriers()
	await wait_physics_frames(2)
	assert_true(m.mission.went_loud, "the product is gone: they raise the alarm")


func test_off_duty_cop_is_a_calm_police_observer_without_a_pager() -> void:
	var m: AfterhoursMissionProbe = await _launch({}, [&"off_duty_cop"], {}, Enums.Difficulty.HAZARDOUS)
	var cop: NpcBase = m.mission.off_duty_cop
	assert_true(cop != null and cop.alive, "spawned in the booth")
	assert_true(_lines.has(&"vo.mercer.afterhours_off_duty_cop"), "Mercer warns")
	assert_ne(cop.role, &"guard", "police role: no pager")
	assert_ne(cop.alert_state, Enums.AlertState.COMBAT, "calm until he sees a masked crew member")
	assert_eq(StringName(cop.get_meta(StealthDirector.META_ALARM_REASON, &"")), &"off_duty_cop", "his alarm reason")


## D-166: Brandt holds the second assault in SUSTAIN (AssaultDirector.captain_active), so its FADE never comes: once
## the 300 s secure wait is over the van comes anyway (the done-check soft lock, Hazardous seeds 1 / 4242); also when he
## arrives after the wait ran out. Without him the second FADE is still needed.
func test_captain_waives_the_second_fade() -> void:
	var m: AfterhoursMissionProbe = await _launch()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	EventBus.device_finished.emit(_id(&"safe_drill"))
	await _secure(3)
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	assert_true(d != null and d.captain != null, "the director and its captain")
	m.mission._on_secure_wait()
	assert_eq(m.state(&"escape"), m.HIDDEN, "no captain, no second FADE: the van is not back")
	d.captain.active = true
	assert_true(m.mission.captain_waiver(), "Brandt holds the assault")
	EventBus.captain_arrived.emit(0)
	assert_eq(m.state(&"escape"), m.ACTIVE, "the wait is over and Brandt locks SUSTAIN: the van comes anyway")
	d.captain.active = false


func test_captain_waiver_at_the_end_of_the_wait() -> void:
	var m: AfterhoursMissionProbe = await _launch()
	_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(2)
	EventBus.device_finished.emit(_id(&"safe_drill"))
	await _secure(3)
	var d: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	d.captain.active = true
	assert_eq(m.state(&"escape"), m.HIDDEN, "Brandt alone does not bring the van before the 300 s")
	m.mission._on_secure_wait()
	assert_eq(m.state(&"escape"), m.ACTIVE, "the 300 s run out with Brandt on the map: the van comes then")
	d.captain.active = false
