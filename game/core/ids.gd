## Server-assigned stable network ids for gameplay entities. Owner: LEAD.
## Any node that must be referenced across the network registers here on the server
## and replicates its id (e.g. via a synced `net_id` property).
extends Node

const INVALID: int = 0

var _next: int = 1
var _by_id: Dictionary[int, Node] = {}


## Server only: allocate a fresh id.
func next() -> int:
	assert(not multiplayer.has_multiplayer_peer() or multiplayer.is_server(), "Ids.next() is server-only")
	var id: int = _next
	_next += 1
	return id


## Register a node under an id (server after next(); clients when the id replicates).
func register(id: int, node: Node) -> void:
	_by_id[id] = node
	node.tree_exiting.connect(_on_exiting.bind(id, node), CONNECT_ONE_SHOT)


func lookup(id: int) -> Node:
	var n: Node = _by_id.get(id)
	if n != null and is_instance_valid(n):
		return n
	return null


## Called at heist start/teardown.
func reset() -> void:
	_next = 1
	_by_id.clear()


func _on_exiting(id: int, node: Node) -> void:
	if _by_id.get(id) == node:
		_by_id.erase(id)
