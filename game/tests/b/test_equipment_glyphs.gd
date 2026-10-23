## LEAD r290: every catalogue deployable and throwable has its own HUD glyph (EquipmentIcon.KINDS), none draws the
## fallback dot, and the glyph set the HUD uses for cable ties, body bags and hostages is covered too.
extends TestCase


func test_every_catalogue_item_has_a_glyph() -> void:
	ContentDB.clear_cache()
	var ids: Array[StringName] = []
	for r: Variant in ContentDB.all_deployables():
		ids.append((r as Resource).get(&"id") as StringName)
	for r: Variant in ContentDB.all_throwables():
		ids.append((r as Resource).get(&"id") as StringName)
	assert_true(ids.size() >= 15, "catalogue read (%d items)" % ids.size())
	for id: StringName in ids:
		var kind: StringName = EquipmentIcon.kind_for(id)
		assert_true(EquipmentIcon.KINDS.has(kind), "%s -> %s draws a glyph, not the fallback dot" % [id, kind])


func test_hud_only_kinds_and_every_kind_is_drawn() -> void:
	for k: StringName in [&"cable_tie", &"body_bag", &"hostage"]:
		assert_true(EquipmentIcon.KINDS.has(k), "%s glyph" % k)
	# Headless tests have no renderer: check that _glyph has a branch for every listed kind instead (the
	# windowed check of the glyph sheet is noted in docs/status/env_b.md).
	var src: String = (load("res://content/ui/hud/widgets/equipment_icon.gd") as Script).source_code
	var body: String = src.substr(src.find("func _glyph("))
	for k: StringName in EquipmentIcon.KINDS:
		assert_true(body.contains('&"%s"' % k), "_glyph draws %s" % k)
