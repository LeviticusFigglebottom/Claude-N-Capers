## D-165 (LEAD r306, D 4eb0336a p5_cast v16): every Afterhours spawn wears a club look. Each GUARD / CIVILIAN /
## CAMERA_OPERATOR SpawnPoint on C's map (and the mission's scripted ones: the off-duty cop, the couriers) carries a tag
## that NpcVisualTweak.heist_tag_characters[afterhours] maps, so none falls back to the shared guard / civilian looks;
## the looks are club_ ids (the couriers: the Co-op gunmen without face cover, p5_cast club_courier). The off-duty
## cop is plain clothes (club_offduty_cop, not frd_agent). the vip_party guests (civ_vip) map to the club_vip pool. SKIPs without the map.
extends TestCase

const MAP_PATH: String = "res://world/heists/afterhours/afterhours.tscn"
const PEOPLE: Array[int] = [SpawnPoint.Kind.GUARD, SpawnPoint.Kind.CIVILIAN, SpawnPoint.Kind.CAMERA_OPERATOR]


func _ah() -> Dictionary:
	return NpcVisuals.tweak().heist_tag_characters.get(&"afterhours", {}) as Dictionary


## The first tag of `tags` the AH map knows (NpcVisuals._by_tag's order), or &"".
func _look_tag(tags: Array[StringName]) -> StringName:
	for t: StringName in tags:
		if _ah().has(t):
			return t
	return &""


func _club_ids(tag: StringName) -> bool:
	for id: Variant in _ah()[tag] as Array:
		var want: String = "cartel_gunman" if tag == &"cartel_courier" else "club_"
		if not String(id).begins_with(want):
			return false
	return true


func test_special_roles_map_to_their_pools() -> void:
	assert_eq(_ah().get(&"civ_offduty"), [&"club_offduty_cop"], "the off-duty cop is plain clothes (D-165 ruling)")
	assert_eq((_ah().get(&"civ_vip", []) as Array).size(), 6, "vip_party guests (civ_vip): club_vip a-f")
	var couriers: Array = _ah().get(&"cartel_courier", [])
	assert_false(couriers.is_empty(), "cartel_courier mapped")
	for face: StringName in [&"cartel_gunman_b", &"cartel_gunman_f", &"cartel_gunman_g"]:
		assert_false(couriers.has(face), "no face-covered courier (%s)" % face)


func test_every_ah_spawn_maps_to_a_club_look() -> void:
	if not ResourceLoader.exists(MAP_PATH):
		skip("pending C G1: no afterhours map on this branch")
		return
	var root: Node = (load(MAP_PATH) as PackedScene).instantiate()
	var seen: int = 0
	for n: Node in root.find_children("*", "SpawnPoint", true, false):
		var sp: SpawnPoint = n as SpawnPoint
		var scripted: bool = sp.tags.has(&"civ_offduty") or sp.tags.has(&"cartel_courier")
		if not (int(sp.kind) in PEOPLE) and not scripted:
			continue  # crew starts, police reinforcements, sniper perches
		seen += 1
		var tag: StringName = _look_tag(sp.tags)
		assert_ne(tag, &"", "%s %s: a tag with an AH look (else the shared fallback)" % [root.get_path_to(sp), sp.tags])
		if tag != &"":
			assert_true(_club_ids(tag), "%s: %s maps to club looks (%s)" % [root.get_path_to(sp), tag, _ah()[tag]])
	root.free()
	assert_true(seen > 40, "audited the AH people spawns (%d)" % seen)
	var missing: Array[String] = []
	for tag: Variant in _ah():
		for id: Variant in _ah()[tag] as Array:
			if not ResourceLoader.exists(NpcVisuals.scene_path(String(id))) and not missing.has(String(id)):
				missing.append(String(id))
	print("AH looks not delivered on this tree yet (D's round; skipped at runtime, D-115): %s" % [missing])
