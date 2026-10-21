## D-145 (LEAD, the Tense vs PD2 Hard table): Tense police and tase values brought in line with PD2 Hard, erring gentle.
## TAC Light / Stinger 8 per hit (PD2 rifle SWAT ~8 close, taser 8-10), TAC Light 80 health, Patrol / Security Officer
## 40 (PD2 80 / 40), a tase downs after 10 s (PD2 tase_time), bots regain 25 %/s after 3 s (PD2 team AI heal at 2 s).
extends TestCase

const ENEMIES: String = "res://systems/ai/data/enemies/%s.tres"


func _def(id: String) -> EnemyDef:
	return load(ENEMIES % id) as EnemyDef


func test_d145_tense_police_damage_and_health() -> void:
	var t: int = Enums.Difficulty.TENSE
	assert_near(_def("tac_light").damage[t], 8.0, 0.001, "TAC Light damage at Tense")
	assert_near(_def("stinger").damage[t], 8.0, 0.001, "Stinger damage at Tense")
	assert_near(_def("tac_light").health[t], 80.0, 0.001, "TAC Light health at Tense")
	assert_near(_def("patrol_officer").health[t], 40.0, 0.001, "Patrol Officer health at Tense")
	assert_near(_def("security_officer").health[t], 40.0, 0.001, "Security Officer health at Tense")
	for id: String in ["tac_light", "stinger", "patrol_officer", "security_officer"]:
		var d: EnemyDef = _def(id)
		assert_true(d.damage[0] <= d.damage[1] and d.health[0] <= d.health[1], "%s: Routine no harsher than Tense" % id)


func test_d145_tase_and_bot_regen() -> void:
	assert_near(SpecialTweak.data().stinger_helpless_after_s, 10.0, 0.001, "a tase downs after 10 s (PD2 tase_time)")
	var ct: CrewAiTweak = CrewHealth._bot_tweak()
	assert_near(ct.bot_regen_delay_s, 3.0, 0.001, "bots regen after 3 s")
	assert_near(ct.bot_regen_frac_per_s, 0.25, 0.001, "at 25 %/s")
