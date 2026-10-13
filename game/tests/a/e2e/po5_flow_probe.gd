## PO-5 diagnostic: wall-clock cost of game time before / after masking (render loop off, HUD hidden).
extends RefCounted

var f: Node = null


func play(flow: Node) -> int:
	f = flow
	var p: Po5Pilot = flow.get(&"pilot") as Po5Pilot
	await _cost("unmasked", 3.0)
	await p.inp.hold(&"mask_up", 1.4)
	await _cost("masked", 3.0)
	await _cost("masked", 3.0)
	return 0


func _cost(label: String, secs: float) -> void:
	var w: int = Time.get_ticks_msec()
	await f.wait_s(secs)
	f.note("PROBE %s: %.1f game s took %.1f wall s" % [label, secs, (Time.get_ticks_msec() - w) / 1000.0])
