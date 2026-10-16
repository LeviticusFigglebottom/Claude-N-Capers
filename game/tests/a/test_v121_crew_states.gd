## characters.md v1.21 (D-116, ENV D c3615354): third-person akimbo (aim_akimbo, fire_akimbo / fire_akimbo_l alternating
## right first, reload_akimbo, one pistol per hand), downed_fire / downed_reload / downed_getup (then the current hold),
## the L2.12 police arrest (downed_arrested, weapon hidden at `disarm`, crew_cuffed), a guard cuffing a standing heister
## (crew_cuffed_enter) and the free (crew_cuffed_free, weapon back at `free`); armed NPCs idle in idle_alert_<kind>.
## Driver and player agree at each step. Real cast rig (rook); a sub-case whose clip the rig lacks is skipped (print).
extends TestCase

const HEISTER: StringName = &"rook"
const AKIMBO_ID: StringName = &"weapon.akimbo_warden_45"
const DT: float = 0.05

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


## A crew body with the rook rig. `human`: a remote human teammate (police only arrest humans, L2.12).
func _crew(loadout: Loadout = null, human: bool = false) -> CrewController:
	var crew: CrewController = (load(CrewController.SCENE_PATH) as PackedScene).instantiate() as CrewController
	var info: Dictionary = {"peer_id": 7 if human else 0, "is_ai": not human, "display_name": "Crew"}
	crew.setup(1 if human else 0, info, loadout)
	crew.heister = HEISTER
	crew.net_id = 88100 + (1 if human else 0)
	add_child(crew)
	_nodes.append(crew)
	await wait_frames(3)  # CrewView.refresh is deferred
	crew.masked = true
	return crew


func _missing(d: AnimDriver, clips: Array[StringName], what: String) -> bool:
	if d == null or d.player == null:
		print("[v121] skip %s: the crew body has no animated rig" % what)
		return true
	for c: StringName in clips:
		if not d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, c]):
			print("[v121] skip %s: the rig has no %s (ENV D assets not checked out)" % [what, c])
			return true
	return false


func _ticks(d: AnimDriver, n: int) -> void:
	for _i: int in n:
		d.tick(DT)


func _playing(d: AnimDriver) -> String:
	return String(d.player.current_animation) if d.player.is_playing() else "<stopped>"


## Driver clip, player clip and weapon visibility at one step.
func _check(d: AnimDriver, want: StringName, weapon: bool, step: String) -> void:
	assert_eq(d.clip, want, "%s: driver plays %s" % [step, want])
	assert_eq(_playing(d), "humanoid/" + String(want), "%s: player agrees" % step)
	if d.weapon_visual != null:
		assert_eq(d.weapon_visual.visible, weapon, "%s: weapon %s" % [step, "shown" if weapon else "hidden"])


func _fire(crew: CrewController) -> void:
	EventBus.weapon_fired.emit(crew.net_id, &"", false, Vector3.ZERO)


func test_akimbo_aim_fire_alternates_and_reload() -> void:
	if ContentDB.weapon(AKIMBO_ID) == null:
		print("[v121] skip akimbo: no %s" % AKIMBO_ID)
		return
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = AKIMBO_ID
	l.secondary_mods = [] as Array[StringName]
	var crew: CrewController = await _crew(l)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"aim_akimbo", &"fire_akimbo", &"fire_akimbo_l", &"reload_akimbo"], "akimbo"):
		return
	crew.weapons.equip(Enums.WeaponSlot.SECONDARY)
	await wait_frames(2)
	d.refresh_weapon()
	d.set_process(false)
	assert_eq(d.weapon_kind, &"akimbo", "akimbo kind")
	d._aim_hold_left = 5.0
	_ticks(d, 4)
	_check(d, &"aim_akimbo", true, "aiming the pair")
	for want: StringName in [&"fire_akimbo", &"fire_akimbo_l", &"fire_akimbo", &"fire_akimbo_l"]:
		_fire(crew)
		d.tick(0.016)
		_check(d, want, true, "shot -> %s" % want)
	_ticks(d, 4)
	d._on_reload_started(Enums.WeaponSlot.SECONDARY, 3.0)
	d.tick(0.016)
	_check(d, &"reload_akimbo", true, "reload")
	assert_near(d.player.speed_scale, 1.5333 / 3.0, 0.01, "done@46 lands on the reload's end")
	var hand_l: Node3D = d.rig.get_node("Skeleton3D/HandL/Socket") as Node3D
	assert_true(d.weapon_offhand != null and d.weapon_offhand.get_parent() == hand_l, "still one pistol per hand")


func test_downed_fire_reload_and_getup() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"downed_fire", &"downed_reload", &"downed_getup"], "downed"):
		return
	d.set_process(false)
	_ticks(d, 2)
	crew.set_crew_state(Enums.CrewState.DOWNED)
	_ticks(d, 2)
	_check(d, &"downed", true, "downed (pistol out)")
	_fire(crew)
	d.tick(DT)
	_check(d, &"downed_fire", true, "downed shot")
	_ticks(d, 2)
	_fire(crew)
	d.tick(0.001)
	assert_true(d.player.current_animation_position < 0.05, "each shot restarts downed_fire")
	_ticks(d, 8)
	_check(d, &"downed", true, "back to downed")
	d._on_reload_started(Enums.WeaponSlot.SECONDARY, 2.0)
	d.tick(DT)
	_check(d, &"downed_reload", true, "downed reload")
	assert_near(d.player.speed_scale, 1.1333 / 2.0, 0.01, "done@34 on the reload's end")
	_ticks(d, 45)
	crew.set_crew_state(Enums.CrewState.NORMAL)  # revived
	d.tick(DT)
	_check(d, &"downed_getup", true, "revived: getup")
	_ticks(d, 30)
	var hold: StringName = StringName("idle_alert_" + String(d.weapon_kind))
	_check(d, hold if d.player.has_animation("humanoid/" + String(hold)) else &"idle_alert", true, "into the hold")
	assert_near(d.last_blend_s, AnimTweak.data().getup_blend_s, 0.001, "crossfade 0.2 s out of the getup")


func test_police_arrest_of_a_downed_heister() -> void:
	var crew: CrewController = await _crew(null, true)
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"downed_arrested", &"crew_cuffed", &"crew_cuffed_free"], "arrest"):
		return
	d.set_process(false)
	_ticks(d, 2)
	crew.set_crew_state(Enums.CrewState.DOWNED)
	_ticks(d, 2)
	if crew.health != null:
		crew.health.down_s = 60.0  # past the D-108 grace (police wait for a quiet downed heister)
	var cuffs: CrewCuffs = CrewCuffs.of(crew, true)
	assert_true(cuffs.cuff_downed(4242), "police cuff the downed heister (L2.12)")
	d.tick(0.02)
	_check(d, &"downed_arrested", true, "arrest starts, weapon still in hand")
	_ticks(d, 4)  # past disarm@6 (0.2 s)
	_check(d, &"downed_arrested", false, "after disarm")
	_ticks(d, 24)
	_check(d, &"crew_cuffed", false, "cuffed loop, weapon still hidden")
	assert_eq(d.last_blend_s, 0.0, "downed_arrested ends on crew_cuffed f0: no crossfade")
	cuffs.free_crew(-1)  # police cuffs: freed back to DOWNED (L2.12)
	_ticks(d, 2)
	_check(d, &"downed", true, "freed from police cuffs: downed again, weapon back")


func test_guard_cuffs_standing_and_free() -> void:
	var crew: CrewController = await _crew()
	var d: AnimDriver = AnimDriver.of(crew)
	if _missing(d, [&"crew_cuffed_enter", &"crew_cuffed", &"crew_cuffed_free"], "standing cuff"):
		return
	d.set_process(false)
	_ticks(d, 2)
	var cuffs: CrewCuffs = CrewCuffs.of(crew, true)
	assert_true(cuffs.cuff(4343), "a guard cuffs the standing heister (S3.2)")
	d.tick(0.02)
	_check(d, &"crew_cuffed_enter", false, "cuffed standing")
	_ticks(d, 14)  # crew_cuffed_enter is 0.6 s
	_check(d, &"crew_cuffed", false, "cuffed loop")
	cuffs.free_crew(2)  # a teammate uncuffs
	d.tick(0.02)
	_check(d, &"crew_cuffed_free", false, "free: weapon not back before free@8")
	_ticks(d, 6)
	_check(d, &"crew_cuffed_free", true, "after free@8 the weapon is back")
	_ticks(d, 14)
	assert_false(String(d.clip).begins_with("crew_cuffed"), "back to the normal state (%s)" % d.clip)
	assert_true(d.weapon_visual == null or d.weapon_visual.visible, "weapon shown")


func test_armed_npc_idles_holding_its_weapon() -> void:
	var npc: NpcBase = NpcBase.new()
	npc.role = &"police"
	npc.enemy_def = ACombatSpecials.def("patrol_officer")
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	npc.add_child(visual)
	add_child(npc)
	_nodes.append(npc)
	await wait_frames(3)
	var d: AnimDriver = AnimDriver.of(npc)
	if d == null or d.weapon_visual == null:
		print("[v121] skip armed NPC: no rig or no modelled weapon")
		return
	var held: StringName = StringName("idle_alert_" + String(d.weapon_kind))
	if _missing(d, [held], "armed NPC"):
		return
	npc.alert_state = Enums.AlertState.COMBAT
	assert_eq(d._idle_clip(), held, "alerted cop with a %s idles in %s" % [d.weapon_kind, held])
	npc.alert_state = Enums.AlertState.CALM
	assert_eq(d._idle_clip(), &"idle", "calm: plain idle")
