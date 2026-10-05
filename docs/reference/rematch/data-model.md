# Persistent data model
Sources: `Rematch.toc`, `savedvars/settings.lua`, `savedvars/savedTeams.lua`, `savedvars/savedGroups.lua`, `savedvars/savedTargets.lua`, `savedvars/convert.lua`, `process/petTags.lua`, `process/queue.lua`, `info/petInfo.lua`, `info/speciesInfo.lua`, `info/collectionInfo.lua`, `info/targetInfo.lua`, `main/constants.lua` · Fork changes: `info/petInfo.lua`, `main/constants.lua`, `savedvars/settings.lua` · Screenshots: none

## Purpose

This is the persistent and derived data contract needed to recreate Rematch behaviour. It describes **data**, not source implementation. UI-specific option labels are owned by [options](options.md); this page lists setting keys only where their value drives an identifiable data model or consumer surface.

## Saved variables

| Saved variable | Shape | Responsibility |
|---|---|---|
| `Rematch5Settings` | key/value object | Preferences, filters, layout state, queue entries, note/tag/marker dictionaries, and migration mappings. |
| `Rematch5SavedTeams` | map `team:<n>` → team record | User-created persistent teams. |
| `Rematch5SavedGroups` | map `group:<n>` / meta group IDs → group record | Persistent organisation and group-level preferences. |
| `Rematch5SavedTargets` | map numeric NPC ID → ordered `teamID[]` | Reverse index from a target to its saved teams. |
| `Rematch4Saved`, `Rematch4Settings` | legacy preservation/import data | Captured Rematch 4 data retained for conversion compatibility. |
| `RematchSaved`, `RematchSettings` | legacy incoming names | Consumed/captured on migration when present. |

The public in-memory facades use the same logical data but add validation, temporary records and calculated indexes. Persist exactly the stored data rather than facade-only caches.

## Team record

A user team is stored under a stable key such as `team:1`. The four always-required fields are `teamID`, `name`, `pets`, and `tags`; optional fields are omitted rather than written as empty/default values.

| Field | Type / example | Required | Meaning |
|---|---|---:|---|
| `teamID` | string, `team:17` | yes | Stable identity; equal to its map key. |
| `name` | string | yes | Trimmed, case-insensitively unique across user teams. On collision, creation appends ` (2)`, ` (3)`, etc. |
| `pets` | ordered array of 0–3 pet IDs | yes | The three team slots. May be owned GUID IDs, species numeric IDs, or special placeholders. |
| `tags` | ordered array matching `pets` | yes | Compact pet specification carrying species/breed/ability-choice data, used for restoration/import/replacement. |
| `favorite` | boolean, optional | no | Favourite flag. A favourite’s active group is the favourite meta group. |
| `groupID` | string `group:<n>`, `group:none`, or `group:favorites` | no (defaults to ungrouped) | Current containing group. |
| `homeID` | group ID, optional | no | Original group while favourite. Remove when unfavourited. |
| `notes` | string, optional | no | Free-form team note. |
| `targets` | ordered numeric NPC ID array | no | Target associations in team order. The reverse target map must agree. |
| `preferences` | preference object | no | Per-team leveling selection rules, layered over group/default rules. |
| `winrecord` | win record object | no | Counts for team battle history. |

### Pet tags

`tags[i]` should survive a missing or invalid original GUID and select an appropriate replacement later. It is a compact base-32 string describing three ability choices (each tier selector is none/first/second), breed (zero means no preference), and species ID. Queue tags instead encode a queue marker plus level and rarity. Reserved special encodings represent leveling, ignored, random type, unnotable target, and unknown slots. New code may use a clearer serialisation internally but must preserve import/export and selection meaning.

### Preferences object

Team/group/default preference objects contain only applied criteria. The recognised team record fields are:

| Key | Value | Meaning |
|---|---|---|
| `minHP`, `maxHP` | numeric percentage/value thresholds | Accepted health range. |
| `minXP`, `maxXP` | numeric percentage/value thresholds | Accepted XP range. |
| `allowMM` | boolean | Whether matchmaking-related candidates are permitted. |
| `expectedDD` | number | Expected damage/death-related preference used in selection. |

The current effective preferences are a layered combination of `DefaultPreferences`, group preferences, and team preferences. Empty objects mean no criteria at that layer.

### Win record object

| Key | Type | Meaning |
|---|---|---|
| `wins` | integer | Recorded wins. |
| `losses` | integer | Recorded losses. |
| `draws` | integer | Recorded draws. |
| `battles` | integer | Total recorded outcomes; migration derives this from the first three fields. |

## Team identity, temporary records, and generated keys

- Allocate the lowest positive unoccupied `team:<n>` key. Deleted numerical keys may be reused.
- The team map has non-persistent working records: `empty`, `sideline`, `loadonly`, `temporary`, `original`, and `counter`. They have the same base `{teamID, name, pets, tags}` shape but are not entries in `Rematch5SavedTeams`.
- `sideline` is the editable staging team for save/import/target-save. `original` supports edit comparison. `loadonly` represents currently loaded unsaved slots. `counter` holds generated target-counter pets. `temporary` is generic transient storage. `empty` resets the other transient records.
- Saving copies staged content rather than retaining its object identity. Copying to a user team normalises name, deep-copies tables, leaves `teamID` immutable, and defaults absent `groupID` to `group:none`.
- Maintain derived indexes: lowercase team name → team ID; pet ID/species ID → number of user teams containing it; current count of user teams. For a repeated numeric species ID in different slots of one team, count it once for that team.

## Group record

A group is stored under `group:<n>`. Group names may repeat; group identity must not.

| Field | Type / example | Required | Meaning |
|---|---|---:|---|
| `groupID` | `group:4` | yes | Stable group identity and map key. |
| `name` | string | yes | Display name. |
| `icon` | texture identifier | optional | Group icon used in lists and notes heading. |
| `color` | hex RGB string or absent | optional | Team/group display colour; absent uses standard gold group/white team treatment. |
| `sortMode` | alpha / wins / custom enum | yes for new groups | Sort team list by name, win record, or preserve manual order. |
| `teams` | ordered `teamID[]` | yes | Display/order list for teams in group. It is rebuilt/reconciled against each team’s `groupID`. |
| `preferences` | preference object | optional | Group-level leveling preferences. |
| `isExpanded` | boolean | optional | Collapsed/expanded state. Current UI also persists expanded IDs in settings. |
| `showTab` | boolean, optional | no | Bookmark group as a team tab; maximum 16. |
| `meta` | boolean | meta groups only | Identifies protected system groups. |

### Meta groups

The model always validates two protected records:

| ID | Display name | Initial icon | Behaviour |
|---|---|---|---|
| `group:favorites` | Favorite Teams | guild-popularity achievement icon | Must appear first in `GroupOrder`; cannot be deleted/replaced through normal group setters; a favourite’s `homeID` remembers its original group. |
| `group:none` | Ungrouped Teams | battle-pet-training icon | Must appear second in `GroupOrder`; default destination for missing/deleted groups. |

Allocate a normal group ID by taking the first unused positive `group:<n>`. Deleting a normal group either moves member teams to ungrouped or, if explicitly requested, deletes those teams. Group reconciliation removes stale/moved IDs and appends missing matching teams. Sort modes are alpha, win-rate/raw wins depending on setting, or custom order unchanged.

## Target record

Targets use numeric NPC IDs in persisted associations. Public IDs may be represented as `target:<npcID>` in list/strings; accept either form at boundaries and normalise to numeric storage.

| Store / field | Shape | Meaning |
|---|---|---|
| Team `targets` | ordered numeric NPC ID array | Every target that names this team. |
| `Rematch5SavedTargets[npcID]` | ordered `teamID[]` | Reverse list: this target’s preferred team at index 1 followed by alternatives. |
| target information (derived) | see below | Not generally persisted by this module: name/subname, display ID, known enemy pets, expansion/map/header/quest, target history. |

A target can be saved even if it is not a recognised/notable target. Reconciliation removes a target whose team list becomes empty, removes stale team IDs, and adds new team associations while retaining order. Changing an ordered target team list must update both sides, then run team/group/target reconciliation.

## Queue storage

`Rematch5Settings.LevelingQueue` is an ordered list. Each entry is:

| Field | Type | Meaning |
|---|---|---|
| `petID` | owned GUID string | Queue candidate. |
| `petTag` | queue-format compact tag | Species plus level/rarity preference for later resolution/import. |
| `added` | numeric `YYYYMMDDHHMMSS` | Time added, used by queue ordering/diagnostics. |

Related saved settings:

| Key | Meaning |
|---|---|
| `SpecialSlots` | map slot 1–3 → special pet ID (`0`, `random:n`, `ignored`) separate from physically loaded Blizzard pets. |
| `DefaultPreferences` | global queue selection rules. |
| `PreferencesPaused` | disables all default/team/group preference filtering. |
| `QueueActiveSort` | continuously maintain selected sort. |
| `QueueSortOrder` | asc / median / desc primary level order. |
| `QueueSortInTeamsFirst`, `QueueSortFavoritesFirst`, `QueueSortRaresFirst`, `QueueSortAlpha`, `QueueSortByNameToo` | tie/priority sort controls. |
| `LastToastedPetID` | last levelling-pet notification state. |
| queue confirmation/auto-fill keys | UI policy for fill, removal, auto-learn, random fallback, dead/full-health preference; see [options](options.md). |

Queue operations use tags to recover a suitable existing pet if exact GUID is unavailable. Queue membership yields derived `isLeveling` on pet info. A queue-controlled slot is encoded by special ID `0`; on load it resolves to an eligible queue pet rather than permanently storing a GUID in the team slot.

## Pet tags, markers, notes, and filter-support state

| Settings key | Shape | Meaning |
|---|---|---|
| `PetNotes` | map `speciesID` → string | Shared note across all owned versions of a species. Enables notes badge and normal search of text such as `#find`. |
| `PetMarkers` | map `speciesID` → integer 1–8 | Chosen raid-marker-like tag for that species. |
| `PetMarkerNames` | map marker index → string | User renames of standard marker labels. |
| `HiddenPets` | map `speciesID` → true | Hidden species filter state. |
| `Filters`, `FavoriteFilters`, `ScriptFilters` | structured filter data | Current/saved pet filtering. See [filter menu](filter-menu.md). |
| `SpecialSlots` | described above | Loaded slot markers, not team fields. |

Markers’ display colours are ordered: yellow `FFEB00`, orange `FA9100`, purple `D438E6`, green `0AF200`, pale blue `B3D1DF`, blue `00B5FF`, red `FF3D2B`, white `FAFAFA`. The icon crop comes from the standard 4×4 raid-target icon sheet.

## Pet ID kinds

All consumers must distinguish ID kind before querying a live journal API.

| Kind | Form / example | Meaning | Common use |
|---|---|---|---|
| owned pet | GUID-shaped string, e.g. `BattlePet-…` | Specific player-owned journal pet | Teams, slots, queue. |
| species | positive number | Species reference, no specific owned version | Missing/uncollected team slot; lists/filters. |
| leveling | numeric `0` | Queue-controlled placeholder | Team slot / special slot. |
| ignored | string `ignored` | Placeholder that intentionally does not load | Team slot / special slot. |
| random | `random:0` … `random:10` | Random high-level pet, any or specified family | Team slot / special slot. |
| link | `battlepet:<species>:<level>:<rarity>:<health>:<power>:<speed>` | Chat-linked snapshot not necessarily owned | Linked card/import context. |
| live battle | `battle:<owner>:<index>` | Current battle companion; owner 1 player / 2 enemy, index 1–3 | Battle UI and live stat display. |
| unnotable | `unnotable:<npcID>` | Placeholder for opponent whose pets are not recorded | Target display/card. |
| empty | nil or `empty` | Empty slot | UI placeholder. |
| unknown | any unrecognised value | Invalid/indecipherable input | Must not make card or API assumptions. |

A stored team pet should normally be owned GUID, species, leveling, ignored, or random. Chat links/live battle/unnotable IDs are runtime representations and must not silently become normal owned-pet records.

## Derived `petInfo` fields used by UI

`petInfo` is a lazily calculated subject object, not a saved record. It refreshes/reset when subject changes and caches requested fields for that subject. UI needs the following contract.

| Category | Derived fields |
|---|---|
| Identity | `petID`, `idType`, `speciesID`, `customName`, `speciesName`, `name`, `formattedName`, `icon`, `displayID`, `creatureID`, `petType`, `suffix`, `petTypeName`, `isValid`, `isOwned`, `isSpecialType`. |
| Journal metadata | `sourceText`, `loreText`, `sourceID`, `expansionID`, `expansionName`, `isWild`, `canBattle`, `isTradable`, `isUnique`, `isObtainable`, `needsFanfare`, `isRevoked`. |
| Progress / combat | `level`, `xp`, `maxXp`, `fullLevel`, `health`, `maxHealth`, `power`, `speed`, `rarity`, `color`, `isDead`, `isInjured`, `shortHealthStatus`, `longHealthStatus`, `isSlotted`, `isSummonable`, `summonError`, `summonErrorText`, `summonShortError`, `isSummoned`, `tint`. |
| Abilities / matchup | `abilityList[1..6]`, `levelList[1..6]`, `usableAbilities`, `moveset`, `strongVs` map ability→target family, `toughVs`, `vulnerableVs`, `passive`. |
| Collection / breed | `count`, `maxCount`, `countColor`, `breedID`, `breedName`, `hasBreed`, `possibleBreedIDs[]`, `possibleBreedNames[]`, `numPossibleBreeds`, `isSpeciesAt25`, `isMovesetAt25`. |
| Rematch organisation | `inTeams`, `numTeams`, `notes`, `hasNotes`, `marker`, `isLeveling`, `isStickied`. |
| Battle/target | `battleOwner`, `battleIndex`, `npcID`. |

Health display semantics: Dead has health zero and `shortHealthStatus = Dead`; injured produces an integer percent; full health reports maximum-health number. `tint` is red for an owned but unsummonable/revoked/wrong-faction issue, grey for unowned/otherwise unsummonable status, absent otherwise. `formattedName` uses rarity colour when name-colouring option is enabled.

For current live battle IDs, values must be drawn from battle APIs, not assumed to match original slot state. The fork specifically corrects ally battle pets to read live species/name/level/display data, described below.

## Derived `speciesInfo`

Species-level data is session-stable and filled during journal roster scan:

| Field / lookup | Meaning |
|---|---|
| species ID → ordered moveset | Six ability IDs in learn order. |
| species ID → source ID | Source category (drop, quest, vendor, etc.). |
| species ID → expansion ID | Expansion inferred from species-range data plus exceptions. |
| species ID → can-battle | Corrected species truth; do not trust some faction-specific per-owned-pet responses. |

UI uses it for source/expansion display, filters, breeds and fallback entity data.

## Derived `collectionInfo`

Collection aggregation is session-derived from owned journal pets, not persisted:

| Lookup / object | Data |
|---|---|
| species-at-25 lookup | whether a particular species has any level-25 owned version. |
| moveset-at-25 lookup | whether a recorded moveset occurs at level 25. |
| unique-moveset lookup | whether only one species shares a moveset. |
| per-species stats | pet type, source, owned count, count at 25, summed levels, counts by rarity. |
| collection aggregate | journal count, unique/total collected, uncollected, unique/total max-level, rarity totals, total/average level. |
| win aggregate | team win record totals and ranked team data. |

These fields drive list filtering and collection summaries, rather than being copied into team records.

## Derived `targetInfo`

Target information combines target-data records with runtime resolution and caches:

| Field / lookup | Meaning |
|---|---|
| `currentTarget` / `recentTarget` | current unit NPC ID and last meaningful target. |
| target history | ordered most-recent three NPC IDs, deduplicated. |
| NPC name/subname | cached readable display name; temporary retrieval state if tooltip/model data is not ready. |
| display ID | portrait/model display ID resolved for NPC. |
| notable/wild indicator | whether target belongs to supplied notable target data or wild-pet class. |
| recorded enemy pets | ordered battlepet-link-compatible pet data (optionally limited slots). |
| target metadata | header/map, expansion, quest, locations, redirects. |

Only target associations/preferring order are persistent in `Rematch5SavedTargets`; discovery/cache data is rebuildable. The UI renders a known but unsaved notable target, and permits saving an arbitrary NPC target.

## Important settings categories

These are data-model-bearing values; link [options](options.md) for full labels/defaults.

| Category | Keys / records |
|---|---|
| Layout/reopen | `CurrentLayout`, standalone/journal/maximized/last layouts, last-open journal, position/scale/lock values. |
| Team organisation | `GroupOrder`, `ExpandedGroups`, `LastSelectedGroup`, `ConvertedTeams`, backup counters. |
| Target organisation | `ExpandedTargets`, interaction target/recent selection state is runtime. |
| Pet organisation | filters, favourite/script filters, `HiddenPets`, marker maps, `PetNotes`. |
| Queue | `LevelingQueue`, `SpecialSlots`, preferences and queue sorting flags above. |
| Card/note positions | `PetCardCanPin`, pin/location values generated by card name; `LockNotesPosition`, `NotesLeft`, `NotesBottom`, `NotesWidth`, `NotesHeight`. |
| Import/export | include-preferences/notes flags and import conflict override/priority choices. |

## Conversion from Rematch 4

On first relevant login, legacy `RematchSaved`/`RematchSettings` are copied into protected Rematch 4 variables and old globals cleared. If Rematch 5 storage is effectively empty, boolean settings, notes, filters, queue and teams are migrated; each old team becomes a new `team:<n>` record, copying pets and converting their old ability data into tags, falling back to its species ID when a GUID is invalid. Old per-team target keys become `targets`, team preferences and win counts become nested records, old favourite placement becomes `group:favorites` plus `homeID`, old group tabs become normal/meta group records and ordered IDs, and a legacy key→new team-ID map is written to `ConvertedTeams`. Legacy queue entries become `{petID, petTag, added}` after validity check. A conversion event/mapping supports external consumers, but no Rematch 4 field should be treated as authoritative after migration.

## Akolus fork changes

| File | Difference that matters to this model |
|---|---|
| `info/petInfo.lua` | For ally `battle:1:<slot>` subjects in WoW 12.1, derives species/name/level/display ID from live battle APIs rather than copying the journal slot’s owned-pet identity. Live card/loadout/battle UI therefore reflects battle state reliably. Enemy battle data likewise supplies current name/species metadata. |
| `main/constants.lua` | Adds unique sort enum after team sort and adjusts Pet-panel top heights (56 collapsed / 115 expanded) to account for fork pet-filter layout. Neither changes saved record shape. Its extended filter help declares native breed-aware constraint logic; see breeds/filter specs. |
| `savedvars/settings.lua` | Adds fork battle-UI settings (enemy ability bar size/spacing/fonts/position/scale, custom battle UI opt-in, battle controls position/scale, autobattle hotkey). They are ordinary setting keys; no additional top-level saved variable nor team/group/target record field. |
| fork breed modules | Native breed source replaces dependency on external breed addon while retaining compatibility source token `BattlePetBreedID`; this makes `breedID`, possible breeds and breed filters available from bundled data. |

## Open questions / gaps

- `settings.lua` contains many surface-only option defaults intentionally not enumerated here; individual surface specs record observed defaults and [options](options.md) governs Phase A exposure.
- Exact serialization bytes for tags are implementation-format details; preserve their semantic fields and legacy-import compatibility rather than relying on textual code.

## BattleBuddy completion contract

The names and legacy conversion above describe the reference, not permission to adopt Rematch globals or run a migration on login. BattleBuddy owns its schema. Explicit text import is a reviewed exchange operation; rendering never writes imported data. Restricted target/breed datasets must not be transplanted.

Associate PBS script content with a stable BattleBuddy team identity, independent of display name, group, or row position. Save Team stages team and script changes together; Cancel leaves both unchanged. Rename/move preserves the association; copying/importing resolves the new identity before attaching the script. Keep transient battle selection and derived target indexes out of authoritative team intent.

Acceptance: reload preserves teams, order, preferences and scripts; rename/move retains the script; collision handling cannot attach it to the wrong team; stale GUIDs produce recoverable unresolved slots; derived-index rebuilds do not load pets. See [team strings](team-strings.md) for exchange gaps.
