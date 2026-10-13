# UI audit, windowed (PO-4, D-086)

ENV B, 2026-10-13. Real flow rendered in a window (xvfb, Forward+ on llvmpipe, not headless) at
1280×720 and 1920×1080 with `game/tests/b/render/ui_audit_capture.gd`: main menu → hub → Board →
Planning (heist select) → briefing → pre-planning → loadout → armory → options → launch Glasshouse
→ HUD casing → masked → loud → in-heist pause → payday → hub. "Before" PNGs:
`game/content/ui/_review/before/`. The 2D hub was shown (the 3D safehouse scene is not on this branch).

Verdict: the screens work and are readable, but they look like a debug build. Every screen is a
grid of same-weight boxes in one brown, with no hierarchy, no identity and no help for a new player.

## Everywhere
* **No identity.** Warm brown panels, one sans at one weight, gold headings. Nothing says "heist".
* **No hierarchy.** Labels and values have the same size and weight ("Secondary" = "Kestrel P9").
  Primary actions look like every other button except a thin gold edge.
* **No input hints.** No screen shows which key / button does Back, Select, tab switch.
* **Empty space vs cramped lists.** Heist select uses 30% of the screen; loadout crams 10 drop-downs.
* **Tabs and toggled buttons** use a gold flood (looks like a primary action, not a selection).

## Per screen
| Screen | Cluttered / confusing | Missing |
|---|---|---|
| Main menu | Tiny title, small buttons in a column, 80% of the screen empty brown. | A title moment; what "Safehouse" means to a new player. |
| Hub (2D) | 9 station cards with truncated descriptions ("pro jobs …"); profile panel repeats money; the focused card's description is repeated under the panel. | Which station to start with (a new player should be pointed at Planning or the Board). |
| Board | Busy but the best screen; map pins are clear. Broker panel always visible even with $0. | Hint that A/Enter takes the selected contract. |
| Heist select | List of 4 names + a paragraph; 2/3 of the screen empty; locked difficulties shown as "(locked)" text buttons. | Heist art/blueprint, stealth/loud icon, pay per difficulty. |
| Briefing | Good content, but 3 columns of equal weight; "Play Briefing" + empty transcript box. | Which objective is first; how long the job is. |
| Pre-planning | **Bug-level:** point labels overlap on the blueprint ("Alley … Van: alley west", "Alley dum… Alley HVAC"). Red "PLACEHOLDER BLUEPRINT" banner. Asset list scrolls inside a short box. | What favors are, before you see "0 / 4". |
| Loadout | 10 rows of identical drop-downs; **the screen only has a Secondary weapon row** (loadout_screen.gd edits `secondary` only; primaries are not selectable here at all); stats panel is a plain column with no comparison; "Concealment 120" vs per-weapon "Concealment 30" is confusing. | Weapon picture, stat bars, what Detection Risk means. |
| Options | Dense, but fine for options. Tabs as gold flood. | Short description of the focused setting. |
| HUD casing | Objectives box lists 5 steps at once; 3 teammate boxes each say "Downs left: 3"; "Unmasked: casing" floats top-right; equipment as 4 text lines; the pistol is drawn while casing (ENV P). | **"Hold G to mask up"**; anything telling the player they are in casing mode and what that allows. |
| HUD masked | Same clutter; "Masked" text top-right says nothing useful. | Throw-bag key while carrying. |
| HUD loud | Assault banner fine; subtitles fine. | Reload indicator (needs an A field, PP-B-7). |
| Pause (in heist) | **Pause is the full Options screen**, opaque, the game hidden; "Leave Heist" is the 5th footer button. | A real pause: Resume / Options / Leave Heist over the dimmed game, cursor released, "Click to resume" after. |
| Payday | A wall of 15 equal rows, most of them 0 (pro bonus 0, custody 0, stealth bonus 0...); no hero number; the crew table has empty columns. Cards screen is fine. | One big "you made $44,000" moment, XP bar animating, zero rows hidden, details on demand. |
| Global input | When the mouse is not captured the HUD does not say so (looks frozen). | "Click to resume". |

## Plan (order)
1. Shared theme from tokens ("Case File", style.md). DONE in f9b52550: every screen re-skins at once.
2. HUD declutter: one objective line, compact teammates, key-cap prompts, hint strip (mask up /
   click to resume / throw bag), mode chip. DONE (first pass) in f9b52550.
3. Pause menu (Resume / Options / Leave Heist) over a scrim, MouseCapture keys.
4. Main menu + hub hierarchy (wordmark done; hub "start here" pointer, shorter cards).
5. Heist select / briefing / pre-planning (label overlap fix) / loadout (Primary row, stat bars).
6. Payday, then the rest (workshop, skills, perks, masks, lobby).
7. Footer control-hint strip on every UiScreen.
