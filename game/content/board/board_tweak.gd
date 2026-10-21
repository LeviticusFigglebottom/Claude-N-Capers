## Board + contract broker numbers (pd2_fidelity C1, roadmap B4-06). Owner: ENV B.
## Data: res://content/data/board/board_tweak.tres. Design: res://content/docs/board.md.
## Arrays indexed by difficulty have one entry per Enums.Difficulty value (Routine..Cataclysm).
class_name BoardTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/board/board_tweak.tres"

@export_group("Rotation")
## Board seed. Every contract is a pure function of (seed, slot, time bucket, player level).
@export var board_seed: int = 0
## Contracts on the board at once (one per slot).
@export var slot_count: int = 8
## Lifetime of one contract in real-time seconds; a slot gets a new contract every rotation_s.
@export var rotation_s: float = 600.0
## Spread the slots' rotations evenly over rotation_s (one contract expires at a time, like
## CRIME.NET) instead of replacing the whole board at once.
@export var stagger_slots: bool = true

@export_group("Difficulty")
## Relative odds of each difficulty on a generated contract (only unlocked ones are rolled).
@export var difficulty_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
## Reputation level a player needs to see or buy a difficulty. D-151: Lethal / Cataclysm at 70 (PD2 gates the top
## tiers at 80; D-148's PD2-length curve made 80 ~230 Brutal clears, 70 keeps the old time-to-Lethal, ~135).
@export var difficulty_min_level: Array[int] = [0, 0, 0, 0, 70, 70]
## Also require the build-wide unlock list (heist_list.tres unlocked_difficulties, the P1 gate).
@export var respect_build_unlocks: bool = true

@export_group("Pro jobs")
## Chance that a generated contract is a pro job (no restarts, PayoutTweak.pro_job_xp_mult XP).
@export_range(0.0, 1.0) var pro_chance: float = 0.2
## Lowest difficulty a pro job can roll on (PD2: pro jobs start one tier above the lowest).
@export var pro_min_difficulty: int = 1

@export_group("Contacts")
## Contacts drawn (deterministically) for a heist that names none in its HeistDef or the city map.
@export var fallback_contacts: Array[StringName] = []

@export_group("Broker")
## Stash cost to buy any contract, per difficulty.
@export var broker_cost_by_difficulty: Array[int] = [0, 0, 0, 0, 0, 0]
## Plus this fraction of the contract pay preview (pricier heists cost more to buy).
@export var broker_cost_payout_fraction: float = 0.0

@export_group("Map")
## Pin scatter around a heist's anchor, in map units (0..1 of the map width/height).
@export var pin_jitter: float = 0.03
## Pins stay this far from the map edge (map units).
@export var pin_margin: float = 0.04


static func load_default() -> BoardTweak:
	var t: BoardTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		t = load(DEFAULT_PATH) as BoardTweak
	if t == null:
		Log.error(&"content", "board tweak missing: %s" % DEFAULT_PATH)
		t = BoardTweak.new()
	return t


func weight_of(difficulty: int) -> float:
	return difficulty_weights[difficulty] if difficulty >= 0 and difficulty < difficulty_weights.size() else 0.0


func min_level_of(difficulty: int) -> int:
	return difficulty_min_level[difficulty] if difficulty >= 0 and difficulty < difficulty_min_level.size() else 0


func broker_base_cost(difficulty: int) -> int:
	if difficulty < 0 or difficulty >= broker_cost_by_difficulty.size():
		return 0
	return broker_cost_by_difficulty[difficulty]
