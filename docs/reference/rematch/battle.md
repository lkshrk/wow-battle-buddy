# Battle

## Evidence and precedence

Visual references: `../screenshots/battle-ui-pbs-bpbuit.png`, `battle-enemy-ability-tooltip.png`, and `battle-enemy-pet-tooltip-breed.png`. They show opposing top health panels, a central round number, health percentage/power/speed beneath the bars, three enemy ability icons above the bottom controls, Pass and Autobattle, and ability/breed tooltips. The captured bottom panel still has Blizzard's wood decoration. Screenshots govern captured layout; do not claim the newer dark panel is pictured.

Local behavior sources: `/tmp/ns/ref/Akolus_12.1-Rematch/process/{battleActionBar,battleControls,enemyAbilities,abilityEffectiveness,battleData,battleBreedTooltip}.lua`, `info/targetInfo.lua`, `panels/loadoutPanel.lua`, and `Rematch-custom-changelog.md`; `/tmp/ns/ref/bpbuit/BattlePetBattleUITweaks/{options,stats,round,health,binds,abilities}.lua`. These are factual references, not reusable implementation or artwork.

## Requested current Akolus panel

- Reproduce the current unified bottom controls as the requested extension to the captured baseline: Battle Data, Pass, Autobattle and binding control; player abilities, swap, trap and forfeit; XP along the bottom; PvP turn time above. Use a compact dark treatment and cyan separators; omit the old separate control plaque and micro-menu. The source describes a 106-pixel panel at 100% scale and an 8-pixel XP strip; verify the result against a new capture before calling this visual parity.
- Shift-drag moves the panel; Ctrl-wheel scales around its center in 1% steps, bounded to 50–200%. Persist placement and scale. Enemy abilities have their own placement and scale, hide during pet selection, update when the active enemy changes, and disappear outside battle.
- Ability hover exposes the native ability information and family effectiveness. Current Akolus additionally colors useful/poor matchups with green/red gradients, leaving neutral or explicitly suppressed hints uncolored. Unknown public data produces no effectiveness claim.
- PBS supplies script execution inside this panel. Save Team's Script tab edits the team's script; the team row exposes its script state/action; Autobattle advances it from a deliberate click or bound key. Do not ship a separate PBS editor/window or second battle bar. `+` captures a binding; right-click clears it. Defer protected binding changes during combat and clear battle-only overrides when battle ends.
- Current `battleControls.lua` is authoritative over older changelog experiments: no unattended event/timer execution, external clicker, global input capture, or persistent automatic-turn toggle. UI refresh never dispatches a move.

## Selected BPBUIT extras

Keep the screenshot-backed round indicator and frontline health percentage, power and speed. Use one enemy-ability display supplied by the Akolus-style panel, not a second BPBUIT or PetTracker bar. Health threshold ticks are an optional shipped-feature control: quarter/half health, magic-family thresholds, and an opposing Explode estimate only with readable inputs. Optional pass/forfeit/swap bindings must coexist with user bindings. Phase A exposes only changed options and controls for features actually shipped; no wholesale BPBUIT settings page.

## Retail 12.1 compatibility boundary

- `info/targetInfo.lua` tests secrecy before string processing, comparisons or lookup. It falls back from unavailable GUID identity to readable species or uniquely matching names, including gossip/scenario evidence; ambiguous or player names must not select a team. This is a public-data fallback, never a method to reveal secrets.
- The Akolus mouse fix replaces unavailable global `MouseIsOver` with region `IsMouseOver`; focus lookup uses `GetMouseFoci`. Check supported APIs with `wow-api` before implementation rather than reviving removed globals.
- `abilityEffectiveness.lua` and `battleData.lua` check optional calls and catch failures; this does not make secret results usable. BattleBuddy must reject secret values before any comparison, indexing, arithmetic or formatting, and distinguish unknown from zero.
- Akolus `enemyAbilities.lua` estimates cooldowns from combat messages; `battleData.lua` records/parses those messages. BattleBuddy's no-combat-log-parsing rule takes precedence. Use supported public pet-battle facts/events; if cooldown or round detail cannot be obtained, show unknown/omit it. Battle Data may present available snapshots, but cannot reproduce the source recorder through log parsing.

## Acceptance and gaps

Check opening/closing battle, active-pet change, death/swap selection, usable/disabled abilities, missing script, binding capture/cancel/clear, PvP timer, reload persistence, and combat lockdown. Secret/missing APIs must leave a usable panel without fabricated values or action dispatch. Test one click causes at most one script action. Compare tooltip and enemy-bar placement against supplied images.

No current dark-panel screenshot, live 12.1 validation, verified public replacement for log-derived cooldowns, or complete PvP capture is supplied. Keep these explicit parity gaps. Do not copy ARR/unlicensed source, XML, comments, prose or assets; PBS reuse is governed separately by its pinned MIT license.
