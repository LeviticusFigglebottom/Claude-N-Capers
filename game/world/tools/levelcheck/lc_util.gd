## Small node helpers shared by levelcheck modules. Owner: ENV C.
class_name LcUtil
extends RefCounted


static func meta_s(n: Node, key: StringName) -> StringName:
	if n != null and n.has_meta(key):
		return StringName(str(n.get_meta(key)))
	return &""


static func meta_b(n: Node, key: StringName) -> bool:
	return n != null and n.has_meta(key) and bool(n.get_meta(key))


static func slot_of(n: Node) -> VariantSlot:
	var cur: Node = n
	while cur != null:
		if cur is VariantSlot:
			return cur as VariantSlot
		cur = cur.get_parent()
	return null
