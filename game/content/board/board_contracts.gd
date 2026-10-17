## The Board's contract generator (pd2_fidelity C1, roadmap B4-06). Owner: ENV B. Pure and static.
##
## Rotation: slot i of BoardTweak.slot_count holds one contract per time bucket
##   bucket(i, t) = floor((t + offset_i) / rotation_s), offset_i = rotation_s * i / slot_count when
##   stagger_slots (else 0), t = real time in Unix seconds.
## Determinism: each contract rolls on its OWN RandomNumberGenerator, seeded explicitly with
##   hash([BoardTweak.board_seed, slot, bucket]) (never the global RNG; GameRng is per heist run and
##   the board lives outside runs). Same seed + slot + bucket + player level + heist pool = same
##   contract on every machine, so a crew with synced clocks sees the same board.
## Rolls, in this fixed order: heist (uniform over the pool; by the pool's "weight" when the weights differ, same one
##   draw), difficulty (BoardTweak.difficulty_weights
##   over the unlocked ones), pro roll (always drawn; pro when difficulty >= pro_min_difficulty and
##   roll < pro_chance), contact pick (drawn always; used only when the heist names no contact), pin
##   jitter x, y.
##
## Pool entry (pool()): { "id": StringName, "base_payout": int (UNSCALED), "mode": int,
##   "contact": StringName ("" = pick from fallback_contacts), "weight": float, "pro": bool, "difficulty_min": int }
##   (the last three from the city map's heist entry, OF-B1; defaults 1.0 / true / Routine).
## Contract (generate()/contract_for()): { "slot": int, "bucket": int, "heist_id": StringName,
##   "difficulty": int, "is_pro": bool, "contact_id": StringName, "payout": int (contract pay preview,
##   PayoutCalculator-consistent), "base_payout": int, "mode": int,
##   "district": StringName, "map_pos": Vector2 (map units), "starts_at": float, "expires_at": float }
##   BoardScreen adds "consumed": bool (a failed pro job, no restart; QB-BRD1).
class_name BoardContracts
extends RefCounted


## Heists offered on the board: HeistCatalog.entries() (registry def + map scene, QB-55), with the
## contact from HeistDef.contact, else the city map's entry.
static func pool(city: BoardCityMap = null) -> Array[Dictionary]:
	return pool_from(HeistCatalog.entries(), city if city != null else BoardCityMap.load_default())


## Pure builder behind pool() (tests): `entries` in HeistCatalog.entries() shape.
static func pool_from(entries: Array[Dictionary], city: BoardCityMap) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var id: StringName = StringName(e.get("id", &""))
		var def: HeistDef = e.get("def") as HeistDef
		var contact: StringName = def.contact if def != null else &""
		if contact == &"" and city != null:
			contact = city.heist_contact(id)
		out.append({
			"id": id, "base_payout": int(e.get("base_payout", 0)), "mode": int(e.get("mode", 0)),
			"contact": contact,
			"weight": city.heist_weight(id) if city != null else 1.0,
			"pro": city.heist_pro(id) if city != null else true,
			"difficulty_min": city.heist_difficulty_min(id) if city != null else 0,
		})
	return out


## Difficulties a player of `level` may get or buy, ascending. `build_unlocked` (optional) is a
## Callable(int) -> bool for the build-wide gate (HeistCatalog.is_difficulty_unlocked).
static func allowed_difficulties(level: int, tweak: BoardTweak, build_unlocked: Callable = Callable()) -> Array[int]:
	var out: Array[int] = []
	for d: int in range(Enums.Difficulty.size()):
		if level < tweak.min_level_of(d):
			continue
		if tweak.respect_build_unlocks and build_unlocked.is_valid() and not bool(build_unlocked.call(d)):
			continue
		out.append(d)
	return out


## Why difficulty `d` is locked, naming every condition that applies (lead r216: the rep level gate stacks on the
## D-117 progression unlock): "Lethal (level 80, win on Brutal)", "(level 80)", "(win on Brutal)" or "(locked)".
static func locked_text(d: int, level: int, tweak: BoardTweak, build_unlocked: Callable = Callable()) -> String:
	var name_text: String = UiText.t(UiText.difficulty_key(d))
	var need_level: bool = level < tweak.min_level_of(d)
	var need_win: bool = build_unlocked.is_valid() and not bool(build_unlocked.call(d)) \
			and HeistCatalog.is_progression_difficulty(d) and d > 0
	var prev: String = UiText.t(UiText.difficulty_key(maxi(d - 1, 0)))
	if need_level and need_win:
		return UiText.t(&"ui.board.broker.locked_both", {"name": name_text, "level": tweak.min_level_of(d), "prev": prev})
	if need_level:
		return UiText.t(&"ui.board.broker.locked_level", {"name": name_text, "level": tweak.min_level_of(d)})
	if need_win:
		return UiText.t(&"ui.board.broker.locked_progress", {"name": name_text, "prev": prev})
	return UiText.t(&"ui.heist_select.difficulty_locked", {"name": name_text})


## The default build gate used by the screen.
static func build_gate() -> Callable:
	return func(d: int) -> bool: return HeistCatalog.is_difficulty_unlocked(d)


static func slot_offset(slot: int, tweak: BoardTweak) -> float:
	if not tweak.stagger_slots or tweak.slot_count <= 0:
		return 0.0
	return tweak.rotation_s * float(slot) / float(tweak.slot_count)


static func bucket_of(slot: int, now: float, tweak: BoardTweak) -> int:
	return floori((now + slot_offset(slot, tweak)) / maxf(tweak.rotation_s, 1.0))


## Every slot's live contract at Unix time `now`, sorted by slot. Empty when the pool is empty.
static func generate(now: float, level: int, heist_pool: Array[Dictionary], tweak: BoardTweak,
		city: BoardCityMap, build_unlocked: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if heist_pool.is_empty():
		return out
	var allowed: Array[int] = allowed_difficulties(level, tweak, build_unlocked)
	for slot: int in range(tweak.slot_count):
		out.append(contract_for(slot, bucket_of(slot, now, tweak), allowed, heist_pool, tweak, city))
	return out


## One slot's contract for one bucket. `allowed` = allowed_difficulties(); empty falls back to Routine.
static func contract_for(slot: int, bucket: int, allowed: Array[int], heist_pool: Array[Dictionary],
		tweak: BoardTweak, city: BoardCityMap) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([tweak.board_seed, slot, bucket])
	var heist: Dictionary = _pick_heist(rng, heist_pool)
	var floor_d: int = int(heist.get("difficulty_min", 0))
	var heist_allowed: Array[int] = []
	for d: int in allowed:
		if d >= floor_d:
			heist_allowed.append(d)
	var difficulty: int = _pick_difficulty(rng, heist_allowed if not heist_allowed.is_empty() else allowed, tweak)
	var pro_roll: float = rng.randf()
	var is_pro: bool = difficulty >= tweak.pro_min_difficulty and pro_roll < tweak.pro_chance \
			and bool(heist.get("pro", true))
	var contact: StringName = StringName(heist.get("contact", &""))
	var contact_pick: int = rng.randi_range(0, maxi(tweak.fallback_contacts.size() - 1, 0))
	if contact == &"" and not tweak.fallback_contacts.is_empty():
		contact = tweak.fallback_contacts[contact_pick]
	var id: StringName = StringName(heist["id"])
	var jitter: Vector2 = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * tweak.pin_jitter
	var pos: Vector2 = (city.heist_anchor(id) if city != null else Vector2(0.5, 0.5)) + jitter
	var lo: float = tweak.pin_margin
	pos = Vector2(clampf(pos.x, lo, 1.0 - lo), clampf(pos.y, lo, 1.0 - lo))
	var period: float = maxf(tweak.rotation_s, 1.0)
	var starts: float = float(bucket) * period - slot_offset(slot, tweak)
	return {
		"slot": slot, "bucket": bucket, "heist_id": id, "difficulty": difficulty, "is_pro": is_pro,
		"contact_id": contact, "payout": HeistCatalog.contract_preview(int(heist.get("base_payout", 0)), difficulty),
		"base_payout": int(heist.get("base_payout", 0)), "mode": int(heist.get("mode", 0)),
		"district": city.heist_district(id) if city != null else &"",
		"map_pos": pos, "starts_at": starts, "expires_at": starts + period,
	}


## Stable identity of one contract (slot + rotation bucket): the key a consumed pro job is locked
## under (QB-BRD1). The next bucket of the same slot is a new contract.
static func contract_key(contract: Dictionary) -> String:
	return "%d:%d" % [int(contract.get("slot", -1)), int(contract.get("bucket", 0))]


## Seconds until `contract` expires (>= 0).
static func time_left(contract: Dictionary, now: float) -> float:
	return maxf(float(contract.get("expires_at", 0.0)) - now, 0.0)


## Earliest expiry among `contracts` (INF when empty): when the board must regenerate.
static func next_expiry(contracts: Array[Dictionary]) -> float:
	var t: float = INF
	for c: Dictionary in contracts:
		t = minf(t, float(c.get("expires_at", INF)))
	return t


## The heist of one roll: uniform (one randi_range, the shipped draw) while every pool weight is equal, else one
## weighted randf draw (OF-B1 Board weights).
static func _pick_heist(rng: RandomNumberGenerator, heist_pool: Array[Dictionary]) -> Dictionary:
	var w0: float = float(heist_pool[0].get("weight", 1.0))
	var total: float = 0.0
	var equal: bool = true
	for h: Dictionary in heist_pool:
		var w: float = maxf(float(h.get("weight", 1.0)), 0.0)
		total += w
		equal = equal and is_equal_approx(w, w0)
	if equal or total <= 0.0:
		return heist_pool[rng.randi_range(0, heist_pool.size() - 1)]
	var roll: float = rng.randf() * total
	for h: Dictionary in heist_pool:
		roll -= maxf(float(h.get("weight", 1.0)), 0.0)
		if roll < 0.0:
			return h
	return heist_pool.back()


static func _pick_difficulty(rng: RandomNumberGenerator, allowed: Array[int], tweak: BoardTweak) -> int:
	var total: float = 0.0
	for d: int in allowed:
		total += maxf(tweak.weight_of(d), 0.0)
	var roll: float = rng.randf() * total
	if allowed.is_empty():
		return Enums.Difficulty.ROUTINE
	for d: int in allowed:
		roll -= maxf(tweak.weight_of(d), 0.0)
		if roll < 0.0:
			return d
	return allowed[allowed.size() - 1]
