# Pet card
Sources: `cards/cardManager.lua`, `cards/petCard.xml`, `cards/petCard.lua`, `cards/petCardMixins.lua`, `cards/petCardStats.lua`, `cards/notes.xml`, `cards/notes.lua`, `tooltips/abilityTooltip.xml`, `tooltips/abilityTooltip.lua`, `tooltips/tooltipManager.lua`, `main/constants.lua`, `savedvars/settings.lua` · Fork changes: `cards/petCardExtras.lua` (new), `cards/notes.lua` · Screenshots: `rematch-pet-card.png`

## Purpose

The pet card is the detailed, floating inspection surface for an owned pet, an uncollected species, a battle pet, or one of the loadout placeholders. It starts as a mouse-transparent tooltip and becomes an interactive, movable card after a click. It has a data-heavy front and a lore/source/type-combat back.

Team and pet note editing uses a separate floating notes card in the same card-management system. The loaded-team and list surfaces that invoke it are specified in [loadout](loadout.md), [teams](teams.md), [queue](queue.md), and [pet list](pet-list.md).

## Frame tree

- `PetCard` — movable, clamped, fullscreen-strata window
  - titlebar chrome — close, minimize/maximize, conditional pin, conditional unflip
  - `CardBorder`
    - `Heading`
      - `PetPortraitButton`
      - `Name`
      - `TypePortraitButton`
    - `Front`
      - `Stats`
        - dynamic `StatRow[]`
        - level pennant, level label and level
        - optional species-name line
        - display-model / fallback player-model
        - health and XP bars
        - optional collected line, possible-breeds line, Alt help line
        - hover `BreedTable`
      - `AbilityGrid`
        - `AbilityButton[1..6]`
    - `Back`
      - `Source`
      - `Lore`
      - `Racial`
- `AbilityTooltip`
  - `TooltipHeading`
  - `Details`
  - optional `VsHints`
- `NotesCard`
  - titlebar chrome / lock-position button
  - `NotesHeading` — generic scroll icon, subject name, subject/group icon
  - `EditorScroll`
    - edit box, focus grabber, scrollbar, resize grip
  - focus-only `EditorControls` — Delete, Undo, Save

## Pet card geometry and layout

The outer card begins at **258 × 358 px**, centred before its first anchor calculation. Its variable height is the larger of the fully laid-out front and back, so flipping never changes the outer height. Normal chrome contributes 33 px; the bordered content begins `(2, -22)` from the outer top-left and ends `(-2, 2)` from the outer bottom-right.

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---:|---|
| Close | outer card | top-right `(-1,-1)` | 22×22 | Standard card chrome. |
| Minimize | outer card | immediately left of Close | 22×22 | Toggles minimized setting. |
| Pin | outer card | top-left `(1,-1)` | 22×22 | Only visible once actually pinned. |
| Unflip | outer card | to right of pin when pin is visible; otherwise `(1,-1)` | 22×22 | Only visible for a click-persisted back side. |
| Heading | CardBorder | top-left `(2,-2)` to top-right `(-2,-2)` | height 47 normal; 38 minimized | Brown/gold gradient. |
| Pet portrait | Heading | top-left `(4,-4)` normal; `(4,-3)` minimized | 40×40 normal; 32×32 minimized | Round/masked icon with a 40 px pet-battle frame. |
| Type portrait | Heading | top-right `(-4,-4)` | 40×40 normal; 32×32 minimized | Round/masked type-family icon. |
| Name | Heading | right of pet icon +2 to left of type icon −2 | heading height | Shadowed medium outlined font; normal gold unless name-by-rarity is enabled. |
| Front / Back | CardBorder | below Heading to content bottom-right `(-2,2)` | fluid | Exactly one is shown. |
| AbilityGrid | Front | bottom-left to bottom-right | 111 high normal; 99 minimized | Brown/gold gradient, top divider. |
| Stats | Front | top-left to top-right of AbilityGrid | fluid | Rock background, optional faint art, model and rows. |
| Source | Back | top-left to top-right | 0–fluid, normally 50+ | Source wraps; expansion is appended here unless front expansion is enabled. |
| Lore | Back | Source bottom to Racial top | fluid | Parchment field. |
| Racial | Back | bottom-left to bottom-right | 105 + racial text normal; 67 minimized | Brown/gold field, top divider. |

### Front statistics

Rows start at stats top-left `(6,-6)`. A normal stat row is 16 px tall, icon at `(2,0)` sized 16×16 and text at `(20,0)`; rows are separated by 1 px. Normal cards stack one column and reserve a minimum 150 px model-height. Minimized cards may use two 90 px-wide columns with a 1 px gap and may distribute rows vertically to match a taller reverse side. Dynamic text is constrained to 175 px before wrapping.

The normal card can show these rows in this order after any wide rows (revoked, cannot summon, expansion, new-pet marker):

| Row | Shown when | Value / interaction |
|---|---|---|
| New Pet | wrapped/fanfare pet is temporarily stickied | green `New Pet`. |
| Pet marker | a marker exists on the species | marker icon and renamed marker label. |
| Slotted | currently in one of three journal slots | green check and `Slotted`. |
| Favorite | pet is favourite | favourite icon. |
| Leveling | listed in leveling queue | leveling icon and label. |
| Health | battle-capable pet has health | max health, or red current/max. |
| Power | battle-capable stat exists | power number. |
| Speed | battle-capable stat exists | speed number. |
| Rarity | not minimized | rarity-coloured quality name. |
| Breed | a breed source is active and breed applies | breed label, or unknown. Hover can expose breed table when the bottom line is hidden. |
| Teams | pet/species belongs to saved teams | count, clickable to open team search. |
| No Trade | obtainable but not tradable | fixed label. |
| Unique | obtainable and only one may be owned | fixed label. |
| Collected | compact/minimized collected mode | count `n/max`; full version is otherwise below rows. |
| Strongest Vs | option enabled for battle pet | up to three weighted enemy-type icons. |
| Species ID | option enabled | numeric species ID. |
| Notes | species has notes | notes icon; hover/click runs the notes card. |
| Search | obtainable species | click clears filters and searches exact species name. |

`Health`, `Power`, `Speed`, and `Rarity` use subregions of `Interface\PetBattles\PetBattle-StatIcons`; breed uses `Interface\AchievementFrame\UI-Achievement-Progressive-Shield`; Slotted uses `Interface\RaidFrame\ReadyCheck-Ready`; and Search uses `Interface\Minimap\Tracking\None`. Marker rows use `Interface\TargetingFrame\UI-RaidTargetingIcons` in a 4×4 crop. New-pet, leveling, teams, notes, unique, and Rematch badge art are **own art — redraw or substitute**.

At lower-left, components are packed upward in this order:

1. **XP bar**, if level is below 25: outer 232×12, fill 226×8, blue `#2E8AE6`; text is `XP: current/max (percent)` only on hover unless always-show is set.
2. **Health bar**, if injured or always-show-health is set: same geometry, green `#1AE61A`; text gives current/max and percent or `Dead`, hover-only by default.
3. **Alt hint**, only on normal non-placeholder cards and when menu help and a flip modifier are enabled. Screenshot wording is `Hold [Alt] to view more about this pet.`
4. **Possible Breeds**, if breed data exists and the option does not suppress it. It shows `Possible Breeds:` followed by values such as `P/P, S/S, P/S, S/B` in pale grey. Hover shows the breed table.
5. **Collected**, for an obtainable species unless compact-collected is enabled. It shows the colour-coded collection count and each owned version’s level/rarity/breed; screenshot example: `Collected (1/3): 25 S/S`.

The XP and health fills use `Interface\TargetingFrame\UI-StatusBar`; their thin 232×12 border is **own art (`textures/borders`) — redraw or substitute**. Full-width lower text is inset 2 px from each edge.

### Pennant, art and model

- A 40×40 pennant at Stats top-right `(-5,-1)` gets the pet’s rarity colour; `Level` is centred at `(+2,-2)` and its `Level` caption sits 1 px above it. The pennant is **own art (`textures/pennant`) — redraw or substitute**.
- A custom-named pet gets its species name at `(8,-6)`, bounded right by the pennant at `-42`.
- The model is top-right `(-3,-3)`, nominally 168×172, but is sized to the available stats height (at least 172 px wide / 150 px tall equivalent). It has a 162×80 shadow from `Interface\PetBattles\PetJournal` at its bottom.
- If models are hidden by minimization or there is no display ID, no model appears. Special placeholders use a fallback named model instead of a pet model.
- Faint stats-background choice is Expansion banner, pet icon, creature portrait, or type icon; icon/portrait/type art is masked and 15–20% alpha. The default is Expansion. Rock base is `Interface\FrameGeneral\UI-Background-Rock`, with `Interface\Common\ShadowOverlay-Corner` over it.

### Ability grid

| Element | Anchor in AbilityGrid | Size | Notes |
|---|---|---:|---|
| Column 1 ability 1/2/3 | top-left `(4,-4)`, then 3 px below prior | 120×32 normal, 120×28 minimized | If only three abilities exist, first column begins x=63 to centre them. |
| Column 2 ability 4/5/6 | top-right `(-4,-4)`, then 3 px below prior | same | Missing ability slots hide. |
| Icon | left `(2,0)` | 28×28 normal, 24×24 minimized | crop 7.5–92.5%. |
| Icon border | left `(0,0)` | 32×32 normal, 28×28 minimized | **own art (`textures/borders`) — redraw or substitute**. |
| Type decal | right | 46×32 normal, 40×28 minimized | **own art (`textures/pettypedecals`) — redraw or substitute**. |
| Ability name | right of icon +4 | remaining width ×30 | `GameFontNormal`, pale gold `#FFD180`. |

An ability selected neither for this pet’s saved team nor expected team tag is dimmed to 50% with greyscale name/icon/decal. A qualifying pet-search/type-search/ability-search match gains a gold 32×32 border around the matching heading or ability icon, cropped from `Interface\PetBattles\PetBattleHUD`.

For a leveling, ignored, random, unnotable-target, or non-battleable subject, all six buttons hide and a central alternative explanation is shown instead. Do not reproduce the upstream prose; communicate respectively that the loaded slot will accept the current queue pet, be skipped, select a high-level random pet, is not recorded, or cannot battle.

## Back side

| Region | Visual / content |
|---|---|
| Source | Rock field with a top divider. Wrapped source line inset 8 px. Long source text uses smaller font; minimized state flattens newlines and truncates at roughly 500 characters. The expansion name is appended in gold unless it was requested as a front stat. An uncollectable opponent receives a short opponent-pet indication instead. |
| Lore | Greyed parchment (`Interface\Store\receipt-parchment-middle`, cropped to 73.4375% width), subtle custom reverse shadow, four grey collection-corner ornaments and centred lore text. At under 20 px tall, hide ornaments. Use Skurri 15 (`Fonts\skurri.ttf`) where available; Korean/Chinese/Russian fallbacks are specified in source. Alternate setting uses `SystemFont_Med1`. |
| Racial | Brown/gold background with a top divider. Normal only: type icon, type name flanked by small curls, passive/racial text. Both sizes: centred `Damage Taken`, then strong-from and weak-from type icons with Blizzard strong/weak badge art and the associated attack types. |

The type and incoming-counter icons are `Interface\PetBattles\PetIcon-<suffix>` with their family crop. Strong/weak badges are `Interface\PetBattles\BattleBar-AbilityBadge-Strong` and `...-Weak`. Custom shadow is **own art (`textures/unshadow`) — redraw or substitute**.

## Ability tooltip

Hovering an ability opens a delayed tooltip (same option speed as other tooltips) anchored to the opposing corner of the source button relative to the relevant panel. It is mouse-disabled, clamped, initially **260×200 px**, then height-fits its actual content.

| Region | Layout / content |
|---|---|
| Header | 252×46 at top `(0,-4)`, brown/gold background. Left ability icon and right type portrait, each 40×40 masked and framed from `PetBattleHUD`; centred pale-gold name in a shadowed medium outlined font, enlarged by 2 px from its base. |
| Details | 252 px wide rock field between header and hints. The content begins 8 px below top, is 238 px wide and separated by 6 px: duration if provided, maximum cooldown if provided, parsed stat-dependent description, and optional grey `Ability ID: n` row. |
| Background choice | Optionally a 15% masked ability icon or type icon at right if at least 32 px fit; otherwise no overlay. |
| Strong/weak footer | 252×38 at bottom `(0,4)`, brown/gold field and divider. It has `Vs` labels and 30×30 strong/weak badges plus the type they affect. Hide the entire section for abilities that deliberately carry no matchup hint (for example healing/buff behaviour). |

The tooltip takes duration, cooldown, hit/chance language, and the fully resolved description from Blizzard’s ability-tooltip data for the displayed pet’s live maximum health, power, and speed. Therefore the specification requires the tooltip content model to expose: **name, type icon/name, duration, cooldown, hit chance when Blizzard includes it, description, strong-vs type, and weak-vs type**. Do not parse or hard-code the visible description independently.

## Pet-card interactions

| Element | Input | Effect |
|---|---|---|
| Any eligible pet row/icon/slot | hover | Requests a card through the shared manager. Normal delay is 0.25 s; Slow is 0.75 s; Fast is immediate; Click mode never opens it on hover. |
| Same subject / card | left click | A pending card opens immediately and locks. An unlocked visible card locks. A locked same-subject card unlocks; Click mode hides it. A new subject replaces card content and reanchors while retaining lock. |
| Locked card | Escape | Hides, unless the card’s policy says otherwise (pet card has no exception). |
| Card body | drag | Always movable. If pinning is permitted, drop saves its centre coordinate and marks it pinned. |
| Pin | click | Unpins and returns to dynamic source anchoring. Pin button only displays when pinned. |
| Card / minimize | double click or button | Toggles minimized format: shorter header/ability rows, 32 px portraits, compact stats; card width remains 258. |
| Pet/type portrait | hover | Brightens portrait. Unless mouseover flip is disabled, temporarily exposes back. |
| Pet/type portrait | click | Toggles a persistent back-side flip for non-special subjects. The unflip chrome appears while this state persists. |
| Configured modifier (Alt by default) | press/release while shown | Temporarily flips front/back. If a persistent flip is active, holding modifier gives the front instead. `None`, Alt, Shift, and Ctrl are valid settings. |
| Stat row | hover | White 12.5% highlight, icon highlight, and concise tooltip; Breed opens its detailed breed table if no bottom breed line is visible. |
| Teams stat | click | Opens Teams and searches this owned pet ID or species name. |
| Search stat | click | Opens Pets, clears filters, searches exact species name, hides card. |
| Notes stat | hover/click | Runs the NotesCard hover/lock path for this pet’s species-scoped note. |
| Possible Breeds | hover | Displays breed table; leave hides it. |
| Breed table | display | Anchors from the opposite screen corner of its initiating breed row/line, clamped; current breed gets a subtle 10% white row highlight. |
| Ability | hover | Shows 12.5% row highlight, icon highlight and AbilityTooltip. |
| Ability | Shift-click | Inserts Blizzard ability link into active chat edit. |
| Ability | right click | Opens a two-item menu: ability title and `Find Pets With This Ability`, which exact-searches its name. |
| Pet link in chat | click (option enabled) | Replaces Blizzard floating pet tooltip with a locked movable card. Second click on the same linked subject closes it. Chat-link modifier bypasses this replacement. |

### Positioning relative to lists and loadout

Unpinned cards anchor to the corner of the initiating element that faces away from the *reference panel*: bottom-left initiator → card bottom-left to initiator top-right; top-left → card top-left to bottom-right; top-right → top-right to bottom-left; otherwise bottom-right → bottom-right to top-left. The reference panel’s vertical midpoint is intentionally biased upward by 20%, favouring upward anchoring. Top-corner anchors add 24 px Y to allow for hidden tooltip chrome. If no source exists, centre the screen.

A pet card invoked from a list/loadout slot uses the enclosing Rematch window (or dialog) as reference, so every row in a list selects consistent side placement. During battle, the active ally/enemy frames override normal placement: place card top-centre below that battle unit with a 16 px gap. A pinned card uses saved centre coordinates relative to UI parent and stops following rows/slots. A chat-link card uses its own saved floating position rather than normal anchoring and cannot be pinned through normal pin policy.

## Shared card manager rules

- Cards register an `update(subject)`, optional lock callback, optional pin callback, optional eligibility test, and optionally a no-anchor/no-hide/no-Escape rule.
- Hover cards are intentionally mouse-transparent: outer chrome alpha 0 and all registered child controls mouse-disabled. This prevents an anchored card under the cursor from generating hover churn.
- Locked cards set chrome alpha 1 and mouse-enable every registered child. Lock selection is reflected in the pet list/queue list for a locked pet card.
- Leaving a source cancels a still-pending hover timer. Leaving an unlocked visible card hides it; locked cards stay until explicitly toggled, closed, or replaced.
- The manager hides outstanding notes before a menu opens and hides all cards on relevant UI reconfiguration. It saves card pin coordinates as centre points based from UI-parent bottom-left.
- Normal and Slow hover use the 0.25 s and 0.75 s delays above. Click behaviour identifies a subject and opens locked directly; a second click on the current subject hides it.

## Notes card

The NotesCard is **258×258 px** initially, fullscreen strata, clamped, movable and resizable. Like pet card it has outer chrome and an inside border from `(2,-22)` to `(-2,2)`. Unlike a pet card it declares no automatic anchor: absent stored coordinates it starts centred; after a move/resize it restores stored bottom-left `(NotesLeft, NotesBottom)` and `NotesWidth × NotesHeight`.

| Element | Parent / anchor | Size | Notes |
|---|---|---:|---|
| Lock position | outer top-left `(1,-1)` | 22×22 | lock/unlock icon. Locked state hides resize grip and shortens scrollbar bottom inset. |
| Heading | inner top `(2,-2)` to `(-2,-2)` | 38 high | Brown/gold. Left generic scroll icon, middle subject name, right group icon or pet icon; two 32 px portrait frames. |
| Editor scroll | below heading `(6,-8)` to inner bottom-right `(-26,8)` | fluid | Marble background behind interior; scrollbar at right, 13 px top inset. |
| Edit box | scroll canvas | initial 100×64; runtime width=card width−45 | Multiline, no auto-focus; configured `NotesFont`, default `GameFontHighlight`. |
| Focus grabber | scroll bounds | full | Clicking blank editor area puts cursor at text end. |
| Resize grip | scroll lower-right `(23,-5)` | 16×16 | Blizzard chat size-grabber art, with outward hit area. |
| Bottom controls | inner bottom `(2,2)` to `(-2,2)` | 26 high | Hidden until editor focus. Brown/gold top divider; three computed-equal buttons Delete / Undo / Save. |

For a team, title is the formatted team name and the right icon is its group icon; data writes to that team’s `notes`. For a pet, title is the rarity-coloured pet name and right icon is pet icon; data writes to `PetNotes[speciesID]`, so all versions share it. Notes support ordinary search text: putting `#find` in a pet note and searching `#find` finds the species.

| Element | Input | Effect |
|---|---|---|
| Notes badge/stat/menu | hover/click | Same manager semantics as pet cards; menu opens a locked card and focuses editor. |
| Editor gains focus | focus/click | Shrinks scroll bottom by 26 px and shows controls. |
| Save | click | Trim text; write non-empty text or clear empty field; refresh UI, emit notes-changed update, clear focus. Team write only applies to user teams. |
| Undo | click | Restores original note value at card-open. |
| Delete | click | Hides card then prompts if confirmation remains enabled and original note existed; deletes directly otherwise. Confirmation may permanently be disabled. |
| Card body / grip | drag | Moves / resizes unless position lock is on; writes all four geometry settings on release. |
| Position-lock | click | Toggles lock; hides grip when locked. |
| Escape while editor | press | Clears editor focus without immediately reclaiming it. |
| Escape while locked notes card | press | Hides, unless `Keep Notes On Screen` and `Even When Escape Pressed` are both enabled. |

`Keep Notes On Screen` prevents global card hiding for notes; `Show Notes On Load`, `Show Notes In Battle`, `Show Notes Once Per Team`, and battle notes-button visibility govern invocations outside this surface. See [options](options.md).

## Fonts and colours

| Use | Font / colour |
|---|---|
| Card title / tooltip name / notes subject | `SystemFont_Shadow_Med1_Outline`; normal gold `#FFD200` except configured rarity title. |
| Body stat text | `GameFontHighlight`; standard white. |
| Ability names / back labels | `GameFontNormal`; pale gold `#FFD180`. |
| Full-width lower text / lore source | `GameFontNormal`; Alt hint `#999999`; breed values `#E5E5E5`. |
| Lore | Skurri 15 black (`Fonts\skurri.ttf`) or listed locale fallback; alternate `SystemFont_Med1`. |
| Status text | `SystemFont_Outline_Small`. |
| Border/lines | `#808080`; card standard panel fill around `#0D0D0D`, shadow dialog fill around `#333333`. |
| Hover blocks | `#FFFFFF` at alpha `.125`; gold active text `#FFD200`. |
| Leveling/random/ignored slot semantic colours | light blue `#80BFFF`, light green `#80FF80`, salmon `#FF8080`. |

## Options affecting this surface

| Option label | Group | Default | Effect |
|---|---|---:|---|
| Card Speed | Behaviour | Normal | Normal / Slow / Fast / Click shared card opening policy. |
| Tooltip Speed | Behaviour | Normal | Ability-tooltip opening policy. |
| Card Background | Pet Card | Expansion | Expansion, icon, portrait, type, or no displayed stats background according to option menu. |
| Flip Modifier Key | Pet Card | Alt | Alt/Shift/Ctrl/None temporary front/back flip. |
| Allow Pet Cards To Be Pinned | Pet Card | off | Allows drag to establish persistent pinned location. |
| Don’t Flip On Mouseover | Pet Card | off | Disables temporary flip on top-portrait hover. |
| Show Expansion On Front | Pet Card | off | Shows expansion stat and omits expansion append on Source. |
| Show Species ID | Pet Card | off | Adds species row. |
| Always Use Collected Stat | Pet Card | off | Replaces full collected line with compact row. |
| Always Hide Possible Breeds | Pet Card | off | Suppresses lower breed line; Breed row still exposes table. |
| Always Show HP/XP Bar Text | Pet Card | off | Keeps bar labels visible. |
| Always Show Health Bar | Pet Card | off | Shows health bar even full. |
| Alternate Lore Font | Pet Card | off | Uses standard system type rather than cursive lore font. |
| Use Pet Cards In Battle | Pet Card | off | Enables battle-side pet card paths. |
| Use Pet Cards For Links | Pet Card | off | Replaces native linked-pet floating tooltip. |
| Click Pet Icon To Show Model | fork Pet Card | **on on first fork login** | Fork makes pet portrait click toggle external model window rather than persistent flip; type icon continues to flip. |
| Keep Notes On Screen / Even When Escape Pressed / Notes Size | Notes | off / off / `GameFontHighlight` | Persistence/Escape rules and editor font. |

## Akolus fork additions and differences

`cards/petCardExtras.lua` is a fork-only companion, not a change to the base card layout.

- **Shift** while the base pet card is visible opens a borderless dark `Possible Breeds` companion immediately to its **left**, 6 px gap. It is 278 px wide, has a 114 px header plus 23 px rows and 18 px lower padding. It labels pet and `Level 25 Rare stats`, displays breed / health / power / speed, gives the active breed an 18 px star and a gold alpha `.08` row highlight. It computes expected rare level-25 values through bundled BPBID-compatible data. It hides when Shift releases or base card closes.
- A persistent **model companion** opens to the base card’s **right**, 6 px gap; it is 258×358, borderless dark, inset 6 px model viewport, 24×24 custom close at top-right `(-4,-4)`, and wheel zoom from .05 to .80 in .05 steps, starting .15. It hides when base card closes and clears its persistent-open state.
- New `Click Pet Icon To Show Model` is inserted after `Don’t Flip On Mouseover`; on first fork login it defaults true. With it enabled, clicking the existing **pet** portrait opens/closes that model companion rather than hard-flipping; type portrait still flips, and portrait hover flip still follows existing option.
- The fork owns its own `textures/breedstar` and `textures/modelclose`; both are **own art — redraw or substitute**. Its dark panels use Blizzard `Interface\DialogFrame\UI-DialogBox-Background` without an edge border.
- Screenshot’s lower `Collected (1/3): 25 S/S` and `Possible Breeds: P/P, S/S, P/S, S/B` are **base-card** fields from `petCard.lua`, not fork extras. The fork companion only opens while Shift is held.
- Fork `cards/notes.lua` makes only a WoW 12.1 API-call substitution (`frame:IsMouseOver()` rather than global `MouseIsOver(frame)`) when deciding whether focus should remain on bottom controls or resize grip. It does not alter NotesCard layout or user behaviour.

## Source vs screenshot

- Screenshot shows the normal front at about **258 px wide / 458 px high**, taller than the initial 358 px because dynamic stats and lower collection/breed/help content expand it. This agrees with max(front/back)-height logic.
- Screenshot’s titlebar itself is invisible because the card is hover/unlocked; pin/minimize/close chrome appears only when locked. The front visible content remains fully opaque through the card’s `ignoreParentAlpha` content layer.
- Screenshot shows `Collected` above `Possible Breeds` and the Alt line closest to ability grid; this is the expected bottom-up packing order.
- Screenshot does **not** show a Shift breed companion or model companion. Its breed/collection lines therefore establish that these are not supplied by the fork extra module.

## States and lockouts

| State | Behaviour |
|---|---|
| Empty / unknown | Card eligibility rejects empty and unknown IDs; no card. |
| Species / unowned | Name/type/data may show; header, front and lore are desaturated. No owned-only actions. |
| Special placeholder | Uses named alternative model, no flips, no level pennant or ability grid; contextual slot explanation. |
| Non-battleable | Shows standard relevant metadata but replaces abilities. |
| Dead / injured | Red health row and/or health bar; loadout/list status is separate. |
| Wrapped | locked card unwraps with fanfare and clears the game fanfare flag. |
| Journal locked / combat / battle | Card inspection still works where caller permits it; loadout edits remain disabled by their own lockouts. Battle card display requires its option. |

## Open questions / gaps

- Exact base-card height in every locale depends on wrapped Blizzard source/lore/stat text and is intentionally content-derived.
- The screenshot cannot establish whether the fork’s model-on-icon option is still at its first-login default; source establishes its default and precedence.
- Base `PetCardBackground` choices are recorded above as reference facts; [options](options.md) limits which controls Phase A exposes. Final visible labels require review with the shipped feature.

## R0 acceptance

Compare the base card to `rematch-pet-card.png`; check hover/lock, Alt reverse side, Shift breed companion, model companion, clipping and dismissal. Inspect owned, unowned, missing and live-battle pets without changing the loadout. Secret/unavailable health, species, stats or ability details must remain unknown and must never enter formatting, comparisons or arithmetic. See [breeds](breeds.md) and [battle](battle.md) for screenshot/source differences and 12.1 fallbacks. Referenced addon artwork is evidence only and must be recreated independently.
