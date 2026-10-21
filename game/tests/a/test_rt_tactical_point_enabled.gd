## D-149 QC-RT1: a TacticalPoint with `enabled` off is out of its kind's group, so no consumer sees it (the director's
## spawn / entry picks, cover searches, flank, perch, rappel and shield-anchor lookups all read the groups live through
## HeistMap.get_slots / get_nodes_in_group). Rolling Thunder swaps convoy-layout nav regions at the stop and toggles the
## points that go with them. SKIPs "pending the LEAD contract" until TacticalPoint has the flag.
extends TestCase

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(1)


func _point(kind: TacticalPoint.Kind) -> TacticalPoint:
	var tp: TacticalPoint = TacticalPoint.new()
	tp.kind = kind
	add_child(tp)
	_nodes.append(tp)
	return tp


func _pending() -> bool:
	if &"enabled" in TacticalPoint.new():
		return false
	skip("pending the LEAD contract: TacticalPoint.enabled (D-149 QC-RT1)")
	return true


func test_disabled_point_leaves_its_group_and_comes_back() -> void:
	if _pending():
		return
	for kind: TacticalPoint.Kind in [TacticalPoint.Kind.COVER, TacticalPoint.Kind.ENTRY, TacticalPoint.Kind.FLANK,
			TacticalPoint.Kind.SNIPER_PERCH, TacticalPoint.Kind.RAPPEL, TacticalPoint.Kind.SHIELD_ANCHOR]:
		var tp: TacticalPoint = _point(kind)
		var group: StringName = TacticalPoint._GROUPS[kind]
		assert_true(tp.is_in_group(group), "kind %d starts in %s" % [kind, group])
		tp.set(&"enabled", false)
		assert_false(tp.is_in_group(group), "kind %d disabled: out of %s" % [kind, group])
		assert_false(get_tree().get_nodes_in_group(group).has(tp), "no group query returns it")
		tp.set(&"enabled", true)
		assert_true(tp.is_in_group(group), "kind %d enabled again: back in %s" % [kind, group])


func test_disabled_at_load_never_joins() -> void:
	if _pending():
		return
	var tp: TacticalPoint = TacticalPoint.new()
	tp.kind = TacticalPoint.Kind.ENTRY
	tp.set(&"enabled", false)
	add_child(tp)
	_nodes.append(tp)
	assert_false(tp.is_in_group(G.ENTRY_POINT), "a point saved disabled (a convoy layout not in play) is not an entry")
