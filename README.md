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

## Pet Journal window

BattleBuddy replaces the Pet Journal panel inside Collections with a three-column window, utility toolbar, bottom actions, and Teams, Targets, Queue, and Options tabs. The left column lists pets; the other columns remain placeholders. Switching tabs remembers the last view without loading a team. Team actions and Summon remain disabled. The toolbar offers pet-care items and Revive Battle Pets; Find Battle starts matchmaking or leaves the queue.

The pet list searches names, abilities and ability text. Combine text with comparisons such as `level=25 health>1400 power>=280 speed=250-300`; the HP, Power and Speed fields accept the same comparisons or inclusive ranges. The level-25 shortcut toggles max-level pets; right-click also requires rare quality. Family, Strong Vs and Tough Vs buttons filter the list. Owned rows support native cursor dragging; filtering never summons or changes the loadout. Breed text stays blank. The full Filter menu and pet-card/menu interactions are pending. `/bb dev shots` includes `window-pets`; live visual parity remains unverified.

Uncheck **BattleBuddy** beside Summon to restore Blizzard’s Pet Journal. Check it there to return to BattleBuddy. The choice is saved. Combat temporarily restores Blizzard’s journal and disables both toggles; BattleBuddy returns after combat if the pets journal remains open. The close button closes Collections.

## Battle statistics

The default Blizzard pet-battle frame shows frontline health percentage, power, and speed below both health bars. Native current/max health stays inside each bar. The Vs-circle indicator shows `?`: available evidence does not establish an absolute current round, and BattleBuddy never derives one from playback or PBS counters. Secret/unavailable percentages are hidden; unknown power and speed show `?`. Native health text retains Blizzard's display path.

`battleRound`, `battleStats`, and `battleHealth` default to enabled through `BattleBuddyConfig`. The replica Options controls are not implemented yet; only defaults are added. Changes apply on the next pet-battle event. Presentation never loads teams or dispatches battle actions. `/bb dev on` followed by `/bb dev shots` includes a `battle-stats` view using synthetic data outside battle; it is a layout preview, not a full Blizzard battle-frame replica.

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

Run the existing tests from the repository root with `lua5.1 tests/<name>_test.lua .` for each file. Retail 12.1 validation must additionally cover secret/unavailable target and battle APIs: unresolved facts stay unknown, ambiguous target matches never auto-load, and UI refresh never dispatches actions. See the target and battle specs for Akolus workarounds and live-test gaps.
