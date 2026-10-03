# BattleBuddy

BattleBuddy is a standalone, current-retail World of Warcraft pet-battle quality-of-life addon. It is being built for repeat battlers first and strategy authors second.

Its interface builds on Blizzard’s Pet Journal and pet-battle UI rather than maintaining a competing standalone control window. BattleBuddy has no runtime dependency on Rematch, tdBattlePetScript, or inherited addon data.

## Current baseline

The M-1 identity boundary provides the clean BattleBuddy addon and native entry points:

- `/bb` opens Blizzard’s Pet Journal on the Pets tab.
- `/bb config` opens BattleBuddy in Blizzard Settings.
- `/bb help` prints the available commands.

The future native data model, repeat workflow, team editing, scripting, collection tools, and battle HUD are delivered as separate dependency-ordered milestones.

## Development

BattleBuddy targets current retail WoW 12.1 (`## Interface: 120100`). Validate the addon with:

```sh
wow-check BattleBuddy
```

A game sync and publishing are separately gated.
