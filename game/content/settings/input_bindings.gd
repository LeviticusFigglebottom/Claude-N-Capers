## Key / pad rebinding on top of GameSettings' BINDINGS section (B5-01). Owner: ENV B. Static API.
##
## Each game action (every project InputMap action except the built-in `ui_*` ones; order from
## SettingsDefaults.action_order) has two columns, KBM and PAD (InputEventCodec). A column holds a
## list of binding dicts. The project.godot events are the defaults; GameSettings stores only
## overrides ({"kbm": [...], "pad": [...]}, a missing column = default). apply() rewrites the
## InputMap with InputMap.action_erase_events / action_add_event (deadzones untouched).
##
## Conflicts: binding an input that another action already uses in the same column, unless the two
## actions share an input in the project defaults (contextual keys such as F = interact / shout and
## G = mask up / throw / drop bag are designed to overlap). rebind() can swap (the other action takes
## this action's previous input) or keep both.
class_name InputBindings
extends RefCounted

static var _defaults: Dictionary = {}
static var _project: Array[StringName] = []
static var _compatible: Dictionary = {}


## Game actions in display order: SettingsDefaults.action_order, then any other project action.
static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	var project: Array[StringName] = project_actions()
	for a: StringName in SettingsDefaults.load_default().action_order:
		if project.has(a) and not out.has(a):
			out.append(a)
	var rest: Array = []
	for a: StringName in project:
		if not out.has(a):
			rest.append(a)
	ContentDB.sort_ids(rest)
	for a: Variant in rest:
		out.append(StringName(a))
	return out


## Every non-`ui_*` action defined in project.godot ([input]).
static func project_actions() -> Array[StringName]:
	if _project.is_empty():
		for p: Dictionary in ProjectSettings.get_property_list():
			var n: String = String(p["name"])
			if n.begins_with("input/") and not n.begins_with("input/ui_"):
				_project.append(StringName(n.trim_prefix("input/")))
	return _project.duplicate()


## strings.csv key of an action's display name.
static func name_key(action: StringName) -> StringName:
	return StringName("ui.action.%s" % action)


## The project.godot bindings of `action` in `column`.
static func default_column(action: StringName, column: StringName) -> Array[Dictionary]:
	if _defaults.is_empty():
		_load_defaults()
	var out: Array[Dictionary] = []
	for d: Dictionary in (_defaults.get(action, {}) as Dictionary).get(column, []) as Array:
		out.append(d.duplicate())
	return out


## The bindings `s` gives `action` in `column` (override, else default).
static func column(s: GameSettings, action: StringName, col: StringName) -> Array[Dictionary]:
	var entry: Dictionary = s.get_value(GameSettings.BINDINGS, action) as Dictionary
	if not entry.has(col):
		return default_column(action, col)
	var out: Array[Dictionary] = []
	for d: Dictionary in entry[col] as Array:
		out.append(d)
	return out


## Replace `action`'s `col` bindings in `s` (an override equal to the defaults is dropped).
static func set_column(s: GameSettings, action: StringName, col: StringName, events: Array[Dictionary]) -> void:
	var entry: Dictionary = s.get_value(GameSettings.BINDINGS, action) as Dictionary
	entry[col] = events.duplicate(true)
	s.set_value(GameSettings.BINDINGS, action, entry)


## Other actions that would clash with binding `ev` to `action` (same column, not designed to share).
static func conflicts(s: GameSettings, action: StringName, ev: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var col: StringName = InputEventCodec.column_of(ev)
	if col == &"":
		return out
	for other: StringName in actions():
		if other == action or compatible(action, other):
			continue
		for d: Dictionary in column(s, other, col):
			if InputEventCodec.same(d, ev):
				out.append(other)
				break
	return out


## True when the two actions share an input in the project defaults (contextual keys).
static func compatible(a: StringName, b: StringName) -> bool:
	if _defaults.is_empty():
		_load_defaults()
	return _compatible.has(_pair_key(a, b))


## Binds `ev` as the only input of its column for `action`. With `swap`, every conflicting action
## loses `ev` and takes this action's previous first input of that column (when it has one and does
## not already use it); otherwise conflicts are kept (both actions fire). Returns the actions whose
## bindings changed (`action` first).
static func rebind(s: GameSettings, action: StringName, ev: Dictionary, swap: bool) -> Array[StringName]:
	var col: StringName = InputEventCodec.column_of(ev)
	var changed_actions: Array[StringName] = []
	if col == &"":
		return changed_actions
	var clean: Dictionary = InputEventCodec.sanitize(ev)
	var others: Array[StringName] = []
	if swap:
		others = conflicts(s, action, clean)
	var previous: Array[Dictionary] = column(s, action, col)
	var only: Array[Dictionary] = [clean]
	set_column(s, action, col, only)
	changed_actions.append(action)
	for other: StringName in others:
		var list: Array[Dictionary] = []
		for d: Dictionary in column(s, other, col):
			if not InputEventCodec.same(d, clean):
				list.append(d)
		if not previous.is_empty() and not previous[0].is_empty() and not InputEventCodec.same(previous[0], clean):
			var has_prev: bool = false
			for d: Dictionary in list:
				has_prev = has_prev or InputEventCodec.same(d, previous[0])
			if not has_prev:
				list.push_front(previous[0])
		set_column(s, other, col, list)
		changed_actions.append(other)
	return changed_actions


## `action` back to its project.godot bindings.
static func reset_action(s: GameSettings, action: StringName) -> void:
	s.set_value(GameSettings.BINDINGS, action, {})


static func reset_all(s: GameSettings) -> void:
	s.reset_section(GameSettings.BINDINGS)


## Rewrites the InputMap events of every game action from `s`.
static func apply(s: GameSettings) -> void:
	for action: StringName in actions():
		apply_action(s, action)


static func apply_action(s: GameSettings, action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for col: StringName in InputEventCodec.COLUMNS:
		for d: Dictionary in column(s, action, col):
			var e: InputEvent = InputEventCodec.from_dict(d)
			if e != null:
				InputMap.action_add_event(action, e)


## Display text of a column ("Ctrl / C"; "-" when unbound).
static func column_text(s: GameSettings, action: StringName, col: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for d: Dictionary in column(s, action, col):
		parts.append(InputEventCodec.text(d))
	return " / ".join(parts) if not parts.is_empty() else UiText.t(&"ui.options.controls.unbound")


## Canonical override entry for `action` ({} for an unknown action or nothing valid). Each column
## keeps only valid dicts of that column; a missing column means "default".
static func sanitize_entry(action: StringName, raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary or not project_actions().has(action):
		return out
	for col: StringName in InputEventCodec.COLUMNS:
		var v: Variant = (raw as Dictionary).get(String(col), (raw as Dictionary).get(col))
		if not v is Array:
			continue
		var list: Array[Dictionary] = []
		for item: Variant in v as Array:
			var d: Dictionary = InputEventCodec.sanitize(item)
			if not d.is_empty() and InputEventCodec.column_of(d) == col:
				list.append(d)
		out[col] = list
	return out


## True when `entry` binds exactly the defaults (missing columns count as default).
static func is_default_entry(action: StringName, entry: Dictionary) -> bool:
	for col: StringName in InputEventCodec.COLUMNS:
		if entry.has(col) and entry[col] != default_column(action, col):
			return false
	return true


static func _load_defaults() -> void:
	_defaults.clear()
	_compatible.clear()
	for action: StringName in project_actions():
		var setting: Dictionary = ProjectSettings.get_setting("input/%s" % action, {}) as Dictionary
		var cols: Dictionary = {InputEventCodec.KBM: [], InputEventCodec.PAD: []}
		for e: Variant in setting.get("events", []) as Array:
			var d: Dictionary = InputEventCodec.to_dict(e as InputEvent)
			var col: StringName = InputEventCodec.column_of(d)
			if col != &"":
				(cols[col] as Array).append(d)
		_defaults[action] = cols
	var all: Array = _defaults.keys()
	for i: int in range(all.size()):
		for j: int in range(i + 1, all.size()):
			if _share(all[i], all[j]):
				_compatible[_pair_key(all[i], all[j])] = true


static func _share(a: StringName, b: StringName) -> bool:
	for col: StringName in InputEventCodec.COLUMNS:
		for da: Dictionary in (_defaults[a] as Dictionary)[col] as Array:
			for db: Dictionary in (_defaults[b] as Dictionary)[col] as Array:
				if InputEventCodec.same(da, db):
					return true
	return false


static func _pair_key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]
