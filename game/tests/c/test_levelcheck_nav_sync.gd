## OF-C2: levelcheck's navigation toggles wait for the map to sync them (not a fixed frame count). A loaded box once
## ran reachability's first (baseline) config on a map that had not yet synced the door links barred_doors had just
## restored: the vault behind its baked-closed gate read unreachable (840 FAILs on a scene that passes on a rerun).
extends LcTestBase


func _ctx_with_slot_link() -> Array:
	var map: HeistMap = (load(GOOD) as PackedScene).instantiate() as HeistMap
	var slot: VariantSlot = VariantSlot.new()
	slot.name = "SyncSlot"
	slot.slot_group = &"sync_test"
	slot.slot_id = &"a"
	map.add_child(slot)
	var link: NavigationLink3D = NavigationLink3D.new()
	link.name = "SyncLink"
	link.start_position = Vector3(1.0, 0.0, 1.0)
	link.end_position = Vector3(2.0, 0.0, 1.0)
	slot.add_child(link)
	var ctx: LcContext = await LcRunner.prepare(map, self)
	return [ctx, map, slot, link]


func _free(map: HeistMap) -> void:
	remove_child(map)
	map.free()
	await wait_physics_frames(2)


## A variant toggle returns only once the navigation map has synced it (its iteration id moved on).
func test_variant_toggle_waits_for_the_map() -> void:
	var r: Array = await _ctx_with_slot_link()
	var ctx: LcContext = r[0]
	var link: NavigationLink3D = r[3]
	var nav_map: RID = (r[1] as HeistMap).get_world_3d().navigation_map
	var before: int = NavigationServer3D.map_get_iteration_id(nav_map)
	await ctx.set_variant_config({r[2]: false})
	assert_false(link.enabled, "the inactive slot's link is disabled")
	assert_true(NavigationServer3D.map_get_iteration_id(nav_map) != before, "the map synced the disable before return")
	before = NavigationServer3D.map_get_iteration_id(nav_map)
	await ctx.set_variant_config({})
	assert_true(link.enabled, "reset re-enables the link")
	assert_true(NavigationServer3D.map_get_iteration_id(nav_map) != before, "the map synced the re-enable before return")
	await _free(r[1])


## restore_links reports whether it changed anything (barred_doors then awaits the map update).
func test_restore_links_reports_changes() -> void:
	var r: Array = await _ctx_with_slot_link()
	var ctx: LcContext = r[0]
	var link: NavigationLink3D = r[3]
	var saved: Array[Array] = [[link, true]]
	assert_false(ctx.restore_links(saved), "nothing to restore")
	link.enabled = false
	assert_true(ctx.restore_links(saved), "a disabled link restored")
	assert_true(link.enabled, "the link is enabled again")
	await _free(r[1])
