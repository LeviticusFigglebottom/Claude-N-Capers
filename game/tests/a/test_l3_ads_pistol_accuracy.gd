## D-131 (B 372f3bd7): an aimed (ADS, standing still) pistol or revolver shot at a body 10 m away hits it essentially
## always, as PD2's ADS pistols do. CombatTweak.ads_spread_mult (0.7, ◇) scales WeaponStats.spread_deg_ads at runtime.
## The shot starts at the eye (no muzzle parallax). Every PISTOL-class weapon in the catalog (revolvers, akimbos
## included): 100 spread seeds through the real hitscan at a guard's chest, >= 98 hits. SMGs are reported only.
extends TestCase

const SEEDS: int = 100
const RANGE_M: float = 10.0
const MIN_HITS: int = 98

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_ads_pistols_hit_a_torso_at_10_m() -> void:
	_rt = await HeistLauncher.launch(&"unit_map", 3720, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -RANGE_M), Vector3(0, 0, 1))
	g.set_alert_state(Enums.AlertState.COMBAT)
	await wait_physics_frames(3)
	assert_near(CombatTweak.data().ads_spread_mult, 0.7, 0.001, "D-131 ads_spread_mult 0.7")
	var checked: int = 0
	for w: Variant in ContentDB.all_weapons():
		var def: WeaponDef = w as WeaponDef
		if def == null or (def.weapon_class != Enums.WeaponClass.PISTOL and def.weapon_class != Enums.WeaponClass.SMG):
			continue
		var res: Array = await _hits(c, g, def.id)
		var hits: int = res[0]
		print("[ads] %s %s: ADS cone %.2f deg (%.2f m at %d m), %d / %d hits" % [
			"pistol" if def.weapon_class == Enums.WeaponClass.PISTOL else "smg   ", def.id, res[1],
			tan(deg_to_rad(res[1])) * RANGE_M, int(RANGE_M), hits, SEEDS])
		if def.weapon_class == Enums.WeaponClass.PISTOL:
			checked += 1
			assert_true(hits >= MIN_HITS, "%s ADS at a 10 m torso: %d / %d hits" % [def.id, hits, SEEDS])
	assert_true(checked >= 3, "pistols and revolvers checked (%d)" % checked)


## [hits on `g` over SEEDS ADS shots of `weapon_id` from the secondary slot, the effective ADS cone in deg].
func _hits(c: CrewController, g: NpcBase, weapon_id: StringName) -> Array:
	var l: Loadout = Loadout.new()
	l.secondary = weapon_id
	c.set_loadout(CrewWeapons.build_loadout(l))
	c.weapons.equip(Enums.WeaponSlot.SECONDARY)
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), CombatSystem.target_center(g))
	aim.aim = true
	_rt.set_bot_intent(0, aim)
	await wait_physics_frames(2)
	var s: Variant = c.weapons._states.get(Enums.WeaponSlot.SECONDARY)
	var hits: int = 0
	for i: int in SEEDS:
		GameRng.stream(&"spread").seed = 1000 + i
		for h: Dictionary in c.weapons._build_claim(s, aim)["hits"]:
			if h.get("target") == g:
				hits += 1
				break
	return [hits, c.weapons._spread_deg(s, aim)]
