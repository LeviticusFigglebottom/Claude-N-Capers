## Shared helpers for ENV B tests.
class_name BTestUtil
extends RefCounted


## Per-process SaveService root for tests. user:// is shared by every checkout of the project
## (same project name), so parallel test runs must not share one profile folder.
static func profile_root() -> String:
	return "user://test_profiles_%d" % OS.get_process_id()


## Per-process GameSettings root (B5-01): settings tests never touch the real user://settings.cfg.
static func settings_root() -> String:
	return "user://test_settings_%d" % OS.get_process_id()


## Per-process ENet port for loopback tests (`offset` keeps the test files apart).
static func port(offset: int) -> int:
	return 20000 + (OS.get_process_id() + offset) % 20000


## A child of `parent` with its own SceneMultiplayer and a core/net.gd instance named "Net" (net.md: host +
## client in one process). Returns the Net node; free with free_net_branches().
static func net_branch(parent: Node, branch_name: String) -> Node:
	var root: Node = Node.new()
	root.name = branch_name
	parent.add_child(root)
	parent.get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	var n: Node = (load("res://core/net.gd") as Script).new() as Node
	n.name = "Net"
	root.add_child(n)
	return n


## Leave every branch's Net session, detach its multiplayer and free it.
static func free_net_branches(parent: Node) -> void:
	for b: Node in parent.get_children():
		var n: Node = b.get_node_or_null(^"Net")
		if n == null:
			continue
		n.call(&"leave")
		parent.get_tree().set_multiplayer(null, b.get_path())
		b.queue_free()
