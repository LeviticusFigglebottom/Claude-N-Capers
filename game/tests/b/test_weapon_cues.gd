## ENV C's catch: rotor_saw.fire_cue named a cue the registry lacks (the placeholder beep played). Every
## weapon's fire / suppressed fire cue is a registered cue (or empty).
extends TestCase


func test_every_weapon_fire_cue_is_registered() -> void:
	var lib: Script = UiNav.global_class(&"AudioCueLib")
	assert_true(lib != null, "AudioCueLib")
	var reg: Object = lib.call(&"registry") as Object
	var weapons: Array = ContentDB.all_weapons()
	assert_true(weapons.size() >= 10, "weapons load")
	for w: Resource in weapons:
		for field: StringName in [&"fire_cue", &"fire_cue_suppressed"]:
			var id: StringName = StringName(w.get(field)) if w.get(field) != null else &""
			if id == &"":
				continue
			assert_true(reg.call(&"get_cue", id) != null, "%s.%s %s is registered" % [w.get(&"id"), field, id])
