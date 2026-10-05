# BattleBuddy

BattleBuddy is a standalone, current-retail World of Warcraft pet-battle quality-of-life addon. It is being built for repeat battlers first and strategy authors second.

The R0 target is a 1:1 replica of the reference pet-management layout and interactions, implemented independently for BattleBuddy. Supplied screenshots take precedence for depicted states; local source documents the remaining behavior. See the [R0 specification index](docs/reference/rematch/README.md).

PBS will be integrated into Save Team’s **Script** tab, a team-row script action, and the battle **Autobattle** button. It will not add standalone PBS windows or require external Rematch/PBS installations. The battle surface follows current Akolus 12.1 plus the selected BPBUIT extras; later UltraSquirt functionality extends the same surfaces rather than adding its own windows.

## Current baseline

The M-1 identity boundary provides the clean BattleBuddy addon and native entry points:

- `/bb` opens Blizzard’s Pet Journal on the Pets tab.
- `/bb config` opens BattleBuddy in Blizzard Settings.
- `/bb help` prints the available commands.

The repository also contains encounter, persistence, and workflow modules with Lua tests. The window shell below implements the first part of the R0 replica target; the full replica and PBS integration remain unfinished. Phase A exposes only changed reference options and controls for shipped features, keeping other defaults internal.

`BattleBuddyTeamStrings` provides Rematch team/group/backup codecs, readable exports, and preview-first imports with explicit apply, name-conflict choices, unresolved pets, and PBS script attachments; live interoperability checks remain pending.

## Pet Journal window

BattleBuddy replaces the Pet Journal panel inside Collections with a three-column window, utility toolbar, bottom actions, and Teams, Targets, Queue, and Options tabs. The left column lists pets, the middle column displays Blizzard's current three-pet loadout, and the right column lists saved teams. Switching tabs remembers the last view without loading a team. Bottom team actions and Summon remain disabled. The toolbar offers pet-care items and Revive Battle Pets; Find Battle starts matchmaking or leaves the queue.

The loadout updates on journal events, with health, abilities, levels, models, and a target header. Drop a pet from Blizzard's journal onto a slot or click an ability to select an unlocked alternative. Combat, battle, journal/slot locks, and matchmaking refuse edits with a visible reason. Breed text remains blank; leveling markers do not run a queue. The team strip observes `BattleBuddyScript.SetLoadedTeam(store, id)` and indicates script presence without opening an editor. Target Save reports that the Save Team dialog is not available yet. BattleBuddy supplies no teams or fight recommendations.

`BattleBuddyLoadout.DropPet(slot, petID)` is the pet-list integration entry point; `SetTarget({ name, npcID, icon, enemies = { { icon, level } } })` supplies observed target facts without loading pets. `/bb dev window-loadout` (after `/bb dev on`) and `/bb dev shots` include this live-loadout view. Flyouts close on selection, a second click, journal refresh, or window hide; there is no polling or timed dismissal. Visual parity and actual client drag/model behavior still need a retail 12.1 check.

The pet list searches names, abilities and ability text. Combine text with comparisons such as `level=25 health>1400 power>=280 speed=250-300`; the HP, Power and Speed fields accept the same comparisons or inclusive ranges. The level-25 shortcut toggles max-level pets; right-click also requires rare quality. Family, Strong Vs and Tough Vs buttons filter the list. Owned rows support native cursor dragging; filtering never summons or changes the loadout. Breed text stays blank. The full Filter menu and pet-card/menu interactions are pending. `/bb dev shots` includes `window-pets`; live visual parity remains unverified.

`BattleBuddyAlternatives` ranks owned slot replacements with differences and requires confirmation to edit a saved team; menu integration is pending.

### Teams

Search saved teams, pets, groups and targets; **All** collapses or expands groups. Click a team body to load its available pets and saved abilities, with visible missing-pet or lockout reasons. Drag teams onto groups or before/after another team to organize them. Right-click teams/groups for notes, rename, duplicate, favorite, move, export and confirmed deletion. The **Teams** menu offers new groups, preview-then-confirm import (name conflicts become copies), and backup export. Pending editor, target, script, leveling and alternatives surfaces stay disabled with an explanation. No teams or recommendations ship; `/bb dev on` then `/bb dev shots` includes isolated sample rows in the existing `window-teams` view only when the saved store is empty. Refresh never loads pets. Native visual parity and drag behavior still require a retail client check.

Uncheck **BattleBuddy** beside Summon to restore Blizzard’s Pet Journal. Check it there to return to BattleBuddy. The choice is saved. Combat temporarily restores Blizzard’s journal and disables both toggles; BattleBuddy returns after combat if the pets journal remains open. The close button closes Collections.

## Save Team dialog

`BattleBuddySaveTeamDialog.Open("save" | "saveAs", {teamID = id, store = store, onSaved = callback})` opens an isolated draft. An explicit `teamID` edits/copies that team's pets; otherwise the current loadout and target prefill the draft, and Save uses the observed loaded team. Team, Targets, Preferences, and Wins support Reset, immediate Cancel/close/Escape discard, and collision Overwrite/New Copy. `Save()` returns the saved ID; the callback receives it after interactive confirmation. Saving never loads pets. Script text is preserved opaquely; its editor and bottom-bar wiring remain separate work. `/bb dev on`, then `/bb dev save-team-dialog` opens disposable sample data.

## Battle statistics

The default Blizzard pet-battle frame shows frontline health percentage, power, and speed below both health bars. Native current/max health stays inside each bar. The Vs-circle indicator shows `?`: available evidence does not establish an absolute current round, and BattleBuddy never derives one from playback or PBS counters. Secret/unavailable percentages are hidden; unknown power and speed show `?`. Native health text retains Blizzard's display path.

`battleRound`, `battleStats`, and `battleHealth` default to enabled through `BattleBuddyConfig`. `battleHealthTicks` also defaults on: hover either frontline health bar for quarter/half ticks, magic-family 35%/70% ticks, and an opposing Explode estimate from readable max health; out-of-bar estimates are omitted. The replica Options controls are not implemented yet; only defaults are added. Changes apply on the next pet-battle event (ticks also update on hover). Presentation never loads teams or dispatches battle actions. `/bb dev on` followed by `/bb dev shots` includes a `battle-stats` view using synthetic data outside battle; it is a layout preview, not a full Blizzard battle-frame replica.

## Enemy abilities

Three enemy ability icons sit above Blizzard’s pet-battle action bar and hide during pet selection or outside battle. Hover opens the native ability tooltip, including duration, hit chance, description and family effectiveness when available. Cooldown numbers use public native cooldown/lockdown state, re-read after rounds and swaps; unavailable values have no number. No combat-message estimates, timers or battle actions are used.

Shift-drag moves the bar; Ctrl-wheel changes its scale by 1%, bounded to 50–200%. Placement and scale persist. Size (42), spacing (6), cooldown font (`Fonts\FRIZQT__.TTF`) and font size (16) use `Config.lua` defaults and setting overrides. The Options tab is currently a placeholder; no new options UI ships. `/bb dev on`, then `/bb dev shots` includes `battle-enemy-abilities`, a stub icon/cooldown preview outside battle. Native tooltips and cooldown continuity still require live 12.1 verification.

## Battle panel

The compact dark battle panel keeps Blizzard’s ability, swap, trap, Pass and single-confirmation Forfeit controls. Autobattle advances the loaded team’s script once per click or fresh key press; its default battle-only key is **A**. Hold repeats never advance it. Missing scripts and reloads during battle disable Autobattle with a visible reason; manual controls remain available, and script execution resumes at the next battle start.

Use **+** to capture a keyboard binding (Escape cancels), or right-click **+** to clear it. Blizzard’s Key Bindings also lists Autobattle, Pass and three swap bindings. Captured keys override their normal actions only during battle; binding changes wait out combat lockdown. Shift-drag moves the panel; Ctrl-wheel scales it by 1%, within 50–200%, with placement and scale saved. XP, PvP time and effectiveness hints use readable public facts; unknown numbers remain blank. Battle Data shows a small current-facts view. `/bb dev on`, then `/bb dev shots`, includes the `battle-panel` stub preview.

The dark panel has no supplied reference capture. Native secure delegation, PvP timing and visual parity still need live 12.1 checks.

## Reference licenses

The engine in `BattleBuddy/Script/` ports PBS v1.13.1 under its MIT notice; share codecs use local implementations with no bundled library dependencies.

Rematch, Akolus, BPBUIT, and PetTracker are ARR/unlicensed: factual own-word specifications only, with no copied code, XML, comments, long text, or assets. Screenshots are reference evidence, not distributable addon artwork. BreedID remains spec-only while its BSD terms are unresolved.

The preserved PBS snapshot is MIT, pinned to **v1.13.1**, revision `fe78bd60049c559d9bf7d8d27a4039a2036b0241`; retain [its license](third_party/pbs/LICENSE.md) and separately applicable bundled-library notices. The [R0 index](docs/reference/rematch/README.md) records integration and verification limits.

## Development

BattleBuddy targets current retail WoW 12.1 (`## Interface: 120100`). Validate the addon with:

```sh
wow-check BattleBuddy
```

A game sync and publishing are separately gated.

Run `scripts/check.sh` (needs `lua5.1` and `luacheck`): TOC file list, luacheck and every `tests/*_test.lua`. CI runs the same on every push and pull request, then builds the addon zip with the BigWigs packager (`.pkgmeta`) as a workflow artifact without uploading. Pushing a `v*` tag runs the checks again and publishes a GitHub release through the same packager; CurseForge, Wago and WoWInterface uploads stay off until their project ids and tokens are added. `wow-check BattleBuddy` (LuaLS with WoW API annotations) runs in the nightshift WoW image. Retail 12.1 validation must additionally cover secret/unavailable target and battle APIs: unresolved facts stay unknown, ambiguous target matches never auto-load, and UI refresh never dispatches actions. See the target and battle specs for Akolus workarounds and live-test gaps.
