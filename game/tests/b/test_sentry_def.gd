## D-157: the crew sentry's DeployableDef (deployables/sentry.tres). ENV A's SentryGun reads `params` over its
## DEFAULTS, so every key it reads must be here; PD2 shape: one sentry (Battery / Tower Defense adds 1-2), 40 % of the
## owner's ammo to deploy, AP / quiet modes come from the Silent Partner skill. Strings and the loadout picker.
extends TestCase

const ID: StringName = &"deployable.sentry"
## SentryGun.DEFAULTS keys (env/a-core f12e25ba).
const PARAM_KEYS: Array[String] = ["ammo", "damage", "fire_rate_rpm", "range_m", "spread_deg", "turn_speed_deg", "health",
	"ammo_cost_frac"]
const PROMPTS: Array[StringName] = [&"ui.prompt.sentry_pickup", &"ui.prompt.sentry_mode", &"ui.sentry.mode.normal",
	&"ui.sentry.mode.quiet", &"ui.sentry.mode.ap"]


func before_all() -> void:
	ContentDB.clear_cache()


func test_def_is_pd2_shaped() -> void:
	var d: DeployableDef = ContentDB.by_id(ContentDB.DEPLOYABLES, ID) as DeployableDef
	assert_true(d != null, "sentry.tres loads")
	if d == null:
		return
	assert_eq(d.kind, &"sentry")
	assert_eq(d.anim_set, &"deploy_sentry", "D-069 FP set")
	assert_eq(d.count, 1, "PD2: one sentry; Battery adds 1 / 2 (deploy.extra.sentry)")
	for k: String in PARAM_KEYS:
		assert_true(d.params.has(k) and float(d.params[k]) > 0.0, "params.%s set" % k)
	assert_near(float(d.params.get("ammo_cost_frac", 0.0)), 0.4, 0.001, "PD2: a sentry costs 40 % of your ammo")
	assert_true(float(d.params.get("range_m", 0.0)) <= 40.0, "a defensive turret, not a sniper")


func test_strings_and_picker() -> void:
	assert_true(UiText.has(UiText.item_key(ID)) and UiText.has(&"item.deployable.sentry.desc"), "name and desc")
	for k: StringName in PROMPTS:
		assert_true(UiText.has(k), "%s exists" % k)
	assert_true(UiText.t(&"ui.prompt.sentry_mode", {"key": "F", "mode": UiText.t(&"ui.sentry.mode.ap")}).contains("armor"))
	var listed: bool = false
	for r: Variant in ContentDB.all_deployables():
		listed = listed or (r as DeployableDef).id == ID
	assert_true(listed, "the loadout's deployable picker lists it (ContentDB.all_deployables)")


## Stand-in for the HUD model's interaction state (InteractionPanel reads `interaction`).
class FakeModel:
	extends Node
	signal interaction_changed
	var interaction: Dictionary = {}


func test_gate_needs_the_first_sentry_skill() -> void:
	assert_eq(DeployableGate.required_flag(ID), &"deploy.sentry_cost_mult", "D-157: gated like the ECM / trip mine")
	assert_false(DeployableGate.allowed(ID, {}), "no Sapper skill: locked")
	assert_true(DeployableGate.allowed(ID, {&"deploy.sentry_cost_mult": 0.95}), "Mount Up basic unlocks it")
	assert_eq(StringName(DeployableGate.unlock_skill(ID).get("id", &"")), &"skill.sapper.mount_up",
			"the locked label names the tier-1 skill (Mount Up), not Lean Build")
	assert_false(DeployableGate.unlock_skill(&"deployable.trip_mine").is_empty(), "the other gates still resolve")


func test_mode_prompt_translates_its_mode_argument() -> void:
	var panel: InteractionPanel = InteractionPanel.new()
	add_child(panel)
	await wait_frames(1)
	var m: FakeModel = FakeModel.new()
	add_child(m)
	m.interaction = {"text_key": &"ui.prompt.sentry_mode", "kind": &"", "args": {"mode": &"ui.sentry.mode.ap"}}
	panel.bind(m)
	await wait_frames(1)
	var shown: String = panel.prompt.text
	assert_true(shown.contains(UiText.t(&"ui.sentry.mode.ap")) and not shown.contains("ui.sentry"), "shows: %s" % shown)
	panel.queue_free()
	m.queue_free()
	await wait_frames(1)
