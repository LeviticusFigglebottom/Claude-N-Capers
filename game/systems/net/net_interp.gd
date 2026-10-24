## Client snapshot interpolation of replicated transforms (P6 co-op hardening, LEAD r313). Owner: ENV A.
## HeistNetSync sends transforms at SYNC_HZ stamped with the server's send tick (far calm civilians every
## CIV_SLOW_DIV-th tick, D-168); applied as they arrive, remote crowds, police, loose bags and teammates stepped at that
## rate and jumped on every lost or late packet. A client keeps a short buffer per entity and renders it DELAY_S behind
## the newest server time it has heard of, lerping between the two samples around that time (no extrapolation: past the
## newest sample it holds it). Render-only: clients do not simulate these bodies (the server owns them); the server
## widens its hit-claim check by the same delay (NetRewind).
## Not interpolated (applied at once through NetEntityCodec.apply_xform): the local crew member (client-predicted),
## corpses (their anchor owns the root), ragdolls, carried bags, and a jump of more than SNAP_M (a teleport / warp).
class_name NetInterp
extends Node

const NODE_NAME: String = "NetInterp"
## Render this far behind the newest server time (s): 1.5 send intervals, so one lost packet is bridged.
const DELAY_S: float = 0.1
## Samples kept per entity (at SYNC_HZ: over half a second).
const MAX_SAMPLES: int = 8
## A move longer than this between two samples is a teleport: snap, do not slide (m).
const SNAP_M: float = 3.0
## Past the newest sample (a lost / late packet) keep going along the last velocity this long at most (s), then hold:
## the lossy soak (120 ms / 5 %) showed hold-then-jump pops when a packet went missing.
const EXTRAP_MAX_S: float = 0.15
## Playout clock smoothing: ease toward the target over this time constant (s); snap when further off than CLOCK_SNAP_S.
const CLOCK_EASE_S: float = 0.5
const CLOCK_SNAP_S: float = 0.25

## Test switch (P6 before / after measurement): false = HeistNetSync applies transforms as they arrive.
static var enabled: bool = true

## Diagnostics for tests: samples received and transforms applied by interpolation.
var samples_in: int = 0
var applied: int = 0

## net_id -> Array of [server_time_s: float, xform: Variant] (oldest first).
var _buf: Dictionary[int, Array] = {}
var _sync_hz: float = 15.0
## Newest server time heard of, and the local clock (s) when it arrived.
var _server_t: float = -1.0
var _heard_at: float = 0.0
## The playout clock (server time being rendered): advances with the frame and eases toward render_target(), so packet
## arrival jitter does not make render time jump a few ms on every packet (the first soak: ~700 jerks / NPC-min).
var _render_t: float = -1.0


func setup(sync_hz: float) -> void:
	_sync_hz = sync_hz


## Client: a transform batch stamped with the server's send tick. Entities that are not interpolated apply at once.
func push(xforms: Dictionary, tick: int) -> void:
	var t: float = float(tick) / _sync_hz
	if t > _server_t:
		_server_t = t
		_heard_at = _now()
	for k: Variant in xforms:
		var id: int = int(k)
		var n: Node = Ids.lookup(id)
		if n == null:
			continue
		var x: Variant = xforms[k]
		if not interpolates(n, x):
			_buf.erase(id)
			NetEntityCodec.apply_xform(n, x)
			continue
		var b: Array = _buf.get(id, [])
		if not b.is_empty() and float((b[b.size() - 1] as Array)[0]) >= t:
			continue  # an older chunk that arrived late
		if not b.is_empty() and _pos(x).distance_to(_pos((b[b.size() - 1] as Array)[1])) > SNAP_M:
			b.clear()
			NetEntityCodec.apply_xform(n, x)
		b.append([t, x])
		while b.size() > MAX_SAMPLES:
			b.pop_front()
		_buf[id] = b
		samples_in += 1


## Whether `n` (transform `x`) is rendered from the buffer: a live NPC, a loose bag or a remote crew member.
static func interpolates(n: Node, x: Variant) -> bool:
	var crew: CrewController = n as CrewController
	if crew != null:
		return not crew.is_local() and x is Array
	if NpcRagdoll.owns_pose(n):
		return false
	var npc: NpcBase = n as NpcBase
	if npc != null:
		return npc.alive and x is Transform3D
	var bag: LootBag = n as LootBag
	if bag != null:
		return not bag.is_carried() and x is Transform3D
	return false


## Where the playout clock should be (s): DELAY_S behind the newest server time heard of, advanced by the local time
## since it arrived (at most one send interval), or -1 before the first sample.
func render_target() -> float:
	if _server_t < 0.0:
		return -1.0
	return _server_t + minf(_now() - _heard_at, 1.0 / _sync_hz) - DELAY_S


## Server time being rendered now (s), or -1 before the first sample.
func render_time() -> float:
	return _render_t


## Advance the playout clock by `delta` and ease it toward render_target() (time constant CLOCK_EASE_S; snap when more
## than CLOCK_SNAP_S off: a hitch or a long gap).
func advance_clock(delta: float) -> void:
	var target: float = render_target()
	if target < 0.0:
		return
	if _render_t < 0.0 or absf(target - _render_t) > CLOCK_SNAP_S:
		_render_t = target
		return
	_render_t += delta
	_render_t += (target - _render_t) * minf(delta / CLOCK_EASE_S, 1.0)


func _process(delta: float) -> void:
	advance_clock(delta)
	var rt: float = render_time()
	if rt < 0.0 or _buf.is_empty():
		return
	var gone: Array[int] = []
	for id: int in _buf:
		var n: Node = Ids.lookup(id)
		var b: Array = _buf[id]
		if n == null or not is_instance_valid(n) or b.is_empty():
			gone.append(id)
			continue
		var x: Variant = sample_at(b, rt)
		if not interpolates(n, x):
			gone.append(id)  # died / picked up since: the next batch applies it directly
			continue
		NetEntityCodec.apply_xform(n, x)
		applied += 1
	for id: int in gone:
		_buf.erase(id)


## The transform at server time `t` from samples `b` ([[time, xform], ...], oldest first): the oldest before the
## first sample, a lerp of the two around it, past the newest: extrapolated along the last segment for at most
## EXTRAP_MAX_S, then held.
static func sample_at(b: Array, t: float) -> Variant:
	if t <= float((b[0] as Array)[0]):
		return (b[0] as Array)[1]
	for i: int in range(1, b.size()):
		var s1: Array = b[i]
		if t <= float(s1[0]):
			var s0: Array = b[i - 1]
			var span: float = maxf(float(s1[0]) - float(s0[0]), 0.0001)
			return lerp_xform(s0[1], s1[1], (t - float(s0[0])) / span)
	var last: Array = b[b.size() - 1]
	if b.size() < 2:
		return last[1]
	var prev: Array = b[b.size() - 2]
	var span: float = maxf(float(last[0]) - float(prev[0]), 0.0001)
	var over: float = minf(t - float(last[0]), EXTRAP_MAX_S)
	return _extrapolate(prev[1], last[1], over / span)


## `b` moved on past itself by `k` segment lengths of a -> b (position only; rotation / look held).
static func _extrapolate(a: Variant, b: Variant, k: float) -> Variant:
	if a is Transform3D and b is Transform3D:
		var tb: Transform3D = b
		return Transform3D(tb.basis, tb.origin + (tb.origin - (a as Transform3D).origin) * k)
	if a is Array and b is Array:
		var bb: Array = (b as Array).duplicate()
		bb[0] = (bb[0] as Vector3) + ((bb[0] as Vector3) - ((a as Array)[0] as Vector3)) * k
		return bb
	return b


## Lerp two transforms of the same kind: Transform3D (position + rotation slerp) or the crew array
## [position, yaw, pitch, crouched] (angles the short way round; crouched from the newer one).
static func lerp_xform(a: Variant, b: Variant, w: float) -> Variant:
	if a is Transform3D and b is Transform3D:
		return (a as Transform3D).interpolate_with(b as Transform3D, w)
	if a is Array and b is Array:
		var aa: Array = a
		var bb: Array = b
		return [(aa[0] as Vector3).lerp(bb[0] as Vector3, w), lerp_angle(float(aa[1]), float(bb[1]), w),
			lerpf(float(aa[2]), float(bb[2]), w), bb[3]]
	return b


static func _pos(x: Variant) -> Vector3:
	if x is Transform3D:
		return (x as Transform3D).origin
	if x is Array and not (x as Array).is_empty():
		return (x as Array)[0] as Vector3
	return Vector3.ZERO


static func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
