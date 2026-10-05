# Options

## Evidence and Phase A boundary

Local behavior references: both Rematch trees' `panels/optionsPanel.lua`, `panels/optionsList.lua`, and `savedvars/settings.lua`. The supplied journal/queue screenshots establish the Options tab location, but do not show its contents. Source layout is provisional until visually checked.

Phase A exposes only changed options and controls needed by shipped features. Do not reproduce the entire historical settings inventory, add controls for unimplemented features, or create a standalone PBS preferences window. Keep the replica Options surface; Blizzard Settings may provide an entry point without creating a second settings store or replacing the reference workflow.

## Reference behavior

- The source panel has a search field and an expand/collapse-all control above a scrollable list of collapsible category headers. Expanded groups persist. Settings use checkboxes, choices, and action buttons; related subordinate controls follow their parent setting.
- Search includes relevant parent/dependent entries so a matching child setting remains understandable. Missing capabilities remove irrelevant controls: breed-related options depend on breed data, and soft-interaction controls depend on the client interaction setting.
- Categories cover interaction, appearance, toolbar, filters, pet cards, notes/tooltips, teams, queue, confirmation, and help. Their existence is reference coverage, not authorization to ship all categories in Phase A.
- Changes must affect only their named behavior. A display preference refreshes presentation; it does not apply a team, summon a pet, or issue a battle action. Reset/import actions require an explicit user action and cannot run during redraw.

## BattleBuddy controls as features ship

- Offer supported appearance and interaction controls only when their corresponding list/card/loadout behavior exists. Preserve accessible focus, readable labels, current values, and disabled reasons.
- PBS editing lives in the Save Team Script tab, its entry point on team rows, and the battle Autobattle control. Expose binding/editor/notification settings only when the integrated behavior is present; no script-manager or selector-window settings inherited merely because PBS supplied them.
- Battle options follow the current Akolus panel and selected BPBUIT extras, with capability-dependent availability on 12.1. A toggle cannot make secret or unavailable API data readable; keep unknown values unknown. Detailed fallback behavior belongs to [battle](battle.md).
- Later UltraSquirt behavior belongs in existing team/battle controls and preferences when implemented, without importing its separate windows. No placeholder automation settings in Phase A.

## Acceptance and gaps

For every visible control, identify its shipped behavior, initial value, persistence, immediate effect, and reset behavior. Verify search, category expansion, missing-capability handling, keyboard operation, and reopen persistence without battle/loadout side effects. The exact Phase A changed-option inventory depends on the shipped implementation; record it during implementation rather than claiming all source options are required. Defaults for observed surface controls remain recorded in their individual specs. Options content has no supplied screenshot, so visual parity there remains unverified.
