# BattleBuddy contributor guide

## Scope and layout

- `BattleBuddy/` is the addon directory installed in `_retail_/Interface/AddOns/`.
- `BattleBuddy/BattleBuddy.toc` is the ordered runtime load manifest.
- `BattleBuddy/BattleBuddy.lua` currently establishes the small product boundary and native entry points. Expand the addon through focused modules as milestones are delivered.
- `BattleBuddy/pkgmeta.yaml` defines release packaging metadata.

## Product rules

BattleBuddy is a standalone current-retail pet-battle QoL addon. Prioritize repeat battlers, then strategy authors.

- Build BattleBuddy-owned features; do not restore inherited interfaces, data migrations/imports, commands, or runtime dependencies.
- Follow Blizzard’s default Pet Journal and pet-battle UI patterns. Extend native surfaces additively rather than creating a competing primary window.
- Use Blizzard Settings for preferences.
- Keep persistence, domain logic, client facts/actions, exchange codecs, and UI presenters independent as the architecture is added. UI refresh must never apply a team or dispatch a battle action.

## Current-retail API rules

Target retail WoW 12.1. Before changing a WoW API call, query it with `wow-api <name>`; if it is not indexed, inspect the live FrameXML source at `~/.local/share/wow/wow-ui-source`.

- Prefer current namespaced APIs when available. Do not add removed legacy APIs or combat-log parsing.
- Treat combat data as potentially secret. Do not compare, index with, or perform arithmetic on secret values.
- Do not change protected or secure frames in combat.

## Validation and testing

Work in the `dev/wow-addons` Coder workspace. Before edits, inspect existing errors with:

```sh
wow-errors --match BattleBuddy
```

Validate touched code before committing:

```sh
cd ~/wow-battle-buddy
wow-check BattleBuddy
```

A sync is separately gated. When authorized, preview the explicit addon path first, then sync only that path and ask the user to `/reload`. Do not sync an empty path or overwrite a released addon without explicit approval.

## Repository hygiene

- Do not commit game data, SavedVariables, caches, logs, packaged archives, or generated output.
- Keep package and source identity aligned: `BattleBuddy/`, `BattleBuddy.toc`, `BattleBuddy.lua`, and `package-as: BattleBuddy`.
- Commit only after `wow-check` has no errors. Push only when requested.
