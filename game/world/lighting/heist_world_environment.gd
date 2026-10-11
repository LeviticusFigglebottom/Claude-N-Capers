## Heist map WorldEnvironment that follows the player's brightness option (B5-01, options.md):
## SettingsApplier.apply_environment(environment) at ready and on GameSettings.changed(&"video",
## &"brightness"). ENV B's classes are looked up by name, so maps load without them (tools, tests).
## Owner: ENV C.
class_name HeistWorldEnvironment
extends WorldEnvironment

const APPLIER_CLASS: StringName = &"SettingsApplier"
const SETTINGS_CLASS: StringName = &"GameSettings"

var _settings: Object = null


func _ready() -> void:
	apply_brightness()
	var gs_script: Script = _global_class(SETTINGS_CLASS)
	if gs_script == null or not gs_script.has_method(&"current"):
		return
	_settings = gs_script.call(&"current")
	if _settings != null and _settings.has_signal(&"changed"):
		_settings.connect(&"changed", _on_settings_changed)


func _exit_tree() -> void:
	if _settings != null and is_instance_valid(_settings) and _settings.is_connected(&"changed", _on_settings_changed):
		_settings.disconnect(&"changed", _on_settings_changed)


## Applies the brightness option to `environment`. False when ENV B's applier is unavailable.
func apply_brightness() -> bool:
	var applier: Script = _global_class(APPLIER_CLASS)
	if applier == null or environment == null:
		return false
	applier.call(&"apply_environment", environment)
	return true


func _on_settings_changed(section: StringName, key: StringName) -> void:
	if section == &"video" and key == &"brightness":
		apply_brightness()


static func _global_class(class_id: StringName) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(c["class"]) == class_id:
			return load(String(c["path"])) as Script
	return null
