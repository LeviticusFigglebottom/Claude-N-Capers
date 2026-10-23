## D's AH in-map cast review (env/d-art a1fa3e44, LEAD r307): (1) the door / rope bouncers (GUARD spawns with
## idle_activity bouncer_idle) play bouncer_idle at their post, not idle_b; (2) a bartender spawned on bartender_wipe
## plays it (CivilianBrain knew bartender_pour but not the wipe: plain idle); (3) spawn_units passes the SpawnPoint's
## idle activity and facing, and a calm police unit (the off-duty cop) plays it (`sit`, standing without a seat).
extends TestCase

const HINT_SCRIPT: String = "extends Node\nvar anim_hint: StringName = &\"idle\"\n"

var _rt: HeistRuntime = null
var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func _guard(activity: StringName) -> NpcBase:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"guard"
	npc.net_id = 98001
	npc.spawn_info = {"tags": [&"guard_door"], "idle_activity": activity}
	npc.visual_scene = load(NpcVisuals.scene_path("security_officer")) as PackedScene
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	var gs: GDScript = GDScript.new()
	gs.source_code = HINT_SCRIPT
	gs.reload()
	var brain: Node = Node.new()
	brain.name = "Brain"
	brain.set_script(gs)
	npc.add_child(brain)
	add_child(npc)
	_nodes.append(npc)
	return npc


func test_calm_bouncer_plays_his_post_activity() -> void:
	var npc: NpcBase = _guard(&"bouncer_idle")
	await wait_frames(1)
	var d: AnimDriver = AnimDriver.of(npc)
	assert_eq(AmbientHints.resolve(npc, d.combat, &"idle"), &"bouncer_idle", "calm at his post: bouncer_idle")
	npc.alert_state = Enums.AlertState.ALARMED
	assert_eq(AmbientHints.resolve(npc, d.combat, &"idle"), &"idle", "alarmed: the brain's own stand")
	npc.alert_state = Enums.AlertState.CALM
	npc.spawn_info["idle_activity"] = &"not_a_clip"
	assert_eq(AmbientHints.resolve(npc, d.combat, &"idle"), &"idle", "an unknown activity is ignored")


func test_bartender_wipe_is_a_known_activity() -> void:
	assert_true(CivilianBrain.KNOWN_ACTIVITIES.has(&"bartender_wipe"), "CivilianBrain plays bartender_wipe")
	assert_eq(AnimDriver.HINT_CLIPS.get(&"bartender_wipe"), &"bartender_wipe", "and the driver maps it to its clip")


func test_spawn_units_passes_the_spawn_activity_and_facing() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1307, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var sp: SpawnPoint = SpawnPoint.new()
	sp.kind = SpawnPoint.Kind.POLICE
	sp.tags = [&"civ_offduty", &"scripted"] as Array[StringName]
	sp.idle_activity = &"sit"
	_rt.map.add_child(sp)
	sp.global_transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(3, 0.05, -6))
	var units: Array[NpcBase] = _rt.mission.spawn_units(&"enemy.patrol_officer", 1, &"civ_offduty")
	assert_eq(units.size(), 1, "the off-duty cop spawned")
	if units.is_empty():
		return
	var cop: NpcBase = units[0]
	assert_eq(StringName(cop.spawn_info.get("idle_activity", &"")), &"sit", "the spawn's activity reaches the unit")
	assert_true(cop.global_basis.z.dot(sp.global_basis.z) > 0.99, "a mission unit keeps its SpawnPoint's facing")
	await wait_physics_frames(3)
	var brain: Node = cop.get_node(^"Brain")
	assert_eq(brain.get(&"anim_hint"), CivilianBrain.seated_or_standing(cop, &"sit"),
		"calm: his activity (seated on a seat, standing without one), not idle_alert")
	# D r308 (r308_offduty.png): the plain-clothes cop keeps his gun holstered until he radios / fights.
	var d: AnimDriver = AnimDriver.of(cop)
	assert_false(d.weapon_shown(&"idle"), "calm in the crowd: holstered")
	cop.set_alert_state(Enums.AlertState.ALARMED)
	assert_true(d.weapon_shown(&"idle_alert"), "alarmed: drawn")


## (4) vip_party: HeistMission.spawn_civilians spawns the civilians of the CIVILIAN SpawnPoints carrying a tag, with
## that point's tags and activity (the runtime skips `scripted` ones at load; the AH map test checks that part).
func test_spawn_civilians_by_tag() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1308, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	for i: int in 2:
		var sp: SpawnPoint = SpawnPoint.new()
		sp.kind = SpawnPoint.Kind.CIVILIAN
		sp.tags = [&"civ_vip", &"scripted"] as Array[StringName]
		sp.idle_activity = &"walk_text"
		_rt.map.add_child(sp)
		sp.global_position = Vector3(2.0 * i, 0.05, -6)
	var before: int = _rt.npcs(&"civilian").size()
	var vips: Array[NpcBase] = _rt.mission.spawn_civilians(&"civ_vip")
	assert_eq(vips.size(), 2, "one civilian per civ_vip spawn")
	assert_eq(_rt.npcs(&"civilian").size(), before + 2, "on the map")
	if not vips.is_empty():
		assert_true((vips[0].spawn_info.get("tags", []) as Array).has(&"civ_vip"), "the point's tags (the club_vip look)")
		assert_eq(StringName(vips[0].spawn_info.get("idle_activity", &"")), &"walk_text", "and its activity")


## D r308 (the door bouncer walked on the spot): a guard whose walk back to his post cannot arrive takes the spot he
## reached as the post after GuardTweak.post_walk_give_up_s and stands (idle -> his post activity), no endless walk.
func test_guard_post_walk_gives_up_and_stands() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1309, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var g: NpcBase = _rt.spawn_npc(&"guard", Transform3D(Basis.IDENTITY, Vector3(2, 0.05, -4)),
		{"tags": [&"guard_door"], "idle_activity": &"bouncer_idle"})
	await wait_physics_frames(10)
	var brain: GuardBrain = g.get_node(^"Brain") as GuardBrain
	brain._post_pos = Vector3(2, 0.0, -400.0)  # off the map: the walk back can never arrive
	brain._walking = false
	await wait_seconds(brain.tweak.post_walk_give_up_s + 1.5)
	assert_false(brain._walking, "the walk gave up")
	assert_ne(brain.anim_hint, &"walk", "standing, not walking on the spot (hint %s)" % brain.anim_hint)
	assert_true(brain._post_pos.distance_to(g.global_position) < 1.0, "the spot reached is the post now")



## D r16 (AH in-map re-shoot): the door bouncer (DoorBouncer: bouncer_idle, no patrol graph) adopted the nearest graph and
## patrolled it, playing bouncer_idle only at waypoints. A post activity without a named graph holds the post.
func test_ah_door_bouncer_holds_his_post_in_bouncer_idle() -> void:
	if not ResourceLoader.exists("res://world/heists/afterhours/afterhours.tscn"):
		skip("no afterhours map on this branch")
		return
	_rt = await HeistLauncher.launch(&"afterhours", 1, Enums.Difficulty.ROUTINE, self, {"crew_ai": false, "ai_teammates": 0})
	var door: NpcBase = null
	for n: Node in _rt.npcs(&"guard"):
		if ((n as NpcBase).spawn_info.get("tags", []) as Array).has(&"guard_door"):
			door = n as NpcBase
	assert_true(door != null, "the door bouncer spawned")
	if door == null:
		return
	var brain: GuardBrain = door.get_node(^"Brain") as GuardBrain
	var settled: bool = await wait_until(func() -> bool: return AnimDriver.of(door).clip == &"bouncer_idle", 7.0)
	assert_true(brain.route.is_empty(), "no patrol route (%d points)" % brain.route.size())
	assert_true(settled, "bouncer_idle at the door (clip %s, hint %s)" % [AnimDriver.of(door).clip, brain.anim_hint])
	var p: Vector3 = door.global_position
	await wait_seconds(2.0)
	assert_true(door.global_position.distance_to(p) < 0.1, "and stays put")
