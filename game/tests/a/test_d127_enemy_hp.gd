## D-127 (PO playtest): every non-special enemy (guards, beat cops, SWAT, heavy SWAT, FBI and their faction variants)
## has +25 % health on every difficulty; specials keep their tuned values (D-125); head multipliers unchanged.
extends TestCase

const DIR: String = "res://systems/ai/data/enemies/"
## Routine..Cataclysm after D-127 (the pre-D-127 table x 1.25).
const TABLE: Dictionary = {
	"security_officer": [50.0, 50.0, 75.0, 100.0, 150.0, 200.0],
	"patrol_officer": [50.0, 50.0, 75.0, 100.0, 150.0, 200.0],
	"tac_light": [100.0, 100.0, 150.0, 200.0, 300.0, 400.0],
	"frd/tac_light": [100.0, 100.0, 150.0, 200.0, 300.0, 400.0],
	"sentinel/tac_light": [100.0, 100.0, 150.0, 200.0, 300.0, 400.0],
	"zero/tac_light": [100.0, 100.0, 150.0, 200.0, 300.0, 400.0],
	"tac_heavy": [200.0, 200.0, 300.0, 400.0, 600.0, 800.0],
	"frd_agent": [75.0, 75.0, 112.5, 150.0, 225.0, 300.0],
	"sentinel/frd_agent": [75.0, 75.0, 112.5, 150.0, 225.0, 300.0],
}
## Specials stay as tuned (Routine and Cataclysm spot values).
const SPECIALS: Dictionary = {
	"bulwark": [80.0, 320.0], "stinger": [240.0, 720.0], "phantom": [160.0, 640.0], "corpsman": [120.0, 480.0],
	"longshot": [40.0, 160.0], "wrecker": [2000.0, 10000.0],
}


func _def(id: String) -> EnemyDef:
	return load(DIR + id + ".tres") as EnemyDef


func test_non_specials_have_the_d127_table() -> void:
	for id: String in TABLE:
		var d: EnemyDef = _def(id)
		assert_true(d != null and not d.is_special, "%s: a non-special EnemyDef" % id)
		var want: Array = TABLE[id]
		for i: int in want.size():
			assert_near(d.health[i], float(want[i]), 0.01, "%s HP[%d]" % [id, i])


func test_every_non_special_enemy_is_covered() -> void:
	var seen: Array[String] = []
	for sub: String in ["", "frd/", "sentinel/", "zero/"]:
		for f: String in DirAccess.get_files_at(DIR + sub):
			if f.ends_with(".tres"):
				var id: String = sub + f.trim_suffix(".tres")
				var d: EnemyDef = _def(id)
				if d != null and not d.is_special and id != "cartel_gunman":  # cartel: not in D-127's list (LEAD)
					seen.append(id)
	for id: String in seen:
		assert_true(TABLE.has(id), "%s is pinned in the D-127 table" % id)


func test_specials_and_head_multipliers_unchanged() -> void:
	for id: String in SPECIALS:
		var d: EnemyDef = _def(id)
		assert_near(d.health[0], float(SPECIALS[id][0]), 0.01, "%s Routine HP unchanged" % id)
		assert_near(d.health[d.health.size() - 1], float(SPECIALS[id][1]), 0.01, "%s Cataclysm HP unchanged" % id)
	assert_near(_def("tac_heavy").headshot_mult[5], 3.0, 0.001, "Heavy head x3 unchanged")
