## Lead queue: every heister row in the loadout picker shows a picture (ENV D's portrait, else an accent-tinted
## silhouette) and the heister's accent strip.
extends TestCase

var _screen: LoadoutScreen


func before_all() -> void:
	SaveService.root_dir = BTestUtil.profile_root()


func after_all() -> void:
	SaveService.delete_profile(0)
	SaveService.root_dir = SaveService.DEFAULT_ROOT_DIR


func before_each() -> void:
	SaveService.delete_profile(0)
	_screen = (load("res://content/ui/menus/loadout.tscn") as PackedScene).instantiate() as LoadoutScreen
	_screen.setup(PlayerProfile.new_default())
	add_child(_screen)
	await wait_frames(1)


func after_each() -> void:
	_screen.queue_free()
	await wait_frames(1)


func test_every_heister_tile_has_picture_and_accent() -> void:
	var slot: ItemSlot = _screen.heister_option
	assert_eq(slot.item_count, Heisters.ids().size() + 1, "any free + every heister")
	for i: int in range(slot.item_count):
		assert_true(slot.get_item_icon(i) != null, "row %d has a picture" % i)
		assert_true(slot.get_item_accent(i).a > 0.0, "row %d has an accent" % i)
	var picker: ItemPicker = slot.open_picker()
	await wait_frames(2)
	for t: Button in picker.tiles:
		assert_true(t.find_child("Picture", true, false) != null, "tile shows the picture, not the slot glyph")
		assert_true(t.find_child("Accent", true, false) != null, "tile shows the accent strip")
	picker.close()


func test_silhouette_until_a_portrait_exists() -> void:
	for id: StringName in Heisters.ids():
		var tex: Texture2D = LoadoutScreen.heister_icon(id)
		assert_true(tex != null, "%s picture" % id)
		if Heisters.portrait(id) != null:
			assert_eq(tex, Heisters.portrait(id), "%s uses ENV D's portrait" % id)
