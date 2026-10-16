## Pre-planning numbers and blueprint colors (B2-01). Owner: ENV B.
## Data: res://content/data/preplanning/preplan_tweak.tres.
class_name PreplanTweak
extends Resource

const DEFAULT_PATH: String = "res://content/data/preplanning/preplan_tweak.tres"

## Asset cash multiplier per Enums.Difficulty (index). PD2: a doctor bag drop costs $1,600 on Normal
## and $20,800 on Death Wish (x13). ◇ The steps between are ours.
@export var cost_mult: Array[float] = [1.0, 2.0, 4.0, 6.5, 9.5, 13.0]
## Scaled costs are rounded to a multiple of this.
@export var cost_round: int = 100
## Favors per heist day when HeistDef.preplanning has no "favors" (PD2 Big Bank: 10).
@export var default_favors: int = 10
## Order of asset categories in the UI; categories missing here follow, sorted.
@export var category_order: Array[StringName] = [&"supply", &"intel", &"gear", &"entry", &"access", &"escape"]

@export_group("Blueprint colors")
@export var paper_color: Color = Color(0.06, 0.13, 0.22)
@export var grid_color: Color = Color(0.25, 0.42, 0.62, 0.22)
@export var grid_major_color: Color = Color(0.35, 0.55, 0.78, 0.38)
@export var line_color: Color = Color(0.72, 0.85, 1.0, 0.9)
@export var label_color: Color = Color(0.72, 0.85, 1.0, 0.75)
## Opacity of the paper-coloured plate behind blueprint point labels (lines under a label stay readable as lines).
@export var label_plate_alpha: float = 0.8
## Shape fill per blueprint shape kind.
@export var shape_fill: Dictionary = {
	&"building": Color(0.2, 0.36, 0.56, 0.55),
	&"room": Color(0.24, 0.42, 0.64, 0.45),
	&"neighbour": Color(0.12, 0.2, 0.3, 0.7),
	&"street": Color(0.09, 0.16, 0.26, 0.6),
	&"sidewalk": Color(0.14, 0.24, 0.36, 0.6),
	&"alley": Color(0.11, 0.19, 0.3, 0.6),
}
@export var point_color: Color = Color(0.85, 0.9, 1.0)
@export var point_owned_color: Color = Color(1.0, 0.75, 0.25)
@export var point_vote_color: Color = Color(0.45, 0.85, 0.6)
@export var placeholder_color: Color = Color(1.0, 0.45, 0.35)
@export var reason_color: Color = Color(1.0, 0.45, 0.35)
## Marker button diameter in base (1920x1080) pixels.
@export var marker_size: float = 46.0


static func load_default() -> PreplanTweak:
	var tw: PreplanTweak = null
	if ResourceLoader.exists(DEFAULT_PATH):
		tw = load(DEFAULT_PATH) as PreplanTweak
	return tw if tw != null else PreplanTweak.new()


func mult_for(difficulty: int) -> float:
	if cost_mult.is_empty():
		return 1.0
	return cost_mult[clampi(difficulty, 0, cost_mult.size() - 1)]


## Spending cash for `base_cost` at `difficulty`, rounded to cost_round.
func scaled_cost(base_cost: int, difficulty: int) -> int:
	var raw: float = float(base_cost) * mult_for(difficulty)
	var r: int = maxi(cost_round, 1)
	return roundi(raw / float(r)) * r
