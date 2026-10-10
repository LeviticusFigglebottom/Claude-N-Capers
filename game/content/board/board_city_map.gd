## The Board's stylised city map (pd2_fidelity C1). Owner: ENV B. Original vector art drawn in code
## by BoardMapView from this data: res://content/data/board/city_map.tres.
## Coordinates are map units: (0, 0) top-left to (1, 1) bottom-right; the map is drawn at `aspect`
## (width / height) and letterboxed into its control.
class_name BoardCityMap
extends Resource

const DEFAULT_PATH: String = "res://content/data/board/city_map.tres"

## Width / height of the drawn map.
@export var aspect: float = 1.6
## district id -> { "polygon": PackedVector2Array, "color": Color, "label_pos": Vector2 (optional;
## default the polygon's average point) }. Display name:
## strings.csv `ui.board.district.<id>`.
@export var districts: Dictionary = {}
## Water areas (bay, harbor) as polygons.
@export var water: Array[PackedVector2Array] = []
## Rivers and canals as centre lines, drawn `river_width` wide.
@export var rivers: Array[PackedVector2Array] = []
@export var river_width: float = 0.035
## Major roads (drawn wide) and minor streets (drawn thin), as polylines.
@export var avenues: Array[PackedVector2Array] = []
@export var streets: Array[PackedVector2Array] = []
## heist id -> { "pos": Vector2 (map units), "district": StringName, "contact": StringName (optional,
## used when the HeistDef names no contact) }. Heists missing here get a deterministic spot in
## `fallback_area`.
@export var heists: Dictionary = {}
@export var fallback_area: Rect2 = Rect2(0.3, 0.3, 0.4, 0.4)

@export_group("Colours")
@export var land_color: Color = Color(0.1, 0.11, 0.13, 1)
@export var water_color: Color = Color(0.08, 0.13, 0.19, 1)
@export var avenue_color: Color = Color(0.4, 0.42, 0.46, 1)
@export var street_color: Color = Color(0.3, 0.32, 0.36, 0.6)
@export var district_border: Color = Color(1, 1, 1, 0.07)
@export var label_color: Color = Color(0.62, 0.65, 0.7, 0.55)
## Focus/selection highlight (style guide §3: the interactable accent #4FD1E8, UI only).
@export var highlight_color: Color = Color(0.31, 0.82, 0.91, 1)
## Pro job badge.
@export var pro_color: Color = Color(0.62, 0.17, 0.15, 1)

@export_group("Sizes (px at the 1920x1080 base)")
@export var avenue_px: float = 7.0
@export var street_px: float = 2.5
@export var pin_px: float = 44.0
@export var label_font_px: int = 18


static func load_default() -> BoardCityMap:
	var m: BoardCityMap = null
	if ResourceLoader.exists(DEFAULT_PATH):
		m = load(DEFAULT_PATH) as BoardCityMap
	if m == null:
		Log.error(&"content", "board city map missing: %s" % DEFAULT_PATH)
		m = BoardCityMap.new()
	return m


## District ids, sorted (ContentDB.sort_ids).
func district_ids() -> Array[StringName]:
	var ids: Array = districts.keys()
	ContentDB.sort_ids(ids)
	var out: Array[StringName] = []
	for id: Variant in ids:
		out.append(StringName(id))
	return out


func heist_anchor(heist_id: StringName) -> Vector2:
	var d: Dictionary = heists.get(heist_id, {}) as Dictionary
	if d.has("pos"):
		return d["pos"] as Vector2
	# Deterministic spot for an unmapped heist (hash of its id), never a global RNG.
	var h: int = hash(String(heist_id))
	var fx: float = float(h & 0xFFFF) / 65535.0
	var fy: float = float((h >> 16) & 0xFFFF) / 65535.0
	return fallback_area.position + fallback_area.size * Vector2(fx, fy)


func heist_district(heist_id: StringName) -> StringName:
	return StringName((heists.get(heist_id, {}) as Dictionary).get("district", &""))


func heist_contact(heist_id: StringName) -> StringName:
	return StringName((heists.get(heist_id, {}) as Dictionary).get("contact", &""))


## Where a district's name is drawn: its "label_pos", else the average of its polygon's points.
func district_center(district_id: StringName) -> Vector2:
	var d: Dictionary = districts.get(district_id, {}) as Dictionary
	if d.has("label_pos"):
		return d["label_pos"] as Vector2
	var poly: PackedVector2Array = d.get("polygon", PackedVector2Array()) as PackedVector2Array
	if poly.is_empty():
		return Vector2(0.5, 0.5)
	var c: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		c += p
	return c / float(poly.size())
