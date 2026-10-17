## PO-5 probe (Gallery Night): the loud pilot walks back and forth through the BronzeDoorsE doorway along the line of
## its east leaf (x = 22.3, P's GN loud rerun: STUCK x4 on LeafBody2 at (22.3, 30.0), then 1200 s on that leg).
## Lanes: the east leaf's line and three more across the doorway; before every other crossing the pilot shuts the door
## (input only), so the walk opens it again from alternating sides (the DOUBLE leaves swing away from the opener). Every
## crossing must arrive without the goto giving up.
## run: game/tests/a/e2e/run_po5.sh gn_leaf <seed> 1500 <out> "Gallery Night"
extends RefCounted

const CROSSINGS: int = 8
const LANES_X: Array[float] = [22.3, 22.3, 22.0, 22.0, 21.0, 21.0, 20.8, 20.8]
const SOUTH_Z: float = 32.5
const NORTH_Z: float = 27.5

var f: Node = null
var p: Po5Pilot = null
var rt: HeistRuntime = null


func play(flow: Node) -> int:
	f = flow
	p = flow.get(&"pilot") as Po5Pilot
	rt = flow.get(&"rt") as HeistRuntime
	await p.inp.hold(&"mask_up", Tweak.crew().mask_up_time_s + 0.4)
	p.combat = true
	p.stuck_give_up = 6
	var door: Door = rt.find_child("BronzeDoorsE", true, false) as Door
	if door == null:
		f.note("FAIL no BronzeDoorsE in the map")
		return 1
	f.note("leaf probe: BronzeDoorsE at %s open=%s locked=%s" % [Po5Pilot._v(door.global_position), door.is_open, door.locked])
	var ok: int = 0
	for i: int in CROSSINGS:
		var z: float = NORTH_Z if i % 2 == 0 else SOUTH_Z
		if i % 2 == 1 and door.is_open:
			await _shut(door)
		var to: Vector3 = p.stand_point(Vector3(LANES_X[i], 0.0, z))
		var t0: float = rt.heist_time_s
		var reached: bool = await p.goto(to, 0.6, 60.0)
		if not reached and p.crew.crew_state != Enums.CrewState.NORMAL:
			f.note("leaf probe: crossing %d: crew down (state %d), waiting" % [i, p.crew.crew_state])
			await f.wait_s(5.0)
		f.note("leaf probe: crossing %d to %s %s in %.1f s (door open=%s, stuck rows %d)" % [i, Po5Pilot._v(to),
			"OK" if reached else "FAILED", rt.heist_time_s - t0, door.is_open, p.stuck_spots.size()])
		ok += 1 if reached else 0
	if ok < CROSSINGS - 1:
		f.note("FAIL leaf probe: %d / %d crossings" % [ok, CROSSINGS])
		return 1
	f.note("RESULT leaf probe PASS: %d / %d crossings" % [ok, CROSSINGS])
	return 0


## Close the open door from where the pilot stands (hold F on its handle, like a player).
func _shut(door: Door) -> void:
	var comp: InteractableComponent = door.get_node_or_null(^"Interactable") as InteractableComponent
	if comp == null or not comp.enabled:
		return
	var n: Vector3 = door.global_transform.basis.z
	n.y = 0.0
	n = n.normalized()
	if n.dot(p.crew.global_position - door.global_position) < 0.0:
		n = -n
	await p.goto(p.stand_point(comp.global_position + n * 1.2), 0.3, 10.0, false, false)
	await p.use(comp, 5.0, func() -> bool: return not door.is_open, false)
	await p.inp.ticks(30)
	f.note("leaf probe: shut BronzeDoorsE -> open=%s" % door.is_open)
