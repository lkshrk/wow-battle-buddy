# Save team dialog and shared dialogs
Sources: `dialogs/dialog.xml`, `dialogs/dialog.lua`, `dialogs/dialogMixins.lua`, `dialogs/saveDialog.lua`, `dialogs/importDialog.lua`, `dialogs/summaryDialog.lua`, `process/send.lua`, `cards/notes.lua`, `menus/teamMenu.lua`, `menus/queueMenu.lua`, `process/dragFrame.lua`, `process/teamStrings.lua`, `templates/templates.xml`, `templates/dropdown.xml` · Fork changes: `cards/notes.lua` only changes a mouse-over API call; no visible change · Screenshots: `rematch-save-team-dialog.png`

## Purpose
The reusable dialog host provides the metal-framed modal shell. Its largest team-specific use is Save Team: an editable working copy of the three current pets, targets, queue preferences, and win record. Every changing control updates the working copy; Cancel discards it, Reset restores the opening copy, and Save commits subject to collision handling.

## Generic dialog frame

### Frame tree
- `DialogHost` (top-level, `DIALOG` strata, screen-clamped, movable)
  - metal title frame
    - title text
    - Close / Escape receiver
    - optional minimize/maximize titlebar button
  - marble inset canvas
    - one vertical layout of currently active controls
  - optional prompt bar
  - bottom `Other`, `Accept`, `Cancel` buttons

### Shell geometry

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---|---|
| Dialog host | `UIParent` | center | initial 300×200 | fully recalculated from canvas width/height; top level and movable |
| canvas | host | `TOPLEFT` 9,-30; `BOTTOMRIGHT` -11,61 | calculated | 9 px left, 11 px right, 30 px top, 32 px base bottom margin |
| prompt | host | bottom left 4,55 to right -6,55 | stretch × 2 baseline | adds 29 px to dialog height; prompt text begins 4,-8 |
| Other button | host | `BOTTOMLEFT`, 4,3 | one-third canvas+10 × 23 | e.g. Reset, Load, Overwrite, More; hidden when not supplied |
| Accept button | host | between Other and Cancel | same | e.g. Save, Yes, Send, Import |
| Cancel button | host | `BOTTOMRIGHT`, -6,3 | same | Cancel/No; hidden only in acknowledgement dialogs |
| close titlebar button | host | `TOPRIGHT`, -1,-1 | 22×22 | Escape invokes Cancel, not an unconditional hide |
| optional min/max button | host | immediately left of close | 22×22 | used by collection summary dialogs |

Canvas content is placed top-down with 6 px outer padding and 6 px between controls. Width is normally declared canvas width plus 20 px shell margins; the default canvas is 280×100, minimum 120×16. Dialogs resize to the active layout's control heights, declared minimum height, and optional prompt. Any open menu is hidden before showing a dialog. Dialog open/close play the corresponding UI sound.

### Generic visual materials

| Part | art | Notes |
|---|---|---|
| outer metal rim | Blizzard `UI-Frame-Metal-*` corner/edge atlases | rock background inside |
| inner field | `Interface\FrameGeneral\UI-Background-Marble` | tiled; bordered by Blizzard inner-frame regions |
| generic action buttons | `Interface\Buttons\UI-Panel-Button-Down` | 23 px high, three-piece stretchable button |
| titlebar buttons | own art `textures/titlebarbuttons` — redraw or substitute | 22×22; close/minimize glyph selection |
| text inputs | own art `textures/controls` — redraw or substitute | three-piece 24 px control with clear X |
| optional warning | Blizzard `Interface\DialogFrame\UI-Dialog-Icon-AlertNew` | 32×32 beside orange `#FF8040` text |

`GameFontNormal` is the default label/body face; `GameFontHighlight` and `GameFontHighlightSmall` serve secondary/compact text. Gold is `#FFD200`, normal white `#FFFFFF`, muted disabled grey `#808080`.

### Shared control behavior

| Control | visual / interaction |
|---|---|
| layout tabs | 24 px stretch tabs, up to four, along canvas top; selected tab has pressed metallic look; tabs with non-default content get a blue `HasStuff` highlight; a clear X at top-right clears the current content-bearing tab, or all content-bearing tabs when current tab has none |
| one-line edit | labeled 24 px control; clear X appears for nonempty text; Enter accepts if enabled; Escape cancels |
| combo box | labeled editable one-line input with dropdown arrow; accepts typing and selection |
| group selector | `Group:` label plus a 26 px header-style clickable row with name, optional preference badge, circular 18 px icon |
| multiline edit | inset frame with scroll bar, selectable text; 166 px high by default; long export/import content scrolls; progress overlay may cover it while a chunked operation works |
| feedback | alert icon plus warning/mail text; shown only when needed |
| check/radio | standard Rematch check or radio visual, click changes dialog working state |
| list data | two-column summary rows, normally 22 px each |
| pet/team preview | non-draggable list row or three-pet preview; pet-card hover still works where appropriate |

Close, Cancel, and Escape discard in-progress dialog state unless a dialog has a supplied cancel callback (notably aborting send). Changing a control calls the current dialog's change handler after the initial refresh frame, allowing dynamic validation, layout change, tab highlights, and action enablement.

## Save Team

### Frame tree
- `DialogHost > SaveTeamCanvas` (290 px requested canvas width)
  - `SaveTabs`: Team, Targets, Preferences, Wins
    - clear-content X
  - **Team tab**
    - receive-status line (only for incoming team)
    - `Name` combo box
    - `Group` selector
    - spacing
    - `ThreePetAbilityPreview`
    - collision feedback
  - **Targets tab**
    - `TargetPicker`
  - **Preferences tab**
    - heading, divider, `PreferenceEditor`, help
  - **Wins tab**
    - heading, divider, `WinRecordEditor`
  - global bottom controls: Reset, Save, Cancel

### Default Team tab layout

| Element | Parent | Anchor / size | Notes |
|---|---|---|---|
| dialog | UIParent | centered | screenshot outer dimensions approximately 366×354 including frame; source canvas 290 px wide with 264 px minimum content height |
| tabs | canvas | flow first | 26 px high; screenshot names `Team`, `Targets`, `Preferences`, `Wins`; Team selected initially |
| clear X | tab row | `TOPRIGHT`, 0,-2 | 18×18; hidden unless at least one auxiliary tab has content |
| Name label + combo | canvas | flow; 24 px high, 250 px control width | label `Name:` followed by typed value; clear X inside input and dropdown arrow at right |
| Group selector | canvas | next flow, 28 px high, 250 px width | label `Group:`; clicking moves to group picker and returns with selection |
| preview | canvas | next flow, 250×76 | three identical 76×76 slots aligned left / center / right |
| preview pet | preview slot | left portion 44×44 | selected pet portrait with quality border, favourite star and level bubble if relevant |
| preview abilities | right side | 26×76 | three vertically stacked 22-ish ability icons: top, middle, bottom; shown actual chosen ability choices |
| Reset | bottom left | 23 px high | disabled until working copy differs from opening snapshot; does not close dialog |
| Save | bottom center | 23 px high | disabled when trimmed name is empty |
| Cancel | bottom right | 23 px high | discards working copy |

Screenshot evidence: the title is `Save Team` centered in the metal bar; close X is red at its top right. The preview begins low in a large black/marble field, with three 44 px portraits and their three-choice bars. Name and Group labels are gold, controls are dark bevelled fields, and Save is red/gold emphasized.

### Team working copy and initialization
The dialog never directly changes a saved team while editing. It opens an isolated sideline copy assembled from either an existing team, current loadouts, an incoming encoded team, or the counter team. It snapshots an `original` copy once. The initial group is made valid, falling back to Ungrouped. Save-As and newly loaded current pets default to a uniquely generated `New Team`-style name; a counter team starts with the target name when one is known.

Name dropdown choices, in displayed order, are current name, saved target NPC names, target quest names, recent target names, and `New Team`, with duplicates removed. The current group colour tints the name input when group-coloured team names are enabled.

## Save Team tabs

### Targets
The tab is a 280×220 two-mode target assignment control.

**Assigned mode** has a 29 px top bar containing four 68×24 buttons: `Add`, `Delete`, `Up`, `Down`; below it is a compact 26 px target list. Selecting a row enables Delete; Up/Down enable only when it is not already at the respective boundary. The selected target has gold body selection.

`Add` swaps to **picker mode**: a 29 px bar with `All`, `Search Targets`, and `Cancel`, then a grouped target list. Selecting an offered target adds it once, selects/flashes it in Assigned mode, and returns. The picker uses the same target headers, search semantics, rows, and placeholder behaviour as [targets](targets.md). `All` expands/collapses headers. Cancel simply returns without changing the selected list.

The saved target order matters: its first target is the Team row subtitle and primary target. On Save, assigned target IDs convert to numeric NPC IDs; an empty list removes the targets field. The tab gains blue content highlight if at least one target exists; its clear X removes all assignments.

### Preferences
This tab uses a 260×131 editor. It configures **team-level** leveling preference overrides. Any used field gives the Preferences tab blue highlight; clear removes every team preference.

| Field | placement / input | stored meaning |
|---|---|---|
| Level Min / Max | first line: two numeric inputs, 40 px apart | fractional full level permitted (e.g. level plus XP fraction); preferred pet must meet min and not exceed max |
| Health Min / Max | second line | max pet health, not current health; expected incoming damage adjusts only min-health comparison |
| `Allow any` Magic or Mechanical | checkbox at x=46, y=-56 | magic/mechanical may bypass lower level/min-health thresholds |
| Expected Damage Taken | label above a 259×25 strip | choose one of ten 23×23 battle-pet type icons; selected icon gets a 25×25 yellow additive outline; the other icons desaturate |

Numeric controls strip all non-digits and decimal point, show clear X when nonempty, cycle focus with Tab, and accept with Enter. Controls are gold-enabled, grey-disabled. The type strip uses Blizzard `Interface\Icons\Pet_Type_*` icons in standard type order: Humanoid, Dragonkin, Flying, Undead, Critter, Magic, Elemental, Beast, Aquatic, Mechanical. Preference precedence outside this dialog is Default then Group then Team—later layers override individual fields—documented in [queue](queue.md).

### Wins
The 260×152 editor exposes independent non-negative integer fields `Wins`, `Losses`, and `Draws`, each with minus and plus controls. Minus disables at zero; zero is represented as blank. Fields are vertically stacked at y=-32 then 8 px gaps. Label colours: Wins green `#20FF20`, Losses red `#FF4848`, Draws gold `#FFD200`.

It derives `Total Battles` as their sum and displays `Win Rate` only when total is nonzero. Rate colour matches the team list: >=60% green `#40BF40`, <=40% red `#FF4040`, otherwise gold. Save omits the record when total is zero; otherwise it stores the counts and calculated total. The tab's clear X sets all values empty.

### Reset, Cancel, validation, and Save

| action | result |
|---|---|
| reset | restores all controls from opening snapshot and returns to Team tab; stays open |
| cancel / close / Escape | drops sideline changes |
| empty/whitespace-only name | Save disabled |
| valid unchanged name in edit mode | updates original saved team identifier |
| valid same name as the original loaded team | updates that original saved team even through non-edit save flow |
| valid new unused name | creates a fresh saved identifier |
| successful Save-As / receive / new save | loads the saved team (unless Edit mode), opens/scolls/flashes it in Teams if window is available, then processes the leveling queue |
| successful edit of loaded team | flashes loaded team/loadouts instead of reloading |

### Name collisions and overwrite confirmation
Names are case-insensitive and must be unique among saved user teams. If the working name differs from the opening name and belongs to another team, the Save Team tab shows warning feedback and Save opens **Overwrite Team** rather than committing.

| Dialog | layout / actions | result |
|---|---|---|
| `Overwrite Team` / name collision | text, `Old <name>` three-pet ability preview, `New <name>` preview | `New Copy` normal accept generates `name (2)`, `(3)`, etc. as needed; `Overwrite` uses Other button to replace the collided team; Cancel returns to Save Team intact |
| collision while editing a third team | Overwrite deletes the collided team, then writes sideline to originally edited team | preserves the edit target identifier |
| collision from Save As / receive | Overwrite replaces collided team and treats it as result | resulting team is loaded/flashed |
| `Saving Loaded Team` | old/new ability previews, Yes/No | appears when direct save sees changed pets; Yes replaces currently loaded saved team |

Automatic unique-name generation removes a terminal ` (number)` before selecting the next number. Group names, by contrast, may duplicate.

## Other dialog specifications

### Import Teams
Canvas width 290 px, minimum height 232. Initial view: paste instruction, 166 px multiline editor, optional `Prioritize Breed For Imports` check, Group selector; bottom controls `Load`, `Save`, `Cancel`. The optional breed check is visible only if a breed provider exists. The group selector sends the parser output to the selected group where applicable.

As input changes, parse/validate live and choose one layout:

| parsed input | visual consequence | action availability |
|---|---|---|
| empty | plain initial layout | Save disabled |
| invalid only | orange warning | Save disabled |
| one team | 3-pet preview and group selector | Save imports; Load uses it once without persistence |
| one team with conflict | warning plus Create copy / Overwrite existing radios | Save enabled |
| multiple teams | count summary and group selector | Save enabled |
| multi-team conflicts | count summary, warning, conflict radios | Save enabled |
| groups (with or without conflicts) | counts groups/teams and optional conflict radios; no target group selector | Save enabled |

`Prioritize Breed For Imports` is retained as a setting. The collision radio defaults to Create copy unless the user elected to remember overwrite behavior. Import/Load must retain parser safety checks, refuse malformed payloads, and not paste original addon grammar in this spec.

### Export team / export multiple teams
Both show an acknowledgement `Okay` action, a short copy instruction, a 166 px selected multiline output, and 44 px include controls. `Include preferences` and `Include notes` persist their checkbox settings and regenerate the encoded export immediately. Single-team Share can choose a plain-text team view or encoded export; group export includes one group, and backup exports all teams. Do not reproduce the encoded protocol here; see [data model](data-model.md) when available.

### Send dialog
`Send Team` shows the formatted team name, spacing, 3-pet/ability preview, Include Preferences/Notes checks, an instruction line, and a `Send To:` one-line input. `Send` stays disabled until trimmed recipient text is nonempty; once pressed, dialog remains visible and swaps feedback to sending status until completed/failed. Recipient lookup first accepts an online Battle.net game account, otherwise uses a character whisper. Cancel stops an in-flight send. `Receive Team` identifies sender, shows incoming team preview, group selector, optional breed preference, and Save/Load/Cancel; a name collision adds warning and copy/overwrite radios.

A legacy placeholder `Sending Team` acknowledgement exists in the save-dialog source but the functional Send Team flow above is the required surface.

### Collection summary dialog
`Pet Collection` has a minimizable/maximizable titlebar and `Okay` action. Compact version defaults to Summary, Pet Types, Sources, and Battles tabs; expanded version has Pet Types, Sources, Battles. It uses existing shared widgets: numerical pet summary, 200 px category dropdown, 250×186 chart, 250×90 battle summary, optional 268×284 top-teams list, and `Rank teams by percentage won` check. The bottom titlebar icon toggles compact vs expanded presentation while retaining selected tab where possible. Chart/detail construction is owned by the collection surface, not this spec.

### Group editor
Opened by group menu or New Group tab; source canvas minimum is 230 px. Its three tabs are `Group`, `Icon`, `Preferences`:

| tab | controls | save result |
|---|---|---|
| Group | Group Name input; colour swatch grid; `Sort:` dropdown (By Name, By Wins, Custom Sort); `Show Tab For This Group` checkbox | creates user group when none supplied, or updates it; name cannot be empty; colors are optional default plus expansion palette and white/grey/gold/blue/purple extras |
| Icon | chosen 30×30 icon, `Search Icons` 180×24 field, 253×230 scrolling seven-icon rows | saves selected icon; default Rematch icon if no choice |
| Preferences | same editor as Save Team Preferences | saves/removes group preferences |

The Favorite Teams group locks its name input. Show Tab disables when 16 bookmark tabs are already used unless this group already has one. Saving re-sorts when sort mode changes, brings Teams view forward if necessary, flashes group, updates bookmark tabs and loaded-team display. Group editor tabs receive blue content marks for used preferences only.

### Notes editor
A separate resizable 258×258 floating card, not the centered DialogHost. It has a 22 px titlebar lock/unlock button; `Lock Notes Position` prevents movement/resizing. The content is bordered and has a 38 px header with scroll icon left, target/pet icon right, and name centered between. A multiline text editor fills below, `GameFontHighlight` by default or user-selected notes font. Bottom controls appear while focused: Delete, Undo, Save (80×23 each). Escape either drops focus/hides according to global notes options or is suppressed by the relevant keep-notes setting. Delete opens a Yes/No confirmation with `Don't Ask When Deleting Notes`; confirmed setting suppresses future confirmation.

### Confirmations

| Dialog | actions / choices | behavior |
|---|---|---|
| Delete Team | Yes / No, team row preview, `Don't Ask When Deleting Teams` | destructive; Yes deletes team |
| Delete Group | Yes / No, optional `Also delete teams in this group` | unchecked moves teams to Ungrouped; checked adds irreversible warning and deletes all group teams |
| Delete Group Teams | Yes / No, count and irreversible warning | deletes each team in group |
| Combine Groups | Yes / No, optional `Don't Delete Empty Group` | moves all source teams; normal user group is deleted by default; meta source remains empty |
| Backup Teams | Yes / No, `Don't Remind About Backups` | offered after 50 additional teams, outside combat/battle/PvP; Yes opens full export |
| Empty Queue | Yes / No | removes all queue entries |
| Fill Queue | Yes / No / `More`, no-repeat check | adds proposed filtered pets; warning layout above 50; More repeats using relaxed inclusion |
| Active Sort Enabled | Yes / No, no-repeat check | turn off active sort then reposition dragged queued pet |
| Remove From Queue | Yes / No, no-repeat check | removes one named pet |
| Delete Notes | Yes / No, no-repeat check | deletes selected team/pet note |

## States and lockouts
- Dialog host is single-instance: opening any dialog hides the prior dialog and menus.
- A changing team/queue list closes queue-management confirmations to prevent stale indices.
- Import and export text fields are selectable; export text is regenerated rather than trusted from user edits.
- Pet swapping/loading stays subject to WoW's combat, battle, journal-lock, and PvP restrictions. Dialog Save may commit data, but it must defer/avoid reporting a load operation until permitted.
- Cancel returns from a group picker to its originating dialog tab without changing group; cancel from the dialog discards all sideline changes.

## Source vs screenshot
- Screenshot wins for exact on-screen appearance: it shows a compact 366-ish px framed Save Team dialog over the journal with a dark center, red/gold bottom buttons, 4 tabs whose active gold tab is visually connected to the content, clear X at tab-row right, and 3 vertically stacked ability buttons per pet.
- Source's requested canvas width is 290 px and generic shell margins produce the observed outer width; screenshot confirms the generated height/minimum layout rather than a fixed 200 px generic dialog.
- Screenshot shows no subtitle/incoming status line on normal Save Team; reserve that line only for receive mode.

## Open questions / gaps
- The requested brief calls the tab field “min/max HP, max XP”; source labels it Health and Level, stores max health plus fractional min/max full level. This spec uses source semantics.
- `summary dialog` potentially refers to Pet Collection rather than the battle summary widget; both are described at required granularity, but this document does not duplicate collection statistics formulas.
- The icon inventory is very large and dynamically searched; reproduce behavior/row geometry, not the original icon list.

## BattleBuddy Script tab addition and acceptance

The screenshot shows four tabs; **Script** is the requested BattleBuddy addition. Preserve Team, Targets, Preferences and Wins, the screenshot's frame, and bottom Reset/Save/Cancel controls. Add Script in the same tab style; its contents are a multiline PBS editor with validation feedback and script import/export actions. Do not open PBS's standalone manager/editor.

Team-row script access opens this dialog on Script for that row's team, including teams that are not currently loaded. Changes are staged with the team: switching tabs retains edits, Reset restores the opening working copy, Cancel/close discards them, and Save validates before committing the team/script association. A parse failure preserves the previous saved script and shows a readable error; saving or previewing never executes it. Empty script content means no attached script after an explicit Save.

Acceptance: screenshot-match the original Team tab; test tab switching, reset, cancel/escape, invalid/empty scripts, name collision, and editing an unloaded team. Verify the team-row badge and battle selection update only from committed state. The new tab's exact layout has no screenshot and needs a BattleBuddy visual review; it is not represented as observed Rematch behavior.
