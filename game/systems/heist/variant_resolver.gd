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
##   excludes        {other_group: [slot_ids]}: pick 0 if any listed slot is active (D-025 QA-3).
## Rules may only reference groups resolved by EARLIER rules (heist_map.md v1.1); a forward or
## unknown reference is a contract violation (Log.error) and counts as "not active".
## Slots whose group has no rule stay active (logged as a warning).
## Rare events are rolled first; `force_active` effects pin a slot active in its group.
## A2-08 fields (all optional; a table without them rolls exactly as before, same seed = same result):
##   force_if        [{"if": {other_group: [slot_ids]}, "then": [slot_ids of this group]}]: when every
##                   group of `if` has any listed slot active (empty list = any), the `then` slots are
##                   pinned active like `force_active` (added first, count toward the rolled pick,
##                   kept even above it, and applied even when requires/excludes zero the pick).
##   slot_requires   {slot_id: {other_group: [slot_ids]}}: that slot is only eligible for the weighted
##                   pick if its condition holds (same semantics as `requires`). Pinned slots ignore it.
##   rare min_difficulty  int: the event's chance draw is always made, then the event only fires at
##                   difficulty >= min_difficulty (so other events' results never depend on it).
##   scalar weights_by_difficulty  {difficulty int: PackedFloat32Array}: replaces `weights` at that
##                   difficulty (missing difficulty = `weights`).
## Every group referenced by force_if / slot_requires must be resolved earlier (else Log.error, not active).
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
## `forced_extra`: group -> [slot_ids] pinned active like rare `force_active` (C3 pre-planning
## assets, PreplanAssets.forced_variants()).
static func resolve(table: HeistVariantTable, slots_by_group: Dictionary, difficulty: int,
		forced_extra: Dictionary = {}) -> Dictionary:
	var rng: RandomNumberGenerator = GameRng.stream(STREAM)
	var result: Dictionary = {}
	var rare: Array[StringName] = []
	var forced: Dictionary = {}  # group -> Array[StringName]
	for fg0: Variant in forced_extra:
		forced[StringName(fg0)] = (forced_extra[fg0] as Array).duplicate()
	if table != null:
		for ev: Dictionary in table.rare_events:
			var chance: float = float(ev.get("chance", 0.0))
			# Always draw (A2-08): gating by difficulty must not shift later events' draws.
			var hit: bool = rng.randf() < chance
			if hit and ev.has("min_difficulty") and difficulty < int(ev["min_difficulty"]):
				hit = false
			if hit:
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
			_validate_refs(rule, result, group)
			if not _conditions_ok(rule, result):
				n = 0
			var chosen: Array[StringName] = []
			var pins: Array = (forced.get(group, []) as Array).duplicate()
			pins.append_array(_force_if_slots(rule, result, slots, group))
			for f: Variant in pins:
				var fid: StringName = StringName(f)
				if _has_slot(slots, fid) and not chosen.has(fid):
					chosen.append(fid)
			var slot_req: Dictionary = {}  # String(slot_id) -> condition (String or StringName keys accepted)
			var sr0: Dictionary = rule.get("slot_requires", {})
			for k: Variant in sr0:
				slot_req[String(k)] = sr0[k]
			var pool: Array = []
			for s: VariantSlot in slots:
				if chosen.has(s.slot_id):
					continue
				if slot_req.has(String(s.slot_id)) and not _all_hold(slot_req[String(s.slot_id)], result):
					continue
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
			var weights: PackedFloat32Array = _scalar_weights(sc, difficulty)
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


static func _validate_refs(rule: Dictionary, so_far: Dictionary, group: StringName) -> void:
	for key: String in ["requires", "excludes"]:
		_check_refs(rule.get(key, {}), so_far, group, key)
	var fi: Variant = rule.get("force_if", [])
	if fi is Array:
		for entry: Variant in fi:
			if entry is Dictionary:
				_check_refs((entry as Dictionary).get("if", {}), so_far, group, "force_if")
			else:
				Log.error(&"variants", "rule '%s' force_if entries must be {\"if\": {...}, \"then\": [...]}" % group)
	else:
		Log.error(&"variants", "rule '%s' force_if must be an Array" % group)
	var sr: Dictionary = rule.get("slot_requires", {})
	for sid: Variant in sr:
		_check_refs(sr[sid], so_far, group, "slot_requires[%s]" % sid)


static func _check_refs(refs: Variant, so_far: Dictionary, group: StringName, key: String) -> void:
	if not refs is Dictionary:
		Log.error(&"variants", "rule '%s' %s must be {group: [slot_ids]}" % [group, key])
		return
	for og: Variant in refs:
		if not so_far.has(StringName(og)):
			Log.error(&"variants", "contract violation: rule '%s' %s group '%s' which is not resolved earlier in the table" % [group, key, og])


## A2-08: slots of `group` pinned by the rule's `force_if` entries whose condition holds.
static func _force_if_slots(rule: Dictionary, so_far: Dictionary, slots: Array, group: StringName) -> Array:
	var out: Array = []
	var fi: Variant = rule.get("force_if", [])
	if not fi is Array:
		return out
	for entry: Variant in fi:
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry
		if not _all_hold(e.get("if", {}), so_far):
			continue
		var then_ids: Variant = e.get("then", [])
		if not then_ids is Array:
			continue
		for t: Variant in then_ids:
			if not _has_slot(slots, StringName(t)):
				Log.warn(&"variants", "rule '%s' force_if pins unknown slot '%s'" % [group, t])
				continue
			out.append(StringName(t))
	return out


## Every group of `cond` ({group: [slot_ids]}) has a listed slot active (empty list = any slot).
static func _all_hold(cond: Variant, so_far: Dictionary) -> bool:
	if not cond is Dictionary:
		return false
	var c: Dictionary = cond
	for og: Variant in c:
		if not _any_active(so_far, StringName(og), c[og]):
			return false
	return true


## A2-08: per-difficulty override of a scalar's weights.
static func _scalar_weights(sc: Dictionary, difficulty: int) -> PackedFloat32Array:
	var by_diff: Variant = sc.get("weights_by_difficulty", {})
	if by_diff is Dictionary and (by_diff as Dictionary).has(difficulty):
		var w: Variant = (by_diff as Dictionary)[difficulty]
		if w is PackedFloat32Array:
			return w
		if w is Array or w is PackedFloat64Array:
			return PackedFloat32Array(w)
		Log.error(&"variants", "scalar '%s' weights_by_difficulty[%d] must be a PackedFloat32Array" % [sc.get("id", &""), difficulty])
	return sc.get("weights", PackedFloat32Array())


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
