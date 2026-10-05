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

BattleBuddy replaces the Pet Journal panel inside Collections with a three-column window, utility toolbar, bottom actions, and Teams, Targets, Queue, and Options tabs. Columns are placeholders; switching tabs remembers the last view without loading a team. Team actions and Summon remain disabled. The toolbar offers pet-care items and Revive Battle Pets; Find Battle starts matchmaking or leaves the queue.

Uncheck **BattleBuddy** beside Summon to restore Blizzard’s Pet Journal. Check it there to return to BattleBuddy. The choice is saved. Combat temporarily restores Blizzard’s journal and disables both toggles; BattleBuddy returns after combat if the pets journal remains open. The close button closes Collections.

## Reference licenses

Rematch, Akolus, BPBUIT, and PetTracker are ARR/unlicensed: factual own-word specifications only, with no copied code, XML, comments, long text, or assets. Screenshots are reference evidence, not distributable addon artwork. BreedID remains spec-only while its BSD terms are unresolved.

The preserved PBS snapshot is MIT, pinned to **v1.13.1**, revision `fe78bd60049c559d9bf7d8d27a4039a2036b0241`; retain [its license](third_party/pbs/LICENSE.md) and separately applicable bundled-library notices. The [R0 index](docs/reference/rematch/README.md) records integration and verification limits.

## Development

BattleBuddy targets current retail WoW 12.1 (`## Interface: 120100`). Validate the addon with:

```sh
wow-check BattleBuddy
```

A game sync and publishing are separately gated.

Run the existing tests from the repository root with `lua5.1 tests/<name>_test.lua .` for each file. Retail 12.1 validation must additionally cover secret/unavailable target and battle APIs: unresolved facts stay unknown, ambiguous target matches never auto-load, and UI refresh never dispatches actions. See the target and battle specs for Akolus workarounds and live-test gaps.
