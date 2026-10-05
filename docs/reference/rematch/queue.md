# Leveling queue panel
Sources: `panels/queuePanel.lua`, `panels/queuePanel.xml`, `process/queue.lua`, `process/preferences.lua`, `menus/queueMenu.lua`, `process/loadTeam.lua`, `process/loadouts.lua`, `templates/petListButton.lua`, `main/main.lua`, `process/toast.lua`, `savedvars/settings.lua` · Fork changes: `panels/queuePanel.lua` replaces two deprecated mouse-over calls; behavior and appearance unchanged · Screenshots: `rematch-queue.png`

## Purpose
The Queue panel is the journal right-column leveling roster. It accepts owned under-level pets, orders them manually or by active sort, applies preference eligibility, and supplies the first available preferred pets to every loadout slot marked as a leveling slot. It does not itself create leveling slots; those are set from the loadout-slot context menu specified in [loadout](loadout.md).

## Frame tree
- `RematchWindow > QueuePanel`
  - `PreferencesInset`
    - `PreferencesGearButton`
  - `QueueTopBar`
    - `QueueCountLabel`
    - `QueueMenuButton`
  - `ActiveSortStatusBar` (conditional)
    - `StatusText`
    - `ClearActiveSortButton`
  - `QueueScrollList`
    - normal or compact `QueuePetRow[*]`
    - muted empty help
    - trailing capture area
    - drag `DropGlow` / pulsing insertion line

## Layout
The generic list width is 246 px (306 px in single-panel standalone), while the screenshot's journal host stretches this panel to its right column.

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---|---|
| preferences inset | Queue panel | `TOPLEFT` | 29×29 | dark inset cell holding gear |
| preferences button | inset | left 3,0 | small grey icon button | active gear or paused gear-with-red-X |
| top bar | Queue panel | left of preferences inset right +2; `TOPRIGHT` | stretch ×29 | dark inset frame |
| queue count | top bar | left 8,0 to menu left -4 | stretch | `GameFontNormal`; reads `Leveling Pets: N`, N white |
| Queue menu button | top bar | `TOPRIGHT`, -3,-3 | 80×24 | label `Queue`, right arrow |
| active-sort status | Queue panel | top below preferences inset and top bar, 0,-2 | stretch ×26 | only visible while Active Sort is on |
| status clear | status | right -4,0 | 18×18 | clears active sort |
| queue list | Queue panel | below status when shown, else below preferences inset; 0,-2 | stretch | normal 44 px or compact 26 px list rows |
| empty explanation | queue list | center -8,16 | 200×300 | muted `#BFBFBF`, hidden by Hide Extra Help |
| glow line | list overlay | current row top/bottom or capture area | normal 244×8 / standalone 304×8 | own art pulse shows drag insertion point |

## Row layout and states
Queue rows reuse the pet-list row template; see [pet card](pet-card.md) and [pet list](pet-list.md) for the shared icon, rarity border, text, breed, health/XP, and badge geometry. Queue-specific requirements:

| State | appearance | meaning |
|---|---|---|
| normal row | standard pet row | owned, battle-capable pet under level 25 |
| current leveling pet | normal shared leveling badge behavior | pet currently assigned to a marked loadout slot |
| not preferred | entire row alpha 65% | retained in queue but does not beat preferred pets for a leveling slot |
| moving | black 65% overlay tint | dragged source pet currently on cursor |
| hovered | shared body highlight + pet card | if held cursor pet cannot level, show explanatory cursor tooltip |
| normal size | 44 px | standard pet list presentation |
| compact size | 26 px | Compact Queue List setting |

The queue passes a `forQueue` row flag, so pet-list badges omit the normal leveling marker rule intended for other lists. Pet card interaction remains available. When `Double Click To Send To Top` is on, double-click a queued pet moves it to index 1 (if there are at least two) rather than summoning it; otherwise standard double-click summoning applies unless globally disabled.

## Empty state
When there are no entries and `Hide Extra Help` is off, center a muted instructional block explaining that users drag pets here, mark a battle-pet loadout slot as leveling, and that level-25 pets advance out of the queue. Do not reproduce the original multi-paragraph wording verbatim. Hide this block when Help is hidden or the queue becomes nonempty.

## Preferences button and eligibility
The small top-left gear is a compound control:

| Input | result |
|---|---|
| left click | opens Current Leveling Preferences dialog with Current / Team / Group / Default tabs |
| right click | pauses or resumes preferences immediately |
| hover | shows current effective preference summary and left/right-click hints |

Normal visual is a blue gear sprite in own art `textures/badges-borderless`; paused state replaces it with the same gear plus red X. Queue preference state is stored globally as paused/unpaused and applies across the effective default/team/group preference merge.

### Effective preference merge
Default preferences apply first. Loaded team's preferences then overwrite matching fields, then loaded group's preferences overwrite both. Pausing ignores all configured criteria but still requires a viable owned/summonable pet. Preferences are not selection filters: entries failing them remain in the queue, dimmed, and are only used after preferred candidates are exhausted.

| Criterion | pass rule |
|---|---|
| Minimum level | `fullLevel >= min`; decimal values represent current level plus XP fraction |
| Maximum level | `fullLevel <= max`; whole-number max compares floored level, allowing XP within that exact level |
| Minimum health | max health must reach threshold; selected expected damage type increases threshold pressure for a type weak to it and reduces it for a type resistant to it |
| Maximum health | max health must not exceed threshold |
| Allow any Magic or Mechanical | magic or mechanical bypass lower level and min-health restrictions; they still obey maxima |
| Prefer Living Pets | when enabled, dead pets fail preference |
| And At Full Health | only applies under Prefer Living Pets; injured pets fail preference |

## Queue menu
The full context-menu mechanics belong in [menus](menus.md). This panel requires the following Queue menu entries and effects.

| item | mode / effect |
|---|---|
| `Ascending Level` | choose level-low-to-high criterion; radio indicates current level order |
| `Median Level` | choose closeness to level 10.5; radio indicates current order |
| `Descending Level` | choose level-high-to-low criterion; radio indicates current order |
| `In Teams First` | check criterion; when not active, run one-off sort by it; when active, participates continuously |
| `Favorites First` | same behavior for Pet Journal favourite state |
| `Rares First` | same behavior for rarity |
| `Active Sort` | continuously applies selected criteria; manual reorder is constrained |
| `Pause Preferences` | same global pause control as gear right-click |
| `Fill Queue` | propose filtered eligible pets using conservative duplicate/level-25 rule |
| `Fill Queue More` | optional menu item, shown only by setting; uses relaxed duplicate/level-25 rule |
| `Empty Queue` | confirmation then removes all entries |
| `Export Queue` | acknowledgement dialog with selected serialized list |
| `Import Queue` | paste/validate/import dialog |
| `Help` | optional explanatory item hidden by Hide Extra Help |

### Sort semantics
All queue sorts are stable: ties retain their prior order unless `Sort Queue By Pet Name Too` is enabled, in which case name ascending is the tie breaker. Owned pets always rank ahead of nonowned/invalid leftovers. The hierarchy for Active Sort, most significant first, is:

1. owned status;
2. `In Teams First`, if enabled;
3. `Favorites First`, if enabled;
4. `Rares First`, if enabled;
5. selected ascending/median/descending level rule;
6. optional pet-name tie-breaker.

Standalone selection of any criterion performs a one-time stable sort. Enabling Active Sort immediately sorts with all configured components and repeats whenever XP, pet validity, queue membership, or relevant sort state changes. Status bar then reads `Active Sort:` plus its 18 px sort icon and selected textual level order. Its X disables Active Sort and hides the bar; it does not undo the last sorted order.

## Manual queue ordering and drag-drop
Drag any pet that can level from a pet list to Queue. While such a pet is on the cursor, show list-wide glowing insertion feedback. Place before a row when cursor is in its top half, after it in bottom half, or at end in capture space. Drop behavior:

| source / state | result |
|---|---|
| new levelable pet, manual queue | insert at requested position |
| queued pet, manual queue | move existing entry to requested position |
| new levelable pet, Active Sort | insert, then automatic sort determines final position |
| queued pet, Active Sort | prompt to turn Active Sort off and move; if no-repeat setting is enabled, turn off and move directly |
| non-levelable pet | no insertion; hover target says it cannot be added |
| right click while a cursor pet is held | cancel/clear held item in shared cursor behavior |

The source is darkened as Moving. The line bounces alpha from 25% to 100%. A dragged pet is valid only when it is owned, battle-capable, has a known level, and is below level 25. Duplicate insertion means moving the existing entry, never adding another copy.

## Queue item right-click menu
The detailed menu belongs in [menus](menus.md). Required outcomes: move to top, interactively move, move to end; summon/dismiss; team/pet notes; find teams; rename; favourite toggle; release/cage when permitted; and `Remove from Leveling Queue`. Removing is confirmed unless its no-repeat setting is active. `Find Teams` switches to Teams view and searches exact pet GUID.

## Fill, empty, import, export dialogs

| Dialog | visible content | behavior |
|---|---|---|
| Fill Queue | count of proposed pets, `Don't Ask When Filling Queue` check; >50 gives warning; Yes/No/`More` | normal fill adds one levelable copy per species from current filtered pet ordering only if species has no level-25 copy and none queued; More relaxes both restrictions |
| Empty Queue | short confirmation, Yes/No | wipes all entries then processes slots |
| Stop Active Sort | warning, explanation, `Don't Ask To Stop Active Sort`, Yes/No | Yes turns Active Sort off and performs held move |
| Remove From Queue | named-pet confirmation and `Don't Ask For Queue Removal` | removes one entry |
| Export Queue | selected multiline list and Okay | writes stable pet tags, not a promise of exact future GUID match |
| Import Queue | paste textarea; live counts of new/already queued/cannot level/invalid, or invalid warning | Import adds parseable eligible tags; exact original pet is best effort because pets can level/change |

A queue update closes queue confirmations to avoid actions targeting an outdated numeric index.

## Processing rules

### Stored entry and cleanup
Each entry carries a current pet GUID, a durable pet tag sufficient to select a comparable replacement, a derived `preferred` flag, and an add timestamp. On update:

1. rebuild GUID→index lookup;
2. remove blank or duplicate GUIDs;
3. remove level-25 pets automatically;
4. if a current pet became invalid, attempt a nonduplicate substitute matching its stored tag; leave unresolved temporarily if none exists;
5. evaluate effective preferences;
6. select up to three top picks and active-sort if enabled.

At login, a partially invalid queue drops invalid entries; if all entries became invalid after server-side GUID reassignment, rebuild as many as possible from tags. Caging/releasing deletes matching entries. New pets can auto-enroll if `Automatically Level New Pets` is enabled; `Only Pets Without One At 25` rejects a species already at 25 or queued, and `Only Rare Pets` requires rare quality.

### Selecting leveling pets
There can be up to three marked leveling slots. A team stores such a slot as a special “leveling” marker rather than a fixed pet; saved teams preserve it across loads. Queue processing scans loadout slots from 1 through 3 and, for each marked slot, assigns the next top pick. It does not use the same pet twice. Preferred queued pets are selected first in queue order; if fewer than three qualify, summonable nonpreferred entries fill remaining slots.

When loading a team, it first evaluates its effective team/group preferences. It builds the plan in slot order and replaces each leveling marker with pick 1, then pick 2, then pick 3. Fixed and random pets participate in exclusion handling so generated choices do not duplicate them. If the queue lacks a pick and `Random Pet When Queue Empty` is enabled, choose a random pet; `Pick Random Max Level` determines whether that fallback can use max-level pets.

The top newly slotted pet triggers a `Now leveling` toast unless Hide Leveling Pet Toast is enabled. Queue code retries slot confirmation after 1.25 seconds, at most 10 times, because journal loadout swaps are asynchronous.

### Advance after battle
After a pet battle, wait for Pet Journal health/XP update (up to a short three-second watch window), then process. A pet that reaches level 25 is removed, its slot receives the next top pick, and the toast changes to that pet. The queue also reprocesses when pet journal changes, a team saves/loads, slot assignments change, a pet is caged/released, XP/rarity changes, preferences change/are paused, or a relevant healing action completes.

Processing is delayed by one frame to coalesce bursts of events. It cancels/defer swaps while leaving the world and never calls a pet-slot swap if global loadout constraints prohibit it (journal lock, PvP queue, battle, combat, or unavailable world state).

## Options affecting this surface

| Option label | group | default | effect |
|---|---|---:|---|
| Compact Queue List | Lists | off | use 26 px rows instead of 44 px |
| Queue Active Sort | Queue | off | persistence flag for continuous sorting |
| Sort Queue By Pet Name Too | Queue | off | alphabetical tie-breaker |
| In Teams First | Queue | off | active-sort priority / one-time sort action |
| Favorites First | Queue | off | active-sort priority / one-time sort action |
| Rares First | Queue | off | active-sort priority / one-time sort action |
| Pause Preferences | Queue | off | ignores Default/Group/Team criteria, keeps basic loadability |
| Prefer Living Pets | Queue | off | de-prefer dead pets |
| And At Full Health | Queue | off | de-prefer injured pets under the above option |
| Double Click To Send To Top | Queue | off | queue double-click moves to index one |
| Automatically Level New Pets | Queue | off | auto-add qualifying new pets |
| Only Pets Without One At 25 | Queue | off | auto-add species guard |
| Only Rare Pets | Queue | off | auto-add rarity guard |
| Random Pet When Queue Empty | Queue | off | fill unserved leveling marker with random pet |
| Pick Random Max Level | Queue | off | allow level-25 random fallback |
| Add Imported Pets To Queue | Import | on | adds sub-25 imported team pets to queue |
| Show Fill Queue More Option | Queue | off | exposes relaxed fill menu item |
| Don't Ask When Filling Queue | Confirmations | off | skips Fill Queue confirmation |
| Don't Ask To Stop Active Sort | Confirmations | off | stops active sort directly on manual drag |
| Don't Ask For Queue Removal | Confirmations | off | skips individual remove confirmation |
| Hide Leveling Pet Toast | Notifications | off | suppresses top-pick toast |
| Hide Extra Help | Menus | off | hides empty state and Help menu item |

## Textures, fonts, and colours

| Use | specification |
|---|---|
| top/status labels | `GameFontNormal` |
| empty help | `GameFontNormal`, `#BFBFBF` |
| menu arrow | Blizzard `Interface\ChatFrame\ChatFrameExpandArrow` |
| list/pet presentation | shared pet-list materials; see [pet list](pet-list.md) |
| preferences gear / pause X | own art `textures/badges-borderless` — redraw or substitute |
| glow | own art `textures/glowline` — redraw or substitute |
| Active Sort level glyphs | own art `textures/badges-borders` — redraw or substitute |

## Source vs screenshot
- Screenshot confirms the top left gear cell, `Leveling Pets: 46` label, `Queue` dropdown, normal 44 px pet rows, and queue panel located as the journal's right column.
- Screenshot has no Active Sort status bar, which is expected because Active Sort is off; list begins immediately below the two 29 px top cells.
- Screenshot's green/blue pet names and shared right-side type/breed display are supplied by the shared pet row, not queue-specific unique fields.

## Open questions / gaps
- The brief says `Start Leveling`; the inspected 5.3.1/fork Queue menu and panel contain no button with that label. The source's practical start action is marking a loadout slot `Put Leveling Pet Here`, after which processing starts automatically. Preserve that behavior rather than inventing an extra button.
- Exact user-facing option grouping labels are owned by [options](options.md); this document records defaults and effects only.

## R0 acceptance

Compare queue placement/rows to `rematch-queue.png`; test empty/fill, manual ordering, active sort, paused preferences, dead/max-level pets, missing GUIDs and two leveling slots. Eligibility changes may refresh suggestions but cannot apply a team from rendering. Advance only on the intended process events; canceling import/empty confirmation preserves the queue. Keep queued intent distinct from the currently slotted leveling pet, and report when no candidate fits instead of silently relaxing requirements.
