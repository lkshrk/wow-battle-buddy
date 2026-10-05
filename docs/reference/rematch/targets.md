# Targets panel
Sources: `panels/targetsPanel.lua`, `panels/targetsPanel.xml`, `templates/teamListButton.lua`, `templates/teamListButton.xml`, `info/targetInfo.lua`, `info/targetData.lua`, `savedvars/savedTargets.lua`, `panels/loadedTargetPanel.lua`, `process/interact.lua`, `menus/targetMenu.lua`, `templates/autoScrollBox.lua` · Fork changes: `info/targetData.lua`, `info/targetInfo.lua`, `process/interact.lua`, `panels/loadedTargetPanel.lua` · Screenshots: `rematch-journal-teams.png`

## Purpose
The Targets panel is the journal right-column alternative to Teams: a browsable catalogue of notable pet-battle opponents plus recent targets. Selecting a target sets the loaded-target context; saved teams associated with that target can then be selected or automatically prompted/loaded on interaction. Detailed loaded-target card layout belongs in [loadout](loadout.md).

## Frame tree
- `RematchWindow > TargetsPanel`
  - `TargetsTopBar`
    - `ExpandAllButton`
    - `TargetSearchBox`
  - `TargetScrollList`
    - `TargetHeaderRow[*]`
    - `TargetRow[*]`
    - `NoRecentTargetsRow`
- `LoadedTargetContext` (separate panel; selection behavior only here)

## Layout
The generic normal list is 246 px wide (306 px in standalone single-panel layout); the journal host stretches it to the width of its right column.

| Element | Parent | Anchor | Size | Notes |
|---|---|---|---|---|
| Targets panel | window | fills its selected panel slot | variable | panel has no independent outer frame |
| top bar | Targets panel | `TOPLEFT` / `TOPRIGHT`, 0,0 | stretch ×29 | dark inset frame |
| All toggle | top bar | `TOPLEFT`, 3,-3 | 64×24 | same expandable-header control as Teams |
| search | top bar | left of All at -1; `TOPRIGHT`, -3,-3 | stretch ×24 | placeholder `Search Targets` |
| list | Targets panel | top bar bottom, 0,-2 to `BOTTOMRIGHT` | stretch | scroll box, list scrolling closes menus |
| header | list flow | full width ×26 | normal/wide header art | map, expansion, or `Recent Targets` |
| normal target row | list flow | full width ×44 | name and optional quest subtitle; target pets on right |
| compact target row | list flow | full width ×26 | one line, compact pets on right |
| no-recent row | list flow | full width ×26 | muted `No recent targets` |

## Catalogue ordering and headers
The list begins with `Recent Targets`, then a conditional empty row or up to the current history entries, followed by all notable targets in data order. The notable catalogue is grouped by target-record header ID: numeric IDs resolve to World Map names; named headers resolve through localized header names. Data order determines header order, so it is intentionally content-driven (generally recent expansion / zone ordering rather than alphabetical global search order).

In the current Akolus fork, the notable-target table has **369** records. Do not duplicate that table in BattleBuddy documentation or code from this reference; treat it as content to independently rebuild/licence appropriately. The reference record shape is:

| position | data type | purpose |
|---|---|---|
| 1 | header ID | numeric map ID or a named grouping key |
| 2 | numeric NPC ID | stable target identity / saved-target lookup key |
| 3 | numeric map ID | most specific location map |
| 4 | numeric expansion ID | expansion grouping/colour source |
| 5 | optional quest ID | resolves optional quest subtitle |
| 6–8 | one to three pet descriptors | species/level/quality/stat/ability-compatible battle-pet data |

There are companion maps for NPC redirects, display subnames, header-to-expansion mapping, and in the fork public identification aliases/hints. Records may also represent a known wild pet dynamically, or an unnotable NPC with a generic portrait fallback.

### Recent target history
Target changes add non-player NPC identity to a session history. History is deduplicated preserving latest occurrence and capped at three. It is not an enduring saved variable. Recent-target panel list insertion is immediately after its header; the empty placeholder appears only when none exists. Programmatic loaded-target selection also adds to recent history.

## Header row

| Sub-element | Anchor / size | Style / state |
|---|---|---|
| header background | whole 26 px row | own art `textures/headers`; normal or wide segment according to global layout |
| expand glyph | left 26×26 | plus closed, minus open; desaturated blank square while a search is active |
| header text | x=27,-2 to right -4,2 | `GameFontNormal`, single-line; normal target headers have no right icon/badges |

Left click toggles its expansion and plays the header click sound. Right click has no target-header context action. `All` expands every header when all are closed or collapses all when any is open. Header expansion persists by header identifier in Targets settings. During a search, result headers are retained as needed but cannot be manually expanded; clearing restores normal state.

## Target row layout
Targets reuse the shared team/target row template but deliberately invert the content order relative to a Team row: name at left, target enemy pets at right.

### Normal 44 px row

| Sub-element | anchor / size | state and content |
|---|---|---|
| dark body | left 0,-1 to right minus pet-border width | own art `textures/listbuttondark`; highlight on hover |
| name | left 4, vertically centered or top-adjusted | `GameFontNormal`; formatted by expansion colour when enabled |
| quest subtitle | 1 px below name | `GameFontNormalSmall`; only when known, different from NPC name, and fits |
| right pets | 1–3 portraits, 28×40 each | right-justified: adjacent 29 px rhythm, final portrait 2 px from right; 1/2/3 pet border widths are 32/61/90 px |
| right border | right edge | own art `textures/teamborders`, normal regions appropriate to enemy-pet count |
| teams badge | immediately left of top-right extent | 14×14 own-art badge if at least one saved team targets this NPC and team badges are visible |

Known notable targets use their 1–3 supplied enemy pet descriptors. A target with no notable battle data shows a creature display portrait instead of a pet icon when obtainable; a seen wild pet shows its species icon. Unknown/unnotable targets still occupy a one-pet portrait block visually but report known enemy count zero to selection logic. Any unused portrait textures are hidden.

### Compact 26 px row

| Sub-element | anchor / size |
|---|---|
| name | left x=4, centered vertically; one-line only |
| pets | right justified at 2 px and 23 px stride; each 22×22 |
| border | right-edge compact 1/2/3 pet regions, widths 26/49/72 |
| teams badge | right-side flow immediately left of pet border when active |

No favourite star, notes icon, or win record appears on a target row. A truncated name shows its simple tooltip unless truncated tooltips are disabled. Hovering an enemy pet opens its pet card. Clicking target-row body performs target selection; it does not load a team directly.

## Search semantics
Search is immediate, case-insensitive literal substring matching, with existing locale accent normalization where available. It matches:

1. target header/map name;
2. NPC name;
3. associated quest name;
4. each listed enemy pet's name;
5. names of saved teams associated with that target.

**Recent Targets are deliberately excluded from hit matching**. The panel leaves their header out of a text-search result rather than permit the dynamically sized recent section to shift catalogue hits. A matching header includes all targets beneath it; a matching target retains its header. The search feature collapses headers for result construction and makes glyphs inert until cleared.

## Target selection and loaded target context

| Input | effect |
|---|---|
| left click target row | resolve numeric NPC identity, set it as loaded target, set enemy-team mode, update recent target history, play team-load sound |
| right click target row | open Target context menu at cursor after hiding an open dialog |
| hover target row | dark body highlight and truncation tooltip if necessary |
| hover enemy-pet portrait | show pet card |
| click portrait | shared pet card click/pin handling; do not change target selection |

Setting the loaded target updates the loaded-target context. This context determines what enemy name/pets and associated-team state the loadout pane uses, but its visual panel composition belongs to [loadout](loadout.md). If a selected target has saved teams, the target menu can choose a specific associated team; a random counter-team action constructs and loads a temporary counter team instead.

## Which teams exist per target
A derived persistent map associates each numeric target ID with an ordered list of saved team identifiers. It is rebuilt from each team's ordered targets whenever teams change, preventing one-way stale links. The topmost associated team is the default preferred team. Editing a target's associated teams through `Edit Target` uses the shared list picker:

- Lister mode has Add / Delete / Up / Down controls and compact team rows.
- Picker mode has All / Search Teams / Cancel and grouped team browse/search.
- The list disallows duplicate team identities and preserves order.
- Save rewrites each affected team's target association while keeping target-list ordering; Cancel discards changes.

The first team can be bypassed by `Prefer Uninjured Teams`: select the first valid associated team whose three pets have no injuries; if all valid candidates are injured, fall back to the first valid candidate. A missing/deleted team is skipped. Association alone does not require a target to be in the notable catalogue: any identified NPC can receive saved teams.

### Target context actions
Detailed menus live in [menus](menus.md). Required Target menu entry points:

| item | effect |
|---|---|
| `Edit Target` | opens assigned-team picker above |
| `Load Random Pets` | selects target then builds and loads temporary random counter team |
| `Load Team` | submenu of associated teams, ordered preference first |
| `Edit Team` | submenu of associated teams, opens their Save Team edit flow |
| `Cancel` | closes menu |

## Interaction process
Interaction settings decide whether encountering a known target with saved teams prompts, opens window, or loads preferred team. Only one source is allowed at a time by priority: **mouseover > soft-interact > target**. Each uses modes None, Prompt, Window, Auto Load.

| trigger | guard | result for selected mode |
|---|---|---|
| target changes | current target resolves to NPC | Prompt opens `Prompt To Load`; Window opens Rematch if closed; Auto Load loads preferred associated team |
| mouseover changes | mouseover resolves to NPC | same modes unless current actual target already has saved teams; then defer until target path |
| soft-interact changes | soft-interact resolves to NPC | same modes with same defer rule |
| team import/create/edit while standing at target | target identity still current | rebuild associations and reevaluate, allowing newly saved team to be offered |

An interaction requires an NPC, at least one associated team, no combat lockout, and normally no associated team already loaded. `Always Interact` allows reevaluation of the same NPC; `Even If Team Loaded` allows a different preferred team to replace the current one. The preferred-uninjured rule applies to automatic selection. The last-interacted identity suppresses repeated prompts unless Always Interact applies.

Prompt dialog shows target context and a compact multi-team selector with previous/next arrows, then `Load` / Cancel. `Window` only opens an invisible Rematch window; it does not load. Auto Load asks target association for preferred candidate then loads it. `Show Window After Loading` can open Rematch after automatic load; `Only When Any Pets Injured` gates that opening, and injured loaded loadout slots flash.

## Akolus 12.1 target identification
WoW 12.1 can mark unit GUIDs, names, and related API return values as secret in restricted dungeon contexts. The fork extends target identification so an interaction is never based on a secret value and ambiguous evidence never causes a guess.

### Identification ladder

1. **Normal GUID:** parse public NPC ID from target/mouseover/soft-interact/npc unit GUID; normalize it through pack/encounter redirects.
2. **Enemy species fallback:** for a readable `UnitBattlePetSpeciesID`, map every enemy species in notable records to a target only when that species maps to exactly one target. Ambiguous species mappings are explicitly rejected.
3. **Unique public name:** map public unit name, saved known display-name data, or registered alias to a target only if one target owns it. Normalized case and terminal punctuation variants are accepted.
4. **Truncated frame name:** accept a public prefix only when matching known names resolves to exactly one target; reject plural matches.
5. **Gossip evidence:** on Gossip show and a short retry, inspect public gossip title/text/options and frame text. Unique public phrase hints can identify selected dungeon encounter targets.
6. **Nameplates, target frame, tooltip:** collect public visible font text from relevant UI, safely scan nameplate/unit-frame names, and use only a unique resolved identity.
7. **Scenario/criteria:** inspect public scenario name, step/description, and Scenario Objective Tracker visible text for unique phrase/name evidence.

Gossip/object targets may expose identifying data only after target-changed, so Gossip Show triggers a reevaluation. Nameplate unit additions reevaluate when they identify target/npc. Scenario updates and criteria updates do likewise. Once a public match resolves, it updates current/recent target state and fires the regular target-changed path, so the normal interaction behavior above remains exactly shared.

### Redirects, aliases, and packs
The fork's data layer normalizes component units to an encounter/root target before saved-team lookup. This covers battle-pet packs, dungeon console/robot arrangements, adjacent encounter pets, and other components that should share the same saved team. It additionally maps individual public member names to an encounter target. Do not copy the source lookup tables or their values; rebuild independently from allowed data sources.

### API-level secret rules
- Check secret status **before** equality, table-key, string, format, pattern, or lowercase operations.
- Treat any secret or non-string/non-numeric candidate as unavailable, not false evidence.
- Do not scrape/private-store hidden data; inspect only publicly rendered text and ordinary readable API return values.
- Never identify from ambiguous species, aliases, names, prefixes, or text hints. Lack of identification is preferable to loading the wrong team.
- Redirect resolved IDs before history, UI display, association lookup, and interaction suppression checks.

See [battle compatibility](battle.md#retail-121-compatibility-boundary) and [processes](processes.md#akolus-121-compatibility-observations) for the related API-level safety rules and remaining live-client checks.

## Options affecting this surface

| Option label | group | default | effect |
|---|---|---:|---|
| Compact Target List | Lists | off | makes target rows 26 px compact rows |
| Color Targets By Expansion | Lists | on | expansion colour for target names |
| Hide Team Badges | Badges | off | hides target-associated-team badge |
| Hide Truncated Tooltips | Tooltips | off | hides hover full-name tooltip |
| On Target | Interaction | None | target-change mode |
| On Soft Target | Interaction | None | soft-interact mode |
| On Mouseover | Interaction | None | mouseover mode |
| Always Interact | Interaction | off | permit recurring same-target interaction |
| Even If Team Loaded | Interaction | off | allow preferred different-team switch under Always |
| Prefer Uninjured Teams | Interaction | off | choose first uninjured associated team |
| Show Window After Loading | Interaction | off | open Rematch after auto-load |
| Only When Any Pets Injured | Interaction | off | gate above opening |
| Hide Extra Help | Menus | off | hides menu Help entries |

## Fonts, colours, and textures

| Use | specification |
|---|---|
| target/header name | `GameFontNormal` |
| quest subtitle | `GameFontNormalSmall` |
| empty/retrieving fallback | `#808080` / standard cache placeholder tone |
| header art | own art `textures/headers` — redraw or substitute |
| row background / pet border | own art `textures/listbuttondark`, `textures/teamborders` — redraw or substitute |
| relationship badge | own art `textures/badges-borderless` — redraw or substitute |
| search/arrow | Blizzard `Interface\Common\UI-Searchbox-Icon`, `Interface\ChatFrame\ChatFrameExpandArrow` |
| target expansion colour | expansion palette derived from target expansion ID; see [window](window.md) / options spec for complete mapping |

## States and lockouts
- **No recent target:** show `No recent targets`; notable catalogue remains available.
- **Header closed:** target children omitted; header retained.
- **Search:** recent items skipped; result headers/children shown; expanding disabled.
- **Name cache pending:** initial uncached NPC name may display a retrieval placeholder and request a delayed UI refresh; after timeout, use a generic unknown-NPC label with ID rather than loop indefinitely.
- **Unknown target:** selectable and can hold saved teams, but shows generic portrait/one visual pet; no claimed enemy count.
- **Secret / ambiguous 12.1 target:** leave current identity unresolved; do not change loaded target or load a team.
- **Combat:** inspect panel remains readable; interaction automatic loading does nothing during combat lockout.

## Source vs screenshot
- Screenshot is the Teams view, not Targets, but establishes the Targets panel's identical journal right-column geometry, top-bar visual language, 29 px header height, 26 px headers, and 44 px normal common row template.
- The source declares Targets top bar without a dropdown menu button, unlike Teams and Queue; screenshot's right-side `Teams` button is not to be carried into Targets.
- Screenshot wins for journal-host width; generic source width values only specify reusable row internals.

## Open questions / gaps
- No dedicated Targets screenshot was supplied, so exact currently-visible target-list colours and real catalogue ordering cannot be screenshot-verified. Source data order and shared visual template supply them.
- The source comments reference a lower historical target count; the fork's live table is 369 records, which this spec uses.
- Target menu labels are intentionally abbreviated here because [menus](menus.md) is owned by another writer.

## R0 acceptance

Exercise known, wild, recent, unknown and ambiguous targets; search/collapse and selecting a target must not implicitly load a team. Test secret GUIDs/IDs/names, absent gossip/scenario APIs and multiple matching aliases. Use only readable corroborating evidence; an unresolved identity stays unresolved and cannot trigger automatic loading. No restricted target database is licensed for copying by this spec. Exact catalogue contents and target-list visuals need independently sourced data and later live/screenshot verification.
