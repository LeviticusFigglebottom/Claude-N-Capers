## D-123: limb hitboxes (upper arms, thighs) on a rigged NPC. Owner: ENV A. Tunables: CombatTweak "Limb hitboxes".
## Each limb is a Hitbox (layer 5) on a BoneAttachment3D of its bone under the rig's Skeleton3D, so it follows the
## animated pose. Damage: a limb box is zone BODY (the BODY multiplier, 1.0): headshot logic, armor (L3.4 / L4.2),
## stats and kill info all see a body hit, PD2 damage is unchanged. The limb only travels as A-side data: the
## sub-zone `limb` (SUB_*) in the hit claim and in DamageInfo, which AnimDriver.hit_zone_clip turns into the
## characters.md v1.18 hit_shoulder_* / hit_leg_* flinch. (Enums.HitZone.LIMB stays unused for NPC boxes so no
## rule keyed on BODY ever misses a limb hit.)
## The HEAD sphere and BODY capsule (NpcBase `Hitboxes`) stay the static hull; the thighs sit inside the hull, so
## a shot that lands on the hull is followed through it (probe) to name the limb it passes. The corpse hitbox
## (CorpseAnchor, D-121) is untouched; the limb boxes go off with the live hitboxes at death.
## Capsule placeholders (no Skeleton3D) get none.
class_name NpcLimbHitboxes
extends RefCounted

const SUB_SHOULDER_L: StringName = &"shoulder_l"
const SUB_SHOULDER_R: StringName = &"shoulder_r"
const SUB_LEG_L: StringName = &"leg_l"
const SUB_LEG_R: StringName = &"leg_r"
const SUBS: Array[StringName] = [SUB_SHOULDER_L, SUB_SHOULDER_R, SUB_LEG_L, SUB_LEG_R]
## Node name prefix of the BoneAttachment3D of a limb box (child of the rig's Skeleton3D).
const PREFIX: String = "LimbHit_"
## [bone, child bone (the length), sub-zone, arm?]. `.L` is the character's left (root-space x < 0).
const LIMBS: Array[Array] = [
	["upper_arm.L", "forearm.L", SUB_SHOULDER_L, true],
	["upper_arm.R", "forearm.R", SUB_SHOULDER_R, true],
	["thigh.L", "shin.L", SUB_LEG_L, false],
	["thigh.R", "shin.R", SUB_LEG_R, false],
]
const MAX_PROBE_STEPS: int = 6


## The rig's Skeleton3D of `npc` (null for a capsule placeholder).
static func skeleton_of(npc: Node) -> Skeleton3D:
	var ap: AnimationPlayer = AnimDriver.find_player(npc)
	var root: Node = ap.get_parent() if ap != null else null
	return root.get_node_or_null(^"Skeleton3D") as Skeleton3D if root != null else null


## Build the limb boxes of `npc` (idempotent). Returns them (empty without a rig or limb bones).
static func ensure(npc: NpcBase) -> Array[Hitbox]:
	var out: Array[Hitbox] = boxes(npc)
	if not out.is_empty():
		return out
	var skel: Skeleton3D = skeleton_of(npc)
	if skel == null:
		return out
	var tw: CombatTweak = CombatTweak.data()
	for l: Array in LIMBS:
		var bone: int = skel.find_bone(String(l[0]))
		if bone < 0:
			continue
		var arm: bool = bool(l[3])
		var length: float = tw.limb_upper_arm_length_m if arm else tw.limb_thigh_length_m
		var child: int = skel.find_bone(String(l[1]))
		if child >= 0 and skel.get_bone_parent(child) == bone:
			length = skel.get_bone_rest(child).origin.length()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = tw.limb_upper_arm_radius_m if arm else tw.limb_thigh_radius_m
		cap.height = maxf(length, cap.radius * 2.0)
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.name = PREFIX + String(l[2])
		att.bone_name = String(l[0])
		var hb: Hitbox = Hitbox.new()
		hb.name = "Hitbox"
		hb.hit_zone = Enums.HitZone.BODY  # D-123: the BODY multiplier and every BODY rule
		hb.limb = l[2]
		hb.target = npc
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = cap
		cs.position = Vector3(0.0, length * 0.5, 0.0)  # Godot bones point +Y at their child joint
		hb.add_child(cs)
		att.add_child(hb)
		skel.add_child(att)
		hb.set_active(npc.alive)
		out.append(hb)
	return out


## The limb boxes of `npc` (empty when none were built).
static func boxes(npc: Node) -> Array[Hitbox]:
	var out: Array[Hitbox] = []
	var skel: Skeleton3D = skeleton_of(npc)
	if skel == null:
		return out
	for c: Node in skel.get_children():
		if c is BoneAttachment3D and c.name.begins_with(PREFIX):
			var hb: Hitbox = c.get_node_or_null(^"Hitbox") as Hitbox
			if hb != null:
				out.append(hb)
	return out


## Enable / disable the limb boxes of `npc` with its live hitboxes.
static func set_active(npc: Node, on: bool) -> void:
	for hb: Hitbox in boxes(npc):
		hb.set_active(on)


## The flinch sub-zone of a shot along `dir` that hit `collider` at `pos` (&"" = none): a limb box names itself; a
## BODY hull hit on an NPC with limb boxes is followed through the hull (limb_probe_depth_m) to the first limb box
## of that NPC on the line. Never changes the hit itself.
static func limb_at(collider: Object, pos: Vector3, dir: Vector3, space: PhysicsDirectSpaceState3D) -> StringName:
	var own: StringName = Hitbox.limb_of(collider)
	if own != &"":
		return own
	var hull: Hitbox = collider as Hitbox
	if hull == null or hull.hit_zone != Enums.HitZone.BODY or space == null or dir.length() < 0.0001:
		return &""
	var npc: NpcBase = hull.get_damage_target() as NpcBase
	if npc == null or boxes(npc).is_empty():
		return &""
	var d: Vector3 = dir.normalized()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pos - d * 0.01, pos + d * CombatTweak.data().limb_probe_depth_m, Hitbox.LAYER_HITBOXES)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var ex: Array[RID] = [hull.get_rid()]
	for _i: int in MAX_PROBE_STEPS:
		q.exclude = ex
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return &""
		var hb: Hitbox = hit.get("collider") as Hitbox
		if hb != null and hb.limb != &"" and hb.get_damage_target() == npc:
			return hb.limb
		ex.append(hit.get("rid") as RID)
	return &""


## Server: a claimed sub-zone, sanitized (a known SUB_* on a non-HEAD hit, else &"").
static func sanitize(limb: Variant, zone: int) -> StringName:
	if zone == Enums.HitZone.HEAD or not (limb is StringName or limb is String):
		return &""
	var s: StringName = StringName(limb)
	return s if SUBS.has(s) else &""
