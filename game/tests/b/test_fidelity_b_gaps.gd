## B fidelity audit (LEAD r287, docs/status/env_b.md "B audit"): pins the B-owned data and HUD parts of pd2_fidelity
## rows that had no exact test. S5.6 (ECM pager delay is the aced ECM skill), S6.2 (body bag case holds 3), S8.4 (ECM
## 2 s deploy, 20 s jam), L2.11 (doctor bag 2 uses + down reset, first aid kit 4 at 1 s, ammo bag 400 %), C5
## (cue.mask_on registered), L1.7 (assault banner difficulty skulls + the Last Breath tag).
extends TestCase

const HUD_SCENE: PackedScene = preload("res://content/ui/hud/hud.tscn")


func before_all() -> void:
	ContentDB.clear_cache()


func _dep(id: StringName) -> DeployableDef:
	return ContentDB.by_id(ContentDB.DEPLOYABLES, id) as DeployableDef


func test_deployable_numbers_match_pd2() -> void:
	var ecm: DeployableDef = _dep(&"deployable.ecm")
	assert_near(ecm.deploy_time_s, 2.0, 0.001, "S8.4 ECM: 2 s deploy")
	assert_near(float(ecm.params.get("duration", 0.0)), 20.0, 0.001, "S8.4 ECM: 20 s jam")
	var bbc: DeployableDef = _dep(&"deployable.body_bag_case")
	assert_eq(int(bbc.params.get("bags", 0)), 3, "S6.2 a body bag case holds 3")
	var doc: DeployableDef = _dep(&"deployable.doctor_bag")
	assert_eq(doc.uses, 2, "L2.11 doctor bag: 2 uses")
	assert_true(bool(doc.params.get("resets_downs", false)), "L2.11 doctor bag resets downs")
	var fak: DeployableDef = _dep(&"deployable.fak")
	assert_eq(fak.count, 4, "L2.11 first aid kit: 4")
	assert_near(fak.deploy_time_s, 1.0, 0.001, "L2.11 first aid kit: 1 s deploy")
	assert_false(bool(fak.params.get("resets_downs", false)), "L2.11 a first aid kit does not reset downs")
	assert_eq(_dep(&"deployable.ammo_bag").uses, 4, "L2.11 ammo bag: 4 uses (400 %)")


func test_ecm_pager_delay_is_the_aced_skill() -> void:
	var sk: SkillDef = ContentDB.by_id(ContentDB.SKILLS, &"skill.infiltrator.jammer_jockey") as SkillDef
	assert_true(sk != null, "Jammer Jockey (PD2 ECM Specialist)")
	if sk == null:
		return
	assert_false(sk.grants_basic.has(&"stealth.ecm_pager_delay"), "S5.6: base ECM / basic never touches pagers")
	assert_true(sk.grants_aced.has(&"stealth.ecm_pager_delay"), "S5.6: aced pauses the pager window")


func test_mask_up_cue_is_registered() -> void:
	var reg: Resource = load("res://world/audio/cues.tres")
	var ids: Array[StringName] = []
	for c: Variant in reg.get(&"cues") as Array:
		ids.append(StringName((c as Resource).get(&"id")))
	assert_true(ids.has(&"cue.mask_on"), "C5: the mask-up sound")


func test_assault_banner_skulls_and_last_breath() -> void:
	var model: MockHudModel = MockHudModel.new()
	add_child(model)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.auto_find_model = false
	hud.difficulty = Enums.Difficulty.LETHAL
	hud.last_breath = true
	add_child(hud)
	await wait_frames(1)
	hud.bind(model)
	model.assault_phase = Enums.AssaultPhase.BUILD
	await wait_frames(1)
	assert_true(hud.assault.visible)
	assert_eq(hud.assault.skulls.count, Enums.Difficulty.LETHAL, "one skull per tier above Routine (Lethal = 4)")
	assert_true(hud.assault.skulls.visible)
	assert_true(hud.assault.last_breath_label.visible, "the Last Breath tag")
	hud.assault.difficulty = Enums.Difficulty.ROUTINE
	hud.assault.last_breath = false
	hud.assault.refresh()
	assert_false(hud.assault.skulls.visible, "Routine: no skulls (PD2 Normal)")
	assert_false(hud.assault.last_breath_label.visible)
	hud.queue_free()
	model.queue_free()
	await wait_frames(1)
