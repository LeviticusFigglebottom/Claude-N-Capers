## Helpers for the A3-06 / A3-01b tests (piercing, suppression, explosives, Bulwark/Wrecker/Corpsman).
class_name ACombatSpecials
extends RefCounted

const ENEMY_DIR: String = "res://systems/ai/data/enemies/"


static func launch(owner: Node, difficulty: int = Enums.Difficulty.ROUTINE, guards: int = 0) -> HeistRuntime:
	var rt: HeistRuntime = await HeistLauncher.launch(&"unit_map", 42, difficulty, owner,
		{"map_packed": ATestMaps.basic(guards, 0), "ai_teammates": 0, "crew_ai": false})
	await owner.get_tree().physics_frame
	return rt


static func def(id: String) -> EnemyDef:
	return load(ENEMY_DIR + id + ".tres") as EnemyDef


## Spawn EnemyDef `id` (its params.scene, else npc_police) at `pos` facing `facing` (horizontal).
static func spawn(rt: HeistRuntime, id: String, pos: Vector3, facing: Vector3 = Vector3.FORWARD) -> NpcBase:
	var f: Vector3 = Vector3(facing.x, 0.0, facing.z)
	var basis: Basis = Basis.looking_at(f.normalized(), Vector3.UP) if f.length() > 0.001 else Basis.IDENTITY
	return rt.spawn_npc(&"police", Transform3D(basis, pos), {"enemy_def": def(id)})


## Put crew `slot` at `pos` (masked) and wait a few physics frames.
static func place_crew(rt: HeistRuntime, slot: int, pos: Vector3) -> CrewController:
	var c: CrewController = rt.crew_controller(slot) as CrewController
	c.set_masked()
	rt.teleport_crew(slot, Transform3D(Basis.IDENTITY, pos))
	for i: int in range(3):
		await c.get_tree().physics_frame
	return c


## One trigger pull of crew `slot` aimed from its eye at `point`.
static func shoot_at(rt: HeistRuntime, slot: int, point: Vector3) -> void:
	var c: CrewController = rt.crew_controller(slot) as CrewController
	var aim: CrewIntent = BotUtil.look_at_intent(c.eye_position(), point)
	aim.fire = true
	rt.set_bot_intent(slot, aim)
	for i: int in range(2):
		await c.get_tree().physics_frame
	var rel: CrewIntent = CrewIntent.new()
	rel.look_yaw = aim.look_yaw
	rel.look_pitch = aim.look_pitch
	rt.set_bot_intent(slot, rel)
	for i: int in range(6):
		await c.get_tree().physics_frame


## Give crew `slot` a resolved loadout with `primary` (and the default secondary) and equip it.
static func arm(rt: HeistRuntime, slot: int, primary: StringName, suppressed_secondary: bool = false) -> CrewWeapons:
	var c: CrewController = rt.crew_controller(slot) as CrewController
	var l: Loadout = Loadout.new()
	l.primary = primary
	l.secondary = &"weapon.kestrel_p9"
	if suppressed_secondary:
		l.secondary_mods = [&"mod.p9_suppressor"]
	c.loadout = CrewWeapons.build_loadout(l)
	c.weapons.set_loadout(c.loadout)
	return c.weapons


## Direct server hit on `npc` (unit tests of target-side rules).
static func hit(npc: NpcBase, amount: float, zone: int = Enums.HitZone.BODY, from: Vector3 = Vector3.INF,
		type: int = Enums.DamageType.BULLET, pierced: bool = false) -> Dictionary:
	var target: Vector3 = CombatSystem.target_center(npc)
	var origin: Vector3 = from if from != Vector3.INF else target - npc.look_forward() * -5.0
	var info: Dictionary = Damage.info(amount, type, zone, &"weapon.test", target, (target - origin).normalized(), 0)
	info["pierced_armor"] = pierced
	return npc.take_hit(info, 0)


## Records EventBus.audio_cue_requested ids.
static func record_cues(into: Array[StringName]) -> Callable:
	var cb: Callable = func(cue_id: StringName, _p: Vector3, _src: int) -> void: into.append(cue_id)
	EventBus.audio_cue_requested.connect(cb)
	return cb
