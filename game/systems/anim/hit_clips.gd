## Hit reacts, hit-zone flinches and death clips for AnimDriver (characters.md v1.10 / v1.11 / v1.18, D-123,
## PO6-18). Owner: ENV A. Presentation only (reads state, never writes gameplay state). The clip constants stay on
## AnimDriver (HIT_*, LIMB_CLIPS, DEATH_SEATED_*); a RefCounted helper with a back-reference `_d` to the driver.
class_name HitClips
extends RefCounted

var _d: AnimDriver = null


func _init(driver: AnimDriver) -> void:
	_d = driver


## characters.md v1.18 (SOURCE `hit_zones:`): the flinch for damage `info` from its `zone` and hit `position` in the
## body's root space: HEAD -> hit_head, BODY -> hit_chest, LIMB above the hips joint -> hit_shoulder_l / _r, below ->
## hit_leg_l / _r (left = root-space x < 0). D-123: a `limb` sub-zone (upper-arm / thigh hitbox, zone BODY) wins
## on a BODY / LIMB hit: shoulder_l / _r -> hit_shoulder_l / _r, leg_l / _r -> hit_leg_l / _r.
## &"" when no zone is known (no `zone`, WEAKPOINT, a type other than
## bullet / melee, a LIMB hit without a position) or the rig lacks the clip: the directional hit_react* set plays.
func zone_clip(info: Dictionary) -> StringName:
	if not info.has("zone") or not AnimDriver.HIT_ZONE_TYPES.has(int(info.get("type", Enums.DamageType.BULLET))):
		return &""
	var out: StringName = &""
	var limb: StringName = StringName(info.get("limb", &""))
	match int(info["zone"]):
		Enums.HitZone.BODY, Enums.HitZone.LIMB when AnimDriver.LIMB_CLIPS.has(limb):
			out = AnimDriver.LIMB_CLIPS[limb]  # D-123: a limb box's sub-zone (zone BODY) names its shoulder / leg flinch
		Enums.HitZone.HEAD:
			out = AnimDriver.HIT_HEAD
		Enums.HitZone.BODY:
			out = AnimDriver.HIT_CHEST
		Enums.HitZone.LIMB:
			var pos: Variant = info.get("position")
			if pos is Vector3:
				var xf: Transform3D = _d._body.global_transform if _d._body.is_inside_tree() else _d._body.transform
				var local: Vector3 = xf.affine_inverse() * (pos as Vector3)
				var left: bool = local.x < 0.0
				if local.y > AnimDriver.HIT_ZONE_HIPS_Y_M * _d._motion_scale():
					out = AnimDriver.HIT_SHOULDER_L if left else AnimDriver.HIT_SHOULDER_R
				else:
					out = AnimDriver.HIT_LEG_L if left else AnimDriver.HIT_LEG_R
	if out == &"" or _d.player == null or not _d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, out]):
		return &""
	return out


## v1.10: the hit react for a bullet travelling along world direction `dir` (body frame: from the front, back,
## left or right).
func react_clip(dir: Vector3) -> StringName:
	var d: Vector3 = _d._body.global_transform.basis.inverse() * Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return AnimDriver.HIT_FRONT
	d = d.normalized()
	if d.z > 0.5:
		return AnimDriver.HIT_FRONT
	if d.z < -0.5:
		return AnimDriver.HIT_BACK
	return AnimDriver.HIT_LEFT if d.x > 0.5 else AnimDriver.HIT_RIGHT


## PO6-18 / D-114 §7: a kneeling / cuffed / crouched / prone / downed body dies from that pose: its pose death,
## or (rig without it) the pose itself, frozen where it is. &"" = a standing body.
func pose_death_clip(tw: AnimTweak) -> StringName:
	if _d._alive_clip == CivPanic.PANIC_START:
		return _d.civ_panic.death_clip()  # D-116: death_crouch from ~f10, before that the normal deaths
	if not tw.death_by_pose.has(_d._alive_clip):
		return &""
	var posed: StringName = tw.death_by_pose[_d._alive_clip]
	if _d.player == null or _d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, posed]):
		return posed
	_d._death_hold = true
	return _d._alive_clip


func pick_death_clip(tw: AnimTweak) -> StringName:
	var posed: StringName = pose_death_clip(tw)
	if posed != &"":
		return posed
	var npc: NpcBase = _d._npc
	var body: Node3D = _d._body
	var dir: Vector3 = _d._hit_dir
	if dir == Vector3.ZERO and npc != null:
		dir = npc.last_damage.get("direction", Vector3.ZERO)
	dir.y = 0.0
	var facing: Vector3 = -body.global_transform.basis.z
	facing.y = 0.0
	# Bullet travelling along the facing = hit from behind (pitched forward, face down); against it = frontal.
	var from_behind: bool = dir.length() >= 0.001 and dir.normalized().dot(facing.normalized()) > tw.death_front_dot
	if _d._seated:  # characters.md v1.11: slump on the desk from a frontal or melee kill, else off the chair
		var melee: bool = npc != null and int(npc.last_damage.get("type", -1)) == Enums.DamageType.MELEE
		var seated_clip: StringName = AnimDriver.DEATH_SEATED_SLUMP if melee or not from_behind \
			else AnimDriver.DEATH_SEATED_FALL
		if _d.player == null or _d.player.has_animation("%s/%s" % [AnimDriver.LIBRARY, seated_clip]):
			return seated_clip
	if dir.length() < 0.001:
		return &"death_back"
	# v1.10 variety: a strong side hit falls sideways; otherwise front / back, half of the bodies with the _b
	# variant. Picked from the replicated node name, so every peer shows the same death.
	var right: Vector3 = body.global_transform.basis.x
	if absf(dir.normalized().dot(right)) > tw.death_side_dot:
		return &"death_side"
	var b: bool = absi(hash(String(body.name) + "death")) % 2 == 1
	if from_behind:
		return &"death_front_b" if b else &"death_front"
	return &"death_back_b" if b else &"death_back"
