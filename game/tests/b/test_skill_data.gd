## B4-01: the 90 skills as data (pd2_fidelity.md P2/P3): structure, costs, ids, grants against the
## ModifierKeys registry, blocked parts, strings and the design doc (content/docs/skills.md).
extends TestCase

const DOC_PATH: String = "res://content/docs/skills.md"
## DeployableDef.kind values (qualifier of deploy.extra / deploy.capacity_mult).
const DEPLOY_KINDS: Array[String] = ["ammo_bag", "doctor_bag", "fak", "ecm", "trip_mine", "sentry", "body_bag_case"]
const DEPLOY_QUALIFIED: Array[String] = ["deploy.extra", "deploy.capacity_mult"]
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


func test_every_part_has_grants_or_is_listed_blocked() -> void:
	var by_id: Dictionary = _by_id()
	for s: SkillDef in _skills:
		for part: String in PARTS:
			var grants: Dictionary = s.grants_basic if part == "basic" else s.grants_aced
			var tag: String = "%s:%s" % [s.id, part]
			var listed: bool = _tree.blocked_on_keys.has(tag) or _tree.unlocks.has(tag)
			assert_true(not grants.is_empty() or listed, "%s has no grant and is not listed blocked/unlock" % tag)
	for tag: Variant in _tree.blocked_on_keys.keys() + _tree.unlocks.keys():
		var bits: PackedStringArray = String(tag).split(":")
		assert_eq(bits.size(), 2, "tag form %s" % tag)
		assert_true(by_id.has(StringName(bits[0])) and PARTS.has(bits[1]), "tag names a skill part: %s" % tag)


## A requested key must still be missing from the registry (or use a qualifier it does not accept). When
## the lead adds one, this fails: grant it in the skill and drop it from blocked_on_keys.
func test_requested_keys_are_not_grantable_yet() -> void:
	for tag: Variant in _tree.blocked_on_keys:
		var keys: Array = _tree.blocked_on_keys[tag]
		assert_false(keys.is_empty(), "%s lists keys" % tag)
		for key: Variant in keys:
			var k: StringName = StringName(key)
			assert_true(String(k).count(".") >= 1, "%s: key form %s" % [tag, k])
			assert_false(ModifierKeys.is_known(k) and _qualifier_ok(k), "%s: %s is grantable now; grant it" % [tag, k])


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


## The design doc covers every tier-3/4 skill (decision note) and every requested key.
func test_design_doc_covers_tier_3_4_and_requested_keys() -> void:
	var doc: String = FileAccess.get_file_as_string(DOC_PATH)
	assert_true(doc.length() > 1000, "skills.md exists")
	var decisions: String = doc.get_slice("## Decisions", 1)
	for s: SkillDef in _skills:
		if s.tier >= 3:
			assert_true(decisions.contains("`%s`" % s.id), "decision note for %s" % s.id)
	var requests: String = doc.get_slice("## Requested keys", 1)
	for tag: Variant in _tree.blocked_on_keys:
		for key: Variant in _tree.blocked_on_keys[tag]:
			assert_true(requests.contains("`%s`" % key), "requested key %s documented" % key)


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
		allowed = DEPLOY_KINDS
	elif parts[0] == "weapon":
		allowed.append("all")
		for c: int in Enums.WeaponClass.values():
			allowed.append(String(Enums.weapon_class_qualifier(c as Enums.WeaponClass)))
	return allowed.has(parts[2])


func _value_ok(key: StringName, v: Variant) -> bool:
	match ModifierKeys.type_of(key):
		ModifierKeys.Type.MULT:
			return (v is float or v is int) and float(v) > 0.0
		ModifierKeys.Type.ADD:
			return v is float or v is int
		ModifierKeys.Type.FLAG:
			return v is bool
		_:
			return v is Dictionary and not (v as Dictionary).is_empty()
