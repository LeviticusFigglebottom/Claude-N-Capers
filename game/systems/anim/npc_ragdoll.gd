## PO6-19 (D-114 §7): ragdoll / body propulsion of an NPC corpse. Owner: ENV A.
## Child `NpcRagdoll` of an NpcBase whose character visual has ENV D's `Skeleton3D/Ragdoll`
## (PhysicalBoneSimulator3D, recipe: world/characters/_tools/RAGDOLL.md). Capsule placeholders get none and
## keep the animation-only death. Tunables: RagdollTweak (ragdoll_tweak.tres).
## Server (authoritative):
## * every hit on the NPC is noted (NpcBase.take_hit); at death, the hits of the killing physics frame (all
##   pellets of a shotgun shot) decide: an explosion kill, or a summed impulse >= min_impulse (point-blank
##   shotgun), starts the ragdoll from the current pose (AnimationPlayer paused) and pushes the hit bodies
##   (blasts: every body outward from the centre with falloff). Otherwise the (PO6-18 pose-aware) death clip
##   plays and, when it ends, a short settle ragdoll lays the body on the floor (settle_after_anim).
## * after settle_s (or once every body is slower than settle_speed_mps) the bodies are baked into the skeleton
##   pose and the simulation stops (frozen corpse: no physics cost, a fixed pose).
## * D-121: the ragdoll is cosmetic. It never moves the NPC root or the corpse hitbox: those sit on the
##   deterministic CorpseAnchor from the death frame on (bagging, corpse stimulus, despawn LOS, bullets stopped by
##   the corpse), so a same-seed run replays whatever the physics world did before. Only the visual, the blood
##   pool where the hips come to rest and the nudges are physics-driven.
## * a bullet / melee / blast on a corpse restarts the ragdoll from the baked pose with a small nudge and
##   re-freezes it after nudge_settle_s (NpcBase emits blood_hit at the hit point).
## * at most max_active ragdolls simulate per peer: starting one more freezes the oldest first.
## Net (NetEntityCodec NPC state, reliable diffs, late joiners get the full state):
##   "rs" = [seq, settle_s, entries]  start / push fact: entries [[body index, impulse, offset], ...];
##   "rp" = [seq, root origin (the anchor), visual offset, Array[Transform3D] baked bone transforms (skeleton
##          space, one per body)]  the server's frozen pose, sent once per freeze.
## Clients run the same start + impulses cosmetically and snap to "rp" (they never re-anchor on their own).
class_name NpcRagdoll
extends Node

enum Phase { IDLE, PENDING_DEATH, ANIM, STARTING, ACTIVE, FROZEN }

const NODE_NAME: String = "NpcRagdoll"
const SIM_PATH: NodePath = ^"Skeleton3D/Ragdoll"
const HEAD_BODY: StringName = &"Head"
const HIPS_BODY: StringName = &"Hips"

## Simulating ragdolls on this peer, oldest first (the cap).
static var _active: Array[NpcRagdoll] = []

var npc: NpcBase = null
var sim: PhysicalBoneSimulator3D = null
var skel: Skeleton3D = null
var player: AnimationPlayer = null
## The ragdoll's physical bones in scene order (the net index).
var bodies: Array[PhysicalBone3D] = []
var phase: Phase = Phase.IDLE
## True once the ragdoll owns the pose (AnimDriver stops driving this body).
var engaged: bool = false
## Server: start counter; client: last applied start / pose.
var seq: int = 0
var applied_rp: int = 0
var freezes: int = 0

var _t: float = 0.0
var _settle_s: float = 0.0
## Server: hit records of the killing frame / of a start waiting for its first physics frame.
var _hits: Array[Dictionary] = []
## PO6-18: the killing hits kept for a held-pose topple.
var _death_hits: Array[Dictionary] = []
var _hits_frame: int = -1
var _death_frame: int = -1
## Entries to apply on the next physics frame (after the bodies went rigid).
var _entries: Array = []
var _rs: Array = []
var _rp: Array = []
var _applied_rs: int = 0


## The ragdoll runtime of `body` (null when it has none).
static func of(body: Node) -> NpcRagdoll:
	return body.get_node_or_null(NODE_NAME) as NpcRagdoll if body != null else null


## Add the runtime to `body` when its visual has a ragdoll (else none; returns it or null).
static func ensure(body: NpcBase) -> NpcRagdoll:
	var r: NpcRagdoll = of(body)
	if r != null:
		return r
	var ap: AnimationPlayer = AnimDriver.find_player(body)
	var root: Node = ap.get_parent() if ap != null else null
	var s: PhysicalBoneSimulator3D = root.get_node_or_null(SIM_PATH) as PhysicalBoneSimulator3D if root != null else null
	if s == null:
		return null
	r = NpcRagdoll.new()
	r.name = NODE_NAME
	r.npc = body
	r.sim = s
	r.skel = s.get_parent() as Skeleton3D
	r.player = ap
	for c: Node in s.get_children():
		if c is PhysicalBone3D:
			r.bodies.append(c as PhysicalBone3D)
	body.add_child(r)
	return r


## True when the ragdoll owns `body`'s pose (AnimDriver must not touch the AnimationPlayer or the rig).
static func owns_pose(body: Node) -> bool:
	var r: NpcRagdoll = of(body)
	return r != null and r.engaged


## Simulating ragdolls on this peer.
static func active_count() -> int:
	_prune()
	return _active.size()


func _exit_tree() -> void:
	_active.erase(self)


# --- Server hooks (NpcBase / Explosion) ---------------------------------------------------------

## Server: a hit on the living NPC (take_hit, before die()).
func note_hit(info: Dictionary) -> void:
	var rec: Dictionary = hit_record(npc, info, RagdollTweak.data())
	if rec.is_empty():
		return
	var f: int = Engine.get_physics_frames()
	if f != _hits_frame and phase != Phase.PENDING_DEATH:
		_hits.clear()
	_hits_frame = f
	_hits.append(rec)


## Server: the NPC died; the ragdoll / animation decision waits one physics frame for the rest of the shot.
func on_died() -> void:
	if not Net.is_authority() or phase != Phase.IDLE:
		return
	if _hits_frame != Engine.get_physics_frames():
		_hits.clear()
	phase = Phase.PENDING_DEATH
	_death_frame = Engine.get_physics_frames()


## Server: a hit on the corpse (`blast` = an explosion push already scaled). Nudges it (or joins the death push).
func corpse_hit(info: Dictionary) -> void:
	if not Net.is_authority():
		return
	var tw: RagdollTweak = RagdollTweak.data()
	var rec: Dictionary = hit_record(npc, info, tw)
	if rec.is_empty():
		return
	match phase:
		Phase.PENDING_DEATH:
			_hits.append(rec)
			return
		Phase.STARTING:
			_hits.append(_as_nudge(rec, tw))
			return
		Phase.ACTIVE:
			var entries: Array = _entries_for([_as_nudge(rec, tw)], tw)
			_apply(entries)
			_settle_s = maxf(_settle_s, _t + tw.nudge_settle_s)
			_publish_start(entries)
		_:
			_start([_as_nudge(rec, tw)], tw.nudge_settle_s)


## Server: stop simulating for good (bagged / removed): no bake, no more pushes.
func release() -> void:
	if phase == Phase.ACTIVE or phase == Phase.STARTING:
		sim.physical_bones_stop_simulation()
		sim.active = false
	_active.erase(self)
	phase = Phase.FROZEN
	_hits.clear()
	_entries.clear()


## Impulse record of a hit `info` (Damage.info) on `body` ({} = no push): point hits {blast: false, impulse,
## point, head, mag}; explosions {blast: true, center, falloff, mag} (needs info.blast_center / blast_radius).
static func hit_record(body: Node3D, info: Dictionary, tw: RagdollTweak) -> Dictionary:
	var t: int = int(info.get("type", Enums.DamageType.BULLET))
	var point: Vector3 = info.get("position", Vector3.ZERO)
	if t == Enums.DamageType.EXPLOSION:
		var dir_b: Vector3 = info.get("direction", Vector3.ZERO)
		var c: Vector3 = info.get("blast_center", point - dir_b)
		var r: float = float(info.get("blast_radius", 0.0))
		var f: float = 1.0
		if r > 0.0 and body != null:
			var d: float = CombatSystem.target_center(body).distance_to(c)
			f = maxf(pow(clampf(1.0 - d / r, 0.0, 1.0), tw.explosion_falloff_pow), tw.explosion_min_falloff)
		f *= float(info.get("blast_mult", 1.0))
		return {"blast": true, "center": c, "falloff": f, "mag": tw.explosion_speed_mps * f * 80.0}
	var mag: float = 0.0
	if t == Enums.DamageType.BULLET:
		var cls: StringName = ShotFx.npc_weapon_class(StringName(info.get("weapon_id", &"")))
		mag = float(tw.bullet_impulse_by_class.get(cls, tw.bullet_impulse_default))
		if cls == &"shotgun" and _range_of(body, info) > tw.shotgun_range_m:
			mag *= tw.shotgun_far_mult
	elif t == Enums.DamageType.MELEE:
		mag = tw.melee_impulse
	var dir: Vector3 = info.get("direction", Vector3.ZERO)
	if mag <= 0.0 or dir.length() < 0.0001:
		return {}
	return {
		"blast": false, "impulse": dir.normalized() * mag, "point": point, "mag": mag,
		"head": int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD,
	}


## Shooter-to-hit distance: info.range_m (CombatSystem), else from the attacker's node, else far.
static func _range_of(body: Node3D, info: Dictionary) -> float:
	if info.has("range_m"):
		return float(info["range_m"])
	var attacker: Node3D = Ids.lookup(int(info.get("attacker_net_id", 0))) as Node3D
	if attacker == null or body == null:
		return INF
	return attacker.global_position.distance_to(info.get("position", body.global_position))


## A corpse hit's record: point pushes clamped to nudge_min..nudge_max (x nudge_mult); blasts scaled.
static func _as_nudge(rec: Dictionary, tw: RagdollTweak) -> Dictionary:
	var out: Dictionary = rec.duplicate()
	if bool(rec["blast"]):
		out["falloff"] = float(rec["falloff"]) * tw.corpse_blast_mult
		return out
	var imp: Vector3 = rec["impulse"]
	var m: float = clampf(imp.length() * tw.nudge_mult, tw.nudge_min, tw.nudge_max)
	out["impulse"] = imp.normalized() * m
	out["mag"] = m
	return out


# --- Frame ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match phase:
		Phase.PENDING_DEATH:
			if Engine.get_physics_frames() > _death_frame:
				_decide()
		Phase.ANIM:
			_t += delta
			if _pose_held():
				_topple_from_pose()
			elif _anim_done():
				_start([], RagdollTweak.data().settle_after_anim_s)
		Phase.STARTING:
			_first_push()
		Phase.ACTIVE:
			_t += delta
			if _t >= _settle_s or (_t >= RagdollTweak.data().settle_min_s and _all_slow()):
				freeze()


## Server: ragdoll now (explosion / big impulse) or let the death clip play first.
func _decide() -> void:
	var tw: RagdollTweak = RagdollTweak.data()
	var total: float = 0.0
	var blast: bool = false
	for h: Dictionary in _hits:
		total += float(h["mag"])
		blast = blast or bool(h["blast"])
	if tw.enabled and ((blast and tw.explosion_always) or total >= tw.min_impulse):
		var hits: Array[Dictionary] = _hits.duplicate()
		_hits.clear()
		_start(hits, tw.settle_s)
		return
	_death_hits = _hits.duplicate()
	_hits.clear()
	_t = 0.0
	phase = Phase.ANIM if tw.enabled and tw.settle_after_anim else Phase.FROZEN


## PO6-18: the AnimDriver froze the pre-death pose (kneel / crouch / prone without a pose death clip on this rig).
func _pose_held() -> bool:
	return _t >= 0.1 and player != null and player.speed_scale == 0.0


## Server: a body frozen in its pose slumps down from it (never left upright): the killing hits' directions at
## pose_topple_impulse (a forward push on the chest without one), settled like a ragdoll death.
func _topple_from_pose() -> void:
	var tw: RagdollTweak = RagdollTweak.data()
	var hits: Array = []
	for h: Dictionary in _death_hits:
		if bool(h["blast"]):
			continue
		var rec: Dictionary = h.duplicate()
		var imp: Vector3 = rec["impulse"]
		rec["impulse"] = (imp.normalized() if imp.length() > 0.001 else -npc.global_basis.z) * tw.pose_topple_impulse
		rec["mag"] = tw.pose_topple_impulse
		hits.append(rec)
	if hits.is_empty():
		var base: Vector3 = npc.visual_root.global_position if npc.visual_root != null else npc.global_position
		hits.append({"blast": false, "head": false, "mag": tw.pose_topple_impulse,
			"point": base + Vector3.UP * 0.9, "impulse": -npc.global_basis.z * tw.pose_topple_impulse})
	_death_hits.clear()
	_start(hits, tw.settle_s)


func _anim_done() -> bool:
	if _t >= RagdollTweak.data().anim_wait_max_s or player == null:
		return true
	if _t < 0.25:  # the AnimDriver switches to the death clip on its next frame
		return false
	return not player.is_playing() or player.current_animation_position >= player.current_animation_length - 0.02


## Start simulating from the current pose; `hits` (server) push on the next physics frame.
func _start(hits: Array, settle: float) -> void:
	_engage()
	sim.active = true
	sim.physical_bones_start_simulation()
	phase = Phase.STARTING
	_t = 0.0
	_settle_s = settle
	_hits.assign(hits)
	_register()


func _engage() -> void:
	if not engaged and player != null:
		player.pause()  # RAGDOLL.md: pause (stop() would snap to frame 0); a playing player would overwrite the bake
	engaged = true


func _first_push() -> void:
	phase = Phase.ACTIVE
	if Net.is_authority():
		var entries: Array = _entries_for(_hits, RagdollTweak.data())
		_hits.clear()
		_apply(entries)
		_publish_start(entries)
	else:
		_apply(_entries)
		_entries = []


func _publish_start(entries: Array) -> void:
	seq += 1
	_rs = [seq, _settle_s, entries]


## [[body index, impulse, offset], ...] for `hits`, from the bodies' current transforms.
func _entries_for(hits: Array, tw: RagdollTweak) -> Array:
	var out: Array = []
	for h: Dictionary in hits:
		if bool(h["blast"]):
			var c: Vector3 = h["center"]
			for i: int in bodies.size():
				var d: Vector3 = bodies[i].global_position - c
				var dir: Vector3 = d.normalized() if d.length() > 0.01 else Vector3.ZERO
				dir = (dir + Vector3.UP * tw.explosion_up_bias).normalized()
				# Upper bodies take more than the legs, so the body tips over instead of sliding upright.
				var hgt: float = clampf((bodies[i].global_position.y - npc.global_position.y) / tw.explosion_tip_height_m, 0.0, 1.0)
				var k: float = lerpf(tw.explosion_leg_mult, tw.explosion_head_mult, hgt)
				out.append([i, dir * bodies[i].mass * tw.explosion_speed_mps * float(h["falloff"]) * k, Vector3.ZERO])
			continue
		var bi: int = _body_index_for(h)
		if bi < 0:
			continue
		var off: Vector3 = (h["point"] as Vector3) - bodies[bi].global_position
		out.append([bi, h["impulse"], off.limit_length(tw.max_offset_m)])
	return out


## The body hit by a point record: the head body for a HEAD zone, else the body nearest to the hit point.
func _body_index_for(h: Dictionary) -> int:
	var best: int = -1
	var best_d: float = INF
	var p: Vector3 = h["point"]
	for i: int in bodies.size():
		if bool(h["head"]) and bodies[i].name == HEAD_BODY:
			return i
		var d: float = bodies[i].global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _apply(entries: Array) -> void:
	for e: Variant in entries:
		var a: Array = e as Array
		var i: int = int(a[0])
		if i >= 0 and i < bodies.size():
			bodies[i].apply_impulse(a[1] as Vector3, a[2] as Vector3)


func _all_slow() -> bool:
	var v: float = RagdollTweak.data().settle_speed_mps
	for pb: PhysicalBone3D in bodies:
		if pb.linear_velocity.length() >= v:
			return false
	return true


# --- Freeze -----------------------------------------------------------------------------------

## Bake the bodies into the skeleton pose and stop simulating. The server publishes the pose (the root stays on
## the CorpseAnchor, D-121); a client freezes cosmetically until the server's pose arrives.
func freeze() -> void:
	if phase != Phase.ACTIVE and phase != Phase.STARTING:
		return
	if Net.is_authority() and phase == Phase.STARTING:
		_publish_start([])  # frozen by the cap before its first push: the clients still need the start
	var xfs: Array[Transform3D] = _body_bone_xforms()
	sim.physical_bones_stop_simulation()
	sim.active = false
	phase = Phase.FROZEN
	_active.erase(self)
	freezes += 1
	_entries.clear()
	_hits.clear()
	if Net.is_authority():
		_bleed_at(skel.global_transform * xfs[_body_index(HIPS_BODY)].origin)
	bake(skel, bodies, xfs)
	if Net.is_authority():
		_rp = [seq, npc.global_position, npc.visual_root.position if npc.visual_root != null else Vector3.ZERO, xfs]


## Bone transforms (skeleton space) driven by each body now: body x body_offset^-1 (RAGDOLL.md).
func _body_bone_xforms() -> Array[Transform3D]:
	var inv: Transform3D = skel.global_transform.affine_inverse()
	var out: Array[Transform3D] = []
	for pb: PhysicalBone3D in bodies:
		out.append(inv * pb.global_transform * pb.body_offset.affine_inverse())
	return out


## Writes `xfs` (skeleton-space bone transforms, one per body) into the local bone poses, parents first;
## bones without a body keep their local pose (RAGDOLL.md bake).
static func bake(p_skel: Skeleton3D, p_bodies: Array[PhysicalBone3D], xfs: Array[Transform3D]) -> void:
	var driven: Dictionary = {}
	for i: int in mini(p_bodies.size(), xfs.size()):
		driven[p_skel.find_bone(p_bodies[i].bone_name)] = xfs[i]
	var global: Array[Transform3D] = []
	global.resize(p_skel.get_bone_count())
	for i: int in p_skel.get_bone_count():
		var parent: int = p_skel.get_bone_parent(i)
		var parent_xf: Transform3D = global[parent] if parent >= 0 else Transform3D.IDENTITY
		var local: Transform3D = p_skel.get_bone_pose(i)
		if driven.has(i):
			local = (parent_xf.affine_inverse() * (driven[i] as Transform3D)).orthonormalized()
			p_skel.set_bone_pose(i, local)
		global[i] = parent_xf * local


## Server, D-113 (cosmetic): the blood pool follows the body to where its hips came to rest when that is
## bleed_move_m or more from the gameplay anchor (the root, D-121; it never moves here).
func _bleed_at(hips: Vector3) -> void:
	var at: Vector3 = Vector3(hips.x, npc.global_position.y, hips.z)
	if at.distance_to(npc.global_position) >= RagdollTweak.data().bleed_move_m and npc.net_id != 0:
		BloodFx.bleed(npc.net_id, true, at, BloodFx.death_rate(npc.last_damage))


func _body_index(nm: StringName) -> int:
	for i: int in bodies.size():
		if bodies[i].name == nm:
			return i
	return 0


# --- Cap ------------------------------------------------------------------------------------------

func _register() -> void:
	_prune()
	if not _active.has(self):
		_active.append(self)
	var cap: int = maxi(RagdollTweak.data().max_active, 1)
	while _active.size() > cap:
		var oldest: NpcRagdoll = _active[0]
		if oldest == self:
			break
		oldest.freeze()
		_active.erase(oldest)


static func _prune() -> void:
	for i: int in range(_active.size() - 1, -1, -1):
		var r: NpcRagdoll = _active[i]
		if not is_instance_valid(r) or not r.is_inside_tree() or r.npc.has_meta(&"bagged"):
			_active.remove_at(i)


# --- Net ------------------------------------------------------------------------------------------

## Server: the ragdoll keys of the NPC's replicated state.
func net_state(st: Dictionary) -> void:
	if not _rs.is_empty():
		st["rs"] = _rs
	if not _rp.is_empty():
		st["rp"] = _rp


## Client: apply "rs" (start / push) then "rp" (frozen pose) from the server.
func apply_net_state(d: Dictionary) -> void:
	if Net.is_authority():
		return
	var rs: Array = d.get("rs", []) as Array
	var rp: Array = d.get("rp", []) as Array
	var rp_seq: int = int(rp[0]) if rp.size() >= 4 else 0
	if rs.size() >= 3 and int(rs[0]) > _applied_rs:
		_applied_rs = int(rs[0])
		if rp_seq < _applied_rs:  # a late joiner with the pose of this start skips the simulation
			_client_start(rs[2] as Array, float(rs[1]))
	if rp_seq > applied_rp:
		applied_rp = rp_seq
		_snap(rp[1] as Vector3, rp[2] as Vector3, rp[3] as Array)


func _client_start(entries: Array, settle: float) -> void:
	if phase == Phase.ACTIVE:
		_apply(entries)
		_settle_s = maxf(_settle_s, _t + RagdollTweak.data().nudge_settle_s)
		return
	if phase == Phase.STARTING:
		_entries.append_array(entries)
		return
	_start([], settle)
	_entries = entries.duplicate()


## Client: the server's frozen pose (root, visual offset, baked bone transforms).
func _snap(root: Vector3, visual_offset: Vector3, xfs_in: Array) -> void:
	if phase == Phase.ACTIVE or phase == Phase.STARTING:
		sim.physical_bones_stop_simulation()
		sim.active = false
	_active.erase(self)
	_engage()
	phase = Phase.FROZEN
	_entries.clear()
	npc.global_position = root
	if npc.visual_root != null:
		npc.visual_root.position = visual_offset
	var xfs: Array[Transform3D] = []
	for x: Variant in xfs_in:
		xfs.append(x as Transform3D)
	bake(skel, bodies, xfs)
