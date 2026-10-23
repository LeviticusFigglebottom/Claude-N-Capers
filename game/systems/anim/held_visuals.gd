## AnimDriver's third-person held visuals: the WeaponVisual at HandR/Socket (v1.20 akimbo: the offhand gun at
## HandL/Socket) and the v1.20 carried-bag visual at Back/Socket. Owner: ENV A. Presentation only. The visual nodes
## and the weapon facts (weapon_visual, weapon_offhand, bag_visual, weapon_kind, weapon_class) stay on the driver;
## this RefCounted helper (back-reference `_d`, like CombatClips) builds and clears them.
class_name HeldVisuals
extends RefCounted

## Same hysteresis as the body's CrowdLod switch (CrowdLod.MARGIN_M).
const WEAPON_RANGE_MARGIN_M: float = 1.0
const SILHOUETTES_PATH: String = G.CHARACTERS_DIR + "_props/weapon_silhouettes/weapon_silhouettes.json"
const SILHOUETTE_NODE: String = "WeaponSilhouette"
## Spawn tags of plain-clothes armed NPCs: holstered until ALARMED / COMBAT (plain_clothes_holstered).
const PLAIN_CLOTHES_TAGS: Array[StringName] = [&"civ_offduty"]

static var _weapon_defs: Dictionary = {}
## weapon_silhouettes.json `silhouettes` (NPC weapon id -> scene path), loaded once; {} without the file.
static var _silhouettes: Variant = null

var _d: AnimDriver = null
## v1.20: the LootBag the carried-bag visual shows.
var _shown_bag: Node = null
## The NPC held weapon's geometry (OF perf: range-culled at the body's CrowdLod switch, shadows by AnimLod band).
var _weapon_gis: Array[GeometryInstance3D] = []
## The far silhouette beside the NPC's WeaponVisual (null when none).
var _silhouette: Node3D = null


func _init(driver: AnimDriver) -> void:
	_d = driver


## Rebuild the third-person weapon at `HandR/Socket` (crew: equipped weapon; NPC: EnemyDef.weapon).
func refresh_weapon() -> void:
	for n: Node3D in [_d.weapon_visual, _d.weapon_offhand, _silhouette]:
		if n != null and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_d.weapon_visual = null
	_d.weapon_offhand = null
	_silhouette = null
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
	if crew == null and wv.has_method(&"setup_npc"):
		wv.call(&"setup_npc", def)  # LEAD r244 (b): NPCs carry the merged one-surface gun (B c7d83262)
	else:
		wv.setup(def, LoadoutResolver.applied_mods(def, mod_ids))
	_d.weapon_visual = wv
	_place_offhand(wv)
	if npc != null:
		_crowd_cull(rig, wv)
		_add_silhouette(socket, npc.enemy_def.weapon if npc.enemy_def != null else &"")


## OF cast perf audit (D ca74efe3): an NPC's held weapon (~14 meshes) stops drawing where its body switches to the
## CrowdLod mesh (the body meshes' visibility_range_end: 25 m units, 15 m civilians), and casts shadows only in the
## FULL AnimLod band (set_weapon_shadows). Crew bodies keep theirs (the local player's view).
func _crowd_cull(rig: Node3D, wv: WeaponVisual) -> void:
	var switch_m: float = 0.0
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not wv.is_ancestor_of(mi) and mi.visibility_range_end > switch_m:
			switch_m = mi.visibility_range_end
	_weapon_gis = _geometry(wv)
	if _d.weapon_offhand != null:
		_weapon_gis.append_array(_geometry(_d.weapon_offhand))
	for gi: GeometryInstance3D in _weapon_gis:
		if switch_m > 0.0:
			gi.visibility_range_end = switch_m
			gi.visibility_range_end_margin = WEAPON_RANGE_MARGIN_M
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	set_weapon_shadows(_d.lod == null or _d.lod.band == AnimLod.Band.FULL)


## ENV D far weapon silhouettes (weapon_silhouettes.json, D 9216f31f): past the switch the full weapon is culled and
## a one-draw, shadowless side profile in the same weapon frame takes over (the scene carries its own
## visibility_range_begin). A sibling of the WeaponVisual under HandR/Socket, freed with it on refresh.
func _add_silhouette(socket: Node3D, weapon_id: StringName) -> void:
	if _silhouettes == null:
		_silhouettes = {}
		if FileAccess.file_exists(SILHOUETTES_PATH):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SILHOUETTES_PATH))
			if data is Dictionary:
				_silhouettes = (data as Dictionary).get("silhouettes", {})
	var path: String = String((_silhouettes as Dictionary).get(String(weapon_id), ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var inst: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	if inst == null:
		return
	inst.name = SILHOUETTE_NODE
	socket.add_child(inst)
	inst.transform = Transform3D.IDENTITY
	_silhouette = inst


## The far silhouette follows the held weapon's visibility (holstered / surrendering: neither shows).
func show_silhouette(on: bool) -> void:
	if _silhouette != null and is_instance_valid(_silhouette):
		_silhouette.visible = on


## AnimLod: shadows on the NPC's held weapon only while its body animates in the FULL band.
func set_weapon_shadows(on: bool) -> void:
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gi: GeometryInstance3D in _weapon_gis:
		if is_instance_valid(gi):
			gi.cast_shadow = mode


static func _geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for n: Node in root.find_children("*", "GeometryInstance3D", true, false):
		out.append(n as GeometryInstance3D)
	if root is GeometryInstance3D:
		out.append(root as GeometryInstance3D)
	return out


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


## D's AH cast review (r308_offduty.png): a plain-clothes observer (PLAIN_CLOTHES_TAGS on his spawn: the AH off-duty
## cop) keeps his gun holstered in the crowd until he radios the alarm or fights (ALARMED / COMBAT). The tags travel with
## the spawn descriptor, so every peer agrees (AnimDriver.weapon_shown).
static func plain_clothes_holstered(npc: NpcBase) -> bool:
	if npc == null or npc.alert_state == Enums.AlertState.ALARMED or npc.alert_state == Enums.AlertState.COMBAT:
		return false
	var tags: Array = npc.spawn_info.get("tags", []) as Array
	for t: StringName in PLAIN_CLOTHES_TAGS:
		if tags.has(t):
			return true
	return false


static func seated_clip(clip: StringName) -> bool:
	var c: String = String(clip)
	return c.begins_with("sit_") or c.begins_with("death_seated_") \
		or c in ["desk_work", "phone_seated", "cower_seated"]

