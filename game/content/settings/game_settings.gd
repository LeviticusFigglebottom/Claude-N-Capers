## Player options: audio, video, controls, accessibility and input bindings (roadmap B5-01). Owner: ENV B.
## API brief for other environments: content/docs/options.md.
##
## Pure model + a small persistence layer: values live in `_values[section][key]`, every write is
## validated against SettingsDefaults (data/settings/settings_defaults.tres) and emits
## `changed(section, key)` when the value actually changes. File: `<root_dir>/settings.cfg`
## (ConfigFile; [meta] version, one section per group, [bindings] action = {"kbm": [...], "pad": [...]}
## with InputEventCodec dicts). A missing or corrupt file -> defaults (+ Log.warn); a bad value ->
## that key's default.
##
## The game-wide instance is `GameSettings.current()` (loaded on first use; MenuFlow applies it at
## start). ENV A reads `fov()`, `mouse_sensitivity()`, `invert_y()`, `pad_sensitivity()`,
## `pad_deadzone()`, `is_toggle(action)` and listens to `changed`. `apply()` pushes what ENV B
## applies itself (SettingsApplier: AudioServer, window / viewport, InputMap).
class_name GameSettings
extends RefCounted

signal changed(section: StringName, key: StringName)

const CURRENT_VERSION: int = 1
const FILE_NAME: String = "settings.cfg"
const DEFAULT_ROOT_DIR: String = "user://"
const AUDIO: StringName = &"audio"
const VIDEO: StringName = &"video"
const CONTROLS: StringName = &"controls"
const ACCESSIBILITY: StringName = &"accessibility"
const BINDINGS: StringName = &"bindings"
## Sections validated by SettingsDefaults (BINDINGS is validated by InputBindings).
const VALUE_SECTIONS: Array[StringName] = [AUDIO, VIDEO, CONTROLS, ACCESSIBILITY]
const META: String = "meta"
## Actions with a hold / toggle choice -> their controls key.
const MODE_KEYS: Dictionary = {
	&"aim": &"aim_mode", &"crouch": &"crouch_mode", &"sprint": &"sprint_mode", &"scoreboard": &"scoreboard_mode",
}

## Tests point this at a per-process folder (BTestUtil.settings_root()).
static var root_dir: String = DEFAULT_ROOT_DIR
static var _current: GameSettings = null

var defaults: SettingsDefaults
## Version read from the file (CURRENT_VERSION for a new / default object).
var loaded_version: int = CURRENT_VERSION
var _values: Dictionary = {}


func _init(p_defaults: SettingsDefaults = null) -> void:
	defaults = p_defaults if p_defaults != null else SettingsDefaults.load_default()
	for section: StringName in VALUE_SECTIONS:
		var sec: Dictionary = {}
		for key: StringName in defaults.keys(section):
			sec[key] = defaults.default_value(section, key)
		_values[section] = sec
	_values[BINDINGS] = {}


## The game-wide settings (loaded from root_dir on first use).
static func current() -> GameSettings:
	if _current == null:
		_current = load_file()
	return _current


## Replace the game-wide instance (tests; null = reload from disk on next current()).
static func set_current(s: GameSettings) -> void:
	_current = s


static func file_path() -> String:
	return root_dir.path_join(FILE_NAME)


## Settings from `path` (default file_path()). Missing -> defaults; unreadable / corrupt -> defaults
## + Log.warn; every value is sanitized.
static func load_file(path: String = "") -> GameSettings:
	var p: String = path if path != "" else file_path()
	var s: GameSettings = GameSettings.new()
	if not FileAccess.file_exists(p):
		return s
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(p)
	if err != OK:
		Log.warn(&"settings", "cannot read %s (%s): defaults used" % [p, error_string(err)])
		return s
	s.from_config(cfg)
	return s


## Writes file_path() (or `path`). Returns the ConfigFile error.
func save(path: String = "") -> Error:
	var p: String = path if path != "" else file_path()
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	if dir_err != OK and not DirAccess.dir_exists_absolute(p.get_base_dir()):
		Log.error(&"settings", "cannot create %s (%s)" % [p.get_base_dir(), error_string(dir_err)])
		return dir_err
	var err: Error = to_config().save(p)
	if err != OK:
		Log.error(&"settings", "cannot write %s (%s)" % [p, error_string(err)])
	return err


func to_config() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(META, "version", CURRENT_VERSION)
	for section: StringName in VALUE_SECTIONS:
		var sec: Dictionary = _values[section]
		for key: Variant in sec:
			cfg.set_value(String(section), String(key), sec[key])
	var b: Dictionary = _values[BINDINGS]
	for action: Variant in b:
		cfg.set_value(String(BINDINGS), String(action), b[action])
	return cfg


## Reads every known key from `cfg` (sanitized; unknown keys ignored; bad ones -> default + warn).
func from_config(cfg: ConfigFile) -> void:
	var v: Variant = cfg.get_value(META, "version", 0)
	loaded_version = int(v) if (v is int or v is float) else 0
	if loaded_version > CURRENT_VERSION:
		Log.warn(&"settings", "settings version %d is newer than %d: reading known keys" % [loaded_version, CURRENT_VERSION])
	for section: StringName in VALUE_SECTIONS:
		if not cfg.has_section(String(section)):
			continue
		for key: StringName in defaults.keys(section):
			if cfg.has_section_key(String(section), String(key)):
				var raw: Variant = cfg.get_value(String(section), String(key))
				var clean: Variant = defaults.sanitize(section, key, raw)
				if typeof(raw) != typeof(clean) or raw != clean:
					Log.warn(&"settings", "%s/%s: %s -> %s" % [section, key, raw, clean])
				_values[section][key] = clean
	_values[BINDINGS] = {}
	if cfg.has_section(String(BINDINGS)):
		for action: String in cfg.get_section_keys(String(BINDINGS)):
			var entry: Dictionary = InputBindings.sanitize_entry(StringName(action), cfg.get_value(String(BINDINGS), action))
			if not entry.is_empty():
				_values[BINDINGS][StringName(action)] = entry


## Current value (null for an unknown key). BINDINGS: the action's override ({} = project default).
func get_value(section: StringName, key: StringName) -> Variant:
	if section == BINDINGS:
		return (_values[BINDINGS] as Dictionary).get(key, {}).duplicate(true)
	var sec: Dictionary = _values.get(section, {}) as Dictionary
	return sec.get(key)


## Validated write; emits `changed` when the stored value changes. Returns the stored value
## (null for an unknown key). BINDINGS: {} or an override equal to the defaults clears it.
func set_value(section: StringName, key: StringName, value: Variant) -> Variant:
	if section == BINDINGS:
		return _set_binding(key, value)
	if not _values.has(section) or not (_values[section] as Dictionary).has(key):
		Log.warn(&"settings", "unknown setting %s/%s" % [section, key])
		return null
	var clean: Variant = defaults.sanitize(section, key, value)
	if _values[section][key] != clean:
		_values[section][key] = clean
		changed.emit(section, key)
	return clean


## Every key of `section` back to its default (BINDINGS: every override cleared).
func reset_section(section: StringName) -> void:
	if section == BINDINGS:
		for action: Variant in (_values[BINDINGS] as Dictionary).keys():
			_set_binding(StringName(action), {})
		return
	for key: StringName in defaults.keys(section):
		set_value(section, key, defaults.default_value(section, key))


## Copies every value of `other` (emits `changed` for each difference).
func copy_from(other: GameSettings) -> void:
	for section: StringName in VALUE_SECTIONS:
		for key: StringName in defaults.keys(section):
			set_value(section, key, other.get_value(section, key))
	var actions: Dictionary = {}
	for a: Variant in (_values[BINDINGS] as Dictionary).keys() + (other._values[BINDINGS] as Dictionary).keys():
		actions[a] = true
	for a: Variant in actions:
		_set_binding(StringName(a), other.get_value(BINDINGS, StringName(a)))


func duplicate_settings() -> GameSettings:
	var s: GameSettings = GameSettings.new(defaults)
	s.copy_from(self)
	return s


## True when every value and binding equals `other`'s.
func equals(other: GameSettings) -> bool:
	return other != null and to_config().encode_to_text() == other.to_config().encode_to_text()


## Pushes audio / video / input into the engine (SettingsApplier). `viewport` defaults to the main window.
func apply(viewport: Viewport = null) -> void:
	SettingsApplier.apply_all(self, viewport)


# --- Values other environments read (content/docs/options.md) -----------------------------------

## Camera vertical FOV in degrees (60..100, default 75).
func fov() -> float:
	return float(get_value(VIDEO, &"fov"))


## Mouse look multipliers (x, y) on top of the controller's base sensitivity (1.0 = unchanged).
func mouse_sensitivity() -> Vector2:
	return Vector2(float(get_value(CONTROLS, &"mouse_sensitivity_x")), float(get_value(CONTROLS, &"mouse_sensitivity_y")))


## Invert vertical look (mouse and pad).
func invert_y() -> bool:
	return bool(get_value(CONTROLS, &"invert_y"))


## Gamepad look-speed multiplier (1.0 = unchanged).
func pad_sensitivity() -> float:
	return float(get_value(CONTROLS, &"pad_sensitivity"))


## Right-stick radial deadzone 0..1.
func pad_deadzone() -> float:
	return float(get_value(CONTROLS, &"pad_deadzone"))


## True when `action` (aim, crouch, sprint, scoreboard) is set to toggle instead of hold.
func is_toggle(action: StringName) -> bool:
	return MODE_KEYS.has(action) and String(get_value(CONTROLS, MODE_KEYS[action])) == "toggle"


func _set_binding(action: StringName, value: Variant) -> Dictionary:
	var entry: Dictionary = InputBindings.sanitize_entry(action, value)
	if InputBindings.is_default_entry(action, entry):
		entry = {}
	var b: Dictionary = _values[BINDINGS]
	var old: Dictionary = b.get(action, {}) as Dictionary
	if entry.is_empty():
		b.erase(action)
	else:
		b[action] = entry
	if old != entry:
		changed.emit(BINDINGS, action)
	return entry.duplicate(true)
