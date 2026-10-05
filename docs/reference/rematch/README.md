# R0 replica specification

This directory is an own-word implementation brief, not copied addon source. The preserved [reference survey](../README.md) provides background; this index governs R0 scope where older survey statements differ. Existing detailed drafts remain intact, with short completion contracts appended where needed.

## Authority and workflow

1. Match the supplied [screenshots](../screenshots/) 1:1 for visible layout, hierarchy, spacing, state, and interaction affordances. Screenshot pixels depend on UI scale; do not treat source-frame dimensions as screenshot pixel measurements.
2. Use the local sources below for unseen states and behavior. Source symbol names and asset paths are evidence locators, not an implementation or asset-reuse prescription.
3. Implement in BattleBuddy-owned modules; compare each delivered surface against the relevant screenshot and exercise the listed acceptance cases. Keep any intentional additions explicitly identified.
4. Phase A exposes only options changed from reference defaults and controls for shipped features. Reference option inventories describe behavior, not a requirement to ship all settings immediately.

PBS integration is an intentional addition: Save Team **Script** tab, team-row script action/badge, and battle **Autobattle**. No standalone PBS manager/editor/selector/minimap surface. Use the current Akolus battle panel plus the selected BPBUIT extras in [battle](battle.md). Later UltraSquirt repeat/heal/buff workflows extend these surfaces; no separate UltraSquirt windows. No silent adoption of another addon's SavedVariables.

## Surface map

| Area | Specification | Screenshot evidence |
|---|---|---|
| Host and navigation | [Window](window.md) | journal teams, queue |
| Collection | [Pet list](pet-list.md), [Filter menu](filter-menu.md), [Pet card](pet-card.md) | journal teams, filter menu, pet card |
| Current pets | [Loadout](loadout.md) | journal teams, queue |
| Persistence and teams | [Data model](data-model.md), [Teams](teams.md), [Save Team](save-team-dialog.md) | journal teams, save dialog |
| Encounter and leveling | [Targets](targets.md), [Queue](queue.md) | shared journal layout, queue |
| Preferences and commands | [Options](options.md), [Menus](menus.md) | filter menu and other visible menu affordances |
| Exchange and lifecycle | [Team strings](team-strings.md), [Processes](processes.md) | source-only behavior |
| Battle and collection extras | [Battle](battle.md), [Breeds](breeds.md), [PetTracker](pettracker.md) | battle UI, enemy ability tooltip, enemy breed tooltip |

The eight supplied PNGs remain unchanged. Targets, general Options, serialized formats, many transient states, and PetTracker world-map surfaces have no dedicated screenshot. Those portions are source-derived and require later visual/live confirmation. No screenshot exists for the new Script tab; retain the existing four tabs and match their styling when adding it.

## Local evidence and license rules

| Local source | Role | Reuse boundary |
|---|---|---|
| `/tmp/ns/ref/rematch-wowi/Rematch` | baseline management behavior | ARR; facts in own words only |
| `/tmp/ns/ref/Akolus_12.1-Rematch` | current 12.1 behavior and battle panel | unlicensed derivative; facts only |
| `/tmp/ns/ref/axc450_pbs` | script engine and integration behavior | MIT; retain notice |
| `/tmp/ns/ref/bpbuit` | selected battle information extras | ARR; facts only |
| `/tmp/ns/ref/BattlePetBreedID` | breed/stat behavior | BSD marker without complete terms; spec-only |
| `/tmp/ns/ref/PetTracker` | collection/map behavior | ARR; facts only |

Do not copy ARR/unlicensed code, XML, comments, long prose, or assets. Existing reference screenshots must not become shipped textures. Use independently created or appropriate native Blizzard UI resources. Do not transplant target/breed databases from restricted sources merely because their format is documented.

## PBS pin and packaging boundary

- Source revision: `fe78bd60049c559d9bf7d8d27a4039a2036b0241`; local tag/description: **v1.13.1**.
- `third_party/pbs/` matches the local source checkout byte-for-byte, excluding the checkout's `.git` directory. Its [MIT license](../../../third_party/pbs/LICENSE.md) is present, including the 2018 Dengzhun Lu copyright notice.
- The source TOC uses `@project-version@`; that template is not a resolved release version. The revision above is the pin. Vendoring is not evidence that the engine is currently loaded by BattleBuddy.
- Preserve the snapshot. Select and adapt the engine through BattleBuddy-owned integration later; do not load its standalone UI wholesale. Bundled libraries retain separate attribution obligations; packaging needs a complete dependency/notice audit.

## Safety and completion

Retail 12.1 facts can be secret or absent. The [targets](targets.md), [battle](battle.md), and [breeds](breeds.md) specs distinguish fallback evidence from authoritative facts. Unknown stays unknown: no inferred target may silently select a team when ambiguous, no secret value is compared/indexed/formatted/arithmetic input, and protected-call success is not proof of a public result. UI refresh does not load teams or execute battle actions; hardware-triggered actions retain combat/journal lockouts.

R0 is documentation completion only. Before implementation acceptance, run the Lua tests, `wow-errors --match BattleBuddy`, `wow-check BattleBuddy`, and screenshot/live-state checks in the configured WoW workspace. Sync remains separately authorized, explicit-path preview first. This documentation task does not authorize commits, pushes, sync, or shipping third-party assets.
