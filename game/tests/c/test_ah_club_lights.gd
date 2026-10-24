## Afterhours `Lighting/ClubLights` (club_lights.gd, the hall's two states; B's r312 review: the club looked unchanged
## after the alarm): every state light is a direct child named Club* (club state) or Work* (house state);
## set_state(&"house") hides every Club* and shows every Work*, set_state(&"club") the reverse; an
## EventBus.alarm_raised brings the house up on its own (every peer, presentation only). Owner: ENV C.
extends TestCase

const SCENE: String = "res://world/heists/afterhours/afterhours.tscn"


func _club_lights(map: Node) -> Node:
	return map.get_node_or_null("Lighting/ClubLights")


static func _lights(cl: Node, prefix: String) -> Array[Light3D]:
	var out: Array[Light3D] = []
	for c: Node in cl.get_children():
		if c is Light3D and String(c.name).begins_with(prefix):
			out.append(c as Light3D)
	return out


func test_state_lights_are_direct_children() -> void:
	var map: Node = (load(SCENE) as PackedScene).instantiate()
	var cl: Node = _club_lights(map)
	assert_true(cl != null, "Lighting/ClubLights exists")
	if cl == null:
		map.free()
		return
	assert_true(_lights(cl, "Club").size() >= 3, "the club state has its lights (%d)" % _lights(cl, "Club").size())
	assert_true(_lights(cl, "Work").size() >= 4, "the house state has its lights (%d)" % _lights(cl, "Work").size())
	# no state light hides deeper (_apply toggles direct children only)
	for l: Node in cl.find_children("*", "Light3D", true, false):
		var nm: String = String(l.name)
		if nm.begins_with("Club") or nm.begins_with("Work"):
			assert_true(l.get_parent() == cl, "%s is a direct child of ClubLights" % nm)
	map.free()


func test_set_state_toggles_both_ways() -> void:
	var map: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(map)
	await wait_frames(1)
	var cl: Node = _club_lights(map)
	cl.call(&"set_state", &"house")
	for l: Light3D in _lights(cl, "Club"):
		assert_false(l.visible, "house: %s hidden" % l.name)
	for l: Light3D in _lights(cl, "Work"):
		assert_true(l.visible, "house: %s shown" % l.name)
	cl.call(&"set_state", &"club")
	for l: Light3D in _lights(cl, "Club"):
		assert_true(l.visible, "club: %s shown" % l.name)
	for l: Light3D in _lights(cl, "Work"):
		assert_false(l.visible, "club: %s hidden" % l.name)
	map.queue_free()


func test_alarm_brings_the_house_up() -> void:
	var map: Node = (load(SCENE) as PackedScene).instantiate()
	add_child(map)
	await wait_frames(1)
	var cl: Node = _club_lights(map)
	assert_eq(StringName(cl.get(&"state")), &"club", "the default state is club")
	EventBus.alarm_raised.emit(&"test", 0)
	await wait_frames(1)
	assert_eq(StringName(cl.get(&"state")), &"house", "alarm_raised: the house state")
	for l: Light3D in _lights(cl, "Work"):
		assert_true(l.visible, "after the alarm: %s shown" % l.name)
	for l: Light3D in _lights(cl, "Club"):
		assert_false(l.visible, "after the alarm: %s hidden" % l.name)
	map.queue_free()
