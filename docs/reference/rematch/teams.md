# Teams panel
Sources: `panels/teamsPanel.lua`, `panels/teamsPanel.xml`, `templates/teamListButton.lua`, `templates/teamListButton.xml`, `savedvars/savedGroups.lua`, `savedvars/savedTeams.lua`, `chrome/teamTabs.lua`, `chrome/teamTabs.xml`, `chrome/chromeMixins.lua`, `process/winrecord.lua`, `process/dragFrame.lua`, `process/badges.lua`, `menus/teamMenu.lua`, `templates/autoScrollBox.lua`, `templates/templates.xml` · Fork changes: none affecting this surface · Screenshots: `rematch-journal-teams.png`

## Purpose
The Teams panel is the right journal column: a collapsible, grouped list of saved three-pet teams. It supplies browsing, loading, searching, manual organization, group bookmarks, and a compact presentation mode. Team editing, sharing, and group commands are launched from the context menus documented in [menus](menus.md); the dialogs they open are specified in [save team dialog](save-team-dialog.md).

## Frame tree
- `RematchWindow > TeamsPanel`
  - `TeamsTopBar`
    - `ExpandAllButton`
    - `TeamSearchBox`
    - `TeamsMenuButton`
  - `TeamScrollList`
    - `GroupHeaderRow[*]`
    - `TeamRow[*]`
    - `EmptyGroupRow[*]`
    - capture area below the final row
- `RematchWindow > GroupBookmarkTabs` (separate right-edge child)
  - `GroupBookmarkTab[1..16]`
  - optional `NewGroupTab`
  - `DropGlow`

## Panel layout
The journal screenshot has a 330 px-wide right column. The generic normal list design is 246 px wide (306 px in standalone single-panel mode); the journal host stretches the rows to its column.

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---|---|
| Teams panel | window | fills its assigned panel area | variable | no intrinsic border; top inset and list are its children |
| top bar | Teams panel | `TOPLEFT` / `TOPRIGHT`, 0, 0 | stretch × 29 | dark inset frame |
| expand-all button | top bar | `TOPLEFT`, 3, -3 | 64×24 | text `All`; graphic carries the plus/minus state |
| search box | top bar | left to expand-all right at -1; right to menu left at +1 | stretch × 24 | magnifier at x=6; text inset left 24/right 19 |
| Teams menu button | top bar | `TOPRIGHT`, -3, -3 | 80×24 | label `Teams`; arrow at its right |
| scroll list | Teams panel | top to bar bottom, 0, -2; `BOTTOMRIGHT` | stretch | vertical ScrollBox; scrolling closes a menu |
| group row | scroll list | flow layout | stretch × 26 | header background and x=0 expand icon |
| normal team row | scroll list | flow layout | stretch × 44 | rich two-line presentation |
| compact team row | scroll list | flow layout | stretch × 26 | one-line alternative |
| empty row | scroll list | flow layout | stretch × 26 | only inside an expanded empty group |

## Top bar

### All / collapse control
`All` is an expand/collapse-all toggle, not a filter. If at least one group is open, activation collapses every group. If every group is closed, activation expands every group in group-order sequence. It is disabled while a search or a group/team drag locks headers. Its 64×24 own-art strip has normal and pressed plus variants for collapsed state, normal and pressed minus variants for expanded state, and a desaturated disabled variant. The text sits 7 px right of horizontal center and drops 2 px while pressed.

### Team search
Placeholder text is `Search Teams`. Search is immediate and case-insensitive, literal-substring matching with locale-friendly accent handling where available. It searches:

1. group display name;
2. team name;
3. each team's pet custom name and species name (including resolving an invalid/caged saved pet through its saved species tag);
4. names of targets attached to a team.

A complete owned-pet GUID is a special exact search: match only teams containing that exact pet. The typed GUID is grey (`#808080`); ordinary text is white. A nonempty search makes the list show only matching groups/teams; a matching group includes all of its teams, and a matching team retains its header. It collapses stored group expansion state for the search without permanently changing it. Group expansion glyphs become desaturated blank squares and cannot be toggled during search. Clearing restores the prior stored expansion state.

### Teams button
Opens the Teams command menu. This specification only names its entry points; use [menus](menus.md) for the complete menu implementation:

| Entry | Effect |
|---|---|
| `Create New Group` | opens the group editor |
| `Team Herder` | opens batch move mode, then clicking team rows sends them to the chosen group |
| `Import Teams` | opens the import dialog |
| `Backup All Teams` | opens full export |
| `Help` | optional explanatory menu item; hidden by the global Hide Extra Help setting |

## Group rows

| Sub-element | Position / styling | Behavior |
|---|---|---|
| header background | entire 26 px row | own art `textures/headers`; use the normal header segment outside standalone mode and the wide segment in standalone mode |
| expand glyph | left 26×26 | plus when closed, minus when open, desaturated empty square while search/drag lock applies |
| group name | `TOPLEFT` 27,-2 to `BOTTOMRIGHT` -4,2 | `GameFontNormal`; gold `#FFD200` unless group colour overrides it; single-line truncation |
| preference badge | immediately left of icon | 14×14 blue/utility badge when group has leveling preferences and badges are enabled |
| group icon | right, -4,0 | 18×18, 7.5% inset crop; circular portrait mask and thin gold border; absent if group has no icon |

A hover highlights the header and glyph; press removes it until mouse-up. Left click toggles expansion and plays the header-click sound. Right click invokes the group menu at the cursor. Dragging starts a group drag when team dragging is enabled. Headers cannot be moved to or combined with themselves.

A group with no teams shows one muted `GameFontNormal` (`#808080`) 26 px row: `No favorite teams`, `No ungrouped teams`, or `No teams in this group` as applicable.

### System groups
The first two ordered meta groups always exist and cannot be deleted or directly written as ordinary user groups:

| Group | icon | semantics |
|---|---|---|
| `Favorite Teams` | `Interface\Icons\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2` | first in the group order; a favourite team lives here temporarily and preserves its non-favourite home group |
| `Ungrouped Teams` | `Interface\Icons\INV_Pet_BattlePetTraining` | second in group order; teams with no valid user group land here |

Favorites move back to their remembered home group when unfavourited; if none is available, they return to Ungrouped. Both meta groups may be emptied but are never deleted. They use the normal group header and support expansion, but deletion is disabled in their context menu.

### User group model and sort modes
A user group has a persistent opaque identifier, required display name (duplicates permitted), optional icon, optional six-digit RGB text colour, ordered team identifiers, optional preferences, expanded-state flag, sort mode, and optional bookmark-tab flag. The group order is a separate ordered list.

| Sort | result | tie-breaking |
|---|---|---|
| `By Name` | favourites first, then case-insensitive name ascending | team identifier |
| `By Wins` | favourites first, then wins descending when alternate win display is on; otherwise win percentage descending | name, then identifier |
| `Custom Sort` | exact saved team order | new arrivals append |

Dropping a team before/after another team converts Name or Wins sorting to Custom Sort. Up to 16 selected groups can have bookmark tabs; excess selections are cleared. A group colour tints its header and, when `Color Team Names By Group` is enabled, its team names.

## Team row layout

### Normal 44 px row

| Sub-element | Anchor / size | Styling and state |
|---|---|---|
| body background | x=91, y=-1 to row bottom/right | own art `textures/listbuttondark`; hover highlight; loaded selection gold `#FFD200` on the body only |
| pets | x=2, 31, 60; y=-2 | three 28×40 portrait crops, 20.3125–79.6875% horizontal and 7.8125–92.1875% vertical crop; always occupies 90×44 border block |
| pet border | left edge, 90×44 | own art `textures/teamborders`, 3-pet normal region `0, .3515625, 0, .171875`; invalid/species placeholder pet is desaturated |
| favourite star | `TOPLEFT`, -5,3 | 21×21 `PetJournal-FavoritesIcon`; visible only for favourites |
| name | `TOPLEFT`, 97,-4 to right reserve | `GameFontNormal`, left aligned; vertically centered with subtitle when present; wraps only if room permits |
| subtitle | 1 px below name | `GameFontNormalSmall`; first saved target's NPC name; hidden if it repeats team name, is still resolving, or cannot fit |
| wins | `BOTTOMRIGHT`, -3,6 | `GameFontHighlightSmall`; see record rules below |
| notes icon | `TOPRIGHT`, -3,-5 | own art `textures/badges-borders`, 20×20; only when team notes exist and notes badges are not hidden |
| target badge | follows notes / other badges leftward | 14×14 own-art badge if team has any saved targets |
| preferences badge | follows target badge leftward | 14×14 own-art badge if team has preferences |

The name reserves space independently for the top-right notes/badges and bottom-right win display, using whichever leaves less room. A truncation tooltip appears unless truncated tooltips are disabled. Hovering a pet opens its pet card; clicking the pet applies the normal card click/pin behavior rather than loading the team.

### Compact 26 px row

| Sub-element | Anchor / size |
|---|---|
| three pet portraits | left x=2,25,48, each 22×22; three-pet border 72×26 |
| body | begins x=73, y=-1 |
| name | left x=76, centered vertically; one line only |
| favourite | `TOPLEFT`, -4,3, 16×16 |
| win display | `RIGHT`, -3,0 |
| notes | right-side flow before the win display, 18×18 |
| badges | right-side flow after notes, 14×14 each |

There is no target subtitle in compact mode. The compact preference is shared by this panel's option, not by target-list compactness.

### Team row interactions

| Input | Effect |
|---|---|
| left click on row | load that saved team and play the team-load sound |
| right click on row | close dialog if one is open, then open Team menu at cursor; see [menus](menus.md) |
| left drag | pick up team for movement when `Enable Drag To Move Teams` is on |
| hover row | own-art body highlight; full-name tooltip when truncated |
| hover/click pet portrait | display / operate the pet card |
| click during Team Herder | move team into currently selected herder group instead of loading it |
| click while a dragged team/group is held | receive an eligible drop rather than performing normal click |

Team rows must not be draggable when their list button marks them `noPickup` (e.g. an embedded dialog row). A group/team cursor also clears if the user right-clicks to cancel it.

## Drag and drop

### Teams
Dragging a team onto a group moves it to that group, updates its saved home/favourite state where needed, and flashes the destination. Dropping before/after a team changes order within the source group; ordering by placement changes that group to Custom Sort. The list collapses all unrelated groups during a team drag, locks headers, and clears search first if active. A moving-row tint is black at 65% opacity. The capture space after the final row accepts the appropriate end insertion.

### Groups
Dragging a group before/after another group changes global group order. A configured modifier (`None` by default, or Alt/Shift/Ctrl) changes a group-on-group drop into a **combine**: all teams move to the destination; the source user group is deleted unless `Don't Delete Empty Group` is checked. Favorite and Ungrouped groups are never deleted—combine only empties them. A confirmation offers `Don't Delete Empty Group`; its checkbox is forced and disabled for the two system groups.

`Click To Drag` changes drag-start behavior from immediate mouse drag to click pickup. `Enable Drag To Move Teams` disables new pickups entirely. `Echo Team Drag` prints the resulting move destination to chat.

## Team menu and group menu
The detailed hierarchy belongs in [menus](menus.md). Required entry points for the implementation are:

| Context | actions |
|---|---|
| group row | create/edit/move/delete/export group, import teams into it, delete all teams in it, show/hide bookmark tab, cancel |
| team row | unload (when loaded), edit, notes, move, favourite toggle, load/edit saved target submenu, share submenu, delete, cancel |
| share submenu | plain text export, encoded export, send team (unless sharing disabled), cancel |

Group delete offers an `Also delete teams in this group` checkbox; otherwise surviving teams move to Ungrouped. Deleting all teams is separately confirmed. Team delete can be configured not to ask again.

## Team tabs / group bookmarks
Bookmark tabs are a vertical 36×44 hit target along the window's right edge, positioned at x=-1 relative to the outer right edge; individual tabs are spaced 44 px. Their 44×44 own-art background (`textures/teamtab`) extends beyond the nominal 36 px hit width. Group icon is a circular-masked 30×30 at 2,-5. At 11 or fewer selected groups, tabs are full scale starting 64 px below window top; 12 shifts upward to -24; 13–15 shrink (90%, 85%, 80%).

Hover highlights the icon/background and shows group name plus count. Left-click enters Teams view when necessary, then toggles the group if it is already visible and open; otherwise it opens it, scrolls/flashes it, and clears an active search. Right-click opens its group menu. A dragged team can be dropped onto a tab to move it into that group; a pulsing `Interface\Archeology\arch-flareeffect` 30×30 overlay marks the valid tab. A yellow-plus bookmark creates a new group when fewer than 16 bookmarks exist and `Show Create New Group Tab` is enabled.

Tabs show only when the window is not minimized, `Never Show Team Tabs` is off, and either the view is Teams or `Always Show Team Tabs` is on.

## Win record
A record stores wins, losses, draws, and total battles. Manual edits are covered in [save team dialog](save-team-dialog.md). When automatic tracking is enabled, after an eligible battle the loaded user team receives one result: player win increments wins, player loss increments losses, and mutual defeat becomes a draw; a detected player forfeit is a loss, while an opponent forfeit with both sides alive counts as a win. `For PVP Battles Only` limits automatic recording to player opponents.

The list hides the record if no battles exist or `Hide Win Record Text` is on. Otherwise display rounded win percentage by default, or `wins-losses` if `Display Total Wins Instead` is on. Percentages >=60 are green `#40BF40`, <=40 red `#FF4040`, otherwise gold `#FFD200`. The same display mode changes Wins sorting from percentage to raw wins.

## Options affecting this surface

| Option label | group | default | effect |
|---|---|---:|---|
| Compact Team List | Lists | off | switches rows 44 px/two line to 26 px/one line |
| Color Team Names By Group | Lists | on | tint names by group colour, otherwise near-white `#E8E8E8` |
| Hide Team Badges | Badges | off | suppresses target/team relationship badges where applicable |
| Hide Target Badges | Badges | off | suppresses target badge on team rows |
| Hide Preference Badges | Badges | off | suppresses team/group preference badges |
| Hide Notes Badges | Badges | off | hides notes glyphs |
| Hide Win Record Text | Miscellaneous | off | hides win label |
| Auto Track Win Record | Miscellaneous | off | records outcomes automatically |
| For PVP Battles Only | suboption | off | limits auto tracking |
| Display Total Wins Instead | Miscellaneous | off | displays W-L and changes win sort basis |
| Show Create New Group Tab | Teams | off | appends yellow plus bookmark when capacity permits |
| Always Show Team Tabs | Teams | off | shows bookmark tabs outside Teams view |
| Never Show Team Tabs | Teams | off | hides bookmark tabs and Show/Hide Tab menu action |
| Enable Drag To Move Teams | Teams | on | enables team and group pickup |
| Require Click To Drag | Teams | off | requires click pickup instead of immediate drag |
| Group Combine Key | Teams | None | Alt/Shift/Ctrl turns a group drop into combine |
| Display Where Teams Dragged | Teams | off | emits drag-move feedback |
| Hide Truncated Tooltips | Tooltips | off | suppresses name tooltip |
| Hide Extra Help | Menus | off | suppresses help entries/empty explanatory text |

## States and lockouts
- **No groups/teams:** validation always restores Favorite Teams and Ungrouped Teams; both can show their dedicated empty rows.
- **Collapsed group:** only its header is visible; expansion table persists by group identifier.
- **Searching:** only result headers/rows; header actions and All button are disabled.
- **Dragging:** search clears, headers lock, source becomes dark moving tint, destination gets a glow line/area; switching away from Teams cancels drop cursor.
- **Loaded team:** gold selection applied to the row body; this is visual only and does not prevent context operations.
- **Invalid/caged/species pet:** portrait is desaturated; display resolves from saved tag where possible.
- **In combat / pet battle:** this panel itself remains inspectable, but loading or swaps follow global WoW lockout handling. Do not falsely mark a team loaded until the load process succeeds.

## Fonts, colours, and textures

| Use | specification |
|---|---|
| labels/names | `GameFontNormal` |
| subtitles / win text | `GameFontNormalSmall` / `GameFontHighlightSmall` |
| muted empty text | `#808080` |
| gold UI/accent | `#FFD200` |
| loaded selection | `#FFD200` |
| own art | `textures/allbutton`, `textures/headers`, `textures/listbuttondark`, `textures/teamborders`, `textures/badges-borderless`, `textures/badges-borders`, `textures/teamtab` — redraw or substitute; do not copy |
| Blizzard art | `Interface\Common\UI-Searchbox-Icon`, `Interface\ChatFrame\ChatFrameExpandArrow`, `PetJournal-FavoritesIcon`, `Interface\Archeology\arch-flareeffect`, circular masks `Interface\CharacterFrame\TempPortraitAlphaMask` / `Interface\Common\common-iconmask` |

## Source vs screenshot
- Screenshot is the journal-hosted three-column layout and wins over generic standalone dimensions. The Teams list is visibly a ~330 px right column; generic list row values above define internals, not the host panel width.
- Screenshot shows all listed groups expanded/collapsed glyphs, the name `Breeeeeds` colour, group icons at right, and 44 px team rows. It visually confirms Team row pet block at left and action/badge cluster at right.
- The screenshot top control displays a red minus graphic with `All`, confirming it represents collapse-all while groups are expanded.

## Open questions / gaps
- Source exposes group colour picker entries but not an explicit exact colour for the uncoloured header beyond gold fallback; use `#FFD200`.
- The screenshot's individual right-side team glyph shapes include user-selected target/preferences/notes state; source establishes their conditions and sprites but not a stable fixed order beyond notes then registered badges.

## BattleBuddy PBS integration and acceptance

Keep the reference row layout; provide a script-presence badge/action in its existing action area. Clicking it opens that team's [Save Team Script tab](save-team-dialog.md), without loading the team. Teams with no script expose creation through their context menu. The local MIT PBS `Rematch/UI.lua` demonstrates row badges and create/edit menu entry points; BattleBuddy routes both into its own dialog rather than the standalone PBS editor.

Acceptance: normal/compact rows, group collapse/search/drag, favorites, and empty groups retain the described behavior. Script presence follows committed team state through rename, move, duplication and deletion; editing a nonloaded row cannot change the active battle script. Repainting or filtering the list must never load a team. Phase A options follow [options](options.md).
