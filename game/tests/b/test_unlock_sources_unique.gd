## LEAD r314 (D's reward audit: the AH achievement rewards were already owned from elsewhere): a cosmetic (mask part or
## preset) has at most one unlock source, so an achievement or a Notoriety rank never hands out something the player
## could own already. Sources:
##   ach:<id>    AchievementDef.rewards, plus the parts / presets gated on its unlock ids (unlock + unlocks)
##   rank:<n>    Notoriety.rewards_for(n) (its rewards plus the parts / presets gated on unlock.notoriety.rank_<n>)
##   choice      a Notoriety choice pool (ranks share one pool on purpose: one source)
##   default     MaskPartDef.default_owned
## Payday cards are not a source here: their pool already leaves out every part above (PaydayCards.pool).
extends TestCase

## The AH achievements (each must grant something exclusive).
const AH: Array[StringName] = [&"achievement.ah_no_witnesses", &"achievement.ah_dead_air",
	&"achievement.ah_just_looking", &"achievement.ah_bottle_service", &"achievement.ah_closing_time",
	&"achievement.ah_cataclysm"]


## { cosmetic id: Array[String] of its sources }.
static func sources() -> Dictionary:
	var out: Dictionary = {}
	var gated: Dictionary = {}  # unlock id -> cosmetic ids behind it (parts and presets)
	for kind: String in MaskCatalog.KINDS:
		for p: MaskPartDef in MaskCatalog.all_parts(kind):
			if p.default_owned:
				_add(out, p.id, "default")
			if p.unlock != &"":
				_gate(gated, p.unlock, p.id)
	for md: MaskDef in MaskCatalog.presets():
		if md.unlock != &"":
			_gate(gated, md.unlock, md.id)
	for a: AchievementDef in Achievements.all():
		var ids: Array[StringName] = []
		for r: StringName in a.rewards:
			ids.append(r)
		for u: StringName in ([a.unlock] as Array[StringName]) + a.unlocks:
			for g: StringName in gated.get(u, []) as Array:
				ids.append(g)
		for id: StringName in ids:
			_add(out, id, "ach:%s" % a.id)
	for d: NotorietyDef in Notoriety.table().ranks:
		for id: StringName in Notoriety.rewards_for(d.rank):
			if _cosmetic(id):
				_add(out, id, "rank:%d" % d.rank)
		for id: StringName in d.choices:
			_add(out, id, "choice")
	return out


static func _cosmetic(id: StringName) -> bool:
	return MaskCatalog.has_part(id) or MaskCatalog.is_preset_id(id)


static func _gate(gated: Dictionary, unlock: StringName, id: StringName) -> void:
	if not gated.has(unlock):
		gated[unlock] = []
	(gated[unlock] as Array).append(id)


static func _add(out: Dictionary, id: StringName, source: String) -> void:
	if not out.has(id):
		out[id] = []
	if not (out[id] as Array).has(source):
		(out[id] as Array).append(source)


func test_every_cosmetic_has_at_most_one_unlock_source() -> void:
	var src: Dictionary = sources()
	var dups: PackedStringArray = PackedStringArray()
	var keys: Array = src.keys()
	keys.sort()
	for id: Variant in keys:
		if (src[id] as Array).size() > 1:
			dups.append("%s <- %s" % [id, ", ".join(PackedStringArray(src[id] as Array))])
	assert_true(dups.is_empty(), "%d cosmetics with two unlock sources:\n  %s" % [dups.size(), "\n  ".join(dups)])
	assert_true(src.size() > 20, "the walk found the catalogue (%d cosmetics)" % src.size())


func test_each_ah_achievement_grants_something() -> void:
	var src: Dictionary = sources()
	for aid: StringName in AH:
		var n: int = 0
		for id: Variant in src:
			if (src[id] as Array).has("ach:%s" % aid):
				n += 1
		assert_true(n > 0, "%s grants a cosmetic" % aid)


func test_no_two_presets_share_a_look() -> void:
	var seen: Dictionary = {}
	for md: MaskDef in MaskCatalog.presets():
		var look: String = "%s|%s|%s|%s|%s" % [md.get_meta(&"mask_base", md.model.resource_path if md.model else ""),
				md.material_id, md.color_a.to_html(), md.color_b.to_html(), md.pattern_id]
		assert_false(seen.has(look), "%s looks exactly like %s" % [md.id, seen.get(look, "")])
		seen[look] = md.id


func test_ah_rewards_are_their_own() -> void:
	# LEAD r316: each AH achievement's exclusive cosmetics (D's bespoke parts and B's club presets).
	var want: Dictionary = {
		&"mask_base.vinyl": "ach:achievement.ah_dead_air", &"mask_pattern.vinyl_label": "ach:achievement.ah_dead_air",
		&"mask.dead_air": "ach:achievement.ah_dead_air", &"mask_base.disco": "ach:achievement.ah_closing_time",
		&"mask_material.sequin": "ach:achievement.ah_bottle_service",
		&"mask.velvet_rope": "ach:achievement.ah_no_witnesses", &"mask.mirror_ball": "ach:achievement.ah_just_looking",
		&"mask.house_lights": "ach:achievement.ah_cataclysm",
	}
	var src: Dictionary = sources()
	for id: StringName in want:
		assert_eq(src.get(id, []), [want[id]], "%s comes only from %s" % [id, want[id]])
