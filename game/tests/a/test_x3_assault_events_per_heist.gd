## X-3 (D-115 / PO6-17): on each loud heist map with ENV C's AssaultEvents markers (night_deposit, dockside_burn,
## gallery_night) every event kind of its rows runs at one of C's markers (not a fallback), seeded, and posts
## EventBus.assault_event_started; the heist's rows come from the tweak / HeistDef with all three kinds.
extends TestCase

const KINDS: Array[StringName] = [&"turret_van", &"heli", &"breach"]
## C's marker name prefix per kind (AssaultEventMarkerScan): a fallback (police spawn / ENTRY point) has another name.
const PREFIX: Dictionary = {&"turret_van": "TurretVan_", &"heli": "HeliDrop_", &"breach": "Breach_"}

var _rt: HeistRuntime = null
var _started: Array[StringName] = []


func _on_started(kind: StringName, _net_id: int, _pos: Vector3) -> void:
	_started.append(kind)


func after_each() -> void:
	Engine.time_scale = 1.0
	if EventBus.assault_event_started.is_connected(_on_started):
		EventBus.assault_event_started.disconnect(_on_started)
	if _rt != null and is_instance_valid(_rt):
		for s: int in _rt.crew_members().size():
			Modifiers.clear_source(s, &"x3.immune")
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _each_kind_runs(heist: StringName, seed_v: int) -> void:
	_started.clear()
	EventBus.assault_event_started.connect(_on_started)
	_rt = await HeistLauncher.launch(heist, seed_v, Enums.Difficulty.HAZARDOUS, self, {"crew_ai": false, "captain": false})
	assert_true(_rt != null, "%s launched" % heist)
	await wait_physics_frames(5)
	for s: int in _rt.crew_members().size():
		Modifiers.set_source(s, &"x3.immune", {&"defense.damage_taken_mult": 0.0})
	assert_true(AssaultEventMarkerScan.root(_rt.map) != null, "%s: C's AssaultEvents markers" % heist)
	if _rt.stealth != null:
		_rt.stealth.raise_alarm(&"test", 0)
	await wait_physics_frames(5)
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var kinds: Array[StringName] = []
	for r: Dictionary in dir.events.rows():
		kinds.append(StringName(r["kind"]))
	for k: StringName in KINDS:
		assert_true(kinds.has(k), "%s rows have %s (%s)" % [heist, k, kinds])
		var e: AssaultEventEntity = dir.events.run(k)
		assert_true(e != null, "%s: %s runs" % [heist, k])
		if e == null:
			continue
		var h: Dictionary = dir.events.history.back()
		assert_true(String(h.get("marker", "")).begins_with(String(PREFIX[k])),
			"%s: %s at a C marker, not a fallback (%s)" % [heist, k, h])
		assert_true(_started.has(k), "%s: assault_event_started for %s" % [heist, k])
		await wait_physics_frames(10)
		dir.events.end_all()
		await wait_physics_frames(2)


func test_x3_night_deposit_each_event_runs_at_a_marker() -> void:
	await _each_kind_runs(&"night_deposit", 31)


func test_x3_dockside_burn_each_event_runs_at_a_marker() -> void:
	await _each_kind_runs(&"dockside_burn", 32)


func test_x3_gallery_night_each_event_runs_at_a_marker() -> void:
	await _each_kind_runs(&"gallery_night", 33)
