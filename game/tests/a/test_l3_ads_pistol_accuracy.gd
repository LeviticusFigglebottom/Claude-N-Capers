## B 372f3bd7 (LEAD, low priority): an aimed (ADS, standing still) kestrel_p9 shot at a body 10 m away must hit it
## essentially always, as PD2's ADS pistol spread does. The shot starts at the eye (no muzzle parallax); 100 spread seeds
## through the real hitscan at a guard's chest; >= 98 hits.
extends TestCase

const SEEDS: int = 100
const RANGE_M: float = 10.0

var _rt: HeistRuntime = null


func after_each() -> void:
	if _rt != null and is_instance_valid(_rt):
		_rt.teardown()
	_rt = null
	await wait_frames(2)


func test_ads_pistol_hits_a_torso_at_10_m() -> void:
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.secondary = &"weapon.kestrel_p9"
	_rt = await HeistLauncher.launch(&"unit_map", 3720, Enums.Difficulty.ROUTINE, self,
		{"map_packed": ATestMaps.basic(0, 0), "ai_teammates": 0, "crew_ai": false, "skip_casing": true,
			"loadouts": {0: CrewWeapons.build_loadout(l)}})
	await wait_physics_frames(2)
	var c: CrewController = _rt.crew_controller(0) as CrewController
	_rt.teleport_crew(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	c.set_masked()
	var g: NpcBase = ATestMaps.add_npc_observer(_rt, &"guard", Vector3(0, 0.05, -RANGE_M), Vector3(0, 0, 1))
	g.set_alert_state(Enums.AlertState.COMBAT)
	await wait_physics_frames(3)
	c.weapons.equip(Enums.WeaponSlot.SECONDARY)
	var chest: Vector3 = CombatSystem.target_center(g)
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), chest)
	aim.aim = true
	_rt.set_bot_intent(0, aim)
	await wait_physics_frames(3)
	var s: Variant = c.weapons._states.get(Enums.WeaponSlot.SECONDARY)
	var spread: float = c.weapons._spread_deg(s, aim)
	var hits: int = 0
	for i: int in SEEDS:
		GameRng.stream(&"spread").seed = 1000 + i
		var claim: Dictionary = c.weapons._build_claim(s, aim)
		for h: Dictionary in claim["hits"]:
			if h.get("target") == g:
				hits += 1
				break
	print("[ads] kestrel_p9 ADS spread %.2f deg (%.2f m max at %d m): %d / %d hits" % [spread,
		tan(deg_to_rad(spread)) * RANGE_M, int(RANGE_M), hits, SEEDS])
	assert_true(hits >= 98, "ADS P9 at a 10 m torso: %d / %d hits (spread %.2f deg)" % [hits, SEEDS, spread])
