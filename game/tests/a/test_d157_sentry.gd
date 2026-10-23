## D-157 crew sentry (PD2 sentry gun) and its six skill keys (B's unhooked keys, batch 5). Skill values come from B's
## skill data (ContentDB); the sentry's own numbers from SentryGun.DEFAULTS until B's DeployableDef ships.
extends TestCase

const SENTRY: StringName = &"deployable.sentry"
const CALIBRATED: StringName = &"skill.sapper.calibrated"
const LEAN_BUILD: StringName = &"skill.sapper.lean_build"
const MOUNT_UP: StringName = &"skill.sapper.mount_up"
const SILENT_PARTNER: StringName = &"skill.sapper.silent_partner"

var _rt: HeistRuntime = null


func before_each() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 1157, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "loadouts": {0: CrewWeapons.build_loadout(null)}})
	_rt.stealth.raise_alarm(&"test")
	await wait_physics_frames(3)


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(1)


func _skill(id: StringName) -> SkillDef:
	return ContentDB.by_id(ContentDB.SKILLS, id) as SkillDef


func _grant(id: StringName, aced: bool = false) -> void:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	Modifiers.set_source(0, StringName("test.%s" % id), g)


func _val(id: StringName, key: StringName, aced: bool = false) -> Variant:
	var g: Dictionary = (_skill(id).grants_basic as Dictionary).duplicate()
	if aced:
		g.merge(_skill(id).grants_aced, true)
	return g.get(key)


func _crew() -> CrewController:
	return _rt.crew_controller(0) as CrewController


func _ds() -> DeployableSystem:
	return _rt.service(DeployableSystem.SERVICE) as DeployableSystem


func _place() -> SentryGun:
	_ds().give(0, SENTRY)
	var p: DeployablePrefab = _ds().place(_crew()) as DeployablePrefab
	return SentryGun.of(p) if p != null else null


func _enemy(pos: Vector3) -> NpcBase:
	var dir: AssaultDirector = _rt.service(G.SVC_DIRECTOR) as AssaultDirector
	return dir.spawn_enemy(dir.enemy_def_for(&"enemy.patrol_officer"), Transform3D(Basis.IDENTITY, pos), null)


func _total_ammo() -> int:
	var w: CrewWeapons = _crew().weapons
	var t: int = 0
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if w.has_weapon(ws):
			t += w.mag(ws) + w.reserve(ws)
	return t


func _max_ammo() -> int:
	var t: int = 0
	for ws: int in [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]:
		if _crew().weapons.has_weapon(ws):
			t += DeployablePrefab.max_ammo(_crew(), ws)
	return t


## Deploy costs ammo_cost_frac of the owner's ammo; it shoots the nearest visible enemy; pickup refunds and restocks.
func test_deploy_shoot_pickup() -> void:
	var before: int = _total_ammo()
	var cues: Array[StringName] = []
	var on_cue: Callable = func(id: StringName, _p: Vector3, _s: int) -> void: cues.append(id)
	EventBus.audio_cue_requested.connect(on_cue)
	var sg: SentryGun = _place()
	assert_true(sg != null, "a sentry placed (fallback def until B's .tres)")
	if sg == null:
		return
	await wait_frames(2)
	EventBus.audio_cue_requested.disconnect(on_cue)
	assert_true(cues.has(&"cue.sentry_deploy"), "B's deploy cue (%s)" % [cues])
	var comp: InteractableComponent = sg.get_parent().get(&"interactable") as InteractableComponent
	assert_eq(comp.prompt_key, SentryGun.PROMPT_PICKUP, "no mode skill: B's pickup prompt")
	var paid: int = before - _total_ammo()
	assert_near(float(paid), float(_max_ammo()) * float(SentryGun.DEFAULTS["ammo_cost_frac"]), 2.0, "40 % of the ammo")
	var npc: NpcBase = _enemy(sg.global_position + (-sg.global_basis.z) * 8.0)
	var h0: float = npc.health
	var shot: bool = await wait_until(func() -> bool: return npc.health < h0 or not npc.alive, 4.0)
	assert_true(shot, "it turns and shoots the enemy")
	assert_true(sg.ammo < sg.ammo_max, "using its own ammo")
	var left: int = _total_ammo()
	var prefab: Node = sg.get_parent()
	prefab.call(&"_on_completed", _crew())
	await wait_frames(2)
	assert_false(is_instance_valid(prefab), "the owner picked it up")
	assert_true(_total_ammo() > left, "the unused share of the cost came back")
	assert_eq(_ds().deployable_count(0), int(DeployableSystem.def_for(SENTRY).count), "back in the inventory")


## deploy.sentry_accuracy_mult / turn_speed_mult (Calibrated), cost_mult + health_mult (Lean Build),
## cost_mult + shield (Mount Up).
func test_sentry_stat_skills() -> void:
	var plain: SentryGun = _place()
	var spread0: float = plain.spread_rad()
	var turn0: float = plain.turn_rate_rad()
	var hp0: float = plain.max_health
	_grant(CALIBRATED, true)
	assert_near(plain.spread_rad(), spread0 * float(_val(CALIBRATED, &"deploy.sentry_accuracy_mult")), 0.0001, "tighter")
	assert_near(plain.turn_rate_rad(), turn0 * float(_val(CALIBRATED, &"deploy.sentry_turn_speed_mult", true)), 0.0001,
		"Aced: faster turning")
	_grant(LEAN_BUILD, true)
	_grant(MOUNT_UP, true)
	var before: int = _total_ammo()
	var sg: SentryGun = _place()
	var frac: float = float(SentryGun.DEFAULTS["ammo_cost_frac"]) * float(_val(LEAN_BUILD, &"deploy.sentry_cost_mult")) \
		* float(_val(MOUNT_UP, &"deploy.sentry_cost_mult"))
	assert_near(float(before - _total_ammo()), float(_max_ammo()) * frac, 2.0, "Lean Build x Mount Up: cheaper")
	assert_near(sg.max_health, hp0 * float(_val(LEAN_BUILD, &"deploy.sentry_health_mult", true)), 0.01,
		"Lean Build Aced: tougher")
	assert_true(bool(_val(MOUNT_UP, &"deploy.sentry_shield", true)) and sg.shield, "Mount Up Aced: a shield")
	var fwd: Vector3 = sg._forward()
	var front: Dictionary = sg.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO,
		-fwd, 99), 99)
	assert_true(bool(front.get("blocked", false)) and sg.health == sg.max_health, "a frontal hit is blocked")
	sg.take_hit(Damage.info(10.0, Enums.DamageType.BULLET, Enums.HitZone.BODY, &"", Vector3.ZERO, fwd, 99), 99)
	assert_near(sg.health, sg.max_health - 10.0, 0.001, "from behind it hurts")


## deploy.sentry_modes (Silent Partner): the owner cycles normal -> quiet (Aced: -> ap); quiet draws less fire, AP fires
## slower, harder and through shields.
func test_sentry_modes() -> void:
	var p: Dictionary = _val(SILENT_PARTNER, &"deploy.sentry_modes", true)
	_grant(SILENT_PARTNER, true)
	var sg: SentryGun = _place()
	assert_eq(sg.modes(), [SentryGun.MODE_NORMAL, SentryGun.MODE_QUIET, SentryGun.MODE_AP] as Array[StringName], "modes")
	await wait_frames(2)
	var comp: InteractableComponent = sg.get_parent().get(&"interactable") as InteractableComponent
	assert_eq(comp.prompt_key, SentryGun.PROMPT_MODE, "B's mode prompt")
	assert_eq(StringName(comp.prompt_args.get("mode", &"")), &"ui.sentry.mode.quiet", "names the next mode")
	assert_false(sg.interact(_crew()), "a tap cycles (no pickup)")
	assert_eq(sg.mode, SentryGun.MODE_QUIET, "quiet")
	assert_near(sg.threat_mult(), float(p["quiet_threat_mult"]), 0.0001, "quiet: x quiet_threat_mult as a target")
	sg.interact(_crew())
	assert_eq(sg.mode, SentryGun.MODE_AP, "Aced: AP")
	var npc: NpcBase = _enemy(sg.global_position + (-sg.global_basis.z) * 8.0)
	npc.max_health = 100000.0
	npc.health = 100000.0
	var got: Array[Dictionary] = []
	var on_hit: Callable = func(victim: int, _a: int, info: Dictionary) -> void:
		if victim == npc.net_id:
			got.append(info)
	EventBus.damage_applied.connect(on_hit)
	await wait_until(func() -> bool: return not got.is_empty(), 4.0)
	EventBus.damage_applied.disconnect(on_hit)
	assert_false(got.is_empty(), "AP hits")
	if not got.is_empty():
		assert_near(float(got[0]["amount"]), float(SentryGun.DEFAULTS["damage"]) * float(p["ap_damage_mult"]), 0.5,
			"AP: x ap_damage_mult")
	assert_near(sg._cooldown, 0.0, 60.0 / (float(SentryGun.DEFAULTS["fire_rate_rpm"]) * float(p["ap_fire_rate_mult"])) + 0.01,
		"AP: slower fire")
	sg.interact(_crew())
	assert_eq(sg.mode, SentryGun.MODE_NORMAL, "back to normal")


## Police weigh a sentry as a target and shoot it (D-157: it draws aggro like PD2's).
func test_police_shoot_the_sentry() -> void:
	var sg: SentryGun = _place()
	sg.ammo = 0  # it does not shoot back here
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(300, 0, 300)))
	var cop: NpcBase = _enemy(sg.global_position + Vector3(0, 0, -10))
	var hurt: bool = await wait_until(func() -> bool: return sg.health < sg.max_health, 12.0)
	var brain: Node = cop.get_node(^"Brain")
	assert_eq(brain.get(&"combat_target"), sg, "the cop targets the sentry")
	assert_true(hurt, "and shoots it")


## D's model (eqp_sentry) is instanced UNDER Visual (Visual/<scene root>/Base/Yaw/Pitch): the contract nodes are found
## at any depth (no placeholder over the model), and the model's baked `deploy` clip plays on placement.
func test_model_nodes_found_under_the_scene_root_and_deploy_plays() -> void:
	var holder: Node3D = Node3D.new()
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	holder.add_child(visual)
	var model: Node3D = Node3D.new()
	model.name = "eqp_sentry"
	visual.add_child(model)
	var base: Node3D = Node3D.new()
	base.name = "Base"
	model.add_child(base)
	var yaw: Node3D = Node3D.new()
	yaw.name = "Yaw"
	base.add_child(yaw)
	var pitch: Node3D = Node3D.new()
	pitch.name = "Pitch"
	yaw.add_child(pitch)
	var muzzle: Marker3D = Marker3D.new()
	muzzle.name = "Muzzle"
	pitch.add_child(muzzle)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	var anim: Animation = Animation.new()
	anim.length = 0.8
	lib.add_animation(SentryGun.DEPLOY_CLIP, anim)
	ap.add_animation_library(&"", lib)
	model.add_child(ap)
	var sg: SentryGun = SentryGun.new()
	sg.process_mode = Node.PROCESS_MODE_DISABLED  # _ready only: no setup() params to tick with
	holder.add_child(sg)
	_rt.dynamic_root.add_child(holder)
	await wait_physics_frames(1)
	assert_eq(sg._yaw, yaw, "Yaw found under the model's root")
	assert_eq(sg._muzzle, muzzle, "Muzzle found")
	assert_eq(model.get_child_count(), 2, "no placeholder built")
	assert_true(model.visible, "the model stays shown")
	assert_eq(str(ap.current_animation), str(SentryGun.DEPLOY_CLIP), "the deploy clip plays")
	holder.queue_free()
