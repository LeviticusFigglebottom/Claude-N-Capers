## One muzzle flash (impact_fx.md §3). Owner: ENV C. Root of `res://world/vfx/muzzle_flash.tscn`.
## Root -Z points down the barrel; at size 1 the flash is ~1 m long (ENV P scales the root to ~0.12 m
## for the viewmodel). Children (built in code): `Star` (camera-facing flash star), `Flame` (two crossed
## quads along -Z), `Smoke` (one-shot puff emitter). `flash()` shows Star+Flame for FLASH_S and restarts
## the smoke; suppressed = smoke only. No light (P has its own; MuzzleFx asks VfxLights for third person).
## Standalone use: instance, then call `flash()` per shot (it times itself while `auto_tick`).
class_name MuzzleFlash
extends Node3D

const FLASH_S: float = 0.05
const FLASH_COLOR: Color = Color(1.0, 0.7, 0.35, 1.0)
const FLAME_COLOR: Color = Color(1.0, 0.62, 0.3, 1.0)
const SMOKE_LAYER: Dictionary = {
	"kind": &"puff", "count": 4, "life": 0.7, "speed": Vector2(0.3, 0.9), "spread": 25.0, "gravity": -0.4,
	"size": Vector2(0.1, 0.2), "c0": Color(0.62, 0.62, 0.6, 0.32), "c1": Color(0.6, 0.6, 0.6, 0.0), "mesh": &"chip",
}

## Hide the flash after FLASH_S in _process (MuzzleFx pools set false and call tick()).
@export var auto_tick: bool = true

var _left: float = 0.0
## Engine.get_frames_drawn() when the flash started: it stays up for at least one drawn frame (hitch-proof).
var _drawn_at: int = -1
var _smoke_left: float = 0.0
var _star: MeshInstance3D
var _flame: Node3D
var _smoke: GeometryInstance3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 0x3A221E
	_build()


func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)


## Show the flash. `size` scales the star/flame (1 = ~1 m, relative to the root's own scale).
func flash(size: float = 1.0, suppressed: bool = false) -> void:
	_star.visible = not suppressed
	_flame.visible = not suppressed
	if not suppressed:
		_star.scale = Vector3.ONE * size * _rng.randf_range(0.5, 0.7)
		_star.rotation = Vector3(0.0, 0.0, _rng.randf_range(-PI, PI))
		_flame.scale = Vector3(size * 0.6, size * 0.6, size * _rng.randf_range(1.4, 2.0))
		_flame.rotation = Vector3(0.0, 0.0, _rng.randf_range(-PI, PI))
		_left = FLASH_S
		_drawn_at = Engine.get_frames_drawn()
	_smoke.scale = Vector3.ONE * (0.6 if suppressed else 1.0)
	_smoke.visible = true
	ImpactFx.restart_emitter(_smoke)
	_smoke_left = float(SMOKE_LAYER["life"]) + 0.1


func is_flashing() -> bool:
	return _star.visible


func tick(delta: float) -> void:
	if _smoke_left > 0.0:
		_smoke_left -= delta
		if _smoke_left <= 0.0:
			_smoke.visible = false  # idle emitter: no draw call
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0 and VfxSettings.frame_drawn_since(_drawn_at):
		hide_flash()


func hide_flash() -> void:
	_left = 0.0
	_star.visible = false
	_flame.visible = false


func _build() -> void:
	_star = MeshInstance3D.new()
	_star.name = "Star"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var star_mat: StandardMaterial3D = VfxTextures.additive_material(VfxTextures.flash(), false)
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.billboard_keep_scale = true  # the star follows _star.scale and the root scale (ENV P FP note)
	star_mat.albedo_color = FLASH_COLOR
	star_mat.vertex_color_use_as_albedo = false
	q.material = star_mat
	_star.mesh = q
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star.visible = false
	add_child(_star)
	_flame = Node3D.new()
	_flame.name = "Flame"
	_flame.visible = false
	var flame_mat: StandardMaterial3D = VfxTextures.additive_material(VfxTextures.flash(), false)
	flame_mat.albedo_color = FLAME_COLOR
	flame_mat.vertex_color_use_as_albedo = false
	for k: int in range(2):
		var m: MeshInstance3D = MeshInstance3D.new()
		var fq: QuadMesh = QuadMesh.new()
		fq.size = Vector2.ONE
		fq.material = flame_mat
		m.mesh = fq
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Quad lies in a plane containing -Z (the barrel axis), forward of the muzzle.
		m.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5 * k) * Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(0, 0, -0.5))
		_flame.add_child(m)
	add_child(_flame)
	var layer: Dictionary = SMOKE_LAYER.duplicate()
	_smoke = ImpactFx.build_emitter(layer, VfxSettings.scaled_count(int(layer["count"])))
	_smoke.name = "Smoke"
	_smoke.visible = false
	# Emitters fire along local +Y; turn it down the barrel (-Z).
	_smoke.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.08))
	add_child(_smoke)
