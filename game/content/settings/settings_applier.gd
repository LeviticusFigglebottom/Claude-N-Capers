## Pushes GameSettings into the engine: AudioServer bus volumes, window / viewport video options and
## the InputMap (InputBindings). Owner: ENV B. Static API; GameSettings.apply() calls apply_all().
##
## Audio: each bus volume is 0..1 linear; the bus gets base_db + linear_to_db(v) where base_db is the
## mix level ENV C's bus layout gave it (remembered the first time this bus is set), and is muted at 0.
## Buses are created first through ENV C's AudioCueLib.ensure_buses() (otherwise a later
## ensure_buses() would replace the layout and drop the player's volumes).
## Video: window mode (fullscreen = Godot's borderless full-screen window) + vsync (skipped on the
## headless display server), Engine.max_fps, and on the viewport: scaling_3d_scale (render scale),
## msaa_3d, screen_space_aa (FXAA). FOV and brightness are read by their owners
## (content/docs/options.md); apply_environment() is the brightness helper.
class_name SettingsApplier
extends RefCounted

const MSAA: Dictionary = {
	"off": Viewport.MSAA_DISABLED, "2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X, "8x": Viewport.MSAA_8X,
}
## video/shadow_quality -> shadow atlas size (px) for the directional and the positional (omni / spot) shadows.
## "high" = Godot's defaults (what the heists were lit with).
const SHADOW_ATLAS: Dictionary = {"low": 1024, "medium": 2048, "high": 4096}
const WINDOW_MODES: Dictionary = {
	"windowed": DisplayServer.WINDOW_MODE_WINDOWED,
	"fullscreen": DisplayServer.WINDOW_MODE_FULLSCREEN,
	"exclusive_fullscreen": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
}

## Bus name -> volume_db before the player's volume was applied.
static var _base_db: Dictionary = {}


static func apply_all(s: GameSettings, viewport: Viewport = null) -> void:
	apply_audio(s)
	apply_video(s, viewport)
	InputBindings.apply(s)


static func apply_audio(s: GameSettings) -> void:
	var cue_lib: Script = UiNav.global_class(&"AudioCueLib")
	if cue_lib != null and cue_lib.has_method(&"ensure_buses"):
		cue_lib.call(&"ensure_buses")
	for bus: StringName in s.defaults.keys(GameSettings.AUDIO):
		set_bus_volume(bus, float(s.get_value(GameSettings.AUDIO, bus)))


## Sets bus `bus` to linear volume `linear` (0 = muted). False when the bus does not exist.
static func set_bus_volume(bus: StringName, linear: float) -> bool:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return false
	if not _base_db.has(bus):
		_base_db[bus] = AudioServer.get_bus_volume_db(idx)
	var v: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.0)
	AudioServer.set_bus_volume_db(idx, float(_base_db[bus]) + (linear_to_db(v) if v > 0.0 else -80.0))
	return true


## The base mix level (dB) remembered for `bus` (0.0 when it was never set).
static func base_db(bus: StringName) -> float:
	return float(_base_db.get(bus, 0.0))


static func apply_video(s: GameSettings, viewport: Viewport = null) -> void:
	Engine.max_fps = int(s.get_value(GameSettings.VIDEO, &"max_fps"))
	if DisplayServer.get_name() != "headless":
		var mode: int = int(WINDOW_MODES.get(String(s.get_value(GameSettings.VIDEO, &"window_mode")), DisplayServer.WINDOW_MODE_WINDOWED))
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)
		var res: Vector2i = s.resolution()
		if mode == DisplayServer.WINDOW_MODE_WINDOWED and res != Vector2i.ZERO:
			apply_window_size(res)
		var vsync: bool = bool(s.get_value(GameSettings.VIDEO, &"vsync"))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var vp: Viewport = viewport
	if vp == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		vp = tree.root if tree != null else null
	if vp == null:
		return
	vp.scaling_3d_scale = float(s.get_value(GameSettings.VIDEO, &"render_scale"))
	vp.msaa_3d = int(MSAA.get(String(s.get_value(GameSettings.VIDEO, &"msaa")), Viewport.MSAA_DISABLED)) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(s.get_value(GameSettings.VIDEO, &"fxaa")) else Viewport.SCREEN_SPACE_AA_DISABLED
	var atlas: int = int(SHADOW_ATLAS.get(String(s.get_value(GameSettings.VIDEO, &"shadow_quality")), 4096))
	vp.positional_shadow_atlas_size = atlas
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)


## Windowed mode: resizes the window to `size` (never beyond the screen's usable area) and centres it.
static func apply_window_size(size: Vector2i) -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var fit: Vector2i = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y)) if usable.size != Vector2i.ZERO else size
	if DisplayServer.window_get_size() != fit:
		DisplayServer.window_set_size(fit)
		DisplayServer.window_set_position(usable.position + (usable.size - fit) / 2)


## Brightness helper for the heist map's Environment (ENV C / A call it; B does not own the map):
## enables the adjustment and sets adjustment_brightness to the video brightness (1.0 = unchanged).
static func apply_environment(env: Environment, s: GameSettings = null) -> void:
	if env == null:
		return
	var gs: GameSettings = s if s != null else GameSettings.current()
	var b: float = float(gs.get_value(GameSettings.VIDEO, &"brightness"))
	env.adjustment_enabled = env.adjustment_enabled or not is_equal_approx(b, 1.0)
	env.adjustment_brightness = b
