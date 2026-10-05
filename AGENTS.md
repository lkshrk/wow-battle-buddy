# BattleBuddy contributor guide

## Scope and layout

- `BattleBuddy/` is the addon directory installed in `_retail_/Interface/AddOns/`.
- `BattleBuddy/BattleBuddy.toc` is the ordered runtime load manifest.
- `BattleBuddy/BattleBuddy.lua` currently establishes the small product boundary and native entry points. Expand the addon through focused modules as milestones are delivered.
- `BattleBuddy/pkgmeta.yaml` defines release packaging metadata.

## Product rules

BattleBuddy is a standalone current-retail pet-battle QoL addon. Prioritize repeat battlers, then strategy authors.

- R0 defines a 1:1 replica of the reference layout and interactions, independently implemented under BattleBuddy ownership. Follow `docs/reference/rematch/README.md`: screenshots win for depicted states; local source fills unseen behavior. Do not redesign a reference surface while reproducing it. Record intentional BattleBuddy additions separately.
- Integrate PBS into the Save Team **Script** tab, team-row script action, and battle **Autobattle** control. No standalone PBS manager, editor, selector, minimap UI, or external PBS/Rematch runtime dependency. Keep its MIT notice and documented revision pin.
- Use the current Akolus 12.1 battle panel with the selected BPBUIT extras in `docs/reference/rematch/battle.md`; do not combine competing battle control bars.
- Later UltraSquirt functionality extends these existing surfaces and processes; do not restore its own windows or commands. Do not silently migrate inherited addon SavedVariables.
- Phase A exposes only changed reference options and controls needed by shipped features. Preserve other reference defaults internally; do not expose inactive future settings. Use the replica Options surface for delivered controls; Blizzard Settings may remain an entry point without duplicating settings state.
- Keep persistence, domain logic, client facts/actions, exchange codecs, and UI presenters independent as the architecture is added. UI refresh must never apply a team or dispatch a battle action.

## Reference and license boundary

- Rematch, Akolus, BPBUIT, and PetTracker are ARR/unlicensed references: own-word factual layout/interaction specifications only. Never copy their code, XML, comments, long text, or assets into BattleBuddy. Source asset paths in specs identify evidence, not permission to reuse it.
- Preserve supplied screenshots as reference evidence; do not extract or ship their addon artwork. Recreate artwork independently or use appropriate native Blizzard UI resources.
- PBS is MIT: retain `third_party/pbs/LICENSE.md`, attribution, and the pin in `docs/reference/rematch/README.md`. Audit bundled library notices before redistribution; the PBS license does not replace them.
- BattlePetBreedID has incomplete BSD licensing evidence in this snapshot; treat it as spec-only until the terms and attribution are resolved. Later UltraSquirt reuse requires a separate license/dependency review.

## Current-retail API rules

Target retail WoW 12.1. Before changing a WoW API call, query it with `wow-api <name>`; if it is not indexed, inspect the live FrameXML source at `~/.local/share/wow/wow-ui-source`.

- Prefer current namespaced APIs when available. Do not add removed legacy APIs or combat-log parsing.
- Treat combat data as potentially secret. Do not compare, index with, or perform arithmetic on secret values.
- Follow the Akolus 12.1 compatibility observations in the target/battle/breed specs: guard secret values before use, prefer public gossip/scenario/name evidence when target IDs are unavailable, reject ambiguous matches, and show unknown/omit details when ability or breed facts are unavailable. Protected calls do not make secret results safe. These observations require live verification; they are not permission to bypass API restrictions.
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
