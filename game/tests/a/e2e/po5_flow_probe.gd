## PO-5 diagnostic: what starts processing when the player masks up, and the wall-clock cost of game time.
extends RefCounted

var f: Node = null


func _snap(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for n: Node in root.find_children("*", "", true, false):
		if n.is_processing() or n.is_physics_processing():
			var s: Script = n.get_script() as Script
			var key: String = "%s %s" % [n.get_class(), s.resource_path.get_file() if s != null else "-"]
			out[key] = int(out.get(key, 0)) + 1
	return out


func _cost(label: String, secs: float) -> void:
	var w: int = Time.get_ticks_msec()
	await f.wait_s(secs)
	f.note("PROBE %s: %.1f game s took %.1f wall s" % [label, secs, (Time.get_ticks_msec() - w) / 1000.0])


func play(flow: Node) -> int:
	f = flow
	var p: Po5Pilot = flow.get(&"pilot") as Po5Pilot
	await _cost("unmasked", 3.0)
	var a: Dictionary = _snap(f.get_tree().root)
	await p.inp.hold(&"mask_up", 1.4)
	var b: Dictionary = _snap(f.get_tree().root)
	for k: String in b:
		if int(b[k]) != int(a.get(k, 0)):
			f.note("PROBE new processing: %s %d -> %d" % [k, int(a.get(k, 0)), int(b[k])])
	await _frames("masked")
	# Diagnostic bisection (writes state on purpose): stop _process per script under Crew0.
	var rt: Node = flow.get(&"rt") as Node
	var groups: Dictionary = {}
	var hud_nodes: Array[Node] = []
	for l: Node in f.get_tree().root.get_children():
		if l is CanvasLayer:
			hud_nodes.append_array(l.find_children("*", "", true, false))
	for c: Node in hud_nodes:
		if c.is_processing():
			var sc: Script = c.get_script() as Script
			var k: String = "%s %s" % [c.get_class(), sc.resource_path.get_file() if sc != null else "-"]
			if not groups.has(k):
				groups[k] = []
			(groups[k] as Array).append(c)
	f.note("PROBE hud processing groups: %s" % [groups.keys()])
	for k2: String in groups:
		for c2: Node in groups[k2]:
			c2.set_process(false)
		await _frames("hud off: " + k2)
	return 0


func _frames(label: String) -> void:
	var w: int = Time.get_ticks_usec()
	var worst: float = 0.0
	for i: int in 3:
		var t: int = Time.get_ticks_usec()
		await f.get_tree().process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1e6)
	f.note("PROBE %s: 3 frames %.2f wall s, worst %.2f" % [label, (Time.get_ticks_usec() - w) / 1e6, worst])


func _ticks(label: String) -> void:
	var w: int = Time.get_ticks_usec()
	for i: int in 3:
		await f.get_tree().physics_frame
	f.note("PROBE %s: 3 ticks %.2f wall s phys=%.1fms proc=%.1fms" % [label, (Time.get_ticks_usec() - w) / 1e6,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
