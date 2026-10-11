## Pauses the LOCAL crew member's gameplay input while a UI layer needs the keyboard (B5-01 options overlay,
## B6-03 chat, B6-04 drop-in dialog). Owner: ENV B. Static.
## Each overlay holds the pause under its own `holder` id; the crew member stays paused while any holder
## remains, so closing the chat never unpauses input under an open options screen. The crew member is the
## G.CREW node whose `slot` is the local slot and that has CrewController.set_input_paused (QB-46).
class_name CrewInput
extends RefCounted

## holder -> local slot it paused.
static var _holders: Dictionary = {}


## Hold (`paused` true) or release the pause for `holder`, then tell the local crew member.
static func set_paused(tree: SceneTree, holder: StringName, paused: bool, local_slot: int) -> void:
	if paused:
		_holders[holder] = local_slot
	else:
		_holders.erase(holder)
	if tree == null:
		return
	var any: bool = is_paused()
	for n: Node in tree.get_nodes_in_group(G.CREW):
		var slot: Variant = n.get(&"slot")
		if slot is int and int(slot) == local_slot and n.has_method(&"set_input_paused"):
			n.call(&"set_input_paused", any)


static func is_paused() -> bool:
	return not _holders.is_empty()


static func is_held(holder: StringName) -> bool:
	return _holders.has(holder)


## Tests: forget every holder (does not touch crew nodes).
static func clear() -> void:
	_holders.clear()
