## B4-01: the 90 skills as data (pd2_fidelity.md P2/P3): structure, costs, ids, grants against the
## ModifierKeys registry, no blocked parts (D-031), strings and the design doc (content/docs/skills.md).
extends TestCase

const DOC_PATH: String = "res://content/docs/skills.md"
## DeployableDef.kind values (qualifier of deploy.extra / deploy.capacity_mult).
const DEPLOY_KINDS: Array[String] = ["ammo_bag", "doctor_bag", "fak", "ecm", "trip_mine", "sentry", "body_bag_case"]
const DEPLOY_QUALIFIED: Array[String] = ["deploy.extra", "deploy.capacity_mult", "deploy.deploy_speed_mult"]
## Deploy keys that also accept `.all` (every deployable kind).
const DEPLOY_ALL_OK: Array[String] = ["deploy.deploy_speed_mult"]
## Non-weapon keys that take a weapon-class qualifier (D-031).
const WEAPON_QUALIFIED_OTHER: Array[String] = ["movement.shoot_while_sprinting"]
## Weapon qualifiers besides the weapon classes and `all` (D-031).
const EXTRA_WEAPON_QUALIFIERS: Array[String] = ["suppressed", "akimbo"]
## MULT keys whose registry description allows 0 ("0 = no penalty").
const MULT_ZERO_OK: Array[StringName] = [&"movement.ads_speed_penalty_mult"]
const PERK_DOC_PATH: String = "res://content/docs/perk_decks.md"
## pd2_fidelity.md P3 signature skills (our names).
const SIGNATURE: Array[String] = [
	"Rally Cry", "Zip & Tie", "Turncoat", "Captive Audience", "Leverage", "Clean Shot", "Plated", "Tinker",
	"Overclocked Bits", "Percussive Maintenance", "Plain Sight", "Tidy Up", "Gut Feeling", "Light Fingers",
	"Signal Flood", "Jammer Jockey", "Deep Pockets", "Cornered", "Grounded", "Slippery", "Bolt", "Low Profile",
	"Cheap Shot", "Ambusher", "Cat's Luck", "Last Stand", "Comeback", "Riposte", "Red Mist", "Anatomy",
	"Lead Rain", "Pack Mule", "Momentum", "Grazing Fire", "Hot Streak",
]
const PARTS: Array[String] = ["basic", "aced"]

var _tree: SkillTreeDef
var _skills: Array[SkillDef] = []


func before_all() -> void:
	ContentDB.clear_cache()
	_tree = SkillTreeDef.load_default()
	for r: Variant in ContentDB.all_of(ContentDB.SKILLS):
		_skills.append(r as SkillDef)


func test_exactly_90_skills_in_15_subtrees() -> void:
	assert_true(_tree != null, "trees.tres loads")
	assert_eq(_skills.size(), 90)
	assert_eq(_tree.trees.size(), 5)
	var per_sub: Dictionary = {}
	for s: SkillDef in _skills:
		per_sub[s.subtree] = int(per_sub.get(s.subtree, 0)) + 1
	assert_eq(per_sub.size(), 15)
	for sub: Variant in per_sub:
		assert_eq(per_sub[sub], 6, "skills in %s" % sub)
	for tree: StringName in _tree.trees:
		assert_eq(_tree.subtree_ids(tree).size(), 3, "subtrees of %s" % tree)


func test_layout_matches_skill_defs_and_tier_sizes() -> void:
	var by_id: Dictionary = _by_id()
	var listed: Array[StringName] = _tree.all_skill_ids()
	assert_eq(listed.size(), 90)
	var seen: Dictionary = {}
	for tree: StringName in _tree.trees:
		for sub: StringName in _tree.subtree_ids(tree):
			var tiers: Array = _tree.layout.get(sub, [])
			assert_eq(tiers.size(), 4, "%s has 4 tiers" % sub)
			for t: int in range(tiers.size()):
				assert_eq((tiers[t] as Array).size(), _tree.tier_sizes[t], "%s tier %d size" % [sub, t + 1])
				for sid: Variant in tiers[t]:
					var s: SkillDef = by_id.get(StringName(sid), null) as SkillDef
					assert_true(s != null, "layout id %s exists" % sid)
					if s == null:
						continue
					assert_false(seen.has(s.id), "%s listed once" % s.id)
					seen[s.id] = true
					assert_eq([s.tree, s.subtree, s.tier], [tree, sub, t + 1], "placement of %s" % s.id)
	assert_eq(seen.size(), 90, "every skill is in the layout")
	assert_eq(_tree.tier_sizes, [1, 2, 2, 1] as Array[int])
	assert_eq(_tree.tier_thresholds, [0, 1, 3, 18] as Array[int])


func test_costs_per_tier_and_full_tree_138() -> void:
	for s: SkillDef in _skills:
		assert_eq(s.cost_basic, _tree.tier_cost_basic[s.tier - 1], "basic cost %s" % s.id)
		assert_eq(s.cost_aced, _tree.tier_cost_aced[s.tier - 1], "aced cost %s" % s.id)
	assert_eq(_tree.tier_cost_basic, [1, 2, 3, 4] as Array[int])
	assert_eq(_tree.tier_cost_aced, [3, 4, 6, 8] as Array[int])
	var per_tree: Dictionary = {}
	var per_sub: Dictionary = {}
	for s: SkillDef in _skills:
		var c: int = SkillPoints.cost_of(s, SkillPoints.ACED)
		per_tree[s.tree] = int(per_tree.get(s.tree, 0)) + c
		per_sub[s.subtree] = int(per_sub.get(s.subtree, 0)) + c
	for tree: Variant in per_tree:
		assert_eq(per_tree[tree], 138, "full %s costs 138 (more than the 120 points at level 100)" % tree)
	for sub: Variant in per_sub:
		assert_eq(per_sub[sub], 46, "full %s costs 46" % sub)


func test_ids_and_names_unique_and_original_form() -> void:
	var names: Dictionary = {}
	var id_re: RegEx = RegEx.create_from_string("^skill\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$")
	for s: SkillDef in _skills:
		assert_true(id_re.search(String(s.id)) != null, "id form %s" % s.id)
		assert_true(String(s.id).begins_with("skill.%s." % s.subtree), "id uses the subtree: %s" % s.id)
		assert_true(s.display_name.strip_edges() != "", "name of %s" % s.id)
		assert_false(names.has(s.display_name), "duplicate name %s" % s.display_name)
		names[s.display_name] = s.id
		assert_true(s.desc_basic != "" and s.desc_aced != "", "descriptions of %s" % s.id)
	for n: String in SIGNATURE:
		assert_has(names, n, "signature skill %s" % n)


func test_every_grant_is_a_registered_key_with_valid_qualifier_and_type() -> void:
	for s: SkillDef in _skills:
		for grants: Dictionary in [s.grants_basic, s.grants_aced]:
			for key: Variant in grants:
				var k: StringName = StringName(key)
				assert_true(key is StringName, "%s: grant keys are StringNames (%s)" % [s.id, k])
				assert_true(ModifierKeys.is_known(k), "%s grants unregistered key %s" % [s.id, k])
				assert_true(_qualifier_ok(k), "%s: bad qualifier in %s" % [s.id, k])
				assert_true(_value_ok(k, grants[key]), "%s: value %s does not fit the type of %s" % [s.id, grants[key], k])


func test_every_part_has_grants_or_an_unlock() -> void:
	var by_id: Dictionary = _by_id()
	for s: SkillDef in _skills:
		for part: String in PARTS:
			var grants: Dictionary = s.grants_basic if part == "basic" else s.grants_aced
			var tag: String = "%s:%s" % [s.id, part]
			assert_true(not grants.is_empty() or _tree.unlocks.has(tag), "%s has no grant and no unlock" % tag)
	for tag: Variant in _tree.unlocks.keys():
		var bits: PackedStringArray = String(tag).split(":")
		assert_eq(bits.size(), 2, "tag form %s" % tag)
		assert_true(by_id.has(StringName(bits[0])) and PARTS.has(bits[1]), "tag names a skill part: %s" % tag)


## D-031: every requested key was registered and is granted. Every key in the "Requested keys" tables of skills.md
## and perk_decks.md must be granted by a skill / a perk card (exactly, or as a qualified form of it), and must be
## grantable (known key, valid qualifier). LEAD r280: blocked_on_keys now marks the parts whose keys have no runtime
## hook yet; test_blocked_parts_track_the_unhooked_keys keeps it exact.
func test_no_blocked_parts_and_every_requested_key_is_granted() -> void:
	var skill_keys: Dictionary = {}
	for s: SkillDef in _skills:
		for grants: Dictionary in [s.grants_basic, s.grants_aced]:
			for key: Variant in grants:
				skill_keys[StringName(key)] = true
	var perk_keys: Dictionary = {}
	for d: Variant in ContentDB.all_of(ContentDB.PERKS):
		for card: Dictionary in (d as PerkDeckDef).cards:
			for key: Variant in (card["grants"] as Dictionary):
				perk_keys[StringName(key)] = true
	var skill_req: Array[StringName] = _requested_keys(DOC_PATH)
	var perk_req: Array[StringName] = _requested_keys(PERK_DOC_PATH)
	assert_true(skill_req.size() >= 60, "skills.md lists the requested keys (%d)" % skill_req.size())
	assert_eq(perk_req.size(), 7, "perk_decks.md lists 7 requested keys")
	for k: StringName in skill_req:
		assert_true(_is_granted(k, skill_keys), "requested skill key %s is granted" % k)
	for k: StringName in perk_req:
		assert_true(_is_granted(k, perk_keys), "requested perk key %s is granted" % k)
	for k: Variant in skill_keys:
		assert_true(ModifierKeys.is_known(k) and _qualifier_ok(k), "%s is grantable" % k)


func test_plated_exists_and_unlocks_breacher_plate() -> void:
	var plated: SkillDef = _by_id().get(&"skill.juggernaut.plated", null) as SkillDef
	assert_true(plated != null, "skill.juggernaut.plated exists")
	if plated == null:
		return
	assert_eq([plated.tree, plated.tier], [&"bruiser", 4])
	assert_eq(ContentDB.armor(&"armor.breacher_plate").unlock_skill, plated.id)
	assert_eq(_tree.unlocks.get("skill.juggernaut.plated:aced", &""), &"armor.breacher_plate")


func test_strings_exist_for_every_skill_tree_and_reason() -> void:
	var table: Dictionary = StringTable.parse_csv()
	for s: SkillDef in _skills:
		assert_eq(table.get("%s.name" % s.id, ""), s.display_name, "strings name of %s" % s.id)
		assert_eq(table.get("%s.basic" % s.id, ""), s.desc_basic, "strings basic of %s" % s.id)
		assert_eq(table.get("%s.aced" % s.id, ""), s.desc_aced, "strings aced of %s" % s.id)
	for tree: StringName in _tree.trees:
		assert_has(table, "ui.skills.tree.%s" % tree)
		for sub: StringName in _tree.subtree_ids(tree):
			assert_has(table, "ui.skills.subtree.%s" % sub)
	for code: StringName in [SkillPoints.REASON_UNKNOWN, SkillPoints.REASON_ACED, SkillPoints.REASON_TIER, SkillPoints.REASON_POINTS]:
		assert_has(table, "ui.skills.reason.%s" % code)


func test_team_skills_use_only_team_keys_for_crew_effects() -> void:
	var team_skills: Array[String] = []
	for s: SkillDef in _skills:
		for grants: Dictionary in [s.grants_basic, s.grants_aced]:
			for key: Variant in grants:
				if _tree.is_team_key(StringName(key)) and not team_skills.has(String(s.id)):
					team_skills.append(String(s.id))
	assert_has(team_skills, "skill.persuader.zip_and_tie", "Zip & Tie aced is crew-wide")
	assert_has(team_skills, "skill.juggernaut.shoulder_check", "Shoulder Check basic is crew-wide")
	assert_eq(team_skills.size(), 2, "team skills: %s" % [team_skills])


## D-031 QB-36: interaction.* speed keys are time multipliers (lower = faster); every skill that makes an
## interaction faster grants a value below 1.
func test_interaction_time_multipliers_below_one() -> void:
	for s: SkillDef in _skills:
		for grants: Dictionary in [s.grants_basic, s.grants_aced]:
			for key: Variant in grants:
				var k: String = String(key)
				if k.begins_with("interaction.") and k.ends_with("speed_mult"):
					assert_true(float(grants[key]) < 1.0, "%s %s = %s must be < 1 (faster)" % [s.id, k, grants[key]])
	var rally: SkillDef = _by_id()[&"skill.field_medic.rally_cry"]
	assert_near(float(rally.grants_basic[&"interaction.revive_speed_mult"]), 0.5, 0.0001, "100% faster revive")


## The design doc covers every tier-3/4 skill (decision note) and every requested key.
func test_design_doc_covers_tier_3_4_and_requested_keys() -> void:
	var doc: String = FileAccess.get_file_as_string(DOC_PATH)
	assert_true(doc.length() > 1000, "skills.md exists")
	var decisions: String = doc.get_slice("## Decisions", 1)
	for s: SkillDef in _skills:
		if s.tier >= 3:
			assert_true(decisions.contains("`%s`" % s.id), "decision note for %s" % s.id)
	# LEAD r280: a blocked key now waits for ENV A's runtime hook; each has a behaviour spec in the triage doc.
	var triage: String = FileAccess.get_file_as_string("res://content/docs/unhooked_skill_keys.md")
	for tag: Variant in _tree.blocked_on_keys:
		for key: Variant in _tree.blocked_on_keys[tag]:
			assert_true(triage.contains("`%s`" % key), "unhooked key %s has a spec in unhooked_skill_keys.md" % key)


func _by_id() -> Dictionary:
	var out: Dictionary = {}
	for s: SkillDef in _skills:
		out[s.id] = s
	return out


func _qualifier_ok(key: StringName) -> bool:
	var parts: PackedStringArray = String(key).split(".")
	if parts.size() != 3:
		return parts.size() <= 2
	var base: String = parts[0] + "." + parts[1]
	var allowed: Array[String] = []
	if StringName(base) == LoadoutResolver.CONCEALMENT_ADD_KEY:
		for q: StringName in LoadoutResolver.CONCEALMENT_QUALIFIERS:
			allowed.append(String(q))
	elif DEPLOY_QUALIFIED.has(base):
		allowed = DEPLOY_KINDS.duplicate()
		if DEPLOY_ALL_OK.has(base):
			allowed.append("all")
	elif parts[0] == "weapon" or WEAPON_QUALIFIED_OTHER.has(base):
		allowed.append("all")
		allowed.append_array(EXTRA_WEAPON_QUALIFIERS)
		for c: int in Enums.WeaponClass.values():
			allowed.append(String(Enums.weapon_class_qualifier(c as Enums.WeaponClass)))
	return allowed.has(parts[2])


## Backticked keys in the first column of the "## Requested keys" tables of a design doc.
func _requested_keys(path: String) -> Array[StringName]:
	var section: String = FileAccess.get_file_as_string(path).get_slice("## Requested keys", 1)
	var out: Array[StringName] = []
	var re: RegEx = RegEx.create_from_string("^\\| `([a-z_]+\\.[a-z_.]+)` \\|")
	for line: String in section.split("\n"):
		var m: RegExMatch = re.search(line)
		if m != null and not out.has(StringName(m.get_string(1))):
			out.append(StringName(m.get_string(1)))
	return out


## `key` is granted as is, or a qualified form of it (`weapon.still_spread_mult` -> `.all`).
func _is_granted(key: StringName, granted: Dictionary) -> bool:
	if granted.has(key):
		return true
	for g: Variant in granted:
		if ModifierKeys.base_key(StringName(g)) == key:
			return true
	return false


func _value_ok(key: StringName, v: Variant) -> bool:
	match ModifierKeys.type_of(key):
		ModifierKeys.Type.MULT:
			if MULT_ZERO_OK.has(ModifierKeys.base_key(key)) or MULT_ZERO_OK.has(key):
				return (v is float or v is int) and float(v) >= 0.0
			return (v is float or v is int) and float(v) > 0.0
		ModifierKeys.Type.LIST:
			return v is Dictionary and not (v as Dictionary).is_empty()
		ModifierKeys.Type.ADD:
			return v is float or v is int
		ModifierKeys.Type.FLAG:
			return v is bool
		_:
			return v is Dictionary and not (v as Dictionary).is_empty()


## D-038 QA-16: ECM feedback is built into every ECM; nothing in our data grants the deprecated flag.
func test_deprecated_ecm_feedback_flag_never_granted() -> void:
	var rx: RegEx = RegEx.create_from_string("\"stealth\\.ecm_feedback\"")
	var files: Array[String] = []
	_collect_tres("res://content/data", files)
	assert_true(files.size() > 50, "scanned %d data files" % files.size())
	for path: String in files:
		assert_true(rx.search(FileAccess.get_file_as_string(path)) == null, "%s grants stealth.ecm_feedback" % path)
	for id: Variant in PreplanBoard.generic_assets():
		assert_false((PreplanBoard.generic_assets()[id] as PreplanAssetDef).grants.has(&"stealth.ecm_feedback"))


func _collect_tres(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
	for sub: String in d.get_directories():
		_collect_tres(dir_path.path_join(sub), out)


## LEAD r280 (content/docs/unhooked_skill_keys.md): a skill part is marked "not active yet" exactly when it grants a
## key the P4 coverage ratchet lists as UNHOOKED (no runtime code reads it). When ENV A hooks a key and moves it out of
## UNHOOKED, this fails until the key leaves blocked_on_keys in the same round, so the marker never outlives the gap.
func test_blocked_parts_track_the_unhooked_keys() -> void:
	var ratchet: GDScript = load("res://tests/integration/p4_coverage_ratchet.gd") as GDScript
	var unhooked: Dictionary = ratchet.get_script_constant_map().get("UNHOOKED", {}) as Dictionary
	assert_true(unhooked.size() > 0, "the ratchet lists unhooked keys")
	var want: Dictionary = {}
	for s: SkillDef in _skills:
		for part: String in PARTS:
			var keys: Array[StringName] = []
			for k: Variant in (s.grants_basic if part == "basic" else s.grants_aced):
				for u: Variant in unhooked:
					if (String(k) == String(u) or String(k).begins_with(String(u) + ".")) and not keys.has(StringName(u)):
						keys.append(StringName(u))
			if not keys.is_empty():
				want["%s:%s" % [s.id, part]] = keys
	assert_eq(want.size(), _tree.blocked_on_keys.size(), "blocked parts")
	for tag: Variant in want:
		var have: PackedStringArray = PackedStringArray()
		for x: Variant in _tree.blocked_on_keys.get(tag, []) as Array:
			have.append(String(x))
		have.sort()
		var exp: PackedStringArray = PackedStringArray()
		for x: StringName in want[tag]:
			exp.append(String(x))
		exp.sort()
		assert_eq(have, exp, "%s blocked on its unhooked keys" % tag)
