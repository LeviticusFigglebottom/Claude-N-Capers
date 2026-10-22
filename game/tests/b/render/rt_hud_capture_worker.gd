## Worker for rt_hud_capture.gd (loaded at runtime so the autoloads exist when it compiles).
extends Node

const RT: StringName = &"rolling_thunder"
const WIP_DEF: String = "res://world/heists/rolling_thunder/rolling_thunder_wip_def.tres"

var _out: String = ""
var _flow: MenuFlow = null
var _issues: int = 0
## 2nd arg "stub_trucks": armored_trucks on the G1 placeholder boxes (A's po5 --po5-rt-stub-trucks, harness only, until
## C's convoy swap ships real trucks).
var _stub_trucks: bool = false
## Test-only fixture (as test_heist_screens_text): held so the cache keeps them for the run.
var _wip: Resource = null
var _list: UiHeistList = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir() + "/rt_hud"
	_stub_trucks = args.size() > 1 and args[1] == "stub_trucks"
	DirAccess.make_dir_recursive_absolute(_out)
	SaveService.root_dir = "user://rt_hud_profiles_%d" % OS.get_process_id()  # never the player's profile
	GameSettings.root_dir = SaveService.root_dir + "_settings"
	OnboardingTips.persist = false
	_run.call_deferred()


func _run() -> void:
	_stage_rt()
	SaveService.save_profile(PlayerProfile.new_default(), 0)
	_flow = (load("res://content/ui/menus/menu_flow.tscn") as PackedScene).instantiate() as MenuFlow
	get_tree().root.add_child(_flow)
	await _frames(20)
	_flow.launch(RT, Enums.Difficulty.HAZARDOUS, SaveService.load_profile(0).loadout, 42)
	var t0: int = Time.get_ticks_msec()
	while (_hud() == null or _flow.runtime == null) and Time.get_ticks_msec() - t0 < 120000:
		await _frames(5)
	if _flow.runtime == null or _hud() == null:
		_issue("launch", "RT did not launch (runtime %s, hud %s)" % [_flow.runtime, _hud()])
		_done()
		return
	var rt: HeistRuntime = _flow.runtime as HeistRuntime
	var mission: Node = rt.mission
	if _stub_trucks:
		_stub_rt_trucks(rt)
	await _seconds(3.0)
	_state("casing")
	await _shot("01_casing")
	var me: CrewController = rt.crew_controller(Net.local_slot() if Net.local_slot() >= 0 else 0) as CrewController
	if me != null:
		me.set_masked()
	await _seconds(1.0)
	_state("masked")
	await _shot("02_masked")
	mission.call(&"_convoy_arrives")  # stated shortcut: the convoy now, not at its ETA
	t0 = Time.get_ticks_msec()
	while int(mission.call(&"objective_state", &"ambush")) != Enums.ObjectiveState.ACTIVE \
			and Time.get_ticks_msec() - t0 < 60000:
		await _seconds(0.5)
	_state("convoy stopped")
	await _shot("03_convoy_stopped")
	var sd: Node = rt.service(G.SVC_STEALTH)
	if sd != null:
		sd.call(&"raise_alarm", &"rt_hud_audit")
	await _seconds(6.0)
	_state("ambush / loud")
	await _shot("04_loud")
	var trucks: Array[Node] = get_tree().get_nodes_in_group(ArmoredTruck.GROUP)
	print("RTHUD trucks %d" % trucks.size())
	for n: Node in trucks:
		var t: ArmoredTruck = n as ArmoredTruck
		if t != null and t.runner != null and not t.opened:
			t.runner.place(0, t.saw_duration())  # stated shortcut: the saw interaction's result
	await _seconds(2.0)
	var hud: Hud = _hud()
	# Device timers are world-anchored (hidden past device_panel_max_m, behind the camera or a wall): every running
	# saw is tracked, and the one the player stands at is drawn (stated shortcut: the player is moved to its rear doors).
	var saws: int = trucks.filter(func(n: Node) -> bool: return n is ArmoredTruck and not (n as ArmoredTruck).opened).size()
	print("RTHUD timer rows %d for %d running saws" % [hud.device_timers.rows().size(), saws])
	if hud.device_timers.rows().size() != saws:
		_issue("timers", "%d saws running, %d timer rows" % [saws, hud.device_timers.rows().size()])
	if me != null and not trucks.is_empty():
		var t0n: Node3D = trucks[0] as Node3D
		var stand: Vector3 = t0n.global_position - t0n.global_basis.z * 5.0
		me.teleport(Transform3D(Basis.looking_at(t0n.global_position - stand, Vector3.UP), stand))
		await _seconds(2.0)
	print("RTHUD timers drawn %s" % [hud.device_timers.drawn.map(func(d: Dictionary) -> String: return "%s %s" % [
			d.get("label", "?"), d.get("time_text", "?")])])
	if saws > 0 and hud.device_timers.drawn.is_empty():
		_issue("timers", "standing at a truck with a running saw, the HUD draws no timer")
		_why_no_timer(hud, trucks[0] as Node3D)
	_state("saws")
	await _shot("05_truck_saws")
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector
	if dir != null and dir.events != null:
		dir.events.run(&"heli", {"drop": false, "sniper": false})
		await _seconds(3.0)
		print("RTHUD assault markers %s" % [hud.assault_events.drawn.map(func(d: Dictionary) -> String: return str(d.get(
				"label", d.get("kind", "?"))))])
		await _shot("06_assault_event")
	hud.scoreboard.set_process(false)
	hud.scoreboard.set_shown(true)
	await _frames(6)
	_state("tab sheet")
	await _shot("07_tab_sheet")
	hud.scoreboard.set_shown(false)
	rt.call(&"end_heist", true, [0] as Array[int])
	await _seconds(2.0)
	var pd: PaydayScreen = _flow.get(&"_heist_payday") as PaydayScreen
	if pd == null or not is_instance_valid(pd):
		_issue("payday", "no in-heist payday after end_heist")
	else:
		pd.show_result(_scripted_result())
		pd.skip_count()
		await _frames(10)
		print("RTHUD payday achievements %s" % [pd.achievements_unlocked])
		# The run's own payday (end_heist) may already have unlocked one (a run with no downs): read the profile.
		for id: StringName in [&"achievement.rt_heavy_haul", &"achievement.rt_iron_crew"]:
			if not Achievements.is_unlocked(pd.profile, id):
				_issue("payday", "%s is not unlocked after the scripted clear" % id)
		await _shot("08_payday")
	_done()


## Why each timer row is not drawn: distance, behind the camera, or the occlusion ray's first hit (DeviceTimers' rules).
func _why_no_timer(hud: Hud, truck: Node3D) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		print("RTHUD why: no camera")
		return
	print("RTHUD why: truck %s at %s, camera %s" % [truck.name, truck.global_position, cam.global_position])
	var tw: HudTweak = hud.device_timers.tweak
	for r: Dictionary in hud.device_timers.rows():
		var wp: Variant = r.get("world_pos", null)
		if not wp is Vector3:
			print("RTHUD why: row %s has no world_pos" % r.get("net_id", -1))
			continue
		var to: Vector3 = wp as Vector3
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, to,
				tw.device_occlusion_mask)
		var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(q)
		var hit_text: String = "none"
		if not hit.is_empty():
			var col: Object = hit.get("collider")
			hit_text = "%s at %.2f m from the device" % [(col as Node).get_path() if col is Node else col,
					(hit["position"] as Vector3).distance_to(to)]
		print("RTHUD why: row %s at %s dist %.1f (max %.1f) behind %s ray hit %s (slack %.2f)" % [r.get("net_id", -1), to,
				cam.global_position.distance_to(to), tw.device_panel_max_m, cam.is_position_behind(to), hit_text,
				tw.device_occlusion_slack_m])


## Harness only (A's po5_flow._stub_rt_trucks): an armored_truck on each G1 convoy placeholder box (cash / bullion).
func _stub_rt_trucks(rt: HeistRuntime) -> void:
	var scene: PackedScene = load("res://systems/prefabs/armored_truck/armored_truck.tscn") as PackedScene
	var n: int = 0
	for layout: Node3D in ConvoyLayouts.layouts(rt.map):
		for body: Node in layout.get_children():
			var kind: String = String(body.get_meta(&"kind", ""))
			if not body is StaticBody3D or not kind in ["convoy_cash", "convoy_bullion"]:
				continue
			var rear: Node3D = layout.get_node_or_null(NodePath(String(body.name) + "RearDoor")) as Node3D
			var t: ArmoredTruck = scene.instantiate() as ArmoredTruck
			t.name = String(body.name) + "Truck"
			if kind == "convoy_bullion":
				t.saw_duration_s = 180.0
				t.hand_saw_duration_s = 90.0
			layout.add_child(t)
			var at: Vector3 = (body as Node3D).global_position
			var to_rear: Vector3 = (rear.global_position - at) if rear != null else -(body as Node3D).global_basis.z
			to_rear.y = 0.0
			t.global_transform = Transform3D(Basis.looking_at(to_rear.normalized(), Vector3.UP), at)
			n += 1
	rt.set_layout(String(rt.layouts.get(ConvoyLayouts.DEFAULT_GROUP, "")))
	print("RTHUD stub trucks %d (harness only, until C's convoy swap)" % n)


## Test-only fixture: RT's WIP def at the convention def path, RT un-hidden on the cached heist list.
func _stage_rt() -> void:
	_list = HeistCatalog.heist_list()
	if ResourceLoader.exists(HeistRegistry.def_path(RT)) or not ResourceLoader.exists(WIP_DEF):
		return
	_wip = load(WIP_DEF)
	_wip.take_over_path(HeistRegistry.def_path(RT))
	(_list.heists[RT] as Dictionary)["hidden"] = false


## A Hazardous RT clear: 4 gold + 2 cash secured, nobody down, signals rigged (the mission's facts do the rest).
func _scripted_result() -> Dictionary:
	var r: Dictionary = HeistCatalog.sample_result()
	var loot: Array = []
	for b: Array in [[&"loot.gold", 4], [&"loot.cash_bricks", 2]]:
		for i: int in range(int(b[1])):
			loot.append({"loot_id": b[0], "value": int(LootManager.loot_info(b[0]).get("value", 0))})
	var crew: Array = []
	for slot: int in range(4):
		crew.append({"slot": slot, "is_ai": slot > 0, "name": "", "kills": 6, "specials_killed": 1, "downs": 0,
			"civilians_killed": 0, "shots": 0, "hits": 0, "headshots": 0, "in_custody": false, "escaped": true})
	r.merge({"heist_id": RT, "success": true, "stealth": false, "time_s": 1080.0, "difficulty": Enums.Difficulty.HAZARDOUS,
		"contract_pay": HeistRegistry.get_def(RT).base_payout, "loot": loot, "small_loot": 1200, "crew": crew,
		"pagers_answered": 0, "fail_reason": &"", "loot_available": 9}, true)
	return r


func _state(tag: String) -> void:
	var hud: Hud = _hud()
	if hud == null:
		return
	var texts: PackedStringArray = PackedStringArray()
	for l: Node in hud.objectives.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text.strip_edges() != "":
			texts.append((l as Label).text.replace("\n", " / "))
	print("RTHUD %s objective: %s" % [tag, " | ".join(texts)])
	var steps: PackedStringArray = PackedStringArray()
	for o: Dictionary in hud.objectives.prop(&"objectives", []) as Array:
		steps.append("%s=%s" % [o.get("id", &""), Enums.ObjectiveState.find_key(int(o.get("state", -1)))])
	print("RTHUD %s model: %s (flashing %s)" % [tag, ", ".join(steps), hud.objectives.flashing])
	var raw: RegEx = RegEx.create_from_string("\\b(objective|ui|vo|heist|item|loot)\\.[a-z_]")
	for c: Node in hud.find_children("*", "Label", true, false):
		var t: String = (c as Label).text
		if (c as Label).is_visible_in_tree() and (raw.search(t) != null or t.contains("{")):
			_issue(tag, "raw text on the HUD: '%s'" % t)


func _hud() -> Hud:
	var h: Array[Node] = get_tree().root.find_children("*", "Hud", true, false)
	return h[0] as Hud if not h.is_empty() else null


func _shot(stem: String) -> void:
	await _frames(4)
	if DisplayServer.get_name() == "headless":  # --headless: the HUD state lines only (no frames to save)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s_%dx%d.png" % [_out, stem, img.get_width(), img.get_height()]
	img.save_png(path)
	print("RTHUD SHOT ", path)


func _issue(tag: String, what: String) -> void:
	_issues += 1
	print("RTHUD ISSUE %s: %s" % [tag, what])


func _done() -> void:
	print("RTHUD DONE %d" % _issues)
	SaveService.delete_profile(0)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
