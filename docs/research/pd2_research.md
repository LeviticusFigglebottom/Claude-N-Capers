# PAYDAY 2 mechanics: research note for our original co-op heist game

**Purpose:** a reference of PD2 *mechanics and numbers* so our design doc stays faithful. It does not cover PD2 trademarks, names or art. Where we copy a mechanic, we should rename it.

**Method and provenance.** The direct HTML pages on payday.fandom.com returned HTTP 402 to WebFetch, so every wiki page was read as raw wikitext through the wiki's own MediaWiki API (`https://payday.fandom.com/api.php?action=query&prop=revisions...`) on 2026-10-10. Citations link to the normal page URL for that same content.

**Legend**
- **VERIFIED (wiki):** stated on the cited payday.fandom.com page as of retrieval. This means the wiki says it. It does not mean someone checked the game files. Many wiki numbers come from Frankelstner's "The Long Guide" (Steam guide id 267214370), which was data-mined.
- **UNVERIFIED (community claim):** comes from Steam forums or search snippets, or is a value we could not find on the wiki.
- **CONFLICT:** the wiki contradicts itself. Both values are given.

Short source keys used below (all `https://payday.fandom.com/wiki/...`):

| Key | URL |
|---|---|
| [Stealth] | https://payday.fandom.com/wiki/Stealth (also the redirect target of /wiki/Concealment) |
| [ECM] | https://payday.fandom.com/wiki/ECM_Jammer |
| [PocketECM] | https://payday.fandom.com/wiki/Pocket_ECM |
| [ECMSpec] | https://payday.fandom.com/wiki/ECM_Specialist |
| [BBC] | https://payday.fandom.com/wiki/Body_Bag_Case |
| [Cleaner] | https://payday.fandom.com/wiki/Cleaner |
| [Civ] | https://payday.fandom.com/wiki/Civilians |
| [FF] | https://payday.fandom.com/wiki/Forced_Friendship |
| [Stockholm] | https://payday.fandom.com/wiki/Stockholm_Syndrome |
| [Shout] | https://payday.fandom.com/wiki/Shout |
| [Sixth] | https://payday.fandom.com/wiki/Sixth_Sense |
| [Chameleon] | https://payday.fandom.com/wiki/Chameleon |
| [Drills] | https://payday.fandom.com/wiki/Drills |
| [HWE] | https://payday.fandom.com/wiki/Hardware_Expert |
| [DS] | https://payday.fandom.com/wiki/Drill_Sawgeant |
| [Kick] | https://payday.fandom.com/wiki/Kickstarter |
| [Doors] | https://payday.fandom.com/wiki/Doors |
| [Trip] | https://payday.fandom.com/wiki/Trip_mine_(Payday_2) |
| [Sentry] | https://payday.fandom.com/wiki/Sentry_gun_(Payday_2) |
| [Assault] | https://payday.fandom.com/wiki/Assault_Waves |
| [Custody] | https://payday.fandom.com/wiki/Police_Custody |
| [NineLives] | https://payday.fandom.com/wiki/Nine_Lives |
| [Cloaker] | https://payday.fandom.com/wiki/Cloaker_(Payday_2) |
| [Taser] | https://payday.fandom.com/wiki/Taser_(Payday_2) |
| [Shield] | https://payday.fandom.com/wiki/Shield_(Payday_2) |
| [Dozer] | https://payday.fandom.com/wiki/Bulldozer_(Payday_2) |
| [Sniper] | https://payday.fandom.com/wiki/Sniper_(Payday_2) |
| [Medic] | https://payday.fandom.com/wiki/Medic |
| [Winters] | https://payday.fandom.com/wiki/Captain_Winters |
| [Diff] | https://payday.fandom.com/wiki/Risk_Level/Difficulties_and_Modifiers_(PAYDAY_2) |
| [Risk] | https://payday.fandom.com/wiki/Risk_Level |
| [Enemies] | https://payday.fandom.com/wiki/Enemies_(Payday_2) |
| [Armors] | https://payday.fandom.com/wiki/Armors (field labels from https://payday.fandom.com/wiki/Template:Armor) |
| [Bullseye] | https://payday.fandom.com/wiki/Bullseye |
| [Skills] | https://payday.fandom.com/wiki/Skills |
| [Perks] | https://payday.fandom.com/wiki/Perk_Decks |
| [WPStat] | https://payday.fandom.com/wiki/Weapons_(Payday_2)/WPStatistics |
| [WPMech] | https://payday.fandom.com/wiki/Weapons_(Payday_2)/WPMechanics |
| [CAR4Mods] | https://payday.fandom.com/wiki/CAR-4/Weapon_Mods |
| [Payday] | https://payday.fandom.com/wiki/Payday_(Gameplay) |
| [Rep] | https://payday.fandom.com/wiki/Reputation_(Payday_2) |
| [Infamy] | https://payday.fandom.com/wiki/Infamy |
| [PrePlan] | https://payday.fandom.com/wiki/Pre-Planning |
| [BBPrePlan] | https://payday.fandom.com/wiki/Big_Bank/PrePlan |
| [Assets] | https://payday.fandom.com/wiki/Assets |
| [Spree] | https://payday.fandom.com/wiki/Crime_Spree |
| [Contractor] | https://payday.fandom.com/wiki/Contractor_(gameplay) |
| [PD2] | https://payday.fandom.com/wiki/PAYDAY_2 |
| [MasksPD2] | https://payday.fandom.com/wiki/Masks_(Payday_2) |
| [Inspire] | https://payday.fandom.com/wiki/Inspire |
| [SwanSong] | https://payday.fandom.com/wiki/Swan_Song |
| [DocBag] | https://payday.fandom.com/wiki/Doctor_bag_(Payday_2) |
| [FAK] | https://payday.fandom.com/wiki/First_Aid_Kit |
| [SneakyB] | https://payday.fandom.com/wiki/Sneaky_Bastard |

> Note on the URLs in the brief: `/wiki/Pager`, `/Detection`, `/Body_Bag`, `/Cable_Tie`, `/Dodge`, `/Damage_falloff`, `/Suppression`, `/Bleedout`, `/Custody`, `/Hostage_trade`, `/Casing_mode`, `/Stoic` (as its own page), `/Health` and `/Headshot` do **not** exist as PD2 pages. That content lives in [Stealth], [Custody], [WPStat], [Perks] and [Diff].

---

## 1. Stealth

### 1.1 Stealth "modes" (VERIFIED (wiki) [Stealth])
- **Civilian mode** (only on certain heists): you carry no gear and no mask, and guards or civilians cannot detect you. **Laser grids still trigger.** You cannot interact with heist equipment. Picking up your gear moves you into casing mode.
- **Casing mode** (unmasked, which is the default start of most stealth heists):
  - **Civilians can never detect you.** Guards and cameras have "elevated resistance" but **can** still detect you if you linger or come too close.
  - **Not allowed:** crouch, jump, sprint (an on-screen "suspicious actions are not allowed" message appears), combat, interaction-wheel interactions (bags, equipment, reviving), climbing ladders, deploying equipment, or taking damage.
  - **Allowed:** shouting or marking (Chameleon basic lets you actively mark guards and cameras, Sixth Sense basic passively marks), "instant" pickups such as keycards and cash bundles with Chameleon aced, and masking up.
  - **Masking up is irreversible**, with 3 scripted exceptions. Being detected or triggering combat forces that player to mask. When any alarm sounds, everyone masks automatically.
  - Unmasking near guards or civilians gives a brief **slow-motion** moment. Cameras do not trigger it.
- **Masked stealth:** you can do everything, and everyone can detect you, civilians included.

### 1.2 Detection meter (VERIFIED (wiki) [Stealth] unless marked)
- **Detection risk (DR) ranges from 3 to 75.** The meter starts at your DR as a percentage (DR 3 starts at 3%) and fills while an observer has line of sight.
- **Meter visuals:** blue for 3–49%, orange from 50%. A **"?"** shows while you are seen but not fully detected, both on the meter and above the observer. At 100% it turns into **"!"** with a loud sound cue.
- **Fill rate** depends on the **distance and the angle** from the observer. Close and centred in their view is fastest. The edge of their field of view or far away is slower.
- **Converting DR to a multiplier.** DR maps to a "concealment modifier". The **minimum detection time is multiplied by** this modifier, and the **detection distance is divided by sqrt(modifier)**:

| DR | 3 | 7 | 10 | 16 | 20 | 26 | 35 | 43 | 52 | 63 | 75 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Modifier | 1.55 | 1.475 | 1.425 | 1.325 | 1.25 | 1.15 | 1.0 | 0.85 | 0.7 | 0.5 | 0.3 |

  (The full 29-step table is on [Stealth].)
- **Total concealment → DR.** Total concealment of **119+ gives DR 3**, and **91 or less gives DR 75**. Total concealment is the sum of primary, secondary, melee, armor and skill bonuses. Selected points: 119→3, 116→7, 113→12, 110→16, 107→20, 104→26, 101→35, 100→43, 97→49, 94→58, 93→63, 92→69, 91→75.
  - Below a total of about 100 the curve is very steep: one point of concealment costs 3–8 DR.
  - Known quirk: weapons with concealment 19 and 20 give the same DR.
- **Loud effect of DR:** DR also sets how far away enemies will target you, from **180 m at DR 75 down to 80 m at DR 3**.
- **Cameras:** the rate works like guards and civilians and is DR-based. It is typically **about 2 s**. Movement speed does **not** change a camera's rate, so sprinting across its view is best.
- **Chameleon basic:** in casing mode the meter builds **25% slower** (×0.75). Despite the skill's tooltip, it does **not** change DR or detection distance ([Chameleon]).
- **Crouching or stance effect on fill rate: UNVERIFIED (community claim).** The wiki says nothing. One search-result guide claims crouching is slower and running is faster, but our wiki pages never state it. Note that crouching is simply disallowed in casing mode.
- **Exact distance curve:** UNVERIFIED. The wiki gives only the qualitative rule and points to "The Long Guide". We could not fetch that guide (Steam returned HTTP 429).

### 1.3 Detection outcomes (VERIFIED (wiki) [Stealth])
- **Civilian fully alerted:** panics, then flees, calls police, hits a panic button or alerts guards. A fleeing civilian who leaves the map raises the alarm. **An alerted civilian cannot be pacified** ([Civ]).
- **Guard spots you:**
  1. He yells "stop", pauses **about 5 s**, walks over and tries to **cuff** you.
  2. If you move **more than 1.7 m** or shoot, he opens fire instead.
  3. Once he has cuffed you, he raises the alarm shortly afterwards.
  4. A cuffed player needs **60 s** to free themselves, or a teammate can free them.
  5. A cuff attempt starts a **4-minute per-player cooldown**. If you are spotted inside that window, the guard shoots and calls in immediately.
  6. If a guard is alerted within 1 m of you, he cuffs you in about 1 s.
- **Guard raises the alarm** by stopping, drawing his weapon and radioing. **Killing him before the call finishes prevents the alarm.**
- **Body-shot kills:** a non-headshot, non-shotgun kill on a guard has a **10% chance his gun misfires**, which alerts nearby NPCs.
- **One-shot rule:** an unalerted guard dies to **any** hit.
- **Camera fully alerted ("!" plus a continuous tone):** the alarm sounds **7 s later, irreversibly**. Destroying the camera, killing the operator or deploying an ECM does **not** stop it.

### 1.4 What guards and cameras treat as suspicious (VERIFIED (wiki) [Stealth])
**Guards alarm on:**
- unsuppressed gunfire, heard to about **45 m** for player weapons and sentries and about **25 m** for NPC weapons;
- explosions (Molotovs are silent beyond 15 m);
- players who are not in civilian mode;
- dead bodies;
- **body bags within 19 m** of line of sight, and **other bags within 18 m** (bags pre-placed on the map are ignored until a player moves them);
- dominated guards;
- tied, panicking or downed civilians;
- broken cameras (sometimes a guard just waves at it, and then *all* guards ignore that camera);
- active drills or saws;
- a running unsilenced saw, or any saw cutting a surface, within **10 m**;
- deployed sentries;
- **cracked or broken glass**;
- enemies hit by ECM feedback;
- devices in the middle of being hacked;
- certain open doors.

**Guards ignore:**
- most opened doors and crates;
- **open bank vaults** (except on one heist);
- **missing items**;
- flashlights and laser sights;
- the getaway vehicles.

**Cameras detect:**
- players;
- body bags (19 m) and other bags (18 m);
- corpses;
- alerted NPCs;
- hostages;
- broken glass;
- broken cameras;
- drills, even when the camera is not pointed at them;
- open vaults;
- sentries.

They **no longer detect sound**.

### 1.5 Security cameras and the security room (VERIFIED (wiki) [Stealth])
- **Ordinary cameras** die to one shot below Mayhem. The camera operator may then **send a guard to investigate**, which is useful as a lure.
- **Camera operator:** usually a guard *with a pager*, in a security room. Killing him **permanently disables all cameras** and gives the crew access to the camera feed. Viewing the feed highlights guards and items for everyone for several seconds.
- **"Titan" cameras** (Mayhem and above on many maps) are indestructible. ECM, a camera loop or killing the operator still neutralises them.
- **Drone variant:** patrols, cannot be looped, has a longer detection range and no operator.
- **Camera loop (Nimble basic):** disables 1 camera for **25 s** and can be reapplied. Only **one looped camera per crew** at a time ([Skills]).

### 1.6 Pagers (VERIFIED (wiki) [Stealth])
- **Trigger:** killing **or dominating** a guard. Only guards carry pagers. Police, civilians and gangsters do not (with one scripted exception).
- **Timeline:**
  1. The pager starts beeping **2–4 s** after the kill or domination.
  2. The crew has **12 s** to **start** answering.
  3. Answering is a **10 s** hold interaction (**9 s** with the Burglar deck's "answer pagers 10% faster" card, [Perks]).
- **Cap: 4 answers for the whole team per heist.** The **5th** answer raises the alarm when it completes. Some Crime Spree modifiers lower the cap. On some heists a replacement guard spawns after 3 answers.
- **Releasing the interaction early raises the alarm immediately**, *unless* another player is answering the same pager at that moment.
- **Juggling:** two players can alternate overlapping holds to keep a pager open indefinitely. Only the first completion counts.
- **ECM effect:** an ECM affects pagers **only** with **ECM Specialist aced**. That skill **pauses** the 12 s response window of pagers whose guard died **during** the jam ([ECMSpec]). It does not touch a pager that is already counting down.
- **Domination in stealth:** one shout makes a guard who has **just** detected you kneel and cuff himself, because there is a **1.5 s near-guaranteed window** after the meter fills ([Shout]). His pager still fires. **Joker conversion is impossible in stealth.**

### 1.7 Body bags (VERIFIED (wiki) [Cleaner], [BBC], [Perks])
- **Base:** each player carries **1** body bag, with an inventory cap of **2**.
- **Cleaner basic:** +1 bag, cap raised to **3**. **Cleaner aced:** you can place **2** Body Bag Cases instead of 1.
- **Body Bag Case:** a deployable holding **3 bags**. The base allowance is 1 case.
- A body-bag **asset** can be bought pre-heist.
- Burglar's "Bag of Tricks" card bags corpses **20% faster**.
- **Design note from the wiki:** with 4 pagers available, a full crew's four base bags already cover the 4 guards that can be killed safely.

### 1.8 Cable ties, civilians and hostages
- **Cable ties:** base **2**. **Forced Friendship basic** gives **+4 (6 total)** and ties **75% faster**, cutting tie time from **2 s to 0.5 s**. You can carry **up to 9** with ties picked up from ammo boxes. VERIFIED (wiki) [Civ], [FF]
- **Intimidating civilians:** shout (the interact key) to make them lie down. Stockholm Syndrome basic lets your **noise** do the same. **They get back up after a while** if nobody watches them. Tied civilians stay put until police free them, and players can lead tied hostages around. VERIFIED (wiki) [Stealth], [Civ]
  - **Base "stay down" duration: UNVERIFIED (community claim).** About **50 s** according to a Steam forum guess. The wiki has no number.
  - With Stockholm noise, the wiki says at least **45 s** can pass between gunshots and controlled civilians stay down ([Stockholm]).
  - **CONFLICT:** the Stockholm skill text says "+50% longer intimidation", but [Civ] notes that the 50% actually belongs to Forced Friendship.
- **Civilian kill penalty (cleaner costs).** VERIFIED (wiki) [Sixth], [Custody]
  - Killing a civilian deducts **spending cash** immediately, even if the heist then fails.
  - The cost scales with job tier and difficulty:

    | Difficulty | Cheapest job tier | Most expensive job tier |
    |---|---|---|
    | Normal | $2,000 | $17,000 |
    | Death Wish | $12,000 | $51,000 |

  - Sixth Sense aced cuts cleaner costs by **75%**.
  - Each civilian a player has killed adds **+30 s** to that player's custody trade negotiation ([Custody]).

### 1.9 ECM jammer (VERIFIED (wiki) [ECM], [ECMSpec], [Skills])
- **Deploy and duration:** deploying takes **2 s**. The jam lasts **20 s**, and the light starts flashing with 8 s left. Two simultaneous jammers do not stack.
- **What it jams:** **all cameras** (globally) and **all cellphones**. It does **not** jam pagers (except with ECM Specialist aced), laser sensors, metal detectors, panic buttons or silent alarms, and it does not stop an already fully alerted camera.
- **Skill effects:**
  - **ECM Overdrive basic:** +25% duration. **Aced:** opens keycard doors.
  - **ECM Specialist basic:** carry **2** ECMs. **Aced:** another +25% and pager delay.
  - Total with both duration bonuses is **31.25 s** (20 × 1.25 × 1.25).
- **Using an ECM on an ATM or keycard door:** spends one jammer. It takes **8 s** for an ATM and **4 s** for a door, and the jammer has no other effect when used this way.
- **Feedback (loud tool):**
  - Interacting with a placed ECM is instant. It **stuns almost all enemies in range** (Cloakers are immune), deals 1 damage and makes heads easy to hit.
  - It recharges **every 4 minutes** per ECM.
  - Used in stealth, it **alerts** any guards and civilians it hits.
- **Pocket ECM (Hacker deck)** ([PocketECM]):
  - Lasts **6 s** and has **2 charges**.
  - Each charge recharges in **100 s**, minus 6 s per kill. Charges recharge one after the other, so the worst case is 200 s.
  - It **cannot** open ATMs or doors.

### 1.10 Drills, saws and breaching (VERIFIED (wiki) [Drills], [HWE], [DS], [Kick], [Doors], [Trip])
- **Drill times:** a basic drill takes **180 s on a security door**, **60 s on cages**, and **360 s for a thermal drill**.
  - Placing a drill takes **3 s**. Upgrading a running drill takes **10 s**.
  - An upgrade applies to the **remaining** time.
- **Jamming:** every drill or saw is scripted to jam **up to 3 times**, with the jams chosen at random when it is placed. Thermal drills follow the same rule.
- **Noise:** an unskilled drill is heard within **25 m**, or **12.5 m** if line of sight is blocked. Guards and gangsters walk over to investigate.
- **Hardware Expert:**
  - **Basic:** fix drills **25% faster**, **silent drills** (noise radius 0), and trip mines deploy 20% faster.
  - **Aced:** +**10%** auto-restart chance.
- **Kickstarter:**
  - **Basic:** +**20%** auto-restart chance, so up to 30% with Hardware Expert aced.
  - **The roll happens once**, when the drill is placed, upgraded or repaired. A drill that wins the roll *always* auto-restarts afterwards, within about 5–20 s (the Kickstarter page says "up to 10 s").
  - **Aced:** a melee hit has a **50%** chance to fix a jam, once per jam per player.
- **Drill Sawgeant:** **−15% / −30%** drill and saw time. Aced, this saves almost 2 minutes on a thermal drill.
- **Saws** (placed rigs) work like drills and use the same skills.
- **OVE9000** is a separate portable-saw weapon.
- **Exempt from all drill skills:** some special drills (the multi-part "Beast", the plasma-cutter "BFD", and a few others).
- **Shaped charges ("C4"):**
  - They come with the **trip mine** deployable: **3 base**, **6** with More Firepower aced. They cannot be resupplied.
  - Charges needed: a GenSec security door takes **3**, an armoured truck **4**.
  - They are **loud**.
- **Trip mines:** **1,000** damage in a **3 m** radius with no falloff, and a 1 s arming time. Sensor mode uses a blue laser that marks targets.
- **Lockpicking:** most doors can be picked. Nimble aced picks **100% faster** (the [Doors] page says "−50% time") and lets you pick safes.
- **GenSec doors** cannot be picked or shot. You drill, saw, blast or use a keycard, or an ECM with Overdrive aced.
- **Laser grids** trip the alarm even in civilian mode ([Stealth]). The ECM does not affect them ([ECM]). We found no per-heist numbers.

### 1.11 Stealth reward
- Finishing a heist in stealth grants a **"Stealth bonus" applied to the *next* heist's XP**. VERIFIED (wiki) [Stealth]
  - **CONFLICT:** [Payday] gives the size as **0–25%**, while [Rep] says **0–30%** in one place and **5–25%** in another.

---

## 2. Loud

### 2.1 Police assault cycle (VERIFIED (wiki) [Assault] unless marked)
**Phases:**
1. **Control** (the first time) or **Recon** (later): first responders, plus hostage-rescue teams if a civilian hostage or loot bag is on the map.
2. **Anticipation:** **30 s**. Having at least 1 hostage adds **+30 s** on Overkill and below, or **+10 s** on Mayhem and above. Extra hostages add nothing more.
3. **Build:** about **35 s**. SWAT moves in with flashbangs and smoke.
4. **Sustain:** the assault proper. Its duration depends on the "stage" and on player count:

   | Stage | 1 player | 2 players | 3 players | 4 players |
   |---|---|---|---|---|
   | "50%" | 40 s | 44 s | 48 s | 52 s |
   | "75%" | 120 s | 132 s | 144 s | 156 s |
   | "100%" | 160 s | 176 s | 192 s | 209 s |

   Sustain was shortened in Update #181.
5. **Fade:** SWAT stops spawning and retreats when **fewer than 50 enemies** remain **or** after a long wait in which **no player takes serious damage** (low "drama"). The intro also states it as a **30 s window without serious damage after the timer ends**. Fade **cannot happen while Captain Winters is present**.

**Other rules:**
- **Escalation:** later waves use later stages, and difficulty raises spawn counts, accuracy and damage. Specials keep spawning between waves (Cloakers *more* between waves). The assault banner shows difficulty skulls. **Some escape phases are never-ending assaults.**
- **Assaults and custody:** no custody negotiation happens *during* an assault, but a trade started before the assault can still be completed.
- **Domination works during assaults** in PD2. In PD1 it did not.

### 2.2 Downs, bleedout and custody (VERIFIED (wiki) [Custody], [NineLives], [Bullseye], [DocBag], [FAK], [Inspire])
- **Bleedout timer:** **30 s**. While bleeding out you can shoot, throw grenades and toss bags, but you cannot move or deploy.
  - **Bleedout health is 100**, or 150 with Nine Lives basic. If it runs out you become fully incapacitated.
  - Police **won't shoot a downed player who isn't shooting at them.**
- **Down limit:** **3 downs.** The **next** (4th) time your health hits zero you go **straight to custody**, with no bleedout. Nine Lives aced raises the limit to 4. One Down mode allows 1, or 2 with Nine Lives aced.
  - The counter resets **only through a Doctor Bag or release from custody**. First Aid Kits do not reset it.
  - At the last down the screen turns black and white.
- **Taser and Cloaker take-downs do NOT use bleedout and do NOT count toward the down limit.** The player is helpless until revived.
- **Revive interaction:** **6 s**, or 3 s with Inspire basic.
  - **Inspire aced:** shouting revives instantly from up to **9 m** away, with a **20 s** cooldown.
  - **Inspire basic shout:** teammates get +20% movement and reload speed for 10 s. This shout has a 3.5 s cooldown.
- **Health after revive:** you lose **60% of base max health** on Overkill and below, or **90%** on Mayhem and above. The loss applies only on the first down; later downs don't reduce it further. Combat Medic aced (+30%) and Up You Go aced (+40%) raise it.
- **Custody:**
  - Released players come back at **full health with 50% ammo**. Deployables are not refilled.
  - Any loot you carried drops where you were taken.
  - On **Hard and below** there is a **119 s** auto-release timer. On **Very Hard and above** the only way back is a **hostage trade**.
  - The heist fails when **all humans** are in custody.
- **Hostage trade:**
  - Bain negotiates automatically, starting outside an assault. Negotiation takes **5 s plus 30 s per civilian that player killed**.
  - Then a hostage (a tied civilian or a dominated cop) is highlighted and traded.
  - Once highlighted, the hostage can be traded even during an assault.
  - Stockholm Syndrome aced: your hostage trades itself for you automatically, **even mid-assault**, once per heist.
- **XP penalty for ending a heist in custody:** **CONFLICT.** [Payday] says **−30% XP**, but [Custody] says "roughly 5%".
- **Doctor Bag:** **2 uses**, or 4 per bag with Combat Doctor aced, which also gives 2 bags. Each use fully heals and resets downs.
- **First Aid Kit:** **4** base, then 11 with Uppers basic and 14 aced. Deploys in **1 s**. Heals but **does not reset downs**.

### 2.3 Armor, damage taken, dodge
**VERIFIED (wiki) [Armors]**, field labels from Template:Armor:

| Armor | Armor value | Concealment | Speed | Dodge | Steadiness | Stamina | Unlock |
|---|---|---|---|---|---|---|---|
| Two-Piece Suit | 20 | **30** | 36.8 | **+5** | 11 | 51.3 | default |
| Lightweight Ballistic Vest | 50 | 26 | 35.9 | −5 | 11.5 | 50 | Rep 7 |
| Ballistic Vest | 60 | 23 | 35 | −10 | 12 | 47.5 | Rep 1 |
| Heavy Ballistic Vest | 70 | 21 | 33.3 | −15 | 12.9 | 45 | Rep 12 |
| Flak Jacket | 90 | 18 | 26.3 | −20 | 13.8 | 42.5 | Rep 21 |
| Combined Tactical Vest | 110 | 12 | 22.8 | −25 | 15.7 | 40 | Rep 31 |
| Improved CTV | **170** | **1** | 20.1 | **−55** | 22 | 35 | **Iron Man aced** |

- **Armor gating:** armor absorbs damage before health does.
  - **Every enemy hit except Sniper and Marksman shots is capped at the armor you have left.** Even 5 armor absorbs a whole shot.
  - After a hit there is a **0.35 s invulnerability** window.
  - Copycat notes give **0.45 s on Overkill and below and 0.35 s on Mayhem and above** ([Perks]).
  - Sources: [Armors], [Bullseye].
- **Armor regeneration:** after a short delay without taking damage, armor refills completely.
  - The delay resets on any damage **or any dodge**.
  - Default delay: "**3 seconds when playing online**" ([Bullseye]).
  - The armor *value* does not change regen speed, except on Anarchist.
  - **UNVERIFIED (community claim):** different armor tiers regenerate at different rates. One Steam claim gives "Suit: 10 armor / 2 s; LBV: 15 / 3 s".
- **Dodge:** the chance that a ranged hit deals no damage. Melee hits can also be dodged, but the knockback still applies. Dodge is **additive**, and any negative total means you can never dodge ([Armors]). Sources of dodge:
  - armor base value;
  - Sneaky Bastard: **+1% per 3 DR below 35 (basic) or per 1 DR below 35 (aced), up to +10%**. The tooltip wrongly says "concealment" ([SneakyB]);
  - Duck and Cover aced: +10% while sprinting;
  - Rogue deck: +45% total;
  - Burglar deck: +30%;
  - Crook deck: up to +40% in ballistic vests;
  - Ex-President deck: +15%;
  - Sicario deck;
  - Hacker deck: unlisted +15% / +30%.
- **Player base health:** not found on the wiki (the /Health page is missing). UNVERIFIED (community): 230 display units at max level.

### 2.4 Weapons and damage
VERIFIED (wiki) [WPStat], [WPMech], [CAR4Mods]
- **Displayed weapon stats:**
  - Magazine
  - Total ammo
  - Rate of fire (RPM)
  - Damage
  - Accuracy (cap 100)
  - Stability (cap 100)
  - **Concealment (cap 30 per weapon)**
  - **Threat** (cap 43)
  - Reload time, listed as tactical | empty
- **Hidden stats:** ammo pickup rate. Walk-in Closet sets it to 135%; Fully Loaded aced sets it to 175% and does not stack.
- **Weapon mod categories** (tabs on a typical rifle):
  - Barrel
  - Barrel Ext
  - Custom
  - Exclusive Set
  - Foregrip
  - Gadget
  - Grip
  - Lower Receiver
  - Magazine
  - Sight
  - Stock
  - Upper Receiver

  Elsewhere the wiki also mentions Boost (stat-boost) mods, ammunition types for shotguns, slides for pistols, and others.
- **Falloff ("optimal range")** by weapon class, qualitative only:
  - Assault rifles: **no** falloff.
  - Shotguns: much less damage beyond close range, except with AP slugs.
  - LMGs and SMGs: less beyond medium range.
  - Pistols: moderately less beyond close range.
  - **Snipers: *more* damage beyond medium range.**
  - Special weapons: immune to falloff.
  - Per-weapon numbers are on each weapon's own page. We did not collect them.
- **Headshots:** a multiplier that depends on enemy and difficulty (see 2.6). For shotguns, **any one pellet** on the head counts as a headshot. Helmet Popping (a shared perk card) adds **×1.25**.
- **Critical hits** (from Low Blow or Unseen Strike) add another headshot multiplier that stacks multiplicatively.
- **Armor piercing:** sniper rifles, AP slugs and AP pistols pierce enemy body armor, shields, thin walls and bodies. Fire ignores armor and shields. A shot that pierces a shield deals about **25%**.
- **Bulldozers have no "armor" in game terms**, just huge HP plus faceplates.
- **Suppression ("Threat"):** suppression builds from damage, or from shots landing **near** an enemy. **Specials and GenSec units are immune.**
  - **First threshold:** the enemy hunches, takes **+50%** longer between shots, takes **+50%** longer to acquire a target, and gets **−50%** hit chance.
  - **Second threshold:** the enemy dives for cover out of your line of sight.
  - **After it wears off:** **50% threat resistance for 30 s**.
  - Threat does **not** affect surrender chance. Suppressed weapons usually have **0** threat.
- **Suppressors:** noise radius **0 m**, occasionally 1 m.
- **Explosives:** damage = base × (1 − d/r)^curve. The curve is usually 0.1.

### 2.5 Special enemies (VERIFIED (wiki) unless marked)
- **Cloaker** ([Cloaker], [Diff]):
  - Spawns on **Very Hard and above**, with a natural **spawn cap of 2** at a time.
  - **Telegraphs:** an electrical "phone ring" hum after spawning and while nearby. When it commits to a charge, its **goggles glow green** and the sound gets louder.
  - **Attack:** a sprinting jump-kick that **instantly incapacitates**. There is no bleedout and **no down is counted**. It then beats the downed player, drops smoke, and may camp the body to ambush rescuers.
  - **Kick cooldown:** about **10 s**. A sidestep can dodge it.
  - **Behaviour:** ambushes from vents, manholes and under cars, plays dead, and flanks.
  - **Immune to ECM feedback.**
  - **Will not kick a solo player with no AI teammates, or the last player standing.**
  - **Counterstrike aced** (melee charge) knocks it down.
  - Its headshot multiplier is the highest of the specials.
- **Taser** ([Taser]):
  - **Windup:** an audible high-pitched charge of about **1 s**.
  - **The tase loop:** the victim cannot move or interact, convulses, and the weapon **auto-fires and auto-reloads** (an instant reload).
  - **Breaking the loop:**
    - kill the Taser, either yourself (you can still click to shoot) or with teammates;
    - Shockproof basic: a **30%** chance to knock the Taser back after about 1–3 s;
    - Shockproof aced: **interact within 2 s** to shock it back.
  - **If nobody breaks it:** a long tase eventually downs you silently, with no bleedout and no down counted.
  - Tasers deploy in pairs and switch to a new target if one walks up.
- **Shield** ([Shield]):
  - The riot shield is impenetrable from the front, except to explosives, fire and AP (AP passes at about 25% damage).
  - **Behaviour:** blocks doorways, fixates on one player, acts as mobile cover for Tasers and Dozers, and bangs the shield to announce itself.
  - **Counters:** flanking, which it handles poorly at close range, and Shock and Awe aced, which staggers it.
  - **Even a dropped shield still blocks bullets.**
- **Bulldozer** ([Dozer]):
  - **Headshot-immune until the faceplate (150 HP) and then the visor (160 HP) are shot off.** These values are the same on every difficulty.
  - Immune to stuns and fire flailing (since the Housewarming event). Sprints while firing. Takes ×1.1 damage from explosives.
  - **Variants:**
    - Green: pump shotgun, Very Hard+.
    - Black: semi-auto shotgun, Very Hard+.
    - Skull: LMG, Mayhem+.
    - Minigun: double HP, slow, Death Wish+.
    - Medic: Death Sentence only.
- **Sniper** ([Sniper]):
  - **Red laser plus a loud report.** Damage per hit by difficulty: **100 / 140 / 160 / 200 / 240** for Normal / Hard / Very Hard / Overkill / Death Wish.
  - Beyond **30 m** damage is **halved on every difficulty except Death Wish**. Death Sentence values are missing from the wiki.
  - **Sniper damage bypasses the armor-gating cap** if it exceeds your remaining armor.
- **Medic** ([Medic], [Diff]):
  - Heals or revives **one** ally within **7 m**, even **through walls**. The ally gets a green outline. Base cooldown **3 s**.
  - It cannot move or shoot while healing, and neither can its target.
  - Medics can no longer heal each other (since Update #242).
- **Captain Winters and the "Phalanx"** ([Winters]):
  - Appears once per heist day on **Very Hard and above**, and only on online lobbies. He arrives during an assault with **10 shield "minions"**.
  - **Movement:** walks to a set spot and forms a testudo or circle.
  - **On arrival:** the assault becomes **locked, unable to end until he retreats**, and **all enemies gain 10% damage resistance**.
  - **Once in position:** another **+5% every 5 s**, up to a cap of **50%** after 40 s.
  - **His group:** Winters and the Phalanx each take **at most 10% of max HP from any single hit**. They take **×6 damage from explosives** and do not flinch.
  - **Retreat:** **Winters cannot be killed.** He retreats permanently when he is reduced to **20% HP**, or when the formation falls to about 3 shields. After that the assault proceeds to end normally.
- **Common units:** some heavies have frontal body armor, so shoot their heads or use AP. Guards, police and gangsters cannot be dominated if they are specials or gangsters. **Converting** a surrendered enemy (Joker) creates an ally, at most 1, or 2 with Confident aced.

### 2.6 Difficulty tiers (VERIFIED (wiki) [Risk], [Diff], [Payday], [Custody])
Order: **Normal → Hard → Very Hard → Overkill → Mayhem → Death Wish → Death Sentence.** One Down is a separate toggle.
- **Hosting Death Wish or Death Sentence needs reputation 80+.**
- **Enemy factions:** SWAT (Normal and Hard) → FBI (Very Hard and Overkill) → GenSec (Mayhem and Death Wish) → ZEAL (Death Sentence).
- **Titan cameras and Titan safes** appear on Mayhem and above.

HP is shown in the wiki's display units (×10 of the internal value, the same scale as weapon damage stats). "HS×" is the wiki's "headshot multiplier" column.

| Unit | Normal | Hard | Very Hard | Overkill | Mayhem | Death Wish | Death Sentence |
|---|---|---|---|---|---|---|---|
| Light SWAT HP (HS×) | 80 (2) | 80 (2) | 160 (4) | 240 (6) | 480 (4) | 480 (3) | 480 (3) |
| Heavy SWAT HP | 160 | 160 | 320 | 480 | 960 | 960 | 960 |
| Shield HP | 80 | 80 | 160 | 240 | 480 | 480 | 480 |
| Taser / Medic HP | 300 | 300 | 600 | 900 | 1,800 | 1,800 | 1,800 |
| Cloaker HP (HS×) | 600 (6) | 600 (6) | 1,200 (12) | 1,800 (18) | 3,600 (12) | 3,600 (9) | 3,600 (9) |
| Bulldozer HP (HS×) | 2,000 (5) | 2,000 (5) | 4,000 (10) | 6,000 (15) | 12,000 (10) | 12,000 (7.5) | **24,000** (7.5) |
| Minigun Dozer HP | — | — | — | — | — | 24,000 | 48,000 |
| Winters / Phalanx HP | 3,000 / 1,500 | same | same | 6,000 / 3,000 | 8,000 / 4,000 | 8,000 / 4,000 | 8,000 / 4,000 |
| Sniper HP | 40 | 40 | 80 | 120 | 240 | 240 | 240 |
| XP multiplier | ×1 | ×2 | ×5 | ×10 | ×11 or ×11.5 (CONFLICT [Diff] vs [Payday]) | ×13 | ×14 |
| Loot-bag value multiplier | ×1 | ×2 | ×2.6 | ×4.2 | ×7.2 | ×8.2 | ×9.2 |
| Revive health lost on first down | 60% | 60% | 60% | 60% | 90% | 90% | 90% |
| Custody | 119 s timer | 119 s timer | trade only | trade only | trade only | trade only | trade only |

- **Spawn caps** (Overkill example): Shields 4, Tasers 2, Medics 3, Cloakers 2, Dozers 2. They rise on Mayhem and above: Tasers 3, then Dozers 3 on Death Sentence.
- **Hostage assault delay:** 30 s on Overkill and below, 10 s on Mayhem and above.

---

## 3. Progression

### 3.1 Skill system (VERIFIED (wiki) [Skills])
- **Points:** **1 skill point per reputation level, plus 2 extra at every 10th level, for 120 points at level 100.**
- **Structure:** **5 trees × 3 subtrees × 6 skills = 90 skills.**
  - Each subtree has tiers 1 / 2 / 3 / 4 with **1 / 2 / 2 / 1** skills.
  - **Tier unlocks:** tier 2 after **1** point spent in that subtree, tier 3 after **3**, tier 4 after **18**. Tier 4 drops to **16** after the first Infamy level.
- **Costs (Basic / Aced):**

  | Tier | Basic | Aced |
  |---|---|---|
  | T1 | 1 | 3 |
  | T2 | 2 | 4 |
  | T3 | 3 | 6 |
  | T4 | 4 | 8 |

  Fully acing one subtree costs 46 points. A whole tree costs **138**, so **you cannot finish even one tree** with 120.
- **Stacking:** team-wide bonuses from the *same* skill held by several players do **not** stack.
- **Loadouts:** you can respec freely and keep multiple skill sets (up to 15 on PC), each tied to a perk deck.
- The full skill list with tiers and Basic/Aced text is in **Appendix A**.

**Game-changers by subtree** (details in Appendix A):
- **Mastermind / Medic:** Inspire (T4).
- **Mastermind / Controller:**
  - Forced Friendship (T1)
  - Joker (T2)
  - Stockholm Syndrome (T3)
  - Partners in Crime (T3)
  - Hostage Taker (T4)
- **Mastermind / Sharpshooter:** Graze (T4).
- **Enforcer / Shotgunner:** Overkill (T4).
- **Enforcer / Tank:**
  - Bullseye (T3)
  - Iron Man (T4, unlocks the ICTV armor)
- **Enforcer / Ammo Specialist:**
  - Bulletstorm (T2)
  - Fully Loaded (T4)
- **Technician / Engineer:** sentry guns (cost ammo to deploy).
- **Technician / Breacher:**
  - Hardware Expert (T1)
  - Drill Sawgeant (T2)
  - Kickstarter (T3)
- **Technician / Oppressor:**
  - Surefire aced (pierces armor)
  - Body Expertise (T4)
- **Ghost / Shinobi:**
  - Chameleon (T1)
  - Cleaner (T2)
  - Sixth Sense (T2)
  - Nimble (T3)
  - ECM Overdrive (T3)
  - ECM Specialist (T4)

  ECM Feedback is now built into every ECM (since Update #100).
- **Ghost / Artful Dodger:**
  - Inner Pockets (T2)
  - Dire Need (T3)
  - Shockproof (T3)
  - Sneaky Bastard (T4)
- **Ghost / Silent Killer:**
  - Second Wind (T1)
  - Optical Illusions (T2)
  - Low Blow (T3)
  - Unseen Strike (T4)
- **Fugitive / Gunslinger:** Trigger Happy (T4).
- **Fugitive / Revenant:**
  - Nine Lives (T1)
  - Swan Song (T3; 3 s, or 6 s with infinite ammo when aced; 60% move penalty; doesn't trigger on fall or fire damage)
  - Messiah (T4; self-revive by getting a kill)
- **Fugitive / Brawler:**
  - Counterstrike (T3)
  - Berserker (T3)
  - Frenzy (T4)

### 3.2 Perk decks (VERIFIED (wiki) [Perks])
- **There are 23 decks with 9 cards each.** The page intro still says "22", an out-of-date figure.
  - Cards are bought in order with **perk points** converted from XP.
  - **13,700 points** buy a full deck. Card costs are **200 / 300 / 400 / 600 / 1,000 / 1,600 / 2,400 / 3,200 / 4,000**.
  - **315,100 points** buy all 23 decks.
  - Decks are **not** reset by Infamy.
  - Only one deck can be active.
- **Shared cards (2, 4, 6, 8 in every deck), plus a completion bonus on card 9:**
  - **Card 2, Helmet Popping:** +25% headshot damage.
  - **Card 4, Blending In:** +1 concealment, armor movement penalty 15% smaller, **+45% XP**.
  - **Card 6, Walk-in Closet:** unlocks the **Armor Bag** (change armor mid-heist) and sets ammo pickup to 135%.
  - **Card 8, Fast and Furious:** +5% damage, +20% Doctor Bag interaction speed.
  - **Card 9:** the deck's own final perk **plus** "Deck Completion Bonus": +10% chance of a higher-quality item from PAYDAY card drops.
- **Unique cards are 1, 3, 5, 7 and 9.** Each deck's signature in one line:

| Deck | Signature |
|---|---|
| Crew Chief | Team aura: damage reduction, +stamina, +health, +armor, plus bonuses scaling with hostage count. |
| Muscle | Huge health (up to +100%), draws aggro, panic on hit; card 9 regenerates 3% health every 5 s. |
| Armorer | +armor (up to about +35%); **2 s health immunity when armor breaks** (15 s cooldown); team armor regen. |
| Rogue | Dodge (+45% total), less aggro, 80% faster weapon swap, 25% armor-pierce chance. |
| Crook | Dodge and armor bonuses that only apply in **ballistic vests**. |
| Hitman | Armor regen speed; **armor always comes back 1.5 s after breaking**. |
| Burglar | Stealth utility (faster bagging, lockpicking and pager answering) plus dodge; armor regen while still or crouching. |
| Infiltrator | Damage reduction at close range; melee combo ×10; melee hit heals 20% (10 s cooldown). |
| Sociopath | Kill-chain sustain: **30 armor per kill** (1 s cooldown), health on melee kills, panic at medium range. |
| Gambler | Ammo pickups heal you and are shared with the crew. |
| Grinder | **Heal over time from dealing damage**; suit or LBV only. |
| Yakuza | Lower health gives faster armor regen and movement. |
| Ex-President | Banks health from kills while armor is up, paid out when armor breaks. |
| Maniac | Damage dealt becomes "Hysteria" stacks, giving damage absorption that is shared with the crew. |
| Anarchist | Converts 50% of health into armor; armor regenerates continuously in ticks instead of all at once; armor on hit. |
| Biker | Health and armor on any crew kill, rate-limited. |
| Kingpin | Active "Injector": for 6 s you heal 75% of the damage you take (30 s cooldown, −1 s per kill); you draw aggro while it is active. |
| Sicario | Active smoke bomb gives dodge inside the smoke; dodge refills armor. |
| Stoic | No armor (converted into health); damage becomes damage over time; a flask cancels it. |
| Tag Team | Tag an ally; both heal on each other's kills. |
| Hacker | Pocket ECM: jams or causes feedback; heals and dodge on kills. |
| Leech | Ampule (6 s, 40 s cooldown): restores 40% health, turns armor off, splits health into 20% segments (each hit removes one), 2 kills restore a segment, and taking damage heals teammates 5%. |
| Copycat | Build-your-own deck: choose bonus options per card; mimic another deck's card 9. |

  Full card text is in **Appendix B**.

### 3.3 How concealment becomes detection risk
VERIFIED (wiki) [Stealth], [WPStat], [Armors]
- **Formula:** total concealment = primary + secondary + melee + armor + skill and perk bonuses. Each weapon's concealment is capped at 30, and the suit is 30.
- **Mapping:** the total converts to DR (119+ gives 3, 91 or less gives 75; see 1.2). DR then sets both the meter's start % and the speed and range multiplier.
- **Concealment bonuses:**
  - +1 from Blending In (shared perk card 4)
  - +2 melee from Inner Pockets basic
  - +4 on ballistic vests from Inner Pockets aced
  - +1 per silenced weapon from Optical Illusions aced, plus a smaller silencer penalty
- **Worked example from the wiki:** a suit (30) plus a 30-concealment melee, +2 Inner Pockets and +1 perk card gives 63. You then need **56** more from the two guns to reach DR 3.
- **Effects of DR beyond detection:**
  - Sneaky Bastard dodge
  - Low Blow critical-hit chance (up to 30%)
  - Loud targeting range (80–180 m)

---

## 4. Structure and charm

- **Job board.** "CRIME.NET" is a city map of contracts from various "contractors", each with a theme. It doubles as matchmaking, with online and offline modes and up to 4 players ([PD2], [Contractor]). VERIFIED (wiki)
- **Contract broker.** You can buy any contract with **offshore money**. Higher difficulties cost more ([Risk], [Contractor]). VERIFIED (wiki), qualitative only. We found no price table.
- **Assets.** These are bought before the heist with **spending cash**.
  - Prices scale with difficulty.
  - Assets are one-use, and any crew member can buy them.
  - Examples: intel, a body bag drop, doctor and ammo drops, an escape-driver upgrade.
  - Sixth Sense aced unlocks "insider" assets ([Assets]).
  - VERIFIED (wiki)
- **Pre-planning.** VERIFIED (wiki) [PrePlan], [BBPrePlan]
  - **The board:** some heists replace Assets with a **blueprint board**. Players place assets at specific map locations and can **draw on the map**.
  - **Favors:** a **fixed "favor" budget per day** that does not scale with difficulty. The Big Bank has **10 favors**. Each asset costs favors *and* cash, and has location and max-count limits.
  - **Cost example:** a Doctor Bag drop costs 2 favors and **$1,600 on Normal up to $20,800 on Death Wish**.
  - **"Plans"** (vault method or escape route) need a **majority vote**, and the host breaks ties. Each heist has a free "Plan B" plus paid alternatives. For example, the Big Bank offers vault options (the free multi-part drill, thermite or C4) and escapes (the free helicopter, an elevator route or a bus).
- **Difficulty names:** see 2.6.
- **Results screen ("PAYDAY").** VERIFIED (wiki) [Payday]
  - **Contents:** mission time, per-player kills, downs, civilian kills, a cash breakdown and an XP breakdown.
  - **Cash:** (contract pay + secured bag loot) × crew-alive bonus (110% if everyone escapes). The split is **80% offshore and 20% spending cash**.
  - **XP calculation order:**
    1. Heist XP
    2. Pro bonus, +20%
    3. Difficulty multiplier
    4. −30% if you are in custody (see the CONFLICT in 2.2)
    5. Additive bonuses: Blending In +45%, Infamy +5–205%, crew alive +10% per surviving teammate (up to +30%), event bonuses, all hidden collectibles found +5%
    6. Multiplicative bonuses: the stealth bonus carried over from the previous heist, and the experience penalty or boost
- **Card drop.** **Pick 1 of 3 face-down cards.** If you don't pick, a random one is chosen after a **30 s** timer. You can also gamble offshore money on cards. VERIFIED (wiki) [Payday]
  - **Card types:**
    - mask components (mask, material, pattern or color), sometimes in an "infamous" quality;
    - cash, **$20,000–$100,000**;
    - XP;
    - weapon mods, at most 2 unused copies of any one mod;
    - stat-boost mods;
    - cosmetic skins.
  - Safe and drill cards were removed in Update 199.3.
- **Masks.** A mask is a **base mask + color + pattern + material**. Card-dropped masks are consumed when you customize them ([PD2], [MasksPD2]). VERIFIED (wiki)
- **Prestige ("Infamy").** VERIFIED (wiki) [Infamy]
  - There are **500 Infamy levels**. You need **reputation 100**; the first 5 levels also cost **$200M offshore** and wipe your spending cash.
  - **Infamy resets** your reputation to 0, your skills, and the level locks on gear. You can skip the reset by spending **30M XP from the "Infamy Pool"**.
  - **You keep** masks, slots and perk decks.
  - **Rewards:** an XP bonus of **5–205%**, a tier-4 skill unlock at 16 points instead of 18, cosmetic "card" badges (rank suits change every 100 levels), and themed masks.
  - The leveling curve runs from 900 XP for level 0→1 to 1,000,000 XP for 99→100. Reaching level 100 takes about 23M XP ([Rep]).
- **Endless mode ("Crime Spree").** VERIFIED (wiki) [Spree]
  - **Access:** level 60+ or Infamous.
  - **Format:** a chain of one-day heists. The host picks from 3 choices. Rank 0 equals Overkill, and difficulty rises with every heist. Stacking modifiers are added.
  - **Currency:** "continental coins". Rerolling the 3 choices costs 6 coins, and the cost doubles every third reroll.
  - **Rewards** are independent of loot, so you only need the minimum bags.

---

## 5. Items we could NOT confirm

All of these are **UNVERIFIED (community claim)** or missing:
- the exact detection-meter distance and angle formula, and whether **crouching or walking speed** changes fill rate against guards;
- **guard investigation ("?") durations**, such as how long a guard searches before giving up;
- **how long intimidated civilians stay down**; about 50 s is a Steam forum guess;
- **armor regen rate per armor tier** (the wiki gives only the about-3 s delay);
- **player base health** (about 230 is a community figure);
- per-weapon falloff distances;
- the contract broker price table;
- Death Sentence sniper damage;
- the base Medic heal cooldown beyond the wiki's "3 s".

---

## Appendix A. Full skill list (VERIFIED (wiki), https://payday.fandom.com/wiki/Skills)

T = tier. B = Basic text. A = Aced text, quoted from in-game descriptions on the wiki. The in-game text is sometimes wrong; see the notes in the main body (Chameleon, Sneaky Bastard, Stockholm Syndrome).


### Mastermind / Medic
- T1 **Combat Medic** — B: You gain a 30% damage reduction for 5 seconds both after and during reviving another player. | A: Reviving a crew member gives them 30% more health.
- T2 **Quick Fix** — B: Decreases your First Aid Kit and Doctor Bag deploy time by 50%. | A: Crew members that use your First Aid Kits or Doctor Bags take 10% less damage for 120 seconds.
- T2 **Painkillers** — B: Crew members you revive take 30% less damage for 5 seconds. | A: The damage reduction is increased by an additional 50%.
- T3 **Uppers** — B: Adds 7 more First Aid Kits to your inventory. | A: Adds 3 First Aid Kits to your inventory. Your deployed First Aid Kits will be automatically used if a player is downed within a 5 meter radius of the First Aid Kit. This cannot occur more than once every 20 seconds.
- T3 **Combat Doctor** — B: You can now deploy 2 Doctor Bags instead of just one. | A: Your doctor bags have 2 more charges.
- T4 **Inspire** — B: You revive crew members 100% faster. Shouting at your teammates will increase their movement and reload speed by 20% for 10 seconds. | A: There is a 100% chance that you can revive crew members at a distance of up to 9 meters by shouting at them. This cannot occur more than once every 20 seconds.

### Mastermind / Controller
- T1 **Forced Friendship** — B: Increases your supply of cable ties by 4. You can cable tie hostages 75% faster. | A: You and your crew gain 0.5 damage absorption for each hostage you have. This effect stacks with up to a maximum of 8 hostages. Note: This skill does not stack with other players Forced Friendship skills.
- T2 **Confident** — B: The power and range of your intimidation is increased by 50%. | A: You can now have 2 converted enemies at the same time.
- T2 **Joker** — B: You can convert a non-special enemy to fight on your side. This cannot be done during stealth and the enemy must have surrendered in order for you to convert them. You can only convert one non-special enemy at a time. | A: Your converted enemy deal 35% more damage. The time taken to convert an enemy is reduced by 65%.
- T3 **Stockholm Syndrome** — B: Civilians are intimidated by the noise you make and remain intimidated 50% longer. | A: Your hostages will not flee when they have been rescued by law enforcers. Whenever you get into custody, your hostages will trade themselves for your safe return. This effect can occur during assaults, but only 1 time during a heist.
- T3 **Partners In Crime** — B: Having a converted enemy increases your movement speed by 10%. Your converted enemy takes 45% less damage. | A: Having a converted enemy increases your health by 30%. Your converted enemy takes an additional 54% less damage.
- T4 **Hostage Taker** — B: Having at least one of your own hostage or converted law enforcer makes you regenerate 1.5% health every 5 seconds. | A: Having at least one of your own hostage or converted law enforcer makes you regenerate 4.5% health every 5 seconds.

### Mastermind / Sharpshooter
- T1 **Stable Shot** — B: You gain 8 weapon stability. | A: You gain 16 weapon accuracy while standing still.
- T2 **Rifleman** — B: Your snap to zoom is 100% faster with all weapons. Your movement speed is unhindered while using steel sight. | A: Your weapon zoom level is increased by 25% with all weapons. Your weapon accuracy while moving with SMGs, Assault Rifles and Sniper Rifles is increased by 16.
- T2 **Marksman** — B: You gain 8 weapon accuracy with all SMGs, Assault Rifles and Sniper Rifles fired in single shot fire mode. | A: You gain a 20% accuracy bonus while aiming down sights with all SMGs, Assault Rifles and Sniper Rifles fired in single shot fire mode.
- T3 **Ammo Efficiency** — B: Getting 3 headshots in less than 6 seconds will refund 1 bullet to your used weapon. Can only be triggered by SMGs, Assault Rifles and Sniper Rifles fired in single shot mode. | A: The amount of headshots required is reduced to 2.
- T3 **Aggressive Reload** — B: Increases your reload speed with SMGs, Assault Rifles and Sniper Rifles by 15%. | A: Any killing headshot will increase your reload speed by 100% for 4 seconds. Can only be triggered by SMGs, Assault Rifles and Sniper Rifles fired in single shot fire mode.
- T4 **Graze** — B: Snipers that hit their target deal 20% of the damage dealt in a 100cm radius around the bullet trajectory. | A: If a bullet would headshot-kill someone, the graze skill will deal 100% of the weapon's damage instead of 20%.

### Enforcer / Shotgunner
- T1 **Underdog** — B: When three or more enemies are within 18 meters of you, you receive a 15% damage bonus that lasts for 7 seconds. | A: When three or more enemies are within 18 meters of you, you also receive a 10% damage reduction that lasts for 7 seconds.
- T2 **Shotgun CQB** — B: You reload shotguns 15% faster. | A: You reload shotguns 35% faster. You gain a 125% increase steel sight speed when using Shotguns.
- T2 **Shotgun Impact** — B: Your weapon stability with all shotguns is increased by 8. You deal 5% more damage with shotguns. | A: You deal an additional 10% more damage with shotguns.
- T3 **Far Away** — B: Your accuracy bonus while aiming down sights with Shotguns is increased by 40%. | A: You gain a 50% increased effective range with Shotguns when aiming down sights.
- T3 **Close By** — B: You can now hip-fire with your Shotguns while sprinting. | A: Your rate of fire is increased by 35% while firing from the hip with single shot Shotguns. Shotguns with magazines have their magazine sizes increased by 15 shells.
- T4 **Overkill** — B: When you kill an enemy with a shotgun or the OVE9000 portable saw, you receive a 75% damage increase for 20 seconds. | A: The damage bonus now applies to all weapons. Skill must still be activated using a Shotgun or the OVE9000 portable saw. Your weapon swap speed is increased by 80%.

### Enforcer / Tank
- T1 **Resilience** — B: Increase your armor recovery rate by 15%. | A: Reduce the visual effect duration of Flashbangs by 75%.
- T2 **Die Hard** — B: You take 50% less damage while interacting with objects. | A: Increases the armor of all Ballistic vests by 20.
- T2 **Transporter** — B: You can throw bags 50% further. | A: For each 10 armor points the bag movement penalty is reduced by 1%.
- T3 **Shock And Awe** — B: Increases the armor recovery rate for you and your crew by 25%. | A: Enables your weapons to have a chance to knock back Shield enemies when attacking them. Ranged weapons' knock back chance is increased the higher the total damage of the weapon is. Melee weapons' knock back chance is 100%.
- T3 **Bullseye** — B: You regenerate 5 armor for each successful headshot. This effect cannot occur more than once every 2 seconds. | A: You regenerate an additional 20 armor for each successful headshot.
- T4 **Iron Man** — B: Your total armor values is increased by 30%. | A: Unlocks the ability to wear the Improved Combined Tactical Vest.

### Enforcer / Ammo Specialist
- T1 **Scavenger** — B: Your ammo box pick up range is increased by 50%. | A: Every 6th enemy you kill will drop an extra ammo box.
- T2 **Bulletstorm** — B: Ammo bags placed by you grant players the ability to shoot without depleting their ammunition for up to 5 seconds after interacting with it. The more ammo players replenish, the longer the duration of the effect. | A: Increases the base duration of the effect by up to 15 seconds.
- T2 **Portable Saw** — B: Unlocks the OVE9000 portable saw for you to use as a secondary weapon. | A: You gain 1 extra saw blade for the OVE9000 portable saw. You replace your saw blades with carbon blades, increasing your saw efficiency by 40%.
- T3 **Extra Lead** — B: You can now place 2 ammo bags instead of just one. | A: Each ammo bag contains 50% more ammunition.
- T3 **Saw Massacre** — B: Reducing the wear down of the blades on enemies by 80%. | A: You can now saw through shield enemies with your OVE9000 portable saw. When killing an enemy with the saw, you have a 50% chance to cause nearby enemies in a 10m radius to panic. Panic will make enemies go into short bursts of uncontrollable fear.
- T4 **Fully Loaded** — B: Your total ammo capacity is increased by 25%. | A: Increases the amount of ammo you gain from ammo boxes by 75%. You also gain a 5% base chance to get a throwable from an ammo box. The base chance is increased by 1% for each ammo box you pick up that does not contain a throwable. When a throwable has been found, the chance is reset to its base value.

### Technician / Engineer
- T1 **Third Law** — B: The cost of deploying a sentry gun is reduced by 5%. | A: Your sentry guns gain a protective shield.
- T2 **Sentry Targeting Package** — B: Your sentry guns gain a 100% increase in accuracy. | A: Your sentry guns rotation speed is increased by 150%. Your sentry guns also have 50% more ammunition.
- T2 **Eco Sentry** — B: The cost of deploying a sentry gun is reduced by 5%. | A: Your sentry guns gain 150% increased health.
- T3 **Engineering** — B: You can now select a less noisy version of the sentry guns, making them much less likely to be targeted by enemies. | A: You can now toggle AP rounds on your sentry guns, lowering the rate of fire by 75%, but increasing the damage by 250% and allowing it to pierce through enemies and shields.
- T3 **Jack Of All Trades** — B: You deploy and interact with all deployables 100% faster. | A: You can now equip a second deployable to bring with you. If your deployable is equipped as a secondary deployable, you can only bring half of what you would bring if it was equipped as a primary deployable.
- T4 **Tower Defense** — B: You can now carry 1 extra sentry gun. | A: You can now carry an additional 2 extra sentry guns.

### Technician / Breacher
- T1 **Hardware Expert** — B: You fix drills and saws 25% faster. Decrease trip mine deploy time by 20%. Drills and saws are also silent. Civilians and guards must see the drill or saw in order to become alerted. | A: Gives your drills and saws a 10% chance to automatically restart after breaking.
- T2 **Combat Engineering** — B: The radius of your trip mine explosion is increase by 30%. | A: Your trip mine damage is increase by 50%.
- T2 **Drill Sawgeant** — B: Your drill and saw timer is decreased by 15%. | A: Your drill and saw timer is decreased by an additional 15%.
- T3 **More Firepower** — B: You gain 1 more shaped charge and 4 more trip mines. | A: You gain 2 more shaped charges and 7 more trip mines.
- T3 **Kickstarter** — B: Your drills and saws gain an additional 20% chance to automatically restart after breaking. | A: Enables the ability to reset a broken drill or saw with a melee attack. The ability has a 50% chance to fix the drill or saw. The ability can only be used once per time the drill or saw is broken.
- T4 **Fire Trap** — B: Your trip mines now spread fire around the area of detonation for 10 seconds in a 4 meter diameter. | A: Increases the fire effect duration by 10 seconds and increases the fire effect radius by 50%.

### Technician / Oppressor
- T1 **Steady Grip** — B: You gain 8 weapon accuracy. | A: You gain 16 weapon stability.
- T2 **Heavy Impact** — B: Your shots have a 5% chance to stagger all enemies except Bulldozers and Captain Winters. | A: Increase your stagger chance to 20%.
- T2 **Fire Control** — B: You gain 12 weapon accuracy while firing from the hip. | A: Your accuracy penalty is decreased by 20% when shooting while moving.
- T3 **Lock N' Load** — B: You can now hip-fire with your weapons while sprinting. | A: Killing 2 enemies with SMGs, LMGs, Assault Rifles or Special Weapons set on automatic fire mode will increase your next reload speed by up to 100%. This bonus is reduced by 1% for each bullet above 20 in the total magazine size, down to a minimum of 40% reload speed increase.
- T3 **Surefire** — B: Your SMGs, LMGs and Assault Rifles gain 15 more bullets in their magazine. This does not affect the "Lock n' Load" Ace skill. | A: Your ranged weapons can now pierce through enemy body armor.
- T4 **Body Expertise** — B: 30% from the bonus headshot damage is permanently applied to hitting enemies on the body. This skill is only activated by SMGs, LMGs, Assault Rifles or Special Weapons fired in automatic fire mode. | A: 90% from the bonus headshot damage is permanently applied to hitting enemies on the body. This skill is only activated by SMGs, LMGs, Assault Rifles or Special Weapons fired in automatic fire mode.

### Ghost / Shinobi
- T1 **Chameleon** — B: Increases the time before you start getting detected by 25% while in casing mode. You can also mark enemies while in casing mode. | A: You can pick up items while in casing mode. You also gain 30% more value to items and cash that you pick up.
- T2 **Cleaner** — B: You gain 1 additional body bag in your inventory. Also increases the body bag inventory space to 3 from 2. | A: You gain the ability to place 2 body bag cases.
- T2 **Sixth Sense** — B: You gain the ability to automatically mark enemies within a 10 meter radius around you after standing still for 3.5 seconds while in stealth. | A: You gain access to all insider assets. Cleaning costs after killing a civilian is reduced by 75%.
- T3 **Nimble** — B: You gain the ability to disable 1 camera from detecting you and your crew.<br>Effect lasts for 25 seconds. | A: You lockpick 100% faster. You also gain the ability to lockpick safes.
- T3 **ECM Overdrive** — B: Your ECM jammer and feedback duration is increased by 25%. | A: Your ECM jammer can now also be used to open certain electronic doors.
- T4 **ECM Specialist** — B: You can now place 2 ECM jammers instead of just one. | A: The ECM jammer duration is increased by an additional 25% and the ECM feedback duration lasts 25% longer. Pagers are delayed by the ECM jammer.

### Ghost / Artful Dodger
- T1 **Duck And Cover** — B: Your stamina starts regenerating 25% earlier and 25% faster. You also sprint 25% faster. | A: You have a 10% increased chance to dodge while sprinting. You gain 15% chance to dodge while ziplining.
- T2 **Parkour** — B: You gain 10% additional movement speed and 20% increased speed while climbing ladders. | A: You gain the ability to sprint in any direction.<br>Run and reload - you can reload your weapons while sprinting.
- T2 **Inner Pockets** — B: Increases the concealment of melee weapons by 2. | A: Increases the concealment of all ballistic vests by 4.
- T3 **Dire Need** — B: When your armor breaks, the first shot on every enemy will cause that enemy to stagger. This effect ends when your armor recovers. | A: The effect persists for 6 seconds after your armor has recovered.
- T3 **Shockproof** — B: When tased, the shock effect has a 30% chance to backfire on the Taser, knocking them back. | A: When tased, you are able to free yourself from the taser interacting with it within 2 seconds of getting tased.
- T4 **Sneaky Bastard** — B: You gain a 1% dodge chance for every 3 points of concealment under 35 up to 10%. | A: You gain a 1% dodge chance for every 1 point of concealment under 35 up to 10%.

### Ghost / Silent Killer
- T1 **Second Wind** — B: When your armor breaks your movement speed is increase by 30% for 5 seconds. | A: This effect also applies to your crew when triggered.
- T2 **Optical Illusions** — B: You are 35% less likely to be targeted by enemies. | A: You gain 1 concealment for each silenced weapon you equip and reduces the concealment penalty of silencers by 2.
- T2 **The Professional** — B: You gain 8 weapon stability and 100% snap to zoom speed increase with silenced weapons. | A: You gain 12 weapon accuracy with silenced weapons.
- T3 **Low Blow** — B: You gain a 3% critical hit chance for every 3 points of concealment under 35 up to 30%. | A: You gain 3% critical hit chance for every 1 point of concealment under 35 up to 30%.
- T3 **High Value Target** — B: Enemies you mark take 15% more damage. | A: Enemies you mark take an additional 50% damage when further away than 10 meters. Increases the duration of marked enemies by 100% and you can now mark specials by aiming at them with any weapon.
- T4 **Unseen Strike** — B: If you do not lose any armor or health for 4 seconds, you gain 35% critical hit chance for 6 seconds. | A: The critical hit chance duration is increased to 18 seconds.

### Fugitive / Gunslinger
- T1 **Equilibrium** — B: Decreases the time it takes to draw and holster pistols by 33%. | A: You gain a 8 weapon accuracy with pistols.
- T2 **Gun Nut** — B: Your pistol magazine sizes are increased by 5 bullets. | A: You gain a 50% increased rate of fire with pistols.
- T2 **Akimbo** — B: Your Akimbo weapons' stability penalty is reduced by 8. | A: Your Akimbo weapons' stability penalty is reduced by an additional 8 and they also have a 50% increased ammo capacity.
- T3 **One Handed Talent** — B: The base damage of all pistols is increased by 5. | A: The base damage of all pistols is increased by an additional 10 damage.
- T3 **Desperado** — B: Each successful pistol hit gives you a 10% increased accuracy bonus for 10 seconds and can stack 4 times. | A: You reload all pistols 50% faster.
- T4 **Trigger Happy** — B: For every hit with a pistol you gain 120% damage boost that lasts for 2 seconds. Stacks up to 1 times. | A: Increases the damage boost duration to 4 seconds.

### Fugitive / Revenant
- T1 **Nine Lives** — B: You gain a 50% increase to bleedout health. | A: You gain the ability to get downed 1 more time before going into custody.
- T2 **Running From Death** — B: You reload and swap weapons 100% faster for 10 seconds after being revived. | A: You move 30% faster for 10 seconds after being revived.
- T2 **Up You Go** — B: You take 30% less damage for 10 seconds after being revived. | A: You receive 40% more health when revived.
- T3 **Swan Song** — B: Instead of getting downed instantly, you gain the ability to keep on fighting for 3 seconds with a 60% movement penalty before going down. | A: Increases the duration of Swan Song by 3 seconds. Ammunition won't be depleted while the effect is active.
- T3 **Feign Death** — B: When you get downed, you have a 15% chance to instantly get revived. | A: The chance to get instantly revived is increased by an additional 30%.
- T4 **Messiah** — B: While in bleedout, you can revive yourself if you kill an enemy. You only have 1 charge. | A: Your Messiah charge is replenished whenever you use a doctor bag.

### Fugitive / Brawler
- T1 **Martial Arts** — B: You take 50% less damage from all melee attacks. Because of training. | A: You are 50% more likely to knock down enemies with a melee strike.
- T2 **Bloodthirst** — B: Every kill you get will increase your next melee attack damage by 100%, up to a maximum of 1600%. This effect gets reset when you kill an enemy with a melee attack. | A: Whenever you kill an enemy with a melee attack, you will gain a 50% increase in reload speed for 10 seconds.
- T2 **Pumping Iron** — B: Your melee attacks against non-special enemies do 100% more damage. | A: Your melee attacks against special enemies do 100% more damage.
- T3 **Counterstrike** — B: When charging your melee weapon you will counterattack enemies that try to strike you, knocking them down. The knockdown does not deal any damage. | A: You gain the ability to counter attack cloakers and their kicks.
- T3 **Berserker** — B: The lower your health, the more damage you do. When your health is below 50%, you will do up to 250% more melee and saw damage. | A: The lower your health, the more damage you do. When your health is below 50%, you will do up to 100% more damage with ranged weapons as well.
- T4 **Frenzy** — B: You only get 30% of your maximum health and cannot heal above it but you take 10% less damage and healing received is reduced by 75%. | A: Damage taken is now reduced by 25% and healing received is reduced by 0%.

## Appendix B. Perk deck unique cards (VERIFIED (wiki), https://payday.fandom.com/wiki/Perk_Decks)

Unique cards 1, 3, 5, 7 and 9 for each deck. Text is truncated at about 330 characters. Shared cards 2, 4, 6 and 8 are in section 3.2.

### Crew Chief
- Brute Strength: You grant 8% damage reduction for players in your group. This bonus is doubled for you when you are under 50% health.
- Marathon Man: You and your crew's stamina is increased by 50%. Increases your shout distance by 25%. When you are within medium range of an enemy, you receive 6% less damage from enemies. Note: In-game description is wrong. The actual damage resistance is 8%, not 6%.
- Wolf Pack: Your crew will gain 10% more health. You will gain 20% more health.
- Testudo: You gain 10% more armor and your crew gains an additional 5% more armor.
- Hostage Situation: You and your crew will gain 6% max health and 12% stamina for every hostage up to 4 times. You and your crew will gain 8% damage reduction for having one or more hostages.
### Muscle
- Brute Strength: You gain 10% more health.
- Meat Shield: You are 15% more likely to be targeted when you are close to your crew members. You gain an additional 10% more health.
- Giant Strength: You gain an additional 20% more health.
- Disturbing the Peace: All firearms have a chance to spread panic among your enemies. Panic will make enemies go into short bursts of uncontrollable fear.
- 800-pound Gorilla: You gain an additional 60% more health. You regenerate 3% of your life every 5 seconds.
### Armorer
- Type I Armor: You gain 10% more armor.
- Type II Armor: You gain an additional 10% more armor.
- Type III Armor: You gain an additional 10% more armor.
- Reinforced Armor: Your armor recovery rate is increased by 10%. When your armor gets depleted, you will be immune to health damage for 2 seconds. This effect cannot occur more often than once every 15 seconds.
- Liquid Armor: You gain an additional 5% more armor. Reduces the armor recovery time for you and your crew by 10%.
### Rogue
- Subtle: Your chance to dodge is increased by 15%.
- Elusive: You are 15% less likely to be targeted when you are close to your crew members.
- Evasive: Your chance to dodge is increased by an additional 15%.
- Shadow Warrior: Your chance to dodge is increased by an additional 15%.
- Killer Instinct: All your weapons have a 25% chance to pierce enemy armor. The time between swapping weapons is reduced for you by 80%.
### Crook
- Subtle: Your chance to dodge is increased by 15%.
- Basic Composure: Your chance to dodge is increased by 5% for ballistic vests. Your armor is increased by 20% for ballistic vests.
- Advanced Composure: Your chance to dodge is increased by 10% for ballistic vests. Your armor is increased by 20% for ballistic vests.
- Expert Composure: Your chance to dodge is increased by 10% for ballistic vests. Your armor is increased by 25% for ballistic vests.
- Master Recovery: Your armor recovery rate is increased by 10%.
### Hitman
- Basic Recovery: Your armor recovery rate is increased by 5%.
- Ambidexterity: Dual wielded weapons have a -16 stability penalty. Your armor recovery rate is increased by an additional 10%. Ammo capacity for your akimbo weapons are increased by 50%
- Advanced Recovery: Your armor recovery rate is increased by an additional 10%.
- Expert Recovery: Your armor recovery rate is increased by an additional 10%.
- Tooth and Claw: Your armor recovery rate is increased by an additional 10%. Your armor will recover 1.5 seconds after being broken no matter what the situation.
### Burglar
- Sneaky: Your chance to dodge is increased by 20%.
- Bag of Tricks: Standing still and crouching decreases your chances to be targeted by 10%. You bag corpses 20% faster.
- Luck of the Irish: Your chance to dodge is increased by an additional 5%. Your chance to be targeted while standing still and crouching is decreased by an additional 5%. You pick locks 20% faster.
- Dutch Courage: Your chance to dodge is increased by an additional 5%. Your chance to be targeted while standing still and crouching is decreased by an additional 5%. You answer pagers 10% faster.
- Breath of Fresh Air: Standing still and crouching increases your armor recovery rate by 20%. You gain 10% crouching movement speed.
### Infiltrator
- OVERDOG: When you are surrounded by three enemies or more, you receive 12% less damage from enemies. Your second and each consecutive melee hit within 1 second of the last one will deal 10 times its normal damage. Note: Missing a melee strike resets the buff. The buff can be activated by hitting team AI and civilians as well. Effect does
- Basic Close Combat: When you are within medium range of an enemy, you receive 8% less damage from enemies.
- Advanced Close Combat: When you are within medium range of an enemy, you receive an additional 8% less damage from enemies. Unlisted effect: An additional 6 seconds are added to OVERDOGs duration of the extra damage on melee strike, for a total of 7 seconds before expiring.
- Expert Close Combat: When you are within medium range of an enemy, you receive an additional 8% less damage from enemies.
- Life Drain: Striking an enemy with your melee weapon regenerates 20% of your health. This cannot occur more than once every 10 seconds.
### Sociopath
- OVERDOG: When you are surrounded by three enemies or more, you receive 12% less damage from enemies. Your second and each consecutive melee hit within 1 second of the last one will deal 10 times its normal damage. Note: Missing a melee strike resets the buff. The buff can be activated by hitting team AI and civilians as well. Effect does
- Tension: Killing an enemy regenerates 30 armor. This cannot occur more than once every 1 second. You gain an additional 10% armor.
- Clean Hit: Killing an enemy with a melee weapon regenerates 10% health. This cannot occur more than once every 1 second. When you are within medium range of an enemy you receive 8% less damage.
- Overdose: Killing an enemy at medium range recovers 30 armor. This cannot occur more than once every 1 seconds. You gain an additional 10% armor.
- Showdown: Killing an enemy at medium range has a 75% chance to spread panic among your enemies. Panic will make enemies go into short bursts of uncontrollable fear. This cannot occur more than once every 1 second.
### Gambler
- Medical Supplies: Ammo packs you pick up also yield medical supplies and heals you for 16 to 24 health. Cannot occur more than once every 3 seconds. If the Gambler's current health is lower than another player's, the heal effect on the Gambler is increased by 20%. Stacks up to three times.
- Ammo Give Out: When you pick up ammo, you trigger an ammo pickup for 50% of normal pickup to other players in your team. Cannot occur more than once every 5 seconds. You gain 20% more health.
- Sharing Is Caring: When you get healed from picking up ammo packs, your teammates also get healed for 50% of the amount. You gain 20% more health.
- More Healing 1: Increase health gained from ammo packs by additional 8.
- More Healing 2: Increase health gained from ammo packs by additional 8.
### Grinder
- Histamine: Damaging an enemy heals 1 life points every 0.3 seconds for 3 seconds. This effect stacks but cannot occur more than once every 1.5 seconds, and only while wearing the Two-piece Suit or Lightweight Ballistic Vest.
- Adrenaline: Damaging an enemy now heals 2 life points every 0.3 seconds for 3 seconds. You gain 20% more health.
- Endorphins: Damaging an enemy now heals 3 life points every 0.3 seconds for 3 seconds. Increase your chance to pierce enemy armor by 10%.
- Dopamine: Damaging an enemy now heals 4 life points every 0.3 seconds for 3 seconds. You gain 20% more health.
- Euphoria: Damaging an enemy now heals 4 life points every 0.3 seconds for 4.2 seconds. Increase your chance to pierce enemy armor by 20%.
### Yakuza
- Koi Irezumi: The lower your health, the more armor recovery rate you have. When your health is below 25%, you will gain up to 20% armor recovery rate. Entering this state negates third party regeneration effects. Bonuses scale linearly with health.
- Hebi Irezumi: The lower your health, the more movement speed you gain. When your health is below 25%, you will gain up to 20% movement speed.
- Tora Irezumi: The lower your health, the more armor recovery rate you have. When your health is below 25%, you will gain up to an additional 20% armor recovery rate.
- Ryu Irezumi: The lower your health, the more armor recovery rate you have. When your health is below 25%, you will gain up to an additional 20% armor recovery rate.
- Oni Irezumi: All berserker effects in this perk deck will start at 50% health instead of 25%. Contrary to the description, all effects begin at 99% health.
### Ex-President
- Point Break: While your armor is up, you will store 4 health for every 1 enemy you or your crew kills. When your armor has been completely depleted and then starts to regenerate, you will gain health equal to the stored health amount. Maximum amount of stored health depends on your equipped armor.
- The Emerging Force: Increases the amount of health stored from kills by 4. You gain 10% more health.
- Life of Ice: Increases the maximum health that can be stored by 50%. You gain 10% more health. Your chance to dodge is increased by 10%. Note: It will actually increase dodge by 15%.
- Awakening Earth: Increases the amount of health stored from kills by 4. You gain 20% more health.
- The Perfect Line: Killing an enemy speeds up your armor recovery time depending on how much armor you have. The more armor the less recovery speed gained per kill. Armor recovery speed is reset whenever your armor recovers.
### Maniac
- Excitement: 100% of damage you deal is converted into Hysteria Stacks, up to 240 every 4 seconds. Max amount of stacks is 600. Hysteria Stacks  You gain 1 damage absorption for every 30 stacks of Hysteria. Hysteria Stacks decays 
- Outburst: Members of your crew also gains the effect of your Hysteria Stacks.  Hysteria Stacks from multiple crew members do not stack and only the stacks that give the highest damage absorption will have an effect.
- Fervor: Change the decay of your Hysteria Stacks to 60% + 40 every 8 seconds.
- Recklessness: Change the damage adsorption of your Hysteria Stacks on you and your crew to 1 damage absorption for every 25 stacks of Hysteria.
- Insanity: Damage absorption from Hysteria Stacks on you is increased by 100%.
### Anarchist
- Blitzkrieg Bop: Instead of fully regenerating armor when out of combat, The Anarchist will continuously regenerate armor throughout the entire combat. Heavier armor regenerates more armor, but during longer intervals. When your armor gets depleted, you will be immune to health damage for 2 seconds. This effect cannot occur more often than once 
- Straight Edge: 50% of your health is converted into 100% armor.
- Death or Glory: 50% of your health is converted into 110% armor.
- Rise Above: 50% of your health is converted into 120% armor.
- Lust for Life: Dealing damage will grant you 10 armor - this can only occur once every 1.5 seconds. Note: Despite saying 10, it has always granted 30 armor.
### Biker
- Prospect: Every time you and your crew performs a kill you will gain 5 health and 5 armor. This cannot occur more than 4 times every 4 seconds.
- Tail Gunner: Every 10% health missing will increase the amount of armor gained from kills by 1.
- Road Captain: Every 10% health missing will reduce the 4 second cooldown to kill regen by 0.1 second.
- Sgt-at-Arms: Every 10% armor missing will increase the amount of health gained from kills by 1.
- Prez: Every 10% armor missing will reduce the 4 second cooldown to kill regen by 0.1 second.
### Kingpin
- Bad Guy Coming Through: Unlocks and equips the Kingpin Injector. Changing to another perk deck will make the Injector unavailable again. The Injector replaces your current throwable, is equipped in your throwable slot and can be switched out if desired. While in game you can use the throwable key to activate the Injector. Activating the Injector will h
- Play Rough: You gain 10% more health.
- Public Enemy No.1: You gain 10% more health. Enemies nearby will prefer targeting you, whenever possible, while the Injector effect is active.
- Balls vs. Bullets: You gain 20% more health. The amount of health received during the Injector effect is increased by 25% while below 50% health.
- Right to the Top: You gain 40% more health. For every 5 points of health gained during the Injector effect while at maximum health, the recharge time of the injector is reduced by 1 second. Note: Actually activates every 50 points of health gained.
### Sicario
- Smoker: Unlocks and equips the throwable Smoke Bomb. When deployed, the smoke bomb creates a smoke screen that lasts for 10 seconds. While standing inside the smoke screen, you and any of your allies automatically avoid 50% of all bullets. Any enemies that stand in the smoke will see their accuracy reduced by 50%. After the smoke screen
- Twitch: Every time the player gets shot, 20% dodge chance is gained. This effect is reset once the player dodges and will not occur for the next 4 second.
- Subtle: Your chance to dodge is increased by 15%.
- Agility Shield: Dodging will replenish your armor.
- Unseen Shadow: All of your perk deck effects are increased by 100% while you are standing in the smoke screen. While any of your allies are standing in the smoke screen, they gain 10% dodge chance. Despite the wording, Unseen Shadow does not double the effects of Smoker, Helmet Popping, Blending In, Walk-in Closet, and Fast and Furious.
### Stoic
- Virtue: Unlocks and equips the Stoic's Hip Flask Damage is now reduced by 75%.  The remaining damage will be applied directly. The 75% reduced damage will be applied over-time (12 seconds) instead. You can use the throwable key to activate the Stoic Hip Flask and immediately negate any pending damage. The flask has a 10 second cooldown 
- Un-moved: All of your armor is converted and applied to your health.
- Calm: After not taking damage for  4 seconds any damage-over-time you are still waiting to receive will be negated.
- Imperturbable: When your health is below 35%, the cooldown of your flask will be reduced by 2 seconds for each enemy you kill instead of 1 second.
- Enduring: When damage-over-time is removed you will be healed for an additional 50% of the damage-over-time remaining at that point.
### Tag Team
- Soul Mates: Unlocks and equips the Gas Dispenser. To activate the Gas Dispenser you need to look at another allied unit within a 18 meter radius with clear line of sight and press the throwable key to tag them. Each enemy you or the tagged unit kills will now heal you for 15 health and the tagged unit for 7.5 health. Each enemy you kill wil
- Scent: Your maximum health is increased by 20%.
- Synergy: Each enemy you or the tagged unit kills will now grant you 2 absorption up to a maximum of 20. This effect will last until the perk deck item goes out of cooldown.
- Inhale: Your maximum health is increased by 20%.
- Harmony: Each enemy the tagged unit kills will now reduce your perk deck item cooldown timer by 2 seconds until you are no longer paired.
### Hacker
- Code Glitch: Unlocks and equips the Pocket ECM. Changing to another perk deck will make the Pocket ECM Device unavailable again. The Pocket ECM Device replaces your current throwable, it can be switched out if desired. While in game you can use the throwable key to activate the Pocket ECM Device. Activating the Pocket ECM Device before the a
- OpSec: Your maximum health is increased by 20%.
- Bit Decay: Killing an enemy while the feedback effect is active will regenerate 20 health. Unlisted effect: Increases dodge by 15%.
- Kluge: Killing at least 1 enemy while the feedback or jamming effect is active will grant 20 dodge of 30 seconds.
- Botnet: Crew members killing enemies while the feedback effect is active will regenerate 10 health. Unlisted effect: Further increases dodge by another 15%.
### Leech
- Momentum: Unlocks and equips the Leech Ampule. Changing to another perk deck will make the Leech Ampule unavailable again. The Leech Ampule replaces your current throwable, is equipped in your throwable slot and can be switched out if desired. While in game you can use the throwable key to activate the Leech Ampule. Activating the Leech A
- Indomitable: Your maximum health is increased by 20%. While the Leech Ampule is active you cannot go into bleedout, but being out of health will slow you down by 80%.
- Stalwart: The Leech Ampule duration is increased to 10 seconds. Killing an enemy reduces the cooldown of the Leech Ampule by 1 second(s). Taking damage now heals teammates by 10% of their health.
- Built Different: Your maximum health is increased by 20%.
- Symbiosis: You can now activate Leech Ampule while downed. temporarily reviving you until the end of the Leech Ampule. If you successfully revive a teammates or use a doctor bag before the Leech Ampule ends, you may stay alive if you are above 0 health. While the Leech Ampule is active your health is now divided into segments (truncated)
### Copycat
- Tactical Reload: Auto-reload your secondary weapon after preforming 10 kills with your primary, and vice versa. Swapping weapon within 3 seconds of auto-reload is nearly instant. Note: Auto-reload counter has no duration, and will last until activated, after which a new counter will immediately begin. Each weapon has a se
- Head Games: Each headshot you land heals 10 health points. This cannot occur more than once every 2 seconds.  Choose 1 of the following perks: •Your maximum health is increased by 20%. •You gain 5% more armor. •Your chance to dodge is increased by 5
- Is This Your Bullet?: Dodged bullets will ricochet back on the enemy that fired them. Due to how damage cooldown works, this cannot occur more than once every 0.45 seconds on Overkill and below, and 0.35 seconds on and above Mayhem.}}  Choose 1 of the following perks: •Your maximum health is inc
- Grace Period: When your health gets below 50% you will be immune to health damage for 2 seconds. This cannot occur more than once every 15 seconds.  Choose 1 of the following perks: •Your maximum health is increased by 20%. •You gain 5% more armor. 
- Mimicry: Choose 1 of the following perks: •See the table "Mimicry Perks" below for a full list of perks.
- Hysteria Stacks: You gain 1 damage absorption for every 30 stacks of Hysteria. Hysteria Stacks decays 60% + 80 every 8 seconds. Members of your crew also gains the effect of your Hysteria Stacks. Hysteria Stacks from multiple crew members do not stack and only the st
