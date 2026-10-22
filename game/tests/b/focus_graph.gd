## Arrow-key focus graph of a UI subtree (RT walk follow-up, r279 (a)): the visible FOCUS_ALL controls and the edges
## Control.find_valid_focus_neighbor gives for the four arrows (what the engine does on ui_left/up/right/down).
## problems() lists every control that cannot reach `home` (a trap: focus goes in and never gets back) and every
## control `home` cannot reach (unreachable by keys). Not a test file (no test_ prefix).
extends RefCounted

const SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]


## The visible, focusable controls under `root`.
static func focusables(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			out.append(c)
	return out


## ["trap: <path>" / "unreachable: <path>"] for `root`, measured from `home` (null = the first focusable).
static func problems(root: Node, home: Control = null) -> PackedStringArray:
	var all: Array[Control] = focusables(root)
	var out: PackedStringArray = PackedStringArray()
	if all.size() < 2:
		return out
	if home == null or not all.has(home):
		home = all[0]
	var edges: Dictionary = {}
	var back_edges: Dictionary = {}
	for c: Control in all:
		edges[c] = []
	for c: Control in all:
		for side: Side in SIDES:
			var nb: Control = c.find_valid_focus_neighbor(side)
			if nb == null or nb == c or not edges.has(nb):
				continue
			(edges[c] as Array).append(nb)
			if not back_edges.has(nb):
				back_edges[nb] = []
			(back_edges[nb] as Array).append(c)
	var fwd: Dictionary = _reach(home, edges)
	var rev: Dictionary = _reach(home, back_edges)
	for c: Control in all:
		if not rev.has(c):
			out.append("trap: %s" % _label(root, c))
		if not fwd.has(c):
			out.append("unreachable: %s" % _label(root, c))
	return out


static func _reach(from: Control, edges: Dictionary) -> Dictionary:
	var seen: Dictionary = {from: true}
	var queue: Array[Control] = [from]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for nb: Variant in edges.get(c, []) as Array:
			if not seen.has(nb):
				seen[nb] = true
				queue.append(nb as Control)
	return seen


static func _label(root: Node, c: Control) -> String:
	var t: String = (c as Button).text.left(20) if c is Button else ""
	return "%s%s" % [root.get_path_to(c), " '%s'" % t if t != "" else ""]
