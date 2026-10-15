# Character ragdoll (PO6-19, D-114 §7): API for ENV A

Every assembled character scene (`world/characters/<id>/<id>.tscn`, all entries of `characters.json`)
has a physical-bones ragdoll. ENV D builds it (`_tools/ragdoll_builder.gd`, data in
`_tools/character_spec.gd` `RAGDOLL_*`); ENV A owns the runtime (death, impulses, cap, freeze, net).
Checked by `game/tests/d/test_ragdoll.gd`; review renders `assets/characters/_review/ragdoll_*.png`.

## Shape

```
<Root>/Skeleton3D/Ragdoll                PhysicalBoneSimulator3D, active = false (ships inactive)
    Hips  Spine  Chest  Head             PhysicalBone3D (bone_name = contract bone), child `Shape`
    UpperArmL  ForearmL  UpperArmR  ForearmR
    ThighL  ShinL  ThighR  ShinR
```

| Body | Bone | Shape | kg | Joint to parent body |
|---|---|---|---|---|
| Hips | `hips` | box | 12 | none (root body) |
| Spine | `spine` | box | 9 | cone: swing 30, twist 30 |
| Chest | `chest` | box | 15 | cone: swing 30, twist 30 |
| Head | `head` | capsule | 5.5 | cone (neck, to Chest): swing 40, twist 45 |
| UpperArmL/R | `upper_arm.L/R` | capsule | 2.5 | cone (shoulder, to Chest): swing 80, twist 45 |
| ForearmL/R | `forearm.L/R` | capsule (incl. hand) | 2.0 | hinge (elbow): 0..140, forward flexion only |
| ThighL/R | `thigh.L/R` | capsule | 10 | cone (hip, to Hips): swing 70, twist 30 |
| ShinL/R | `shin.L/R` | capsule (incl. foot) | 4.5 | hinge (knee): 0..140, backward flexion only |

Total 79.5 kg. Shapes are sized from the rest pose and scale with the character height. Bones without
a body (neck, clavicles, hands, fingers, feet, toes) keep their current local pose and ride along.
Damping: linear 0.4, angular 3.0, friction 0.9, bounce 0: a body settles in about 2.5 s.

**Collision:** `collision_layer = 1 << 10` (layer 11, unnamed in project.godot: **the LEAD must name it**,
proposal `ragdoll`), `collision_mask = 1 | 2 | 1024` (`world_static | world_dynamic | ragdoll`). The bodies
hit world geometry and other ragdoll bodies (so legs do not cross through each other and corpses pile; the
two bodies of a joint never collide), never players, NPC capsules, hitboxes or loot. While not simulating,
the bodies have layer and mask 0 in the physics server and the inactive simulator does not touch the
animated pose (both tested).

## Start at death

```gdscript
var sim := root.get_node(^"Skeleton3D/Ragdoll") as PhysicalBoneSimulator3D
anim_player.pause()                  # freeze the hands/feet in the death-frame pose (stop() snaps to frame 0)
sim.active = true                    # BOTH lines: an inactive simulator never writes the pose
sim.physical_bones_start_simulation()
await get_tree().physics_frame       # impulses applied after the bodies went rigid (what the tests do)
```

The bodies start from the current (animated) pose. Disable the NPC's CharacterBody3D collision and
hitbox Areas as today; the ragdoll does not need them.

## Impulse on a named bone

```gdscript
func body_for_bone(sim: PhysicalBoneSimulator3D, skel: Skeleton3D, bone: StringName) -> PhysicalBone3D:
	var i := skel.find_bone(bone)
	while i >= 0:                     # hand.R -> ForearmR, foot.L -> ShinL, neck/clavicle -> Chest
		for pb in sim.get_children():
			if pb is PhysicalBone3D and pb.bone_name == skel.get_bone_name(i):
				return pb
		i = skel.get_bone_parent(i)
	return null

var pb := body_for_bone(sim, skel, hit_bone)
pb.apply_impulse(dir * strength, hit_point - pb.global_position)   # offset: global axes, from the body origin
```

Reference: 150 N s on `Chest` (the test and the review render) knocks a standing 80 kg body flat ~1 m
back, like a point-blank shotgun. For an explosion, give each body `dir_from_centre * k * falloff`
(about 15–40 N s per body near the centre). Corpse nudges: 5–20 N s on the hit body.

## Settle and freeze (~3 s)

After `SETTLE_S` ≈ 3 s (or when every body's `linear_velocity` < 0.05 m/s), bake the bodies into the
skeleton pose and stop the simulation. The corpse then costs nothing and has a fixed pose to sync:

```gdscript
# anim_player stays paused (from the death start): a playing / stopping player would overwrite the bake
bake(skel, sim)                      # below; copy of test_ragdoll.gd _bake()
sim.physical_bones_stop_simulation()
sim.active = false

static func bake(skel: Skeleton3D, sim: PhysicalBoneSimulator3D) -> void:
	var driven := {}
	for pb in sim.get_children():
		if pb is PhysicalBone3D:
			driven[skel.find_bone(pb.bone_name)] = skel.global_transform.affine_inverse() \
				* pb.global_transform * pb.body_offset.affine_inverse()
	var global: Array[Transform3D] = []
	global.resize(skel.get_bone_count())
	for i in skel.get_bone_count():      # contract order is parents first
		var parent := skel.get_bone_parent(i)
		var parent_xf := global[parent] if parent >= 0 else Transform3D.IDENTITY
		var local := skel.get_bone_pose(i)
		if driven.has(i):
			local = parent_xf.affine_inverse() * driven[i]
			skel.set_bone_pose(i, local.orthonormalized())
		global[i] = parent_xf * local
```

Read `Skeleton3D.get_bone_global_pose()` of a simulating ragdoll only inside `skeleton_updated`
(modifier output is reset each frame); `pb.global_transform * pb.body_offset.affine_inverse()` works
any time. Net: the server is authoritative for the frozen pose (12 body transforms, or the baked bone
poses); peers may simulate the same start + impulse cosmetically and snap to the server pose at freeze.
A later nudge on a frozen corpse: start again (the bodies start from the baked pose), impulse, re-freeze
after ~1 s (not covered by the D tests). Cap the active ragdolls (freeze the oldest first).

## Proposed contract text (characters.md v1.12, for the LEAD)

> **v1.12: ragdoll (PO6-19, D-114 §7).** Every character scene has `Skeleton3D/Ragdoll`, a
> `PhysicalBoneSimulator3D` shipped with `active = false`, holding `PhysicalBone3D` bodies `Hips`, `Spine`,
> `Chest`, `Head`, `UpperArmL/R`, `ForearmL/R`, `ThighL/R`, `ShinL/R` (`bone_name` = the contract bone; each
> with a `Shape` child; ~80 kg total; cone joints at the spine, neck, shoulders and hips, hinge joints
> flexing the elbows forward and the knees back, 0–140°). Bodies are on physics layer 11 `ragdoll` and
> collide with `world_static | world_dynamic | ragdoll` only (not players, NPCs or hitboxes). ENV A starts it at death with `active = true` +
> `physical_bones_start_simulation()`, applies impulses to the body of the hit bone (nearest ancestor with
> a body), and freezes the corpse after ~3 s by baking the bodies into the bone poses and stopping the
> simulation (recipe: `world/characters/_tools/RAGDOLL.md`). project.godot names `3d_physics/layer_11="ragdoll"`.
