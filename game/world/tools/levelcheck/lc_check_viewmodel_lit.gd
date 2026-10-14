## viewmodel_lit (all stages, WARN only): interior key lights carry render layer 21 `viewmodel_lit`
## (CrewView.VIEWMODEL_LIT_LAYER, `1 << 20`; D-094 / D-095, visual_slots 1.2) in their `layers`, so
## they light the first-person arms and gun as well as the world (next_heist.md §7.11).
## A key light is a visible, active OmniLight3D / SpotLight3D inside a RoomVolume whose purpose is not
## `exterior` / `roof`, that is not a fill light (meta fill = true), and that either casts shadows,
## has energy >= KEY_ENERGY, or is the brightest such light in its room. Never fails the run.
class_name LcCheckViewmodelLit
extends LcCheck

const KEY_ENERGY: float = 0.5
const OUTDOOR_PURPOSES: Array[StringName] = [&"exterior", &"roof"]


func _init() -> void:
	id = &"viewmodel_lit"
	title = "Interior key lights light the viewmodel (D-095)"


static func is_key_candidate(l: Light3D) -> bool:
	return (l is OmniLight3D or l is SpotLight3D) and not LcUtil.meta_b(l, &"fill")


func run(ctx: LcContext) -> void:
	var by_room: Dictionary = {}  # RoomVolume -> Array[Light3D]
	for n: Node in ctx.map.find_children("*", "Light3D", true, false):
		var l: Light3D = n
		if not is_key_candidate(l) or not l.is_visible_in_tree() or not ctx.is_active(l):
			continue
		var room: RoomVolume = ctx.room_at(l.global_position)
		if room == null or room.purpose in OUTDOOR_PURPOSES:
			continue
		if not by_room.has(room):
			by_room[room] = []
		(by_room[room] as Array).append(l)
	var keys: int = 0
	var missing: int = 0
	for room: RoomVolume in by_room.keys():
		var lights: Array = by_room[room]
		var brightest: Light3D = null
		for l2: Light3D in lights:
			if brightest == null or l2.light_energy > brightest.light_energy:
				brightest = l2
		for l3: Light3D in lights:
			if not (l3 == brightest or l3.shadow_enabled or l3.light_energy >= KEY_ENERGY):
				continue
			keys += 1
			if (l3.layers & CrewView.VIEWMODEL_LIT_LAYER) == 0:
				missing += 1
				warn(ctx, l3, null, "key light in room `%s` (energy %.2f%s) lacks render layer 21 `viewmodel_lit` (layers |= %d)"
					% [room.room_id, l3.light_energy, ", shadows" if l3.shadow_enabled else "",
					CrewView.VIEWMODEL_LIT_LAYER])
	note("%d interior key light(s) in %d room(s); %d lack `viewmodel_lit` (WARN)" % [keys, by_room.size(), missing])
