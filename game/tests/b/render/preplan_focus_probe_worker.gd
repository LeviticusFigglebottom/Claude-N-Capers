## Worker for preplan_focus_probe.gd. Prints "FOCUS <state> reached a/b; unreachable: ...; traps: ..." and "FOCUS DONE".
extends Node

const SCENE: String = "res://content/ui/preplanning/preplanning_screen.tscn"
const SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]

var _fx: RefCounted = preload("res://tests/b/staged_heist_fixture.gd").new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var heist: StringName = StringName(args[0]) if args.size() > 0 else &"rolling_thunder"
	_fx.call(&"stage")
	var p: PlayerProfile = PlayerProfile.new_default()
	p.cash = 500000
	var s: PreplanningScreen = (load(SCENE) as PackedScene).instantiate() as PreplanningScreen
	s.save_on_confirm = false
	s.setup(heist, Enums.Difficulty.ROUTINE, p)
	get_tree().root.add_child(s)
	for _i: int in range(10):
		await get_tree().process_frame
	s.show_crew_assets()
	await _probe(s, "crew")
	for f: int in range(maxi(s.floor_buttons.size(), 1)):
		if f < s.floor_buttons.size():
			s._on_floor(f)
		for pid: StringName in s.blueprint_view.marker_ids():
			s.show_point(pid)
			await _probe(s, "floor%d/%s" % [f, pid])
	_fx.call(&"unstage")
	print("FOCUS DONE")
	get_tree().quit(0)


func _name(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return "%s'%s'" % [c.name, (c as Button).text.left(24)]
	return String(c.name)


func _probe(s: PreplanningScreen, state: String) -> void:
	for _i: int in range(4):
		await get_tree().process_frame
	var all: Array[Control] = []
	for n: Node in s.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			all.append(c)
	# Reachability from the crew tab over arrow-key edges.
	var edges: Dictionary = {}
	for c: Control in all:
		var out: Array[Control] = []
		for side: Side in SIDES:
			var nb: Control = c.find_valid_focus_neighbor(side)
			if nb != null and nb != c:
				out.append(nb)
		edges[c] = out
	var seen: Dictionary = {s.crew_button: true}
	var queue: Array[Control] = [s.crew_button]
	while not queue.is_empty():
		var c: Control = queue.pop_front()
		for nb: Control in edges.get(c, []) as Array:
			if not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	var unreachable: PackedStringArray = PackedStringArray()
	for c: Control in all:
		if not seen.has(c):
			unreachable.append(_name(c))
	# Traps: controls from which the crew tab cannot be reached again.
	var traps: PackedStringArray = PackedStringArray()
	for c: Control in all:
		var back: Dictionary = {c: true}
		var q: Array[Control] = [c]
		var ok: bool = c == s.crew_button
		while not q.is_empty() and not ok:
			var x: Control = q.pop_front()
			for nb: Control in edges.get(x, []) as Array:
				if nb == s.crew_button:
					ok = true
					break
				if not back.has(nb):
					back[nb] = true
					q.append(nb)
		if not ok:
			traps.append(_name(c))
	if not traps.is_empty() and OS.get_cmdline_user_args().has("edges"):
		for c: Control in all:
			var e: PackedStringArray = PackedStringArray()
			for side: Side in SIDES:
				var nb: Control = c.find_valid_focus_neighbor(side)
				e.append("%s->%s" % [["L", "U", "R", "D"][side], _name(nb) if nb != null else "-"])
			print("FOCUS edge %s @%s: %s" % [_name(c), c.get_global_rect().position.round(), " ".join(e)])
	print("FOCUS %s reached %d/%d; unreachable: %s; traps (cannot get back to the crew tab): %s" % [state, seen.size(),
			all.size(), ", ".join(unreachable), ", ".join(traps)])
