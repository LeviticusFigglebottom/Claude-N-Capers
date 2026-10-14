## Small node helpers shared by levelcheck modules. Owner: ENV C.
class_name LcUtil
extends RefCounted


static func meta_s(n: Node, key: StringName) -> StringName:
	if n != null and n.has_meta(key):
		return StringName(str(n.get_meta(key)))
	return &""


static func meta_b(n: Node, key: StringName) -> bool:
	return n != null and n.has_meta(key) and bool(n.get_meta(key))


## Lead D-113 ruling: a node with meta `lc_ignore = true` (cable / FX-only meshes, e.g. a zipline's drawn Cable) and its
## whole subtree are invisible to levelcheck's geometry, prop and fixture scans. Never put it on collision.
static func lc_ignored(n: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if meta_b(cur, &"lc_ignore"):
			return true
		cur = cur.get_parent()
	return false


static func slot_of(n: Node) -> VariantSlot:
	var cur: Node = n
	while cur != null:
		if cur is VariantSlot:
			return cur as VariantSlot
		cur = cur.get_parent()
	return null
