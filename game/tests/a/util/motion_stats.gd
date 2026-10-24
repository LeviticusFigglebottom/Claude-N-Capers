## P6 rubber-banding metric (test only, never shipped): on a client, every rendered frame, the replicated NPCs' on-screen
## motion. A pop is a frame jump > POP_M that is not a teleport (> SNAP_M); a jerk is a frame-to-frame velocity change
## faster than JERK_MPS2 (no NPC accelerates like that: it is a correction / a late packet). Rates per NPC-minute of
## motion, so runs of different length and crowd size compare. Added to the tree by LoopbackProbe ("motion_start").
class_name MotionStats
extends Node

const POP_M: float = 0.25
const SNAP_M: float = 3.0
const JERK_MPS2: float = 40.0
## A frame with less flat motion than this is "still" (not counted as moving time).
const STILL_M: float = 0.002

var frames: int = 0
var moving_s: float = 0.0
var pops: int = 0
var jerks: int = 0
var max_jump_m: float = 0.0

var _last: Dictionary[int, Vector3] = {}
var _vel: Dictionary[int, Vector3] = {}


func _process(delta: float) -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt == null or delta <= 0.0:
		return
	frames += 1
	var seen: Dictionary[int, bool] = {}
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive:
			continue
		var id: int = npc.net_id
		seen[id] = true
		var p: Vector3 = npc.global_position
		if not _last.has(id):
			_last[id] = p
			continue
		var step: Vector3 = p - _last[id]
		step.y = 0.0
		_last[id] = p
		var d: float = step.length()
		if d > SNAP_M:
			_vel.erase(id)  # a teleport / warp, not a rubber band
			continue
		if d > STILL_M:
			moving_s += delta
		if d > POP_M:
			pops += 1
		max_jump_m = maxf(max_jump_m, d if d <= SNAP_M else 0.0)
		var v: Vector3 = step / delta
		if _vel.has(id) and (v - _vel[id]).length() / delta > JERK_MPS2 and (d > STILL_M or _vel[id].length() * delta > STILL_M):
			jerks += 1
		_vel[id] = v
	for id: int in _last.keys():
		if not seen.has(id):
			_last.erase(id)
			_vel.erase(id)


func report() -> Dictionary:
	var npc_min: float = maxf(moving_s / 60.0, 0.0001)
	return {"frames": frames, "moving_npc_s": moving_s, "pops": pops, "jerks": jerks, "max_jump_m": max_jump_m,
		"pops_per_npc_min": float(pops) / npc_min, "jerks_per_npc_min": float(jerks) / npc_min}
