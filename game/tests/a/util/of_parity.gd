## Co-op parity check for the loopback tests (test_of_coop_loopback, test_a4_03_soak): a client's replica is the
## HOST'S PAST (one-way latency, the client's own frame, interpolation), and under box load the snapshot round trip
## takes seconds, so comparing it with the host's state at the reply races every moving NPC and every door a unit walks
## through. This node samples LoopbackProbe.of_state on the host at SAMPLE_HZ (last HISTORY_S) and `diff` matches each
## entity / value of a client snapshot against every host sample from request - LAG_MS to now: a value differs only
## when it matches NONE of them. A real desync (a value the host never had in the window) still fails.
class_name OfParity
extends Node

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const SAMPLE_HZ: float = 10.0
const HISTORY_S: float = 12.0
## How far behind the host a client replica may be at the request (ms): replication at SYNC_HZ, interpolation, a
## loaded client's frame.
const LAG_MS: int = 2000

var rt: HeistRuntime = null
## [[ticks_msec, of_state], ...] oldest first
var history: Array = []
var _left: float = 0.0


static func attach(runtime: HeistRuntime, parent: Node) -> OfParity:
	var p: OfParity = OfParity.new()
	p.name = "OfParity"
	p.rt = runtime
	parent.add_child(p)
	p.sample()
	return p


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = 1.0 / SAMPLE_HZ
		sample()


func sample() -> void:
	if rt == null or not is_instance_valid(rt) or rt.map == null:
		return
	var now: int = Time.get_ticks_msec()
	history.append([now, PROBE.of_state(rt)])
	while not history.is_empty() and now - int(history[0][0]) > int(HISTORY_S * 1000.0):
		history.pop_front()


## Diff lines of client snapshot `c` (requested at `since_ms`) against the host's samples since since_ms - LAG_MS
## (and its state now). tol: {"npcs": m, "bags": m, "lifts": m}. A key is reported when no sample matches it.
func diff(c: Dictionary, since_ms: int, tol: Dictionary) -> Array[String]:
	if c.is_empty():
		return ["no client snapshot"]
	sample()
	var common: Dictionary = {}
	var first: bool = true
	for s: Array in history:
		if int(s[0]) < since_ms - LAG_MS:
			continue
		var d: Dictionary = diff_one(s[1] as Dictionary, c, tol)
		if first:
			common = d
			first = false
		else:
			for k: Variant in common.keys():
				if not d.has(k):
					common.erase(k)
		if common.is_empty():
			break
	var out: Array[String] = []
	for k: Variant in common:
		out.append(str(common[k]))
	return out


## One host state vs the client: key (kind + id) -> message for every value that differs.
func diff_one(h: Dictionary, c: Dictionary, tol: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["phase", "went_loud", "objectives", "reveals", "items"]:
		if h.has(k) and str(h[k]) != str(c.get(k)):
			out[k] = "%s host %s client %s" % [k, h[k], c.get(k)]
	for k: String in ["prefabs", "doors"]:
		var hd: Dictionary = h[k]
		var cd: Dictionary = c.get(k, {})
		for id: Variant in hd:
			if str(hd[id]) != str(cd.get(id)):
				out["%s %s" % [k, id]] = "%s %s (%s) host %s client %s" % [k, id, _name(int(id)), hd[id], cd.get(id)]
	_pos_diff(out, "lifts", h["lifts"], c.get("lifts", {}), float(tol.get("lifts", 1.5)), false)
	_pos_diff(out, "bags", h["bags"], c.get("bags", {}), float(tol.get("bags", 1.0)), true)
	_pos_diff(out, "npcs", h["npcs"], c.get("npcs", {}), float(tol.get("npcs", 2.5)), false)
	return out


func _pos_diff(out: Dictionary, k: String, hd: Dictionary, cd: Dictionary, tol: float, with_id: bool) -> void:
	for id: Variant in hd:
		var key: String = "%s %s" % [k, id]
		if not cd.has(id):
			out[key] = "%s %s (%s) missing on the client" % [k, id, _name(int(id))]
			continue
		var hp: Vector3 = (hd[id][1] if with_id else hd[id]) as Vector3
		var cp: Vector3 = (cd[id][1] if with_id else cd[id]) as Vector3
		if with_id and StringName(hd[id][0]) != StringName(cd[id][0]):
			out[key + " loot"] = "%s %s loot host %s client %s" % [k, id, hd[id][0], cd[id][0]]
		if hp.distance_to(cp) > tol:
			out[key] = "%s %s (%s) host %s client %s (%.1f m)" % [k, id, _name(int(id)), hp, cp, hp.distance_to(cp)]
	for id: Variant in cd:
		if not hd.has(id):
			out["%s %s" % [k, id]] = "%s %s (%s) only on the client" % [k, id, _name(int(id))]


func _name(id: int) -> String:
	var n: Node = Ids.lookup(id)
	if n == null:
		return "?"
	return String(rt.map.get_path_to(n)) if rt != null and rt.map != null and rt.map.is_ancestor_of(n) else String(n.name)
