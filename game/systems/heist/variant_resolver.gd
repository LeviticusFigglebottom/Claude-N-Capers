## Rolls a heist's dynamic variables once, on the server, before NPCs spawn. Owner: ENV A.
## Contract: docs/contracts/heist_map.md §5. This is the ONLY code that rolls heist variables (D-006).
##
## Result (replicated + logged): { group: [active slot_ids (sorted)], scalar_id: value, "rare": [ids] }
##
## Rule semantics (HeistVariantTable.rules, processed in array order):
##   pick            Vector2i [min, max] active slots, rolled uniformly, clamped to slot count.
##   difficulty_add  Array[int] indexed by Enums.Difficulty: extra picks.
##   requires        {other_group: [slot_ids]}: roll only if any listed slot is active (else 0 picks).
##                   An empty list means "any slot of other_group".
##   excludes        {other_group: [slot_ids]}: pick 0 if any listed slot is active (QA-3 to confirm).
## Slots whose group has no rule stay active (logged as a warning).
## Rare events are rolled first; `force_active` effects pin a slot active in its group.
class_name VariantResolver
extends RefCounted

const STREAM: StringName = &"variants"
const RARE_KEY: String = "rare"


## Collect VariantSlots under `root` (works before the map enters the tree), keyed by group.
static func collect_slots(root: Node) -> Dictionary:
	var out: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var vs: VariantSlot = n as VariantSlot
		if vs != null:
			if not out.has(vs.slot_group):
				out[vs.slot_group] = []
			(out[vs.slot_group] as Array).append(vs)
		for c: Node in n.get_children():
			stack.append(c)
	for g: Variant in out:
		(out[g] as Array).sort_custom(func(a: VariantSlot, b: VariantSlot) -> bool: return String(a.slot_id) < String(b.slot_id))
	return out


## Pure roll. `slots_by_group`: group -> Array[VariantSlot] (sorted by slot_id).
static func resolve(table: HeistVariantTable, slots_by_group: Dictionary, difficulty: int) -> Dictionary:
	var rng: RandomNumberGenerator = GameRng.stream(STREAM)
	var result: Dictionary = {}
	var rare: Array[StringName] = []
	var forced: Dictionary = {}  # group -> Array[StringName]
	if table != null:
		for ev: Dictionary in table.rare_events:
			var chance: float = float(ev.get("chance", 0.0))
			if rng.randf() < chance:
				var ev_id: StringName = StringName(ev.get("id", &""))
				rare.append(ev_id)
				var fx: Dictionary = ev.get("effects", {})
				if fx.has("force_active"):
					var fa: Dictionary = fx["force_active"]
					var fg: StringName = StringName(fa.get("group", &""))
					if not forced.has(fg):
						forced[fg] = []
					(forced[fg] as Array).append(StringName(fa.get("slot", &"")))
	var ruled: Dictionary = {}
	if table != null:
		for rule: Dictionary in table.rules:
			var group: StringName = StringName(rule.get("group", &""))
			ruled[group] = true
			var slots: Array = slots_by_group.get(group, [])
			if slots.is_empty():
				Log.warn(&"variants", "rule for group '%s' has no VariantSlots in the map" % group)
				result[group] = []
				continue
			var pick: Vector2i = rule.get("pick", Vector2i(1, 1))
			var n: int = rng.randi_range(mini(pick.x, pick.y), maxi(pick.x, pick.y))
			var dadd: Array = rule.get("difficulty_add", [])
			if difficulty >= 0 and difficulty < dadd.size():
				n += int(dadd[difficulty])
			if not _conditions_ok(rule, result):
				n = 0
			var chosen: Array[StringName] = []
			for f: StringName in forced.get(group, []):
				if _has_slot(slots, f) and not chosen.has(f):
					chosen.append(f)
			var pool: Array = []
			for s: VariantSlot in slots:
				if not chosen.has(s.slot_id):
					pool.append(s)
			while chosen.size() < mini(n, slots.size()) and not pool.is_empty():
				var w: PackedFloat32Array = PackedFloat32Array()
				for s: VariantSlot in pool:
					w.append(maxf(s.weight, 0.0))
				var idx: int = rng.rand_weighted(w)
				if idx < 0:
					idx = 0
				chosen.append((pool[idx] as VariantSlot).slot_id)
				pool.remove_at(idx)
			chosen.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			result[group] = chosen
		for sc: Dictionary in table.scalars:
			var values: Array = sc.get("values", [])
			if values.is_empty():
				continue
			var weights: PackedFloat32Array = sc.get("weights", PackedFloat32Array())
			var vi: int = 0
			if weights.size() == values.size():
				vi = maxi(rng.rand_weighted(weights), 0)
			else:
				vi = rng.randi_range(0, values.size() - 1)
			result[StringName(sc.get("id", &""))] = values[vi]
	for group: Variant in slots_by_group:
		if not ruled.has(group):
			Log.warn(&"variants", "slot group '%s' has no rule; all its slots stay active" % group)
			var all_ids: Array[StringName] = []
			for s: VariantSlot in slots_by_group[group]:
				all_ids.append(s.slot_id)
			result[group] = all_ids
	result[RARE_KEY] = rare
	return result


## Remove inactive slots' children and instantiate active slots' prefabs. Call before the map
## enters the tree. Returns [ [prefab_instance, params], ... ] for configure_variant() after _ready.
static func apply(slots_by_group: Dictionary, resolved: Dictionary) -> Array:
	var pending: Array = []
	for group: Variant in slots_by_group:
		var active: Array = resolved.get(group, [])
		for s: VariantSlot in slots_by_group[group]:
			if active.has(s.slot_id):
				s.visible = true
				if s.prefab != null:
					var inst: Node = s.prefab.instantiate()
					s.add_child(inst)
					pending.append([inst, s.params])
			else:
				s.visible = false
				for c: Node in s.get_children():
					s.remove_child(c)
					c.free()
	return pending


## After the map is in the tree: hand params to prefabs that accept them.
static func configure_pending(pending: Array) -> void:
	for p: Array in pending:
		var inst: Node = p[0]
		if is_instance_valid(inst) and inst.has_method(&"configure_variant"):
			inst.call(&"configure_variant", p[1])


static func _has_slot(slots: Array, slot_id: StringName) -> bool:
	for s: VariantSlot in slots:
		if s.slot_id == slot_id:
			return true
	return false


static func _conditions_ok(rule: Dictionary, so_far: Dictionary) -> bool:
	var req: Dictionary = rule.get("requires", {})
	for og: Variant in req:
		if not _any_active(so_far, StringName(og), req[og]):
			return false
	var exc: Dictionary = rule.get("excludes", {})
	for og: Variant in exc:
		if _any_active(so_far, StringName(og), exc[og]):
			return false
	return true


static func _any_active(so_far: Dictionary, group: StringName, ids: Variant) -> bool:
	var active: Array = so_far.get(group, [])
	var wanted: Array = ids if ids is Array else []
	if wanted.is_empty():
		return not active.is_empty()
	for i: Variant in wanted:
		if active.has(StringName(i)):
			return true
	return false
