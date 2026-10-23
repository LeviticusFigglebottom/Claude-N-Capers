## Co-op lobby model (B4-11). Owner: ENV B. Pure: no Net, no nodes; LobbySession feeds it the crew
## registry (Net.crew) and every lobby message with the SENDER'S crew slot, and the lobby screen draws it.
##
## Messages (Net.lobby_send(kind, data) / Net.lobby_message; contract docs/contracts/net.md, D-038).
## Every payload is JSON-safe (String keys; bool / int / float / String / Array / Dictionary values):
## * MSG_READY    {"ready": bool}                                 any human slot, for itself
## * MSG_PROFILE  {"name", "level", "notoriety", "loadout": loadout_to_dict()} any human slot, for itself;
##                `notoriety` = the Notoriety rank 0..max (B5-02; a summary without it reads as 0). Sent at
##                join and after every loadout change. `music` (B5-03) = the sender's resolved music pick
##                (MusicCatalog.resolve_choice; "" = heist default; missing or not a String reads as ""):
##                only the HOST's is used, shown read-only to clients (slot_view "music", host_music()).
##                `loadout.heister` (D-073) = the sender's heister pick ("" = no preference); every peer
##                serves picks first-come (heister_assignment(), rule in Heisters): the slot whose current pick
##                arrived first keeps it, a later conflicting pick falls back to the next free heister, and
##                AI / empty seats fill the rest. An unknown heister id is illegal.
##                `loadout.weapon_finishes` (B7-04) = {weapon id: finish id} for the equipped primary /
##                secondary (WeaponFinishes.for_loadout); cosmetic, so unknown ids are dropped, never illegal.
##                launch_loadouts() copies it into Loadout.weapon_finishes once that contract field exists.
##                Every peer validates it with validate_summary()
##                (SkillPoints.validate + LoadoutResolver mod legality + known ids, architecture §11):
##                an illegal summary is FLAGGED on its slot and blocks Start; the host never launches it.
## * MSG_CONTRACT {"heist": String, "difficulty": int, "is_pro": bool, "last_breath": bool}   host only. D-049:
##                every player has their own Board; the lobby runs the host's contract. A new heist/difficulty
##                clears every ready flag and the plan-vote log; toggling Last Breath (C4) clears the ready flags.
## * MSG_START    {"heist", "difficulty", "is_pro", "last_breath", "seed": int}   host only; the launch order.
## * PlanVote.MSG_CAST / MSG_RETRACT (preplanning.md): logged in order (vote_log) so a pre-planning
##                screen opened later can replay them (PreplanPlan.receive_vote); the live screen
##                applies them itself.
## * MSG_CHAT     {"text": String}                               any human slot (B6-03). Validated by ChatLog
##                (`chat`): attribution by the sender's slot, control characters stripped, length cap, rate
##                limit per sender against `now_s` (R_RATE_LIMITED / R_EMPTY). Plain text only (no BBCode).
## * MSG_KICK     {"slot": int}                                  host only (B6-04, D-072): a UI notice that the
##                host kicked the human in `slot` (not the host). Net.kick does the actual drop; every peer
##                adds that slot's peer id + name to `kicked` (KickList: no rejoin this session).
## * MSG_SETTINGS {"dropin": "ask"|"auto"|"off"}                  host only (B6-04): the lobby's host settings.
##                `dropin_policy` (PD2 drop-in: ask = the host answers each request, auto = accepted without a
##                dialog, off = denied). Session state, not GameSettings: every member sees it and the host's
##                drop-in path reads it (join_decision); default LobbyTweak.dropin_default_policy.
## receive() rejects unknown kinds, senders that are not a human crew slot, host-only kinds from
## anyone but the host slot, and malformed / non-JSON-safe payloads (R_* codes).
class_name LobbyState
extends RefCounted

const MSG_READY: StringName = &"lobby.ready"
const MSG_PROFILE: StringName = &"lobby.profile_summary"
const MSG_CONTRACT: StringName = &"lobby.contract"
const MSG_START: StringName = &"lobby.start"
const MSG_CHAT: StringName = &"lobby.chat"
const MSG_KICK: StringName = &"lobby.kick"
const MSG_SETTINGS: StringName = &"lobby.settings"
const KINDS: Array[StringName] = [MSG_READY, MSG_PROFILE, MSG_CONTRACT, MSG_START, PlanVote.MSG_CAST, PlanVote.MSG_RETRACT,
	MSG_CHAT, MSG_KICK, MSG_SETTINGS]
const HOST_ONLY: Array[StringName] = [MSG_CONTRACT, MSG_START, MSG_KICK, MSG_SETTINGS]
## Drop-in policies (host setting, PD2). UI text: `ui.lobby.dropin.<policy>`.
const POLICY_ASK: StringName = &"ask"
const POLICY_AUTO: StringName = &"auto"
const POLICY_OFF: StringName = &"off"
const POLICIES: Array[StringName] = [POLICY_ASK, POLICY_AUTO, POLICY_OFF]
## join_decision() results besides a deny reason (DropInService.REASON_KICKED / REASON_OFF).
const JOIN_ASK: StringName = &"ask"
const JOIN_ACCEPT: StringName = &"accept"

## receive() results.
const OK: StringName = &""
const R_UNKNOWN_KIND: StringName = &"unknown_kind"
const R_BAD_SENDER: StringName = &"bad_sender"
const R_NOT_HOST: StringName = &"not_host"
const R_BAD_PAYLOAD: StringName = &"bad_payload"
const R_EMPTY: StringName = ChatLog.R_EMPTY
const R_RATE_LIMITED: StringName = ChatLog.R_RATE_LIMITED
## start_block() reasons (UI text: strings.csv `ui.lobby.block.<reason>`).
const BLOCK_NOT_HOST: StringName = &"not_host"
const BLOCK_STARTED: StringName = &"started"
const BLOCK_NO_CONTRACT: StringName = &"no_contract"
const BLOCK_MISSING_SUMMARY: StringName = &"missing_summary"
const BLOCK_ILLEGAL: StringName = &"illegal_loadout"
const BLOCK_NOT_READY: StringName = &"not_ready"

const MAX_CREW: int = 4
const MAX_PERK_CARDS: int = 9
## Loadout fields carried by a profile summary (StringName ids; *_mods are id lists).
const ID_FIELDS: Array[String] = ["primary", "secondary", "melee", "throwable", "deployable",
	"deployable_secondary", "armor", "mask", "perk_deck", "heister", "perk_mimic_deck"]
const MOD_FIELDS: Array[String] = ["primary_mods", "secondary_mods"]
## Item kind each id field is checked against (ContentDB kinds).
const FIELD_KINDS: Dictionary = {
	"primary": ContentDB.WEAPONS, "secondary": ContentDB.WEAPONS, "melee": ContentDB.MELEE,
	"throwable": ContentDB.THROWABLES, "deployable": ContentDB.DEPLOYABLES,
	"deployable_secondary": ContentDB.DEPLOYABLES, "armor": ContentDB.ARMOR, "perk_deck": ContentDB.PERKS,
	"perk_mimic_deck": ContentDB.PERKS,
}

var is_host: bool = false
## Local player's crew slot (-1 while joining).
var local_slot: int = -1
## Crew slot of the host (peer 1).
var host_slot: int = 0
## Snapshot of Net.crew: slot -> {"peer_id": int, "is_ai": bool, "display_name": String}.
var crew: Dictionary = {}
## slot -> bool
var ready: Dictionary = {}
## slot -> sanitized profile summary
var summaries: Dictionary = {}
## slot -> Array[String] legality problems ([] = legal)
var errors: Dictionary = {}
## The host's contract ({} until chosen): {"heist": StringName, "difficulty": int, "is_pro": bool}.
var contract: Dictionary = {}
## The accepted MSG_START ({} until then): contract keys + "seed".
var started: Dictionary = {}
## Plan votes in arrival order: {"slot": int, "kind": StringName, "data": Dictionary}.
var vote_log: Array[Dictionary] = []
## Chat history + validation (B6-03). Survives crew changes; cleared by reset().
var chat: ChatLog = ChatLog.new()
## Clock (seconds) for the chat rate limit; LobbySession sets it before every receive().
var now_s: float = 0.0
## slot -> claim number of the slot's current heister pick (D-073: lower = earlier = keeps the heister).
var heister_claims: Dictionary = {}
## Host setting (MSG_SETTINGS): POLICY_ASK / POLICY_AUTO / POLICY_OFF.
var dropin_policy: StringName = POLICY_ASK
## Players kicked this session (MSG_KICK notices; the host also adds Net.peer_kicked). Cleared by reset().
var kicked: KickList = KickList.new()
var _claim_counter: int = 0


func _init(p_is_host: bool = false) -> void:
	is_host = p_is_host
	dropin_policy = default_policy()


func reset(p_is_host: bool) -> void:
	is_host = p_is_host
	local_slot = -1
	host_slot = 0
	crew = {}
	ready = {}
	summaries = {}
	errors = {}
	contract = {}
	started = {}
	vote_log = []
	chat.clear()
	heister_claims = {}
	_claim_counter = 0
	dropin_policy = default_policy()
	kicked.clear()


## New crew registry. A slot whose occupant changed (other peer, turned AI, emptied) loses its ready
## flag, summary and votes.
func set_crew(new_crew: Dictionary, p_local_slot: int, p_host_slot: int) -> void:
	for slot: Variant in crew.keys():
		var s: int = int(slot)
		var was: Dictionary = crew[slot] as Dictionary
		var now: Dictionary = new_crew.get(s, {}) as Dictionary
		if now.is_empty() or bool(now.get("is_ai", true)) != bool(was.get("is_ai", true)) \
				or int(now.get("peer_id", -1)) != int(was.get("peer_id", -1)):
			_forget(s)
	crew = {}
	for slot: Variant in new_crew:
		crew[int(slot)] = (new_crew[slot] as Dictionary).duplicate()
	local_slot = p_local_slot
	host_slot = p_host_slot if p_host_slot >= 0 else 0


func human_slots() -> Array[int]:
	var out: Array[int] = []
	for slot: Variant in crew:
		if not bool((crew[slot] as Dictionary).get("is_ai", true)):
			out.append(int(slot))
	out.sort()
	return out


func is_human(slot: int) -> bool:
	return crew.has(slot) and not bool((crew[slot] as Dictionary).get("is_ai", true))


func is_ready(slot: int) -> bool:
	return bool(ready.get(slot, false))


func is_legal(slot: int) -> bool:
	return summaries.has(slot) and (errors.get(slot, []) as Array).is_empty()


## Apply one lobby message from crew slot `from_slot`. Returns OK or an R_* reason (nothing changed).
func receive(from_slot: int, kind: StringName, data: Dictionary) -> StringName:
	if not KINDS.has(kind):
		return R_UNKNOWN_KIND
	if not is_human(from_slot):
		return R_BAD_SENDER
	if HOST_ONLY.has(kind) and from_slot != host_slot:
		return R_NOT_HOST
	if not is_json_safe(data):
		return R_BAD_PAYLOAD
	if kind == MSG_CHAT:
		return chat.receive(from_slot, String(slot_view(from_slot)["name"]), data, now_s)
	return OK if _apply(from_slot, kind, data) else R_BAD_PAYLOAD


## Applies a validated sender's message; false (nothing changed) when the payload shape is wrong.
func _apply(from_slot: int, kind: StringName, data: Dictionary) -> bool:
	var ok: bool = true
	match kind:
		MSG_READY:
			ok = data.get("ready") is bool
			if ok:
				ready[from_slot] = bool(data["ready"])
		MSG_PROFILE:
			var s: Dictionary = sanitize_summary(data)
			ok = not s.is_empty()
			if ok:
				_claim_heister(from_slot, s)
				summaries[from_slot] = s
				errors[from_slot] = validate_summary(s)
		MSG_CONTRACT:
			var c: Dictionary = parse_contract(data)
			ok = not c.is_empty()
			if ok:
				if contract.is_empty() or c["heist"] != contract["heist"] or c["difficulty"] != contract["difficulty"]:
					ready = {}
					vote_log = []
				elif bool(c["last_breath"]) != bool(contract.get("last_breath", false)):
					ready = {}  # C4: Last Breath changes the stakes; everyone readies again
				contract = c
		MSG_START:
			var st: Dictionary = parse_contract(data)
			ok = not st.is_empty() and _is_int(data.get("seed"))
			if ok:
				st["seed"] = int(data["seed"])
				started = st
				ready = {}  # C11: a Start spends every ready flag; the next heist needs a fresh Ready Up from each human
		MSG_KICK:
			var target: Variant = data.get("slot")
			ok = _is_int(target) and is_human(int(target)) and int(target) != host_slot
			if ok:
				remember_kick(int(target))
		MSG_SETTINGS:
			var policy: Variant = data.get("dropin")
			ok = policy is String and POLICIES.has(StringName(String(policy)))
			if ok:
				dropin_policy = StringName(String(policy))
		PlanVote.MSG_CAST, PlanVote.MSG_RETRACT:
			var key: String = "option" if kind == PlanVote.MSG_CAST else "group"
			ok = data.get(key) is String and String(data[key]) != ""
			if ok:
				vote_log.append({"slot": from_slot, "kind": kind, "data": data.duplicate(true)})
	return ok


## Put the human in `slot` on the kick list (its peer id, Net display name and summary name).
func remember_kick(slot: int) -> void:
	var c: Dictionary = crew.get(slot, {}) as Dictionary
	if c.is_empty() or bool(c.get("is_ai", true)):
		return
	kicked.add(int(c.get("peer_id", 0)), String(c.get("display_name", "")))
	var s: Dictionary = summaries.get(slot, {}) as Dictionary
	kicked.add(0, String(s.get("name", "")))


## Host: what to do with a join / drop-in request from `peer_id` with profile `summary` (LobbyState.summary_from
## shape): DropInService.REASON_KICKED (kicked this session), DropInService.REASON_OFF (policy off), JOIN_ACCEPT
## (policy auto) or JOIN_ASK (show the request dialog).
func join_decision(peer_id: int, summary: Dictionary) -> StringName:
	var player: String = String(summary.get("name", "")) if summary.get("name") is String else ""
	if kicked.has(peer_id, player):
		return DropInService.REASON_KICKED
	match dropin_policy:
		POLICY_OFF:
			return DropInService.REASON_OFF
		POLICY_AUTO:
			return JOIN_ACCEPT
	return JOIN_ASK


## The data default drop-in policy (LobbyTweak.dropin_default_policy; ask when unknown).
static func default_policy() -> StringName:
	var p: StringName = LobbyTweak.load_default().dropin_default_policy
	return p if POLICIES.has(p) else POLICY_ASK


static func settings_data(policy: StringName) -> Dictionary:
	return {"dropin": String(policy)}


## C11: the crew is back in the kept lobby after a heist. Start is "once per heist", not once per session:
## clears the launch order and the previous job's plan votes; the contract, crew and summaries stay
## (the ready flags were spent by the Start itself, so a peer still on its payday cannot be started into the
## next heist; the 2-window two-heist run caught that).
func end_round() -> void:
	started = {}
	vote_log = []


## Why the host cannot Start right now (OK = it can): host only, once, with a contract, and every human
## slot has sent a legal profile summary and is ready.
func start_block() -> StringName:
	if not is_host:
		return BLOCK_NOT_HOST
	if not started.is_empty():
		return BLOCK_STARTED
	if contract.is_empty():
		return BLOCK_NO_CONTRACT
	return _crew_block()


## The first crew-wide reason Start is blocked: a missing summary, then an illegal one, then not ready.
func _crew_block() -> StringName:
	var humans: Array[int] = human_slots()
	var missing: bool = false
	var illegal: bool = false
	var unready: bool = false
	for slot: int in humans:
		missing = missing or not summaries.has(slot)
		illegal = illegal or (summaries.has(slot) and not is_legal(slot))
		unready = unready or not is_ready(slot)
	if missing:
		return BLOCK_MISSING_SUMMARY
	if illegal:
		return BLOCK_ILLEGAL
	return BLOCK_NOT_READY if unready else OK


func can_start() -> bool:
	return start_block() == OK


## HeistLauncher options["loadouts"] for the human slots: slot -> resolved Loadout (legal summaries only).
func launch_loadouts() -> Dictionary:
	var out: Dictionary = {}
	for slot: int in human_slots():
		if is_legal(slot):
			var l: Loadout = LoadoutResolver.resolve(loadout_from_dict(summaries[slot]["loadout"] as Dictionary))
			l.heister = heister_of(slot)
			out[slot] = l
	return out


## D-073 heisters for every crew slot 0..MAX_CREW-1 (slot -> id; see Heisters for the rule): human slots
## with a summary in claim order (first claim keeps its pick), then every other slot (AI, empty seats the
## launcher fills with AI, humans still joining) in slot order.
func heister_assignment() -> Dictionary:
	var order: Array[int] = []
	var picks: Dictionary = {}
	for slot: int in human_slots():
		if summaries.has(slot):
			order.append(slot)
			picks[slot] = StringName(String((summaries[slot]["loadout"] as Dictionary).get("heister", "")))
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca: int = int(heister_claims.get(a, 0))
		var cb: int = int(heister_claims.get(b, 0))
		return ca < cb or (ca == cb and a < b))
	var fill: Array[int] = []
	for slot: int in range(MAX_CREW):
		if not order.has(slot) and not is_human(slot):
			fill.append(slot)
	# PO-19: the bots wear the host's crew outfits (bot slot i = the i-th fill seat), heisters still one per crew.
	var crew_l: Array = _host_crew()
	var fill_picks: Dictionary = {}
	for i: int in range(mini(fill.size(), crew_l.size())):
		var o: String = String((crew_l[i] as Dictionary).get("outfit", ""))
		if o != "":
			fill_picks[fill[i]] = StringName(o)
	return Heisters.assign(order, picks, fill, fill_picks)


## The heister `slot` launches as (&"" for a human without a summary yet).
func heister_of(slot: int) -> StringName:
	return StringName(heister_assignment().get(slot, &""))


## Heisters the other HUMAN slots hold (AI only fills what is left): the loadout picker marks them taken.
## Claim order is each peer's own arrival order; the host's view decides the launch (launch_loadouts).
func heisters_taken_by_others(slot: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var a: Dictionary = heister_assignment()
	for s: Variant in a:
		if int(s) != slot and is_human(int(s)) and StringName(a[s]) != &"":
			out.append(StringName(a[s]))
	return out


## Heisters of the AI slots and empty seats (slot -> id), for their HeistLauncher loadouts (Heisters.ai_loadouts).
func ai_heisters() -> Dictionary:
	var out: Dictionary = {}
	var a: Dictionary = heister_assignment()
	for s: Variant in a:
		if not is_human(int(s)):
			out[int(s)] = a[s]
	return out


## PO-19: the host's crew bot loadouts from its summary (CrewLoadouts.summary entries; [] before it arrives).
func _host_crew() -> Array:
	return (summaries.get(host_slot, {}) as Dictionary).get("crew", []) as Array


## PO-19: the crew bot entry an AI / empty seat carries (its index among the non-human seats; {} for a human).
func _bot_entry(slot: int) -> Dictionary:
	if is_human(slot):
		return {}
	var i: int = 0
	for s: int in range(slot):
		if not is_human(s):
			i += 1
	var crew_l: Array = _host_crew()
	return (crew_l[i] as Dictionary).duplicate(true) if i < crew_l.size() else {}


## One row per crew slot 0..MAX_CREW-1 for the lobby screen (ids, not text; see item_names()).
func slot_view(slot: int) -> Dictionary:
	var c: Dictionary = crew.get(slot, {}) as Dictionary
	var s: Dictionary = summaries.get(slot, {}) as Dictionary
	var view: Dictionary = {
		"slot": slot, "occupied": not c.is_empty(), "is_ai": bool(c.get("is_ai", false)),
		"is_local": slot == local_slot, "is_host": slot == host_slot and not c.is_empty(),
		"name": String(s.get("name", c.get("display_name", ""))), "ready": is_ready(slot),
		"has_summary": not s.is_empty(), "level": int(s.get("level", 0)), "notoriety": int(s.get("notoriety", 0)),
		"music": StringName(String(s.get("music", ""))), "heister": heister_of(slot),
		"heister_pick": StringName(String((s.get("loadout", {}) as Dictionary).get("heister", ""))),
		"loadout": (s.get("loadout", {}) as Dictionary).duplicate(true),
		"legal": is_legal(slot), "errors": (errors.get(slot, []) as Array).duplicate(),
		"bot": _bot_entry(slot),
	}
	return view


## The host's music pick from its summary (&"" = heist default or no summary yet), B5-03.
func host_music() -> StringName:
	return StringName(String((summaries.get(host_slot, {}) as Dictionary).get("music", "")))


## Profile summary the local player sends (MSG_PROFILE): name, level, Notoriety rank (B5-02) and the
## loadout's ids, with the worn custom mask's descriptor (D-043 QA-25).
static func summary_from(loadout: Loadout, profile: PlayerProfile) -> Dictionary:
	var l: Loadout = loadout.duplicate(true) as Loadout
	l.mask_descriptor = LoadoutResolver.mask_descriptor_for(loadout, profile)
	var ld: Dictionary = loadout_to_dict(l)
	ld["weapon_finishes"] = WeaponFinishes.sanitize_map(WeaponFinishes.for_loadout(profile, loadout))  # B7-04
	return {"name": profile.profile_name, "level": profile.level, "notoriety": profile.notoriety,
			"music": String(MusicCatalog.resolve_choice(profile)), "loadout": ld, "crew": CrewLoadouts.summary(profile)}


## JSON-safe loadout input (no resolved numbers; every peer resolves with LoadoutResolver).
static func loadout_to_dict(l: Loadout) -> Dictionary:
	var d: Dictionary = {}
	for f: String in ID_FIELDS:
		d[f] = String(l.get(f))
	for f: String in MOD_FIELDS:
		var ids: Array = []
		for m: StringName in l.get(f) as Array[StringName]:
			ids.append(String(m))
		d[f] = ids
	d["mask_descriptor"] = _json_copy(l.mask_descriptor)
	d["weapon_finishes"] = WeaponFinishes.sanitize_map(l.get(&"weapon_finishes"))  # B7-04: {} until the field lands
	d["perk_deck_cards"] = l.perk_deck_cards
	d["perk_choices"] = PlayerProfile.choices_to(l.perk_choices)  # D-164 (net.md)
	var skills: Dictionary = {}
	for k: Variant in l.skills:
		skills[String(k)] = int(l.skills[k])
	d["skills"] = skills
	return d


static func loadout_from_dict(d: Dictionary) -> Loadout:
	var l: Loadout = Loadout.new()
	for f: String in ID_FIELDS:
		l.set(f, StringName(String(d.get(f, ""))))
	for f: String in MOD_FIELDS:
		var ids: Array[StringName] = []
		for m: Variant in d.get(f, []) as Array:
			ids.append(StringName(String(m)))
		l.set(f, ids)
	l.mask_descriptor = (d.get("mask_descriptor", {}) as Dictionary).duplicate(true)
	if &"weapon_finishes" in l:  # B7-04: Loadout.weapon_finishes (contracts round 28)
		var fin: Dictionary = {}
		var src_f: Dictionary = WeaponFinishes.sanitize_map(d.get("weapon_finishes", {}))
		for k: Variant in src_f:
			fin[StringName(String(k))] = StringName(String(src_f[k]))
		l.set(&"weapon_finishes", fin)
	l.perk_deck_cards = int(d.get("perk_deck_cards", 0))
	l.perk_choices = PlayerProfile.choices_from(d.get("perk_choices", {}))
	var skills: Dictionary = {}
	var src: Dictionary = d.get("skills", {}) as Dictionary
	for k: Variant in src:
		skills[StringName(String(k))] = int(src[k])
	l.skills = skills
	return l


## A well-formed copy of a MSG_PROFILE payload ({} when the shape is wrong). Numbers arriving as
## integral floats (JSON) become ints; the name is cut to LobbyTweak.max_name_length.
static func sanitize_summary(data: Dictionary) -> Dictionary:
	var ld: Variant = data.get("loadout")
	var rank: Variant = data.get("notoriety", 0)
	if not (data.get("name") is String) or not _is_int(data.get("level")) or not _is_int(rank) or not (ld is Dictionary):
		return {}
	var src: Dictionary = ld as Dictionary
	var out: Dictionary = {}
	for f: String in ID_FIELDS:
		var v: Variant = src.get(f, "")
		if not (v is String):
			return {}
		out[f] = v
	for f: String in MOD_FIELDS:
		var arr: Variant = src.get(f, [])
		if not (arr is Array):
			return {}
		var ids: Array = []
		for m: Variant in arr as Array:
			if not (m is String):
				return {}
			ids.append(m)
		out[f] = ids
	var desc: Variant = src.get("mask_descriptor", {})
	var cards: Variant = src.get("perk_deck_cards", 0)
	var skills: Variant = src.get("skills", {})
	if not (desc is Dictionary) or not _is_int(cards) or not (skills is Dictionary):
		return {}
	out["mask_descriptor"] = (desc as Dictionary).duplicate(true)
	out["weapon_finishes"] = WeaponFinishes.sanitize_map(src.get("weapon_finishes", {}))  # cosmetic: unknown ids dropped
	out["perk_deck_cards"] = int(cards)
	var ch: Variant = src.get("perk_choices", {})
	if not (ch is Dictionary):
		return {}
	out["perk_choices"] = PlayerProfile.choices_to(PlayerProfile.choices_from(ch))
	var sk: Dictionary = {}
	for k: Variant in skills as Dictionary:
		var lv: Variant = (skills as Dictionary)[k]
		if not (k is String) or not _is_int(lv):
			return {}
		sk[k] = int(lv)
	out["skills"] = sk
	var max_len: int = LobbyTweak.load_default().max_name_length
	var music: Variant = data.get("music", "")
	return {"name": String(data["name"]).strip_edges().left(max_len), "level": int(data["level"]),
			"notoriety": int(rank), "music": String(music).left(ProfileSchema.SHORT_ID_MAX_LENGTH) if music is String else "",
			"loadout": out, "crew": _sanitize_crew(data.get("crew", []))}


## PO-19: a summary's crew bot entries, cosmetic for the other peers (the host validated them against its profile):
## at most CrewLoadouts.SLOTS dicts of short id strings (+ a mods list); anything malformed is dropped.
static func _sanitize_crew(v: Variant) -> Array:
	var out: Array = []
	if not v is Array:
		return out
	for e: Variant in v as Array:
		if out.size() >= CrewLoadouts.SLOTS or not e is Dictionary:
			break
		var d: Dictionary = e as Dictionary
		var clean: Dictionary = {"mods": []}
		for f: String in ["weapon", "armor", "mask", "outfit"]:
			var x: Variant = d.get(f, "")
			clean[f] = String(x).left(ProfileSchema.SHORT_ID_MAX_LENGTH) if x is String else ""
		for m: Variant in d.get("mods", []) as Array if d.get("mods") is Array else []:
			if m is String:
				(clean["mods"] as Array).append(String(m).left(ProfileSchema.SHORT_ID_MAX_LENGTH))
		out.append(clean)
	return out


## Legality problems of a sanitized summary ([] = legal), for logs and the slot's "illegal" flag:
## level and Notoriety rank ranges, known item ids, weapon mods the resolver accepts, perk card count, the skill set
## (SkillPoints.validate against the level's points) and the mask (preset id or a valid descriptor).
static func validate_summary(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var level: int = int(s.get("level", -1))
	var max_level: int = SkillPoints.tree_def().max_level
	if level < 0 or level > max_level:
		out.append("level %d outside 0..%d" % [level, max_level])
	var rank: int = int(s.get("notoriety", 0))
	if rank < 0 or rank > Notoriety.max_rank():
		out.append("notoriety %d outside 0..%d" % [rank, Notoriety.max_rank()])
	var ld: Dictionary = s.get("loadout", {}) as Dictionary
	for f: String in FIELD_KINDS:
		var id: String = String(ld.get(f, ""))
		if id != "" and not _known(FIELD_KINDS[f] as StringName, StringName(id)):
			out.append("%s: unknown id %s" % [f, id])
	for pair: Array in [["primary", "primary_mods"], ["secondary", "secondary_mods"]]:
		var mods: Array = ld.get(pair[1], []) as Array
		if mods.is_empty():
			continue
		var wid: String = String(ld.get(pair[0], ""))
		var def: WeaponDef = ContentDB.weapon(StringName(wid)) if _known(ContentDB.WEAPONS, StringName(wid)) else null
		if def == null:
			out.append("%s: mods without a weapon" % pair[1])
			continue
		var typed: Array[StringName] = []
		for m: Variant in mods:
			typed.append(StringName(String(m)))
		var applied: Array[StringName] = []
		for m: WeaponModDef in LoadoutResolver.applied_mods(def, typed):
			applied.append(m.id)
		for m: StringName in typed:  # each equipped mod must survive the resolver (counted: no duplicates)
			if applied.has(m):
				applied.erase(m)
			else:
				out.append("%s: illegal mod %s" % [pair[1], m])
	var cards: int = int(ld.get("perk_deck_cards", 0))
	if cards < 0 or cards > MAX_PERK_CARDS:
		out.append("perk_deck_cards %d outside 0..%d" % [cards, MAX_PERK_CARDS])
	var skills: Dictionary = {}
	var src: Dictionary = ld.get("skills", {}) as Dictionary
	for k: Variant in src:
		skills[StringName(String(k))] = int(src[k])
	for e: String in SkillPoints.validate(skills, SkillPoints.points_for_level(clampi(level, 0, max_level))):
		out.append("skills: " + e)
	var heister: StringName = StringName(String(ld.get("heister", "")))
	if heister != &"" and not Heisters.is_known(heister):
		out.append("heister: unknown id %s" % heister)
	var mask: StringName = StringName(String(ld.get("mask", "")))
	if mask != &"":
		if MaskCatalog.is_custom_id(mask):
			var desc: Dictionary = ld.get("mask_descriptor", {}) as Dictionary
			if String(desc.get("id", "")) != String(mask) or not MaskComposer.validate(desc).is_empty():
				out.append("mask: invalid custom descriptor for %s" % mask)
		elif not _known(ContentDB.MASKS, mask):
			out.append("mask: unknown id %s" % mask)
	return out


## Host contract payload ({} on a bad shape): heist id, difficulty 0..5, is_pro and last_breath (absent = false).
static func parse_contract(data: Dictionary) -> Dictionary:
	var heist: Variant = data.get("heist")
	var diff: Variant = data.get("difficulty")
	if not (heist is String) or String(heist) == "" or not _is_int(diff) or not (data.get("is_pro", false) is bool) \
			or not (data.get("last_breath", false) is bool):
		return {}
	if int(diff) < 0 or int(diff) >= Enums.Difficulty.size():
		return {}
	return {"heist": StringName(String(heist)), "difficulty": int(diff), "is_pro": bool(data.get("is_pro", false)),
			"last_breath": bool(data.get("last_breath", false))}


static func contract_data(heist_id: StringName, difficulty: int, is_pro: bool, last_breath: bool = false) -> Dictionary:
	return {"heist": String(heist_id), "difficulty": difficulty, "is_pro": is_pro, "last_breath": last_breath}


static func start_data(c: Dictionary, run_seed: int) -> Dictionary:
	var d: Dictionary = contract_data(StringName(c.get("heist", &"")), int(c.get("difficulty", 0)), bool(c.get("is_pro", false)),
			bool(c.get("last_breath", false)))
	d["seed"] = run_seed
	return d


## True for data JSON can carry unchanged: null, bool, int, float, String, Array and Dictionary with
## String keys (recursively). StringName, Object, Vector* ... are rejected.
static func is_json_safe(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for e: Variant in v as Array:
				if not is_json_safe(e):
					return false
			return true
		TYPE_DICTIONARY:
			var d: Dictionary = v as Dictionary
			for k: Variant in d:
				if typeof(k) != TYPE_STRING or not is_json_safe(d[k]):
					return false
			return true
	return false


## UI names of a summary loadout's items: {"primary", "secondary", "armor", "deployable", "perk_deck",
## "mask"} -> display text ("" for an empty slot).
static func item_names(loadout_dict: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for f: String in ["primary", "secondary", "armor", "deployable", "perk_deck"]:
		var id: String = String(loadout_dict.get(f, ""))
		out[f] = UiText.t(UiText.item_key(StringName(id))) if id != "" else ""
	out["mask"] = mask_name(loadout_dict)
	return out


## The worn mask's name: preset `item.<id>.name`, a custom mask `ui.lobby.custom_mask`, none "".
static func mask_name(loadout_dict: Dictionary) -> String:
	var id: StringName = StringName(String(loadout_dict.get("mask", "")))
	if id == &"":
		return ""
	if MaskCatalog.is_custom_id(id):
		return UiText.t(&"ui.lobby.custom_mask")
	return UiText.t(UiText.item_key(id))


## MaskDef every peer can render for a summary loadout (preset or composed descriptor), or null.
static func mask_def(loadout_dict: Dictionary) -> MaskDef:
	var id: StringName = StringName(String(loadout_dict.get("mask", "")))
	if id == &"":
		return null
	if MaskCatalog.is_custom_id(id):
		var desc: Dictionary = loadout_dict.get("mask_descriptor", {}) as Dictionary
		return MaskCatalog.from_descriptor(desc) if MaskComposer.validate(desc).is_empty() else null
	return ContentDB.mask(id) as MaskDef if _known(ContentDB.MASKS, id) else null


## A new or changed heister pick takes the next claim number; re-sending the same pick keeps its place.
func _claim_heister(slot: int, summary: Dictionary) -> void:
	var pick: String = String((summary["loadout"] as Dictionary).get("heister", ""))
	var old: Dictionary = summaries.get(slot, {}) as Dictionary
	if old.is_empty() or not heister_claims.has(slot) or String((old["loadout"] as Dictionary).get("heister", "")) != pick:
		_claim_counter += 1
		heister_claims[slot] = _claim_counter


func _forget(slot: int) -> void:
	heister_claims.erase(slot)
	ready.erase(slot)
	summaries.erase(slot)
	errors.erase(slot)
	var kept: Array[Dictionary] = []
	for e: Dictionary in vote_log:
		if int(e["slot"]) != slot:
			kept.append(e)
	vote_log = kept


static func _is_int(v: Variant) -> bool:
	return v is int or (v is float and is_equal_approx(float(v), roundf(float(v))) and not is_inf(float(v)))


## Does ContentDB know `id` in `kind`? (No error log, unlike the typed lookups.)
static func _known(kind: StringName, id: StringName) -> bool:
	if id == &"":
		return false
	for r: Variant in ContentDB.all_of(kind):
		var res: Resource = r as Resource
		if res != null and StringName(res.get(&"id")) == id:
			return true
	return false


## JSON-safe deep copy (StringName keys/values become String).
static func _json_copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING_NAME:
			return String(v)
		TYPE_ARRAY:
			var a: Array = []
			for e: Variant in v as Array:
				a.append(_json_copy(e))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in v as Dictionary:
				d[String(k)] = _json_copy((v as Dictionary)[k])
			return d
	return v
