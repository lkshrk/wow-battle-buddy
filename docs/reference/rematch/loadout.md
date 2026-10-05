# Loadout
Sources: `panels/loadedTeamPanel.xml`, `panels/loadedTeamPanel.lua`, `panels/loadedTargetPanel.xml`, `panels/loadedTargetPanel.lua`, `panels/loadoutPanel.xml`, `panels/loadoutPanel.lua`, `panels/loadoutPanelMixins.lua`, `panels/miniLoadoutPanel.xml`, `panels/miniLoadoutPanel.lua`, `process/loadouts.lua`, `menus/loadoutMenu.lua`, `templates/fillMixins.lua`, `main/constants.lua` · Fork changes: `panels/loadedTargetPanel.lua`, `panels/loadoutPanel.lua`, `panels/miniLoadoutPanel.lua` · Screenshots: `rematch-journal-teams.png`, `rematch-queue.png`

## Purpose

The loadout is the editable three-slot view of Blizzard’s currently loaded battle pets. In the three-panel Pet Journal layout it fills the central column below the loaded target and loaded team headers. It combines current live pet data, saved-team identity, optional target association, ability selection, special leveling/random/ignored slot modes, models, drag/drop, and pet-card/menu entry points.

The saved-team workflow belongs in [save team dialog](save-team-dialog.md); teams, targets, and queue semantics are detailed in [teams](teams.md), [targets](targets.md), and [queue](queue.md).

## Frame tree

- `LoadedTargetPanel`
  - inset background
  - target/team badge, title, underline, clear X
  - optional target `Portrait`
  - optional `EnemyPets[1..3]`
  - optional `AllyPets[1..3]` with previous/next team arrows
  - contextual Save / Load and small action buttons
- `LoadedTeamPanel`
  - optional `PreferencesButton`
  - `TeamNameButton` / favourite star / load bling
  - optional `NotesButton`
- `LoadoutPanel`
  - `Slot[1..3]`
    - `PetButton` — icon, rarity border, level bubble, status, favourite
    - type decal / notes badge / breed / other badges / names
    - health and XP bars
    - `AbilityBar > Ability[1..3]`
    - `ModelScene`
    - `SpecialButton`
    - conditional `LockOverlay`
  - `FlyoutArrow`
  - `AbilityFlyout > Alternative[1..2]`
- `MiniLoadoutPanel`
  - compact `MiniSlot[1..3]` and its compact ability bar/status bars
  - left-pointing flyout arrow and flyout

## Placement in the journal three-panel layout

The documented screenshots use a 3-panel canvas: left pet list, **middle 280 px loadout column**, right active Teams or Queue list. The vertical middle stack is:

1. **Loaded target panel**, 75 px high in the normal central column;
2. 2 px gap;
3. **Loaded team strip**, 26 px high;
4. 2 px gap;
5. **Loadout panel**, filling the remaining central column, containing three 280×137 cards at y=0, −139, and −278.

The normal full canvas is 280×520 per column. In 1/2-panel/minimized layouts a **MiniLoadoutPanel** is used instead: 92 px high directly beneath the LoadedTeamPanel (or target panel in target-focused layouts). Its three equal card widths are calculated from its current host width, leaving 2 px gaps around the centred middle card.

## Loaded team panel

The strip has no imposed size in XML; the 3-panel layout constrains it to the central 280 px column by **26 px** height.

| Element | Parent | Anchor | Size | Appearance / state |
|---|---|---|---:|---|
| Preferences inset | panel | top-left | 28×26 | Only if `Show Extra Preferences Button` is on and at least one loaded slot is leveling. |
| Preferences blue button | inset | left +2 | 24×24 | **own art (`textures/badges-borderless`) — redraw or substitute**. Blue gear normally; blue gear with red X when preferences paused. |
| Team name button | panel | left after pref inset +2; right before Notes inset −2 | variable×26 | Gold inset, faded ornamental corners, word-unwrapped name. Favourite star appears at its top-left. |
| Notes inset | panel | top-right | 28×26 | Visible for user team and `loadonly` only if it has notes. |
| Notes button | inset | left +2 | 24×24 | Existing note icon; green-plus note icon for a user team with no note. |
| Favourite | TeamNameButton | top-left `(0,0)` | 20×20 | `PetJournal-FavoritesIcon`; hidden for loadonly/counter/no team. |
| Bling | TeamNameButton | `(2,-2)` to `(-2,2)` | inset | Additive archaeology flare on team load. |

The name is a `GameFontNormal` text field padded 8 px each side. Its gold inset uses `Interface\PetBattles\_PetJournalHorizTile`; corner decorations are cropped `Interface\Collections\Collections` at 65% alpha and `#BFBFBF` tint. Existing standard toolbar/panel button art remains **own art** where it refers to `textures/badges-borderless`.

| Loaded condition | Name field | Notes button | Main click |
|---|---|---|---|
| User saved team | formatted team name | always; normal notes or add-note glyph | reloads that saved team; right-click opens loaded-team menu. |
| `loadonly` temporary team | stored loadonly name | only if it has notes | reloads temporary team. |
| `counter` temporary team | `Counter to <target>` if one target, otherwise random-team name | hidden | regenerates counter pets, then reloads. |
| no team | `Battle Pet Slots` | hidden | inert. |

Hover highlights the inset and, if text is truncated and truncation tooltips are enabled, shows its full name. The action area uses the regular `LoadedTeamMenu` rather than the standard Team list menu: see [menus](menus.md).

### Loaded team controls

| Element | Input | Effect |
|---|---|---|
| Team name | left click | Reload current team; for `counter`, make a fresh counter first. |
| Team name | right click | Opens loaded-team actions. |
| Team name | hover | Highlight and possible truncated-name tooltip. |
| Notes | hover/click | Opens shared notes card for loaded team. For a user team without notes, click opens and focuses a new editor. |
| Preferences | left click | Opens current effective leveling-preferences dialog scoped to current team/group. |
| Preferences | right click | Toggles global preferences pause. |

## Loaded target panel

The normal target panel is an inset card, **75 px high** in normal layout (`51 px` in its short/mini target configuration). It represents the current/recent target and optionally the known enemy team and preferred saved player team.

| Element | Parent | Anchor | Size | Appearance / state |
|---|---|---|---:|---|
| Badge | panel | top-left `(5,-4)` | 18×18 | Target/team badge from **own art (`textures/badges`) — redraw or substitute**. Hidden in mini target view. |
| Name | panel | top-left `(8,-8)` to dynamic right | 14-ish high | `GameFontHighlight`, word-wrap off; formatted target name. |
| Underline | panel | y=−22, x=8 to dynamic right | 182×3 nominal | Blizzard `_UI-Frame-InnerTopTile`. |
| Clear | panel | dynamic top-right, normally `(-4,-3)` | 18×18 | `Interface\FriendsFrame\ClearBroadcastIcon`; clears recent target. Hidden in mini view/no target. |
| Portrait | panel | bottom-left `(4,3)` | 44×44 | Creature portrait, thin gold `PetBattleHUD` frame. |
| Enemy team | right of portrait +4 | 1–3 × 28×40 cells | width changes 32 / 61 / 90 ×44 | Known target pets, not desaturated; `teamborders` crop. |
| Ally team | after enemy +20; or portrait +22 if no enemy | three 28×40 cells | 90×44 | Chosen saved team for target; grey if species-only; red X / haze by dead/injured status. |
| Team pager | around AllyTeam right | 24×24 each | compact arrows | visible only if multiple saved teams; ends disabled. |
| Big Load/Save | bottom-right `(-8,6)` | 68×34 | Grey panel button. |
| Medium Load | top-right `(-3,-3)` | 68×24 | Grey panel button when both enemy and saved player team are present. |
| Small random / edit-target / save | packed against right or Medium Load | 24×24 | dice / paw / save icons. |

`Enemy team` comes from the recognised target’s recorded opponent pets. `Ally team` is the saved target’s ordered team list; the first is the preferred entry, except the target-selection rule can choose a non-injured one. Target name’s right edge moves left to avoid visible action buttons.

### Target state matrix

| Target state | Team blocks | Primary button | Small buttons |
|---|---|---|---|
| No recent target | all hide | none | all hide; title becomes `No Target`. |
| Recent unknown/not notable, no saved team | portrait only | **Save** (68×34) | Random and Edit Target. |
| Notable target, no saved team | portrait + enemy pets | **Save** | Random and Edit Target. |
| Saved non-notable target | portrait + ally team | **Load** (68×34) | Random, Edit Target, Save. |
| Saved notable target | portrait + enemy and ally team | **Load** (68×24) | Random, Edit Target, Save beside it. |
| Mini target | portrait + ally only | **Load** 68×34 | no extra actions; only displays saved target. |

`Save` takes the currently slotted pets into a sideline team, gives it a unique target-derived name, assigns this target, then opens the save-team dialog. **Random** builds and loads a counter/random temporary team for the target. **Edit Target** opens assignment/order editing for the target’s teams. Small Save repeats Save; a large Load/medium Load loads the selected AllyTeam.

### Target interactions

| Element | Input | Effect |
|---|---|---|
| Clear X | click | Clears recent target and redraws. |
| Enemy pet texture | hover | Target pet interaction/tooltip surface; mousedown/up use normal visual pressed handling. |
| Ally pet texture | hover | Pet card path; uses its pet ID and the parent reference. |
| Pager | click | Moves selected ally team backward/forward; cannot move beyond list ends. |
| Load | click | Loads displayed target team. |
| Save | click | Starts target-associated new-team save. |
| Dice | click | Builds a target-aware counter/random team and loads it. |
| Paw / Edit Target | click | Opens Edit Target teams/order dialog. |

## Main loadout panel

Each normal slot is **280×137 px**, an inset panel. Slots 2 and 3 begin 139 and 278 px below Slot 1, leaving 2 px gaps. The screenshot shows the full regular format: name/level/breed at left, three ability buttons, heart health, 3D model, and XP line.

### Slot layout

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---:|---|
| Brown back / hover | slot | all points | 280×137 | Brown `PetJournal` crop; hover is additive `#A6A6A6` α .85. |
| PetButton | slot | top-left `(15,-18)` | 46×46 | icon inset 2 px, rarity border; level bubble at lower-right; favourite star top-left; dead X/injured haze. |
| SpecialButton | slot | near PetButton top-right `(-1,-1)` | 19×19 | appears only for leveling, random or ignored special slot. |
| Type decal | slot | top-right `(-4,-4)` | 77×77 | Cropped family icon; sits as large translucent type image behind right content. |
| Pet name | slot | `(70,-21)` to dynamic right | fluid | `GameFontNormal`, rarity-coloured if setting allows. Vertically nudges down if one short line. |
| Species name | below name `y=-2` | same horizontal bounds | fluid | `GameFontHighlightSmall`, `#E6E6E6`; only custom name. |
| Notes badge | slot | top-right `(-12,-21)` | 20×20 | only when notes badge option permits and pet has notes. |
| Breed | slot | top-right `(-14,-56)` | text | only breed-known and visible option; small or normal font option. |
| Other badges | left of notes/right edge | 14×14 chain, −1 gap | dynamic | pet status/category badges. |
| HP back/fill | slot | bottom-left `(14,26)` | 60×8 / 58×6 | dark back, green `#1AE61A`, 64×12 border. |
| Heart / health text | above HP border | 12×12 / text | dynamic | `PetBattle-StatIcons` heart; `Dead`, percent, or full health. |
| XP back/fill | slot | bottom centre `(0,7)` | 252×8 / 250×6 | blue `#2E8AE6`, 256×12 border; shown only below 25. |
| AbilityBar | slot | bottom centre `(0,24)` | 112×36 | three 32×32 buttons at left +2, centre, right −2. |
| ModelScene | slot | bottom-right `(-1,1)` | 88×100 | model + 69×42 `PetJournal-BattleSlot-Shadow` at `(4,8)`. |
| Cursor glow | centred PetButton | 56×56 | animation | checkbutton glow pulses `.25 → 1 → .25` every 1.8 s while a pet rides cursor. |
| Bling | slot | `(2,-2)` to `(-2,2)` | inset | team-load flare. |

The main slot pet border, ability-bar border, XP/HP border, status art, level-bubble, badge backgrounds and giant type decal are **own art (`textures/borders`, `petstatus`, `level-bubble`, `badges-*`) — redraw or substitute**. The base inset frame uses Blizzard `UI-Frame-Inner*` atlases. Pet-level icon cropping follows a 8×4 sheet; hide the bubble at level 25 when `Hide Level At Max Level` is on.

### Special and locked slots

| State | Back treatment | visible content |
|---|---|---|
| Normal | normal brown background | current pet data. |
| Leveling | desaturated light blue `#80BFFF` back | `SpecialButton` with leveling glyph; actual currently-queued pet may occupy it. |
| Random type | desaturated light green `#80FF80` back | random-type badge; loads a high-level random pet avoiding other loaded pets. |
| Ignored | desaturated salmon `#FF8080` back | ignored badge; does not load a pet. |
| Game slot locked / journal locked | all-points black α .5 overlay | 32×32 Blizzard `PetBattle-LockIcon`, requirement explanation, and a requirement spell/achievement link. Ability bar hides for a game-locked slot. |

A locked game slot can show its unlock requirement tooltip on the lock icon and its linked achievement/spell tooltip on the link. Pet swapping is refused if the journal is locked, player is in a pet battle/combat/not yet in world, or pet PvP matchmaking is queued.

### Ability bar and selector flyout

Each loaded ability button is 32×32, icon cropped 7.5–92.5%, with an optional tiny **1/2** at bottom-right when both ability-number options are enabled. An unavailable later-level ability is desaturated `#666666` and overlays its unlock level in red `#FF4040`. Empty is blank icon.

Hover draws icon highlight and opens [ability tooltip](pet-card.md#ability-tooltip). Left click on a usable button opens a vertical **44×81 px** flyout, with a 24×24 bottom arrow pointing at the source button. The two 32×32 candidates sit 6 px from flyout top/bottom; each corresponds to one of the species’ two alternatives for the clicked ability tier. The selected one gets CheckButton additive glow. Choose a usable alternative to call the Blizzard selection API and close; click original ability again toggles it closed. The flyout remains while pointer is over source/flyout, otherwise closes after **1.5 s**. Right click opens the ability menu; Shift-click produces a chat link.

## Drag and drop / click rules

| Element | Input | Conditions | Effect |
|---|---|---|---|
| Slot background | hover | any valid slot | shows slot highlight and starts pet-card hover path. |
| Slot / pet icon | left click | journal editable; pet cursor occupied | accepts cursor pet into this slot, clears cursor, hides pet card, returns hover state, plays drop sound. |
| Slot background | left click | no pet cursor | locks/unlocks pet card. |
| Slot background / pet icon | right click | owned actual pet and editable | opens LoadoutMenu at cursor. |
| Pet icon | left click | owned actual pet / editable / no special click | picks up pet on cursor. |
| Pet icon or slot | drag | owned actual pet and editable | picks up that pet on cursor. |
| Pet icon / slot | double click | summon option not disabled | summons or dismisses selected pet and hides pet card. |
| Slot / icon | any card-related click | journal locked | no slot edit; only lock/unlock pet card. |
| Ability | left click | journal editable, ability usable | open/change flyout selection. |
| Ability | right click | journal editable | AbilityMenu. |
| Ability | Shift-click | valid ability | paste ability hyperlink into chat. |
| Special badge | hover | special slot | highlight and describe special mode. |
| Special badge | click | journal editable | opens SpecialMenu. |
| Notes badge | hover/click | has notes | standard notes-card path. |
| Requirement link | hover | locked | Blizzard spell/achievement tooltip. |

Dropping an actual pet into a special slot clears its special annotation unless the action is a slot swap (in which case the special annotations move with the pets). A special value is stored separately from what Blizzard has physically loaded. After any leveling special slot change, the queue process runs to choose/rearrange its candidate.

## Right-click LoadoutMenu

Both normal and mini slots use the same cursor-anchored menu. The first title is `Battle Pet Slot 1`, `2`, or `3`; the PetButton form uses pet name as title in the same menu context.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Put Leveling Pet Here | current slot is not leveling | marks slot as leveling (special value 0), then queue process fills it. |
| Stop Leveling This Slot | current slot is leveling | removes special marking; preserve physically slotted pet. Highlighted while active. |
| Put Random Pet Here | current slot is not random | opens `Any Type` plus ten Blizzard pet-type choices; chooses an eligible high-level random pet and records `random:type`. |
| Stop Randomizing This Slot | current slot is random | clears random special marking. |
| Ignore This Slot | current slot is not ignored | marks special ignored. |
| Stop Ignoring This Slot | current slot is ignored | clears ignored special marking. |
| Summon / Dismiss | actual pet sub-menu context | toggles companion. |
| Set Notes | actual pet sub-menu context | opens pet note editor. |
| Find Similar | actual pet sub-menu context | applies similar-species filter in Pets. |
| Find Teams | actual pet sub-menu context; disabled if zero teams | opens Teams search for pet. |
| Rename | actual pet sub-menu context | opens rename dialog. |
| Set Favorite / Remove Favorite | actual pet sub-menu context | toggles Blizzard favourite. |
| Cancel | always | close. |

The dedicated `SpecialMenu`, launched from the badge, contains only the first six special-mode choices plus Cancel and has the same state visibility/highlighting. The random submenu uses `Any Type` and the ten pet family labels/icons.

## Mini loadout panel (only scope relevant here)

Mini loadout replaces the large 3×137 stack in narrow modes. Each of its three equal-width **92 px high** cards has 40×40 icon at top, a 26 px-wide vertical ability bar at top-right, and one or two 38 px-wide status bars below icon. Mini status differs:

- below level 25: upper green health bar and lower blue XP bar;
- level 25: only lower green health bar, with heart + numerical/percent/Dead health text in the upper area;
- empty slot: both bars empty black.

Mini cards retain icon/border/favourite/level/status, pet-card click/hover, drag/drop, right-click LoadoutMenu, cursor glow, special badge, and lock overlay. It omits normal slot names, breed, notes badge, 3D model, and large type decal. Its ability flyout is horizontal/left-opening rather than the normal vertical/bottom arrow version, but retains the two alternatives, selection highlight, and 1.5 second linger rule.

## Fonts and colours

| Use | Font / colour |
|---|---|
| Loaded team name / slot name | `GameFontNormal`; normal gold `#FFD200` or configured rarity for pet name. |
| Species / breed | `GameFontHighlightSmall`, `#E6E6E6`; larger breed uses `GameFontNormal`. |
| Health text | `GameFontHighlight`; red status comes from dynamic health string. |
| Ability number | `GameFontHighlightSmall`; mini uses `SystemFont_Tiny`. |
| Locked explanation | `GameFontHighlight`; requirement link `GameFontNormalLarge`. |
| HP / XP | `#1AE61A` / `#2E8AE6`. |
| Level requirement | `#FF4040`. |
| Special backs | leveling `#80BFFF`, random `#80FF80`, ignored `#FF8080`. |

## Options affecting this surface

| Option label | Group | Default | Effect |
|---|---|---:|---|
| Load Healthiest Pets / Ally Any Version / After Pet Battles Too | Team | off | Alters team-pet resolution on loading, not card layout. |
| Show Extra Preferences Button | Leveling Queue | off | Shows blue settings/paw-area button on loaded team when a leveling slot exists. |
| Hide Notes Badges | Appearance | off | Hides notes badge in slots and notes indicators elsewhere. |
| Hide Breeds In Pet Slots | Breed | off | Hides loadout breed label. |
| Larger Breed Text | Breed | off | Uses normal rather than small breed font. |
| Hide Rarity Borders | Appearance | off | Muted generic pet border rather than rarity border. |
| Hide Level At Max Level | Appearance | off | Hides level bubble at level 25. |
| Color Pet Names By Rarity | Appearance | on | Rarity colour rather than normal gold. |
| Show Ability Numbers / On Loaded Abilities Too | Appearance | off / off | Shows 1/2 tier markers and matching ability-bar/flyout border crops. |
| No Summon On Double Click | Miscellaneous | off | Disables double-click summon. |
| Keep Companion | Miscellaneous | off | Restores prior companion after slot swap. |

## Akolus fork changes

The fork has no layout or user-facing behavioural redesign in these three files. All three changes are WoW 12.1 API substitutions from global `MouseIsOver(frame)` to the frame method `frame:IsMouseOver()`:

- normal loadout’s hovering-slot card refresh and flyout linger detection;
- mini loadout’s equivalent two paths;
- loaded target panel has only leading whitespace / blank-line-level difference under the prescribed whitespace-insensitive comparison.

Implement the same hover continuity: when a slot update replaces the pet under an unlocked visible pet card, re-run the current hover target; and keep a flyout open while pointer is over its origin or itself.

## Source vs screenshot

- Both screenshots show the normal 3-panel layout: 280 px centre loadout, target at top, 26 px named-team strip below, then three full-height cards. The screenshot agrees with **75 px** normal target panel rather than the old commented 87 px reference.
- `rematch-journal-teams` shows target `Lorewalker Cho’s Dream Brew`; the top bar has its framed model-ish/portrait icon and `Save`, with visible enemy pets. It also shows two small square actions right of its name area (green paw/target editing and blue dice/random) and no attached saved ally panel in that example.
- Screenshot normal slots show dead pet red-X overlay, `Dead` label above empty health fill, level bubbles, three ability buttons, type decal, and a small 3D model at right, matching source.
- `rematch-queue` confirms switching only the right panel to Queue does not alter the central loaded target/team/loadout stack.

## States / lockouts

| State | Result |
|---|---|
| No target | target title `No Target`, no portrait/team/buttons. |
| No loaded team | strip says `Battle Pet Slots`; no Notes/favourite. |
| Journal locked | no swapping/configuration; lock overlay / card lock interaction only. |
| PvP queue | slot locks and supplies queue-related lock tooltip. |
| Battle / combat / player not in world | cannot swap through drag/drop/menu; current battle values are read live for display. |
| Slot progression locked | dark overlay and unlock requirement; ability bar hides. |
| Cursor carrying pet | every eligible slot gets pulsing yellow glow; drop accepted if not locked. |
| Dead/injured | pet icon red X/haze; current health shown as Dead/red percentage. |

## Open questions / gaps

- The exact visual meaning of the screenshot’s two small loaded-target actions is resolved by source as Edit Target (paw) and Load Random Pets (dice); their sprite detail is own art and needs recreation rather than copying.
- No screenshots cover mini mode, but source fully specifies its relevant dimensions and interactions.

## R0 acceptance

Compare the three-slot layout and loaded-team/target strips to the supplied journal/queue images. Exercise empty, progression-locked, dead, injured, leveling-placeholder and missing-owned-pet slots; ability choices and drag/drop must respect lockouts. Inspection, tooltip refresh and list rebuild cannot apply a team. Partial loading remains visible until journal confirmation; saved slot intent is preserved. PBS execution belongs only to the [battle](battle.md) control, not a loadout refresh or team selection event.
