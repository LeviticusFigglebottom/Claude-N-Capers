## AnimDriver's third-person held visuals: the WeaponVisual at HandR/Socket (v1.20 akimbo: the offhand gun at
## HandL/Socket) and the v1.20 carried-bag visual at Back/Socket. Owner: ENV A. Presentation only. The visual nodes
## and the weapon facts (weapon_visual, weapon_offhand, bag_visual, weapon_kind, weapon_class) stay on the driver;
## this RefCounted helper (back-reference `_d`, like CombatClips) builds and clears them.
class_name HeldVisuals
extends RefCounted

static var _weapon_defs: Dictionary = {}

var _d: AnimDriver = null
## v1.20: the LootBag the carried-bag visual shows.
var _shown_bag: Node = null


func _init(driver: AnimDriver) -> void:
	_d = driver


## Rebuild the third-person weapon at `HandR/Socket` (crew: equipped weapon; NPC: EnemyDef.weapon).
func refresh_weapon() -> void:
	for n: Node3D in [_d.weapon_visual, _d.weapon_offhand]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_d.weapon_visual = null
	_d.weapon_offhand = null
	var crew: CrewController = _d._crew
	var npc: NpcBase = _d._npc
	var def: WeaponDef = null
	var mod_ids: Array[StringName] = []
	if crew != null and crew.weapons != null:
		var ws: int = crew.weapons.equipped_slot
		if crew.weapons.has_weapon(ws):
			def = weapon_def(crew.weapons.weapon_id(ws))
		var l: Loadout = crew.loadout
		if l != null:
			mod_ids = l.primary_mods if ws == Enums.WeaponSlot.PRIMARY else l.secondary_mods
	elif npc != null and npc.enemy_def != null:
		# NPC weapon ids (weapon.npc_*) have no model of their own: ENV B's mapping to an armory model (PO6-16 review).
		def = NpcWeaponModels.weapon_def(npc.enemy_def.weapon)
	_d.weapon_kind = kind_for(def)
	_d.weapon_class = def.weapon_class if def != null else -1
	_d._holds_weapon = def != null
	var rig: Node3D = _d.rig
	var socket: Node3D = rig.get_node_or_null(^"Skeleton3D/HandR/Socket") as Node3D if rig != null else null
	if def == null or def.model == null or socket == null:
		return
	var wv: WeaponVisual = WeaponVisual.new()
	wv.name = AnimDriver.WEAPON_NODE
	socket.add_child(wv)
	wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
	_d.weapon_visual = wv
	_place_offhand(wv)


## v1.20 akimbo: WeaponVisual builds the pair as the gun plus `offhand` beside it (the first-person rest pose); in
## third person the second gun goes in the left fist: HandL/Socket, the mirrored weapon-grip convention (identity).
## One gun per hand, never the pair in one hand.
func _place_offhand(wv: WeaponVisual) -> void:
	var socket: Node3D = _d.rig.get_node_or_null(^"Skeleton3D/HandL/Socket") as Node3D
	if not wv.is_akimbo() or socket == null:
		return
	var off: Node3D = wv.offhand
	off.get_parent().remove_child(off)
	off.name = AnimDriver.OFFHAND_NODE
	socket.add_child(off)
	off.transform = Transform3D.IDENTITY
	_d.weapon_offhand = off


## Hold kind (characters.md v1.20, SOURCE weapon_holds): WeaponDef.weapon_class -> rifle / smg / sniper / lmg /
## pistol / akimbo (KIND_BY_CLASS; an akimbo pair of pistols is `akimbo`); NPCs without a WeaponDef: rifle / pistol.
func kind_for(def: WeaponDef) -> StringName:
	if def != null:
		if def.weapon_class == Enums.WeaponClass.PISTOL and def.akimbo:
			return &"akimbo"
		return AnimDriver.KIND_BY_CLASS.get(def.weapon_class, &"rifle")
	var npc: NpcBase = _d._npc
	if npc != null:
		if npc.enemy_def != null and npc.enemy_def.params.has("anim_weapon"):
			return StringName(npc.enemy_def.params["anim_weapon"])
		return AnimTweak.data().npc_weapon_anim_by_role.get(npc.role, &"pistol")
	return &"pistol"


## WeaponDef by id without ContentDB's unknown-id error (NPC weapons usually have no WeaponDef).
static func weapon_def(id: StringName) -> WeaponDef:
	if id == &"":
		return null
	if _weapon_defs.is_empty():
		for r: Variant in ContentDB.all_weapons():
			var w: WeaponDef = r as WeaponDef
			if w != null:
				_weapon_defs[w.id] = w
	return _weapon_defs.get(id) as WeaponDef


## v1.20: while the crew body carries a LootBag, its LootDef.bag_model (else the bag's own visual scene) sits at
## Back/Socket (v1.22: the bag pivot) shifted by AnimTweak.carried_bag_offset_by_weight; the LootBag's own visual
## (which follows the carrier's back) is hidden meanwhile. Dropped / thrown / secured: removed, the bag shows again.
func update_bag(tw: AnimTweak) -> void:
	var crew: CrewController = _d._crew
	var bag: Node = crew.carried_bag if crew != null and crew.is_carrying_bag() else null
	if bag == _shown_bag and (bag == null or (_d.bag_visual != null and is_instance_valid(_d.bag_visual))):
		return
	clear_bag()
	var rig: Node3D = _d.rig
	var socket: Node3D = rig.get_node_or_null(^"Skeleton3D/Back/Socket") as Node3D if rig != null else null
	if bag == null or socket == null:
		return
	var lb: LootBag = bag as LootBag
	var def: LootDef = ContentDB.loot(lb.loot_id) if lb != null and lb.loot_id != &"" else null
	var scene: PackedScene = def.bag_model if def != null and def.bag_model != null else null
	if scene == null and lb != null:
		scene = lb.visual_scene if lb.visual_scene != null else LootBag.PLACEHOLDER
	if scene == null:
		return
	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		return
	inst.name = AnimDriver.CARRIED_BAG_NODE
	socket.add_child(inst)
	inst.transform = Transform3D(Basis.IDENTITY, tw.carried_bag_offset_by_weight.get(
		int(lb.weight) if lb != null else Enums.LootWeight.MEDIUM, Vector3.ZERO))
	if lb != null and lb.visual_instance != null and is_instance_valid(lb.visual_instance) and scene == LootBag.PLACEHOLDER:
		inst.scale = lb.visual_instance.scale  # the placeholder is sized by weight class
	if lb != null and lb.visual_root != null:
		lb.visual_root.visible = false
	_d.bag_visual = inst
	_shown_bag = bag


func clear_bag() -> void:
	if _d.bag_visual != null and is_instance_valid(_d.bag_visual):
		_d.bag_visual.get_parent().remove_child(_d.bag_visual)
		_d.bag_visual.queue_free()
	_d.bag_visual = null
	var lb: LootBag = _shown_bag as LootBag if _shown_bag != null and is_instance_valid(_shown_bag) else null
	if lb != null and lb.visual_root != null:
		lb.visual_root.visible = true
	_shown_bag = null


## characters.md v1.27 (D 7dc91bd0): the cartel looks with a gun on the back carry it as `Skeleton3D/Slung`; it clips
## through the chair, so it hides while a seated clip plays (sit_*, desk_work, phone_seated, cower_seated,
## death_seated_*) and shows otherwise. Rigs without the node: nothing.
static func update_slung(rig: Node3D, clip: StringName) -> void:
	var slung: Node3D = rig.get_node_or_null(^"Skeleton3D/Slung") as Node3D if rig != null else null
	if slung != null:
		slung.visible = not seated_clip(clip)


static func seated_clip(clip: StringName) -> bool:
	var c: String = String(clip)
	return c.begins_with("sit_") or c.begins_with("death_seated_") \
		or c in ["desk_work", "phone_seated", "cower_seated"]

