## PO-18 (D-145 §3, PO: "the cops seem to have body armor which they shouldn't until later"): on Routine and Tense no
## police unit the director can spawn has damage-reducing body armor (no TAC Heavy frontal plate, no armor_body_mult,
## no Wrecker plates); armored units start at Hazardous. Covers every director source: assault / control / first
## responder groups, the PO6-17 assault-event squads (breach, heli, turret van) and Brandt's Aegis squad. Pure data:
## EnemyRoster.resolve is what the director's roster calls for every id (faction remap + the armor rule).
extends TestCase

const DIRECTOR_TWEAK: String = "res://systems/director/director_tweak.tres"
const ENEMY_DIR: String = "res://systems/ai/data/enemies/"
const HEAVY_SQUAD: String = "res://systems/ai/data/groups/heavy_squad.tres"
const LOW: Array[int] = [Enums.Difficulty.ROUTINE, Enums.Difficulty.TENSE]
const HIGH: Array[int] = [
	Enums.Difficulty.HAZARDOUS, Enums.Difficulty.BRUTAL, Enums.Difficulty.LETHAL, Enums.Difficulty.CATACLYSM]


func _tw() -> DirectorTweak:
	return load(DIRECTOR_TWEAK) as DirectorTweak


## Every unit id the director may try to spawn on `difficulty`: groups with weight > 0 there (any stage, the
## difficulty's faction), every assault-event squad / sniper (they are not difficulty-gated), and Brandt's squad
## from captain_min_difficulty.
func _spawnable_ids(tw: DirectorTweak, difficulty: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var fac: StringName = EnemyRoster.faction_for_tweak(tw, difficulty)
	var groups: Array[SpawnGroupDef] = []
	groups.append_array(tw.assault_groups)
	groups.append_array(tw.control_special_groups)
	groups.append(tw.first_responder_group)
	for g: SpawnGroupDef in groups:
		if g == null:
			continue
		var w: float = 0.0
		for st: int in range(3):
			w = maxf(w, g.weight_for(difficulty, st, fac))
		if w > 0.0:
			for id: StringName in g.unit_ids:
				if not out.has(id):
					out.append(id)
	var ev: AssaultEventsTweak = AssaultEventsTweak.data()
	var params: Array[Dictionary] = []
	for kind: Variant in ev.kind_defaults.keys():
		params.append(ev.kind_defaults[kind] as Dictionary)
	for heist: Variant in ev.heists.keys():
		for row: Dictionary in AssaultEventsTweak.valid_rows((ev.heists[heist] as Dictionary).get("events", []) as Array):
			params.append(ev.params_for(row))
	for p: Dictionary in params:
		for id: Variant in p.get("squad", []):
			if not out.has(StringName(str(id))):
				out.append(StringName(str(id)))
		if p.has("sniper_id") and not out.has(StringName(str(p["sniper_id"]))):
			out.append(StringName(str(p["sniper_id"])))
	return out


func test_low_difficulties_spawn_no_armored_unit() -> void:
	var tw: DirectorTweak = _tw()
	for d: int in LOW:
		var ids: Array[StringName] = _spawnable_ids(tw, d)
		assert_true(ids.has(&"enemy.tac_light") and ids.has(&"enemy.tac_heavy"),
			"difficulty %d: the scan sees the event squads' TAC Heavy (so the rule is what keeps it out)" % d)
		for id: StringName in ids:
			var def: EnemyDef = EnemyRoster.resolve(tw, d, id)
			if def == null:
				continue  # skipped by the director
			assert_false(EnemyRoster.has_body_armor(def), "difficulty %d: %s resolves to %s, unarmored" % [d, id, def.id])
			assert_true(def.id != &"enemy.tac_heavy", "difficulty %d: no TAC Heavy (%s)" % [d, id])
			var a: Dictionary = NpcHitRules.armor_of(def)
			assert_near(float(a["armor_body_mult"]), 1.0, 0.0001, "difficulty %d: %s no body armor mult" % [d, def.id])
			assert_true(float(a["frontal_armor"]) >= 1.0 or float(a["frontal_armor_arc_deg"]) <= 0.0,
				"difficulty %d: %s no frontal plate" % [d, def.id])
			assert_true((a["plate_health"] as Array).is_empty(), "difficulty %d: %s no plates" % [d, def.id])
	assert_true(tw.captain_min_difficulty >= tw.armored_min_difficulty, "Brandt + Aegis only where armor is allowed")


func test_tac_heavy_becomes_tac_light_and_wreckers_are_skipped_below_hazardous() -> void:
	var tw: DirectorTweak = _tw()
	assert_eq(tw.armored_min_difficulty, Enums.Difficulty.HAZARDOUS, "armored units start at Hazardous")
	for d: int in LOW:
		var sub: EnemyDef = EnemyRoster.resolve(tw, d, &"enemy.tac_heavy")
		assert_true(sub != null and sub.id == &"enemy.tac_light", "difficulty %d: TAC Heavy -> TAC Light" % d)
		for w: StringName in [&"enemy.wrecker", &"enemy.wrecker_g", &"enemy.wrecker_b", &"enemy.wrecker_s", &"enemy.wrecker_m"]:
			assert_eq(EnemyRoster.resolve(tw, d, w), null, "difficulty %d: %s (plates) skipped" % [d, w])
		var bul: EnemyDef = EnemyRoster.resolve(tw, d, &"enemy.bulwark")
		assert_true(bul != null and bul.id == &"enemy.bulwark", "difficulty %d: Bulwark kept (a shield is not armor)" % d)
	var heavy: SpawnGroupDef = load(HEAVY_SQUAD) as SpawnGroupDef
	assert_near(heavy.weight(Enums.Difficulty.ROUTINE), 0.0, 0.0001, "no heavy squad on Routine")
	assert_near(heavy.weight(Enums.Difficulty.TENSE), 0.0, 0.0001, "no heavy squad on Tense")


func test_hazardous_and_up_allow_armored_units() -> void:
	var tw: DirectorTweak = _tw()
	for d: int in HIGH:
		var def: EnemyDef = EnemyRoster.resolve(tw, d, &"enemy.tac_heavy")
		assert_true(def != null and def.id == &"enemy.tac_heavy", "difficulty %d: TAC Heavy spawns" % d)
		assert_true(EnemyRoster.has_body_armor(def), "difficulty %d: with its frontal plate" % d)
		assert_true(EnemyRoster.resolve(tw, d, &"enemy.wrecker_g") != null, "difficulty %d: Wrecker allowed" % d)
	var heavy: SpawnGroupDef = load(HEAVY_SQUAD) as SpawnGroupDef
	assert_true(heavy.weight(Enums.Difficulty.HAZARDOUS) > 0.0, "heavy squad from Hazardous")
	var armored: bool = false
	for id: StringName in _spawnable_ids(tw, Enums.Difficulty.HAZARDOUS):
		armored = armored or EnemyRoster.has_body_armor(EnemyRoster.resolve(tw, Enums.Difficulty.HAZARDOUS, id))
	assert_true(armored, "Hazardous spawns armored units")


## The armor classifier: exactly the TAC Heavy (frontal plate) and the Wreckers (plates) are armored today; a unit
## added later with armor is caught by the rule above without a list to maintain.
func test_armor_classifier_over_every_enemy_def() -> void:
	var armored: Array[String] = []
	for sub: String in ["", "frd/", "sentinel/", "zero/"]:
		for f: String in DirAccess.get_files_at(ENEMY_DIR + sub):
			if not f.ends_with(".tres"):
				continue
			var def: EnemyDef = load(ENEMY_DIR + sub + f) as EnemyDef
			if def != null and EnemyRoster.has_body_armor(def):
				armored.append(sub + f.trim_suffix(".tres"))
	armored.sort()
	assert_eq(",".join(armored), "tac_heavy,wrecker,wrecker_b,wrecker_g,wrecker_m,wrecker_s", "armored EnemyDefs")
	var fake: EnemyDef = (load(ENEMY_DIR + "tac_light.tres") as EnemyDef).duplicate() as EnemyDef
	fake.params = fake.params.duplicate()
	fake.params["armor_body_mult"] = 0.5
	assert_true(EnemyRoster.has_body_armor(fake), "armor_body_mult < 1 counts as body armor")


## D-145.3: Routine/Tense police wear ENV D's unarmoured `duty` look (NpcVisualTweak.difficulty_variants, only below
## armored_min_difficulty): patrol officer, TAC Light, Stinger, Bulwark; Longshot / FRD keep their (unarmoured) base
## look, which the base fallback serves. Hazardous+ never try `duty`.
func test_low_difficulty_police_wear_duty_looks() -> void:
	var tw: DirectorTweak = _tw()
	for k: Variant in NpcVisuals.tweak().difficulty_variants.keys():
		assert_true(int(k) < tw.armored_min_difficulty, "duty variant only below armored_min_difficulty (%s)" % k)
	for d: int in LOW:
		for id: StringName in [&"enemy.patrol_officer", &"enemy.tac_light", &"enemy.stinger", &"enemy.bulwark"]:
			var def: EnemyDef = EnemyRoster.resolve(tw, d, id)
			assert_true(def != null, "difficulty %d: %s resolves" % [d, id])
			if def != null:
				assert_eq(Array(NpcVisuals.variants(def, d)), ["duty", ""], "difficulty %d: %s tries duty first" % [d, id])
	for d: int in HIGH:
		for id: StringName in _spawnable_ids(tw, d):
			var def: EnemyDef = EnemyRoster.resolve(tw, d, id)
			if def != null:
				assert_false(NpcVisuals.variants(def, d).has("duty"), "difficulty %d: %s keeps its armoured look" % [d, id])


## D-145 §2/§3: the Corpsman, Wreckers and the Phantom never spawn on Routine/Tense (their groups weigh 0 there).
func test_no_corpsman_wrecker_or_phantom_below_hazardous() -> void:
	var tw: DirectorTweak = _tw()
	for d: int in LOW:
		for id: StringName in _spawnable_ids(tw, d):
			var def: EnemyDef = EnemyRoster.resolve(tw, d, id)
			if def == null:
				continue
			assert_false(def.id == &"enemy.corpsman" or def.id == &"enemy.phantom"
				or String(def.id).begins_with("enemy.wrecker"), "difficulty %d: %s does not spawn" % [d, def.id])
