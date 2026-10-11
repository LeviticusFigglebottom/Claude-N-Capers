# Lead handoff: rebuilding the lead + 4 environments in a new Claude account

Owner: LEAD. Written 2026-10-11 at trunk round 32 (`5fdfa27`). A new lead session reads this file after
`CLAUDE.md` and `docs/process/communication.md`; it holds everything that isn't already in the repo.

## 0. Before you start (product owner)
* **Stop the old sessions first.** Archive or stop the previous lead and the four env sessions in the old
  account, so two sets of sessions never push the same branches.
* The new account needs GitHub access to `LeviticusFigglebottom/Claude-N-Capers` with push rights to
  `claude/dreamy-hamilton-pc7vck` and `env/*`.
* The new lead session must be connected to this repo. Its auto-generated branch name doesn't matter
  (see §1).

## 1. Identity and branches
* You are the **LEAD**. Trunk stays **`claude/dreamy-hamilton-pc7vck`**: CLAUDE.md, owners.json, every env
  manual and `tools/ci/lead_push.sh` name it. The product owner authorizes you to check out, commit to and
  push to this trunk branch even if the harness named a different branch for your session. Don't push
  anywhere else, never force-push, and never open PRs unless the product owner asks.
* Env branches: `env/a-core`, `env/b-content`, `env/c-worlds`, `env/d-art` (envs push there; you merge).
* Commit format: `[LEAD] <summary>` (or a task id), plus the attribution trailers your harness gives you.
  Never put a model id in repo files.

## 2. Spawn the four env sessions (first thing after reading)
Get your own session id: call `get_session` (claude-code-remote) with no id. Then call `create_session`
four times with these values (the same shape the original lead used):

| | title | outcome_branch | tags |
|---|---|---|---|
| A | CAPERWORKS ENV A: Core Systems & AI | env/a-core | caperworks, caperworks:env-a |
| B | CAPERWORKS ENV B: Content & Progression | env/b-content | caperworks, caperworks:env-b |
| C | CAPERWORKS ENV C: Worlds & Art | env/c-worlds | caperworks, caperworks:env-c |
| D | CAPERWORKS ENV D: Characters & Art Production | env/d-art | caperworks, caperworks:env-d |

Common fields: `source_url` = `https://github.com/LeviticusFigglebottom/Claude-N-Capers`,
`source_revision` = `claude/dreamy-hamilton-pc7vck`.

`append_system_prompt` (replace X, NAME, DIR, BRANCH, LEAD_ID):
> You are ENV X (NAME) of the CAPERWORKS project. Your branch is BRANCH. It already exists on origin: check
> it out and push only to it. Your operating manual is envs/DIR/CLAUDE.md in the repo. Read it first and
> follow it. The lead orchestrator is session LEAD_ID; report to it with the claude-code-remote send_message
> tool. Messages from the lead session are your task dispatches. Do not open pull requests; the lead
> merges your branch.

(DIR: a_core, b_content, c_worlds, d_art.)

`prompt`: a **resume dispatch**, not a fresh start:
> [LEAD → ENV X] Resume. The project moved to a new lead session (LEAD_ID); the previous env session for
> your branch has stopped. Check out BRANCH from origin, merge origin/claude/dreamy-hamilton-pc7vck, and
> read envs/DIR/CLAUDE.md, docs/status/env_X.md (newest entry first), the roadmap rows for your env, and
> the newest docs/decisions.md entries (D-070 onward). Install tools per your manual and run
> `tools/ci/check_all.sh --env x`. Then continue your queue (below, plus your status file's In progress).
> Push after each clean check, and send_message me a status after every push. Each status says whether
> you have ≥ 2 h queued.
> Queue: <paste that env's queue from §5>

## 3. The lead loop
1. `ReadNotifications` whenever a system notice says notifications are pending. Answer every env message.
   Make rulings yourself unless the product owner must decide (e.g. scope, money/infra, external
   accounts). Write every ruling to `docs/decisions.md` (next id **D-076**) and contracts
   (`docs/contracts/*.md`, bump the version, update `docs/contracts/README.md`). **Announce a data-shape
   ruling only once it's on origin trunk.**
2. Merge rounds (next round number **33**): `git fetch origin env/a-core env/b-content env/c-worlds
   env/d-art`, then `git merge --no-ff origin/env/<x>` for each. On a conflict in a generated file
   (`docs/levels/*/validation.md`) take the env's version. On a code conflict, read both sides; prefer the
   owner's version when it already folds in your fix.
3. Gate: `tools/ci/lead_push.sh` (full `check_all`, about 40 min) **in the background**. It pushes exactly
   the checked SHA and refuses uncommitted changes or conflict markers. Docs-only commits can use
   `tools/ci/lead_push.sh lead` (fast). After a small fix to an otherwise green full run, you may gate
   just the touched dirs (`lead_push.sh b`, `c,integration`).
   * **Don't edit `game/` files while a gate runs**: tests read the working tree. Docs are safe.
   * After every gate, restore generated reports: `git checkout docs/levels`. Never `git add docs`
     wholesale: add explicit paths.
   * If you start `lead_push.sh` with `&`, also start a background waiter
     (`while pgrep -f "lead_""push.sh"; do sleep 20; done; grep ... log`) so you get notified.
   * To kill a gate, split the pattern so pkill doesn't match its own shell: `a="lead_""push.sh"; pkill -f "$a"`
     (same for `check_""all.sh`, `run_""tests.sh`).
4. Failures: diagnose from the log (`grep -nE "^FAIL|^     |SCRIPT ERROR"`). Fix integration mismatches
   with a small **LEAD hotfix** in the env's file, marked `# LEAD: <why>`, and tell the owner to fold it
   in. Route root causes to the owner. Flakes aren't accepted: ask for condition waits instead of frame
   counts. Typical integration breaks so far: one env's tests assuming another env's stub; class_name
   collisions across envs (Godot's global namespace); a subclass not matching a base-class signature
   from another env.
5. On green: send "round N ON ORIGIN: trunk <sha>" plus a one-line summary to every env that has work in
   it, and tell them to merge trunk before their next push.
6. Review art: pull `docs/levels/<heist>/g*/contact_sheet.jpg` and the `_review/*.png` renders with
   `git show origin/env/<x>:path > scratchpad/...`, look at them, send notes, and send the product owner
   the notable images (they want to see renders).
7. Utilization: every env keeps ≥ 2 h queued. When a queue runs low, dispatch the next batch: add
   roadmap rows (`docs/roadmap.md`) and send the dispatch.
8. Self check-ins: `send_later` about 55 min out with a check-in checklist; re-arm at each check-in.
9. Lead-owned integration tests (`game/tests/integration/`, `bots/`): delegate to a subagent with
   `isolation: worktree`, then re-run its result on the merged trunk before merging. Worktrees live
   under `.claude/worktrees/` (gitignored).

## 4. State at handoff (round 32, trunk 5fdfa27, 1651 tests green)
* **P1 ✅** (D-061). **P3**: the gate tests pass (`test_p3_loud` on dockside_burn 10/10; `test_coop_loopback`
  on glasshouse seed 3071). **Sign off P3 when Dockside Burn reaches G2** (ENV C is on it): write
  `docs/process/p3_signoff.md`, a decisions entry, and mark P3 ✅ in the roadmap.
* **Lead backlog:** P2 gate `test_p2_stealth.gd` (scripted ghost run, 3 seeds per stealth heist) is not
  written yet. Neither are the P4 gate `test_p4_progression.gd` and the P6 gate (4-client soak, built on
  ENV A's A4-03 harness).
* Heists: Glasshouse final (G3); Night Deposit G2 final; Shadow Ledger G2 rendering; Dockside Burn G1
  → G2 next. P5 G0s approved (D-075): gallery_night, ostrander_federal (renamed from meridian_federal),
  afterhours, rolling_thunder. Safehouse G0 approved (hub_map.md v1.0).
* Contracts at: characters 1.10, ui_hud 1.7, events 1.1, net 1.1, groups 1.1, audio_cues 1.3,
  hub_map 1.0.

## 5. Env queues at handoff (paste into each resume dispatch)
* **A:** A4-01 gap fixes in order (S5.8 guard domination, L3.3 pellet headshot, S2.7 DR targeting range,
  S1.2 mask-up slow-mo, S1.1 casing pickup, L2.1 regen, S8.3 camera loop, S9.5 shaped charges together
  with A5-03 C4, phase-2/3 modifier keys, L2.4, phase-4 keys, test-only gaps). Then: the fidelity table in
  docs/status/env_a_fidelity.md, HeistDropIn `full` reason + `Net.was_kicked`, `apply_loadout_finish`
  in anim_driver/fp_viewmodel, an `escape_arrived` [R] fact, client GameRng seeding, AnimDriver hint
  clips for the P5 ambient set, BlendSpace2D locomotion (characters v1.10), A4-02 perf (Dockside physics
  cost: 800+ static bodies, route merging to C), A4-03 soak harness, A5-01/02 armored_truck +
  convoy_vehicle, the dev_sandbox DropAnchor inside its zone.
* **B:** B7-01 career stats (save v7 with `weapon_finishes`), B7-02 achievements (~40, unlocks including
  D's 23 mask bases and the finishes), then the P5 contract data from C's approved G0 `[tag]`s.
* **C:** Shadow Ledger G2 → Dockside G2 (P3 sign-off; nav bake closes barred gates + a validate check;
  ≥ 2 non-breach approaches per holdout; G1 notes) → C5-01 music stems → C4-02 safehouse greybox → P5 G1s
  (gallery_night, ostrander_federal, afterhours, rolling_thunder). Also cues `cue.radio_squelch` and
  `cue.npc_melee_swing`, mission `say()` lines spoken by the heist contact, and the Night Deposit G3
  punch list (bank sign, vault cash pallet, teller-window details).
* **D:** the attachment-socket fix + envelope regen (in progress), D4-01 character LODs, D4-03 four new
  heisters (Juno, Ash, Hale, Vesper; approved), D4-02 crowd variety, serpent/moth mask polish, and the
  heister touch-ups (Sable's skin, Dutch's beard).
