# CAPERWORKS UI style: "Case File"

Owner: ENV B (D-086, PO-4). Status: **DRAFT for lead / product-owner sign-off.**
Code: `game/content/ui/theme/ui_tokens.gd` (tokens), `ui_theme_factory.gd` (builds
`caper_theme.tres`), `game/content/ui/common/ui_build.gd` (widget factories). No screen styles itself:
a screen picks a theme variation or a token, never a literal colour, size or StyleBox.

## 1. Identity

Every screen is a page from the crew's **case file**: ink-dark paper, off-white type, tracked
capitals for labels, hairline rules, and one cut corner on every box. Two accent colours carry all
the meaning:

* **Brass** (`#C9A227`) is the house colour: the wordmark, money, and the one *commit* action of a
  screen (Start Heist, Continue, Take Contract). If it is brass, it costs or pays or moves you on.
* **Cyan** (`#4FD1E8`, style_guide.md §3, reserved) means *this is what you act on*: keyboard / pad
  focus, the selected tab or row, interaction prompts in the world. Nothing decorative is cyan.

Everything else is ink and paper. Red appears only when something is wrong or loud.

Reference feel: a modern heist thriller's title cards and evidence boards, not a sci-fi HUD. Calm,
confident and sparse. The 3D world and the art-directed heist lighting (GSR) carry the mood; the UI
frames it and stays out of the way.

Rules of thumb:
1. **One primary action per screen**, brass, bottom right. Back is bottom left, a panelled Button (`UiBuild.back`, LEAD r304: a ghost read faint over 3D / photo backdrops).
2. **Labels are captions, values are body.** "SECONDARY" (caption caps, dim) above "Kestrel P9"
   (body, paper). Never "Secondary: Kestrel P9" in one string when a layout can split it.
3. **Show less.** Default to what a player needs now; details on focus / hover or a second level.
4. **Every interactive thing names its input** with a key cap (`[F]`, `[A]`), following the last
   device used.

## 2. Layout grid

* Canvas: 1920×1080 units (`canvas_items` stretch), so everything scales to 720p..4K.
  1 unit = 0.667 px at 1280×720.
* Safe margin `MARGIN` 72 on every side. 12 columns, gutter `GUTTER` 24.
* Spacing steps: 4, 8, 16, 24, 32, 48, 64 (`S1`..`S7`). Nothing uses other gaps.
* Screen skeleton (menus):
  * **Header band** (top, 120): caption breadcrumb (`SAFEHOUSE / PLANNING`) over an H1 title; right
    side: the player's money / level as caption + value pairs.
  * **Body**: 8 columns of content + 4 columns of context (details of the focused item).
  * **Footer band** (bottom, 72): Back (panelled, `UiBuild.back`) left, a control-hint strip centre
    (`[Esc] Back  [Enter] Select`), primary action right.
* Minimum text size: 21 units (14 px at 720p), from PQ-B-14.

## 3. Colour tokens

| Token | Hex | Use |
|---|---|---|
| `INK_0` | `#0B0D10` | app background, HUD panel base (62% alpha) |
| `INK_1` | `#12161B` | panels |
| `INK_2` | `#1A2027` | buttons, cards, fields |
| `INK_3` | `#232B34` | hover, selected rows |
| `LINE` | `#2C3540` | hairlines, panel edges |
| `LINE_STRONG` | `#46525F` | field edges, idle button base edge |
| `PAPER` | `#ECE7DD` | primary text |
| `PAPER_DIM` | `#A8A296` | secondary text, captions (≥ 7:1 on INK_1) |
| `PAPER_MUTE` | `#6C6961` | disabled |
| `BRASS` / `BRASS_HI` | `#C9A227` / `#E6C65C` | brand, money, primary action |
| `CYAN` | `#4FD1E8` | focus, selection, interact prompts |
| `ALERT` | `#E5484D` | loud, assault, danger, failure |
| `WARN` | `#F0A13A` | warnings |
| `OK` | `#5BC08A` | done, secured, success |

Per-heist accents (UiAccent, style_guide §3) stay: a heist's colour edges its card, its briefing
header strip and the HUD objective tick, nothing more. HUD detection / health colours stay in
`HudTweak` and follow the colour-vision palettes (B5-01).

## 4. Type

Font: **the engine's built-in default font only** (no font files, third_party.md). Styles are
`FontVariation`s over it (`UiTokens.font_*`): embolden for weight, glyph spacing for tracking,
`Label.uppercase` for caps, tabular figures (`tnum`) so numbers line up.

| Style | Size | Font | Use |
|---|---|---|---|
| Display | 88 | display (heavy, +6 tracking, caps) | wordmark, payday total |
| H1 (`HeaderLabel`) | 48 | heading | screen title |
| H2 (`SubheaderLabel`) | 32 | heading | section title, item name |
| Lead | 28 | body | key value (weapon name, contract pay) |
| Body | 24 | body | everything else |
| Caption (`CaptionLabel`) | 21 | caps (+2 tracking, uppercase) | labels, breadcrumbs, column heads |
| HUD (`HudLabel`) | 24 | body + 6 outline | HUD text |
| HUD big (`HudBigLabel`) | 44 | heading + 8 outline | ammo count |

An open-licence or procedurally built font is a later option for the lead (QB question); the
spec works without one.

## 5. Components and states

All boxes are chamfered: top-left and bottom-right corners cut 10 (panels) or 6 (buttons, HUD).

| Component | Normal | Hover | Focus (pad / keys) | Pressed / selected | Disabled |
|---|---|---|---|---|---|
| Button | INK_2, 1 px LINE, 2 px LINE_STRONG base | INK_3, PAPER_DIM edge | + 2 px cyan ring outside (no layout shift) | INK_3 + 4 px cyan left edge | INK_1, PAPER_MUTE text |
| PrimaryButton | BRASS_INK fill, brass edge, 3 px base, caps label in BRASS_HI | brass flood, ink text | cyan ring | brass flood | as Button |
| GhostButton | no fill, LINE edge, dim text | as Button | cyan ring | as Button | as Button |
| TabButton | caps, dim, 2 px LINE underline | PAPER_DIM underline | cyan ring | 3 px cyan underline, paper text | |
| StationButton (hub card) | INK_1, 3 px LINE left edge | INK_2, brass edges | cyan ring | | |
| Field / OptionButton list | INK_0, LINE_STRONG | | cyan edge | cyan row bar | |
| Panel | INK_1 97%, LINE edge | | | | |
| CardPanel | INK_2, LINE edge | | | | |
| KeyCap | INK_0 85%, 2 px PAPER edge, 3 px base | | | | |

Focus is always visible when the last input was keys or pad; mouse hover never moves focus away.

## 6. Motion

Short and eased; nothing loops except the detection meter and the assault banner.

* `T_FAST` 0.12 s: hover / focus colour, key-cap press.
* `T_BASE` 0.2 s: panel in / out (fade + 24-unit slide up), toasts, prompt appear.
* `T_SLOW` 0.35 s: screen change (outgoing fades 0.12 s, incoming slides from 24 units).
* Ease: cubic out for entering, quad in for leaving. Payday counters tick up over ≤ 1.2 s and can be
  skipped with the primary input.
* Respect `accessibility/reduce_motion` (new option, proposed): all slides become fades.

## 7. Iconography

Line icons we draw in code (`draw_*` / SVG we author, like `hub_station_icon.gd`): 2-unit stroke at
48 units, square caps, no fills except small solid dots, PAPER or BRASS, cyan only when focused.
Set: board, planning, armory, mask, range, crew, jukebox, notoriety, record, money, bag, hostage,
cable tie, body bag, camera, pager, keycard, drill, warning. Key caps are drawn as KeyCap panels,
not icons.

## 8. HUD composition (PD2-like)

Minimal, in the corners; the centre is reserved for aim, the prompt and detection.

```
┌──────────────────────────────────────────────────────────────────────┐
│ OBJECTIVE                                     [ASSAULT banner]  MODE │
│ Get into the workshop                                    CASING / ⓜ  │
│ ▸ 1/2 bags                                               bag, hostages│
│                                                                      │
│                         ◂ detection arcs (D-128)▸                    │
│                                 +                                    │
│                         [F] Pick the lock                            │
│                         ▬▬▬▬▬▬▬▬▬▬ hold bar                          │
│ crew (compact rows)                                                  │
│                                                                      │
│ ▮▮▮▮▮▮▮▮ armor 20         hint strip:              17 │ 136          │
│ ▮▮▮▮▮▮▮▮ health 230      [G] Hold to mask up      ▪ Doctor Bag 1     │
└──────────────────────────────────────────────────────────────────────┘
```

* **Top left: one objective line** (the current ACTIVE objective, H2-ish), a caption "OBJECTIVE"
  above it and at most one sub-line (bag count). Completed objectives flash OK green for 2 s, then
  the next one slides in. The full list is on the scoreboard (Tab).
* **Top right: mode** as a caption chip (`CASING`, `CIVILIAN`, `MASKED` is not shown once loud),
  then carried bag and hostages as icon + value.
* **Bottom left: vitals**: armor over health as two thin bars with values; downs as pips, not text.
  Teammates above it as compact rows (name + two 4-unit bars + state icon), no "Downs left: 3"
  repeated per row.
* **Bottom right: ammo** big (mag) / small (reserve), equipment as icon + count rows; hidden while
  casing/civilian (you carry no drawn weapon).
* **Below the prompt (centre, +190): the hint strip**: the one thing a new player should do next, from real state:
  `[G] Hold to mask up` while casing, `Click to resume` when the mouse is not captured,
  `[Space] Throw bag` while carrying. One line, KeyCap + caption, fades after the player does it.
* **Centre**: crosshair (masked only), prompt below it: KeyCap + verb + object, cyan progress bar.
  Blocked reason in ALERT under it.
* **Top centre**: assault banner (BannerPanel, red), pager prompt, captain panel. Toasts above the
  crosshair, max one at a time.
* Floating HUD text keeps the PQ-B-23 outline + shadow; panels are HudPanel (ink 62%).
* **Right of centre: first-time onboarding card** (lane 11), one per situation the first time it
  arises (casing, stealth, loud, escape), never a wall of text. The card is opaque (INK_1 95%) with
  a brass left edge, the caption "FIRST TIME", n/4, a title, 3-4 rows (brass dash or KeyCap +
  one short line), a draining brass hairline (14 s) and "Press [H] to close". Seen ids are stored
  in the profile (`settings.onboarding_seen`).

## 9. Sound hooks

UI cues (requested from ENV C via the lead, audio_cues.md): `ui_focus` (soft tick), `ui_confirm`
(brass "clack"), `ui_back` (lower tick), `ui_primary` (two-tone commit), `ui_error`, `ui_tab`
(paper slide), `hud_objective_done`, `hud_hint_appear`, `payday_tick` (counter), `payday_total`.
UiBuild wires focus / press on every Button it makes, so screens get them for free.

## 10. Checks

* Windowed screenshots at 1280×720 and 1920×1080 (`tests/b/render/ui_audit_capture.gd`) for every
  screen touched; review PNGs under `game/content/ui/_review/`.
* `test_ui_theme` keeps `caper_theme.tres` equal to `UiThemeFactory.build()`.
* Contrast (`hud_contrast_capture.gd`) ≥ 4.5:1 for all text; 720p size floor 14 px.
* r249 fill rule (LEAD ruling): text **fill vs its local background ≥ 3:1** (`contrast_worker.fill_ratio`: brightest 3%
  vs the median in the label rect), over the mid and bright backdrops. The 4.5:1 check above counts the dark outline,
  so frameless text always passes it; the fill rule is what fails on bright stone. Small HUD labels that fail it get
  the **label scrim** (`UiBuild.scrim_label` / `label_scrim()`: 45% black, radius 4, padding 6×2): world-marker
  labels (2.0:1 on the OF facade) and teammate names (2.6:1). It is a gate only for scrimmed labels: frameless text
  (objective block, vitals, prompts) cannot reach 3:1 on a flat bright backdrop by construction, and stays frameless
  (PO-4); the probe prints those as `CONTRAST FILL NOTE`.

## 11. Menu rules (D-111: "menus look bad and cluttered")

The one-page sheet for the menu declutter pass. §1–§5 still hold. These rules decide what each screen *removes*.

**Budget.** A menu screen shows at most **7 interactive things** in its body, plus Back and one primary action.
A uniform grid of like items (stations, armor, swatches) counts as one.
It shows at most **3 text sizes** (H1, one of Lead/H2, and Body/Caption) and **one accent**: brass for money and
the commit button, cyan only for focus. A per-heist accent is allowed only on that heist's strip.

**Spacing.** Gaps come only from S1–S7. Inside a card use S2 (8). Between cards use S4 (24). Between a section
and its head use S3 (16). Sections are separated by a 48 gap (S6), never by a rule *and* a gap.

**Text.** Every value is shown once per screen. A description sits **either** on the card **or** in the context
panel for the focused card, never both. A card is an icon, a title and at most one state word (`EQUIPPED`, `NEW`,
`LOCKED`). Longer copy appears on focus.

**Secondary info goes behind a tab, a hover, or a second level.** Examples: stat breakdowns, mod slots on the
loadout, skill/perk point counts, the contract broker, key-binding tables, payday line items beyond the totals.

**Footer.** `[Esc] Back` appears only where Back exists; the root main menu has none. Only the primary action is
brass.

### Per-screen layouts (PD2 reference in brackets)

| Screen | Body after the pass | Moves out of the body |
|---|---|---|
| Main menu [PD2 title] | Wordmark, tagline, 4 entries, mask render, one status line | Footer `Esc` hint |
| Hub [PD2 safehouse menu] | 3×3 station grid (icon and title); context panel: focused station's line, then level, XP bar, money | Two-line blurbs on every card; skill/perk point counts (they move to Armory) |
| Board [crime.net] | Map (60%); focused contract card; primary Take Contract | Broker form → a `Contract Broker` button that opens it in the context panel |
| Loadout / Armory [PD2 inventory] | Primary, Secondary, Melee, Throwable, Deployable, Armor, Mask, Heister tiles; stats: 6 key bars + detection | Mod row (Workshop owns mods), the `Masks` button (the mask tile opens the bench), Threat/Total ammo (on hover), the skill/perk lines |
| Workshop | 3D weapon, slot list, stat diff on focus | — |
| Mask bench | Mask render, 3 layer tabs, swatch grid | — |
| Options [PD2 options] | Tab bar, one column of rows, Apply/Back | Floating key-binding header (it belongs inside the Controls tab's scroll) |
| Briefing [PD2 briefing] | Job, short objectives (D-109), loot; header: approach and escape | — (D-109 pass done) |
| Payday [PD2 payday] | Total, the stash/spending split, Cash card (contract + loot + total), XP card with bar, crew table | Duplicate XP figure in the header, half-visible third panel |

### Process
For each screen: take a **before** capture (`ui_audit_capture.gd`, 1280×720 and 1920×1080), apply the table row,
take an **after** capture, and keep the 720p tests green. Push one screen (or a pair) per commit. P runs the
windowed feel pass on each.
