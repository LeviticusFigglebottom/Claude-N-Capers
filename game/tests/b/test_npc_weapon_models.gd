## Lead ruling (PO6-16 shot: cops empty-handed): every EnemyDef.weapon id maps to an armory model through
## NpcWeaponModels (or is itself an armory weapon), except melee-only ids.
extends TestCase

const ENEMY_DIR: String = "res://systems/ai/data/enemies/"


func test_every_enemy_gun_has_a_model() -> void:
	var seen: int = 0
	for f: String in DirAccess.get_files_at(ENEMY_DIR):
		if not f.ends_with(".tres"):
			continue
		var e: EnemyDef = load(ENEMY_DIR + f) as EnemyDef
		if e == null or e.weapon == &"" or String(e.weapon).contains("melee"):
			continue
		seen += 1
		var def: WeaponDef = NpcWeaponModels.weapon_def(e.weapon)
		assert_true(def != null and def.model != null, "%s (%s) carries a model" % [e.id, e.weapon])
	assert_true(seen >= 10, "enemy guns checked: %d" % seen)


func test_unmapped_and_armory_ids() -> void:
	assert_true(NpcWeaponModels.weapon_def(&"weapon.npc_melee_kick") == null, "melee stays empty-handed")
	assert_true(NpcWeaponModels.weapon_def(&"") == null)
	assert_eq(NpcWeaponModels.weapon_def(&"weapon.corsair_ar").id, &"weapon.corsair_ar", "an armory id is itself")
	assert_eq(NpcWeaponModels.weapon_def(&"weapon.npc_rifle").id, &"weapon.corsair_ar")


## LEAD (P's GN loud run): AnimDriver.refresh_weapon's NPC path (NpcWeaponModels.weapon_def) logged "unknown weapons id
## 'weapon.npc_*'" for every NPC (ContentDB.weapon on a gameplay id). Every enemy weapon id, mapped or not, resolves
## without an ERROR line.
func test_npc_ids_resolve_without_logging_an_error() -> void:
	var ids: Array[StringName] = [&"weapon.npc_melee_kick", &"weapon.npc_unknown_test"]
	for f: String in DirAccess.get_files_at(ENEMY_DIR):
		var e: EnemyDef = load(ENEMY_DIR + f) as EnemyDef if f.ends_with(".tres") else null
		if e != null and e.weapon != &"":
			ids.append(e.weapon)
	Log.captured.clear()
	Log.capture = true
	for id: StringName in ids:
		NpcWeaponModels.weapon_def(id)
	Log.capture = false
	var errors: Array[String] = []
	for line: String in Log.captured:
		if line.begins_with("[ERROR]"):
			errors.append(line)
	Log.captured.clear()
	assert_true(ids.size() > 10, "ids checked: %d" % ids.size())
	assert_eq(errors.size(), 0, "no error logged:\n" + "\n".join(errors))
