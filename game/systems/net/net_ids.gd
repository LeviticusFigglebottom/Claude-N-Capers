## Helpers for stable network ids (architecture.md §3). Owner: ENV A.
## Server: `NetIds.claim(node)` allocates an id via `Ids.next()` and registers the node.
## Map-placed prefabs are claimed by HeistRuntime in tree order after variant resolution, so a
## client that loads the same map can reproduce the mapping from the replicated path table (P3).
class_name NetIds
extends RefCounted


## Allocate and register a net_id for `node` (authority only). Sets `node.net_id` if present.
static func claim(node: Node) -> int:
	if not Net.is_authority():
		return Ids.INVALID
	var current: Variant = node.get(&"net_id")
	if current is int and int(current) != Ids.INVALID:
		return int(current)
	var id: int = Ids.next()
	if current != null:
		node.set(&"net_id", id)
	Ids.register(id, node)
	return id


## Register a replicated id on a client (or re-register on the server).
static func adopt(node: Node, id: int) -> void:
	if node.get(&"net_id") != null:
		node.set(&"net_id", id)
	Ids.register(id, node)


static func of(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return Ids.INVALID
	var v: Variant = node.get(&"net_id")
	return int(v) if v is int else Ids.INVALID
