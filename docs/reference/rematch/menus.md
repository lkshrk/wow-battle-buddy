# Menus
Sources: `menus/menus.xml`, `menus/menus.lua`, `menus/teamMenu.lua`, `menus/petMenu.lua`, `menus/queueMenu.lua`, `menus/loadoutMenu.lua`, `menus/targetMenu.lua`, `cards/petCard.lua`, `cards/petCardMixins.lua`, `panels/teamsPanel.lua`, `panels/queuePanel.lua`, `panels/loadoutPanelMixins.lua`, `chrome/minimap.lua`, `savedvars/settings.lua` · Fork changes: `menus/menus.lua` · Screenshots: none

## Purpose

Rematch uses a custom hierarchical popup system rather than Blizzard dropdown frames. Definitions are ordered rows whose values/visibility/enablement can be calculated against a menu subject. This document covers every concrete Rematch menu except the pet filter menu, which has its own [filter-menu](filter-menu.md) specification.

Team, target, queue and editing results cross-link to [teams](teams.md), [targets](targets.md), [queue](queue.md), [loadout](loadout.md), and [save team dialog](save-team-dialog.md).

## Frame tree

- `MenuPopup[level]` — pooled for root and each submenu depth
  - optional `MenuTitle`
  - pooled `MenuRow[]`
    - optional check/radio icon
    - optional 18 px item icon
    - text
    - optional submenu arrow
  - transient `SideActions`
    - delete 16×16
    - edit 16×16

## Generic look and geometry

| Element | Parent | Anchor / size | Visual |
|---|---|---|---|
| MenuPopup | UI parent for root; initiating row for submenu | content-fit; 8 px outer padding each dimension | Clamped, fullscreen-dialog stratum, mouse-enabled; dark shadow-backed popup. |
| Title | popup | `(3,-3)` to `(-3,-23)` | 20 px logical title height, brown/gold Pet Journal crop and bottom grey divider. Title text centred `GameFontNormal`, `#FFD180`. |
| Row | popup | top-left `(8,-currentHeight)` | height **20 px**, width=max row width; `GameFontHighlight`. |
| Spacer | popup | consumes **8 px** (or explicit height) | no control. |
| Hover | row | left −2 to right +2 | white `#FFFFFF`, alpha .10. |
| Check/radio | row | left `(leftOffset−2, 0)` | 22×22, **own art (`textures/checkbuttons`) — redraw or substitute**. Four quadrants: checkbox/radio × off/on. |
| Item icon | row | left current offset | 18×18, default crop `.075,.925,.075,.925`. |
| Submenu arrow | row | right `(8,-1)` | 18×18 `Interface\Buttons\Arrow-Up-Up`, rotated right. |
| Side actions | selected row right edge | 32×16 max | delete is `Interface\Buttons\UI-GroupLoot-Pass-Up`; edit is cropped `Interface\WorldMap\Gear_64Grey`. |

The base popup uses a solid `#333333` backdrop with a `Interface\Common\ShadowOverlay-Corner` inset shadow and `#808080` border. Its title uses `Interface\PetBattles\PetJournal` crop `(0.189453125, 0.658203125, 0.486328125, 0.5708203125)`. Divider art is `Interface\Tooltips\UI-Tooltip-Border`, crop `(0.8125, 0.9453125, 0.625, 0.9375)`, grey `#808080`. Own check art and any Rematch texture path must be redrawn/substituted, never copied.

### Dynamic width and row composition

- Visible rows alone consume height. The popup adds 8 px top and 8 px bottom effective padding.
- It measures every visible title/text/icon/indent/submenu/side-action contribution, applies any requested `minWidth`, then makes every row that max width.
- An indented entry receives 8 px left indentation. Checkbox/radio receives 20 px; icon receives 20 px; submenu arrow reserves 12 px right; delete/edit reserve 16 px each plus 2 px leading gap.
- Gold `#FFD200` row text means a definition explicitly marks it highlighted. Standard enabled text is white. Disabled text/icons/checks are desaturated/`#808080`.
- Mouse down offsets visible icon/text `(−1,−2)`; mouse up restores it.

## Generic placement, hover, close, and keyboard behaviour

| Situation | Behaviour |
|---|---|
| Root from cursor | Top-left is cursor position adjusted by UI scale, x−4/y+4. |
| Explicit anchor | Uses caller’s exact anchor. |
| Default root/submenu | Opens immediately right of originating control, aligning top; a titled menu offsets its top 30 px down. If it would exceed screen right, opens left instead. A reversed parent forces descendants left. |
| Hover submenu row | Closes deeper submenu levels, runs optional builder, then opens child. |
| Hover tooltip row | Shows row tooltip; disabled row uses its red disabled-reason text if supplied. |
| Hover side action | Keeps parent row highlight alive. |
| Click ordinary action | Runs action, refreshes visible check/disabled/highlight state, then closes all popups. |
| Click check/radio/submenu/stay action | Runs action but keeps menu open (submenus open independently). |
| Click disabled | no action and no pressed effect. |
| Mouse exits hierarchy | Root/children close after **1.5 seconds** unless pointer is over any menu, root origin control, or side-actions frame. |
| Escape | Closes menu root unless Pet Journal host is active; consumes key when it closes. |
| Parent/frame hide | Child menus hide, anchors/buttons clear and pooled rows release. |
| New menu open | Hides drag operation and active notes card first. |

## Definition features

A row can be title, text action, spacer, indented item, check, radio, icon item, submenu, disabled state, highlighted text, stay-open help, post-action callback, or an optional hover-only delete/edit side action. All presentation/condition values can be run-time expressions. `Cancel`/`Okay` are normal action rows that rely on close behaviour; a help row is stay-open and uses standard help icon `Interface\Common\help-i` crop `.15,.85,.15,.85`.

## Team row menu (`TeamMenu`)

Invocation: right-click a user-team row in [teams](teams.md). Title is raw team name.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Unload Team | shown only if this exact team is currently loaded | Clears loaded team. |
| Edit Team | always for a team row | Stages named team and opens team editor in edit mode. |
| Set Notes | always | Opens locked/focused NotesCard for team. |
| Move Team | always | Puts team in Rematch drag cursor for destination selection. |
| Set Favorite / Remove Favorite | always; dynamic label | Adds favourite: preserves current group as `homeID`, moves to Favorite Teams and flags favourite. Removes: restores `homeID` or Ungrouped and clears flag. |
| Load Target ▸ | only if team has one or more target IDs | Click loads first target into the loaded-target panel; hover submenu lists all associated targets and selecting one chooses it. |
| Edit Target ▸ | only if team has targets | Click edits first target’s team assignment; hover submenu lists all targets, choosing one opens that target editor. |
| Share ▸ | always | Opens Plain Text / Export Team / Send Team choices. |
| Delete Team | always | Confirmation dialog unless delete confirmation setting is off, then deletes team. |
| Cancel | always | close. |

Target submenu title is `Targets`; it rebuilds dynamically from team target IDs and appends `Cancel`. If no usable list, it displays `No targets :(`. Load Target promotes/summons the Teams view and, in a 1-panel layout, changes to 2-panel mode so the target is visible.

## Loaded-team menu (`LoadedTeamMenu`)

Invocation: right-click `TeamNameButton` in [loadout](loadout.md). Title is current loaded-team name. It deliberately handles transient `loadonly`/`counter` as well as user teams.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Unload Team | always | Clears current loaded team. |
| Edit Team | only a user-persisted team | Opens editor. |
| Set Notes | only a user-persisted team | Opens/focuses team notes. |
| Set/Remove Favorite | only a user-persisted team | favourite transition as above. |
| Load Target ▸ / Edit Target ▸ | only when loaded record has targets | same target behaviour as TeamMenu. |
| Share ▸ | always | See share submenu. For this menu, export captures the *currently slotted* loadout into staging first rather than exporting old saved record. |
| Cancel | always | close. |

## Share team submenu (`ShareTeamMenu`)

| Label | Shown / enabled when | Effect |
|---|---|---|
| Plain Text | always | Opens copyable human-readable team export dialog. |
| Export Team | always | Opens copyable structured Rematch team-string dialog. |
| Send Team | disabled if `Disable Sharing` is enabled | Opens Send Team dialog. Disabled tooltip explains exporting/importing remains possible. |
| Cancel | always | close. |

The export dialog’s include-notes/include-preferences controls are specified in [team strings](team-strings.md) and [save team dialog](save-team-dialog.md).

## Group menu (`GroupMenu`)

Invocation: right-click a group header or group tab. Title is group name.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Create New Group | always | Opens empty group editor. |
| Edit Group | always | Opens group editor (name, colour, icon, sort, tab, preferences). Favourite meta group has protected name edit constraints. |
| Move Group | always | Picks up group for drag rearrangement. |
| Delete Group | disabled for Favorite Teams and Ungrouped Teams | Confirmation offers whether to delete contained teams; otherwise deletes group and moves teams to Ungrouped. Disabled tooltip says system group cannot be deleted. |
| Export Group | always | Opens group-team export dialog. |
| Import Teams | always | Opens import and preselects this group. |
| Delete Teams | disabled if group has no teams | Confirmation deletes all its teams. |
| Show Tab / Hide Tab | hidden when `Never Show Team Tabs` is on; Show disabled at 16 visible tabs | toggles `showTab`, refreshes tabs. Disabled tooltip gives current/maximum tab count. |
| Cancel | always | close. |

## Teams dropdown (`TeamsButtonMenu`)

Invocation: the `Teams` dropdown at the top of Teams panel. It has no title.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Create New Group | always | Opens group editor. |
| Team Herder | always | Opens bulk moving dialog: choose destination group, then click rows to move them. |
| Import Teams | always | Opens import dialog. |
| Backup All Teams | always | Opens all-team export/backup dialog. |
| Help | hidden if extra menu help is disabled | Stay-open help tooltip about groups, tabs and drag/drop. |
| Okay | always | close. |

## Pet menu (`PetMenu`)

Invocation: right-click a pet list row/eligible pet control. Title is formatted pet name. “Owned” means an actual owned GUID, not species/placeholder/link; “obtainable” refers to the Pet Journal entity.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Summon / Dismiss | only owned actual pet | Dynamic label; calls companion toggle. |
| Set Notes | always (valid subject) | Opens and focuses species-shared NotesCard. |
| Pet Tags ▸ | only obtainable | Opens marker menu (called Pet Tags in UI). |
| Find Similar | only obtainable | Applies similar-species filter and refreshes Pets. |
| Find Moveset | only obtainable | Applies exact moveset filter and refreshes Pets. |
| Find Teams | always; disabled if team count is zero | Opens Teams view searching the owned pet ID. |
| Rename | only owned actual pet | Opens Blizzard-name-compatible rename dialog. |
| Set Favorite / Remove Favorite | only owned actual pet | Toggles Blizzard pet favourite, refreshes filters/UI. |
| Hide Pet / Show Pet | only if hidden-pet operation is allowed | Toggles species-wide `HiddenPets`; hiding prompts unless confirmation suppression is enabled. |
| Release | only owned and Blizzard says releasable; disabled if slotted | Opens release confirmation. Disabled tooltip: slotted pets cannot be released. |
| Cage | only owned tradable pet; disabled if injured or slotted | Cages directly only with confirmation suppression and no team use; otherwise confirmation. Disabled reason identifies injury/slotted state. |
| Start Leveling | only level-capable and not already queued | Inserts at top of leveling queue, processes and highlights it. |
| Add to Leveling Queue / Remove from Leveling Queue | level-capable | Toggle membership, process queue and highlight. |
| Cancel | always | close. |

The two spacer rows surrounding queue operations hide with operations when pet cannot level.

### Pet Tags marker submenu (`SetPetMarker`)

| Label | Shown / enabled when | Effect |
|---|---|---|
| 8 named marker rows | always | Radio-select marker index 8 down to 1 for species. Each has standard raid-target icon and hover-only gear side action to rename its global marker label. |
| None | always | Radio-selected when no marker; clears marker. |
| Help | hidden when extra menu help disabled | Stay-open help about marker naming/filtering. |
| Cancel | always | close. |

The edit side action appears for each numbered marker. It opens Rename Pet Marker dialog with that marker index. Marker values are species-level and therefore apply to every owned copy.

## Queue dropdown (`QueueMenu`)

Invocation: `Queue` dropdown at top of [queue](queue.md). It has no title.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Sort by: | always, highlighted non-action heading | category label. |
| Ascending Level | radio marking active sort | sets primary ascending sort; one-time sort when inactive, continuous sorting when active. |
| Median Level | radio marking active sort | sets median-level ordering. |
| Descending Level | radio marking active sort | sets descending-level ordering. |
| In Teams First | checkbox only while Active Sort is on | toggle team-membership priority; when inactive, performs a one-time corresponding sort. |
| Favorites First | checkbox only while Active Sort is on | toggle favourite priority / one-time sort. |
| Rares First | checkbox only while Active Sort is on | toggle rarity priority / one-time sort. |
| Active Sort | always checkbox | toggles continual reordering using selected criteria and processes queue. |
| Pause Preferences | always checkbox | toggles all default/team/group queue preferences; normal queue top candidate selection resumes when paused. |
| Fill Queue | always | Adds eligible filtered pet-list candidates; confirms unless suppression setting. |
| Fill Queue More | only `Show Fill Queue More` option | broader fill that permits duplicates/max-level overlap conditions normally skipped. |
| Empty Queue | disabled if empty | asks then clears all entries and processes. |
| Export Queue | disabled if empty | opens clipboard export dialog. |
| Import Queue | always | opens paste/import validation dialog. |
| Help | hidden if extra menu help disabled | stay-open explanation of queue-controlled slots. |
| Okay | always | close. |

The sort radios technically appear as radios only while `QueueActiveSort` is true; when inactive the current sort is applied once, so their checked values still identify configured order but no active radio widget is drawn.

## Queue row menu (`QueueListMenu`)

Invocation: right-click a queue pet. Title is formatted pet name.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Move To Top Of Queue | always | moves queue entry to index 1 and highlights it. |
| Move Pet In Queue | always | picks it up for drag repositioning. |
| Move To End Of Queue | always | moves entry to end and highlights it. |
| Summon / Dismiss | always for a queue owned pet | companion toggle. |
| Set Notes | always | open/focus notes. |
| Find Teams | disabled at zero team count | open Teams search. |
| Rename | always valid queue pet | rename dialog. |
| Set/Remove Favorite | always | toggle favourite. |
| Release | only releasable; disabled if slotted | confirmation/release. |
| Cage | only tradable; disabled injured/slotted | confirmation/cage. |
| Remove from Leveling Queue | always | removes directly if suppression setting, otherwise confirmation. |
| Cancel | always | close. |

If manual moving conflicts with Active Sort, the drag process can prompt to disable Active Sort before placing the entry.

## Loadout menu (`LoadoutMenu`) and special menu

Invocation: right-click an editable owned pet/slot in [loadout](loadout.md). `LoadoutMenu` title is slot label when invoked from slot background, pet name from pet-icon use where applicable. `SpecialMenu` is invoked by special badge and contains only special controls.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Put Leveling Pet Here | slot is not currently leveling | marks slot’s special value 0, processes queue. |
| Stop Leveling This Slot | slot is currently leveling | clears special slot marking; highlighted while state is selected. |
| Put Random Pet Here ▸ | slot is not currently random | opens random family submenu. |
| Stop Randomizing This Slot | slot is currently random | clears random marking. |
| Ignore This Slot | slot is not ignored | writes ignored special value. |
| Stop Ignoring This Slot | slot is ignored | clears ignored marking. |
| Summon / Dismiss | `LoadoutMenu` only | toggles actual slot pet companion. |
| Set Notes | `LoadoutMenu` only | opens pet notes. |
| Find Similar | `LoadoutMenu` only | opens Pets with similar-species filter. |
| Find Teams | `LoadoutMenu` only; disabled at zero team count | opens Teams pet search. |
| Rename | `LoadoutMenu` only | opens pet rename dialog. |
| Set/Remove Favorite | `LoadoutMenu` only | toggles favourite. |
| Cancel | always | close. |

Special controls mutually hide their “put” choice once enabled and show “stop” choice instead. Random submenu (`SpecialSubMenu`) lists `Any Type` plus every Blizzard pet family, each with family icon. Choosing one excludes the two other physical loaded pets while selecting an eligible high-level candidate, stores `random:0…10`, then processes queue/UI.

## Ability menu (`AbilityMenu`)

Invocation: right-click any valid ability in pet card/loadout/mini loadout. It is a concrete two-row menu.

| Label | Shown / enabled when | Effect |
|---|---|---|
| ability name (title) | always valid ability | title/non-action. |
| Find Pets With This Ability | always | opens Pets and exact-searches ability name. |

## Target menu (`TargetMenu`)

Invocation: right-click a target list row. Title is target’s readable name.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Edit Target | always | opens picker/order dialog for teams assigned to target. |
| Load Random Pets | always | chooses target as loaded/recent, builds random counter team and loads it. |
| Load Team ▸ | only if target has saved team(s) | click loads preferred selected team; hover submenu lists all target teams. |
| Edit Team ▸ | only if target has saved team(s) | click opens preferred selected team editor; hover submenu lists all. |
| Cancel | always | close. |

`TargetLoadTeamMenu` and `TargetEditTeamMenu` rebuild from ordered target team IDs before opening. Both title themselves `Teams`, list formatted names, append Cancel, and use first/preferred team when parent row itself is clicked. Missing list uses `No teams :(` fallback.

## Minimap favourites menu (`MinimapFavorites`)

This is a concrete but optional menu that does not belong to filter/menu panels. Invocation: right-click enabled Rematch minimap button.

| Label | Shown / enabled when | Effect |
|---|---|---|
| Favorite Teams (title) | always | title. |
| Favourite team names | one per current favourite team | loads selected team. |
| No favorite teams :( | if favourite group empty | non-action informational row. |

It opens explicit top-right of minimap button to button bottom-left `(8,8)`.

## Conditions shared across concrete menus

- A pet is caged only if actual owned, tradable, uninjured, and unslotted; it is released only if actual owned, Blizzard permits release, and unslotted.
- A pet-only action normally hides for species-only/unowned/link/special data. Find filters act on obtainable species; actual Team searches expect an owned GUID in base menu implementations.
- Target-specific actions hide if no target associations rather than showing disabled rows.
- User-team-only editing actions hide in loaded transient team menu; team row menu is only instantiated for persisted user team rows.
- System groups remain represented in menu but delete is disabled.
- Menu tooltip policy respects global normal tooltip configuration; Help rows additionally obey `Hide Extra Help`.

## Fork changes

`menus/menus.lua` changes only WoW 12.1 pointer tests from the global `MouseIsOver(frame)` to `frame:IsMouseOver()` for:

1. deciding if root origin / side-action area prevents timer-close;
2. deciding whether a leaving submenu row should hide its child;
3. deciding whether side-actions should hide on leave.

No menu labels, order, geometry, check state, permissions, or effects differ. Preserve the timer-close and hover-continuity behaviour described above.

## States / lockouts

| State | Behaviour |
|---|---|
| Disabled row | grey/desaturated text/icon/check, does not press or call action, may describe reason in red tooltip. |
| Hidden row | consumes no height and no width. |
| Root origin still hovered | menu remains open across pointer gap / menu transitions. |
| Pet Journal active | Escape does not close custom menu, allowing host journal handling. |
| Combat/journal lock | Context menus may still appear, but underlying loadout mutation actions are unavailable because caller/menu creation is gated. |
| Empty menu source | Dynamic menus use informational `No … :(` row rather than producing a malformed submenu. |

## Open questions / gaps

- The generic menu system allows external addons to register/add entries dynamically. This specification covers all built-in menus shipped in the cited sources, not third-party augmentations.
- Dropdowns generated from generic UI controls (such as option combo boxes) reuse this engine but are not named concrete Rematch action menus and are documented with their owning surfaces.

## BattleBuddy script actions and acceptance

Add Create/Edit Script to the team and loaded-team menus, routed to the existing Save Team dialog's Script tab for the selected team. Script export stays with the integrated sharing/editor workflow; do not launch a separate PBS UI. The local MIT PBS `Rematch/UI.lua` supplies the factual precedent for these entry points, not the requested dialog destination.

Acceptance: exercise hover/submenu transitions, checked/disabled entries, close/Escape, no-data menus, and combat lockouts. A menu opening or hover cannot dispatch its action. Verify script actions target the right team after list sorting; destructive entries retain their confirmation and cancel behavior. Do not expose menu actions for unshipped Phase A features.
