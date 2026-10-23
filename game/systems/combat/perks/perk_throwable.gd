## perk.throwable (Composure / Overlord deck throwable). Owner: ENV A. Schema: perk_decks.md /
## modifiers_params.md. `item_id` replaces the equipped throwable while the deck is active
## (PerkHooks.throwable_id). Minimal throw-item runtime for deck throwables (grenades are not
## implemented yet): a rising edge of CrewIntent.throw_item (or PerkHooks.use_throwable) uses the item,
## and the perk that owns its ThrowableDef.kind consumes it (&"flask" -> perk.stoic, &"injector" ->
## perk.kingpin). The perk's own cooldown gates it, so the item is never used up.
class_name PerkThrowable
extends PerkComponent

const KEY: StringName = &"perk.throwable"

var _prev_throw: bool = false


func item_id() -> StringName:
	return StringName(str(param("item_id", &"")))


## ThrowableDef.kind of item_id (&"" when unknown).
func item_kind() -> StringName:
	var def: ThrowableDef = ContentDB.throwable(item_id()) if item_id() != &"" else null
	return def.kind if def != null else &""


func tick(_delta: float) -> void:
	var pressed: bool = crew != null and crew.intent != null and crew.intent.throw_item
	if pressed and not _prev_throw:
		throw_now()
	_prev_throw = pressed


## Use the deck throwable now. True when a perk consumed it.
func throw_now() -> bool:
	var kind: StringName = item_kind()
	if kind == &"":
		return false
	var perks: CrewPerks = PerkHooks.of(crew)
	if perks == null or not perks.use_throwable(kind):
		return false
	CrewThrowables.deck_item_fired(crew, item_id(), kind)  # presentation: the FP / 3P use pose on every peer
	return true
